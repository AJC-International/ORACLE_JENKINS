PACKAGE BODY ajc_bc_ic_customers_pkg AS
  
  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line (fnd_file.log, p_message);

  END print_log;

  PROCEDURE main_p ( p_bc_environment    IN   VARCHAR2 ) IS

    v_api              VARCHAR2(100);

    v_url              VARCHAR2(2000);
    v_temp_url         VARCHAR2(2000);

    v_clob_result      CLOB;

    CURSOR c_ic_customers ( p_clob_result   IN   CLOB ) IS
    SELECT no
      FROM json_table( p_clob_result,
                       '$.value[*]' COLUMNS ( no   VARCHAR2(4000)  path '$.no' ) )
     -- Se excluyen las excepciones cargadas en la lookup
     WHERE no NOT IN ( SELECT lookup_code
                         FROM fnd_lookup_values
                        WHERE lookup_type = 'AJC_BC_IC_CUSTOMERS_EXCEPTIONS'
                          AND NVL(enabled_flag,'N') = 'Y'
                          AND SYSDATE BETWEEN start_date_active AND NVL(end_date_active,SYSDATE + 1) );

    CURSOR c_customers IS
    SELECT customer_number
      FROM ajc_bc_ic_customers;

    CURSOR c_ic_customers_name ( p_clob_result   IN   CLOB ) IS
    SELECT no,
           name
      FROM json_table( p_clob_result,
                       '$.value[*]' COLUMNS ( no     VARCHAR2(4000)  path '$.no',
                                              name   VARCHAR2(4000)  path '$.name' ) );

  BEGIN

    print_log ('ajc_bc_ic_customers_pkg.main_p (+)');

    print_log ('Deleting ajc_bc_ic_customers table..');
    DELETE ajc_bc_ic_customers;
    COMMIT;

    print_log ('Inserting UNIDENTIFIED (998021) customer..');
    INSERT INTO ajc_bc_ic_customers ( customer_number ) VALUES ( '998021' );

    -- Inicio - Se bajan los customer number de los IC
    v_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'IC PARTNERS',
                                             p_subentity => NULL,
                                             p_method => 'GET' );

    v_url := ajc_bc_ws_utils_pkg.get_base_ajc_url_v2_f ( p_bc_environment, gv_company_id ) || v_api;
    print_log ( 'v_url: ' || v_url );

    v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );

    print_log ('Getting Intercompany Customers..');

    FOR cicc IN c_ic_customers ( v_clob_result ) LOOP

      INSERT INTO ajc_bc_ic_customers ( customer_number ) VALUES ( cicc.no ); 
      print_log ('Customer ' || cicc.no || ' inserted.');

    END LOOP;
    -- Fin - Se bajan los customer number de los IC

    -- Se recorren todos los customer number de la tabla y se obtienen los names
    v_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'CUSTOMERS',
                                             p_subentity => NULL,
                                             p_method => 'GET' );

    v_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, gv_company_id ) || v_api;
    print_log ( 'v_url: ' || v_url );

    print_log ('Getting Intercompany Customers names..');

    FOR cc IN c_customers LOOP

      v_temp_url := v_url || '?$filter=no eq ''' || cc.customer_number || '''';
      print_log ( 'v_temp_url: ' || v_temp_url );

      v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( v_temp_url );

      FOR ciccn IN c_ic_customers_name ( v_clob_result ) LOOP

        UPDATE ajc_bc_ic_customers 
           SET customer_name = ciccn.name 
         WHERE customer_number = cc.customer_number;

        print_log ('Customer ' || cc.customer_number || ' updated with name ' || ciccn.name );

      END LOOP;

    END LOOP;

    COMMIT;

    print_log ('ajc_bc_ic_customers_pkg.main_p (-)');

  END main_p;

END ajc_bc_ic_customers_pkg;
