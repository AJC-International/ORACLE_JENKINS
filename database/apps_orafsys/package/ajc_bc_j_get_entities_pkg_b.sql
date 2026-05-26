PACKAGE BODY ajc_bc_j_get_entities_pkg IS
-- Creation: SBANCHIERI 23-AUG-2023

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    gv_log_seq := gv_log_seq + 1;
    AJC_BC_J_UTILS_PKG.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );

  END print_log;

  -- Obtiene los usuarios que tienen permiso para sincronizar Vendors y Customers de INC y LOG de BC a Oracle
  PROCEDURE get_vend_cust_ifc_users_p ( p_bc_environment   IN   VARCHAR2,
                                        p_bc_ifc           IN   VARCHAR2,
                                        p_request_id       IN   NUMBER,
                                        p_log_seq      IN OUT   NUMBER,
                                        p_status          OUT   VARCHAR2 ) IS

    v_url                      VARCHAR2(2000);
    v_clob_result              CLOB;
    v_total_record_count       NUMBER := 0;

    -- Lock & Release
    v_process_name             VARCHAR2(200) := 'AJC BC GET VENDORS CUSTOMERS IFC USERS';

    v_request_status           VARCHAR2(200);
    v_id_lock                  VARCHAR2(200);
    e_lock                     EXCEPTION;

    v_release_status           VARCHAR2(200);
    e_release                  EXCEPTION;   
    -- Lock & Release

    CURSOR c_vend_cust_ifc_users ( p_clob_result   IN   CLOB ) IS
    SELECT company,
           type,
           bc_user,
           full_name,
           user_security_id,
           DECODE(enabled,'true','Y','N') enabled
      FROM json_table( p_clob_result,  
                       '$.value[*]' COLUMNS ( company            VARCHAR2(4000)  path '$.company',
                                              type               VARCHAR2(4000)  path '$.type',
                                              bc_user            VARCHAR2(4000)  path '$.user',
                                              full_name          VARCHAR2(4000)  path '$.fullname',
                                              user_security_id   VARCHAR2(4000)  path '$.usersecurityid',
                                              enabled            VARCHAR2(4000)  path '$.enabled' ) ); 

  BEGIN

    -- Lock & Release
    ajc_bc_dbms_lock_pkg.lock_p ( p_process_name => v_process_name,
                                  p_id_lock => v_id_lock,
                                  p_request_status => v_request_status ); 

    IF ( v_request_status != 'success' ) THEN

      RAISE e_lock;

    END IF;
    -- Lock & Release

    gv_bc_ifc := p_bc_ifc;
    gv_request_id := p_request_id;
    gv_log_seq := p_log_seq;

    print_log ( 'ajc_bc_j_get_entities_pkg.get_vend_cust_ifc_users_p (+)' );

    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,
                                                          p_entity => 'VENDORS CUSTOMERS IFC USERS', 
                                                          p_subentity => NULL,
                                                          p_method => 'GET',
                                                          p_company_id => gv_company_id ); 

    print_log ( 'v_url: ' || v_url );

    v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );

    -- print_log ( 'v_clob_result: ' || v_clob_result );

    DELETE AJC_BC_VEND_CUST_IFC_USERS
     WHERE bc_environment = p_bc_environment;

    COMMIT;

    print_log ( 'DELETE AJC_BC_VEND_CUST_IFC_USERS' );

    FOR cvciu IN c_vend_cust_ifc_users ( v_clob_result ) LOOP

      v_total_record_count := v_total_record_count + 1;      
      -- print_log ( 'user: ' || cvciu.bc_user );

      BEGIN

          INSERT
            INTO ajc_bc_vend_cust_ifc_users
               ( bc_environment,
                 company,
                 type,
                 bc_user,
                 full_name,
                 user_security_id,
                 enabled,
                 creation_date )
        VALUES ( p_bc_environment,
                 cvciu.company,
                 cvciu.type,
                 cvciu.bc_user,
                 cvciu.full_name,
                 cvciu.user_security_id,
                 cvciu.enabled,
                 SYSDATE );

      EXCEPTION 
        WHEN OTHERS THEN
          print_log ( 'ajc_bc_j_get_entities_pkg.get_vend_cust_ifc_users_p (!). Error insertando ajc_bc_vend_cust_ifc_users. Error: ' || SQLERRM );

      END;

    END LOOP;

    COMMIT;

    print_log ( 'v_total_record_count: ' || v_total_record_count );

    p_status := 'S';

    print_log ( 'ajc_bc_j_get_entities_pkg.get_vend_cust_ifc_users_p (-)' );
    p_log_seq := gv_log_seq;

    -- Lock & Release
    ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,
                                     p_release_status => v_release_status );

    IF ( v_release_status != 'success' ) THEN

      RAISE e_release;

    END IF;                                     
    -- Lock & Release

  EXCEPTION
    -- Lock & Release
    WHEN e_lock THEN
      print_log ('ajc_bc_j_get_entities_pkg.get_vend_cust_ifc_users_p. Error al intentar hacer el lock del proceso: ' || v_process_name || ' | v_request_status: ' || v_request_status);
      p_status := 'E';
      p_log_seq := gv_log_seq;
    WHEN e_release THEN
      print_log ('ajc_bc_j_get_entities_pkg.get_vend_cust_ifc_users_p. Error al intentar hacer el release del proceso: ' || v_process_name || ' | v_release_status: ' || v_release_status);
      p_status := 'E';
      p_log_seq := gv_log_seq;
    -- Lock & Release

    WHEN OTHERS THEN
      p_status := 'E';
      print_log('ajc_bc_j_get_entities_pkg.get_vend_cust_ifc_users_p (!). Error: ' || SQLERRM); 
      -- Lock & Release
      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,
                                       p_release_status => v_release_status );
      p_log_seq := gv_log_seq;

  END get_vend_cust_ifc_users_p;

END ajc_bc_j_get_entities_pkg;
