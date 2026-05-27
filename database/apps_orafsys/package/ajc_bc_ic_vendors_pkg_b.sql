CREATE OR REPLACE PACKAGE BODY ajc_bc_ic_vendors_pkg AS
  
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
    
    v_error_message     VARCHAR2(2000);
    e_parameter_value   EXCEPTION;    
    
  BEGIN
    
    gv_request_id := AJC_BC_J_UTILS_PKG.get_request_id_f;
    gv_jenkins_build_number := p_jenkins_build_number;
    
    -- Se inserta el concurrent_job
    AJC_BC_J_UTILS_PKG.ins_jenkins_concurrent_job_p ( p_request_id => gv_request_id,
                                                      p_job_name => gv_bc_ifc,
                                                      p_jenkins_build_number => p_jenkins_build_number,
                                                      p_argument1 => p_bc_environment );
    
    print_log ( 'ajc_bc_ic_vendors_pkg.main_p (+)' );
    print_log ( 'gv_request_id: ' || gv_request_id );
    print_log ( 'gv_jenkins_build_number: ' || gv_jenkins_build_number );
    
    -- Validacion parametro p_bc_environment -----------------------------------------------------------------------------------
    IF ( AJC_BC_J_UTILS_PKG.is_bc_environment_valid_f ( p_bc_environment ) = 'N' ) THEN

      v_error_message := 'Invalid value (' || p_bc_environment || ') for parameter BC_ENVIRONMENT.';
      RAISE e_parameter_value;

    END IF;
    
    gv_bc_environment := p_bc_environment;
    print_log ( 'gv_bc_environment: ' || gv_bc_environment );    
    
    -- gv_bc_support_email := 'sbanchieri@gmail.com';
    gv_bc_support_email := AJC_BC_J_UTILS_PKG.get_emails_f ( 'SUPPORT' );
    print_log ( 'gv_bc_support_email: ' || gv_bc_support_email );
    
    print_log ('Deleting ajc_bc_ic_vendors table..');
    DELETE ajc_bc_ic_vendors;
    COMMIT;
    
    -- Inicio - Se bajan los customer number de los IC
    v_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'IC VENDORS',
                                             p_subentity => NULL,
                                             p_method => 'GET' );
                                             
    v_url := ajc_bc_ws_utils_pkg.get_base_ajc_url_v2_f ( gv_bc_environment, gv_company_id ) || v_api;
    print_log ( 'v_url: ' || v_url );
    
    v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );
    
    print_log ('Getting Intercompany Vendors..');
     
    FOR cicv IN c_ic_vendors ( v_clob_result ) LOOP

      INSERT 
        INTO ajc_bc_ic_vendors 
             ( vendor_number ) 
      VALUES ( cicv.no );
      
      print_log ('Vendor ' || cicv.no || ' inserted.');

    END LOOP;
    -- Fin - Se bajan los customer number de los IC
    
    -- Se recorren todos los vendor number de la tabla y se obtienen los names
    v_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'VENDORS',
                                             p_subentity => NULL,
                                             p_method => 'GET' );
    
    v_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( gv_bc_environment, gv_company_id ) || v_api;
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
    
    -- Se actualiza el concurrent_job
    AJC_BC_J_UTILS_PKG.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'S' );
    
    COMMIT;

    print_log ('ajc_bc_ic_vendors_pkg.main_p (-)');
    
  EXCEPTION
    WHEN e_parameter_value THEN
      
      print_log('ajc_bc_ic_vendors_pkg.main_p (!)');
      print_log(v_error_message);    

      BEGIN
      
        AJC_BC_J_UTILS_PKG.send_email_p ( p_to => gv_bc_support_email,
                                          p_subject => gv_bc_ifc || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',
                                          p_message => 'Error: ' || v_error_message || CHR(10) || 'Request ID: ' || gv_request_id );

      EXCEPTION
        WHEN OTHERS THEN
          print_log ( 'SMTP not working.' );
      END;
      
      -- Se actualiza el concurrent_job
      AJC_BC_J_UTILS_PKG.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );                                       

      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_message ); 
      
    WHEN OTHERS THEN
      print_log('ajc_bc_ic_vendors_pkg.main_p (!)');
      print_log('Error: ' || SQLERRM );

      BEGIN
      
        AJC_BC_J_UTILS_PKG.send_email_p ( p_to => gv_bc_support_email,
                                          p_subject => gv_bc_ifc || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',
                                          p_message => 'General error: ' || SQLERRM );
 
      EXCEPTION
        WHEN OTHERS THEN
          print_log ( 'SMTP not working.' );
      END;
 
      -- Se actualiza el concurrent_job
      AJC_BC_J_UTILS_PKG.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );

      RAISE_APPLICATION_ERROR(-20000,'General Error: ' || SQLERRM );

  END main_p;

END ajc_bc_ic_vendors_pkg;