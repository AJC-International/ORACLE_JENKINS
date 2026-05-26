CREATE OR REPLACE PACKAGE BODY ajcl_bc_ies_ar_pkg IS

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

                           WHERE TRIM(name) = TRIM(a.terms) )

    ORDER BY 1;



      CURSOR c_orgn_dest_excep IS

      SELECT DISTINCT origin_country country_code,

             'Country not found.' error_message

        FROM ajc_ar_ies_inbound_data a

       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

         AND a.origin_country IS NOT NULL

         AND NOT EXISTS ( SELECT 'x'

                          FROM ajcl_bc_ies_country_codes x

                         WHERE bc_environment = gv_bc_environment

                           AND x.country_code = TRIM(a.origin_country) )

       UNION

      SELECT DISTINCT destination_country country_code,

             'Country not found.' error_message

        FROM ajc_ar_ies_inbound_data a

       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

         AND a.destination_country IS NOT NULL

         AND NOT EXISTS ( SELECT 'x'

                          FROM ajcl_bc_ies_country_codes x

                         WHERE bc_environment = gv_bc_environment

                           AND x.country_code = TRIM(a.destination_country) )

       UNION

      SELECT DISTINCT origin_country country_code,

             'Origin and/or destination not populated for this country' error_message

        FROM ajc_ar_ies_inbound_data a

       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

         AND a.origin_country IS NOT NULL

         AND EXISTS ( SELECT 'x'

                        FROM ajcl_bc_ies_country_codes x

                       WHERE bc_environment = gv_bc_environment

                         AND x.country_code = TRIM(a.origin_country)

                         AND ( x.origin IS NULL OR x.destination IS NULL ) )

       UNION

      SELECT DISTINCT destination_country country_code,

             'Origin and/or destination not populated for this country' error_message

        FROM ajc_ar_ies_inbound_data a

       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

         AND a.destination_country IS NOT NULL

         AND EXISTS ( SELECT 'x'

                        FROM ajcl_bc_ies_country_codes x

                       WHERE bc_environment = gv_bc_environment

                         AND x.country_code = TRIM(a.destination_country)

                         AND ( x.origin IS NULL OR x.destination IS NULL ) )

    ORDER BY 1;



    CURSOR c_cm_missing_warning IS

    SELECT fin_party,

           invoice_number,

           reference_value_1,

           inv_amt,

           'Manual application to invoice required.' warn_message

      FROM ( SELECT financial_party fin_party,

                    invoice_number,

                    reference_value_1,

                    SUM(charge_amount) inv_amt

               FROM ajc_ar_ies_inbound_data a

              WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

           GROUP BY financial_party,

                    invoice_number,

                    reference_value_1

             HAVING SUM(charge_amount) < 0 ) x

     -- Nuevo

     WHERE -- BC

           NOT EXISTS ( SELECT 'x'

                          FROM ajcl_bc_posted_sd_headers sdh,

                               hz_cust_accounts_all hca

                         WHERE sdh.bc_environment = gv_bc_environment

                           AND sdh.iesNumber = NVL(x.reference_value_1,x.invoice_number) -- IES Number

                           AND sdh.billToCustomerNo = hca.account_number

                           AND sdh.class != 'CM'

                           AND hca.attribute6 = x.fin_party

                           AND sdh.amount = sdh.remainingAmount

                           AND ABS(x.inv_amt) = ( SELECT SUM(amount)

                                                    FROM ajcl_bc_posted_sd_lines sdl

                                                   WHERE sdl.bc_environment = gv_bc_environment

                                                     AND sdh.billToCustomerNo = sdl.billToCustomerNo

                                                     AND sdh.transactionno = sdl.transactionno ))

           -- Oracle

       AND NOT EXISTS ( SELECT 'x'

                          FROM ra_customer_trx_all rct, 

                               hz_cust_accounts_all hca, 

                               ra_cust_trx_types_all rctt, 

                               ar_payment_schedules_all aps

                         WHERE rct.interface_header_attribute4 = NVL(x.reference_value_1, x.invoice_number) -- IES Number

                           AND rct.bill_to_customer_id = hca.cust_account_id

                           AND rct.org_id = gv_org_id

                           AND rctt.cust_trx_type_id = rct.cust_trx_type_id

                           AND rctt.type != 'CM'

                           AND hca.attribute6 = x.fin_party

                           AND aps.customer_trx_id = rct.customer_trx_id

                           AND aps.amount_due_original = aps.amount_due_remaining

                           AND ABS(x.inv_amt) = ( SELECT SUM(extended_amount)

                                                    FROM ra_customer_trx_lines_all

                                                   WHERE customer_trx_id = rct.customer_trx_id ) );



      CURSOR c_inv_lines_missing_orgn_dest IS

      SELECT substr(financial_party,1,50) fin_party,

             substr(invoice_number,1,20) invoice_number,

             substr(charge_type_code,1,20) charge_type_code,

             substr(business_line,1,5) business_line,

             to_number(charge_amount) charge_amount,

             'Line missing origin and/or destination.' warn_message,

             to_char(sysdate,'DD-MON-YYYY HH24:MI:SS') report_date

        FROM ajc_ar_ies_inbound_data a

       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

         AND ( a.origin_country IS NULL OR a.destination_country IS NULL )

    ORDER BY 1,2,3,4;



    v_count   NUMBER;



  BEGIN



    print_log('ajcl_bc_ies_ar_pkg.validate_preprocess_p (+)');



    v_count := 0;



    -- Se verifica si hay registros a informar

    FOR cmce IN c_missing_customer_excep LOOP



      v_count := v_count + 1;



    END LOOP;



    IF ( v_count != 0 ) THEN



      IF ( gv_file_format = 'CSV' ) THEN



        print_output ( ' ' );

        print_output ( 'Date|' || SYSDATE );

        print_output ( 'AJC AR IES Txn Processing Errors' );



        print_output ( ' ' );

        print_output ( 'AJC AR IES Missing Customer Exceptions' );



        print_output ( ' ' );

        print_output ( 'Financial Party' || '|' ||

                       'Invoice Number' || '|' ||

                       'Error Message' );



        FOR cmce IN c_missing_customer_excep LOOP



          print_output ( cmce.financial_party || '|' ||

                         cmce.invoice_number || '|' ||

                         cmce.error_message );      



        END LOOP;



      ELSIF ( gv_file_format = 'XLSX' ) THEN 



        -- Column Names

        print_output_xlsx ( p_section => 'Missing Customer Exceptions',

                            p_column1 => 'Financial Party',

                            p_column2 => 'Invoice Number',

                            p_column3 => 'Invoice Number' );



        -- NEW

        FOR cmce IN c_missing_customer_excep LOOP



          print_output_xlsx ( p_section => 'Missing Customer Exceptions',

                              p_column1 => cmce.financial_party,

                              p_column2 => cmce.invoice_number,

                              p_column3 => cmce.error_message );



        END LOOP;



      END IF;



    END IF;



    v_count := 0;



    FOR cmid IN c_missing_item_definition LOOP



      v_count := v_count + 1;



    END LOOP;



    IF ( v_count != 0 ) THEN



      IF ( gv_file_format = 'CSV' ) THEN



        print_output ( ' ' );

        print_output ( 'AJC AR IES Missing Item Definitions' );



        print_output ( ' ' );

        print_output ( 'Item' || '|' ||

                       'Error Message' );



        FOR cmid IN c_missing_item_definition LOOP



          print_output ( cmid.item || '|' ||

                         cmid.error_message );



        END LOOP;



      ELSIF ( gv_file_format = 'XLSX' ) THEN 



        -- Column Names

        print_output_xlsx ( p_section => 'Missing Item Definitions',

                            p_column1 => 'Item',

                            p_column2 => 'Error Message' );



        -- NEW

        FOR cmid IN c_missing_item_definition LOOP



          print_output_xlsx ( p_section => 'Missing Item Definitions',

                              p_column1 => cmid.item,

                              p_column2 => cmid.error_message );



        END LOOP;



      END IF;



    END IF;



    v_count := 0;



    FOR code IN c_orgn_dest_excep LOOP



      v_count := v_count + 1;



    END LOOP;



    IF ( v_count != 0 ) THEN



      IF ( gv_file_format = 'CSV' ) THEN



        print_output ( ' ' );

        print_output ( 'AJC AR IES Missing Payment Terms' );



        print_output ( ' ' );

        print_output ( 'Term' || '|' ||

                       'Error Message' );



        FOR cmpt IN c_missing_payment_terms LOOP



          print_output ( cmpt.terms || '|' ||

                         cmpt.error_message );



        END LOOP;



      ELSIF ( gv_file_format = 'XLSX' ) THEN 



        -- Column Names

        print_output_xlsx ( p_section => 'Missing Payment Terms',

                            p_column1 => 'Term',

                            p_column2 => 'Error Message' );



        -- NEW

        FOR cmpt IN c_missing_payment_terms LOOP



          print_output_xlsx ( p_section => 'Missing Payment Terms',

                              p_column1 => cmpt.terms,

                              p_column2 => cmpt.error_message );



        END LOOP;



      END IF;



    END IF;



    v_count := 0;



    FOR code IN c_orgn_dest_excep LOOP



      v_count := v_count + 1;



    END LOOP;



    IF ( v_count != 0 ) THEN



      IF ( gv_file_format = 'CSV' ) THEN



        print_output ( ' ' );

        print_output ( 'AJC AR IES Origin/Destination Exceptions' );



        print_output ( ' ' );

        print_output ( 'Country Code' || '|' ||

                       'Error Message' );



        FOR code IN c_orgn_dest_excep LOOP



          print_output ( code.country_code || '|' ||

                         code.error_message );



        END LOOP;



      ELSIF ( gv_file_format = 'XLSX' ) THEN 



        -- Column Names

        print_output_xlsx ( p_section => 'Origin/Destination Exceptions',

                            p_column1 => 'Country Code',

                            p_column2 => 'Error Message' );



        -- NEW

        FOR code IN c_orgn_dest_excep LOOP



          print_output_xlsx ( p_section => 'Origin/Destination Exceptions',

                              p_column1 => code.country_code,

                              p_column2 => code.error_message );



        END LOOP;



      END IF;



    END IF;



    v_count := 0;



    FOR ccmm IN c_cm_missing_warning LOOP



      v_count := v_count + 1;



    END LOOP;



    IF ( v_count != 0 ) THEN



      IF ( gv_file_format = 'CSV' ) THEN



        print_output ( ' ' );

        print_output ( 'AJC AR IES Credit Memo Mismatch' );



        print_output ( ' ' );

        print_output ( 'Financial Party' || '|' ||

                       'Invoice Number' || '|' ||

                       'Reference Value' || '|' ||

                       'Invoice Amount' || '|' ||

                       'Warning Message' );



        FOR ccmm IN c_cm_missing_warning LOOP



          print_output ( ccmm.fin_party || '|' ||

                         ccmm.invoice_number || '|' ||

                         ccmm.reference_value_1 || '|' ||

                         ccmm.inv_amt || '|' ||

                         ccmm.warn_message );



        END LOOP;



      ELSIF ( gv_file_format = 'XLSX' ) THEN 



        -- Column Names

        print_output_xlsx ( p_section => 'Credit Memo Mismatch',

                            p_column1 => 'Financial Party',

                            p_column2 => 'Invoice Number',

                            p_column3 => 'Reference Value',

                            p_column4 => 'Invoice Amount',

                            p_column5 => 'Warning Message' );



        -- NEW

        FOR ccmm IN c_cm_missing_warning LOOP



          print_output_xlsx ( p_section => 'Credit Memo Mismatch',

                              p_column1 => ccmm.fin_party,

                              p_column2 => ccmm.invoice_number,

                              p_column3 => ccmm.reference_value_1,

                              p_column4 => ccmm.inv_amt,

                              p_column5 => ccmm.warn_message );



        END LOOP;



      END IF;



    END IF;



    v_count := 0;



    FOR cilmod IN c_inv_lines_missing_orgn_dest LOOP



      v_count := v_count + 1;



    END LOOP;



    IF ( v_count != 0 ) THEN



      IF ( gv_file_format = 'CSV' ) THEN



        print_output ( ' ' );

        print_output ( 'AJC AR IES Invoice Lines Missing Origin/Destination Country' );



        print_output ( ' ' );

        print_output ( 'Financial Party' || '|' ||

                       'Invoice Number' || '|' ||

                       'Charge Type' || '|' ||

                       'Business Line' || '|' ||

                       'Charge Amount' || '|' ||

                       'Warning Message' );



        FOR cilmod IN c_inv_lines_missing_orgn_dest LOOP



          print_output ( cilmod.fin_party || '|' ||

                         cilmod.invoice_number || '|' ||

                         cilmod.charge_type_code || '|' ||

                         cilmod.business_line || '|' ||

                         cilmod.charge_amount || '|' ||

                         cilmod.warn_message );



        END LOOP;



      ELSIF ( gv_file_format = 'XLSX' ) THEN 



        -- Column Names

        print_output_xlsx ( p_section => 'Invoice Lines Missing Origin/Destination Country',

                            p_column1 => 'Financial Party',

                            p_column2 => 'Invoice Number',

                            p_column3 => 'Charge Type',

                            p_column4 => 'Business Line',

                            p_column5 => 'Charge Amount',

                            p_column6 => 'Warning Message' );



        -- NEW

        FOR cilmod IN c_inv_lines_missing_orgn_dest LOOP



          print_output_xlsx ( p_section => 'Invoice Lines Missing Origin/Destination Country',

                              p_column1 => cilmod.fin_party,

                              p_column2 => cilmod.invoice_number,

                              p_column3 => cilmod.charge_type_code,

                              p_column4 => cilmod.business_line,

                              p_column5 => cilmod.charge_amount,

                              p_column6 => cilmod.warn_message );



        END LOOP;



      END IF;



    END IF;



    p_status := 'S';



    print_log('ajcl_bc_ies_ar_pkg.validate_preprocess_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_ies_ar_pkg.validate_preprocess_p (!). Error: ' || SQLERRM);



  END validate_preprocess_p;  



  PROCEDURE stop_processing_p ( p_status   OUT   VARCHAR2 ) IS



    v_cust_excp1            NUMBER := 0;

    v_cust_excp2            NUMBER := 0;

    v_cust_excp3            NUMBER := 0;

    v_cust_excp4            NUMBER := 0;

    v_item_excp1            NUMBER := 0;

    v_item_excp2            NUMBER := 0;

    v_item_excp3            NUMBER := 0;

    v_orig_dest_excp1       NUMBER := 0;

    v_orig_dest_excp2       NUMBER := 0;

    v_orig_dest_excp3       NUMBER := 0;

    v_orig_dest_excp4       NUMBER := 0;

    v_orig_dest_excp_count  NUMBER := 0;

    v_cust_excp_count       NUMBER := 0;

    v_item_excp_count       NUMBER := 0;

    v_term_excp_count       NUMBER := 0;

    v_sql_stmt_id           NUMBER := 0;

    stop_processing         EXCEPTION;



  BEGIN



    print_log('ajcl_bc_ies_ar_pkg.stop_processing_p (+)');



    v_sql_stmt_id := 10;



    SELECT COUNT(1)

      INTO v_cust_excp1

      FROM ajc_ar_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND NOT EXISTS ( SELECT 'x'

                          FROM hz_cust_accounts_all

                         WHERE TRIM(UPPER(attribute6)) = TRIM(UPPER(a.financial_party) ) );



    v_sql_stmt_id := 20;



    SELECT COUNT(1)

      INTO v_cust_excp2

      FROM ajc_ar_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND EXISTS ( SELECT 'x'

                      FROM hz_cust_accounts_all

                     WHERE TRIM(UPPER(attribute6)) = TRIM(UPPER(a.financial_party)))

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

                           AND hcsu.site_use_code = 'BILL_TO');



    v_sql_stmt_id := 30;



   SELECT COUNT(1)

     INTO v_cust_excp3

     FROM ajc_ar_ies_inbound_data a

    WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

      AND EXISTS ( SELECT 'x'

                     FROM hz_cust_accounts_all

                    WHERE TRIM(UPPER(attribute6)) = TRIM(UPPER(a.financial_party)))

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

                          AND hcsu.site_use_code = 'SHIP_TO' );



    v_sql_stmt_id := 40;



    SELECT COUNT(1)

      INTO v_cust_excp4

      FROM ajc_ar_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND 1 < ( SELECT NVL(COUNT(1),0)

                   FROM hz_cust_accounts_all

                  WHERE TRIM(UPPER(attribute6)) = TRIM(UPPER(a.financial_party)));



    v_sql_stmt_id := 50;



    SELECT COUNT(1)

      INTO v_item_excp1

      FROM ajc_ar_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

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



    v_sql_stmt_id := 60;



    SELECT COUNT(1)

      INTO v_item_excp3

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

                       AND NVL(b.inactive_date, SYSDATE + 1) <= SYSDATE );



    v_sql_stmt_id := 70;



    SELECT COUNT(1)

      INTO v_item_excp2

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

                       AND b.rev_accountno IS NULL );



    v_sql_stmt_id := 80;



    SELECT COUNT(1)

      INTO v_orig_dest_excp1

      FROM ajc_ar_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND a.origin_country IS NOT NULL

       AND NOT EXISTS ( SELECT 'x'

                          FROM ajcl_bc_ies_country_codes x

                         WHERE bc_environment = gv_bc_environment

                           AND x.country_code = TRIM(a.origin_country) );



    v_sql_stmt_id := 90;



    SELECT COUNT(1)

      INTO v_orig_dest_excp2

      FROM ajc_ar_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND a.destination_country IS NOT NULL

       AND NOT EXISTS ( SELECT 'x'

                          FROM ajcl_bc_ies_country_codes x

                         WHERE bc_environment = gv_bc_environment

                           AND x.country_code = TRIM(a.destination_country) );



    v_sql_stmt_id := 100;



    SELECT COUNT(1)

      INTO v_orig_dest_excp3

      FROM ajc_ar_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND a.origin_country IS NOT NULL

       AND EXISTS ( SELECT 'x'

                      FROM ajcl_bc_ies_country_codes x

                     WHERE bc_environment = gv_bc_environment

                       AND x.country_code = TRIM(a.origin_country)

                       AND ( x.origin IS NULL OR x.destination IS NULL ) );



    v_sql_stmt_id := 110;



    SELECT COUNT(1)

      INTO v_orig_dest_excp4

      FROM ajc_ar_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND a.destination_country IS NOT NULL

       AND EXISTS ( SELECT 'x'

                      FROM ajcl_bc_ies_country_codes x

                     WHERE bc_environment = gv_bc_environment

                       AND x.country_code = TRIM(a.destination_country)

                       AND ( x.origin IS NULL OR x.destination IS NULL ) );



    /* 20240807

       Se comenta para que no frene la ejecucion cuando un financial_party que viene en el file no existe para ningun customer en oracle

       Se deja que siga para que genere e intente enviar los comprobantes a BC.

       Si el comprobante falla, hay que hacer el fix en ajcl_bc_ies_ar_headers

    */

    -- v_cust_excp_count := NVL(v_cust_excp1,0) + NVL(v_cust_excp2,0) + NVL(v_cust_excp3,0);

    -- 20240807



    print_log ( 'v_item_excp1: ' || v_item_excp1 ); 

    print_log ( 'v_item_excp2: ' || v_item_excp2 ); 

    print_log ( 'v_item_excp3: ' || v_item_excp3 ); 



    v_item_excp_count := NVL(v_item_excp1,0) + NVL(v_item_excp2,0) + NVL(v_item_excp3,0);

    print_log ( 'v_item_excp_count: ' || v_item_excp_count );



    -- 



    print_log ( 'v_orig_dest_excp1: ' || v_orig_dest_excp1 ); 

    print_log ( 'v_orig_dest_excp2: ' || v_orig_dest_excp2 ); 

    print_log ( 'v_orig_dest_excp3: ' || v_orig_dest_excp3 ); 

    print_log ( 'v_orig_dest_excp4: ' || v_orig_dest_excp4 ); 



    v_orig_dest_excp_count := NVL(v_orig_dest_excp1,0) + NVL(v_orig_dest_excp2,0)+

                              NVL(v_orig_dest_excp3,0) + NVL(v_orig_dest_excp4,0);

    print_log ( 'v_orig_dest_excp_count: ' || v_orig_dest_excp_count ); 



    v_sql_stmt_id := 120;



    SELECT COUNT(1)

      INTO v_term_excp_count

      FROM ajc_ar_ies_inbound_data a

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND NOT EXISTS ( SELECT 'x'

                          FROM ra_terms

                         WHERE trim(name) = trim(a.terms));



    print_log ( 'v_term_excp_count: ' || v_term_excp_count );



    v_sql_stmt_id := 130;



    IF ( gv_if_errors_stop = 'Y' ) THEN



      IF ( v_cust_excp_count > 0 OR v_item_excp_count > 0 OR v_term_excp_count > 0 OR v_orig_dest_excp_count > 0 ) THEN



        RAISE stop_processing;



      END IF;



    END IF;



    p_status := 'S';



    print_log('ajcl_bc_ies_ar_pkg.stop_processing_p (-)');



  EXCEPTION

    WHEN stop_processing THEN

      p_status := 'E';

      print_log ( 'ajcl_bc_ies_ar_pkg.stop_processing_p (!). Error: ' || SQLERRM );



    WHEN OTHERS THEN

      p_status := 'E';

      print_log ( ' ajcl_bc_ies_ar_pkg.stop_processing_p (!). Error OTHERS: ' || SQLERRM );



  END stop_processing_p;



  PROCEDURE insert_p ( p_status   OUT   VARCHAR2 ) IS



    v_sql_stmt_id                    NUMBER := 0;

    v_line_number                    NUMBER := 0;

    v_customer_id                    NUMBER := 0;

    --

    v_bill_to_customer_name          VARCHAR2(50);

    v_bill_to_customer_no            VARCHAR2(20);

    --

    v_bill_to_gl_id_rec              NUMBER := 0;

    v_rec_acct_from_cust_flag        VARCHAR2(1);

    -- v_min_trx_line_id                NUMBER := 0;

    -- v_min_line_no                    NUMBER := 0;



    v_inv_gl_id_rec_accountno        VARCHAR2(10);

    v_inv_gl_id_rec_company          VARCHAR2(10);

    v_inv_gl_id_rec_department       VARCHAR2(10);

    v_inv_gl_id_rec_destination      VARCHAR2(10);

    v_inv_gl_id_rec_office           VARCHAR2(10);

    v_inv_gl_id_rec_origin           VARCHAR2(10);

    v_inv_gl_id_rec_division         VARCHAR2(10);



    v_cm_gl_id_rec_accountno         VARCHAR2(10);

    v_cm_gl_id_rec_company           VARCHAR2(10);

    v_cm_gl_id_rec_department        VARCHAR2(10);

    v_cm_gl_id_rec_destination       VARCHAR2(10);

    v_cm_gl_id_rec_office            VARCHAR2(10);

    v_cm_gl_id_rec_origin            VARCHAR2(10);

    v_cm_gl_id_rec_division          VARCHAR2(10);



    v_rec_accountno                  VARCHAR2(10);

    v_rec_company                    VARCHAR2(10);

    v_rec_department                 VARCHAR2(10);

    v_rec_destination                VARCHAR2(10);

    v_rec_office                     VARCHAR2(10);

    v_rec_origin                     VARCHAR2(10);

    v_rec_division                   VARCHAR2(10);



    v_header_company                 VARCHAR2(10);

    v_header_account                 VARCHAR2(10);

    v_header_department              VARCHAR2(10);

    v_header_destination             VARCHAR2(10);

    v_header_office                  VARCHAR2(10);

    v_header_origin                  VARCHAR2(10);    

    v_header_division                VARCHAR2(10);



    v_rev_accountno                  VARCHAR2(10);

    v_rev_company                    VARCHAR2(10);

    v_rev_department                 VARCHAR2(10);

    v_rev_destination                VARCHAR2(10);

    v_rev_office                     VARCHAR2(10);

    v_rev_origin                     VARCHAR2(10);

    v_rev_division                   VARCHAR2(10);



    v_line_company                   VARCHAR2(10);

    v_line_account                   VARCHAR2(10);

    v_line_department                VARCHAR2(10);

    v_line_destination               VARCHAR2(10);

    v_line_office                    VARCHAR2(10);

    v_line_origin                    VARCHAR2(10);

    v_line_division                  VARCHAR2(10);



    v_charge_type_code               VARCHAR2(10);

    v_bill_to_cust_acct_site_id      NUMBER := 0;

    -- v_ship_to_cust_acct_site_id      NUMBER := 0;

    --

    v_bill_to_address1               VARCHAR2(150);

    v_bill_to_address2               VARCHAR2(150);

    v_bill_to_address3               VARCHAR2(150);

    --

    v_rowid                          ROWID;

    i                                NUMBER := 0;



      CURSOR ies_inv_cur IS

      SELECT invoice_number, 

             financial_party, 

             terms

        FROM ajc_ar_ies_inbound_data

       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

    GROUP BY invoice_number, 

             financial_party, 

             terms

      HAVING SUM(charge_amount) > 0;



    CURSOR ies_inv_line_cur (p_invoice_number CHAR, p_financial_party CHAR) IS

    SELECT rowid inbound_rowid, 

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

           NVL(description,TRIM(charge_type)) description, 

           original_amount, 

           invoice_amount

      FROM ajc_ar_ies_inbound_data

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND invoice_number = p_invoice_number

       AND financial_party = p_financial_party;



    v_bc_transactionno         VARCHAR2(100);

    v_bc_billtocustomerno      VARCHAR2(100);

    v_oracle_customer_trx_id   NUMBER;

    v_match                    VARCHAR2(100);



      CURSOR ies_cm_cur IS

      SELECT financial_party,

             invoice_number,

             reference_value_1,

             terms,

             SUM(charge_amount) inv_amt

        FROM ajc_ar_ies_inbound_data a

       WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

    GROUP BY financial_party,

             invoice_number,

             reference_value_1,

             terms

      HAVING SUM(charge_amount) < 0;



      -- BC

      /*

      SELECT ies.financial_party, 

             ies.invoice_number, 

             ies.terms, 

             -- MIN(rct.customer_trx_id) customer_trx_id

             sdh.transactionno,

             sdh.billtocustomerno

        FROM ( SELECT financial_party,

                      invoice_number,

                      reference_value_1,

                      terms,

                      SUM(charge_amount) inv_amt

                 FROM ajc_ar_ies_inbound_data a

                WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

                  -- AND TO_DATE(creation_date) BETWEEN NVL(p_from_accounting_date, TO_DATE('01-JAN-1900'))

                  --                                AND NVL(p_to_accounting_date, TO_DATE('31-DEC-4712'))

             GROUP BY financial_party,

                      invoice_number,

                      reference_value_1,

                      terms

               HAVING SUM(charge_amount) < 0 ) ies, 

             ajcl_bc_posted_sd_headers sdh,

             hz_cust_accounts_all hca

       WHERE sdh.iesNumber = NVL(ies.reference_value_1,ies.invoice_number) -- IES Number

         AND hca.attribute6 = ies.financial_party

         AND sdh.class != 'CM'

         AND hca.account_number = sdh.billtocustomerno

         AND ABS(ies.inv_amt) = ( SELECT SUM(amount)

                                    FROM ajcl_bc_posted_sd_lines sdl

                                   WHERE sdh.billtocustomerno = sdl.billtocustomerno

                                     AND sdh.transactionno = sdl.transactionno )

         AND sdh.amount = sdh.remainingAmount

    GROUP BY ies.financial_party, 

             ies.invoice_number, 

             ies.terms,

             sdh.transactionno,

             sdh.billtocustomerno

       UNION 

      -- Oracle

      SELECT ies.financial_party, 

             ies.invoice_number, 

             ies.terms, 

             rct.trx_number transactionno,

             hca.account_number billtocustomerno

        FROM ( SELECT financial_party,

                      invoice_number,

                      reference_value_1,

                      terms,

                      sum(charge_amount) inv_amt

                 FROM ajc_ar_ies_inbound_data a

                WHERE nvl(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

                  -- AND to_date(creation_date) BETWEEN nvl(to_date('&&3','YYYY/MM/DD HH24:MI:SS'), to_date('01-JAN-1900'))

                  --                                AND nvl(to_date('&&4','YYYY/MM/DD HH24:MI:SS'), to_date('31-DEC-4712'))

             GROUP BY financial_party,

                      invoice_number,

                      reference_value_1,

                      terms

               HAVING SUM(charge_amount) < 0 ) ies,

             ra_customer_trx_all rct, 

             hz_cust_accounts_all hca, 

             ra_cust_trx_types_all rctt

       WHERE rct.interface_header_attribute4 = NVL(ies.reference_value_1,ies.invoice_number) -- IES Number

         AND rct.bill_to_customer_id = hca.cust_account_id

         AND rct.org_id = gv_org_id

         AND hca.attribute6 = ies.financial_party

         AND rctt.cust_trx_type_id = rct.cust_trx_type_id

         AND rctt.type != 'CM'

         AND ABS(ies.inv_amt) = ( SELECT SUM(extended_amount)

                                    FROM ra_customer_trx_lines_all

                                   WHERE customer_trx_id = rct.customer_trx_id )

         AND EXISTS ( SELECT 'x'

                        FROM ar_payment_schedules_all

                       WHERE customer_trx_id = rct.customer_trx_id

                         AND amount_due_original = amount_due_remaining )

    GROUP BY ies.financial_party, 

             ies.invoice_number, 

             ies.terms

       UNION

      SELECT ies.financial_party, 

             ies.invoice_number, 

             ies.terms, 

             -- TO_NUMBER(NULL) customer_trx_id

             NULL transactionno,

             NULL billtocustomerno

        FROM ( SELECT financial_party,

                      invoice_number,

                      reference_value_1,

                      terms,

                      SUM(charge_amount) inv_amt

                 FROM ajc_ar_ies_inbound_data a

                WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

                  -- AND TO_DATE(creation_date) BETWEEN NVL(p_from_accounting_date, TO_DATE('01-JAN-1900'))

                  --                                AND NVL(p_to_accounting_date, TO_DATE('31-DEC-4712'))

             GROUP BY financial_party,

                      invoice_number,

                      reference_value_1,

                      terms

               HAVING SUM(charge_amount) < 0 ) ies

             -- BC

       WHERE NOT EXISTS ( SELECT 'x'

                            FROM ajcl_bc_posted_sd_headers sdh,

                                 hz_cust_accounts_all hca

                           WHERE sdh.iesNumber = NVL(ies.reference_value_1,ies.invoice_number) -- IES Number

                             AND hca.attribute6 = ies.financial_party

                             AND sdh.class != 'CM'

                             AND hca.account_number = sdh.billToCustomerNo

                             AND sdh.amount = sdh.remainingAmount

                             AND ABS(ies.inv_amt) = ( SELECT SUM(amount)

                                                        FROM ajcl_bc_posted_sd_lines sdl

                                                       WHERE sdh.billToCustomerNo = sdl.billToCustomerNo

                                                         AND sdh.transactionno = sdl.transactionno )

                             )

             -- Oracle

         AND NOT EXISTS ( SELECT 'x'

                            FROM ra_customer_trx_all rct, 

                                 hz_cust_accounts_all hca, 

                                 ra_cust_trx_types_all rctt, 

                                 ar_payment_schedules_all aps

                           WHERE rct.interface_header_attribute4 = NVL(ies.reference_value_1,ies.invoice_number) -- IES Number

                             AND rct.bill_to_customer_id = hca.cust_account_id

                             AND rct.org_id = gv_org_id

                             AND rctt.cust_trx_type_id = rct.cust_trx_type_id

                             AND rctt.type != 'CM'

                             AND hca.attribute6 = ies.financial_party

                             AND aps.customer_trx_id = rct.customer_trx_id

                             AND aps.amount_due_original = aps.amount_due_remaining

                             AND ABS(ies.inv_amt) = ( SELECT SUM(extended_amount)

                                                        FROM ra_customer_trx_lines_all

                                                       WHERE customer_trx_id = rct.customer_trx_id ) );

    */



    CURSOR ies_cm_line_cur ( p_invoice_number CHAR, 

                             p_financial_party CHAR ) IS

    SELECT rowid inbound_rowid, 

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

           NVL(description,trim(charge_type)) description, 

           original_amount, 

           invoice_amount

      FROM ajc_ar_ies_inbound_data

     WHERE NVL(interface_status,'UN-PROCESSED') = 'UN-PROCESSED'

       AND invoice_number = p_invoice_number

       AND financial_party = p_financial_party;



      CURSOR c_headers IS

      SELECT billToCustomerId,

             billToCustomerName,

             billToCustomerNo,

             billToAddress1,

             billToAddress2,

             billToAddress3,

             transactionNo,

             class,

             transactionDate,

             glDate,

             termName,

             termDueDate,

             invoiceCurrencyCode,

             exchangeRateType,

             exchangeDate,

             exchangeRate,

             SUM(extendedAmount) amount,

             header_company company,

             header_account account,

             header_department department,

             header_destination destination,

             header_office office,

             header_origin origin,

             header_division division,

             dff_invoice_company, 

             dff_invoice_number,

             dff_ies_number,

             header_worksheet worksheetNo,

             appliestoDocType,

             appliestoDocNo,

             financial_party,

             status 

        FROM ajcl_bc_ies_ar_lines a

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         -- AND status = 'NEW' -- Para que genera la cabecera de los que dan error en oracle

    GROUP BY billToCustomerId,

             billToCustomerName,

             billToCustomerNo,

             billToAddress1,

             billToAddress2,

             billToAddress3,

             transactionNo,

             class,

             transactionDate,

             glDate,

             termName,

             termDueDate,

             invoiceCurrencyCode,

             exchangeRateType,

             exchangeDate,

             exchangeRate,

             header_company,

             header_account,

             header_department,

             header_destination,

             header_office,

             header_origin,

             header_division,

             dff_invoice_company,

             dff_invoice_number, 

             dff_ies_number, 

             header_worksheet,

             appliesToDocType,

             appliesToDocNo,

             financial_party,

             status;



    v_error_msg    VARCHAR2(200);

    v_tbl_status   VARCHAR2(20);



  BEGIN



    print_log ( 'ajcl_bc_ies_ar_pkg.insert_p (+)' );



    v_sql_stmt_id := 10;



    SELECT b.segment1,

           aba.bc_account,

           NULL,

           NULL,

           NULL,

           NULL,

           NULL

      INTO v_inv_gl_id_rec_company,

           v_inv_gl_id_rec_accountno,

           v_inv_gl_id_rec_department,

           v_inv_gl_id_rec_destination,

           v_inv_gl_id_rec_office,

           v_inv_gl_id_rec_origin,

           v_inv_gl_id_rec_division

      FROM ra_cust_trx_types_all a, 

           gl_code_combinations b,

           ajc_bc_accounts aba

     WHERE a.org_id = gv_org_id

       AND a.name = 'IES INVOICE' 

       AND a.gl_id_rec = b.code_combination_id

       AND b.segment2 = aba.oracle_account;



    v_sql_stmt_id := 30;



    SELECT b.segment1,

           aba.bc_account,

           NULL,

           NULL,

           NULL,

           NULL,

           NULL

      INTO v_cm_gl_id_rec_company,

           v_cm_gl_id_rec_accountno,

           v_cm_gl_id_rec_department,

           v_cm_gl_id_rec_destination,

           v_cm_gl_id_rec_office,

           v_cm_gl_id_rec_origin,

           v_cm_gl_id_rec_division

      FROM ra_cust_trx_types_all a, 

           gl_code_combinations b,

           ajc_bc_accounts aba

     WHERE a.org_id = gv_org_id

       AND a.name = 'IES CM'

       AND a.gl_id_rec = b.code_combination_id

       AND b.segment2 = aba.oracle_account;



    -- Process invoices first.

    FOR ies_inv_row IN ies_inv_cur LOOP



      print_log ( '** Processing invoice number: ' || ies_inv_row.invoice_number || 

                    '|financial party: ' || ies_inv_row.financial_party || 

                    '|terms: ' || ies_inv_row.terms || ' **');



      v_tbl_status := 'NEW';

      v_error_msg := NULL;     



      v_line_number := 0;



      v_customer_id := NULL;

      v_rec_acct_from_cust_flag := NULL;

      v_bill_to_customer_name := NULL;

      v_bill_to_customer_no := NULL;



      BEGIN



        v_sql_stmt_id := 40;



        SELECT hca.cust_account_id, 

               NVL(hca.attribute7,'N') 

          INTO v_customer_id, 

               v_rec_acct_from_cust_flag 

          FROM hz_cust_accounts_all hca

         WHERE TRIM(UPPER(hca.attribute6)) = TRIM(UPPER(ies_inv_row.financial_party));



        --

        SELECT customer_name,

               customer_number

          INTO v_bill_to_customer_name,

               v_bill_to_customer_no

          FROM ra_customers

         WHERE customer_id = v_customer_id;



        print_log ( 'v_bill_to_customer_name: ' || v_bill_to_customer_name );

        print_log ( 'v_bill_to_customer_no: ' || v_bill_to_customer_no );

        --



      EXCEPTION

        WHEN NO_DATA_FOUND THEN

          v_error_msg := 'Could not retrieve customer for financial party ' || TRIM(UPPER(ies_inv_row.financial_party));

          print_log ( v_error_msg );

          v_tbl_status := 'ERROR';

          v_customer_id := NULL;

          v_bill_to_customer_name := NULL;

          v_bill_to_customer_no := NULL;



        WHEN OTHERS THEN

          v_error_msg := 'Error retrieving customer.';

          print_log ( v_error_msg || ' - ' || SQLERRM );

          v_tbl_status := 'ERROR';

          v_customer_id := NULL;

          v_rec_acct_from_cust_flag := 'N';

          v_bill_to_customer_name := NULL;

          v_bill_to_customer_no := NULL;



      END;



      -- Get the bill to cust acct site id 

      v_bill_to_cust_acct_site_id := NULL;

      v_bill_to_gl_id_rec := NULL;

      v_bill_to_address1 := NULL;

      v_bill_to_address2 := NULL;

      v_bill_to_address3 := NULL;



      BEGIN



        v_sql_stmt_id := 50;



        SELECT hcas.cust_acct_site_id, 

               hcsu.gl_id_rec

               --

               ,SUBSTR(hl.address1,1,100) billToAddress1

               ,SUBSTR(hl.address2,1,50) billToAddress2

               ,SUBSTR(hl.address3,1,50) billToAddress3

          INTO v_bill_to_cust_acct_site_id, 

               v_bill_to_gl_id_rec

               -- 

               ,v_bill_to_address1

               ,v_bill_to_address2

               ,v_bill_to_address3

          FROM hz_cust_accounts_all hca, 

               hz_cust_acct_sites_all hcas, 

               hz_cust_site_uses_all hcsu

               --

               ,hz_party_sites ps

               ,hz_locations hl

         WHERE TRIM(UPPER(hca.attribute6)) = TRIM(UPPER(ies_inv_row.financial_party))

           AND hcas.cust_account_id = hca.cust_account_id

           AND hcas.org_id = gv_org_id

           AND hcsu.org_id = gv_org_id

           AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id

           AND hcsu.status = 'A'

           AND hcsu.primary_flag = 'Y'

           AND hcsu.site_use_code = 'BILL_TO'

           --

           AND hcas.party_site_id = ps.party_site_id

           AND ps.location_id = hl.location_id

           --

           ;



      EXCEPTION

        WHEN NO_DATA_FOUND THEN

          IF ( v_tbl_status != 'ERROR' ) THEN

            v_error_msg := 'Could not retrieve bill to site for financial party ' || ies_inv_row.financial_party;

            print_log ( v_error_msg );

            v_tbl_status := 'ERROR';

          END IF;

          v_bill_to_cust_acct_site_id := NULL;

          v_bill_to_address1 := NULL;

          v_bill_to_address2 := NULL;

          v_bill_to_address3 := NULL;



        WHEN OTHERS THEN

          IF ( v_tbl_status != 'ERROR' ) THEN

            v_error_msg := 'Error retrieving bill to site for financial party ' || ies_inv_row.financial_party || ' - ERROR: ' || SQLERRM;

            print_log ( v_error_msg || ' - ' || SQLERRM );

            v_tbl_status := 'ERROR';

          END IF;

          v_bill_to_cust_acct_site_id := NULL;

          v_bill_to_address1 := NULL;

          v_bill_to_address2 := NULL;

          v_bill_to_address3 := NULL;



      END;



      i := 0;



      FOR ies_inv_line_row IN ies_inv_line_cur (ies_inv_row.invoice_number, ies_inv_row.financial_party) LOOP



        v_charge_type_code := null;



        v_sql_stmt_id := 70;



        BEGIN



          SELECT NVL(substitute, TRIM(ies_inv_line_row.charge_type_code))

            INTO v_charge_type_code

            FROM ajcl_bc_ies_charge_types

           WHERE bc_environment = gv_bc_environment

             AND charge_type_code = TRIM(ies_inv_line_row.charge_type_code)

           UNION

          SELECT TRIM(ies_inv_line_row.charge_type_code)

            FROM dual

           WHERE NOT EXISTS ( SELECT 'x'

                                FROM ajcl_bc_ies_charge_types

                               WHERE bc_environment = gv_bc_environment

                                 AND charge_type_code = TRIM(ies_inv_line_row.charge_type_code) );



        EXCEPTION

          WHEN OTHERS THEN

            v_error_msg := 'Charge type code ' || ies_inv_line_row.charge_type_code || ' not found in ajcl_bc_ies_charge_types.';

            print_log ( v_error_msg );

            v_tbl_status := 'ERROR';



        END;



        print_log ( 'Processing amount: ' || ies_inv_line_row.charge_amount || 

                    '|item = ' || v_charge_type_code || '.' || ies_inv_line_row.business_line );



        v_rev_accountno := NULL;

        v_rev_company := NULL;

        v_rev_department := NULL;

        v_rev_destination := NULL;

        v_rev_office := NULL;

        v_rev_origin := NULL;

        v_rev_division := NULL;



        i := i + 1;



        -- Get revenue accounting and item id -- line dimensions

        BEGIN



          v_sql_stmt_id := 80;

          print_log ( 'ies_inv_line_row.business_line: ' || ies_inv_line_row.business_line );



          SELECT rev_accountno,

                 rev_company,

                 rev_department,

                 rev_destination,

                 rev_office,

                 rev_origin,

                 rev_division

            INTO v_rev_accountno,

                 v_rev_company,

                 v_rev_department, 

                 v_rev_destination, 

                 v_rev_office,

                 v_rev_origin,

                 v_rev_division

            FROM ajcl_bc_ies_items b

           WHERE bc_environment = gv_bc_environment

             AND TRIM(b.charge_type_code) = v_charge_type_code

             AND TRIM(b.business_line) = TRIM(ies_inv_line_row.business_line)

             AND nvl(b.inactive_date, SYSDATE + 1) > SYSDATE;



          IF ( ies_inv_line_row.destination_country IS NOT NULL ) THEN



            BEGIN



              v_sql_stmt_id := 90;



              SELECT destination

                INTO v_rev_destination

                FROM ajcl_bc_ies_country_codes

               WHERE bc_environment = gv_bc_environment

                 AND country_code = ies_inv_line_row.destination_country;



            EXCEPTION

              WHEN NO_DATA_FOUND THEN

                v_rev_destination := NULL;

              WHEN OTHERS THEN

                v_rev_destination := NULL;



            END;



          END IF;



          IF ( ies_inv_line_row.origin_country IS NOT NULL ) THEN



            BEGIN



              v_sql_stmt_id := 100;



              SELECT origin

                INTO v_rev_origin

                FROM ajcl_bc_ies_country_codes

               WHERE bc_environment = gv_bc_environment

                 AND country_code = ies_inv_line_row.origin_country;



            EXCEPTION

              WHEN NO_DATA_FOUND THEN

                v_rev_origin := null;

              WHEN OTHERS THEN

                v_rev_origin := null;



            END;



          END IF;



        EXCEPTION

          WHEN NO_DATA_FOUND THEN



            IF ( v_tbl_status != 'ERROR' ) THEN



              v_error_msg := 'Could not retrieve revenue accounting for Charge Type Code ' || v_charge_type_code || ' and Business Line ' || TRIM(ies_inv_line_row.business_line);

              print_log ( v_error_msg );

              v_tbl_status := 'ERROR';



            END IF;



        END;



        -- Se mapea la cuenta de la linea al formato BC - REV

        v_line_account := v_rev_accountno;

        v_line_company := v_rev_company;

        v_line_department := v_rev_department;

        v_line_destination := v_rev_destination;

        v_line_office := v_rev_office;

        v_line_origin := v_rev_origin;

        v_line_division := v_rev_division;



        print_log ( 'v_line_company: ' || v_line_company );

        print_log ( 'v_line_account: ' || v_line_account );

        print_log ( 'v_line_department: ' || v_line_department );

        print_log ( 'v_line_destination: ' || v_line_destination );

        print_log ( 'v_line_office: ' || v_line_office );

        print_log ( 'v_line_origin: ' || v_line_origin );

        print_log ( 'v_line_division: ' || v_line_division );



        v_line_number := v_line_number + 1;

        v_rowid := ies_inv_line_row.inbound_rowid;



        -- 

        v_rec_accountno := null;

        v_rec_company := null;

        v_rec_department := null;

        v_rec_destination := null;

        v_rec_office := null;

        v_rec_origin := null;

        v_rec_division := null;



        IF ( v_rec_acct_from_cust_flag = 'N' ) THEN



          v_rec_accountno := v_inv_gl_id_rec_accountno;

          v_rec_company := v_inv_gl_id_rec_company;

          v_rec_department := v_inv_gl_id_rec_department;

          v_rec_destination := v_inv_gl_id_rec_destination;

          v_rec_office := v_inv_gl_id_rec_office;

          v_rec_origin := v_inv_gl_id_rec_origin;

          v_rec_division := v_inv_gl_id_rec_division;



        END IF;



        IF ( v_rec_acct_from_cust_flag = 'Y' ) THEN



          IF ( v_bill_to_gl_id_rec IS NOT NULL ) THEN



            v_sql_stmt_id := 140;



            SELECT aba.bc_account,

                   ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'COMPANY',gcc.segment1) company,

                   ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'DEPARTMENT',gcc.segment3) department,

                   ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'DESTINATION',

                     DECODE(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                                       p_oracle_value => gcc.segment5,

                                                                       p_bc_dimension => 'OFFICE' ),NULL,gcc.segment5,'000') ) destination,

                   ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'OFFICE',

                     NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                                    p_oracle_value => gcc.segment5,

                                                                    p_bc_dimension => 'OFFICE'),'000') ) office,

                   ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'ORIGIN',gcc.segment6) origin,

                   ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'DIVISION',

                     NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4',

                                                                    p_oracle_value => gcc.segment4,

                                                                    p_bc_dimension => 'DIVISION'),'000') ) division

              INTO v_rec_accountno,

                   v_rec_company,

                   v_rec_department,

                   v_rec_destination,

                   v_rec_office, 

                   v_rec_origin,

                   v_rec_division

              FROM gl_code_combinations gcc,

                   ajc_bc_accounts aba

             WHERE gcc.code_combination_id = v_bill_to_gl_id_rec

               AND gcc.segment2 = aba.oracle_account;



          END IF;



        END IF;



        -- Se mapea la cuenta de la cabecera al formato BC - REC

        v_header_account := v_rec_accountno;

        v_header_company := v_rec_company;

        v_header_department := v_rec_department;

        v_header_destination := v_rec_destination;

        v_header_office := v_rec_office;

        v_header_origin := v_rec_origin;

        v_header_division := v_rec_division;



        print_log ( 'v_header_company: ' || v_header_company );

        print_log ( 'v_header_account: ' || v_header_account );

        print_log ( 'v_header_department: ' || v_header_department );

        print_log ( 'v_header_destination: ' || v_header_destination );

        print_log ( 'v_header_office: ' || v_header_office );

        print_log ( 'v_header_origin: ' || v_header_origin );

        print_log ( 'v_header_division: ' || v_header_division );



        -- Insert a record into ajcl_bc_ies_ar_lines

        v_sql_stmt_id := 110;

        print_log ( 'INSERT ajcl_bc_ies_ar_lines (1).');



        -- print_log ( 'v_customer_id: ' || v_customer_id );

        -- print_log ( 'v_line_number: ' || v_line_number );

        -- print_log ( 'ies_inv_line_row.charge_amount: ' || TO_NUMBER(ies_inv_line_row.charge_amount,'999999.99') );



        -- No se generan ni envian las lineas en 0, porque BC las rechaza

        IF ( TO_NUMBER(ies_inv_line_row.charge_amount,'999999.99') != 0 ) THEN



          INSERT 

            INTO ajcl_bc_ies_ar_lines

               ( bc_environment,

                 billToCustomerId,

                 billToCustomerName,

                 billToCustomerNo,

                 billToAddress1,

                 billToAddress2,

                 billToAddress3,

                 transactionNo,

                 class,

                 transactionDate,

                 glDate,

                 termName,

                 termDueDate,

                 lineNo,

                 description,

                 invoiceCurrencyCode,

                 exchangeRateType,

                 exchangeDate,

                 exchangeRate,

                 quantity,

                 unitSellingPrice,

                 extendedAmount,

                 accountedAmount,

                 header_company,

                 header_account,

                 header_department,

                 header_destination,

                 header_office,

                 header_origin,

                 header_worksheet,

                 header_division,               

                 line_company,

                 line_account,

                 line_department,

                 line_destination,

                 line_office,

                 line_origin,

                 line_division,

                 line_worksheet,

                 dff_invoice_company,

                 dff_invoice_number,

                 dff_invoice_line,

                 dff_ies_number,

                 dff_pickup_date,

                 dff_etd,

                 dff_eta,

                 dff_destination,

                 dff_origin,

                 financial_party,

                 org_id,

                 request_id,

                 creation_date,

                 created_by,

                 last_update_date,

                 last_updated_by,

                 status,

                 error_message )

        VALUES ( gv_bc_environment,

                 v_customer_id,

                 v_bill_to_customer_name,

                 v_bill_to_customer_no,

                 v_bill_to_address1,

                 v_bill_to_address2,

                 v_bill_to_address3,

                 ies_inv_line_row.invoice_number, -- trx_number

                 'INV', -- class

                 TO_CHAR(TO_DATE(ies_inv_line_row.accounting_date,'YYYY-MM-DD'),'YYYY-MM-DD'), -- trx_date

                 TO_CHAR(NVL(gv_gl_date,TO_DATE(ies_inv_line_row.accounting_date,'YYYY-MM-DD')),'YYYY-MM-DD'), -- gl_date

                 ies_inv_line_row.terms, -- term_name

                 TO_CHAR(TO_DATE(ies_inv_line_row.due_date,'YYYY-MM-DD'),'YYYY-MM-DD'),

                 v_line_number, -- line_number

                 v_charge_type_code || '.' || TRIM(ies_inv_line_row.business_line) || ';' || ies_inv_line_row.description, -- description

                 ies_inv_line_row.currency_code, -- currency_code

                 'User', -- conversion_type

                 NULL, -- conversion_date

                 1, -- conversion_rate

                 1, -- quantity

                 ABS(TO_NUMBER(ies_inv_line_row.charge_amount,'999999.99')), -- unit_selling_price,

                 ABS(TO_NUMBER(ies_inv_line_row.charge_amount,'999999.99')), -- extended_amount

                 ABS(TO_NUMBER(ies_inv_line_row.charge_amount,'999999.99')), -- accounted_amount

                 v_header_company, 

                 v_header_account, 

                 v_header_department, 

                 v_header_destination, 

                 v_header_office,

                 v_header_origin, 

                 ies_inv_line_row.reference_value_1, -- header_worksheet

                 v_header_division,

                 v_line_company, 

                 v_line_account, 

                 v_line_department, 

                 v_line_destination, 

                 v_line_office, 

                 v_line_origin, 

                 v_line_division,

                 ies_inv_line_row.reference_value_1, -- line_worksheet

                 ies_inv_line_row.company_number, -- dff_invoice_company

                 ies_inv_line_row.invoice_number, -- dff_invoice_number

                 v_line_number, -- dff_invoice_line

                 NVL(ies_inv_line_row.reference_value_1, ies_inv_line_row.invoice_number), -- dff_ies_number

                 ies_inv_line_row.due_date, -- dff_pickup_date

                 ies_inv_line_row.due_date, -- dff_etd

                 ies_inv_line_row.due_date, -- dff_eta

                 NVL(ies_inv_line_row.destination_country,'NOTINFILE'), -- dff_destination

                 NVL(ies_inv_line_row.origin_country,'NOTINFILE'), -- dff_origin

                 ies_inv_line_row.financial_party,

                 gv_org_id,

                 gv_request_id,

                 SYSDATE,

                 gv_user_id,

                 SYSDATE,

                 gv_user_id,

                 v_tbl_status,

                 v_error_msg );



          IF ( SQL%ROWCOUNT > 0 ) THEN



            print_log ( '1 invoice line record inserted into ajcl_bc_ies_ar_lines.' );

            COMMIT;



          END IF;



        END IF;



        UPDATE ajc_ar_ies_inbound_data

           SET interface_status = 'TRANSFERRED'

         WHERE rowid = ies_inv_line_row.inbound_rowid;



      END LOOP; -- ies_inv_line_row



    END LOOP; -- ies_inv_row



    -- Process credit memos next. Process their lines and distributions 

    FOR ies_cm_row IN ies_cm_cur LOOP



      v_bc_transactionno := NULL;

      v_bc_billtocustomerno := NULL;

      v_oracle_customer_trx_id := NULL;

      v_match := NULL;



      v_line_number := 0;



      v_tbl_status := 'NEW';

      v_error_msg := NULL;



      -- Se verifica si se levanta algo del lado de BC

      BEGIN



          SELECT MIN(sdh.transactionno), -- Se busca el min porque puede existir una trx 20-172041-1, otra 20-172041-2, etc, con todo igual

                 sdh.billtocustomerno

            INTO v_bc_transactionno,

                 v_bc_billtocustomerno

            FROM ajcl_bc_posted_sd_headers sdh,

                 hz_cust_accounts_all hca

           WHERE sdh.bc_environment = gv_bc_environment

             AND sdh.iesNumber = NVL(ies_cm_row.reference_value_1,ies_cm_row.invoice_number) -- IES Number

             AND hca.attribute6 = ies_cm_row.financial_party

             AND sdh.class != 'CM'

             AND hca.account_number = sdh.billtocustomerno

             AND ABS(ies_cm_row.inv_amt) = ( SELECT SUM(amount)

                                               FROM ajcl_bc_posted_sd_lines sdl

                                              WHERE sdl.bc_environment = gv_bc_environment

                                                AND sdh.billtocustomerno = sdl.billtocustomerno

                                                AND sdh.transactionno = sdl.transactionno )

             AND sdh.amount = sdh.remainingAmount

        GROUP BY sdh.billtocustomerno;



        v_match := 'BC';



        print_log ( '** Processing credit memo invoice number: ' || ies_cm_row.invoice_number || 

                      '|financial party: ' || ies_cm_row.financial_party || 

                      '|billtocustomerno: ' || v_bc_billtocustomerno || 

                      '|transactionno: ' || v_bc_transactionno || ' **');



      EXCEPTION

        WHEN OTHERS THEN

          v_bc_transactionno := NULL;

          v_bc_billtocustomerno := NULL;

          v_match := NULL;



      END;



      -- Si no encontro nada del lado de BC, verifico en Oracle

      IF ( v_bc_transactionno IS NULL AND v_bc_billtocustomerno IS NULL ) THEN



        BEGIN



          SELECT MIN(y.customer_trx_id)   

            INTO v_oracle_customer_trx_id

            FROM ra_customer_trx_all y, 

                 hz_cust_accounts_all z, 

                 ra_cust_trx_types_all r

           WHERE y.interface_header_attribute4 = nvl(ies_cm_row.reference_value_1, ies_cm_row.invoice_number)

             AND y.bill_to_customer_id = z.cust_account_id

             AND y.org_id = gv_org_id

             AND z.attribute6 = ies_cm_row.financial_party

             AND r.cust_trx_type_id = y.cust_trx_type_id

             AND r.type != 'CM'

             AND abs(ies_cm_row.inv_amt) = ( SELECT SUM(extended_amount)

                                               FROM ra_customer_trx_lines_all

                                              WHERE customer_trx_id = y.customer_trx_id)

             AND EXISTS ( SELECT 'x'

                            FROM ar_payment_schedules_all

                           WHERE customer_trx_id = y.customer_trx_id

                             AND amount_due_original = amount_due_remaining )

         UNION

        SELECT TO_NUMBER(NULL)

          FROM DUAL

         WHERE NOT EXISTS ( SELECT 'x'

                              FROM ra_customer_trx_all m, 

                                   hz_cust_accounts_all n, 

                                   ra_cust_trx_types_all r, 

                                   ar_payment_schedules_all f

                             WHERE m.interface_header_attribute4 = NVL(ies_cm_row.reference_value_1, ies_cm_row.invoice_number)

                               AND m.bill_to_customer_id = n.cust_account_id

                               AND m.org_id = gv_org_id

                               AND r.cust_trx_type_id = m.cust_trx_type_id

                               AND r.type != 'CM'

                               AND n.attribute6 = ies_cm_row.financial_party

                               AND f.customer_trx_id = m.customer_trx_id

                               AND f.amount_due_original = f.amount_due_remaining

                               AND ABS(ies_cm_row.inv_amt) = ( SELECT SUM(extended_amount)

                                                                 FROM ra_customer_trx_lines_all

                                                                WHERE customer_trx_id = m.customer_trx_id ) );                             



          v_match := 'ORACLE';



          print_log ( '** Processing credit memo invoice number: ' || ies_cm_row.invoice_number || 

                      '|financial party: ' || ies_cm_row.financial_party || 

                      '|customer_trx_id: ' || v_oracle_customer_trx_id || ' **');



        EXCEPTION

          WHEN OTHERS THEN

            v_oracle_customer_trx_id := NULL;

            v_match := NULL;



        END;



      END IF;      



      -- Si no machea en BC ni en Oracle, se continua con la siguiente iteracion

      IF ( ( v_bc_transactionno IS NULL AND 

             v_bc_billtocustomerno IS NULL ) AND 

           ( v_oracle_customer_trx_id IS NULL ) AND

             v_match IS NULL ) THEN



        CONTINUE;



      END IF;      



      -- Get the customer id 

      v_customer_id := null;

      v_rec_acct_from_cust_flag := null;

      v_bill_to_customer_name := NULL;

      v_bill_to_customer_no := NULL;



      BEGIN



        v_sql_stmt_id := 160;



        SELECT hca.cust_account_id, 

               NVL(hca.attribute7,'N')

          INTO v_customer_id, 

               v_rec_acct_from_cust_flag

          FROM hz_cust_accounts_all hca

         WHERE TRIM(UPPER(hca.attribute6)) = TRIM(UPPER(ies_cm_row.financial_party));



        --

        SELECT customer_name,

               customer_number

          INTO v_bill_to_customer_name,

               v_bill_to_customer_no

          FROM ra_customers

         WHERE customer_id = v_customer_id;



        print_log ( 'v_bill_to_customer_name: ' || v_bill_to_customer_name );

        print_log ( 'v_bill_to_customer_no: ' || v_bill_to_customer_no );

        --



      EXCEPTION

        WHEN NO_DATA_FOUND THEN

          v_error_msg := 'Could not retrieve customer for financial party ' || TRIM(UPPER(ies_cm_row.financial_party));

          print_log ( v_error_msg );

          v_tbl_status := 'ERROR';

          v_customer_id := NULL;

          v_bill_to_customer_name := NULL;

          v_bill_to_customer_no := NULL;



        WHEN OTHERS THEN

          v_error_msg := 'Error retrieving customer.';

          print_log ( v_error_msg || ' - ' || SQLERRM );

          v_tbl_status := 'ERROR';

          v_customer_id := NULL;

          v_rec_acct_from_cust_flag := NULL;

          v_bill_to_customer_name := NULL;

          v_bill_to_customer_no := NULL;



      END;



      -- Get the bill to cust acct site id 

      v_bill_to_cust_acct_site_id := NULL;

      v_bill_to_gl_id_rec := NULL;

      v_bill_to_address1 := NULL;

      v_bill_to_address2 := NULL;

      v_bill_to_address3 := NULL;



      BEGIN



        v_sql_stmt_id := 170;



        SELECT hcas.cust_acct_site_id, 

               hcsu.gl_id_rec

               --

               ,SUBSTR(hl.address1,1,100) billToAddress1

               ,SUBSTR(hl.address2,1,50) billToAddress2

               ,SUBSTR(hl.address3,1,50) billToAddress3

          INTO v_bill_to_cust_acct_site_id, 

               v_bill_to_gl_id_rec

               -- 

               ,v_bill_to_address1

               ,v_bill_to_address2

               ,v_bill_to_address3

          FROM hz_cust_accounts_all hca, 

               hz_cust_acct_sites_all hcas, 

               hz_cust_site_uses_all hcsu

               --

               ,hz_party_sites ps

               ,hz_locations hl

         WHERE trim(upper(hca.attribute6)) = trim(upper(ies_cm_row.financial_party))

           AND hcas.cust_account_id = hca.cust_account_id

           AND hcas.org_id = gv_org_id

           AND hcsu.org_id = gv_org_id

           AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id

           AND hcsu.status = 'A'

           AND hcsu.primary_flag = 'Y'

           AND hcsu.site_use_code = 'BILL_TO'

           --

           AND hcas.party_site_id = ps.party_site_id

           AND ps.location_id = hl.location_id

           --

           ;



      EXCEPTION

        WHEN NO_DATA_FOUND THEN

          IF ( v_tbl_status != 'ERROR' ) THEN

            v_error_msg := 'Could not retrieve bill to site for financial party ' || ies_cm_row.financial_party;

            print_log ( v_error_msg );

            v_tbl_status := 'ERROR';

          END IF;

          v_bill_to_cust_acct_site_id := NULL;

          v_bill_to_address1 := NULL;

          v_bill_to_address2 := NULL;

          v_bill_to_address3 := NULL;



        WHEN OTHERS THEN

          IF ( v_tbl_status != 'ERROR' ) THEN

            v_error_msg := 'Error retrieving bill to site for financial party ' || ies_cm_row.financial_party || ' - ERROR: ' || SQLERRM;

            print_log ( v_error_msg || ' - ' || SQLERRM );

            v_tbl_status := 'ERROR';

          END IF;

          v_bill_to_cust_acct_site_id := NULL;

          v_bill_to_address1 := NULL;

          v_bill_to_address2 := NULL;

          v_bill_to_address3 := NULL;



      END;



      i := 0;



      FOR ies_cm_line_row IN ies_cm_line_cur ( ies_cm_row.invoice_number, ies_cm_row.financial_party ) LOOP



        v_charge_type_code := null;



        v_sql_stmt_id := 190;



        BEGIN



          SELECT NVL(substitute, TRIM(ies_cm_line_row.charge_type_code))

            INTO v_charge_type_code

            FROM ajcl_bc_ies_charge_types

           WHERE bc_environment = gv_bc_environment

             AND charge_type_code = TRIM(ies_cm_line_row.charge_type_code)

           UNION

          SELECT TRIM(ies_cm_line_row.charge_type_code)

            FROM dual

           WHERE NOT EXISTS ( SELECT 'x'

                                FROM ajcl_bc_ies_charge_types

                               WHERE bc_environment = gv_bc_environment

                                 AND charge_type_code = TRIM(ies_cm_line_row.charge_type_code ));



        EXCEPTION

          WHEN OTHERS THEN

            v_error_msg := 'Charge type code ' || ies_cm_line_row.charge_type_code || ' not found in ajcl_bc_ies_charge_types.';

            print_log ( v_error_msg );

            v_tbl_status := 'ERROR';



        END;



        print_log ( 'Processing cm amount = ' || ies_cm_line_row.charge_amount || 

                    ', item = ' || v_charge_type_code || '.' ||

                     ies_cm_line_row.business_line );



        v_rev_accountno := null;

        v_rev_company := null;

        v_rev_department := null;

        v_rev_destination := null;

        v_rev_office := null;

        v_rev_origin := null;

        v_rev_division := null;



        i := i + 1;



        -- Get revenue accounting 

        BEGIN



          v_sql_stmt_id := 200;



          SELECT rev_accountno,

                 rev_company,

                 rev_department,

                 rev_destination,

                 rev_office,

                 rev_origin,

                 rev_division

            INTO v_rev_accountno, 

                 v_rev_company,

                 v_rev_department,

                 v_rev_destination,

                 v_rev_office,

                 v_rev_origin,

                 v_rev_division

            FROM ajcl_bc_ies_items b

           WHERE bc_environment = gv_bc_environment

             AND TRIM(b.charge_type_code) = v_charge_type_code

             AND TRIM(b.business_line) = TRIM(ies_cm_line_row.business_line)

             AND NVL(b.inactive_date, SYSDATE + 1) > SYSDATE;



          IF ( ies_cm_line_row.destination_country IS NOT NULL ) THEN



            BEGIN



              v_sql_stmt_id := 210;



              SELECT destination

                INTO v_rev_destination

                FROM ajcl_bc_ies_country_codes

               WHERE bc_environment = gv_bc_environment

                 AND country_code = ies_cm_line_row.destination_country;



            EXCEPTION

              WHEN NO_DATA_FOUND THEN

                v_rev_destination := null;

              WHEN OTHERS THEN

                v_rev_destination := null;



            END;



          END IF;



          IF ( ies_cm_line_row.origin_country IS NOT NULL ) THEN



            BEGIN



              v_sql_stmt_id := 220;



              SELECT origin

                INTO v_rev_origin

                FROM ajcl_bc_ies_country_codes

               WHERE bc_environment = gv_bc_environment

                 AND country_code = ies_cm_line_row.origin_country;



            EXCEPTION

              WHEN NO_DATA_FOUND THEN

                v_rev_origin := null;

              WHEN OTHERS THEN

                v_rev_origin := null;



            END;



          END IF;



        EXCEPTION

          WHEN NO_DATA_FOUND THEN



            IF ( v_tbl_status != 'ERROR' ) THEN



              v_error_msg := 'Could not retrieve revenue accounting for Charge Type Code ' || v_charge_type_code || ' and Business Line ' || TRIM(ies_cm_line_row.business_line);

              print_log ( v_error_msg );

              v_tbl_status := 'ERROR';



            END IF;



            v_rev_accountno := NULL;

            v_rev_company := NULL;

            v_rev_department := NULL;

            v_rev_destination := NULL;

            v_rev_office := NULL;

            v_rev_origin := NULL;

            v_rev_division := NULL;



          WHEN OTHERS THEN

            IF ( v_tbl_status != 'ERROR' ) THEN

              v_error_msg := 'Error retrieving revenue accounting.' || ' - ' || SQLERRM;

              print_log ( v_error_msg );

              v_tbl_status := 'ERROR';

            END IF;



            v_rev_accountno := null;

            v_rev_company := null;

            v_rev_department := null;

            v_rev_destination := null;

            v_rev_office := null;

            v_rev_origin := null;

            v_rev_division := null;



        END;



        -- Se mapea la cuenta de la linea al formato BC - REV

        v_line_account := v_rev_accountno;

        v_line_company := v_rev_company;

        v_line_department := v_rev_department;

        v_line_destination := v_rev_destination;

        v_line_office := v_rev_office;

        v_line_origin := v_rev_origin;   

        v_line_division := v_rev_division;     



        v_line_number := v_line_number + 1;



        print_log ( 'v_line_company: ' || v_line_company );

        print_log ( 'v_line_account: ' || v_line_account );

        print_log ( 'v_line_department: ' || v_line_department );

        print_log ( 'v_line_destination: ' || v_line_destination );

        print_log ( 'v_line_office: ' || v_line_office );

        print_log ( 'v_line_origin: ' || v_line_origin );

        print_log ( 'v_line_division: ' || v_line_division );



        --

        v_rec_accountno := null;

        v_rec_company := null;

        v_rec_department := null;

        v_rec_destination := null;

        v_rec_office := null;

        v_rec_origin := null;

        v_rec_division := null;



        IF ( v_rec_acct_from_cust_flag = 'N' ) THEN



          v_rec_accountno := v_cm_gl_id_rec_accountno;

          v_rec_company := v_cm_gl_id_rec_company;

          v_rec_department := v_cm_gl_id_rec_department;

          v_rec_destination := v_cm_gl_id_rec_destination;

          v_rec_office := v_cm_gl_id_rec_office;

          v_rec_origin := v_cm_gl_id_rec_origin;

          v_rec_division := v_cm_gl_id_rec_division;



        END IF;



        IF ( v_rec_acct_from_cust_flag = 'Y' ) THEN



          IF ( v_bill_to_gl_id_rec IS NOT NULL ) THEN



            v_sql_stmt_id := 250;



            SELECT aba.bc_account,

                   ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'COMPANY',gcc.segment1) company,

                   ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'DEPARTMENT',gcc.segment3) department,

                   ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'DESTINATION',

                     DECODE(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                                       p_oracle_value => gcc.segment5,

                                                                       p_bc_dimension => 'OFFICE' ),NULL,gcc.segment5,'000') ) destination,

                   ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'OFFICE',

                     NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                                    p_oracle_value => gcc.segment5,

                                                                    p_bc_dimension => 'OFFICE'),'000') ) office,

                   ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'ORIGIN',gcc.segment6) origin,

                   ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'DIVISION',

                     NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4',

                                                                    p_oracle_value => gcc.segment4,

                                                                    p_bc_dimension => 'DIVISION'),'000') ) division

              INTO v_rec_accountno,

                   v_rec_company,

                   v_rec_department,

                   v_rec_destination,

                   v_rec_office,

                   v_rec_origin,

                   v_rec_division

              FROM gl_code_combinations gcc,

                   ajc_bc_accounts aba

             WHERE gcc.code_combination_id = v_bill_to_gl_id_rec

               AND gcc.segment2 = aba.oracle_account;



          END IF;



        END IF;



        -- Se mapea la cuenta de la cabecera al formato BC - REC

        v_header_account := v_rec_accountno;

        v_header_company := v_rec_company;

        v_header_department := v_rec_department;

        v_header_destination := v_rec_destination;

        v_header_office := v_rec_office;   

        v_header_origin := v_rec_origin;

        v_header_division := v_rec_division;



        print_log ( 'v_header_account: ' || v_header_account );

        print_log ( 'v_header_company: ' || v_header_company );

        print_log ( 'v_header_department: ' || v_header_department );

        print_log ( 'v_header_destination: ' || v_header_destination );

        print_log ( 'v_header_office: ' || v_header_office );

        print_log ( 'v_header_origin: ' || v_header_origin );

        print_log ( 'v_header_division: ' || v_header_division );



        -- Insert a record into ajcl_bc_ies_ar_lines for no invoice match - BC

        IF ( ( v_bc_transactionno IS NULL AND v_bc_billtocustomerno IS NULL AND v_match = 'BC' ) OR 

             ( v_oracle_customer_trx_id IS NULL AND v_match = 'ORACLE' ) ) THEN



          v_sql_stmt_id := 230;

          print_log ( 'INSERT ajcl_bc_ies_ar_lines (2).');



          -- No se generan ni envian las lineas en 0, porque BC las rechaza

          IF ( TO_NUMBER(ies_cm_line_row.charge_amount,'999999.99') != 0 ) THEN



            INSERT 

              INTO ajcl_bc_ies_ar_lines

                 ( bc_environment,

                   billToCustomerId,

                   billToCustomerName,

                   billToCustomerNo,

                   billToAddress1,

                   billToAddress2,

                   billToAddress3,

                   transactionNo,

                   class,

                   transactionDate,

                   glDate,

                   termName,

                   termdueDate,

                   lineNo,

                   description,

                   invoiceCurrencyCode,

                   exchangeRateType,

                   exchangeDate,

                   exchangeRate,

                   quantity,

                   unitSellingPrice,

                   extendedAmount,

                   accountedAmount,

                   header_company,

                   header_account,

                   header_department,

                   header_destination,

                   header_office,

                   header_origin,

                   header_worksheet,

                   header_division,

                   line_company,

                   line_account,

                   line_department,

                   line_destination,

                   line_office,

                   line_origin,

                   line_division,

                   line_worksheet, 

                   dff_invoice_company,

                   dff_invoice_number,

                   dff_invoice_line,

                   dff_ies_number,

                   dff_pickup_date,

                   dff_etd,

                   dff_eta,

                   dff_destination,

                   dff_origin,

                   financial_party,

                   org_id,

                   request_id,

                   creation_date,

                   created_by,

                   last_update_date,

                   last_updated_by,

                   status,

                   error_message )

          VALUES ( gv_bc_environment,

                   v_customer_id,

                   v_bill_to_customer_name,

                   v_bill_to_customer_no,

                   v_bill_to_address1,

                   v_bill_to_address2,

                   v_bill_to_address3,

                   ies_cm_line_row.invoice_number, -- trx_number

                   'CM', -- class

                   TO_CHAR(TO_DATE(ies_cm_line_row.accounting_date,'YYYY-MM-DD'),'YYYY-MM-DD'), -- trx_date

                   TO_CHAR(NVL(gv_gl_date,TO_DATE(ies_cm_line_row.accounting_date,'YYYY-MM-DD')),'YYYY-MM-DD'), -- gl_date

                   NULL, -- term_name

                   TO_CHAR(TO_DATE(ies_cm_line_row.due_date,'YYYY-MM-DD'),'YYYY-MM-DD'),

                   v_line_number, -- line_number

                   v_charge_type_code || '.' || trim(ies_cm_line_row.business_line) || ';' || ies_cm_line_row.description, -- description

                   ies_cm_line_row.currency_code, -- currency_code

                   'User', -- conversion_type

                   NULL, -- conversion_date

                   1, -- conversion_rate

                   1, -- quantity

                   ABS(TO_NUMBER(ies_cm_line_row.charge_amount,'999999.99')), -- unit_selling_price,

                   ABS(TO_NUMBER(ies_cm_line_row.charge_amount,'999999.99')), -- extended_amount

                   ABS(TO_NUMBER(ies_cm_line_row.charge_amount,'999999.99')), -- accounted_amount,

                   v_header_company, 

                   v_header_account, 

                   v_header_department, 

                   v_header_destination, 

                   v_header_office, 

                   v_header_origin, 

                   ies_cm_line_row.reference_value_1, -- header_worksheet

                   v_header_division, -- header_division,

                   v_line_company, 

                   v_line_account, 

                   v_line_department, 

                   v_line_destination, 

                   v_line_office, 

                   v_line_origin, 

                   v_line_division,

                   ies_cm_line_row.reference_value_1, -- worksheet

                   ies_cm_line_row.company_number, -- dff_invoice_company

                   ies_cm_line_row.invoice_number, -- dff_invoice_number

                   v_line_number, -- dff_invoice_line

                   NVL(ies_cm_line_row.reference_value_1, ies_cm_line_row.invoice_number), -- dff_ies_number

                   ies_cm_line_row.due_date, -- dff_pickup_date

                   ies_cm_line_row.due_date, -- dff_etd

                   ies_cm_line_row.due_date, -- dff_eta

                   NVL(ies_cm_line_row.destination_country,'NOTINFILE'), -- dff_destination

                   NVL(ies_cm_line_row.origin_country,'NOTINFILE'), -- dff_origin

                   ies_cm_line_row.financial_party,

                   gv_org_id,

                   gv_request_id,

                   SYSDATE,

                   gv_user_id,

                   SYSDATE,

                   gv_user_id,

                   v_tbl_status,

                   v_error_msg );



            IF ( SQL%ROWCOUNT > 0 ) THEN



              print_log ( '1 no match credit memo line record inserted into ajcl_bc_ies_ar_lines.' );

              COMMIT;



            END IF;



          END IF;



        END IF;  



        -- Insert records into ajcl_bc_ies_ar_lines for invoice match - BC

        IF ( v_bc_transactionno IS NOT NULL AND 

             v_bc_billtocustomerno IS NOT NULL AND 

             v_match = 'BC' AND i = 1 ) THEN



          v_sql_stmt_id := 270;

          print_log ( 'INSERT ajcl_bc_ies_ar_lines (3).');



          INSERT

            INTO ajcl_bc_ies_ar_lines 

               ( bc_environment,

                 billToCustomerId,

                 billToCustomerName,

                 billToCustomerNo,

                 billToAddress1,

                 billToAddress2,

                 billToAddress3,

                 transactionNo,

                 class,

                 transactionDate,

                 glDate,

                 termName,

                 termDueDate,

                 lineNo,

                 description,

                 invoiceCurrencyCode,

                 exchangeRateType,

                 exchangeDate,

                 exchangeRate,

                 quantity,

                 unitSellingPrice,

                 extendedAmount,

                 accountedAmount,

                 header_company,

                 header_account,

                 header_department,

                 header_destination,

                 header_office,

                 header_origin,                 

                 header_worksheet,

                 header_division,

                 line_company,

                 line_account,

                 line_department,

                 line_destination,

                 line_office,

                 line_origin,                 

                 line_division,

                 line_worksheet,

                 dff_invoice_company,

                 dff_invoice_number,

                 dff_invoice_line,

                 dff_ies_number,

                 dff_pickup_date,

                 dff_etd,

                 dff_eta,

                 dff_destination,

                 dff_origin,

                 appliesToDocType,

                 appliesToDocNo,

                 financial_party,

                 org_id,

                 request_id,

                 creation_date,

                 created_by,

                 last_update_date,

                 last_updated_by,

                 status )

          SELECT gv_bc_environment,

                 v_customer_id,

                 v_bill_to_customer_name,

                 v_bill_to_customer_no,

                 v_bill_to_address1,

                 v_bill_to_address2,

                 v_bill_to_address3,

                 ies_cm_line_row.invoice_number, -- trx_number

                 'CM', -- class

                 TO_CHAR(TO_DATE(ies_cm_line_row.accounting_date,'YYYY-MM-DD'),'YYYY-MM-DD'), -- trx_date

                 TO_CHAR(NVL(gv_gl_date,TO_DATE(ies_cm_line_row.accounting_date,'YYYY-MM-DD')),'YYYY-MM-DD'), -- gl_date

                 NULL, -- term_name

                 TO_CHAR(TO_DATE(ies_cm_line_row.due_date,'YYYY-MM-DD'),'YYYY-MM-DD'),

                 sdl.iesinvoiceline,

                 v_charge_type_code || '.' || TRIM(ies_cm_line_row.business_line) || ';' || ies_cm_line_row.description, -- description

                 ies_cm_line_row.currency_code, -- currency_code

                 'User', -- conversion_type

                 NULL, -- conversion_date

                 1, -- conversion_rate

                 1, -- quantity

                 -- -1 * 

                 ABS(sdl.amount), -- unit_selling_price, -- monto de la linea de la INV a la que machea

                 -- -1 * 

                 ABS(sdl.amount), -- extended_amount, -- monto de la linea de la INV a la que machea

                 -- -1 * 

                 ABS(sdl.amount), -- accounted_amount, -- monto de la linea de la INV a la que machea

                 sdh.company, -- company de la cabecera de la INV a la que machea

                 sdh.account, -- account de la cabecera de la INV a la que machea

                 sdh.department, -- department de la cabecera de la INV a la que machea

                 sdh.destination, -- destination de la cabecera de la INV a la que machea

                 sdh.office, -- office de la cabecera de la INV a la que machea

                 sdh.origin, -- origin de la cabecera de la INV a la que machea

                 sdh.worksheetno, -- worksheet de la cabecera de la INV a la que machea

                 sdh.division, -- division de la cabecera de la INV a la que machea

                 sdl.company, -- company de la linea de la INV a la que machea

                 sdl.account, -- account de la linea de la INV a la que machea

                 sdl.department, -- department de la linea de la INV a la que machea

                 sdl.destination, -- destination de la linea de la INV a la que machea

                 sdl.office, -- office de la linea de la INV a la que machea

                 sdl.origin, -- origin de la linea de la INV a la que machea

                 sdl.division, -- division de la linea de la INV a la que machea

                 ies_cm_line_row.reference_value_1, -- worksheet

                 ies_cm_line_row.company_number, -- dff_invoice_company

                 ies_cm_line_row.invoice_number, -- dff_invoice_number

                 sdl.iesinvoiceline, 

                 NVL(ies_cm_line_row.reference_value_1, ies_cm_line_row.invoice_number), -- dff_ies_number

                 ies_cm_line_row.due_date, -- dff_pickup_date

                 ies_cm_line_row.due_date, -- dff_etd

                 ies_cm_line_row.due_date, -- dff_eta

                 NVL(ies_cm_line_row.destination_country,'NOTINFILE'), -- dff_destination

                 NVL(ies_cm_line_row.origin_country,'NOTINFILE'), -- dff_origin

                 'Invoice', -- applies_to_doc_type

                 v_bc_transactionno, -- applies_to_doc_no

                 ies_cm_line_row.financial_party,

                 gv_org_id,

                 gv_request_id,

                 SYSDATE,

                 gv_user_id,

                 SYSDATE,

                 gv_user_id,

                 'NEW' 

            FROM ajcl_bc_posted_sd_headers sdh,

                 ajcl_bc_posted_sd_lines sdl

           WHERE sdh.bc_environment = gv_bc_environment

             AND sdh.transactionno = v_bc_transactionno

             AND sdh.billtocustomerno = v_bc_billtocustomerno

             AND sdh.transactionno = sdl.transactionno

             AND sdl.bc_environment = gv_bc_environment

             AND sdh.billtocustomerno = sdl.billtocustomerno

             AND sdl.amount != 0; -- No se generan ni envian las lineas en 0, porque BC las rechaza



          COMMIT;



        END IF;



        IF ( v_oracle_customer_trx_id IS NOT NULL AND 

             v_match = 'ORACLE' AND i = 1 ) THEN



          v_sql_stmt_id := 270;

          print_log ( 'INSERT ajcl_bc_ies_ar_lines (4).');

          print_log ( 'v_oracle_customer_trx_id: ' || v_oracle_customer_trx_id ); 

          print_log ( 'billToCustomerId: ' || v_customer_id );

          print_log ( 'ies_cm_line_row.invoice_number: ' || ies_cm_line_row.invoice_number );

          print_log ( 'ies_cm_line_row.accounting_date: ' || ies_cm_line_row.accounting_date );

          print_log ( 'ies_cm_line_row.due_date: ' || ies_cm_line_row.due_date );



          INSERT 

            INTO ajcl_bc_ies_ar_lines 

               ( bc_environment,

                 billToCustomerId,

                 billToCustomerName,

                 billToCustomerNo,

                 billToAddress1,

                 billToAddress2,

                 billToAddress3,

                 transactionNo,

                 class,

                 transactionDate,

                 glDate,

                 termName,

                 termDueDate,

                 lineNo,

                 description,

                 invoiceCurrencyCode,

                 exchangeRateType,

                 exchangeDate,

                 exchangeRate,

                 quantity,

                 unitSellingPrice,

                 extendedAmount,

                 accountedAmount,

                 header_company,

                 header_account,

                 header_department,

                 header_destination,

                 header_office,

                 header_origin,                 

                 header_division,

                 header_worksheet,

                 line_company,

                 line_account,

                 line_department,

                 line_destination,

                 line_office,

                 line_origin,                 

                 line_division,

                 line_worksheet,

                 dff_invoice_company,

                 dff_invoice_number,

                 dff_invoice_line,

                 dff_ies_number,

                 dff_pickup_date,

                 dff_etd,

                 dff_eta,

                 dff_destination,

                 dff_origin,

                 appliesToDocType,

                 appliesToDocNo,

                 financial_party,

                 org_id,

                 request_id,

                 creation_date,

                 created_by,

                 last_update_date,

                 last_updated_by,

                 status )

          SELECT gv_bc_environment,

                 v_customer_id billToCustomerId, 

                 v_bill_to_customer_name billToCustomerName, 

                 v_bill_to_customer_no billToCustomerNo, 

                 v_bill_to_address1 billToAddress1, 

                 v_bill_to_address2 billToAddress2, 

                 v_bill_to_address3 billToAddress3, 

                 ies_cm_line_row.invoice_number transactionNo, 

                 'CM' class,

                 ies_cm_line_row.accounting_date transactionDate, 

                 TO_CHAR(NVL(gv_gl_date,TO_DATE(ies_cm_line_row.accounting_date,'YYYY-MM-DD')),'YYYY-MM-DD') glDate, 

                 NULL termName,

                 ies_cm_line_row.due_date termDueDate, 

                 -- rctl.customer_trx_line_id lineNo, 

                 rctl.line_number lineNo, 

                 v_charge_type_code || '.' || TRIM(ies_cm_line_row.business_line) || ';' || ies_cm_line_row.description description, 

                 ies_cm_line_row.currency_code invoiceCurrencyCode,

                 'User' exchangeRateType,

                 NULL exchangeDate,

                 1 exchangeRate,  

                 1 quantity,  

                 ABS(rctl.extended_amount) unitSellingPrice, 

                 ABS(rctl.extended_amount) extendedAmount, 

                 ABS(rctl.extended_amount) accountedAmount, 

                 -- Header

                 ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba_h.bc_account,'COMPANY',gcc_h.segment1) header_company,

                 aba_h.bc_account header_account,

                 ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba_h.bc_account,'DEPARTMENT',gcc_h.segment3) header_department,

                 ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba_h.bc_account,'DESTINATION',

                   DECODE(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                                     p_oracle_value => gcc_h.segment5,

                                                                     p_bc_dimension => 'OFFICE' ),NULL,gcc_h.segment5,'000') ) header_destination,

                 ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba_h.bc_account,'OFFICE',

                   NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                                  p_oracle_value => gcc_h.segment5,

                                                                  p_bc_dimension => 'OFFICE'),'000') ) header_office,

                 ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba_h.bc_account,'ORIGIN',gcc_h.segment6) header_origin,

                 ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba_h.bc_account,'DIVISION',

                   NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4',

                                                                  p_oracle_value => gcc_h.segment4,

                                                                  p_bc_dimension => 'DIVISION'),'000') ) header_division,                                                                              

                 ies_cm_line_row.reference_value_1 header_worksheet,

                 -- Line

                 ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba_l.bc_account,'COMPANY',gcc_l.segment1) line_company,

                 aba_l.bc_account line_account,

                 ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba_l.bc_account,'DEPARTMENT',gcc_l.segment3) line_department,

                 ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba_l.bc_account,'DESTINATION',

                   DECODE(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                                     p_oracle_value => gcc_l.segment5,

                                                                     p_bc_dimension => 'OFFICE' ),NULL,gcc_l.segment5,'000') ) line_destination,

                 ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba_l.bc_account,'OFFICE',

                   NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                                  p_oracle_value => gcc_l.segment5,

                                                                  p_bc_dimension => 'OFFICE'),'000') ) line_office,

                 ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba_l.bc_account,'ORIGIN',gcc_l.segment6) line_origin,

                 ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba_l.bc_account,'DIVISION',

                   NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4',

                                                                  p_oracle_value => gcc_l.segment4,

                                                                  p_bc_dimension => 'DIVISION'),'000') ) line_division,                                                                              

                 ies_cm_line_row.reference_value_1 line_worksheet,

                 -- 

                 ies_cm_line_row.company_number, -- dff_invoice_company

                 ies_cm_line_row.invoice_number, -- dff_invoice_number,

                 -- rctl.customer_trx_line_id, -- dff_invoice_line,

                 rctl.line_number, -- dff_invoice_line,

                 nvl(ies_cm_line_row.reference_value_1, ies_cm_line_row.invoice_number), -- dff_ies_number,

                 ies_cm_line_row.due_date, -- dff_pickup_date,

                 ies_cm_line_row.due_date, -- dff_etd,

                 ies_cm_line_row.due_date, -- dff_eta,

                 NVL(ies_cm_line_row.destination_country,'NOTINFILE'), -- dff_destination,

                 NVL(ies_cm_line_row.origin_country,'NOTINFILE'), -- dff_origin,

                 ( SELECT DECODE(ctt.type,'INV','Invoice',ctt.type)

                     FROM ra_customer_trx_all h,

                          ra_cust_trx_types_all ctt

                    WHERE h.trx_number = rctl.interface_line_attribute2

                      AND h.interface_header_context = rctl.interface_line_context

                      AND h.set_of_books_id = rctl.set_of_books_id

                      AND h.org_id = rctl.org_id

                      AND h.bill_to_customer_id = rct.bill_to_customer_id

                      AND h.cust_trx_type_id = ctt.cust_trx_type_id ) appliesToDocType,

                 rctl.interface_line_attribute2 appliesToDocNo,

                 ies_cm_line_row.financial_party,

                 gv_org_id org_id,

                 gv_request_id request_id,

                 SYSDATE creation_date,

                 gv_user_id created_by,

                 SYSDATE last_update_date,

                 gv_user_id last_updated_by,

                 'NEW' status

            FROM ra_customer_trx_all rct,

                 ra_customer_trx_lines_all rctl,

                 --

                 ra_cust_trx_line_gl_dist_all rctd_h,

                 gl_code_combinations gcc_h,

                 ajc_bc_accounts aba_h,

                 --

                 ra_cust_trx_line_gl_dist_all rctd_l,

                 gl_code_combinations gcc_l,

                 ajc_bc_accounts aba_l

           WHERE rct.customer_trx_id = v_oracle_customer_trx_id

             AND rct.org_id = gv_org_id

             AND rct.customer_trx_id = rctd_h.customer_trx_id

             AND rct.org_id = rctd_h.org_id

             AND rctd_h.account_class = 'REC'

             AND rctd_h.code_combination_id = gcc_h.code_combination_id

             AND gcc_h.segment2 = aba_h.oracle_account (+)

             --

             AND rctl.extended_amount != 0 -- No se generan ni envian las lineas en 0, porque BC las rechaza

             --

             AND rct.customer_trx_id = rctl.customer_trx_id

             AND rct.org_id = rctl.org_id

             AND rctl.customer_trx_line_id = rctd_l.customer_trx_line_id

             AND rctl.org_id = rctd_l.org_id

             AND rctd_l.account_class = 'REV'

             AND rctd_l.code_combination_id = gcc_l.code_combination_id

             AND gcc_l.segment2 = aba_l.oracle_account (+);



          COMMIT;



        END IF;



        IF ( SQL%ROWCOUNT > 0 ) THEN



          print_log ( '1 matched credit memo line record inserted into ajcl_bc_ies_ar_lines.' );



        END IF;



        v_sql_stmt_id := 300;



        UPDATE ajc_ar_ies_inbound_data

           SET interface_status = 'TRANSFERRED'

         WHERE rowid = ies_cm_line_row.inbound_rowid;



      END LOOP; -- ies_cm_line_row



    END LOOP; -- ies_cm_row



    print_log ( 'Before generating the headers, all lines of the receipts that have at least one line with ERROR are marked with ERROR.' );



    UPDATE ajcl_bc_ies_ar_lines a

       SET status = 'ERROR'

     WHERE request_id = gv_request_id

       AND bc_environment = gv_bc_environment

       AND transactionno IN ( SELECT transactionno 

                                FROM ajcl_bc_ies_ar_lines b 

                               WHERE b.request_id = a.request_id

                                 AND b.bc_environment = gv_bc_environment

                                 AND b.status = 'ERROR' );



    -- COMMIT;



    print_log ( 'Headers are generated from the inserted lines.' );



    FOR ch IN c_headers LOOP



        INSERT

          INTO ajcl_bc_ies_ar_headers

             ( bc_environment,

               billToCustomerId,

               billToCustomerName,

               billToCustomerNo,

               billToAddress1,

               billToAddress2,

               billToAddress3,

               transactionNo,

               class,

               transactionDate,

               glDate,

               termName,

               termDueDate,

               invoiceCurrencyCode,

               exchangeRateType,

               exchangeDate,

               exchangeRate,

               amount,

               company,

               account,

               department,

               destination,

               office,

               origin,

               division,

               dff_invoice_company, 

               dff_invoice_number, 

               dff_ies_number, 

               worksheetNo,

               appliesToDocType,

               appliesToDocNo,

               financial_party,

               org_id,

               request_id,

               creation_date,

               created_by,

               last_update_date,

               last_updated_by,

               status )

      VALUES ( gv_bc_environment,

               ch.billToCustomerId,

               ch.billToCustomerName,

               ch.billToCustomerNo,

               ch.billToAddress1,

               ch.billToAddress2,

               ch.billToAddress3,

               ch.transactionNo,

               ch.class,

               ch.transactionDate,

               ch.glDate,

               ch.termName,

               ch.termDueDate,

               ch.invoiceCurrencyCode,

               ch.exchangeRateType,

               ch.exchangeDate,

               ch.exchangeRate,

               ch.amount,

               ch.company,

               ch.account,

               ch.department,

               ch.destination,

               ch.office,

               ch.origin,

               ch.division,

               ch.dff_invoice_company, 

               ch.dff_invoice_number, 

               ch.dff_ies_number,               

               ch.worksheetNo,

               ch.appliesToDocType,

               ch.appliesToDocNo,

               ch.financial_party,

               gv_org_id,

               gv_request_id,

               SYSDATE, -- creation_date

               gv_user_id,

               SYSDATE, -- last_update_date

               gv_user_id,

               ch.status );



    END LOOP;



    p_status := 'S';

    print_log ( 'ajcl_bc_ies_ar_pkg.insert_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log ( 'ajcl_bc_ies_ar_pkg.insert_p (!). Error: ' || SQLERRM );



  END insert_p;



  PROCEDURE call_ws ( p_status        OUT   VARCHAR2,

                      p_trx_count     OUT   NUMBER,

                      p_lines_count   OUT   NUMBER ) IS



      CURSOR c_headers_reprocess IS

      SELECT *

        FROM ajcl_bc_ies_ar_headers h

       WHERE bc_environment = gv_bc_environment

         AND ( ( request_id != gv_request_id AND status = 'ERROR' AND NOT EXISTS ( SELECT 1 

                                                                                     FROM ajcl_bc_ies_ar_lines l 

                                                                                    WHERE h.transactionno = l.transactionno 

                                                                                      AND h.class = l.class

                                                                                      AND NVL(h.billtocustomerno,-1) = NVL(l.billtocustomerno,-1)

                                                                                      AND h.request_id = l.request_id

                                                                                      AND l.bc_environment = h.bc_environment

                                                                                      AND UPPER(l.error_message) LIKE UPPER('%Line%already%exists%') ) ) OR

               ( request_id != gv_request_id AND status NOT IN ('SUCCESS','ERROR') ) ); 



      CURSOR c_headers IS

      SELECT *

        FROM ajcl_bc_ies_ar_headers

       WHERE bc_environment = gv_bc_environment

         AND request_id = gv_request_id 

         AND status = 'NEW'

    ORDER BY transactionNo;            



      CURSOR c_lines ( pc_transactionNo         IN   VARCHAR2,

                       pc_billToCustomerId      IN   NUMBER,

                       pc_class                 IN   VARCHAR2 ) IS

      SELECT *

        FROM ajcl_bc_ies_ar_lines

       WHERE transactionNo = pc_transactionNo

         AND NVL(billToCustomerId,-1) = NVL(pc_billToCustomerId,-1)

         AND class = pc_class

         AND bc_environment = gv_bc_environment

         AND request_id = gv_request_id 

         AND status = 'NEW'

    ORDER BY lineNo;



    v_status                      VARCHAR2(1);



    v_url_header                  VARCHAR2(2000);

    v_body_header                 CLOB;

    v_clob_result_header          CLOB;



    v_url_line                    VARCHAR2(2000);

    v_body_line                   CLOB;

    v_clob_result_line            CLOB;



    v_tbl_status                  VARCHAR2(100);

    v_tbl_error_message           VARCHAR2(200);



    -- v_financial_party             ajc_ar_ies_inbound_data.financial_party%TYPE;

    v_customer_id                 NUMBER;

    v_rec_acct_from_cust_flag     VARCHAR2(1);

    v_bill_to_customer_name       VARCHAR2(50);

    v_bill_to_customer_no         VARCHAR2(20);

    v_bill_to_gl_id_rec           NUMBER;    

    v_bill_to_cust_acct_site_id   NUMBER;

    v_bill_to_address1            VARCHAR2(150);

    v_bill_to_address2            VARCHAR2(150);

    v_bill_to_address3            VARCHAR2(150);



    v_rec_accountno               VARCHAR2(10);

    v_rec_company                 VARCHAR2(10);

    v_rec_department              VARCHAR2(10);

    v_rec_destination             VARCHAR2(10);

    v_rec_office                  VARCHAR2(10);

    v_rec_origin                  VARCHAR2(10);

    v_rec_division                VARCHAR2(10);



    v_linea_con_error             VARCHAR2(1);

    v_error_message               VARCHAR2(2000);



  BEGIN



    print_log('ajcl_bc_ies_ar_pkg.call_ws (+)');



    print_log ('Headers are traversed to obtain the customer, address, company and account of the header in the reprocesses that failed because those data were not found (+)');



    FOR ch IN c_headers_reprocess LOOP



      v_tbl_status := 'NEW';

      v_tbl_error_message := NULL;



      -- Si el comprobante quedo sin customer en una ejecucion anterior, se trata de obtener nuevamente y se actualiza en las lineas y cabecera

      -- 20250507 

      -- Se comenta para siempre recalcular el customer

      -- IF ( ch.billtocustomerid IS NULL ) THEN

      -- 20250507 



        -- v_financial_party := NULL;

        v_customer_id := NULL;

        v_rec_acct_from_cust_flag := NULL;

        v_bill_to_customer_name := NULL;

        v_bill_to_customer_no := NULL;



        BEGIN



          /* Se agrego que el financial_party se guarde en las tablas ajcl_bc_ies_ar_lines y ajcl_bc_ies_ar_headers para no tener que ir a buscarlo

          -- a la tabla de origen en los reprocesos

          BEGIN



              -- Se obtiene el financial party original

              SELECT financial_party 

                INTO v_financial_party

                FROM ajc_ar_ies_inbound_data

               WHERE invoice_number = ch.transactionNo

            GROUP BY financial_party;



            print_log ( 'v_financial_party: ' || v_financial_party );



          EXCEPTION

            WHEN OTHERS THEN

              NULL;



          END;

          */



          -- IF ( v_financial_party IS NOT NULL ) THEN

          IF ( ch.financial_party IS NOT NULL ) THEN



            BEGIN



              SELECT hca.cust_account_id, 

                     NVL(hca.attribute7,'N'),

                     rc.customer_name,

                     rc.customer_number

                INTO v_customer_id, 

                     v_rec_acct_from_cust_flag,

                     v_bill_to_customer_name,

                     v_bill_to_customer_no

                FROM hz_cust_accounts_all hca,

                     ra_customers rc

               -- WHERE TRIM(UPPER(hca.attribute6)) = TRIM(UPPER(v_financial_party))

               WHERE TRIM(UPPER(hca.attribute6)) = TRIM(UPPER(ch.financial_party))

                 AND hca.cust_account_id = rc.customer_id;



              print_log ( 'v_customer_id: ' || v_customer_id );

              print_log ( 'v_rec_acct_from_cust_flag: ' || v_rec_acct_from_cust_flag );

              print_log ( 'v_bill_to_customer_name: ' || v_bill_to_customer_name );

              print_log ( 'v_bill_to_customer_no: ' || v_bill_to_customer_no );



            EXCEPTION

              WHEN NO_DATA_FOUND THEN

                v_tbl_status := 'ERROR';

                -- v_tbl_error_message := 'Could not retrieve customer for financial party ' || TRIM(UPPER(v_financial_party));

                v_tbl_error_message := 'Could not retrieve customer for financial party ' || TRIM(UPPER(ch.financial_party));

                print_log ( v_tbl_error_message );

              WHEN OTHERS THEN

                v_tbl_status := 'ERROR';

                -- v_tbl_error_message := 'Error retrieving customer for financial party ' || TRIM(UPPER(v_financial_party)) || ' - ' || SQLERRM;

                v_tbl_error_message := 'Error retrieving customer for financial party ' || TRIM(UPPER(ch.financial_party)) || ' - ' || SQLERRM;

                print_log ( v_tbl_error_message );

                v_rec_acct_from_cust_flag := 'N';



            END;



            -- Get the bill to cust acct site id 

            v_bill_to_cust_acct_site_id := NULL;

            v_bill_to_gl_id_rec := NULL;

            v_bill_to_address1 := NULL;

            v_bill_to_address2 := NULL;

            v_bill_to_address3 := NULL;



            BEGIN



              SELECT hcas.cust_acct_site_id, 

                     hcsu.gl_id_rec,

                     SUBSTR(hl.address1,1,100) billToAddress1,

                     SUBSTR(hl.address2,1,50) billToAddress2,

                     SUBSTR(hl.address3,1,50) billToAddress3

                INTO v_bill_to_cust_acct_site_id, 

                     v_bill_to_gl_id_rec,

                     v_bill_to_address1,

                     v_bill_to_address2,

                     v_bill_to_address3

                FROM hz_cust_accounts_all hca, 

                     hz_cust_acct_sites_all hcas, 

                     hz_cust_site_uses_all hcsu,

                     hz_party_sites ps,

                     hz_locations hl

               -- WHERE TRIM(UPPER(hca.attribute6)) = TRIM(UPPER(v_financial_party))

               WHERE TRIM(UPPER(hca.attribute6)) = TRIM(UPPER(ch.financial_party))

                 AND hcas.cust_account_id = hca.cust_account_id

                 AND hcas.org_id = gv_org_id

                 AND hcsu.org_id = gv_org_id

                 AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id

                 AND hcsu.status = 'A'

                 AND hcsu.primary_flag = 'Y'

                 AND hcsu.site_use_code = 'BILL_TO'

                 AND hcas.party_site_id = ps.party_site_id

                 AND ps.location_id = hl.location_id;



            EXCEPTION

              WHEN NO_DATA_FOUND THEN

                v_tbl_status := 'ERROR';

                -- v_tbl_error_message := 'Could not retrieve bill to site for financial party ' || v_financial_party;

                v_tbl_error_message := 'Could not retrieve bill to site for financial party ' || ch.financial_party;

                print_log ( v_tbl_error_message );

              WHEN OTHERS THEN

                v_tbl_status := 'ERROR';

                -- v_tbl_error_message := 'Error retrieving bill to site for financial party ' || v_financial_party || ' - ERROR: ' || SQLERRM;

                v_tbl_error_message := 'Error retrieving bill to site for financial party ' || ch.financial_party || ' - ERROR: ' || SQLERRM;

                print_log ( v_tbl_error_message );



            END;



          END IF; -- v_financial_party IS NOT NULL



          IF ( v_rec_acct_from_cust_flag = 'N' ) THEN



            SELECT b.segment1,

                   aba.bc_account

              INTO v_rec_company,

                   v_rec_accountno

              FROM ra_cust_trx_types_all a, 

                   gl_code_combinations b,

                   ajc_bc_accounts aba

             WHERE a.org_id = gv_org_id

               AND a.name = 'IES INVOICE' 

               AND a.gl_id_rec = b.code_combination_id

               AND b.segment2 = aba.oracle_account;          



          ELSIF ( v_rec_acct_from_cust_flag = 'Y' ) THEN



            IF ( v_bill_to_gl_id_rec IS NOT NULL ) THEN



              SELECT aba.bc_account,

                     ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'COMPANY',gcc.segment1) company,

                     ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'DEPARTMENT',gcc.segment3) department,

                     ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'DESTINATION',

                       DECODE(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                                         p_oracle_value => gcc.segment5,

                                                                         p_bc_dimension => 'OFFICE' ),NULL,gcc.segment5,'000') ) destination,

                     ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'OFFICE',

                       NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                                      p_oracle_value => gcc.segment5,

                                                                      p_bc_dimension => 'OFFICE'),'000') ) office,

                     ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'ORIGIN',gcc.segment6) origin,

                     ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'DIVISION',

                       NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4',

                                                                      p_oracle_value => gcc.segment4,

                                                                      p_bc_dimension => 'DIVISION'),'000') ) division

                INTO v_rec_accountno,

                     v_rec_company,

                     v_rec_department,

                     v_rec_destination,

                     v_rec_office, 

                     v_rec_origin,

                     v_rec_division

                FROM gl_code_combinations gcc,

                     ajc_bc_accounts aba

               WHERE gcc.code_combination_id = v_bill_to_gl_id_rec

                 AND gcc.segment2 = aba.oracle_account;



              print_log ( 'v_rec_company: ' || v_rec_company );

              print_log ( 'v_rec_accountno: ' || v_rec_accountno );

              print_log ( 'v_rec_department: ' || v_rec_department );

              print_log ( 'v_rec_destination: ' || v_rec_destination );

              print_log ( 'v_rec_office: ' || v_rec_office );

              print_log ( 'v_rec_origin: ' || v_rec_origin );

              print_log ( 'v_rec_division: ' || v_rec_division );



            END IF; -- v_bill_to_gl_id_rec IS NOT NULL



          END IF; -- v_rec_acct_from_cust_flag



          UPDATE ajcl_bc_ies_ar_headers

             SET billToCustomerId = v_customer_id,

                 billToCustomerName = v_bill_to_customer_name,

                 billToCustomerNo = v_bill_to_customer_no,

                 billToAddress1 = v_bill_to_address1,

                 billToAddress2 = v_bill_to_address2,

                 billToAddress3 = v_bill_to_address3,

                 company = v_rec_company,

                 account = v_rec_accountno,

                 department = v_rec_department,

                 office = v_rec_office,

                 origin = v_rec_origin,

                 division = v_rec_division

           WHERE bc_environment = gv_bc_environment

             AND transactionno = ch.transactionno

             AND class = ch.class

             AND request_id = ch.request_id;



          UPDATE ajcl_bc_ies_ar_lines

             SET billToCustomerId = v_customer_id,

                 billToCustomerName = v_bill_to_customer_name,

                 billToCustomerNo = v_bill_to_customer_no,

                 billToAddress1 = v_bill_to_address1,

                 billToAddress2 = v_bill_to_address2,

                 billToAddress3 = v_bill_to_address3,

                 header_company = v_rec_company,

                 header_account = v_rec_accountno,

                 header_department = v_rec_department,

                 header_office = v_rec_office,

                 header_origin = v_rec_origin,

                 header_division = v_rec_division

           WHERE bc_environment = gv_bc_environment

             AND transactionno = ch.transactionno

             AND class = ch.class

             AND request_id = ch.request_id;



        EXCEPTION

          WHEN OTHERS THEN

            NULL;



        END;



      -- 20250507 

      -- END IF; -- ch.billtocustomerid IS NULL

      -- 20250507 



      UPDATE ajcl_bc_ies_ar_headers

         SET -- Se ponen estos valores para que lo levante el proceso

             request_id = gv_request_id,

             status = v_tbl_status,

             error_message = v_tbl_error_message,

             --

             reprocess = 'Y'

       WHERE bc_environment = gv_bc_environment

         AND transactionno = ch.transactionno

         AND class = ch.class

         AND request_id = ch.request_id;



      UPDATE ajcl_bc_ies_ar_lines

         SET -- Se ponen estos valores para que lo levante el proceso

             request_id = gv_request_id,

             status = v_tbl_status,

             error_message = v_tbl_error_message

       WHERE bc_environment = gv_bc_environment

         AND transactionno = ch.transactionno

         AND class = ch.class

         AND request_id = ch.request_id;



    END LOOP;



    print_log ('Headers are traversed to obtain the customer, address, company and account of the header in the reprocesses that failed because those data were not found (-)');



    COMMIT;



    FOR ch IN c_headers LOOP



      print_log ('transactionNo: ' || ch.transactionNo);



      v_linea_con_error := 'N';



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



      FOR cl IN c_lines ( ch.transactionNo,

                          ch.billToCustomerId,

                          ch.class ) LOOP



        print_log ('lineNo: ' || cl.lineNo);



        -- Se arma la linea

        APEX_JSON.initialize_clob_output;

        APEX_JSON.open_object;

        APEX_JSON.write('requestID',gv_request_id);

        APEX_JSON.write('company',cl.line_company,TRUE);

        APEX_JSON.write('billToCustomerNo',ch.billToCustomerNo);

        APEX_JSON.write('transactionNo',cl.transactionNo);

        APEX_JSON.write('class',ch.class);

        APEX_JSON.write('lineNo',cl.lineNo);

        APEX_JSON.write('description',cl.description);

        APEX_JSON.write('quantity',cl.quantity);

        APEX_JSON.write('unitSellingPrice',cl.unitSellingPrice);

        APEX_JSON.write('extendedAmount',cl.extendedAmount);

        APEX_JSON.write('accountedAmount',cl.accountedAmount,true);

        APEX_JSON.write('account',cl.line_account);

        APEX_JSON.write('department',cl.line_department,TRUE);

        APEX_JSON.write('destination',cl.line_destination,TRUE);

        APEX_JSON.write('office',cl.line_office,TRUE);

        APEX_JSON.write('origin',cl.line_origin,TRUE);

        APEX_JSON.write('divisionLog',cl.line_division,TRUE);

        APEX_JSON.write('worksheetNo',cl.line_worksheet,TRUE);



        -- nuevos de logistics

        APEX_JSON.write('iesInvoiceLine',cl.dff_invoice_line,TRUE); 

        APEX_JSON.write('iesPickupDate',cl.dff_pickup_date,TRUE); 

        APEX_JSON.write('iesETD',cl.dff_etd,TRUE); 

        APEX_JSON.write('iesETA',cl.dff_eta,TRUE); 

        APEX_JSON.write('iesDestination',cl.dff_destination,TRUE); 

        APEX_JSON.write('iesOrigin',cl.dff_origin,TRUE);         



        APEX_JSON.close_object;



        v_body_line := APEX_JSON.get_clob_output;

        print_log('v_body_line: ' || v_body_line);  



        -- 20251106 REINTENTO

        gv_retry := 'N';



        BEGIN

        -- 20251106 REINTENTO



          v_clob_result_line := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_url_line),

                                                                           p_request_header_name1 => 'Content-Type',

                                                                           p_request_header_value1 => 'application/json',

                                                                           p_request_header_name2 => NULL,

                                                                           p_request_header_value2 => NULL,

                                                                           p_http_method => 'POST',

                                                                           p_body => v_body_line );



          -- 20251106 REINTENTO

          IF ( UPPER(v_clob_result_line) LIKE UPPER('%502 Bad Gateway%') ) THEN



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



          v_clob_result_line := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_url_line),

                                                                           p_request_header_name1 => 'Content-Type',

                                                                           p_request_header_value1 => 'application/json',

                                                                           p_request_header_name2 => NULL,

                                                                           p_request_header_value2 => NULL,

                                                                           p_http_method => 'POST',

                                                                           p_body => v_body_line );



        END IF;

        -- 20251106 REINTENTO



        print_log('v_clob_result_line: ' || v_clob_result_line);

        APEX_JSON.free_output;



        IF ( UPPER(v_clob_result_line) LIKE '%"ERROR":%' ) THEN



          print_log ( 'Error sending transaction line.' );



          v_error_message := -- 'An error occurred while sending the line: ' ||

                              SUBSTR(v_clob_result_line,INSTR(v_clob_result_line,'message') + 10);



          print_log(v_error_message);



          UPDATE ajcl_bc_ies_ar_lines

             SET status = 'ERROR',

                 error_message = v_error_message,

                 json_data = v_body_line,

                 json_data_response = v_clob_result_line,

                 request_id = gv_request_id

           WHERE transactionNo = ch.transactionNo

             AND lineNo = cl.lineNo

             AND request_id = cl.request_id

             AND bc_environment = gv_bc_environment;



          v_linea_con_error := 'Y';



        ELSE



          UPDATE ajcl_bc_ies_ar_lines

             SET status = 'SENT',

                 error_message = NULL,

                 json_data = v_body_line,

                 json_data_response = v_clob_result_line,

                 request_id = gv_request_id

           WHERE transactionNo = ch.transactionNo

             AND lineNo = cl.lineNo

             AND request_id = cl.request_id

             AND bc_environment = gv_bc_environment;



          print_log ( 'Line sent successfully.' );



        END IF;



        p_lines_count := NVL(p_lines_count,0) + 1;



      END LOOP;



      -- Si todas las lineas se enviaron sin problema

      IF ( v_linea_con_error = 'N' ) THEN



        v_error_message := NULL;



        -- Se envia la cabecera

        APEX_JSON.initialize_clob_output;

        APEX_JSON.open_object;



        APEX_JSON.write('company',ch.company,TRUE);

        APEX_JSON.write('transactionNo',ch.transactionNo);

        APEX_JSON.write('transactionDate',ch.transactionDate);

        APEX_JSON.write('class',ch.class);

        APEX_JSON.write('termName',ch.termName,true);

        APEX_JSON.write('termDueDate',ch.termDueDate);

        APEX_JSON.write('glDate',ch.glDate);

        APEX_JSON.write('invoiceCurrencyCode',ch.invoiceCurrencyCode);

        APEX_JSON.write('exchangeDate',ch.exchangeDate,true);

        APEX_JSON.write('exchangeRate',ch.exchangeRate,true);

        APEX_JSON.write('exchangeRateType',ch.exchangeRateType,true);

        APEX_JSON.write('amount',ch.amount);

        APEX_JSON.write('accountedAmount',ch.accountedAmount,true);

        APEX_JSON.write('account',ch.account,true);

        APEX_JSON.write('department',ch.department,TRUE);

        APEX_JSON.write('destination',ch.destination,TRUE);

        APEX_JSON.write('office',ch.office,TRUE);

        APEX_JSON.write('origin',ch.origin,TRUE);

        APEX_JSON.write('divisionLog',ch.division,TRUE);

        APEX_JSON.write('billToCustomerName',ch.billToCustomerName);

        APEX_JSON.write('billToCustomerNo',ch.billToCustomerNo);

        APEX_JSON.write('billToAddress1',ch.billToAddress1,true);

        APEX_JSON.write('billToAddress2',ch.billToAddress2,true);

        APEX_JSON.write('billToAddress3',ch.billToAddress3,true);

        APEX_JSON.write('requestID',gv_request_id);

        APEX_JSON.write('worksheetNo',ch.WorksheetNo,true);

        APEX_JSON.write('appliestoDocType',ch.AppliestoDocType,true);

        APEX_JSON.write('appliestoDocNo',ch.AppliestoDocNo,true);



        -- nuevos logistics

        APEX_JSON.write('source','IES');

        APEX_JSON.write('iesInvoiceCompany',ch.dff_invoice_company,true);

        APEX_JSON.write('iesInvoiceNumber',ch.dff_invoice_number,true);

        APEX_JSON.write('iesNumber',ch.dff_ies_number,true);

        --



        APEX_JSON.close_object;



        v_body_header := APEX_JSON.get_clob_output;



        print_log ( 'v_body_header: ' || v_body_header );



        -- 20251106 REINTENTO

        gv_retry := 'N';



        BEGIN

        -- 20251106 REINTENTO



          v_clob_result_header := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_url_header),

                                                                             p_request_header_name1 => 'Content-Type',

                                                                             p_request_header_value1 => 'application/json',

                                                                             p_request_header_name2 => NULL,

                                                                             p_request_header_value2 => NULL,

                                                                             p_http_method => 'POST',

                                                                             p_body => v_body_header );



          -- 20251106 REINTENTO

          IF ( UPPER(v_clob_result_header) LIKE UPPER('%502 Bad Gateway%') ) THEN



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



          v_clob_result_header := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_url_header),

                                                                             p_request_header_name1 => 'Content-Type',

                                                                             p_request_header_value1 => 'application/json',

                                                                             p_request_header_name2 => NULL,

                                                                             p_request_header_value2 => NULL,

                                                                             p_http_method => 'POST',

                                                                             p_body => v_body_header );



        END IF;

        -- 20251106 REINTENTO  



        print_log ( 'v_clob_result_header: ' || v_clob_result_header);

        APEX_JSON.free_output;



        IF ( UPPER(v_clob_result_header) LIKE '%"ERROR":%' ) THEN



          print_log ( 'Error sending transaction header.' );



          v_error_message := -- 'An error occurred while sending the header: ' ||

                              SUBSTR(v_clob_result_header,INSTR(v_clob_result_header,'message') + 10);



          print_log ( v_error_message );



          UPDATE ajcl_bc_ies_ar_headers

             SET status = 'ERROR',

                 error_message = v_error_message,

                 json_data = v_body_header,

                 json_data_response = v_clob_result_header,

                 request_id = gv_request_id

           WHERE transactionNo = ch.transactionNo

             AND request_id = ch.request_id

             AND bc_environment = gv_bc_environment;



        ELSE



          UPDATE ajcl_bc_ies_ar_headers

             SET status = 'SENT',

                 error_message = NULL,

                 json_data = v_body_header,

                 json_data_response = v_clob_result_header,

                 request_id = gv_request_id

           WHERE transactionNo = ch.transactionNo

             AND request_id = ch.request_id

             AND bc_environment = gv_bc_environment;



          print_log ( 'Header sent successfully.' );



        END IF;



        p_trx_count := NVL(p_trx_count,0) + 1;



      ELSE



        UPDATE ajcl_bc_ies_ar_headers

           SET status = 'ERROR',

               error_message = 'An error occurred on some line of the document',

               request_id = gv_request_id

         WHERE transactionNo = ch.transactionNo

           AND request_id = ch.request_id

           AND bc_environment = gv_bc_environment;



      END IF;



    END LOOP;



    p_status := 'S';

    print_log('ajcl_bc_ies_ar_pkg.call_ws (-)');



  EXCEPTION

    WHEN OTHERS THEN

      print_log('ajcl_bc_ies_ar_pkg.call_ws (!)');

      p_status := 'E';



  END call_ws;



  PROCEDURE call_job ( p_status   OUT   VARCHAR2 ) IS



    v_object_id       NUMBER;

    v_status          VARCHAR2(20);

    v_clob_response   CLOB;



  BEGIN



    print_log ('ajcl_bc_ies_ar_pkg.call_job (+)');



    v_object_id := ajcl_bc_ws_utils_pkg.get_object_id_f ( 'SALES DOCUMENTS' );

    print_log ('v_object_id: ' || v_object_id || ' - ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));



    v_clob_response := ajcl_bc_ws_utils_pkg.run_job_queue_f ( p_bc_environment => gv_bc_environment,

                                                              p_company_id => gv_bc_company_id,

                                                              p_object_id => v_object_id );



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

      INTO ajcl_bc_ies_ar_control

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

             SYSDATE );



    print_log ('ajcl_bc_ies_ar_pkg.call_job (-)');



  EXCEPTION    

    WHEN OTHERS THEN

      p_status := 'E';

      print_log ( 'Not caught error when calling Job, Error: ' || SQLERRM );

      print_log ('ajcl_bc_ies_ar_pkg.call_job (!)');



  END call_job;



  PROCEDURE delete_inbound_records ( p_transactionNo     IN   VARCHAR2,

                                     p_billToCustomerNo  IN   VARCHAR2,

                                     p_class             IN   VARCHAR2 ) IS



    v_line_del_api      VARCHAR2(2000);

    v_line_del_url      VARCHAR2(2000);

    v_line_body         CLOB;

    v_line_del_clob     CLOB;



      CURSOR c_lines IS

      SELECT lineno

        FROM ajcl_bc_ies_ar_lines

       WHERE transactionNo = p_transactionNo

         AND billToCustomerNo = p_billToCustomerNo

         AND class = p_class

         AND request_id = gv_request_id

         AND bc_environment = gv_bc_environment

    ORDER BY lineno;



    v_header_del_api    VARCHAR2(2000);

    v_header_del_url    VARCHAR2(2000);

    v_header_body       CLOB;

    v_header_del_clob   CLOB;



  BEGIN



    print_log ('ajcl_bc_ies_ar_pkg.delete_inbound_records (+)');



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

      APEX_JSON.write('transactionNo',p_transactionNo);

      APEX_JSON.write('customerNo',p_billToCustomerNo);

      APEX_JSON.write('classType',p_class);

      APEX_JSON.write('lineNo',cl.lineno);

      APEX_JSON.close_object;



      v_line_body := APEX_JSON.get_clob_output;

      APEX_JSON.free_output;



      -- Se borra la linea de la tabla staging.

      v_line_del_clob := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_line_del_url),

                                                                    p_request_header_name1 => 'Content-Type',

                                                                    p_request_header_value1 => 'application/json',

                                                                    p_request_header_name2 => NULL,

                                                                    p_request_header_value2 => NULL,

                                                                    p_http_method => 'POST',

                                                                    p_body => v_line_body );



      IF ( INSTR(v_line_del_clob,'error') != 0 )  THEN



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

    APEX_JSON.write('transactionNo',p_transactionNo);

    APEX_JSON.write('customerNo',p_billToCustomerNo);

    APEX_JSON.write('classType',p_class);

    APEX_JSON.close_object;



    v_header_body := APEX_JSON.get_clob_output;

    APEX_JSON.free_output;



    -- Se borra cabecera de la tabla staging.

    v_header_del_clob := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_header_del_url),

                                                                    p_request_header_name1 => 'Content-Type',

                                                                    p_request_header_value1 => 'application/json',

                                                                    p_request_header_name2 => NULL,

                                                                    p_request_header_value2 => NULL,

                                                                    p_http_method => 'POST',

                                                                    p_body => v_header_body );



    IF ( INSTR(v_header_del_clob,'error') != 0 )  THEN



      print_log('Error when deleting header from BC stage table.');

      print_log(v_header_del_clob);



    ELSE



      print_log('Deleted header from BC stage table.');



    END IF;



    print_log ('ajcl_bc_ies_ar_pkg.delete_inbound_records (-)');



  END delete_inbound_records;



  PROCEDURE call_status ( p_status   OUT   VARCHAR2 ) IS



    v_status               VARCHAR2(1);

    v_error_message        VARCHAR2(2000);

    e_cust_exception       EXCEPTION;

    v_url                  VARCHAR2(2000);

    v_clob_result          CLOB;

    v_header_delete_clob   CLOB;

    v_lines_delete_clob    CLOB;



    v_cant_sin_procesar    NUMBER;

    v_stime                NUMBER;

    v_etime                NUMBER;



    CURSOR c_status ( p_clob_result_status   IN   CLOB ) IS

    SELECT company,

           transactionNo,

           transactionDate,

           billToCustomerNo,

           class,

           glDate,

           amount,

           status,

           statusRemarks,

           requestID

      FROM json_table( p_clob_result_status,

                       '$.value[*]' COLUMNS ( company           VARCHAR2(4000)  path '$.company',

                                              transactionNo     VARCHAR2(4000)  path '$.transactionNo',

                                              transactionDate   VARCHAR2(4000)  path '$.transactionDate',

                                              billToCustomerNo  VARCHAR2(4000)  path '$.billToCustomerNo',

                                              class             VARCHAR2(4000)  path '$.class',

                                              glDate            VARCHAR2(4000)  path '$.glDate',

                                              amount            VARCHAR2(4000)  path '$.amount',

                                              status            VARCHAR2(4000)  path '$.status',

                                              statusRemarks     VARCHAR2(4000)  path '$.statusRemarks',

                                              requestID         VARCHAR2(4000)  path '$.requestID' ) );



  BEGIN



    print_log ('ajcl_bc_ies_ar_pkg.call_status (+)');



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                          p_entity => 'INBOUND SALES DOC',

                                                          p_subentity => 'HEADERS',

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id )

             || '?$filter=requestID eq ' || TO_CHAR(gv_request_id);



    print_log ( 'v_url: ' || v_url );



    v_cant_sin_procesar := -1;



    -- seteo tiempo de inicio

    SELECT TO_NUMBER(((TO_CHAR(SYSDATE, 'J') - 1 ) * 86400) + TO_CHAR(SYSDATE, 'SSSSS'))

      INTO v_stime

      FROM DUAL;



    WHILE v_cant_sin_procesar <> 0 LOOP



      BEGIN



        -- 20251219 REINTENTO

        gv_retry := 'N';



        BEGIN

        -- 20251219 REINTENTO



          v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



          -- 20251219 REINTENTO

          IF ( UPPER(v_clob_result) LIKE UPPER('%502 Bad Gateway%') ) THEN



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



          v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



        END IF;

        -- 20251219 REINTENTO 



      EXCEPTION

        WHEN OTHERS THEN

          NULL;



      END;



      SELECT COUNT(1)

        INTO v_cant_sin_procesar

        FROM json_table( v_clob_result,

                         '$.value[*]' COLUMNS ( status      VARCHAR2(4000) path '$.status',

                                                requestid   VARCHAR2(4000) path '$.requestID'))

       WHERE requestid = gv_request_id

         AND status NOT IN ('Error','Success');



      print_log ( 'Number of not processed records: ' || v_cant_sin_procesar );



      IF v_cant_sin_procesar <> 0 THEN



        SELECT TO_NUMBER(((TO_CHAR(SYSDATE, 'J') - 1 ) * 86400) + TO_CHAR(SYSDATE, 'SSSSS'))

          INTO v_etime

          FROM DUAL;



        print_log ( 'v_etime: ' || v_etime );



        IF ( ( v_etime - v_stime ) >= 600 ) THEN



          print_log ( 'The wait for the job took more than 600 seconds. All records will be marked REJECTED.' );

          EXIT;



        END IF;



        print_log ( 'I wait 15 seconds.' );  

        DBMS_LOCK.sleep(15);



      END IF;



    END LOOP;



    print_log ( 'Status: ' );



    FOR cs IN c_status ( v_clob_result ) LOOP



      IF ( UPPER(cs.status) != 'SUCCESS' ) THEN



        print_log ( 'company: ' || cs.company || 

                    ' | transactionNo: ' || cs.transactionNo || 

                    ' | transactionDate: ' || cs.transactionDate ||

                    ' | billToCustomerNo: ' || cs.billToCustomerNo ||

                    ' | class: ' || cs.class ||

                    ' | glDate: ' || cs.glDate || 

                    ' | amount: ' || cs.amount || 

                    ' | status: ' || cs.status || 

                    ' | statusRemarks: ' || cs.statusRemarks);



        -- Se actualiza la tabla custom con el status REJECTED

        UPDATE ajcl_bc_ies_ar_headers

           SET status = 'REJECTED',

               error_message = cs.statusRemarks

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND transactionNo = cs.transactionNo;



        -- Se actualiza el status de sus lineas   

        UPDATE ajcl_bc_ies_ar_lines

           SET status = 'REJECTED'

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND transactionNo = cs.transactionNo;



        -- Se borra cabecera y lineas de las tablas inbound

        delete_inbound_records ( p_transactionNo => cs.transactionno,

                                 p_billToCustomerNo => cs.billToCustomerNo,

                                 p_class => cs.class );



      ELSE



        -- Se actualiza la tabla custom con el status IMPORTED

        UPDATE ajcl_bc_ies_ar_headers

           SET status = 'SUCCESS'

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND transactionno = cs.transactionno;



        -- Se actualizan sus lineas   

        UPDATE ajcl_bc_ies_ar_lines

           SET status = 'SUCCESS'

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND transactionno = cs.transactionno;



      END IF;



    END LOOP;



    p_status := 'S';



    print_log ('ajcl_bc_ies_ar_pkg.call_status (-)');   



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      print_log (v_error_message);

      print_log ('ajcl_bc_ies_ar_pkg.call_status (!)');



    WHEN others THEN

      p_status := 'E';

      print_log ( 'Not caught error when calling status. Error: ' || SQLERRM );

      print_log ('ajcl_bc_ies_ar_pkg.call_status (!)');



  END call_status;



  -- Inserta los worksheets a enviar a BC en la tabla AJCL_BC_WORKSHEETS

  -- y ejecuta el concurrente que los envia: AJCL BC Worksheets Interface

  PROCEDURE worksheets_to_bc_p ( p_status   IN OUT   VARCHAR2 ) IS



      CURSOR c_worksheets IS

      SELECT line_worksheet ws_ies_num

        FROM ajcl_bc_ies_ar_lines

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND line_worksheet IS NOT NULL

    GROUP BY line_worksheet;



    v_total_worksheets   NUMBER;

    e_error              EXCEPTION;



  BEGIN



    print_log( 'ajcl_bc_ies_ar_pkg.worksheets_to_bc_p (+)' );



    v_total_worksheets := 0;



    FOR cw IN c_worksheets LOOP



      v_total_worksheets := v_total_worksheets + ajcl_bc_worksheets_pkg.insert_p ( p_ws_ies_num => cw.ws_ies_num,

                                                                                   p_bc_environment => gv_bc_environment );



    END LOOP;



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

    print_log( 'ajcl_bc_ies_ar_pkg.worksheets_to_bc_p (-)' );



  EXCEPTION

    WHEN e_error THEN

      print_log( 'ajcl_bc_ies_ar_pkg.worksheets_to_bc_p (!)' );

      p_status := 'E';

    WHEN OTHERS THEN

      print_log( 'ajcl_bc_ies_ar_pkg.worksheets_to_bc_p (!)' );

      p_status := 'E';



  END worksheets_to_bc_p;



  PROCEDURE final_report_csv_p ( p_status   OUT   VARCHAR2 ) IS



      CURSOR c_invoices IS

      -- Armar SELECT que corresponda

      SELECT h.class,

             h.transactionNo,

             h.transactionDate,

             h.billToCustomerName,

             h.billToCustomerNo,

             h.invoiceCurrencyCode,

             TRIM(TO_CHAR(h.amount,'999,999,999.00')) amount,

             h.status h_status,

             h.error_message h_error_message,

             l.lineNo,

             l.description,

             TRIM(TO_CHAR(l.quantity,'999,999,999.00')) quantity,

             TRIM(TO_CHAR(l.unitSellingPrice,'999,999,999.00')) unitSellingPrice,

             TRIM(TO_CHAR(l.extendedAmount,'999,999,999.00')) extendedAmount,

             l.status l_status,

             l.error_message l_error_message

        FROM ajcl_bc_ies_ar_headers h,

             ajcl_bc_ies_ar_lines l

       WHERE h.request_id = gv_request_id

         AND h.bc_environment = gv_bc_environment

         AND h.request_id = l.request_id

         AND l.bc_environment = gv_bc_environment

         AND NVL(h.billToCustomerId,-1) = NVL(l.billToCustomerId,-1) -- Para que muestre los que dieron error del lado de Oracle

         AND h.transactionNo = l.transactionNo

         AND h.class = l.class

    ORDER BY h.billToCustomerName,

             h.transactionNo, 

             l.lineNo;



  BEGIN



    print_log( 'ajcl_bc_ies_ar_pkg.final_report_csv_p (+)' );



    -- Insert Report Title

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => gv_bc_ifc || ' Report',

                                        p_request_id => gv_request_id );

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Request ID|' || gv_request_id,

                                        p_request_id => gv_request_id ); 



    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Tabla -------------------------------------------------------------------------------------------------------------------                                    

    -- Insert Table Column Names                            

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Customer Name' || '|' ||

                                                  'Customer Number' || '|' ||

                                                  'Trx No.' || '|' ||

                                                  'Trx Date' || '|' ||

                                                  'Type' || '|' ||

                                                  'Currency' || '|' ||

                                                  'Trx Amount' || '|' ||

                                                  'Line No' || '|' ||

                                                  'Description' || '|' ||

                                                  'Quantity' || '|' ||

                                                  'Unit Price' || '|' ||

                                                  'Extended Amount' || '|' ||

                                                  'Trx Status' || '|' ||

                                                  'Trx Error' || '|' ||

                                                  'Line Status' || '|' ||

                                                  'Line Error',

                                        p_request_id => gv_request_id );  



    -- Se insertan los registros

    FOR ci IN c_invoices LOOP



      ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                          p_text => ci.billToCustomerName || '|' || 

                                                    ci.billToCustomerNo || '|' || 

                                                    ci.transactionNo || '|' || 

                                                    ci.transactionDate || '|' || 

                                                    ci.class || '|' || 

                                                    ci.invoiceCurrencyCode || '|' || 

                                                    ci.amount || '|' || 

                                                    ci.lineNo || '|' || 

                                                    ci.description || '|' || 

                                                    ci.quantity || '|' || 

                                                    ci.unitSellingPrice || '|' || 

                                                    ci.extendedAmount || '|' || 

                                                    ci.h_status || '|' || 

                                                    ci.h_error_message || '|' || 

                                                    ci.l_status || '|' || 

                                                    ci.l_error_message,

                                          p_request_id => gv_request_id );                                                          



    END LOOP;



    p_status := 'S';



    print_log( 'ajcl_bc_ies_ar_pkg.final_report_csv_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_ies_ar_pkg.final_report_csv_p (!). Error: ' || SQLERRM );



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



    print_log( 'ajcl_bc_ies_ar_pkg.final_output_xlsx_p (+)' );



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



    print_log( 'ajcl_bc_ies_ar_pkg.final_output_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_ies_ar_pkg.final_output_xlsx_p (!). Error: ' || SQLERRM );



  END final_output_xlsx_p;



  PROCEDURE final_report_xlsx_p ( p_status   OUT   VARCHAR2 ) IS



    c_cursor            SYS_REFCURSOR;



  BEGIN



    print_log( 'ajcl_bc_ies_ar_pkg.final_report_xlsx_p (+)' );



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



    -- Summary

        OPEN c_cursor FOR

    -- Muestra los totales de proceso y reproceso agrupados

    SELECT class, 

           status, 

           qty "COUNT"

      FROM ( SELECT 1 order_by,

                    class, 

                    UPPER(status) status, 

                    COUNT(1) qty

               FROM ajcl_bc_ies_ar_headers 

              WHERE request_id = gv_request_id

                AND reprocess IS NULL

           GROUP BY class, 

                    status

              UNION

             SELECT 2 order_by,

                    'Reprocess' class,

                    NULL status,

                    NULL qty

               FROM DUAL

              -- Solo se imprime este registros si hay al menos un comprobante reprocesado

              WHERE ( SELECT COUNT(1) 

                        FROM ajcl_bc_ies_ar_headers 

                       WHERE request_id = gv_request_id 

                         AND reprocess IS NOT NULL ) > 0

              UNION                

             SELECT 3 order_by,

                    class, 

                    UPPER(status) status, 

                    COUNT(1) qty

               FROM ajcl_bc_ies_ar_headers 

              WHERE request_id = gv_request_id

                AND reprocess IS NOT NULL

            GROUP BY class, 

                     status

            ORDER BY 1,2,3 DESC );



    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Summary',

                                       p_sheet => 2,

                                       p_cursor => c_cursor );



    -- Sales Documents

        OPEN c_cursor FOR

      SELECT h.class,

             h.transactionNo transaction_no,

             h.transactionDate transaction_date,

             h.gldate gl_date,

             h.billToCustomerName customer_name,

             h.billToCustomerNo customer_no,

             h.invoiceCurrencyCode currency_code,

             TRIM(TO_CHAR(h.amount,'999,999,999.00')) amount,

             h.appliesToDocType applies_to_doc_type,

             h.appliesToDocNo applies_to_doc_no,

             UPPER(h.status) header_status,

             h.error_message header_error_message,

             l.lineNo line_num,

             l.description,

             TRIM(TO_CHAR(l.quantity,'999,999,999.00')) quantity,

             TRIM(TO_CHAR(l.unitSellingPrice,'999,999,999.00')) unit_selling_price,

             TRIM(TO_CHAR(l.extendedAmount,'999,999,999.00')) extended_amount,

             UPPER(l.status) line_status,

             l.error_message line_error_message

        FROM ajcl_bc_ies_ar_headers h,

             ajcl_bc_ies_ar_lines l

       WHERE h.request_id = gv_request_id

         AND h.bc_environment = gv_bc_environment

         AND h.request_id = l.request_id (+)

         AND h.bc_environment = l.bc_environment (+)

         -- 20240917

         -- AND h.billToCustomerId = l.billToCustomerId (+) 

         AND NVL(h.billToCustomerId,-1) = NVL(l.billToCustomerId,-1)

         -- 20240917

         AND h.transactionNo = l.transactionNo (+)

         AND h.class = l.class (+)

         AND h.reprocess IS NULL

    ORDER BY h.billToCustomerName,

             h.transactionNo, 

             l.lineNo;



    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Sales Documents',

                                       p_sheet => 3,

                                       p_cursor => c_cursor );



    -- Reprocess

        OPEN c_cursor FOR

      SELECT h.class,

             h.transactionNo transaction_no,

             h.transactionDate transaction_date,

             h.gldate gl_date,

             h.billToCustomerName customer_name,

             h.billToCustomerNo customer_no,

             h.invoiceCurrencyCode currency_code,

             TRIM(TO_CHAR(h.amount,'999,999,999.00')) amount,

             h.appliesToDocType applies_to_doc_type,

             h.appliesToDocNo applies_to_doc_no,

             UPPER(h.status) header_status,

             h.error_message header_error_message,

             l.lineNo line_num,

             l.description,

             TRIM(TO_CHAR(l.quantity,'999,999,999.00')) quantity,

             TRIM(TO_CHAR(l.unitSellingPrice,'999,999,999.00')) unit_selling_price,

             TRIM(TO_CHAR(l.extendedAmount,'999,999,999.00')) extended_amount,

             UPPER(l.status) line_status,

             l.error_message line_error_message

        FROM ajcl_bc_ies_ar_headers h,

             ajcl_bc_ies_ar_lines l

       WHERE h.request_id = gv_request_id

         AND h.bc_environment = gv_bc_environment

         AND h.request_id = l.request_id (+)

         AND h.bc_environment = l.bc_environment (+)

         -- 20240917

         -- AND h.billToCustomerId = l.billToCustomerId (+) 

         AND NVL(h.billToCustomerId,-1) = NVL(l.billToCustomerId,-1)

         -- 20240917

         AND h.transactionNo = l.transactionNo (+)

         AND h.class = l.class (+)

         AND h.reprocess = 'Y'

    ORDER BY h.billToCustomerName,

             h.transactionNo, 

             l.lineNo;



    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Reprocess',

                                       p_sheet => 4,

                                       p_cursor => c_cursor );



    as_xlsx.save ( gv_directory_report, gv_report_filename || '.' || LOWER(gv_file_format) );



    p_status := 'S';



    print_log( 'ajcl_bc_ies_ar_pkg.final_report_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_ies_ar_pkg.final_report_xlsx_p (!). Error: ' || SQLERRM );



  END final_report_xlsx_p;



  -- 20241001

  -- FIX ACCOUNT 1110.1200

  PROCEDURE fix_dim_DATAMIG_inv_to_cm_p IS



    CURSOR c_lines IS

    SELECT l.rowid row_id,

           l.*

      FROM ajcl_bc_ies_ar_lines l

     WHERE class = 'CM'

       AND line_account = '1110.1200'

       AND bc_environment = gv_bc_environment

       AND request_id = gv_request_id

       AND status = 'NEW'

       AND appliestodocno IS NOT NULL;



    v_line_company                   VARCHAR2(10);

    v_line_account                   VARCHAR2(10);

    v_line_department                VARCHAR2(10);

    v_line_destination               VARCHAR2(10);

    v_line_office                    VARCHAR2(10);

    v_line_origin                    VARCHAR2(10);

    v_line_division                  VARCHAR2(10);



  BEGIN



    print_log('ajcl_bc_ies_ar_pkg.fix_dim_DATAMIG_inv_to_cm_p (+)');



    FOR cl IN c_lines LOOP



      v_line_company := NULL;

      v_line_account := NULL;

      v_line_department := NULL;

      v_line_destination := NULL;

      v_line_office := NULL;

      v_line_origin := NULL;

      v_line_division := NULL;



      BEGIN



        -- Se busca en Oracle el inv al que aplica la CM para obtener las dimensiones

        SELECT ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'COMPANY',gcc.segment1) company,

               aba.bc_account account,

               ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'DEPARTMENT',gcc.segment3) department,

               ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'DESTINATION',gcc.segment5) destination,

               NULL office, 

               ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'ORIGIN',gcc.segment6) origin,

               ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'DIVISION',

                 NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4',

                                                                p_oracle_value => gcc.segment4,

                                                                p_bc_dimension => 'DIVISION'),'000') ) division

          INTO v_line_company,

               v_line_account,

               v_line_department,

               v_line_destination,

               v_line_office,

               v_line_origin,

               v_line_division

          FROM ra_customer_trx_all rct,

               ra_cust_trx_line_gl_dist_all rctlg,

               gl_code_combinations gcc,

               ajc_bc_accounts aba

         WHERE rct.trx_number = cl.appliestodocno

           AND rct.org_id = gv_org_id

           and rct.bill_to_customer_id = cl.billToCustomerId

           AND rct.customer_trx_id = rctlg.customer_trx_id

           AND rctlg.code_combination_id = gcc.code_combination_id

           AND rctlg.account_class = 'REV'

           AND gcc.segment2 = aba.oracle_account (+)

           AND ROWNUM = 1;



        UPDATE ajcl_bc_ies_ar_lines

           SET line_company = v_line_company,

               line_account = v_line_account,

               line_department = v_line_department,

               line_destination = v_line_destination,

               line_office = v_line_office,

               line_origin = v_line_origin,

               line_division = v_line_division

         WHERE rowid = cl.row_id;



        print_log ('transactionno:' || cl.transactionno || '|' || 'lineno: ' || cl.lineno);

        print_log ('new values >> ' ||  

                   'line_company: ' || v_line_company || '|' ||

                   'line_account: ' || v_line_account || '|' ||

                   'line_department: ' || v_line_department || '|' ||

                   'line_destination: ' || v_line_destination || '|' ||

                   'line_office: ' || v_line_office || '|' ||

                   'line_origin: ' || v_line_origin || '|' ||

                   'line_division: ' || v_line_division );                  



      EXCEPTION

        WHEN OTHERS THEN

          NULL;



      END;



    END LOOP;



    COMMIT;



    print_log('ajcl_bc_ies_ar_pkg.fix_dim_DATAMIG_inv_to_cm_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      NULL;



  END fix_dim_DATAMIG_inv_to_cm_p;

  -- 20241001



  PROCEDURE main_bc_p ( p_status   OUT   VARCHAR2 ) IS



    v_status                VARCHAR2(1);

    v_phase                 VARCHAR2(100);

    v_trx_count             NUMBER;

    v_lines_count           NUMBER;

    v_error_oracle_count    NUMBER;

    v_error_message         VARCHAR2(2000);



    e_error                 EXCEPTION;



  BEGIN



    print_log( 'ajcl_bc_ies_ar_pkg.main_bc_p (+)' );



    insert_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'insert_p';

      RAISE e_error;



    END IF;



    -- 20241001

    fix_dim_DATAMIG_inv_to_cm_p;

    -- 20241001



    worksheets_to_bc_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'worksheets_to_bc_p';

      RAISE e_error;



    END IF;



    -- dbms_lock - Lock --------------------------------------------------------------------------------------------------------

    print_log ( 'Trying to lock ' || gv_ar_process_name || '.' );

    print_log ( 'If it stops at this point it is because it is blocked by another integration. It will continue once the other integration releases.' );



    ajc_bc_dbms_lock_pkg.lock_p ( p_process_name => gv_ar_process_name,

                                  p_id_lock => gv_ar_id_lock,

                                  p_request_status => gv_ar_request_status ); 



    IF ( gv_ar_request_status != 'success' ) THEN



      RAISE ge_ar_lock;



    END IF;

    -- dbms_lock - Lock --------------------------------------------------------------------------------------------------------



    call_ws ( p_status => v_status,

              p_trx_count => v_trx_count,

              p_lines_count => v_lines_count );



    IF ( v_status != 'S' ) THEN



      v_phase := 'call_ws';

      RAISE e_error;



    END IF;



    -- Si no se enviaron comprobantes a BC

    IF ( NVL(v_trx_count,0) = 0 ) THEN



      -- Se verifica si hay comprobantes con ERROR, son los que dieron error en oracle

      SELECT COUNT(1)

        INTO v_error_oracle_count

        FROM ajcl_bc_ies_ar_headers

       WHERE status = 'ERROR'

         AND request_id = gv_request_id

         AND bc_environment = gv_bc_environment;



    END IF;



    -- Si se envió al menos un comprobante o si hay comprobantes que dieron error en Oracle se ejecuta el job

    IF ( v_trx_count > 0 OR v_error_oracle_count > 0 ) THEN



      print_log ( 'v_trx_count: ' || v_trx_count );



      IF ( v_trx_count > 0 ) THEN



        -- Se ejecuta el JOB -----------------------------------------------------------------------------------------------------

        call_job ( p_status => v_status );



        IF v_status != 'S' THEN



          v_phase := 'call_job';

          RAISE e_error;



        END IF;



        print_log ( 'v_lines_count: ' || v_lines_count );



        -- dbms_lock - Release -------------------------------------------------------------------------------------------------

        ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_ar_id_lock,

                                         p_release_status => gv_ar_release_status );



        IF ( gv_ar_release_status != 'success' ) THEN



          RAISE ge_ar_release;



        END IF;                                     

        -- dbms_lock - Release -------------------------------------------------------------------------------------------------



        -- Verifico el status de las lineas procesadas por el job --------------------------------------------------------------

        call_status ( p_status => v_status );



        IF v_status != 'S' THEN



          v_phase := 'call_status';

          RAISE e_error;



        END IF;



      -- 20241008

      ELSE



        -- dbms_lock - Release -------------------------------------------------------------------------------------------------

        ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_ar_id_lock,

                                         p_release_status => gv_ar_release_status );



        IF ( gv_ar_release_status != 'success' ) THEN



          RAISE ge_ar_release;



        END IF;                                     

        -- dbms_lock - Release -------------------------------------------------------------------------------------------------

      -- 20241008



      END IF;



      -- INSERT REPORT IN TABLE AJCL_BC_REPORTS --------------------------------------------------------------------------------

      IF ( gv_file_format = 'CSV' ) THEN



        final_report_csv_p ( p_status => v_status );     



        IF ( v_status != 'S' ) THEN



          v_phase := 'final_report_p';

          RAISE e_error;



        END IF;  



        -- CREATE CSV FROM TABLE AJCL_BC_REPORTS -------------------------------------------------------------------------------

        ajcl_bc_utils_pkg.create_csv_p ( p_ifc => gv_bc_ifc,

                                         p_request_id => gv_request_id,

                                         p_log_seq => gv_log_seq,

                                         p_type => 'REPORT',

                                         p_filename => gv_report_filename,

                                         p_status => v_status );



        IF ( v_status != 'S' ) THEN



          v_phase := 'create_csv_p | REPORT';

          RAISE e_error;



        END IF;



      ELSIF ( gv_file_format = 'XLSX' ) THEN  



        -- No inserta en tabla, genera el xlsx directamente en el filesystem

        final_report_xlsx_p ( p_status => v_status );     



        IF ( v_status != 'S' ) THEN



          v_phase := 'final_report_xlsx_p';

          RAISE e_error;



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



    ELSE



      print_log ('No sales documents to process.');



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_ar_id_lock,

                                       p_release_status => gv_ar_release_status );



      IF ( gv_ar_release_status != 'success' ) THEN



        RAISE ge_ar_release;



      END IF;                                     

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => 'No sales documents to process.' || CHR(10) || 'Request ID: ' || gv_request_id );



    END IF;



    p_status := 'S';



    print_log( 'ajcl_bc_ies_ar_pkg.main_bc_p (-)' );



  EXCEPTION

    -- dbms_lock ---------------------------------------------------------------------------------------------------------------

    WHEN ge_ar_lock THEN -- Lock & Release

      p_status := 'E';

      print_log ('ajcl_bc_ies_ar_pkg.main_bc_p. Error when trying to lock the process ' || gv_ar_process_name || 

              ' | request_status: ' || gv_ar_request_status);

    -- dbms_lock ---------------------------------------------------------------------------------------------------------------



    WHEN e_error THEN

      p_status := 'E';

      print_log ( v_phase );



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_ar_id_lock,

                                       p_release_status => gv_ar_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------



      print_log( 'ajcl_bc_ies_ar_pkg.main_bc_p (!). Error: ' || SQLERRM );



    WHEN OTHERS THEN

      p_status := 'E';

      print_log ( v_phase );



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_ar_id_lock,

                                       p_release_status => gv_ar_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------



      print_log( 'ajcl_bc_ies_ar_pkg.main_bc_p (!). Error: ' || SQLERRM );



  END main_bc_p;



  -- ---------------------------------------------------------------------------------------------------------------------------

  -- Main

  -- ---------------------------------------------------------------------------------------------------------------------------

  PROCEDURE main_p ( p_bc_environment         IN   VARCHAR2,

                     p_gl_date                IN   VARCHAR2,

                     p_if_errors_stop         IN   VARCHAR2,

                     p_jenkins_build_number   IN   VARCHAR2 ) IS



    v_status            VARCHAR2(1);

    v_phase             VARCHAR2(200);

    v_error_msg         VARCHAR2(4000);



    v_argument1         VARCHAR2(100);

    v_argument2         VARCHAR2(100);

    v_argument3         VARCHAR2(100);



    -- 20250507

    v_support_email          VARCHAR2(200);

    v_ar_not_success         NUMBER;

    -- 20250507



    e_error             EXCEPTION;

    e_stop_processing   EXCEPTION;

    e_warning           EXCEPTION;

    e_parameter_value   EXCEPTION;

    e_bc_setup          EXCEPTION;



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



    gv_email := ajcl_bc_utils_pkg.get_emails_f ( 'IES SALES DOC' );

    print_log( 'gv_email: ' || gv_email );



    gv_ar_process_name := ajcl_bc_ws_utils_pkg.get_lock_process_name_f ( p_integration => 'SALES DOCUMENTS' );

    print_log( 'gv_ar_process_name: ' || gv_ar_process_name );



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



    -- Validacion parametro p_if_errors_stop -----------------------------------------------------------------------------------

    IF ( p_if_errors_stop NOT IN ('Y','N') ) THEN



      v_error_msg := 'Invalid value (' || p_if_errors_stop || ') for parameter IF_ERRORS_STOP.';

      RAISE e_parameter_value;



    END IF;



    gv_if_errors_stop := p_if_errors_stop;

    print_log ( 'gv_if_errors_stop: ' || gv_if_errors_stop );

    print_log ( 'gv_data_file_name: ' || gv_data_file_name );



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



    -- Se obtienen los Posted Sales Invoices y Posted Sales Credit Memos de BC

    ajcl_bc_get_entities_pkg.get_sales_documents_p ( p_bc_environment => gv_bc_environment,

                                                     p_bc_ifc => gv_bc_ifc,

                                                     p_request_id => gv_request_id,

                                                     p_log_seq => gv_log_seq,

                                                     p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'ajcl_bc_get_entities_pkg.get_sales_documents_p';

      RAISE e_error;



    END IF;



    print_log ( 'The required dimensions of the accounts are refreshed.' );

    ajcl_bc_accounts_pkg.main_p ( p_bc_environment => gv_bc_environment );



    -- 20240916

    IF ( ajcl_bc_utils_pkg.get_db_name_f IN ('FINUPG5','PROD') ) THEN



      gv_ftp_loader := 'Y'; -- FTP, LOADER



    ELSIF ( ajcl_bc_utils_pkg.get_db_name_f IN ('FINUPG6') ) THEN



      gv_ftp_loader := 'N'; -- TRIGGER



    END IF;



    print_log ( 'gv_ftp_loader: ' || gv_ftp_loader );

    -- 20240916



    -- AJC Ftp IES AR File -----------------------------------------------------------------------------------------------------

    /* 20241211

    -- Se reemplaza con un build step en Jenkins

    IF ( gv_ftp_loader = 'Y' ) THEN 



      print_log ( 'Run job AJCL_BC_FTP_IES_AR_FILE' );

      -- 20240923 v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJCL_BC_FTP_IES_AR_FILE';

      v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_BC_IES_AR_FTP' );

      print_log ( 'v_argument1: ' || v_argument1 );



      ajc_bc_scheduler_pkg.create_run_wait_job_p ( p_job_name => 'AJCL_BC_FTP_IES_AR_FILE',

                                                   p_comments => 'AJC Ftp IES AR File',

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



        v_phase := 'AJC Ftp IES AR File';

        RAISE e_error;



      END IF; 



      -- AJC Archive Ftped IES AR Files On IES Server ----------------------------------------------------------------------------

      print_log ( 'Run job AJCL_BC_ARCH_IES_AR_FILE' );

      -- 20240923 v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJCL_BC_ARCH_IES_AR_FILE';

      v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_BC_IES_AR_ARCHIVE' );

      print_log ( 'v_argument1: ' || v_argument1 );



      ajc_bc_scheduler_pkg.create_run_wait_job_p ( p_job_name => 'AJCL_BC_ARCH_IES_AR_FILE',

                                                   p_comments => 'AJC Archive Ftped IES AR Files On IES Server',

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



        v_phase := 'AJC Archive Ftped IES AR Files On IES Server';

        RAISE e_error;



      END IF; 



      -- AJC Load IES AR File Into Custom Table ----------------------------------------------------------------------------------

      print_log ( 'Run job AJC_LOAD_IES_AR_FILE' );



      -- 20240923 v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJCL_EXECUTE_CTL.sh';

      v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_EXECUTE_CTL' );

      print_log ( 'v_argument1: ' || v_argument1 );



      -- 20240923 v_argument2 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJC_LOAD_IES_AR_FILE';

      v_argument2 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_BC_IES_AR_LOADER' );

      print_log ( 'v_argument2: ' || v_argument2 );



      v_argument3 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'APPLTMP' ) || gv_data_file_name; -- 'AJC_IES_AR_FILE.xml'

      print_log ( 'v_argument3: ' || v_argument3 );



      ajc_bc_scheduler_pkg.create_run_wait_job_p ( p_job_name => 'AJC_LOAD_IES_AR_FILE',

                                                   p_comments => 'AJC Load IES AR File Into Custom Table',

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



        v_phase := 'AJC Load IES AR File Into Custom Table';

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



    -- AJC Populate IES AR Inbound Data Table ----------------------------------------------------------------------------------

    populate_table_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'AJC Populate IES AR Inbound Data Table';

      RAISE e_error;



    END IF;



    /* 20241211

    -- Se reemplaza con un build step en Jenkins

    -- AJC Rename IES AR File --------------------------------------------------------------------------------------------------

    IF ( gv_ftp_loader = 'Y' ) THEN



      print_log ( 'Run job AJCL_BC_RENAME_IES_AR_FILE' );

      -- 20240923 v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJCL_BC_RENAME_IES_AR_FILE';

      v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_BC_IES_AR_RENAME' );

      print_log ( 'v_argument1: ' || v_argument1 );



      ajc_bc_scheduler_pkg.create_run_wait_job_p ( p_job_name => 'AJCL_BC_RENAME_IES_AR_FILE',

                                                   p_comments => 'AJC Rename IES AR File',

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



        v_phase := 'AJC Rename IES AR File';

        RAISE e_error;



      END IF;



    END IF; -- gv_ftp_loader

    -- 20241211

    */



    IF ( gv_only_reprocess = 'N' ) THEN



      -- Processing Control Report -----------------------------------------------------------------------------------------------

      control_report_p ( p_status => v_status );



      IF ( v_status != 'S' ) THEN



        v_phase := 'control_report_p';



        IF ( v_status = 'E' ) THEN



          RAISE e_error;



        ELSIF ( v_status = 'W' ) THEN



          RAISE e_warning;



        END IF;



      END IF; 



      -- Data Listing ------------------------------------------------------------------------------------------------------------

      data_list_p ( p_status => v_status );



      IF ( v_status != 'S' ) THEN



        v_phase := 'data_list_p';

        RAISE e_error;



      END IF;



      -- Validate and Preprocessing ----------------------------------------------------------------------------------------------

      validate_preprocess_p ( p_status => v_status );



      IF ( v_status != 'S' ) THEN



        v_phase := 'validate_preprocess_p';

        RAISE e_error;



      END IF;



      IF ( gv_file_format = 'CSV' ) THEN



        -- CREATE OUTPUT -----------------------------------------------------------------------------------------------------------

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



      -- Stop Processing on Validate Errors --------------------------------------------------------------------------------------

      stop_processing_p ( p_status => v_status );



      IF ( v_status != 'S' ) THEN



        v_phase := 'stop_processing_p';

        RAISE e_stop_processing;



      END IF;



    END IF;



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



      DELETE ajc_ies_ar_file;

      COMMIT;



    END IF;



    -- 20250507

    -- Se agrega envio de mail para soporte, para informar que no se pudo importar todo en la ejecucion 

    BEGIN



      v_support_email := ajcl_bc_utils_pkg.get_emails_f ( 'SUPPORT' );



      -- AR ------------------------------------------------------------------------

      SELECT COUNT(1) 

        INTO v_ar_not_success

        FROM ajcl_bc_ies_ar_headers

       WHERE request_id = gv_request_id

         AND UPPER(status) != 'SUCCESS';



      print_log ('v_ar_not_success: ' || v_ar_not_success);



      IF ( v_ar_not_success > 0 ) THEN



        ajcl_bc_utils_pkg.send_email_p ( p_to => v_support_email,

                                         p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - WARNING - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => 'Some invoices could not be imported. Please review the integration report.' || CHR(10) || 'Request ID: ' || gv_request_id );



      END IF;



    EXCEPTION

      WHEN OTHERS THEN

        NULL;



    END;

    -- 20250507



    -- Se actualiza el concurrent_job

    ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'S' );



    print_log ( 'ajcl_bc_ies_ar_pkg.main_p (-)' );



  EXCEPTION

    WHEN e_bc_setup THEN

      print_log('ajcl_bc_ies_ar_pkg.main_p (!). BC setup error. please contact support.');



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



    WHEN e_warning THEN

      print_log('ajcl_bc_ies_ar_pkg.main_p (!)');

      print_log(v_phase);

      print_log('No records to process.');



      BEGIN



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                         p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => 'No records to process.' || CHR(10) || 'Request ID: ' || gv_request_id );



      EXCEPTION

        WHEN OTHERS THEN

          print_log ( 'SMTP NOT WORKING.' );



      END;          



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );   



      RAISE_APPLICATION_ERROR(-20000,'No records to process.');



    WHEN e_error THEN

      print_log('ajcl_bc_ies_ar_pkg.main_p (!)');

      print_log(v_phase); 



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

      print_log('ajcl_bc_ies_ar_pkg.main_p (!)');

      print_log(v_phase); 



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



    WHEN e_parameter_value THEN

      print_log('ajcl_bc_ies_ar_pkg.main_p (!)');

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



    WHEN OTHERS THEN

      print_log('ajcl_bc_ies_ar_pkg.main_p (!). ' || SQLERRM );

      print_log(v_phase);



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



END ajcl_bc_ies_ar_pkg;
