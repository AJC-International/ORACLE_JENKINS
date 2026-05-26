CREATE OR REPLACE PACKAGE BODY ajc_bc_ar_customers_dae_pkg IS



  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    fnd_file.put_line (fnd_file.log, p_message);



  END print_log;



  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    fnd_file.put_line(fnd_file.output,p_message);



  END print_output;



  PROCEDURE patch_dae_p ( p_bc_environment       IN   VARCHAR2,

                          p_url                  IN   VARCHAR2,

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



    v_clob_result := ajc_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => p_url,

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



  PROCEDURE main_p ( retcode           OUT   NUMBER,

                     errbuf            OUT   VARCHAR2,

                     p_bc_environment   IN   VARCHAR2 ) IS



    v_check_api          VARCHAR2(100);

    v_check_url          VARCHAR2(2000);

    v_clob_result        CLOB; 



    v_api                VARCHAR2(100);

    v_url                VARCHAR2(2000);



    v_email              VARCHAR2(2000);

    v_count              NUMBER := 0;

    v_request_id_excel   NUMBER;



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



    print_log ( 'ajc_bc_ar_customers_dae_pkg.main_p (+)' );



    v_email := ajc_bc_ws_utils_pkg.get_emails_f ( 'CUSTOMERS DAE' );



    -- Web service Customers

    v_check_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'CUSTOMERS',

                                                   p_subentity => NULL,

                                                   p_method => 'GET' );

    print_log ( 'v_check_api: ' || v_check_api );



    v_check_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, gv_company_id ) || v_check_api;



    print_log ( 'Check URL' || v_check_url );



    -- Web service DAE    

    v_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'CUSTOMERS',

                                             p_subentity => 'DAE',

                                             p_method => 'POST' );

    print_log ( 'v_api: ' || v_api );

    v_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, gv_company_id ) || v_api;



    print_log ( ' ' );

    print_log ( 'BC Environment: ' || p_bc_environment );

    print_log ( 'Mail: ' || v_email );

    print_log ( 'URL: ' || v_url );

    print_log ( ' ' );



    FOR cc IN c_customers LOOP



      print_log ( 'Customer Number: ' || cc.customer_number || ' | Customer Name: ' || cc.customer_name || ' | Customer ID: ' || cc.customer_id || ' | DAE: ' || cc.dae );



      -- Verifica si el customer existe en BC

      v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_check_url || '?$filter=no eq ''' || cc.customer_number || '''' );



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



        patch_dae_p ( p_bc_environment => p_bc_environment,

                    p_url => v_url,

                    p_customer_id => cc.customer_id,

                    p_customer_number => cc.customer_number,

                    p_dae => cc.dae,

                    p_request_id => gv_request_id );



        v_count := v_count + 1;



      END IF;



    END LOOP;



    IF ( v_count > 0 ) THEN



      -- AJC BC AR Customers DAE Interface Report

      v_request_id_excel := ajc_bc_ws_utils_pkg.print_excel_report ( p_request_id => gv_request_id,

                                                                     p_program => 'AJCBCARCDAEIR',

                                                                     p_template => 'AJCBCARCDAEIR' );



      ajc_bc_ws_utils_pkg.send_unix_mail_attach ( p_mail => v_email,

                                                  p_report_request_id => v_request_id_excel );



    END IF;



    print_log ( 'ajc_bc_ar_customers_dae_pkg.main_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      print_log ( 'ajc_bc_ar_customers_dae_pkg.main_p (!). Error: ' || SQLERRM );



      ajc_bc_ws_utils_pkg.send_email ( p_to => v_email,

                                       p_subject => 'AJC BC AR Customers DAE Interface - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'),

                                       p_message => 'Error processing DAE: ' || SQLERRM );



      retcode := 2;



  END main_p;



END ajc_bc_ar_customers_dae_pkg; 
