PACKAGE BODY ajc_bc_ic_vendors_pkg AS
  
  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    gv_log_seq := gv_log_seq + 1;
    AJC_BC_J_UTILS_PKG.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );

  END print_log;

  PROCEDURE main_p ( p_bc_environment         IN   VARCHAR2,
                     p_jenkins_build_number   IN   VARCHAR2 ) IS

    v_api              VARCHAR2(100);

    v_url              VARCHAR2(2000);
    v_temp_url         VARCHAR2(2000);

    v_clob_result      CLOB;

    CURSOR c_ic_vendors ( p_clob_result   IN   CLOB ) IS
    SELECT no
      FROM json_table( p_clob_result,
                       '$.value[*]' COLUMNS ( no   VARCHAR2(4000)  path '$.no' ) );

    CURSOR c_vendors IS
    SELECT vendor_number
      FROM ajc_bc_ic_vendors;

    CURSOR c_ic_vendors_name ( p_clob_result   IN   CLOB ) IS
    SELECT no,
           name
      FROM json_table( p_clob_result,
                       '$.value[*]' COLUMNS ( no     VARCHAR2(4000)  path '$.vendorno',
                                              name   VARCHAR2(4000)  path '$.name' ) );

  BEGIN

    gv_request_id := AJC_BC_J_UTILS_PKG.get_request_id_f;
    gv_jenkins_build_number := p_jenkins_build_number;

    print_log ('ajc_bc_ic_vendors_pkg.main_p (+)');

    print_log ('Deleting ajc_bc_ic_vendors table..');
    DELETE ajc_bc_ic_vendors;
    COMMIT;

    -- Inicio - Se bajan los customer number de los IC
    v_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'IC VENDORS',
                                             p_subentity => NULL,
                                             p_method => 'GET' );

    v_url := ajc_bc_ws_utils_pkg.get_base_ajc_url_v2_f ( p_bc_environment, gv_company_id ) || v_api;
    print_log ( 'v_url: ' || v_url );

    v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );

    print_log ('Getting Intercompany Vendors..');

    FOR cicv IN c_ic_vendors ( v_clob_result ) LOOP

      INSERT INTO ajc_bc_ic_vendors ( vendor_number ) VALUES ( cicv.no ); 
      print_log ('Vendor ' || cicv.no || ' inserted.');

    END LOOP;
    -- Fin - Se bajan los customer number de los IC

    -- Se recorren todos los vendor number de la tabla y se obtienen los names
    v_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'VENDORS',
                                             p_subentity => NULL,
                                             p_method => 'GET' );

    v_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, gv_company_id ) || v_api;
    print_log ( 'v_url: ' || v_url );

    print_log ('Getting Intercompany Vendors names..');

    FOR cv IN c_vendors LOOP

      v_temp_url := v_url || '?$filter=vendorno eq ''' || cv.vendor_number || '''';
      print_log ( 'v_temp_url: ' || v_temp_url );

      v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( v_temp_url );

      FOR cicvn IN c_ic_vendors_name ( v_clob_result ) LOOP

        UPDATE ajc_bc_ic_vendors 
           SET vendor_name = cicvn.name 
         WHERE vendor_number = cv.vendor_number;

        print_log ('Vendor ' || cv.vendor_number || ' updated with name ' || cicvn.name );

      END LOOP;

    END LOOP;

    COMMIT;

    print_log ('ajc_bc_ic_vendors_pkg.main_p (-)');

  EXCEPTION
    WHEN OTHERS THEN
      print_log ('General error: ' || SQLERRM);

  END main_p;

END ajc_bc_ic_vendors_pkg;
