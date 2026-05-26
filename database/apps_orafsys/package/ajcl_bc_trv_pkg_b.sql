CREATE OR REPLACE PACKAGE BODY ajcl_bc_trv_pkg IS

-- Creation: SBANCHIERI 23-AUG-2023 

  

  -- Parameters

  gv_journal_source                VARCHAR2(50) := 'TRV Cost Entries';

  gv_default_billed_trx_type       NUMBER := 1875; -- TRV INV

  gv_default_cogs_recog_je_cat     VARCHAR2(50) := 'TRV INV COGS';

  gv_default_accrual_trx_type      NUMBER := 1877; -- ZTRV INV ACCR

  gv_default_batch_source          NUMBER := 1851; -- TURVO

  gv_default_cogs_accrual_je_cat   VARCHAR2(50) := 'TRV ACCR COGS';

  --



  -- 20251106 REINTENTO

  gv_retry_in_seconds              NUMBER;

  gv_retry                         VARCHAR2(1);

  -- 20251106 REINTENTO



  -- 20260108

  gv_support_email                 VARCHAR2(200);

  -- 20260108



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



    print_log( 'ajcl_bc_trv_pkg.final_output_xlsx_p (+)' );



    gv_directory_output := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_OUTPUT' );



    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc || ' Output',

                                                p_request_id => gv_request_id,

                                                p_bc_environment => gv_bc_environment,

                                                p_jenkins_build_number => gv_jenkins_build_number,

                                                --

                                                p_param_1_title => ' ',

                                                p_param_1_value => ' ',

                                                p_param_2_title => 'RUN ID', 

                                                p_param_2_value => gv_run_id

                                                -- 20240905 ,p_param_3_title => 'CHECK_INTEGRATIONS_SOURCE'

                                                -- 20240905 ,p_param_3_value => gv_check_integrations_source

                                                );



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



    print_log( 'ajcl_bc_trv_pkg.final_output_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_trv_pkg.final_output_xlsx_p (!). Error: ' || SQLERRM );



  END final_output_xlsx_p;



  -- AJCL TRV Step 1 Valid Control Report

  PROCEDURE step_1_valid_control_report_p IS



      CURSOR c_report IS

      SELECT trv_shipping_order, 

             xml_file_type, 

             xml_file_name, 

             trv_cust_carr_acct_num no,

             trv_cust_carr_acct_name name,

             invoice_num, 

             DECODE(xml_file_type,'Customer-Inv', DECODE(substr(invoice_num, -1),'R', 0, charge_amount), 

                                  'Route-QAREV', DECODE(substr(invoice_num, -1),'R', 0, charge_amount),0) inv_amt,

             DECODE(xml_file_type,'Customer-Inv', DECODE(substr(invoice_num, -1),'R', charge_amount,0),0) cm_amt,

             DECODE(xml_file_type,'Carrier-Inv', charge_amount, 'Route-QACOGS', charge_amount, 0) cogs_amt,

             validation_status,

             validation_message,

             interface_status

        FROM ajc_trv_interface

       WHERE oracle_xml_run_id = gv_run_id

    ORDER BY trv_shipping_order, 

             xml_file_type, 

             xml_file_name, 

             invoice_num;



      CURSOR c_report_total IS

      SELECT SUM(DECODE(xml_file_type,'Customer-Inv', DECODE(substr(invoice_num, -1),'R', 0, charge_amount), 

                                  'Route-QAREV', DECODE(substr(invoice_num, -1),'R', 0, charge_amount),0)) inv_amt,

             SUM(DECODE(xml_file_type,'Customer-Inv', DECODE(substr(invoice_num, -1),'R', charge_amount,0),0)) cm_amt,

             SUM(DECODE(xml_file_type,'Carrier-Inv', charge_amount, 'Route-QACOGS', charge_amount, 0)) cogs_amt

        FROM ajc_trv_interface

       WHERE oracle_xml_run_id = gv_run_id;             



      CURSOR c_lines_count IS 

      SELECT validation_status, 

             COUNT(1) rec_cnt

        FROM ajc_trv_interface

       WHERE oracle_xml_run_id = gv_run_id

    GROUP BY validation_status

    ORDER BY validation_status;



    v_columns   VARCHAR2(2000);



  BEGIN



    print_log('ajcl_bc_trv_pkg.step_1_valid_control_report_p (+)');



    ----------------------------------------------------------------------------------------------------------------------------



    IF ( gv_file_format = 'CSV' ) THEN



      print_output (' ');

      print_output ('AJC Turvo Validation Step 1 Control Report');

      print_output (' ');



      v_columns := 'SO Number' || '|' ||

                   'File Type' || '|' ||

                   'File Name' || '|' ||

                   'Invoice No' || '|' ||            

                   'Inv Amt' || '|' ||

                   'CM Amt' || '|' ||

                   'COGS Amt' || '|' ||     

                   'Validation Status' || '|' ||

                   'Validation Message' || '|' ||

                   'Interface Status';



      print_output ( v_columns );



      FOR crpt IN c_report LOOP



        print_output ( crpt.trv_shipping_order || '|' ||

                       crpt.xml_file_type || '|' ||

                       crpt.xml_file_name || '|' ||

                       crpt.invoice_num || '|' ||                

                       crpt.inv_amt || '|' ||

                       crpt.cm_amt || '|' ||

                       crpt.cogs_amt || '|' ||               

                       crpt.validation_status || '|' ||

                       crpt.validation_message || '|' ||

                       crpt.interface_status );



      END LOOP;



      -- Totales

      FOR crptt IN c_report_total LOOP



        print_output ( ' ' || '|' ||

                       ' ' || '|' ||

                       ' ' || '|' ||

                       ' ' || '|' ||

                       crptt.inv_amt || '|' ||

                       crptt.cm_amt || '|' ||

                       crptt.cogs_amt );



      END LOOP;  



    ELSIF ( gv_file_format = 'XLSX' ) THEN 



      -- Column Names

      print_output_xlsx ( p_section => 'Validation Step 1 Control Report',

                          p_column1 => 'SO Number',

                          p_column2 => 'File Type',

                          p_column3 => 'File Name',

                          p_column4 => 'No.',

                          p_column5 => 'Name',

                          p_column6 => 'Invoice No',

                          p_column7 => 'Inv Amt',

                          p_column8 => 'CM Amt',

                          p_column9 => 'COGS Amt',

                          p_column10 => 'Validation Status',

                          p_column11 => 'Validation Message',

                          p_column12 => 'Interface Status' );   



      FOR crpt IN c_report LOOP



        print_output_xlsx ( p_section => 'Validation Step 1 Control Report',

                            p_column1 => crpt.trv_shipping_order,

                            p_column2 => crpt.xml_file_type,

                            p_column3 => crpt.xml_file_name,

                            p_column4 => crpt.no,

                            p_column5 => crpt.name,

                            p_column6 => crpt.invoice_num,          

                            p_column7 => crpt.inv_amt,

                            p_column8 => crpt.cm_amt,

                            p_column9 => crpt.cogs_amt,           

                            p_column10 => crpt.validation_status,

                            p_column11 => crpt.validation_message,

                            p_column12 => crpt.interface_status );



      END LOOP;



      -- Totales

      FOR crptt IN c_report_total LOOP



        print_output_xlsx ( p_section => 'Validation Step 1 Control Report',

                            p_column1 => ' ',

                            p_column2 => ' ',

                            p_column3 => ' ',

                            p_column4 => ' ',  

                            p_column5 => ' ',  

                            p_column6 => ' ',  

                            p_column7 => crptt.inv_amt,

                            p_column8 => crptt.cm_amt,

                            p_column9 => crptt.cogs_amt );



      END LOOP;  



    END IF;



    ----------------------------------------------------------------------------------------------------------------------------



    IF ( gv_file_format = 'CSV' ) THEN



      print_output( ' ' );

      print_output( 'Line count by validation status' );

      print_output( ' ' );



      v_columns := 'Validation Status' || '|' ||

                   'Line Count';



      print_output ( v_columns );



      FOR clc IN c_lines_count LOOP



        print_output ( clc.validation_status || '|' ||

                       clc.rec_cnt );



      END LOOP;



    ELSIF ( gv_file_format = 'XLSX' ) THEN 



      -- Column Names

      print_output_xlsx ( p_section => 'Line count by validation status',

                          p_column1 => 'Validation Status',

                          p_column2 => 'Line Count' );    



      FOR clc IN c_lines_count LOOP



        print_output_xlsx ( p_section => 'Line count by validation status',

                            p_column1 => clc.validation_status,

                            p_column2 => clc.rec_cnt );



      END LOOP;



    END IF;



    print_log('ajcl_bc_trv_pkg.step_1_valid_control_report_p (-)');



  END step_1_valid_control_report_p;  



  -- AJCL TRV Step 1 Validation

  FUNCTION billed_trv_trx_exists ( invoice_num_in              IN   VARCHAR2, 

                                   shipping_order_in           IN   VARCHAR2,

                                   -- p_default_billed_trx_type   IN   VARCHAR2,

                                   billed_cm_trx_type_id_in    IN   NUMBER ) RETURN VARCHAR2 IS



    billed_trx_exists_out   VARCHAR2(1) := 'N';



  BEGIN



    BEGIN



      BEGIN



        SELECT 'Y' 

          INTO billed_trx_exists_out

          FROM ajcl_bc_posted_sd_headers

         WHERE bc_environment = gv_bc_environment

           AND class IN ( SELECT type 

                            FROM ra_cust_trx_types_all 

                           WHERE cust_trx_type_id IN (gv_default_billed_trx_type, billed_cm_trx_type_id_in ) )

           AND trvinvoicenum = invoice_num_in

           AND trvshippingorder = shipping_order_in

           AND transactionno = 'TRV-' || invoice_num_in;



      EXCEPTION

        -- Si no se encontro en BC, se busca en Oracle

        WHEN OTHERS THEN



          SELECT 'Y'

            INTO billed_trx_exists_out

            FROM ra_customer_trx_all

           WHERE cust_trx_type_id IN ( gv_default_billed_trx_type, billed_cm_trx_type_id_in )

             AND org_id = gv_org_id

             AND interface_header_attribute2 = invoice_num_in

             AND interface_header_attribute1 = shipping_order_in

             AND trx_number = 'TRV-' || invoice_num_in;



      END;



    EXCEPTION

      WHEN NO_DATA_FOUND THEN

        billed_trx_exists_out := 'N';



    END;



    RETURN billed_trx_exists_out;



  END billed_trv_trx_exists;  



  PROCEDURE step_1_validation ( p_status   IN OUT   VARCHAR2 ) IS



    file_type_v 			             ajc_trv_interface.xml_file_type%TYPE;

    shipping_order_v  		        ajc_trv_interface.trv_shipping_order%TYPE;

    inv_found_v 		             	VARCHAR2(1);

    found_v 			                 VARCHAR2(1);

    je_found_v 			              VARCHAR2(1);

    billed_inv_found_v  		      VARCHAR2(1);

    validation_status_v 		      VARCHAR2(1);

    match_to_file_type_v		      VARCHAR2(30);

    carr_cust_match_found_v 	   VARCHAR2(1);

    interface_status_v 		       ajc_trv_interface.interface_status%TYPE;

    Cust_NoMatch_run_id_v		     NUMBER;

    Carrier_NoMatch_run_id_v	   NUMBER;

    ajc_mg_accr_trx_seq_v		     NUMBER;

    invoice_num_v			            ajc_trv_interface.invoice_num%TYPE;

    carrier_inv_found_v 		      VARCHAR2(1);

    rev_accrual_found_v 		      VARCHAR2(1);

    cogs_accrual_found_v 		     VARCHAR2(1);

    stmt_v				                  NUMBER;

    prog_failed_v			            BOOLEAN; 

    num_with_delivery_date_v	   NUMBER; 

    num_lds_v                   NUMBER; 

    num_not_interfaced_v		      NUMBER := 0;

    stop_message_v			           VARCHAR2(200);

    req_id_v			                 NUMBER;

    rpt_date_v			               VARCHAR2(30);

    jobcost_id_v			             gl_je_lines.attribute11%TYPE;

    billed_cm_trx_type_id_v 	   ra_cust_trx_types_all.credit_memo_type_id%TYPE;

    accrual_type_processing_v   ajc_trv_interface.xml_file_type%TYPE;

    accrual_type_to_skip_v      ajc_trv_interface.xml_file_type%TYPE;

    inv_type_to_process_v       ajc_trv_interface.xml_file_type%TYPE;

    inv_type_not_in_file_v      ajc_trv_interface.xml_file_type%TYPE;

    update_status_v             VARCHAR2(1);

    accrual_found_to_skip_v     VARCHAR2(1);

    accrual_found_val_status_v  ajc_trv_interface.validation_status%TYPE;

    inv_type_to_proc_found_v    VARCHAR2(1);

    upd_to_invalid_v           	VARCHAR2(1);

    max_invoice_date_v		        ajc_trv_interface.invoice_date%TYPE;



    je_category_v		            	gl_je_categories.je_category_name%TYPE := NULL; 



    stop_processing 	          	EXCEPTION;

    e_only_reprocess            EXCEPTION;



      -- Correctable errors will be reprocessed in the step 1 validation

      CURSOR select_so IS

      SELECT	xml_file_type, 

             trv_shipping_order, 

             MAX(xml_file_id) max_xml_file_id,

             trv_cust_carr_acct_num,

             trv_order_id

        FROM ajc_trv_interface

       WHERE oracle_xml_run_id = gv_run_id 

         AND nvl(validation_status,'Correctable') = 'Correctable'

         AND interface_status IS NULL

    GROUP BY xml_file_type, 

             trv_shipping_order, 

             trv_cust_carr_acct_num, 

             trv_order_id

    ORDER BY xml_file_type, 

             trv_shipping_order, 

             trv_cust_carr_acct_num, 

             trv_order_id;



    CURSOR select_so_loadid IS

    SELECT DISTINCT trv_shipping_order, 

           trv_load_id

      FROM ajc_trv_interface

     WHERE oracle_xml_run_id = gv_run_id 

       AND nvl(validation_status,'Correctable') NOT IN ('Skipped', 'Invalid')

       AND interface_status IS NULL;



    CURSOR SELECT_SO_Inv IS

    SELECT DISTINCT xml_file_type, 

           trv_shipping_order, 

           invoice_num

      FROM ajc_trv_interface

     WHERE oracle_xml_run_id = gv_run_id 

       AND nvl(validation_status,'Correctable') = 'Correctable'

       AND interface_status IS NULL

       AND xml_file_type IN ('Customer-Inv', 'Carrier-Inv');



      CURSOR select_so_delivery_date is

      SELECT xml_file_name, 

             trv_shipping_order, 

             MAX(delivery_date) delivery_date,

             COUNT(1) num_recs

        FROM ajc_trv_interface

       WHERE oracle_xml_run_id = gv_run_id 

         AND nvl(validation_status,'Correctable') = 'Correctable'

         AND interface_status IS NULL

    GROUP BY xml_file_name, 

             trv_shipping_order

    ORDER BY xml_file_name, 

             trv_shipping_order;



    CURSOR select_accrual_rec IS

    SELECT DISTINCT xml_file_type, 

           trv_shipping_order, 

           xml_file_name

      FROM ajc_trv_interface

     WHERE nvl(validation_status, 'Valid') NOT IN ('Skipped', 'Invalid', 'Generated')

       AND oracle_xml_run_id = gv_run_id

       AND xml_file_type IN ('Route-QAREV', 'Route-QACOGS')

       AND 1 = 2;



  BEGIN



    print_log('ajcl_bc_trv_pkg.step_1_validation (+)');



    IF ( gv_run_id = 999999999999 ) THEN



      stop_message_v := 'TRV Interface table is empty'; 

      RAISE stop_processing;



    END IF;



    -- Stop processesing if there are no records to process

    SELECT COUNT(*)

      INTO num_not_interfaced_v

      FROM ajc_trv_interface

     WHERE interface_status IS NULL;



    IF ( num_not_interfaced_v = 0 ) THEN



      -- stop_message_v := 'No data to process';

      -- RAISE stop_processing;

      RAISE e_only_reprocess;



    END IF;



    -- Get the CM trx type for the Billed Inv trx type

    SELECT credit_memo_type_id

      INTO billed_cm_trx_type_id_v

      FROM ra_cust_trx_types_all

     WHERE cust_trx_type_id = gv_default_billed_trx_type;



    SELECT je_category_name 

      INTO je_category_v

      FROM gl_je_categories 

     WHERE user_je_category_name = gv_default_cogs_recog_je_cat;



    -- Validation - Step 1 - Correctable



    -- Reset Correctable status if the user has fixed the issue



    stmt_v := 240;



    UPDATE ajc_trv_interface i

       SET validation_status = NULL, 

           validation_message = NULL,

           interface_status = NULL

     WHERE xml_file_type IN ('Customer-Inv', 'Route-QAREV')

       AND oracle_xml_run_id = gv_run_id 

       AND validation_status = 'Correctable'

       AND NVL(LENGTH(TRIM(TRANSLATE(trv_cust_carr_acct_num, '0123456789.', ' '))),0) = 0

       AND EXISTS ( SELECT 'x' 

                      FROM ajcl_bc_cust_xref x 

                     WHERE bc_environment = gv_bc_environment

                       AND source = 'TRV'

                       AND source_type = 'CUSTOMER'

                       AND x.bp_cust_id = i.trv_cust_carr_acct_num );    



    stmt_v := 250;



    UPDATE ajc_trv_interface i

       SET validation_status = NULL, 

           validation_message = NULL,

           interface_status = NULL

     WHERE xml_file_type IN ('Carrier-Inv', 'Route-QACOGS')

       AND oracle_xml_run_id = gv_run_id 

       AND validation_status = 'Correctable'

       AND NVL(LENGTH(TRIM(TRANSLATE(trv_cust_carr_acct_num, '0123456789.', ' '))),0) = 0

       AND EXISTS ( SELECT 'x'

                      FROM ajcl_bc_cust_xref x 

                     WHERE bc_environment = gv_bc_environment

                       AND source = 'TRV'

                       AND source_type = 'VENDOR'

                       AND x.bp_cust_id = i.trv_cust_carr_acct_num );



    stmt_v := 260;



    UPDATE ajc_trv_interface i

       SET validation_status = NULL, 

           validation_message = NULL, 

           interface_status = NULL

     WHERE validation_status = 'Correctable' 

       AND oracle_xml_run_id = gv_run_id 

       AND EXISTS ( SELECT 'x'

                      FROM ajcl_bc_ies_items items

                     WHERE bc_environment = gv_bc_environment

                       AND NVL(i.edi_item_code,i.charge_type) = items.charge_type_code

                       AND items.business_line = NVL(( SELECT business_line

                                                         FROM ajcl_bc_ies_business_lines 

                                                        WHERE bc_environment = gv_bc_environment

                                                          AND enabled = 'Y'

                                                          AND fs_office_code = SUBSTR(i.trv_shipping_order,LENGTH(i.trv_shipping_order),1) ),

                                                     ( SELECT business_line

                                                         FROM ajcl_bc_ies_business_lines 

                                                        WHERE bc_environment = gv_bc_environment

                                                          AND enabled = 'Y'

                                                          AND trv_default = 'Y' ))  

                  );



    COMMIT;



    -- End of reset Correctable status logic that was moved



    FOR so_rec2 IN select_so LOOP



      IF so_rec2.xml_file_type NOT IN ('Carrier-Inv', 'Customer-Inv') THEN



        stmt_v := 95;

        -- 20241021

        print_log ('1. UPDATE ajc_trv_interface | so_rec2.trv_shipping_order: ' || so_rec2.trv_shipping_order);

        print_log ('1. UPDATE ajc_trv_interface | so_rec2.xml_file_type: ' || so_rec2.xml_file_type);

        print_log ('1. UPDATE ajc_trv_interface | so_rec2.max_xml_file_id: ' || so_rec2.max_xml_file_id);

        -- 20241021



        BEGIN



          UPDATE ajc_trv_interface

             SET validation_status = 'Skipped', 

                 interface_status = 'NA'

           WHERE trv_shipping_order = so_rec2.trv_shipping_order

             AND xml_file_type = so_rec2.xml_file_type

             AND oracle_xml_run_id = gv_run_id 

             -- 20241024

             AND trv_order_id = so_rec2.trv_order_id

             -- 20241024

             AND interface_status IS NULL

             AND xml_file_id < so_rec2.max_xml_file_id;



        END;



      END IF;



    END LOOP;



    COMMIT;



    FOR so_rec IN select_so LOOP



      file_type_v := so_rec.xml_file_type;

      shipping_order_v := so_rec.trv_shipping_order;

      found_v := NULL;



      print_log('File type: ' || so_rec.xml_file_type);

      print_log('Shipping Order: ' || so_rec.trv_shipping_order);

      print_log('Max XML File ID: ' || so_rec.max_xml_file_id);

      print_log('Cust Carr Acct Num: ' || so_rec.trv_cust_carr_acct_num);



      -- If file type is Route-QAREV or Route-QACOGS AND any imported MG AR invoice exists in Oracle AR with the 

		    -- same SO number, validation status is set to skipped AND interface status to NA

      IF ( file_type_v IN ('Route-QAREV', 'Route-QACOGS') ) THEN



        BEGIN



          BEGIN



            SELECT 'Y' 

              INTO found_v

              FROM ajcl_bc_posted_sd_headers

             WHERE bc_environment = gv_bc_environment

               AND trvshippingorder = so_rec.trv_shipping_order

               AND class IN ( SELECT type 

                                FROM ra_cust_trx_types_all 

                               WHERE cust_trx_type_id = gv_default_billed_trx_type )

               AND billtocustomerno = so_rec.trv_cust_carr_acct_num

               AND ROWNUM = 1;             



          EXCEPTION

            -- Si no se encontro en BC, se busca en Oracle

            WHEN NO_DATA_FOUND THEN



              SELECT 'Y' 

                INTO found_v

                FROM ra_customer_trx_all

               WHERE org_id = gv_org_id 

                 AND interface_header_attribute1 = so_rec.trv_shipping_order

                 AND cust_trx_type_id = gv_default_billed_trx_type

                 AND rownum = 1

                 AND bill_to_customer_id = ( SELECT oracle_cust_id

                                               FROM ajcl_bc_cust_xref 

                                              WHERE bc_environment = gv_bc_environment

                                                AND source = 'TRV'

                                                AND source_type = 'CUSTOMER'

                                                AND bp_cust_id = so_rec.trv_cust_carr_acct_num );



          END;



        EXCEPTION

          WHEN NO_DATA_FOUND THEN

            found_v := 'N';



          WHEN OTHERS THEN

            stmt_v := 100;

            RAISE;



        END;



        IF ( found_v = 'Y' ) THEN



          print_log('Billed invoice found in AR'); 



        END IF;



        -- If any imported TRV AP invoice(carrier invoice) exists in Oracle GL with the 

        -- same SO number, validation status is set to skipped AND interface status to NA

        IF ( NVL(found_v,'N') = 'N' ) THEN



          BEGIN



            BEGIN



              SELECT 'Y'

                INTO found_v

                FROM ajcl_bc_gen_jnl_entries

               WHERE bc_environment = gv_bc_environment

                 AND userjecategoryname = je_category_v

                 AND worksheetno = 'TRV' || so_rec.trv_shipping_order

                 AND trvcustomercarrieracctnum = so_rec.trv_cust_carr_acct_num

                 AND ( NVL(trvorderid,-1) = NVL(so_rec.trv_order_id, -1) OR trvorderid IS NULL )

                 AND ROWNUM = 1;



            EXCEPTION

              -- Si no se encontro en BC, se busca en Oracle

              WHEN NO_DATA_FOUND THEN



                SELECT 'Y' 

                  INTO found_v

                  FROM gl_je_headers h, 

                       gl_je_lines l 

                 WHERE h.je_header_id = l.je_header_id

                   AND h.set_of_books_id = gv_set_of_books_id

                   AND h.je_category = je_category_v 

                   AND l.attribute11 = 'TRV' || so_rec.trv_shipping_order

                   AND ROWNUM = 1

                   AND l.attribute3 = so_rec.trv_cust_carr_acct_num

                   AND ( NVL(l.attribute19,-1) = NVL(so_rec.trv_order_id, -1) OR l.attribute19 IS NULL ); 



            END;



          EXCEPTION

            WHEN NO_DATA_FOUND THEN

               found_v := 'N';

            WHEN OTHERS THEN

               stmt_v := 101;

               RAISE;



          END;



          IF ( found_v = 'Y' ) THEN



            print_log('Carrier Invoice found in GL'); 



          END IF;



        END IF;



        IF ( file_type_v = 'Route-QAREV' AND nvl(found_v,'N') = 'N' ) THEN



          -- If file type is Route-QAREV and file type of Customer-Inv exists 

          -- with the same runid AND Shipping Order (SO) number, validation status is set to 

          -- skipped AND interface status to NA

          BEGIN



            SELECT 'Y'

              INTO found_v

              FROM ajc_trv_interface

             WHERE trv_shipping_order = so_rec.trv_shipping_order

               AND oracle_xml_run_id = gv_run_id 

               AND xml_file_type = 'Customer-Inv'

               AND rownum = 1

               AND trv_cust_carr_acct_num = so_rec.trv_cust_carr_acct_num

               -- 20250408

               AND trv_order_id = so_rec.trv_order_id 

               -- 20250408

               ;



          EXCEPTION

            WHEN NO_DATA_FOUND THEN

              found_v := 'N';



            WHEN OTHERS THEN

              stmt_v := 110;

              RAISE;



          END;



        END IF;



        IF ( file_type_v = 'Route-QACOGS' AND NVL(found_v,'N') = 'N' ) THEN



          -- If file type is Route-QACOGS and file type of Carrier-Inv exists 

          -- with the same runid AND Shipping Order (SO) number, validation status is set to 

          -- skipped AND interface status to NA

          BEGIN



            SELECT 'Y'

              INTO found_v

              FROM ajc_trv_interface

             WHERE trv_shipping_order = so_rec.trv_shipping_order

               AND oracle_xml_run_id = gv_run_id 

               AND xml_file_type = 'Carrier-Inv'

               AND rownum = 1

               AND trv_cust_carr_acct_num = so_rec.trv_cust_carr_acct_num

               AND trv_order_id = so_rec.trv_order_id;



          EXCEPTION

            WHEN NO_DATA_FOUND THEN

              found_v := 'N';

            WHEN OTHERS THEN

              stmt_v := 112;

              RAISE;



          END;



        END IF;



        stmt_v := 120;



        IF ( found_v = 'Y' ) THEN



          -- 20241021

          print_log ('2. UPDATE ajc_trv_interface | so_rec.trv_shipping_order: ' || so_rec.trv_shipping_order);

          print_log ('2. UPDATE ajc_trv_interface | so_rec.xml_file_type: ' || so_rec.xml_file_type);

          print_log ('2. UPDATE ajc_trv_interface | so_rec.trv_cust_carr_acct_num: ' || so_rec.trv_cust_carr_acct_num);

          -- 20241021



          UPDATE ajc_trv_interface

             SET validation_status = 'Skipped', 

                 interface_status = 'NA'

           WHERE trv_shipping_order = so_rec.trv_shipping_order

             AND xml_file_type = so_rec.xml_file_type

             AND oracle_xml_run_id = gv_run_id

             AND interface_status IS NULL

             AND trv_cust_carr_acct_num = so_rec.trv_cust_carr_acct_num;



        END IF;



      END IF;



    END LOOP; -- select_so 



    COMMIT;



    stmt_v := 135;



    FOR inv_rec IN select_so_inv LOOP



     	inv_found_v := NULL;

	     je_found_v := NULL;

	     jobcost_id_v := NULL;



	     -- If type is Customer-Inv AND transaction exists in Oracle AR with the same invoice number AND SO, 

	     -- validation status is set to skipped for lines with that invoice number AND interface status to NA

	     IF ( inv_rec.xml_file_type = 'Customer-Inv' ) THEN



		      stmt_v := 136;

		      inv_found_v := billed_trv_trx_exists ( inv_rec.invoice_num, 

                                               inv_rec.trv_shipping_order, 

                                               -- p_default_billed_trx_type,

                                               billed_cm_trx_type_id_v );



		      stmt_v := 140;



		      IF ( inv_found_v = 'Y' ) THEN



          -- 20241021

          print_log ('3. UPDATE ajc_trv_interface | inv_rec.trv_shipping_order: ' || inv_rec.trv_shipping_order);

          print_log ('3. UPDATE ajc_trv_interface | inv_rec.xml_file_type: ' || inv_rec.xml_file_type);

          print_log ('3. UPDATE ajc_trv_interface | inv_rec.invoice_num: ' || inv_rec.invoice_num);

          -- 20241021



          UPDATE ajc_trv_interface

			          SET validation_status = 'Skipped', 

                 interface_status = 'NA'

			        WHERE trv_shipping_order = inv_rec.trv_shipping_order

             AND xml_file_type = inv_rec.xml_file_type

             AND oracle_xml_run_id = gv_run_id

             AND interface_status is null

             AND invoice_num = inv_rec.invoice_num;



        END IF;



      END IF;



      -- If type is Carrier-Inv AND transaction exists in Oracle GL with the same invoice number AND SO, 

      -- validation status is set to skipped for lines with that invoice number AND interface status to NA



	     IF ( inv_rec.xml_file_type = 'Carrier-Inv' ) THEN



		      jobcost_id_v := 'TRV' || inv_rec.trv_shipping_order;



		      BEGIN



          BEGIN



            SELECT 'Y'

              INTO je_found_v

              FROM ajcl_bc_gen_jnl_entries

             WHERE bc_environment = gv_bc_environment

               -- 20241003

               -- AND userjesourcename = gv_journal_source

               AND userjesourcename = UPPER(gv_journal_source)

               -- 20241003

               AND trvinvoicenum = inv_rec.invoice_num

               AND worksheetno = jobcost_id_v

               AND ROWNUM = 1;



          EXCEPTION

            -- Si no se encontro en BC, se busca en Oracle

            WHEN NO_DATA_FOUND THEN



              SELECT 'Y'

                INTO je_found_v

                FROM gl_je_lines l,

                     gl_je_headers h, 

                     gl_je_sources s

               WHERE l.je_header_id = h.je_header_id

                 AND s.user_je_source_name = gv_journal_source 

                 AND h.je_source = s.je_source_name 

                 AND l.attribute1 = inv_rec.invoice_num

                 AND l.attribute11 = jobcost_id_v 

                 AND rownum = 1;



          END;



        EXCEPTION

          WHEN NO_DATA_FOUND THEN

            je_found_v := 'N';



          WHEN OTHERS THEN

            stmt_v := 150;

            RAISE;



        END;



      		stmt_v := 160;



        IF ( je_found_v = 'Y' ) THEN



          -- 20241021

          print_log ('4. UPDATE ajc_trv_interface | so_rec.trv_shipping_order: ' || inv_rec.trv_shipping_order);

          print_log ('4. UPDATE ajc_trv_interface | so_rec.xml_file_type: ' || inv_rec.xml_file_type);

          print_log ('4. UPDATE ajc_trv_interface | so_rec.invoice_num: ' || inv_rec.invoice_num);

          -- 20241021



          UPDATE ajc_trv_interface

             SET validation_status = 'Skipped', 

                 interface_status = 'NA'

           WHERE trv_shipping_order = inv_rec.trv_shipping_order

             AND xml_file_type = inv_rec.xml_file_type

             AND oracle_xml_run_id = gv_run_id 

             AND interface_status IS NULL

             AND invoice_num = inv_rec.invoice_num;



        END IF;



      END IF;



    END LOOP; -- select_so_inv LOOP



    COMMIT;



    -- ------------------------------------------------------------------------------------

    -- Validation - Step 1 - Invalid

    -- ------------------------------------------------------------------------------------

    -- If some of the lines for a given SO  in an xml file have a delivery date and some don't, then update the lines without a delivery date.

    -- If the delivery date is null for all transactions(that haven't been skipped) for a given SO in an xml file and the xml file is a customer or carrier 

    --      invoice, update the delivery date to the value of the invoice date. If the invoice date is null then set all of the lines for that SO in the xml file  to invalid.

    -- If the delivery date is null for all transactions(that haven't been skipped) for a given SO in an xml file and the xml file is a route file, 

    --     then set all of the lines for that SO in the xml file  to invalid.



    print_log('- Delivery Date Validation');



    FOR so_rec IN select_so_delivery_date LOOP



      print_log('XML File, Shipping Order,Max Delv Date, Num Recs: ' || so_rec.xml_file_name || ';' || 

                 so_rec.trv_shipping_order ||';' ||

                 so_rec.delivery_date || ';' || 

                 so_rec.num_recs );



      upd_to_invalid_v := 'N';

      num_with_delivery_date_v := 0;

      max_invoice_date_v := null;



      stmt_v := 170;



      -- Count the number of lines that have a delivery date

      SELECT COUNT(1)

        INTO num_with_delivery_date_v

        FROM ajc_trv_interface

       WHERE oracle_xml_run_id = gv_run_id 

         AND nvl(validation_status,'Correctable') = 'Correctable'

         AND interface_status IS NULL

         AND delivery_date IS NOT NULL

         AND trv_shipping_order = so_rec.trv_shipping_order

         and xml_file_name = so_rec.xml_file_name;



      print_log('Num lines with a delv date: '||num_with_delivery_date_v);



      IF ( num_with_delivery_date_v = 0 ) THEN



        -- If the xml file is a Customer invoice or Carrier invoice 

        -- can't include xml_file_type in cursor because it will process Route files incorrectly



        IF ( SUBSTR(so_rec.xml_file_name,1,1) = 'C' ) THEN



          stmt_v := 172;



          -- Find the invoice date for this so, xml file type

          BEGIN



            SELECT MAX(invoice_date)

              INTO max_invoice_date_v

              FROM ajc_trv_interface

             WHERE oracle_xml_run_id = gv_run_id 

               AND nvl(validation_status,'Correctable') = 'Correctable'

               AND interface_status IS NULL

               AND delivery_date IS NULL

               AND trv_shipping_order = so_rec.trv_shipping_order

               AND xml_file_name = so_rec.xml_file_name;



          EXCEPTION

            WHEN NO_DATA_FOUND THEN

              NULL;

            WHEN OTHERS THEN

              RAISE;          



          END;



          print_log('Max Inv Date: '||max_invoice_date_v);



          stmt_v := 174;



          IF ( max_invoice_date_v IS NOT NULL ) THEN



            UPDATE ajc_trv_interface

               SET delivery_date = max_invoice_date_v   

             WHERE oracle_xml_run_id = gv_run_id 

               AND trv_shipping_order = so_rec.trv_shipping_order

               AND delivery_date IS NULL

               AND nvl(validation_status,'Correctable') = 'Correctable'

               AND xml_file_name = so_rec.xml_file_name;



            print_log('Updated Delivery date to invoice date');



          ELSE



            upd_to_invalid_v := 'Y';



          END IF;



        ELSE



          upd_to_invalid_v := 'Y';



        END IF;



        IF ( upd_to_invalid_v = 'Y' ) THEN



          stmt_v := 176;



          UPDATE ajc_trv_interface

             SET validation_status = 'Invalid', 

                 validation_message = 'Delivery Date Missing',

                 interface_status = 'NA'

           WHERE validation_status IS NULL

             AND oracle_xml_run_id = gv_run_id 

             AND trv_shipping_order = so_rec.trv_shipping_order

             AND xml_file_name = so_rec.xml_file_name;



          print_log('Updated validation status to Invalid.');



        END IF;



      ELSIF ( so_rec.num_recs <> num_with_delivery_date_v ) THEN



        stmt_v := 178;



        print_log('Some lines have a delivery date');          



        UPDATE ajc_trv_interface

           SET delivery_date = so_rec.delivery_date 

         WHERE oracle_xml_run_id = gv_run_id 

           AND trv_shipping_order = so_rec.trv_shipping_order

           AND delivery_date IS NULL

           AND nvl(validation_status,'Correctable') = 'Correctable'

           AND xml_file_name = so_rec.xml_file_name;



        print_log('Updated Delivery Date to delivery date: ' || so_rec.delivery_date);



      END IF;



    END LOOP; -- select_so_delivery_date LOOP



    COMMIT;



    -- If the invoice_num is null on any line for a Carrier-Inv or for a Customer_inv, 

    -- set status to Invalid for all lines of all transactions for that xml file type and SO#

    stmt_v := 180;



    UPDATE ajc_trv_interface

       SET validation_status = 'Invalid', 

           validation_message = 'Invoice Number Missing',

           interface_status = 'NA'

     WHERE validation_status IS NULL

       AND oracle_xml_run_id = gv_run_id 

       AND xml_file_type IN ('Customer-Inv', 'Carrier-Inv')

       AND ( xml_file_name,trv_shipping_order ) IN ( SELECT DISTINCT xml_file_name,

                                                            trv_shipping_order

                                                       FROM ajc_trv_interface

                                                      WHERE oracle_xml_run_id = gv_run_id 

                                                        AND invoice_num IS NULL

                                                        AND validation_status IS NULL

                                                        AND xml_file_type IN ('Customer-Inv', 'Carrier-Inv') );

    COMMIT;



    print_log('- New Accrual Processing');



    FOR accrual_rec IN select_accrual_rec LOOP



      print_log('FILE type: ' || accrual_rec.xml_file_type);

      print_log('SO: ' || accrual_rec.trv_shipping_order);

      print_log('File Name: ' || accrual_rec.xml_file_name);



      IF ( accrual_rec.xml_file_type = 'Route-QACOGS' ) THEN



        accrual_type_processing_v := 'Route-QACOGS';

        accrual_type_to_skip_v := 'Route-QAREV';

        inv_type_to_process_v := 'Customer-Inv';

        inv_type_not_in_file_v := 'Carrier-Inv';



      ELSE



        accrual_type_processing_v :='Route-QAREV';

        accrual_type_to_skip_v := 'Route-QACOGS';

        inv_type_to_process_v := 'Carrier-Inv';

        inv_type_not_in_file_v := 'Customer-Inv';



      END IF;



      print_log('Accrual Proc Type: ' || accrual_type_processing_v);

      print_log('Accrual Type to Skip: ' || accrual_type_to_skip_v);

      print_log('Inv type to Process: ' || inv_type_to_process_v);

      print_log('Inv type NOT to Process: ' || inv_type_not_in_file_v);



      update_status_v := null;

      accrual_found_to_skip_v := 'N';

      accrual_found_val_status_v := null;

      inv_type_to_proc_found_v := null;

      stmt_v := 200;



      -- Does a matching accrual record exists in this run id for the 

      -- same SO? The matching accrual record may have a status of Skipped

      -- at this point in the processing. This statement is assuming all lines 

      -- for an xml_file_name, oracle_xml_run_id, trv_shipping_order will have the same status

      --

      BEGIN



        SELECT 'Y', 

               NVL(validation_status,'Valid')

          INTO accrual_found_to_skip_v, 

               accrual_found_val_status_v 

          FROM ajc_trv_interface

         WHERE xml_file_type = accrual_type_to_skip_v

           AND nvl(validation_status, 'Valid') NOT IN ('Invalid','Generated')	

           AND xml_file_name = accrual_rec.xml_file_name				

           AND oracle_xml_run_id = gv_run_id			

           AND trv_shipping_order = accrual_rec.trv_shipping_order

           AND rownum = 1;



      EXCEPTION

        WHEN NO_DATA_FOUND THEN

          accrual_found_to_skip_v := 'N';

        When OTHERS THEN 

          RAISE;



      END;



      print_log('Accrual Found to Skip: ' || accrual_found_to_skip_v || ' | Validation Status: ' || accrual_found_val_status_v );



	     IF ( accrual_found_to_skip_v = 'N' ) THEN



        -- If not skipped Route-QAREV or Route-QACOGS does not have a corresponding 

        -- match with the same SO AND 

        -- xml_file_name, set its status to Invalid to prevent processing 

        update_status_v := 'Y';



      ELSE



        -- matching accrual was found

 	      IF ( accrual_found_val_status_v = 'Skipped' ) THEN 



			       inv_type_to_proc_found_v := 'N';

			       stmt_v := 210;



			       BEGIN



            SELECT 'Y'

				          INTO inv_type_to_proc_found_v

				          FROM ajc_trv_interface i

             WHERE nvl(validation_status, 'Valid') = 'Valid'

               AND oracle_xml_run_id = gv_run_id

               AND trv_shipping_order = accrual_rec.trv_shipping_order

               AND xml_file_type = inv_type_to_process_v

               AND NOT EXISTS ( SELECT 'x'

                                  FROM ajc_trv_interface i2

                                 WHERE nvl(validation_status, 'Valid') NOT IN ('Skipped', 'Invalid','Generated')

                                   AND xml_file_type= inv_type_not_in_file_v

                                   AND oracle_xml_run_id = gv_run_id

                                   AND i2.trv_shipping_order = i.trv_shipping_order)

               AND rownum = 1;



			       EXCEPTION

            WHEN NO_DATA_FOUND THEN

              inv_type_to_proc_found_v := 'N';	

            WHEN OTHERS THEN 

              RAISE;



          END;



          print_log('Invoice Type to Process Trx Found: ' || inv_type_to_proc_found_v);



			       IF ( inv_type_to_proc_found_v = 'Y' ) THEN



            -- Do not update the status of this record to Invalid. This is a special condition

            -- which allows a separate accrual to be processed. Separate accrual means

            -- either a Route-QAREV or Route-QACOGS. Normally, both are required at the same

            -- time for processing.



            update_status_v := 'N';



          ELSE



            update_status_v := 'Y';



          END IF;



		      ELSE



          -- accrual_found_val_status_v is either  'Valid' or 'Correctable'

          -- A matching Valid accrual was found so do not update the status of this record

          -- to Invalid.



			       update_status_v := 'N';



        END IF;



	     END IF; -- accrual_found_to_skip_v = N



      print_log('Update Status Flag: ' || update_status_v);



      IF ( update_status_v = 'Y' ) THEN



        stmt_v := 220;



		      UPDATE ajc_trv_interface i

           SET validation_status = 'Invalid',

               interface_status = 'NA',

               validation_message = 'Corresponding Accrual Match Missing for Shipping Order in XML File'

         WHERE oracle_xml_run_id = gv_run_id

           AND nvl(validation_status, 'Valid') NOT IN ('Skipped', 'Invalid', 'Generated')

           AND xml_file_type = accrual_rec.xml_file_type

           AND  xml_file_name = accrual_rec.xml_file_name

           AND trv_shipping_order = accrual_rec.trv_shipping_order;				



        print_log('MG Int Updated.');



      END IF;



    END LOOP;



    COMMIT;



    stmt_v := 250;



    -- If there are multiple load ids for a single shipping order then set the shipping order to Invalid

    UPDATE ajc_trv_interface i

       SET validation_status = 'Invalid', 

           interface_status = 'NA',

           validation_message = 'Multiple Load IDs found for Shipping Order'

     WHERE oracle_xml_run_id = gv_run_id 

       AND EXISTS ( SELECT i2.trv_shipping_order, 

                           COUNT(DISTINCT(i2.trv_load_id)) cnt

                      FROM ajc_trv_interface i2

                     WHERE i2.oracle_xml_run_id = gv_run_id 

                       AND i2.trv_shipping_order = i.trv_shipping_order

                  GROUP BY i2.trv_shipping_order 

                    HAVING COUNT(DISTINCT(i2.trv_load_id)) > 1); 



    COMMIT;



    -- Verify the Load id for the shipping order is the same as any trx that may have been

    -- previously imported into AR



    FOR so_ld_rec IN select_so_loadid LOOP



      num_lds_v := 0;



      SELECT COUNT(1)

        INTO num_lds_v

        FROM ajcl_bc_posted_sd_lines l,

             ajcl_bc_posted_sd_headers h

       WHERE l.bc_environment = gv_bc_environment

         AND h.bc_environment = gv_bc_environment

         AND l.transactionno = h.transactionno

         AND l.billtocustomerno = h.billtocustomerno

         AND h.source = 'TRV'

         AND h.trvshippingorder = so_ld_rec.trv_shipping_order

         AND l.trvmgloadid <> so_ld_rec.trv_load_id;



      IF ( num_lds_v > 0 ) THEN



        UPDATE ajc_trv_interface i

           SET validation_status = 'Invalid', 

               interface_status = 'NA',

               validation_message = 'Different Load ID exists for Shipping Order in Oracle AR'

         WHERE oracle_xml_run_id = gv_run_id

           AND trv_shipping_order = so_ld_rec.trv_shipping_order

           AND trv_load_id = so_ld_rec.trv_load_id;



      END IF;



    END LOOP;



    COMMIT;



    --

    -- Customer/Vendor Validation

    -- 

    -- The trv_cust_carr_acct_num is not defined appropriately in the Logistics Customer/Vendor table

    -- If the xml_file_type is Customer-Inv or Route-QAREV, the supplied number must be defined as a 

    -- Bplus or MG customer number



    stmt_v := 210;

    -- If the supplied customer number contains a character other than a decimail point then set validation status to Correctable



    UPDATE ajc_trv_interface i

       SET validation_status = 'Correctable',

           validation_message = 'Customer not defined in the Logistics Customer/Vendor table',

           interface_status = NULL

     WHERE xml_file_type IN ('Customer-Inv', 'Route-QAREV')

       AND oracle_xml_run_id = gv_run_id 

       AND NVL(validation_status,'Correctable') = 'Correctable'

       AND NVL(LENGTH(TRIM(TRANSLATE(trv_cust_carr_acct_num,'0123456789.', ' '))),0) > 0;



    stmt_v := 211;



    -- This update statement will only look at supplied customer numbers that are numeric or contain a decimal poing

    UPDATE ajc_trv_interface i

       SET validation_status = 'Correctable', 

           validation_message = 'Customer not defined in the Logistics Customer/Vendor table',

           interface_status = NULL

     WHERE xml_file_type IN ('Customer-Inv', 'Route-QAREV')

       AND oracle_xml_run_id = gv_run_id 

       AND NVL(validation_status,'Correctable') = 'Correctable'

       AND NVL(LENGTH(TRIM(TRANSLATE(trv_cust_carr_acct_num,'0123456789.', ' '))),0) = 0

       AND NOT EXISTS ( SELECT 'x'

                          FROM ajcl_bc_cust_xref x 

                         WHERE bc_environment = gv_bc_environment

                           AND source = 'TRV'

                           AND source_type = 'CUSTOMER'

                           AND x.bp_cust_id = i.trv_cust_carr_acct_num);



    -- If the xml_file_type is Carrier-Inv or Route-QACOGS, the supplied number must be defined as an MG vendor number



    stmt_v := 220;

    -- If the supplied vendor number contains a character then set validation status to Correctable



    UPDATE ajc_trv_interface i

       SET validation_status = 'Correctable',

           validation_message = 'Vendor not defined in the Logistics Customer/Vendor table',

           interface_status = NULL

     WHERE xml_file_type IN ('Carrier-Inv', 'Route-QACOGS')

       AND oracle_xml_run_id = gv_run_id 

       AND NVL(validation_status,'Correctable') = 'Correctable'

       AND NVL(LENGTH(TRIM(TRANSLATE(trv_cust_carr_acct_num, '0123456789.', ' '))),0) > 0;



    stmt_v := 221;



    -- This update statement will only look at supplied vendor numbers that are numeric or contain a decimal point

    UPDATE ajc_trv_interface i

       SET validation_status = 'Correctable', 

           validation_message = 'Vendor not defined in the Logistics Customer/Vendor table',

           interface_status = NULL

     WHERE xml_file_type IN ('Carrier-Inv', 'Route-QACOGS')

       AND oracle_xml_run_id = gv_run_id 

       AND nvl(validation_status,'Correctable') = 'Correctable'

       AND NVL(LENGTH(TRIM(TRANSLATE(trv_cust_carr_acct_num, '0123456789.', ' '))),0) = 0

       AND NOT EXISTS ( SELECT 'x'

                          FROM ajcl_bc_cust_xref x 

                         WHERE bc_environment = gv_bc_environment

                           AND source = 'TRV'

                           AND source_type = 'VENDOR'

                           AND x.bp_cust_id = i.trv_cust_carr_acct_num);



    stmt_v := 230;



    --

    -- Item Validation

    --

    -- The Charge type is not defined in Oracle

    UPDATE ajc_trv_interface i

       SET validation_status = 'Correctable', 

           validation_message = 'Charge Type not defined in Oracle',

           interface_status = NULL

     WHERE nvl(validation_status, 'Correctable') = 'Correctable' 

       AND oracle_xml_run_id = gv_run_id 

       AND NOT EXISTS ( SELECT 'x'

                          FROM ajcl_bc_ies_items items

                         WHERE bc_environment = gv_bc_environment

                           AND NVL(i.edi_item_code,i.charge_type) = items.charge_type_code

                           AND items.business_line = NVL(( SELECT business_line

                                                             FROM ajcl_bc_ies_business_lines 

                                                            WHERE bc_environment = gv_bc_environment

                                                              AND enabled = 'Y'

                                                              AND fs_office_code = SUBSTR(i.trv_shipping_order,LENGTH(i.trv_shipping_order),1) ),

                                                         ( SELECT business_line

                                                             FROM ajcl_bc_ies_business_lines 

                                                            WHERE bc_environment = gv_bc_environment

                                                              AND enabled = 'Y'

                                                              AND trv_default = 'Y' )) );



    COMMIT;



    -- If any line of shipping order, xml file name contains a Correctable error then

    -- mark all the lines of the shipping order, xml file name as Correctable

    -- so all the lines get processed at the same time.

    UPDATE ajc_trv_interface i

       SET validation_status = 'Correctable',

           validation_message = 'Correctable Error exists for this SO,XML File',

           interface_status = NULL

     WHERE validation_status IS NULL

       AND oracle_xml_run_id = gv_run_id

       AND EXISTS ( SELECT 'x'

                      FROM ajc_trv_interface i2

                     WHERE validation_status = 'Correctable'

                       AND oracle_xml_run_id = gv_run_id 

                       AND i2.xml_file_name = i.xml_file_name

                       AND i2.trv_shipping_order = i.trv_shipping_order ); 



    COMMIT;



    -- Submit the control report

    step_1_valid_control_report_p;



    p_status := 'S';



    print_log('ajcl_bc_trv_pkg.step_1_validation (-)');



  EXCEPTION 

    WHEN e_only_reprocess THEN

      print_log( 'ajcl_bc_trv_pkg.step_1_validation (!)' );

      p_status := 'W';

      gv_only_reprocess := 'Y';

      stop_message_v := 'The file has already been processed. Only errors/rejects records from previous runs will be reprocessed.';

      print_log('The file has already been processed. Only errors/rejects records from previous runs will be reprocessed.');



    WHEN stop_processing THEN

      SELECT TO_CHAR(SYSDATE, 'DD-MON-YYYY HH12:MI:SS PM') 

	       INTO rpt_date_v

	       FROM dual;



        print_log('AJCL MG Validation Step 1');                  

        print_log('Report Date: '|| rpt_date_v); 

        print_log(stop_message_v);

	       -- prog_failed_v := FND_CONCURRENT.SET_COMPLETION_STATUS('ERROR', 'Unexpected Error');



        p_status := 'E';



    WHEN OTHERS THEN

      print_log('AJCL MG Validation Step 1');                  

      print_log('Program encountered an unexpected error: ');

      print_log('Error Line: '||stmt_v);

      print_log(to_char(SQLCODE)||'-'||SQLERRM);

      -- prog_failed_v := FND_CONCURRENT.SET_COMPLETION_STATUS('ERROR', 'Unexpected Error');



      p_status := 'E';



  END step_1_validation;



  -- AJCL TRV Step 2 Validation

  -- ============================================================================

  -- Procedure Generate_Accrual_Rev_Recs

  --

  -- Generate reversal records for an accrual. Change the sign on the line

  -- amount, add an 'R' to the prior invoice number,

  -- set GL date to the same as the corresponding initial billing transaction;

  -- Set the validation status to Generated, interface status to null;

  -- Change the run id to current run id so it gets processed with this run.

  -- ============================================================================



  PROCEDURE generate_accrual_rev_recs ( file_type_in              IN   VARCHAR2,

                                        shipping_order_in         IN   VARCHAR2,

                                        gl_date_in                IN   DATE,

                                        accrual_found_run_id_in   IN   NUMBER,

                                        trv_cust_carr_acct_num_in IN   VARCHAR2,

                                        trv_order_id_in           IN   VARCHAR2 ) IS

  BEGIN



    print_log('Generate Accrual Reversal');



    INSERT

      INTO ajc_trv_interface

         ( xml_file_date,

           xml_file_type,

           xml_file_name,

           oracle_xml_run_id,

           trv_shipping_order,

           trv_load_id,

           trv_item_seq,

           trv_cust_carr_acct_num,

           po_num,

           price_sheet_type,

           invoice_date,

           invoice_num,

           charge_type,

           edi_item_code,

           charge_amount,

           delivery_date,

           creation_date,

           created_by,

           last_update_date,

           last_updated_by,

           transaction_gl_date,

           interface_status,

           validation_status,

           xml_file_id,

           unbilled_AR_run_id,

           unbilled_AR_invoice_num )

    SELECT xml_file_date,

           xml_file_type,

           xml_file_name,

           gv_run_id,

           trv_shipping_order,

           trv_load_id,

           trv_item_seq,

           trv_cust_carr_acct_num,

           po_num,

           price_sheet_type,

           invoice_date,

           invoice_num || 'R',  -- invoice_num||'-R', Removed dash 5/17/19 M.Stansell

           charge_type,

           edi_item_code,

           (charge_amount * -1), 

           delivery_date,

           SYSDATE,

           gv_user_id,

           SYSDATE,

           gv_user_id,

           gl_date_in,

           NULL,

           'Generated',

           xml_file_id,

           accrual_found_run_id_in,

           invoice_num

      FROM ajc_trv_interface

     WHERE oracle_xml_run_id = accrual_found_run_id_in 

       AND xml_file_type = file_type_in

       AND validation_status = 'Valid'

       AND interface_status = 'Interfaced'

       AND trv_shipping_order= shipping_order_in

       AND trv_cust_carr_acct_num = trv_cust_carr_acct_num_in

		     AND ( trv_order_id = trv_order_id_in OR trv_order_id IS NULL );



  EXCEPTION

    WHEN OTHERS THEN

      RAISE;



  END generate_accrual_rev_recs;  



  -- ================================================================

  -- Function Verify_Date

  --

  -- Confirm the date passed in is in a open AR period. If it is not 

  -- then use/return the gl date parameter value.

  -- ================================================================

  FUNCTION verify_date ( date_in   IN   DATE ) RETURN DATE IS



    return_date date;

    ARperiod_status_v gl_period_statuses.closing_status%TYPE;



  BEGIN



    print_log('ajcl_bc_trv_pkg.verify_date (+)');



    -- Se verifica si la fecha a enviar cae dentro del periodo abierto

    IF ( TRUNC(date_in) BETWEEN gv_bc_start_date AND gv_bc_end_date ) THEN



      -- Si cae dentro del periodo, se enviara la fecha que viene de TRV

      return_date := TO_DATE(date_in);



    ELSE



      -- Si no cae dentro del periodo, se envia el start_date de BC

      return_date := gv_bc_start_date;



    END IF; 



    print_log ( 'Return date: ' || return_date);    



    RETURN return_date;



    print_log('ajcl_bc_trv_pkg.verify_date (-)');



  END verify_date;



  PROCEDURE step_2_valid_control_report_p IS



      CURSOR c_report_detail IS

      SELECT trv_shipping_order, 

             xml_file_type, 

             xml_file_name, 

             trv_cust_carr_acct_num no,

             trv_cust_carr_acct_name name,

             invoice_num, 

             DECODE(xml_file_type, 'Customer-Inv',  decode(substr(invoice_num, -1),'R', 0, charge_amount), 

                                   'Route-QAREV',   decode(substr(invoice_num, -1),'R', 0, charge_amount), 0) inv_amt,

             DECODE(xml_file_type, 'Customer-Inv',  decode(substr(invoice_num, -1),'R', charge_amount, 0), 0) CM_amt,

             DECODE(xml_file_type, 'Carrier-Inv', charge_amount, 'Route-QACOGS', charge_amount, 0) cogs_amt,

             validation_status,

             validation_message,

             interface_status

        FROM ajc_trv_interface

       WHERE oracle_xml_run_id = gv_run_id

         and nvl(validation_status,'XX') NOT IN ('Skipped', 'Invalid')

    ORDER BY trv_shipping_order, 

             xml_file_type, 

             xml_file_name, 

             invoice_num;



      CURSOR c_report_total IS

      SELECT validation_status, 

             SUM(decode(xml_file_type, 'Customer-Inv', decode(substr(invoice_num, -1),'R', 0, charge_amount), 

                                       'Route-QAREV',  decode(substr(invoice_num, -1),'R', 0, charge_amount), 0)) inv_amt,

             SUM(decode(xml_file_type, 'Customer-Inv', decode(substr(invoice_num, -1),'R', charge_amount,0), 

                                       'Route-QAREV',  decode(substr(invoice_num, -1),'R', charge_amount,0), 0)) CM_amt,

             SUM(decode(xml_file_type, 'Carrier-Inv', charge_amount, 'Route-QACOGS', charge_amount, 0) ) cogs_amt,

             COUNT(1) rec_cnt

        from ajc_trv_interface

       where oracle_xml_run_id = gv_run_id

         and nvl(validation_status,'XX') NOT IN ('Skipped', 'Invalid')

    GROUP BY validation_status

    ORDER BY validation_status;  



    v_columns   VARCHAR2(2000);



  BEGIN



    print_log('ajcl_bc_trv_pkg.step_2_valid_control_report_p (+)');



    ----------------------------------------------------------------------------------------------------------------------------



    IF ( gv_file_format = 'CSV' ) THEN



      print_output (' ');

      print_output ('AJC Turvo Validation Step 2 Control Report');

      print_output (' ');



      v_columns := 'SO Number' || '|' ||

                   'File Type' || '|' ||

                   'File Name' || '|' ||

                   'Invoice No' || '|' ||                

                   'Inv Amt' || '|' ||

                   'CM Amt' || '|' ||

                   'COGS Amt' || '|' ||              

                   'Validation Status' || '|' ||

                   'Validation Message' || '|' ||

                   'Interface Status';



      print_output ( v_columns );



      FOR crpt IN c_report_detail LOOP



        print_output ( crpt.trv_shipping_order || '|' ||

                       crpt.xml_file_type || '|' ||

                       crpt.xml_file_name || '|' ||

                       crpt.invoice_num || '|' ||              

                       crpt.inv_amt || '|' ||

                       crpt.cm_amt || '|' ||

                       crpt.cogs_amt || '|' ||                

                       crpt.validation_status || '|' ||

                       crpt.validation_message || '|' ||

                       crpt.interface_status );



      END LOOP;



      -- Totales

      print_output ( ' ' );

      v_columns := 'Validation Status' || '|' ||

                   'Inv Amt' || '|' ||

                   'CM Amt' || '|' ||

                   'COGS Amt' || '|' ||                  

                   'Line Count';



      print_output ( v_columns );



      FOR crptt IN c_report_total LOOP



        print_output ( crptt.validation_status || '|' ||

                       crptt.inv_amt || '|' ||

                       crptt.cm_amt || '|' ||

                       crptt.cogs_amt || '|' ||   

                       crptt.rec_cnt );



      END LOOP; 



    ELSIF ( gv_file_format = 'XLSX' ) THEN 



      -- Column Names

      print_output_xlsx ( p_section => 'Validation Step 2 Control Report',

                          p_column1 => 'SO Number',

                          p_column2 => 'File Type',

                          p_column3 => 'File Name',

                          p_column4 => 'No',

                          p_column5 => 'Name',

                          p_column6 => 'Invoice No',          

                          p_column7 => 'Inv Amt',

                          p_column8 => 'CM Amt',

                          p_column9 => 'COGS Amt',         

                          p_column10 => 'Validation Status',

                          p_column11 => 'Validation Message',

                          p_column12 => 'Interface Status' );    



      FOR crpt IN c_report_detail LOOP



        print_output_xlsx ( p_section => 'Validation Step 2 Control Report',

                            p_column1 => crpt.trv_shipping_order,

                            p_column2 => crpt.xml_file_type,

                            p_column3 => crpt.xml_file_name,

                            p_column4 => crpt.no,         

                            p_column5 => crpt.name,

                            p_column6 => crpt.invoice_num,         

                            p_column7 => crpt.inv_amt,

                            p_column8 => crpt.cm_amt,

                            p_column9 => crpt.cogs_amt,          

                            p_column10 => crpt.validation_status,

                            p_column11 => crpt.validation_message,

                            p_column12 => crpt.interface_status );



      END LOOP;   



      -- Column Names

      print_output_xlsx ( p_section => 'Validation Step 2 Control Report Totals',

                          p_column1 => 'Validation Status',

                          p_column2 => 'Inv Amt',

                          p_column3 => 'CM Amt',

                          p_column4 => 'COGS Amt',             

                          p_column5 => 'Line Count' );    



      FOR crptt IN c_report_total LOOP



        print_output_xlsx ( p_section => 'Validation Step 2 Control Report Totals',

                            p_column1 => crptt.validation_status,

                            p_column2 => crptt.inv_amt,

                            p_column3 => crptt.cm_amt,

                            p_column4 => crptt.cogs_amt,         

                            p_column5 => crptt.rec_cnt );



      END LOOP; 



    END IF;



    print_log('ajcl_bc_trv_pkg.step_2_valid_control_report_p (-)');



  END step_2_valid_control_report_p;



  PROCEDURE step_2_validation ( p_status   IN OUT   VARCHAR2 ) IS



    file_type_v                     ajc_trv_interface.xml_file_type%TYPE;

    shipping_order_v                ajc_trv_interface.trv_shipping_order%TYPE;

    validation_status_v             ajc_trv_interface.validation_status%TYPE;

    validation_message_v            ajc_trv_interface.validation_message%TYPE;

    match_to_file_type_v            VARCHAR2(30);

    interface_status_v              ajc_trv_interface.interface_status%TYPE;

    gl_date_v                       DATE;

    ajc_trv_accr_trx_seq_v          NUMBER;

    invoice_num_v                   ajc_trv_interface.invoice_num%TYPE;

    matched_cogs_gl_date_v          date;

    accrual_file_type_v             VARCHAR2(30);

    match_found_v                   VARCHAR2(1);

    accrual_found_run_id_v          NUMBER; 

    stmt_v                          NUMBER;

    prog_failed_v                   BOOLEAN; 

    -- period_start_date_v             gl_period_statuses.start_date%TYPE;



      CURSOR select_so_inv_step2 IS

      SELECT DISTINCT xml_file_type, 

             trv_shipping_order, 

             invoice_num

        FROM ajc_trv_interface

       WHERE oracle_xml_run_id = gv_run_id

         AND validation_status IS NULL

         AND interface_status IS NULL

         AND xml_file_type in ('Customer-Inv', 'Carrier-Inv')

    ORDER BY trv_shipping_order, 

             xml_file_type;



      CURSOR select_so_inv_step2_valid IS

      SELECT xml_file_type, 

             trv_shipping_order, 

             invoice_num, 

             MAX(delivery_date) max_delivery_date, 

             trv_ship_id, 

             trv_cust_carr_acct_num,

             trv_order_id,

             DECODE(SIGN(charge_amount), -1, 'CM', 'INV') trx_type

        FROM ajc_trv_interface

       WHERE oracle_xml_run_id = gv_run_id

         AND validation_status IS NULL

         AND interface_status IS NULL

    GROUP BY xml_file_type, 

             trv_shipping_order, 

             invoice_num, 

             trv_ship_id, 

             trv_cust_carr_acct_num,

             trv_order_id,

             DECODE(SIGN(charge_amount), -1, 'CM', 'INV')

    ORDER BY trv_shipping_order, 

             xml_file_type, 

             trv_ship_id, 

             trv_cust_carr_acct_num;



      CURSOR select_so_ar_inv_step2_gldate is

      SELECT DISTINCT xml_file_type, 

             trv_shipping_order, 

             invoice_num, 

             transaction_gl_date

        FROM ajc_trv_interface

       WHERE oracle_xml_run_id = gv_run_id

         AND xml_file_type IN ('Customer-Inv', 'Route-QAREV')

         AND validation_status = 'Valid'

         AND interface_status IS NULL

    ORDER BY trv_shipping_order, 

             xml_file_type;



      CURSOR select_so_inv_step2_genrev is

      SELECT DISTINCT xml_file_type, 

             trv_shipping_order, 

             invoice_num, 

             transaction_gl_date,

             trv_cust_carr_acct_num,

             trv_order_id

        FROM ajc_trv_interface

       WHERE oracle_xml_run_id = gv_run_id

         AND validation_status = 'Valid'

         AND interface_status IS NULL

         -- AND xml_file_type IN ('Customer-Inv', 'Carrier-Inv')

    ORDER BY trv_shipping_order, 

             xml_file_type;



  BEGIN



    print_log('ajcl_bc_trv_pkg.step_2_validation (+)');



    stmt_v := 10;

    print_log( 'Run id: ' || gv_run_id);



    -- For all transactions with any line set to Valid and/or with no lines set to an earlier status

    print_log( '-- STEP 2 VALID --' ); 



    FOR so_inv_valid_rec IN SELECT_SO_Inv_Step2_Valid LOOP 



      print_log( 'SO#: ' || so_inv_valid_rec.trv_shipping_order || '|' || 

                 'Invoice#: ' || so_inv_valid_rec.invoice_num || '|' || 

                 'XML File type: ' || so_inv_valid_rec.xml_file_type || '|' || 

                 'Delivery date:  ' || so_inv_valid_rec.max_delivery_date);



		    print_log( 'Cust Carr Acct Num: '||so_inv_valid_rec.trv_cust_carr_acct_num );



      stmt_v := 100;

      gl_date_v := null;

      ajc_trv_accr_trx_seq_v := null;

      invoice_num_v := null;



      -- Determine AND set GL date for the transaction based on delivery date AND earliest open AR period

      gl_date_v := Verify_Date(so_inv_valid_rec.max_delivery_date);

      print_log( 'GL Date: '||gl_date_v);



      -- If xml_file_type is accrual (Route-QAREV or Route-QACOGS), populate invoice number

      -- Set invoice date to delivery date if null



      IF ( so_inv_valid_rec.xml_file_type in ('Route-QAREV', 'Route-QACOGS') ) THEN



        stmt_v := 110;



        SELECT ajc_trv_accr_trx_s.nextval

          INTO ajc_trv_accr_trx_seq_v

          FROM dual; 



        print_log( 'invoice_num_v: ' || 'TRVA-' || so_inv_valid_rec.trv_ship_id || '-' || ajc_trv_accr_trx_seq_v);



        invoice_num_v := 'TRVA-' || so_inv_valid_rec.trv_order_id || '-' || ajc_trv_accr_trx_seq_v;



        stmt_v := 120;



        UPDATE ajc_trv_interface

           SET transaction_gl_date = gl_date_v,

               invoice_num = invoice_num_v,

               invoice_date = nvl(invoice_date,delivery_date),

               validation_status = 'Valid'

         WHERE oracle_xml_run_id = gv_run_id

           AND xml_file_type = so_inv_valid_rec.xml_file_type

           AND validation_status IS NULL

           AND interface_status IS NULL

           AND trv_shipping_order = so_inv_valid_rec.trv_shipping_order

           AND trv_cust_carr_acct_num = so_inv_valid_rec.trv_cust_carr_acct_num

           AND decode(sign(charge_amount), -1, 'CM', 'INV') = so_inv_valid_rec.trx_type

           AND NVL(trv_order_id, -1) = NVL(so_inv_valid_rec.trv_order_id, -1);



      ELSE



        stmt_v := 130;

        print_log('Update Status to Valid');



        UPDATE ajc_trv_interface

           SET transaction_gl_date = gl_date_v,

               invoice_date = nvl(invoice_date,delivery_date),

               validation_status = 'Valid'

         WHERE oracle_xml_run_id = gv_run_id

           AND xml_file_type = so_inv_valid_rec.xml_file_type

           AND validation_status IS NULL

           AND interface_status IS NULL

           AND invoice_num = so_inv_valid_rec.invoice_num

           AND trv_shipping_order = so_inv_valid_rec.trv_shipping_order

           AND trv_cust_carr_acct_num = so_inv_valid_rec.trv_cust_carr_acct_num

           AND decode(sign(charge_amount), -1, 'CM', 'INV') = so_inv_valid_rec.trx_type;



      END IF;



    END LOOP;



    COMMIT;



    -- At this point, all valid records have a transaction gl date AND an invoice number

    -- Verify that the GL dates of a matching transaction, if any, are the same

    -- Matching transactions are Route-QAREV AND Route-QOGS, or Carrier-Inv AND Customer-Inv

    -- GL date for AR transaction is used for COGS when COGS different



    print_log('- STEP 2 Verify GL Dates'); 



    FOR so_ar_inv_rec_gldate IN SELECT_SO_AR_Inv_Step2_GLDate LOOP



      print_log('SO#: ' || so_ar_inv_rec_gldate.trv_shipping_order || '|' || 

                'Invoice#: ' || so_ar_inv_rec_gldate.invoice_num || '|' ||        

                'XML File type: ' || so_ar_inv_rec_gldate.xml_file_type || '|' || 

                'Trans GL date:  ' || so_ar_inv_rec_gldate.transaction_gl_date);



      stmt_v := 140;

      match_to_file_type_v := null;

      matched_cogs_gl_date_v := null;



      -- Find the matching COGS (Carrier-Inv, Route-QACOGS)

      IF ( so_ar_inv_rec_gldate.xml_file_type='Customer-Inv' ) THEN



        match_to_file_type_v := 'Carrier-Inv';



      ELSE



        match_to_file_type_v := 'Route-QACOGS';



      END IF;



      stmt_v := 150;



      BEGIN



        SELECT distinct(transaction_gl_date)

          INTO matched_cogs_gl_date_v

          FROM ajc_trv_interface

         WHERE oracle_xml_run_id = gv_run_id

           AND trv_shipping_order = so_ar_inv_rec_gldate.trv_shipping_order

           AND invoice_num = so_ar_inv_rec_gldate.invoice_num

           AND validation_status <> 'Skipped'

           AND xml_file_type = match_to_file_type_v;



      EXCEPTION

        WHEN NO_DATA_FOUND THEN

          matched_cogs_gl_date_v := null;

        WHEN TOO_MANY_ROWS THEN

          -- set the date to a value so that it will get updated below

          matched_cogs_gl_date_v := sysdate+1000;

        WHEN OTHERS THEN

          stmt_v := 315;

          RAISE;



      END;



      print_log('Matching COGS trans gl date: '||matched_cogs_gl_date_v);



      IF ( so_ar_inv_rec_gldate.transaction_gl_date <> matched_cogs_gl_date_v ) THEN



        stmt_v := 160;



        print_log('Updating Transcation GL Date.');



        UPDATE ajc_trv_interface

           SET transaction_gl_date = so_ar_inv_rec_gldate.transaction_gl_date

         WHERE oracle_xml_run_id = gv_run_id

           AND trv_shipping_order = so_ar_inv_rec_gldate.trv_shipping_order

           AND invoice_num = so_ar_inv_rec_gldate.invoice_num

           AND xml_file_type = match_to_file_type_v;



      END IF;



    END LOOP;



    COMMIT;



    -- ------------------------------------------------------------------------------------

    -- Validation - Step 2 -Generated (Reversal)

    -- ------------------------------------------------------------------------------------

    -- If the status is valid for Carrier-Inv or Customer-Inv AND an accrual exists for this SO then

    --      Find the valid, interfaced TRV accrual(Route-QAREV for Customer-Inv AND Route-QACOGS for Carrier-Inv) for the same 

    --      SO in the TRV_Interface table

    --      Replicate the records for the accrual invoice changing the signs on the line amounts AND adding an "R"

    --      to the end of the prior invoice number



    print_log('- STEP 2 Generate Reversals'); 



    FOR so_inv_rec IN SELECT_SO_Inv_Step2_GenRev LOOP



      print_log('SO#:'||so_inv_rec.trv_shipping_order || '|' || 

                     'Invoice# :' || so_inv_rec.invoice_num || '|' ||        

                     'File type :' || so_inv_rec.xml_file_type || '|' || 

                     'Trans GL Date: ' || so_inv_rec.transaction_gl_date);           



      stmt_v := 170;

      accrual_file_type_v := null;

      accrual_found_run_id_v := null;



      -- modified if statement, 12/2/19

      IF ( so_inv_rec.xml_file_type = 'Customer-Inv' ) THEN



        accrual_file_type_v := 'Route-QAREV';



      ELSIF ( so_inv_rec.xml_file_type = 'Carrier-Inv' ) THEN



        accrual_file_type_v := 'Route-QACOGS';



      ELSE 



        accrual_file_type_v := so_inv_rec.xml_file_type;



      END IF;



      -- Find the valid, interfaced TRV accrual(Route-QAREV for Customer-Inv AND 

      -- Route-QACOGS for Carrier-Inv) for the same SO in the TRV_Interface table



      stmt_v := 200;

      -- Does a valid, interfaced accrual exists for this shipping order?

      BEGIN



        SELECT MAX(oracle_xml_run_id)

          INTO accrual_found_run_id_v

          FROM ajc_trv_interface

         WHERE validation_status = 'Valid'

           AND interface_status = 'Interfaced' 

           AND xml_file_type = accrual_file_type_v

           AND trv_shipping_order = so_inv_rec.trv_shipping_order

           AND trv_cust_carr_acct_num = so_inv_rec.trv_cust_carr_acct_num

           AND ( trv_order_id = so_inv_rec.trv_order_id OR trv_order_id IS NULL );



      EXCEPTION

        WHEN NO_DATA_FOUND THEN

          accrual_found_run_id_v:= null; 

        WHEN OTHERS THEN

          RAISE;



      END;



      print_log('Accrual found in TRV Int table: ' || accrual_found_run_id_v);



      IF ( accrual_found_run_id_v IS NOT NULL ) THEN



        -- Replicate the records for the accrual changing the 

        -- signs on the line amounts AND 

        -- adding an "R" to the end of the prior invoice number



        stmt_v := 210;

        generate_accrual_rev_recs ( accrual_file_type_v,

                                    so_inv_rec.trv_shipping_order,

                                    so_inv_rec.transaction_gl_date,

                                    accrual_found_run_id_v,

                                    so_inv_rec.trv_cust_carr_acct_num,

                                   	so_inv_rec.trv_order_id );



        stmt_v := 220;

        print_log('Update Status to Reversed.');



        UPDATE ajc_trv_interface

           SET validation_status = 'Reversed'

         WHERE oracle_xml_run_id = accrual_found_run_id_v 

           AND validation_status = 'Valid'

           AND interface_status = 'Interfaced' 

           AND xml_file_type = accrual_file_type_v

           AND trv_shipping_order = so_inv_rec.trv_shipping_order

           AND trv_cust_carr_acct_num = so_inv_rec.trv_cust_carr_acct_num

       				AND ( trv_order_id = so_inv_rec.trv_order_id OR trv_order_id IS NULL );



      END IF; 



    END LOOP; --  SELECT_SO_Inv_Step2_GenRev



    COMMIT;



    -- Submit the control report

    step_2_valid_control_report_p;



    p_status := 'S';



    print_log('ajcl_bc_trv_pkg.step_2_validation (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';



  END step_2_validation;



  PROCEDURE get_ar_rec_distr (	p_trx_type_id 	         IN   NUMBER,

                               p_company           	  OUT   VARCHAR2, 

                               p_account  	           OUT   VARCHAR2,

                               p_department           OUT   VARCHAR2,

                               p_destination          OUT   VARCHAR2,

                               p_office   	           OUT   VARCHAR2,

                               p_origin 	             OUT   VARCHAR2,

                               p_division             OUT   VARCHAR2,

                               p_trx_type_name 	      OUT   VARCHAR2,

                               p_cm_trx_type_name    	OUT   VARCHAR2 ) IS



    v_cm_trx_type_id	ra_cust_trx_types_all.cust_trx_type_id%TYPE;



  BEGIN



    SELECT gcc.segment1 company, 

           aba.bc_account account, 

           null department,

           null destination, 

           null office, 

           null origin,

           null division,

           credit_memo_type_id, 

           name

      INTO p_company, 

           p_account, 

           p_department, 

           p_destination, 

           p_office, 

           p_origin, 

           p_division,

           v_cm_trx_type_id, 

           p_trx_type_name 

      FROM ra_cust_trx_types_all t, 

           gl_code_combinations gcc,

           ajc_bc_accounts aba

     WHERE t.gl_id_rec = gcc.code_combination_id

       AND t.org_id = gv_org_id

       AND t.cust_trx_type_id = p_trx_type_id

       AND aba.oracle_account = gcc.segment2;



    IF ( v_cm_trx_type_id IS NOT NULL ) THEN



      -- Find the CM trx type name

      BEGIN 



        SELECT name

          INTO p_cm_trx_type_name

          FROM ra_cust_trx_types_all

         WHERE org_id = gv_org_id 

           AND cust_trx_type_id = v_cm_trx_type_id;



      EXCEPTION

        WHEN OTHERS THEN

          NULL;



      END;



    END IF;



  END get_ar_rec_distr;



  PROCEDURE find_oracle_customer ( trv_cust_in 	            IN   NUMBER,

                                   oracle_addr_id_in        IN   NUMBER,

                                   --

                                   ora_cust_id_out         OUT   NUMBER,

                                   ora_cust_name_out       OUT   VARCHAR2,

                                   ora_cust_number_out     OUT   VARCHAR2,

                                   ora_addr_id_out         OUT   NUMBER,

                                   ora_bill_to_addr1_out   OUT   VARCHAR2, 

                                   ora_bill_to_addr2_out   OUT   VARCHAR2,

                                   ora_bill_to_addr3_out   OUT   VARCHAR2 ) IS



    customer_not_found       EXCEPTION;

    multi_customers_found    EXCEPTION;



  BEGIN



    print_log('ajcl_bc_trv_pkg.find_oracle_customer (+)');



    print_log( 'trv_cust_in: ' || trv_cust_in);

    print_log( 'oracle_addr_id_in: ' || oracle_addr_id_in);



    ora_cust_id_out := NULL;

    ora_cust_name_out := NULL;

    ora_cust_number_out := NULL;



    -- Find the Oracle customer

    BEGIN



      SELECT oracle_cust_id

        INTO ora_cust_id_out

        FROM ajcl_bc_cust_xref 

       WHERE bc_environment = gv_bc_environment

         AND source = 'TRV'

         AND source_type = 'CUSTOMER'

         AND bp_cust_id = trv_cust_in;



      print_log( 'ora_cust_id_out: ' || ora_cust_id_out);



      /*

      SELECT ca.account_number,

             hp.party_name 

        INTO ora_cust_number_out,

             ora_cust_name_out

        FROM hz_cust_accounts_all ca, 

             hz_parties hp

       WHERE ca.cust_account_id = ora_cust_id_out

         AND ca.party_id = hp.party_id;

      */



      SELECT customer_number,

             customer_name

        INTO ora_cust_number_out,

             ora_cust_name_out

        FROM ra_customers

       WHERE customer_id = ora_cust_id_out;   



      print_log( 'ora_cust_number_out: ' || ora_cust_number_out);

      print_log( 'ora_cust_name_out: ' || ora_cust_name_out);



    EXCEPTION

      WHEN NO_DATA_FOUND THEN

        RAISE customer_not_found;

      WHEN TOO_MANY_ROWS THEN

        RAISE multi_customers_found;

      WHEN OTHERS THEN 

        RAISE customer_not_found;



    END;



    -- Find the bill to site for the customer

    ora_addr_id_out := null;

    ora_bill_to_addr1_out := NULL;

    ora_bill_to_addr2_out := NULL;

    ora_bill_to_addr3_out := NULL;



    -- Check to see if there is an active primary bill-to site.

    -- Note: Only 1 primary bill-to site is allowed per customer



    BEGIN



      -- First see if there is a primary bill-to site

      SELECT cas.cust_acct_site_id     

        INTO ora_addr_id_out

        FROM hz_cust_acct_sites_all cas

       WHERE cas.org_id = gv_org_id 

         AND cas.status = 'A'

         AND cas.bill_to_flag = 'P'

         AND cas.cust_account_id = ora_cust_id_out; 



    EXCEPTION

      WHEN OTHERS THEN 

        NULL;



    END;



    print_log( '1. ora_addr_id_out: ' || ora_addr_id_out);



    IF ( oracle_addr_id_in IS NULL ) THEN 



      -- If No primary bill-to site found then

      -- check to see if there are any bill-to sites defined

      BEGIN



        SELECT MAX(cas.cust_acct_site_id)     

          INTO ora_addr_id_out

          FROM hz_cust_acct_sites_all cas

         WHERE cas.org_id = gv_org_id 

           AND cas.status= 'A'

           AND cas.bill_to_flag = 'Y'

           AND cas.cust_account_id = ora_cust_id_out;



        print_log( '2. ora_addr_id_out: ' || ora_addr_id_out);



      EXCEPTION

        WHEN OTHERS THEN

          NULL;



      END;



    END IF;



    IF ( ora_addr_id_out IS NULL ) THEN



      -- If no active bill-to sites found then

      -- check to see if there are any active addresses

      BEGIN



        SELECT MAX(cas.cust_acct_site_id)     

          INTO ora_addr_id_out

          FROM hz_cust_acct_sites_all cas

         WHERE cas.org_id = gv_org_id 

           AND cas.status = 'A'

           AND cas.cust_account_id = ora_cust_id_out;



        print_log( '3. ora_addr_id_out: ' || ora_addr_id_out);



      EXCEPTION

        WHEN OTHERS THEN

          NULL;



      END;



    END IF; -- oracle_addr_id_v is null



    -- Se obtiene la direccion

    SELECT SUBSTR(hl.address1,1,100) billToAddress1,

           SUBSTR(hl.address2,1,50) billToAddress2,

           SUBSTR(hl.address3,1,50) billToAddress3

      INTO ora_bill_to_addr1_out,

           ora_bill_to_addr2_out,

           ora_bill_to_addr3_out

      FROM hz_cust_acct_sites_all hcas, 

           hz_cust_site_uses_all hcsu,

           hz_party_sites ps,

           hz_locations hl

     WHERE hcas.bill_to_flag = 'P'

       AND hcas.cust_account_id = ora_cust_id_out

       AND hcas.org_id = gv_org_id

       AND hcsu.org_id = hcas.org_id

       AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id

       AND hcsu.cust_acct_site_id = ora_addr_id_out

       AND hcsu.status = 'A'

       AND hcsu.primary_flag = 'Y'

       AND hcsu.site_use_code = 'BILL_TO'

       AND hcas.party_site_id = ps.party_site_id

       AND ps.location_id = hl.location_id;



    print_log ( 'Oracle Address 1: ' || ora_bill_to_addr1_out );

    print_log ( 'Oracle Address 2: ' || ora_bill_to_addr2_out );

    print_log ( 'Oracle Address 3: ' || ora_bill_to_addr3_out );

    -- 20231011 SBanchieri



    print_log('ajcl_bc_trv_pkg.find_oracle_customer (-)');



  EXCEPTION

    WHEN customer_not_found THEN 

      print_log('ajcl_bc_trv_pkg.find_oracle_customer (!)' || SQLERRM);

      ora_cust_id_out := NULL;

      ora_addr_id_out := NULL;

    WHEN multi_customers_found THEN

      print_log('ajcl_bc_trv_pkg.find_oracle_customer (!). ' || SQLERRM);

      ora_cust_id_out := NULL; 

      ora_addr_id_out := NULL;



  END find_oracle_customer;



  PROCEDURE create_ar_trx ( shipping_order_in 		         IN   VARCHAR2,

                            invoice_num_in 	           		IN   VARCHAR2, 

                            trv_cust_carr_acct_num_in    IN   VARCHAR2,

                            xml_file_name_in 		          IN   VARCHAR2,

                            xml_file_type_in 		          IN   VARCHAR2,

                            oracle_xml_run_id_in 	     	 IN   NUMBER,

                            xml_file_date_in 		          IN   VARCHAR2,

                            trx_type_in 			              IN   VARCHAR2,

                            unbilled_ar_run_id_in	     	 IN   NUMBER,

                            unbilled_ar_invoice_num_in	  IN   VARCHAR2,

                            validation_status_in		       IN   VARCHAR2,

                            --

                            oracle_cust_id_in            IN   NUMBER,

                            oracle_cust_name_in          IN   VARCHAR2,

                            oracle_cust_number_in        IN   VARCHAR2,

                            oracle_addr_id_in            IN   NUMBER,

                            oracle_addr1_in              IN   VARCHAR2,

                            oracle_addr2_in              IN   VARCHAR2,

                            oracle_addr3_in              IN   VARCHAR2,

                            --

                            unbilled_inv_trx_type_name_v IN   VARCHAR2,

                            unbilled_cm_trx_type_name_v  IN   VARCHAR2,

                            billed_inv_trx_type_name_v   IN   VARCHAR2,

                            billed_cm_trx_type_name_v    IN   VARCHAR2,

                            term_name_v                  IN   VARCHAR2,

                            due_days_v                   IN   NUMBER,

                            --

                            b_rec_company                IN   VARCHAR2,

                            b_rec_account                IN   VARCHAR2,

                            b_rec_department             IN   VARCHAR2,

                            b_rec_destination            IN   VARCHAR2,

                            b_rec_office                 IN   VARCHAR2,

                            b_rec_origin                 IN   VARCHAR2,

                            b_rec_division               IN   VARCHAR2,

                            ub_rec_company               IN   VARCHAR2,

                            ub_rec_account               IN   VARCHAR2,

                            ub_rec_department            IN   VARCHAR2,

                            ub_rec_destination           IN   VARCHAR2,

                            ub_rec_office                IN   VARCHAR2,

                            ub_rec_origin                IN   VARCHAR2,

                            ub_rec_division              IN   VARCHAR2,

                            --

                            p_status                    OUT   VARCHAR2 ) IS



    stmt_v				   NUMBER;



    rev_company		     gl_code_combinations.segment1%TYPE;

    rev_account			    gl_code_combinations.segment2%TYPE;

    rev_department			 gl_code_combinations.segment3%TYPE;

    rev_destination			gl_code_combinations.segment4%TYPE;

    rev_office			     gl_code_combinations.segment5%TYPE;

    rev_origin		  	   gl_code_combinations.segment6%TYPE;

    rev_division		   	gl_code_combinations.segment7%TYPE;



    rec_company			    gl_code_combinations.segment1%TYPE;

    rec_account	    		gl_code_combinations.segment2%TYPE;

    rec_department		 	gl_code_combinations.segment3%TYPE;

    rec_destination			gl_code_combinations.segment4%TYPE;

    rec_office		     	gl_code_combinations.segment5%TYPE;

    rec_origin			     gl_code_combinations.segment6%TYPE;

    rec_division			   gl_code_combinations.segment7%TYPE;



    trx_number_v			   ra_customer_trx_all.trx_number%TYPE;

    invoice_amt_v			  NUMBER;

    jobcost_id_v			   ra_interface_distributions_all.attribute11%TYPE; 

    trv_item_seq_v			 ajc_trv_interface.trv_item_seq%TYPE; 

    load_id_v 			     ajc_trv_interface.trv_load_id%TYPE;

    item_v				        ajc_trv_interface.edi_item_code%TYPE;

    delivery_date_v			ajc_trv_interface.delivery_date%TYPE;

    po_num_v		       	ra_interface_lines_all.purchase_order%TYPE;

    line_cnt_v			     NUMBER;

    trx_date_v			     DATE;

    accr_trx_seq_v			 NUMBER;

    trx_type_name_v			ra_cust_trx_types.name%TYPE;

    payment_terms_v			ra_interface_lines_all.term_name%TYPE;



      CURSOR select_inv_line IS

      SELECT trv_item_seq,

             trv_load_id,

             NVL(edi_item_code, charge_type) item,

             transaction_gl_date,

             charge_amount,

             delivery_date,

             po_num,

             invoice_date,

             charge_type

        FROM ajc_trv_interface

       WHERE trv_shipping_order = shipping_order_in

         AND invoice_num = invoice_num_in

         AND	trv_cust_carr_acct_num = trv_cust_carr_acct_num_in

         AND	xml_file_name = xml_file_name_in

         AND	xml_file_type = xml_file_type_in

         AND	oracle_xml_run_id = oracle_xml_run_id_in

         AND xml_file_date = xml_file_date_in

         AND interface_status IS NULL

         AND validation_status IN ('Valid','Generated')

         AND oracle_xml_run_id = gv_run_id

         AND decode(sign(charge_amount),-1,'CM','INV') = trx_type_in

    ORDER BY trv_item_seq;



    v_bc_class                       VARCHAR2(10);

    v_header_company                 VARCHAR2(10);

    v_header_account                 VARCHAR2(10);

    v_header_department              VARCHAR2(10);

    v_header_destination             VARCHAR2(10);

    v_header_office                  VARCHAR2(10);

    v_header_origin                  VARCHAR2(10);    

    v_header_division                VARCHAR2(10);



    v_line_company                   VARCHAR2(10);

    v_line_account                   VARCHAR2(10);

    v_line_department                VARCHAR2(10);

    v_line_destination               VARCHAR2(10);

    v_line_office                    VARCHAR2(10);

    v_line_origin                    VARCHAR2(10);    

    v_line_division                  VARCHAR2(10);



    -- 20240823

    v_xml_file_date                  DATE;

    -- 20240823



  BEGIN



    payment_terms_v := null;



    print_log('ajcl_bc_trv_pkg.create_ar_trx (+)');

    print_log('** Customer id: ' || oracle_cust_id_in || '|' || ' Address id: ' || oracle_addr_id_in );



    -- Determine the po number and trx type

    IF ( xml_file_type_in = 'Customer-Inv' ) THEN



      -- BILLED

      rec_company := b_rec_company; 

      rec_account := b_rec_account; 

      rec_department := b_rec_department; 

      rec_destination := b_rec_destination; 

      rec_office := b_rec_office; 

      rec_origin := b_rec_origin; 

      rec_division := b_rec_division; 



      trx_number_v := SUBSTR(invoice_num_in,1,17);



      po_num_v := invoice_num_in;



      IF ( trx_type_in = 'INV' ) THEN



        trx_type_name_v := billed_inv_trx_type_name_v;

        v_bc_class := 'INV';



      ELSE



        trx_type_name_v := billed_cm_trx_type_name_v;

        v_bc_class := 'CM';



      END IF;



    ELSE



      -- UNBILLED (ACCRUAL)

      rec_company := ub_rec_company; 

      rec_account := ub_rec_account; 

      rec_department := ub_rec_department; 

      rec_destination := ub_rec_destination; 

      rec_office := ub_rec_office; 

      rec_origin := ub_rec_origin; 

      rec_division := ub_rec_division; 



      trx_number_v := SUBSTR(invoice_num_in,1,17); 



      po_num_v := null;



      IF ( trx_type_in = 'INV' ) THEN



        trx_type_name_v := unbilled_inv_trx_type_name_v;

        v_bc_class := 'INV';



      ELSE



        trx_type_name_v := unbilled_cm_trx_type_name_v;

        v_bc_class := 'CM';



      END IF;



    END IF;



    print_log('Trx#: '||trx_number_v);

    print_log('Trx type: '||trx_type_name_v);

    print_log('BC Class: '||v_bc_class);



    -- SBanchieri se obtiene la cuenta REC (header) para BC

    v_header_company := rec_company;

    v_header_account := rec_account;

    v_header_department := rec_department;

    v_header_destination := rec_destination;

    v_header_office := rec_office;

    v_header_origin := rec_origin;    

    v_header_division := rec_division;



    print_log ( 'v_header_company: ' || v_header_company );

    print_log ( 'v_header_account: ' || v_header_account );

    print_log ( 'v_header_department: ' || v_header_department );

    print_log ( 'v_header_destination: ' || v_header_destination );

    print_log ( 'v_header_office: ' || v_header_office );

    print_log ( 'v_header_origin: ' || v_header_origin );    

    print_log ( 'v_header_division: ' || v_header_division );



    jobcost_id_v := 'TRV' || shipping_order_in;



    line_cnt_v := 0;



    FOR line_rec IN select_inv_line LOOP



      -- Determine the trx date

      IF ( xml_file_type_in ='Customer-Inv' ) THEN



        trx_date_v := line_rec.delivery_date;



      ELSE



        trx_date_v := line_rec.transaction_gl_date;



      END IF;



      print_log('Item Seq: ' || line_rec.trv_item_seq || '|' ||

                'Load id: ' || line_rec.trv_load_id || '|' ||

                'Item: ' || line_rec.item || '|' ||

                'GL Date: ' || line_rec.transaction_gl_date || '|' ||

                'Amt: ' || line_rec.charge_amount || '|' ||

                'Delivery Date: ' || line_rec.delivery_date || '|' ||

                'Charge Type: ' || line_rec.charge_type || '|' ||

                'Trx Date: ' || trx_date_v);



      -- Get the REV accounts from the TRV Item



      -- The validation program ensures the item is in the ajc_ies_items table

      stmt_v := 100;



      SELECT rev_company,

             rev_accountno,

             rev_department,

             rev_destination,

             rev_office,

             rev_origin,

             rev_division

        INTO v_line_company,

             v_line_account,

             v_line_department,

             v_line_destination,

             v_line_office,

             v_line_origin,             

             v_line_division

        FROM ajcl_bc_ies_items

       WHERE bc_environment = gv_bc_environment

         AND NVL(inactive_date,SYSDATE + 1) > SYSDATE

         AND charge_type_code = line_rec.item

         AND business_line = NVL(( SELECT business_line

                                     FROM ajcl_bc_ies_business_lines 

                                    WHERE bc_environment = gv_bc_environment

                                      AND enabled = 'Y'

                                      AND fs_office_code = SUBSTR(shipping_order_in,LENGTH(shipping_order_in),1) ),

                                 ( SELECT business_line

                                     FROM ajcl_bc_ies_business_lines 

                                    WHERE bc_environment = gv_bc_environment

                                      AND enabled = 'Y'

                                      AND trv_default = 'Y' ));



      print_log ( 'v_line_company: ' || v_line_company );

      print_log ( 'v_line_account: ' || v_line_account );

      print_log ( 'v_line_department: ' || v_line_department );

      print_log ( 'v_line_destination: ' || v_line_destination );

      print_log ( 'v_line_office: ' || v_line_office ); 

      print_log ( 'v_line_origin: ' || v_line_origin );      

      print_log ( 'v_line_division: ' || v_line_division ); 



      IF ( trx_type_in = 'INV' ) THEN



        payment_terms_v := term_name_v;



      ELSE



        payment_terms_v := null;



      END IF;



      -- Create the invoice lines	



      line_cnt_v := line_cnt_v + 1;

      invoice_amt_v := invoice_amt_v + line_rec.charge_amount;

      stmt_v := 110;



      -- 20240823

      -- Format xml_file_date_in

      BEGIN



        v_xml_file_date := TO_DATE(xml_file_date_in,'DD-MON-YY');



      EXCEPTION

        WHEN OTHERS THEN



          BEGIN



            IF ( SUBSTR(xml_file_date_in,6) LIKE '/00%' ) THEN



              v_xml_file_date := TO_DATE(SUBSTR(xml_file_date_in,1,6) || SUBSTR(xml_file_date_in,9),'DD/MM/YY');



            ELSE



              v_xml_file_date := TO_DATE(xml_file_date_in,'DD/MM/YYYY');



            END IF;



          EXCEPTION

            WHEN OTHERS THEN

              v_xml_file_date := NULL;



          END;



      END;

      -- 20240823



      INSERT

        INTO ajcl_bc_trv_ar_lines

           ( bc_environment,

             transactionNo,

             transactiondate,

             class,

             termname,

             termduedate,

             gldate,

             invoicecurrencycode,

             exchangedate,

             exchangerate,

             exchangeratetype,

             purchaseorder,

             billtocustomerid,

             billtocustomername,

             billtocustomerno,

             billtoaddress1,

             billtoaddress2,

             billtoaddress3,

             header_company,

             header_account,

             header_department,

             header_destination,

             header_office,

             header_origin,             

             header_division,

             appliestodoctype,

             appliestodocno,

             overrideflag,

             commentsajc_ine,

             dff_shipping_order,

             dff_invoice_num,

             dff_customer_carrier_acct_num,

             dff_xml_file_name,

             dff_oracle_xml_run_id,

             dff_xml_file_date,

             lineno,

             description,

             quantity,

             unitsellingprice,

             extendedamount,

             accountedamount,

             line_company,

             line_account,

             line_department,

             line_destination,

             line_office,

             line_origin,             

             line_division,

             line_worksheet,

             salesordersource,

             salesorder,

             salesorderrevision,

             salesorderline,

             salesorderdate,

             alreasonmeaning,

             dff_item_sequence,

             dff_mg_load_id,

             dff_edi_item_code_charge_type,

             dff_delivery_date,

             org_id,

             request_id,

             creation_date,

             created_by,

             last_update_date,

             last_updated_by,

             status )

    VALUES ( gv_bc_environment,

             trx_number_v, 

             TO_CHAR(line_rec.invoice_date,'YYYY-MM-DD'), -- transactiondate,

             v_bc_class, -- class,

             payment_terms_v, -- termname,

             -- 20241105 

             -- TO_CHAR(line_rec.transaction_gl_date + due_days_v,'YYYY-MM-DD'), -- termduedate 

             TO_CHAR(line_rec.invoice_date + due_days_v,'YYYY-MM-DD'), -- termduedate 

             -- 20241105

             TO_CHAR(line_rec.transaction_gl_date,'YYYY-MM-DD'), -- gldate,

             'USD', -- invoicecurrencycode,

             TO_CHAR(line_rec.transaction_gl_date,'YYYY-MM-DD'), -- exchangedate,

             1, -- exchangerate,

             'User', -- exchangeratetype,

             NULL, -- purchaseorder,

             oracle_cust_id_in, -- billtocustomerid,

             oracle_cust_name_in, -- billtocustomername,

             oracle_cust_number_in, -- billtocustomerno,

             oracle_addr1_in, -- billtoaddress1,

             oracle_addr2_in, -- billtoaddress2, 

             oracle_addr3_in, -- billtoaddress3, 

             v_header_company,

             v_header_account,

             v_header_department,

             v_header_destination,

             v_header_office,

             v_header_origin,             

             v_header_division,

             NULL, -- appliestodoctype,

             NULL, -- appliestodocno,

             NULL, -- overrideflag,

             NULL, -- commentsajc_ine,

             shipping_order_in, -- dff_shipping_order,

             invoice_num_in, -- dff_invoice_num,

             trv_cust_carr_acct_num_in, -- dff_customer_carrier_acct_num,

             xml_file_name_in, -- dff_xml_file_name,

             oracle_xml_run_id_in, -- dff_oracle_xml_run_id,

             -- 20240823 TO_CHAR(TO_DATE(xml_file_date_in,'DD-MON-YY'),'YYYY-MM-DD'), -- dff_xml_file_date,

             TO_CHAR(v_xml_file_date,'YYYY-MM-DD'), -- dff_xml_file_date,

             --

             line_cnt_v, -- lineno,

             line_rec.charge_type, -- description,

             1, -- quantity,

             ABS(line_rec.charge_amount), -- unitsellingprice,

             ABS(line_rec.charge_amount), -- extendedamount,

             ABS(line_rec.charge_amount), -- accountedamount,

             v_line_company,

             v_line_account,

             v_line_department,

             v_line_destination,

             v_line_office,

             v_line_origin,             

             v_line_division,

             jobcost_id_v, -- line_worksheet,

             NULL, -- salesordersource,

             NULL, -- salesorder,

             NULL, -- salesorderrevision,

             NULL, -- salesorderline,

             NULL, -- salesorderdate,

             NULL, -- alreasonmeaning,

             line_rec.trv_item_seq, -- dff_item_sequence,

             line_rec.trv_load_id, -- dff_mg_load_id,

             line_rec.item, -- dff_edi_item_code_charge_type,

             TO_CHAR(line_rec.delivery_date,'YYYY-MM-DD'), -- dff_delivery_date,

             gv_org_id,

             gv_request_id,

             SYSDATE, -- creation_date

             gv_user_id, -- created_by,

             SYSDATE, -- last_update_date,

             gv_user_id, -- last_updated_by,

             'NEW' -- status 

             );



    END LOOP; 



    p_status := 'S';

    print_log('ajcl_bc_trv_pkg.create_ar_trx (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_trv_pkg.create_ar_trx (!). Error: ' || SQLERRM);



  END create_ar_trx;



  PROCEDURE print_ar_insert_report_p IS



    v_columns   VARCHAR2(2000);



      CURSOR c_report_detail IS

      SELECT 'TRV' || h.dff_shipping_order job_cost_id,

             h.transactionNo trx_number,

             h.class cust_trx_type_name,

             h.billToCustomerNo account_number,

             h.transactionDate trx_date,

             h.glDate gl_date,

             ( SELECT COUNT(1)

                 FROM ajcl_bc_trv_ar_lines l

                WHERE l.transactionNo = h.transactionNo

                  AND l.billToCustomerNo = h.billToCustomerNo

                  AND l.bc_environment = gv_bc_environment ) cnt,

             DECODE(h.class,'INV',h.amount,0) inv_amt,

             DECODE(h.class,'CM',h.amount,0) cm_amt

        FROM ajcl_bc_trv_ar_headers h

       WHERE h.status = 'NEW'

         AND h.org_id = gv_org_id

         AND h.request_id = gv_request_id

         AND bc_environment = gv_bc_environment

       UNION 

      SELECT 'No Data Found' job_cost_id,

             NULL, 

             NULL, 

             NULL, 

             NULL,

             NULL, 

             NULL, 

             NULL, 

             NULL

        FROM dual

       WHERE 0 = ( SELECT COUNT(1)

                     FROM ajcl_bc_trv_ar_headers h

                    WHERE h.status = 'NEW'

                      AND h.org_id = gv_org_id

                      AND h.request_id = gv_request_id

                      AND h.bc_environment = gv_bc_environment )

    ORDER BY 1,2;                    



    v_inv_total   VARCHAR2(2000);

    v_cm_total    VARCHAR2(2000);



  BEGIN



    SELECT COUNT(DECODE(h.class,'INV',1,0)),

           COUNT(DECODE(h.class,'CM',1,0))

      INTO v_inv_total,

           v_cm_total

      FROM ajcl_bc_trv_ar_headers h

     WHERE h.status = 'NEW'

       AND h.org_id = gv_org_id

       AND h.request_id = gv_request_id

       AND h.bc_environment = gv_bc_environment

       AND h.class = 'INV';



    IF ( gv_file_format = 'CSV' ) THEN



      print_output ( ' ' );

      print_output ( 'AJCL TRV AR Interface Control Report' );

      print_output ( ' ' );



      v_columns := 'Job Cost ID' || '|' || 

                   'Trx Num' || '|' || 

                   'Trx Type' || '|' || 

                   'Customer Num' || '|' || 

                   'Invoice Date' || '|' || 

                   'GL Date' || '|' || 

                   'Line Count' || '|' || 

                   'Invoice Amount' || '|' || 

                   'Credit Memo Amount';



      print_output ( v_columns );



      FOR crptd IN c_report_detail LOOP



        print_output ( crptd.job_cost_id || '|' || 

                       crptd.trx_number || '|' || 

                       crptd.cust_trx_type_name || '|' || 

                       crptd.account_number || '|' || 

                       crptd.trx_date || '|' || 

                       crptd.gl_date || '|' || 

                       crptd.cnt || '|' || 

                       crptd.inv_amt || '|' || 

                       crptd.cm_amt );



      END LOOP;



      print_output ( ' ' );



      print_output ( 'Total Invoice Count|' || v_inv_total );

      print_output ( 'Total Credit Memo Count|' || v_cm_total );



    ELSIF ( gv_file_format = 'XLSX' ) THEN 



      -- Column Names

      print_output_xlsx ( p_section => 'AR Interface Control Report',

                          p_column1 => 'Job Cost ID',

                          p_column2 => 'Trx Num',

                          p_column3 => 'Trx Type',

                          p_column4 => 'Customer Num',

                          p_column5 => 'Invoice Date',

                          p_column6 => 'GL Date',

                          p_column7 => 'Line Count',

                          p_column8 => 'Invoice Amount',

                          p_column9 => 'Credit Memo Amount' );    



      FOR crptd IN c_report_detail LOOP



        print_output_xlsx ( p_section => 'AR Interface Control Report',

                            p_column1 => crptd.job_cost_id,

                            p_column2 => crptd.trx_number,

                            p_column3 => crptd.cust_trx_type_name,

                            p_column4 => crptd.account_number, 

                            p_column5 => crptd.trx_date,

                            p_column6 => crptd.gl_date,

                            p_column7 => crptd.cnt,

                            p_column8 => crptd.inv_amt,

                            p_column9 => crptd.cm_amt );



      END LOOP;  



      -- Column Names

      print_output_xlsx ( p_section => 'Total Invoices / Credit Memos',

                          p_column1 => 'Invoices Count',

                          p_column2 => 'Credit Memos Count' );    



      print_output_xlsx ( p_section => 'Total Invoices / Credit Memos',

                          p_column1 => v_inv_total,

                          p_column2 => v_cm_total );



    END IF;



  END print_ar_insert_report_p; 



  PROCEDURE ar_insert_p ( p_status      OUT   VARCHAR2,

                          p_error_msg   OUT   VARCHAR2 ) IS



    -- Constants

    -- dff_context_c			               ra_interface_lines.interface_line_context%TYPE := 'TURVO';    

    line_type_c			                 ra_interface_lines.line_type%TYPE := 'LINE';

    uom_c			           	           VARCHAR2(10) := 'Each';



    -- Variables

    ub_rec_company                 gl_code_combinations.segment1%TYPE;

    ub_rec_account                 gl_code_combinations.segment1%TYPE;

    ub_rec_department              gl_code_combinations.segment1%TYPE;

    ub_rec_destination             gl_code_combinations.segment1%TYPE;

    ub_rec_office                  gl_code_combinations.segment1%TYPE;

    ub_rec_origin                  gl_code_combinations.segment1%TYPE;

    ub_rec_division                gl_code_combinations.segment1%TYPE;



    unbilled_inv_trx_type_name_v	  ra_cust_trx_types.name%TYPE; 

    unbilled_cm_trx_type_name_v	   ra_cust_trx_types.name%TYPE;



    b_rec_seg1_v			                gl_code_combinations.segment1%TYPE;

    b_rec_seg2_v			                gl_code_combinations.segment2%TYPE;

    b_rec_seg3_v			                gl_code_combinations.segment3%TYPE;

    b_rec_seg4_v			                gl_code_combinations.segment4%TYPE;

    b_rec_seg5_v			                gl_code_combinations.segment5%TYPE;

    b_rec_seg6_v			                gl_code_combinations.segment6%TYPE;

    b_rec_seg7_v			                gl_code_combinations.segment7%TYPE;

    billed_inv_trx_type_name_v	    ra_cust_trx_types_all.name%TYPE; 

    billed_cm_trx_type_name_v	     ra_cust_trx_types_all.name%TYPE;



    user_id_v                      NUMBER;

    prev_cust_trx_id_v 		          ra_customer_trx_all.customer_trx_id%TYPE;

    prev_trx_num_v			              ra_customer_trx_all.trx_number%TYPE;

    prev_trx_seq_no_v		            ra_customer_trx_all.trx_number%TYPE;

    prev_trx_invseq_no_v		         ra_customer_trx_all.trx_number%TYPE;



    oracle_cust_id_v	             	hz_cust_accounts.cust_account_id%TYPE;

    oracle_addr_id_v		             hz_cust_acct_sites.cust_acct_site_id%TYPE;

    term_name_v			                 ra_terms.name%TYPE;

    due_days_v                     NUMBER;

    gl_date_v			                   DATE;

    amt_credited_v 			             NUMBER;

    error_code_v    		             NUMBER;

    trv_batch_source_name_v		      ra_batch_sources.name%TYPE;

    next_invseq_v		               	NUMBER;	



    inv_distr_attr1_v		            ra_cust_trx_line_gl_dist_all.attribute1%TYPE;

    error_line_v			                NUMBER;

    stmt_v				                     NUMBER;

    rec_cnt_v		                   	NUMBER;

    num_correctables_v		           NUMBER := 0;

    prog_failed_v			               BOOLEAN; 

    stop_message_v			              VARCHAR2(200) := NULL;

    stop_processing  		            EXCEPTION;

    -- 20240823

    e_create_ar_trx                EXCEPTION;

    -- 20240823



    -- 20231011

    oracle_cust_name_v	            hz_parties.party_name%TYPE;

    oracle_cust_number_v	          hz_cust_accounts.account_number%TYPE;



    oracle_addr1_v                 VARCHAR2(100);

    oracle_addr2_v                 VARCHAR2(50);

    oracle_addr3_v                 VARCHAR2(50);

    -- 20231011



    -- 20240823

    v_appliesToDocNo               ajcl_bc_trv_ar_headers.appliestodocno%TYPE;

    v_appliesToDocType             ajcl_bc_trv_ar_headers.appliestodoctype%TYPE;

    -- 20240823



      CURSOR select_trv_trx IS

      SELECT DISTINCT

             trv_shipping_order,

             invoice_num,

             trv_cust_carr_acct_num,

             xml_file_name,

             xml_file_type, 

             oracle_xml_run_id,

             xml_file_date,

             decode(sign(charge_amount),-1,'CM','INV')  trx_type,

             unbilled_ar_run_id,

             unbilled_ar_invoice_num,

             validation_status

        FROM ajc_trv_interface

       WHERE validation_status IN ('Valid','Generated')

         AND xml_file_type IN ('Customer-Inv', 'Route-QAREV')

         AND interface_status IS NULL

         AND oracle_xml_run_id = gv_run_id 

    ORDER BY xml_file_type, 

             trx_type ASC, 

             invoice_num;



    -- Cursor para generar Headers

      CURSOR c_headers IS

      SELECT header_company company,

             transactionNo,

             transactionDate,

             class,

             termName,

             termDueDate,

             glDate,

             invoicecurrencycode,

             exchangedate,

             exchangerate,

             exchangeratetype,

             purchaseorder,

             SUM(extendedAmount) amount,

             header_account account,

             header_department department,

             header_destination destination,

             header_office office,

             header_origin origin,             

             header_division division,

             billtocustomerid,

             billtocustomername,

             billtocustomerno,

             billtoaddress1,

             billtoaddress2,

             billtoaddress3,

             appliestodoctype,

             appliestodocno,

             overrideflag,

             commentsajc_ine,

             dff_shipping_order,

             dff_invoice_num,

             dff_customer_carrier_acct_num,

             dff_xml_file_name,

             dff_oracle_xml_run_id,

             dff_xml_file_date,

             status

        FROM ajcl_bc_trv_ar_lines

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND status = 'NEW'

    GROUP BY header_company,

             transactionNo,

             transactionDate,

             class,

             termName,

             termDueDate,

             glDate,

             invoicecurrencycode,

             exchangedate,

             exchangerate,

             exchangeratetype,

             purchaseorder,

             header_account,

             header_department,

             header_destination,

             header_office,

             header_origin,             

             header_division,

             billtocustomerid,

             billtocustomername,

             billtocustomerno,

             billtoaddress1,

             billtoaddress2,

             billtoaddress3,

             appliestodoctype,

             appliestodocno,

             overrideflag,

             commentsajc_ine,

             dff_shipping_order,

             dff_invoice_num,

             dff_customer_carrier_acct_num,

             dff_xml_file_name,

             dff_oracle_xml_run_id,

             dff_xml_file_date,

             status;



    v_transactionNo   AJCL_BC_TRV_AR_HEADERS.transactionNo%TYPE;



  BEGIN



    print_log ( 'ajcl_bc_trv_pkg.ar_insert_p (+)' );



    stmt_v := 5;



    -- If there are Correctables in this run then stop processing

    SELECT COUNT(1)

      INTO num_correctables_v

      FROM ajc_trv_interface

     WHERE validation_status = 'Correctable'

       AND oracle_xml_run_id = gv_run_id ;



    IF ( num_correctables_v > 0 ) THEN



      stop_message_v := 'Correctable Errors Found. No Interface Processing Occurred.';

      RAISE stop_processing;



    END IF;



    stmt_v := 10;



    SELECT name

      INTO trv_batch_source_name_v

      FROM ra_batch_sources_all

     WHERE org_id = gv_org_id 

       AND batch_source_id = gv_default_batch_source;



    stmt_v := 20;



    get_ar_rec_distr ( gv_default_accrual_trx_type, 

                       ub_rec_company,

                       ub_rec_account,

                       ub_rec_department,

                       ub_rec_destination,

                       ub_rec_office, 

                       ub_rec_origin, 

                       ub_rec_division, 

                       unbilled_inv_trx_type_name_v, 

                       unbilled_cm_trx_type_name_v );



    print_log('Unbilled Inv type: ' || unbilled_inv_trx_type_name_v);

    print_log('Unbilled CM type: ' || unbilled_cm_trx_type_name_v);



    stmt_v := 30;



    get_ar_rec_distr ( gv_default_billed_trx_type, 

                       b_rec_seg1_v,

                       b_rec_seg2_v,

                       b_rec_seg3_v,

                       b_rec_seg4_v, 

                       b_rec_seg5_v, 

                       b_rec_seg6_v, 

                       b_rec_seg7_v, 

                       billed_inv_trx_type_name_v, 

                       billed_cm_trx_type_name_v );



    print_log('Billed Inv type: ' || billed_inv_trx_type_name_v);

    print_log('Billed CM type: ' || billed_cm_trx_type_name_v);



    rec_cnt_v := 0;



    FOR trx_rec IN select_trv_trx LOOP



      BEGIN



        rec_cnt_v := rec_cnt_v + 1;



        print_log( 'Shipping Order: ' || trx_rec.trv_shipping_order || ' - ' || 'Invoice: ' || trx_rec.invoice_num);

        print_log( 'Customer: ' || trx_rec.trv_cust_carr_acct_num || ' - ' || 'XML File: ' || trx_rec.xml_file_name);

        print_log( 'Run id: ' || trx_rec.oracle_xml_run_id || ' - ' || 'Trx type: ' || trx_rec.trx_type);



        stmt_v := 40;

        find_oracle_customer ( trx_rec.trv_cust_carr_acct_num, 

                               oracle_addr_id_v, 

                               --

                               oracle_cust_id_v, 

                               --

                               oracle_cust_name_v, 

                               oracle_cust_number_v,

                               --

                               oracle_addr_id_v,

                               --

                               oracle_addr1_v,

                               oracle_addr2_v,

                               oracle_addr3_v);



        print_log ( 'Customer ID: ' || oracle_cust_id_v);

        print_log ( 'Customer Name: ' || oracle_cust_name_v);

        print_log ( 'Customer Number: ' || oracle_cust_number_v);

        print_log ( 'Address ID: ' || oracle_addr_id_v);

        print_log ( 'Address1: ' || oracle_addr1_v);

        print_log ( 'Address2: ' || oracle_addr2_v);

        print_log ( 'Address3: ' || oracle_addr3_v);



        stmt_v := 50;

        term_name_v := null;

        due_days_v := null;



        -- Find the payment terms from the customer header profile

        BEGIN



          SELECT t.name,

                 l.due_days

            INTO term_name_v,

                 due_days_v

            FROM ra_terms t, 

                 ra_terms_lines l,

                 hz_customer_profiles cp

           WHERE cp.status = 'A'

             AND cp.site_use_id IS NULL

             AND cp.cust_account_id = oracle_cust_id_v 

             AND cp.standard_terms = t.term_id

             AND t.term_id = l.term_id;



        EXCEPTION

         WHEN NO_DATA_FOUND THEN

           print_log('Payment term not found for customer');

         WHEN OTHERS THEN 

           RAISE;



        END;



        create_ar_trx (	trx_rec.trv_shipping_order,

                        trx_rec.invoice_num, 

                        trx_rec.trv_cust_carr_acct_num,

                        trx_rec.xml_file_name,

                        trx_rec.xml_file_type,

                        trx_rec.oracle_xml_run_id,

                        trx_rec.xml_file_date,

                        trx_rec.trx_type,

                        trx_rec.unbilled_ar_run_id,

                        trx_rec.unbilled_ar_invoice_num,

                        trx_rec.validation_status,

                        --

                        --

                        oracle_cust_id_v,

                        oracle_cust_name_v,

                        oracle_cust_number_v,

                        --

                        oracle_addr_id_v,

                        oracle_addr1_v,

                        oracle_addr2_v,

                        oracle_addr3_v,

                        --

                        unbilled_inv_trx_type_name_v,

                        unbilled_cm_trx_type_name_v,

                        billed_inv_trx_type_name_v,

                        billed_cm_trx_type_name_v,

                        term_name_v,

                        due_days_v,

                        --

                        b_rec_seg1_v,

                        b_rec_seg2_v,

                        b_rec_seg3_v,

                        b_rec_seg4_v,

                        b_rec_seg5_v,

                        b_rec_seg6_v,

                        b_rec_seg7_v,

                        ub_rec_company,

                        ub_rec_account,

                        ub_rec_department,

                        ub_rec_destination,

                        ub_rec_office,

                        ub_rec_origin, 

                        ub_rec_division,

                        p_status );



        -- 20240823

        IF ( p_status != 'S' ) THEN



          RAISE e_create_ar_trx;



        END IF;

        -- 20240823



        UPDATE ajc_trv_interface

           SET interface_status = 'Interfaced'

         WHERE trv_shipping_order = trx_rec.trv_shipping_order

           AND invoice_num = trx_rec.invoice_num

           AND trv_cust_carr_acct_num = trx_rec.trv_cust_carr_acct_num

           AND xml_file_name = trx_rec.xml_file_name

           AND xml_file_type = trx_rec.xml_file_type

           AND oracle_xml_run_id		= trx_rec.oracle_xml_run_id

           AND xml_file_date = trx_rec.xml_file_date

           and DECODE(SIGN(charge_amount),-1,'CM','INV') = trx_rec.trx_type;



      END;



    END LOOP;



    print_log ( 'Before generating the headers, all lines of the receipts that have at least one line with ERROR are marked with ERROR.' );



    UPDATE ajcl_bc_trv_ar_lines a

       SET status = 'ERROR'

     WHERE request_id = gv_request_id

       AND bc_environment = gv_bc_environment

       AND transactionno IN ( SELECT transactionno 

                                FROM ajcl_bc_trv_ar_lines b 

                               WHERE b.request_id = a.request_id

                                 AND b.bc_environment = gv_bc_environment

                                 AND b.status = 'ERROR' );



    -- COMMIT;



    -- Se generan las cabeceras a partir de las lineas insertadas

    FOR ch IN c_headers LOOP



      v_transactionNo := NULL;

      v_appliesToDocNo := NULL;

      v_appliesToDocType := NULL;



      IF ( ch.transactionNo LIKE 'TRVA-%' ) THEN



        SELECT 'TRVA-' || ajcl_bc_trv_transaction_no_s.NEXTVAL

          INTO v_transactionNo

          FROM DUAL;



        -- 20240823

        -- Si es una CM de accrual, se verifica si se encuentra un INV en BC al que tiene que aplicar

        IF ( ch.class = 'CM' ) THEN



          print_log ( 'Transaction is an accrual credit memo R. We checked if the invoice against which it should be applied is found.' );

          print_log ( 'billtocustomerno:' || ch.billtocustomerno );

          print_log ( 'dff_shipping_order:' || ch.dff_shipping_order );

          print_log ( 'dff_customer_carrier_acct_num:' || ch.dff_customer_carrier_acct_num );

          print_log ( 'dff_invoice_num:' || ch.dff_invoice_num );



          BEGIN



            SELECT psh.transactionno,

                   'Invoice'

              INTO v_appliesToDocNo,

                   v_appliesToDocType

              FROM ajcl_bc_posted_sd_headers psh

             WHERE psh.billtocustomerno = ch.billtocustomerno

               AND psh.bc_environment = gv_bc_environment

               AND psh.class = 'INV'

               AND psh.transactionno LIKE 'TRVA-%'

               AND psh.trvshippingorder = ch.dff_shipping_order

               AND psh.trvcustomercarrieracctnum = ch.dff_customer_carrier_acct_num

               AND psh.trvinvoicenum LIKE REPLACE(ch.dff_invoice_num,'R','%')

               AND psh.remainingamount > 0;



            print_log ( 'Invoice found against which the credit memo applies. Invoice Transaction No.: ' || v_appliesToDocNo );



          EXCEPTION

            WHEN OTHERS THEN

              print_log ( 'Invoice not found against which the credit memo applies.' );

              v_appliesToDocNo := NULL;

              v_appliesToDocType := NULL;



          END;



        END IF;

        -- 20240823



      ELSE



        v_transactionNo := ch.transactionNo;



      END IF;



      INSERT

        INTO ajcl_bc_trv_ar_headers

           ( bc_environment,

             company,

             transactionNo,

             transactionDate,

             class,

             termName,

             termDueDate,

             glDate,

             invoicecurrencycode,

             exchangedate,

             exchangerate,

             exchangeratetype,

             purchaseorder,

             amount,

             accountedamount,

             account,

             department,

             destination,

             office,

             origin,             

             division,

             billtocustomerid,

             billtocustomername,

             billtocustomerno,

             billtoaddress1,

             billtoaddress2,

             billtoaddress3,

             appliestodoctype,

             appliestodocno,

             overrideflag,

             commentsajc_ine,

             dff_shipping_order,

             dff_invoice_num,

             dff_customer_carrier_acct_num,

             dff_xml_file_name,

             dff_oracle_xml_run_id,

             dff_xml_file_date,

             org_id,

             request_id,

             creation_date,

             created_by,

             last_update_date,

             last_updated_by,

             status )

    VALUES ( gv_bc_environment,

             ch.company,

             v_transactionNo, 

             ch.transactionDate,

             ch.class,

             ch.termName,

             ch.termDueDate, 

             ch.glDate,

             ch.invoicecurrencycode,

             ch.exchangedate,

             ch.exchangerate,

             ch.exchangeratetype,

             ch.purchaseorder,

             ch.amount,

             ch.amount,

             ch.account,

             ch.department,

             ch.destination,

             ch.office,

             ch.origin,             

             ch.division,

             ch.billtocustomerid,

             ch.billtocustomername,

             ch.billtocustomerno,

             ch.billtoaddress1,

             ch.billtoaddress2,

             ch.billtoaddress3,

             -- 20240823

             -- ch.appliestodoctype,

             v_appliesToDocType,

             -- ch.appliestodocno,

             v_appliesToDocNo,

             -- 20240823

             ch.overrideflag,

             ch.commentsajc_ine,

             ch.dff_shipping_order,

             ch.dff_invoice_num,

             ch.dff_customer_carrier_acct_num,

             ch.dff_xml_file_name,

             ch.dff_oracle_xml_run_id,

             ch.dff_xml_file_date,

             gv_org_id,

             gv_request_id,

             SYSDATE, -- creation_date

             gv_user_id,

             SYSDATE, -- last_update_date

             gv_user_id,

             'NEW' );



      -- Se actualiza el campo transactionNo en las líneas del comprobante

      UPDATE ajcl_bc_trv_ar_lines

         SET transactionNo = v_transactionNo

       WHERE dff_invoice_num = ch.dff_invoice_num -- Se hace el join por este flexfield porque tiene el valor completo del transaction no.

         AND NVL(billtocustomerno,-1) = NVL(ch.billtocustomerno,-1)

         AND class = ch.class

         AND request_id = gv_request_id

         AND bc_environment = gv_bc_environment;



    END LOOP; 



    IF ( rec_cnt_v = 0 ) THEN 



      stop_message_v := 'No records exist for AR Processing';

	     RAISE stop_processing;



    END IF;



    print_ar_insert_report_p;



    p_status := 'S';



    print_log ( 'ajcl_bc_trv_pkg.ar_insert_p (-)' );    



  EXCEPTION

    WHEN stop_processing THEN

      p_status := 'W';

      p_error_msg := stop_message_v;

      print_log ( 'ajcl_bc_trv_pkg.ar_insert_p (!). Error: ' || stop_message_v );                      

      print_log( stop_message_v );



    -- 20240823

    WHEN e_create_ar_trx THEN

      p_status := 'E';

      print_log ( 'ajcl_bc_trv_pkg.ar_insert_p (!). Error create_ar_trx.' );

    -- 20240823



    WHEN OTHERS THEN

      p_status := 'E';

      p_error_msg := 'Error: ' || SQLCODE || ' ' || SQLERRM;

	     print_log ( 'ajcl_bc_trv_pkg.ar_insert_p (!). Error: ' || to_char(SQLCODE)||'-'||SQLERRM);      

      print_log ( 'Statement Line: ' || stmt_v );



  END ar_insert_p;



  PROCEDURE ar_call_ws ( p_status        OUT   VARCHAR2,

                         p_trx_count     OUT   NUMBER,

                         p_lines_count   OUT   NUMBER ) IS



      CURSOR c_headers_reprocess IS

      SELECT *

        FROM ajcl_bc_trv_ar_headers h

       WHERE bc_environment = gv_bc_environment

         AND ( ( request_id != gv_request_id AND status = 'ERROR' AND NOT EXISTS ( SELECT 1 

                                                                                     FROM ajcl_bc_trv_ar_lines l 

                                                                                    WHERE h.transactionno = l.transactionno 

                                                                                      AND h.class = l.class

                                                                                      AND NVL(h.billtocustomerno,-1) = NVL(l.billtocustomerno,-1)

                                                                                      AND h.request_id = l.request_id

                                                                                      AND l.bc_environment = h.bc_environment

                                                                                      AND UPPER(l.error_message) LIKE UPPER('%Line%already%exists%') ) ) OR

               -- 20250328

               -- ( request_id != gv_request_id AND status NOT IN ('SUCCESS','ERROR') ) ); 

               ( request_id != gv_request_id AND status = 'REJECTED' AND UPPER(error_message) NOT LIKE UPPER('%Unit%Price%Excl.%It cannot be zero or empty.') ) );

               -- 20250328



      CURSOR c_headers IS

      SELECT *

        FROM ajcl_bc_trv_ar_headers h

       WHERE bc_environment = gv_bc_environment

         AND request_id = gv_request_id 

         AND status = 'NEW';    



      CURSOR c_lines ( pc_transactionNo         IN   VARCHAR2,

                       pc_billToCustomerNo      IN   NUMBER,

                       pc_class                 IN   VARCHAR2 ) IS

      SELECT *

        FROM ajcl_bc_trv_ar_lines

       WHERE transactionNo = pc_transactionNo

         AND billToCustomerNo = pc_billToCustomerNo

         AND NVL(class,pc_class) = pc_class

         AND bc_environment = gv_bc_environment

         AND request_id = gv_request_id 

         AND status = 'NEW'

    ORDER BY lineNo;



    v_status               VARCHAR2(1);



    v_url_header           VARCHAR2(2000);

    v_body_header          CLOB;

    v_clob_result_header   CLOB;



    v_url_line             VARCHAR2(2000);

    v_body_line            CLOB;

    v_clob_result_line     CLOB;



    oracle_addr_id_v		     hz_cust_acct_sites.cust_acct_site_id%TYPE;

    oracle_cust_id_v	      hz_cust_accounts.cust_account_id%TYPE;

    oracle_cust_name_v	    hz_parties.party_name%TYPE;

    oracle_cust_number_v	  hz_cust_accounts.account_number%TYPE;

    oracle_addr1_v         VARCHAR2(100);

    oracle_addr2_v         VARCHAR2(50);

    oracle_addr3_v         VARCHAR2(50);

    term_name_v	           ra_terms.name%TYPE;

    due_days_v             NUMBER;

    payment_terms_v			     ra_interface_lines_all.term_name%TYPE;



    v_linea_con_error      VARCHAR2(1);

    v_error_message        VARCHAR2(2000);



  BEGIN



    print_log ( 'ajcl_bc_trv_pkg.ar_call_ws (+)' ); 



    print_log ('Headers are traversed to obtain the customer and the payment term in the reprocesses that failed because those data were not found (+)');



    FOR ch IN c_headers_reprocess LOOP



      -- Si el comprobante quedo sin customer en una ejecucion anterior, se trata de obtener nuevamente y se actualiza en las lineas y cabecera

      -- Tambien se obtiene el payment term

      -- 20250507 

      -- Se comenta para siempre recalcular el customer

      -- IF ( ch.billtocustomerid IS NULL ) THEN

      -- 20250507 



        oracle_addr_id_v := NULL;

        oracle_cust_id_v := NULL;

        oracle_cust_name_v := NULL;

        oracle_cust_number_v := NULL;

        oracle_addr_id_v := NULL;

        oracle_addr1_v := NULL;

        oracle_addr2_v := NULL;

        oracle_addr3_v := NULL;



        find_oracle_customer ( ch.dff_customer_carrier_acct_num, 

                               oracle_addr_id_v, 

                               --

                               oracle_cust_id_v, 

                               --

                               oracle_cust_name_v, 

                               oracle_cust_number_v,

                               --

                               oracle_addr_id_v,

                               --

                               oracle_addr1_v,

                               oracle_addr2_v,

                               oracle_addr3_v);



        print_log ( 'Customer ID: ' || oracle_cust_id_v);

        print_log ( 'Customer Name: ' || oracle_cust_name_v);

        print_log ( 'Customer Number: ' || oracle_cust_number_v);

        print_log ( 'Address ID: ' || oracle_addr_id_v);

        print_log ( 'Address1: ' || oracle_addr1_v);

        print_log ( 'Address2: ' || oracle_addr2_v);

        print_log ( 'Address3: ' || oracle_addr3_v);



        term_name_v := NULL;

        due_days_v := NULL;

        payment_terms_v := NULL;



        -- Find the payment terms from the customer header profile

        BEGIN



          SELECT t.name,

                 l.due_days

            INTO term_name_v,

                 due_days_v

            FROM ra_terms t, 

                 ra_terms_lines l,

                 hz_customer_profiles cp

           WHERE cp.status = 'A'

             AND cp.site_use_id IS NULL

             AND cp.cust_account_id = oracle_cust_id_v 

             AND cp.standard_terms = t.term_id

             AND t.term_id = l.term_id;



          IF ( ch.class = 'INV' ) THEN



            payment_terms_v := term_name_v;



          ELSE



            payment_terms_v := NULL;



          END IF;



        EXCEPTION

         WHEN NO_DATA_FOUND THEN

           print_log('Payment term not found for customer');

         WHEN OTHERS THEN 

           RAISE;



        END;



        UPDATE ajcl_bc_trv_ar_headers

           SET termName = payment_terms_v,

               -- 20241105

               -- termDueDate = TO_CHAR(TO_DATE(ch.glDate,'YYYY-MM-DD') + due_days_v,'YYYY-MM-DD'),

               termDueDate = TO_CHAR(TO_DATE(ch.transactionDate,'YYYY-MM-DD') + due_days_v,'YYYY-MM-DD'),

               -- 20241105

               billToCustomerId = oracle_cust_id_v,

               billToCustomerName = oracle_cust_name_v,

               billToCustomerNo = oracle_cust_number_v,

               billToAddress1 = oracle_addr1_v,

               billToAddress2 = oracle_addr2_v,

               billToAddress3 = oracle_addr3_v

         WHERE bc_environment = gv_bc_environment

           AND transactionno = ch.transactionno

           AND class = ch.class

           AND request_id = ch.request_id;



        UPDATE ajcl_bc_trv_ar_lines

           SET termName = payment_terms_v,

               -- 20241105

               -- termDueDate = TO_CHAR(TO_DATE(ch.glDate,'YYYY-MM-DD') + due_days_v,'YYYY-MM-DD'),

               termDueDate = TO_CHAR(TO_DATE(ch.transactionDate,'YYYY-MM-DD') + due_days_v,'YYYY-MM-DD'),

               -- 20241105

               billToCustomerId = oracle_cust_id_v,

               billToCustomerName = oracle_cust_name_v,

               billToCustomerNo = oracle_cust_number_v,

               billToAddress1 = oracle_addr1_v,

               billToAddress2 = oracle_addr2_v,

               billToAddress3 = oracle_addr3_v

         WHERE bc_environment = gv_bc_environment

           AND transactionno = ch.transactionno

           AND class = ch.class

           AND request_id = ch.request_id;



      -- 20250507 

      -- END IF;

      -- 20250507 



      UPDATE ajcl_bc_trv_ar_headers

         SET -- Se ponen estos valores para que lo levante el proceso

             request_id = gv_request_id,

             status = 'NEW',

             error_message = NULL,

             reprocess = 'Y'

       WHERE bc_environment = gv_bc_environment

         AND transactionno = ch.transactionno

         AND class = ch.class

         AND request_id = ch.request_id;



      UPDATE ajcl_bc_trv_ar_lines

         SET -- Se ponen estos valores para que lo levante el proceso

             request_id = gv_request_id,

             status = 'NEW',

             error_message = NULL

       WHERE bc_environment = gv_bc_environment

         AND transactionno = ch.transactionno

         AND class = ch.class

         AND request_id = ch.request_id;



    END LOOP;



    print_log ('Headers are traversed to obtain the customer and the payment term in the reprocesses that failed because those data were not found (-)');



    print_log ('Transactions with no customer number are updated to ERROR (+)');



    -- Se actualizan a ERROR las que no tienen customer number

    UPDATE ajcl_bc_trv_ar_headers

       SET status = 'ERROR',

           error_message = 'Oracle Customer not found for CUST_CARR_ACCT_NUM ' || dff_customer_carrier_acct_num || '.'

     WHERE billtocustomerno IS NULL

       AND request_id = gv_request_id

       AND bc_environment = gv_bc_environment;



    print_log ('Transactions with no customer number are updated to ERROR (-)');



    COMMIT;



    -- Se envian los comprobantes y sus lineas

    FOR ch IN c_headers LOOP



      print_log ('transactionNo: ' || ch.transactionNo);

      print_log ('billToCustomerno: ' || ch.billtocustomerno);



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

                          ch.billToCustomerNo,

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

        APEX_JSON.write('trvItemSequence',cl.dff_item_sequence,TRUE); 

        APEX_JSON.write('trvMGLoadId',cl.dff_mg_load_id,TRUE); 

        APEX_JSON.write('trvEDIItemCodeChargeType',cl.dff_edi_item_code_charge_type,TRUE); 

        APEX_JSON.write('trvDeliveryDate',cl.dff_delivery_date,TRUE);



        --

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



          v_error_message := 'An error occurred while sending the line: ' ||

                              SUBSTR(v_clob_result_line,INSTR(v_clob_result_line,'message') + 10);



          print_log(v_error_message);



          UPDATE ajcl_bc_trv_ar_lines

             SET status = 'ERROR',

                 error_message = v_error_message,

                 json_data = v_body_line,

                 json_data_response = v_clob_result_line

           WHERE transactionNo = ch.transactionNo

             AND billtocustomerno = ch.billtocustomerno

             AND lineNo = cl.lineNo

             AND request_id = cl.request_id

             AND bc_environment = gv_bc_environment;



          v_linea_con_error := 'Y';



        ELSE



          UPDATE ajcl_bc_trv_ar_lines

             SET status = 'SENT',

                 json_data = v_body_line,

                 json_data_response = v_clob_result_line

           WHERE transactionNo = ch.transactionNo

             AND billtocustomerno = ch.billtocustomerno

             AND lineNo = cl.lineNo

             AND request_id = cl.request_id

             AND bc_environment = gv_bc_environment;



          print_log ( 'The line was sent successfully.' );



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



        -- nuevo logistics

        APEX_JSON.write('source','TRV');

        APEX_JSON.write('trvShippingOrder',ch.dff_shipping_order,true);

        APEX_JSON.write('trvInvoiceNum',ch.dff_invoice_num,true);

        APEX_JSON.write('trvCustCarrierAcctNum',ch.dff_customer_carrier_acct_num,true);

        APEX_JSON.write('trvXMLFileName',ch.dff_xml_file_name,true);

        APEX_JSON.write('trvOracleXMLRunId',ch.dff_oracle_xml_run_id,true);

        APEX_JSON.write('trvXMLFileDate',ch.dff_xml_file_date,true);



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



          v_error_message := 'An error occurred while sending the header: ' ||

                              SUBSTR(v_clob_result_header,INSTR(v_clob_result_header,'message') + 10);



          print_log ( v_error_message );



          UPDATE ajcl_bc_trv_ar_headers

             SET status = 'ERROR',

                 error_message = v_error_message,

                 json_data = v_body_header,

                 json_data_response = v_clob_result_header

           WHERE transactionNo = ch.transactionNo

             AND billtocustomerno = ch.billtocustomerno

             AND class = ch.class

             AND request_id = ch.request_id

             AND bc_environment = gv_bc_environment;



        ELSE



          UPDATE ajcl_bc_trv_ar_headers

             SET status = 'SENT',

                 json_data = v_body_header,

                 json_data_response = v_clob_result_header

           WHERE transactionNo = ch.transactionNo

             AND request_id = ch.request_id

             AND bc_environment = gv_bc_environment;



          print_log ( 'Header was sent successfully.' );



        END IF;



        p_trx_count := NVL(p_trx_count,0) + 1;



      ELSE



        UPDATE ajcl_bc_trv_ar_headers

           SET status = 'ERROR',

               error_message = 'An error occurred on some line of the document'

         WHERE transactionNo = ch.transactionNo

           AND billtocustomerno = ch.billtocustomerno

           AND class = ch.class

           AND request_id = gv_request_id

           AND bc_environment = gv_bc_environment;



      END IF;



    END LOOP;



    p_status := 'S';

    print_log('ajcl_bc_trv_pkg.ar_call_ws (-)' ); 



  EXCEPTION

    WHEN OTHERS THEN

      print_log('ajcl_bc_trv_pkg.ar_call_ws (!) - ' || SQLERRM);

      p_status := 'E';       



  END ar_call_ws;



  PROCEDURE ar_call_job ( p_status   OUT   VARCHAR2 ) IS



    v_object_id       NUMBER;

    v_status          VARCHAR2(20);

    v_clob_response   CLOB;



  BEGIN



    print_log ( 'ajcl_bc_trv_pkg.ar_call_job (+)' ); 



    v_object_id := ajcl_bc_ws_utils_pkg.get_object_id_f ( 'SALES DOCUMENTS' ); 

    print_log ( 'v_object_id: ' || v_object_id || ' - ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));



    v_clob_response := ajcl_bc_ws_utils_pkg.run_job_queue_f ( p_bc_environment => gv_bc_environment,

                                                              p_company_id => gv_bc_company_id,

                                                              p_object_id => v_object_id );



    IF ( UPPER(v_clob_response) LIKE '%"ERROR":%' ) THEN



      print_log('An error occurred while executing the job SALES DOCUMENTS.');

      v_status := 'ERROR';

      p_status := 'E';



    ELSE



      print_log('SALES DOCUMENTS job was executed successfully.');

      v_status := 'SUCCESS';

      p_status := 'S';



    END IF;



    -- Se inserta registro de control

    INSERT

      INTO ajcl_bc_trv_ar_control

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



    print_log ( 'ajcl_bc_trv_pkg.ar_call_job (-)' );    



  EXCEPTION    

    WHEN OTHERS THEN

      p_status := 'E';

      print_log ( 'Not caught error when calling job. Error: ' || SQLERRM );

      print_log ('ajcl_bc_trv_pkg.ar_call_job (!)');



  END ar_call_job;        



  PROCEDURE ar_delete_inbound_records ( p_transactionNo     IN   VARCHAR2,

                                        p_billToCustomerNo  IN   VARCHAR2,

                                        p_class             IN   VARCHAR2 ) IS



    v_line_del_api      VARCHAR2(2000);

    v_line_del_url      VARCHAR2(2000);

    v_line_body         CLOB;

    v_line_del_clob     CLOB;



      CURSOR c_lines IS

      SELECT lineno

        FROM ajcl_bc_trv_ar_lines

       WHERE UPPER(transactionNo) = UPPER(p_transactionNo)

         AND billToCustomerNo = p_billToCustomerNo

         AND NVL(class,p_class) = p_class

         AND request_id = gv_request_id

         AND bc_environment = gv_bc_environment

    ORDER BY lineno;



    v_header_del_api    VARCHAR2(2000);

    v_header_del_url    VARCHAR2(2000);

    v_header_body       CLOB;

    v_header_del_clob   CLOB;



  BEGIN



    print_log ('ajcl_bc_trv_pkg.ar_delete_inbound_records (+)');



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



      print_log ('Line to delete: transactionNo: ' || p_transactionNo || ' | customerNo: ' || p_billToCustomerNo || ' | classType: ' || p_class || ' | lineNo: ' || cl.lineno);



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



      IF ( UPPER(v_line_del_clob) LIKE '%"ERROR":%' ) THEN



        print_log('Error deleting the line from the BC stage table.');

        print_log(v_line_del_clob);



      ELSE



        print_log('Line deleted from the BC stage table.');



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



    print_log ('Header to delete: transactionNo: ' || p_transactionNo || ' | customerNo: ' || p_billToCustomerNo || ' | classType: ' || p_class);



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



    print_log ('ajcl_bc_trv_pkg.ar_delete_inbound_records (-)');



  END ar_delete_inbound_records;



  PROCEDURE ar_call_status ( p_status   OUT   VARCHAR2 ) IS



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



    print_log ( 'ajcl_bc_trv_pkg.ar_call_status (+)' ); 



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



      SELECT COUNT(*)

        INTO v_cant_sin_procesar

        FROM json_table( v_clob_result,

                         '$.value[*]' COLUMNS ( status      VARCHAR2(4000) path '$.status',

                                                requestID   VARCHAR2(4000) path '$.requestID'))

       WHERE requestID = gv_request_id

         AND status NOT IN ('Error','Success');



      print_log ( 'Number of unprocessed records: ' || v_cant_sin_procesar );



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

    -- print_log ( 'v_clob_result: ' || v_clob_result );



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

        UPDATE ajcl_bc_trv_ar_headers

           SET status = 'REJECTED',

               error_message = cs.statusRemarks

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND UPPER(transactionNo) = UPPER(cs.transactionNo);



        -- Se actualiza el status de sus lineas   

        UPDATE ajcl_bc_trv_ar_lines

           SET status = 'REJECTED'

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND UPPER(transactionNo) = UPPER(cs.transactionNo);



        -- Se borra cabecera y lineas de las tablas inbound

        ar_delete_inbound_records ( p_transactionNo => cs.transactionno,

                                    p_billToCustomerNo => cs.billToCustomerNo,

                                    p_class => cs.class );



      ELSE



        -- Se actualiza la tabla custom con el status SUCCESS

        UPDATE ajcl_bc_trv_ar_headers

           SET status = 'SUCCESS'

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND UPPER(transactionNo) = UPPER(cs.transactionNo);



        -- Se actualizan sus lineas   

        UPDATE ajcl_bc_trv_ar_lines

           SET status = 'SUCCESS'

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND UPPER(transactionNo) = UPPER(cs.transactionNo);



      END IF;



    END LOOP;



    p_status := 'S';



    print_log ( 'ajcl_bc_trv_pkg.ar_call_status (-)' );    



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      print_log (v_error_message);

      print_log ('ajcl_bc_trv_pkg.call_status (!)');



    WHEN others THEN

      p_status := 'E';

      print_log ( 'Not caught error when checking status. Error: ' || SQLERRM );

      print_log ('ajcl_bc_trv_pkg.call_status (!)');



  END ar_call_status; 



  --

  PROCEDURE create_je_line ( transaction_gl_date_in	  IN   DATE,

                             je_category_in           IN   VARCHAR2,

                             p_journal_source         IN   VARCHAR2,

                             p_company	               IN   VARCHAR2,

                             p_account	               IN   VARCHAR2,

                             p_department             IN   VARCHAR2,

                             p_destination            IN   VARCHAR2,

                             p_office		               IN   VARCHAR2,

                             p_origin		               IN   VARCHAR2,

                             p_division               IN   VARCHAR2,

                             dr_amt_in 		             IN   NUMBER,

                             cr_amt_in 		             IN   NUMBER,

                             invoice_num_in 		        IN   VARCHAR2, 

                             po_num_in 		             IN   VARCHAR2,

                             trv_cust_carr_acct_num 	 IN   VARCHAR2,

                             oracle_vendor_num_in 	   IN   VARCHAR2,

                             oracle_vendor_name_in   	IN   VARCHAR2,

                             xml_file_name_in       	 IN   VARCHAR2,

                             oracle_xml_run_id_in	    IN   NUMBER,

                             xml_file_date_in	        IN   VARCHAR2,

                             trv_load_id_in		         IN   VARCHAR2,

                             trv_item_seq_in		        IN   VARCHAR2,

                             edi_item_code_in	        IN   VARCHAR2,

                             delivery_date_in	        IN   VARCHAR2,

                             je_line_desc_in		        IN   VARCHAR2,

                             trv_shipping_order_in	   IN   VARCHAR2,

                             trv_order_id_in          IN   VARCHAR2,

                             --

                             p_line_num           IN OUT   NUMBER,

                             p_status                OUT   VARCHAR2 ) IS 



    v_jelineid   NUMBER;



    -- 20240823

    v_xml_file_date                  DATE;

    -- 20240823



  BEGIN



    print_log ( 'ajcl_bc_trv_pkg.create_je_line (+)' );



    print_log('Create JE Line>  DR: ' || dr_amt_in || '|' || ' CR: ' || cr_amt_in);



    print_log ( 'p_company: ' || p_company );

    print_log ( 'p_account: ' || p_account );

    print_log ( 'p_department: ' || p_department );

    print_log ( 'p_destination: ' || p_destination );

    print_log ( 'p_office: ' || p_office );

    print_log ( 'p_origin: ' || p_origin );    

    print_log ( 'p_division: ' || p_division );



    -- 20240823

    -- Format xml_file_date_in

    BEGIN



      v_xml_file_date := TO_DATE(xml_file_date_in,'DD-MON-YY');



    EXCEPTION

      WHEN OTHERS THEN



        BEGIN



          IF ( SUBSTR(xml_file_date_in,6) LIKE '/00%' ) THEN



            v_xml_file_date := TO_DATE(SUBSTR(xml_file_date_in,1,6) || SUBSTR(xml_file_date_in,9),'DD/MM/YY');



          ELSE



            v_xml_file_date := TO_DATE(xml_file_date_in,'DD/MM/YYYY');



          END IF;



        EXCEPTION

          WHEN OTHERS THEN

            v_xml_file_date := NULL;



        END;



    END;

    -- 20240823



         -- entereddr       -- enteredcr

    IF ( NOT ( dr_amt_in = 0 AND cr_amt_in = 0 ) ) THEN 



      SELECT AJCL_BC_JE_LINE_ID_S.NEXTVAL

        INTO v_jelineid

        FROM DUAL; 



      INSERT 

        INTO ajcl_bc_trv_gl_lines

           ( bc_environment,

             journaltemplatename,

             journalbatchname,

             documentno,

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

             dff_invoice_num,

             dff_po_num,

             dff_customer_carrier_acct_num,

             dff_oracle_vendor_number,

             dff_oracle_vendor_name,

             dff_xml_file_name,

             dff_oracle_xml_run_id,

             dff_xml_file_date,

             dff_load_id,

             dff_item_sequence,

             dff_edi_item_code,

             dff_delivery_date,

             --

             dff_order_id,

             --

             jelineid,

             --

             status,

             creation_date,

             created_by,

             last_update_date,

             last_updated_by,

             request_id )

    VALUES ( gv_bc_environment,

             gv_journal_template_name, -- journaltemplatename

             gv_journal_batch_name, -- journalbatchname

             TO_CHAR(gv_request_id) || '.' || TO_CHAR(transaction_gl_date_in,'YYYYMMDD'), -- documentno

             TO_CHAR(transaction_gl_date_in,'YYYY-MM-DD'), -- postingdate

             gv_journal_source, -- userjesourcename

             je_category_in, -- userjecategoryname

             p_account, -- account

             p_company,

             p_department,

             p_destination,

             p_office,

             p_origin,

             p_division,

             'USD', -- currencycode

             NULL, -- currencyconversiondate

             NULL, -- currencyconversionrate

             NULL, -- currencyconversiontype

             dr_amt_in, -- entereddr

             cr_amt_in, -- enteredcr

             SUBSTR(je_line_desc_in,1,100), -- description

             'TRV' || trv_shipping_order_in, -- woksheetnumber

             p_line_num, -- oraclelineno

             invoice_num_in, -- dff_invoice_num

             po_num_in, -- dff_po_num

             trv_cust_carr_acct_num, -- dff_customer_carrier_acct_num

             oracle_vendor_num_in, -- dff_oracle_vendor_number

             oracle_vendor_name_in, -- dff_oracle_vendor_name

             xml_file_name_in, -- dff_xml_file_name

             oracle_xml_run_id_in, -- dff_oracle_xml_run_id

             -- 20240823 TO_CHAR(TO_DATE(xml_file_date_in,'DD-MON-YY'),'YYYY-MM-DD'), -- dff_xml_file_date

             TO_CHAR(v_xml_file_date,'YYYY-MM-DD'), -- dff_xml_file_date,

             --

             trv_load_id_in, -- dff_load_id

             trv_item_seq_in, -- dff_item_sequence

             edi_item_code_in, -- dff_edi_item_code

             TO_CHAR(TO_DATE(delivery_date_in,'DD-MON-YY'),'YYYY-MM-DD'), -- dff_delivery_date

             --

             trv_order_id_in,

             --

             v_jelineid,

             --

             'NEW', -- status

             SYSDATE, -- creation_date

             gv_user_id, -- created_by

             SYSDATE, -- last_update_date

             gv_user_id, -- last_updated_by

             gv_request_id );



    END IF;



    p_status := 'S';

    print_log ( 'ajcl_bc_trv_pkg.create_je_line (-)' );



  EXCEPTION

    WHEN OTHERS THEN 

      p_status := 'E';

      print_log ( 'ajcl_bc_trv_pkg.create_je_line (!). Error inserting line into ajcl_bc_trv_gl_lines.' );



  END create_je_line;



  PROCEDURE gl_generate_document_no_p IS



    -- Documents

      CURSOR c_documents IS

      SELECT documentno, 

             userjesourcename, 

             userjecategoryname

        FROM ajcl_bc_trv_gl_lines

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

    GROUP BY documentno, 

             userjesourcename, 

             userjecategoryname

    ORDER BY documentno, 

             userjesourcename, 

             userjecategoryname;



    v_documentno_ant   ajcl_bc_trv_gl_lines.documentno%TYPE;

    v_seq              NUMBER; 



  BEGIN



    print_log ( 'ajcl_bc_trv_pkg.gl_generate_document_no_p (+)' );



    FOR cd IN c_documents LOOP



      IF ( v_documentno_ant IS NULL ) THEN



        v_seq := 1;



      ELSE



        IF ( cd.documentno != v_documentno_ant ) THEN



          v_seq := 1;



        ELSE



          v_seq := v_seq + 1;



        END IF;



      END IF;



      v_documentno_ant := cd.documentno;



      UPDATE ajcl_bc_trv_gl_lines

         SET documentno = documentno || '.' || v_seq

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND documentno = cd.documentno

         AND userjesourcename = cd.userjesourcename

         AND userjecategoryname = cd.userjecategoryname;



    END LOOP;



    print_log ( 'ajcl_bc_trv_pkg.gl_generate_document_no_p (-)' );



  END gl_generate_document_no_p;



  PROCEDURE gl_generate_line_number_p IS



    -- Documents

      CURSOR c_documents IS

      SELECT documentno

        FROM ajcl_bc_trv_gl_lines

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

    GROUP BY documentno

    ORDER BY documentno;



      -- Lines

      CURSOR c_lines ( p_documentno   IN   VARCHAR2 ) IS

      SELECT *

        FROM ajcl_bc_trv_gl_lines

       WHERE documentno = p_documentno

         AND request_id = gv_request_id

         AND bc_environment = gv_bc_environment

    ORDER BY oraclelineno;



    v_line_no   NUMBER;



  BEGIN



    print_log ( 'ajcl_bc_trv_pkg.gl_generate_line_number_p (+)' );



    FOR cd IN c_documents LOOP



      v_line_no := 0;



      FOR cl IN c_lines ( p_documentno => cd.documentno ) LOOP



        v_line_no := v_line_no + 1;



        UPDATE ajcl_bc_trv_gl_lines

           SET oraclelineno = v_line_no

         WHERE request_id = cl.request_id

           AND bc_environment = gv_bc_environment

           AND documentno = cl.documentno

           AND account = cl.account

           AND oraclelineno = cl.oraclelineno;



      END LOOP;



    END LOOP;



    print_log ( 'ajcl_bc_trv_pkg.gl_generate_line_number_p (-)' );



  END gl_generate_line_number_p;



  PROCEDURE gl_insert_p ( p_status   IN OUT   VARCHAR2,

                          p_error_msg   OUT   VARCHAR2 ) IS



    v_line_num             NUMBER := 0;

    je_line_desc_v			      gl_interface.reference10%TYPE;

    je_category_v			       gl_interface.user_je_category_name%TYPE;

    oracle_vendor_num_v		  po_vendors.segment1%TYPE; 

    oracle_vendor_name_v		 po_vendors.vendor_name%TYPE; 

    rec_cnt_v 			          NUMBER := 0;

    --

    v_cogs_company			      gl_code_combinations.segment1%TYPE;

    v_cogs_account 			     gl_code_combinations.segment2%TYPE;

    v_cogs_department      gl_code_combinations.segment3%TYPE;

    v_cogs_destination     gl_code_combinations.segment4%TYPE;

    v_cogs_office			       gl_code_combinations.segment5%TYPE;

    v_cogs_origin			       gl_code_combinations.segment6%TYPE;	

    v_cogs_division	       gl_code_combinations.segment7%TYPE;

    --

    v_offs_company 			     gl_code_combinations.segment1%TYPE; 

    v_offs_account			      gl_code_combinations.segment2%TYPE; 

    v_offs_department	     gl_code_combinations.segment3%TYPE;

    v_offs_destination     gl_code_combinations.segment4%TYPE;

    v_offs_office			       gl_code_combinations.segment5%TYPE;

    v_offs_origin			       gl_code_combinations.segment6%TYPE;

    v_offs_division	       gl_code_combinations.segment7%TYPE;

    --

    user_id_v			           NUMBER;

    stmt_v 				            NUMBER := 0;

    prog_failed_v			       BOOLEAN; 



    stop_message_v			      VARCHAR2(200) := NULL;

    num_correctables_v		   NUMBER := 0;

    stop_processing			     EXCEPTION;



    -- 20240823

    v_status               VARCHAR2(1);

    e_create_je_line       EXCEPTION;

    -- 20240823



    CURSOR sel_trv IS

    SELECT xml_file_date,

           xml_file_type,

           xml_file_name,

           oracle_xml_run_id,

           trv_shipping_order,

           trv_load_id,

           trv_item_seq,

           trv_cust_carr_acct_num,

           po_num,

           invoice_num,

           edi_item_code,

           nvl(edi_item_code, charge_type) item,

           charge_amount,

           delivery_date,

           transaction_gl_date,

           charge_type,

           charge_desc,

           rowid trv_rowid,

           trv_order_id

      FROM ajc_trv_interface

     WHERE xml_file_type IN ('Carrier-Inv', 'Route-QACOGS')

       AND validation_status IN ('Valid', 'Generated')

       AND interface_status IS NULL

       AND oracle_xml_run_id = gv_run_id;



  BEGIN



    print_log ( 'ajcl_bc_trv_pkg.gl_insert_p (+)' );  



    -- If there are Correctables in this run then stop processing

    SELECT COUNT(1)

      INTO num_correctables_v

      FROM ajc_trv_interface

     WHERE validation_status = 'Correctable'

       AND oracle_xml_run_id = gv_run_id;



    IF ( num_correctables_v > 0 ) THEN



      stop_message_v := 'Correctable Errors Found. No Interface Processing Occurred.';

      RAISE stop_processing;



    END IF;



    FOR trv_rec IN sel_trv LOOP



      oracle_vendor_num_v := NULL;

      oracle_vendor_name_v	:= NULL;

      je_line_desc_v := NULL;

      --

      v_cogs_company := NULL;

      v_cogs_account := NULL;

      v_cogs_department := NULL;

      v_cogs_destination := NULL;

      v_cogs_office := NULL;

      v_cogs_origin := NULL;	

      v_cogs_division := NULL;

      --

      v_offs_company := NULL;

      v_offs_account := NULL;

      v_offs_department := NULL;

      v_offs_destination := NULL;

      v_offs_office := NULL;

      v_offs_origin := NULL;	

      v_offs_division := NULL;

      --

      je_category_v := NULL;



      print_log('SO#: ' || trv_rec.trv_shipping_order || '|' || 

                'XML File Type: ' || trv_rec.xml_file_type || '|' || 

                'Invoice: ' || trv_rec.invoice_num || '|' || 

                'Item Seq:' || trv_rec.trv_item_seq || '|' || 

                'Item: ' || trv_rec.item);



      rec_cnt_v := rec_cnt_v + 1;



      stmt_v := 20;



      -- 20240905 IF ( gv_check_integrations_source = 'Y' ) THEN



        BEGIN



          print_log ('trv_rec.trv_cust_carr_acct_num: ' || trv_rec.trv_cust_carr_acct_num );



          -- 20240905

          oracle_vendor_num_v := NULL;

          oracle_vendor_name_v := NULL;

          -- 20240905



          SELECT v.segment1, 

                 v.vendor_name

            INTO oracle_vendor_num_v, 

                 oracle_vendor_name_v  

            FROM ajcl_bc_cust_xref x,

                 po_vendors v

           WHERE bc_environment = gv_bc_environment

             AND x.bp_cust_id = trv_rec.trv_cust_carr_acct_num

             AND x.source_type = 'VENDOR'

             AND x.source = 'TRV'

             AND x.oracle_vendor_id = v.vendor_id;



        EXCEPTION

          WHEN OTHERS THEN

            print_log ('Vendor not found for bc_cust_id: ' || trv_rec.trv_cust_carr_acct_num);

            oracle_vendor_num_v := NULL;

            oracle_vendor_name_v := NULL;



        END;



      -- 20240905

      /*

      ELSE



        oracle_vendor_num_v := NULL;

        oracle_vendor_name_v := NULL;



      END IF;

      */

      -- 20240905



      je_line_desc_v := 'ShOrder:' || trv_rec.trv_shipping_order|| 

                        -- '|Load Id:' || trv_rec.trv_load_id||

                        '|OraVendor#:' || oracle_vendor_num_v||

                        '|Invoice:' || trv_rec.invoice_num||

                        '|ChargeType:' || trv_rec.charge_type || '-' || trv_rec.charge_desc;



      print_log('JE Line Descr = ' || je_line_desc_v);



      -- Retrieve accounting  for the charge type

      BEGIN



        stmt_v := 40;



        SELECT cgs_company,

               cgs_accountno,

               cgs_department,

               cgs_destination,

               cgs_office,

               cgs_origin,

               cgs_division,

               offset_company,

               offset_accountno,

               offset_department,

               offset_destination,

               offset_office,

               offset_origin,

               offset_division

          INTO v_cogs_company,

               v_cogs_account,

               v_cogs_department,

               v_cogs_destination,

               v_cogs_office,

               v_cogs_origin,

               v_cogs_division,

               --

               v_offs_company,

               v_offs_account,

               v_offs_department,

               v_offs_destination,

               v_offs_office,

               v_offs_origin,

               v_offs_division

          FROM ajcl_bc_ies_items

         WHERE bc_environment = gv_bc_environment

           AND NVL(inactive_date, SYSDATE + 1) > SYSDATE

           AND charge_type_code = trv_rec.item

           AND business_line = NVL(( SELECT business_line

                                       FROM ajcl_bc_ies_business_lines 

                                      WHERE bc_environment = gv_bc_environment

                                        AND enabled = 'Y'

                                        AND fs_office_code = SUBSTR(trv_rec.trv_shipping_order,LENGTH(trv_rec.trv_shipping_order),1) ),

                                   ( SELECT business_line

                                       FROM ajcl_bc_ies_business_lines 

                                      WHERE bc_environment = gv_bc_environment

                                        AND enabled = 'Y'

                                        AND trv_default = 'Y' ));



      EXCEPTION

        WHEN NO_DATA_FOUND THEN

          print_log('Could not retrieve accounting');



      END;      



      stmt_v := 45;



     	IF ( trv_rec.xml_file_type = 'Carrier-Inv' ) THEN



        je_category_v := gv_default_cogs_recog_je_cat;



      ELSE



        je_category_v := gv_default_cogs_accrual_je_cat;



	     END IF;



      -- Populate gl_interface */



      stmt_v := 50;



      v_line_num := v_line_num + 1;



      -- DR COGS Account

      create_je_line ( trv_rec.transaction_gl_date,

                       je_category_v,

                       gv_journal_source,

                       v_cogs_company, 

                       v_cogs_account,

                       v_cogs_department,

                       v_cogs_destination,

                       v_cogs_office,

                       v_cogs_origin,

                       v_cogs_division,

                       trv_rec.charge_amount, -- DR

                       0, -- CR

                       trv_rec.invoice_num, 

                       trv_rec.po_num,

                       trv_rec.trv_cust_carr_acct_num,

                       oracle_vendor_num_v,

                       oracle_vendor_name_v,

                       trv_rec.xml_file_name,

                       trv_rec.oracle_xml_run_id,

                       trv_rec.xml_file_date,

                       trv_rec.trv_load_id,

                       trv_rec.trv_item_seq,

                       trv_rec.edi_item_code,

                       trv_rec.delivery_date,

                       je_line_desc_v,

                       trv_rec.trv_shipping_order,

                       trv_rec.trv_order_id,

                       --

                       v_line_num,

                       p_status => v_status );



      -- 20240823

      IF ( v_status != 'S' ) THEN



        RAISE e_create_je_line;



      END IF;

      -- 20240823



      stmt_v := 60;



      v_line_num := v_line_num + 1;



		    -- CR the offset account

		    create_je_line ( trv_rec.transaction_gl_date,

                       je_category_v,

                       gv_journal_source,

                       v_offs_company, 

                       v_offs_account,

                       v_offs_department,

                       v_offs_destination,

                       v_offs_office,

                       v_offs_origin,

                       v_offs_division,

                       0, -- DR

                       trv_rec.charge_amount, -- CR

                       trv_rec.invoice_num, 

                       trv_rec.po_num,

                       trv_rec.trv_cust_carr_acct_num,

                       oracle_vendor_num_v,

                       oracle_vendor_name_v,

                       trv_rec.xml_file_name,

                       trv_rec.oracle_xml_run_id,

                       trv_rec.xml_file_date,

                       trv_rec.trv_load_id,

                       trv_rec.trv_item_seq,

                       trv_rec.edi_item_code,

                       trv_rec.delivery_date,

                       je_line_desc_v,

                       trv_rec.trv_shipping_order,

                       trv_rec.trv_order_id,

                       --

                       v_line_num,

                       p_status => v_status );



      -- Update gl_status to INTERFACED except rvrs records 



      -- 20240823

      IF ( v_status != 'S' ) THEN



        RAISE e_create_je_line;



      END IF;

      -- 20240823



     	stmt_v := 90;



	     UPDATE ajc_trv_interface

	        SET interface_status = 'Interfaced'

	      WHERE rowid = trv_rec.trv_rowid;



	     print_log('Interface Status updated to Interfaced');



    END LOOP; 



    IF ( rec_cnt_v = 0 ) THEN



      stop_message_v := 'No records exist for GL Processing';

      RAISE stop_processing;



    END IF;



    -- Se genera el documentno por documentno, source y category

    gl_generate_document_no_p;



    -- Se numeran las lineas por documentno

    gl_generate_line_number_p;



    p_status := 'S';    

    print_log('ajcl_bc_trv_pkg.gl_insert_p (-)');    



  EXCEPTION

    WHEN stop_processing THEN

      p_status := 'W';    

      p_error_msg := stop_message_v;

      print_log('ajcl_bc_trv_pkg.gl_insert_p (!). Error: ' || p_error_msg);    

      print_log(stop_message_v);



    -- 20240823

    WHEN e_create_je_line THEN

      p_status := 'E';    

      print_log('ajcl_bc_trv_pkg.gl_insert_p (!). Error create_je_line');    

    -- 20240823



    WHEN OTHERS THEN

      p_status := 'E';    

      p_error_msg := 'Error: ' || SQLCODE || ' ' || SQLERRM;

      print_log('ajcl_bc_trv_pkg.gl_insert_p (!)');    

      print_log('Line: '||stmt_v);

      print_log(TO_CHAR(SQLCODE) || '-' || SQLERRM);



  END gl_insert_p;



  PROCEDURE gl_insert_json_table ( p_status_code            IN OUT VARCHAR2,

                                   p_error_message          IN OUT VARCHAR2,

                                   p_record_count               IN NUMBER,

                                   p_json_number                IN NUMBER,

                                   p_json_data                  IN CLOB ) IS

  BEGIN



      INSERT 

        INTO ajcl_bc_trv_gl_jsons

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



  END gl_insert_json_table;  



  PROCEDURE gl_insert_request_table ( p_status_code            IN OUT VARCHAR2,

                                      p_error_message          IN OUT VARCHAR2,

                                      p_record_count           IN     NUMBER ) IS  

  BEGIN



      INSERT 

        INTO ajcl_bc_trv_gl_requests

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



  END gl_insert_request_table;



  PROCEDURE gl_generate_jsons ( p_journals_count   OUT   NUMBER,

                                p_error_message    OUT   VARCHAR2,

                                p_status           OUT   VARCHAR2 ) IS



      CURSOR c_journals IS

      SELECT *

        FROM ajcl_bc_trv_gl_lines

       WHERE bc_environment = gv_bc_environment

         AND ( ( request_id = gv_request_id AND UPPER(status) IN ('NEW') ) 

               -- 20240917

            OR ( request_id != gv_request_id AND UPPER(status) IN ('REJECTED','ERROR') ) 

               -- 20240917

             )

    ORDER BY oraclelineno;



    v_bc_company_id           VARCHAR2(200);



    v_base_inecta_batch_url   VARCHAR2(300);

    v_credential_static_id    VARCHAR2(300);

    v_token_url               VARCHAR2(300);

    v_url                     VARCHAR2(2000);

    v_api                     VARCHAR2(300);

    v_clob_response           CLOB;

    v_json_number             NUMBER := 1;

    v_split_quantity          NUMBER := 0;

    v_ticketing_number        NUMBER := 50;

    v_count                   NUMBER := 0;

    r_id                      VARCHAR2(20);

    v_error_message           VARCHAR2(2000);

    v_status                  VARCHAR2(1);



    e_cust_exception          EXCEPTION;



  BEGIN



    print_log('ajcl_bc_trv_pkg.gl_generate_jsons (+)');



    v_api := ajcl_bc_ws_utils_pkg.get_api_f ( p_entity => 'INBOUND JOURNALS',

                                              p_subentity => 'LINES',

                                              p_method => 'POST' );

    print_log ( 'v_api: ' || v_api );



    APEX_JSON.initialize_clob_output;

    APEX_JSON.open_object;

    APEX_JSON.open_array('requests');



    FOR cj IN c_journals LOOP



      BEGIN



        -- print_log ( 'oraclelineno: ' || cj.oraclelineno );



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

        APEX_JSON.write('source','TRV');

        APEX_JSON.write('jelineid',cj.jelineid,true);

        APEX_JSON.write('journaltemplatename',cj.journaltemplatename);

        APEX_JSON.write('journalbatchname',cj.journalbatchname);

        APEX_JSON.write('documentno',cj.documentNo);

        APEX_JSON.write('postingdate',cj.postingdate);

        APEX_JSON.write('userjesourcename',cj.userjesourcename);

        APEX_JSON.write('userjecategoryname',cj.userjecategoryname);

        APEX_JSON.write('account',cj.account,true);

        APEX_JSON.write('company', cj.company,true); 

        APEX_JSON.write('department', cj.department,true);

        APEX_JSON.write('destination', cj.destination,true); 

        APEX_JSON.write('office', cj.office,true);

        APEX_JSON.write('origin', cj.origin,true); 

        APEX_JSON.write('division', cj.division,true);

        APEX_JSON.write('currencycode',cj.currencycode);

        APEX_JSON.write('currencyconversiondate',cj.currencyconversiondate,true);

        APEX_JSON.write('currencyconversionrate',cj.currencyconversionrate,true);

        APEX_JSON.write('currencyconversiontype',cj.currencyconversiontype,true);

        APEX_JSON.write('entereddr',cj.entereddr);

        APEX_JSON.write('enteredcr',cj.enteredcr);

        APEX_JSON.write('description',cj.description,true);

        APEX_JSON.write('worksheetno',cj.worksheetnumber);

        APEX_JSON.write('oraclelineno',cj.oraclelineno,true);

        APEX_JSON.write('requestid',gv_request_id,true);

        -- DFF

        APEX_JSON.write('trvinvoicenum',cj.dff_invoice_num,true);

        APEX_JSON.write('trvponum',cj.dff_po_num,true);

        APEX_JSON.write('trvcustcarrieracctnum',cj.dff_customer_carrier_acct_num,true);

        APEX_JSON.write('trvoraclevendornumber',cj.dff_oracle_vendor_number,true);

        APEX_JSON.write('trvoraclevendorname',cj.dff_oracle_vendor_name,true);

        APEX_JSON.write('trvxmlfilename',cj.dff_xml_file_name,true);

        APEX_JSON.write('trvoraclexmlrunid',cj.dff_oracle_xml_run_id,true);

        APEX_JSON.write('trvxmlfiledate',cj.dff_xml_file_date,true);

        APEX_JSON.write('trvloadid',cj.dff_load_id,true);

        APEX_JSON.write('trvitemsequence',cj.dff_item_sequence,true);

        APEX_JSON.write('trvediitemcode',cj.dff_edi_item_code,true);

        APEX_JSON.write('trvdeliverydate',cj.dff_delivery_date,true);

        APEX_JSON.write('trvorderid',cj.dff_order_id,true);

        -- DFF

        APEX_JSON.close_object; -- } body



        APEX_JSON.close_object; -- }



        -- Se actualiza en la tabla de lineas

        UPDATE ajcl_bc_trv_gl_lines

           SET json_number = v_json_number,

               -- 20240917

               request_id = gv_request_id, -- Se pone el request_id actual a lo nuevo y a lo reprocesado

               -- 20240917

               error_message = NULL

         WHERE documentno = cj.documentno

           AND oraclelineno = cj.oraclelineno

           AND request_id = cj.request_id

           AND bc_environment = gv_bc_environment;



        IF ( v_split_quantity = v_ticketing_number ) THEN



          APEX_JSON.close_array; -- ] requests

          APEX_JSON.close_object;



          gl_insert_json_table ( p_status_code => v_status,

                                 p_error_message => v_error_message,

                                 p_record_count => v_split_quantity,

                                 p_json_number => v_json_number,

                                 p_json_data => APEX_JSON.get_clob_output);



          v_split_quantity := 0;

          v_json_number := v_json_number + 1;



          APEX_JSON.free_output;



          -- Vuelvo a inciar Clob

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



      gl_insert_json_table ( p_status_code          => v_status,

                             p_error_message        => v_error_message,

                             p_record_count         => v_split_quantity,

                             p_json_number          => v_json_number,

                             p_json_data            => APEX_JSON.get_clob_output );



      APEX_JSON.free_output;



    END IF;



    gl_insert_request_table ( p_status_code => v_status,

                              p_error_message => v_error_message,

                              p_record_count => v_count );



    print_log('ajcl_bc_trv_pkg.gl_generate_jsons (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('ajcl_bc_trv_pkg.gl_generate_jsons (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));

    WHEN others THEN

        v_error_message := 'Not caught error when creating JSON. Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('ajcl_bc_trv_pkg.gl_generate_jsons (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));



  END gl_generate_jsons;



  PROCEDURE gl_call_ws ( p_error_message    IN OUT   VARCHAR2,

                         p_status           IN OUT   VARCHAR2 ) IS



      CURSOR c_jsons IS

      SELECT REPLACE(json_data,'\/','/') json_data,

             json_number

        FROM ajcl_bc_trv_gl_jsons

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

    ORDER BY json_number;



    v_url                     VARCHAR2(200);



    v_status                  VARCHAR2(1);

    v_error_message           VARCHAR2(2000);

    e_cust_exception          EXCEPTION;

    v_clob_response           CLOB;







  BEGIN



    print_log('ajcl_bc_trv_pkg.gl_call_ws (+)');



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



          UPDATE ajcl_bc_trv_gl_jsons

             SET json_data_response = v_clob_response,

                 last_update_date = sysdate

           WHERE request_id = gv_request_id

             AND bc_environment = gv_bc_environment

             AND json_number = cj.json_number;



          COMMIT;



        EXCEPTION

          WHEN OTHERS THEN

            v_error_message := 'Error al Actualizar tabla ajcl_bc_trv_gl_jsons con respuesta generada al llamar al Web Service. Error: ' || SQLERRM;

            RAISE e_cust_exception;



        END; 



        IF ( UPPER(v_clob_response) LIKE '%"ERROR":%' ) THEN



          v_error_message := SUBSTR(v_clob_response,INSTR(v_clob_response,'"message":') + 11,

                             INSTR(v_clob_response,'CorrelationId:') - INSTR(v_clob_response,'"message":') - 11

                             );



          RAISE e_cust_exception;



        ELSE



          p_status := 'S';



        END IF;



      EXCEPTION

        WHEN e_cust_exception THEN

          v_error_message := 'Error processing JSON nro: ' || cj.json_number || '. Error:' || v_error_message;

          RAISE e_cust_exception;



        WHEN others THEN

          v_error_message := 'General error when processing JSON nro: ' || cj.json_number || '. Error:' || SQLERRM;

          RAISE e_cust_exception;



      END;



    END LOOP;



    print_log('ajcl_bc_trv_pkg.gl_call_ws (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_trv_pkg.gl_call_ws (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));



    WHEN others THEN

      v_error_message := 'Not caught error calling General Journal Inbounds. Error: '||sqlerrm;

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_trv_pkg.gl_call_ws (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));



  END gl_call_ws;



  PROCEDURE gl_call_job ( p_error_message   IN OUT   VARCHAR2,

                          p_status          IN OUT   VARCHAR2 ) IS



    v_object_id         NUMBER;

    v_status            VARCHAR2(1);

    v_error_message     VARCHAR2(2000);

    e_cust_exception    EXCEPTION;

    v_clob_response     CLOB;



  BEGIN



    print_log('ajcl_bc_trv_pkg.gl_call_job (+)');



    v_object_id := ajcl_bc_ws_utils_pkg.get_object_id_f ( 'JOURNALS' );

    print_log ( 'v_object_id: ' || v_object_id || ' - ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));



    v_clob_response := ajcl_bc_ws_utils_pkg.run_job_queue_f ( p_bc_environment => gv_bc_environment,

                                                              p_company_id => gv_bc_company_id,

                                                              p_object_id => v_object_id );



    IF ( UPPER(v_clob_response) LIKE '%"ERROR":%' ) THEN



      print_log('An error occurred while running the JOURNALS job.');

      p_status := 'E';



    ELSE



      print_log('The JOURNALS job was executed successfully.');

      p_status := 'S';       



    END IF;



    BEGIN



      UPDATE ajcl_bc_trv_gl_requests

         SET json_job_response = v_clob_response,

             last_update_date = SYSDATE

       WHERE request_id = gv_request_id;



      COMMIT;



    EXCEPTION

      WHEN OTHERS THEN

        v_error_message := 'Error al Actualizar tabla ajcl_bc_trv_gl_requests con respuesta generada al llamar al Web Service. Error: ' || SQLERRM;

        RAISE e_cust_exception;



    END; 



    IF REPLACE(SUBSTR(v_clob_response,INSTR(v_clob_response,'"value"')+8,LENGTH(v_clob_response)),'}') IN ('"Success"','""','"Job Queue Scheduled successfully."') THEN



      p_status:='S';



    ELSE



      v_error_message := 'Error calling Job: ' || REPLACE(substr(v_clob_response,INSTR(v_clob_response,'"value"')+8,LENGTH(v_clob_response)),'}');

      print_log(v_clob_response);

      RAISE e_cust_exception;



    END IF;



    print_log('ajcl_bc_trv_pkg.gl_call_job (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_trv_pkg.gl_call_job (!). '|| TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));

    WHEN OTHERS THEN

      v_error_message := 'Uncaught error when calling job. Error: ' || SQLERRM;

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_trv_pkg.gl_call_job (!). '|| TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));



  END gl_call_job;



  PROCEDURE gl_call_ws_staging_pending ( p_pending_rows     OUT VARCHAR2,

                                         p_error_message IN OUT VARCHAR2,

                                         p_status        IN OUT VARCHAR2 ) IS



    v_url               VARCHAR2(2000);



    v_status            VARCHAR2(1);

    v_error_message     VARCHAR2(2000);

    e_cust_exception    EXCEPTION;

    v_clob_response     CLOB;

    v_count             NUMBER := 0;



  BEGIN



    print_log('ajcl_bc_trv_pkg.gl_call_ws_staging_pending (+)');



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                          p_entity => 'INBOUND JOURNALS',

                                                          p_subentity => 'LINES',

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id )

             || '?$filter=requestid eq ' || gv_request_id

             ||' and status eq ''Pending''';



    LOOP



      -- DBMS_LOCK.sleep(seconds => 10 * v_count);

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



    print_log ( 'ajcl_bc_trv_pkg.gl_call_ws_staging_pending (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_trv_pkg.gl_call_ws_staging_pending (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));

    WHEN others THEN

      v_error_message := 'Not caught error when calling staging table. Error: ' || SQLERRM;

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_trv_pkg.gl_call_ws_staging_pending (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));



  END gl_call_ws_staging_pending;



  PROCEDURE gl_call_ws_staging ( p_error_message   IN OUT   VARCHAR2,

                                 p_status          IN OUT   VARCHAR2 ) IS



    v_url               VARCHAR2(2000);



    v_status            VARCHAR2(1);

    v_error_message     VARCHAR2(2000);

    e_cust_exception    EXCEPTION;

    v_clob_response     CLOB;



  BEGIN



    print_log ( 'ajcl_bc_trv_pkg.gl_call_ws_staging (+)');



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                          p_entity => 'INBOUND JOURNALS',

                                                          p_subentity => 'LINES',

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id )

             || '?$filter=requestid eq ' || gv_request_id;



    print_log('v_url: '|| v_url);



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



      UPDATE ajcl_bc_trv_gl_requests

         SET json_staging_response = v_clob_response,

             last_update_date = sysdate

       WHERE request_id = gv_request_id;



      COMMIT;



    EXCEPTION

      WHEN OTHERS THEN

        v_error_message := 'Error updating table ajcl_bc_trv_gl_requests with response generated when calling the Web Service ' || '. Error: ' || SQLERRM;

        RAISE e_cust_exception;



    END; 



    print_log ( 'ajcl_bc_trv_pkg.gl_call_ws_staging (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_trv_pkg.gl_call_ws_staging (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));

    WHEN others THEN

      v_error_message := 'Not caught error when calling staging web service. Error: ' || SQLERRM;

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_trv_pkg.gl_call_ws_staging (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));



  END gl_call_ws_staging; 



  PROCEDURE gl_validate_ws_data ( p_error_message   IN OUT   VARCHAR2,

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



    v_status            VARCHAR2(1);

    v_error_message     VARCHAR2(2000);

    v_clob_result       CLOB;

    e_cust_exception    EXCEPTION;



  BEGIN



    print_log ( 'ajcl_bc_trv_pkg.gl_validate_ws_data (+)');



    BEGIN



      SELECT json_staging_response

        INTO v_clob_result

        FROM ajcl_bc_trv_gl_requests

       WHERE request_id = gv_request_id;



    EXCEPTION

      WHEN OTHERS THEN

        v_error_message := 'Error al obtener json almacenado en tabla ajcl_bc_trv_gl_requests del Web Service. Error: ' || SQLERRM;

        RAISE e_cust_exception;



    END;



    FOR cl IN c_lines ( v_clob_result ) LOOP



      BEGIN



        UPDATE ajcl_bc_trv_gl_lines abagl

           SET status = cl.status,

               error_message = cl.statusRemarks,

               last_update_date = SYSDATE

         WHERE abagl.documentNo = cl.documentNo

           AND abagl.oracleLineNo = cl.oracleLineNo

           AND request_id = gv_request_id

           AND bc_environment = gv_bc_environment;



      EXCEPTION

        WHEN OTHERS THEN

          v_error_message := 'Error updating table ajcl_bc_trv_gl_lines with response generated when calling the Web Service. Error: ' || SQLERRM;

          RAISE e_cust_exception;



      END;



    END LOOP;



    p_status := 'S';



    print_log ( 'ajcl_bc_trv_pkg.gl_validate_ws_data (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_trv_pkg.gl_validate_ws_data (!)');

    WHEN others THEN

      v_error_message := 'Error not caught when updating transaction lines sent by the process. Error: ' || SQLERRM;

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_trv_pkg.gl_validate_ws_data (!)');



  END gl_validate_ws_data;   



  PROCEDURE gl_check_lines_status ( p_error_message   IN OUT   VARCHAR2,

                                    p_status          IN OUT   VARCHAR2 ) IS



    v_error_lines   NUMBER;

    e_error_lines   EXCEPTION;



  BEGIN



    print_log ( 'ajcl_bc_trv_pkg.gl_check_lines_status (+)');



      SELECT COUNT(1) 

        INTO v_error_lines

        FROM ajcl_bc_trv_gl_lines

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND status IN ('ERROR','REJECTED');



    -- Si hay lineas con ERROR o REJECTED, se borran de la inbound

    IF ( v_error_lines != 0 ) THEN



      RAISE e_error_lines;



    END IF;



    p_status := 'S';



    print_log ( 'ajcl_bc_trv_pkg.gl_check_lines_status (-)');



  EXCEPTION

    WHEN e_error_lines THEN

      p_status := 'E';

      p_error_message := 'Journal with error.';

      print_log ( 'ajcl_bc_trv_pkg.gl_check_lines_status (!). Error: ' || p_error_message);



    WHEN OTHERS THEN

      p_status := 'E';

      p_error_message := SQLERRM;

      print_log ( 'ajcl_bc_trv_pkg.gl_check_lines_status (!). Error: ' || SQLERRM);



  END gl_check_lines_status; 



  PROCEDURE gl_call_ws_delete ( -- 20240917

                                p_documentno      IN       VARCHAR2,

                                -- 20240917

                                p_error_message   IN OUT   VARCHAR2,

                                p_status          IN OUT   VARCHAR2 ) IS



    v_api               VARCHAR2(500);

    v_url               VARCHAR2(500);

    v_body              CLOB;  

    v_clob_response     CLOB;



    -- 20240917 v_error_message     VARCHAR2(2000);



  BEGIN



    print_log ( 'ajcl_bc_trv_pkg.gl_call_ws_delete (+)');



    -- 20240917

    /*

    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                          p_entity => 'INBOUND JOURNALS',

                                                          p_subentity => 'LINES',

                                                          p_method => 'DEL',

                                                          p_company_id => gv_bc_company_id )

             || '(' || gv_request_id || ')'; 



    print_log( 'v_url: ' || v_url );



    v_clob_response := ajcl_bc_ws_utils_pkg.delete_bc_row_f ( v_url );



    IF ( UPPER(v_clob_response) LIKE '%"ERROR":%' ) THEN



      v_error_message := SUBSTR(v_clob_response,INSTR(v_clob_response,'message')+9,LENGTH(v_clob_response));

      RAISE e_cust_exception;



    ELSE



      p_status := 'S';



    END IF;

    */ 

    -- 20240917



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



    print_log ( 'ajcl_bc_trv_pkg.gl_call_ws_delete (-)');



    EXCEPTION

      WHEN OTHERS THEN

        p_status := 'E';

        p_error_message := 'Not caught error when Delete General Journal Inbounds, Error: ' || SQLERRM;

        print_log (p_error_message);

        print_log ('ajcl_bc_trv_pkg.gl_call_ws_delete (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));



  END gl_call_ws_delete;



  -- 20240917

  PROCEDURE gl_check_lines_status_p ( p_error_message   IN OUT   VARCHAR2,

                                      p_status          IN OUT   VARCHAR2 ) IS



    v_error_lines   NUMBER;

    e_error_lines   EXCEPTION;



      CURSOR c_documentno_error IS

      SELECT documentno

        FROM ajcl_bc_trv_gl_lines

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND status IN ('ERROR','REJECTED')

    GROUP BY documentno;



  BEGIN



    print_log ( 'ajcl_bc_trv_gl_pkg.gl_check_lines_status_p (+)');



    -- Se recorren los documentos ERROR/REJECTED y se borran de la inbound

    FOR cdnoe IN c_documentno_error LOOP



      gl_call_ws_delete ( p_documentno => cdnoe.documentno,

                          p_error_message => p_error_message,

                          p_status => p_status );



      IF ( p_status = 'E' ) THEN



        RAISE e_error_lines;



      END IF;



    END LOOP;

    -- 20240917



    p_status := 'S';



    print_log ( 'ajcl_bc_trv_gl_pkg.gl_check_lines_status_p (-)');



  EXCEPTION

    WHEN e_error_lines THEN

      p_status := 'E';

      p_error_message := 'Cant delete journal line.';

      print_log ( 'ajcl_bc_trv_gl_pkg.gl_check_lines_status_p (!). Error: ' || p_error_message);



    WHEN OTHERS THEN

      p_status := 'E';

      p_error_message := SQLERRM;

      print_log ( 'ajcl_bc_trv_gl_pkg.gl_check_lines_status_p (!). Error: ' || SQLERRM);



  END gl_check_lines_status_p; 

  -- 20240917



  -- Inserta los worksheets a enviar a BC en la tabla AJCL_BC_WORKSHEETS

  -- y ejecuta el concurrente que los envia: AJCL BC Worksheets Interface

  PROCEDURE worksheets_to_bc_p ( p_status   IN OUT   VARCHAR2 ) IS



      CURSOR c_worksheets IS

      -- AR

      SELECT line_worksheet ws_ies_num

        FROM ajcl_bc_trv_ar_lines

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND line_worksheet IS NOT NULL

    GROUP BY line_worksheet

       UNION 

      -- GL

      SELECT worksheetnumber ws_ies_num

        FROM ajcl_bc_trv_gl_lines

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND worksheetnumber IS NOT NULL

    GROUP BY worksheetnumber;



    v_total_worksheets   NUMBER;

    e_error              EXCEPTION;



  BEGIN



    print_log( 'ajcl_bc_trv_pkg.worksheets_to_bc_p (+)' );



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

    print_log( 'ajcl_bc_trv_pkg.worksheets_to_bc_p (-)' );



  EXCEPTION

    WHEN e_error THEN

      print_log( 'ajcl_bc_trv_pkg.worksheets_to_bc_p (!)' );

      p_status := 'E';

    WHEN OTHERS THEN

      print_log( 'ajcl_bc_trv_pkg.worksheets_to_bc_p (!)' );

      p_status := 'E';



  END worksheets_to_bc_p;



  PROCEDURE gl_final_report_csv_p ( p_status   OUT   VARCHAR2 ) IS



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

        FROM ajcl_bc_trv_gl_lines abagl

       WHERE abagl.request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND UPPER(abagl.status) NOT IN ('ERROR','REJECTED')

    GROUP BY abagl.documentno,

             abagl.postingdate,

             abagl.userjesourcename,

             abagl.userjecategoryname,

             abagl.currencycode,

             abagl.status;



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

        FROM ajcl_bc_trv_gl_lines abagl

       WHERE abagl.request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND UPPER(abagl.status) = 'ERROR'

         AND abagl.error_message IS NOT NULL

    ORDER BY abagl.documentno,

             abagl.postingdate,

             abagl.json_number,

             abagl.oraclelineno;



  BEGIN



    print_log( 'ajcl_bc_trv_pkg.gl_final_report_csv_p (+)' );



    -- Insert Report Title

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_gl_ifc,

                                        p_text => gv_bc_gl_ifc || ' Report',

                                        p_request_id => gv_request_id );

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_gl_ifc,

                                        p_text => 'Request ID|' || gv_request_id,

                                        p_request_id => gv_request_id );     



    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_gl_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Tabla 1 -----------------------------------------------------------------------------------------------------------------                                    

    -- Insert Table Title

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_gl_ifc,

                                        p_text => 'Processed Journals',

                                        p_request_id => gv_request_id );



    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_gl_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Insert Table Column Names                            

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_gl_ifc,

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



      ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_gl_ifc,

                                          p_text => cpj.documentno || '|' || 

                                                    cpj.postingdate || '|' || 

                                                    cpj.userjesourcename || '|' || 

                                                    cpj.userjecategoryname || '|' || 

                                                    cpj.currency_code || '|' || 

                                                    cpj.status || '|' || 

                                                    cpj.entereddr || '|' || 

                                                    cpj.enteredcr || '|' || 

                                                    cpj.qty,

                                          p_request_id => gv_request_id );                                                          



    END LOOP;



    -- Tabla 2 -----------------------------------------------------------------------------------------------------------------

    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_gl_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Insert Table Title

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_gl_ifc,

                                        p_text => 'Errors',

                                        p_request_id => gv_request_id );



    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_gl_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Insert Table Column Names                            

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_gl_ifc,

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



      ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_gl_ifc,

                                          p_text => ce.postingdate || '|' || 

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



    print_log( 'ajcl_bc_trv_pkg.gl_final_report_csv_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_trv_pkg.gl_final_report_csv_p (!). Error: ' || SQLERRM );



  END gl_final_report_csv_p;



  PROCEDURE gl_final_report_xlsx_p ( p_status   OUT   VARCHAR2 ) IS



    c_cursor   SYS_REFCURSOR;



  BEGIN



    print_log( 'ajcl_bc_trv_pkg.gl_final_report_xlsx_p (+)' );



    gv_directory_report := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_REPORT' );



    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc || ' Report',

                                                p_request_id => gv_request_id,

                                                p_bc_environment => gv_bc_environment,

                                                p_jenkins_build_number => gv_jenkins_build_number,

                                                --

                                                p_param_1_title => ' ',

                                                p_param_1_value => ' ',



                                                p_param_2_title => 'RUN ID', 

                                                p_param_2_value => gv_run_id

                                                -- 20240905 ,p_param_3_title => 'CHECK_INTEGRATIONS_SOURCE'

                                                -- 20240905 ,p_param_3_value => gv_check_integrations_source

                                                );



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

        FROM ajcl_bc_trv_gl_lines abagl

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



    -- Error Journals

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

        FROM ajcl_bc_trv_gl_lines abagl

       WHERE abagl.request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND UPPER(abagl.status) = 'ERROR'

         AND abagl.error_message IS NOT NULL

    ORDER BY abagl.documentno,

             abagl.postingdate,

             abagl.json_number,

             abagl.oraclelineno;



    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Error Journals',

                                       p_sheet => 3,

                                       p_cursor => c_cursor );



    as_xlsx.save ( gv_directory_report, gv_gl_report_filename || '.' || LOWER(gv_file_format) );



    p_status := 'S';



    print_log( 'ajcl_bc_trv_pkg.gl_final_report_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_trv_pkg.gl_final_report_xlsx_p (!). Error: ' || SQLERRM );



  END gl_final_report_xlsx_p;



  PROCEDURE ar_final_report_csv_p ( p_status   OUT   VARCHAR2 ) IS



      CURSOR c_invoices IS

      SELECT h.billToCustomerName,

             h.billToCustomerNo,

             h.transactionNo,

             h.dff_invoice_num trv_invoice_num,

             h.transactionDate,

             h.class,

             h.invoiceCurrencyCode,

             TRIM(TO_CHAR(h.amount,'999,999,999.00')) amount,

             l.lineNo,

             l.description,

             l.quantity quantity,

             l.unitSellingPrice unitSellingPrice,

             l.extendedAmount extendedAmount,

             h.status h_status,

             h.error_message h_error_message,

             l.status l_status,

             l.error_message l_error_message

        FROM ajcl_bc_trv_ar_headers h,

             ajcl_bc_trv_ar_lines l

       WHERE h.request_id = gv_request_id

         AND h.bc_environment = gv_bc_environment

         AND h.request_id = l.request_id

         AND l.bc_environment = gv_bc_environment

         AND NVL(h.billToCustomerNo,999) = NVL(l.billToCustomerNo,999)

         AND h.transactionNo = l.transactionNo

         AND h.class = NVL(l.class,h.class)

    ORDER BY h.billToCustomerName,

             h.transactionNo, 

             l.lineNo;



  BEGIN



    print_log( 'ajcl_bc_trv_pkg.ar_final_report_csv_p (+)' );



    -- Insert Report Title

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ar_ifc,

                                        p_text => gv_bc_ar_ifc || ' Report',

                                        p_request_id => gv_request_id );

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ar_ifc,

                                        p_text => 'Request ID|' || gv_request_id,

                                        p_request_id => gv_request_id ); 



    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ar_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Tabla 1 -----------------------------------------------------------------------------------------------------------------                                    

    -- Insert Table Column Names                            

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ar_ifc,

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



      ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ar_ifc,

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



    print_log( 'ajcl_bc_trv_pkg.ar_final_report_csv_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_trv_pkg.ar_final_report_csv_p (!). Error: ' || SQLERRM );



  END ar_final_report_csv_p;



  PROCEDURE ar_final_report_xlsx_p ( p_status   OUT   VARCHAR2 ) IS



    c_cursor            SYS_REFCURSOR;



  BEGIN



    print_log( 'ajcl_bc_trv_ar_pkg.ar_final_report_xlsx_p (+)' );



    gv_directory_report := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_REPORT' );



    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc || ' Report',

                                                p_request_id => gv_request_id,

                                                p_bc_environment => gv_bc_environment,

                                                p_jenkins_build_number => gv_jenkins_build_number,

                                                --

                                                p_param_1_title => ' ',

                                                p_param_1_value => ' ',

                                                p_param_2_title => 'RUN ID', 

                                                p_param_2_value => gv_run_id

                                                -- 20240905 ,p_param_3_title => 'CHECK_INTEGRATIONS_SOURCE' 

                                                -- 20240905 ,p_param_3_value => gv_check_integrations_source

                                                );



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

               FROM ajcl_bc_trv_ar_headers 

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

                        FROM ajcl_bc_trv_ar_headers 

                       WHERE request_id = gv_request_id 

                         AND reprocess IS NOT NULL ) > 0

              UNION                

             SELECT 3 order_by,

                    class, 

                    UPPER(status) status, 

                    COUNT(1) qty

               FROM ajcl_bc_trv_ar_headers 

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

             h.dff_invoice_num trv_transaction_no,

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

             -- 20240820

             l.dff_mg_load_id shipment_no,

             -- 20240820

             UPPER(l.status) line_status,

             l.error_message line_error_message

        FROM ajcl_bc_trv_ar_headers h,

             ajcl_bc_trv_ar_lines l

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

             h.dff_invoice_num trv_transaction_no,

             h.transactionDate transaction_date,

             h.gldate gl_date,

             h.billToCustomerName customer_name,

             h.billToCustomerNo customer_no,

             h.invoiceCurrencyCode currency_code,

             TRIM(TO_CHAR(h.amount,'999,999,999.00')) amount,

             UPPER(h.status) header_status,

             h.error_message header_error_message,

             l.lineNo line_num,

             l.description,

             TRIM(TO_CHAR(l.quantity,'999,999,999.00')) quantity,

             TRIM(TO_CHAR(l.unitSellingPrice,'999,999,999.00')) unit_selling_price,

             TRIM(TO_CHAR(l.extendedAmount,'999,999,999.00')) extended_amount,

             -- 20240820

             l.dff_mg_load_id shipment_no,

             -- 20240820

             UPPER(l.status) line_status,

             l.error_message line_error_message

        FROM ajcl_bc_trv_ar_headers h,

             ajcl_bc_trv_ar_lines l

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



    as_xlsx.save ( gv_directory_report, gv_ar_report_filename || '.' || LOWER(gv_file_format) );



    p_status := 'S';



    print_log( 'ajcl_bc_trv_ar_pkg.ar_final_report_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_trv_ar_pkg.ar_final_report_xlsx_p (!). Error: ' || SQLERRM );



  END ar_final_report_xlsx_p;



  -- 20241001

  -- FIX ACCOUNT 1110.1200

  PROCEDURE fix_dim_DATAMIG_inv_to_cm_p IS



    CURSOR c_lines IS

    SELECT l.rowid row_id,

           l.*

      FROM ajcl_bc_trv_ar_lines l

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



    print_log('ajcl_bc_trv_ar_pkg.fix_dim_DATAMIG_inv_to_cm_p (+)');



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



        UPDATE ajcl_bc_trv_ar_lines

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



    print_log('ajcl_bc_trv_ar_pkg.fix_dim_DATAMIG_inv_to_cm_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      NULL;



  END fix_dim_DATAMIG_inv_to_cm_p;

  -- 20241001



  PROCEDURE main_bc_p ( p_status   IN OUT   VARCHAR2,

                        p_module      OUT   VARCHAR2,

                        p_error_msg   OUT   VARCHAR2 ) IS



    v_phase                 VARCHAR2(200);



    v_status                VARCHAR2(1);

    v_error_message         VARCHAR2(2000);



    v_send_ar_data_to_bc    VARCHAR2(1) := 'Y';

    v_send_gl_data_to_bc    VARCHAR2(1) := 'Y';



    -- GL

    v_lines_count           NUMBER;

    v_journals_count        NUMBER;

    v_pending_rows          NUMBER := -1;

    e_gl_error              EXCEPTION;

    -- 20260108

    e_gl_job_error          EXCEPTION;

    -- 20260108    

    e_gl_exception          EXCEPTION;



    -- AR

    v_trx_count             NUMBER;

    e_ar_error              EXCEPTION;

    -- 20260108

    e_ar_job_error          EXCEPTION;

    -- 20260108 

    e_ar_exception          EXCEPTION;



  BEGIN



    print_log('ajcl_bc_trv_pkg.main_bc_p (+)');



    -- Se hace el insert de lo nuevo solo si el archivo no fue procesado aun

    IF ( gv_only_reprocess = 'N' ) THEN



      -- AJCL TRV GL Interface

      gl_insert_p ( p_status => v_status,

                    p_error_msg => v_error_message );



      IF ( v_status = 'W' ) THEN



        v_send_gl_data_to_bc := 'N';



      ELSIF ( v_status = 'E' ) THEN



        v_phase := 'gl_insert_p';

        RAISE e_gl_exception;



      END IF;



      -- AJCL TRV AR Interface

      ar_insert_p ( p_status => v_status,

                    p_error_msg => v_error_message );



      -- 20241001

      fix_dim_DATAMIG_inv_to_cm_p;

      -- 20241001



      IF ( v_status = 'W' ) THEN



        v_send_ar_data_to_bc := 'N';



      ELSIF ( v_status = 'E' ) THEN



        v_phase := 'ar_insert_p';

        RAISE e_ar_exception;



      END IF;



      IF ( v_send_gl_data_to_bc ='Y' OR v_send_ar_data_to_bc = 'Y' ) THEN



        worksheets_to_bc_p ( p_status => v_status );



        IF ( v_status != 'S' ) THEN



          v_phase := 'worksheets_to_bc_p';

          RAISE e_ar_error;



        END IF;



      END IF;



    END IF; -- gv_only_reprocess = 'N'



    -- GL ----------------------------------------------------------------------------------------------------------------------

    IF ( v_send_gl_data_to_bc = 'Y' ) THEN



      BEGIN



        gl_generate_jsons ( p_journals_count => v_journals_count,

                            p_error_message => v_error_message,

                            p_status => v_status );



        IF ( v_status != 'S' ) THEN



          v_phase := 'gl_generate_jsons';

          RAISE e_gl_error;



        END IF;



        IF NVL(v_journals_count,0) > 0 THEN



          -- dbms_lock - Lock --------------------------------------------------------------------------------------------------

          print_log ( 'Trying to lock ' || gv_gl_process_name || '.' );

          print_log ( 'If it stops at this point it is because it is blocked by another integration. It will continue once the other integration releases.' );



          ajc_bc_dbms_lock_pkg.lock_p ( p_process_name => gv_gl_process_name,

                                        p_id_lock => gv_gl_id_lock,

                                        p_request_status => gv_gl_request_status ); 



          IF ( gv_gl_request_status != 'success' ) THEN



            RAISE ge_gl_lock;



          END IF;

          -- dbms_lock - Lock --------------------------------------------------------------------------------------------------



          gl_call_ws ( p_error_message => v_error_message,

                       p_status => v_status );



          IF ( v_status != 'S' ) THEN



            v_phase := 'gl_call_ws';

            RAISE e_gl_error;



          END IF;



          gl_call_job ( p_error_message => v_error_message,

                        p_status => v_status );



          IF ( v_status != 'S' ) THEN



            v_phase := 'gl_call_job';



            -- 20260108

            -- RAISE e_gl_error;

            RAISE e_gl_job_error;

            -- 20260108



          END IF;



          -- dbms_lock - Release -----------------------------------------------------------------------------------------------

          ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_gl_id_lock,

                                           p_release_status => gv_gl_release_status );



          IF ( gv_gl_release_status != 'success' ) THEN



            RAISE ge_gl_release;



          END IF;                                     

          -- dbms_lock - Release -----------------------------------------------------------------------------------------------



          gl_call_ws_staging_pending ( p_pending_rows => v_pending_rows,

                                       p_error_message => v_error_message,

                                       p_status => v_status );



          IF ( v_status != 'S' ) THEN



            v_phase := 'gl_call_ws_staging_pending';

            RAISE e_gl_error;



          END IF;



          gl_call_ws_staging ( p_error_message => v_error_message,

                               p_status => v_status );



          IF ( v_status != 'S' ) THEN



            v_phase := 'gl_call_ws_staging';

            RAISE e_gl_error;



          END IF;



          gl_validate_ws_data ( p_error_message => v_error_message,

                                p_status => v_status );



          IF ( v_status != 'S' ) THEN



            v_phase := 'gl_validate_ws_data';

            RAISE e_gl_error;



          END IF;  



          -- 20240919

          -- Se agrega para borrar las lineas de la inbound si hay registros con error

          gl_check_lines_status_p ( p_error_message => v_error_message,

                                    p_status => v_status );

          -- 20240919



          -- INSERT GL REPORT IN TABLE AJCL_BC_REPORTS --------------------------------------------------------------------------------

          IF ( gv_file_format = 'CSV' ) THEN



            gl_final_report_csv_p ( p_status => v_status );     



            IF ( v_status != 'S' ) THEN



              v_phase := 'gl_final_report_csv_p';

              RAISE e_gl_exception;



            END IF;  



            -- CREATE CSV FROM TABLE AJCL_BC_REPORTS --------------------------------------------------------------------------------

            ajcl_bc_utils_pkg.create_csv_p ( p_ifc => gv_bc_gl_ifc,

                                             p_request_id => gv_request_id,

                                             p_log_seq => gv_log_seq,

                                             p_type => 'REPORT',

                                             p_filename => gv_gl_report_filename,

                                             p_status => v_status );



            IF ( v_status != 'S' ) THEN



              v_phase := 'create_csv_p | REPORT';

              RAISE e_gl_exception;



            END IF;



          ELSIF ( gv_file_format = 'XLSX' ) THEN 



            -- No inserta en tabla, genera el xlsx directamente en el filesystem

            gl_final_report_xlsx_p ( p_status => v_status );     



            IF ( v_status != 'S' ) THEN



              v_phase := 'gl_final_report_xlsx_p';

              RAISE e_gl_exception;



            END IF;  



          END IF;



          -- MAIL REPORT -----------------------------------------------------------------------------------------------------------

          BEGIN



            ajcl_bc_utils_pkg.send_mail_with_attach ( p_to_mail => gv_gl_email,

                                                      p_subject => gv_bc_gl_ifc || ' Report - ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                                      p_body => gv_bc_gl_ifc || ' Report.',

                                                      p_type => 'REPORT',

                                                      p_filename => gv_gl_report_filename, 

                                                      p_file_format => gv_file_format,

                                                      p_attach_filename => gv_bc_gl_ifc || ' Report ' || TO_CHAR(SYSDATE,'MMDDYYYY HH24MISS') || ' ' || gv_bc_environment || '.' || LOWER(gv_file_format) ); 



          EXCEPTION

            WHEN OTHERS THEN

              print_log ( 'SMTP NOT WORKING.' );



          END;



          -- Se agregar para borrar las lineas de la inbound si hay registros con error

          gl_check_lines_status ( p_error_message => v_error_message,

                                  p_status => v_status );



          IF ( v_status != 'S' ) THEN



            v_phase := 'gl_check_lines_status';

            RAISE e_gl_exception;



          END IF;



        ELSE



          print_log('No journals to process.');



          ajcl_bc_utils_pkg.send_email_p ( p_to => gv_gl_email,

                                           p_subject => gv_bc_gl_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                           p_message => 'No journals to process.' || CHR(10) || 'Request ID: ' || gv_request_id );



        END IF;



      EXCEPTION

        -- dbms_lock -----------------------------------------------------------------------------------------------------------

        WHEN ge_gl_lock THEN 

          print_log ('ajcl_bc_trv_pkg.main_bc_p. Error when trying to lock the process ' || gv_gl_process_name || 

                  ' | request_status: ' || gv_gl_request_status);

        -- dbms_lock -----------------------------------------------------------------------------------------------------------



        WHEN e_gl_error THEN

          print_log ( 'e_gl_error' );



          -- dbms_lock - Release -----------------------------------------------------------------------------------------------

          ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_gl_id_lock,

                                           p_release_status => gv_gl_release_status );  

          -- dbms_lock - Release -----------------------------------------------------------------------------------------------



          RAISE e_gl_exception;



        -- 20260108

        WHEN e_gl_job_error THEN

          print_log ( 'e_gl_job_error' );



          -- dbms_lock - Release -----------------------------------------------------------------------------------------------

          ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_gl_id_lock,

                                           p_release_status => gv_gl_release_status );  

          -- dbms_lock - Release -----------------------------------------------------------------------------------------------



          ajcl_bc_utils_pkg.send_email_p ( p_to => gv_support_email,

                                           p_subject => gv_bc_gl_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - WARNING - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                           p_message => 'There was a critical error processing journals.' || CHR(10) || 'Request ID: ' || gv_request_id );

          -- 20260108



        WHEN OTHERS THEN

          print_log ( 'General error GL. ' || SQLERRM  );



          -- dbms_lock - Release -----------------------------------------------------------------------------------------------

          ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_gl_id_lock,

                                           p_release_status => gv_gl_release_status );  

          -- dbms_lock - Release -----------------------------------------------------------------------------------------------



          RAISE e_gl_exception;



      END; 



    END IF; -- GL



    -- AR ----------------------------------------------------------------------------------------------------------------------

    IF ( v_send_ar_data_to_bc = 'Y' ) THEN



      BEGIN



        -- dbms_lock - Lock ---------------------------------------------------------------------------------------------------- 

        print_log ( 'Trying to lock ' || gv_ar_process_name || '.' );

        print_log ( 'If it stops at this point it is because it is blocked by another integration. It will continue once the other integration releases.' );



        ajc_bc_dbms_lock_pkg.lock_p ( p_process_name => gv_ar_process_name,

                                      p_id_lock => gv_ar_id_lock,

                                      p_request_status => gv_ar_request_status ); 



        IF ( gv_ar_request_status != 'success' ) THEN



          RAISE ge_ar_lock;



        END IF;

        -- dbms_lock - Lock ----------------------------------------------------------------------------------------------------



        ar_call_ws ( p_status => v_status,

                     p_trx_count => v_trx_count,

                     p_lines_count => v_lines_count );



        IF ( v_status != 'S' ) THEN



          v_phase := 'ar_call_ws';

          -- 20260108

          -- RAISE e_ar_error;

          RAISE e_ar_job_error;

          -- 20260108



        END IF;



        print_log ( 'v_trx_count: ' || v_trx_count );



        -- Si se envió al menos un comprobante, se ejecuta el job

        IF ( v_trx_count > 0 ) THEN



          -- Se ejecuta el JOB -----------------------------------------------------------------------------------------------------

          ar_call_job ( p_status => v_status );



          IF v_status != 'S' THEN



            v_phase := 'ar_call_job';

            RAISE e_ar_error;



          END IF;



          print_log ( 'v_lines_count: ' || v_lines_count );



          -- dbms_lock - Release -----------------------------------------------------------------------------------------------

          ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_ar_id_lock,

                                           p_release_status => gv_ar_release_status );



          IF ( gv_ar_release_status != 'success' ) THEN



            RAISE ge_ar_release;



          END IF;                                     

          -- dbms_lock - Release -----------------------------------------------------------------------------------------------



          -- Verifico el status de las lineas procesadas por el job ----------------------------------------------------------------

          ar_call_status ( p_status => v_status );



          IF v_status != 'S' THEN



            v_phase := 'ar_call_status';

            RAISE e_ar_error;



          END IF;



          -- INSERT AR REPORT IN TABLE AJCL_BC_REPORTS --------------------------------------------------------------------------------

          IF ( gv_file_format = 'CSV' ) THEN



            ar_final_report_csv_p ( p_status => v_status );     



            IF ( v_status != 'S' ) THEN



              v_phase := 'ar_final_report_csv_p';

              RAISE e_ar_exception;



            END IF;  



            -- CREATE CSV FROM TABLE AJCL_BC_REPORTS --------------------------------------------------------------------------------

            ajcl_bc_utils_pkg.create_csv_p ( p_ifc => gv_bc_ar_ifc,

                                             p_request_id => gv_request_id,

                                             p_log_seq => gv_log_seq,

                                             p_type => 'REPORT',

                                             p_filename => gv_ar_report_filename,

                                             p_status => v_status );



            IF ( v_status != 'S' ) THEN



              v_phase := 'create_csv_p | REPORT';

              RAISE e_ar_exception;



            END IF;



          ELSIF ( gv_file_format = 'XLSX' ) THEN 



            -- No inserta en tabla, genera el xlsx directamente en el filesystem

            ar_final_report_xlsx_p ( p_status => v_status );     



            IF ( v_status != 'S' ) THEN



              v_phase := 'ar_final_report_xlsx_p';

              RAISE e_ar_exception;



            END IF;  



          END IF;



          -- MAIL REPORT -----------------------------------------------------------------------------------------------------------

          BEGIN



            ajcl_bc_utils_pkg.send_mail_with_attach ( p_to_mail => gv_ar_email,

                                                      p_subject => gv_bc_ar_ifc || ' Report - ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                                      p_body => gv_bc_ar_ifc || ' Report.',

                                                      p_type => 'REPORT',

                                                      p_filename => gv_ar_report_filename, 

                                                      p_file_format => gv_file_format,

                                                      p_attach_filename => gv_bc_ar_ifc || ' Report ' || TO_CHAR(SYSDATE,'MMDDYYYY HH24MISS') || ' ' || gv_bc_environment || '.' || LOWER(gv_file_format) );     



          EXCEPTION

            WHEN OTHERS THEN

              print_log ( 'SMTP NOT WORKING.' );



          END;



        ELSE



          print_log ( 'No sales documents to process.' );



          -- dbms_lock - Release -----------------------------------------------------------------------------------------------

          ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_ar_id_lock,

                                           p_release_status => gv_ar_release_status );



          IF ( gv_ar_release_status != 'success' ) THEN



            RAISE ge_ar_release;



          END IF;                                     

          -- dbms_lock - Release -----------------------------------------------------------------------------------------------



          ajcl_bc_utils_pkg.send_email_p ( p_to => gv_ar_email,

                                           p_subject => gv_bc_ar_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                           p_message => 'No sales documents to process.' || CHR(10) || 'Request ID: ' || gv_request_id );



        END IF;



      EXCEPTION

        -- dbms_lock -----------------------------------------------------------------------------------------------------------

        WHEN ge_ar_lock THEN 

          print_log ('ajcl_bc_trv_pkg.main_bc_p. Error when trying to lock the process ' || gv_ar_process_name || 

                  ' | request_status: ' || gv_ar_request_status);

        -- dbms_lock -----------------------------------------------------------------------------------------------------------



        WHEN e_ar_error THEN

          print_log ( 'e_ar_error' );



          -- dbms_lock - Release -----------------------------------------------------------------------------------------------

          ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_ar_id_lock,

                                           p_release_status => gv_ar_release_status );  

          -- dbms_lock - Release -----------------------------------------------------------------------------------------------



          RAISE e_ar_exception;



        -- 20260108    

        WHEN e_ar_job_error THEN

          print_log ( 'e_ar_job_error' );



          -- dbms_lock - Release -----------------------------------------------------------------------------------------------

          ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_ar_id_lock,

                                           p_release_status => gv_ar_release_status );  

          -- dbms_lock - Release -----------------------------------------------------------------------------------------------



          ajcl_bc_utils_pkg.send_email_p ( p_to => gv_support_email,

                                           p_subject => gv_bc_ar_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - WARNING - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                           p_message => 'There was a critical error processing sales documents.' || CHR(10) || 'Request ID: ' || gv_request_id );

          -- 20260108        



        WHEN OTHERS THEN

          print_log ( 'General error AR. ' || SQLERRM );



          -- dbms_lock - Release -----------------------------------------------------------------------------------------------

          ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_ar_id_lock,

                                           p_release_status => gv_ar_release_status );  

          -- dbms_lock - Release ----------------------------------------------------------------------------------------------- 



          RAISE e_ar_exception;



      END; 



    END IF; -- AR



    p_status := 'S';



    print_log('ajcl_bc_trv_pkg.main_bc_p (-)');



  EXCEPTION

    WHEN e_ar_exception THEN

      p_status := 'E';

      p_module := 'AR';

      p_error_msg := v_error_message;

      print_log (v_error_message);

      print_log( 'ajcl_bc_trv_pkg.main_bc_p (!)' );



    WHEN e_gl_exception THEN

      p_status := 'E';

      p_module := 'GL';

      p_error_msg := v_error_message;

      print_log (v_error_message);



      -- Llamo al Web Service que borra tablas de staging de General Journals en BC

      -- 20240917

      /*

      gl_call_ws_delete ( p_error_message => v_error_message,

                          p_status => v_status );

      */

      -- 20240917



      print_log( 'ajcl_bc_trv_pkg.main_bc_p (!)' );



    WHEN OTHERS THEN

      p_status := 'E';

      print_log ( v_phase );

      print_log( 'ajcl_bc_trv_pkg.main_bc_p (!). Error: ' || SQLERRM );



  END main_bc_p;  



  PROCEDURE main_p ( p_bc_environment              IN   VARCHAR2,

                     -- 20240905 p_check_integrations_source   IN   VARCHAR2,

                     p_jenkins_build_number        IN   VARCHAR2 ) IS



    v_run_id            NUMBER;



    v_status            VARCHAR(1);

    v_module            VARCHAR2(10);

    v_phase             VARCHAR2(200);

    v_error_msg         VARCHAR2(4000);



    -- 20250507

    -- 20260108 v_support_email          VARCHAR2(200);

    v_ar_not_success         NUMBER;

    v_gl_not_success         NUMBER;

    -- 20250507



    e_error             EXCEPTION;

    e_parameter_value   EXCEPTION;

    e_bc_setup          EXCEPTION;



  BEGIN



    gv_request_id := ajcl_bc_utils_pkg.get_request_id_f;

    gv_jenkins_build_number := p_jenkins_build_number;



    -- Se inserta el concurrent_job

    ajcl_bc_utils_pkg.ins_jenkins_concurrent_job_p ( p_request_id => gv_request_id,

                                                     p_job_name => gv_bc_ifc,

                                                     p_jenkins_build_number => p_jenkins_build_number,

                                                     p_argument1 => p_bc_environment

                                                     -- 20240905 ,p_argument2 => p_check_integrations_source 

                                                     );



    print_log ( 'ajcl_bc_trv_pkg.main_p (+)');

    print_log ( 'gv_request_id: ' || gv_request_id ); 



    -- 20240905 gv_check_integrations_source := p_check_integrations_source;

    -- 20240905 print_log ( 'gv_check_integrations_source: ' || gv_check_integrations_source );



    gv_file_format := ajcl_bc_ws_utils_pkg.get_parameter_f ( 'FILE_FORMAT' );

    print_log( 'FILE_FORMAT: ' || gv_file_format ); 



    gv_ar_email := ajcl_bc_utils_pkg.get_emails_f ( 'TRV SALES DOC' );

    -- gv_ar_email := 'sbanchieri@gmail.com'; -- QUITAR

    print_log( 'gv_ar_email: ' || gv_ar_email );



    gv_ar_process_name := ajcl_bc_ws_utils_pkg.get_lock_process_name_f ( p_integration => 'SALES DOCUMENTS' );

    print_log( 'gv_ar_process_name: ' || gv_ar_process_name );



    gv_gl_email := ajcl_bc_utils_pkg.get_emails_f ( 'TRV JOURNALS' );

    -- gv_gl_email := 'sbanchieri@gmail.com'; -- QUITAR

    print_log( 'gv_gl_email: ' || gv_gl_email );



    gv_gl_process_name := ajcl_bc_ws_utils_pkg.get_lock_process_name_f ( p_integration => 'JOURNALS' );

    print_log( 'gv_gl_process_name: ' || gv_gl_process_name );



    -- 20260108

    gv_support_email := ajcl_bc_utils_pkg.get_emails_f ( 'SUPPORT' );

    print_log( 'gv_support_email: ' || gv_support_email );

    -- 20260108



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



    -- Get MAX Run ID to process

    SELECT MAX(oracle_xml_run_id) 

      INTO gv_run_id

      FROM ajc_trv_interface;   



    print_log ('Run Id: ' || gv_run_id);



    print_log ( 'gv_journal_source: ' || gv_journal_source );

    print_log ( 'gv_default_billed_trx_type: ' || gv_default_billed_trx_type );

    print_log ( 'gv_default_cogs_recog_je_cat: ' || gv_default_cogs_recog_je_cat );

    print_log ( 'gv_default_accrual_trx_type: ' || gv_default_accrual_trx_type );

    print_log ( 'gv_default_batch_source: ' || gv_default_batch_source );



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



    -- Se obtienen los General Journal Entries con source GENJNL y REVERSAL de BC

    ajcl_bc_get_entities_pkg.get_journals_p ( p_bc_environment => gv_bc_environment,

                                              p_bc_ifc => gv_bc_ifc,

                                              p_request_id => gv_request_id,

                                              p_log_seq => gv_log_seq,

                                              p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'ajcl_bc_get_entities_pkg.get_journals_p';

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



    -- Se obtienen los business lines de BC

    ajcl_bc_get_entities_pkg.get_ies_business_lines_p ( p_bc_environment => gv_bc_environment,

                                                        p_bc_ifc => gv_bc_ifc,

                                                        p_request_id => gv_request_id,

                                                        p_log_seq => gv_log_seq,

                                                        p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'ajcl_bc_get_entities_pkg.get_ies_business_lines_p';

      RAISE e_error;



    END IF;



    -- Se obtienen los items de BC

    ajcl_bc_get_entities_pkg.get_ies_items_p ( p_bc_environment => gv_bc_environment,

                                               p_bc_ifc => gv_bc_ifc,

                                               p_request_id => gv_request_id,

                                               p_log_seq => gv_log_seq,

                                               p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'ajcl_bc_get_entities_pkg.get_ies_items_p';

      RAISE e_error;



    END IF;



    -- Se obtienen los Logistic Integrations Source

    ajcl_bc_get_entities_pkg.get_cust_xref_p ( p_bc_environment => gv_bc_environment,

                                               p_bc_ifc => gv_bc_ifc,

                                               p_request_id => gv_request_id,

                                               p_log_seq => gv_log_seq,

                                               p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'ajcl_bc_get_entities_pkg.get_cust_xref_p';

      RAISE e_error;



    END IF;



    -- print_log ( 'The Allow Posting From and Allow Posting To dates are obtained from BC General Ledger Setup.' );

    print_log ( 'The Allow Posting From and Allow Posting To dates are obtained from BC User Setup.' );

    ajcl_bc_get_entities_pkg.get_bc_allow_posting_from_to_p ( p_bc_environment => gv_bc_environment,

                                                              p_bc_company_id => gv_bc_company_id,

                                                              p_bc_start_date => gv_bc_start_date,

                                                              p_bc_end_date => gv_bc_end_date,

                                                              p_status => v_status,

                                                              p_error_msg => v_error_msg );



    print_log ( 'gv_bc_start_date: ' || gv_bc_start_date );

    print_log ( 'gv_bc_end_date: ' || gv_bc_end_date );



    IF ( v_status != 'S' ) THEN



      v_phase := 'ajcl_bc_get_entities_pkg.get_bc_allow_posting_from_to_p';

      RAISE e_error;



    END IF;



    -- AJCL TRV Step 1 Validation

    step_1_validation ( p_status => v_status );



    IF ( v_status = 'E' ) THEN



      v_phase := 'step_1_validation';

      RAISE e_error;



    END IF;



    -- Solo si no es un reproceso, se ejecutan estos procedures

    IF ( gv_only_reprocess = 'N' ) THEN



      -- AJCL TRV Step 2 Validation

      step_2_validation ( p_status => v_status );



      IF ( v_status != 'S' ) THEN



        v_phase := 'step_2_validation';

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



        ajcl_bc_utils_pkg.send_mail_with_attach ( p_to_mail => gv_ar_email,

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



    END IF; -- gv_only_reprocess = 'N'



    -- 20251106 REINTENTO

    gv_retry_in_seconds := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'POST_RETRY_IN_SECONDS' );

    print_log ( 'POST_RETRY_IN_SECONDS: ' || gv_retry_in_seconds );    

    -- 20251106 REINTENTO



    main_bc_p ( p_status => v_status,

                p_module => v_module,

                p_error_msg => v_error_msg );



    IF ( v_status != 'S' ) THEN



      v_phase := 'main_bc_p';

      RAISE e_error;



    END IF;



    -- 20250507

    -- Se agrega envio de mail para soporte, para informar que no se pudo importar todo en la ejecucion 

    BEGIN



      -- 20260108 - Se obtiene en main_p, y se guarda en una global

      -- v_support_email := ajcl_bc_utils_pkg.get_emails_f ( 'SUPPORT' );

      -- 20260108



      -- AR ------------------------------------------------------------------------

      SELECT COUNT(1) 

        INTO v_ar_not_success

        FROM ajcl_bc_trv_ar_headers

       WHERE request_id = gv_request_id

         AND UPPER(status) != 'SUCCESS';



      print_log ('v_ar_not_success: ' || v_ar_not_success);



      IF ( v_ar_not_success > 0 ) THEN



        ajcl_bc_utils_pkg.send_email_p ( -- 20260108

                                         -- p_to => v_support_email,

                                         p_to => gv_support_email,

                                         -- 20260108

                                         p_subject => gv_bc_ar_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - WARNING - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => 'Some invoices could not be imported. Please review the integration report.' || CHR(10) || 'Request ID: ' || gv_request_id );



      END IF;



      -- GL ------------------------------------------------------------------------

      SELECT COUNT(1)

        INTO v_gl_not_success

        FROM ajcl_bc_trv_gl_lines

       WHERE request_id = gv_request_id

         AND UPPER(status) != 'SUCCESS';



      print_log ('v_gl_not_success: ' || v_gl_not_success);  



      IF ( v_gl_not_success > 0 ) THEN



        ajcl_bc_utils_pkg.send_email_p ( -- 20260108

                                         -- p_to => v_support_email,

                                         p_to => gv_support_email,

                                         -- 20260108

                                         p_subject => gv_bc_gl_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - WARNING - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => 'Some journals could not be imported. Please review the integration report.' || CHR(10) || 'Request ID: ' || gv_request_id );



      END IF;



    EXCEPTION

      WHEN OTHERS THEN

        NULL;



    END;

    -- 20250507



    -- Se actualiza el concurrent_job

    ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'S' );



    print_log('ajcl_bc_trv_pkg.main_p (-)');



  EXCEPTION 

    WHEN e_bc_setup THEN

      print_log('ajcl_bc_trv_pkg.main_p (!). BC setup error. please contact support.');



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



    WHEN e_parameter_value THEN

      print_log('ajcl_bc_trv_pkg.main_p (!)');

      print_log(v_error_msg);



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_gl_email,

                                       p_subject => gv_bc_gl_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => v_error_msg || CHR(10) || 'Request ID: ' || gv_request_id );



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_ar_email,

                                       p_subject => gv_bc_ar_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => v_error_msg || CHR(10) || 'Request ID: ' || gv_request_id );



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );  



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );



    WHEN e_error THEN

      print_log('ajcl_bc_trv_pkg.main_p (!). Error: ' || SQLERRM);

      print_log('Phase: ' || v_phase);



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );  



      IF ( v_module = 'GL' ) THEN



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_gl_email,

                                         p_subject => gv_bc_gl_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => 'General Error: ' || SQLERRM || CHR(10) || 'Request ID: ' || gv_request_id );



      ELSIF ( v_module = 'AR' ) THEN



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_ar_email,

                                         p_subject => gv_bc_ar_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => 'General Error: ' || SQLERRM || CHR(10) || 'Request ID: ' || gv_request_id );



      ELSE



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_gl_email,

                                         p_subject => gv_bc_gl_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => 'General Error: ' || SQLERRM || CHR(10) || 'Request ID: ' || gv_request_id );



        IF ( gv_gl_email != gv_ar_email ) THEN



          ajcl_bc_utils_pkg.send_email_p ( p_to => gv_ar_email,

                                           p_subject => gv_bc_ar_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                           p_message => 'General Error: ' || SQLERRM || CHR(10) || 'Request ID: ' || gv_request_id );



        END IF;                                           



      END IF;



      RAISE_APPLICATION_ERROR(-20000,'Error at phase: ' || v_phase );



    WHEN OTHERS THEN

      print_log('ajcl_bc_trv_pkg.main_p (!). General Error: ' || SQLERRM);     



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_gl_email,

                                       p_subject => gv_bc_gl_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => 'General Error: ' || SQLERRM || CHR(10) || 'Request ID: ' || gv_request_id );



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_ar_email,

                                       p_subject => gv_bc_ar_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => 'General Error: ' || SQLERRM || CHR(10) || 'Request ID: ' || gv_request_id );



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );  



      RAISE_APPLICATION_ERROR(-20000,'General Error: ' || SQLERRM );    



  END main_p;



END ajcl_bc_trv_pkg;
