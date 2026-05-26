PACKAGE BODY ajcl_bc_ar_data_migration_pkg IS
  
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
    print_log ('v_job_object_id: ' || v_job_object_id || ' - ' || TO_CHAR(SYSDATE,'YYYY-MM-DD
