CREATE OR REPLACE PACKAGE BODY ajcl_bc_ap_data_migration_pkg IS

  

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    gv_log_seq := gv_log_seq + 1;

    ajcl_bc_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );



  END print_log;



  PROCEDURE final_report_xlsx_p IS



    c_cursor   SYS_REFCURSOR;

    v_sheet    NUMBER := 1;



  BEGIN



    print_log( 'ajcl_bc_ap_data_migration_pkg.final_report_xlsx_p (+)' );



    gv_directory_report := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_REPORT' );



    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc,

                                                p_request_id => gv_request_id,

                                                p_bc_environment => gv_bc_environment,

                                                p_jenkins_build_number => gv_jenkins_build_number,

                                                --

                                                p_param_1_title => ' ',

                                                p_param_1_value => NULL,

                                                --

                                                p_param_2_title => 'ACCOUNTING_DATE_TO',

                                                p_param_2_value => TO_CHAR(gv_accounting_date_to,'YYYY-MM-DD'),

                                                p_param_3_title => 'GL_DATE',

                                                p_param_3_value => TO_CHAR(gv_gl_date,'YYYY-MM-DD'),

                                                p_param_4_title => 'INVOICE_NUM_TYPE',

                                                p_param_4_value => gv_invoice_num_type,

                                                p_param_5_title => 'EXPORT_TYPE',

                                                p_param_5_value => gv_export_type,

                                                p_param_6_title => 'TYPE',

                                                p_param_6_value => gv_type,

                                                p_param_7_title => 'MIGRATION_TYPE',

                                                p_param_7_value => gv_migration_type,

                                                p_param_8_title => 'INVOICE_NUM_PREFIX',

                                                p_param_8_value => gv_invoice_num_prefix,

                                                p_param_9_title => 'ORACLE_DB',

                                                p_param_9_value => gv_oracle_db );



    IF ( gv_export_type = 'CONFIGURATION_PACKAGE' ) THEN



      -- Worksheets ------------------------------------------------------------------------------------------------------------                     

          OPEN c_cursor FOR                                                

        SELECT 'WORKSHEET' dimension_code,

               worksheet dimension_value_code,

               NULL dimension_value_name,

               'false' blocked,

               NULL status,

               NULL status_timestamp,

               NULL status_remarks,

               NULL creation_timestamp,

               TO_CHAR(request_id) request_id

          FROM ajcl_bc_ap_dm_lines

         WHERE request_id = gv_request_id

      GROUP BY worksheet,

               request_id

      ORDER BY worksheet;



      v_sheet := v_sheet + 1;

      ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Worksheets',

                                         p_sheet => v_sheet,

                                         p_cursor => c_cursor );



      -- Purchase Headers ------------------------------------------------------------------------------------------------------

          OPEN c_cursor FOR                                                

        SELECT DECODE(invoice_type_lookup_code,'STANDARD','Invoice',

                                               'CREDIT','Credit Memo') document_type,

               TO_CHAR(invoice_id) invoice_id,

               DECODE(gv_invoice_num_type,'ORACLE',oracle_invoice_num,'BC',invoice_num) invoice_no,

               invoice_type_lookup_code invoice_type,

               TO_CHAR(invoice_date,'YYYY-MM-DD') invoice_date,

               vendor_num vendor_no,

               vendor_site_code,

               invoice_amount,

               invoice_currency_code,

               exchange_rate,

               exchange_rate_type,

               TO_CHAR(exchange_date,'YYYY-MM-DD') exchange_date,

               0 base_amount,

               TO_CHAR(gl_date,'YYYY-MM-DD') gl_date,

               TO_CHAR(org_id) OrganisationID,

               description,

               terms_name term_name,

               TO_CHAR(terms_date,'YYYY-MM-DD') terms_date,

               NULL due_date,

               payment_method_lookup_code payment_method_code,

               pay_group_lookup_code pay_group_code,

               set_of_books_id,

               set_of_books_name,

               NULL accounts_pay_code,

               company, 

               account, 

               account_description,

               department,

               product,

               destination,

               origin,

               division,

               NULL status,

               NULL status_timestamp,

               NULL status_remarks,

               NULL creation_timestamp,

               pdf_file_url,

               TO_CHAR(request_id) request_id,

               source,

               office

          FROM ajcl_bc_ap_dm_headers

         WHERE request_id = gv_request_id

      ORDER BY DECODE(invoice_type_lookup_code,'STANDARD',1,'CREDIT',2),

               invoice_id;



      v_sheet := v_sheet + 1;

      ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Purchase Headers',

                                         p_sheet => v_sheet,

                                         p_cursor => c_cursor );  



      -- Purchase Lines --------------------------------------------------------------------------------------------------------

      OPEN c_cursor FOR                                                

        SELECT TO_CHAR(l.invoice_id) invoice_id,

               l.line_number line_no,

               l.amount,

               l.description,

               TO_CHAR(SYSDATE,'YYYY-MM-DD') accounting_date,

               ( SELECT period_name 

                   FROM gl_periods gp

                  WHERE gp.adjustment_period_flag = 'N' 

                    AND gp.period_set_name = 'AJC CALENDAR' 

                    AND h.gl_date BETWEEN start_date AND end_date ) period_name,

               l.worksheet worksheet_no,

               0 base_amount,

               h.exchange_rate, 

               h.exchange_rate_type,

               TO_CHAR(h.exchange_date,'YYYY-MM-DD') exchange_date,

               TO_CHAR(h.org_id) OrganisationID,

               l.set_of_books_id,

               l.set_of_books_name,

               NULL dist_code_combination,

               l.company,

               l.account,

               l.account_description,

               l.department,

               l.product,

               l.destination,

               l.origin,

               l.division,

               NULL status,

               NULL status_timestamp,

               NULL status_remarks,

               NULL creation_timestamp,

               TO_CHAR(l.request_id) request_id,

               l.pdf_file_url,

               l.office

          FROM ajcl_bc_ap_dm_lines l,

               ajcl_bc_ap_dm_headers h

         WHERE l.request_id = gv_request_id

           AND l.invoice_id = h.invoice_id 

           AND l.request_id = h.request_id

      ORDER BY DECODE(h.invoice_type_lookup_code,'STANDARD',1,'CREDIT',2),

               l.invoice_id,

               l.line_number;



      v_sheet := v_sheet + 1;

      ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Purchase Lines',

                                         p_sheet => v_sheet,

                                         p_cursor => c_cursor );



    ELSIF ( gv_export_type IN ( 'BC_PREVIEW','BC_SEND' ) ) THEN



        OPEN c_cursor FOR

      SELECT ( SELECT COUNT(1) FROM ajcl_bc_ap_dm_headers WHERE request_id = gv_request_id AND bc_environment = gv_bc_environment ) invoices_total_count,

             ( SELECT SUM(invoice_amount) FROM ajcl_bc_ap_dm_headers WHERE request_id = gv_request_id AND bc_environment = gv_bc_environment ) invoices_total_sum,

             ( SELECT SUM(amount) FROM ajcl_bc_ap_dm_lines WHERE request_id = gv_request_id AND bc_environment = gv_bc_environment ) lines_total_sum

        FROM DUAL;



      v_sheet := v_sheet + 1;

      ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Summary',

                                         p_sheet => v_sheet,

                                         p_cursor => c_cursor );



          OPEN c_cursor FOR     

        SELECT h.invoice_id,

               h.vendor_num,

               h.vendor_name,

               h.vendor_site_code,

               TO_CHAR(h.invoice_date,'YYYY-MM-DD') invoice_date,

               TO_CHAR(h.gl_date,'YYYY-MM-DD') posting_date,

               h.invoice_num,

               h.invoice_type_lookup_code,

               h.invoice_currency_code currency_code,

               -- TRIM(TO_CHAR(h.invoice_amount,'999,999,999.00')) invoice_amount,

               h.invoice_amount,

               h.terms_name,

               l.line_number line_num,

               l.description,

               -- TRIM(TO_CHAR(l.amount,'999,999,999.00')) line_amount,

               l.amount line_amount,

               l.worksheet worksheet_number,

               h.status status_inv,

               h.error_message err_msg_inv,

               l.error_message err_msg_lin

          FROM ajcl_bc_ap_dm_headers h,

               ajcl_bc_ap_dm_lines l

         WHERE h.request_id = gv_request_id

           AND h.bc_environment = gv_bc_environment

           AND h.request_id = l.request_id (+)

           AND h.bc_environment = l.bc_environment (+)

           AND h.invoice_id = l.invoice_id (+)

      ORDER BY h.vendor_num,

               h.invoice_num,

               l.line_number; 



      v_sheet := v_sheet + 1;

      ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Purchase Documents',

                                         p_sheet => v_sheet,

                                         p_cursor => c_cursor );



      /*

      IF ( gv_export_type = 'BC_PREVIEW' ) THEN



          -- Se crea solapa con los vendors que no existen en BC

            OPEN c_cursor FOR     

          SELECT vendor_num,

                 vendor_name

            FROM ( SELECT vendor_num,

                          vendor_name  

                     FROM ajcl_bc_ap_dm_headers h

                    WHERE request_id = gv_request_id

                      AND bc_environment = gv_bc_environment

                 GROUP BY vendor_num,

                          vendor_name )

           WHERE ajcl_bc_ws_utils_pkg.check_vendor_exists_bc_p ( p_bc_environment => gv_bc_environment,

                                                                 p_company_id => gv_bc_company_id,

                                                                 p_no => vendor_num ) = 'N'

        ORDER BY vendor_name;



        v_sheet := v_sheet + 1;

        ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Vendors Missing',

                                         p_sheet => v_sheet,

                                         p_cursor => c_cursor );                                         



      END IF;

      */



          -- Se crea solapa con los vendors que no existen en BC

          OPEN c_cursor FOR    

        SELECT vendor_num,

               vendor_name  

          FROM ajcl_bc_ap_dm_headers h

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND NOT EXISTS ( SELECT 1

                              FROM ajcl_bc_vendors_customers bcv

                             WHERE type = 'VENDOR' 

                               AND bcv.bc_environment = gv_bc_environment 

                               AND bcv.no = h.vendor_num )

      ORDER BY vendor_name;



      v_sheet := v_sheet + 1;

      ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Vendors Missing',

                                         p_sheet => v_sheet,

                                         p_cursor => c_cursor );    



          -- Se crea solapa con los payment terms de todas las facturas a migrar

          OPEN c_cursor FOR    

        SELECT terms_name 

          FROM ajcl_bc_ap_dm_headers 

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

      GROUP BY terms_name;



      v_sheet := v_sheet + 1;

      ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Payment Terms',

                                         p_sheet => v_sheet,

                                         p_cursor => c_cursor );       



    END IF;



    as_xlsx.save ( gv_directory_report, gv_report_filename || '.' || LOWER(gv_file_format) );



    print_log( 'ajcl_bc_ap_data_migration_pkg.final_report_xlsx_p (-)' );



  END final_report_xlsx_p;



  PROCEDURE worksheets_to_bc_p ( p_status   OUT   VARCHAR2 ) IS



      CURSOR c_worksheets IS

      SELECT worksheet dimValueCode

        FROM ajcl_bc_ap_dm_lines

       WHERE request_id = gv_request_id

         AND worksheet IS NOT NULL

    GROUP BY worksheet;



    v_url               VARCHAR2(2000); 

    v_body              VARCHAR2(2000);

    v_clob_result       CLOB;

    v_clob_job_result   CLOB;



    v_count             NUMBER := 0;

    v_job_object_id     NUMBER;



  BEGIN



    print_log( 'ajcl_bc_ap_data_migration_pkg.worksheets_to_bc_p (+)' );



    v_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => gv_bc_environment, 

                                                          p_entity => 'WORKSHEETS',

                                                          p_subentity => NULL,

                                                          p_method => 'POST',

                                                          p_company_id => gv_bc_company_id );



    FOR cw IN c_worksheets LOOP



      v_body := '{"requestID":"' || gv_request_id || '",' ||

                 '"dimValueCode":"' || cw.dimValueCode || '",' ||

                 '"dimValueName":"' || '' || '",' ||

                 '"blocked":false}';



      v_clob_result := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url,

                                                                  p_request_header_name1 => 'Content-Type',

                                                                  p_request_header_value1 => 'application/json',

                                                                  p_request_header_name2 => NULL,

                                                                  p_request_header_value2 => NULL,

                                                                  p_http_method => 'POST',

                                                                  p_body => v_body );  



      IF ( INSTR(v_clob_result,'error') != 0 ) THEN



        print_log ( 'WS: ' || cw.dimValueCode || ' - Error: ' || v_clob_result );



      ELSE



        print_log ( 'WS: ' || cw.dimValueCode || ' - Sent.' );

        v_count := v_count + 1;



      END IF;



    END LOOP;



    IF ( v_count > 0 ) THEN



      v_job_object_id := ajcl_bc_ws_utils_pkg.get_object_id_f ( p_integration => 'WORKSHEETS' );

      print_log ( 'object_id: ' || v_job_object_id || ' - ' || TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS') );



      v_clob_job_result := ajcl_bc_ws_utils_pkg.run_job_queue_f ( p_bc_environment => gv_bc_environment,

                                                                  p_company_id => gv_bc_company_id,

                                                                  p_object_id => v_job_object_id );



      print_log ( 'v_clob_job_result: ' || v_clob_job_result );



      IF ( INSTR(UPPER(v_clob_job_result),'ERROR') = 0 ) THEN 



        print_log ( 'Se ejecutó el job ProcessDimensionValuesAJC_INE con éxito.' );



      ELSE



         print_log ( 'Se produjo un error al ejecutar el job ProcessDimensionValuesAJC_INE.' );



      END IF;



    END IF;



    p_status := 'S';

    print_log( 'ajcl_bc_ap_data_migration_pkg.worksheets_to_bc_p (-)' );



  END worksheets_to_bc_p;



  PROCEDURE call_ws_p ( p_invoices_count   OUT   NUMBER,

                        --

                        p_status           OUT   VARCHAR2,

                        p_error_message    OUT   VARCHAR2 ) IS



      CURSOR c_headers IS

      SELECT *

        FROM ajcl_bc_ap_dm_headers 

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND status = 'NEW';



      CURSOR c_lines ( p_invoice_id   IN   NUMBER ) IS

      SELECT *

        FROM ajcl_bc_ap_dm_lines

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND invoice_id = p_invoice_id

         AND status = 'NEW'

    ORDER BY line_number;



    v_url_header           VARCHAR2(2000);      

    v_body_header          VARCHAR2(2000);

    v_clob_result_header   CLOB;



    v_url_line             VARCHAR2(2000);

    v_body_line            VARCHAR2(2000);

    v_clob_result_line     CLOB;



    v_linea_con_error      VARCHAR2(1);

    v_clob_result_job      CLOB;



    v_error_message        VARCHAR2(2000);



  BEGIN



    print_log('ajcl_bc_ap_data_migration_pkg.call_ws_p (+)');



    v_url_header := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => gv_bc_environment,

                                                                 p_entity => 'PURCHASE INVOICES',

                                                                 p_subentity => 'HEADERS',

                                                                 p_method => 'POST',

                                                                 p_company_id => gv_bc_company_id );



    print_log('v_url_header: ' || v_url_header);



    v_url_line := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => gv_bc_environment,

                                                               p_entity => 'PURCHASE INVOICES',

                                                               p_subentity => 'LINES',

                                                               p_method => 'POST',

                                                               p_company_id => gv_bc_company_id );



    -- print_log('v_url_line: ' || v_url_line);



    FOR ch IN c_headers LOOP



      print_log('invoice_num: ' || ch.invoice_num);



      v_linea_con_error := 'N';



      -- Se envian las líneas

      FOR cl IN c_lines ( p_invoice_id => ch.invoice_id ) LOOP



        -- Si hasta el momento, para el comprobante, no se produjo error en alguna linea, se continua enviando las siguientes

        IF ( v_linea_con_error = 'N' ) THEN



          print_log('line_number: ' || cl.line_number);



          APEX_JSON.initialize_clob_output;

          APEX_JSON.open_object;



          -- Se arma la linea

          APEX_JSON.write('invoiceID',TO_CHAR(ch.invoice_id));

          APEX_JSON.write('requestID',TO_CHAR(gv_request_id));

          APEX_JSON.write('lineNo',cl.line_number);

          APEX_JSON.write('amount',cl.amount);

          APEX_JSON.write('description', '', TRUE);

          APEX_JSON.write('accountingDate',TO_CHAR(NVL(gv_gl_date,cl.accounting_date),'YYYY-MM-DD'));

          APEX_JSON.write('periodName','', TRUE);

          APEX_JSON.write('worksheetNo',cl.worksheet, TRUE);

          APEX_JSON.write('baseAmount',0,TRUE); 

          APEX_JSON.write('exchangeRate',ch.exchange_rate, TRUE); 

          APEX_JSON.write('exchangeRateType',ch.exchange_rate_type, TRUE); 

          APEX_JSON.write('exchangeDate',ch.exchange_date, TRUE);

          APEX_JSON.write('organisationID',TO_CHAR(gv_org_id) );

          APEX_JSON.write('setOfBooksID',cl.set_of_books_id, TRUE); 

          APEX_JSON.write('setOfBooksName',cl.set_of_books_name); 

          APEX_JSON.write('distCodeCombination',TO_CHAR(cl.dist_code_combination_id));

          APEX_JSON.write('company',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,cl.account,'COMPANY',cl.company),TRUE);        

          APEX_JSON.write('account',cl.account); 

          APEX_JSON.write('accountDescription',cl.description, TRUE); -- Se envia la descripcion de la linea en Oracle

          APEX_JSON.write('department',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,cl.account,'DEPARTMENT',cl.department),TRUE);   

          APEX_JSON.write('product',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,cl.account,'PRODUCT',cl.product),TRUE);   

          APEX_JSON.write('intercompany',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,cl.account,'DIVISION',cl.division),TRUE);    

          APEX_JSON.write('destination',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,cl.account,'DESTINATION',cl.destination),TRUE);   

          APEX_JSON.write('office',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,cl.account,'OFFICE',cl.office),TRUE);   

          APEX_JSON.write('origin',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,cl.account,'ORIGIN',cl.origin),TRUE); 

          APEX_JSON.write('pdfFileUrl',cl.pdf_file_url, TRUE);



          APEX_JSON.close_object;



          v_body_line := APEX_JSON.get_clob_output;



          print_log('v_body_line: ' || v_body_line);                          



          v_clob_result_line := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url_line,

                                                                          p_request_header_name1 => 'Content-Type',

                                                                          p_request_header_value1 => 'application/json',

                                                                          p_request_header_name2 => NULL,

                                                                          p_request_header_value2 => NULL, 

                                                                          p_http_method => 'POST',

                                                                          p_body => v_body_line );  



          print_log('v_clob_result_line: ' || v_clob_result_line);



          APEX_JSON.free_output;



          IF ( UPPER(v_clob_result_line) LIKE UPPER('%ERROR%') ) THEN



            print_log('Error al enviar la línea del comprobante.');



            v_error_message := SUBSTR(v_clob_result_line,INSTR(v_clob_result_line,'message') + 10);



            print_log(v_error_message);



            UPDATE ajcl_bc_ap_dm_lines

               SET status = 'ERROR',

                   error_message = v_error_message,

                   json_data = v_body_line,

                   json_data_response = v_clob_result_line

             WHERE invoice_id = ch.invoice_id

               AND line_number = cl.line_number

               AND request_id = gv_request_id;



            v_linea_con_error := 'Y';



          ELSE



            UPDATE ajcl_bc_ap_dm_lines

               SET status = 'SENT',

                   error_message = NULL,

                   json_data = v_body_line,

                   json_data_response = v_clob_result_line

             WHERE invoice_id = ch.invoice_id

               AND line_number = cl.line_number

               AND request_id = gv_request_id;



            print_log('La línea se envió correctamente.');



          END IF;



        END IF;



      END LOOP;



      -- Si todas las lineas se enviaron sin problema

      IF ( v_linea_con_error = 'N' ) THEN



        v_error_message := NULL;



        -- Se envia la cabecera

        APEX_JSON.initialize_clob_output;

        APEX_JSON.open_object;



        APEX_JSON.write('requestID', TO_CHAR(gv_request_id));

        APEX_JSON.write('invoiceID',TO_CHAR(ch.invoice_id));

        APEX_JSON.write('invoiceNo',ch.invoice_num);

        APEX_JSON.write('invoiceType',ch.invoice_type_lookup_code);

        APEX_JSON.write('invoiceDate',TO_CHAR(ch.invoice_date,'YYYY-MM-DD'), TRUE);

        APEX_JSON.write('vendorNo',ch.vendor_num);

        APEX_JSON.write('vendorSiteCode', ch.vendor_site_code);

        APEX_JSON.write('invoiceAmount', ch.invoice_amount );

        APEX_JSON.write('invoiceCurrencyCode', ch.invoice_currency_code);

        APEX_JSON.write('exchangeRate', ch.exchange_rate, TRUE);

        APEX_JSON.write('exchangeRateType', ch.exchange_rate_type, TRUE);

        APEX_JSON.write('exchangeDate', ch.exchange_date, TRUE);

        APEX_JSON.write('baseAmount', 0, TRUE); 

        APEX_JSON.write('gLDate', TO_CHAR(NVL(gv_gl_date,TRUNC(SYSDATE)),'YYYY-MM-DD'));

        APEX_JSON.write('organisationID', TO_CHAR(gv_org_id));

        APEX_JSON.write('description', ch.description, TRUE);

        APEX_JSON.write('termName', ch.terms_name, TRUE);

        APEX_JSON.write('termsDate', TO_CHAR(ch.terms_date,'YYYY-MM-DD'), TRUE);

        APEX_JSON.write('paymentMethodCode', ch.payment_method_lookup_code, TRUE);

        APEX_JSON.write('payGroupCode', ch.pay_group_lookup_code,TRUE);

        APEX_JSON.write('setofBooksID', ch.set_of_books_id, TRUE);

        APEX_JSON.write('setofBooksName', ch.set_of_books_name, TRUE ); 

        APEX_JSON.write('company',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,ch.account,'COMPANY',ch.company),TRUE);    

        APEX_JSON.write('account', ch.account,TRUE ); 

        APEX_JSON.write('accountDescription',ch.account_description, TRUE);

        APEX_JSON.write('department',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,ch.account,'DEPARTMENT',ch.department),TRUE); 

        APEX_JSON.write('product',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,ch.account,'PRODUCT',ch.product),TRUE);

        APEX_JSON.write('destination',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,ch.account,'DESTINATION',ch.destination),TRUE);

        APEX_JSON.write('origin',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,ch.account,'ORIGIN',ch.origin),TRUE);

        APEX_JSON.write('source',ch.source, TRUE);

        APEX_JSON.write('office',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,ch.account,'OFFICE',ch.office),TRUE);

        APEX_JSON.write('pdfFileUrl',ch.pdf_file_url,TRUE);



        APEX_JSON.close_object;

        v_body_header := APEX_JSON.get_clob_output;



        print_log('v_body_header: ' || v_body_header);



        v_clob_result_header := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url_header,

                                                                          p_request_header_name1 => 'Content-Type',

                                                                          p_request_header_value1 => 'application/json',

                                                                          p_request_header_name2 => NULL,

                                                                          p_request_header_value2 => NULL, 

                                                                          p_http_method => 'POST',

                                                                          p_body => v_body_header );  





        print_log('v_clob_result_header: ' || v_clob_result_header);



        APEX_JSON.free_output;



        IF ( UPPER(v_clob_result_header) LIKE UPPER('%ERROR%') ) THEN



          print_log('Error al enviar la cabecera del comprobante.');



          v_error_message := SUBSTR(v_clob_result_header,INSTR(v_clob_result_header,'message') + 10);



          print_log(v_error_message);



          UPDATE ajcl_bc_ap_dm_headers

             SET status = 'ERROR',

                 error_message = v_error_message,

                 json_data = v_body_header,

                 json_data_response = v_clob_result_header,

                 last_update_date = TRUNC(SYSDATE)

           WHERE invoice_id = ch.invoice_id

             AND request_id = gv_request_id;



        ELSE



          UPDATE ajcl_bc_ap_dm_headers

             SET status = 'SENT',

                 json_data = v_body_header,

                 json_data_response = v_clob_result_header,

                 last_update_date = TRUNC(SYSDATE),

                 error_message = NULL

           WHERE invoice_id = ch.invoice_id 

             AND request_id = gv_request_id;



          print_log('El comprobante se envió correctamente.');



        END IF;



        p_invoices_count := NVL(p_invoices_count,0) + 1;



      ELSE



        UPDATE ajcl_bc_ap_dm_headers

           SET status = 'ERROR',

               error_message = 'Se produjo un error en alguna línea del comprobante.',

               last_update_date = TRUNC(SYSDATE)

         WHERE invoice_id = ch.invoice_id

           AND request_id = gv_request_id;



      END IF;



    END LOOP;



    p_status := 'S';

    print_log('ajcl_bc_ap_data_migration_pkg.call_ws_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_ap_data_migration_pkg.call_ws_p (!). Error: ' || SQLERRM);



  END call_ws_p;



  PROCEDURE call_job_p ( p_status          OUT   VARCHAR2,

                         p_error_message   OUT   VARCHAR2 ) IS



    v_job_object_id     NUMBER;

    v_status            VARCHAR2(20);

    v_error_message     VARCHAR2(2000);

    v_clob_response   CLOB;



  BEGIN



    print_log ('ajcl_bc_ap_data_migration_pkg.call_job_p (+)');



    v_job_object_id := ajcl_bc_ws_utils_pkg.get_object_id_f ( 'PURCHASE INVOICES' );

    print_log ( 'v_job_object_id: ' || v_job_object_id );



    v_clob_response := ajcl_bc_ws_utils_pkg.run_job_queue_f ( p_bc_environment => gv_bc_environment,

                                                              p_company_id => gv_bc_company_id,

                                                              p_object_id => v_job_object_id );



    IF ( INSTR(UPPER(v_clob_response),'SUCCESS') > 0 ) THEN



      print_log ( 'Se ejecutó el job Purchase Document con éxito.');

      v_status := 'SUCCESS';



    ELSE



      print_log ( 'Se produjo un error al ejecutar el job Purchase Document.');

      v_status := 'ERROR';



    END IF;



    -- Se inserta registro de control

    INSERT

      INTO ajcl_bc_ap_dm_control

           ( bc_environment,

             request_id,

             org_id,

             type,

             status,

             job_response,

             creation_date )

    VALUES ( gv_bc_environment,

             gv_request_id,

             gv_org_id,

             gv_type,

             v_status,

             v_clob_response,

             TRUNC(SYSDATE) );



    p_status := 'S';



    print_log ('ajcl_bc_ap_data_migration_pkg.call_job_p (-)');   



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      p_error_message := SQLERRM;

      print_log ('ajcl_bc_ap_data_migration_pkg.call_job_p (!). Error: ' || p_error_message);



  END call_job_p;



  PROCEDURE call_status_p ( p_status          OUT   VARCHAR2,

                            p_error_message   OUT   VARCHAR2 ) IS



    v_status               VARCHAR2(1);

    v_error_message        VARCHAR2(2000);



    v_get_url              VARCHAR2(2000);

    v_clob_result_status   CLOB;



    v_header_delete_url    VARCHAR2(2000);

    v_lines_delete_url     VARCHAR2(2000);



    v_header_delete_clob   CLOB;

    v_lines_delete_clob    CLOB;



    CURSOR c_status ( p_clob_result_status   IN   CLOB ) IS

    SELECT documentType,

           invoiceID,

           invoiceNo,

           invoiceType,

           invoiceDate,

           vendorNo,

           glDate,

           status,

           StatusRemarks,

           StatusTimeStamp,

           requestID

      FROM json_table( p_clob_result_status,

                       '$.value[*]' COLUMNS ( documentType     VARCHAR2(4000) path '$.documentType',

                                              invoiceID        VARCHAR2(4000) path '$.invoiceID' ,

                                              invoiceNo        VARCHAR2(4000) path '$.invoiceNo',

                                              invoiceType      VARCHAR2(4000) path '$.invoiceType',

                                              invoiceDate      VARCHAR2(4000) path '$.invoiceDate',

                                              vendorNo         VARCHAR2(4000) path '$.vendorNo',

                                              glDate           VARCHAR2(4000) path '$.gLDate',

                                              status           VARCHAR2(4000) path '$.status',

                                              StatusRemarks    VARCHAR2(4000) path '$.statusRemarks',

                                              StatusTimeStamp  VARCHAR2(4000) path '$.statusTimestamp',

                                              requestID        VARCHAR2(4000) path '$.requestID'));



  BEGIN



    print_log ('ajcl_bc_ap_data_migration_pkg.call_status_p (+)');



    v_get_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => gv_bc_environment,

                                                              p_entity => 'PURCHASE INVOICES',

                                                              p_subentity => 'STATUS',

                                                              p_method => 'GET',

                                                              p_company_id => gv_bc_company_id ) 

                 || '?$filter=requestID eq ' || gv_request_id;



    print_log ( 'v_get_url: ' || v_get_url );



    v_clob_result_status := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );



    FOR cs IN c_status ( v_clob_result_status ) LOOP



      IF ( UPPER(cs.status) != 'SUCCESS' ) THEN



        print_log ( 'documentType: ' || cs.documentType || 

                    '|invoiceNo: ' || cs.invoiceNo || 

                    '|invoiceType: ' || cs.invoiceType || 

                    '|invoiceDate: ' || cs.invoiceDate || 

                    '|vendorNo: ' || cs.vendorNo || 

                    '|glDate: ' || cs.glDate || 

                    '|status: ' || cs.status || 

                    '|statusRemarks: ' || cs.statusRemarks );



        -- Se actualiza la tabla custom con el status REJECTED

        UPDATE AJCL_BC_AP_DM_HEADERS 

           SET status = 'REJECTED',

               error_message = cs.statusRemarks,

               last_update_date = TRUNC(SYSDATE)

         WHERE request_id = gv_request_id

           AND invoice_id = cs.invoiceID;



        UPDATE ajcl_bc_ap_dm_lines

           SET status = 'REJECTED',

               last_update_date = TRUNC(SYSDATE),

               error_message = NULL

         WHERE request_id = gv_request_id

           AND invoice_id = cs.invoiceID;



        v_lines_delete_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => gv_bc_environment,

                                                                           p_entity => 'PURCHASE INVOICES',

                                                                           p_subentity => 'LINES',

                                                                           p_method => 'DELETE',

                                                                           p_company_id => gv_bc_company_id ) 

                               || '(''' || cs.invoiceID || ''',0,0)'; -- invoice id, request id, line no



        print_log ( 'v_lines_delete_url: ' || v_lines_delete_url );



        -- Se borran las lineas de la tabla staging

        v_lines_delete_clob := ajcl_bc_ws_utils_pkg.delete_bc_row_f ( p_url => v_lines_delete_url );



        IF ( INSTR(UPPER(v_lines_delete_clob),'ERROR') != 0 )  THEN



          print_log('Error al borrar lineas de la tabla stage de BC');

          print_log(v_lines_delete_clob);



        ELSE



          print_log('Lineas borradas de la tabla stage de BC');



        END IF;  



        v_header_delete_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => gv_bc_environment,

                                                                            p_entity => 'PURCHASE INVOICES',

                                                                            p_subentity => 'HEADERS',

                                                                            p_method => 'DELETE',

                                                                            p_company_id => gv_bc_company_id ) 

                                || '(''' || cs.invoiceID || ''',0)'; -- invoice id, request id



        print_log ( 'v_header_delete_url: ' || v_header_delete_url );



        -- Se borra la cabecera de la tabla staging

        v_header_delete_clob := ajcl_bc_ws_utils_pkg.delete_bc_row_f ( p_url => v_header_delete_url );



        IF ( INSTR(UPPER(v_header_delete_clob),'ERROR') != 0 )  THEN



          print_log('Error al borrar cabecera de la tabla stage de BC');

          print_log(v_header_delete_clob);



        ELSE



          print_log('Cabecera borrada de la tabla stage de BC');



        END IF; 



      ELSE



        -- Se actualiza la tabla custom con el status SUCCESS

        UPDATE ajcl_bc_ap_dm_headers

           SET status = 'SUCCESS',

               last_update_date = TRUNC(SYSDATE),

               error_message = NULL

         WHERE request_id = gv_request_id

           AND invoice_id = cs.invoiceID;



        UPDATE ajcl_bc_ap_dm_lines

           SET status = 'SUCCESS',

               last_update_date = TRUNC(SYSDATE),

               error_message = NULL

         WHERE request_id = gv_request_id

           AND invoice_id = cs.invoiceID;



      END IF;



    END LOOP;  



    p_status := 'S';

    print_log ('ajcl_bc_ap_data_migration_pkg.call_status_p (-)');   



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_ap_data_migration_pkg.call_status_p (!). Error: ' || SQLERRM);



  END call_status_p;



  PROCEDURE main_bc_p ( p_status          OUT   VARCHAR2,

                        p_error_message   OUT   VARCHAR2 ) IS



    v_invoices_count   NUMBER;



    v_status           VARCHAR2(1);

    v_error_message    VARCHAR2(1000);



    v_phase            VARCHAR2(100);

    e_error            EXCEPTION;



  BEGIN



    print_log ( 'ajcl_bc_ap_data_migration_pkg.main_bc_p (+)' );



    worksheets_to_bc_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'worksheets_to_bc_p';

      RAISE e_error;



    END IF;



    call_ws_p ( p_invoices_count => v_invoices_count,

                --

                p_status => v_status,

                p_error_message => v_error_message );



    IF ( v_status != 'S' ) THEN



      v_phase := 'call_ws_p';

      RAISE e_error;



    END IF;



    IF ( v_invoices_count > 0 ) THEN



      call_job_p ( p_status => v_status,

                   p_error_message => v_error_message );



      IF ( v_status != 'S' ) THEN



        v_phase := 'call_job_p';

        RAISE e_error;



      END IF;  



      call_status_p ( p_status => v_status,

                      p_error_message => v_error_message );



      IF ( v_status != 'S' ) THEN



        v_phase := 'call_status_p';

        RAISE e_error;



      END IF;                     



    END IF;



    p_status := 'S';

    print_log( 'ajcl_bc_ap_data_migration_pkg.main_bc_p (-)' );



  EXCEPTION

    WHEN e_error THEN

      p_status := 'E'; 

      print_log ( 'phase: ' || v_phase );

      print_log ( 'ajcl_bc_ap_data_migration_pkg.main_bc_p (!). Error: ' || v_error_message );



    WHEN OTHERS THEN

      p_status := 'E';    

      print_log ( 'ajcl_bc_ap_data_migration_pkg.main_bc_p (!). Error: ' || SQLERRM );



  END main_bc_p; 



  PROCEDURE main_p ( p_bc_environment         IN    VARCHAR2,

                     p_accounting_date_to     IN    VARCHAR2,

                     p_gl_date                IN    VARCHAR2,

                     p_invoice_num_prefix     IN    VARCHAR2,

                     p_invoice_num_type       IN    VARCHAR2,

                     p_export_type            IN    VARCHAR2,

                     p_type                   IN    VARCHAR2,

                     p_migration_type         IN    VARCHAR2,

                     p_jenkins_build_number   IN    VARCHAR2 ) IS



      v_company                   gl_code_combinations.segment1%type;

      v_company_get               VARCHAR2(200);

      v_bc_invoice_num            VARCHAR2(20);

      v_invoice_distribution_id   ap_invoice_distributions_all.invoice_distribution_id%TYPE;

      v_worksheet                 ap_invoice_distributions_all.attribute1%TYPE;

      v_dist_code_combination_id  NUMBER;



      v_line_error                VARCHAR2(1);

      v_vendor_site_code          po_vendor_sites_all.vendor_site_code%TYPE;



      v_status                    VARCHAR2(1);

      v_error_message             VARCHAR2(2000);

      e_cust_exception            EXCEPTION;

      e_parameter_value           EXCEPTION;

      e_main_bc                   EXCEPTION;



      CURSOR c_invoice_id IS

      -- TRIAL BALANCE

      SELECT ai.invoice_id,

             SUM(trial_balance.remaining_amount_ic) balance

        FROM ( SELECT alb.org_id org_id,

                      alb.set_of_books_id books,

                      alb.code_combination_id code_combination_id,

                      alb.vendor_id vendor_id,

                      alb.invoice_id invoice_id,

                      SUM(alb.accounted_cr) - SUM(alb.accounted_dr) remaining_amount_fc,

                      SUM(alb.ae_invoice_amount) invoice_amount,

                      SUM(NVL(aal.entered_cr,0)) - SUM(NVL(aal.entered_dr,0)) remaining_amount_ic      

                 FROM ap_liability_balance alb,

                      ap_ae_lines_all aal

                WHERE aal.ae_line_id = alb.ae_line_id        

                  AND aal.ae_header_id = alb.ae_header_id

                  AND TRUNC(alb.accounting_date) <= gv_accounting_date_to

                  AND alb.set_of_books_id = gv_set_of_books_id

             GROUP BY alb.org_id,

                      alb.set_of_books_id,

                      alb.code_combination_id,

                      alb.vendor_id,

                      alb.invoice_id

               HAVING SUM(alb.accounted_cr) <> SUM(alb.accounted_dr)

                  AND SUM(NVL(aal.entered_cr,0)) <> SUM(NVL(aal.entered_dr,0)) ) trial_balance,

              hr_all_organization_units haou,

              po_vendors pv,

              po_vendors1_dfv pvd,

              ap_invoices_all ai,

              ap_invoices_all2_dfv aiad,

              gl_code_combinations_kfv gcc

        WHERE trial_balance.org_id = haou.organization_id

          AND trial_balance.vendor_id = pv.vendor_id

          AND ai.invoice_id = trial_balance.invoice_id

          AND trial_balance.code_combination_id = gcc.code_combination_id

          AND ai.org_id = gv_org_id

          AND pv.rowid = pvd.row_id  

          AND ai.rowid = aiad.row_id

          AND gv_type = 'TRIAL BALANCE'

          -- Se agrega porque ya se hizo el envio, para no volver a enviar

          AND 1 = 2

          -- Se agrega porque ya se hizo el envio, para no volver a enviar

          AND NOT EXISTS ( SELECT 1

                             FROM ajcl_bc_ap_dm_headers bcaph 

                            WHERE bcaph.invoice_id = ai.invoice_id

                              AND type = gv_type

                              AND bc_environment = gv_bc_environment )

     GROUP BY ai.invoice_id         

        UNION

      -- AGING

      SELECT ai.invoice_id,

             aps.amount_remaining balance

        FROM ap_invoices_all ai,

             ap_payment_schedules_all aps,

             po_vendors pv,

             po_vendor_sites_all pvs

       WHERE ai.invoice_id = aps.invoice_id

         AND ai.org_id = gv_org_id

         AND ai.vendor_id = pv.vendor_id

         AND ai.vendor_id = pvs.vendor_id

         AND ai.vendor_site_id = pvs.vendor_site_id

         AND ai.cancelled_date IS NULL

         AND ai.payment_status_flag IN ('N','P')

         AND ai.invoice_type_lookup_code NOT IN ('PREPAYMENT')

         AND ( NVL(aps.amount_remaining,0) * NVL(ai.exchange_rate,1) ) != 0

         AND gv_type = 'AGING'

         -- Se agrega porque ya se hizo el envio, para no volver a enviar

         AND 1 = 2

          -- Se agrega porque ya se hizo el envio, para no volver a enviar

         -- QUITAR

         /*

         AND ai.invoice_num IN ('941703778',

                                '1685847-000',

                                '656832433',

                                'DSAV1730411227',

                                'VSSL001227085/A',

                                'YBM-233271',

                                '20-164415-2',

                                'CLU111900M',

                                'TINY14420',

                                '0117546')

         AND ai.invoice_num IN ('FEX120',

                                '969188',

                                '21040',

                                '40-020035',

                                '50601275XH14',

                                '594MGBEXTRA24',

                                '394899',

                                '2845497',

                                'INV-4640090',

                                'SI226077')

         */

         -- AND ai.invoice_num = '2148023-000'

         -- AND ai.invoice_num = '573223210361'

         -- QUITAR

         AND NOT EXISTS ( SELECT alb.org_id org_id,

                                 alb.set_of_books_id books,

                                 alb.code_combination_id code_combination_id,

                                 alb.vendor_id vendor_id,

                                 alb.invoice_id invoice_id,

                                 SUM(alb.accounted_cr) - SUM(alb.accounted_dr) remaining_amount_fc,

                                 SUM(alb.ae_invoice_amount) invoice_amount,

                                 SUM(NVL(aal.entered_cr,0)) - SUM(NVL(aal.entered_dr,0)) remaining_amount_ic      

                            FROM ap_liability_balance alb,

                                 ap_ae_lines_all aal

                           WHERE aal.ae_line_id = alb.ae_line_id        

                             AND aal.ae_header_id = alb.ae_header_id

                             AND TRUNC(alb.accounting_date) <= gv_accounting_date_to

                             AND alb.set_of_books_id = gv_set_of_books_id

                             AND alb.invoice_id = ai.invoice_id

                        GROUP BY alb.org_id,

                                 alb.set_of_books_id,

                                 alb.code_combination_id,

                                 alb.vendor_id,

                                 alb.invoice_id

                          HAVING SUM(alb.accounted_cr) <> SUM(alb.accounted_dr)

                             AND SUM(NVL(aal.entered_cr,0)) <> SUM(NVL(aal.entered_dr,0)) )

         AND NOT EXISTS ( SELECT 1

                            FROM ajcl_bc_ap_dm_headers bcaph 

                           WHERE bcaph.invoice_id = ai.invoice_id

                             AND type = gv_type

                             AND bc_environment = gv_bc_environment );



    CURSOR c_headers ( p_invoice_id           IN   NUMBER,

                       p_amount               IN   NUMBER ) IS

    -- TRIAL BALANCE

    SELECT ai.invoice_id,

           ai.invoice_num,

           CASE

             WHEN p_amount < 0 THEN

               'CREDIT'

             ELSE

               'STANDARD'

           END invoice_type_lookup_code,    

           -- NVL(aiad.legal_transaction_category,upper(ai.invoice_type_lookup_code)) invoice_type_lookup_code,

           ai.invoice_date, 

           ai.vendor_id,

           pv.segment1 vendor_num,

           pv.vendor_name vendor_name,

           ai.vendor_site_id,

           vs.vendor_site_code,

           vs.accts_pay_code_combination_id,

           ABS(p_amount) invoice_amount,

           ai.invoice_currency_code,

           --

           ai.exchange_rate,

           ai.exchange_rate_type,

           ai.exchange_date,

           ai.terms_id,

           SUBSTR(t.name,1,10) terms_name,

           ai.invoice_date terms_date,

           SUBSTR(ai.description,1,50) description,

           ai.payment_method_lookup_code,

           ai.pay_group_lookup_code,

           gv_gl_date gl_date,

           ai.org_id,

           ai.set_of_books_id,

           sob.name set_of_books_name,

           '2105.2000' account,

           'ACCOUNTS PAYABLE-TRADE' account_description,

           NULL department,

           NULL product,

           NULL destination,

           NULL office,

           NULL origin,

           NULL division,

           NVL( ( SELECT file_name

                    FROM FND_ATTACHED_DOCS_FORM_VL

                   WHERE function_name = DECODE(0,1,NULL,'APXINWKB') 

                     AND function_type = DECODE(0,1,NULL,'O')

                     AND ( security_type = 4 OR publish_flag = 'Y' OR ( security_type = 2 and security_id = 1 ) )

                     AND entity_name = 'AP_INVOICES' 

                     AND datatype_name = 'Web Page'

                     AND pk1_value = TO_CHAR(ai.invoice_id)

                     AND rownum = 1 ),

             'http://datamigration') pdffileurl,

           gv_source source

           --

      FROM ( SELECT alb.org_id org_id,

                    alb.set_of_books_id books,

                    alb.code_combination_id code_combination_id,

                    alb.vendor_id vendor_id,

                    alb.invoice_id invoice_id,

                    SUM(alb.accounted_cr) - SUM(alb.accounted_dr) remaining_amount_fc,

                    SUM(alb.ae_invoice_amount) invoice_amount,

                    SUM(NVL(aal.entered_cr,0)) - SUM(NVL(aal.entered_dr,0)) remaining_amount_ic      

               FROM ap_liability_balance alb,

                    ap_ae_lines_all aal

              WHERE aal.ae_line_id = alb.ae_line_id        

                AND aal.ae_header_id = alb.ae_header_id

                AND TRUNC(alb.accounting_date) <= gv_accounting_date_to

                AND alb.set_of_books_id = gv_set_of_books_id

           GROUP BY alb.org_id,

                    alb.set_of_books_id,

                    alb.code_combination_id,

                    alb.vendor_id,

                    alb.invoice_id

             HAVING SUM(alb.accounted_cr) <> SUM(alb.accounted_dr)

                AND SUM(NVL(aal.entered_cr,0)) <> SUM(NVL(aal.entered_dr,0)) ) trial_balance,

            hr_all_organization_units haou,

            po_vendors pv,

            po_vendors1_dfv pvd,

            po_vendor_sites_all vs,

            ap_invoices_all ai,

            ap_invoices_all2_dfv aiad,

            gl_code_combinations_kfv gcc,

            ap_terms_tl t,

            gl_sets_of_books sob

      WHERE ai.invoice_id = p_invoice_id

        AND trial_balance.org_id = haou.organization_id

        AND trial_balance.vendor_id = pv.vendor_id

        AND ai.invoice_id = trial_balance.invoice_id

        AND ai.vendor_site_id = vs.vendor_site_id

        AND trial_balance.code_combination_id = gcc.code_combination_id

        AND pv.rowid = pvd.row_id  

        AND ai.rowid = aiad.row_id

        AND gv_type = 'TRIAL BALANCE'

        AND ai.terms_id = t.term_id

        AND ai.set_of_books_id = sob.set_of_books_id

      UNION 

    -- AGING

    SELECT ai.invoice_id,

           ai.invoice_num,

           -- ai.invoice_type_lookup_code,

           CASE

             WHEN p_amount < 0 THEN

               'CREDIT'

             ELSE

               'STANDARD'

           END invoice_type_lookup_code,

           --

           ai.invoice_date, 

           ai.vendor_id,

           v.segment1 vendor_num,

           v.vendor_name,

           ai.vendor_site_id,

           vs.vendor_site_code,

           vs.accts_pay_code_combination_id,

           ABS(p_amount) invoice_amount,

           ai.invoice_currency_code,

           ai.exchange_rate,

           ai.exchange_rate_type,

           ai.exchange_date,

           ai.terms_id,

           SUBSTR(t.name,1,10) terms_name,

           ai.invoice_date terms_date,

           SUBSTR(ai.description,1,50) description,

           ai.payment_method_lookup_code,

           ai.pay_group_lookup_code,

           gv_gl_date gl_date,

           ai.org_id,

           ai.set_of_books_id,

           sob.name set_of_books_name,

           '2105.2000' account,

           'ACCOUNTS PAYABLE-TRADE' account_description,

           NULL department,

           NULL product,

           NULL destination,

           NULL office,

           NULL origin,

           NULL division,

           NVL ( ( SELECT file_name

                     FROM FND_ATTACHED_DOCS_FORM_VL

                    WHERE function_name = DECODE(0,1,NULL,'APXINWKB') 

                      AND function_type = DECODE(0,1,NULL,'O')

                      AND ( security_type = 4 OR publish_flag = 'Y' OR ( security_type = 2 and security_id = 1 ) )

                      AND entity_name = 'AP_INVOICES' 

                      AND datatype_name = 'Web Page'

                      AND pk1_value = TO_CHAR(ai.invoice_id)

                      AND rownum = 1 ),

             'http://datamigration') pdffileurl,

           gv_source source

      FROM ap_invoices_all ai,

           po_vendors v,

           po_vendor_sites_all vs,

           gl_sets_of_books sob,

           ap_terms_tl t

     WHERE invoice_id = p_invoice_id

       AND ai.vendor_id = v.vendor_id

       AND ai.vendor_site_id = vs.vendor_site_id

       AND ai.set_of_books_id = sob.set_of_books_id

       AND ai.terms_id = t.term_id (+)

       AND gv_type = 'AGING';



    CURSOR c_lines ( p_invoice_id        IN   NUMBER,

                     p_invoice_amount    IN   NUMBER,

                     p_description       IN   VARCHAR2,

                     p_set_of_books_id   IN   NUMBER,

                     p_sob_name          IN   VARCHAR2,

                     p_company           IN   VARCHAR2 ) IS

    -- Para TRIAL BALANCE se arma una sola línea

    SELECT p_invoice_id invoice_id,

           NULL invoice_distribution_id,

           1 distribution_line_number,

           ABS(p_invoice_amount) amount,

           gv_gl_date accounting_date,

           SUBSTR(p_description,1,50) description,

           NULL worksheet,

           p_set_of_books_id set_of_books_id,

           p_sob_name set_of_books_name,

           p_company company,

           '2105.2000' account, 

           'ACCOUNTS PAYABLE-TRADE' account_description,

           NULL department, 

           NULL product,

           NULL destination,

           NULL office,

           NULL origin,

           NULL division,

           NULL attachment

      FROM DUAL

     WHERE gv_type = 'TRIAL BALANCE'

     UNION

    SELECT aid.invoice_id,

           aid.invoice_distribution_id,

           aid.distribution_line_number,

           ABS(aid.amount) amount,

           gv_gl_date accounting_date,

           SUBSTR(aid.description,1,50) description,

           aid.attribute1 worksheet,

           aid.set_of_books_id set_of_books_id,

           sob.name set_of_books_name,

           p_company company,

           CASE

             WHEN bca.bc_account = '9105.ZERO' THEN

               '9105.9890'

             ELSE

               bca.bc_account

           END account, 

           CASE

             WHEN bca.bc_account = '9105.ZERO' THEN

               'ZERO ACCOUNT'

             ELSE

               bca.description 

           END account_description,

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,bca.bc_account,'DEPARTMENT',gcc.segment3) department, 

           NULL product,

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,bca.bc_account,'DESTINATION',gcc.segment5) destination,

           NULL office,

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,bca.bc_account,'ORIGIN',gcc.segment6) origin,

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,bca.bc_account,'DIVISION',

           NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4',

                                                          p_oracle_value => gcc.segment4,

                                                          p_bc_dimension => 'DIVISION'),'000') ) division,

           NULL attachment

      FROM ap_invoice_distributions_all aid,

           gl_sets_of_books sob,

           gl_code_combinations gcc,

           ajc_bc_accounts bca

     WHERE aid.invoice_id = p_invoice_id

       AND aid.set_of_books_id = sob.set_of_books_id

       AND gv_type = 'AGING'

       AND aid.dist_code_combination_id = gcc.code_combination_id

       AND gcc.segment2 = bca.oracle_account (+);



  BEGIN



    gv_request_id := ajcl_bc_utils_pkg.get_request_id_f;

    gv_jenkins_build_number := p_jenkins_build_number;



    DELETE ajcl_bc_logs

     WHERE ifc = gv_bc_ifc;



    COMMIT;



    print_log ( 'ajcl_bc_ap_data_migration_pkg.main_p (+)');



    print_log ( 'gv_request_id: ' || gv_request_id );

    print_log ( 'gv_bc_ifc: ' || gv_bc_ifc );

    print_log ( 'gv_jenkins_build_number: ' || gv_jenkins_build_number );



    gv_oracle_db := ajcl_bc_utils_pkg.get_db_name_f;

    print_log ( 'gv_oracle_db: ' || gv_oracle_db );



    print_log ( 'gv_report_filename: ' || gv_report_filename );



    print_log ( 'p_bc_environment: ' || p_bc_environment );

    print_log ( 'p_accounting_date_to: ' || p_accounting_date_to );

    print_log ( 'p_gl_date: ' || p_gl_date );

    print_log ( 'p_invoice_num_prefix: ' || p_invoice_num_prefix );

    print_log ( 'p_invoice_num_type: ' || p_invoice_num_type );

    print_log ( 'p_export_type: ' || p_export_type );

    print_log ( 'p_type: ' || p_type );

    print_log ( 'p_migration_type: ' || p_migration_type );    



    -- Se obtienen los parametros de la company 

    print_log ( 'gv_bc_company_name: ' || gv_bc_company_name );



    gv_bc_company_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                     p_column => 'BC_COMPANY_ID' );



    print_log ( 'gv_bc_company_id: ' || gv_bc_company_id );



    gv_org_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                              p_column => 'ORG_ID' );



    print_log ( 'gv_org_id: ' || gv_org_id );



    gv_set_of_books_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                       p_column => 'SET_OF_BOOKS_ID' );



    print_log ( 'gv_set_of_books_id: ' || gv_set_of_books_id );



    gv_resp_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                               p_column => 'AP_RESP_ID' );



    print_log ( 'gv_resp_id: ' || gv_resp_id );



    fnd_global.apps_initialize ( user_id => 0,

                                 resp_id => gv_resp_id,

                                 resp_appl_id => 200 ); -- SQLAP



    mo_global.set_policy_context ('S', gv_org_id);                                 



    -- Validacion parametro p_bc_environment -----------------------------------------------------------------------------------

    IF ( ajcl_bc_utils_pkg.is_bc_environment_valid_f ( p_bc_environment ) = 'N' ) THEN



      v_error_message := 'Invalid value (' || p_bc_environment || ') for parameter BC_ENVIRONMENT.';

      RAISE e_parameter_value;



    END IF;



    gv_bc_environment := p_bc_environment;

    print_log ( 'gv_bc_environment: ' || gv_bc_environment );



    -- Validacion parametro p_accounting_date_to -------------------------------------------------------------------------------

    -- Validacion para cuando el parametro en jenkins es tipo date y llega como varchar2

    IF ( p_accounting_date_to IS NOT NULL ) THEN 



      BEGIN



        gv_accounting_date_to := TO_DATE(p_accounting_date_to,'YYYY-MM-DD');



      EXCEPTION

        WHEN OTHERS THEN

          v_error_message := 'Error: ' || SUBSTR(SQLERRM,INSTR(SQLERRM,':') + 2) || ' (' || p_accounting_date_to || ')';

          RAISE e_parameter_value;



      END;



    END IF;



    print_log ( 'gv_accounting_date_to: ' || gv_accounting_date_to );



    -- Validacion parametro p_gl_date ------------------------------------------------------------------------------------------

    -- Validacion para cuando el parametro en jenkins es tipo date y llega como varchar2

    IF ( p_gl_date IS NOT NULL ) THEN 



      BEGIN



        gv_gl_date := TO_DATE(p_gl_date,'YYYY-MM-DD');



      EXCEPTION

        WHEN OTHERS THEN

          v_error_message := 'Error: ' || SUBSTR(SQLERRM,INSTR(SQLERRM,':') + 2) || ' (' || p_gl_date || ')';

          RAISE e_parameter_value;



      END;



    END IF;



    print_log ( 'gv_gl_date: ' || gv_gl_date );



    gv_invoice_num_prefix := p_invoice_num_prefix;

    print_log ( 'gv_invoice_num_prefix: ' || gv_invoice_num_prefix );



    gv_invoice_num_type := p_invoice_num_type;

    print_log ( 'gv_invoice_num_type: ' || gv_invoice_num_type );    



    gv_export_type := p_export_type;

    print_log ( 'gv_export_type: ' || gv_export_type );



    gv_type := p_type;

    print_log ( 'gv_type: ' || gv_type );



    gv_migration_type := p_migration_type;

    print_log ( 'gv_migration_type: ' || gv_migration_type );



    -- Comentar si no se quiere que se borre, sirve para cuando hay que reprocesar algo de otro request_id

    IF ( gv_migration_type = 'ALL' ) THEN



      DELETE ajcl_bc_ap_dm_headers WHERE type = p_type AND bc_environment = gv_bc_environment;

      print_log ( 'Se borra la tabla ajcl_bc_ap_dm_headers para el type ' || p_type || ' y bc_environment ' || gv_bc_environment || '. Cantidad registros borrados: ' || SQL%ROWCOUNT ); 



      DELETE ajcl_bc_ap_dm_lines WHERE type = p_type AND bc_environment = gv_bc_environment;

      print_log ( 'Se borra la tabla ajcl_bc_ap_dm_lines para el type ' || p_type || ' y bc_environment ' || gv_bc_environment || '. Cantidad registros borrados: ' || SQL%ROWCOUNT ); 



      DELETE ajcl_bc_ap_dm_control WHERE type = p_type AND bc_environment = gv_bc_environment;

      print_log ( 'Se borra la tabla ajcl_bc_ap_dm_control para el type ' || p_type || ' y bc_environment ' || gv_bc_environment || '. Cantidad registros borrados: ' || SQL%ROWCOUNT ); 



      COMMIT;



    END IF;



    -- Get Vendors from BC

    ajcl_bc_get_entities_pkg.get_bc_vendors_p ( p_bc_environment => gv_bc_environment,

                                                p_bc_ifc => gv_bc_ifc,

                                                p_request_id => gv_request_id,

                                                p_log_seq => gv_log_seq,

                                                p_status => v_status );



    IF ( v_status != 'S' ) THEN



      RAISE e_cust_exception;



    END IF;

    -- 



    FOR ciid IN c_invoice_id LOOP



      FOR ch IN c_headers ( ciid.invoice_id, 

                            ciid.balance ) LOOP



        BEGIN



          -- Generate BC Invoice Num

          BEGIN



            v_bc_invoice_num := SUBSTR(gv_invoice_num_prefix || REPLACE(ch.invoice_num,'Withholding Tax - ','WHT'),1,20);



          EXCEPTION

            WHEN OTHERS THEN

              v_bc_invoice_num := NULL;

              print_log(gv_invoice_num_prefix || REPLACE(ch.invoice_num,'Withholding Tax - ','WHT'));

              print_log(SQLERRM);



          END;          



          -- Get Company

          BEGIN



            v_company := NULL;

            v_company_get := NULL;



            SELECT gcc.segment1,

                   gcc.code_combination_id

              INTO v_company,

                   v_dist_code_combination_id

              FROM ap_invoice_distributions_all aid,

                   gl_code_combinations gcc

             WHERE aid.dist_code_combination_id = gcc.code_combination_id

               AND aid.invoice_id = ciid.invoice_id

               AND aid.invoice_distribution_id = ( SELECT MIN(invoice_distribution_id)

                                                     FROM ap_invoice_distributions_all aid2

                                                    WHERE aid2.invoice_id = aid.invoice_id );



            v_company_get := 'distribution';



          EXCEPTION

            WHEN OTHERS THEN



              BEGIN



                SELECT gcc.segment1,

                       gcc.code_combination_id

                  INTO v_company,

                       v_dist_code_combination_id

                  FROM gl_code_combinations gcc

                 WHERE gcc.code_combination_id = ch.accts_pay_code_combination_id;



                v_company_get := 'site';



              EXCEPTION

                WHEN OTHERS THEN

                  v_company_get := 'default';

                  print_log('Se obtiene la company del default.');  

                  v_company := '53';

                  v_dist_code_combination_id := 66197;



              END;



          END;



          print_log ( 'invoice_id: ' || ciid.invoice_id || ' | balance: ' || ciid.balance || ' | invoice_num: ' || ch.invoice_num || ' | vendor: ' || ch.vendor_name || ' | company: ' || v_company || ' (' || v_company_get || ')');



          v_line_error := 'N';



          FOR cl IN c_lines ( ciid.invoice_id, 

                              ch.invoice_amount,

                              ch.description,

                              ch.set_of_books_id,

                              ch.set_of_books_name,

                              v_company ) LOOP



            v_worksheet := NULL;

            v_invoice_distribution_id := NULL;



            -- Se obtiene el invoice_distribution_id y worksheet de la primera linea, si tiene

            IF ( gv_type = 'TRIAL BALANCE' ) THEN



              BEGIN



                SELECT aid.invoice_distribution_id,

                       aid.attribute1

                  INTO v_invoice_distribution_id,

                       v_worksheet

                  FROM ap_invoice_distributions_all aid

                 WHERE aid.invoice_id = ciid.invoice_id

                   AND invoice_distribution_id = ( SELECT MIN(invoice_distribution_id)

                                                     FROM ap_invoice_distributions_all aid2

                                                    WHERE aid2.invoice_id = ciid.invoice_id );



                IF ( v_worksheet = 'NA' OR v_worksheet IS NULL ) THEN



                  v_worksheet := 'N/A';



                END IF;



              EXCEPTION

                WHEN OTHERS THEN

                  v_worksheet := 'N/A';

                  v_invoice_distribution_id := NULL;



              END;



            ELSIF ( gv_type = 'AGING' ) THEN



              v_invoice_distribution_id := cl.invoice_distribution_id;

              v_worksheet := cl.worksheet;



            END IF;



            BEGIN



              -- Lines

              INSERT 

                INTO ajcl_bc_ap_dm_lines

                   ( invoice_id,

                     invoice_distribution_id,

                     line_number,

                     amount,

                     accounting_date,

                     description,

                     worksheet,

                     set_of_books_id,

                     set_of_books_name,

                     company,

                     dist_code_combination_id,

                     account,

                     account_description,

                     department,

                     product,

                     destination,

                     office,

                     origin,

                     division,

                     type,

                     --

                     last_updated_by,

                     last_update_date,

                     last_update_login,

                     created_by,

                     creation_date,

                     pdf_file_url,

                     status,

                     request_id,

                     bc_environment )

            VALUES ( cl.invoice_id,

                     v_invoice_distribution_id,

                     cl.distribution_line_number,

                     cl.amount,

                     cl.accounting_date,

                     cl.description,

                     v_worksheet,

                     cl.set_of_books_id,

                     cl.set_of_books_name,

                     cl.company,

                     v_dist_code_combination_id,

                     cl.account,

                     cl.account_description,

                     cl.department,

                     cl.product,

                     cl.destination,

                     cl.office,

                     cl.origin,

                     cl.division,

                     p_type,

                     gv_user_id,

                     TRUNC(SYSDATE),

                     gv_user_id,

                     gv_user_id,

                     TRUNC(SYSDATE),

                     cl.attachment,

                     'NEW', -- status

                     gv_request_id,

                     gv_bc_environment );



            EXCEPTION

              WHEN OTHERS THEN

                v_line_error := 'Y';

                print_log ( 'Se produjo un error al insertar una línea del comprobante. Error: ' || SQLERRM );



            END;



          END LOOP;



          IF ( v_line_error = 'N' ) THEN



            -- Se intenta obtener el vendor site code del legacy vendor site name de la bajada de BC

            BEGIN



              v_vendor_site_code := NULL;



              SELECT vendor_site_code

                INTO v_vendor_site_code

                FROM ajcl_bc_vendors_customers

               WHERE type = 'VENDOR'

                 AND bc_environment = gv_bc_environment

                 AND no = ch.vendor_num;



              print_log ( 'Oracle invoice vendor site code ' || ch.vendor_site_code || ' replaced with BC Legacy Vendor Site Name ' || v_vendor_site_code );



            EXCEPTION

              WHEN OTHERS THEN

                print_log ( 'Oracle invoice vendor site code is used.' );

                v_vendor_site_code := ch.vendor_site_code;                



            END;



            -- Headers

            INSERT 

              INTO ajcl_bc_ap_dm_headers

                   ( invoice_id,

                     oracle_invoice_num,

                     invoice_num,

                     invoice_type_lookup_code,

                     invoice_date, 

                     vendor_id,

                     vendor_num,

                     vendor_name,

                     vendor_site_id,

                     vendor_site_code,

                     invoice_amount,

                     invoice_currency_code,

                     exchange_rate,

                     exchange_rate_type,

                     exchange_date,

                     terms_id,

                     terms_name,

                     terms_date,

                     description,

                     source,

                     payment_method_lookup_code,

                     pay_group_lookup_code,

                     gl_date,

                     org_id,

                     type,

                     set_of_books_id,

                     set_of_books_name,

                     company,

                     account,

                     account_description,

                     department,

                     product,

                     destination,

                     office,

                     origin,

                     division,

                     pdf_file_url,

                     --

                     last_update_date,

                     last_updated_by,

                     last_update_login,

                     creation_date,

                     created_by,

                     status,

                     request_id,

                     bc_environment )

            VALUES ( ch.invoice_id,

                     ch.invoice_num,

                     v_bc_invoice_num,

                     ch.invoice_type_lookup_code,

                     ch.invoice_date, 

                     ch.vendor_id,

                     ch.vendor_num,

                     ch.vendor_name,

                     ch.vendor_site_id,

                     -- ch.vendor_site_code,

                     v_vendor_site_code,

                     --

                     ch.invoice_amount,

                     ch.invoice_currency_code,

                     ch.exchange_rate,

                     ch.exchange_rate_type,

                     ch.exchange_date,

                     ch.terms_id,

                     ch.terms_name,

                     ch.terms_date,

                     ch.description,

                     ch.source,

                     ch.payment_method_lookup_code,

                     ch.pay_group_lookup_code,

                     ch.gl_date,

                     ch.org_id,

                     p_type,

                     ch.set_of_books_id,

                     ch.set_of_books_name,

                     v_company,

                     ch.account,

                     ch.account_description,

                     ch.department,

                     ch.product,

                     ch.destination,

                     ch.office,

                     ch.origin,

                     ch.division,

                     ch.pdffileurl,

                     --

                     TRUNC(SYSDATE),

                     gv_user_id,

                     gv_user_id,

                     TRUNC(SYSDATE),

                     gv_user_id,

                     'NEW', -- status

                     gv_request_id,

                     gv_bc_environment );



            ELSE



              print_log ( 'Se produjo un error al insertar una línea del comprobante. Error: ' || SQLERRM );



            END IF;



          EXCEPTION

            WHEN e_cust_exception THEN

              print_log ( v_error_message );

              RAISE;



          END; 



        END LOOP;



    END LOOP;



    -- QUITAR

    -- Sirve para levantar generados por otra ejecucion, y se debe comentar el loop de arriba

    /*

    UPDATE ajcl_bc_ap_dm_headers

       SET request_id = gv_request_id

     WHERE request_id = 11

       AND type = 'AGING'

       AND status = 'NEW'

       AND bc_environment = gv_bc_environment;



    UPDATE ajcl_bc_ap_dm_lines

       SET request_id = gv_request_id

     WHERE request_id = 11

       AND type = 'AGING'

       AND status = 'NEW'

       AND bc_environment = gv_bc_environment;



    COMMIT;  

    */

    -- QUITAR



    IF ( gv_export_type = 'BC_SEND' ) THEN



      main_bc_p ( p_status => v_status,

                  p_error_message => v_error_message );



      IF ( v_status != 'S' ) THEN



        RAISE e_main_bc;



      END IF;



    END IF;



    final_report_xlsx_p; 



    ajcl_bc_utils_pkg.send_mail_with_attach ( p_to_mail => gv_mail,

                                              p_subject => gv_bc_ifc || ' ' || p_type || ' - ' || gv_oracle_db || ' - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'),

                                              p_body => gv_oracle_db || ' > ' || p_bc_environment || CHR(10) || CHR(10) || 

                                                        --

                                                        'Type: ' || p_type || CHR(10) || 

                                                        'Export Type: ' || p_export_type,

                                              p_type => 'REPORT',

                                              p_filename => gv_report_filename, 

                                              p_file_format => gv_file_format,

                                              p_attach_filename => gv_bc_ifc || ' ' || p_type || ' - ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24MISS') || '.' || LOWER(gv_file_format) );  



    COMMIT; 



    print_log ( 'ajcl_bc_ap_data_migration_pkg.main_p (-)');



  EXCEPTION

    WHEN e_parameter_value THEN

      print_log('ajcl_bc_ap_data_migration_pkg.main_p (!)');

      print_log(v_error_message);



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_mail,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') || ' - ERROR',

                                       p_message => v_error_message );



    WHEN e_main_bc THEN

      print_log('ajcl_bc_ap_data_migration_pkg.main_p (!)');

      print_log(v_error_message);



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_mail,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') || ' - ERROR',

                                       p_message => v_error_message );



    WHEN e_cust_exception THEN

      print_log('ajcl_bc_ap_data_migration_pkg.main_p (!)');



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_mail,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') || ' - ERROR',

                                       p_message => v_error_message );



    WHEN OTHERS THEN

      print_log('ajcl_bc_ap_data_migration_pkg.main_p (!)');

      print_log('Error: ' || SQLERRM);



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_mail,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') || ' - ERROR',

                                       p_message => SQLERRM );



  END main_p;



END ajcl_bc_ap_data_migration_pkg;
