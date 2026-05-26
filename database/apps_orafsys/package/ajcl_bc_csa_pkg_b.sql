PACKAGE BODY ajcl_bc_csa_pkg IS
-- Creation: SBANCHIERI 23-AUG-2023 
  
  gv_ftp_loader                     VARCHAR2(1); -- := 'N'; -- Se resuelve mas abajo, segun la db

  -- Paramters
  -- 20241211 gv_filename                       VARCHAR2(50); -- Se define su valor en el main, segun la db donde estamos parados
  --
  gv_csa_je_source                  VARCHAR2(50) := 'CSA Cost Entries'; 
  gv_gl_category_cogs_accrual       VARCHAR2(50) := 'CSA COGS Recognition';
  gv_gl_cat_cogs_accrual_rev        VARCHAR2(50) := 'CSA COGS Reversal';
  gv_gl_category_transit            VARCHAR2(50) := 'CSA InTransit Accrual';
  gv_gl_category_transit_rev        VARCHAR2(50) := 'CSA InTransit Reversal';
  gv_default_subaccount             VARCHAR2(50) := 'TBD';
  gv_default_division               VARCHAR2(50) := 'TBD';
  gv_default_csa_inv_type           NUMBER := 1655; -- CSA INVOICE
  gv_default_csa_batch_source       NUMBER := 1551; -- CSA IMPORT
  gv_default_ies_batch_source       NUMBER := 1431; -- IES IMPORT
  gv_starting_pk_seqno              NUMBER; 
  gv_ies_je_source                  VARCHAR2(50) := 'IES Payables';
  -- 

  -- 20251106 REINTENTO
  gv_retry_in_seconds               NUMBER;
  gv_retry                          VARCHAR2(1);
  -- 20251106 REINTENTO

  -- 20260108
  gv_support_email                 VARCHAR2(200);
  -- 20260108

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    gv_log_seq := gv_log_seq + 1;
    ajcl_bc_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );

  END print_log;

  -- 20240828
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
  -- 20240828

  PROCEDURE file_validation_p ( p_status      OUT   VARCHAR2,
                                p_error_msg   OUT   VARCHAR2 ) IS

    csa_file_no_v                   ajc_csa_interfaceAPAR_temp.csa_file_no%TYPE;
    report_date_v                   VARCHAR2(25);
    last_file_processed_v           ajc_csa_interfaceAPAR_temp.csa_file_no%TYPE;
    num_recs_already_processed_v    NUMBER;
    file_in_control_tab_v           NUMBER := 0; 
    mesg_v                          VARCHAR2(200);
    error_code_v                    NUMBER;

    error_message_v                 VARCHAR2(240);
    prog_failed_v                   BOOLEAN;
    stop_prog                       EXCEPTION;
    e_only_reprocess                EXCEPTION;

  BEGIN

    print_log( 'ajcl_bc_csa_pkg.file_validation_p (+)' );

    -- Find the csa_file_no being processed
    BEGIN

      SELECT csa_file_no, 
             TO_CHAR(SYSDATE,'DD-MON-YYYY HH:MI:SS')
        INTO csa_file_no_v, 
             report_date_v
        FROM ajc_csa_interfaceAPAR_temp
       WHERE ROWNUM = 1;

    EXCEPTION
      WHEN OTHERS THEN
        RAISE e_only_reprocess;

    END;

    print_log('Report Date: ' || report_date_v || ' - AJC CSA File Validation Report');
    print_log('CSA File No: ' || csa_file_no_v );

    -- Find the last csa_file_no processed from the interface table
    SELECT MAX(csa_file_no)
      INTO last_file_processed_v
      FROM ajc_csa_interfaceAPAR;

    print_log('last_file_processed_v: ' || last_file_processed_v);

    -- Determine if there are records in the interface table for the csa_file_no being processed
    SELECT COUNT(*)
      INTO num_recs_already_processed_v
      FROM ajc_csa_interfaceAPAR
     WHERE csa_file_no = csa_file_no_v;

    print_log('num_recs_already_processed_v: ' || num_recs_already_processed_v);

    IF ( num_recs_already_processed_v > 0 ) THEN

      mesg_v := 'CSA File No: ' || csa_file_no_v || ' has already been processed.';
      RAISE e_only_reprocess; 

    END IF;

    -- Se salva el error para la primera ejecucion
    IF ( last_file_processed_v IS NOT NULL ) THEN

      IF ( csa_file_no_v < last_file_processed_v ) THEN

        mesg_v := 'CSA File No: ' || csa_file_no_v || ' created before last file processed,' || last_file_processed_v;
        RAISE stop_prog;

      END IF;

      -- Determine if the latest csa file in the interface table has been processed(a record is in the control table).
      -- if not then stop processing
      SELECT COUNT(*) 
        INTO file_in_control_tab_v 
        FROM ajc_csa_control
       WHERE csa_file_no = last_file_processed_v;

      print_log('file_in_control_tab_v: ' || file_in_control_tab_v);

      IF ( file_in_control_tab_v = 0 ) THEN

        mesg_v := 'The latest file in the csa interface table, ' || last_file_processed_v || ' has not been processed.';
        RAISE stop_prog;

      END IF;

    END IF;

    print_log('CSA Data File Validation Successful');

    -- Copy the data from the temp table to the interface table
    INSERT
      INTO ajc_csa_interfaceAPAR
           ( csa_file_no,
             PK_SeqNo,
             FK_OrderNo,
             FK_CVNo,
             FK_SeqNo,
             Description, 
             Quantity,
             ChargeCode,
             Total,
             APARCode,
             Finalize,
             FK_StationId,
             Housebill,
             InvoiceDate,
             CreateDate,
             ShipmentDateTime,
             PODDateTime,
             RefNo,
             FK_ServiceId,
             SubAccount,
             Division,
             Processed,
             Created_By,
             Creation_Date,
             Last_Updated_By,
             Last_Update_Date,
             InvoiceAmount )
      SELECT csa_file_no,
             PK_SeqNo,
             FK_OrderNo,
             FK_CVNo,
             FK_SeqNo,
             Description, 
             Quantity,
             ChargeCode,
             Total,
             APARCode,
             Finalize,
             FK_StationId,
             Housebill,
             InvoiceDate,
             CreateDate,
             ShipmentDateTime,
             PODDateTime,
             RefNo,
             FK_ServiceId,
             SUBSTR(SubAccount,1,3),
             Division,
             Processed,
             gv_user_id,
             SYSDATE,
             gv_user_id,
             SYSDATE,
             InvoiceAmount
        FROM ajc_csa_interfaceAPAR_temp
       WHERE housebill IS NOT NULL;

    COMMIT;

    print_log('Number of rows inserted into interface table ajc_csa_interfaceAPAR: ' || SQL%ROWCOUNT);

    p_status := 'S';
    print_log( 'ajcl_bc_csa_pkg.file_validation_p (-)' );

  EXCEPTION
    WHEN stop_prog THEN
      print_log( 'ajcl_bc_csa_pkg.file_validation_p (!)' );
      p_status := 'E';
      print_log('>>> Validation FAILED - '||mesg_v);
      p_error_msg := mesg_v;
      print_log('Processing will be terminated');

    WHEN e_only_reprocess THEN
      print_log( 'ajcl_bc_csa_pkg.file_validation_p (!)' );
      p_status := 'W';
      gv_only_reprocess := 'Y';
      p_error_msg := 'The file has already been processed. Only errors/rejects records from previous runs will be reprocessed.';
      print_log('The file has already been processed. Only errors/rejects records from previous runs will be reprocessed.');

    WHEN OTHERS THEN
      print_log( 'ajcl_bc_csa_pkg.file_validation_p (!)' );
      error_code_v := SQLCODE;
      p_error_msg := SQLERRM;
      error_message_v := SQLERRM;
      print_log('Program encountered an unexpected error: ');
      print_log(TO_CHAR(error_code_v)||'-'||error_message_v);

  END file_validation_p;

  PROCEDURE get_start_seq IS

    v_file1         NUMBER;
    v_file2         NUMBER;
    v_last_seq      INTEGER := 0;

  BEGIN

    print_log('ajcl_bc_csa_pkg.get_start_seq (+)');

    SELECT MAX(pk_seqno)
      INTO v_last_seq
      FROM ajc_csa_interfaceAPAR
     WHERE validation_status = 'Y';

    print_log ( 'v_last_seq: ' || v_last_seq );

    IF ( v_last_seq IS NULL ) THEN

      v_last_seq := 0;

    ELSE

      SELECT csa_file_no
        INTO v_file1
        FROM ajc_csa_interfaceAPAR
       WHERE pk_seqno = v_last_seq
         AND validation_status = 'Y';

		    print_log ( 'v_file1: ' || v_file1 );

    END IF;

    print_log ( 'Last processed max sequence number: ' || v_last_seq || ' for file ' || v_file1 );

    IF ( ( gv_starting_pk_seqno IS NULL ) OR ( gv_starting_pk_seqno < v_last_seq ) ) THEN

      gv_start_seq := v_last_seq + 1;

    ELSE

      gv_start_seq := gv_starting_pk_seqno;

    END IF;

    BEGIN

      SELECT csa_file_no
        INTO v_file2
        FROM ajc_csa_interfaceAPAR
       WHERE pk_seqno = gv_start_seq
         AND validation_status IS NULL;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN 
        NULL;

    END;

    print_log ( 'Next starting sequence number (gv_start_seq): ' || gv_start_seq || ' for file ' || v_file2 );
    print_log('ajcl_bc_csa_pkg.get_start_seq (-)');

  END get_start_seq;

  PROCEDURE get_proc_count IS

  BEGIN

    print_log('ajcl_bc_csa_pkg.get_proc_count (+)');  

    SELECT COUNT(*)
      INTO gv_count
      FROM ajc_csa_interfaceAPAR
     WHERE ( ( validation_status = 'C' ) OR ( validation_status IS NULL AND pk_seqno >= gv_start_seq ) );

	   print_log ( 'gv_count: ' || gv_count );

    print_log('ajcl_bc_csa_pkg.get_proc_count (-)');  

  END get_proc_count;

  PROCEDURE insert_control_rec IS

  BEGIN

    print_log('ajcl_bc_csa_pkg.insert_control_rec (+)');  

    INSERT 
      INTO ajc_csa_control 
         ( csa_file_no,
           start_pk_seqno )
    SELECT MAX(csa_file_no),
           MAX(gv_start_seq)
      FROM ajc_csa_interfaceAPAR a
     WHERE ( ( aparcode = 'V' AND TRUNC(shipmentdatetime) > TO_DATE('01-JAN-1900') ) OR ( aparcode = 'C') )
       AND ( ( validation_status = 'C' ) OR ( validation_status IS NULL AND pk_seqno >= gv_start_seq ) )
       AND NOT EXISTS ( SELECT 'x'
                          FROM ajc_csa_control
                         WHERE csa_file_no = a.csa_file_no );

	   -- print_log ( 'Record count: ' || SQL%ROWCOUNT );

		  print_log ('ajcl_bc_csa_pkg.insert_control_rec (-)');  

  END insert_control_rec;

  PROCEDURE init_vars IS
  BEGIN

    gv_valid := NULL;
    gv_fin_chrg_exists := NULL;
    gv_err_msg := NULL;
    gv_val_status := NULL;
    gv_ar_status := NULL;
    gv_gl_status := NULL;
    gv_gl_date := NULL;
    gv_trx_date := NULL;
    gv_in_date := NULL;
    gv_out_date := NULL;
    gv_reversal_source := NULL;
    gv_ar_reversal_ref_name := NULL;
    gv_gl_reversal_ref_name := NULL;
    gv_je_category := NULL;
    gv_ar_reversal_ref_id := NULL;

    gv_gl_rev_ref_entryno := NULL;
    gv_gl_reversal_ref_id := NULL;

    gv_worksheet := NULL;
    gv_ar_invoice_amt := NULL;
    gv_ar_app_cm_amt := NULL;
    gv_ar_manual_cm_amt := NULL;
    gv_gl_rvrs_amt := NULL;

  END init_vars;

  PROCEDURE insert_rep_table ( p_housebill      IN   VARCHAR2,
                               p_csa_file_no    IN   NUMBER ) IS   
  BEGIN

    print_log ('ajcl_bc_csa_pkg.insert_rep_table (+)');  

    INSERT 
      INTO ajc_csa_valid_report
         ( housebill,
           csa_file_no )
    SELECT p_housebill,
           p_csa_file_no
      FROM dual
     WHERE NOT EXISTS ( SELECT 'x'
                          FROM ajc_csa_valid_report
                         WHERE housebill = p_housebill
                           AND csa_file_no = p_csa_file_no );


	   -- print_log ( 'Record count: ' || SQL%ROWCOUNT );

    print_log ('ajcl_bc_csa_pkg.insert_rep_table (-)');  

  END insert_rep_table;

  -- =========================================================
   -- Procedure upd_interface
   -- Updates interface record
   -- =========================================================
  PROCEDURE upd_interface ( p_val_status     IN     VARCHAR2,
                            p_err_msg        IN     VARCHAR2,
                            p_worksheet      IN     VARCHAR2,
                            p_tot_cr         IN     NUMBER, 
                            p_trx_date       IN     DATE,
                            p_gl_date        IN     DATE,
                            p_ar_status      IN     VARCHAR2,
                            p_gl_status      IN     VARCHAR2,
                            p_rev_source     IN     VARCHAR2,
                            p_ar_ref_name    IN     VARCHAR2,
                            p_gl_ref_name    IN     VARCHAR2,
                            p_ar_ref_entryno IN     VARCHAR2,
                            p_ar_ref_id      IN     VARCHAR2,
                            p_gl_ref_entryno IN     VARCHAR2,
                            p_gl_ref_id      IN     VARCHAR2,
                            p_last_upd_by    IN     NUMBER,
                            p_last_upd_date  IN     DATE,
                            p_rowid          IN     ROWID ) IS 

  BEGIN

    print_log ('ajcl_bc_csa_pkg.upd_interface (+)');  

    UPDATE ajc_csa_interfaceAPAR
       SET validation_status = p_val_status,
           error_message = p_err_msg,
           worksheet = p_worksheet,
           total_credit_amount = p_tot_cr,
           trx_date = p_trx_date,
           gl_date = p_gl_date,
           ar_status = p_ar_status,
           gl_status = p_gl_status,
           reversal_source = p_rev_source,
           ar_reversal_ref_name = p_ar_ref_name,
           gl_reversal_ref_name = p_gl_ref_name,
           ar_reversal_entryno = p_ar_ref_entryno,
           ar_reversal_ref_id = p_ar_ref_id,
           gl_reversal_entryno = p_gl_ref_entryno,
           gl_reversal_ref_id = p_gl_ref_id,
           last_updated_by = p_last_upd_by,
           last_update_date = p_last_upd_date
     WHERE rowid = p_rowid;

    COMMIT; 

	  	-- print_log ( 'Record count: ' || SQL%ROWCOUNT );

    print_log ('ajcl_bc_csa_pkg.upd_interface (-)');  

  END upd_interface;

  -- =========================================================
   -- Procedure validate
   -- Validate data in the record; validation outcome can be success,
   -- correctable error, or incorrectable error. Correctable errors can
   -- be fixed by users and the record can be reprocessed. Incorrectable
   -- errors will be reported until the file is completely processed,
   -- but cannot be fixed.
   -- =========================================================
  PROCEDURE validate_p ( p_aparcode       IN       VARCHAR2,
                         p_finalize       IN       VARCHAR2,
                         p_poddatetime    IN       DATE,
                         p_fk_cvno        IN       NUMBER, 
                         p_chargecode     IN       VARCHAR2,
                         p_fk_orderno     IN       NUMBER,
                         p_fk_stationid   IN       VARCHAR2,
                         p_fk_serviceid   IN       VARCHAR2,
                         p_fk_seqno       IN       NUMBER,
                         p_housebill      IN       NUMBER,
                         p_total          IN       NUMBER,
                         p_invoiceamount  IN       NUMBER ) IS 

  BEGIN

    print_log ('ajcl_bc_csa_pkg.validate_p (+)');  

    IF ( p_aparcode = 'C' AND p_finalize = 'Y' AND TRUNC(p_poddatetime) = TO_DATE('01-JAN-1900') AND gv_err_msg IS NULL ) THEN

      print_log ( 'Validating aparcode/final/pod datetime ' || p_aparcode || '/' || p_finalize || '/' || p_poddatetime);

      gv_err_msg := 'No PODDate for Billed Trx';
      print_log ( 'No PODDate for Billed Trx' );
      gv_val_status := 'I';

    END IF;

    -- Validate customer/vendor 
    IF ( gv_err_msg IS NULL ) THEN

      print_log ( 'Validating fk_cvno: ' || p_fk_cvno );
      print_log ( 'Validating p_aparcode: ' || p_aparcode );

      BEGIN

        SELECT 'Y'
          INTO gv_valid
          -- FROM ajc_bplus_cust_xref
          FROM ajcl_bc_cust_xref
         WHERE bc_environment = gv_bc_environment
           AND bp_cust_id = p_fk_cvno
           AND source = 'CSA'
           AND source_type = 'VENDOR'
           AND p_aparcode = 'V'
         UNION
        SELECT 'Y'
          -- FROM ajc_bplus_cust_xref
          FROM ajcl_bc_cust_xref
         WHERE bc_environment = gv_bc_environment
           AND bp_cust_id = p_fk_cvno
           AND source = 'CSA'
           AND source_type = 'CUSTOMER'
           AND p_aparcode = 'C';

		      print_log ( 'gv_valid: ' || gv_valid );

      EXCEPTION
        WHEN NO_DATA_FOUND THEN

          IF ( p_aparcode = 'C' ) THEN

            gv_err_msg := 'Invalid Customer# ' || p_fk_cvno;
            print_log ( 'Invalid Customer# ' || p_fk_cvno );

          END IF;

          IF p_aparcode = 'V' THEN

            gv_err_msg := 'Invalid Vendor# ' || p_fk_cvno;
            print_log ( 'Invalid Vendor# ' || p_fk_cvno );

          END IF;

          gv_val_status := 'C';

      END;

    END IF;

    gv_valid := null;

    -- Validate charge code 
    IF ( p_chargecode IS NOT NULL AND gv_err_msg IS NULL ) THEN

      print_log ( 'Validating charge code ' || p_chargecode );

      BEGIN

        SELECT 'Y'
          INTO gv_valid
          FROM ajcl_bc_ies_items
         WHERE bc_environment = gv_bc_environment
           AND charge_type_code = p_chargecode
           AND business_line = '76'
           AND NVL(inactive_date, SYSDATE + 1) > SYSDATE;

			     print_log ( 'gv_valid: ' || gv_valid );

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          gv_err_msg := 'Invalid Charge Code ' || p_chargecode;
          print_log ( 'Invalid Charge Code ' || p_chargecode );
          gv_val_status := 'C';

      END;

	   END IF;

    gv_valid := null;

    -- Validate APAR code 
    IF ( gv_err_msg IS NULL ) THEN

      print_log ( 'Validating APARcode ' || p_aparcode );

      BEGIN

        SELECT 'Y'
          INTO gv_valid
          FROM dual
         WHERE p_aparcode IN ('C','V');

        print_log ( 'gv_valid: ' || gv_valid );

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          gv_err_msg := 'Invalid APARCode ' || p_aparcode;
          print_log ( 'Invalid APARCode ' || p_aparcode );
          gv_val_status := 'I';

      END;

    END IF;

    gv_valid := null;

    -- Validate finalize flag 
    IF ( gv_err_msg IS NULL ) THEN

      print_log ( 'Validating finalize ' || p_finalize );

      BEGIN

        SELECT 'Y'
          INTO gv_valid
          FROM dual
         WHERE p_finalize in ('Y','N');

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          gv_err_msg := 'Invalid Finalize flag ' || p_finalize;
          print_log ( 'Invalid Finalize flag ' || p_finalize );
          gv_val_status := 'I';
      END;

		 	  print_log ( 'gv_valid: ' || SQL%ROWCOUNT );

    END IF;

    gv_valid := null;

    -- Validate station id 
    IF ( gv_err_msg IS NULL ) THEN

      print_log ( 'Validating station ' || p_fk_stationid );

      BEGIN

        SELECT destination
          INTO gv_destination
          FROM ajcl_bc_csa_station_id
         WHERE bc_environment = gv_bc_environment
           AND station_id = p_fk_stationid;

        IF ( gv_destination IS NULL ) THEN

          gv_err_msg := 'No destination for station ' || p_fk_stationid;
          print_log ( 'Invalid - No destination for station ' || p_fk_stationid );
          gv_val_status := 'C';

        ELSE

          print_log ( 'Destination is ' || gv_destination );

        END IF;

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          gv_err_msg := 'Invalid Station id ' || p_fk_stationid;
          print_log ( 'Invalid Station id ' || p_fk_stationid );
          gv_val_status := 'C';

      END;

    END IF;

    gv_valid := null;

    -- Validate service id 
    IF ( p_fk_serviceid IS NOT NULL AND gv_err_msg IS NULL ) THEN

      print_log ( 'Validating service id ' || p_fk_serviceid );

      BEGIN

        SELECT 'Y'
          INTO gv_valid
          FROM ajcl_bc_ies_items
         WHERE bc_environment = gv_bc_environment
           AND charge_type_code = p_fk_serviceid
           AND business_line = '76'
           AND NVL(inactive_date, SYSDATE + 1) > SYSDATE;

      EXCEPTION
        WHEN NO_DATA_FOUND THEN
          gv_err_msg := 'Invalid Service id ' || p_fk_serviceid;
          print_log ( 'Invalid Service id ' || p_fk_serviceid );
          gv_val_status := 'C';

      END;

      print_log ( 'gv_valid: ' || gv_valid );

    END IF;

    -- Validate file number is not null 
    print_log ( 'Validating file no ' || p_fk_orderno );

    IF ( p_fk_orderno IS NULL AND gv_err_msg IS NULL ) THEN

      gv_err_msg := 'File number is null';
      print_log ( 'File number is null' );
      gv_val_status := 'I';

    END IF;

    -- Validate fk_seqno is not null */
    print_log ( 'Validating fk_seqno ' || p_fk_seqno );

    IF ( p_fk_seqno IS NULL AND gv_err_msg IS NULL ) THEN

      gv_err_msg := 'Fk_seqno is null';
      print_log ( 'Fk_seqno is null' );
      gv_val_status := 'I';

    END IF;

    -- Validate total for C records 
    IF ( p_aparcode = 'C' ) THEN

      print_log ( 'Validating total ' || p_total );

      IF ( p_total IS NULL AND gv_err_msg IS NULL ) THEN

        gv_err_msg := 'Total is null';
        print_log ( 'Total is null');
        gv_val_status := 'I';

      END IF;

    END IF;

    -- Validate invoiceamount for V records 
    IF ( p_aparcode = 'V' ) THEN

      print_log ( 'Validating invoiceamount ' || p_invoiceamount );

      IF ( p_invoiceamount IS NULL AND gv_err_msg IS NULL ) THEN

        gv_err_msg := 'InvoiceAmount is null';
        print_log ( 'InvoiceAmount is null' );
        gv_val_status := 'I';

      END IF;

    END IF;

    -- Validate housebill 
    print_log ( 'Validating housebill ' || p_housebill );

    IF ( p_housebill = 0 AND gv_err_msg IS NULL ) THEN

      gv_err_msg := 'Housebill is zero';
      print_log ( 'Housebill is zero' );
      gv_val_status := 'I';

    END IF;

    -- Validate fk_seqno 
    print_log ( 'Validating fk_seqno zero ' || p_fk_seqno );

    IF ( p_fk_seqno = 0 AND gv_err_msg IS NULL ) THEN

      gv_err_msg := 'FK_Seqno is zero';
      print_log ( 'FK_Seqno is zero');
      gv_val_status := 'I';

    END IF;

    print_log ('ajcl_bc_csa_pkg.validate_p (-)');  

  END validate_p;

  PROCEDURE get_last_inv ( p_housebill      IN   VARCHAR2,
                           p_fk_orderno     IN   NUMBER ) IS 
  BEGIN

    print_log ('ajcl_bc_csa_pkg.get_last_inv (+)');  
    print_log ('p_housebill: ' || p_housebill);
    print_log ('p_fk_orderno: ' || p_fk_orderno);

    SELECT MAX(entryno)
      INTO gv_ar_rev_ref_entryno
      FROM ajcl_bc_posted_sd_headers 
     WHERE bc_environment = gv_bc_environment
       AND invoicereference1 = p_housebill
       AND invoicereference2 = p_fk_orderno
       AND class = 'INV';

    IF ( gv_ar_rev_ref_entryno IS NOT NULL ) THEN

      gv_ar_match := 'BC';
      print_log ( 'gv_ar_rev_ref_entryno: ' || gv_ar_rev_ref_entryno);

    ELSE

      SELECT MAX(customer_trx_id)
        INTO gv_ar_reversal_ref_id
        FROM ra_customer_trx_all a
       WHERE attribute5 = p_housebill
         AND attribute6 = p_fk_orderno
         AND EXISTS ( SELECT 'x'
                        FROM ra_cust_trx_types_all
                       WHERE cust_trx_type_id = a.cust_trx_type_id
                         AND type = 'INV' );

      IF ( gv_ar_reversal_ref_id IS NULL ) THEN

        SELECT MAX(customer_trx_id)
          INTO gv_ar_reversal_ref_id
          FROM ra_customer_trx_all a
         WHERE attribute5 = p_housebill
           AND attribute6 = p_fk_orderno
           AND EXISTS ( SELECT 'x'
                          FROM ra_cust_trx_types_all
                         WHERE cust_trx_type_id = a.cust_trx_type_id
                           AND type = 'INV' );

        IF ( gv_ar_reversal_ref_id IS NOT NULL ) THEN

          gv_err_msg := 'No Match on StationID in printed reference';
          print_log ( 'Invalid - No Match on StationID in printed reference');
          gv_val_status := 'C';
          gv_ar_rev_ref_entryno := NULL;
          gv_ar_reversal_ref_id := NULL;

        END IF;

      END IF;

      gv_ar_match := 'ORACLE';
      print_log ( 'gv_ar_reversal_ref_id: ' || gv_ar_reversal_ref_id);

    END IF;

    print_log ('ajcl_bc_csa_pkg.get_last_inv (-)');  

  END get_last_inv;

  PROCEDURE get_worksheet_num ( p_housebill   IN   VARCHAR2 ) IS 
  BEGIN

    print_log ('ajcl_bc_csa_pkg.get_worksheet_num (+)');  

    IF ( gv_ar_rev_ref_entryno IS NOT NULL OR gv_ar_reversal_ref_id IS NOT NULL ) THEN

      IF ( gv_ar_rev_ref_entryno IS NOT NULL AND
           gv_ar_match = 'BC' ) THEN

        SELECT transactionno, 
               source
          INTO gv_ar_reversal_ref_name, 
               gv_reversal_source
          FROM ajcl_bc_posted_sd_headers
         WHERE bc_environment = gv_bc_environment
           AND entryno = gv_ar_rev_ref_entryno;         

      END IF;

      IF ( gv_ar_reversal_ref_id IS NOT NULL AND
           gv_ar_match = 'ORACLE' ) THEN 

        SELECT trx_number, 
               interface_header_context
          INTO gv_ar_reversal_ref_name, 
               gv_reversal_source
          FROM ra_customer_trx_all a
         WHERE customer_trx_id = gv_ar_reversal_ref_id;

      END IF;

      print_log ( 'AR reversal ref name ' || gv_ar_reversal_ref_name );
      print_log ( 'AR reversal source ' || gv_reversal_source );

      IF ( gv_ar_rev_ref_entryno IS NOT NULL AND
           gv_ar_match = 'BC' ) THEN

        SELECT DISTINCT worksheetno
          INTO gv_worksheet
          FROM ajcl_bc_posted_sd_headers 
         WHERE bc_environment = gv_bc_environment
           AND entryno = gv_ar_rev_ref_entryno;

      END IF;

      IF ( gv_ar_reversal_ref_id IS NOT NULL AND
           gv_ar_match = 'ORACLE' ) THEN 

        SELECT DISTINCT attribute1
          INTO gv_worksheet
          FROM ra_cust_trx_line_gl_dist_all
         WHERE customer_trx_id = gv_ar_reversal_ref_id;

      END IF;

      print_log ( 'Worksheet# from AR ' || gv_worksheet );

      IF ( gv_worksheet IS NULL ) THEN

        gv_worksheet := '70-' || TO_CHAR(p_housebill);

      END IF;

    ELSE

      gv_worksheet := '70-' || TO_CHAR(p_housebill);

    END IF;

    print_log ('ajcl_bc_csa_pkg.get_worksheet_num (-)');  

  END get_worksheet_num;

  PROCEDURE process_ar ( p_housebill      IN   VARCHAR2,
                         p_fk_orderno     IN   NUMBER,
                         p_aparcode       IN   VARCHAR2,
                         p_poddatetime    IN   DATE,
                         p_finalize       IN   VARCHAR2,
                         p_csa_file_no    IN   NUMBER ) IS 
  BEGIN

    print_log('ajcl_bc_csa_pkg.process_ar (+)');

    IF ( p_housebill != gv_prev_ar_housebill ) THEN 

      gv_prev_ar_housebill := p_housebill;

      UPDATE ajc_csa_valid_report
         SET ar_credit_memo_amount = NULL
       WHERE housebill = p_housebill
         AND csa_file_no = p_csa_file_no;

      COMMIT; 
		    -- print_log ( 'Record count: ' || SQL%ROWCOUNT);

    END IF;

    IF ( p_aparcode = 'C' AND p_finalize = 'Y' ) THEN

      print_log ( 'In APARCode = C' );

      gv_gl_rev_ref_entryno := '';
      gv_gl_reversal_ref_name := '';
      gv_gl_reversal_ref_id := '';

      print_log ( 'AR reversal ref id: ' || gv_ar_reversal_ref_id);

      IF ( gv_ar_rev_ref_entryno IS NOT NULL OR gv_ar_reversal_ref_id IS NOT NULL ) THEN

        -- Determine if there is an amount to be credited 
        IF ( gv_ar_rev_ref_entryno IS NOT NULL AND
             gv_ar_match = 'BC' ) THEN

          SELECT SUM(amount)
            INTO gv_ar_invoice_amt
            FROM ajcl_bc_posted_sd_headers
           WHERE bc_environment = gv_bc_environment
             AND entryno = gv_ar_rev_ref_entryno; 

        END IF;

        IF ( gv_ar_rev_ref_entryno IS NULL AND 
             gv_ar_reversal_ref_id IS NOT NULL AND
             gv_ar_match = 'ORACLE' ) THEN

          SELECT SUM(extended_amount)
            INTO gv_ar_invoice_amt
            FROM ra_customer_trx_lines_all
           WHERE customer_trx_id = gv_ar_reversal_ref_id;

        END IF;

        print_log ( 'AR invoice amount: ' || gv_ar_invoice_amt);

        BEGIN

          print_log ('line 999 - START - ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));
          print_log ('gv_ar_rev_ref_entryno: ' || gv_ar_rev_ref_entryno);
          print_log ('gv_ar_reversal_ref_id: ' || gv_ar_reversal_ref_id);
          print_log ('gv_ar_match: ' || gv_ar_match);

          IF ( gv_ar_rev_ref_entryno IS NOT NULL AND
               gv_ar_match = 'BC' ) THEN

            print_log ('BC START 1: ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));

            SELECT cm.amount
              INTO gv_ar_app_cm_amt
              FROM ajcl_bc_posted_sd_headers inv,
                   ajcl_bc_posted_sd_headers cm
             WHERE inv.bc_environment = gv_bc_environment
               AND inv.class = 'INV'
               AND inv.entryno = gv_ar_rev_ref_entryno
               AND cm.bc_environment = gv_bc_environment
               AND inv.appliestodocno = cm.transactionno
               AND cm.class = 'CM'
               AND inv.billtocustomerno = cm.billtocustomerno;

            print_log ('BC END 1: ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));

          END IF;

          IF ( gv_ar_rev_ref_entryno IS NULL AND 
               gv_ar_reversal_ref_id IS NOT NULL AND
               gv_ar_match = 'ORACLE' ) THEN

            print_log ('ORACLE START 1: ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));

            SELECT SUM(extended_amount)
              INTO gv_ar_app_cm_amt
              FROM ra_customer_trx_lines_all
             WHERE previous_customer_trx_id = gv_ar_reversal_ref_id;

            print_log ('ORACLE END 1: ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));

          END IF;

          print_log ('line 1032 - END - ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));

        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            print_log ( 'NO_DATA_FOUND: gv_ar_app_cm_amt := null - ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));
            gv_ar_app_cm_amt := null;

        END;

  
