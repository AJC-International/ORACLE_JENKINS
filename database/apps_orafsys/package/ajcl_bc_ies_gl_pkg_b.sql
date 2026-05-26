PACKAGE BODY ajcl_bc_ies_gl_pkg IS
-- Creation: SBANCHIERI 23-AUG-2023

  gv_ftp_loader      VARCHAR2(1); -- := 'N'; -- Se resuelve mas abajo, segun la db

  -- Parameters
  gv_data_file_name     VARCHAR2(200) := 'AJC_IES_AP_FILE.xml';
  gv_journal_source     VARCHAR2(200) := '1221'; -- IES Payables
  gv_journal_category   VARCHAR2(200) := 'Accrual';
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
      SELECT line_num, 
             TRIM(line) line
        FROM ajc_ies_ap_file
       WHERE line_num > 7
    ORDER BY line_num;

   v_sql_stmt_id          INTEGER := 0;
   v_remove_char          INTEGER := 0;
   v_rec_count            INTEGER := 0;
   v_ap_file_count        INTEGER := 0;
   v_run_date             DATE;
   v_line                 VARCHAR2(2000);
   v_line_num             INTEGER := 0;
   v_user_id	             fnd_user.user_id%TYPE := 0;
   v_charge_type_code     ajc_ap_ies_inbound_data.charge_type_code%TYPE := NULL;
   v_carrier              ajc_ap_ies_inbound_data.carrier%TYPE := NULL;
   v_type_of_move         ajc_ap_ies_inbound_data.type_of_move%TYPE := NULL;
   v_master_blawb_number  ajc_ap_ies_inbound_data.master_blawb_number%TYPE := NULL;
   v_house_blawb_number   ajc_ap_ies_inbound_data.house_blawb_number%TYPE := NULL;
   v_financial_party_external_id   ajc_ap_ies_inbound_data.financial_party_external_id%TYPE := NULL;
   v_charge_type          ajc_ap_ies_inbound_data.charge_type%TYPE := NULL;
   v_company_number       ajc_ap_ies_inbound_data.company_number%TYPE := NULL;
   v_shipment_reference   ajc_ap_ies_inbound_data.shipment_reference%TYPE := NULL;
   v_division             ajc_ap_ies_inbound_data.division%TYPE := NULL;
   v_business_line        ajc_ap_ies_inbound_data.business_line%TYPE := NULL;
   v_task                 ajc_ap_ies_inbound_data.task%TYPE := NULL;
   v_gl_account           ajc_ap_ies_inbound_data.gl_account%TYPE := NULL;
   v_location             ajc_ap_ies_inbound_data.location%TYPE := NULL;
   v_project              ajc_ap_ies_inbound_data.project%TYPE := NULL;
   v_invoice_number       ajc_ap_ies_inbound_data.invoice_number%TYPE := NULL;
   v_invoice_type         ajc_ap_ies_inbound_data.invoice_type%TYPE := NULL;
   v_financial_party      ajc_ap_ies_inbound_data.financial_party%TYPE := NULL;
   v_me_number            ajc_ap_ies_inbound_data.me_number%TYPE := NULL;
   v_transaction_type     ajc_ap_ies_inbound_data.transaction_type%TYPE := NULL;
   v_accounting_date      ajc_ap_ies_inbound_data.accounting_date%TYPE := NULL;
   v_due_date             ajc_ap_ies_inbound_data.due_date%TYPE := NULL;
   v_charge_amount        ajc_ap_ies_inbound_data.charge_amount%TYPE := NULL;
   v_currency_code        ajc_ap_ies_inbound_data.currency_code%TYPE := NULL;
   v_terms                ajc_ap_ies_inbound_data.terms%TYPE := NULL;
   v_reference_type_1     ajc_ap_ies_inbound_data.reference_type_1%TYPE := NULL;
   v_reference_value_1    ajc_ap_ies_inbound_data.reference_value_1%TYPE := NULL;
   v_destination_country  ajc_ap_ies_inbound_data.destination_country%TYPE := NULL;
   v_origin_country       ajc_ap_ies_inbound_data.origin_country%TYPE := NULL;
   v_description          ajc_ap_ies_inbound_data.description%TYPE := NULL;
   v_orig_ap_internal     ajc_ap_ies_inbound_data.orig_ap_internal%TYPE := NULL;

  BEGIN

    print_log('ajcl_bc_ies_gl_pkg.populate_table_p (+)');

    v_run_date := SYSDATE;

    FOR sel_lines_rec IN sel_lines LOOP

      v_line_num := sel_lines_rec.line_num;
      v_line := sel_lines_rec.line;

      IF ( sel_lines_rec.line = '<ACCOUNTING_EVENT>' ) THEN

        v_remove_char := 0;
        v_carrier := NULL;
        v_type_of_move := NULL;
        v_master_blawb_number := NULL;
        v_house_blawb_number := NULL;
        v_financial_party_external_id := NULL;
        v_charge_type_code := NULL;
        v_charge_type := NULL;
        v_company_number := NULL;
        v_shipment_reference := NULL;
        v_division := NULL;
        v_business_line := NULL;
        v_task := NULL;
        v_gl_account := NULL;
        v_location := NULL;
        v_project := NULL;
        v_invoice_number := NULL;
        v_invoice_type := NULL;
        v_financial_party := NULL;
        v_me_number := NULL;
        v_transaction_type := NULL;
        v_accounting_date := NULL;
        v_due_date := NULL;
        v_charge_amount := NULL;
        v_currency_code := NULL;
        v_terms := NULL;
        v_reference_type_1 := NULL;
        v_reference_value_1 := NULL;
        v_destination_country := NULL;
        v_origin_country := NULL;
        v_description := NULL;

      END IF;

      IF ( ( sel_lines_rec.line LIKE '%<ACCOUNTING_EVENT>%' ) AND ( sel_lines_rec.line != '<ACCOUNTING_EVENT>' ) ) THEN

        v_remove_char := 1;
        v_carrier := NULL;
        v_type_of_move := NULL;
        v_master_blawb_number := NULL;
        v_house_blawb_number := NULL;
        v_financial_party_external_id := NULL;
        v_charge_type_code := NULL;
        v_charge_type := NULL;
        v_company_number := NULL;
        v_shipment_reference := NULL;
        v_division := NULL;
        v_business_line := NULL;
        v_task := NULL;
        v_gl_account := NULL;
        v_location := NULL;
        v_project := NULL;
        v_invoice_number := NULL;
        v_invoice_type := NULL;
        v_financial_party := NULL;
        v_me_number := NULL;
        v_transaction_type := NULL;
        v_accounting_date := NULL;
        v_due_date := NULL;
        v_charge_amount := NULL;
        v_currency_code := NULL;
        v_terms := NULL;
        v_reference_type_1 := NULL;
        v_reference_value_1 := NULL;
        v_destination_country := NULL;
        v_origin_country := NULL;
        v_description := NULL;

      END IF;

      IF ( sel_lines_rec.line like '<CHARGE_TYPE>%' ) THEN

        v_charge_type := replace(replace(sel_lines_rec.line,'</CHARGE_TYPE>'),'<CHARGE_TYPE>');
        v_charge_type := substr(v_charge_type, 1,length(v_charge_type) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<CARRIER>%' ) THEN

        v_carrier := replace(replace(sel_lines_rec.line,'</CARRIER>'),'<CARRIER>');
        v_carrier := substr(v_carrier, 1,length(v_carrier) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<TYPE_OF_MOVE>%' ) THEN

        v_type_of_move := replace(replace(sel_lines_rec.line,'</TYPE_OF_MOVE>'),'<TYPE_OF_MOVE>');
        v_type_of_move := substr(v_type_of_move, 1,length(v_type_of_move) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<MASTER_BLAWB_NUMBER>%' ) THEN

        v_master_blawb_number := replace(replace(sel_lines_rec.line,'</MASTER_BLAWB_NUMBER>'),'<MASTER_BLAWB_NUMBER>');
        v_master_blawb_number := substr(v_master_blawb_number, 1,length(v_master_blawb_number) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<HOUSE_BLAWB_NUMBER>%' ) THEN

        v_house_blawb_number := replace(replace(sel_lines_rec.line,'</HOUSE_BLAWB_NUMBER>'),'<HOUSE_BLAWB_NUMBER>');
        v_house_blawb_number := substr(v_house_blawb_number, 1,length(v_house_blawb_number) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<FINANCIAL_PARTY_EXTERNAL_ID>%' ) THEN

        v_financial_party_external_id := replace(replace(sel_lines_rec.line,'</FINANCIAL_PARTY_EXTERNAL_ID>'),'<FINANCIAL_PARTY_EXTERNAL_ID>');
        v_financial_party_external_id := substr(v_financial_party_external_id, 1,length(v_financial_party_external_id) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<CHARGE_TYPE_CODE>%' ) THEN

        v_charge_type_code := replace(replace(sel_lines_rec.line,'</CHARGE_TYPE_CODE>'),'<CHARGE_TYPE_CODE>');
        v_charge_type_code := substr(v_charge_type_code, 1,length(v_charge_type_code) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<COMPANY_NUMBER>%' ) THEN

        v_company_number := replace(replace(sel_lines_rec.line,'</COMPANY_NUMBER>'),'<COMPANY_NUMBER>');
        v_company_number := substr(v_company_number, 1,length(v_company_number) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<SHIPMENT REFERENCE>%' ) THEN

        v_shipment_reference := replace(replace(sel_lines_rec.line,'</SHIPMENT REFERENCE>'),'<SHIPMENT REFERENCE>');
        v_shipment_reference := substr(v_shipment_reference, 1,length(v_shipment_reference) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<SHIPMENT_REFERENCE>%' ) THEN

        v_shipment_reference := replace(replace(sel_lines_rec.line,'</SHIPMENT_REFERENCE>'),'<SHIPMENT_REFERENCE>');
        v_shipment_reference := substr(v_shipment_reference, 1,length(v_shipment_reference) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<DIVISION>%' ) THEN

        v_division := replace(replace(sel_lines_rec.line,'</DIVISION>'),'<DIVISION>');
        v_division := substr(v_division, 1,length(v_division) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<BUSINESS_LINE>%' ) THEN

        v_business_line := replace(replace(sel_lines_rec.line,'</BUSINESS_LINE>'),'<BUSINESS_LINE>');
        v_business_line := substr(v_business_line, 1,length(v_business_line) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<TASK>%' ) THEN

        v_task := replace(replace(sel_lines_rec.line,'</TASK>'),'<TASK>');
        v_task := substr(v_task, 1,length(v_task) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<GL_ACCOUNT>%' ) THEN

        v_gl_account := replace(replace(sel_lines_rec.line,'</GL_ACCOUNT>'),'<GL_ACCOUNT>');
        v_gl_account := substr(v_gl_account, 1,length(v_gl_account) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<LOCATION>%' ) THEN

        v_location := replace(replace(sel_lines_rec.line,'</LOCATION>'),'<LOCATION>');
        v_location := substr(v_location, 1,length(v_location) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<PROJECT>%' ) THEN

        v_project := replace(replace(sel_lines_rec.line,'</PROJECT>'),'<PROJECT>');
        v_project := substr(v_project, 1,length(v_project) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<INVOICE_NUMBER>%' ) THEN

        v_invoice_number := replace(replace(sel_lines_rec.line,'</INVOICE_NUMBER>'),'<INVOICE_NUMBER>');
        v_invoice_number := substr(v_invoice_number, 1,length(v_invoice_number) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<INVOICE_TYPE>%' ) THEN

        v_invoice_type := replace(replace(sel_lines_rec.line,'</INVOICE_TYPE>'),'<INVOICE_TYPE>');
        v_invoice_type := substr(v_invoice_type, 1,length(v_invoice_type) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<FINANCIAL_PARTY>%' ) THEN

        v_financial_party := replace(replace(sel_lines_rec.line,'</FINANCIAL_PARTY>'),'<FINANCIAL_PARTY>');
        v_financial_party := substr(v_financial_party, 1,length(v_financial_party) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<ME_NUMBER>%' ) THEN

        v_me_number := replace(replace(sel_lines_rec.line,'</ME_NUMBER>'),'<ME_NUMBER>');
        v_me_number := substr(v_me_number, 1,length(v_me_number) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<TRANSACTION_TYPE>%' ) THEN

        v_transaction_type := replace(replace(sel_lines_rec.line,'</TRANSACTION_TYPE>'),'<TRANSACTION_TYPE>');
        v_transaction_type := substr(v_transaction_type, 1,length(v_transaction_type) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<ACCOUNTING_DATE>%' ) THEN

        v_accounting_date := replace(replace(sel_lines_rec.line,'</ACCOUNTING_DATE>'),'<ACCOUNTING_DATE>');
        v_accounting_date := substr(v_accounting_date, 1,length(v_accounting_date) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<DUE_DATE>%' ) THEN

        v_due_date := replace(replace(sel_lines_rec.line,'</DUE_DATE>'),'<DUE_DATE>');
        v_due_date := substr(v_due_date, 1,length(v_due_date) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<CHARGE_AMOUNT>%' ) THEN

        v_charge_amount := replace(replace(sel_lines_rec.line,'</CHARGE_AMOUNT>'),'<CHARGE_AMOUNT>');
        v_charge_amount := substr(v_charge_amount, 1,length(v_charge_amount) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<CURRENCY_CODE>%' ) THEN

        v_currency_code := replace(replace(sel_lines_rec.line,'</CURRENCY_CODE>'),'<CURRENCY_CODE>');
        v_currency_code := substr(v_currency_code, 1,length(v_currency_code) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<TERMS>%' ) THEN

        v_terms := replace(replace(sel_lines_rec.line,'</TERMS>'),'<TERMS>');
        v_terms := substr(v_terms, 1,length(v_terms) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<REFERENCE_TYPE_1>%' ) THEN

        v_reference_type_1 := replace(replace(sel_lines_rec.line,'</REFERENCE_TYPE_1>'),'<REFERENCE_TYPE_1>');
        v_reference_type_1 := substr(v_reference_type_1, 1,length(v_reference_type_1) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<REFERENCE_VALUE_1>%' ) THEN

        v_reference_value_1 := replace(replace(sel_lines_rec.line,'</REFERENCE_VALUE_1>'),'<REFERENCE_VALUE_1>');
        v_reference_value_1 := substr(v_reference_value_1, 1,length(v_reference_value_1) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<ORIGIN_COUNTRY>%' ) THEN

        v_origin_country := replace(replace(sel_lines_rec.line,'</ORIGIN_COUNTRY>'),'<ORIGIN_COUNTRY>');
        v_origin_country := substr(v_origin_country, 1,length(v_origin_country) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<DESTINATION_COUNTRY>%' ) THEN

        v_destination_country := replace(replace(sel_lines_rec.line,'</DESTINATION_COUNTRY>'),'<DESTINATION_COUNTRY>');
        v_destination_country := substr(v_destination_country, 1,length(v_destination_country) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line like '<ORIG_AP_INTERNAL>%' ) THEN

        v_orig_ap_internal := replace(replace(sel_lines_rec.line,'</ORIG_AP_INTERNAL>'),'<ORIG_AP_INTERNAL>');
        v_orig_ap_internal := substr(v_orig_ap_internal, 1,length(v_orig_ap_internal) - v_remove_char);

      END IF;

      IF ( sel_lines_rec.line LIKE '%</ACCOUNTING_EVENT>%' ) THEN

        v_sql_stmt_id := 10;

        INSERT 
          INTO ajc_ap_ies_inbound_data
             ( charge_type,
               charge_type_code,
               company_number,
               shipment_reference,
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
               description,
               carrier,
               type_of_move,
               master_blawb_number,
               house_blawb_number,
               financial_party_external_id,
               orig_ap_internal )
      VALUES ( v_charge_type,
               v_charge_type_code,
               v_company_number,
               v_shipment_reference,
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
               v_description,
               v_carrier,
               v_type_of_move,
               v_master_blawb_number,
               v_house_blawb_number,
               v_financial_party_external_id,
               v_orig_ap_internal );

        v_rec_count := v_rec_count + 1;

      END IF;

    END LOOP;

    v_sql_stmt_id := 20;

    UPDATE ajc_ap_ies_inbound_data 
       SET interface_status = 'UN-PROCESSED',
	          financial_party = decode(substr(trim(financial_party),1,1),'*', substr(financial_party,2,length(financial_party) -1),financial_party),
	          created_by = v_user_id,
           creation_date = v_run_date,
           last_updated_by = v_user_id,
           last_update_date = v_run_date,
           inbound_file_name = 'AJC_IES_AP_FILE ' || to_char(v_run_date,'DD-MON-YYYY HH24:MI:SS')
     WHERE interface_status IS NULL;

    print_log(TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS') || ' Total IES AP records inserted: ' || v_rec_count);

    print_log('ajcl_bc_ies_gl_pkg.populate_table_p (-)');

  EXCEPTION
    WHEN OTHERS THEN
      p_status := 'E';
      print_log('ajcl_bc_ies_gl_pkg.populate_table_p (!). Processing Line: ' || v_line_num || '/' || v_line || '. Error: ' || SQLERRM || '. sql statement: ' || v_sql_stmt_id);

  END populate_table_p;

  PROCEDURE control_report_p ( p_status   OUT   VARCHAR2 ) IS

      CURSOR c_total_count IS
      SELECT COUNT(1) line_count,
             TO_CHAR(SUM(charge_amount),'999,999,999.99') inv_amt,
             TO_CHAR(sysdate,'DD-MON-YYYY HH24:MI:SS') report_date
        FROM ajc_ap_ies_inbound_data
       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'
         AND TRIM(gl_account) LIKE '5%'
    GROUP BY TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS');

    CURSOR c_lines_to_be_processed IS
    SELECT COUNT(1) line_count, 
           TO_CHAR(SUM(charge_amount),'999,999,999.99') charge_total
      FROM ajc_ap_ies_inbound_data
     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'
       AND TRIM(gl_account) LIKE '5%';

    CURSOR c_total_lines IS
    SELECT COUNT(1) line_count, 
           TO_CHAR(SUM(charge_amount),'999,999,999.99') charge_total
      FROM ajc_ap_ies_inbound_data
     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED';

    v_header   VARCHAR2(2000);

    -- Agrupado, reemplaza a los anteriores, se usa para generar el output en XLSX
    CURSOR c_lines IS
    SELECT SUM(line_count_tp) line_count_tp,
           TRIM(TO_CHAR(SUM(charge_total_tp),'999,999,999.99')) charge_total_tp,
           SUM(line_count) line_count,
           TRIM(TO_CHAR(SUM(charge_total),'999,999,999.99')) charge_total
      FROM ( SELECT 
                    CASE
                      WHEN TRIM(gl_account) LIKE '5%' THEN
                        1
                      ELSE
                        0
                    END line_count_tp
                   ,CASE
                      WHEN TRIM(gl_account) LIKE '5%' THEN
                        charge_amount
                      ELSE
                        '0'
                    END charge_total_tp
                   ,1 line_count
                   ,charge_amount charge_total
               FROM ajc_ap_ies_inbound_data
              WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED' );

  BEGIN

    print_log('ajcl_bc_ies_gl_pkg.control_report_p (+)');

    IF ( gv_file_format = 'CSV' ) THEN

      print_output ( 'Date|' || SYSDATE );
      print_output ( 'AJC AP IES Inbound Data Control Report' );
      print_output ( ' ' );

      v_header := 'Line Count' || '|' || 'Line Amount';

      print_output ( v_header ); 

      FOR ctc IN c_total_count LOOP

        print_output ( TRIM(ctc.line_count) || '|' ||
                       TRIM(ctc.inv_amt) );               

      END LOOP;

      print_output ( ' ' );

      FOR cltbp IN c_lines_to_be_processed LOOP

        print_output ( 'Lines to be Processed' || '|' || TRIM(cltbp.line_count) );
        print_output ( 'Amount' || '|' || TRIM(cltbp.charge_total) );

      END LOOP;

      print_output ( ' ' );

      FOR ctl IN c_total_lines LOOP

        print_output ( 'Total Lines' || '|' || TRIM(ctl.line_count) );
        print_output ( 'Amount' || '|' || TRIM(ctl.charge_total) );

      END LOOP;

    ELSIF ( gv_file_format = 'XLSX' ) THEN

      -- Column Names
      print_output_xlsx ( p_section => 'Inbound Data Control Report',
                          p_column1 => 'Line Count To Process',
                          p_column2 => 'Amount to Process',
                          p_column3 => 'Total Line Count',
                          p_column4 => 'Total Amount' );    

      FOR cl IN c_lines LOOP

        print_output_xlsx ( p_section => 'Inbound Data Control Report',
                            p_column1 => cl.line_count_tp,
                            p_column2 => cl.charge_total_tp,
                            p_column3 => cl.line_count,
                            p_column4 => cl.charge_total );

      END LOOP;                        

    END IF;

    p_status := 'S';

    print_log('ajcl_bc_ies_gl_pkg.control_report_p (-)');

  EXCEPTION
    WHEN OTHERS THEN
      p_status := 'E';
      print_log('ajcl_bc_ies_gl_pkg.control_report_p (!). Error: ' || SQLERRM);

  END control_report_p;

  PROCEDURE data_list_p ( p_status   OUT   VARCHAR2 ) IS

    CURSOR c_listing IS 
    SELECT inbound_file_name,
           NULL financial_party,
           shipment_reference,
           NULL accounting_date,
           NULL charge_type_code,
           NULL business_line,
           NULL invoice_number,
           NULL gl_account,
           NULL origin_country,
           NULL destination_country,
           NULL charge_amount,
           1 flag,
           TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS') report_date
      FROM ( SELECT DISTINCT inbound_file_name,
                    shipment_reference
               FROM ajc_ap_ies_inbound_data
              WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'
                AND TRIM(gl_account) LIKE '5%' )
     UNION ALL
    SELECT inbound_file_name,
           financial_party,
           shipment_reference,
           TO_DATE(accounting_date,'YYYY-MM-DD') accounting_date,
           charge_type_code,
           business_line,
           invoice_number,
           gl_account,
           origin_country,
           destination_country,
           TO_CHAR(charge_amount,'999,999,999.99') charge_amount,
           2 flag,
           TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS') report_date
      FROM ( SELECT inbound_file_name,
                    financial_party,
                    shipment_reference,
                    accounting_date,
                    invoice_number,
                    gl_account,
                    origin_country,
                    destination_country,
                    charge_type_code,
                    business_line,
                    charge_amount
               FROM ajc_ap_ies_inbound_data
              WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'
                AND TRIM(gl_account) LIKE '5%' )
      ORDER BY 1,3,12,4,5,6;

      v_header   VARCHAR2(2000);

    -- Se usa para generar el output en XLSX
    CURSOR c_list IS 
    SELECT inbound_file_name,
           financial_party,
           shipment_reference,
           TO_DATE(accounting_date,'YYYY-MM-DD') accounting_date,
           charge_type_code,
           business_line,
           invoice_number,
           gl_account,
           origin_country,
           destination_country,
           TO_CHAR(charge_amount,'999,999,999.99') charge_amount
      FROM ajc_ap_ies_inbound_data
     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'
       AND TRIM(gl_account) LIKE '5%'
  ORDER BY 1,3,4,5,6;

  BEGIN

    print_log('ajcl_bc_ies_gl_pkg.data_list_p (+)');

    IF ( gv_file_format = 'CSV' ) THEN

      print_output ( ' ' );
      print_output ( 'Date|' || SYSDATE );
      print_output ( 'AJC AP IES Inbound Detailed Data Listing' );
      print_output ( ' ' );

      v_header := 'Inbound File Name' || '|' ||
                  'IES File Number' || '|' ||
                  'Accounting Date' || '|' ||
                  'Charge Type' || '|' ||
                  'Business Line' || '|' ||
                  'Financial Party' || '|' ||
                  'Invoice Num' || '|' ||
                  'GL Acct.' || '|' ||
                  'Orign' || '|' ||
                  'Destn' || '|' ||
                  'Charge Amount';

      print_output ( v_header );

      FOR cl IN c_listing LOOP

        print_output ( cl.inbound_file_name || '|' ||
                       cl.shipment_reference || '|' ||
                       cl.accounting_date || '|' ||
                       cl.charge_type_code || '|' ||
                       cl.business_line || '|' ||
                       cl.financial_party || '|' ||
                       cl.invoice_number || '|' ||
                       cl.gl_account || '|' ||
                       cl.origin_country || '|' ||
                       cl.destination_country || '|' ||
                       TRIM(cl.charge_amount) );

      END LOOP;  

    ELSIF ( gv_file_format = 'XLSX' ) THEN 

      -- Column Names
      print_output_xlsx ( p_section => 'Inbound Detailed Data Listing',
                          p_column1 => 'Inbound File Name',
                          p_column2 => 'IES File Number',
                          p_column3 => 'Accounting Date',
                          p_column4 => 'Charge Type',
                          p_column5 => 'Business Line',
                          p_column6 => 'Financial Party',
                          p_column7 => 'Invoice Number',
                          p_column8 => 'GL Account',
                          p_column9 => 'Origin',
                          p_column10 => 'Destination',
                          p_column11 => 'Charge Amount' );

      -- NEW
      FOR cl IN c_list LOOP 

        print_output_xlsx ( p_section => 'Inbound Detailed Data Listing',
                            p_column1 => cl.inbound_file_name,
                            p_column2 => cl.shipment_reference,
                            p_column3 => cl.accounting_date,
                            p_column4 => cl.charge_type_code,
                            p_column5 => cl.business_line,
                            p_column6 => cl.financial_party,
                            p_column7 => cl.invoice_number,
                            p_column8 => cl.gl_account,
                            p_column9 => cl.origin_country,
                            p_column10 => cl.destination_country,
                            p_column11 => TRIM(cl.charge_amount) );

      END LOOP;        

    END IF;

    p_status := 'S';

    print_log('ajcl_bc_ies_gl_pkg.data_list_p (-)');

  EXCEPTION
    WHEN OTHERS THEN
      p_status := 'E';
      print_log('ajcl_bc_ies_gl_pkg.data_list_p (!). Error: ' || SQLERRM);

  END data_list_p;         

  PROCEDURE validate_preprocess_p ( p_status   OUT   VARCHAR2 ) IS

    CURSOR c_missing_item_def IS
    SELECT DISTINCT TRIM(charge_type_code) || '.' || TRIM(business_line) item,
           'Item not found.' error_message,
           TO_CHAR(sysdate,'DD-MON-YYYY HH24:MI:SS') report_date,
           1 print_order
      FROM ajc_ap_ies_inbound_data a
     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'
       AND TRIM(gl_account) LIKE '5%'
       AND NOT EXISTS ( SELECT 'x'
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
     UNION
    SELECT distinct trim(charge_type_code) || '.' || TRIM(business_line) item,
           'Item is inactive.' error_message,
           to_char(sysda
