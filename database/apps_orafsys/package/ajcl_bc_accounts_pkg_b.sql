PACKAGE BODY ajcl_bc_accounts_pkg AS
-- Creation: SBANCHIERI 23-AUG-2023
  
  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    dbms_output.put_line(p_message);

  END print_log;

  PROCEDURE main_p ( p_bc_environment   IN   VARCHAR2 ) IS

    v_get_url        VARCHAR2(2000);
    v_clob_result    CLOB;
    v_record_count   NUMBER := 0;

    CURSOR c_account_dim_req ( p_clob_result   IN   CLOB ) IS
    SELECT gl_account,
           dimension_code,
           dimension_value_code,
           value_posting
    FROM json_table( p_clob_result,
                     '$.value[*]' COLUMNS ( gl_account               VARCHAR2(4000)  path '$.no',
                                            dimension_code           VARCHAR2(4000)  path '$.dimensionCode',
                                            dimension_value_code     VARCHAR2(4000)  path '$.dimensionValueCode',
                                            value_posting            VARCHAR2(4000)  path '$.valuePosting' ) );

    -- Lock & Release
    v_process_name         VARCHAR2(200) := 'AJCL BC GET ACCOUNTS DEFAULT DIMENSIONS';

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

    print_log ('ajcl_bc_accounts_pkg.main_p (+)');

    -- Se borran todos los valores para el environment
    DELETE ajcl_bc_account_dimensions WHERE bc_environment = p_bc_environment;
    COMMIT;

    print_log ( 'Table ajcl_bc_account_dimensions deleted for bc_environment ' || p_bc_environment);

    --
    gv_bc_company_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,
                                                                     p_column => 'BC_COMPANY_ID' );
    -- comentar la linea de arriba y descomentar la linea de abajo para usar en PROD antes del Go Live
    -- gv_bc_company_id := '6f83219b-6dc5-ec11-8e7e-0022482b52d9';

    print_log ( 'gv_bc_company_id: ' || gv_bc_company_id );

    v_get_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,
                                                              p_entity => 'ACCOUNTS DEFAULT DIMENSIONS',
                                                              p_subentity => NULL,
                                                              p_method => 'GET',
                                                              p_company_id => gv_bc_company_id );

    print_log ( 'v_get_url: ' || v_get_url );

    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );

    FOR cadr IN c_account_dim_req ( p_clob_result => v_clob_result ) LOOP 

      v_record_count := v_record_count + 1;

        INSERT 
          INTO ajcl_bc_account_dimensions 
             ( bc_environment,
               gl_account,
               dimension_code,
               dimension_value_code,
               value_posting,
               creation_date )
      VALUES ( p_bc_environment,
               cadr.gl_account,
               cadr.dimension_code,
               cadr.dimension_value_code,
               cadr.value_posting,
               TRUNC(SYSDATE) );

    END LOOP;

    COMMIT;

    print_log ('v_record_count: ' || v_record_count );

    -- Lock & Release
    ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,
                                     p_release_status => v_release_status );

    IF ( v_release_status != 'success' ) THEN

      RAISE e_release;

    END IF;                                     
    -- Lock & Release

    print_log ('ajcl_bc_accounts_pkg.main_p (-)');

  EXCEPTION
    WHEN OTHERS THEN
      print_log ('ajcl_bc_accounts_pkg.main_p (!). Error: ' || SQLERRM);
      -- Lock & Release
      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,
                                       p_release_status => v_release_status );

      IF ( v_release_status != 'success' ) THEN

        RAISE e_release;

      END IF;                                     
      -- Lock & Release

  END main_p;

  FUNCTION account_dim_required ( p_bc_environment   IN   VARCHAR2,
                                  p_account          IN   VARCHAR2,
                                  p_dimension        IN   VARCHAR2,
                                  p_value            IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_value_posting   VARCHAR2(100);

  BEGIN

    SELECT value_posting
      INTO v_value_posting
      FROM ajcl_bc_account_dimensions
     WHERE bc_environment = p_bc_environment
       AND gl_account = p_account
       AND dimension_code = p_dimension;

    IF ( v_value_posting = 'Code Mandatory' ) THEN

      RETURN p_value;

    ELSIF ( v_value_posting = 'No Code' ) THEN

      RETURN '';

    -- Cuando el registro existe pero sin valor, se debe seguir la misma logica que cuando el registro no existe
    ELSIF ( v_value_posting = ' ' ) THEN

      IF ( p_dimension = 'OFFICE' ) THEN

        -- Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation
        --RETURN p_value;  
        IF ( p_value IN ('000','00') ) THEN

          RETURN '';

        ELSE

          RETURN p_value;     

        END IF;              
        -- End Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

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

        -- Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation
        --RETURN p_value;  
        IF ( p_value IN ('000','00') ) THEN

          RETURN '';

        ELSE

          RETURN p_value; 

        END IF;          
        -- End Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

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

  FUNCTION get_dimension_value ( p_oracle_segment   IN   VARCHAR2,
                                 p_oracle_value     IN   VARCHAR2,
                                 p_bc_dimension     IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_bc_value   VARCHAR2(20);

  BEGIN

    SELECT bc_value
      INTO v_bc_value
      -- Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation
      --FROM ajc_bc_gl_mapping
      FROM ajcl_bc_gl_mapping
      -- End Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation
     WHERE oracle_segment = p_oracle_segment
       AND oracle_value = p_oracle_value
       AND bc_dimension = p_bc_dimension
       AND NVL(active,'N') = 'Y';

    RETURN v_bc_value;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;

    WHEN OTHERS THEN
      print_log('p_oracle_segment:'||p_oracle_segment);
      print_log('p_oracle_value:'||p_oracle_value);
      print_log('p_bc_dimension:'||p_bc_dimension);
      print_log('ajcl_bc_accounts_pkg.get_dimension_value(!)');
      print_log('ajcl_bc_accounts_pkg.get_dimension_value Error:'||sqlerrm);
      RETURN NULL;

  END get_dimension_value;

END ajcl_bc_accounts_pkg;
