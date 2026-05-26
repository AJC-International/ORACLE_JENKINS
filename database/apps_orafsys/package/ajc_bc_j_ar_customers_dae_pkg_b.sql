PACKAGE BODY AJC_BC_J_AR_CUSTOMERS_DAE_PKG IS

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    gv_log_seq := gv_log_seq + 1;
    AJC_BC_J_UTILS_PKG.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );

  END print_log;

  PROCEDURE patch_dae_p ( p_url                  IN   VARCHAR2,
                          p_customer_id          IN   NUMBER,
                          p_customer_number      IN   NUMBER,
                          p_dae                  IN   NUMBER,
                          --
                          p_request_id           IN   NUMBER ) IS

    v_dae_char      VARCHAR2(20);
    v_body          VARCHAR2(2000);
    v_clob_result   CLOB;

    v_error         VARCHAR2(2000);

  BEGIN

    SELECT REPLACE(DECODE(TO_CHAR(TRUNC(p_dae,2)),'0','0.01',TO_CHAR(TRUNC(p_dae,2))),',','.')
      INTO v_dae_char
      FROM DUAL;

    v_body := '{"no":"' || p_customer_number || '",' || 
               '"dae":' || v_dae_char || '}';

    v_clob_result := AJC_BC_J_WS_UTILS_PKG.patch_post_bc_row_f ( p_url => p_url,
                                                                 p_request_header_name1 => 'Content-Type',
                                                                 p_request_header_value1 => 'application/json',
                                                                 p_request_header_name2 => NULL,
                                                                 p_request_header_value2 => NULL,
                                                                 p_http_method => 'POST',
                                                                 p_body => v_body );

    IF ( v_clob_result LIKE '%api.businesscentral.dynamics.com%' ) THEN

      UPDATE AJC_BC_CUSTOMERS_DAE
         SET json_data = v_body,
             json_data_response = v_clob_result,
             request_id = gv_request_id,
             status = 'PROCESSED'
       WHERE status IN ('NEW','ERROR')
         AND request_id IS NULL
         AND customer_id = p_customer_id;

    ELSIF ( UPPER(v_clob_result) LIKE '%ERROR%' ) THEN

      UPDATE AJC_BC_CUSTOMERS_DAE
         SET json_data = v_body,
             json_data_response = v_clob_result,
             request_id = gv_request_id,
             status = 'ERROR',
             error_message = v_clob_result
       WHERE status IN ('NEW','ERROR')
         AND request_id IS NULL
         AND customer_id = p_customer_id;

    ELSE

      UPDATE AJC_BC_CUSTOMERS_DAE
         SET json_data = v_body,
             json_data_response = v_clob_result,
             request_id = gv_request_id,
             status = 'ERROR',
             error_message = v_clob_result
       WHERE status IN ('NEW','ERROR')
         AND request_id IS NULL
         AND customer_id = p_customer_id;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN

      v_error := SQLERRM;

      UPDATE AJC_BC_CUSTOMERS_DAE
         SET json_data = v_body,
             json_data_response = v_clob_result,
             request_id = gv_request_id,
             status = 'ERROR',
             error_message = v_error
       WHERE status IN ('NEW','ERROR')
         AND request_id IS NULL
         AND customer_id = p_customer_id;

  END patch_dae_p;

  PROCEDURE final_report_csv_p ( p_status   OUT   VARCHAR2 ) IS

      CURSOR c_customers IS
      SELECT cd.customer_id,
             rc.customer_number,
             rc.customer_name,
             cd.dae,
             cd.status,
             cd.error_message
        FROM AJC_BC_CUSTOMERS_DAE cd,
             ra_customers rc
       WHERE cd.customer_id = rc.customer_id
             AND cd.request_id = gv_request_id
             AND cd.status != 'NEW'
        ORDER BY rc.customer_name;

  BEGIN

    print_log( 'AJC_BC_J_AR_CUSTOMERS_DAE_PKG.final_report_csv_p (+)' );

    -- Insert Report Title
    AJC_BC_J_UTILS_PKG.insert_report_p ( p_ifc => gv_bc_ifc,
                                         p_text => gv_bc_ifc || ' Report',
                                         p_request_id => gv_request_id );

    -- Fila vacia
    AJC_BC_J_UTILS_PKG.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );

    -- Tabla 1 -----------------------------------------------------------------------------------------------------------------                                    
    -- Insert Table Title
    AJC_BC_J_UTILS_PKG.insert_report_p ( p_ifc => gv_bc_ifc,
                                         p_text => 'Customers DAE',
                                         p_request_id => gv_request_id );

    -- Fila vacia
    AJC_BC_J_UTILS_PKG.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );

    -- Insert Table Column Names                            
    AJC_BC_J_UTILS_PKG.insert_report_p ( p_ifc => gv_bc_ifc,
                                         p_text => 'Customer ID' || '|' ||
                                                   'Customer Number' || '|' ||
                                                   'Customer Name' || '|' ||
                                                   'DAE' || '|' ||
                                                   'Status' || '|' ||
                                                   'Message',
                                         p_request_id => gv_request_id );                                        

    -- Se insertan los registros
    FOR cc IN c_customers LOOP

      AJC_BC_J_UTILS_PKG.insert_report_p ( p_ifc => gv_bc_ifc,
                                           p_text => cc.customer_id || '|' || 
                                                     cc.customer_number || '|' || 
                                                     cc.customer_name || '|' || 
                                                     cc.dae || '|' || 
                                                     cc.status || '|' || 
                                                     cc.error_message,
                                           p_request_id => gv_request_id );     

    END LOOP;

    p_status := 'S';

    print_log( 'AJC_BC_J_AR_CUSTOMERS_DAE_PKG.final_report_csv_p (-)' );

  EXCEPTION
    WHEN OTHERS THEN
      p_status := 'E';
      print_log( 'AJC_BC_J_AR_CUSTOMERS_DAE_PKG.final_report_csv_p (!). Error: ' || SQLERRM );

  END final_report_csv_p;

  PROCEDURE final_report_xlsx_p ( p_status   OUT   VARCHAR2 ) IS

    c_cursor   SYS_REFCURSOR;

  BEGIN

    print_log( 'AJC_BC_J_AR_CUSTOMERS_DAE_PKG.final_report_xlsx_p (+)' );

    gv_directory_report := AJC_BC_J_WS_UTILS_PKG.get_parameter_f ( p_parameter_code => 'AJC_DIRECTORY_REPORT' );

    AJC_BC_J_UTILS_PKG.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc || ' Report',
                                                 p_request_id => gv_request_id,
                                                 p_bc_environment => gv_bc_environment,
                                                 p_jenkins_build_number => gv_jenkins_build_number );

    -- CUSTOMERS DAE
        OPEN c_cursor FOR
      SELECT cd.customer_id,
             rc.customer_number,
             rc.customer_name,
             cd.dae,
             cd.status,
             cd.error_message
        FROM AJC_BC_CUSTOMERS_DAE cd,
             ra_customers rc
       WHERE cd.customer_id = rc.customer_id
             AND cd.request_id = gv_request_id
             AND cd.status != 'NEW'
        ORDER BY rc.customer_name;

    AJC_BC_J_UTILS_PKG.create_sheet_p ( p_sheet_title => 'Customers DAE',
                                        p_sheet => 2,
                                        p_cursor => c_cursor );

    as_xlsx.save ( gv_directory_report, gv_report_filename || '.' || LOWER(gv_file_format) );

    p_status := 'S';

    print_log( 'AJC_BC_J_AR_CUSTOMERS_DAE_PKG.final_report_xlsx_p (-)' );

  EXCEPTION
    WHEN OTHERS THEN
      p_status := 'E';
      print_log( 'AJC_BC_J_AR_CUSTOMERS_DAE_PKG.final_report_xlsx_p (!). Error: ' || SQLERRM );

  END final_report_xlsx_p;

  PROCEDURE main_p ( p_bc_environment           IN   VARCHAR2,
                     p_jenkins_build_number     IN   VARCHAR2 ) IS

    v_check_api          VARCHAR2(100);
    v_check_url          VARCHAR2(2000);
    v_clob_result        CLOB; 

    v_api                VARCHAR2(100);
    v_url                VARCHAR2(2000);

    v_count              NUMBER := 0;

    v_error_message      VARCHAR2(200);
    v_status             VARCHAR2(200);
    v_phase              VARCHAR2(100);

    e_parameter_value    EXCEPTION;
    e_dae                EXCEPTION;        

    CURSOR c_customers IS
    SELECT cd.customer_id,
           rc.customer_number,
           rc.customer_name,
           cd.dae dae
      FROM AJC_BC_CUSTOMERS_DAE cd,
           ra_customers rc
     WHERE cd.customer_id = rc.customer_id
       AND cd.status IN ('NEW','ERROR');

  BEGIN

    gv_request_id := AJC_BC_J_UTILS_PKG.get_request_id_f;
    gv_jenkins_build_number := p_jenkins_build_number;

    -- Se inserta el concurrent_job
    AJC_BC_J_UTILS_PKG.ins_jenkins_concurrent_job_p ( p_request_id => gv_request_id,
                                                      p_job_name => gv_bc_ifc,
                                                      p_jenkins_build_number => p_jenkins_build_number,
                                                      p_argument1 => p_bc_environment );

    print_log ( 'AJC_BC_J_AR_CUSTOMERS_DAE_PKG.main_p (+)' );
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

    gv_email := AJC_BC_J_UTILS_PKG.get_emails_f ( 'CUSTOMERS DAE' );
    print_log ( 'gv_email: ' || gv_email );

    -- Web service Customers
    v_check_api := AJC_BC_J_WS_UTILS_PKG.get_api_f ( p_entity => 'CUSTOMERS',
                                                     p_subentity => NULL,
                                                     p_method => 'GET' );
    print_log ( 'v_check_api: ' || v_check_api );

    v_check_url := AJC_BC_J_WS_UTILS_PKG.get_base_inecta_url_f ( gv_bc_environment, gv_company_id ) || v_check_api;

    print_log ( 'Check URL' || v_check_url );

    v_api := AJC_BC_J_WS_UTILS_PKG.get_api_f ( p_entity => 'CUSTOMERS',
                                               p_subentity => 'DAE',
                                               p_method => 'POST' );
    print_log ( 'v_api: ' || v_api );

    v_url := AJC_BC_J_WS_UTILS_PKG.get_base_inecta_url_f ( gv_bc_environment, gv_company_id ) || v_api;
    print_log ( 'v_url: ' || v_url );

    FOR cc IN c_customers LOOP

      print_log ( 'Customer Number: ' || cc.customer_number || ' | Customer Name: ' || cc.customer_name || ' | Customer ID: ' || cc.customer_id || ' | DAE: ' || cc.dae );

      -- Verifica si el customer existe en BC
      v_clob_result := AJC_BC_J_WS_UTILS_PKG.get_bc_clob_result_f ( p_url => v_check_url || '?$filter=no eq ''' || cc.customer_number || '''' );

      -- No existe, se marca SKIPPED para que no vuelva a intentar enviarlo
      IF ( v_clob_result LIKE '%"value":[]%' ) THEN

        print_log ( 'Customer does not exist.' );

        UPDATE AJC_BC_CUSTOMERS_DAE
           SET request_id = gv_request_id,
               status = 'SKIPPED',
               error_message = 'Customer does not exist in BC Master Data'
         WHERE status IN ('NEW','ERROR')
           AND request_id IS NULL
           AND customer_id = cc.customer_id;

      -- Existe, se envía el valor de DAE
      ELSE

        print_log ( 'Customer exists.' );

        patch_dae_p ( p_url => v_url,
                      p_customer_id => cc.customer_id,
                      p_customer_number => cc.customer_number,
                      p_dae => cc.dae,
                      p_request_id => gv_request_id );

        v_count := v_count + 1;

      END IF;

    END LOOP;

    IF ( v_count > 0 ) THEN

      -- INSERT REPORT IN TABLE AJC_BC_REPORTS --------------------------------------------------------------------------------
      IF ( gv_file_format = 'CSV' ) THEN

        final_report_csv_p ( p_status => v_status );     

        IF ( v_status != 'S' ) THEN

          v_phase := 'final_report_csv_p';
          RAISE e_dae;

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
          RAISE e_dae;

        END IF;

      ELSIF ( gv_file_format = 'XLSX' ) THEN 

        -- No inserta en tabla, genera el xlsx directamente en el filesystem
        final_report_xlsx_p ( p_status => v_status );     

        IF ( v_status != 'S' ) THEN

          v_phase := 'final_report_xlsx_p';
          RAISE e_dae;

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

    END IF;

    -- Se actualiza el concurrent_job
    AJC_BC_J_UTILS_PKG.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'S' );

    print_log ( 'AJC_BC_J_AR_CUSTOMERS_DAE_PKG.main_p (-)' );

  EXCEPTION
    WHEN e_dae THEN
      print_log ( 'AJC_BC_J_AR_CUSTOMERS_DAE_PKG.main_p (!). Phase: ' || v_phase || '. Error: ' || v_error_message );

      AJC_BC_J_UTILS_PKG.send_email_p ( p_to => gv_email,
                                        p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',
                                        p_message => 'Error creating report ' || 'Request ID: ' || gv_request_id );

      -- Se actualiza el concurrent_job
      AJC_BC_J_UTILS_PKG.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );

      RAISE_APPLICATION_ERROR(-20000,'Error creating report.' );     

    WHEN OTHERS THEN
      print_log ( 'AJC_BC_J_AR_CUSTOMERS_DAE_PKG.main_p (!). Error: ' || SQLERRM );

      AJC_BC_J_UTILS_PKG.send_email_p ( p_to => gv_email,
                                        p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',
                                        p_message => 'Error processing DAE: ' || SQLERRM );

      -- Se actualiza el concurrent_job
      AJC_BC_J_UTILS_PKG.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );

      RAISE_APPLICATION_ERROR(-20000,'General Error: ' || SQLERRM );     

  END main_p;

END AJC_BC_J_AR_CUSTOMERS_DAE_PKG; 
