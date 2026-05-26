PACKAGE BODY ajc_bc_purge_tables_pkg IS
-- SBANCHIERI - FEB-2025
  
  -- gv_email   VARCHAR2(2000) := 'sbanchieri@gmail.com';
  gv_email   VARCHAR2(2000) := 'appstech@ajcfood.com';

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    gv_log_seq := gv_log_seq + 1;
    ajcl_bc_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );

  END print_log;

  PROCEDURE send_mail_p ( p_error_msg   IN   VARCHAR2 ) IS
  BEGIN

    print_log ( 'ajc_bc_purge_tables_pkg.send_mail_p (+)' );

    ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,
                                     p_subject => gv_bc_ifc || ' - ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_oracle_db || ' (' || gv_jenkins_build_number || ')',
                                     p_message => p_error_msg );

    print_log ( 'ajc_bc_purge_tables_pkg.send_mail_p (-)' );

  END send_mail_p;

  FUNCTION validate_keep_x_days_f RETURN VARCHAR2 IS

    v_keep_x_days       VARCHAR2(200);
    e_parameter_value   EXCEPTION;

  BEGIN

    print_log ( 'ajc_bc_purge_tables_pkg.validate_keep_x_days_f (+) ');

    v_keep_x_days := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'PURGE_CLOB_KEEP_X_DAYS' );

    IF ( LENGTH(regexp_replace(v_keep_x_days, '[0-9]', '')) IS NOT NULL ) THEN

      RAISE e_parameter_value;

    END IF;

    -- Se copia el valor a la global
    gv_keep_x_days := TO_NUMBER(v_keep_x_days);

    print_log ( 'gv_keep_x_days: ' || gv_keep_x_days );

    print_log ( 'ajc_bc_purge_tables_pkg.validate_keep_x_days_f (-)' );

    RETURN 'S';

  EXCEPTION 
    WHEN e_parameter_value THEN
      print_log ( 'ajc_bc_purge_tables_pkg.validate_keep_x_days_f (!)' );
      RETURN 'E';
    WHEN OTHERS THEN
      print_log ( 'ajc_bc_purge_tables_pkg.validate_keep_x_days_f (!)' );
      RETURN 'E';

  END validate_keep_x_days_f;

  PROCEDURE calc_statistics_p ( p_moment   IN   VARCHAR2 ) IS

      CURSOR c_tab_stats IS
      SELECT pt.TABLE_NAME,
             ROUND(SUM(bytes) / 1048567,2) table_size_mb
        FROM AJC_BC_PURGE_TABLES_COLUMNS pt,
             DBA_SEGMENTS ds           
       WHERE pt.COMPANY = gv_company
         AND pt.COLUMN_NAME = 'ALL'
         AND pt.PURGE_ACTION = 'DELETE_ROWS'
         AND pt.TABLE_NAME = ds.segment_name
         AND pt.ENABLED = 'Y'
    GROUP BY pt.TABLE_NAME;

      CURSOR c_clob_stats IS
      SELECT pt.TABLE_NAME,
             pt.COLUMN_NAME,
             ROUND(SUM(bytes) / 1048567,2) clob_size_mb
        FROM AJC_BC_PURGE_TABLES_COLUMNS pt,
             DBA_LOBS dl,
             DBA_SEGMENTS ds
       WHERE pt.COMPANY = gv_company
         AND pt.PURGE_ACTION = 'UPDATE_CLOBS'
         AND pt.ENABLED = 'Y'
         AND pt.TABLE_NAME = dl.TABLE_NAME
         AND pt.COLUMN_NAME = dl.COLUMN_NAME
         AND dl.SEGMENT_NAME = ds.SEGMENT_NAME
    GROUP BY pt.TABLE_NAME,
             pt.COLUMN_NAME;

  BEGIN          

    IF ( p_moment = 'BEFORE' ) THEN

      UPDATE AJC_BC_PURGE_TABLES_COLUMNS
         SET TABLE_SIZE_BEFORE_MB = NULL,
             TABLE_SIZE_AFTER_MB = NULL,
             --
             CLOB_SIZE_BEFORE_MB = NULL,
             CLOB_SIZE_AFTER_MB = NULL,
             --
             ROWS_TO_UPDATE = NULL,
             ROWS_UPDATED = NULL,
             --
             LAST_UPDATE_DATE = SYSDATE
       WHERE COMPANY = gv_company;          

      COMMIT;

    END IF;  

    -- Estadisticas Tablas
    FOR ct IN c_tab_stats LOOP

      IF ( p_moment = 'BEFORE' ) THEN 

        UPDATE AJC_BC_PURGE_TABLES_COLUMNS
           SET TABLE_SIZE_BEFORE_MB = ct.table_size_mb
         WHERE TABLE_NAME = ct.TABLE_NAME
           AND COLUMN_NAME = 'ALL'
           AND ENABLED = 'Y'
           AND COMPANY = gv_company
           AND PURGE_ACTION = 'DELETE_ROWS';

      ELSIF ( p_moment = 'AFTER' ) THEN 

        UPDATE AJC_BC_PURGE_TABLES_COLUMNS
           SET TABLE_SIZE_AFTER_MB = ct.table_size_mb
         WHERE TABLE_NAME = ct.TABLE_NAME
           AND COLUMN_NAME = 'ALL'
           AND ENABLED = 'Y'
           AND COMPANY = gv_company
           AND PURGE_ACTION = 'DELETE_ROWS';

      END IF;

    END LOOP;

    -- Estadisticas CLOBs
    FOR ct IN c_clob_stats LOOP

      IF ( p_moment = 'BEFORE' ) THEN 

        UPDATE AJC_BC_PURGE_TABLES_COLUMNS
           SET CLOB_SIZE_BEFORE_MB = ct.clob_size_mb
         WHERE TABLE_NAME = ct.TABLE_NAME
           AND COLUMN_NAME = ct.COLUMN_NAME
           AND ENABLED = 'Y'
           AND COMPANY = gv_company
           AND PURGE_ACTION = 'UPDATE_CLOBS';

      ELSIF ( p_moment = 'AFTER' ) THEN 

        UPDATE AJC_BC_PURGE_TABLES_COLUMNS
           SET CLOB_SIZE_AFTER_MB = ct.clob_size_mb
         WHERE TABLE_NAME = ct.TABLE_NAME
           AND COLUMN_NAME = ct.COLUMN_NAME
           AND ENABLED = 'Y'
           AND COMPANY = gv_company
           AND PURGE_ACTION = 'UPDATE_CLOBS';

      END IF;

    END LOOP;

    COMMIT;

  END calc_statistics_p;

  PROCEDURE rebuild_indexes_p ( p_table_name   IN   VARCHAR2,
                                p_status      OUT   VARCHAR2,
                                p_error_msg   OUT   VARCHAR2 ) IS

      CURSOR c_rebuild_indexes ( p_table_name   IN   VARCHAR2 ) IS
      SELECT 'ALTER INDEX ' || owner || '.' || index_name || ' REBUILD' rebuild
        FROM dba_indexes 
       WHERE table_name = p_table_name 
         AND index_type = 'NORMAL'
    ORDER BY index_name;    

  BEGIN

    -- print_log ( 'ajc_bc_purge_tables_pkg.rebuild_indexes_p (+)' );

    FOR cri IN c_rebuild_indexes ( p_table_name => p_table_name ) LOOP

      print_log ( cri.rebuild );

      IF ( gv_preview = 'N' ) THEN

        EXECUTE IMMEDIATE cri.rebuild;

      END IF;

    END LOOP;

    p_status := 'S';

    -- print_log ( 'ajc_bc_purge_tables_pkg.rebuild_indexes_p (-)' );

  EXCEPTION
    WHEN OTHERS THEN
      print_log ( 'ajc_bc_purge_tables_pkg.rebuild_indexes_p (!)' );
      p_status := 'E';
      p_error_msg := SQLERRM;

  END rebuild_indexes_p;

  FUNCTION check_table_exists_f ( p_table_name   IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_exists   VARCHAR2(1);

  BEGIN

    -- print_log ( 'ajc_bc_purge_tables_pkg.check_table_exists_f (+)' );

    SELECT DECODE(COUNT(1),0,'N','Y')
      INTO v_exists
      FROM ALL_TABLES
     WHERE TABLE_NAME = p_table_name;

    IF ( v_exists = 'N' ) THEN

      print_log ( 'Table ' || p_table_name || ' not exist.' );
      print_log ( 'v_exists:: ' || v_exists );

    END IF;
    -- print_log ( 'ajc_bc_purge_tables_pkg.check_table_exists_f (-)' );

    RETURN v_exists;    

  END check_table_exists_f;

  FUNCTION check_column_exists_f ( p_table_name    IN   VARCHAR2,
                                   p_column_name   IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_exists   VARCHAR2(1);

  BEGIN

    -- print_log ( 'ajc_bc_purge_tables_pkg.check_column_exists_f (+)' );    

    SELECT DECODE(COUNT(1),0,'N','Y')
      INTO v_exists
      FROM ALL_TAB_COLUMNS
     WHERE TABLE_NAME = p_table_name
       AND COLUMN_NAME = p_column_name;

    IF ( v_exists = 'N' ) THEN

      print_log ( 'Column ' || p_table_name || '.' || p_column_name || ' not exist.' );

    END IF;

    -- print_log ( 'ajc_bc_purge_tables_pkg.check_column_exists_f (-)' );

    RETURN v_exists;    

  END check_column_exists_f;

  PROCEDURE update_row_count ( p_table_name    IN   VARCHAR2,
                               p_rows          IN   NUMBER ) IS
  BEGIN

    IF ( gv_preview = 'Y' ) THEN

      UPDATE AJC_BC_PURGE_TABLES_COLUMNS
         SET rows_to_update = p_rows
       WHERE TABLE_NAME = p_table_name
         AND COMPANY = gv_company;

    ELSIF ( gv_preview = 'N' ) THEN

      UPDATE AJC_BC_PURGE_TABLES_COLUMNS
         SET rows_updated = p_rows
       WHERE TABLE_NAME = p_table_name
         AND COMPANY = gv_company;

    END IF;

  END update_row_count;

  PROCEDURE process_p ( p_status      OUT   VARCHAR2,
                        p_error_msg   OUT   VARCHAR2 ) IS

      CURSOR c_tables IS
      SELECT at.OWNER,
             at.TABLESPACE_NAME,
             pc.TABLE_NAME,
             pc.PURGE_ACTION
        FROM AJC_BC_PURGE_TABLES_COLUMNS pc,
             ALL_TABLES at
       WHERE pc.COMPANY = gv_company
         AND pc.PURGE_ACTION IN ('DELETE_ROWS','UPDATE_CLOBS')
         AND pc.ENABLED = 'Y'
         AND pc.TABLE_NAME = at.TABLE_NAME (+)
    GROUP BY at.OWNER,
             at.TABLESPACE_NAME,
             pc.TABLE_NAME,
             pc.PURGE_ACTION 
    ORDER BY at.OWNER,
             pc.TABLE_NAME;

      CURSOR c_columns ( p_table_name   IN   VARCHAR2 ) IS
      SELECT atc.OWNER,
             pc.COLUMN_NAME,
             atc.DATA_TYPE
        FROM AJC_BC_PURGE_TABLES_COLUMNS pc,
             ALL_TAB_COLUMNS atc
       WHERE pc.COMPANY = gv_company
         AND pc.PURGE_ACTION IN ('DELETE_ROWS','UPDATE_CLOBS')
         AND pc.ENABLED = 'Y'
         AND pc.TABLE_NAME = p_table_name
         AND pc.TABLE_NAME = atc.TABLE_NAME (+)
         AND pc.COLUMN_NAME = atc.COLUMN_NAME (+)
    ORDER BY pc.COLUMN_NAME; 

    v_select             VARCHAR2(2000);
    v_columns            VARCHAR2(2000);
    v_where              VARCHAR2(2000);
    v_count              NUMBER;

    v_update             VARCHAR2(2000);
    v_alter              VARCHAR2(2000);

    v_delete             VARCHAR2(2000);

    v_table_name         VARCHAR2(200);
    v_column_name        VARCHAR2(200);

    c_cursor             SYS_REFCURSOR;

    e_parameter_value    EXCEPTION;
    e_table_not_exist    EXCEPTION;
    e_column_not_exist   EXCEPTION;
    e_not_clob           EXCEPTION;

  BEGIN

    print_log ( 'ajc_bc_purge_tables_pkg.process_p (+)' );

    gv_oracle_db := ajcl_bc_utils_pkg.get_db_name_f;
    print_log ( 'gv_oracle_db: ' || gv_oracle_db );

    IF ( validate_keep_x_days_f != 'S' ) THEN

      RAISE e_parameter_value;

    END IF;

    -- Se chequea si todas las tablas / columnas cargadas en la tabla AJC_BC_PURGE_TABLES_COLUMNS existen
    -- Cuando PURGE_ACTION es DELETE_ROWS, no se chequea si las columnas existen
    -- Cuando PURGE_ACTION es UPDATE_CLOBS, si
    print_log ( 'Checking if tables / columns exist.' );

    FOR ct IN c_tables LOOP

      v_table_name := ct.TABLE_NAME;

      IF ( check_table_exists_f ( ct.TABLE_NAME ) = 'Y' ) THEN

        IF ( ct.PURGE_ACTION = 'UPDATE_CLOBS' ) THEN

          FOR cc IN c_columns ( ct.TABLE_NAME ) LOOP

            v_column_name := cc.COLUMN_NAME;

            IF ( check_column_exists_f ( ct.TABLE_NAME, cc.COLUMN_NAME ) = 'N' ) THEN

              RAISE e_column_not_exist;

            ELSE

              IF ( cc.DATA_TYPE != 'CLOB' ) THEN

                RAISE e_not_clob;

              END IF;

            END IF;

          END LOOP;

        END IF;

      ELSE

        RAISE e_table_not_exist;

      END IF;

    END LOOP;

    calc_statistics_p ( p_moment => 'BEFORE' );

    -- Se arman los UPDATES / DELETES
    FOR ct IN c_tables LOOP

      print_log ( '-- ' || ct.TABLE_NAME );

      -- ERASE CLOB columns ------------------------------------------------------------------------------------  
      IF ( ct.PURGE_ACTION = 'UPDATE_CLOBS' ) THEN

        v_update := 'UPDATE ' || ct.OWNER || '.' || ct.TABLE_NAME || ' SET';
        v_columns := NULL;

        FOR cc IN c_columns ( ct.TABLE_NAME ) LOOP

          v_columns := v_columns || ' ' || cc.COLUMN_NAME || ' = NULL,';

        END LOOP;

        -- Se quita la ultima coma
        v_columns := SUBSTR(v_columns,1,LENGTH(v_columns) - 1);

        v_update := v_update || v_columns;        
        v_where := ' WHERE TRUNC(SYSDATE) - TRUNC(creation_date) > ' || gv_keep_x_days;

        -- Se agregan condiciones para no estar actualizando constantemente registros que ya fueron actualizados
        v_where := v_where || ' AND (';
        v_columns := NULL;

        FOR cc IN c_columns ( ct.TABLE_NAME ) LOOP

          v_columns := v_columns || ' ' || cc.COLUMN_NAME || ' IS NOT NULL OR';

        END LOOP;

        -- Se quita el último OR
        v_columns := SUBSTR(v_columns,1,LENGTH(v_columns) - 2);
        v_where := v_where || v_columns || ')';

        v_update := v_update || v_where;

        print_log ( v_update );

        IF ( gv_preview = 'Y' ) THEN

          v_select := 'SELECT COUNT(1) FROM ' || ct.OWNER || '.' || ct.TABLE_NAME;
          v_select := v_select || v_where;

          EXECUTE IMMEDIATE v_select INTO v_count;

          print_log ( 'Rows to UPDATE: ' || v_count );
          update_row_count ( p_table_name => ct.TABLE_NAME,
                             p_rows => v_count );

        ELSIF ( gv_preview = 'N' ) THEN

          EXECUTE IMMEDIATE v_update;

          v_count := SQL%ROWCOUNT;
          print_log ( 'Rows UPDATED: ' || v_count );
          update_row_count ( p_table_name => ct.TABLE_NAME,
                             p_rows => v_count );

          COMMIT;

        END IF;

        -- MOVE CLOB COLUMNS ------------------------------------------------------------------------------------  
        FOR cc IN c_columns ( ct.TABLE_NAME ) LOOP

          v_alter := 'ALTER TABLE ' || ct.OWNER || '.' || ct.TABLE_NAME || ' MOVE LOB (' || cc.COLUMN_NAME || ') STORE AS (TABLESPACE ' || ct.TABLESPACE_NAME || ')';
          print_log ( v_alter );

          IF ( gv_preview = 'N' ) THEN

            EXECUTE IMMEDIATE v_alter;

          END IF;

        END LOOP;

      -- DELETE records
      ELSIF ( ct.PURGE_ACTION = 'DELETE_ROWS' ) THEN

        v_delete := 'DELETE ' || ct.OWNER || '.' || ct.TABLE_NAME;
        -- v_delete := 'DELETE ' || NVL(ct.VIEW_NAME,ct.TABLE_NAME);

        v_where := ' WHERE TRUNC(SYSDATE) - TRUNC(creation_date) > ' || gv_keep_x_days;
        v_delete := v_delete || v_where;

        print_log ( v_delete );

        v_alter := 'ALTER TABLE ' || ct.OWNER || '.' || ct.TABLE_NAME || ' MOVE';
        print_log ( v_alter );

        IF ( gv_preview = 'Y' ) THEN

          v_select := 'SELECT COUNT(1) FROM ' || ct.OWNER || '.' || ct.TABLE_NAME;
          -- v_select := 'SELECT COUNT(1) FROM ' || NVL(ct.VIEW_NAME,ct.TABLE_NAME);

          v_select := v_select || v_where;

          EXECUTE IMMEDIATE v_select INTO v_count;

          print_log ( 'Rows to DELETE: ' || v_count );
          update_row_count ( p_table_name => ct.TABLE_NAME,
                             p_rows => v_count );

        ELSIF ( gv_preview = 'N' ) THEN

          EXECUTE IMMEDIATE v_delete;

          v_count := SQL%ROWCOUNT;
          print_log ( 'Rows DELETED: ' || SQL%ROWCOUNT );
          update_row_count ( p_table_name => ct.TABLE_NAME,
                             p_rows => v_count );

          EXECUTE IMMEDIATE v_alter;

          COMMIT;  

        END IF;

      END IF;

      -- REBUILD INDEXES --------------------------------------------------------------------------------------
      rebuild_indexes_p ( p_table_name => ct.TABLE_NAME,
                          p_status => p_status,
                          p_error_msg => p_error_msg );

    END LOOP;  

    IF ( gv_preview = 'N' ) THEN

      calc_statistics_p ( p_moment => 'AFTER' );

    END IF;

    COMMIT;

    gv_output_filename := gv_output_filename || gv_company;

    -- Output ------------------------------------------------------------------------------------------------------------------------------------------------------------
    ajcl_bc_utils_pkg.create_csv_p ( p_ifc => gv_bc_ifc,
                                     p_request_id => gv_request_id,
                                     p_log_seq => gv_log_seq,
                                     p_type => 'LOG',
                                     p_filename => gv_output_filename,
                                     p_status => p_status );

    ajcl_bc_utils_pkg.send_mail_with_attach ( p_to_mail => gv_email,
                                              p_subject => gv_bc_ifc || ' Log - ' || TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS') || ' ' || gv_oracle_db || ' (' || gv_jenkins_build_number || ')',
                                              p_body => gv_bc_ifc || ' Log.',
                                              p_type => 'LOG',
                                              p_filename => gv_output_filename, 
                                              p_attach_filename => gv_bc_ifc || ' Log ' || TO_CHAR(SYSDATE,'YYYY-MM-DD HH24MISS') || ' ' || gv_oracle_db || '.csv' );  

    -- Report ------------------------------------------------------------------------------------------------------------------------------------------------------------
    gv_directory_report := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_REPORT' );

    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc || ' Report',
                                                p_request_id => gv_request_id,
                                                p_bc_environment => gv_oracle_db,
                                                p_jenkins_build_number => gv_jenkins_build_number,
                                                p_param_1_title => 'PREVIEW',
                                                p_param_1_value => gv_preview );

    -- Purge Details
    IF ( gv_preview = 'Y' ) THEN

          OPEN c_cursor FOR
        SELECT TABLE_NAME,
               COLUMN_NAME,
               PURGE_ACTION,
               TABLE_SIZE_BEFORE_MB table_size_mb,
               CLOB_SIZE_BEFORE_MB clob_size_mb,
               ROWS_TO_UPDATE
          FROM AJC_BC_PURGE_TABLES_COLUMNS 
         WHERE COMPANY = gv_company
      ORDER BY 1,2,3;

    ELSIF ( gv_preview = 'N' ) THEN

        OPEN c_cursor FOR
        SELECT TABLE_NAME,
               COLUMN_NAME,
               PURGE_ACTION,
               TABLE_SIZE_BEFORE_MB,
               TABLE_SIZE_AFTER_MB,
               CLOB_SIZE_BEFORE_MB,
               CLOB_SIZE_AFTER_MB,
               ROWS_UPDATED
          FROM AJC_BC_PURGE_TABLES_COLUMNS 
         WHERE COMPANY = gv_company
      ORDER BY 1,2,3;

    END IF;

    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Purge Details',
                                       p_sheet => 2,
                                       p_cursor => c_cursor );

    gv_report_filename := gv_report_filename || gv_company;

    as_xlsx.save ( gv_directory_report, gv_report_filename || '.' || LOWER(gv_file_format) );

    ajcl_bc_utils_pkg.send_mail_with_attach ( p_to_mail => gv_email,
                                              p_subject => gv_bc_ifc || ' Report - ' || TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS') || ' ' || gv_oracle_db || ' (' || gv_jenkins_build_number || ')',
                                              p_body => gv_bc_ifc || ' Report.',
                                              p_type => 'REPORT',
                                              p_filename => gv_report_filename, 
                                              p_file_format => gv_file_format,
                                              p_attach_filename => gv_bc_ifc || ' Report ' || TO_CHAR(SYSDATE,'YYYY-MM-DD HH24MISS') || ' ' || gv_oracle_db || '.' || LOWER(gv_file_format) );      

    p_status := 'S';

    print_log ( 'ajc_bc_purge_tables_pkg.process_p (-)' );    

  EXCEPTION
    WHEN e_parameter_value THEN
      p_error_msg := 'PURGE_CLOB_KEEP_X_DAYS parameter code only allow numbers in parameter_value field. Check AJC_BC_PARAMETERS table.';
      print_log ( 'ajc_bc_purge_tables_pkg.process_p (!). - ' || p_error_msg );    
      p_status := 'P';      

    WHEN e_table_not_exist THEN
      p_error_msg := 'Table ' || v_table_name || ' not exist. Check AJC_BC_PURGE_TABLES_COLUMNS table.';
      print_log ( 'ajc_bc_purge_tables_pkg.process_p (!). - ' || p_error_msg );    
      p_status := 'E';      

    WHEN e_column_not_exist THEN
      p_error_msg := 'Column ' || v_table_name || '.' || v_column_name || ' not exist. Check AJC_BC_PURGE_TABLES_COLUMNS table.';
      print_log ( 'ajc_bc_purge_tables_pkg.process_p (!). - ' || p_error_msg );    
      p_status := 'E';      

    WHEN e_not_clob THEN
      p_error_msg := 'Column ' || v_table_name || '.' || v_column_name || ' is not a CLOB column. Check AJC_BC_PURGE_TABLES_COLUMNS table.';  
      print_log ( 'ajc_bc_purge_tables_pkg.process_p (!). - ' || p_error_msg );    
      p_status := 'E';      

    WHEN OTHERS THEN
      print_log ( 'ajc_bc_purge_tables_pkg.process_p (!). ' || SQLERRM ); 
      p_status := 'E';
      p_error_msg := SQLERRM;

  END process_p;

  -- MAIN FOODS ----------------------------------------------------------------
  PROCEDURE foods_main_p ( p_preview                IN   VARCHAR2,
                           p_jenkins_build_number   IN   VARCHAR2 ) IS

    v_status            VARCHAR2(10);
    v_error_msg         VARCHAR2(2000);

    e_parameter_value   EXCEPTION;
    e_others            EXCEPTION;

  BEGIN

    gv_request_id := ajcl_bc_utils_pkg.get_request_id_f;
    gv_jenkins_build_number := p_jenkins_build_number;

    gv_preview := p_preview;

    gv_bc_ifc := 'BC Purge Tables - FOODS';

    print_log ( 'ajc_bc_purge_tables_pkg.foods_main_p (+)' );

    print_log ( 'gv_bc_ifc: ' || gv_bc_ifc );
    print_log ( 'gv_request_id: ' || gv_request_id ); 
    print_log ( 'gv_jenkins_build_number: ' || gv_jenkins_build_number );
    print_log ( 'gv_preview: ' || gv_preview );

    gv_company := 'FOODS';
    print_log ( 'gv_company: ' || gv_company );

    process_p ( p_status => v_status,
                p_error_msg => v_error_msg );

    IF ( v_status = 'P' ) THEN

      RAISE e_parameter_value;

    ELSIF ( v_status = 'E' ) THEN

      RAISE e_others;

    END IF;

    print_log ( 'ajc_bc_purge_tables_pkg.foods_main_p (-)' );

  EXCEPTION
    WHEN e_parameter_value THEN

      send_mail_p ( p_error_msg => v_error_msg );
      print_log ( 'ajc_bc_purge_tables_pkg.foods_main_p (!). ' || v_error_msg );
      RAISE_APPLICATION_ERROR(-20000,'ajc_bc_purge_tables_pkg.foods_main_p - ' || v_error_msg);

    WHEN e_others THEN

      send_mail_p ( p_error_msg => v_error_msg );
      print_log ( 'ajc_bc_purge_tables_pkg.foods_main_p (!). ' || v_error_msg );
      RAISE_APPLICATION_ERROR(-20000,'ajc_bc_purge_tables_pkg.foods_main_p - ' || v_error_msg);

    WHEN OTHERS THEN

      send_mail_p ( p_error_msg => v_error_msg );
      print_log ( 'ajc_bc_purge_tables_pkg.foods_main_p (!). ' || v_error_msg );
      RAISE_APPLICATION_ERROR(-20000,'ajc_bc_purge_tables_pkg.foods_main_p - ' || SQLERRM);

  END foods_main_p;

  -- MAIN LOGIS ----------------------------------------------------------------
  PROCEDURE logis_main_p ( p_preview                IN   VARCHAR2,
                           p_jenkins_build_number   IN   VARCHAR2 ) IS

    v_status            VARCHAR2(10);
    v_error_msg         VARCHAR2(2000);

    e_parameter_value   EXCEPTION;
    e_others            EXCEPTION;

  BEGIN

    gv_request_id := ajcl_bc_utils_pkg.get_request_id_f;
    gv_jenkins_build_number := p_jenkins_build_number;

    gv_preview := p_preview;

    gv_bc_ifc := 'BC Purge Tables - LOGIS';

    print_log ('ajc_bc_purge_tables_pkg.logis_main_p (+)');

    print_log ( 'gv_bc_ifc: ' || gv_bc_ifc ); 
    print_log ( 'gv_request_id: ' || gv_request_id ); 
    print_log ( 'gv_jenkins_build_number: ' || gv_jenkins_build_number );
    print_log ( 'gv_preview: ' || gv_preview );

    gv_company := 'LOGIS';
    print_log ( 'gv_company: ' || gv_company );

    process_p ( p_status => v_status,
                p_error_msg => v_error_msg );

    IF ( v_status = 'P' ) THEN

      RAISE e_parameter_value;

    ELSIF ( v_status = 'E' ) THEN

      RAISE e_others;

    END IF;

    print_log ( 'ajc_bc_purge_tables_pkg.logis_main_p (-)' );

  EXCEPTION
    WHEN e_parameter_value THEN

      send_mail_p ( p_error_msg => v_error_msg );
      print_log ( 'ajc_bc_purge_tables_pkg.logis_main_p (!). ' || v_error_msg );
      RAISE_APPLICATION_ERROR(-20000,'ajc_bc_purge_tables_pkg.logis_main_p - ' || v_error_msg);

    WHEN e_others THEN

      send_mail_p ( p_error_msg => v_error_msg );
      print_log ( 'ajc_bc_purge_tables_pkg.logis_main_p (!). ' || v_error_msg );
      RAISE_APPLICATION_ERROR(-20000,'ajc_bc_purge_tables_pkg.logis_main_p - ' || v_error_msg);

    WHEN OTHERS THEN

      send_mail_p ( p_error_msg => v_error_msg );
      print_log ( 'ajc_bc_purge_tables_pkg.logis_main_p (!). ' || v_error_msg );
      RAISE_APPLICATION_ERROR(-20000,'ajc_bc_purge_tables_pkg.logis_main_p - ' || SQLERRM);

  END logis_main_p;

END ajc_bc_purge_tables_pkg;
