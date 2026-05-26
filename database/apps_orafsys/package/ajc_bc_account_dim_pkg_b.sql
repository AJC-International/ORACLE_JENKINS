PACKAGE BODY ajc_bc_account_dim_pkg AS
-- -------------------------------------------------------------------------- --
-- SBANCHIERI JUL-23
-- -------------------------------------------------------------------------- --
  
  -- 20250703
  gv_api_records_limit   NUMBER := 20000;
  -- 20250703

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line (fnd_file.log, p_message);

  END print_log;

  -- 20250703
  /*
  PROCEDURE main_p ( retcode            OUT   NUMBER,
                     errbuf             OUT   VARCHAR2,
                     p_bc_environment    IN   VARCHAR2 ) IS

    v_get_url       VARCHAR2(2000);
    -- v_get_api       VARCHAR2(100) := 'DefaultDimensionKHRONUS'; -- Creado por Juanpi
    v_get_api       VARCHAR2(100);
    v_clob_result   CLOB;

  BEGIN

    print_log ('ajc_bc_account_dim_pkg.main_p (+)');

    -- Se borran todos los valores
    DELETE ajc_bc_account_dimensions;
    COMMIT;

    print_log ( 'Table ajc_bc_account_dimensions deleted.' );

    v_get_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'CHART OF ACCOUNTS',
                                                 p_subentity => NULL,
                                                 p_method => 'GET' ); 
    print_log ( 'v_get_api: ' || v_get_api );

    v_get_url := ajc_bc_ws_utils_pkg.get_base_ajc_url_f ( p_bc_environment, gv_company_name ) || v_get_api; -- Asi se llama al ws que cree yo
    -- v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, gv_company_id ) || v_get_api; -- Asi se tiene que llamar al ws que cree inecta

    print_log ( 'Get URL: ' || v_get_url );

    v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );

    INSERT 
      INTO ajc_bc_account_dimensions 
         ( gl_account,
           dimension_code,
           dimension_value_code,
           value_posting,
           allowed_values_filters,
           request_id,
           creation_date )
    SELECT gl_account,
           dimension_code,
           dimension_value_code,
           value_posting,
           allowed_values_filters,
           --
           gv_request_id,
           TRUNC(SYSDATE) creation_date
    FROM json_table( v_clob_result,
                     '$.value[*]' COLUMNS ( gl_account               VARCHAR2(4000)  path '$.No',
                                            dimension_code           VARCHAR2(4000)  path '$.Dimension_Code',
                                            dimension_value_code     VARCHAR2(4000)  path '$.Dimension_Value_Code',
                                            value_posting            VARCHAR2(4000)  path '$.Value_Posting',
                                            allowed_values_filters   VARCHAR2(4000)  path '$.AllowedValuesFilter' ) );

    COMMIT;

    print_log ('ajc_bc_account_dim_pkg.main_p (-)');

  END main_p;
  */
  -- 20250703

  PROCEDURE main_p ( retcode            OUT   NUMBER,
                     errbuf             OUT   VARCHAR2,
                     p_bc_environment    IN   VARCHAR2 ) IS

    v_url            VARCHAR2(2000);
    v_api            VARCHAR2(100);
    v_clob_result    CLOB;

    v_record_count   NUMBER;
    v_iteraciones    NUMBER;
    v_skip           NUMBER := 0;
    v_url_page       VARCHAR2(2000);

    v_insert_count   NUMBER := 0;

    CURSOR c_dimensions ( p_clob_result   IN   CLOB ) IS
    SELECT gl_account,
           dimension_code,
           dimension_value_code,
           value_posting,
           allowed_values_filters,
           -- 20250703
           table_id,
           -- 20250703
           TRUNC(SYSDATE) creation_date
      FROM json_table( v_clob_result,
                       '$.value[*]' COLUMNS ( gl_account               VARCHAR2(4000)  path '$.No',
                                              dimension_code           VARCHAR2(4000)  path '$.Dimension_Code',
                                              dimension_value_code     VARCHAR2(4000)  path '$.Dimension_Value_Code',
                                              value_posting            VARCHAR2(4000)  path '$.Value_Posting',
                                              allowed_values_filters   VARCHAR2(4000)  path '$.AllowedValuesFilter'
                                             -- 20250703
                                             ,table_id                 VARCHAR2(4000)  path '$.Table_ID' 
                                             -- 20250703
                                             ) );

  BEGIN

    print_log ('ajc_bc_account_dim_pkg.main_p (+)');

    -- Se borran todos los valores
    DELETE ajc_bc_account_dimensions;
    COMMIT;

    print_log ( 'Table ajc_bc_account_dimensions deleted.' );

    v_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'CHART OF ACCOUNTS',
                                             p_subentity => NULL,
                                             p_method => 'GET' ); 
    print_log ( 'API: ' || v_api );

    v_url := ajc_bc_ws_utils_pkg.get_base_ajc_url_f ( p_bc_environment, gv_company_name ) || v_api;

    print_log ( 'URL: ' || v_url );

    v_record_count := TO_NUMBER( regexp_replace(
                        TO_CHAR ( ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url || '/$count' ) )
                      , '[^0-9]', '') );
    print_log ( 'Record Count: ' || v_record_count );

    v_iteraciones := CEIL(v_record_count / gv_api_records_limit);
    print_log ( 'Iteraciones: ' || v_iteraciones );

    FOR i IN 1..v_iteraciones LOOP

      -- Se arma la url para paginado
      v_url_page := v_url || '?$top=' || gv_api_records_limit || '&$skip=' || v_skip;
      print_log ( 'v_url_page: ' || v_url_page );

      -- Se obtienen los registros de a 20000
      v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url_page ); 

      -- Se calcula la cantidad de registros a omitir en la siguiente iteracion
      v_skip := v_skip + gv_api_records_limit;

      FOR cdim IN c_dimensions ( p_clob_result => v_clob_result ) LOOP

        -- 20250703
        -- Solo se insertan los registros correspondientes a G/L Account
        IF ( cdim.table_id = 15 ) THEN
        -- 20250703

            INSERT 
              INTO ajc_bc_account_dimensions 
                 ( gl_account,
                   dimension_code,
                   dimension_value_code,
                   value_posting,
                   allowed_values_filters,
                   request_id,
                   creation_date )
          VALUES ( cdim.gl_account,              
                   cdim.dimension_code,
                   cdim.dimension_value_code,
                   cdim.value_posting,
                   cdim.allowed_values_filters,
                   gv_request_id,
                   cdim.creation_date );

          v_insert_count := v_insert_count + 1;

        -- 20250703   
        END IF;    
        -- 20250703

      END LOOP;  

    END LOOP;

    print_log ('Registros insertados: ' || v_insert_count);

    COMMIT;

    print_log ('ajc_bc_account_dim_pkg.main_p (-)');

  EXCEPTION
    WHEN OTHERS THEN
      print_log ('ajc_bc_account_dim_pkg.main_p (!). Error: ' || SQLERRM);

  END main_p;

  FUNCTION account_dim_required ( p_account     IN   VARCHAR2,
                                  p_dimension   IN   VARCHAR2,
                                  p_value       IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_value_posting   VARCHAR2(100);

  BEGIN

    -- print_log ('ajc_bc_account_dim_pkg.account_dim_required (+)');

    SELECT value_posting
      INTO v_value_posting
      FROM ajc_bc_account_dimensions
     WHERE gl_account = p_account
       AND dimension_code = p_dimension;

    IF ( v_value_posting = 'Code Mandatory' ) THEN

      RETURN p_value;

    ELSIF ( v_value_posting = 'No Code' ) THEN

      RETURN '';

    -- 20230102
    /*
    ELSE

      RETURN '';
    */
    -- Cuando el registro existe pero sin valor, se debe seguir la misma logica que cuando el registro no existe
    ELSIF ( v_value_posting = ' ' ) THEN
    -- 20230102

      IF ( p_dimension = 'OFFICE' ) THEN

        RETURN p_value;  

      ELSE -- No es OFFICE

        -- 20230201 IF ( p_value = '000' ) THEN -- Intercompany tiene solo dos 0
        IF ( p_value IN ('000','00') ) THEN

          RETURN '';

        ELSE

          RETURN p_value;  

        END IF;

      END IF;

    END IF;

    -- print_log ('ajc_bc_account_dim_pkg.account_dim_required (-)');

    RETURN '';

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      -- print_log ('ajc_bc_account_dim_pkg.account_dim_required (!)');
      -- print_log ('Dimension ' || p_dimension || ' not found for account ' || p_account );

      IF ( p_dimension = 'OFFICE' ) THEN

        RETURN p_value;  

      ELSE -- No es OFFICE

        -- 20230201 IF ( p_value = '000' ) THEN -- Intercompany tiene solo dos 0
        IF ( p_value IN ('000','00') ) THEN

          RETURN '';

        ELSE

          RETURN p_value;  

        END IF;

      END IF;

    WHEN OTHERS THEN
      -- print_log ('ajc_bc_account_dim_pkg.account_dim_required (!). Error: ' || SQLERRM );
      NULL;

  END account_dim_required;

  PROCEDURE caller_p ( p_bc_environment   IN   VARCHAR2 ) IS

    v_request_id        NUMBER;
    v_message           VARCHAR2(2000);
    v_error_message     VARCHAR2(2000);
    e_cust_exception    EXCEPTION;
    v_conc_phase        VARCHAR2 (50);
    v_conc_status       VARCHAR2 (50);
    v_conc_dev_phase    VARCHAR2 (50);
    v_conc_dev_status   VARCHAR2 (50);
    v_conc_message      VARCHAR2 (250);

  BEGIN

    v_request_id := fnd_request.submit_request ( 'XXAJC',
                                                 'AJCBCCOAI',
                                                 argument1 => p_bc_environment ) ;

    IF v_request_id = 0 THEN

      v_message := fnd_message.get;
      print_log('Error Ejecutando FND_REQUEST.SUBMIT_REQUEST. AJCBCCOAI - AJC BC Chart Of Accounts Interface. Error: ' || v_message || ', ' || SQLERRM);
      RAISE e_cust_exception;

    END IF ;

    COMMIT;

    IF NOT fnd_concurrent.wait_for_request ( v_request_id,
                                             10,
                                             18000,
                                             v_conc_phase,
                                             v_conc_status,
                                             v_conc_dev_phase,
                                             v_conc_dev_status,
                                             v_conc_message) THEN
      v_message := fnd_message.get;
      print_log('Error Ejecutando FND_REQUEST.WAIT_FOR_REQUEST. AJCBCCOAI - AJC BC Chart Of Accounts Interface, con nro. solicitud ' || 
                 TO_CHAR (v_request_id) || '. Error: ' || v_message || ' ' || SQLERRM);
      RAISE e_cust_exception;

    END IF ;

    IF v_conc_dev_phase != 'COMPLETE' OR v_conc_dev_status != 'NORMAL' THEN

      v_error_message := fnd_message.get;
      print_log('Error en la ejecucion del concurrente AJCBCCOAI - AJC BC Chart Of Accounts Interface, con nro. solicitud ' || 
                 TO_CHAR (v_request_id) || '. Error: ' || v_error_message || ' ' || SQLERRM);
      RAISE e_cust_exception;

    END IF ;

  END caller_p;

END ajc_bc_account_dim_pkg;
