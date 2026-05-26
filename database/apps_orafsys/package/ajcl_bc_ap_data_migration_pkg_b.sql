PACKAGE BODY ajcl_bc_ap_data_migration_pkg IS
  
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

    v_get_url := ajcl_bc_ws
