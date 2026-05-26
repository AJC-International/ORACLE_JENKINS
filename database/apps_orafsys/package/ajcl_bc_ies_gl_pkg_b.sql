CREATE OR REPLACE PACKAGE BODY ajcl_bc_ies_gl_pkg IS

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

           to_char(sysdate,'DD-MON-YYYY HH24:MI:SS') report_date,

           2 print_order

      FROM ajc_ap_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND TRIM(gl_account) LIKE '5%'

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

                       AND NVL(b.inactive_date,SYSDATE + 1) <= SYSDATE )

     UNION

    SELECT DISTINCT TRIM(charge_type_code) || '.' || TRIM(business_line) item,

           'Cost of sales account not populated for item.' error_message,

           to_char(sysdate,'DD-MON-YYYY HH24:MI:SS') report_date,

           3 print_order

      FROM ajc_ap_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND TRIM(gl_account) LIKE '5%'

       AND EXISTS ( SELECT 'x'

                      FROM ajcl_bc_ies_items b

                     WHERE bc_environment = gv_bc_environment

                       AND TRIM(b.charge_type_code) = ( SELECT NVL(substitute, TRIM(a.charge_type_code))

                                                          FROM ajcl_bc_ies_charge_types

                                                         WHERE bc_environment = gv_bc_environment

                                                           AND charge_type_code = TRIM(a.charge_type_code)

                                                         UNION

                                                        SELECT trim(a.charge_type_code)

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

                       AND b.cgs_accountno IS NULL )

     UNION

    SELECT DISTINCT TRIM(charge_type_code) || '.' || TRIM(business_line) item,

           'Offset to cost of sales account not populated for item.' error_message,

           to_char(sysdate,'DD-MON-YYYY HH24:MI:SS') report_date,

           4 print_order

      FROM ajc_ap_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND TRIM(gl_account) LIKE '5%'

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

                       AND b.offset_accountno IS NULL )

  ORDER BY 4, 1;



      CURSOR c_orgn_dest_exception IS

      SELECT DISTINCT origin_country country_code,

             'Country not found.' error_message,

             to_char(sysdate,'DD-MON-YYYY HH24:MI:SS') report_date,

             1 print_order

        FROM ajc_ap_ies_inbound_data a

       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

         AND TRIM(gl_account) LIKE '5%'

         AND a.origin_country IS NOT NULL

         AND NOT EXISTS ( SELECT 'x'

                          FROM ajcl_bc_ies_country_codes x

                         WHERE bc_environment = gv_bc_environment

                           AND x.country_code = TRIM(a.origin_country) )

       UNION

      SELECT DISTINCT destination_country country_code,

             'Country not found.' error_message,

             to_char(sysdate,'DD-MON-YYYY HH24:MI:SS') report_date,

             2 print_order

        FROM ajc_ap_ies_inbound_data a

       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

         AND TRIM(gl_account) LIKE '5%'

         AND a.destination_country IS NOT NULL

         AND NOT EXISTS ( SELECT 'x'

                          FROM ajcl_bc_ies_country_codes x

                         WHERE bc_environment = gv_bc_environment

                           AND x.country_code = TRIM(a.destination_country) )

       UNION

     SELECT DISTINCT origin_country country_code,

            'Origin and/or destination not populated for this country.' error_message,

            to_char(sysdate,'DD-MON-YYYY HH24:MI:SS') report_date,

            3 print_order

       FROM ajc_ap_ies_inbound_data a

      WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

        AND TRIM(gl_account) LIKE '5%'

        AND a.origin_country IS NOT NULL

        AND EXISTS ( SELECT 'x'

                       FROM ajcl_bc_ies_country_codes x

                      WHERE bc_environment = gv_bc_environment

                        AND x.country_code = TRIM(a.origin_country)

                        AND ( x.origin IS NULL OR x.destination IS NULL ) )

      UNION

     SELECT distinct destination_country country_code,

            'Origin and/or destination not populated for this country.' error_message,

            to_char(sysdate,'DD-MON-YYYY HH24:MI:SS') report_date,

            4 print_order

       FROM ajc_ap_ies_inbound_data a

      WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

        AND TRIM(gl_account) LIKE '5%'

        AND a.destination_country IS NOT NULL

        AND EXISTS ( SELECT 'x'

                       FROM ajcl_bc_ies_country_codes x

                      WHERE bc_environment = gv_bc_environment

                        AND x.country_code = TRIM(a.destination_country)

                        AND ( x.origin IS NULL OR x.destination IS NULL ) )

    ORDER BY 4, 1;



    CURSOR c_reference_mismatch_excep IS

    SELECT DISTINCT SUBSTR(orig_ap_internal,1,59) orig_ap_internal,

           SUBSTR(shipment_reference,1,59) shipment_reference,

           'Orig AP internal and shipment reference do not match.' error_message,

           to_char(sysdate,'DD-MON-YYYY HH24:MI:SS') report_date

      FROM ajc_ap_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND TRIM(gl_account) LIKE '5%'

       AND ( ( NVL(SUBSTR(TRIM(orig_ap_internal),1,LENGTH(TRIM(shipment_reference))),'X') != NVL(TRIM(shipment_reference),'X') )

               OR ( NVL(substr(TRIM(orig_ap_internal),1,LENGTH(TRIM(shipment_reference))),'X') = NVL(TRIM(shipment_reference),'X')

                    AND SUBSTR(TRIM(orig_ap_internal), LENGTH(TRIM(shipment_reference)) + 1, 1) NOT IN ('/','-','R') ) );



      CURSOR c_orgn_dest_missing IS

      SELECT substr(financial_party,1,50) fin_party,

             substr(invoice_number,1,20) invoice_number,

             substr(charge_type_code,1,20) charge_type_code,

             substr(business_line,1,5) business_line,

             to_number(charge_amount) charge_amount,

             'Line missing origin and/or destination.' warn_message,

             to_char(sysdate,'DD-MON-YYYY HH24:MI:SS') report_date

        FROM ajc_ap_ies_inbound_data a

       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

         AND TRIM(gl_account) LIKE '5%'

         AND ( a.origin_country IS NULL OR a.destination_country IS NULL )

    ORDER BY 1,2,3,4;



    v_count   NUMBER;



  BEGIN



    print_log('ajcl_bc_ies_gl_pkg.validate_preprocess_p (+)');



    v_count := 0;



    -- Se verifica si hay registros a informar

    FOR cmid IN c_missing_item_def LOOP



      v_count := v_count + 1;



    END LOOP;



    IF ( v_count != 0 ) THEN



      IF ( gv_file_format = 'CSV' ) THEN



        print_output ( ' ' );

        print_output ( 'Date|' || SYSDATE );

        print_output ( 'AJC AP IES Txn Processing Errors' );



        print_output ( ' ' );

        print_output ( 'AJC AP IES Missing Item Definitions' );



        print_output ( ' ' );

        print_output ( 'Item' || '|' ||

                       'Error Message' );



        FOR cmid IN c_missing_item_def LOOP



          print_output ( cmid.item || '|' ||

                         cmid.error_message );



        END LOOP;



      ELSIF ( gv_file_format = 'XLSX' ) THEN 



        -- Column Names

        print_output_xlsx ( p_section => 'Missing Item Definitions',

                            p_column1 => 'Item',

                            p_column2 => 'Error Message' );



        FOR cmid IN c_missing_item_def LOOP



          print_output_xlsx ( p_section => 'Missing Item Definitions',

                              p_column1 => cmid.item,

                              p_column2 => cmid.error_message );



        END LOOP;



      END IF;



    END IF;



    v_count := 0;



    -- Se verifica si hay registros a informar

    FOR code IN c_orgn_dest_exception LOOP



      v_count := v_count + 1;



    END LOOP;



    IF ( v_count != 0 ) THEN



      IF ( gv_file_format = 'CSV' ) THEN



        print_output ( ' ' );

        print_output ( 'AJC AP IES Origin/Destination Exceptions' );



        print_output ( ' ' );

        print_output ( 'Country Code' || '|' ||

                       'Error Message' );



        FOR code IN c_orgn_dest_exception LOOP



          print_output ( code.country_code || '|' ||

                         code.error_message );



        END LOOP;



      ELSIF ( gv_file_format = 'XLSX' ) THEN 



        -- Column Names

        print_output_xlsx ( p_section => 'Origin/Destination Exceptions',

                            p_column1 => 'Country Code',

                            p_column2 => 'Error Message' );



        -- NEW

        FOR code IN c_orgn_dest_exception LOOP



          print_output_xlsx ( p_section => 'Origin/Destination Exceptions',

                              p_column1 => code.country_code,

                              p_column2 => code.error_message );



        END LOOP;



      END IF;



    END IF;



    v_count := 0;



    -- Se verifica si hay registros a informar

    FOR crme IN c_reference_mismatch_excep LOOP



      v_count := v_count + 1;



    END LOOP;



    IF ( v_count != 0 ) THEN



      IF ( gv_file_format = 'CSV' ) THEN



        print_output ( ' ' );

        print_output ( 'AJC AP IES Orig AP Internal/Shipment Reference Mismatch Exceptions' );



        print_output ( ' ' );

        print_output ( 'Orig AP Internal' || '|' ||

                       'Shipment Reference' || '|' ||

                       'Error Message' );



        FOR crme IN c_reference_mismatch_excep LOOP



          print_output ( crme.orig_ap_internal || '|' ||

                         crme.shipment_reference || '|' ||

                         crme.error_message );



        END LOOP;



      ELSIF ( gv_file_format = 'XLSX' ) THEN 



        -- Column Names

        print_output_xlsx ( p_section => 'Orig AP Internal/Shipment Reference Mismatch Exceptions',

                            p_column1 => 'Orig AP Internal',

                            p_column2 => 'Shipment Reference',

                            p_column3 => 'Error Message' );



        FOR crme IN c_reference_mismatch_excep LOOP



          print_output_xlsx ( p_section => 'Orig AP Internal/Shipment Reference Mismatch Exceptions',

                              p_column1 => crme.orig_ap_internal,

                              p_column2 => crme.shipment_reference,

                              p_column3 => crme.error_message );



        END LOOP;



      END IF;



    END IF;



    v_count := 0;



    -- Se verifica si hay registros a informar

    FOR codm IN c_orgn_dest_missing LOOP



      v_count := v_count + 1;



    END LOOP;



    IF ( v_count != 0 ) THEN



      IF ( gv_file_format = 'CSV' ) THEN



        print_output ( ' ' );

        print_output ( 'AJC AP IES Invoice Lines Missing Origin/Destination Country Warning' );



        print_output ( ' ' );

        print_output ( 'Financial Party' || '|' ||

                       'Invoice Number' || '|' ||

                       'Charge Type Code' || '|' ||

                       'Business Line' || '|' ||

                       'Charge Amount' || '|' ||

                       'Warning Message' );



        FOR codm IN c_orgn_dest_missing LOOP



          print_output ( codm.fin_party || '|' ||

                         codm.invoice_number || '|' ||

                         codm.charge_type_code || '|' ||

                         codm.business_line || '|' ||

                         codm.charge_amount || '|' ||

                         codm.warn_message );



        END LOOP;



      ELSIF ( gv_file_format = 'XLSX' ) THEN 



        -- Column Names

        print_output_xlsx ( p_section => 'Invoice Lines Missing Origin/Destination Country Warning',

                            p_column1 => 'Financial Party',

                            p_column2 => 'Invoice Number',

                            p_column3 => 'Charge Type Code',

                            p_column4 => 'Business Line',

                            p_column5 => 'Charge Amount',

                            p_column6 => 'Warning Message' );



        FOR codm IN c_orgn_dest_missing LOOP



          print_output_xlsx ( p_section => 'Invoice Lines Missing Origin/Destination Country Warning',

                              p_column1 => codm.fin_party,

                              p_column2 => codm.invoice_number,

                              p_column3 => codm.charge_type_code,

                              p_column4 => codm.business_line,

                              p_column5 => codm.charge_amount,

                              p_column6 => codm.warn_message );



        END LOOP;



      END IF;



    END IF;



    p_status := 'S';



    print_log('ajcl_bc_ies_gl_pkg.validate_preprocess_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_ies_gl_pkg.validate_preprocess_p (!). Error: ' || SQLERRM);



  END validate_preprocess_p;



  PROCEDURE stop_processing_p ( p_status   OUT   VARCHAR2 ) IS



    v_item_excp1            INTEGER := 0;

    v_item_excp2            INTEGER := 0;

    v_item_excp3            INTEGER := 0;

    v_item_excp4            INTEGER := 0;

    v_orig_dest_excp1       INTEGER := 0;

    v_orig_dest_excp2       INTEGER := 0;

    v_orig_dest_excp3       INTEGER := 0;

    v_orig_dest_excp4       INTEGER := 0;

    v_orig_dest_excp_count  INTEGER := 0;

    v_item_excp_count       INTEGER := 0;

    v_ship_ref_excp_count   INTEGER := 0;

    v_sql_stmt_id           INTEGER := 0;

    stop_processing         EXCEPTION;



  BEGIN



    print_log('ajcl_bc_ies_gl_pkg.stop_processing_p (+)');



    v_sql_stmt_id := 10;



    SELECT COUNT(1)

      INTO v_item_excp1

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

                                                            SELECT trim(a.charge_type_code)

                                                              FROM dual

                                                             WHERE NOT EXISTS ( SELECT 'x'

                                                                                  FROM ajcl_bc_ies_charge_types

                                                                                 WHERE bc_environment = gv_bc_environment

                                                                                   AND charge_type_code = TRIM(a.charge_type_code) ) )

                           AND TRIM(b.business_line) = TRIM(a.business_line) );



    v_sql_stmt_id := 20;



    SELECT COUNT(1)

      INTO v_item_excp2

      FROM ajc_ap_ies_inbound_data a

     WHERE nvl(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND TRIM(gl_account) LIKE '5%'

       AND EXISTS ( SELECT 'x'

                      FROM ajcl_bc_ies_items b

                     WHERE bc_environment = gv_bc_environment

                       AND TRIM(b.charge_type_code) = ( SELECT NVL(substitute, TRIM(a.charge_type_code))

                                                          FROM ajcl_bc_ies_charge_types

                                                         WHERE bc_environment = gv_bc_environment

                                                           AND charge_type_code = TRIM(a.charge_type_code)

                                                         UNION

                                                        SELECT trim(a.charge_type_code)

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

                       AND b.cgs_accountno IS NULL );



    v_sql_stmt_id := 30;



    SELECT COUNT(1)

      INTO v_item_excp4

      FROM ajc_ap_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND TRIM(gl_account) LIKE '5%'

       AND EXISTS ( SELECT 'x'

                      FROM ajcl_bc_ies_items b

                     WHERE bc_environment = gv_bc_environment

                       AND TRIM(b.charge_type_code) = ( SELECT NVL(substitute, TRIM(a.charge_type_code))

                                                          FROM ajcl_bc_ies_charge_types

                                                         WHERE bc_environment = gv_bc_environment

                                                           AND charge_type_code = TRIM(a.charge_type_code)

                                                         UNION

                                                        SELECT trim(a.charge_type_code)

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

                       AND NVL(b.inactive_date, SYSDATE + 1) <= SYSDATE );



    v_sql_stmt_id := 40;



    SELECT COUNT(1)

      INTO v_item_excp3

      FROM ajc_ap_ies_inbound_data a

     WHERE nvl(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND TRIM(gl_account) LIKE '5%'

       AND EXISTS ( SELECT 'x'

                      FROM ajcl_bc_ies_items b

                     WHERE bc_environment = gv_bc_environment

                       AND TRIM(b.charge_type_code) = ( SELECT NVL(substitute, TRIM(a.charge_type_code))

                                                          FROM ajcl_bc_ies_charge_types

                                                         WHERE bc_environment = gv_bc_environment

                                                           AND charge_type_code = TRIM(a.charge_type_code)

                                                         UNION

                                                        SELECT trim(a.charge_type_code)

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

                       AND b.offset_accountno IS NULL );



    v_sql_stmt_id := 50;



    SELECT COUNT(1)

      INTO v_orig_dest_excp1

      FROM ajc_ap_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND TRIM(gl_account) LIKE '5%'

       AND a.origin_country is not null

       AND NOT EXISTS ( SELECT 'x'

                          FROM ajcl_bc_ies_country_codes x

                         WHERE bc_environment = gv_bc_environment

                           AND x.country_code = TRIM(a.origin_country) );



    v_sql_stmt_id := 60;



    SELECT COUNT(1)

      INTO v_orig_dest_excp2

      FROM ajc_ap_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND TRIM(gl_account) LIKE '5%'

       AND a.destination_country is not null

       AND NOT EXISTS ( SELECT 'x'

                          FROM ajcl_bc_ies_country_codes x

                         WHERE bc_environment = gv_bc_environment

                           AND x.country_code = TRIM(a.destination_country) );



    v_sql_stmt_id := 70;



    SELECT COUNT(1)

      INTO v_orig_dest_excp3

      FROM ajc_ap_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND TRIM(gl_account) LIKE '5%'

       AND a.origin_country IS NOT NULL

       AND EXISTS ( SELECT 'x'

                      FROM ajcl_bc_ies_country_codes x

                     WHERE bc_environment = gv_bc_environment

                       AND x.country_code = TRIM(a.origin_country)

                       AND ( x.origin IS NULL OR x.destination IS NULL ) );



    v_sql_stmt_id := 80;



    SELECT COUNT(1)

      INTO v_orig_dest_excp4

      FROM ajc_ap_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND TRIM(gl_account) LIKE '5%'

       AND a.destination_country IS NOT NULL

       AND EXISTS ( SELECT 'x'

                      FROM ajcl_bc_ies_country_codes x

                     WHERE bc_environment = gv_bc_environment

                       AND x.country_code = TRIM(a.destination_country)

                       AND ( x.origin IS NULL OR x.destination IS NULL ) );



    v_sql_stmt_id := 90;



    SELECT COUNT(1)

      INTO v_ship_ref_excp_count

      FROM ajc_ap_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND TRIM(gl_account) LIKE '5%'

       AND ( ( NVL(substr(TRIM(orig_ap_internal),1,LENGTH(TRIM(shipment_reference))),'X') != NVL(TRIM(shipment_reference),'X') )

             OR ( NVL(SUBSTR(TRIM(orig_ap_internal),1,LENGTH(TRIM(shipment_reference))),'X') = NVL(TRIM(shipment_reference),'X')

                  AND SUBSTR(TRIM(orig_ap_internal), LENGTH(TRIM(shipment_reference)) + 1, 1) NOT IN ('/','-','R')));



    print_log('v_ship_ref_excp_count: ' || v_ship_ref_excp_count);



    --

    print_log('v_item_excp1: ' || v_item_excp1);

    print_log('v_item_excp2: ' || v_item_excp2);

    print_log('v_item_excp3: ' || v_item_excp3);

    print_log('v_item_excp4: ' || v_item_excp4);



    v_item_excp_count := NVL(v_item_excp1,0) + NVL(v_item_excp2,0) + NVL(v_item_excp3,0) + NVL(v_item_excp4,0);

    print_log('v_item_excp_count: ' || v_item_excp_count);

    --



    --

    print_log('v_orig_dest_excp1: ' || v_orig_dest_excp1);

    print_log('v_orig_dest_excp2: ' || v_orig_dest_excp2);

    print_log('v_orig_dest_excp3: ' || v_orig_dest_excp3);

    print_log('v_orig_dest_excp4: ' || v_orig_dest_excp4);



    v_orig_dest_excp_count := NVL(v_orig_dest_excp1,0) + NVL(v_orig_dest_excp2,0) + NVL(v_orig_dest_excp3,0) + NVL(v_orig_dest_excp4,0);

    print_log('v_orig_dest_excp_count: ' || v_orig_dest_excp_count);

    --



    v_sql_stmt_id := 100;



    IF ( gv_if_errors_stop = 'Y' ) THEN



      -- 20240808 IF ( v_item_excp_count > 0 OR v_orig_dest_excp_count > 0 OR v_ship_ref_excp_count > 0 ) THEN

      IF ( v_item_excp_count > 0 OR v_orig_dest_excp_count > 0 ) THEN



        RAISE stop_processing;



      END IF;



    END IF;



    p_status := 'S';



    print_log('ajcl_bc_ies_gl_pkg.stop_processing_p (-)');



  EXCEPTION

    WHEN stop_processing THEN

      p_status := 'E';

      print_log ( 'ajcl_bc_ies_gl_pkg.stop_processing_p (!). Error: ' || SQLERRM );



    WHEN OTHERS THEN

      p_status := 'E';

      print_log ( 'ajcl_bc_ies_gl_pkg.stop_processing_p (!). Error: ' || SQLERRM );



  END stop_processing_p;



  PROCEDURE insert_p ( p_status   OUT   VARCHAR2 ) IS



    v_remaining_count                INTEGER := 0;



    v_cgs_accountno                  VARCHAR2(10);

    v_cgs_company                    VARCHAR2(10);

    v_cgs_department                 VARCHAR2(10);

    v_cgs_destination                VARCHAR2(10);

    v_cgs_office                     VARCHAR2(10);

    v_cgs_origin                     VARCHAR2(10);

    v_cgs_division                   VARCHAR2(10);



    v_offset_accountno               VARCHAR2(10);

    v_offset_company                 VARCHAR2(10);

    v_offset_department              VARCHAR2(10);

    v_offset_destination             VARCHAR2(10);

    v_offset_office                  VARCHAR2(10);

    v_offset_origin                  VARCHAR2(10);

    v_offset_division                VARCHAR2(10);



    v_je_line_desc                   VARCHAR2(240);

    v_invoice_number                 VARCHAR2(500);

    v_charge_type_code               VARCHAR2(25);

    v_line_num                       NUMBER := 0;



    v_jelineid                       NUMBER;



    -- GL

    CURSOR ies_ap_line_cur IS

    SELECT ies.rowid in_rowid, 

           ies.charge_type_code, 

           ies.company_number, 

           ies.division,

           ies.business_line, 

           ies.task, 

           ies.gl_account, 

           ies.location, 

           ies.project, 

           ies.invoice_number, 

           ies.invoice_type, 

           ies.financial_party, 

           ies.me_number, 

           ies.transaction_type, 

           ies.invoice_amount, 

           ies.orig_ap_internal, 

           ies.accounting_date, 

           ies.due_date, 

           ies.charge_amount, 

           ies.currency_code, 

           ies.terms, 

           ies.reference_type_1, 

           ies.destination_country, 

           ies.origin_country, 

           ies.shipment_reference,

           NVL(ies.description,TRIM(ies.charge_type)) description, 

           ies.reference_value_1, 

           ies.original_amount, 

           b.period_name

      FROM ajc_ap_ies_inbound_data ies, 

           gl_periods b,

           gl_sets_of_books sob

    WHERE nvl(ies.interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

      AND TRIM(ies.gl_account) LIKE '5%'

      -- AND TO_DATE(ies.accounting_date,'YYYY-MM-DD') BETWEEN NVL(p_from_accounting_date, TO_DATE('01-JAN-1900'))

      --                                                   AND NVL(p_to_accounting_date, TO_DATE('31-DEC-4712'))

      AND TO_DATE(ies.accounting_date,'YYYY-MM-DD') BETWEEN b.start_date AND b.end_date

      AND b.period_set_name = sob.period_set_name

      AND b.adjustment_period_flag = 'N' 

      AND b.period_type = 'PERIOD'

      AND sob.set_of_books_id = gv_set_of_books_id; 



  BEGIN



    print_log ( 'ajcl_bc_ies_gl_pkg.insert_p (+)' );



    -- Now process the records to create JE interface entries

    FOR ies_ap_line_row IN ies_ap_line_cur LOOP



      print_log ( '- Processing invoice number = ' || ies_ap_line_row.invoice_number || ', financial party = ' || ies_ap_line_row.financial_party || ', file# = ' || ies_ap_line_row.shipment_reference || ' *****');



      v_charge_type_code := null;



      SELECT NVL(substitute, TRIM(ies_ap_line_row.charge_type_code))

        INTO v_charge_type_code

        FROM ajcl_bc_ies_charge_types

       WHERE bc_environment = gv_bc_environment

         AND charge_type_code = TRIM(ies_ap_line_row.charge_type_code)

       UNION

      SELECT TRIM(ies_ap_line_row.charge_type_code)

        FROM dual

       WHERE NOT EXISTS ( SELECT 'x'

                            FROM ajcl_bc_ies_charge_types

                           WHERE bc_environment = gv_bc_environment

                             AND charge_type_code = TRIM(ies_ap_line_row.charge_type_code) ); 



      print_log ( 'Processing amount = ' ||

                   ies_ap_line_row.charge_amount || ', item = ' ||

                   v_charge_type_code || '.' ||

                   ies_ap_line_row.business_line);



      v_cgs_accountno := null;

      v_cgs_company := null;

      v_cgs_department := null;

      v_cgs_destination := null;

      v_cgs_office := null;

      v_cgs_origin := null;

      v_cgs_division := null;



      -- Get cost of goods sold accounting 

      BEGIN



        SELECT i.cgs_accountno,

               i.cgs_company,

               i.cgs_department,

               i.cgs_destination,

               i.cgs_office,

               i.cgs_origin,

               i.cgs_division

          INTO v_cgs_accountno,

               v_cgs_company,

               v_cgs_department,

               v_cgs_destination,

               v_cgs_office,

               v_cgs_origin,

               v_cgs_division

          FROM ajcl_bc_ies_items i

         WHERE bc_environment = gv_bc_environment

           AND TRIM(i.charge_type_code) = v_charge_type_code

           AND TRIM(i.business_line) = TRIM(ies_ap_line_row.business_line)

           AND NVL(i.inactive_date, SYSDATE + 1) > SYSDATE;



        IF ( ies_ap_line_row.destination_country IS NOT NULL ) THEN



          BEGIN



            SELECT cc.destination

              INTO v_cgs_destination

              FROM ajcl_bc_ies_country_codes cc

             WHERE bc_environment = gv_bc_environment

               AND country_code = ies_ap_line_row.destination_country;



          EXCEPTION

            WHEN NO_DATA_FOUND THEN

              v_cgs_destination := null;

            WHEN OTHERS THEN

              v_cgs_destination := null;



          END;



        END IF;



        IF ( ies_ap_line_row.origin_country IS NOT NULL ) THEN



          BEGIN



            SELECT cc.origin

              INTO v_cgs_origin

              FROM ajcl_bc_ies_country_codes cc

             WHERE bc_environment = gv_bc_environment

               AND country_code = ies_ap_line_row.origin_country;



          EXCEPTION

            WHEN NO_DATA_FOUND THEN

              v_cgs_origin := null;

            WHEN OTHERS THEN

              v_cgs_origin := null;



          END;



        END IF;



      EXCEPTION

        WHEN NO_DATA_FOUND THEN

          print_log ( 'Could not retrieve cost of goods sold accounting for Charge Type Code ' || v_charge_type_code || ' and Business Line ' || TRIM(ies_ap_line_row.business_line) );



      END;



      v_offset_accountno := null;

      v_offset_company := null;

      v_offset_department := null;

      v_offset_destination := null;

      v_offset_office := null;

      v_offset_origin := null;

      v_offset_division := null;



      -- Get offset to cost of goods sold accounting 

      BEGIN



        SELECT i.offset_accountno,

               i.offset_company,

               i.offset_department,

               i.offset_destination,

               i.offset_office,

               i.offset_origin,

               i.offset_division

          INTO v_offset_accountno,

               v_offset_company,

               v_offset_department,

               v_offset_destination,

               v_offset_office,

               v_offset_origin,

               v_offset_division

          FROM ajcl_bc_ies_items i

         WHERE bc_environment = gv_bc_environment

           AND TRIM(i.charge_type_code) = v_charge_type_code

           AND TRIM(i.business_line) = TRIM(ies_ap_line_row.business_line)

           AND NVL(i.inactive_date, SYSDATE + 1) > SYSDATE;



      EXCEPTION

        WHEN NO_DATA_FOUND THEN

          print_log ( 'Could not retrieve offset to cost of goods sold accounting.' );



      END;



      v_je_line_desc := 'Inv#:' || ies_ap_line_row.invoice_number || 

                        '|ChgTyp:' || ies_ap_line_row.description ||

                        '|Item#:' || ies_ap_line_row.charge_type_code || '.' || ies_ap_line_row.business_line ||

                        '|ShipRef:' || nvl(ies_ap_line_row.shipment_reference,'NIF') || -- 'Not in File') ||

                        '|Dest:' || nvl(ies_ap_line_row.destination_country,'NIF') || -- 'Not in File') ||

                        '|Orig:' || nvl(ies_ap_line_row.origin_country,'NIF'); -- 'Not in File') 



      -- Se agrega para que no exceda los 100 caracteres que tiene el campo en la tabla standard de journals

      v_je_line_desc := SUBSTR(v_je_line_desc,1,100);



      v_line_num := v_line_num + 1;



      SELECT AJCL_BC_JE_LINE_ID_S.NEXTVAL

        INTO v_jelineid

        FROM DUAL;



      -- Insert into ajcl_bc_ies_gl_lines

      INSERT 

        INTO ajcl_bc_ies_gl_lines

           ( bc_environment,

             journaltemplatename,

             journalbatchname,

             documentNo,

             postingdate,

             userjesourcename,

             userjecategoryname,

             account,

             company,

             department,

             destination,

             office,

             origin,

             division,

             currencycode,

             currencyconversiondate,

             currencyconversionrate,

             currencyconversiontype,

             entereddr,

             enteredcr,

             description,

             worksheetnumber,

             oraclelineno,

             --

             dff_ap_financial_party,

             dff_orig_ap_internal,

             --

             jelineid,

             --

             status,

             creation_date,

             created_by,

             last_update_date,

             last_updated_by,

             request_id )

      SELECT gv_bc_environment,

             gv_journal_template_name,

             gv_journal_batch_name,

             TO_CHAR(gv_request_id) || '.' || TO_CHAR(NVL(gv_gl_date,TRUNC(SYSDATE)),'YYYYMMDD'), -- documentNo

             TO_CHAR(NVL(gv_gl_date,TO_DATE(ies_ap_line_row.accounting_date,'YYYY-MM-DD')),'YYYY-MM-DD'), -- postingdate

             a.user_je_source_name,

             b.user_je_category_name,

             v_cgs_accountno, 

             v_cgs_company, 

             v_cgs_department,

             v_cgs_destination,

             v_cgs_office,

             v_cgs_origin,

             v_cgs_division,        

             ies_ap_line_row.currency_code, -- currencycode

             NULL, -- currencyconversiondate

             NULL, -- currencyconversionrate

             NULL, -- currencyconversiontype

             ies_ap_line_row.charge_amount, -- eneterddr

             0, -- eneterdcr

             v_je_line_desc, -- description

             ies_ap_line_row.shipment_reference, -- worksheetnumber

             v_line_num,

             --

             ies_ap_line_row.financial_party,

             ies_ap_line_row.orig_ap_internal,

             --

             v_jelineid,

             --

             'NEW', -- status

             SYSDATE,

             gv_user_id,

             SYSDATE,

             gv_user_id,

             gv_request_id

        FROM gl_je_sources a, 

             gl_je_categories b

       WHERE a.je_source_name = gv_journal_source

         AND b.je_category_name = gv_journal_category;



      IF ( SQL%ROWCOUNT > 0 ) THEN



        print_log (SQL%ROWCOUNT || ' cost of goods sold records inserted into ajcl_bc_ies_gl_lines.');



      END IF;



      v_line_num := v_line_num + 1;



      SELECT AJCL_BC_JE_LINE_ID_S.NEXTVAL

        INTO v_jelineid

        FROM DUAL;



      -- Insert offset record into gl_interface 

      INSERT 

        INTO ajcl_bc_ies_gl_lines

           ( bc_environment,

             journaltemplatename,

             journalbatchname,

             documentNo,

             postingDate,

             userjesourcename,

             userjecategoryname,

             account,

             company,

             department,

             destination,

             office,

             origin,

             division,

             currencycode,

             currencyconversiondate,

             currencyconversionrate,

             currencyconversiontype,

             entereddr,

             enteredcr,

             description,

             worksheetnumber,

             oraclelineno,

             --

             dff_ap_financial_party,

             dff_orig_ap_internal,

             --

             jelineid,

             --

             status,

             creation_date,

             created_by,

             last_update_date,

             last_updated_by,

             request_id )

      SELECT gv_bc_environment,

             gv_journal_template_name,

             gv_journal_batch_name,

             TO_CHAR(gv_request_id) || '.' || TO_CHAR(NVL(gv_gl_date,TRUNC(SYSDATE)),'YYYYMMDD'), -- documentNo

             TO_CHAR(NVL(gv_gl_date,TO_DATE(ies_ap_line_row.accounting_date,'YYYY-MM-DD')),'YYYY-MM-DD'), -- postingdate

             a.user_je_source_name,

             b.user_je_category_name,

             v_offset_accountno, 

             v_offset_company,

             v_offset_department,

             v_offset_destination,

             v_offset_office,

             v_offset_origin,

             v_offset_division,

             ies_ap_line_row.currency_code,

             NULL, -- currencyconversiondate

             NULL, -- currencyconversionrate

             NULL, -- currencyconversiontype

             0, -- eneterddr

             ies_ap_line_row.charge_amount, -- eneterdcr

             v_je_line_desc, -- description

             ies_ap_line_row.shipment_reference, -- worksheetnumber

             v_line_num,

             --

             ies_ap_line_row.financial_party,

             ies_ap_line_row.orig_ap_internal,

             --

             v_jelineid,

             --

             'NEW', -- status

             SYSDATE,

             gv_user_id,

             SYSDATE,

             gv_user_id,

             gv_request_id

        FROM gl_je_sources a, 

             gl_je_categories b

       WHERE a.je_source_name = gv_journal_source

         AND b.je_category_name = gv_journal_category;



       IF ( SQL%ROWCOUNT > 0 ) THEN



          print_log ( SQL%ROWCOUNT || ' offset to cost of goods sold records inserted into ajcl_bc_ies_gl_lines.');



       END IF;



       UPDATE ajc_ap_ies_inbound_data

          SET interface_status = 'TRANSFERRED',

              last_update_date = sysdate

        WHERE rowid = ies_ap_line_row.in_rowid;



    END LOOP; -- ies_ap_line_row



    COMMIT;



    v_remaining_count := 0;



    SELECT COUNT(1)

      INTO v_remaining_count

      FROM ajc_ap_ies_inbound_data

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND TRIM(gl_account) LIKE '5%'

       -- AND ( TO_DATE(accounting_date,'YYYY-MM-DD') < NVL(p_from_accounting_date, TO_DATE('01-JAN-1900'))

       --      OR TO_DATE(accounting_date,'YYYY-MM-DD') > NVL(p_to_accounting_date, TO_DATE('31-DEC-4712')))

       ;



    IF ( v_remaining_count > 0 ) THEN



      print_log ( '* WARNING * ' || v_remaining_count || ' unprocessed records exist outside the accounting date range specified.' );



    END IF;



    p_status := 'S';



    print_log ( 'ajcl_bc_ies_gl_pkg.insert_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log ( 'ajcl_bc_ies_gl_pkg.insert_p (!). Error: ' || SQLERRM );



  END insert_p;



  PROCEDURE insert_json_table ( p_status_code            IN OUT VARCHAR2,

                                p_error_message          IN OUT VARCHAR2,

                                p_record_count               IN NUMBER,

                                p_json_number                IN NUMBER,

                                p_json_data                  IN CLOB ) IS

  BEGIN



      INSERT 

        INTO ajcl_bc_ies_gl_jsons

           ( bc_environment,

             request_id,

             record_count,

             json_number,

             json_data,

             creation_date,

             created_by,

             last_update_date,

             last_updated_by)

    VALUES ( gv_bc_environment,

             gv_request_id,

             p_record_count,

             p_json_number,

             p_json_data,

             SYSDATE,

             gv_user_id,

             SYSDATE,

             gv_user_id );



    COMMIT;



  END insert_json_table;   



  PROCEDURE insert_request_table ( p_status_code            IN OUT VARCHAR2,

                                   p_error_message          IN OUT VARCHAR2,

                                   p_record_count           IN     NUMBER ) IS  

  BEGIN



      INSERT 

        INTO ajcl_bc_ies_gl_requests

           ( request_id,

             bc_environment,

             record_count,

             creation_date,

             created_by,

             last_update_date,

             last_updated_by )

    VALUES ( gv_request_id,

             gv_bc_environment,

             p_record_count,

             SYSDATE,

             gv_user_id,

             SYSDATE,

             gv_user_id );



    COMMIT;



  END insert_request_table;



  PROCEDURE generate_jsons ( p_journals_count   OUT   NUMBER,

                             p_error_message    OUT   VARCHAR2,

                             p_status           OUT   VARCHAR2 ) IS



      CURSOR c_journals IS

      SELECT *

        FROM ajcl_bc_ies_gl_lines

       WHERE bc_environment = gv_bc_environment

         AND ( ( request_id = gv_request_id AND UPPER(status) IN ('NEW') )

               -- 20240917

            OR ( request_id != gv_request_id AND UPPER(status) IN ('REJECTED','ERROR') ) 

               -- 20240917

               )

    ORDER BY oraclelineno;



    v_url                     VARCHAR2(2000);

    v_api                     VARCHAR2(300);

    v_clob_response           CLOB;

    v_json_number             NUMBER := 1;

    v_split_quantity          NUMBER := 0;



    v_count                   NUMBER := 0;

    r_id                      VARCHAR2(20);

    v_error_message           VARCHAR2(2000);

    v_status                  VARCHAR2(1);



    e_cust_exception          EXCEPTION;



  BEGIN



    print_log('ajcl_bc_ies_gl_pkg.generate_jsons (+)');



    v_api := ajcl_bc_ws_utils_pkg.get_api_f ( p_entity => 'INBOUND JOURNALS',

                                              p_subentity => 'LINES',

                                              p_method => 'POST' );

    print_log ( 'v_api: ' || v_api );



    APEX_JSON.initialize_clob_output;

    APEX_JSON.open_object;

    APEX_JSON.open_array('requests');



    FOR cj IN c_journals LOOP



      BEGIN



        IF ( cj.account IS NULL ) THEN



          v_error_message := 'La cuenta BC debe tener valor.';

          RAISE e_cust_exception;



        END IF;



        v_count := v_count + 1;

        r_id := 'r' || v_count;



        v_split_quantity := v_split_quantity + 1;



        APEX_JSON.open_object; -- {

        APEX_JSON.write('method','POST');

        APEX_JSON.write('id',r_id);      



        APEX_JSON.write('url',utl_url.escape('companies(' || gv_bc_company_id || ')/' || v_api));



        APEX_JSON.open_object('headers'); -- headers{

        APEX_JSON.write('Content-Type','application/json');

        APEX_JSON.close_object; -- } headers



        APEX_JSON.open_object('body');

        APEX_JSON.write('source','IES');

        APEX_JSON.write('jelineid',cj.jelineid,true);

        APEX_JSON.write('journaltemplatename',cj.journaltemplatename);

        APEX_JSON.write('journalbatchname',cj.journalbatchname);

        APEX_JSON.write('documentno',cj.documentNo);

        APEX_JSON.write('postingdate',cj.postingdate);

        APEX_JSON.write('userjesourcename',cj.userjesourcename);

        APEX_JSON.write('userjecategoryname',cj.userjecategoryname);

        APEX_JSON.write('account',cj.account,true);

        APEX_JSON.write('company',cj.company,true);

        APEX_JSON.write('department',cj.department,true); 

        APEX_JSON.write('destination',cj.destination,true); 

        APEX_JSON.write('office',cj.office,true); 

        APEX_JSON.write('origin',cj.origin,true); 

        APEX_JSON.write('division',cj.division,true); 

        APEX_JSON.write('currencycode',cj.currencycode);

        APEX_JSON.write('currencyconversiondate',cj.currencyconversiondate,true);

        APEX_JSON.write('currencyconversionrate',cj.currencyconversionrate,true);

        APEX_JSON.write('currencyconversiontype',cj.currencyconversiontype,true);

        APEX_JSON.write('entereddr',cj.entereddr);

        APEX_JSON.write('enteredcr',cj.enteredcr);

        APEX_JSON.write('description',cj.description,true);

        APEX_JSON.write('worksheetno',cj.worksheetnumber);

        APEX_JSON.write('oraclelineno',cj.oracleLineNo,true);

        -- DFF

        APEX_JSON.write('iesapfinancialparty',cj.dff_ap_financial_party,true);

        APEX_JSON.write('iesorigapinternal',cj.dff_orig_ap_internal,true);

        -- APEX_JSON.write('iesoraclevendornumber',cj.dff_oracle_vendor_number,true);

        -- APEX_JSON.write('iesoraclevendorname',cj.dff_oracle_vendor_name,true);

        -- APEX_JSON.write('iestrxcurrencycode',cj.dff_trx_currency_code,true);

        -- APEX_JSON.write('iestrxorigcurramount',cj.dff_trx_orig_curr_amount,true);

        -- APEX_JSON.write('iestrxcontractrate',cj.dff_trx_contract_rate,true);

        --

        APEX_JSON.write('requestid',gv_request_id,true);

        APEX_JSON.close_object; -- } body



        APEX_JSON.close_object; -- }



        -- Se actualiza en la tabla de lineas

        UPDATE ajcl_bc_ies_gl_lines

           SET json_number = v_json_number,

               -- 20240917

               request_id = gv_request_id, -- Se pone el request_id actual a lo nuevo y a lo reprocesado

               -- 20240917

               error_message = NULL

         WHERE documentno = cj.documentno

           AND oraclelineno = cj.oraclelineno

           AND request_id = cj.request_id

           AND bc_environment = gv_bc_environment;



        COMMIT;



        IF ( v_split_quantity = gv_lines_per_json ) THEN



          APEX_JSON.close_array; -- ] requests

          APEX_JSON.close_object;



          insert_json_table ( p_status_code => v_status,

                              p_error_message => v_error_message,

                              p_record_count => v_split_quantity,

                              p_json_number => v_json_number,

                              p_json_data => APEX_JSON.get_clob_output );



          v_split_quantity := 0;

          v_json_number := v_json_number + 1;



          APEX_JSON.free_output;



          -- Vuelvo a iniciar CLOB

          APEX_JSON.initialize_clob_output;

          APEX_JSON.open_object;

          APEX_JSON.open_array('requests'); -- requests: [



        END IF;



      EXCEPTION

        WHEN e_cust_exception THEN

            v_error_message := 'Error al crear detalle de JSON para Lote: ' || cj.journalbatchname || ' documentNo ' || cj.documentNo || ' Linea ' || cj.oracleLineNo || ', Error:' || v_error_message;

            RAISE e_cust_exception;

        WHEN others THEN

            v_error_message := 'Error general al crear detalle de JSON para Lote: ' || cj.journalbatchname || ' documentNo ' || cj.documentNo || ' Linea ' || cj.oracleLineNo || ', Error: ' || SQLERRM;

            RAISE e_cust_exception;



      END;



    END LOOP;



    p_journals_count := v_count;



    IF ( v_split_quantity > 0 ) THEN



      APEX_JSON.close_array; -- ] requests

      APEX_JSON.close_object;



      insert_json_table ( p_status_code          => v_status,

                          p_error_message        => v_error_message,

                          p_record_count         => v_split_quantity,

                          p_json_number          => v_json_number,

                          p_json_data            => APEX_JSON.get_clob_output );



      APEX_JSON.free_output;



    END IF;



    insert_request_table ( p_status_code => v_status,

                           p_error_message => v_error_message,

                           p_record_count => v_count );



    p_status := 'S';



    print_log('ajcl_bc_ies_gl_pkg.generate_jsons (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('ajcl_bc_ies_gl_pkg.generate_jsons (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));

    WHEN others THEN

        v_error_message := 'Not caught error creating JSON, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('ajcl_bc_ies_gl_pkg.generate_jsons (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));



  END generate_jsons;



  PROCEDURE call_ws ( p_error_message    IN OUT   VARCHAR2,

                      p_status           IN OUT   VARCHAR2 ) IS



      CURSOR c_jsons IS

      SELECT REPLACE(json_data,'\/','/') json_data,

             json_number

        FROM ajcl_bc_ies_gl_jsons

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

    ORDER BY json_number;



    v_url                     VARCHAR2(200);



    v_error_message           VARCHAR2(2000);

    e_cust_exception          EXCEPTION;

    v_clob_response           CLOB;



  BEGIN



    print_log('ajcl_bc_ies_gl_pkg.call_ws (+)');



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_batch_url_f ( p_bc_environment => gv_bc_environment,

                                                                p_entity => 'INBOUND JOURNALS',

                                                                p_subentity => 'LINES',

                                                                p_method => 'POST',

                                                                p_company_id => gv_bc_company_id );



    print_log ( 'v_url: ' || v_url );



    FOR cj IN c_jsons LOOP



      BEGIN



        print_log ( 'Json Data Number: ' || cj.json_number || ' | ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') );



        -- 20251106 REINTENTO

        gv_retry := 'N';



        BEGIN

        -- 20251106 REINTENTO



          v_clob_response := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_url),

                                                                        p_request_header_name1 => 'Content-Type',

                                                                        p_request_header_value1 => 'application/json;IEEE754Compatible=true',

                                                                        p_request_header_name2 => NULL,

                                                                        p_request_header_value2 => NULL,

                                                                        p_http_method => 'POST',

                                                                        p_body => cj.json_data );



          -- 20251106 REINTENTO

          IF ( UPPER(v_clob_response) LIKE UPPER('%502 Bad Gateway%') ) THEN



            print_log('502 Bad Gateway'); 

            gv_retry := 'Y';



          END IF;



        EXCEPTION

          WHEN OTHERS THEN

            print_log('Error calling ajcl_bc_ws_utils_pkg.patch_post_bc_row_f: ' || SQLCODE || '|' || SQLERRM ); 

            gv_retry := 'Y';



        END;



        IF ( gv_retry = 'Y' ) THEN



          print_log( 'Connection error detected. Retrying in ' || gv_retry_in_seconds || ' seconds.' );

          DBMS_LOCK.sleep(gv_retry_in_seconds);



          v_clob_response := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_url),

                                                                        p_request_header_name1 => 'Content-Type',

                                                                        p_request_header_value1 => 'application/json;IEEE754Compatible=true',

                                                                        p_request_header_name2 => NULL,

                                                                        p_request_header_value2 => NULL,

                                                                        p_http_method => 'POST',

                                                                        p_body => cj.json_data );



        END IF;

        -- 20251106 REINTENTO



        BEGIN



          UPDATE ajcl_bc_ies_gl_jsons

             SET json_data_response = v_clob_response,

                 last_update_date = sysdate

           WHERE request_id = gv_request_id

             AND bc_environment = gv_bc_environment

             AND json_number = cj.json_number;



          COMMIT;



        EXCEPTION

          WHEN OTHERS THEN

            v_error_message := 'Error al Actualizar tabla ajcl_bc_ies_gl_jsons con respuesta generada al llamar al Web Service. Error: ' || SQLERRM;

            RAISE e_cust_exception;



        END; 



        IF ( UPPER(v_clob_response) LIKE '%"ERROR":%' ) THEN



          v_error_message := SUBSTR(v_clob_response,INSTR(v_clob_response,'"message":') + 11,

                             INSTR(v_clob_response,'CorrelationId:') - INSTR(v_clob_response,'"message":') - 11

                             );



          -- Marco todos las lineas del asiento con error

          BEGIN



            UPDATE ajcl_bc_ies_gl_lines

               SET status = 'ERROR'

                   ,error_message = v_error_message

             WHERE request_id = gv_request_id 

               AND bc_environment = gv_bc_environment;



            COMMIT;



          END;



          RAISE e_cust_exception;



        ELSE



          p_status := 'S';



        END IF;



      EXCEPTION

        WHEN e_cust_exception THEN

          v_error_message := 'Error al procesar JSON nro: ' || cj.json_number || ', Error:' || v_error_message;

          RAISE e_cust_exception;



        WHEN others THEN

          v_error_message := 'Error general al procesar JSON nro: ' || cj.json_number || ', Error:' || SQLERRM;

          RAISE e_cust_exception;



      END;



    END LOOP;



    print_log('ajcl_bc_ies_gl_pkg.call_ws (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_ies_gl_pkg.call_ws (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));



    WHEN others THEN

      v_error_message := 'Not caught error - AJCL General Journal Inbounds, Error: '||sqlerrm;

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_ies_gl_pkg.call_ws (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));



  END call_ws;



  PROCEDURE call_job ( p_error_message   IN OUT   VARCHAR2,

                       p_status          IN OUT   VARCHAR2 ) IS



    v_object_id         NUMBER;

    v_error_message     VARCHAR2(2000);

    e_cust_exception    EXCEPTION;

    v_clob_response     CLOB;



  BEGIN



    print_log('ajcl_bc_ies_gl_pkg.call_job (+)');



    v_object_id := ajcl_bc_ws_utils_pkg.get_object_id_f ( 'JOURNALS' ); 

    print_log ( 'v_object_id: ' || v_object_id || ' - ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));



    v_clob_response := ajcl_bc_ws_utils_pkg.run_job_queue_f ( p_bc_environment => gv_bc_environment,

                                                              p_company_id => gv_bc_company_id,

                                                              p_object_id => v_object_id );



    IF ( UPPER(v_clob_response) LIKE '%"ERROR":%' ) THEN



      print_log('An error occurred while executing the job JOURNALS.');

      p_status := 'E'; 



    ELSE



      print_log('The JOURNALS job was executed successfully.');

      p_status := 'S';



    END IF;



    BEGIN



      UPDATE ajcl_bc_ies_gl_requests

         SET json_job_response = v_clob_response,

             last_update_date = SYSDATE

       WHERE request_id = gv_request_id;



      COMMIT;



    EXCEPTION

      WHEN OTHERS THEN

        v_error_message := 'Error al Actualizar tabla ajcl_bc_ies_gl_requests con respuesta generada al llamar al Web Service. Error: ' || SQLERRM;

        RAISE e_cust_exception;



    END; 



    IF REPLACE(substr(v_clob_response,INSTR(v_clob_response,'"value"')+8,LENGTH(v_clob_response)),'}') in ('"Success"','""','"Job Queue Scheduled successfully."') THEN



      p_status := 'S';



    ELSE



      v_error_message := 'Error al llamar al Job, Mensaje: ' || REPLACE(substr(v_clob_response,INSTR(v_clob_response,'"value"')+8,LENGTH(v_clob_response)),'}');

      print_log(v_clob_response);

      RAISE e_cust_exception;



    END IF;



    print_log('ajcl_bc_ies_gl_pkg.call_job (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_ies_gl_pkg.call_job (!). '|| TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));

    WHEN OTHERS THEN

      v_error_message := 'Not caught error when calling Job, Error: ' || SQLERRM;

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_ies_gl_pkg.call_job (!). '|| TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));



  END call_job;



  PROCEDURE call_ws_staging_pending ( p_pending_rows     OUT VARCHAR2,

                                      p_error_message IN OUT VARCHAR2,

                                      p_status        IN OUT VARCHAR2 ) IS



    v_url               VARCHAR2(2000);



    v_error_message     VARCHAR2(2000);

    e_cust_exception    EXCEPTION;

    v_clob_response     CLOB;

    v_count             NUMBER := 0;    



  BEGIN



    print_log('ajcl_bc_ies_gl_pkg.call_ws_staging_pending (+)');



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                          p_entity => 'INBOUND JOURNALS',

                                                          p_subentity => 'LINES',

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id )

             || '?$filter=requestid eq ' || gv_request_id

             ||' and status eq ''Pending''';



    print_log('v_url: ' || v_url);



    LOOP



      v_count := v_count + 1;



      -- 20251219 REINTENTO

      gv_retry := 'N';



      BEGIN

      -- 20251219 REINTENTO



        v_clob_response := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



        -- 20251219 REINTENTO

        IF ( UPPER(v_clob_response) LIKE UPPER('%502 Bad Gateway%') ) THEN



          print_log('502 Bad Gateway'); 

          gv_retry := 'Y';



        END IF;



      EXCEPTION

        WHEN OTHERS THEN

          print_log('Error calling ajcl_bc_ws_utils_pkg.get_bc_clob_result_f: ' || SQLCODE || '|' || SQLERRM ); 

          gv_retry := 'Y';



      END;



      IF ( gv_retry = 'Y' ) THEN



        print_log( 'Connection error detected. Retrying in ' || gv_retry_in_seconds || ' seconds.' );

        DBMS_LOCK.sleep(gv_retry_in_seconds);



        v_clob_response := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



      END IF;

      -- 20251219 REINTENTO 



      BEGIN



        SELECT COUNT(1)

          INTO p_pending_rows

          FROM ( SELECT status

                   FROM json_table ( v_clob_response,

                                     '$.value[*]' COLUMNS ( status   VARCHAR2(4000)  path '$.status') ))

         WHERE status ='Pending';



        EXCEPTION

          WHEN OTHERS THEN

            v_error_message := 'Error obteniendo cantidad de registros pendientes al llamar al Web Service ' || '. Error: ' || SQLERRM;

            RAISE e_cust_exception;



        END; 



      EXIT WHEN p_pending_rows = 0 OR v_count = 20;



    END LOOP;



    print_log ( 'Number of pending records WS calls: ' || v_count );

    print_log ( 'Number pending records: ' || p_pending_rows );



    print_log ( 'ajcl_bc_ies_gl_pkg.call_ws_staging_pending (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_ies_gl_pkg.call_ws_staging_pending (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));

    WHEN others THEN

      v_error_message := 'Not caught error when calling Web Service Staging Table. Error: ' || SQLERRM;

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_ies_gl_pkg.call_ws_staging_pending (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));



  END call_ws_staging_pending;



  PROCEDURE call_ws_staging ( p_error_message   IN OUT   VARCHAR2,

                              p_status          IN OUT   VARCHAR2 ) IS



    v_url               VARCHAR2(2000);



    v_status            VARCHAR2(1);

    v_error_message     VARCHAR2(2000);

    e_cust_exception    EXCEPTION;

    v_clob_response     CLOB;



  BEGIN



    print_log ( 'ajcl_bc_ies_gl_pkg.call_ws_staging (+)');



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                          p_entity => 'INBOUND JOURNALS',

                                                          p_subentity => 'LINES',

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id )

             || '?$filter=requestid eq ' || gv_request_id;



    print_log('v_url: ' || v_url);



    -- 20251219 REINTENTO

    gv_retry := 'N';



    BEGIN

    -- 20251219 REINTENTO



      v_clob_response := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



      -- 20251219 REINTENTO

      IF ( UPPER(v_clob_response) LIKE UPPER('%502 Bad Gateway%') ) THEN



        print_log('502 Bad Gateway'); 

        gv_retry := 'Y';



      END IF;



    EXCEPTION

      WHEN OTHERS THEN

        print_log('Error calling ajcl_bc_ws_utils_pkg.get_bc_clob_result_f: ' || SQLCODE || '|' || SQLERRM ); 

        gv_retry := 'Y';



    END;



    IF ( gv_retry = 'Y' ) THEN



      print_log( 'Connection error detected. Retrying in ' || gv_retry_in_seconds || ' seconds.' );

      DBMS_LOCK.sleep(gv_retry_in_seconds);



      v_clob_response := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



    END IF;

    -- 20251219 REINTENTO 



    BEGIN



      UPDATE ajcl_bc_ies_gl_requests

         SET json_staging_response = v_clob_response,

             last_update_date = sysdate

       WHERE request_id = gv_request_id;



      COMMIT;



    EXCEPTION

      WHEN OTHERS THEN

        v_error_message := 'Error al Actualizar tabla ajcl_bc_ies_gl_requests con respuesta generada al llamar al Web Service ' || '. Error: ' || SQLERRM;

        RAISE e_cust_exception;



    END; 



    print_log ( 'ajcl_bc_ies_gl_pkg.call_ws_staging (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_ies_gl_pkg.call_ws_staging (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));

    WHEN others THEN

      v_error_message := 'Not caught error when calling Web Service from Job. Error: ' || SQLERRM;

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_ies_gl_pkg.call_ws_staging (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));



  END call_ws_staging; 



  PROCEDURE validate_ws_data ( p_error_message   IN OUT   VARCHAR2,

                               p_status          IN OUT   VARCHAR2 ) IS



    CURSOR c_lines ( p_clob_result IN CLOB ) IS

    SELECT systemid,

           journaltemplatename,

           journalbatchname,

           documentno,

           postingdate,

           oraclelineno,           

           account,

           entereddr,

           enteredcr,        

           status,     

           statusremarks

      FROM json_table( p_clob_result,

                       '$.value[*]' COLUMNS ( systemid            VARCHAR2(4000)  path '$.systemid',

                                              journaltemplatename VARCHAR2(4000)  path '$.journaltemplatename',

                                              journalbatchname    VARCHAR2(4000)  path '$.journalbatchname',

                                              documentno          VARCHAR2(4000)  path '$.documentno',

                                              postingdate         VARCHAR2(4000)  path '$.postingdate', 

                                              oraclelineno        VARCHAR2(4000)  path '$.oraclelineno',

                                              account             VARCHAR2(4000)  path '$.account',

                                              entereddr           VARCHAR2(4000)  path '$.entereddr',

                                              enteredcr           VARCHAR2(4000)  path '$.enteredcr',

                                              status              VARCHAR2(4000)  path '$.status', 

                                              statusremarks       VARCHAR2(4000)  path '$.statusremarks' ) );



    v_error_message     VARCHAR2(2000);

    v_clob_result       CLOB;

    e_cust_exception    EXCEPTION;



  BEGIN



    print_log ( 'ajcl_bc_ies_gl_pkg.validate_ws_data (+)');



    BEGIN



      SELECT json_staging_response

        INTO v_clob_result

        FROM ajcl_bc_ies_gl_requests

       WHERE request_id = gv_request_id;



    EXCEPTION

      WHEN OTHERS THEN

        v_error_message := 'Error al obtener json almacenado en tabla ajcl_bc_ies_gl_requests del Web Service. Error: ' || SQLERRM;

        RAISE e_cust_exception;



    END;



    FOR cl IN c_lines ( v_clob_result ) LOOP



      BEGIN



        UPDATE ajcl_bc_ies_gl_lines abagl

           SET status = UPPER(cl.status),

               error_message = cl.statusremarks,

               last_update_date = SYSDATE

         WHERE abagl.documentno = cl.documentno

           AND abagl.oraclelineno = cl.oraclelineno

           AND request_id = gv_request_id

           AND bc_environment = gv_bc_environment;



      EXCEPTION

        WHEN OTHERS THEN

          v_error_message := 'Error al actualizar tabla ajcl_bc_ies_gl_lines con respuesta generada al llamar al Web Service. Error: ' || SQLERRM;

          RAISE e_cust_exception;



      END;



    END LOOP;



    COMMIT;



    p_status := 'S';



    print_log ( 'ajcl_bc_ies_gl_pkg.validate_ws_data (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_ies_gl_pkg.validate_ws_data (!)');

    WHEN others THEN

      v_error_message := 'Error not caught when updating journals lines sent by the process, Error: ' || SQLERRM;

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_ies_gl_pkg.validate_ws_data (!)');



  END validate_ws_data;   



  PROCEDURE call_ws_delete ( p_documentno      IN       VARCHAR2,

                             p_error_message   IN OUT   VARCHAR2,

                             p_status          IN OUT   VARCHAR2 ) IS



    v_api               VARCHAR2(500);

    v_url               VARCHAR2(500);

    v_body              CLOB;  

    v_clob_response     CLOB;



  BEGIN



    print_log ( 'ajcl_bc_ies_gl_pkg.call_ws_delete (+)');



    v_api := ajcl_bc_ws_utils_pkg.get_api_f ( p_entity => 'INBOUND JOURNALS DEL',

                                              p_subentity => NULL,

                                              p_method => 'DEL' );



    print_log ( 'v_api: ' || v_api );



    v_url := ajcl_bc_ws_utils_pkg.get_base_standard_url_f ( gv_bc_environment, v_api, gv_bc_company_id );

    print_log ( 'v_url: ' || v_url );



    v_body := '{"p_documentno": "' || p_documentno || '"}';



    print_log ( 'v_body: ' || v_body );



    v_clob_response := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url,

                                                                  p_request_header_name1 => 'Content-Type',

                                                                  p_request_header_value1 => 'application/json',

                                                                  p_request_header_name2 => NULL,

                                                                  p_request_header_value2 => NULL,

                                                                  p_http_method => 'POST',

                                                                  p_body => v_body );



    print_log ( 'v_clob_response: ' || v_clob_response );

    p_error_message := v_clob_response;



    IF ( UPPER(v_clob_response) LIKE '%SUCCESS%' ) THEN



      p_status := 'S';



    ELSE



      p_status := 'E';



    END IF;



    print_log ( 'ajcl_bc_ies_gl_pkg.call_ws_delete (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      p_error_message := 'Not caught error when Delete General Journal Inbounds, Error: ' || SQLERRM;

      print_log (p_error_message);

      print_log ('ajcl_bc_ies_gl_pkg.call_ws_delete (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));



  END call_ws_delete;



  PROCEDURE check_lines_status_p ( p_error_message   IN OUT   VARCHAR2,

                                   p_status          IN OUT   VARCHAR2 ) IS



    v_error_lines   NUMBER;

    e_error_lines   EXCEPTION;



      CURSOR c_documentno_error IS

      SELECT documentno

        FROM ajcl_bc_ies_gl_lines

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND status IN ('ERROR','REJECTED')

    GROUP BY documentno;



  BEGIN



    print_log ( 'ajcl_bc_ies_gl_pkg.check_lines_status_p (+)');



    -- Se recorren los documentos ERROR/REJECTED y se borran de la inbound

    FOR cdnoe IN c_documentno_error LOOP



      call_ws_delete ( p_documentno => cdnoe.documentno,

                       p_error_message => p_error_message,

                       p_status => p_status );



      IF ( p_status = 'E' ) THEN



        RAISE e_error_lines;



      END IF;



    END LOOP;



    p_status := 'S';



    print_log ( 'ajcl_bc_ies_gl_pkg.check_lines_status_p (-)');



  EXCEPTION

    WHEN e_error_lines THEN

      p_status := 'E';

      p_error_message := 'Cant delete journal line.';

      print_log ( 'ajcl_bc_ies_gl_pkg.check_lines_status_p (!). Error: ' || p_error_message);



    WHEN OTHERS THEN

      p_status := 'E';

      p_error_message := SQLERRM;

      print_log ( 'ajcl_bc_ies_gl_pkg.check_lines_status_p (!). Error: ' || SQLERRM);



  END check_lines_status_p; 



  -- Inserta los worksheets a enviar a BC en la tabla AJCL_BC_WORKSHEETS

  -- y ejecuta el procedure que los envia a BC

  PROCEDURE worksheets_to_bc_p ( p_status             IN OUT   VARCHAR2 ) IS



      CURSOR c_worksheets IS

      SELECT worksheetnumber ws_ies_num

        FROM ajcl_bc_ies_gl_lines

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND worksheetnumber IS NOT NULL

    GROUP BY worksheetnumber;



    v_total_worksheets   NUMBER;

    e_error              EXCEPTION;



  BEGIN



    print_log( 'ajcl_bc_ies_gl_pkg.worksheets_to_bc_p (+)' );



    v_total_worksheets := 0;



    FOR cw IN c_worksheets LOOP



      print_log ( 'ws_ies_num: ' || cw.ws_ies_num );

      v_total_worksheets := v_total_worksheets + ajcl_bc_worksheets_pkg.insert_p ( p_ws_ies_num => cw.ws_ies_num,

                                                                                   p_bc_environment => gv_bc_environment );



    END LOOP;



    print_log( 'v_total_worksheets: ' || v_total_worksheets );



    IF ( v_total_worksheets != 0 ) THEN



      ajcl_bc_worksheets_pkg.main_p ( p_bc_environment => gv_bc_environment,

                                      p_bc_company_id => gv_bc_company_id,

                                      p_bc_ifc => gv_bc_ifc,

                                      p_request_id => gv_request_id,

                                      p_log_seq => gv_log_seq,

                                      p_status => p_status );



      IF ( p_status != 'S' ) THEN



        RAISE e_error;



      END IF;



    END IF;



    p_status := 'S';

    print_log( 'ajcl_bc_ies_gl_pkg.worksheets_to_bc_p (-)' );



  EXCEPTION

    WHEN e_error THEN

      print_log( 'ajcl_bc_ies_gl_pkg.worksheets_to_bc_p (!). ' || SQLERRM );

      p_status := 'E';

    WHEN OTHERS THEN

      print_log( 'ajcl_bc_ies_gl_pkg.worksheets_to_bc_p (!). ' || SQLERRM );

      p_status := 'E';



  END worksheets_to_bc_p;



  PROCEDURE final_report_csv_p ( p_status   OUT   VARCHAR2 ) IS



      CURSOR c_processed_journals IS

      -- Armar SELECT que corresponda

      SELECT abagl.documentno,

             abagl.postingdate,

             abagl.userjesourcename,

             abagl.userjecategoryname,

             abagl.currencycode currency_code,

             abagl.status,

             SUM(NVL(abagl.entereddr,0)) entereddr,

             SUM(NVL(abagl.enteredcr,0)) enteredcr,

             COUNT(1) qty

        FROM ajcl_bc_ies_gl_lines abagl

       WHERE abagl.request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND UPPER(abagl.status) NOT IN ('ERROR','REJECTED')

    GROUP BY abagl.documentno,

             abagl.postingdate,

             abagl.userjesourcename,

             abagl.userjecategoryname,

             abagl.currencycode,

             abagl.status

    ORDER BY abagl.documentno;



      CURSOR c_errors IS

      SELECT abagl.documentno,

             abagl.postingdate,

             abagl.userjesourcename,

             abagl.userjecategoryname,

             abagl.currencycode currency_code,

             abagl.status,

             abagl.error_message,

             abagl.json_number,

             abagl.oraclelineno line_num,

             company || ' ' || 

               account || ' ' || 

               department || ' ' || 

               destination || ' ' || 

               office || ' ' ||

               origin || ' ' ||

               division account,

             NVL(abagl.entereddr,0) entered_dr,

             NVL(abagl.enteredcr,0) entered_cr

        FROM ajcl_bc_ies_gl_lines abagl

       WHERE abagl.request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND UPPER(abagl.status) = 'ERROR'

         AND abagl.error_message IS NOT NULL

    ORDER BY abagl.documentno,

             abagl.postingdate,

             abagl.json_number,

             abagl.oraclelineno;



  BEGIN



    print_log( 'ajcl_bc_ies_gl_pkg.final_report_csv_p (+)' );



    -- Insert Report Title

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => gv_bc_ifc || ' Report',

                                        p_request_id => gv_request_id );

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Request ID|' || gv_request_id,

                                        p_request_id => gv_request_id ); 



    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Tabla 1 -----------------------------------------------------------------------------------------------------------------                                    

    -- Insert Table Title

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Processed Journals',

                                        p_request_id => gv_request_id );



    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Insert Table Column Names                            

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Document No.' || '|' ||

                                                  'Effective Date' || '|' ||

                                                  'Source Name' || '|' ||

                                                  'Category Name' || '|' ||

                                                  'Currency Code' || '|' ||

                                                  'Status' || '|' ||

                                                  'Debit' || '|' ||

                                                  'Credit' || '|' ||

                                                  'Lines Qty',

                                        p_request_id => gv_request_id );                                        



    -- Se insertan los registros

    FOR cpj IN c_processed_journals LOOP



      ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                          p_text => cpj.documentno || '|' || 

                                                    cpj.postingdate || '|' || 

                                                    cpj.userjesourcename || '|' || 

                                                    cpj.userjecategoryname || '|' || 

                                                    cpj.currency_code || '|' || 

                                                    cpj.status || '|' || 

                                                    TRIM(cpj.entereddr) || '|' || 

                                                    TRIM(cpj.enteredcr) || '|' || 

                                                    TRIM(cpj.qty),

                                          p_request_id => gv_request_id );                                                          



    END LOOP;



    -- Tabla 2 -----------------------------------------------------------------------------------------------------------------

    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Insert Table Title

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Errors',

                                        p_request_id => gv_request_id );



    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Insert Table Column Names                            

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Document No.' || '|' ||

                                                  'Effective Date' || '|' ||

                                                  'Source Name' || '|' ||

                                                  'Category Name' || '|' ||

                                                  'Currency Code' || '|' ||

                                                  'Status' || '|' ||

                                                  'Line' || '|' ||

                                                  'Account' || '|' ||

                                                  'Debit' || '|' ||

                                                  'Credit' || '|' ||

                                                  'Error Message' || '|' ||

                                                  'Json Number',

                                        p_request_id => gv_request_id );  



    -- Se insertan los registros

    FOR ce IN c_errors LOOP



      ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                          p_text => ce.documentno || '|' || 

                                                    ce.postingdate || '|' || 

                                                    ce.userjesourcename || '|' || 

                                                    ce.userjecategoryname || '|' || 

                                                    ce.currency_code || '|' || 

                                                    ce.status || '|' || 

                                                    ce.line_num || '|' || 

                                                    ce.account || '|' || 

                                                    ce.entered_dr || '|' || 

                                                    ce.entered_cr || '|' || 

                                                    ce.error_message || '|' || 

                                                    ce.json_number,

                                          p_request_id => gv_request_id );  



    END LOOP;



    p_status := 'S';



    print_log( 'ajcl_bc_ies_gl_pkg.final_report_csv_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_ies_gl_pkg.final_report_csv_p (!). Error: ' || SQLERRM );



  END final_report_csv_p;



  PROCEDURE final_output_xlsx_p ( p_status   OUT   VARCHAR2 ) IS



    v_query     VARCHAR2(2000);

    c_cursor    SYS_REFCURSOR;

    v_sheet     NUMBER := 1;



      CURSOR c_sections IS

      SELECT *

        FROM ajcl_bc_outputs_xlsx

       WHERE ifc = gv_bc_ifc

         AND request_id = gv_request_id

         AND seq IN ( SELECT MIN(seq)

                        FROM ajcl_bc_outputs_xlsx

                       WHERE ifc = gv_bc_ifc

                         AND request_id = gv_request_id

                    GROUP BY section )

    ORDER BY seq;    



  BEGIN



    print_log( 'ajcl_bc_ies_gl_pkg.final_output_xlsx_p (+)' );



    gv_directory_output := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_OUTPUT' );



    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc || ' Output',

                                                p_request_id => gv_request_id,

                                                p_bc_environment => gv_bc_environment,

                                                p_jenkins_build_number => gv_jenkins_build_number,

                                                p_param_1_title => ' ',

                                                p_param_1_value => ' ',

                                                p_param_2_title => 'GL_DATE',

                                                p_param_2_value => TO_CHAR(gv_gl_date,'YYYY-MM-DD'),

                                                p_param_3_title => 'IF_ERRORS_STOP',

                                                p_param_3_value => gv_if_errors_stop );



    FOR cs IN c_sections LOOP



      v_sheet := v_sheet + 1;



      v_query := 'SELECT column1 "' || cs.column1 || '"';



      IF ( cs.column2 IS NOT NULL ) THEN

        v_query := v_query || ', column2 "' || cs.column2 || '"';

      END IF;  



      IF ( cs.column3 IS NOT NULL ) THEN

        v_query := v_query || ', column3 "' || cs.column3 || '"';

      END IF;



      IF ( cs.column4 IS NOT NULL ) THEN

        v_query := v_query || ', column4 "' || cs.column4 || '"';

      END IF; 



      IF ( cs.column5 IS NOT NULL ) THEN

        v_query := v_query || ', column5 "' || cs.column5 || '"';

      END IF;



      IF ( cs.column6 IS NOT NULL ) THEN

        v_query := v_query || ', column6 "' || cs.column6 || '"';

      END IF;



      IF ( cs.column7 IS NOT NULL ) THEN

        v_query := v_query || ', column7 "' || cs.column7 || '"';

      END IF;



      IF ( cs.column8 IS NOT NULL ) THEN

        v_query := v_query || ', column8 "' || cs.column8 || '"';

      END IF;



      IF ( cs.column9 IS NOT NULL ) THEN

        v_query := v_query || ', column9 "' || cs.column9 || '"';

      END IF;



      IF ( cs.column10 IS NOT NULL ) THEN

        v_query := v_query || ', column10 "' || cs.column10 || '"';

      END IF;



      IF ( cs.column11 IS NOT NULL ) THEN

        v_query := v_query || ', column11 "' || cs.column11 || '"';

      END IF;



      IF ( cs.column12 IS NOT NULL ) THEN

        v_query := v_query || ', column12 "' || cs.column12 || '"';

      END IF;



      IF ( cs.column13 IS NOT NULL ) THEN

        v_query := v_query || ', column13 "' || cs.column13 || '"';

      END IF;



      IF ( cs.column14 IS NOT NULL ) THEN

        v_query := v_query || ', column14 "' || cs.column14 || '"';

      END IF;



      IF ( cs.column15 IS NOT NULL ) THEN

        v_query := v_query || ', column15 "' || cs.column15 || '"';

      END IF;



      IF ( cs.column16 IS NOT NULL ) THEN

        v_query := v_query || ', column16 "' || cs.column16 || '"';

      END IF;



      IF ( cs.column17 IS NOT NULL ) THEN

        v_query := v_query || ', column17 "' || cs.column17 || '"';

      END IF;



      IF ( cs.column18 IS NOT NULL ) THEN

        v_query := v_query || ', column18 "' || cs.column18 || '"';

      END IF;



      IF ( cs.column19 IS NOT NULL ) THEN

        v_query := v_query || ', column19 "' || cs.column19 || '"';

      END IF;



      IF ( cs.column20 IS NOT NULL ) THEN

        v_query := v_query || ', column20 "' || cs.column20 || '"';

      END IF;



      v_query := v_query || ' FROM AJCL_BC_OUTPUTS_XLSX' ||

                           ' WHERE ifc = ''' || gv_bc_ifc || '''' ||

                             ' AND request_id = ' || gv_request_id ||

                             ' AND section = ''' || cs.section || '''' ||

                             ' AND seq != ' || cs.seq || -- No se incluye la fila que contiene los nombres de las columnas

                             ' ORDER BY seq';



      OPEN c_cursor FOR v_query;



      ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => cs.section,

                                         p_sheet => v_sheet,

                                         p_cursor => c_cursor );



    END LOOP;



    as_xlsx.save ( gv_directory_output, gv_output_filename || '.' || LOWER(gv_file_format) );



    p_status := 'S';



    print_log( 'ajcl_bc_ies_gl_pkg.final_output_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_ies_gl_pkg.final_output_xlsx_p (!). Error: ' || SQLERRM );



  END final_output_xlsx_p;



  PROCEDURE final_report_xlsx_p ( p_status   OUT   VARCHAR2 ) IS



    c_cursor   SYS_REFCURSOR;



  BEGIN



    print_log( 'ajcl_bc_ies_gl_pkg.final_report_xlsx_p (+)' );



    gv_directory_report := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_REPORT' );



    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc || ' Report',

                                                p_request_id => gv_request_id,

                                                p_bc_environment => gv_bc_environment,

                                                p_jenkins_build_number => gv_jenkins_build_number,

                                                p_param_1_title => ' ',

                                                p_param_1_value => ' ',

                                                p_param_2_title => 'GL_DATE',

                                                p_param_2_value => TO_CHAR(gv_gl_date,'YYYY-MM-DD'),

                                                p_param_3_title => 'IF_ERRORS_STOP',

                                                p_param_3_value => gv_if_errors_stop );



    -- Processed Journals

        OPEN c_cursor FOR

      SELECT abagl.documentno document_no,

             abagl.postingdate posting_date,

             abagl.userjesourcename user_je_source_name,

             abagl.userjecategoryname user_je_category_name,

             abagl.currencycode currency_code,

             UPPER(abagl.status) status,

             SUM(NVL(abagl.entereddr,0)) entered_dr,

             SUM(NVL(abagl.enteredcr,0)) entered_cr,

             COUNT(1) quantity

        FROM ajcl_bc_ies_gl_lines abagl

       WHERE abagl.request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND UPPER(abagl.status) NOT IN ('ERROR','REJECTED')

    GROUP BY abagl.documentno,

             abagl.postingdate,

             abagl.userjesourcename,

             abagl.userjecategoryname,

             abagl.currencycode,

             abagl.status

    ORDER BY abagl.documentno;



    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Processed Journals',

                                       p_sheet => 2,

                                       p_cursor => c_cursor );



    -- Solapa Error Journals

        OPEN c_cursor FOR

      SELECT abagl.documentno document_no,

             abagl.postingdate posting_date,

             abagl.userjesourcename user_je_source_name,

             abagl.userjecategoryname user_je_category_name,

             abagl.currencycode currency_code,

             UPPER(abagl.status) status,

             abagl.error_message,

             abagl.json_number,

             abagl.oraclelineno line_num,

             company, 

             account,

             department,

             destination,

             office,

             origin,

             division,

             NVL(abagl.entereddr,0) entered_dr,

             NVL(abagl.enteredcr,0) entered_cr

        FROM ajcl_bc_ies_gl_lines abagl

       WHERE abagl.request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND UPPER(abagl.status) IN ('ERROR','NEW')

    ORDER BY abagl.documentno,

             abagl.postingdate,

             abagl.json_number,

             abagl.oraclelineno;



    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Error Journals',

                                       p_sheet => 3,

                                       p_cursor => c_cursor );



    as_xlsx.save ( gv_directory_report, gv_report_filename || '.' || LOWER(gv_file_format) );



    p_status := 'S';



    print_log( 'ajcl_bc_ies_gl_pkg.final_report_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_ies_gl_pkg.final_report_xlsx_p (!). Error: ' || SQLERRM );



  END final_report_xlsx_p;



  PROCEDURE gen_report_and_send_mail_p ( p_phase    OUT   VARCHAR2, 

                                         p_status   OUT   VARCHAR2 ) IS



    e_exception   EXCEPTION;



  BEGIN



    print_log( 'ajcl_bc_ies_gl_pkg.gen_report_and_send_mail_p (+)' );



    -- INSERT REPORT IN TABLE AJCL_BC_REPORTS --------------------------------------------------------------------------------

    IF ( gv_file_format = 'CSV' ) THEN



      final_report_csv_p ( p_status => p_status );     



      IF ( p_status != 'S' ) THEN



        p_phase := 'final_report_csv_p';

        RAISE e_exception;



      END IF;  



      -- CREATE CSV FROM TABLE AJCL_BC_REPORTS --------------------------------------------------------------------------------

      ajcl_bc_utils_pkg.create_csv_p ( p_ifc => gv_bc_ifc,

                                       p_request_id => gv_request_id,

                                       p_log_seq => gv_log_seq,

                                       p_type => 'REPORT',

                                       p_filename => gv_report_filename,

                                       p_status => p_status );



      IF ( p_status != 'S' ) THEN



        p_phase := 'create_csv_p | REPORT';

        RAISE e_exception;



      END IF;



    ELSIF ( gv_file_format = 'XLSX' ) THEN 



      -- No inserta en tabla, genera el xlsx directamente en el filesystem

      final_report_xlsx_p ( p_status => p_status );     



      IF ( p_status != 'S' ) THEN



        p_phase := 'final_report_xlsx_p';

        RAISE e_exception;



      END IF;  



    END IF;



    -- MAIL REPORT -----------------------------------------------------------------------------------------------------------

    BEGIN



      ajcl_bc_utils_pkg.send_mail_with_attach ( p_to_mail => gv_email,

                                                p_subject => gv_bc_ifc || ' Report - ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                                p_body => gv_bc_ifc || ' Report.',

                                                p_type => 'REPORT',

                                                p_filename => gv_report_filename, 

                                                p_file_format => gv_file_format,

                                                p_attach_filename => gv_bc_ifc || ' Report ' || TO_CHAR(SYSDATE,'MMDDYYYY HH24MISS') || ' ' || gv_bc_environment || '.' || LOWER(gv_file_format) );                                                 



    EXCEPTION

      WHEN OTHERS THEN

        print_log ( 'SMTP NOT WORKING.' );



    END;



    print_log( 'ajcl_bc_ies_gl_pkg.gen_report_and_send_mail_p (-)' );



  EXCEPTION 

    WHEN OTHERS THEN

      print_log( 'ajcl_bc_ies_gl_pkg.gen_report_and_send_mail_p (!)' );



  END gen_report_and_send_mail_p;



  PROCEDURE main_bc_p ( p_status   OUT   VARCHAR2 ) IS



    v_status                VARCHAR2(1);

    v_error_message         VARCHAR2(2000);

    v_journals_count        NUMBER;

    v_pending_rows          NUMBER := -1;



    v_phase                 VARCHAR2(100);



    e_error                 EXCEPTION;

    e_call_ws               EXCEPTION;

    e_exception             EXCEPTION;



  BEGIN



    print_log( 'ajcl_bc_ies_gl_pkg.main_bc_p (+)' );



    -- AJC AP IES Populate AP and GL Interface Tables

    insert_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'insert_p';

      RAISE e_error;



    END IF;



    worksheets_to_bc_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'worksheets_to_bc_p';

      RAISE e_error;



    END IF;



    generate_jsons ( p_journals_count => v_journals_count,

                     p_error_message => v_error_message,

                     p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'generate_jsons';

      RAISE e_exception;



    END IF;



    print_log ( 'journals count: ' || v_journals_count );



    IF NVL(v_journals_count,0) > 0 THEN



      -- dbms_lock - Lock ------------------------------------------------------------------------------------------------------

      print_log ( 'Trying to lock ' || gv_gl_process_name || '.' );

      print_log ( 'If it stops at this point it is because it is blocked by another integration. It will continue once the other integration releases.' );



      ajc_bc_dbms_lock_pkg.lock_p ( p_process_name => gv_gl_process_name,

                                    p_id_lock => gv_gl_id_lock,

                                    p_request_status => gv_gl_request_status ); 



      IF ( gv_gl_request_status != 'success' ) THEN



        RAISE ge_gl_lock;



      END IF;

      -- dbms_lock - Lock ------------------------------------------------------------------------------------------------------



        call_ws ( p_error_message => v_error_message,

                  p_status => v_status );



        IF ( v_status != 'S' ) THEN



          v_phase := 'call_ws';

          RAISE e_call_ws;



        END IF;



        call_job ( p_error_message => v_error_message,

                   p_status => v_status );



        IF ( v_status != 'S' ) THEN



          v_phase := 'call_job';

          RAISE e_exception;



        END IF;



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_gl_id_lock,

                                       p_release_status => gv_gl_release_status );



      IF ( gv_gl_release_status != 'success' ) THEN



        RAISE ge_gl_release;



      END IF;                                     

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------



      call_ws_staging_pending ( p_pending_rows => v_pending_rows,

                                p_error_message => v_error_message,

                                p_status => v_status );



      IF ( v_status != 'S' ) THEN



        v_phase := 'call_ws_staging_pending';

        RAISE e_exception;



      END IF;



      call_ws_staging ( p_error_message => v_error_message,

                        p_status => v_status );



      IF ( v_status != 'S' ) THEN



        v_phase := 'call_ws_staging';

        RAISE e_exception;



      END IF;



      validate_ws_data ( p_error_message => v_error_message,

                         p_status => v_status );



      IF ( v_status != 'S' ) THEN



        v_phase := 'validate_ws_data';

        RAISE e_exception;



      END IF;



      gen_report_and_send_mail_p ( p_phase => v_phase, 

                                   p_status => v_status );



      IF ( v_status != 'S' ) THEN



        v_phase := 'gen_report_and_send_mail_p';

        RAISE e_exception;



      END IF;



      -- Se agrega para borrar las lineas de la inbound si hay registros con error

      check_lines_status_p ( p_error_message => v_error_message,

                             p_status => v_status );



      /*

      IF ( v_status != 'S' ) THEN



        v_phase := 'check_lines_status';

        RAISE e_exception;



      END IF;

      */



    ELSE



      print_log('No journals to process.');



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => 'No journals to process.' || CHR(10) || 'Request ID: ' || gv_request_id );



    END IF;



    p_status := 'S';



    print_log( 'ajcl_bc_ies_gl_pkg.main_bc_p (-)' );



  EXCEPTION

    -- dbms_lock ---------------------------------------------------------------------------------------------------------------

    WHEN ge_gl_lock THEN -- Lock & Release

      p_status := 'E';

      print_log ('ajcl_bc_ies_gl_pkg.main_bc_p. Error al intentar hacer el lock del proceso ' || gv_gl_process_name || 

              ' | request_status: ' || gv_gl_request_status);



    WHEN ge_gl_release THEN -- Lock & Release

      p_status := 'E';

      print_log ('ajcl_bc_ies_gl_pkg.main_bc_p. Error al intentar hacer el release del proceso ' || gv_gl_process_name || 

              ' | request_status: ' || gv_gl_release_status);

    -- dbms_lock ---------------------------------------------------------------------------------------------------------------



    WHEN e_error THEN

      p_status := 'E';

      print_log ('phase: ' || v_phase);

      print_log ('error: ' || v_error_message);

      print_log( 'ajcl_bc_ies_gl_pkg.main_bc_p (!)' );



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_gl_id_lock,

                                       p_release_status => gv_gl_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------                                    



    WHEN e_call_ws THEN

      p_status := 'E';

      print_log ('phase: ' || v_phase);

      print_log ('error: ' || v_error_message);



      gen_report_and_send_mail_p ( p_phase => v_phase, 

                                   p_status => v_status );



      print_log( 'ajcl_bc_ies_gl_pkg.main_bc_p (!)' );



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_gl_id_lock,

                                       p_release_status => gv_gl_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------                                   



    WHEN e_exception THEN

      p_status := 'E';

      print_log ('phase: ' || v_phase);

      print_log ('error: ' || v_error_message);



      gen_report_and_send_mail_p ( p_phase => v_phase, 

                                   p_status => v_status );



      print_log( 'ajcl_bc_ies_gl_pkg.main_bc_p (!)' );



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_gl_id_lock,

                                       p_release_status => gv_gl_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------



    WHEN OTHERS THEN

      p_status := 'E';

      print_log (v_phase);

      print_log( 'ajcl_bc_ies_gl_pkg.main_bc_p (!). Error: ' || SQLERRM );



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_gl_id_lock,

                                       p_release_status => gv_gl_release_status );  

      -- dbms_lock - Release --------------------------------------------------------------------------------------------------- 



  END main_bc_p;



  -- Main ----------------------------------------------------------------------------------------------------------------------

  PROCEDURE main_p ( p_bc_environment         IN   VARCHAR2,

                     p_gl_date                IN   VARCHAR2,

                     p_if_errors_stop         IN   VARCHAR2,

                     p_jenkins_build_number   IN   VARCHAR2 ) IS



    v_status                 VARCHAR2(1);

    v_phase                  VARCHAR2(200);



    v_argument1              VARCHAR2(100);

    v_argument2              VARCHAR2(100);

    v_argument3              VARCHAR2(100);



    -- 20250507

    v_support_email          VARCHAR2(200);

    v_gl_not_success         NUMBER;

    -- 20250507



    e_error                  EXCEPTION;

    e_stop_processing        EXCEPTION;

    v_error_msg              VARCHAR2(4000);



    e_parameter_value        EXCEPTION;

    e_bc_setup               EXCEPTION;



  BEGIN



    gv_request_id := ajcl_bc_utils_pkg.get_request_id_f;

    gv_jenkins_build_number := p_jenkins_build_number;



    -- Se inserta el concurrent_job

    ajcl_bc_utils_pkg.ins_jenkins_concurrent_job_p ( p_request_id => gv_request_id,

                                                     p_job_name => gv_bc_ifc,

                                                     p_jenkins_build_number => p_jenkins_build_number,

                                                     p_argument1 => p_bc_environment,

                                                     p_argument2 => p_gl_date,

                                                     p_argument3 => p_if_errors_stop );



    print_log ( 'ajcl_bc_ies_gl_pkg.main_p (+)' );

    print_log ( 'gv_request_id: ' || gv_request_id );

    print_log ( 'gv_jenkins_build_number: ' || gv_jenkins_build_number );



    gv_file_format := ajcl_bc_ws_utils_pkg.get_parameter_f ( 'FILE_FORMAT' );

    print_log( 'FILE_FORMAT: ' || gv_file_format ); 



    gv_email := ajcl_bc_utils_pkg.get_emails_f ( 'IES JOURNALS' );

    print_log( 'gv_email: ' || gv_email );



    gv_gl_process_name := ajcl_bc_ws_utils_pkg.get_lock_process_name_f ( p_integration => 'JOURNALS' );

    print_log( 'gv_gl_process_name: ' || gv_gl_process_name );



    -- Se valida que en BC el setup sea el correcto

    print_log( 'Checking if General Ledger Setup | Sales and Receivables Setup are ok in BC..' );



    ajcl_bc_get_entities_pkg.check_logistics_setup_p ( p_bc_environment => p_bc_environment,

                                                       p_status => v_status );



    IF ( v_status != 'S' ) THEN  



      RAISE e_bc_setup;



    END IF;



    -- Validacion parametro p_bc_environment -----------------------------------------------------------------------------------

    IF ( ajcl_bc_utils_pkg.is_bc_environment_valid_f ( p_bc_environment ) = 'N' ) THEN



      v_error_msg := 'Invalid value (' || p_bc_environment || ') for parameter BC_ENVIRONMENT.';

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

          v_error_msg := 'Error: ' || SUBSTR(SQLERRM,INSTR(SQLERRM,':') + 2) || ' (' || p_gl_date || ')';

          RAISE e_parameter_value;



      END;



    END IF;



    print_log ( 'gv_gl_date: ' || gv_gl_date );



    gv_if_errors_stop := p_if_errors_stop;

    print_log ( 'gv_if_errors_stop: ' || gv_if_errors_stop );



    print_log ( 'gv_data_file_name: ' || gv_data_file_name );

    print_log ( 'gv_journal_source: ' || gv_journal_source );

    print_log ( 'gv_journal_category: ' || gv_journal_category );



    -- Se obtienen los parametros de la company 

    print_log ( 'gv_bc_company_name: ' || gv_bc_company_name );



    gv_org_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                              p_column => 'ORG_ID' );



    print_log ( 'gv_org_id: ' || gv_org_id );



    gv_set_of_books_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                       p_column => 'SET_OF_BOOKS_ID' );



    print_log ( 'gv_set_of_books_id: ' || gv_set_of_books_id );



    gv_bc_company_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                     p_column => 'BC_COMPANY_ID' );



    print_log ( 'gv_bc_company_id: ' || gv_bc_company_id );



    ajcl_bc_utils_pkg.initialize_p ( p_org_id => gv_org_id );

    print_log ( 'ajcl_bc_utils_pkg.initialize_p' );



    ajcl_bc_get_entities_pkg.get_ies_charge_types_p ( p_bc_environment => gv_bc_environment,

                                                      p_bc_ifc => gv_bc_ifc,

                                                      p_request_id => gv_request_id,

                                                      p_log_seq => gv_log_seq,

                                                      p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'ajcl_bc_get_entities_pkg.get_ies_charge_types_p';

      RAISE e_error;



    END IF;



    ajcl_bc_get_entities_pkg.get_ies_items_p ( p_bc_environment => gv_bc_environment,

                                               p_bc_ifc => gv_bc_ifc,

                                               p_request_id => gv_request_id,

                                               p_log_seq => gv_log_seq,

                                               p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'ajcl_bc_get_entities_pkg.get_ies_items_p';

      RAISE e_error;



    END IF;



    ajcl_bc_get_entities_pkg.get_ies_country_codes_p ( p_bc_environment => gv_bc_environment,

                                                       p_bc_ifc => gv_bc_ifc,

                                                       p_request_id => gv_request_id,

                                                       p_log_seq => gv_log_seq,

                                                       p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'ajcl_bc_get_entities_pkg.get_ies_country_codes_p';

      RAISE e_error;



    END IF;



    IF ( ajcl_bc_utils_pkg.get_db_name_f IN ('FINUPG5','PROD') ) THEN



      gv_ftp_loader := 'Y'; -- FTP, LOADER



    ELSIF ( ajcl_bc_utils_pkg.get_db_name_f IN ('FINUPG6') ) THEN



      gv_ftp_loader := 'N'; -- TRIGGER



    END IF;



    print_log ( 'gv_ftp_loader: ' || gv_ftp_loader );



    -- AJC Ftp IES AP File -----------------------------------------------------------------------------------------------------

    /* 20241211

    -- Se reemplaza con un build step en Jenkins

    IF ( gv_ftp_loader = 'Y' ) THEN 



      print_log ( 'Run job AJCL_BC_FTP_IES_AP_FILE' );



      -- 20240923 v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJCL_BC_FTP_IES_AP_FILE';

      v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_BC_IES_GL_FTP' );

      print_log ( 'v_argument1: ' || v_argument1 );



      ajc_bc_scheduler_pkg.create_run_wait_job_p ( p_job_name => 'AJCL_BC_FTP_IES_AP_FILE',

                                                   p_comments => 'AJC Ftp IES AP File',

                                                   p_number_of_arguments => 1,

                                                   p_argument1 => v_argument1,

                                                   --

                                                   p_bc_ifc => gv_bc_ifc,

                                                   p_request_id => gv_request_id,

                                                   p_log_seq => gv_log_seq,

                                                   --

                                                   p_status => v_status,

                                                   p_error_msg => v_error_msg );



      IF ( v_status != 'S' ) THEN



        v_phase := 'AJC Ftp IES AP File';

        print_log ( v_error_msg );

        RAISE e_error;



      END IF; 



      -- AJC Archive Ftped IES AP Files On IES Server ----------------------------------------------------------------------------

      print_log ( 'Run job AJCL_BC_ARCH_IES_AP_FILE' );

      -- 20240923 v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJCL_BC_ARCH_IES_AP_FILE';

      v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_BC_IES_GL_ARCHIVE' );

      print_log ( 'v_argument1: ' || v_argument1 );



      ajc_bc_scheduler_pkg.create_run_wait_job_p ( p_job_name => 'AJCL_BC_ARCH_IES_AP_FILE',

                                                   p_comments => 'AJC Archive Ftped IES AP Files On IES Server',

                                                   p_number_of_arguments => 1,

                                                   p_argument1 => v_argument1,

                                                   --

                                                   p_bc_ifc => gv_bc_ifc,

                                                   p_request_id => gv_request_id,

                                                   p_log_seq => gv_log_seq,

                                                   --

                                                   p_status => v_status,

                                                   p_error_msg => v_error_msg );



      IF ( v_status != 'S' ) THEN



        v_phase := 'AJC Archive Ftped IES AP Files On IES Server';

        RAISE e_error;



      END IF; 



      -- AJC Load IES AP File Into Custom Table ----------------------------------------------------------------------------------

      print_log ( 'Run job AJC_LOAD_IES_AP_FILE' );



      -- 20240923 v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJCL_EXECUTE_CTL.sh';

      v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_EXECUTE_CTL' );

      print_log ( 'v_argument1: ' || v_argument1 );



      -- 20240923 v_argument2 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJC_LOAD_IES_AP_FILE';

      v_argument2 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_BC_IES_GL_LOADER' );

      print_log ( 'v_argument2: ' || v_argument2 );



      v_argument3 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'APPLTMP' ) || gv_data_file_name; -- 'AJC_IES_AP_FILE.xml';

      print_log ( 'v_argument3: ' || v_argument3 );



      ajc_bc_scheduler_pkg.create_run_wait_job_p ( p_job_name => 'AJC_LOAD_IES_AP_FILE',

                                                   p_comments => 'AJC Load IES AP File Into Custom Table',

                                                   p_number_of_arguments => 3,

                                                   p_argument1 => v_argument1,

                                                   p_argument2 => v_argument2,

                                                   p_argument3 => v_argument3,

                                                   --

                                                   p_bc_ifc => gv_bc_ifc,

                                                   p_request_id => gv_request_id,

                                                   p_log_seq => gv_log_seq,

                                                   --

                                                   p_status => v_status,

                                                   p_error_msg => v_error_msg );



      IF ( v_status != 'S' ) THEN



        v_phase := 'AJC Load IES AP File Into Custom Table';

        RAISE e_error;



      END IF;



      -- 20241210

      -- DBMS_LOCK.SLEEP(10);

      DBMS_LOCK.SLEEP(30);

      COMMIT;

      -- 20241210



    END IF; -- gv_ftp_loader

    -- 20241211

    */



    -- AJC Populate IES AP Inbound Data Table ----------------------------------------------------------------------------------

    populate_table_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'populate_table_p';

      RAISE e_error;



    END IF;



    -- AJC Rename IES AP File --------------------------------------------------------------------------------------------------

    /* 20241211

    -- Se reemplaza con un build step en Jenkins

    IF ( gv_ftp_loader = 'Y' ) THEN



      print_log ( 'Run job AJCL_BC_RENAME_IES_AP_FILE' );

      -- 20240923 v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJCL_BC_RENAME_IES_AP_FILE';

      v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_BC_IES_GL_RENAME' );

      print_log ( 'v_argument1: ' || v_argument1 );



      ajc_bc_scheduler_pkg.create_run_wait_job_p ( p_job_name => 'AJCL_BC_RENAME_IES_AP_FILE',

                                                   p_comments => 'AJC Rename IES AP File',

                                                   p_number_of_arguments => 1,

                                                   p_argument1 => v_argument1,

                                                   --

                                                   p_bc_ifc => gv_bc_ifc,

                                                   p_request_id => gv_request_id,

                                                   p_log_seq => gv_log_seq,

                                                   --

                                                   p_status => v_status,

                                                   p_error_msg => v_error_msg );



      IF ( v_status != 'S' ) THEN



        v_phase := 'AJC Rename IES AP File';

        RAISE e_error;



      END IF;



    END IF; -- gv_ftp_loader

    -- 20241211

    */



    -- AJC AP IES Processing Control Report ------------------------------------------------------------------------------------

    control_report_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'control_report_p';

      RAISE e_error;



    END IF;



    -- AJC AP IES Data Listing -------------------------------------------------------------------------------------------------

    data_list_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'data_list_p';

      RAISE e_error;



    END IF;



    -- AJC AP IES Validate and Preprocessing -----------------------------------------------------------------------------------

    validate_preprocess_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'validate_preprocess_p';

      RAISE e_error;



    END IF;



    -- CREATE OUTPUT -----------------------------------------------------------------------------------------------------------

    IF ( gv_file_format = 'CSV' ) THEN



      ajcl_bc_utils_pkg.create_csv_p ( p_ifc => gv_bc_ifc,

                                       p_request_id => gv_request_id,

                                       p_log_seq => gv_log_seq,

                                       p_type => 'OUTPUT',

                                       p_filename => gv_output_filename,

                                       p_status => v_status );



      IF ( v_status != 'S' ) THEN



        v_phase := 'create_csv_p | OUTPUT';

        RAISE e_error;



      END IF;



    ELSIF ( gv_file_format = 'XLSX' ) THEN 



      final_output_xlsx_p ( p_status => v_status );



      IF ( v_status != 'S' ) THEN



        v_phase := 'final_output_xlsx_p';

        RAISE e_error;



      END IF;



    END IF;



    -- MAIL OUTPUT -----------------------------------------------------------------------------------------------------------

    BEGIN



      ajcl_bc_utils_pkg.send_mail_with_attach ( p_to_mail => gv_email,

                                                p_subject => gv_bc_ifc || ' Output - ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',                                               

                                                p_body => gv_bc_ifc || ' Output.',

                                                p_type => 'OUTPUT',

                                                p_filename => gv_output_filename, 

                                                p_file_format => gv_file_format,

                                                p_attach_filename => gv_bc_ifc || ' Output ' || TO_CHAR(SYSDATE,'MMDDYYYY HH24MISS') || ' ' || gv_bc_environment || '.' || LOWER(gv_file_format) ); 



    EXCEPTION

      WHEN OTHERS THEN

        print_log ( 'SMTP NOT WORKING.' );



    END;



    -- AJC AP IES Stop Processing on Validate Errors ---------------------------------------------------------------------------

    stop_processing_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'stop_processing_p';

      RAISE e_stop_processing;



    END IF;



    -- BC ----------------------------------------------------------------------------------------------------------------------



    -- 20251106 REINTENTO

    gv_retry_in_seconds := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'POST_RETRY_IN_SECONDS' );

    print_log ( 'POST_RETRY_IN_SECONDS: ' || gv_retry_in_seconds );    

    -- 20251106 REINTENTO



    main_bc_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'main_bc_p';

      RAISE e_error;



    END IF;



    IF ( gv_ftp_loader = 'N' ) THEN



      DELETE ajc_ies_ap_file;

      COMMIT;



    END IF;



    -- 20250507

    -- Se agrega envio de mail para soporte, para informar que no se pudo importar todo en la ejecucion 

    BEGIN



      v_support_email := ajcl_bc_utils_pkg.get_emails_f ( 'SUPPORT' );



      -- GL ------------------------------------------------------------------------

      SELECT COUNT(1)

        INTO v_gl_not_success

        FROM ajcl_bc_ies_gl_lines

       WHERE request_id = gv_request_id

         AND UPPER(status) != 'SUCCESS';



      print_log ('v_gl_not_success: ' || v_gl_not_success);  



      IF ( v_gl_not_success > 0 ) THEN



        ajcl_bc_utils_pkg.send_email_p ( p_to => v_support_email,

                                         p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - WARNING - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => 'Some journals could not be imported. Please review the integration report.' || CHR(10) || 'Request ID: ' || gv_request_id );



      END IF;



    EXCEPTION

      WHEN OTHERS THEN

        NULL;



    END;

    -- 20250507



    -- Se actualiza el concurrent_job

    ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'S' );



    print_log('ajcl_bc_ies_gl_pkg.main_p (-)');



  EXCEPTION

    WHEN e_bc_setup THEN

      print_log('ajcl_bc_ies_gl_pkg.main_p (!). BC setup error. please contact support.');



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );     



    WHEN e_parameter_value THEN

      print_log('ajcl_bc_ies_gl_pkg.main_p (!)');

      print_log(v_error_msg);



      BEGIN



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                         p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',                                         

                                         p_message => v_error_msg || CHR(10) || 'Request ID: ' || gv_request_id );



      EXCEPTION

        WHEN OTHERS THEN

          print_log ( 'SMTP NOT WORKING.' );



      END;                                           



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );                                       



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );                                       



    WHEN e_error THEN

      print_log('ajcl_bc_ies_gl_pkg.main_p (!)');

      print_log('phase: ' || v_phase);



      BEGIN



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                         p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',                                     

                                         p_message => 'Error at phase ' || v_phase || CHR(10) || 'Request ID: ' || gv_request_id );



      EXCEPTION

        WHEN OTHERS THEN

          print_log ( 'SMTP NOT WORKING.' );



      END;  



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



      RAISE_APPLICATION_ERROR(-20000,'Error at phase: ' || v_phase );    



    WHEN e_stop_processing THEN

      print_log('ajcl_bc_ies_gl_pkg.main_p (!)');

      print_log('phase: ' || v_phase);



      BEGIN



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                         p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',                                     

                                         p_message => 'The process could not be executed due to errors. Please review the output, correct any errors and rerun the process.' || CHR(10) || 'Request ID: ' || gv_request_id );



      EXCEPTION

        WHEN OTHERS THEN

          print_log ( 'SMTP NOT WORKING.' );



      END;  



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



      RAISE_APPLICATION_ERROR(-20000,'Error at phase: ' || v_phase );   



    WHEN OTHERS THEN

      print_log('ajcl_bc_ies_gl_pkg.main_p (!). General Error: ' || SQLERRM);      



      BEGIN



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                         p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => 'General Error: ' || SQLERRM || CHR(10) || 'Request ID: ' || gv_request_id );



      EXCEPTION

        WHEN OTHERS THEN

          print_log ( 'SMTP NOT WORKING.' );



      END;                                           



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



      RAISE_APPLICATION_ERROR(-20000,'General Error: ' || SQLERRM );                                        



  END main_p;



END ajcl_bc_ies_gl_pkg;
