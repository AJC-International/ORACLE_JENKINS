PACKAGE BODY ajc_bc_create_entities_pkg IS
  
  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line (fnd_file.log, p_message);

  END print_log;

  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line(fnd_file.output,p_message);

  END print_output;

  FUNCTION create_ap_payment_term_f ( p_payment_terms    IN   VARCHAR2,
                                      p_company_id       IN   VARCHAR2,
                                      p_bc_environment   IN   VARCHAR2 ) RETURN NUMBER IS 

    v_rowid             VARCHAR2(200);
    v_term_id           NUMBER;

    v_get_url           VARCHAR2(2000);
    -- 20230414 v_get_api       VARCHAR2(100) := 'paymentTermsAJCINE';
    v_get_api           VARCHAR2(100);
    v_clob_result       CLOB;

    v_due_days          NUMBER;
    v_inactive          VARCHAR2(1);
    v_end_date_active   DATE;
    -- 20240202
    v_description       ap_terms.description%TYPE;
    -- 20240202

  BEGIN

    print_log ( 'ajc_bc_create_entities_pkg.create_ap_payment_term_f (+)' );
    print_log ( 'p_payment_terms: ' || p_payment_terms );
    print_log ( 'p_company_id: ' || p_company_id );

    -- Se obtienen el estado y los dias del termino de pago de BC
    v_get_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'PAYMENT TERMS',
                                                 p_subentity => NULL,
                                                 p_method => 'GET' );
    print_log ( 'v_get_api: ' || v_get_api );


    v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, p_company_id ) || v_get_api
                 || '?$filter=code eq ''' || p_payment_terms || ''''; 

    print_log ( 'v_get_url: ' || v_get_url );

    v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );

    SELECT NVL(regexp_replace(dueDateCalculation,'[^0-9]', ''),0),
           DECODE(inactive,'true','Y','N'),
           -- 20240202
           description
           -- 20240202
      INTO v_due_days,
           v_inactive,
           -- 20240202
           v_description
           -- 20240202
      FROM json_table( v_clob_result, '$.value[*]' COLUMNS ( dueDateCalculation   VARCHAR2(4000)  path '$.dueDateCalculation',
                                                             inactive             VARCHAR2(4000)  path '$.inactive',
                                                             -- 20240202
                                                             description          VARCHAR2(4000)  path '$.description'
                                                             -- 20240202
                                                             ) );

    print_log ( 'v_due_days: ' || v_due_days );
    print_log ( 'v_inactive: ' || v_inactive );
    -- 20240202
    print_log ( 'v_description: ' || v_description );
    -- 20240202

    IF ( v_inactive = 'Y' ) THEN

      v_end_date_active := SYSDATE;

    END IF;

    -- Se obtiene el term id
    SELECT ap_terms_s.NEXTVAL
      INTO v_term_id
      FROM DUAL;

    -- Se crea la cabecera del termino de pago  
    ap_terms_pkg.insert_row ( x_rowid => v_rowid,
                              x_term_id => v_term_id,
                              x_enabled_flag => 'Y',
                              x_due_cutoff_day	=> NULL,
                              x_type => 'STD',
                              x_start_date_active	=> SYSDATE - 1,
                              x_end_date_active	=> v_end_date_active,
                              x_rank => NULL,
                              x_attribute_category	=> NULL,
                              x_attribute1 => NULL,
                              x_attribute2 => NULL,
                              x_attribute3 => NULL,
                              x_attribute4 => NULL,
                              x_attribute5 => NULL,
                              x_attribute6 => NULL,
                              x_attribute7 => NULL,
                              x_attribute8 => NULL,
                              x_attribute9 => NULL,
                              x_attribute10 => NULL,
                              x_attribute11 => NULL,
                              x_attribute12 => NULL,
                              x_attribute13 => NULL,
                              x_attribute14 => NULL,
                              x_attribute15 => NULL,
                              x_name => p_payment_terms,
                              -- 20240202
                              -- x_description => INITCAP(p_payment_terms),
                              x_description => v_description,
                              -- 20240202
                              x_creation_date => SYSDATE,
                              x_created_by => gv_user_id,
                              x_last_update_date	=> SYSDATE,
                              x_last_updated_by	=> gv_user_id,
                              x_last_update_login	=> gv_user_id );

    -- Se crea la línea
    INSERT
      INTO ap_terms_lines
           ( term_id,
             due_percent,
             due_days,
             sequence_num,
             --
             last_update_date,
             last_updated_by,
             creation_date,
             created_by,
             last_update_login )
    VALUES ( v_term_id,
             100,
             v_due_days,
             1,
             --
             SYSDATE,
             gv_user_id,
             SYSDATE,
             gv_user_id,
             gv_user_id );

    -- Se inserta en la tabla de payment terms para que tambien guarde los payment term creados
    INSERT
      INTO ajc_bc_payment_terms
           ( code,
             dueDateCalculation,
             inactive,
             -- 20240202
             description,
             -- 20240202
             creation_date,
             processed_date,
             module,
             status )
    VALUES ( p_payment_terms,
             v_due_days,
             v_inactive,
             -- 20240202
             v_description,
             -- 20240202
             SYSDATE,
             SYSDATE,
             'AP',
             'CREATED' );

    -- 20250821 - USO TABLA AJC_BC_PAYMENT_TERMS_MAPPING
    -- Se inserta el registro en la tabla de mapeo
    INSERT 
      INTO AJC_BC_PAYMENT_TERMS_MAPPING 
           ( MODULE,
             TERM_ID,
             BC_CODE ) 
    VALUES ( 'AP',
             v_term_id,
             p_payment_terms );
    -- 20250821 - USO TABLA AJC_BC_PAYMENT_TERMS_MAPPING

    COMMIT;             

    print_log ( 'ajc_bc_create_entities_pkg.create_ap_payment_term_f (-)' );

    RETURN v_term_id;

  EXCEPTION  
    WHEN OTHERS THEN
      print_log ( 'ajc_bc_create_entities_pkg.create_ap_payment_term_f (!)' );
      RETURN NULL;

  END create_ap_payment_term_f;

  FUNCTION create_ar_payment_term_f ( p_payment_terms    IN   VARCHAR2,
                                      p_company_id       IN   VARCHAR2,
                                      p_bc_environment   IN   VARCHAR2 ) RETURN NUMBER IS 

    v_rowid                        VARCHAR2(200);
    v_term_id                      NUMBER;

    v_get_url                      VARCHAR2(2000);
    -- 20230414 v_get_api                      VARCHAR2(100) := 'paymentTermsAJCINE';
    v_get_api                      VARCHAR2(100);
    v_clob_result                  CLOB;

    v_type                         VARCHAR2(100);
    v_due_days                     NUMBER;
    v_account_statement_due_days   VARCHAR2(100);
    v_inactive                     VARCHAR2(1);
    v_end_date_active              DATE;

    -- 20240202
    v_description                  ra_terms.description%TYPE;
    -- 20240202

  BEGIN

    print_log ( 'ajc_bc_create_entities_pkg.create_ar_payment_term_f (+)' );
    print_log ( 'p_payment_terms: ' || p_payment_terms );
    print_log ( 'p_company_id: ' || p_company_id );

    -- Se obtienen los dias del termino de pago de BC y el type
    v_get_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'PAYMENT TERMS',
                                                 p_subentity => NULL,
                                                 p_method => 'GET' );
    print_log ( 'v_get_api: ' || v_get_api );

    v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, p_company_id ) || v_get_api 
                 || '?$filter=code eq ''' || p_payment_terms || ''''; 

    print_log ( 'v_get_url: ' || v_get_url );

    v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );

    SELECT type,
           NVL(regexp_replace(due_days,'[^0-9]', ''),0),
           account_statement_due_days,
           DECODE(inactive,'true','Y','N'),
           -- 20240202
           description
           -- 20240202
      INTO v_type,
           v_due_days,
           v_account_statement_due_days,
           v_inactive,
           -- 20240202
           v_description
           -- 20240202
      FROM json_table( v_clob_result, '$.value[*]' COLUMNS ( type                         VARCHAR2(4000)  path '$.type',
                                                             due_days                     VARCHAR2(4000)  path '$.dueDateCalculation',
                                                             account_statement_due_days   VARCHAR2(4000)  path '$.accStatemntDueDays',
                                                             inactive                     VARCHAR2(4000)  path '$.inactive',
                                                             -- 20240202
                                                             description                  VARCHAR2(4000)  path '$.description'
                                                             -- 20240202
                                                             ) );

    print_log ( 'v_type: ' || v_type );
    print_log ( 'v_due_days: ' || v_due_days );
    print_log ( 'v_account_statement_due_days: ' || v_account_statement_due_days );
    print_log ( 'v_inactive: ' || v_inactive );
    -- 20240202
    print_log ( 'v_description: ' || v_description );
    -- 20240202

    IF ( v_inactive = 'Y' ) THEN

      v_end_date_active := SYSDATE;

    END IF;

    -- Se obtiene el term id
    SELECT RA_TERMS_S.NEXTVAL
      INTO v_term_id
      FROM DUAL;

    -- Se crea la cabecera del termino de pago  
    ra_terms_table_handler.insert_row ( x_rowid => v_rowid,
                                        x_term_id => v_term_id,
                                        x_credit_check_flag => NULL,
                                        x_prepayment_flag => NULL,
                                        x_due_cutoff_day => NULL,
                                        x_printing_lead_days => NULL,
                                        x_start_date_active => SYSDATE - 1,
                                        x_end_date_active => v_end_date_active,
                                        x_attribute_category => NULL,
                                        x_attribute1 => v_type,
                                        x_attribute2 => NULL,
                                        x_attribute3 => NULL,
                                        x_attribute4 => NULL,
                                        x_attribute5 => NULL,
                                        x_attribute6 => NULL,
                                        x_attribute7 => NULL,
                                        x_attribute8 => NULL,
                                        x_attribute9 => NULL,
                                        x_attribute10 => NULL,
                                        x_base_amount => 100,
                                        x_calc_discount_on_lines_flag => 'I',
                                        x_first_installment_code => 'ALLOCATE',
                                        x_in_use => 'Y',
                                        x_partial_discount_flag => 'N',
                                        x_attribute11 => NULL,
                                        x_attribute12 => NULL,
                                        x_attribute13 => NULL,
                                        x_attribute14 => NULL,
                                        x_attribute15 => NULL,
                                        x_name => p_payment_terms,
                                        -- 20240202
                                        -- x_description => INITCAP(p_payment_terms),
                                        x_description => v_description,
                                        -- 20240202
                                        x_creation_date => SYSDATE,
                                        x_created_by => gv_user_id,
                                        x_last_update_date => SYSDATE,
                                        x_last_updated_by => gv_user_id,
                                        x_last_update_login => gv_user_id );

    -- Se crea la línea
    INSERT
      INTO ra_terms_lines
           ( term_id,
             sequence_num,
             relative_amount,
             due_days,
             attribute1,
             --
             last_update_date,
             last_updated_by,
             creation_date,
             created_by,
             last_update_login )
    VALUES ( v_term_id,
             1,
             100,
             v_due_days,
             v_account_statement_due_days,
             --
             SYSDATE,
             gv_user_id,
             SYSDATE,
             gv_user_id,
             gv_user_id );

    -- Se inserta en la tabla de payment terms para que tambien guarde los payment term creados
    INSERT
      INTO ajc_bc_payment_terms
           ( code,
             dueDateCalculation,
             accountStatementDueDays,
             inactive,
             -- 20240202
             description,
             -- 20240202
             type,
             creation_date,
             processed_date,
             module,
             status )
    VALUES ( p_payment_terms,
             v_due_days,
             v_account_statement_due_days,
             v_inactive,
             -- 20240202
             v_description,
             -- 20240202
             v_type,
             SYSDATE,
             SYSDATE,
             'AR',
             'CREATED' );

    -- 20250821 - USO TABLA AJC_BC_PAYMENT_TERMS_MAPPING
    -- Se inserta el registro en la tabla de mapeo
    INSERT 
      INTO AJC_BC_PAYMENT_TERMS_MAPPING 
           ( MODULE,
             TERM_ID,
             BC_CODE ) 
    VALUES ( 'AR',
             v_term_id,
             p_payment_terms );
    -- 20250821 - USO TABLA AJC_BC_PAYMENT_TERMS_MAPPING

    COMMIT;             

    print_log ( 'ajc_bc_create_entities_pkg.create_ar_payment_term_f (-)' );

    RETURN v_term_id;

  EXCEPTION  
    WHEN OTHERS THEN
      print_log ( 'ajc_bc_create_entities_pkg.create_ar_payment_term_f (!). Error: ' || SQLERRM );
      RETURN NULL;

  END create_ar_payment_term_f;

  PROCEDURE create_lookup_code_p ( p_lookup_type           IN   VARCHAR2,
                                   p_view_application_id   IN   NUMBER,
                                   p_lookup_code           IN   VARCHAR2,
                                   p_user_id               IN   NUMBER ) IS

    v_rowid   VARCHAR2(200);

  BEGIN

    print_log ( 'ajc_bc_create_entities_pkg.create_lookup_code_p (+)' );

    print_log ( 'p_lookup_type: ' || p_lookup_type );
    print_log ( 'p_view_application_id: ' || p_view_application_id );
    print_log ( 'p_lookup_code: ' || p_lookup_code );
    print_log ( 'p_user_id: ' || p_user_id );

    fnd_lookup_values_pkg.insert_row ( X_ROWID => v_rowid,
                                       X_LOOKUP_TYPE => p_lookup_type,
                                       X_VIEW_APPLICATION_ID => p_view_application_id,
                                       X_LOOKUP_CODE => p_lookup_code,
                                       X_TAG => NULL,
                                       X_ATTRIBUTE_CATEGORY => NULL,
                                       X_ATTRIBUTE1 => NULL,
                                       X_ATTRIBUTE2 => NULL,
                                       X_ATTRIBUTE3 => NULL,
                                       X_ATTRIBUTE4 => NULL,
                                       X_ENABLED_FLAG => 'Y',
                                       X_START_DATE_ACTIVE => NULL,
                                       X_END_DATE_ACTIVE => NULL,
                                       X_TERRITORY_CODE => NULL,
                                       X_ATTRIBUTE5 => NULL,
                                       X_ATTRIBUTE6 => NULL,
                                       X_ATTRIBUTE7 => NULL,
                                       X_ATTRIBUTE8 => NULL,
                                       X_ATTRIBUTE9 => NULL,
                                       X_ATTRIBUTE10 => NULL,
                                       X_ATTRIBUTE11 => NULL,
                                       X_ATTRIBUTE12 => NULL,
                                       X_ATTRIBUTE13 => NULL,
                                       X_ATTRIBUTE14 => NULL,
                                       X_ATTRIBUTE15 => NULL,
                                       X_MEANING => INITCAP(p_lookup_code),
                                       X_DESCRIPTION => INITCAP(p_lookup_code),
                                       X_CREATION_DATE => SYSDATE,
                                       X_CREATED_BY => p_user_id,
                                       X_LAST_UPDATE_DATE => SYSDATE,
                                       X_LAST_UPDATED_BY => p_user_id,
                                       X_LAST_UPDATE_LOGIN => p_user_id );

    print_log ( 'ajc_bc_create_entities_pkg.create_lookup_code_p (-)' );

  END create_lookup_code_p;

  FUNCTION payment_terms_f ( p_name             IN   VARCHAR2,
                             p_application      IN   VARCHAR2,
                             p_company_id       IN   VARCHAR2,
                             p_bc_environment   IN   VARCHAR2 ) RETURN NUMBER IS

    v_terms_id   NUMBER;

  BEGIN

    print_log ( 'ajc_bc_create_entities_pkg.payment_terms_f (+)' );  

    print_log ( 'p_payment_terms: ' || p_name );    
    print_log ( 'p_application: ' || p_application ); 
    print_log ( 'p_company_id: ' || p_company_id );     

    -- 20250821 - USO TABLA AJC_BC_PAYMENT_TERMS_MAPPING
    IF ( p_application = 'AP' ) THEN

      BEGIN

        SELECT m.term_id
          INTO v_terms_id
          FROM AJC_BC_PAYMENT_TERMS_MAPPING m,
               ap_terms pt
         WHERE m.bc_code = p_name
           AND m.module = p_application
           AND m.term_id = pt.term_id;

        print_log ( 'v_terms_id: ' || v_terms_id );

        RETURN v_terms_id;

      EXCEPTION
        WHEN OTHERS THEN
          print_log ( 'El termino de pago de AP no existe, se crea.' ); 
          v_terms_id := create_ap_payment_term_f ( p_name, p_company_id, p_bc_environment );
          print_log ( 'ajc_bc_create_entities_pkg.payment_terms_f (-)' );  

          RETURN v_terms_id;

      END;

    ELSIF ( p_application = 'AR' ) THEN

      BEGIN

        SELECT m.term_id
          INTO v_terms_id
          FROM AJC_BC_PAYMENT_TERMS_MAPPING m,
               ra_terms pt
         WHERE m.bc_code = p_name
           AND m.module = p_application
           AND m.term_id = pt.term_id;

        print_log ( 'v_terms_id: ' || v_terms_id );

        RETURN v_terms_id;

      EXCEPTION
        WHEN OTHERS THEN
          print_log ( 'El termino de pago de AR no existe, se crea.' ); 
          v_terms_id := create_ar_payment_term_f ( p_name, p_company_id, p_bc_environment );
          print_log ( 'ajc_bc_create_entities_pkg.payment_terms_f (-)' );  

          RETURN v_terms_id;

      END;

    END IF;    

    /*
    IF ( p_application = 'AP' ) THEN

      BEGIN

        SELECT term_id
          INTO v_terms_id
          FROM ap_terms_tl
         WHERE name = p_name; 

        print_log ( 'v_terms_id: ' || v_terms_id );

        RETURN v_terms_id;

      EXCEPTION 
        WHEN NO_DATA_FOUND THEN
          print_log ( 'ajc_bc_create_entities_pkg.payment_terms_f (!)' ); 

          BEGIN 

            SELECT term_id
              INTO v_terms_id
              FROM ap_terms_tl
             WHERE name LIKE p_name || '%'; 

            print_log ( 'v_terms_id: ' || v_terms_id );

            RETURN v_terms_id;

          EXCEPTION
            WHEN OTHERS THEN

              print_log ( 'El termino de pago de AP no existe, se crea.' ); 
              v_terms_id := create_ap_payment_term_f ( p_name, p_company_id, p_bc_environment );

              print_log ( 'ajc_bc_create_entities_pkg.payment_terms_f (-)' );  

              RETURN v_terms_id;

          END;

      END;

    ELSE -- p_application = 'AR'

      BEGIN

        SELECT term_id
          INTO v_terms_id
          FROM ra_terms
         WHERE name = p_name;

        print_log ( 'v_terms_id: ' || v_terms_id );

        print_log ( 'ajc_bc_create_entities_pkg.payment_terms_f (-)' );  

        RETURN v_terms_id;

      EXCEPTION 
        WHEN NO_DATA_FOUND THEN
          print_log ( 'ajc_bc_create_entities_pkg.payment_terms_f (!)' ); 

          BEGIN

            SELECT term_id
              INTO v_terms_id
              FROM ra_terms
             WHERE name LIKE p_name || '%';

            print_log ( 'v_terms_id: ' || v_terms_id );

            RETURN v_terms_id;

          EXCEPTION
            WHEN OTHERS THEN
              print_log ( 'El termino de pago de AR no existe, se crea.' ); 
              v_terms_id := create_ar_payment_term_f ( p_name, p_company_id, p_bc_environment );
              RETURN v_terms_id;

          END;

      END;

    END IF;
    */
    -- 20250821 - USO TABLA AJC_BC_PAYMENT_TERMS_MAPPING

  EXCEPTION
    WHEN OTHERS THEN
      print_log ( 'ajc_bc_create_entities_pkg.payment_terms_f (!). Error general.' ); 
      RETURN NULL;

  END payment_terms_f;

  FUNCTION payment_method_f ( p_name   IN   VARCHAR2 ) RETURN VARCHAR IS

    v_payment_method_lookup_code   fnd_lookup_values.lookup_code%TYPE;
    v_view_application_id          NUMBER := 200; -- AP

  BEGIN

    print_log ('ajc_bc_create_entities_pkg.payment_method_f (+)');

    print_log ( 'p_name: ' || p_name );    

    SELECT lookup_code
      INTO v_payment_method_lookup_code
      FROM fnd_lookup_values
     WHERE lookup_type = 'PAYMENT METHOD'
       AND UPPER(meaning) = p_name
       AND view_application_id = v_view_application_id;

    print_log ( 'v_payment_method_lookup_code: ' || v_payment_method_lookup_code );    

    print_log ('ajc_bc_create_entities_pkg.payment_method_f (-)');

    RETURN v_payment_method_lookup_code;    

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      print_log ( 'ajc_bc_create_entities_pkg.check_payment_method_f (!)' ); 
      print_log ( 'El método de pago no existe, se crea.' ); 
      -- Se crea el metodo de pago
      create_lookup_code_p ( p_lookup_type => 'PAYMENT METHOD',
                             p_view_application_id => v_view_application_id,
                             p_lookup_code => p_name,
                             p_user_id => gv_user_id );

      RETURN p_name;

  END payment_method_f;

  FUNCTION pay_group_f ( p_name   IN   VARCHAR2 ) RETURN VARCHAR IS

    v_pay_group_lookup_code   fnd_lookup_values.lookup_code%TYPE;
    v_view_application_id     NUMBER := 201; -- PO

  BEGIN

    print_log ( 'ajc_bc_create_entities_pkg.pay_group_f (+)' );  

    print_log ( 'p_pay_group: ' || p_name );    

    SELECT lookup_code
      INTO v_pay_group_lookup_code
      FROM fnd_lookup_values
     WHERE lookup_type = 'PAY GROUP'
       AND lookup_code = p_name
       AND view_application_id = v_view_application_id;

    print_log ( 'v_pay_group_lookup_code: ' || v_pay_group_lookup_code );

    print_log ( 'ajc_bc_create_entities_pkg.pay_group_f (-)' );  

    RETURN v_pay_group_lookup_code;    

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      print_log ( 'ajc_bc_create_entities_pkg.pay_group_f (!)' ); 
      print_log ( 'El grupo de pago no existe, se crea.' ); 
      -- Se crea el grupo de pago
      create_lookup_code_p ( p_lookup_type => 'PAY GROUP',
                             p_view_application_id => v_view_application_id,
                             p_lookup_code => p_name,
                             p_user_id => gv_user_id );
      RETURN p_name;

  END pay_group_f;

  FUNCTION collector_f ( p_name   IN   VARCHAR ) RETURN NUMBER IS

    v_collector_id   NUMBER;

  BEGIN

    print_log ( 'ajc_bc_create_entities_pkg.collector_f (+)' );  

    print_log ( 'p_collector: ' || p_name );    

    SELECT collector_id
      INTO v_collector_id
      FROM ar_collectors
     WHERE name = p_name;

    print_log ( 'v_collector_id: ' || v_collector_id ); 
    print_log ( 'ajc_bc_create_entities_pkg.collector_f (-)' );  

    RETURN v_collector_id;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      print_log ( 'ajc_bc_create_entities_pkg.collector_f (!)' ); 
      print_log ( 'El collector no existe, se crea.' ); 
      -- Se crea el collector

      SELECT AR_COLLECTORS_S.NEXTVAL
        INTO v_collector_id
        FROM DUAL;

      INSERT
        INTO ar_collectors
             ( collector_id,
               name,
               description,
               alias,
               status,
               last_updated_by,
               last_update_date,
               last_update_login,
               creation_date,
               created_by )
      VALUES ( v_collector_id,
               p_name,
               p_name,
               p_name,
               'A',
               gv_user_id,
               SYSDATE,
               gv_user_id,
               SYSDATE,
               gv_user_id );

      COMMIT;

      RETURN v_collector_id;

  END collector_f; 

  FUNCTION statement_cycle_f ( p_name   IN   VARCHAR ) RETURN NUMBER IS

    v_statement_cycle_id   NUMBER;

  BEGIN

    print_log ( 'ajc_bc_create_entities_pkg.statement_cycle_f (+)' );  

    print_log ( 'p_statement_cycle: ' || p_name );    

    SELECT statement_cycle_id
      INTO v_statement_cycle_id
      FROM ar_statement_cycles
     -- 20251209 
     -- WHERE name = p_name;
     WHERE UPPER(name) = UPPER(p_name);
     -- 20251209 

    print_log ( 'v_statement_cycle_id: ' || v_statement_cycle_id );
    print_log ( 'ajc_bc_create_entities_pkg.statement_cycle_f (-)' );

    RETURN v_statement_cycle_id;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      print_log ( 'ajc_bc_create_entities_pkg.statement_cycle_f (!)' ); 
      print_log ( 'El statement cycle no existe, se crea.' ); 
      -- Se crea el statement cycle
      -- AGREGAR

      RETURN v_statement_cycle_id;

  END statement_cycle_f;

END ajc_bc_create_entities_pkg;
