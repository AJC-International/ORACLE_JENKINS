PACKAGE BODY ajcl_bc_trv_pkg IS
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

        IF ( file_type_v = 'Route-QACOGS
