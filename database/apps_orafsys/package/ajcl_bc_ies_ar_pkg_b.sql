PACKAGE BODY ajcl_bc_ies_ar_pkg IS
-- Creation: SBANCHIERI 23-AUG-2023
  
  -- Setear en N cuando se usan los triggers de PROD a FINUPG5/FINUPG6
  -- Setear en Y cuando se necesite cargar la data de files / tables
  gv_ftp_loader         VARCHAR2(1); -- := 'N'; -- Se resuelve mas abajo, segun la db

  -- Parameters
  gv_data_file_name     VARCHAR2(200) := 'AJC_IES_AR_FILE.xml';
  --

  -- 20251106 REINTENTO
  gv_retry_in_seconds   NUMBER;
  gv_retry              VARCHAR2(1);
  -- 20251106 REINTENTO

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    gv_log_seq := gv_log_seq + 1;
    ajcl_bc_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );

  END print_log;

  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    ajcl_bc_utils_pkg.insert_output_p ( gv_bc_ifc, p_message, gv_request_id );

  END print_output;

  PROCEDURE print_output_xlsx ( p_section      VARCHAR2,
                                p_column1      VARCHAR2,
                                p_column2      VARCHAR2 DEFAULT NULL,
                                p_column3      VARCHAR2 DEFAULT NULL,
                                p_column4      VARCHAR2 DEFAULT NULL,
                                p_column5      VARCHAR2 DEFAULT NULL,
                                p_column6      VARCHAR2 DEFAULT NULL,
                                p_column7      VARCHAR2 DEFAULT NULL,
                                p_column8      VARCHAR2 DEFAULT NULL,
                                p_column9      VARCHAR2 DEFAULT NULL,
                                p_column10     VARCHAR2 DEFAULT NULL,
                                p_column11     VARCHAR2 DEFAULT NULL,
                                p_column12     VARCHAR2 DEFAULT NULL,
                                p_column13     VARCHAR2 DEFAULT NULL,
                                p_column14     VARCHAR2 DEFAULT NULL,
                                p_column15     VARCHAR2 DEFAULT NULL,
                                p_column16     VARCHAR2 DEFAULT NULL,
                                p_column17     VARCHAR2 DEFAULT NULL,
                                p_column18     VARCHAR2 DEFAULT NULL,
                                p_column19     VARCHAR2 DEFAULT NULL,
                                p_column20     VARCHAR2 DEFAULT NULL ) IS
  BEGIN

    ajcl_bc_utils_pkg.insert_output_xlsx_p ( p_ifc => gv_bc_ifc,
                                             p_section => p_section,
                                             p_column1 => p_column1,
                                             p_column2 => p_column2,
                                             p_column3 => p_column3,
                                             p_column4 => p_column4,
                                             p_column5 => p_column5,
                                             p_column6 => p_column6,
                                             p_column7 => p_column7,
                                             p_column8 => p_column8,
                                             p_column9 => p_column9,
                                             p_column10 => p_column10,
                                             p_column11 => p_column11,
                                             p_column12 => p_column12,
                                             p_column13 => p_column13,
                                             p_column14 => p_column14,
                                             p_column15 => p_column15,
                                             p_column16 => p_column16,
                                             p_column17 => p_column17,
                                             p_column18 => p_column18,
                                             p_column19 => p_column19,
                                             p_column20 => p_column20,
                                             p_request_id => gv_request_id );

  END print_output_xlsx;

  PROCEDURE populate_table_p ( p_status   OUT   VARCHAR2 ) IS

      CURSOR sel_lines IS
      SELECT line_num, trim(line) line
        FROM ajc_ies_ar_file
       WHERE line_num > 7
    ORDER BY line_num;

    v_sql_stmt_id         INTEGER := 0;
   v_rec_count            INTEGER := 0;
   v_run_date             DATE;
   v_line                 VARCHAR2(2000);
   v_line_num             INTEGER := 0;
   v_user_id	             fnd_user.user_id%TYPE := FND_GLOBAL.user_id;
   v_charge_type_code     ajc_ar_ies_inbound_data.charge_type_code%TYPE := null;
   v_charge_type          ajc_ar_ies_inbound_data.charge_type%TYPE := null;
   v_company_number       ajc_ar_ies_inbound_data.company_number%TYPE := null;
   v_division             ajc_ar_ies_inbound_data.division%TYPE := null;
   v_business_line        ajc_ar_ies_inbound_data.business_line%TYPE := null;
   v_task                 ajc_ar_ies_inbound_data.task%TYPE := null;
   v_gl_account           ajc_ar_ies_inbound_data.gl_account%TYPE := null;
   v_location             ajc_ar_ies_inbound_data.location%TYPE := null;
   v_project              ajc_ar_ies_inbound_data.project%TYPE := null;
   v_invoice_number       ajc_ar_ies_inbound_data.invoice_number%TYPE := null;
   v_invoice_type         ajc_ar_ies_inbound_data.invoice_type%TYPE := null;
   v_financial_party      ajc_ar_ies_inbound_data.financial_party%TYPE := null;
   v_me_number            ajc_ar_ies_inbound_data.me_number%TYPE := null;
   v_transaction_type     ajc_ar_ies_inbound_data.transaction_type%TYPE := null;
   v_accounting_date      ajc_ar_ies_inbound_data.accounting_date%TYPE := null;
   v_due_date             ajc_ar_ies_inbound_data.due_date%TYPE := null;
   v_charge_amount        ajc_ar_ies_inbound_data.charge_amount%TYPE := null;
   v_currency_code        ajc_ar_ies_inbound_data.currency_code%TYPE := null;
   v_terms                ajc_ar_ies_inbound_data.terms%TYPE := null;
   v_reference_type_1     ajc_ar_ies_inbound_data.reference_type_1%TYPE := null;
   v_reference_value_1    ajc_ar_ies_inbound_data.reference_value_1%TYPE := null;
   v_destination_country  ajc_ar_ies_inbound_data.destination_country%TYPE := null;
   v_origin_country       ajc_ar_ies_inbound_data.origin_country%TYPE := null;
   v_description          ajc_ar_ies_inbound_data.description%TYPE := null;

   -- 20241001
   v_pending_records      NUMBER;
   -- 20241001

  BEGIN

    print_log('ajcl_bc_ies_ar_pkg.populate_table_p (+)');

    v_run_date := SYSDATE;

    FOR sel_lines_rec IN sel_lines LOOP

      v_line_num := sel_lines_rec.line_num;
      v_line := sel_lines_rec.line;

      IF ( sel_lines_rec.line = '<ACCOUNTING_EVENT>' ) THEN

        v_charge_type_code := null;
        v_charge_type := null;
        v_company_number := null;
        v_division := null;
        v_business_line := null;
        v_task := null;
        v_gl_account := null;
        v_location := null;
        v_project := null;
        v_invoice_number := null;
        v_invoice_type := null;
        v_financial_party := null;
        v_me_number := null;
        v_transaction_type := null;
        v_accounting_date := null;
        v_due_date := null;
        v_charge_amount := null;
        v_currency_code := null;
        v_terms := null;
        v_reference_type_1 := null;
        v_reference_value_1 := null;
        v_destination_country := null;
        v_origin_country := null;
        v_description := null;

      END IF;

      IF ( sel_lines_rec.line like '<CHARGE_TYPE>%' ) THEN

        v_charge_type := replace(replace(sel_lines_rec.line,'</CHARGE_TYPE>'),'<CHARGE_TYPE>');

      END IF;

      IF ( sel_lines_rec.line like '<CHARGE_TYPE_CODE>%' ) THEN

        v_charge_type_code := replace(replace(sel_lines_rec.line,'</CHARGE_TYPE_CODE>'),'<CHARGE_TYPE_CODE>');

      END IF;

      IF ( sel_lines_rec.line like '<COMPANY_NUMBER>%' ) THEN

        v_company_number := replace(replace(sel_lines_rec.line,'</COMPANY_NUMBER>'),'<COMPANY_NUMBER>');

      END IF;

      IF ( sel_lines_rec.line like '<DIVISION>%' ) THEN

        v_division := replace(replace(sel_lines_rec.line,'</DIVISION>'),'<DIVISION>');

      END IF;

      IF ( sel_lines_rec.line like '<BUSINESS_LINE>%' ) THEN

        v_business_line := replace(replace(sel_lines_rec.line,'</BUSINESS_LINE>'),'<BUSINESS_LINE>');

      END IF;

      IF ( sel_lines_rec.line like '<TASK>%' ) THEN

        v_task := replace(replace(sel_lines_rec.line,'</TASK>'),'<TASK>');

      END IF;

      IF ( sel_lines_rec.line like '<GL_ACCOUNT>%' ) THEN

        v_gl_account := replace(replace(sel_lines_rec.line,'</GL_ACCOUNT>'),'<GL_ACCOUNT>');

      END IF;

      IF ( sel_lines_rec.line like '<LOCATION>%' ) THEN

        v_location := replace(replace(sel_lines_rec.line,'</LOCATION>'),'<LOCATION>');

      END IF;

      IF ( sel_lines_rec.line like '<PROJECT>%' ) THEN

        v_project := replace(replace(sel_lines_rec.line,'</PROJECT>'),'<PROJECT>');

      END IF;

      IF ( sel_lines_rec.line like '<INVOICE_NUMBER>%' ) THEN

        v_invoice_number := replace(replace(sel_lines_rec.line,'</INVOICE_NUMBER>'),'<INVOICE_NUMBER>');

      END IF;

      IF ( sel_lines_rec.line like '<INVOICE_TYPE>%' ) THEN

        v_invoice_type := replace(replace(sel_lines_rec.line,'</INVOICE_TYPE>'),'<INVOICE_TYPE>');

      END IF;

      IF ( sel_lines_rec.line like '<FINANCIAL_PARTY>%' ) THEN

        v_financial_party := replace(replace(sel_lines_rec.line,'</FINANCIAL_PARTY>'),'<FINANCIAL_PARTY>');

      END IF;

      IF ( sel_lines_rec.line like '<ME_NUMBER>%' ) THEN

        v_me_number := replace(replace(sel_lines_rec.line,'</ME_NUMBER>'),'<ME_NUMBER>');

      END IF;

      IF ( sel_lines_rec.line like '<TRANSACTION_TYPE>%' ) THEN

        v_transaction_type := replace(replace(sel_lines_rec.line,'</TRANSACTION_TYPE>'),'<TRANSACTION_TYPE>');

      END IF;

      IF ( sel_lines_rec.line like '<ACCOUNTING_DATE>%' ) THEN

        v_accounting_date := replace(replace(sel_lines_rec.line,'</ACCOUNTING_DATE>'),'<ACCOUNTING_DATE>');

      END IF;

      IF ( sel_lines_rec.line like '<DUE_DATE>%' ) THEN

        v_due_date := replace(replace(sel_lines_rec.line,'</DUE_DATE>'),'<DUE_DATE>');

      END IF;

      IF ( sel_lines_rec.line like '<CHARGE_AMOUNT>%' ) THEN

        v_charge_amount := replace(replace(sel_lines_rec.line,'</CHARGE_AMOUNT>'),'<CHARGE_AMOUNT>');

      END IF;

      IF ( sel_lines_rec.line like '<CURRENCY_CODE>%' ) THEN

        v_currency_code := replace(replace(sel_lines_rec.line,'</CURRENCY_CODE>'),'<CURRENCY_CODE>');

      END IF;

      IF ( sel_lines_rec.line like '<TERMS>%' ) THEN

        v_terms := replace(replace(sel_lines_rec.line,'</TERMS>'),'<TERMS>');

      END IF;

      IF ( sel_lines_rec.line like '<REFERENCE_TYPE_1>%' ) THEN

        v_reference_type_1 := replace(replace(sel_lines_rec.line,'</REFERENCE_TYPE_1>'),'<REFERENCE_TYPE_1>');

      END IF;

      IF ( sel_lines_rec.line like '<REFERENCE_VALUE_1>%' ) THEN

        v_reference_value_1 := replace(replace(sel_lines_rec.line,'</REFERENCE_VALUE_1>'),'<REFERENCE_VALUE_1>');

      END IF;

      IF ( sel_lines_rec.line like '<ORIGIN_COUNTRY>%' ) THEN

        v_origin_country := replace(replace(sel_lines_rec.line,'</ORIGIN_COUNTRY>'),'<ORIGIN_COUNTRY>');

      END IF;

      IF ( sel_lines_rec.line like '<DESTINATION_COUNTRY>%' ) THEN

        v_destination_country := replace(replace(sel_lines_rec.line,'</DESTINATION_COUNTRY>'),'<DESTINATION_COUNTRY>');

      END IF;

      IF ( sel_lines_rec.line = '</ACCOUNTING_EVENT>' ) THEN

        v_sql_stmt_id := 10;

        INSERT 
          INTO ajc_ar_ies_inbound_data
             ( charge_type,
               charge_type_code,
               company_number,
               division,
               business_line,
               task,
               gl_account,
               location,
               project,
               invoice_number,
               invoice_type,
               financial_party,
               me_number,
               transaction_type,
               accounting_date,
               due_date,
               charge_amount,
               currency_code,
               terms,
               reference_type_1,
               reference_value_1,
               destination_country,
               origin_country,
               description )
      VALUES ( v_charge_type,
               v_charge_type_code,
               v_company_number,
               v_division,
               v_business_line,
               v_task,
               v_gl_account,
               v_location,
               v_project,
               v_invoice_number,
               v_invoice_type,
               v_financial_party,
               v_me_number,
               v_transaction_type,
               v_accounting_date,
               v_due_date,
               v_charge_amount,
               v_currency_code,
               v_terms,
               v_reference_type_1,
               v_reference_value_1,
               v_destination_country,
               v_origin_country,
               v_description );

        v_rec_count := v_rec_count + 1;

      END IF;

    END LOOP;

    v_sql_stmt_id := 20;

    UPDATE ajc_ar_ies_inbound_data 
       SET interface_status = 'UN-PROCESSED',
           financial_party = decode(substr(trim(financial_party),1,1),'*', substr(financial_party,2,length(financial_party) -1),financial_party),
           created_by = v_user_id,
           creation_date = v_run_date,
           last_update_date = v_run_date,
           inbound_file_name = 'AJC_IES_AR_FILE ' || to_char(v_run_date,'DD-MON-YYYY HH24:MI:SS')
     WHERE interface_status IS NULL;

    print_log(TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS') || ' Total IES AR records inserted: ' || v_rec_count);

    -- 20241001
    -- Se verifica si hay algo pendiente de procesar
    SELECT COUNT(1)
      INTO v_pending_records
      FROM ( SELECT invoice_number, 
                    financial_party, 
                    terms
               FROM ajc_ar_ies_inbound_data
              WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'
           GROUP BY invoice_number, 
                    financial_party, 
                    terms
             HAVING SUM(charge_amount) > 0 );

    print_log ( 'v_pending_records: ' || v_pending_records );
    -- 20241001

    -- Si no inserto nada y no hay nada pendiente para procesar en la tabla, solo se reprocesa lo que no haya ingresado a BC de ejecuciones anteriores
    -- 20241001 IF ( v_rec_count = 0 ) THEN
    IF ( v_rec_count = 0 AND v_pending_records = 0 ) THEN

      gv_only_reprocess := 'Y';

    END IF;

    print_log('gv_only_reprocess: ' || gv_only_reprocess);

    print_log('ajcl_bc_ies_ar_pkg.populate_table_p (-)');

  EXCEPTION
    WHEN OTHERS THEN
      p_status := 'E';
      print_log('ajcl_bc_ies_ar_pkg.populate_table_p (!). Processing Line: ' || v_line_num || '/' || v_line || '. Error: ' || SQLERRM || '. sql statement: ' || v_sql_stmt_id);

  END populate_table_p;

  PROCEDURE control_report_p ( p_status   OUT   VARCHAR2 ) IS

      CURSOR c_total_count IS
      SELECT COUNT(DISTINCT financial_party || ' ' || invoice_number) inv_count,
             SUM(charge_amount) inv_amt
        FROM ajc_ar_ies_inbound_data
       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'
    GROUP BY TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS');

  BEGIN

    print_log ( 'ajcl_bc_ies_ar_pkg.control_report_p (+)' );

    IF ( gv_file_format = 'CSV' ) THEN

      print_output ( 'Date|' || SYSDATE );
      print_output ( 'AJC AR IES Processing Control Report' );
      print_output ( ' ' );

      print_output ( 'Inv Count' || '|' ||
                     'Inv Amount' );

      -- Se setea en warning, si hay algun registro a procesar, se setea en success.
      -- Si no hay registros, termina en warning
      p_status := 'W';

      FOR ctc IN c_total_count LOOP

        print_output ( ctc.inv_count || '|' ||
                       ctc.inv_amt );  

        p_status := 'S';

      END LOOP;    

    ELSIF ( gv_file_format = 'XLSX' ) THEN 

      -- Column Names
      print_output_xlsx ( p_section => 'Processing Control Report',
                          p_column1 => 'Inv Count',
                          p_column2 => 'Inv Amount' );    

      FOR ctc IN c_total_count LOOP

        print_output_xlsx ( p_section => 'Processing Control Report',
                            p_column1 => ctc.inv_count,
                            p_column2 => ctc.inv_amt );

      END LOOP;                            

    END IF;

    print_log ( 'ajcl_bc_ies_ar_pkg.control_report_p (-)' );

  EXCEPTION
    WHEN OTHERS THEN
      p_status := 'E';
      print_log('ajcl_bc_ies_ar_pkg.control_report_p (!). Error: ' || SQLERRM);

  END control_report_p;

  PROCEDURE data_list_p ( p_status   OUT   VARCHAR2 ) IS

      CURSOR c_listing IS
      SELECT inbound_file_name,
             financial_party,
             invoice_number,
             TO_CHAR(null) accounting_date,
             TO_CHAR(null) charge_type_code,
             TO_CHAR(null) business_line,
             NULL charge_amount,
             1 flag,
             TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS') report_date
        FROM ( SELECT DISTINCT inbound_file_name,
                      financial_party,
                      invoice_number
                 FROM ajc_ar_ies_inbound_data
                WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED' )
       UNION
      SELECT inbound_file_name,
             financial_party,
             invoice_number,
             accounting_date,
             charge_type_code,
             business_line,
             charge_amount,
             2 flag,
             TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS') report_date
        FROM ( SELECT inbound_file_name,
                      financial_party,
                      invoice_number,
                      accounting_date,
                      charge_type_code,
                      business_line,
                      charge_amount
                 FROM ajc_ar_ies_inbound_data
                WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED' )
    ORDER BY 2,3,4,8,5,6,7;

    CURSOR c_list IS
    SELECT inbound_file_name,
           financial_party,
           invoice_number,
           accounting_date,
           charge_type_code,
           business_line,
           charge_amount
      FROM ajc_ar_ies_inbound_data
     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED';

  BEGIN

    print_log('ajcl_bc_ies_ar_pkg.data_list_p (+)');

    IF ( gv_file_format = 'CSV' ) THEN

      print_output ( ' ' );
      print_output ( 'Date|' || SYSDATE );
      print_output ( 'AJC AR IES Inbound Detailed Data Listing' );
      print_output ( ' ' );

      print_output ( 'Inbound File Name' || '|' ||
                     'Acct. Date' || '|' ||
                     'Chrg' || '|' ||
                     'Bus' || '|' ||
                     'Financial Party' || '|' ||
                     'Invoice Num' || '|' ||
                     'Charge Amount' );

      FOR cl IN c_listing LOOP

        print_output ( cl.inbound_file_name || '|' ||
                       cl.accounting_date || '|' ||
                       cl.charge_type_code || '|' ||
                       cl.business_line || '|' ||
                       cl.financial_party || '|' ||
                       cl.invoice_number || '|' ||
                       cl.charge_amount );

      END LOOP;

    ELSIF ( gv_file_format = 'XLSX' ) THEN 

      -- Column Names
      print_output_xlsx ( p_section => 'Inbound Detailed Data Listing',
                          p_column1 => 'Inbound File Name',
                          p_column2 => 'Accounting Date',
                          p_column3 => 'Charge Type',
                          p_column4 => 'Business Line',
                          p_column5 => 'Financial Party',
                          p_column6 => 'Invoice Nummber',
                          p_column7 => 'Charge Amount' );

      -- NEW
      FOR cl IN c_list LOOP 

        print_output_xlsx ( p_section => 'Inbound Detailed Data Listing',
                            p_column1 => cl.inbound_file_name,
                            p_column2 => cl.accounting_date,
                            p_column3 => cl.charge_type_code,
                            p_column4 => cl.business_line,
                            p_column5 => cl.financial_party,
                            p_column6 => cl.invoice_number,
                            p_column7 => cl.charge_amount );

      END LOOP;  

    END IF;

    p_status := 'S';

    print_log('ajcl_bc_ies_ar_pkg.data_list_p (-)');

  EXCEPTION
    WHEN OTHERS THEN
      p_status := 'E';
      print_log('ajcl_bc_ies_ar_pkg.data_list_p (!). Error: ' || SQLERRM);

  END data_list_p;

  PROCEDURE validate_preprocess_p ( p_status   OUT   VARCHAR2 ) IS

      CURSOR c_missing_customer_excep IS 
      SELECT DISTINCT financial_party,
             SUBSTR(invoice_number,1,20) invoice_number,
             'Customer not found.' error_message,
             to_char(sysdate,'DD-MON-YYYY HH24:MI:SS') report_date,
             1 print_order
        FROM ajc_ar_ies_inbound_data a
       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'
         AND NOT EXISTS ( SELECT 'x'
                            FROM hz_cust_accounts_all
                           WHERE TRIM(UPPER(attribute6)) = TRIM(UPPER(a.financial_party)) )
       UNION
      SELECT DISTINCT financial_party,
             SUBSTR(invoice_number,1,20) invoice_number,
             'Primary bill-to site not found.' error_message,
             TO_CHAR(sysdate,'DD-MON-YYYY HH24:MI:SS') report_date,
             2 print_order
        FROM ajc_ar_ies_inbound_data a
       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'
         AND EXISTS ( SELECT 'x'
                        FROM hz_cust_accounts_all
                       WHERE TRIM(UPPER(attribute6)) = TRIM(UPPER(a.financial_party)) )
         AND NOT EXISTS ( SELECT 'x'
                            FROM hz_cust_accounts_all hza, 
                                 hz_cust_acct_sites_all hcas, 
                                 hz_cust_site_uses_all hcsu
                           WHERE TRIM(UPPER(hza.attribute6)) = TRIM(UPPER(a.financial_party))
                             AND hcas.cust_account_id = hza.cust_account_id
                             AND hcas.org_id = gv_org_id
                             AND hcsu.org_id = gv_org_id
                             AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
                             AND hcsu.status = 'A'
                             AND hcsu.primary_flag = 'Y'
                             AND hcsu.site_use_code = 'BILL_TO' )
       UNION
      SELECT DISTINCT financial_party,
             SUBSTR(invoice_number,1,20) invoice_number,
             'Primary ship-to site not found.' error_message,
             TO_CHAR(sysdate,'DD-MON-YYYY HH24:MI:SS') report_date,
             3 print_order
        FROM ajc_ar_ies_inbound_data a
       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'
         AND EXISTS ( SELECT 'x'
                        FROM hz_cust_accounts_all
                       WHERE TRIM(UPPER(attribute6)) = TRIM(UPPER(a.financial_party)) )
         AND NOT EXISTS ( SELECT 'x'
                            FROM hz_cust_accounts_all hca, 
                                 hz_cust_acct_sites_all hcas, 
                                 hz_cust_site_uses_all hcsu
                           WHERE TRIM(UPPER(hca.attribute6)) = TRIM(UPPER(a.financial_party))
                             AND hcas.cust_account_id = hca.cust_account_id
                             AND hcas.org_id = gv_org_id
                             AND hcsu.org_id = gv_org_id
                             AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
                             AND hcsu.status = 'A'
                             AND hcsu.primary_flag = 'Y'
                             AND hcsu.site_use_code = 'SHIP_TO')
       UNION
      SELECT DISTINCT financial_party,
             SUBSTR(invoice_number,1,20) invoice_number,
             'Duplicate customers found.' error_message,
             TO_CHAR(sysdate,'DD-MON-YYYY HH24:MI:SS') report_date,
             4 print_order
        FROM ajc_ar_ies_inbound_data a
       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'
         AND 1 < ( SELECT NVL(COUNT(1),0)
                     FROM hz_cust_accounts_all
                    WHERE TRIM(UPPER(attribute6)) = TRIM(UPPER(a.financial_party)))
    ORDER BY 5,1;

      CURSOR c_missing_item_definition IS
      SELECT DISTINCT TRIM(charge_type_code) || '.' || TRIM(business_line) item,
             'Item not found.' error_message,
             TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS') report_date,
             1 print_order
        FROM ajc_ar_ies_inbound_data a
       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'
         AND NOT EXISTS ( SELECT 'x'
                            FROM ajcl_bc_ies_items b
                           WHERE bc_environment = gv_bc_environment
                             AND TRIM(b.charge_type_code) = ( SELECT NVL(substitute,TRIM(a.charge_type_code))
                                                                FROM ajcl_bc_ies_charge_types
                                                               WHERE bc_environment = gv_bc_environment
                                                                 AND charge_type_code = TRIM(a.charge_type_code)
                                                               UNION
                                                              SELECT TRIM(a.charge_type_code)
                                                                FROM dual
                                                               WHERE NOT EXISTS ( SELECT 'x'
                                                                                    FROM ajcl_bc_ies_charge_types
                                                                                   WHERE bc_environment = gv_bc_environment
                                                                                     AND charge_type_code = TRIM(a.charge_type_code) ) )
                             AND TRIM(b.business_line) = TRIM(a.business_line) )
       UNION
      SELECT DISTINCT TRIM(charge_type_code) || '.' || TRIM(business_line) item,
             'Item is inactive.' error_message,
             to_char(sysdate,'DD-MON-YYYY HH24:MI:SS') report_date,
             2 print_order
        FROM ajc_ar_ies_inbound_data a
       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'
         AND EXISTS ( SELECT 'x'
                        FROM ajcl_bc_ies_items b
                       WHERE bc_environment = gv_bc_environment
                         AND TRIM(b.charge_type_code) = ( SELECT NVL(substitute, TRIM(a.charge_type_code))
                                                            FROM ajcl_bc_ies_charge_types
                                                           WHERE bc_environment = gv_bc_environment
                                                             AND charge_type_code = TRIM(a.charge_type_code)
                                                           UNION
                                                          SELECT TRIM(a.charge_type_code)
                                                            FROM dual
                                                           WHERE NOT EXISTS ( SELECT 'x'
                                                                                FROM ajcl_bc_ies_charge_types
                                                                               WHERE bc_environment = gv_bc_environment
                                                                                 AND charge_type_code = TRIM(a.charge_type_code) ) )
                         AND TRIM(b.business_line) = TRIM(a.business_line))
         AND EXISTS ( SELECT 'x'
                        FROM ajcl_bc_ies_items b
                       WHERE bc_environment = gv_bc_environment
                         AND TRIM(b.charge_type_code) = ( SELECT NVL(substitute, TRIM(a.charge_type_code))
                                                            FROM ajcl_bc_ies_charge_types
                                                           WHERE bc_environment = gv_bc_environment
                                                             AND charge_type_code = TRIM(a.charge_type_code)
                                                           UNION
                                                          SELECT TRIM(a.charge_type_code)
                                                            FROM dual
                                                           WHERE NOT EXISTS ( SELECT 'x'
                                                                                FROM ajcl_bc_ies_charge_types
                                                                               WHERE bc_environment = gv_bc_environment
                                                                                 AND charge_type_code = TRIM(a.charge_type_code) ) )
                         AND TRIM(b.business_line) = TRIM(a.business_line)
                         AND NVL(b.inactive_date,SYSDATE + 1) <= SYSDATE )
       UNION
      SELECT DISTINCT TRIM(charge_type_code) || '.' || TRIM(business_line) item,
             'Sales account not populated for item.' error_message,
             TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS') report_date,
             3 print_order
        FROM ajc_ar_ies_inbound_data a
       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'
         AND EXISTS ( SELECT 'x'
                        FROM ajcl_bc_ies_items b
                       WHERE bc_environment = gv_bc_environment
                         AND TRIM(b.charge_type_code) = ( SELECT NVL(substitute, TRIM(a.charge_type_code))
                                                            FROM ajcl_bc_ies_charge_types
                                                           WHERE bc_environment = gv_bc_environment
                                                             AND charge_type_code = TRIM(a.charge_type_code)
                                                           UNION
                                                          SELECT TRIM(a.charge_type_code)
                                                            FROM dual
                                                          WHERE NOT EXISTS ( SELECT 'x'
                                                                               FROM ajcl_bc_ies_charge_types
                                                                              WHERE bc_environment = gv_bc_environment
                                                                                AND charge_type_code = TRIM(a.charge_type_code) ) )
                         AND TRIM(b.business_line) = TRIM(a.business_line) )
         AND EXISTS ( SELECT 'x'
                        FROM ajcl_bc_ies_items b
                       WHERE bc_environment = gv_bc_environment
                         AND TRIM(b.charge_type_code) = ( SELECT NVL(substitute, TRIM(a.charge_type_code))
                                                            FROM ajcl_bc_ies_charge_types
                                                           WHERE bc_environment = gv_bc_environment
                                                             AND charge_type_code = TRIM(a.charge_type_code)
                                                           UNION
                                                          SELECT TRIM(a.charge_type_code)
                                                            FROM dual
                                                           WHERE NOT EXISTS ( SELECT 'x'
                                                                                FROM ajcl_bc_ies_charge_types
                                                                               WHERE bc_environment = gv_bc_environment
                                                                                 AND charge_type_code = TRIM(a.charge_type_code) ) )
                         AND TRIM(b.business_line) = TRIM(a.business_line)
                         AND b.rev_accountno IS NULL )
    ORDER BY 4, 1;

      CURSOR c_missing_payment_terms IS
      SELECT DISTINCT terms,
             'Payment term not found.' error_message
        FROM ajc_ar_ies_inbound_data a
       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'
         AND NOT EXISTS ( SELECT 'x'
                            FROM ra_terms
                     
