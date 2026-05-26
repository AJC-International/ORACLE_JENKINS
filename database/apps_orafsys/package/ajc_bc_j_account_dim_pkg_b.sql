PACKAGE BODY AJC_BC_J_ACCOUNT_DIM_PKG AS

  gv_api_records_limit   NUMBER := 20000;

  PROCEDURE main_p ( p_bc_environment   IN   VARCHAR2,
                     p_request_id       IN   NUMBER  ) IS

    v_error_message     VARCHAR2(200);

    v_url               VARCHAR2(2000);
    v_api               VARCHAR2(100);
    v_clob_result       CLOB;

    v_record_count      NUMBER;
    v_iteraciones       NUMBER;
    v_skip              NUMBER := 0;
    v_url_page          VARCHAR2(2000);

    CURSOR c_dimensions ( p_clob_result   IN   CLOB ) IS
    SELECT gl_account,
           dimension_code,
           dimension_value_code,
           value_posting,
           allowed_values_filters,
           table_id,
           TRUNC(SYSDATE) creation_date
    FROM json_table( v_clob_result,
                     '$.value[*]' COLUMNS ( gl_account               VARCHAR2(4000)  path '$.No',
                                            dimension_code           VARCHAR2(4000)  path '$.Dimension_Code',
                                            dimension_value_code     VARCHAR2(4000)  path '$.Dimension_Value_Code',
                                            value_posting            VARCHAR2(4000)  path '$.Value_Posting',
                                            allowed_values_filters   VARCHAR2(4000)  path '$.AllowedValuesFilter',
                                            table_id                 VARCHAR2(4000)  path '$.Table_ID' ) );

    -- Lock & Release
    v_process_name         VARCHAR2(200) := 'AJC BC GET ACCOUNTS DEFAULT DIMENSIONS';

    v_request_status       VARCHAR2(200);
    v_id_lock              VARCHAR2(200);
    e_lock                 EXCEPTION;

    v_release_status       VARCHAR2(200);
    e_release              EXCEPTION;   
    -- Lock & Release

  BEGIN

    -- Lock & Release
    ajc_bc_dbms_lock_pkg.lock_p ( p_process_name => v_process_name,
                                  p_id_lock => v_id_lock,
                                  p_request_status => v_request_status ); 

    IF ( v_request_status != 'success' ) THEN

      RAISE e_lock;

    END IF;
    -- Lock & Release

    -- Se borran todos los valores
    DELETE ajc_bc_account_dimensions;
    COMMIT;

    v_api := AJC_BC_J_WS_UTILS_PKG.get_api_f ( p_entity => 'CHART OF ACCOUNTS',
                                             p_subentity => NULL,
                                             p_method => 'GET' ); 

    v_url := AJC_BC_J_WS_UTILS_PKG.get_base_ajc_url_f ( p_bc_environment, gv_company_name ) || v_api;

    v_record_count := TO_NUMBER( regexp_replace(
                        TO_CHAR ( AJC_BC_J_WS_UTILS_PKG.get_bc_clob_result_f ( p_url => v_url || '/$count' ) )
                      , '[^0-9]', '') );

    v_iteraciones := CEIL(v_record_count / gv_api_records_limit);

    FOR i IN 1..v_iteraciones LOOP

      -- Se arma la url para paginado
      v_url_page := v_url || '?$top=' || gv_api_records_limit || '&$skip=' || v_skip;

      -- Se obtienen los registros de a 20000
      v_clob_result := AJC_BC_J_WS_UTILS_PKG.get_bc_clob_result_f ( p_url => v_url_page ); 

      -- Se calcula la cantidad de registros a omitir en la siguiente iteracion
      v_skip := v_skip + gv_api_records_limit;

      FOR cdim IN c_dimensions ( p_clob_result => v_clob_result ) LOOP

        -- Solo se insertan los registros correspondientes a G/L Account
        IF ( cdim.table_id = 15 ) THEN

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
                   p_request_id,
                   cdim.creation_date );

        END IF;    

      END LOOP;  

    END LOOP;

    COMMIT;

    -- dbms_lock - Release -------------------------------------------------------------------------------------------------
    ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,
                                     p_release_status => v_release_status );

    IF ( v_release_status != 'success' ) THEN

      RAISE e_release;

    END IF;                                     
    -- dbms_lock - Release -------------------------------------------------------------------------------------------------

  EXCEPTION
    -- Lock & Release
    WHEN e_lock THEN
      RAISE_APPLICATION_ERROR(-20000, 'Error trying to lock the process: ' || v_process_name || ' | v_request_status: ' || v_request_status);

    WHEN e_release THEN
      RAISE_APPLICATION_ERROR(-20000, 'Error trying to release the process: ' || v_process_name || ' | v_release_status: ' || v_release_status);
    -- Lock & Release

    WHEN OTHERS THEN
      -- Lock & Release
      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,
                                       p_release_status => v_release_status );

      IF ( v_release_status != 'success' ) THEN

        RAISE e_release;

      END IF;      

      RAISE_APPLICATION_ERROR(-20000, 'General error: ' || SQLERRM );
      -- Lock & Release

  END main_p;

  FUNCTION account_dim_required ( p_account     IN   VARCHAR2,
                                  p_dimension   IN   VARCHAR2,
                                  p_value       IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_value_posting   VARCHAR2(100);

  BEGIN

    SELECT value_posting
      INTO v_value_posting
      FROM ajc_bc_account_dimensions
     WHERE gl_account = p_account
       AND dimension_code = p_dimension;

    IF ( v_value_posting = 'Code Mandatory' ) THEN

      RETURN p_value;

    ELSIF ( v_value_posting = 'No Code' ) THEN

      RETURN '';

    -- Cuando el registro existe pero sin valor, se debe seguir la misma logica que cuando el registro no existe
    ELSIF ( v_value_posting = ' ' ) THEN

      IF ( p_dimension = 'OFFICE' ) THEN

        RETURN p_value;  

      ELSE -- No es OFFICE

        IF ( p_value IN ('000','00') ) THEN

          RETURN '';

        ELSE

          RETURN p_value;  

        END IF;

      END IF;

    END IF;

    RETURN '';

  EXCEPTION
    WHEN NO_DATA_FOUND THEN

      IF ( p_dimension = 'OFFICE' ) THEN

        RETURN p_value;  

      ELSE -- No es OFFICE

        IF ( p_value IN ('000','00') ) THEN

          RETURN '';

        ELSE

          RETURN p_value;  

        END IF;

      END IF;

    WHEN OTHERS THEN
      NULL;

  END account_dim_required;

END AJC_BC_J_ACCOUNT_DIM_PKG;
