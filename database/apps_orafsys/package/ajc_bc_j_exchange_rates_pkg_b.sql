PACKAGE BODY              AJC_BC_J_EXCHANGE_RATES_PKG IS

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    gv_log_seq := gv_log_seq + 1;
    AJC_BC_J_UTILS_PKG.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );

  END print_log;

  PROCEDURE get_daily_rates_p ( p_return           OUT   VARCHAR2, 
                                p_message          OUT   VARCHAR2,
                                p_count            OUT   NUMBER ) IS

    v_get_url       VARCHAR2(2000);
    v_get_api       VARCHAR2(100);
    v_clob_result   CLOB;

      CURSOR c_companies IS
   
     SELECT bc_company_name,
             currency,
             bc_company_id
        FROM ajc_bc_companies
        WHERE BC_COMPANY_NAME NOT LIKE 'LFS%' --Mbetti REVISAR 20260421
    GROUP BY bc_company_name,
             currency,
             bc_company_id
    ORDER BY bc_company_name;

    CURSOR c_rates ( p_clob_result   CLOB ) IS
    SELECT DECODE(currency,'MXN','MEX',currency) currency,
           TO_DATE(conversion_date,'YYYY-MM-DD') conversion_date,
           conversion_rate
      FROM json_table( p_clob_result,
                       '$.value[*]' COLUMNS ( currency          VARCHAR2(4000)  path '$.Currency_Code'
                                             ,conversion_date   VARCHAR2(4000)  path '$.Starting_Date'
                                             ,conversion_rate   VARCHAR2(4000)  path '$.Exchange_Rate_Amount' ) );

    v_from_currency     gl_daily_rates.from_currency%TYPE;
    v_to_currency       gl_daily_rates.to_currency%TYPE;
    v_conversion_date   gl_daily_rates.conversion_date%TYPE;
    v_conversion_rate   gl_daily_rates.conversion_rate%TYPE;

  BEGIN

    print_log ('AJC_BC_J_EXCHANGE_RATES_PKG.get_daily_rates_p (+)');

    v_get_api := AJC_BC_J_WS_UTILS_PKG.get_api_f ( p_entity => 'EXCHANGE RATES',
                                                   p_subentity => NULL,
                                                   p_method => 'GET' );
    print_log ( 'v_get_api: ' || v_get_api );

    p_count := 0;

    FOR cc IN c_companies LOOP

      print_log ( 'Company: ' || cc.bc_company_name );

      v_get_url := AJC_BC_J_WS_UTILS_PKG.get_base_ajc_url_f ( gv_bc_environment, cc.bc_company_name ) || v_get_api
                   || '?$filter=Starting_Date eq ' || TO_CHAR(gv_date,'YYYY-MM-DD');

      print_log ( 'v_get_url: ' || v_get_url );

      v_clob_result := AJC_BC_J_WS_UTILS_PKG.get_bc_clob_result_f ( p_url => v_get_url );

      FOR cr IN c_rates ( v_clob_result ) LOOP

        v_from_currency := cc.currency;
        v_to_currency := cr.currency;
        v_conversion_date := cr.conversion_date;
        v_conversion_rate := cr.conversion_rate;

        print_log ('from_currency: ' || v_from_currency || ' to_currency: ' || v_to_currency || ' conversion_date: ' || v_conversion_date || ' conversion_rate: ' || v_conversion_rate);

        BEGIN

            INSERT 
              INTO AJC_BC_GL_DAILY_RATES 
                 ( bc_company,
                   from_currency,
                   to_currency,
                   conversion_date,
                   conversion_type,
                   conversion_rate,
                   --
                   request_id,
                   status,
                   creation_date,
                   created_by,
                   last_update_date,
                   last_updated_by,
                   last_update_login )
          VALUES ( cc.bc_company_name,
                   cc.currency,
                   cr.currency,
                   cr.conversion_date,
                   'Spot',
                   cr.conversion_rate,
                   --
                   gv_request_id,
                   'NEW',
                   SYSDATE,
                   gv_user_id,
                   SYSDATE,
                   gv_user_id,
                   gv_user_id );

          p_count := p_count + 1;

        EXCEPTION
          -- WHEN DUP_VAL_ON_INDEX THEN
          --   print_log ('Rate exists.');
          WHEN OTHERS THEN
            print_log ('Error: ' || SQLERRM);

        END;

      END LOOP; -- rates

    END LOOP; -- companies

    p_return := 'S';
    print_log ('AJC_BC_J_EXCHANGE_RATES_PKG.get_daily_rates_p (-)');

  EXCEPTION
    WHEN OTHERS THEN
      p_return := 'E';
      print_log ('AJC_BC_J_EXCHANGE_RATES_PKG.get_daily_rates_p (!). Error: ' || SQLERRM);

  END get_daily_rates_p;

  PROCEDURE create_daily_rates_p ( p_return    OUT   VARCHAR2, 
                                   p_message   OUT   VARCHAR2 ) IS

    v_message           VARCHAR2(2000);
    v_error_message     VARCHAR2(2000);
    e_cust_exception    EXCEPTION;  

      CURSOR c_rates_grouped ( p_condition   IN   VARCHAR2 ) IS
      SELECT from_currency, 
             to_currency, 
             conversion_date,
             conversion_type
        FROM ( SELECT from_currency, 
                      to_currency, 
                      conversion_date,
                      conversion_type,
                      conversion_rate
                 FROM ajc_bc_gl_daily_rates
                WHERE request_id = gv_request_id
                  AND status = 'NEW'
             GROUP BY from_currency, 
                      to_currency, 
                      conversion_date,
                      conversion_type,
                      conversion_rate         
             ORDER BY from_currency, 
                      to_currency )
    GROUP BY from_currency, 
             to_currency, 
             conversion_date,
             conversion_type
      HAVING DECODE(COUNT(1),1,'TO_PROCESS','DUPLICATED') = p_condition;     

      CURSOR c_daily_rates ( p_status   IN   VARCHAR2 ) IS
      SELECT from_currency, 
             to_currency, 
             conversion_date,
             conversion_type,
             conversion_rate,
             status
        FROM ajc_bc_gl_daily_rates
       WHERE request_id = gv_request_id
         AND status = p_status
    ORDER BY from_currency, 
             to_currency;

    v_from_currency     gl_daily_rates.from_currency%TYPE;
    v_to_currency       gl_daily_rates.to_currency%TYPE;
    v_conversion_date   gl_daily_rates.conversion_date%TYPE;
    v_conversion_rate   gl_daily_rates.conversion_rate%TYPE;

    v_duplicated        NUMBER;

    v_exists            NUMBER;
    v_inverse_exists    NUMBER;

    v_count             NUMBER;
    v_tbl_status        ajc_bc_gl_daily_rates.status%TYPE;
    v_tbl_message       ajc_bc_gl_daily_rates.message%TYPE;

  BEGIN

    print_log ('AJC_BC_J_EXCHANGE_RATES_PKG.create_daily_rates_p (+)');

    -- Se marcan las que tienen misma moneda from y to
    UPDATE ajc_bc_gl_daily_rates
       SET status = 'SKIPPED',
           message = 'Same Currency From - To.'
     WHERE from_currency = to_currency
       AND request_id = gv_request_id
       AND status = 'NEW';

    -- Se marcan las que estan ok para procesar
    FOR cok IN c_rates_grouped ( 'TO_PROCESS' ) LOOP

      -- Se actualiza su estado a TO_PROCESS
      UPDATE ajc_bc_gl_daily_rates
         SET status = 'TO_PROCESS'
       WHERE from_currency = cok.from_currency
         AND to_currency = cok.to_currency
         AND conversion_date = cok.conversion_date
         AND request_id = gv_request_id
         AND status = 'NEW';

    END LOOP;

    v_duplicated := 0;

    -- Se marcan las que NO estan ok para procesar
    FOR cnotok IN c_rates_grouped ( 'DUPLICATED' ) LOOP

      -- Se actualiza su estado a DUPLICATED
      UPDATE ajc_bc_gl_daily_rates
         SET status = 'DUPLICATED',
             message = 'Duplicated. Please, correct the situation in BC.'
       WHERE from_currency = cnotok.from_currency
         AND to_currency = cnotok.to_currency
         AND conversion_date = cnotok.conversion_date
         AND request_id = gv_request_id
         AND status = 'NEW';

      v_duplicated := v_duplicated + 1;

    END LOOP;

    v_count := 0;

    -- Se insertan en la interface las que estan ok para procesar
    FOR cdr IN c_daily_rates ( p_status => 'TO_PROCESS' ) LOOP

      -- Se verifica que no haya sido insertada aun
      SELECT COUNT(1)
        INTO v_exists
        FROM gl_daily_rates_interface
       WHERE from_currency = cdr.from_currency
         AND to_currency = cdr.to_currency
         AND from_conversion_date = cdr.conversion_date;

      -- Se verifica si ya se inserto la tasa inversa, si es asi, no se inserta y se marca como SKIPPED
      SELECT COUNT(1)
        INTO v_inverse_exists
        FROM gl_daily_rates_interface
       WHERE from_currency = cdr.to_currency
         AND to_currency = cdr.from_currency
         AND from_conversion_date = cdr.conversion_date;

      -- Si no existe la inversa, se inserta, sino se marca como SKIPPED
      IF ( v_exists = 0 AND v_inverse_exists = 0 ) THEN

          INSERT 
            INTO gl_daily_rates_interface 
               ( from_currency,
                 to_currency,
                 from_conversion_date,
                 to_conversion_date,
                 user_conversion_type,
                 conversion_rate,
                 mode_flag )
        VALUES ( cdr.from_currency,
                 cdr.to_currency,
                 cdr.conversion_date,
                 cdr.conversion_date,
                 cdr.conversion_type,
                 cdr.conversion_rate,
                 'I' );

        COMMIT;

        v_tbl_status := 'INTERFACED';
        v_tbl_message := NULL;

        v_count := v_count + 1;

      ELSE

        v_tbl_status := 'SKIPPED';
        v_tbl_message := 'Inverse rate processed.';

      END IF;

      -- Se actualiza su estado
      UPDATE ajc_bc_gl_daily_rates
         SET status = v_tbl_status,
             message = v_tbl_message
       WHERE from_currency = cdr.from_currency
         AND to_currency = cdr.to_currency
         AND conversion_date = cdr.conversion_date
         AND conversion_rate = cdr.conversion_rate
         AND request_id = gv_request_id
         AND status = cdr.status;

    END LOOP;

    print_log ( 'Rows Inserted: ' || v_count );

    IF ( v_count > 0 ) THEN

      DECLARE

        v_errbuf    VARCHAR2(100);
        v_retcode   NUMBER; 

      BEGIN

        -- Program - Daily Rates Import and Calculation
        print_log ( 'GL_CRM_UTILITIES_PKG.daily_rates_import' );
        GL_CRM_UTILITIES_PKG.daily_rates_import ( errbuf => v_errbuf,
                                                  retcode => v_retcode );
         print_log('v_errbuf: '||v_errbuf);
         print_log('v_retcode: '||v_retcode);         

      END;

      -- Se controlan las procesadas contra gl_daily_rates
      FOR cdr IN c_daily_rates ( p_status => 'INTERFACED' ) LOOP

        -- Se verifica si fueron creados los rates
        SELECT DECODE(COUNT(1),0,'ERROR',1,'ERROR',2,'IMPORTED','ERROR') -- 2 significa que creo el rate y el inverso
          INTO v_tbl_status
          FROM gl_daily_rates gldr
         WHERE ( ( gldr.from_currency = cdr.from_currency AND gldr.to_currency = cdr.to_currency ) OR
                 ( gldr.from_currency = cdr.to_currency AND gldr.to_currency = cdr.from_currency ) ) -- inverso
           AND gldr.conversion_date = cdr.conversion_date;

        UPDATE ajc_bc_gl_daily_rates
           SET status = v_tbl_status
         WHERE from_currency = cdr.from_currency
           AND to_currency = cdr.to_currency
           AND conversion_date = cdr.conversion_date
           AND conversion_rate = cdr.conversion_rate
           AND request_id = gv_request_id
           AND status = cdr.status;

      END LOOP;  

    END IF;

    COMMIT;

    IF ( v_duplicated != 0 ) THEN

      p_return := 'W';
      p_message := 'Some rates were not processed because they are duplicated with different rates.';

    ELSE

      p_return := 'S';

    END IF;

    print_log ('AJC_BC_J_EXCHANGE_RATES_PKG.create_daily_rates_p (-)');

  EXCEPTION
    WHEN OTHERS THEN
      p_return := 'E';
      p_message := 'AJC_BC_J_EXCHANGE_RATES_PKG.create_daily_rates_p (!). Error: ' || SQLERRM;
      print_log ( p_message );

  END create_daily_rates_p;

  PROCEDURE create_translation_rates_p ( p_return    OUT   VARCHAR2, 
                                         p_message   OUT   VARCHAR2 ) IS

      CURSOR c_companies IS
      SELECT c.currency,
             sob.name,
             sob.set_of_books_id,
             p.period_name,
             p.end_date
        FROM ajc_bc_companies c,
             gl_sets_of_books sob,
             gl_periods p
       WHERE c.currency != 'USD'
         AND sob.set_of_books_id = c.set_of_books_id
         AND sob.period_set_name = p.period_set_name
         -- AND p.period_set_name = 'AJC CALENDAR'
         AND gv_date = p.end_date
    ORDER BY sob.set_of_books_id;

    v_eop_rate   gl_daily_rates.conversion_rate%TYPE;

  BEGIN

    print_log ('AJC_BC_J_EXCHANGE_RATES_PKG.create_translation_rates_p (+)');

    FOR cc IN c_companies LOOP

      BEGIN

        print_log ( 'Set of books: ' || cc.name || ' (' || cc.set_of_books_id || 
                    ') | Currency: ' || cc.currency || 
                    ' | Period Name: ' || cc.period_name || 
                    ' | End Date: ' || cc.end_date );

        v_eop_rate := NULL;

        -- Se obtiene el end of period rate para el periodo
        SELECT conversion_rate
          INTO v_eop_rate
          FROM gl_daily_rates dr
         WHERE dr.from_currency = cc.currency
           AND dr.to_currency = 'USD'
           AND dr.conversion_date = cc.end_date;

        print_log ( 'End of period rate: ' || v_eop_rate );

        -- Se copiaron todos los registros de gl_translation_rates a esta tabla
        DELETE ajc_bc_gl_translation_rates
         WHERE set_of_books_id = cc.set_of_books_id
           AND period_name = cc.period_name
           AND to_currency_code = 'USD';

        print_log ( 'Se borran registros con mismo set of books id y period name de la tabla ajc_bc_gl_translation_rates.' );

          INSERT
            INTO AJC_BC_GL_TRANSLATION_RATES
               ( set_of_books_id,
                 period_name,
                 to_currency_code,
                 avg_rate,
                 eop_rate,
                 update_flag,
                 last_update_date,
                 last_updated_by,
                 creation_date,
                 created_by,
                 last_update_login,
                 actual_flag,
                 eop_rate_numerator,
                 eop_rate_denominator,
                 avg_rate_numerator,
                 avg_rate_denominator )
        VALUES ( cc.set_of_books_id,
                 cc.period_name,
                 'USD',
                 1, -- avg_rate,
                 v_eop_rate,
                 'N', -- update_flag
                 SYSDATE, -- last_update_date
                 gv_user_id, -- last_updated_by
                 SYSDATE, -- creation_date
                 gv_user_id, -- created_by
                 gv_user_id, -- last_update_login
                 'A', -- actual_flag
                 v_eop_rate, -- eop_rate_numerator
                 1, -- eop_rate_denominator
                 1, -- avg_rate_numerator
                 1 ); -- avg_rate_denominator                 

      EXCEPTION
        WHEN OTHERS THEN
          print_log ('Error: ' || SQLERRM);

      END;

    END LOOP;

    COMMIT;

    p_return := 'S';

    print_log ('AJC_BC_J_EXCHANGE_RATES_PKG.create_translation_rates_p (-)');

  EXCEPTION
    WHEN OTHERS THEN
      p_return := 'E';
      p_message := 'Error general create_translation_rates_p: ' || SQLERRM;

  END create_translation_rates_p;

  PROCEDURE final_report_csv_p ( p_status   OUT   VARCHAR2 ) IS

      CURSOR c_daily_rates IS
      SELECT from_currency,
             to_currency,
             REPLACE(SUBSTR(conversion_date,1,19),'T',' ') conversion_date,
             REPLACE(REPLACE(REPLACE(TRIM(TO_CHAR(conversion_rate,'999,990.0000000000')),',','C'),'.',','),'C','.') conversion_rate,
             status
        FROM ajc_bc_gl_daily_rates
       WHERE request_id = gv_request_id
         AND status = 'IMPORTED'
    GROUP BY from_currency,
             to_currency,
             conversion_date,
             conversion_rate,
             status
    ORDER BY from_currency, 
             to_currency;

      CURSOR c_not_processed IS
      SELECT bc_company company,
             from_currency,
             to_currency,
             REPLACE(SUBSTR(conversion_date,1,19),'T',' ') conversion_date,
             REPLACE(REPLACE(REPLACE(TRIM(TO_CHAR(conversion_rate,'999,990.0000000000')),',','C'),'.',','),'C','.') conversion_rate,
             status,
             message
        FROM ajc_bc_gl_daily_rates
       WHERE request_id = gv_request_id
         AND status != 'IMPORTED'
    ORDER BY DECODE(status,'SKIPPED',1,'DUPLICATED',2,3),
             from_currency, 
             to_currency;

  BEGIN

    print_log( 'AJC_BC_J_EXCHANGE_RATES_PKG.final_report_csv_p (+)' );

    -- Insert Report Title
    AJC_BC_J_UTILS_PKG.insert_report_p ( p_ifc => gv_bc_ifc,
                                         p_text => gv_bc_ifc || ' Report',
                                         p_request_id => gv_request_id );

    -- Fila vacia
    AJC_BC_J_UTILS_PKG.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );

    -- Tabla 1 -----------------------------------------------------------------------------------------------------------------                                    
    -- Insert Table Title
    AJC_BC_J_UTILS_PKG.insert_report_p ( p_ifc => gv_bc_ifc,
                                         p_text => 'Rates Processed',
                                         p_request_id => gv_request_id );

    -- Fila vacia
    AJC_BC_J_UTILS_PKG.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );

    -- Insert Table Column Names                            
    AJC_BC_J_UTILS_PKG.insert_report_p ( p_ifc => gv_bc_ifc,
                                         p_text => 'From Currency' || '|' ||
                                                   'To Currency' || '|' ||
                                                   'Conversion Date' || '|' ||
                                                   'Conversion Rate' || '|' ||
                                                   'Status',
                                         p_request_id => gv_request_id );                                        

    -- Se insertan los registros
    FOR cdr IN c_daily_rates LOOP

      AJC_BC_J_UTILS_PKG.insert_report_p ( p_ifc => gv_bc_ifc,
                                           p_text => cdr.from_currency || '|' || 
                                                     cdr.to_currency || '|' || 
                                                     cdr.conversion_date || '|' || 
                                                     cdr.conversion_rate || '|' || 
                                                     cdr.status,
                                           p_request_id => gv_request_id );     

    END LOOP;

    -- Tabla 2 -----------------------------------------------------------------------------------------------------------------
    -- Fila vacia
    AJC_BC_J_UTILS_PKG.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );

    -- Insert Table Title
    AJC_BC_J_UTILS_PKG.insert_report_p ( p_ifc => gv_bc_ifc,
                                         p_text => 'Rates NOT Processed',
                                         p_request_id => gv_request_id );

    -- Fila vacia
    AJC_BC_J_UTILS_PKG.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );

    -- Insert Table Column Names                            
    AJC_BC_J_UTILS_PKG.insert_report_p ( p_ifc => gv_bc_ifc,
                                         p_text => 'Company' || '|' ||
                                                   'From Currency' || '|' ||
                                                   'To Currency' || '|' ||
                                                   'Conversion Date' || '|' ||
                                                   'Conversion Rate' || '|' ||
                                                   'Status' || '|' ||
                                                   'Message',
                                         p_request_id => gv_request_id );  

    -- Se insertan los registros
    FOR cnp IN c_not_processed LOOP

      AJC_BC_J_UTILS_PKG.insert_report_p ( p_ifc => gv_bc_ifc,
                                           p_text => cnp.company || '|' || 
                                                     cnp.from_currency || '|' || 
                                                     cnp.to_currency || '|' || 
                                                     cnp.conversion_date || '|' || 
                                                     cnp.conversion_rate || '|' || 
                                                     cnp.status || '|' || 
                                                     cnp.message,
                                           p_request_id => gv_request_id );  

    END LOOP;

    p_status := 'S';

    print_log( 'AJC_BC_J_EXCHANGE_RATES_PKG.final_report_csv_p (-)' );

  EXCEPTION
    WHEN OTHERS THEN
      p_status := 'E';
      print_log( 'AJC_BC_J_EXCHANGE_RATES_PKG.final_report_csv_p (!). Error: ' || SQLERRM );

  END final_report_csv_p;

  PROCEDURE final_report_xlsx_p ( p_status   OUT   VARCHAR2 ) IS

    c_cursor   SYS_REFCURSOR;

  BEGIN

    print_log( 'AJC_BC_J_EXCHANGE_RATES_PKG.final_report_xlsx_p (+)' );

    gv_directory_report := AJC_BC_J_WS_UTILS_PKG.get_parameter_f ( p_parameter_code => 'AJC_DIRECTORY_REPORT' );

    AJC_BC_J_UTILS_PKG.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc || ' Report',
                                                 p_request_id => gv_request_id,
                                                 p_bc_environment => gv_bc_environment,
                                                 p_jenkins_build_number => gv_jenkins_build_number );

    -- DAILY RATES
        OPEN c_cursor FOR
      SELECT from_currency,
             to_currency,
             REPLACE(SUBSTR(conversion_date,1,19),'T',' ') conversion_date,
             REPLACE(REPLACE(REPLACE(TRIM(TO_CHAR(conversion_rate,'999,990.0000000000')),',','C'),'.',','),'C','.') conversion_rate,
             status
        FROM ajc_bc_gl_daily_rates
       WHERE request_id = gv_request_id
         AND status = 'IMPORTED'
    GROUP BY from_currency,
             to_currency,
             conversion_date,
             conversion_rate,
             status
    ORDER BY from_currency, 
             to_currency;

    AJC_BC_J_UTILS_PKG.create_sheet_p ( p_sheet_title => 'Rates Processed',
                                        p_sheet => 2,
                                        p_cursor => c_cursor );

    -- NOT PROCESSED                      
        OPEN c_cursor FOR
      SELECT bc_company company,
             from_currency,
             to_currency,
             REPLACE(SUBSTR(conversion_date,1,19),'T',' ') conversion_date,
             REPLACE(REPLACE(REPLACE(TRIM(TO_CHAR(conversion_rate,'999,990.0000000000')),',','C'),'.',','),'C','.') conversion_rate,
             status,
             message
        FROM ajc_bc_gl_daily_rates
       WHERE request_id = gv_request_id
         AND status != 'IMPORTED'
    ORDER BY DECODE(status,'SKIPPED',1,'DUPLICATED',2,3),
             from_currency, 
             to_currency;                          

    AJC_BC_J_UTILS_PKG.create_sheet_p ( p_sheet_title => 'Rates NOT Processed',
                                        p_sheet => 3,
                                        p_cursor => c_cursor );

    as_xlsx.save ( gv_directory_report, gv_report_filename || '.' || LOWER(gv_file_format) );

    p_status := 'S';

    print_log( 'AJC_BC_J_EXCHANGE_RATES_PKG.final_report_xlsx_p (-)' );

  EXCEPTION
    WHEN OTHERS THEN
      p_status := 'E';
      print_log( 'AJC_BC_J_EXCHANGE_RATES_PKG.final_report_xlsx_p (!). Error: ' || SQLERRM );

  END final_report_xlsx_p;

  PROCEDURE main_p ( p_bc_environment         IN   VARCHAR2,
                     p_date                   IN   VARCHAR2,
                     p_jenkins_build_number   IN   VARCHAR2 ) IS                      

    v_count              NUMBER;

    v_return             VARCHAR2(1);
    v_return_dr          VARCHAR2(1);
    v_message            VARCHAR2(2000);
    v_message_dr         VARCHAR2(2000);

    v_error_message      VARCHAR2(200);
    v_phase              VARCHAR2(100);
    v_status             VARCHAR2(200);

    e_parameter_value    EXCEPTION;
    e_daily_rates        EXCEPTION;

    e_no_rates           EXCEPTION;
    e_warning            EXCEPTION;
    e_error              EXCEPTION;

  BEGIN

    gv_request_id := AJC_BC_J_UTILS_PKG.get_request_id_f;
    gv_jenkins_build_number := p_jenkins_build_number;

    -- Se inserta el concurrent_job
    AJC_BC_J_UTILS_PKG.ins_jenkins_concurrent_job_p ( p_request_id => gv_request_id,
                                                      p_job_name => gv_bc_ifc,
                                                      p_jenkins_build_number => p_jenkins_build_number,
                                                      p_argument1 => p_bc_environment,
                                                      p_argument2 => p_date );

    print_log ( 'AJC_BC_J_EXCHANGE_RATES_PKG.main_p (+)' );
    print_log ( 'gv_request_id: ' || gv_request_id );
    print_log ( 'gv_jenkins_build_number: ' || gv_jenkins_build_number );

    gv_file_format := AJC_BC_J_WS_UTILS_PKG.get_parameter_f ( 'FILE_FORMAT' );
    print_log( 'FILE_FORMAT: ' || gv_file_format ); 

    -- Validacion parametro p_bc_environment -----------------------------------------------------------------------------------
    IF ( AJC_BC_J_UTILS_PKG.is_bc_environment_valid_f ( p_bc_environment ) = 'N' ) THEN

      v_error_message := 'Invalid value (' || p_bc_environment || ') for parameter BC_ENVIRONMENT.';
      RAISE e_parameter_value;

    END IF;

    gv_bc_environment := p_bc_environment;
    print_log ( 'gv_bc_environment: ' || gv_bc_environment );

    -- Validacion parametro p_date --------------------------------------------------------------------------------------------
    -- Validacion para cuando el parametro en jenkins es tipo date y llega como varchar2
    IF ( p_date IS NULL ) THEN 

      gv_date := SYSDATE + 1;

    ELSE

      BEGIN

        gv_date := TO_DATE(p_date,'YYYY-MM-DD');

      EXCEPTION
        WHEN OTHERS THEN
          v_error_message := 'Error: ' || SUBSTR(SQLERRM,INSTR(SQLERRM,':') + 2) || ' (' || p_date || ')';
          RAISE e_parameter_value;

      END;

    END IF;

    print_log ( 'gv_date: ' || gv_date );

    gv_email := AJC_BC_J_UTILS_PKG.get_emails_f ( 'EXCHANGE RATES' );
    print_log ( 'gv_email: ' || gv_email );

    get_daily_rates_p ( p_return => v_return, 
                        p_message => v_message,
                        p_count => v_count );

    IF ( v_return != 'S' ) THEN

      RAISE e_error;

    ELSIF ( v_count = 0 ) THEN

      RAISE e_no_rates;

    END IF;

    create_daily_rates_p ( p_return => v_return_dr, 
                           p_message => v_message_dr );

    -- INSERT REPORT IN TABLE AJC_BC_REPORTS --------------------------------------------------------------------------------
    IF ( gv_file_format = 'CSV' ) THEN

      final_report_csv_p ( p_status => v_status );     

      IF ( v_status != 'S' ) THEN

        v_phase := 'final_report_csv_p';
        RAISE e_daily_rates;

      END IF;  

      -- CREATE CSV FROM TABLE AJC_BC_REPORTS --------------------------------------------------------------------------------
      AJC_BC_J_UTILS_PKG.create_csv_p ( p_ifc => gv_bc_ifc,
                                        p_request_id => gv_request_id,
                                        p_log_seq => gv_log_seq,
                                        p_type => 'REPORT',
                                        p_filename => gv_report_filename,
                                        p_status => v_status );

      IF ( v_status != 'S' ) THEN

        v_phase := 'create_csv_p | REPORT';
        RAISE e_daily_rates;

      END IF;

    ELSIF ( gv_file_format = 'XLSX' ) THEN 

      -- No inserta en tabla, genera el xlsx directamente en el filesystem
      final_report_xlsx_p ( p_status => v_status );     

      IF ( v_status != 'S' ) THEN

        v_phase := 'final_report_xlsx_p';
        RAISE e_daily_rates;

      END IF;  

    END IF;

    -- MAIL REPORT -----------------------------------------------------------------------------------------------------------
    AJC_BC_J_UTILS_PKG.send_mail_with_attach ( p_to_mail => gv_email,
                                               p_subject => gv_bc_ifc || ' Report - ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',
                                               p_body => gv_bc_ifc || ' Report.',
                                               p_type => 'REPORT',
                                               p_filename => gv_report_filename, 
                                               p_file_format => gv_file_format, 
                                               p_attach_filename => gv_bc_ifc || ' Report ' || TO_CHAR(SYSDATE,'MMDDYYYY HH24MISS') || ' ' || gv_bc_environment || '.' || LOWER(gv_file_format) );   

    COMMIT;

    create_translation_rates_p ( p_return => v_return, 
                                 p_message => v_message );

    IF ( v_return != 'S' ) THEN

      RAISE e_error;

    END IF;

    COMMIT;

    -- Se verifica si daily rates dio warning o error
    IF ( v_return_dr = 'W' ) THEN

      v_message := v_message_dr;
      RAISE e_warning;

    ELSIF ( v_return_dr = 'E' ) THEN

      v_message := v_message_dr;
      RAISE e_error;

    END IF;

    -- Se actualiza el concurrent_job
    AJC_BC_J_UTILS_PKG.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'S' );

    print_log ('AJC_BC_J_EXCHANGE_RATES_PKG.main_p (-)');

  EXCEPTION
    WHEN e_parameter_value THEN

      AJC_BC_J_UTILS_PKG.send_email_p ( p_to => gv_email,
                                        p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',
                                        p_message => v_error_message );

      -- Se actualiza el concurrent_job
      AJC_BC_J_UTILS_PKG.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );

      RAISE_APPLICATION_ERROR(-20000, v_error_message );

    WHEN e_no_rates THEN

      AJC_BC_J_UTILS_PKG.send_email_p ( p_to => gv_email,
                                        p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',
                                        p_message => 'No rates for sync from BC ' || gv_bc_environment || ' to Oracle for date ' || gv_date );

      -- Se actualiza el concurrent_job
      AJC_BC_J_UTILS_PKG.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );

      RAISE_APPLICATION_ERROR(-20000,'No rates for sync.' );    

    WHEN e_warning THEN

      AJC_BC_J_UTILS_PKG.send_email_p ( p_to => gv_email,
                                        p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - WARNING - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',
                                        p_message => v_message || CHR(10) || 'Request ID: ' || gv_request_id );

      print_log ( v_message );

      -- Se actualiza el concurrent_job
      AJC_BC_J_UTILS_PKG.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'W' );

      RAISE_APPLICATION_ERROR(-20000,'Warning: ' || v_message );    

    WHEN e_error THEN

      AJC_BC_J_UTILS_PKG.send_email_p ( p_to => gv_email,
                                        p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - WARNING - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',
                                        p_message => v_message || CHR(10) || 'Request ID: ' || gv_request_id );

      print_log ( v_message );

      -- Se actualiza el concurrent_job
      AJC_BC_J_UTILS_PKG.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );

      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_message );     

    WHEN OTHERS THEN

      AJC_BC_J_UTILS_PKG.send
