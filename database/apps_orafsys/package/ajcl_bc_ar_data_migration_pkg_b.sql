CREATE OR REPLACE PACKAGE BODY ajcl_bc_ar_data_migration_pkg IS

  

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    gv_log_seq := gv_log_seq + 1;

    ajcl_bc_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );



  END print_log;



  PROCEDURE final_report_xlsx_p IS



    c_cursor   SYS_REFCURSOR;

    v_sheet    NUMBER := 1;



  BEGIN



    print_log( 'ajcl_bc_ar_data_migration_pkg.final_report_xlsx_p (+)' );



    gv_directory_report := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_REPORT' );



    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc,

                                                p_request_id => gv_request_id,

                                                p_bc_environment => gv_bc_environment,

                                                p_jenkins_build_number => gv_jenkins_build_number,

                                                --

                                                p_param_1_title => ' ',

                                                p_param_1_value => NULL,

                                                --

                                                p_param_2_title => 'GL_DATE',

                                                p_param_2_value => TO_CHAR(gv_gl_date,'YYYY-MM-DD'),

                                                p_param_3_title => 'TRX_NUM_PREFIX',

                                                p_param_3_value => gv_trx_num_prefix,

                                                p_param_4_title => 'TRX_NUM_TYPE',

                                                p_param_4_value => gv_trx_num_type,

                                                p_param_5_title => 'EXPORT_TYPE',

                                                p_param_5_value => gv_export_type,

                                                p_param_6_title => 'MIGRATION_TYPE',

                                                p_param_6_value => gv_migration_type,

                                                p_param_7_title => 'ORACLE_DB',

                                                p_param_7_value => gv_oracle_db );



    IF ( gv_export_type = 'CONFIGURATION_PACKAGE' ) THEN



      -- Worksheets ------------------------------------------------------------------------------------------------------------

      /*

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

          FROM ajcl_bc_ar_dm_lines

         WHERE request_id = gv_request_id

      GROUP BY worksheet,

               request_id

      ORDER BY worksheet;



      v_sheet := v_sheet + 1;

      ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Worksheets',

                                         p_sheet => v_sheet,

                                         p_cursor => c_cursor );

      */                                       



      -- Sales Headers ---------------------------------------------------------------------------------------------------------

        OPEN c_cursor FOR                                                

      SELECT DECODE(class,'INV','Invoice','CM','Credit Memo') document_type,

             DECODE(gv_trx_num_type,'ORACLE',oracle_trx_number,'BC',trx_number) transaction_no,

             TO_CHAR(trx_date,'YYYY-MM-DD') transaction_date,

             company,

             class,

             term_name,

             TO_CHAR(term_due_date,'YYYY-MM-DD') term_due_date,

             TO_CHAR(gl_date,'YYYY-MM-DD') gl_date,

             invoice_currency_code,

             TO_CHAR(exchange_date,'YYYY-MM-DD') exchange_date,

             exchange_rate,

             exchange_rate_type,

             purchase_order,

             amount,

             accounted_amount,

             customer_name bill_to_customer_name,

             customer_number bill_to_customer_no,

             bill_to_address_1,

             bill_to_address_2,

             bill_to_address_3,

             NULL status,

             NULL status_timestamp,

             NULL status_remarks,

             NULL creation_timestamp,

             request_id,

             NULL inspected_for,

             NULL destination_country,

             NULL destination_region,

             NULL destination_port,

             NULL origin_country,

             NULL origin_region,

             NULL origin_state,

             NULL for_shipment_start_date,

             NULL for_shipment_end_date,

             NULL for_arrival_start_date,

             NULL for_arrival_end_date,

             NULL logistics_operator,

             NULL salesperson_code,

             NULL external_document_no,

             NULL incoterms,

             NULL incoplace,

             NULL document_date,

             NULL frgn_exchange_bank,

             NULL frgn_exchange_contract_number,

             worksheet worksheet_no,

             applies_to_doc_type,

             applies_to_doc_no,

             override_flag,

             account,

             department,

             product,

             destination,

             origin,

             office,

             intercompany,

             NULL credit_memo_adjustment,

             comments,

             NULL created_date,

             NULL created_time,

             NULL modified_date,

             NULL modified_time,

             source,

             NULL division,

             iesInvoiceCompany ies_invoice_company,

             iesInvoiceNumber ies_invoice_number,

             iesNumber ies_number,

             --

             csaHousebill csa_housebill,

             csaMaxCSAPKSeqNo csa_max_csa_pk_seq_no,

             csaCustomerVendor csa_customer_vendor,

             csaSeqNum csa_seq_num,

             csaFileExtractNumber csa_file_extract_number,

             --

             trvShippingOrder trv_shipping_order,

             trvInvoiceNum trv_invoice_num,

             trvCustCarrierAcctNum trv_customer_carrier_acct_num,

             trvXMLFileName trv_xml_file_name,

             trvOracleXMLRunId trv_oracle_xml_run_id,

             trvXMLFileDate trv_xml_file_date,

             --

             invoiceReference1 invoice_reference_1,

             invoiceReference2 invoice_reference_2

        FROM ajcl_bc_ar_dm_headers

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

    ORDER BY DECODE(class,'INV',1,'CM',2),

             trx_number;



      v_sheet := v_sheet + 1;

      ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Sales Headers',

                                         p_sheet => v_sheet,

                                         p_cursor => c_cursor );                                       



      -- Sales Lines -----------------------------------------------------------------------------------------------------------                                

          OPEN c_cursor FOR                                                

        SELECT DECODE(gv_trx_num_type,'ORACLE',h.oracle_trx_number,'BC',h.trx_number) transaction_no,

               l.line_number line_no,

               l.company,

               l.description,

               l.quantity,

               l.unit_selling_price,

               l.extended_amount,

               l.accounted_amount,

               l.account,

               l.department,

               l.product,

               l.destination,

               l.origin,

               l.sales_order_source,

               l.sales_order,

               l.sales_order_revision,

               l.sales_order_line,

               TO_CHAR(l.sales_order_date,'YYYY-MM-DD') sales_order_date,

               NULL al_reason_meaning,

               NULL status,

               NULL status_timestamp,

               NULL status_remarks,

               NULL creation_timestamp,

               l.request_id,

               l.office,

               l.intercompany,

               NULL item_no,

               NULL packaging,

               NULL vendor_lot,

               NULL freezer_lot,

               NULL box_no,

               NULL halal,

               NULL prc,

               NULL po_number,

               NULL po_line,

               NULL estimated_cases,

               NULL estimated_net_weight,

               NULL unit_cost,

               NULL sales_uom,

               NULL sales_qty,

               l.worksheet worksheet_no,

               NULL created_date,

               NULL created_time,

               NULL modified_date,

               NULL modified_time,

               h.customer_number bill_to_customer_no,

               h.class,

               NULL division,

               -- ies

               l.iesInvoiceLine ies_invoice_line,

               TO_CHAR(TO_DATE(l.iesPickupDate,'YYYY-MM-DD'),'YYYY-MM-DD') ies_pickup_date,

               TO_CHAR(TO_DATE(l.iesETD,'YYYY-MM-DD'),'YYYY-MM-DD') ies_etd,

               TO_CHAR(TO_DATE(l.iesETA,'YYYY-MM-DD'),'YYYY-MM-DD') ies_eta,

               l.iesDestination ies_destination,

               l.iesOrigin ies_origin,

               -- CSA

               l.csaPKSeqNumber csa_pk_seq_number,

               l.csaSeqofCharge csa_seq_of_charge,

               TO_CHAR(TO_DATE(l.csaCreationDate,'DD-MON-YY'),'YYYY-MM-DD') csa_creation_date,

               l.csaOrderNo csa_order_no,

               l.csaStationId csa_station_id,

               l.csaSubAccount csa_sub_account,

               l.csaDivision csa_division,

               -- TRV

               l.trvItemSequence trv_item_sequence,

               l.trvMGLoadId trv_mg_load_id,

               l.trvEDIItemCodeChargeType trv_edi_item_code_charge_type,

               TO_CHAR(TO_DATE(l.trvDeliveryDate,'DD-MON-YY'),'YYYY-MM-DD') trv_delivery_date

          FROM ajcl_bc_ar_dm_lines l,

               ajcl_bc_ar_dm_headers h 

         WHERE l.request_id = gv_request_id

           AND l.customer_trx_id = h.customer_trx_id

           AND l.request_id = h.request_id

           AND h.bc_environment = gv_bc_environment

           AND h.bc_environment = l.bc_environment

      ORDER BY DECODE(h.class,'INV',1,'CM',2),

               h.trx_number,

               l.line_number;



      v_sheet := v_sheet + 1;

      ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Sales Lines',

                                         p_sheet => v_sheet,

                                         p_cursor => c_cursor );



    ELSIF ( gv_export_type IN ( 'BC_PREVIEW','BC_SEND' ) ) THEN



        OPEN c_cursor FOR

      SELECT ( SELECT COUNT(1) FROM ajcl_bc_ar_dm_headers WHERE request_id = gv_request_id AND bc_environment = gv_bc_environment ) invoices_total_count,

             ( SELECT SUM(amount) FROM ajcl_bc_ar_dm_headers WHERE request_id = gv_request_id AND bc_environment = gv_bc_environment ) invoices_total_sum,

             ( SELECT SUM(accounted_amount) FROM ajcl_bc_ar_dm_lines WHERE request_id = gv_request_id AND bc_environment = gv_bc_environment ) lines_total_sum

        FROM DUAL;



      v_sheet := v_sheet + 1;

      ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Summary',

                                         p_sheet => v_sheet,

                                         p_cursor => c_cursor );



          OPEN c_cursor FOR

        SELECT h.customer_trx_id,

               h.class,

               h.trx_number transaction_no,

               TO_CHAR(h.trx_date,'YYYY-MM-DD') transaction_date,

               TO_CHAR(h.gl_date,'YYYY-MM-DD') gl_date,

               h.customer_name customer_name,

               h.customer_number customer_no,

               h.invoice_currency_code currency_code,

               -- TRIM(TO_CHAR(h.amount,'999,999,999.00')) amount,

               h.amount,

               h.term_name,

               UPPER(h.status) header_status,

               h.error_message header_error_message,

               l.line_number line_num,

               l.description,

               -- TRIM(TO_CHAR(l.accounted_amount,'999,999,999.00')) accounted_amount,

               l.accounted_amount,

               UPPER(l.status) line_status,

               l.error_message line_error_message

          FROM ajcl_bc_ar_dm_headers h,

               ajcl_bc_ar_dm_lines l

         WHERE h.request_id = gv_request_id

           AND h.bc_environment = gv_bc_environment

           AND h.request_id = l.request_id

           AND h.bc_environment = l.bc_environment

           AND h.customer_trx_id = l.customer_trx_id

      ORDER BY h.customer_name,

               h.trx_number, 

               l.line_number;



      v_sheet := v_sheet + 1;

      ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Sales Documents',

                                         p_sheet => v_sheet,

                                         p_cursor => c_cursor );



      /*

      IF ( gv_export_type = 'BC_PREVIEW' ) THEN



        -- Se crea solapa con los customers que no existen en BC

            OPEN c_cursor FOR     

          SELECT customer_number,

                 customer_name

            FROM ( SELECT customer_number,

                          customer_name  

                     FROM ajcl_bc_ar_dm_headers h

                    WHERE request_id = gv_request_id

                      AND bc_environment = gv_bc_environment

                 GROUP BY customer_number,

                          customer_name )

           WHERE ajcl_bc_ws_utils_pkg.check_customer_exists_bc_p ( p_bc_environment => gv_bc_environment,

                                                                   p_company_id => gv_bc_company_id,

                                                                   p_no => customer_number ) = 'N'

        ORDER BY customer_name;



        v_sheet := v_sheet + 1;

        ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Customers Missing',

                                           p_sheet => v_sheet,

                                           p_cursor => c_cursor );                                         



      END IF;  

      */



          -- Se crea solapa con los customers que no existen en BC

          OPEN c_cursor FOR    

        SELECT customer_number,

               customer_name  

          FROM ajcl_bc_ar_dm_headers h  

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND NOT EXISTS ( SELECT 1

                              FROM ajcl_bc_vendors_customers bcv

                             WHERE type = 'CUSTOMER' 

                               AND bcv.bc_environment = gv_bc_environment 

                               AND bcv.no = h.customer_number )

      ORDER BY customer_name;



      v_sheet := v_sheet + 1;

      ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Customers Missing',

                                         p_sheet => v_sheet,

                                         p_cursor => c_cursor );    



          -- Se crea solapa con los payment terms de todas las facturas a migrar

          OPEN c_cursor FOR    

        SELECT term_name 

          FROM ajcl_bc_ar_dm_headers 

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

      GROUP BY term_name

      ORDER BY term_name;



      v_sheet := v_sheet + 1;

      ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Payment Terms Missing',

                                         p_sheet => v_sheet,

                                         p_cursor => c_cursor );



    END IF;



    as_xlsx.save ( gv_directory_report, gv_report_filename || '.' || LOWER(gv_file_format) );



    print_log( 'ajcl_bc_ar_data_migration_pkg.final_report_xlsx_p (-)' );



  END final_report_xlsx_p;



  /*

  PROCEDURE worksheets_to_bc_p ( p_status   OUT   VARCHAR2 ) IS



      CURSOR c_worksheets IS

      SELECT worksheet dimValueCode

        FROM ajcl_bc_ar_dm_lines

       WHERE request_id = gv_request_id

    GROUP BY worksheet;



    v_url               VARCHAR2(2000); 

    v_body              VARCHAR2(2000);

    v_clob_result       CLOB;

    v_clob_job_result   CLOB;



    v_count             NUMBER := 0;

    v_job_object_id     NUMBER;



  BEGIN



    print_log( 'ajcl_bc_ar_data_migration_pkg.worksheets_to_bc_p (+)' );



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



      END IF;



      v_count := v_count + 1;



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

    print_log( 'ajcl_bc_ar_data_migration_pkg.worksheets_to_bc_p (-)' );



  END worksheets_to_bc_p;

  */



  PROCEDURE call_ws_p ( p_trx_count       OUT   NUMBER,

                        --

                        p_status          OUT   VARCHAR2,

                        p_error_message   OUT   VARCHAR2 ) IS



      CURSOR c_headers IS

      SELECT *

        FROM ajcl_bc_ar_dm_headers

       WHERE request_id = gv_request_id 

         AND bc_environment = gv_bc_environment

         AND status = 'NEW'

    ORDER BY trx_number;            



      CURSOR c_lines ( p_customer_trx_id   IN   NUMBER ) IS

      SELECT *

        FROM ajcl_bc_ar_dm_lines

       WHERE customer_trx_id = p_customer_trx_id

         AND request_id = gv_request_id 

         AND bc_environment = gv_bc_environment

         AND status = 'NEW'

    ORDER BY line_number;



    v_status                      VARCHAR2(1);



    v_url_header                  VARCHAR2(2000);

    v_body_header                 CLOB;

    v_clob_result_header          CLOB;



    v_url_line                    VARCHAR2(2000);

    v_body_line                   CLOB;

    v_clob_result_line            CLOB;



    v_linea_con_error             VARCHAR2(1);

    v_error_message               VARCHAR2(2000);



  BEGIN



    print_log('ajcl_bc_ar_data_migration_pkg.call_ws_p (+)');



    v_url_header := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                                 p_entity => 'INBOUND SALES DOC',

                                                                 p_subentity => 'HEADERS',

                                                                 p_method => 'POST',

                                                                 p_company_id => gv_bc_company_id );



    print_log('v_url_header: ' || v_url_header);



    v_url_line := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                                 p_entity => 'INBOUND SALES DOC',

                                                                 p_subentity => 'LINES',

                                                                 p_method => 'POST',

                                                                 p_company_id => gv_bc_company_id );



    print_log('v_url_line: ' || v_url_line);



    FOR ch IN c_headers LOOP



      print_log ('trx_number: ' || ch.trx_number);



      v_linea_con_error := 'N';



      FOR cl IN c_lines ( ch.customer_trx_id ) LOOP



        print_log ('line_number: ' || cl.line_number);



        -- Se arma la linea

        APEX_JSON.initialize_clob_output;

        APEX_JSON.open_object;

        APEX_JSON.write('requestID',gv_request_id);

        APEX_JSON.write('company',cl.company,TRUE);

        APEX_JSON.write('billToCustomerNo',ch.customer_number);

        APEX_JSON.write('transactionNo',ch.trx_number);

        APEX_JSON.write('class',ch.class);

        APEX_JSON.write('lineNo',cl.line_number);

        APEX_JSON.write('description',cl.description);

        APEX_JSON.write('quantity',cl.quantity);

        APEX_JSON.write('unitSellingPrice',cl.unit_selling_price);

        APEX_JSON.write('extendedAmount',cl.extended_amount);

        APEX_JSON.write('accountedAmount',cl.accounted_amount,true);

        APEX_JSON.write('account',cl.account);

        APEX_JSON.write('department',cl.department,TRUE);

        APEX_JSON.write('destination',cl.destination,TRUE);

        APEX_JSON.write('office',cl.office,TRUE);

        APEX_JSON.write('origin',cl.origin,TRUE);

        -- APEX_JSON.write('divisionLog',cl.division,TRUE);

        APEX_JSON.write('worksheetNo',cl.worksheet,TRUE);



        APEX_JSON.write('iesInvoiceLine',cl.iesInvoiceLine,TRUE); 

        APEX_JSON.write('iesPickupDate',TO_CHAR(TO_DATE(cl.iesPickupDate,'YYYY-MM-DD'),'YYYY-MM-DD'),TRUE); 

        APEX_JSON.write('iesETD',TO_CHAR(TO_DATE(cl.iesETD,'YYYY-MM-DD'),'YYYY-MM-DD'),TRUE); 

        APEX_JSON.write('iesETA',TO_CHAR(TO_DATE(cl.iesETA,'YYYY-MM-DD'),'YYYY-MM-DD'),TRUE); 

        APEX_JSON.write('iesDestination',cl.iesDestination,TRUE); 

        APEX_JSON.write('iesOrigin',cl.iesOrigin,TRUE); 



        APEX_JSON.write('csaPKSeqNumber',cl.csaPKSeqNumber,TRUE); 

        APEX_JSON.write('csaSeqofCharge',cl.csaSeqofCharge,TRUE); 

        APEX_JSON.write('csaCreationDate',TO_CHAR(TO_DATE(cl.csaCreationDate,'DD-MON-YY'),'YYYY-MM-DD'),TRUE); 

        APEX_JSON.write('csaOrderNo',cl.csaOrderNo,TRUE);   

        APEX_JSON.write('csaStationId',cl.csaStationId,TRUE);   

        APEX_JSON.write('csaSubAccount',cl.csaSubAccount,TRUE);   

        APEX_JSON.write('csaDivision',cl.csaDivision,TRUE);  



        APEX_JSON.write('trvItemSequence',cl.trvItemSequence,TRUE); 

        APEX_JSON.write('trvMGLoadId',cl.trvMGLoadId,TRUE); 

        APEX_JSON.write('trvEDIItemCodeChargeType',cl.trvEDIItemCodeChargeType,TRUE); 

        APEX_JSON.write('trvDeliveryDate',TO_CHAR(TO_DATE(cl.trvDeliveryDate,'DD-MON-YY'),'YYYY-MM-DD'),TRUE);



        APEX_JSON.close_object;



        v_body_line := APEX_JSON.get_clob_output;

        print_log('v_body_line: ' || v_body_line);  



        v_clob_result_line := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_url_line),

                                                                         p_request_header_name1 => 'Content-Type',

                                                                         p_request_header_value1 => 'application/json',

                                                                         p_request_header_name2 => NULL,

                                                                         p_request_header_value2 => NULL,

                                                                         p_http_method => 'POST',

                                                                         p_body => v_body_line );



        print_log('v_clob_result_line: ' || v_clob_result_line);

        APEX_JSON.free_output;



        IF ( UPPER(v_clob_result_line) LIKE '%"ERROR":%' ) THEN



          print_log ( 'Error sending transaction line.' );



          v_error_message := SUBSTR(v_clob_result_line,INSTR(v_clob_result_line,'message') + 10);



          print_log(v_error_message);



          UPDATE ajcl_bc_ar_dm_lines

             SET status = 'ERROR',

                 error_message = v_error_message,

                 json_data = v_body_line,

                 json_data_response = v_clob_result_line

           WHERE customer_trx_id = ch.customer_trx_id

             AND line_number = cl.line_number

             AND request_id = gv_request_id

             AND bc_environment = gv_bc_environment;



          v_linea_con_error := 'Y';



        ELSE



          UPDATE ajcl_bc_ar_dm_lines

             SET status = 'SENT',

                 error_message = NULL,

                 json_data = v_body_line,

                 json_data_response = v_clob_result_line

           WHERE customer_trx_id = ch.customer_trx_id

             AND line_number = cl.line_number

             AND request_id = gv_request_id

             AND bc_environment = gv_bc_environment;



          print_log ( 'The line was sent successfully.' );



        END IF;



      END LOOP;



      -- Si todas las lineas se enviaron sin problema

      IF ( v_linea_con_error = 'N' ) THEN



        v_error_message := NULL;



        -- Se envia la cabecera

        APEX_JSON.initialize_clob_output;

        APEX_JSON.open_object;



        APEX_JSON.write('company',ch.company,TRUE);

        APEX_JSON.write('transactionNo',ch.trx_number);

        APEX_JSON.write('transactionDate',TO_CHAR(ch.trx_date,'YYYY-MM-DD'));

        APEX_JSON.write('class',ch.class);

        APEX_JSON.write('termName',ch.term_name,true);

        APEX_JSON.write('termDueDate',TO_CHAR(ch.term_due_date,'YYYY-MM-DD'));

        APEX_JSON.write('glDate',TO_CHAR(ch.gl_date,'YYYY-MM-DD'));

        APEX_JSON.write('invoiceCurrencyCode',ch.invoice_currency_code);

        APEX_JSON.write('exchangeDate',ch.exchange_date,true);

        APEX_JSON.write('exchangeRate',ch.exchange_rate,true);

        APEX_JSON.write('exchangeRateType',ch.exchange_rate_type,true);

        APEX_JSON.write('amount',ch.amount);

        APEX_JSON.write('accountedAmount',ch.accounted_amount,true);

        APEX_JSON.write('account',ch.account,true);

        APEX_JSON.write('department',ch.department,TRUE);

        APEX_JSON.write('destination',ch.destination,TRUE);

        APEX_JSON.write('office',ch.office,TRUE);

        APEX_JSON.write('origin',ch.origin,TRUE);

        -- APEX_JSON.write('divisionLog',ch.division,TRUE);

        APEX_JSON.write('billToCustomerName',ch.customer_name);

        APEX_JSON.write('billToCustomerNo',ch.customer_number);

        APEX_JSON.write('billToAddress1',ch.bill_to_address_1,true);

        APEX_JSON.write('billToAddress2',ch.bill_to_address_2,true);

        APEX_JSON.write('billToAddress3',ch.bill_to_address_3,true);

        APEX_JSON.write('requestID',gv_request_id);

        APEX_JSON.write('worksheetNo',ch.worksheet,true);

        APEX_JSON.write('appliestoDocType',ch.applies_to_doc_type,true);

        APEX_JSON.write('appliestoDocNo',ch.applies_to_doc_no,true);



        -- 20240826

        APEX_JSON.write('commentsAJC_INE',gv_source,true); -- Campo Comments en BC

        -- 20240826



        -- nuevos logistics

        APEX_JSON.write('source',ch.source);



        APEX_JSON.write('iesInvoiceCompany',ch.iesInvoiceCompany,true);

        APEX_JSON.write('iesInvoiceNumber',ch.iesInvoiceNumber,true);

        APEX_JSON.write('iesNumber',ch.iesNumber,true);



        APEX_JSON.write('invoiceReference1',ch.invoiceReference1,true);

        APEX_JSON.write('invoiceReference2',ch.invoiceReference2,true);

        APEX_JSON.write('csaHousebill',ch.csaHousebill,true);

        APEX_JSON.write('csaMaxCSAPKSeqNo',ch.csaMaxCSAPKSeqNo,true);

        APEX_JSON.write('csaCustomerVendor',ch.csaCustomerVendor,true);

        APEX_JSON.write('csaSeqNum',ch.csaSeqNum,true);

        APEX_JSON.write('csaFileExtractNumber',ch.csaFileExtractNumber,true);



        APEX_JSON.write('trvShippingOrder',ch.trvShippingOrder,true);

        APEX_JSON.write('trvInvoiceNum',ch.trvInvoiceNum,true);

        APEX_JSON.write('trvCustCarrierAcctNum',ch.trvCustCarrierAcctNum,true);

        APEX_JSON.write('trvXMLFileName',ch.trvXMLFileName,true);

        APEX_JSON.write('trvOracleXMLRunId',ch.trvOracleXMLRunId,true);

        APEX_JSON.write('trvXMLFileDate',TO_CHAR(ch.trvXMLFileDate,'YYYY-MM-DD'),true);

        --



        APEX_JSON.close_object;



        v_body_header := APEX_JSON.get_clob_output;



        print_log ( 'v_body_header: ' || v_body_header );



        v_clob_result_header := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_url_header),

                                                                           p_request_header_name1 => 'Content-Type',

                                                                           p_request_header_value1 => 'application/json',

                                                                           p_request_header_name2 => NULL,

                                                                           p_request_header_value2 => NULL,

                                                                           p_http_method => 'POST',

                                                                           p_body => v_body_header );



        print_log ( 'v_clob_result_header: ' || v_clob_result_header);

        APEX_JSON.free_output;



        IF ( UPPER(v_clob_result_header) LIKE '%"ERROR":%' ) THEN



          print_log ( 'Error sending transaction header.' );



          v_error_message := -- 'An error occurred while sending the header: ' ||

                             SUBSTR(v_clob_result_header,INSTR(v_clob_result_header,'message') + 10);



          print_log ( v_error_message );



          UPDATE ajcl_bc_ar_dm_headers

             SET status = 'ERROR',

                 error_message = v_error_message,

                 json_data = v_body_header,

                 json_data_response = v_clob_result_header

           WHERE customer_trx_id = ch.customer_trx_id

             AND request_id = gv_request_id

             AND bc_environment = gv_bc_environment;



        ELSE



          UPDATE ajcl_bc_ar_dm_headers

             SET status = 'SENT',

                 error_message = NULL,

                 json_data = v_body_header,

                 json_data_response = v_clob_result_header

           WHERE customer_trx_id = ch.customer_trx_id

             AND request_id = gv_request_id

             AND bc_environment = gv_bc_environment;



          print_log ( 'Transaction header was sent successfully.' );



        END IF;



        p_trx_count := NVL(p_trx_count,0) + 1;



      ELSE



        UPDATE ajcl_bc_ar_dm_headers

           SET status = 'ERROR',

               error_message = 'An error occurred on some line of the document'

         WHERE customer_trx_id = ch.customer_trx_id

           AND request_id = gv_request_id

           AND bc_environment = gv_bc_environment;



      END IF;



    END LOOP;



    p_status := 'S';

    print_log('ajcl_bc_ar_data_migration_pkg.call_ws_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      print_log('ajcl_bc_ar_data_migration_pkg.call_ws_p (!). Error: ' || SQLERRM);

      p_status := 'E';



  END call_ws_p;



  PROCEDURE call_job_p ( p_status          OUT   VARCHAR2,

                         p_error_message   OUT   VARCHAR2 ) IS



    v_job_object_id     NUMBER;

    v_status            VARCHAR2(20);

    v_clob_response     CLOB;



  BEGIN



    print_log ('ajcl_bc_ar_data_migration_pkg.call_job_p (+)');



    v_job_object_id := ajcl_bc_ws_utils_pkg.get_object_id_f ( 'SALES DOCUMENTS' );

    print_log ('v_job_object_id: ' || v_job_object_id || ' - ' || TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS'));



    v_clob_response := ajcl_bc_ws_utils_pkg.run_job_queue_f ( p_bc_environment => gv_bc_environment,

                                                              p_company_id => gv_bc_company_id,

                                                              p_object_id => v_job_object_id );



    IF ( UPPER(v_clob_response) LIKE '%"ERROR":%' ) THEN



      print_log('An error occurred while running Sales Invoices job.');

      v_status := 'ERROR';

      p_status := 'E';



    ELSE



      print_log('Sales Invoices job was executed successfully.');

      v_status := 'SUCCESS';

      p_status := 'S';



    END IF;



    -- Se inserta registro de control

    INSERT

      INTO ajcl_bc_ar_dm_control

           ( bc_environment,

             request_id,

             org_id,

             status,

             job_response,

             creation_date )

    VALUES ( gv_bc_environment,

             gv_request_id, 

             gv_org_id,

             v_status,

             v_clob_response,

             TRUNC(SYSDATE) );



    print_log ('ajcl_bc_ar_data_migration_pkg.call_job_p (-)');



  EXCEPTION    

    WHEN OTHERS THEN

      p_status := 'E';

      p_error_message := SQLERRM;

      print_log ('ajcl_bc_ar_data_migration_pkg.call_job_p (!). Error: ' || p_error_message);



  END call_job_p;



  PROCEDURE delete_inbound_records_p ( p_trx_number       IN   VARCHAR2,

                                       p_customer_number  IN   VARCHAR2,

                                       p_class            IN   VARCHAR2 ) IS



    v_line_del_api      VARCHAR2(2000);

    v_line_del_url      VARCHAR2(2000);

    v_line_body         CLOB;

    v_line_del_clob     CLOB;



      CURSOR c_lines IS

      SELECT l.line_number

        FROM ajcl_bc_ar_dm_lines l,

             ajcl_bc_ar_dm_headers h

       WHERE l.customer_trx_id = h.customer_trx_id

         AND h.trx_number = p_trx_number

         AND h.customer_number = p_customer_number

         AND h.class = p_class

         AND h.request_id = gv_request_id

         AND l.request_id = h.request_id

         AND h.bc_environment = gv_bc_environment

         AND l.bc_environment = h.bc_environment

    ORDER BY line_number;



    v_header_del_api    VARCHAR2(2000);

    v_header_del_url    VARCHAR2(2000);

    v_header_body       CLOB;

    v_header_del_clob   CLOB;



  BEGIN



    print_log ('ajcl_bc_ar_data_migration_pkg.delete_inbound_records_p (+)');



    -- Lines -------------------------------------------------------------------------------------------------------------------



    -- Se obtiene la api para borrar las lineas

    v_line_del_api := ajcl_bc_ws_utils_pkg.get_api_f ( p_entity => 'INBOUND SALES DOC DEL',

                                                       p_subentity => 'LINES',

                                                       p_method => 'DEL' );



    print_log ( 'v_line_del_api: ' || v_line_del_api );



    -- Se arma la URL para borrar la linea de la tabla staging.

    v_line_del_url := ajcl_bc_ws_utils_pkg.get_base_standard_url_f ( p_bc_environment => gv_bc_environment,

                                                                     p_api => v_line_del_api,

                                                                     p_company_id => gv_bc_company_id );



    print_log ( 'v_line_del_url: ' || v_line_del_url );



    -- Se recorren las lineas

    FOR cl IN c_lines LOOP



      -- Se arma el clob

      APEX_JSON.initialize_clob_output;

      APEX_JSON.open_object;

      APEX_JSON.write('transactionNo',p_trx_number);

      APEX_JSON.write('customerNo',p_customer_number);

      APEX_JSON.write('classType',p_class);

      APEX_JSON.write('lineNo',cl.line_number);

      APEX_JSON.close_object;



      v_line_body := APEX_JSON.get_clob_output;

      APEX_JSON.free_output;



      print_log ( 'v_line_body: ' || v_line_body );



      -- Se borra la linea de la tabla staging.

      v_line_del_clob := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_line_del_url),

                                                                    p_request_header_name1 => 'Content-Type',

                                                                    p_request_header_value1 => 'application/json',

                                                                    p_request_header_name2 => NULL,

                                                                    p_request_header_value2 => NULL,

                                                                    p_http_method => 'POST',

                                                                    p_body => v_line_body );



      IF ( UPPER(v_line_del_clob) LIKE '%ERROR%' )  THEN



        print_log('Error when deleting the line from the BC stage table.');

        print_log(v_line_del_clob);



      ELSE



        print_log('Line deleted from BC stage table.');



      END IF;



    END LOOP;



    -- Headers -----------------------------------------------------------------------------------------------------------------



    -- Se obtiene la api para borrar la cabecera

    v_header_del_api := ajcl_bc_ws_utils_pkg.get_api_f ( p_entity => 'INBOUND SALES DOC DEL',

                                                         p_subentity => 'HEADERS',

                                                         p_method => 'DEL' );



    print_log ( 'v_header_del_api: ' || v_header_del_api );



    -- Se arma la URL para borrar cabecera de la tabla staging.

    v_header_del_url := ajcl_bc_ws_utils_pkg.get_base_standard_url_f ( p_bc_environment => gv_bc_environment,

                                                                       p_api => v_header_del_api,

                                                                       p_company_id => gv_bc_company_id );



    print_log ( 'v_header_del_url: ' || v_header_del_url );



    -- Se arma el clob

    APEX_JSON.initialize_clob_output;

    APEX_JSON.open_object;

    APEX_JSON.write('transactionNo',p_trx_number);

    APEX_JSON.write('customerNo',p_customer_number);

    APEX_JSON.write('classType',p_class);

    APEX_JSON.close_object;



    v_header_body := APEX_JSON.get_clob_output;

    APEX_JSON.free_output;



    print_log ( 'v_header_body: ' || v_header_body );



    -- Se borra cabecera de la tabla staging.

    v_header_del_clob := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_header_del_url),

                                                                    p_request_header_name1 => 'Content-Type',

                                                                    p_request_header_value1 => 'application/json',

                                                                    p_request_header_name2 => NULL,

                                                                    p_request_header_value2 => NULL,

                                                                    p_http_method => 'POST',

                                                                    p_body => v_header_body );



    IF ( UPPER(v_header_del_clob) LIKE '%ERROR%' )  THEN



      print_log('Error when deleting header from BC stage table.');

      print_log(v_header_del_clob);



    ELSE



      print_log('Deleted header from BC stage table.');



    END IF;



    print_log ('ajcl_bc_ar_data_migration_pkg.delete_inbound_records_p (-)');



  END delete_inbound_records_p;



  PROCEDURE call_status_p ( p_status          OUT   VARCHAR2,

                            p_error_message   OUT   VARCHAR2 ) IS



    v_status               VARCHAR2(1);

    v_error_message        VARCHAR2(2000);

    e_cust_exception       EXCEPTION;

    v_url                  VARCHAR2(2000);

    v_clob_result          CLOB;

    v_header_delete_clob   CLOB;

    v_lines_delete_clob    CLOB;



    CURSOR c_status ( p_clob_result_status   IN   CLOB ) IS

    SELECT -- company,

           trx_number,

           -- trx_date,

           customer_number,

           class,

           -- gl_date,

           -- amount,

           status,

           statusRemarks,

           requestID

      FROM json_table( p_clob_result_status,

                       '$.value[*]' COLUMNS ( -- company           VARCHAR2(4000)  path '$.company',

                                              trx_number        VARCHAR2(4000)  path '$.transactionNo',

                                              -- trx_date          VARCHAR2(4000)  path '$.transactionDate',

                                              customer_number   VARCHAR2(4000)  path '$.billToCustomerNo',

                                              class             VARCHAR2(4000)  path '$.class',

                                              -- gl_date           VARCHAR2(4000)  path '$.glDate',

                                              -- amount            VARCHAR2(4000)  path '$.amount',

                                              status            VARCHAR2(4000)  path '$.status',

                                              statusRemarks     VARCHAR2(4000)  path '$.statusRemarks',

                                              requestID         VARCHAR2(4000)  path '$.requestID' ) );



  BEGIN



    print_log ('ajcl_bc_ar_data_migration_pkg.call_status_p (+)');



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                          p_entity => 'INBOUND SALES DOC',

                                                          p_subentity => 'HEADERS',

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id )

             || '?$filter=requestID eq ' || TO_CHAR(gv_request_id);



    print_log ( 'v_url: ' || v_url );



    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



    FOR cs IN c_status ( v_clob_result ) LOOP



      IF ( UPPER(cs.status) != 'SUCCESS' ) THEN



        print_log ( -- 'company: ' || cs.company || 

                    'trx_number: ' || cs.trx_number || 

                    -- '|trx_date: ' || cs.trx_date ||

                    -- '|customer_number: ' || cs.customer_number ||

                    -- '|class: ' || cs.class ||

                    -- '|gl_date: ' || cs.gl_date || 

                    -- '|amount: ' || cs.amount || 

                    '|status: ' || cs.status || 

                    '|statusRemarks: ' || cs.statusRemarks);



        -- Se actualiza la tabla custom con el status REJECTED

        UPDATE ajcl_bc_ar_dm_headers

           SET status = 'REJECTED',

               error_message = cs.statusRemarks

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND UPPER(trx_number) = UPPER(cs.trx_number);



        -- Se actualiza el status de sus lineas   

        UPDATE ajcl_bc_ar_dm_lines

           SET status = 'REJECTED'

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND customer_trx_id = ( SELECT customer_trx_id 

                                     FROM ajcl_bc_ar_dm_headers 

                                    WHERE request_id = gv_request_id

                                      AND bc_environment = gv_bc_environment

                                      AND UPPER(trx_number) = UPPER(cs.trx_number) );



        -- Se borra cabecera y lineas de las tablas inbound

        delete_inbound_records_p ( p_trx_number => cs.trx_number,

                                   p_customer_number => cs.customer_number,

                                   p_class => cs.class );



      ELSE



        -- Se actualiza la tabla custom con el status SUCCESS

        UPDATE ajcl_bc_ar_dm_headers

           SET status = 'SUCCESS'

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND UPPER(trx_number) = UPPER(cs.trx_number);



        -- Se actualizan sus lineas   

        UPDATE ajcl_bc_ar_dm_lines

           SET status = 'SUCCESS'

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND customer_trx_id = ( SELECT customer_trx_id 

                                     FROM ajcl_bc_ar_dm_headers 

                                    WHERE request_id = gv_request_id

                                      AND bc_environment = gv_bc_environment

                                      AND UPPER(trx_number) = UPPER(cs.trx_number) );



      END IF;



    END LOOP;



    p_status := 'S';



    print_log ('ajcl_bc_ar_data_migration_pkg.call_status_p (-)');   



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      print_log (v_error_message);

      print_log ('ajcl_bc_ar_data_migration_pkg.call_status_p (!)');



    WHEN others THEN

      p_status := 'E';

      print_log ( 'Not caught error when calling status. Error: ' || SQLERRM );

      print_log ('ajcl_bc_ar_data_migration_pkg.call_status_p (!)');



  END call_status_p;



  PROCEDURE main_bc_p ( p_status          OUT   VARCHAR2,

                        p_error_message   OUT   VARCHAR2 ) IS



    v_trx_count        NUMBER;



    v_status           VARCHAR2(1);

    v_error_message    VARCHAR2(1000);



    v_phase            VARCHAR2(100);

    e_error            EXCEPTION;



  BEGIN



    print_log( 'ajcl_bc_ar_data_migration_pkg.main_bc_p (+)' );



    /*

    worksheets_to_bc_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'worksheets_to_bc_p';

      RAISE e_error;



    END IF;

    */



    call_ws_p ( p_trx_count => v_trx_count,

                --

                p_status => v_status,

                p_error_message => v_error_message );



    IF ( v_status != 'S' ) THEN



      v_phase := 'call_ws_p';

      RAISE e_error;



    END IF;



    IF ( v_trx_count > 0 ) THEN



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

    print_log( 'ajcl_bc_ar_data_migration_pkg.main_bc_p (-)' );



  EXCEPTION

    WHEN e_error THEN

      p_status := 'E'; 

      print_log ( 'phase: ' || v_phase );

      print_log ( 'ajcl_bc_ar_data_migration_pkg.main_bc_p (!). Error: ' || v_error_message );



    WHEN OTHERS THEN

      p_status := 'E';    

      print_log ( 'ajcl_bc_ar_data_migration_pkg.main_bc_p (!). Error: ' || SQLERRM );



  END main_bc_p;



  PROCEDURE main_p ( p_bc_environment         IN   VARCHAR2,

                     p_gl_date                IN   VARCHAR2,

                     p_trx_num_prefix         IN   VARCHAR2,

                     p_trx_num_type           IN   VARCHAR2,

                     p_export_type            IN   VARCHAR2,

                     p_migration_type         IN   VARCHAR2,

                     p_jenkins_build_number   IN   VARCHAR2 ) IS



    CURSOR c_headers IS

    SELECT rct.customer_trx_id, 

           gcc.segment1 company,

           '1110.1200' account,

           NULL department,

           NULL product,

           NULL destination,

           NULL origin,

           NULL office,

           NULL intercompany,

           gv_trx_num_prefix || rct.trx_number trx_number,

           rct.trx_date,

           -- DECODE(ctt.type,'DM','INV',ctt.type) class,

           CASE

             WHEN aps.amount_due_remaining < 0 THEN

               'CM'

             ELSE 

               'INV'

           END class,

           pt.term_id,

           SUBSTR(pt.name,1,10) term_name,

           NVL(rct.term_due_date,aps.due_date) term_due_date,

           gv_gl_date gl_date,

           NVL(fc.attribute1, rct.invoice_currency_code) invoice_currency_code,

           rct.exchange_date,

           rct.exchange_rate,

           rct.exchange_rate_type,

           rct.purchase_order purchase_order,

           ABS(aps.amount_due_remaining) amount,

           NULL accounted_amount,

           rc.customer_name customer_name,

           rc.customer_number customer_number,

           SUBSTR(hl.address1,1,100) bill_to_address_1,

           SUBSTR(hl.address2,1,50) bill_to_address_2,

           SUBSTR(hl.address3,1,50) bill_to_address_3,

           -- rctd.attribute1 worksheet,

           NULL worksheet,

           --

           DECODE(NVL(rct.attribute2,'N'),'N','false','Y','true') override_flag,

           rct.org_id,

           rct.comments,

           -- flexfields

           rct.attribute5 invoiceReference1,

           rct.attribute6 invoiceReference2,

           CASE

             WHEN gv_trx_num_type = 'ORACLE' THEN

               rct.interface_header_context

             WHEN gv_trx_num_type = 'BC' THEN

               DECODE(rct.interface_header_context,'IES','IES',

                                                   'CSA','CSA',

                                                   'TURVO','TRV',

                                                   'MGATE','TRV',

                                                   --

                                                   'TRV' -- 'NOT ATIS','ORDER ENTRY'

                                                   ) 

           END source,

           rct.interface_header_context original_source,

           -- IES

           DECODE(rct.interface_header_context,'IES',rct.interface_header_attribute1,NULL) iesInvoiceCompany,

           DECODE(rct.interface_header_context,'IES',rct.interface_header_attribute2,NULL) iesInvoiceNumber,

           DECODE(rct.interface_header_context,'IES',rct.interface_header_attribute4,NULL) iesNumber,

           -- CSA

           DECODE(rct.interface_header_context,'CSA',rct.interface_header_attribute1,NULL) csaHousebill,

           DECODE(rct.interface_header_context,'CSA',rct.interface_header_attribute2,NULL) csaMaxCSAPKSeqNo,

           DECODE(rct.interface_header_context,'CSA',rct.interface_header_attribute3,NULL) csaCustomerVendor,

           DECODE(rct.interface_header_context,'CSA',rct.interface_header_attribute4,NULL) csaSeqNum,

           DECODE(rct.interface_header_context,'CSA',rct.interface_header_attribute12,NULL) csaFileExtractNumber,

           -- TRV

           DECODE(rct.interface_header_context,'TURVO',rct.interface_header_attribute1,'MGATE',rct.interface_header_attribute1,NULL) trvShippingOrder,

           -- DECODE(rct.interface_header_context,'TURVO',rct.interface_header_attribute2,'MGATE',rct.interface_header_attribute2,NULL) trvInvoiceNum,

           DECODE(rct.interface_header_context,'TURVO',rct.trx_number,'MGATE',rct.trx_number,NULL) trvInvoiceNum, -- Se envia el nro original en el flexfield

           --

           DECODE(rct.interface_header_context,'TURVO',rct.interface_header_attribute3,'MGATE',rct.interface_header_attribute3,NULL) trvCustCarrierAcctNum,

           DECODE(rct.interface_header_context,'TURVO',rct.interface_header_attribute4,'MGATE',rct.interface_header_attribute4,NULL) trvXMLFileName,

           DECODE(rct.interface_header_context,'TURVO',rct.interface_header_attribute5,'MGATE',rct.interface_header_attribute5,NULL) trvOracleXMLRunId,

           DECODE(rct.interface_header_context,'TURVO',rct.interface_header_attribute6,'MGATE',rct.interface_header_attribute6,NULL) trvXMLFileDate,

           --

           rct.ct_reference l_description

      FROM ra_customer_trx_all rct, 

           ra_cust_trx_types_all ctt,

           ar_customers rc,

           hz_cust_site_uses_all site_uses,

           hz_cust_acct_sites_all acct_sites,

           hz_party_sites party_sites,

           hz_locations hl,

           ra_terms_tl pt,

           ar_payment_schedules_all aps,

           ra_cust_trx_line_gl_dist_all rctd,

           gl_code_combinations gcc,

           fnd_currencies fc

     WHERE rct.org_id = gv_org_id

       AND rct.complete_flag = 'Y'

       AND rct.cust_trx_type_id = ctt.cust_trx_type_id

       AND rct.bill_to_customer_id = rc.customer_id

       AND rct.bill_to_site_use_id = site_uses.site_use_id

       AND site_uses.cust_acct_site_id = acct_sites.cust_acct_site_id

       AND acct_sites.party_site_id = party_sites.party_site_id

       AND party_sites.location_id = hl.location_id

       AND rct.term_id = pt.term_id (+)

       AND rct.customer_trx_id = aps.customer_trx_id (+)

       -- Estan abiertas

       AND aps.status = 'OP'

       AND rct.customer_trx_id = rctd.customer_trx_id

       AND rctd.account_class = 'REC'

       AND rctd.account_set_flag = 'N'

       AND rctd.code_combination_id = gcc.code_combination_id

       AND rct.invoice_currency_code = fc.currency_code

       AND aps.amount_due_remaining != 0

       --

       AND 1 = 2

       --

       AND NOT EXISTS ( SELECT 1 

                          FROM ajcl_bc_ar_dm_headers

                         WHERE customer_trx_id = rct.customer_trx_id

                           AND bc_environment = gv_bc_environment )

  ORDER BY DECODE(ctt.type,'INV',1,'DM',2,'CM',3);



    CURSOR c_lines ( p_customer_trx_id   IN   NUMBER,

                     p_class             IN   VARCHAR2,

                     p_amount            IN   NUMBER,

                     p_description       IN   VARCHAR2 ) IS

    SELECT rctl.customer_trx_id,

           rctl.customer_trx_line_id,

           1 line_number,

           SUBSTR(p_description,1,100) description,

           -- SUBSTR(gv_source || ' - ' || p_description,1,100) description,

           -- 20240912 DECODE(p_class,'INV',rctl.quantity_invoiced,NVL(ABS(rctl.quantity_credited),1)) quantity,

           1 quantity,

           -- 20240912

           p_amount unit_selling_price,

           p_amount extended_amount,

           p_amount accounted_amount,

           '1110.1200' account,

           NULL department,

           NULL product,         

           NULL destination,

           NULL office,

           NULL origin,   

           NULL intercompany,       

           rctl.sales_order_source,

           rctl.sales_order,

           rctl.sales_order_revision,

           rctl.sales_order_line,

           rctl.sales_order_date,

           gcc.segment2,

           -- rctd.attribute1 worksheet,

           NULL worksheet,

           -- Flexfields

           -- IES

           DECODE(rctl.interface_line_context,'IES',rctl.interface_line_attribute3,NULL) iesInvoiceLine,

           DECODE(rctl.interface_line_context,'IES',rctl.interface_line_attribute5,NULL) iesPickupDate,

           DECODE(rctl.interface_line_context,'IES',rctl.interface_line_attribute6,NULL) iesETD,

           DECODE(rctl.interface_line_context,'IES',rctl.interface_line_attribute7,NULL) iesETA,

           DECODE(rctl.interface_line_context,'IES',rctl.interface_line_attribute8,NULL) iesDestination,

           DECODE(rctl.interface_line_context,'IES',rctl.interface_line_attribute9,NULL) iesOrigin,

           -- CSA

           DECODE(rctl.interface_line_context,'CSA',rctl.interface_line_attribute5,NULL) csaPKSeqNumber,

           DECODE(rctl.interface_line_context,'CSA',rctl.interface_line_attribute6,NULL) csaSeqofCharge,

           DECODE(rctl.interface_line_context,'CSA',rctl.interface_line_attribute7,NULL) csaCreationDate,

           DECODE(rctl.interface_line_context,'CSA',rctl.interface_line_attribute8,NULL) csaOrderNo,

           DECODE(rctl.interface_line_context,'CSA',rctl.interface_line_attribute9,NULL) csaStationId,

           DECODE(rctl.interface_line_context,'CSA',rctl.interface_line_attribute10,NULL) csaSubAccount,

           DECODE(rctl.interface_line_context,'CSA',rctl.interface_line_attribute11,NULL) csaDivision,

           -- TRV

           DECODE(rctl.interface_line_context,'TURVO',rctl.interface_line_attribute7,'MGATE',rctl.interface_line_attribute7,NULL) trvItemSequence,

           DECODE(rctl.interface_line_context,'TURVO',rctl.interface_line_attribute8,'MGATE',rctl.interface_line_attribute8,NULL) trvMGLoadId,

           DECODE(rctl.interface_line_context,'TURVO',rctl.interface_line_attribute9,'MGATE',rctl.interface_line_attribute9,NULL) trvEDIItemCodeChargeType,

           DECODE(rctl.interface_line_context,'TURVO',rctl.interface_line_attribute10,'MGATE',rctl.interface_line_attribute10,NULL) trvDeliveryDate

      FROM ra_customer_trx_lines_all rctl,

           ra_cust_trx_line_gl_dist_all rctd,

           gl_code_combinations gcc

     WHERE rctl.customer_trx_id = p_customer_trx_id 

       AND rctl.customer_trx_line_id = ( SELECT MIN(customer_trx_line_id) FROM ra_cust_trx_line_gl_dist_all WHERE customer_trx_id = p_customer_trx_id )

       AND rctl.customer_trx_line_id = rctd.customer_trx_line_id

       AND rctd.account_class = 'REV'

       AND rctd.account_set_flag = 'N'

       AND rctd.code_combination_id = gcc.code_combination_id;



    v_bc_trx_num            VARCHAR2(20);

    v_line_error            VARCHAR2(1);



    -- v_applies_to_doc_no     ra_customer_trx_all.trx_number%TYPE;

    -- v_applies_to_doc_type   ra_cust_trx_types_all.type%TYPE;



    v_trvXMLFileDate        VARCHAR2(10);



    v_status                    VARCHAR2(1);

    v_error_message             VARCHAR2(2000);



    e_cust_exception        EXCEPTION;

    e_parameter_value       EXCEPTION;

    e_main_bc               EXCEPTION;



  BEGIN



    gv_request_id := ajcl_bc_utils_pkg.get_request_id_f;



    DELETE ajcl_bc_logs

     WHERE ifc = gv_bc_ifc;



    COMMIT;



    print_log ( 'ajcl_bc_ar_data_migration_pkg.main_p (+)');



    print_log ( 'gv_request_id: ' || gv_request_id );

    print_log ( 'gv_bc_ifc: ' || gv_bc_ifc );



    gv_oracle_db := ajcl_bc_utils_pkg.get_db_name_f;

    print_log ( 'gv_oracle_db: ' || gv_oracle_db );



    gv_jenkins_build_number := p_jenkins_build_number;

    print_log ( 'gv_jenkins_build_number: ' || gv_jenkins_build_number );



    print_log ( 'gv_report_filename: ' || gv_report_filename );



    print_log ( 'p_gl_date: ' || p_gl_date );

    print_log ( 'p_trx_num_prefix: ' || p_trx_num_prefix );

    print_log ( 'p_trx_num_type: ' || p_trx_num_type );  

    print_log ( 'p_export_type: ' || p_export_type );  

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

                                                               p_column => 'AR_RESP_ID' );



    print_log ( 'gv_resp_id: ' || gv_resp_id );



    fnd_global.apps_initialize ( user_id => 0,

                                 resp_id => gv_resp_id,

                                 resp_appl_id => 222 ); -- AR 



    mo_global.set_policy_context ('S', gv_org_id); 



    -- 20240928

    EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''AMERICAN''';

    -- 20240928



    -- Validacion parametro p_bc_environment -----------------------------------------------------------------------------------

    IF ( ajcl_bc_utils_pkg.is_bc_environment_valid_f ( p_bc_environment ) = 'N' ) THEN



      v_error_message := 'Invalid value (' || p_bc_environment || ') for parameter BC_ENVIRONMENT.';

      RAISE e_parameter_value;



    END IF;



    gv_bc_environment := p_bc_environment;

    print_log ( 'gv_bc_environment: ' || gv_bc_environment );



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



    gv_trx_num_prefix := p_trx_num_prefix;

    print_log ( 'gv_trx_num_prefix: ' || gv_trx_num_prefix );



    gv_trx_num_type := p_trx_num_type;

    print_log ( 'gv_trx_num_type: ' || gv_trx_num_type );



    gv_export_type := p_export_type;

    print_log ( 'gv_export_type: ' || gv_export_type );



    gv_migration_type := p_migration_type;

    print_log ( 'gv_migration_type: ' || gv_migration_type );



    IF ( gv_migration_type = 'ALL' ) THEN



      DELETE ajcl_bc_ar_dm_headers WHERE bc_environment = gv_bc_environment;

      print_log ( 'Se borra la tabla ajcl_bc_ar_dm_headers para bc_environment ' || gv_bc_environment || '. Cantidad registros borrados: ' || SQL%ROWCOUNT ); 



      DELETE ajcl_bc_ar_dm_lines WHERE bc_environment = gv_bc_environment;

      print_log ( 'Se borra la tabla ajcl_bc_ar_dm_lines para bc_environment ' || gv_bc_environment || '. Cantidad registros borrados: ' || SQL%ROWCOUNT ); 



      DELETE ajcl_bc_ar_dm_control WHERE bc_environment = gv_bc_environment;

      print_log ( 'Se borra la tabla ajcl_bc_ar_dm_control para bc_environment ' || gv_bc_environment || '. Cantidad registros borrados: ' || SQL%ROWCOUNT ); 



      COMMIT;



    END IF;



    -- Get Customers from BC

    ajcl_bc_get_entities_pkg.get_bc_customers_p ( p_bc_environment => gv_bc_environment,

                                                  p_bc_ifc => gv_bc_ifc,

                                                  p_request_id => gv_request_id,

                                                  p_log_seq => gv_log_seq,

                                                  p_status => v_status );



    IF ( v_status != 'S' ) THEN



      RAISE e_cust_exception;



    END IF;



    FOR ch IN c_headers LOOP



      print_log ( 'trx_number: ' || ch.trx_number || ' | customer_name: ' || ch.customer_name );



      -- Generate BC Invoice Num

      BEGIN



        v_bc_trx_num := -- REPLACE(

                          REPLACE(ch.trx_number,'TRV-',NULL)

                        -- ,'TRVA-',NULL)

                        ;  



        v_bc_trx_num := SUBSTR(gv_trx_num_prefix || v_bc_trx_num,1,17);



      EXCEPTION

        WHEN OTHERS THEN

          v_bc_trx_num := NULL;

          print_log(gv_trx_num_prefix || ch.trx_number);

          print_log(SQLERRM);



      END;   



      BEGIN



        v_line_error := 'N';



        FOR cl IN c_lines ( p_customer_trx_id => ch.customer_trx_id, 

                            p_class => ch.class,

                            p_amount => ch.amount, 

                            p_description => ch.l_description ) LOOP



          BEGIN



            -- Lines

            INSERT 

              INTO ajcl_bc_ar_dm_lines

                 ( bc_environment,

                   customer_trx_id,

                   customer_trx_line_id,

                   company,

                   line_number,

                   description,

                   quantity,

                   unit_selling_price,

                   extended_amount,

                   accounted_amount,

                   account,

                   department,

                   product,

                   destination,

                   office,

                   origin,

                   intercompany,

                   sales_order_source,

                   sales_order,

                   sales_order_revision,

                   sales_order_line,

                   sales_order_date,

                   worksheet,

                   -- Flexfields

                   -- IES

                   iesInvoiceLine,

                   iesPickupDate,

                   iesETD,

                   iesETA,

                   iesDestination,

                   iesOrigin,

                   -- CSA

                   csaPKSeqNumber,

                   csaSeqofCharge,

                   csaCreationDate,

                   csaOrderNo,

                   csaStationId,

                   csaSubAccount,

                   csaDivision,

                   -- TRV

                   trvItemSequence,

                   trvMGLoadId,

                   trvEDIItemCodeChargeType,

                   trvDeliveryDate,

                   --

                   status,

                   creation_date,

                   created_by,

                   last_update_date,

                   last_updated_by,

                   request_id )

          VALUES ( gv_bc_environment,

                   cl.customer_trx_id,

                   cl.customer_trx_line_id,

                   ch.company,

                   cl.line_number,

                   cl.description,

                   cl.quantity,

                   cl.unit_selling_price,

                   cl.extended_amount,

                   cl.accounted_amount,

                   cl.account, 

                   cl.department,

                   cl.product,

                   cl.destination,

                   cl.office,

                   cl.origin,

                   cl.intercompany,

                   cl.sales_order_source,

                   cl.sales_order,

                   cl.sales_order_revision,

                   cl.sales_order_line,

                   cl.sales_order_date,

                   cl.worksheet,

                   -- Flexfields

                   -- IES

                   cl.iesInvoiceLine,

                   cl.iesPickupDate,

                   cl.iesETD,

                   cl.iesETA,

                   cl.iesDestination,

                   cl.iesOrigin,

                   -- CSA

                   cl.csaPKSeqNumber,

                   cl.csaSeqofCharge,

                   cl.csaCreationDate,

                   cl.csaOrderNo,

                   cl.csaStationId,

                   cl.csaSubAccount,

                   cl.csaDivision,

                   -- TRV

                   cl.trvItemSequence,

                   cl.trvMGLoadId,

                   cl.trvEDIItemCodeChargeType,

                   cl.trvDeliveryDate,

                   --

                   'NEW', -- status

                   TRUNC(SYSDATE),

                   gv_user_id,

                   TRUNC(SYSDATE),

                   gv_user_id,

                   gv_request_id );



          EXCEPTION

            WHEN OTHERS THEN

              v_line_error := 'Y';

              print_log ( 'Error: ' || SQLERRM );



          END;



        END LOOP;



        IF ( v_line_error = 'N' ) THEN



          -- CAST DATES

          IF ( ch.original_source = 'TRV' ) THEN



            BEGIN

              v_trvXMLFileDate := TO_CHAR(TO_DATE(ch.trvXMLFileDate,'DD-MON-YY'),'YYYY-MM-DD');

            EXCEPTION

              WHEN OTHERS THEN

                BEGIN

                  v_trvXMLFileDate := TO_CHAR(TO_DATE(ch.trvXMLFileDate,'DD/MM/YYYY'),'YYYY-MM-DD');

                EXCEPTION

                  WHEN OTHERS THEN 

                    v_trvXMLFileDate := NULL;

                END;

            END;



          ELSE



            v_trvXMLFileDate := NULL;



          END IF;



          -- Headers

          INSERT 

            INTO ajcl_bc_ar_dm_headers

                 ( bc_environment,

                   customer_trx_id,

                   company,

                   oracle_trx_number,

                   trx_number,

                   trx_date,

                   class,

                   term_id,

                   term_name,

                   term_due_date,

                   gl_date,

                   invoice_currency_code,

                   exchange_date,

                   exchange_rate,

                   exchange_rate_type,

                   purchase_order,

                   amount,

                   accounted_amount,

                   account,

                   department,

                   product,

                   destination,

                   office,

                   origin,

                   intercompany,

                   customer_name,

                   customer_number,

                   bill_to_address_1,

                   bill_to_address_2,

                   bill_to_address_3,

                   worksheet,

                   applies_to_doc_type,

                   applies_to_doc_no,

                   override_flag,

                   comments,

                   -- Flexfields

                   invoiceReference1,

                   invoiceReference2,

                   source,

                   -- IES

                   iesInvoiceCompany,

                   iesInvoiceNumber,

                   iesNumber,

                   -- CSA

                   csaHousebill,

                   csaMaxCSAPKSeqNo,

                   csaCustomerVendor,

                   csaSeqNum,

                   csaFileExtractNumber,

                   -- TRV

                   trvShippingOrder,

                   trvInvoiceNum,

                   trvCustCarrierAcctNum,

                   trvXMLFileName,

                   trvOracleXMLRunId,

                   trvXMLFileDate,

                   --

                   status,

                   org_id,

                   creation_date,

                   created_by,

                   last_update_date,

                   last_updated_by,

                   request_id )

          VALUES ( gv_bc_environment,

                   ch.customer_trx_id,

                   ch.company,

                   ch.trx_number,

                   v_bc_trx_num,

                   ch.trx_date,

                   ch.class,

                   ch.term_id,

                   ch.term_name,

                   ch.term_due_date,

                   ch.gl_date,

                   ch.invoice_currency_code,

                   ch.exchange_date,

                   ch.exchange_rate,

                   ch.exchange_rate_type,

                   ch.purchase_order,

                   ch.amount,

                   ch.accounted_amount,

                   ch.account,

                   ch.department,

                   ch.product,

                   ch.destination,

                   ch.office,

                   ch.origin,

                   ch.intercompany,

                   ch.customer_name,

                   ch.customer_number,

                   ch.bill_to_address_1,

                   ch.bill_to_address_2,

                   ch.bill_to_address_3,

                   ch.worksheet,

                   NULL, -- v_applies_to_doc_type,

                   NULL, -- v_applies_to_doc_no,

                   ch.override_flag,

                   ch.comments,

                   -- Flexfields

                   ch.invoiceReference1,

                   ch.invoiceReference2,

                   ch.source,

                   -- IES

                   ch.iesInvoiceCompany,

                   ch.iesInvoiceNumber,

                   ch.iesNumber,

                   -- CSA

                   ch.csaHousebill,

                   ch.csaMaxCSAPKSeqNo,

                   ch.csaCustomerVendor,

                   ch.csaSeqNum,

                   ch.csaFileExtractNumber,

                   -- TRV

                   ch.trvShippingOrder,

                   ch.trvInvoiceNum,

                   ch.trvCustCarrierAcctNum,

                   ch.trvXMLFileName,

                   ch.trvOracleXMLRunId,

                   v_trvXMLFileDate, -- ch.trvXMLFileDate,

                   --

                   'NEW', -- status

                   ch.org_id,

                   TRUNC(SYSDATE),

                   gv_user_id,

                   TRUNC(SYSDATE),

                   gv_user_id,

                   gv_request_id );



        ELSE



          print_log ( 'Se produjo un error al insertar una línea del comprobante.' );



        END IF;



      EXCEPTION

        WHEN e_cust_exception THEN

          print_log ( v_error_message );

          RAISE;



      END;



    END LOOP;



    -- QUITAR

    -- Sirve para reprocesar registros de un request_id anterior

    -- Se debe comentar el loop de arriba para que no vuelva a generar

    /*

    UPDATE ajcl_bc_ar_dm_headers

       SET status = 'NEW',

           error_message = NULL,

           json_data = NULL,

           json_data_response = NULL,

           request_id = gv_request_id

     WHERE status != 'SUCCESS'

       AND request_id = 20

       AND bc_environment = gv_bc_environment;



    UPDATE ajcl_bc_ar_dm_lines

       SET status = 'NEW',

           error_message = NULL,

           json_data = NULL,

           json_data_response = NULL,

           request_id = gv_request_id

     WHERE status != 'SUCCESS'

       AND request_id = 20

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

                                              p_subject => gv_bc_ifc || ' - ' || gv_oracle_db || ' - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'),

                                              p_body => gv_oracle_db || ' > ' || p_bc_environment || CHR(10) || CHR(10) || 

                                                        -- 

                                                        'Export Type: ' || p_export_type,

                                              p_type => 'REPORT',

                                              p_filename => gv_report_filename, 

                                              p_file_format => gv_file_format,

                                              p_attach_filename => gv_bc_ifc || ' - ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24MISS') || '.' || LOWER(gv_file_format) );  



    COMMIT;



    print_log ( 'ajcl_bc_ar_data_migration_pkg.main_p (-)');



  EXCEPTION

    WHEN e_parameter_value THEN

      print_log('ajcl_bc_ar_data_migration_pkg.main_p (!)');

      print_log(v_error_message);



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_mail,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') || ' - ERROR',

                                       p_message => v_error_message );



    WHEN e_main_bc THEN

      print_log('ajcl_bc_ar_data_migration_pkg.main_p (!)');

      print_log(v_error_message);



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_mail,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') || ' - ERROR',

                                       p_message => v_error_message );



    WHEN e_cust_exception THEN

      print_log('ajcl_bc_ar_data_migration_pkg.main_p (!)');



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_mail,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') || ' - ERROR',

                                       p_message => v_error_message );



    WHEN OTHERS THEN

      print_log('ajcl_bc_ar_data_migration_pkg.main_p (!)');

      print_log('Error: ' || SQLERRM);



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_mail,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') || ' - ERROR',

                                       p_message => SQLERRM );



  END main_p;



END ajcl_bc_ar_data_migration_pkg;
