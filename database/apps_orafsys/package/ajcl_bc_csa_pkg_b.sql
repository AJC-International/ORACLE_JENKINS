CREATE OR REPLACE PACKAGE BODY ajcl_bc_csa_pkg IS

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



        print_log ( 'CM applied to AR invoice: ' || gv_ar_app_cm_amt);



        BEGIN



          print_log ('line 1045 - START - ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));

          print_log ('gv_ar_rev_ref_entryno: ' || gv_ar_rev_ref_entryno);

          print_log ('gv_ar_reversal_ref_id: ' || gv_ar_reversal_ref_id);

          print_log ('gv_ar_match: ' || gv_ar_match);



          IF ( gv_ar_rev_ref_entryno IS NOT NULL AND

               gv_ar_match = 'BC' ) THEN



            print_log ('BC START 2: ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));



            SELECT inv.amount

              INTO gv_ar_manual_cm_amt

              FROM ajcl_bc_posted_sd_headers inv

             WHERE inv.bc_environment = gv_bc_environment

               AND ( inv.appliestodocno IS NULL OR inv.appliestodocno = ' ' )

               AND EXISTS ( SELECT 1

                              FROM ajcl_bc_posted_sd_headers cm

                             WHERE cm.entryno = inv.entryno

                               AND cm.bc_environment = gv_bc_environment

                               AND cm.invoicereference1 = p_housebill

                               AND cm.invoicereference2 = p_fk_orderno

                               AND cm.class = 'CM' );



            print_log ('BC END 2: ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));



          END IF;



          IF ( gv_ar_rev_ref_entryno IS NULL AND 

               gv_ar_reversal_ref_id IS NOT NULL AND

               gv_ar_match = 'ORACLE' ) THEN



            print_log ('ORACLE START 2: ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));



            SELECT SUM(extended_amount)

              INTO gv_ar_manual_cm_amt

              FROM ra_customer_trx_lines_all a

             WHERE previous_customer_trx_id IS NULL

               AND EXISTS ( SELECT 'x'

                              FROM ra_customer_trx_all b, 

                                   ra_cust_trx_types_all c

                             WHERE b.customer_trx_id = a.customer_trx_id

                               AND b.attribute5 = p_housebill

                               AND b.attribute6 = p_fk_orderno

                               AND b.cust_trx_type_id = c.cust_trx_type_id

                               AND c.type = 'CM' );



            print_log ('ORACLE END 2: ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));



          END IF;



          print_log ('line 1087 - END - ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));



        EXCEPTION

          WHEN NO_DATA_FOUND THEN

            print_log ( 'NO_DATA_FOUND: gv_ar_manual_cm_amt := null - ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));

            gv_ar_manual_cm_amt := null;



        END;



        print_log ( 'Manual CM amount: ' || gv_ar_manual_cm_amt );



        IF ( gv_ar_invoice_amt + nvl(gv_ar_app_cm_amt,0) + nvl(gv_ar_manual_cm_amt,0)) <= 0 THEN



          gv_ar_status := 'INV';



        ELSE



          gv_ar_status := 'CM';



        END IF;



        IF ( gv_ar_status = 'CM' ) THEN



          -- Update reporting table with CM amount 

          UPDATE ajc_csa_valid_report

             SET ar_credit_memo_amount = gv_ar_invoice_amt + nvl(gv_ar_app_cm_amt,0) + nvl(gv_ar_manual_cm_amt,0)

           WHERE housebill = TO_CHAR(p_housebill)

             AND csa_file_no = TO_CHAR(p_csa_file_no)

             AND ar_credit_memo_amount IS NULL;



          COMMIT; 



          -- print_log ( 'Record count: ' || SQL%ROWCOUNT);



          print_log ( 'Credit to be created for amount ' || (gv_ar_invoice_amt + nvl(gv_ar_app_cm_amt,0) + nvl(gv_ar_manual_cm_amt,0)) );



        END IF;



      ELSE



        gv_ar_status := 'INV';

        gv_reversal_source := '';

        gv_ar_reversal_ref_name := '';

        gv_ar_reversal_ref_id := '';



      END IF;



      print_log ( 'POD Date Time: ' || p_poddatetime );

      gv_in_date := p_poddatetime;



    END IF;



    print_log('ajcl_bc_csa_pkg.process_ar (-)');



  END process_ar;



  PROCEDURE process_gl ( p_housebill      IN   VARCHAR2,

                         p_aparcode       IN   VARCHAR2,

                         p_poddatetime    IN   DATE,

                         p_shipdatetime   IN   DATE ) IS 



  BEGIN



    print_log('ajcl_bc_csa_pkg.process_gl (+)');



    IF ( p_housebill != gv_prev_gl_housebill ) THEN 



      gv_prev_gl_housebill := p_housebill;



      UPDATE ajc_csa_valid_report

         SET cogs_rvrs_amount = null,

             in_transit_rvrs_amount = null

       WHERE housebill = p_housebill;



      COMMIT; 



		    -- print_log ( 'Record count: ' || SQL%ROWCOUNT);



    END IF;



    IF ( p_aparcode = 'V' AND TRUNC(p_shipdatetime) > TO_DATE('01-JAN-1900') ) THEN



      print_log ( 'In APARCode = V' );



      gv_reversal_source := '';

      gv_ar_reversal_ref_name := '';

      gv_ar_reversal_ref_id := '';



      BEGIN



        SELECT distinct 'x'

          INTO gv_fin_chrg_exists

          FROM ajc_csa_interfaceAPAR

         WHERE housebill = p_housebill

           AND aparcode = 'C'

           AND finalize = 'Y';



			     print_log ( 'gv_fin_chrg_exists: ' || gv_fin_chrg_exists);



        gv_gl_status := 'COGS';

        print_log ( 'POD Date Time ' || p_poddatetime );

        gv_in_date := p_poddatetime;



      EXCEPTION

        WHEN NO_DATA_FOUND THEN

          gv_gl_status := 'INTRANSIT';

          print_log ( 'Shipment Date Time ' || p_shipdatetime );

          gv_in_date := p_shipdatetime;



      END;



      gv_gl_match := NULL;

      print_log ( 'gv_gl_status: ' || gv_gl_status);



      -- Get the last unreversed JE if any; if any exists, set gl statuses to reversal 

      IF ( gv_gl_status = 'COGS' ) THEN



        -- Se busca en BC

        SELECT MAX(jnl.entryno)

          INTO gv_gl_rev_ref_entryno

          FROM ajcl_bc_gen_jnl_entries jnl          

         WHERE jnl.bc_environment = gv_bc_environment

           AND jnl.worksheetno = gv_worksheet

           -- 20241003

           -- AND ( ( jnl.userjesourcename = gv_ies_je_source ) OR ( jnl.userjesourcename = gv_csa_je_source AND jnl.userjecategoryname in (gv_gl_category_cogs_accrual,gv_gl_category_transit) ) )  

           AND ( ( jnl.userjesourcename = UPPER(gv_ies_je_source) ) OR ( jnl.userjesourcename = UPPER(gv_csa_je_source) AND jnl.userjecategoryname in ( UPPER(gv_gl_category_cogs_accrual), UPPER(gv_gl_category_transit) ) ) )

           -- 20241003

           AND NOT EXISTS ( SELECT 1

                              FROM ajcl_bc_gen_jnl_entries

                             WHERE bc_environment = gv_bc_environment

                               AND sourcecode = 'REVERSAL'

                               AND reversedentryno = jnl.entryno );



        IF ( gv_gl_rev_ref_entryno IS NOT NULL ) THEN



          print_log ( 'gv_gl_rev_ref_entryno: ' || gv_gl_rev_ref_entryno);

          gv_gl_match := 'BC';



        END IF;



        -- Si no se encuentra en BC

        IF ( gv_gl_rev_ref_entryno IS NULL ) THEN



          SELECT MAX(je_header_id)

            INTO gv_gl_reversal_ref_id

            FROM gl_je_lines a

           WHERE attribute11 = gv_worksheet 

             AND EXISTS ( SELECT 'x'

                            FROM gl_je_headers, 

                                 gl_je_sources_tl, 

                                 gl_je_categories_tl

                           WHERE je_header_id = a.je_header_id

                             AND je_source = je_source_name

                             AND je_category = je_category_name

                             AND ( ( user_je_source_name = gv_ies_je_source ) OR ( user_je_source_name = gv_csa_je_source AND user_je_category_name in (gv_gl_category_cogs_accrual,gv_gl_category_transit))) )

                             AND NOT EXISTS ( SELECT 'x'

                                                FROM gl_je_headers

                                               WHERE reversed_je_header_id = a.je_header_id ); 



          IF ( gv_gl_reversal_ref_id IS NOT NULL ) THEN



            gv_gl_match := 'ORACLE';

            print_log ( 'gv_gl_reversal_ref_id: ' || gv_gl_reversal_ref_id);



          END IF;



        END IF;



        print_log ( 'gv_gl_match: ' || gv_gl_match);



      END IF;



      IF ( gv_gl_status = 'INTRANSIT' ) THEN



        SELECT MAX(jnl.entryno)

          INTO gv_gl_rev_ref_entryno

          FROM ajcl_bc_gen_jnl_entries jnl

         WHERE jnl.bc_environment = gv_bc_environment

           AND jnl.worksheetno = gv_worksheet

           -- 20241003

           -- AND jnl.userjesourcename = gv_csa_je_source

           AND jnl.userjesourcename = UPPER(gv_csa_je_source)

           -- AND jnl.userjecategoryname = gv_gl_category_transit

           AND jnl.userjecategoryname = UPPER(gv_gl_category_transit)

           -- 20241003

           AND NOT EXISTS ( SELECT 1

                              FROM ajcl_bc_gen_jnl_entries

                             WHERE bc_environment = gv_bc_environment

                               AND sourcecode = 'REVERSAL'

                               AND reversedentryno = jnl.entryno );



        IF ( gv_gl_rev_ref_entryno IS NOT NULL ) THEN



          gv_gl_match := 'BC';

          print_log ( 'gv_gl_rev_ref_entryno: ' || gv_gl_rev_ref_entryno);



        END IF;



        IF ( gv_gl_rev_ref_entryno IS NULL ) THEN



          SELECT MAX(je_header_id)

            INTO gv_gl_reversal_ref_id

            FROM gl_je_lines a

           WHERE attribute11 = gv_worksheet 

             AND EXISTS ( SELECT 'x'

                            FROM gl_je_headers, gl_je_sources_tl, gl_je_categories_tl

                           WHERE je_header_id = a.je_header_id

                             AND je_source = je_source_name

                             AND user_je_source_name = gv_csa_je_source

                             AND je_category = je_category_name

                             AND user_je_category_name = gv_gl_category_transit )

             AND NOT EXISTS ( SELECT 'x'

                                FROM gl_je_headers

                               WHERE reversed_je_header_id = a.je_header_id ); 



          IF ( gv_gl_reversal_ref_id IS NOT NULL ) THEN



            gv_gl_match := 'ORACLE';

            print_log ( 'gv_gl_reversal_ref_id: ' || gv_gl_reversal_ref_id);



          END IF;



        END IF;



        print_log ( 'gv_gl_match: ' || gv_gl_match);



      END IF;



      IF ( gv_gl_rev_ref_entryno IS NOT NULL OR gv_gl_reversal_ref_id IS NOT NULL ) THEN



        IF ( gv_gl_status = 'COGS' ) THEN



          IF ( gv_err_msg = 'No PODDate for Billed Trx' ) THEN



            gv_gl_status := NULL;

            gv_gl_reversal_ref_name := NULL;

            gv_gl_reversal_ref_id := NULL;

            gv_gl_rev_ref_entryno := NULL;

            gv_in_date := NULL;



          ELSE



            gv_gl_status := 'COGS RVRS';



          END IF;



        END IF;



        IF ( gv_gl_status = 'INTRANSIT' ) THEN



          gv_gl_status := 'INTRANSIT RVRS';



        END IF;



        IF ( gv_gl_match = 'BC' AND gv_gl_rev_ref_entryno IS NOT NULL ) THEN



          SELECT documentno, 

                 userjecategoryname

            INTO gv_gl_reversal_ref_name, 

                 gv_je_category

            FROM ajcl_bc_gen_jnl_entries

           WHERE bc_environment = gv_bc_environment

             AND entryno = gv_gl_rev_ref_entryno;  



        END IF;



        IF ( gv_gl_match = 'ORACLE' AND gv_gl_reversal_ref_id IS NOT NULL ) THEN



          SELECT b.name, 

                 c.user_je_category_name

            INTO gv_gl_reversal_ref_name, 

                 gv_je_category

            FROM gl_je_headers a, 

                 gl_je_batches b, 

                 gl_je_categories_tl c

           WHERE a.je_header_id = gv_gl_reversal_ref_id

             AND b.je_batch_id = a.je_batch_id

             AND a.je_category = c.je_category_name;



        END IF;



        print_log ( 'GL reversal ref name: ' || gv_gl_reversal_ref_name );

        print_log ( 'GL reversal ref category: ' || gv_je_category );



        IF ( UPPER(gv_je_category) = UPPER(gv_gl_category_cogs_accrual) ) THEN



          gv_gl_status := 'COGS RVRS';



        END IF;



        IF ( UPPER(gv_je_category) = UPPER(gv_gl_category_transit) ) THEN



          IF ( gv_gl_status = 'COGS RVRS' ) THEN



            gv_gl_status := 'COGS,INTRANSIT RVRS';



          ELSE



            gv_gl_status := 'INTRANSIT RVRS';



          END IF;



        END IF;



        IF ( gv_gl_match = 'BC' AND gv_gl_rev_ref_entryno IS NOT NULL ) THEN



          SELECT -- 20241003 SUM(NVL(jnl.amount,0))

                 ABS(SUM(NVL(jnl.amount,0)))

            INTO gv_gl_rvrs_amt

            FROM ajcl_bc_gen_jnl_entries jnl

           WHERE jnl.bc_environment = gv_bc_environment

             -- 20241003

             AND worksheetno = gv_worksheet

             -- 20241003

             AND jnl.documentno = ( SELECT documentno

                                      FROM ajcl_bc_gen_jnl_entries

                                     WHERE bc_environment = gv_bc_environment

                                       AND entryno = gv_gl_rev_ref_entryno

                                       AND worksheetno = gv_worksheet )

             -- 20241003

             AND jnl.amount < 0;

             -- 20241003



        END IF;                                       



        IF ( gv_gl_match = 'ORACLE' AND gv_gl_reversal_ref_id IS NOT NULL ) THEN



          SELECT SUM(nvl(entered_dr,0))

            INTO gv_gl_rvrs_amt

            FROM gl_je_lines

           WHERE je_header_id = gv_gl_reversal_ref_id

             AND attribute11 = gv_worksheet;



        END IF;



        print_log ( 'Reversal amount: ' || gv_gl_rvrs_amt );



      ELSE



        gv_gl_reversal_ref_name := '';

        gv_gl_reversal_ref_id := '';



      END IF;



    END IF;



    print_log('ajcl_bc_csa_pkg.process_gl (-)');



  END process_gl;



  PROCEDURE upd_gl_none ( p_housebill   IN   VARCHAR2 ) IS 

  BEGIN



    print_log('ajcl_bc_csa_pkg.upd_gl_none (+)');



    SELECT 'NONE'

      INTO gv_gl_status

      FROM dual

     WHERE NOT EXISTS ( SELECT 'x'

                          FROM ajc_csa_interfaceAPAR

                         WHERE housebill = p_housebill

                           AND aparcode = 'V' );



    print_log ( 'gv_gl_status: ' || gv_gl_status);



    print_log('ajcl_bc_csa_pkg.upd_gl_none (-)');



  EXCEPTION

    WHEN NO_DATA_FOUND THEN

      print_log('ajcl_bc_csa_pkg.upd_gl_none (!)');



  END upd_gl_none;



  -- =========================================================

   -- Procedure get_gl_date

   -- Determine gl date

   -- =========================================================

  PROCEDURE get_gl_date IS

  BEGIN



    print_log('ajcl_bc_csa_pkg.get_gl_date (+)');



    -- Se verifica si la fecha a enviar cae dentro del periodo abierto

    IF ( TO_DATE(gv_in_date) BETWEEN gv_bc_start_date AND gv_bc_end_date ) THEN



      -- Si cae dentro del periodo, se enviara la fecha que viene en el archivo de CSA

      gv_out_date := TO_DATE(gv_in_date);



    ELSE



      -- Si no cae dentro del periodo, se envia el start_date de BC

      gv_out_date := gv_bc_start_date;



    END IF; 



    print_log ( 'Out date: ' || gv_out_date);    

    gv_gl_date := gv_out_date;



    print_log('ajcl_bc_csa_pkg.get_gl_date (-)');



  END get_gl_date;



  -- =========================================================

   -- Procedure get_trx_date

   -- Determine trx date for AR

   -- =========================================================

  PROCEDURE get_trx_date ( p_housebill   IN   VARCHAR2 ) IS 

  BEGIN



    print_log('ajcl_bc_csa_pkg.get_trx_date (+)');



    IF ( gv_ar_status IS NOT NULL ) THEN



      SELECT MAX(poddatetime)

        INTO gv_trx_date

        FROM ajc_csa_interfaceAPAR

       WHERE housebill = p_housebill;



      print_log ( 'gv_trx_date: ' || gv_trx_date);



    END IF;



    print_log('ajcl_bc_csa_pkg.get_trx_date (-)');



  END get_trx_date;



  PROCEDURE upd_rvrs_amt ( p_housebill      IN varchar2,

                           p_csa_file_no    IN number ) IS 

  BEGIN



    print_log('ajcl_bc_csa_pkg.upd_rvrs_amt (+)');



    UPDATE ajc_csa_valid_report

       SET cogs_rvrs_amount = DECODE(gv_gl_rvrs_amt,0, NULL, gv_gl_rvrs_amt)

     WHERE housebill = TO_CHAR(p_housebill)

       AND csa_file_no = TO_CHAR(p_csa_file_no)

       AND gv_gl_status = 'COGS RVRS'

       AND cogs_rvrs_amount IS NULL;



    COMMIT;



 	  -- print_log ( 'Record count: ' || SQL%ROWCOUNT);



    UPDATE ajc_csa_valid_report

       SET in_transit_rvrs_amount = DECODE(gv_gl_rvrs_amt,0, NULL, gv_gl_rvrs_amt)

     WHERE housebill = TO_CHAR(p_housebill)

       AND csa_file_no = TO_CHAR(p_csa_file_no)

       AND gv_gl_status like '%INTRANSIT RVRS%'

       AND in_transit_rvrs_amount IS NULL;



    COMMIT;



    -- print_log ( 'Record count: ' || SQL%ROWCOUNT);



    print_log('ajcl_bc_csa_pkg.upd_rvrs_amt (-)');



  END upd_rvrs_amt;



  PROCEDURE process_unproc_cogs IS



      CURSOR sel_unproc IS

      SELECT a.rowid val_rowid, 

             a.fk_cvno, 

             a.chargecode, 

             a.aparcode, 

             a.finalize,

             a.pk_seqno, 

             a.fk_seqno, 

             a.fk_stationid, 

             a.fk_serviceid, 

             a.shipmentdatetime, 

             a.poddatetime, 

             a.csa_file_no, 

             a.housebill, 

             a.createdate, 

             a.fk_orderno, 

             a.subaccount, 

             a.division, 

             a.total,

             a.invoiceamount, 

             a.validation_status

        FROM ajc_csa_interfaceAPAR a

       WHERE aparcode = 'V' 

         AND TRUNC(shipmentdatetime) > to_date('01-JAN-1900')

         AND ( validation_status IS NULL OR validation_status = 'S' )

         AND csa_file_no IN ( SELECT distinct csa_file_no

                                FROM ajc_csa_interfaceAPAR

                               WHERE validation_status IN ('Y','C')

                                 AND housebill = a.housebill

                                 AND pk_seqno >= gv_start_seq )

         AND pk_seqno < gv_start_seq 

         AND EXISTS ( SELECT 'x'

                        FROM ajc_csa_interfaceAPAR

                       WHERE validation_status IN ('Y','C')

                         AND housebill = a.housebill

                         AND csa_file_no = a.csa_file_no

                         AND pk_seqno >= gv_start_seq )

    ORDER BY a.csa_file_no, 

             a.housebill, 

             a.pk_seqno;



    v_assoc_rev_pod_null	varchar2(1);



  BEGIN



    print_log('ajcl_bc_csa_pkg.process_unproc_cogs (+)');



    FOR sel_unproc_rec IN sel_unproc LOOP



      print_log ( Localtimestamp||' - Processing unprocessed file#/housebill/fk_seqno/pk_seqno: ' || 

                  sel_unproc_rec.csa_file_no || '/' || 

                  sel_unproc_rec.housebill || '/' || 

                  sel_unproc_rec.fk_seqno || '/' || 

                  sel_unproc_rec.pk_seqno);



      print_log ( 'Finalize/PODDatetime/ShipmentDateTime: ' || 

                  sel_unproc_rec.finalize || '/' || 

                  sel_unproc_rec.poddatetime || '/' ||

                  sel_unproc_rec.shipmentdatetime);



      -- Initialize variables 

      init_vars;



      IF ( sel_unproc_rec.validation_status = 'S' ) THEN



        UPDATE ajc_csa_interfaceAPAR

           SET validation_status = NULL

         WHERE rowid = sel_unproc_rec.val_rowid;



        COMMIT;



			     -- print_log ( 'Record count: ' || SQL%ROWCOUNT);



      END IF;



      -- Validate data 

      validate_p ( p_aparcode => sel_unproc_rec.aparcode, 

                   p_finalize => sel_unproc_rec.finalize, 

                   p_poddatetime => sel_unproc_rec.poddatetime, 

                   p_fk_cvno => sel_unproc_rec.fk_cvno, 

                   p_chargecode => sel_unproc_rec.chargecode, 

                   p_fk_orderno => sel_unproc_rec.fk_orderno, 

                   p_fk_stationid => sel_unproc_rec.fk_stationid, 

                   p_fk_serviceid => sel_unproc_rec.fk_serviceid,

                   p_fk_seqno => sel_unproc_rec.fk_seqno, 

                   p_housebill => sel_unproc_rec.housebill, 

                   p_total => sel_unproc_rec.total, 

                   p_invoiceamount => sel_unproc_rec.invoiceamount );



      -- Find the last uncredited transaction in AR 

      get_last_inv ( sel_unproc_rec.housebill, sel_unproc_rec.fk_orderno );



      -- Determine the worksheet number 

      get_worksheet_num(sel_unproc_rec.housebill);

      print_log ( 'Worksheet: ' || gv_worksheet);



      -- Process for GL only */

      process_gl ( p_housebill => sel_unproc_rec.housebill, 

                   p_aparcode => sel_unproc_rec.aparcode, 

                   p_poddatetime => sel_unproc_rec.poddatetime, 

                   p_shipdatetime => sel_unproc_rec.shipmentdatetime );



      print_log ( 'Prelim GL Status: ' || gv_gl_status || ' | ' ||

                  'In date: ' || gv_in_date || ' | ' ||

                  'AR status: ' || gv_ar_status || ' | ' ||

                  'GL status: ' || gv_gl_status);



      -- Calculate gl date

      get_gl_date;

      print_log ( 'GL date: ' || gv_gl_date );



      -- Update reversal amounts in the reporting table 

      upd_rvrs_amt(sel_unproc_rec.housebill, sel_unproc_rec.csa_file_no);



      -- Determine validation status 

      IF ( gv_err_msg IS NULL AND gv_gl_status like '%COGS%' ) THEN



      		-- Determine if the the POD date is null on the associated revenue

        v_assoc_rev_pod_null := null;



        BEGIN



          SELECT 'Y'

            INTO v_assoc_rev_pod_null

            FROM ajc_csa_interfaceAPAR

           WHERE housebill = sel_unproc_rec.housebill

             AND csa_file_no = sel_unproc_rec.csa_file_no

             AND aparcode = 'C'

             AND finalize = 'Y'

             AND TRUNC(poddatetime) = TO_DATE('01-JAN-1900');



          print_log ( 'v_assoc_rev_pod_null: ' || v_assoc_rev_pod_null);



		      EXCEPTION

			       WHEN NO_DATA_FOUND THEN 

            NULL;

			       WHEN OTHERS THEN

            NULL;



        END;



		      IF ( v_assoc_rev_pod_null = 'Y' ) THEN



          gv_err_msg := 'No PODDate for Finalized Revenue';

          print_log ( 'No PODDate for Finalized Revenue' );

          gv_val_status := 'I';



        END IF;



      END IF;



      IF ( gv_err_msg IS NULL AND NVL(gv_val_status,'X') != 'S' ) THEN



        gv_val_status := 'Y';



      END IF;



      print_log ('Validation status: ' || gv_val_status );



      -- Update interface record 

      upd_interface ( p_val_status => gv_val_status, 

                      p_err_msg => gv_err_msg, 

                      p_worksheet => gv_worksheet, 

                      p_tot_cr => NULL, 

                      p_trx_date => gv_trx_date,

                      p_gl_date => gv_gl_date, 

                      p_ar_status => gv_ar_status, 

                      p_gl_status => gv_gl_status, 

                      p_rev_source => gv_reversal_source,

                      p_ar_ref_name => gv_ar_reversal_ref_name, 

                      p_gl_ref_name => gv_gl_reversal_ref_name,

                      p_ar_ref_entryno => gv_ar_rev_ref_entryno,

                      p_ar_ref_id => gv_ar_reversal_ref_id, 

                      p_gl_ref_entryno => gv_gl_rev_ref_entryno,

                      p_gl_ref_id => gv_gl_reversal_ref_id, 

                      p_last_upd_by => gv_user_id,

                      p_last_upd_date => SYSDATE, 

                      p_rowid => sel_unproc_rec.val_rowid );



    END LOOP;



    print_log('ajcl_bc_csa_pkg.process_unproc_cogs (-)');



  END process_unproc_cogs;



  -- =========================================================

   -- Procedure upd_null_gl_dates

   -- Update null gl dates as the max gl date from housebill. This applies

   -- to housebills where some records have a gl_date, but others are

   -- missing one.

   -- =========================================================

  PROCEDURE upd_null_gl_dates IS

  BEGIN



    print_log('ajcl_bc_csa_pkg.upd_null_gl_dates (+)');



    UPDATE ajc_csa_interfaceAPAR a

       SET gl_date = ( SELECT max(gl_date)

                         FROM ajc_csa_interfaceAPAR

                        WHERE gl_date IS NOT NULL

                          AND housebill = a.housebill

                          AND csa_file_no = a.csa_file_no )

     WHERE validation_status = 'Y'

       AND gl_date IS NULL

       AND ( nvl(gl_status,'X') in ('COGS','COGS RVRS','INTRANSIT','INTRANSIT RVRS','COGS,INTRANSIT RVRS') OR nvl(ar_status,'X') in ('INV','CM') );



    COMMIT;



	   -- print_log ( 'Record count: ' || SQL%ROWCOUNT);



    print_log('ajcl_bc_csa_pkg.upd_null_gl_dates (-)');



  END upd_null_gl_dates;



  -- =========================================================

   -- Procedure set_skipped

   -- Set status to skipped

   -- =========================================================

  PROCEDURE set_skipped IS

  BEGIN



    print_log('ajcl_bc_csa_pkg.set_skipped (+)');



    UPDATE ajc_csa_interfaceAPAR

       SET validation_status = 'S',

           last_updated_by = gv_user_id,

           last_update_date = SYSDATE

     WHERE validation_status IS NULL;



    COMMIT;



	   -- print_log ( 'Record count: ' || SQL%ROWCOUNT);



    print_log('ajcl_bc_csa_pkg.set_skipped (-)');



  END set_skipped;



  -- =========================================================

   -- Procedure set_uniform_status

   -- Set uniform statuses on processed records for housebills who have

   -- records with different statuses. The status for all records of a

   -- housebill is set to the lowest status. For instance, if a housebill has 

   -- some valid records and some incorrectable errors, this procedure sets 

   -- the status of all records of that housebill to Incorrectable.

   -- =========================================================

  PROCEDURE set_uniform_status IS



     CURSOR sel_upd IS

     SELECT DISTINCT housebill, 

            csa_file_no

       FROM ajc_csa_interfaceAPAR a

      WHERE NOT EXISTS ( SELECT 'x'

                           FROM ajc_csa_interfaceAPAR

                          WHERE csa_file_no = a.csa_file_no

                            AND housebill = a.housebill

                            AND ( NVL(ar_status,'X') = 'INTERFACED' OR NVL(gl_status,'X') = 'INTERFACED') )

        AND NVL(gl_status,'X') != 'INTERFACED'

        AND NVL(ar_status,'X') != 'INTERFACED'

        AND validation_status IN ('C','Y')

        AND housebill IN ( SELECT housebill

                             FROM ajc_csa_interfaceAPAR

                            WHERE csa_file_no = a.csa_file_no

                              AND nvl(validation_status,'X') != 'S'

                           HAVING COUNT(DISTINCT validation_status) > 1

                            GROUP BY housebill )

    ORDER BY 2, 1;



  BEGIN



    print_log('ajcl_bc_csa_pkg.set_uniform_status (+)');



    FOR sel_upd_rec IN sel_upd LOOP



      fnd_file.put_line (fnd_file.log,'Upd processing file#/housebill ' || sel_upd_rec.csa_file_no || '/' || sel_upd_rec.housebill);



      UPDATE ajc_csa_interfaceAPAR a

         SET ( validation_status, error_message ) = ( SELECT validation_status, error_message

                                                        FROM ajc_csa_interfaceAPAR

                                                       WHERE housebill = sel_upd_rec.housebill

                                                         AND csa_file_no = sel_upd_rec.csa_file_no

                                                         AND validation_status = 'C'

                                                         AND NVL(ar_status,'X') != 'INTERFACED'

                                                         AND NVL(gl_status,'X') != 'INTERFACED'

                                                         AND ROWNUM = 1),

             last_updated_by = gv_user_id,

             last_update_date = SYSDATE

       WHERE housebill = sel_upd_rec.housebill

         AND csa_file_no = sel_upd_rec.csa_file_no

         AND validation_status = 'Y'

         AND EXISTS ( SELECT 'x'

                        FROM ajc_csa_interfaceAPAR

                       WHERE housebill = sel_upd_rec.housebill

                         AND csa_file_no = sel_upd_rec.csa_file_no

                         AND validation_status = 'C'

                         AND NVL(ar_status,'X') != 'INTERFACED'

                         AND NVL(gl_status,'X') != 'INTERFACED');



		 	  -- print_log ( 'Record count: ' || SQL%ROWCOUNT);



      UPDATE ajc_csa_interfaceAPAR a

         SET ( validation_status, error_message ) = ( SELECT validation_status, error_message

                                                        FROM ajc_csa_interfaceAPAR

                                                       WHERE housebill = sel_upd_rec.housebill

                                                         AND csa_file_no = sel_upd_rec.csa_file_no

                                                         AND validation_status = 'I'

                                                         AND NVL(ar_status,'X') != 'INTERFACED'

                                                         AND NVL(gl_status,'X') != 'INTERFACED'

                                                         AND rownum = 1 ),

             last_updated_by = gv_user_id,

             last_update_date = SYSDATE

       WHERE housebill = sel_upd_rec.housebill

         AND csa_file_no = sel_upd_rec.csa_file_no

         AND validation_status in ('C','Y')

         AND EXISTS ( SELECT 'x'

                        FROM ajc_csa_interfaceAPAR

                       WHERE housebill = sel_upd_rec.housebill

                         AND csa_file_no = sel_upd_rec.csa_file_no

                         AND validation_status = 'I'

                         AND NVL(ar_status,'X') != 'INTERFACED'

                         AND NVL(gl_status,'X') != 'INTERFACED');



      COMMIT;



		 	  -- print_log ( 'Record count: ' || SQL%ROWCOUNT);



    END LOOP;



    print_log('ajcl_bc_csa_pkg.set_uniform_status (-)');



  END set_uniform_status;



  PROCEDURE reset_invalid_pod IS

  BEGIN



    print_log('ajcl_bc_csa_pkg.reset_invalid_pod (+)');



    UPDATE ajc_csa_interfaceAPAR

       SET gl_status = NULL,

           gl_reversal_entryno = NULL,

           gl_reversal_ref_id = NULL,

           gl_reversal_ref_name = NULL

     WHERE error_message = 'No PODDate for Billed Trx'

       AND NVL(gl_status,'X') != 'INTERFACED'

       AND NVL(ar_status,'X') != 'INTERFACED'

       AND gl_status like 'COGS%';



    COMMIT;



	   -- print_log ( 'Record count: ' || SQL%ROWCOUNT);



    print_log('ajcl_bc_csa_pkg.reset_invalid_pod (-)');



  END reset_invalid_pod;



  PROCEDURE upd_rep_table IS



      CURSOR sel_rep IS

      SELECT housebill, 

             rowid rep_rowid, 

             ar_credit_memo_amount, 

             csa_file_no

        FROM ajc_csa_valid_report

    ORDER BY 1;



  BEGIN



    print_log('ajcl_bc_csa_pkg.upd_rep_table (+)');



    DELETE FROM ajc_csa_valid_report

     WHERE housebill NOT IN ( SELECT DISTINCT housebill

                                FROM ajc_csa_interfaceAPAR a

                               WHERE ( (validation_status = 'C') OR ( validation_status = 'I' AND NOT EXISTS ( SELECT 'x' 

                                                                                                                 FROM ajc_csa_interfaceAPAR 

                                                                                                                WHERE csa_file_no = a.csa_file_no 

                                                                                                                  AND ( NVL(ar_status,'X') = 'INTERFACED' OR NVL(gl_status,'X') = 'INTERFACED') ) )

                                                                 OR ( validation_status = 'Y' AND ( NVL(ar_status,'X') != 'INTERFACED' OR NVL(gl_status,'X') != 'INTERFACED') ) ) );



    -- print_log ( 'Record count: ' || SQL%ROWCOUNT);



    FOR sel_rep_rec IN sel_rep LOOP



      print_log ( 'Rep processing file#/housebill ' || sel_rep_rec.csa_file_no || '/' || sel_rep_rec.housebill);



      UPDATE ajc_csa_valid_report

         SET ( validation_status, report_message ) = ( SELECT DECODE(validation_status,

                                                                     'I', 'Invalid',

                                                                     'C', 'Correctable',

                                                                     'Y', 'Valid',

                                                                     ''),

                                                              DECODE (validation_status,

                                                                      'I', error_message,

                                                                      'C', error_message,

                                                                      'Y', DECODE(gl_status,'NONE', 'Valid; No COGS','Valid'), '')

                                                         FROM ajc_csa_interfaceAPAR a

                                                        WHERE housebill = sel_rep_rec.housebill

                                                          AND csa_file_no = sel_rep_rec.csa_file_no

                                                          AND rownum = 1

                                                          AND ( (validation_status = 'C') OR ( validation_status = 'I' AND NOT EXISTS ( SELECT 'x' 

                                                                                                                                          FROM ajc_csa_interfaceAPAR 

                                                                                                                                         WHERE csa_file_no = a.csa_file_no 

                                                                                                                                           AND ( NVL(ar_status,'X') = 'INTERFACED' OR 

                                                                                                                                                 NVL(gl_status,'X') = 'INTERFACED') ) )

                                                                                          OR ( validation_status = 'Y' AND ( NVL(ar_status,'X') in ('INV','CM') OR NVL(gl_status,'X') in 

                                                                                          ('COGS', 'COGS RVRS', 'INTRANSIT', 'INTRANSIT RVRS','COGS,INTRANSIT RVRS') ) ) ) )

       WHERE  rowid = sel_rep_rec.rep_rowid;



      -- print_log ( 'Record count: ' || SQL%ROWCOUNT);



      UPDATE ajc_csa_valid_report a

         SET ar_invoice_amount = ( SELECT DECODE(sum(total), 0, null, sum(total))

                                     FROM ajc_csa_interfaceAPAR

                                    WHERE housebill = sel_rep_rec.housebill

                                      AND csa_file_no = sel_rep_rec.csa_file_no

                                      AND NVL(ar_status,'X') IN ('INV','CM')

                                      AND NVL(gl_status,'X') != 'INTERFACED'),

             cogs_amount = ( SELECT DECODE(sum(invoiceamount), 0, null, sum(invoiceamount))

                               FROM ajc_csa_interfaceAPAR

                              WHERE housebill = sel_rep_rec.housebill

                                AND csa_file_no = sel_rep_rec.csa_file_no

                                AND aparcode = 'V'

                                AND EXISTS ( SELECT 'x'

                                               FROM ajc_csa_interfaceAPAR

                                              WHERE housebill = sel_rep_rec.housebill

                                                AND csa_file_no = sel_rep_rec.csa_file_no

                                                AND NVL(gl_status,'X') in ('COGS','COGS RVRS','COGS,INTRANSIT RVRS')

                                                AND NVL(ar_status,'X') != 'INTERFACED')),

             cogs_rvrs_amount = ( SELECT DECODE(a.report_message,'No PODDate for Billed Trx', null,DECODE(a.cogs_rvrs_amount,0, null, a.cogs_rvrs_amount))

                                    FROM dual),

             in_transit_amount = ( SELECT DECODE(sum(invoiceamount), 0, null, sum(invoiceamount))

                                     FROM ajc_csa_interfaceAPAR

                                    WHERE housebill = sel_rep_rec.housebill

                                      AND csa_file_no = sel_rep_rec.csa_file_no

                                      AND aparcode = 'V'

                                      AND EXISTS ( SELECT 'x'

                                                     FROM ajc_csa_interfaceAPAR

                                                    WHERE housebill = sel_rep_rec.housebill

                                                      AND csa_file_no = sel_rep_rec.csa_file_no

                                                      AND NVL(gl_status,'X') in ('INTRANSIT','INTRANSIT RVRS')

                                                      AND NVL(ar_status,'X') != 'INTERFACED') )

       WHERE rowid = sel_rep_rec.rep_rowid;



     	-- print_log ( 'Record count: ' || SQL%ROWCOUNT);



      UPDATE ajc_csa_interfaceAPAR a

         SET total_credit_amount = sel_rep_rec.ar_credit_memo_amount

       WHERE housebill = sel_rep_rec.housebill

         AND csa_file_no = sel_rep_rec.csa_file_no

         AND ar_status = 'CM'

         AND ( ( validation_status = 'C' ) OR ( validation_status = 'I' AND NOT EXISTS ( SELECT 'x' 

                                                                                           FROM ajc_csa_interfaceAPAR 

                                                                                          WHERE csa_file_no = a.csa_file_no 

                                                                                            AND ( NVL(ar_status,'X') = 'INTERFACED' OR NVL(gl_status,'X') = 'INTERFACED' ) ) )

                                           OR ( validation_status = 'Y' AND ( NVL(ar_status,'X') != 'INTERFACED' OR NVL(gl_status,'X') != 'INTERFACED' ) ) );



		    -- print_log ( 'Record count: ' || SQL%ROWCOUNT);



    END LOOP;



    -- If gl_status is InTransit, PODDate exists, and status is valid, reset report message



    UPDATE ajc_csa_valid_report a

       SET report_message = 'Valid, PODDate exists'

     WHERE report_message = 'Valid'

       AND EXISTS ( SELECT 'x'

                      FROM ajc_csa_interfaceAPAR

                     WHERE housebill = a.housebill

                       AND csa_file_no = a.csa_file_no

                       AND gl_status = 'INTRANSIT'

                       AND validation_status = 'Y'

                       AND trunc(poddatetime) > TO_DATE('01-JAN-1900') );



    -- print_log ( 'Record count: ' || SQL%ROWCOUNT);



    COMMIT;



    print_log('ajcl_bc_csa_pkg.upd_rep_table (-)');



  END upd_rep_table;



  PROCEDURE stop_p ( p_status   OUT   VARCHAR2 ) IS



    v_stop            VARCHAR(1) := 'N';

    e_stop_exception  EXCEPTION;



  BEGIN



    print_log('ajcl_bc_csa_pkg.stop_p (+)');



    /*

    SELECT DISTINCT 'Y'

      INTO v_stop

      FROM ajc_csa_interfaceapar

     WHERE ( ( validation_status = 'C' ) OR ( validation_status = 'I' AND csa_file_no = ( SELECT MAX(csa_file_no) FROM ajc_csa_interfaceapar ) ) )

     UNION

    SELECT 'N'

      FROM dual

     WHERE 0 = ( SELECT COUNT(*) 

                   FROM ajc_csa_interfaceapar 

                  WHERE ( ( validation_status = 'C' ) OR ( validation_status = 'I' AND csa_file_no = ( SELECT MAX(csa_file_no) FROM ajc_csa_interfaceapar ) ) ) );

    */



    SELECT DECODE(COUNT(1),0,'N','Y')

      INTO v_stop

      FROM ajc_csa_interfaceapar

     WHERE ( ( validation_status = 'C' AND error_message NOT LIKE 'Invalid Customer%' ) OR -- 20240828 No se tienen en cuenta los correctable Invalid Customer

             ( validation_status = 'I' AND csa_file_no = ( SELECT MAX(csa_file_no) FROM ajc_csa_interfaceapar ) ) );



    IF ( v_stop = 'Y' AND gv_if_errors_stop = 'Y' ) THEN



      print_log('Errors found in validation, processing will stop.');

      RAISE e_stop_exception;



    END IF;



    p_status := 'S';



    print_log('ajcl_bc_csa_pkg.stop_p (-)');



  EXCEPTION

    WHEN e_stop_exception THEN

      p_status := 'E';

      print_log('ajcl_bc_csa_pkg.stop_p (!). Error found in validation, processing will stop.');

    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_csa_pkg.stop_p (!). Error: ' || SQLERRM );



  END stop_p;



  -- 20240828

  PROCEDURE generate_validate_output_p IS



      CURSOR c_report IS

      SELECT csa_file_no,

             housebill,

             validation_status,

             report_message,

             ar_invoice_amount invoice_amount,

             ar_credit_memo_amount credit_memo_amount,

             cogs_amount,

             cogs_rvrs_amount cogs_reversal_amount,

             in_transit_amount,

             in_transit_rvrs_amount in_transit_reversal_amount

        FROM ajc_csa_valid_report, 

             gl_sets_of_books b, 

             hr_organization_units c, 

             ra_cust_trx_types_all d, 

             ra_batch_sources_all e, 

             ra_batch_sources_all f

       WHERE b.set_of_books_id = gv_set_of_books_id

         AND c.organization_id = gv_org_id

         AND d.cust_trx_type_id = gv_default_csa_inv_type

         AND e.batch_source_id = gv_default_csa_batch_source

         AND f.batch_source_id = gv_default_ies_batch_source

       UNION 

      SELECT to_number(null) csa_file_no,

             to_number(null) housebill,

             'No Data Found' validation_status,

             NULL report_message,

             to_number(null) invoice_amount,

             to_number(null) credit_memo_amount,

             to_number(null) cogs_amount,

             to_number(null) cogs_reversal_amount,

             to_number(null) in_transit_amount,

             to_number(null) in_transit_reversal_amount

        FROM gl_sets_of_books b, 

             hr_organization_units c,

             ra_cust_trx_types_all d, 

             ra_batch_sources_all e, 

             ra_batch_sources_all f

       WHERE b.set_of_books_id = gv_set_of_books_id

         AND c.organization_id = gv_org_id

         AND d.cust_trx_type_id = gv_default_csa_inv_type

         AND e.batch_source_id = gv_default_csa_batch_source

         AND f.batch_source_id = gv_default_ies_batch_source

         AND NOT EXISTS ( SELECT 'x' 

                            FROM ajc_csa_valid_report )

    ORDER BY 1,2;



      CURSOR c_report_total IS

      SELECT csa_file_no,

             validation_status,

             SUM(ar_invoice_amount) invoice_amount,

             SUM(ar_credit_memo_amount) credit_memo_amount,

             SUM(cogs_amount) cogs_amount,

             SUM(cogs_rvrs_amount) cogs_reversal_amount,

             SUM(in_transit_amount) in_transit_amount,

             SUM(in_transit_rvrs_amount) in_transit_reversal_amount

        FROM ajc_csa_valid_report, 

             gl_sets_of_books b, 

             hr_organization_units c, 

             ra_cust_trx_types_all d, 

             ra_batch_sources_all e, 

             ra_batch_sources_all f

       WHERE b.set_of_books_id = gv_set_of_books_id

         AND c.organization_id = gv_org_id

         AND d.cust_trx_type_id = gv_default_csa_inv_type

         AND e.batch_source_id = gv_default_csa_batch_source

         AND f.batch_source_id = gv_default_ies_batch_source

    GROUP BY csa_file_no,

             validation_status

       UNION 

      SELECT to_number(null) csa_file_no,

             'No Data Found' validation_status,

             to_number(null) invoice_amount,

             to_number(null) credit_memo_amount,

             to_number(null) cogs_amount,

             to_number(null) cogs_reversal_amount,

             to_number(null) in_transit_amount,

             to_number(null) in_transit_reversal_amount

        FROM gl_sets_of_books b, 

             hr_organization_units c,

             ra_cust_trx_types_all d, 

             ra_batch_sources_all e, 

             ra_batch_sources_all f

       WHERE b.set_of_books_id = gv_set_of_books_id

         AND c.organization_id = gv_org_id

         AND d.cust_trx_type_id = gv_default_csa_inv_type

         AND e.batch_source_id = gv_default_csa_batch_source

         AND f.batch_source_id = gv_default_ies_batch_source

         AND NOT EXISTS ( SELECT 'x' 

                            FROM ajc_csa_valid_report )

    ORDER BY 1,2;



  BEGIN



    print_log('ajcl_bc_csa_pkg.generate_validate_output_p (+)');



    IF ( gv_file_format = 'XLSX' ) THEN 



      -- Detail

      -- Column Names

      print_output_xlsx ( p_section => 'Detail',

                          p_column1 => 'CSA Extract File Number',

                          p_column2 => 'Housebill',

                          p_column3 => 'Validation Status',

                          p_column4 => 'Error Message',

                          p_column5 => 'Invoice Amount',

                          p_column6 => 'Credit Memo Amount',

                          p_column7 => 'COGS Amount',

                          p_column8 => 'COGS Reversal Amount',

                          p_column9 => 'InTransit Amount',

                          p_column10 => 'InTransit Reversal Amount' ); 



      FOR crpt IN c_report LOOP



        print_output_xlsx ( p_section => 'Detail',

                            p_column1 => crpt.csa_file_no,

                            p_column2 => crpt.housebill,

                            p_column3 => crpt.validation_status,

                            p_column4 => crpt.report_message,

                            p_column5 => crpt.invoice_amount,

                            p_column6 => crpt.credit_memo_amount,

                            p_column7 => crpt.cogs_amount,      

                            p_column8 => crpt.cogs_reversal_amount,

                            p_column9 => crpt.in_transit_amount,

                            p_column10 => crpt.in_transit_reversal_amount );



      END LOOP;



      -- Total

      -- Column Names

      print_output_xlsx ( p_section => 'Summary',

                          p_column1 => 'CSA Extract File Number',

                          p_column2 => 'Validation Status - Error Msg',

                          p_column3 => 'Invoice Amount',

                          p_column4 => 'Credit Memo Amount',

                          p_column5 => 'COGS Amount',

                          p_column6 => 'COGS Reversal Amount',

                          p_column7 => 'InTransit Amount',

                          p_column8 => 'InTransit Reversal Amount' ); 



      FOR crptt IN c_report_total LOOP



        print_output_xlsx ( p_section => 'Summary',

                            p_column1 => crptt.csa_file_no,

                            p_column2 => crptt.validation_status,

                            p_column3 => crptt.invoice_amount,

                            p_column4 => crptt.credit_memo_amount,

                            p_column5 => crptt.cogs_amount,      

                            p_column6 => crptt.cogs_reversal_amount,

                            p_column7 => crptt.in_transit_amount,

                            p_column8 => crptt.in_transit_reversal_amount );



      END LOOP;



    END IF;



    print_log('ajcl_bc_csa_pkg.generate_validate_output_p (-)');



  END generate_validate_output_p; 



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



    print_log( 'ajcl_bc_csa_pkg.final_output_xlsx_p (+)' );



    gv_directory_output := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_OUTPUT' );



    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc || ' Output',

                                                p_request_id => gv_request_id,

                                                p_bc_environment => gv_bc_environment,

                                                p_jenkins_build_number => gv_jenkins_build_number,

                                                --

                                                p_param_1_title => ' ',

                                                p_param_1_value => ' ',

                                                p_param_2_title => 'GL Set of Books', 

                                                p_param_2_value => 'LOGISTICS',                                                

                                                p_param_3_title => 'Org', 

                                                p_param_3_value => 'LOGISTICS OP UNIT',

                                                p_param_4_title => 'If Errors, Stop Processing', 

                                                p_param_4_value => gv_if_errors_stop,

                                                p_param_5_title => 'Default CSA JE Source', 

                                                p_param_5_value => gv_csa_je_source,

                                                p_param_6_title => 'IES JE Source', 

                                                p_param_6_value => gv_ies_je_source,

                                                p_param_7_title => 'Default COGS Accrual JE Category', 

                                                p_param_7_value => gv_gl_category_cogs_accrual,

                                                p_param_8_title => 'Default COGS Reversal JE Category', 

                                                p_param_8_value => gv_gl_cat_cogs_accrual_rev,

                                                p_param_9_title => 'Default In Transit JE Category', 

                                                p_param_9_value => gv_gl_category_transit,

                                                p_param_10_title => 'Default In Transit Reversal JE Category',

                                                p_param_10_value => gv_gl_category_transit_rev,

                                                p_param_11_title => 'Default Subaccount', 

                                                p_param_11_value => gv_default_subaccount,

                                                p_param_12_title => 'Default Division', 

                                                p_param_12_value => gv_default_division,

                                                p_param_13_title => 'Default CSA Invoice Type', 

                                                p_param_13_value => 'CSA INVOICE',

                                                p_param_14_title => 'Default CSA Batch Source', 

                                                p_param_14_value => 'CSA IMPORT',

                                                p_param_15_title => 'Default IES Batch Source', 

                                                p_param_15_value => 'IES IMPORT' );



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



    print_log( 'ajcl_bc_csa_pkg.final_output_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_csa_pkg.final_output_xlsx_p (!). Error: ' || SQLERRM );



  END final_output_xlsx_p;



  -- 20240828



  PROCEDURE validate_preprocess_p ( p_status      OUT   VARCHAR2,

                                    p_error_msg   OUT   VARCHAR2 ) IS



      CURSOR sel_val ( p_start_seq   NUMBER ) IS

      SELECT a.rowid val_rowid, 

             a.fk_cvno, 

             a.chargecode, 

             a.aparcode, 

             a.finalize, 

             a.pk_seqno, 

             a.fk_seqno, 

             a.fk_stationid, 

             a.fk_serviceid, 

             a.shipmentdatetime, 

             a.poddatetime, 

             a.csa_file_no, 

             a.housebill, 

             a.createdate, 

             a.fk_orderno, 

             a.subaccount, 

             a.division, 

             a.total, 

             a.validation_status, 

             a.invoiceamount

        FROM ajc_csa_interfaceAPAR a

       WHERE ( ( aparcode = 'V' AND TRUNC(shipmentdatetime) > TO_DATE('01-JAN-1900') ) OR ( aparcode = 'C' ) )

         AND ( ( validation_status = 'C' ) OR ( validation_status IS NULL AND pk_seqno >= p_start_seq ) )

    ORDER BY a.csa_file_no, 

             a.housebill, 

             a.pk_seqno;



    v_record_count   NUMBER := 0;

    v_status         VARCHAR2(1);

    e_stop           EXCEPTION;

    e_output         EXCEPTION;



  BEGIN



    print_log('ajcl_bc_csa_pkg.validate_preprocess_p (+)');



    -- Determine starting sequence for processing 

    get_start_seq;



    -- Determine if there are records to process

    get_proc_count;



    IF ( gv_count = 0 ) THEN



      print_log( 'No new records to validate. ');



    ELSE



      -- Insert starting pk_seqno into the control table 

      insert_control_rec;



      DELETE 

        FROM ajc_csa_valid_report a

       WHERE NOT EXISTS ( SELECT 'x'

                            FROM ajc_csa_interfaceAPAR

                           WHERE validation_status = 'Y'

                             AND csa_file_no = a.csa_file_no

                             AND housebill = a.housebill

                             AND ( ar_status IN ('INV','CM') OR gl_status in ('COGS','COGS RVRS','COGS,INTRANSIT RVRS','INTRANSIT','INTRANSIT RVRS') )

                           UNION

                          SELECT 'x'

                            FROM ajc_csa_interfaceAPAR

                           WHERE validation_status = 'I' 

                             AND NOT EXISTS ( SELECT 'x' 

                                                FROM ajc_csa_interfaceAPAR 

                                               WHERE csa_file_no = a.csa_file_no 

                                                 AND housebill = a.housebill

                                                 AND ( NVL(ar_status,'X') = 'INTERFACED' OR NVL(gl_status,'X') = 'INTERFACED') ) );





      print_log ( 'Record deleted count: ' || SQL%ROWCOUNT );



      FOR sel_val_rec IN sel_val ( gv_start_seq ) LOOP



        gv_ar_match := NULL;



        print_log ( SYSTIMESTAMP || '- Processing file#/housebill/fk_seqno/pk_seqno: ' ||

                    sel_val_rec.csa_file_no || '/' || 

                    sel_val_rec.housebill || '/' || 

                    sel_val_rec.fk_seqno || '/' || 

                    sel_val_rec.pk_seqno );



        print_log ( 'Finalize/PODDatetime/ShipmentDateTime: ' ||

                     sel_val_rec.finalize || '/' || 

                     sel_val_rec.poddatetime || '/' ||

                     sel_val_rec.shipmentdatetime);



        -- Initialize variables 

        init_vars;



        -- Insert housebill in the reporting table if not already there 

        insert_rep_table ( sel_val_rec.housebill, sel_val_rec.csa_file_no );



        -- Reset status on correctable error records 

        IF ( sel_val_rec.validation_status = 'C' ) THEN



          upd_interface ( p_val_status => NULL, 

                          p_err_msg => NULL, 

                          p_worksheet => NULL, 

                          p_tot_cr => NULL, 

                          p_trx_date => NULL, 

                          p_gl_date => NULL, 

                          p_ar_status => NULL, 

                          p_gl_status => NULL, 

                          p_rev_source => NULL,

                          p_ar_ref_name => NULL, 

                          p_gl_ref_name => NULL, 

                          p_ar_ref_entryno => NULL, 

                          p_ar_ref_id => NULL, 

                          p_gl_ref_entryno => NULL, 

                          p_gl_ref_id => NULL,

                          p_last_upd_by => gv_user_id, 

                          p_last_upd_date => SYSDATE, 

                          p_rowid => sel_val_rec.val_rowid );



		        -- print_log ( 'Record count: ' || SQL%ROWCOUNT );



        END IF;



        -- Validate data 

        validate_p ( p_aparcode => sel_val_rec.aparcode, 

                     p_finalize => sel_val_rec.finalize, 

                     p_poddatetime => sel_val_rec.poddatetime, 

                     p_fk_cvno => sel_val_rec.fk_cvno, 

                     p_chargecode => sel_val_rec.chargecode, 

                     p_fk_orderno => sel_val_rec.fk_orderno, 

                     p_fk_stationid => sel_val_rec.fk_stationid, 

                     p_fk_serviceid => sel_val_rec.fk_serviceid,

                     p_fk_seqno => sel_val_rec.fk_seqno, 

                     p_housebill => sel_val_rec.housebill, 

                     p_total => sel_val_rec.total, 

                     p_invoiceamount => sel_val_rec.invoiceamount );



        -- Find the last uncredited transaction in AR 

        get_last_inv ( sel_val_rec.housebill, sel_val_rec.fk_orderno );



        -- Determine the worksheet number 

        get_worksheet_num ( sel_val_rec.housebill );

        print_log ( 'Worksheet ' || gv_worksheet );



        -- If final charges report potential AR transactions 

        process_ar ( p_housebill => sel_val_rec.housebill, 

                     p_fk_orderno => sel_val_rec.fk_orderno, 

                     p_aparcode => sel_val_rec.aparcode, 

                     p_poddatetime => sel_val_rec.poddatetime, 

                     p_finalize => sel_val_rec.finalize, 

                     p_csa_file_no => sel_val_rec.csa_file_no );



        -- If costs and valid shipment date/time, create GL transactions

        -- If finalized charges exist, create COGS transactions 

        -- If finalized charges don't exist, create In Transit transactions 

        process_gl ( p_housebill => sel_val_rec.housebill, 

                     p_aparcode => sel_val_rec.aparcode, 

                     p_poddatetime => sel_val_rec.poddatetime, 

                     p_shipdatetime => sel_val_rec.shipmentdatetime );



        print_log ( 'Prelim GL Status: ' || gv_gl_status );



        IF ( sel_val_rec.aparcode = 'C' ) THEN



          upd_gl_none ( sel_val_rec.housebill );



        END IF;



        print_log ( 'In date: ' || gv_in_date );

        print_log ( 'AR status: ' || gv_ar_status );

        print_log ( 'GL status: ' || gv_gl_status );



        -- Calculate gl date 

        get_gl_date;

        print_log ( 'GL date: ' || gv_gl_date );



        -- Determine trx date 

        get_trx_date ( sel_val_rec.housebill );

        print_log ( 'Trx date: ' || gv_trx_date );



        -- Update reversal amounts in the reporting table 

        upd_rvrs_amt(sel_val_rec.housebill, sel_val_rec.csa_file_no);



        IF ( gv_err_msg IS NULL AND gv_gl_status LIKE '%COGS%' ) THEN 



          -- Determine if the the POD date is null on the associated revenue

		        gv_assoc_rev_pod_null := null;



          BEGIN



            SELECT 'Y'

              INTO gv_assoc_rev_pod_null

              FROM ajc_csa_interfaceAPAR

             WHERE housebill = sel_val_rec.housebill

               AND csa_file_no = sel_val_rec.csa_file_no

               AND aparcode = 'C'

               AND finalize = 'Y'

               AND TRUNC(poddatetime) = TO_DATE('01-JAN-1900');



          EXCEPTION

            WHEN NO_DATA_FOUND THEN

              NULL;

            WHEN OTHERS THEN

              NULL;



          END;



			       print_log ( 'gv_assoc_rev_pod_null: ' || gv_assoc_rev_pod_null );



          IF ( gv_assoc_rev_pod_null = 'Y' ) THEN



            gv_err_msg := 'No PODDate for Finalized Revenue';

            print_log ( 'No PODDate for Finalized Revenue' );

            gv_val_status := 'I';



          END IF;



        END IF;



        IF ( gv_err_msg IS NULL AND NVL(gv_val_status,'X') != 'S' ) THEN



          gv_val_status := 'Y';



        END IF;



        print_log ( 'Validation status: '|| gv_val_status );



        -- Update interface record 

        upd_interface ( p_val_status => gv_val_status, 

                        p_err_msg => gv_err_msg, 

                        p_worksheet => gv_worksheet, 

                        p_tot_cr => NULL, 

                        p_trx_date => gv_trx_date,

                        p_gl_date => gv_gl_date, 

                        p_ar_status => gv_ar_status, 

                        p_gl_status => gv_gl_status, 

                        p_rev_source => gv_reversal_source,

                        p_ar_ref_name => gv_ar_reversal_ref_name, 

                        p_gl_ref_name => gv_gl_reversal_ref_name,

                        p_ar_ref_entryno => gv_ar_rev_ref_entryno,

                        p_ar_ref_id => gv_ar_reversal_ref_id, 

                        p_gl_ref_entryno => gv_gl_rev_ref_entryno, 

                        p_gl_ref_id => gv_gl_reversal_ref_id, 

                        p_last_upd_by => gv_user_id,

                        p_last_upd_date => SYSDATE, 

                        p_rowid => sel_val_rec.val_rowid );



      END LOOP;



    END IF;



    -- Check unprocessed records for COGS 

    print_log ( '- Checking unprocessed records for COGS' );



    process_unproc_cogs;



    -- Update null gl dates 

    upd_null_gl_dates;



    -- Update skipped records 

    set_skipped;



    -- Update records to uniform statuses 

    set_uniform_status;



    -- Reset GL status on invalid POD Datetime records 

    reset_invalid_pod;



    -- Clean up and update the reporting table 

    upd_rep_table;



    -- 20240828

    generate_validate_output_p;



    IF ( gv_file_format = 'XLSX' ) THEN 



      final_output_xlsx_p ( p_status => v_status );



      IF ( v_status != 'S' ) THEN



        RAISE e_output;



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

    -- 20240828



    -- Stop if errors found and p_if_errors_stop = 'Y'

    stop_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      RAISE e_stop;



    END IF;



    p_status := 'S';



    print_log('ajcl_bc_csa_pkg.validate_preprocess_p (-)');



  EXCEPTION

    WHEN e_stop THEN

      p_status := 'E';

      p_error_msg := 'Stop due to validations.';

      print_log('ajcl_bc_csa_pkg.validate_preprocess_p (!). Error: stop due to validations.');

    WHEN e_output THEN

      p_status := 'E';

      p_error_msg := 'Output error.';

      print_log('ajcl_bc_csa_pkg.validate_preprocess_p (!). Output error.');

    WHEN OTHERS THEN

      p_status := 'E';

      p_error_msg := SQLERRM;

      print_log('ajcl_bc_csa_pkg.validate_preprocess_p (!). Error: ' || SQLERRM);



  END validate_preprocess_p;



  PROCEDURE find_oracle_customer_p ( csa_cust_in              IN   NUMBER,

                                     ora_cust_id_out         OUT   NUMBER,

                                     ora_cust_name_out       OUT   VARCHAR2,

                                     ora_cust_number_out     OUT   VARCHAR2,

                                     ora_addr_id_out         OUT   NUMBER,

                                     ora_bill_to_addr1_out   OUT   VARCHAR2, 

                                     ora_bill_to_addr2_out   OUT   VARCHAR2,

                                     ora_bill_to_addr3_out   OUT   VARCHAR2 ) IS



    oracle_addr_id_v        NUMBER;



    Customer_Not_Found      EXCEPTION;

    Multi_Customers_Found   EXCEPTION;



  BEGIN



    print_log('ajcl_bc_csa_pkg.find_oracle_customer_p (+)');



    ora_cust_id_out := NULL;

    ora_cust_name_out := NULL;

    ora_cust_number_out := NULL;



    -- Find the Oracle customer

    BEGIN



      SELECT oracle_cust_id

        INTO ora_cust_id_out

        -- FROM ajc_bplus_cust_xref

        FROM ajcl_bc_cust_xref

       WHERE bc_environment = gv_bc_environment

         AND source = 'CSA'

         AND source_type = 'CUSTOMER'

         AND bp_cust_id = csa_cust_in;



      -- SBanchieri

      -- Se comenta porque puede no coincidir el party_name con el customer_name, y hace que BC lo devuelva REJECTED

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

      -- SBanchieri



    EXCEPTION

      WHEN NO_DATA_FOUND THEN

        RAISE Customer_Not_Found;

      WHEN TOO_MANY_ROWS THEN

        RAISE Multi_Customers_Found;

      WHEN OTHERS THEN

        RAISE Customer_Not_Found;



    END;



    print_log ( 'Oracle Customer ID from Cust XREF table: ' || ora_cust_id_out );

    print_log ( 'Oracle Customer Name: ' || ora_cust_name_out );

    print_log ( 'Oracle Customer Number: ' || ora_cust_number_out );



    -- Find the bill to site for the customer

    ora_addr_id_out := NULL;

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



    IF ( oracle_addr_id_v IS NULL ) THEN



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

           AND cas.status= 'A'

           AND cas.cust_account_id = ora_cust_id_out;



      EXCEPTION

        WHEN OTHERS THEN

          NULL;



      END;



    END IF; -- oracle_addr_id_v is null



    -- 20231003

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

    -- 20231003



    print_log ( 'Oracle Address ID: ' || ora_addr_id_out || '|' ||

                'Oracle Address 1: ' || ora_bill_to_addr1_out || '|' ||

                'Oracle Address 2: ' || ora_bill_to_addr2_out || '|' ||

                'Oracle Address 3: ' || ora_bill_to_addr3_out );



    print_log('ajcl_bc_csa_pkg.find_oracle_customer_p (-)');



  EXCEPTION

    WHEN CUSTOMER_NOT_FOUND THEN

      print_log('ajcl_bc_csa_pkg.find_oracle_customer_p (!)');

      ora_cust_id_out := NULL;

      ora_addr_id_out := NULL;



    WHEN MULTI_CUSTOMERS_FOUND THEN

      print_log('ajcl_bc_csa_pkg.find_oracle_customer_p (!)');

      ora_cust_id_out := NULL; 

      ora_addr_id_out := NULL;



  END find_oracle_customer_p;



  PROCEDURE create_credit_memo_from_trx_p ( p_entryno_in	              IN   NUMBER,

                                            p_inv_id_in		              IN   NUMBER,

                                            p_trx_date_in		            IN   DATE,

                                            p_gl_date_in             		IN   DATE,

                                            p_reversal_source_in	      IN   VARCHAR2,

                                            p_total_credit_amount_in   IN   NUMBER,

                                            p_csa_file_no_in		         IN   NUMBER,

                                            --

                                            p_csa_batch_source_name    IN   VARCHAR2,

                                            p_csa_cm_trx_type_name     IN   VARCHAR2,

                                            p_ies_batch_source_name    IN   VARCHAR2 ) IS



    inv_trx_dff_seq_no_v	   NUMBER;

    batch_source_name_v	    ra_interface_lines.batch_source_name%TYPE;

    context_v		             ra_interface_lines.interface_line_context%TYPE;

    cm_trx_type_name_v	     ra_interface_lines.cust_trx_type_name%TYPE;

    trx_date_v		            DATE;

    percent_to_apply_v	     NUMBER(30,9);

    distr_seg1_v		          gl_code_combinations.segment1%TYPE;

    distr_seg2_v		          gl_code_combinations.segment2%TYPE;

    distr_seg3_v		          gl_code_combinations.segment3%TYPE;

    distr_seg4_v		          gl_code_combinations.segment4%TYPE;

    distr_seg5_v		          gl_code_combinations.segment5%TYPE;

    distr_seg6_v		          gl_code_combinations.segment6%TYPE;

    distr_seg7_v		          gl_code_combinations.segment7%TYPE;

    distr_rec_seg1_v		      gl_code_combinations.segment1%TYPE;

    distr_rec_seg2_v		      gl_code_combinations.segment2%TYPE;

    distr_rec_seg3_v		      gl_code_combinations.segment3%TYPE;

    distr_rec_seg4_v		      gl_code_combinations.segment4%TYPE;

    distr_rec_seg5_v		      gl_code_combinations.segment5%TYPE;

    distr_rec_seg6_v		      gl_code_combinations.segment6%TYPE;

    distr_rec_seg7_v		      gl_code_combinations.segment7%TYPE;

    distr_worksheet_num_v	  gl_code_combinations.attribute1%TYPE;

    REC_distr_created_v 	   VARCHAR2(1);

    orig_inv_amt_v		        NUMBER;

    line_cnt_v		            NUMBER;

    num_lines_v		           NUMBER;

    lines_total_v		         NUMBER(15,2);

    line_amt_v	 	           NUMBER(15,2);	



    CURSOR c_select_line IS

    -- BC

    SELECT c.customer_id billtocustomerid,

           sdh.billtocustomername,

           sdh.billtocustomerno,

           sdh.transactionno || '-CM' transactionno,

           sdh.billtoaddress billtoaddress1,

           sdh.billtoaddress2,

           sdh.billtoaddress3,

           sdh.termname,

           sdh.duedate,

           sdh.currencycode invoicecurrencycode,

           sdh.csahousebill, -- interface_line_attribute1

           sdh.csamaxpkseqno, -- interface_line_attribute2

           sdh.csacustomervendorno, -- interface_line_attribute3

           sdh.csafileextractnumber, -- interface_line_attribute12

           DECODE(p_reversal_source_in,'CSA',TO_CHAR(inv_trx_dff_seq_no_v),sdh.csamaxpkseqno) csaseqnum, -- interface_line_attribute4

           sdl.csapkseqnumber, -- interface_line_attribute5

           sdl.csaseqofcharge, -- interface_line_attribute6

           sdl.csacreationdate, -- interface_line_attribute7

           sdl.csaorderno, -- interface_line_attribute8

           sdl.csastationid, -- interface_line_attribute9

           sdl.csasubaccount, -- interface_line_attribute10

           sdl.csadivision, -- interface_line_attribute11

           sdl.description,

           sdl.quantity,

           ABS(sdl.amount) extendedamount,

           TO_CHAR(sdh.invoicereference1) invoicereference1,

           TO_CHAR(sdh.invoicereference2) invoicereference2,

           sdh.company header_company,

           sdh.account header_account,

           sdh.department header_department,

           sdh.destination header_destination,

           sdh.office header_office,

           sdh.origin header_origin,           

           sdh.division header_division,

           sdh.worksheetno header_worksheet,

           sdl.company line_company,

           sdl.account line_account,

           sdl.department line_department,

           sdl.destination line_destination,

           sdl.office line_office,

           sdl.origin line_origin,

           sdl.division line_division,

           sdl.worksheetno line_worksheet,

           --

           sdh.transactionno applies_to_doc_no,

           'Invoice' applies_to_doc_type

      FROM ajcl_bc_posted_sd_headers sdh,

           ajcl_bc_posted_sd_lines sdl, 

           ra_customers c

     WHERE sdh.bc_environment = gv_bc_environment

       AND sdh.entryno = p_entryno_in

       AND sdl.bc_environment = gv_bc_environment

       AND sdh.transactionno = sdl.transactionno

       AND sdh.billtocustomerno = sdl.billtocustomerno

       AND sdh.billtocustomerno = c.customer_number

       --

       AND p_inv_id_in IS NULL

     UNION

    -- Oracle

	   SELECT rct.bill_to_customer_id billtocustomerid,

           c.customer_name billtocustomername,

           c.customer_number billtocustomerno,

           rct.trx_number || '-CM' transactionno,

           SUBSTR(hl.address1,1,100) billtoaddress1,

           SUBSTR(hl.address2,1,50) billtoaddress2,

           SUBSTR(hl.address3,1,50) billtoaddress3,

           t.name termname,

           TO_CHAR(NVL(rct.term_due_date,aps.due_date),'YYYY-MM-DD') duedate,

           rct.invoice_currency_code invoicecurrencycode,

           rctl.interface_line_attribute1 csahousebill,

           rctl.interface_line_attribute2 csamaxpkseqno, 

           rctl.interface_line_attribute3 csacustomervendorno, 

           rctl.interface_line_attribute12 csafileextractnumber, 

           rctl.interface_line_attribute4 csaseqnum,

           rctl.interface_line_attribute5 csapkseqnumber, 

           rctl.interface_line_attribute6 csaseqofcharge, 

           rctl.interface_line_attribute7 csacreationdate, 

           rctl.interface_line_attribute8 csaorderno,

           rctl.interface_line_attribute9 csastationid, 

           rctl.interface_line_attribute10 csasubaccount, 

           rctl.interface_line_attribute11 csadivision, 

           rctl.description,

           rctl.quantity_invoiced quantity,

           ABS(rctl.extended_amount) extendedamount,

           rct.attribute5 invoicereference1,

           rct.attribute6 invoicereference2,

           -- Headers

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,h_aba.bc_account,'COMPANY',h_gcc.segment1) header_company,

           h_aba.bc_account header_account,

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,h_aba.bc_account,'DEPARTMENT',h_gcc.segment3) header_department,

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,h_aba.bc_account,'DESTINATION',

             DECODE(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                               p_oracle_value => h_gcc.segment5,

                                                               p_bc_dimension => 'OFFICE' ),NULL,h_gcc.segment5,'000') ) header_destination,

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,h_aba.bc_account,'OFFICE',

             NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                            p_oracle_value => h_gcc.segment5,

                                                            p_bc_dimension => 'OFFICE'),'000') ) header_office,

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,h_aba.bc_account,'ORIGIN',h_gcc.segment6) header_origin,

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,h_aba.bc_account,'DIVISION',

             NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4',

                                                            p_oracle_value => h_gcc.segment4,

                                                            p_bc_dimension => 'DIVISION'),'000') ) header_division,

           -- Line

           NULL header_worksheet,

           --

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,l_aba.bc_account,'COMPANY',l_gcc.segment1) line_company,

           l_aba.bc_account header_account,

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,l_aba.bc_account,'DEPARTMENT',l_gcc.segment3) line_department,

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,l_aba.bc_account,'DESTINATION',

             DECODE(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                               p_oracle_value => l_gcc.segment5,

                                                               p_bc_dimension => 'OFFICE' ),NULL,l_gcc.segment5,'000') ) line_destination,

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,l_aba.bc_account,'OFFICE',

             NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                            p_oracle_value => l_gcc.segment5,

                                                            p_bc_dimension => 'OFFICE'),'000') ) line_office,

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,l_aba.bc_account,'ORIGIN',l_gcc.segment6) line_origin,

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,l_aba.bc_account,'DIVISION',

             NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4',

                                                            p_oracle_value => l_gcc.segment4,

                                                            p_bc_dimension => 'DIVISION'),'000') ) line_division,

           --                                                                         

           NULL line_worksheet,

           rct.trx_number applies_to_doc_no,

           'Invoice' applies_to_doc_type

      FROM ra_customer_trx_all rct,

           ra_customers c,

           ra_customer_trx_lines_all rctl,

           hz_cust_site_uses_all su,

           hz_cust_acct_sites_all cas,

           hz_party_sites ps,

           hz_locations hl,

           ra_terms_tl t,

           ar_payment_schedules_all aps,

           -- REC - Header

           ra_cust_trx_line_gl_dist_all h_rctd,

           gl_code_combinations h_gcc,

           ajc_bc_accounts h_aba,

           -- REV - Line

           ra_cust_trx_line_gl_dist_all l_rctd,

           gl_code_combinations l_gcc,

           ajc_bc_accounts l_aba

     WHERE rct.bill_to_customer_id = c.customer_id

       AND rct.bill_to_site_use_id = su.site_use_id

       AND su.cust_acct_site_id = cas.cust_acct_site_id

       AND cas.party_site_id = ps.party_site_id

       AND ps.location_id = hl.location_id

       AND rct.org_id = rctl.org_id

       AND rct.org_id = gv_org_id

       AND rct.customer_trx_id = rctl.customer_trx_id

       AND rct.customer_trx_id = p_inv_id_in

       AND rct.term_id = t.term_id

       AND rct.customer_trx_id = aps.customer_trx_id (+)

       -- REC - Header

       AND rct.customer_trx_id = h_rctd.customer_trx_id

       AND h_rctd.account_class = 'REC'

       AND h_rctd.code_combination_id = h_gcc.code_combination_id

       AND h_gcc.segment2 = h_aba.oracle_account (+)

       -- REV - Line

       AND rctl.customer_trx_line_id = l_rctd.customer_trx_line_id

       AND l_rctd.account_class = 'REV'

       AND l_rctd.code_combination_id = l_gcc.code_combination_id

       AND l_gcc.segment2 = l_aba.oracle_account (+) 

       --

       AND p_entryno_in IS NULL;



    -- line_rec   c_select_line%ROWTYPE; 

    v_csacreationdate   VARCHAR2(10);



  BEGIN



    print_log('ajcl_bc_csa_pkg.create_credit_memo_from_trx_p (+)');



    print_log('Trx Date: ' || p_trx_date_in || ' | ' || 

              'GL Date: ' || p_gl_date_in || ' | ' || 

              'Entry No.' || p_entryno_in || ' | ' ||  

              'Inv Id:  ' || p_inv_id_in || ' | ' || 

              'Reversal Source: ' || p_reversal_source_in || ' | ' || 

              'Total Credit Amt: ' || p_total_credit_amount_in );



    IF ( p_reversal_source_in = 'CSA' ) THEN



      batch_source_name_v := p_csa_batch_source_name;

      context_v := 'CSA';

      cm_trx_type_name_v := p_csa_cm_trx_type_name;

      trx_date_v := p_trx_date_in;



    ELSE



      batch_source_name_v := p_ies_batch_source_name;

      context_v := 'IES';

      -- trx type name hardcoded here because it is hardcoded in IES AR interface program

      cm_trx_type_name_v := 'IES CM'; 

      trx_date_v := p_gl_date_in;



    END IF;	



    orig_inv_amt_v := null;

    num_lines_v := 0;



    BEGIN



      IF ( p_entryno_in IS NOT NULL ) THEN



        SELECT SUM(sdl.amount), 

               COUNT(1)

          INTO orig_inv_amt_v, 

               num_lines_v

          FROM ajcl_bc_posted_sd_headers sdh,

               ajcl_bc_posted_sd_lines sdl

         WHERE sdh.bc_environment = gv_bc_environment

           AND sdh.entryno = p_entryno_in

           AND sdl.bc_environment = gv_bc_environment

           AND sdh.transactionno = sdl.transactionno

           AND sdh.billtocustomerno = sdl.billtocustomerno;



      END IF;



      IF ( p_entryno_in IS NULL AND p_inv_id_in IS NOT NULL ) THEN



        SELECT SUM(extended_amount), 

               COUNT(*)

          INTO orig_inv_amt_v, num_lines_v

          FROM ra_customer_trx_lines_all

         WHERE customer_trx_id = p_inv_id_in;



       END IF;



    EXCEPTION

      WHEN OTHERS THEN

        NULL;



    END;



    print_log('Number of lines to process: ' || num_lines_v);



    percent_to_apply_v := null;



    IF ( p_total_credit_amount_in <> 0 ) THEN



      -- Calculate the percent to apply to the line amount

      percent_to_apply_v := p_total_credit_amount_in / orig_inv_amt_v;



    END IF;



    print_log('Orig Inv Amt: ' || orig_inv_amt_v);

    print_log('Percent to apply: ' || percent_to_apply_v);



    line_cnt_v := 0;

    lines_total_v := 0;

    REC_distr_created_v := 'N';



    FOR csl IN c_select_line LOOP



    -- OPEN c_select_line; LOOP



      -- FETCH c_select_line INTO line_rec;

		    -- EXIT WHEN ( c_select_line%ROWCOUNT = 0 OR c_select_line%NOTFOUND );



		    line_cnt_v := line_cnt_v + 1;

		    print_log( 'Line Extended Amount: ' || csl.extendedamount );



      -- Calculate the line amount

      IF ( percent_to_apply_v IS NOT NULL ) THEN



        line_amt_v := (csl.extendedamount * percent_to_apply_v);



      ELSE



        line_amt_v := csl.extendedamount;



      END IF;



      print_log('Line Amount: ' || line_amt_v);



		    lines_total_v := lines_total_v + line_amt_v;



		    print_log('Lines Total: ' || lines_total_v);



		    IF ( line_cnt_v = num_lines_v AND ( lines_total_v <> p_total_credit_amount_in ) ) THEN



        print_log('Lines Total <> Total Credit Amount');

        line_amt_v := line_amt_v + (p_total_credit_amount_in - lines_total_v);

        print_log('Adjusted Line Amount: '||line_amt_v);



      END IF;



      IF ( p_entryno_in IS NOT NULL ) THEN



        v_csacreationdate := csl.csaCreationDate;



      ELSE



        BEGIN



          v_csacreationdate := TO_CHAR(TO_DATE(csl.csaCreationDate,'DD-MON-YY'),'YYYY-MM-DD'); 



        EXCEPTION

          WHEN OTHERS THEN



            BEGIN



              v_csacreationdate := TO_CHAR(TO_DATE(csl.csaCreationDate,'YYYY-MM-DD'),'YYYY-MM-DD');



            EXCEPTION

              WHEN OTHERS THEN

                v_csacreationdate := NULL;              



            END;



        END;



      END IF;



      print_log ( 'v_csacreationdate: ' || v_csacreationdate );



      -- No se generan ni envian las lineas en 0, porque BC las rechaza

      IF ( line_amt_v != 0 ) THEN



        print_log ( 'Insert CM' );



        INSERT 

          INTO ajcl_bc_csa_ar_lines

             ( bc_environment,

               transactionno,

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

               header_origin,

               header_office,

               header_division,

               header_worksheet,

               appliestodoctype,

               appliestodocno,

               overrideflag,

               commentsajc_ine,

               invoicereference1,

               invoicereference2,

               dff_housebill,

               dff_max_csa_pk_seq,

               dff_cust_vend,

               dff_seq_num,

               dff_file_extract_number,

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

               line_origin,

               line_office,

               line_division,

               line_worksheet,

               salesordersource,

               salesorder,

               salesorderrevision,

               salesorderline,

               salesorderdate,

               alreasonmeaning,             

               dff_pk_seq_number,

               dff_seq_of_charge,

               dff_creation_date,

               dff_order_no,

               dff_station_id,

               dff_sub_account,

               dff_division,

               org_id,

               request_id,

               creation_date,

               created_by,

               last_update_date,

               last_updated_by,

               status )

      VALUES ( gv_bc_environment,

               csl.transactionNo,

               TO_CHAR(trx_date_v,'YYYY-MM-DD'), -- transactionDate

               'CM', -- class

               csl.termName,

               csl.duedate, -- termDueDate - Viene de BC, ya esta en formato YYYY-MM-DD

               TO_CHAR(p_gl_date_in,'YYYY-MM-DD'), -- glDate

               currency_code_c, -- invoicecurrencycode

               NULL, -- exchangedate

               conversion_rate_c, -- exchangerate

               conversion_type_c, -- exchangeratetype

               NULL, -- purchaseorder

               csl.billtocustomerid,

               csl.billtocustomername,

               csl.billtocustomerno,

               csl.billtoaddress1,

               csl.billtoaddress2,

               csl.billtoaddress3,

               csl.header_company, 

               csl.header_account, 

               csl.header_department, 

               csl.header_destination, 

               csl.header_origin, 

               csl.header_office,  

               csl.header_division,

               csl.header_worksheet, -- header_worksheet

               csl.applies_to_doc_type, -- csl.appliestodoctype

               csl.applies_to_doc_no, -- csl.appliestodocno

               NULL, -- csl.overrideflag

               NULL, -- csl.commentsajc_ine

               csl.invoicereference1,

               csl.invoicereference2,

               -- header level

               csl.csaHousebill, -- dff_housebill

               csl.csaMaxPKSeqNo, -- dff_max_csa_pk_seq

               csl.csaCustomerVendorNo, -- dff_cust_vend

               NULL, -- inv_trx_dff_seq_no_v, -- dff_seq_num -- Se genera cuando se genera la cabecera

               csl.csaFileExtractNumber, -- dff_file_extract_number   

               --

               line_cnt_v, -- lineNo

               csl.description,

               qty_c, -- quantity

               ABS(line_amt_v), -- unitsellingprice,

               ABS(line_amt_v), -- extendedamount

               ABS(line_amt_v), -- accountedamount

               csl.line_company,

               csl.line_account, 

               csl.line_department,

               csl.line_destination,

               csl.line_origin,

               csl.line_office,

               csl.line_division,

               csl.line_worksheet, -- line_worksheet

               NULL, -- salesordersource

               NULL, -- salesorder,

               NULL, -- salesorderrevision,

               NULL, -- salesorderline,

               NULL, -- salesorderdate,

               NULL, -- alreasonmeaning,             

               -- line level

               csl.csaPkSeqNumber, -- dff_pk_seq_number

               csl.csaSeqOfCharge, -- dff_seq_of_charge

               -- TO_CHAR(TO_DATE(csl.csaCreationDate,'DD-MON-YY'),'YYYY-MM-DD'), -- dff_creation_date

               v_csacreationdate, -- dff_creation_date

               csl.csaOrderNo, -- dff_order_no

               csl.csaStationId, -- dff_station_id

               csl.csaSubAccount, -- dff_sub_account

               csl.csaDivision, -- dff_division

               --

               gv_org_id,

               gv_request_id,

               SYSDATE,

               gv_user_id,

               SYSDATE,

               gv_user_id,

               'NEW' );   



      END IF;



    END LOOP;  



    print_log('ajcl_bc_csa_pkg.create_credit_memo_from_trx_p (-)');



  END create_credit_memo_from_trx_p;



  PROCEDURE create_ar_invoice_p ( p_trx_number_in		         IN   VARCHAR2,

                                  p_housebill_in            IN   NUMBER,

                                  p_inv_distr_attr1_in	     IN   VARCHAR2,

                                  p_stationId_in	           IN   VARCHAR2,

                                  --

                                  -- p_default_division        IN   VARCHAR2,

                                  -- p_stationid_set_id        IN   NUMBER,

                                  p_csa_batch_source_name   IN   VARCHAR2,

                                  p_csa_file_no             IN   ajc_csa_interfaceAPAR.csa_file_no%TYPE,

                                  p_inv_trx_type_name       IN   ra_cust_trx_types_all.name%TYPE,

                                  p_oracle_cust_id          IN   NUMBER,

                                  --

                                  p_oracle_cust_name        IN   VARCHAR2,

                                  p_oracle_cust_number      IN   VARCHAR2,

                                  --

                                  p_oracle_addr_id          IN   NUMBER,

                                  --

                                  p_oracle_addr1            IN   VARCHAR2,

                                  p_oracle_addr2            IN   VARCHAR2,

                                  p_oracle_addr3            IN   VARCHAR2,

                                  --

                                  p_term_name               IN   VARCHAR2,

                                  p_due_days                IN   NUMBER,

                                  p_header_company          IN   VARCHAR2,

                                  p_header_account          IN   VARCHAR2,

                                  p_header_department       IN   VARCHAR2,

                                  p_header_destination      IN   VARCHAR2,

                                  p_header_origin           IN   VARCHAR2,

                                  p_header_office           IN   VARCHAR2,

                                  p_header_division         IN   VARCHAR2 ) IS



    invoice_num_v			       ra_customer_trx.trx_number%TYPE;



    seq_no_v			            NUMBER;

    invoice_line_num_v		   NUMBER;

    got_max_pk_seq_no_v		  VARCHAR2(1);

    max_pk_seqno_v			      NUMBER;

    -- inv_trx_dff_seq_no_v		 NUMBER;

    invoice_amt_v			       NUMBER;

    attribute_category_c		 ra_customer_trx_all.attribute_category%TYPE := 'CSA';

    fk_cvno_v			           ajc_csa_interfaceAPAR.fk_cvno%TYPE;

    pk_seqno_v			          ajc_csa_interfaceAPAR.pk_seqno%TYPE;

    fk_seqno_v			          ajc_csa_interfaceAPAR.fk_seqno%TYPE;

    createdate_v			        ajc_csa_interfaceAPAR.createdate%TYPE;

    fk_orderNo_v			        ajc_csa_interfaceAPAR.fk_orderNo%TYPE;

    subaccount_v			        ajc_csa_interfaceAPAR.subaccount%TYPE;

    division_v			          ajc_csa_interfaceAPAR.division%TYPE;



      -- Sort the lines by the pk_seqno so the largest value will be first which will be the value for interface_line_attribute2

      CURSOR c_select_inv_line IS

      SELECT pk_seqno, 

             chargecode, 

             total, 

             fk_cvno, 

             fk_seqno, 

             createdate, 

             fk_orderNo,

             RTRIM(SUBSTR(NVL(subaccount,gv_default_subaccount),1,30)) subaccount, 

             NVL(division,gv_default_division) division, 

             description, 

             trx_date, 

             ShipmentDateTime, 

             PODDateTime, 

             gl_date 

        FROM ajc_csa_interfaceAPAR 

       WHERE NVL(AR_status,'XXX') <> 'INTERFACED'

         AND validation_status = 'Y'

         AND housebill = p_housebill_in

         AND aparcode = 'C'  

         AND finalize = 'Y' 

    ORDER BY pk_seqno DESC;



    v_line_company                   VARCHAR2(10);

    v_line_account                   VARCHAR2(10);

    v_line_department                VARCHAR2(10);

    v_line_destination               VARCHAR2(10);

    v_line_origin                    VARCHAR2(10);

    v_line_office                    VARCHAR2(10);

    v_line_division                  VARCHAR2(10);



  BEGIN 



    print_log('ajcl_bc_csa_pkg.create_ar_invoice_p (+)');



	   print_log('Procedure: Create_AR_Invoice');

	   print_log('Inv num: ' || p_trx_number_in);



    invoice_line_num_v := 0;

    got_max_pk_seq_no_v := 'N';

    max_pk_seqno_v := NULL;



    print_log('Value to store in distr attr1: ' || p_inv_distr_attr1_in);



	   FOR line_rec IN c_select_inv_line LOOP



		    IF ( got_max_pk_seq_no_v = 'N' ) THEN



        max_pk_seqno_v := line_rec.pk_seqno;

			     got_max_pk_seq_no_v := 'Y';



      END IF;



		    -- Get the REV accounts from the CSA Item

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

         AND charge_type_code = line_rec.chargecode

         AND business_line = '76'

         AND NVL(inactive_date, SYSDATE + 1) > SYSDATE;      



      BEGIN



        SELECT destination

          INTO v_line_destination

          FROM ajcl_bc_csa_station_id

         WHERE bc_environment = gv_bc_environment

           AND station_id = p_stationId_in;



      EXCEPTION

        WHEN NO_DATA_FOUND THEN

          NULL;

        WHEN OTHERS THEN

          NULL;



      END;



      -- Create the invoice lines	

      invoice_line_num_v := invoice_line_num_v + 1;

      invoice_amt_v := invoice_amt_v + line_rec.total;



      -- No se generan ni envian las lineas en 0, porque BC las rechaza

      IF ( line_rec.total != 0 ) THEN



        INSERT 

          INTO ajcl_bc_csa_ar_lines

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

               header_origin,

               header_office,

               header_division,

               header_worksheet,

               line_company,

               line_account,

               line_department,

               line_destination,

               line_origin,

               line_office,

               line_division,

               line_worksheet,

               --

               invoicereference1,

               invoicereference2,

               -- header level

               dff_housebill,

               dff_max_csa_pk_seq,

               dff_cust_vend,

               dff_seq_num,

               dff_file_extract_number,

               -- line level

               dff_pk_seq_number,

               dff_seq_of_charge,

               dff_creation_date,

               dff_order_no,

               dff_station_id,

               dff_sub_account,

               dff_division,

               --

               org_id,

               request_id,

               creation_date,

               created_by,

               last_update_date,

               last_updated_by,

               status )

      VALUES ( gv_bc_environment,

               p_oracle_cust_id,

               p_oracle_cust_name, 

               p_oracle_cust_number,

               p_oracle_addr1, 

               p_oracle_addr2, 

               p_oracle_addr3, 

               p_trx_number_in, -- trx_number

               'INV', -- class

               TO_CHAR(line_rec.trx_date,'YYYY-MM-DD'), -- trx_date

               TO_CHAR(line_rec.gl_date,'YYYY-MM-DD'), -- gl_date

               p_term_name,

               TO_CHAR(NVL(line_rec.trx_date,line_rec.gl_date) + p_due_days,'YYYY-MM-DD'), -- termDueDate

               invoice_line_num_v, -- line_number

               line_rec.description, -- description

               currency_code_c, -- currency_code

               conversion_type_c, -- conversion_type

               NULL, -- conversion_date

               conversion_rate_c, -- conversion_rate

               qty_c, -- quantity

               line_rec.total, -- unit_selling_price,

               line_rec.total, -- extended_amount

               line_rec.total, -- accounted_amount

               p_header_company, 

               p_header_account, 

               p_header_department,  

               p_header_destination, 

               p_header_origin, 

               p_header_office,  

               p_header_division,

               p_inv_distr_attr1_in, -- header_worksheet

               v_line_company,

               v_line_account, 

               v_line_department,

               v_line_destination,

               v_line_origin,

               v_line_office,

               v_line_division, 

               p_inv_distr_attr1_in, -- line_worksheet

               p_housebill_in, -- invoicereference1

               line_rec.fk_orderno, -- invoicereference2,

               -- header level

               p_housebill_in, -- dff_housebill

               max_pk_seqno_v, -- dff_max_csa_pk_seq

               line_rec.fk_cvno, -- dff_cust_vend

               NULL, -- inv_trx_dff_seq_no_v, -- dff_seq_num

               p_csa_file_no, -- dff_file_extract_number             

               -- line level

               line_rec.pk_seqno, -- dff_pk_seq_number

               line_rec.fk_seqno, -- dff_seq_of_charge

               TO_CHAR(line_rec.createdate,'YYYY-MM-DD'), -- dff_creation_date

               -- line_rec.createdate, -- dff_creation_date

               line_rec.fk_orderNo, -- dff_order_no

               p_stationId_in, -- dff_station_id

               line_rec.subaccount, -- dff_sub_account

               line_rec.division, -- dff_division

               --

               gv_org_id,

               gv_request_id,

               SYSDATE,

               gv_user_id,

               SYSDATE,

               gv_user_id,

               'NEW' );



      END IF;



      fk_cvno_v	:= line_rec.fk_cvno;

      pk_seqno_v	:= line_rec.pk_seqno;

      fk_seqno_v	:= line_rec.fk_seqno;

      createdate_v	:= line_rec.createdate;

      fk_orderNo_v	:= line_rec.fk_orderNo;

      subaccount_v	:= line_rec.subaccount;

      division_v	:= line_rec.division;



    END LOOP; 



    print_log('ajcl_bc_csa_pkg.create_ar_invoice_p (-)');



  END create_ar_invoice_p;



  PROCEDURE ar_insert_p ( p_status             OUT   VARCHAR2,

                          p_error_message   IN OUT   VARCHAR2 ) IS



    num_recs_to_process_v		   NUMBER	:= 0;

    csa_batch_source_name_v		 ra_batch_sources.name%TYPE;

    ies_batch_source_name_v		 ra_batch_sources.name%TYPE;



    cm_trx_type_id_v		        ra_cust_trx_types_all.credit_memo_type_id%TYPE;

    inv_trx_type_name_v		     ra_cust_trx_types_all.name%TYPE;

    csa_cm_trx_type_name_v		  ra_cust_trx_types_all.name%TYPE;



    -- stationid_set_id_v		      fnd_flex_value_sets.flex_value_set_id%TYPE;

    oracle_cust_id_v		        hz_cust_accounts.cust_account_id%TYPE;

    -- 20231003

    oracle_cust_name_v	       hz_parties.party_name%TYPE;

    oracle_cust_number_v	     hz_cust_accounts.account_number%TYPE;

    -- 20231003

    oracle_addr_id_v		        hz_cust_acct_sites.cust_acct_site_id%TYPE;

    -- 20231003

    oracle_addr1_v            VARCHAR2(100);

    oracle_addr2_v            VARCHAR2(50);

    oracle_addr3_v            VARCHAR2(50);

    -- 20231003



    csa_file_no_v	          		ajc_csa_interfaceAPAR.csa_file_no%TYPE;



    term_name_v		            	ra_terms.name%TYPE;

    due_days_v                NUMBER;



    stationId_v			            ajc_csa_interfaceAPAR.fk_stationId%TYPE;



    prev_trx_num_v			         ra_customer_trx_all.trx_number%TYPE;

    prev_trx_seq_no_v		       ra_customer_trx_all.trx_number%TYPE;

    prev_trx_invseq_no_v		    ra_customer_trx_all.trx_number%TYPE;

    trx_number_v			           ra_customer_trx_all.trx_number%TYPE;

    inv_distr_attr1_v		       ra_cust_trx_line_gl_dist_all.attribute1%TYPE;



    -- Se cambia la forma de numerar los comprobantes

    -- next_invseq_v		          	NUMBER;	



    no_data_to_process		      EXCEPTION;

    skip_housebill		         	EXCEPTION;



    -- Revenue Finalized and Delivery Occurred (APARCode = C; Finalize = Y; PODDateTime is greater than zeroes)

      CURSOR c_select_housebill IS

      SELECT DISTINCT housebill, 

             fk_orderno, 

             fk_cvno, 

             poddatetime, 

             trx_date, 

             gl_date, 

             reversal_source, 

             ar_reversal_entryno,

             ar_reversal_ref_id, 

             ar_reversal_ref_name, 

             ar_status,

             csa_file_no,

             total_credit_amount

        FROM ajc_csa_interfaceAPAR

       WHERE aparcode = 'C' 

         AND finalize = 'Y'

         AND validation_status = 'Y'

         AND nvl(ar_status,'XXX') <> 'INTERFACED'

    ORDER BY housebill;



    inv_trx_dff_seq_no_v   NUMBER;



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

             header_origin origin,

             header_office office,

             header_division division,

             billtocustomerid,

             billtocustomername,

             billtocustomerno,

             billtoaddress1,

             billtoaddress2,

             billtoaddress3,

             header_worksheet,

             appliestodoctype,

             appliestodocno,

             overrideflag,

             commentsajc_ine,

             invoicereference1,

             invoicereference2,

             dff_housebill,

             dff_max_csa_pk_seq,

             dff_cust_vend,

             dff_seq_num,

             dff_file_extract_number,

             status

        FROM ajcl_bc_csa_ar_lines

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

             header_origin,

             header_office,

             header_division,

             billtocustomerid,

             billtocustomername,

             billtocustomerno,

             billtoaddress1,

             billtoaddress2,

             billtoaddress3,

             header_worksheet,

             appliestodoctype,

             appliestodocno,

             overrideflag,

             commentsajc_ine,

             invoicereference1,

             invoicereference2,

             dff_housebill,

             dff_max_csa_pk_seq,

             dff_cust_vend,

             dff_seq_num,

             dff_file_extract_number,

             status;



    v_header_company                 VARCHAR2(10);

    v_header_account                 VARCHAR2(10);

    v_header_department              VARCHAR2(10);

    v_header_destination             VARCHAR2(10);

    v_header_origin                  VARCHAR2(10);

    v_header_office                  VARCHAR2(10);

    v_header_division                VARCHAR2(10);



  BEGIN



    print_log ( 'ajcl_bc_csa_pkg.ar_insert_p (+)' );



    SELECT COUNT(*)

      INTO num_recs_to_process_v

      FROM ajc_csa_interfaceAPAR

     WHERE aparcode = 'C'

       AND finalize = 'Y'

       AND NVL(AR_status,'XXX') <> 'INTERFACED'

       AND validation_status = 'Y'; 



    IF ( num_recs_to_process_v = 0 ) THEN



      RAISE no_data_to_process;



    END IF;



    SELECT name

      INTO csa_batch_source_name_v

      FROM ra_batch_sources

     WHERE batch_source_id = gv_default_csa_batch_source;



    SELECT name

      INTO ies_batch_source_name_v

      FROM ra_batch_sources

     WHERE batch_source_id = gv_default_ies_batch_source;



    -- Get the AR distribution from the inv trx type

    BEGIN



      SELECT gcc.segment1 company, 

             aba.bc_account account, 

             NULL department,

             NULL destination, 

             NULL office, 

             NULL origin,

             NULL division,

             credit_memo_type_id, 

             name

        INTO v_header_company, 

             v_header_account, 

             v_header_department, 

             v_header_destination, 

             v_header_office, 

             v_header_origin, 

             v_header_division,

             cm_trx_type_id_v, 

             inv_trx_type_name_v 

        FROM ra_cust_trx_types_all t, 

             gl_code_combinations gcc,

             ajc_bc_accounts aba

       WHERE t.gl_id_rec = gcc.code_combination_id

         AND t.org_id = gv_org_id

         AND t.cust_trx_type_id = gv_default_csa_inv_type

         AND aba.oracle_account = gcc.segment2;



    EXCEPTION

      WHEN OTHERS THEN

        RAISE;



    END;



    print_log ( 'v_header_company: ' || v_header_company );

    print_log ( 'v_header_account: ' || v_header_account );

    print_log ( 'v_header_department: ' || v_header_department );

    print_log ( 'v_header_destination: ' || v_header_destination );

    print_log ( 'v_header_office: ' || v_header_office );

    print_log ( 'v_header_origin: ' || v_header_origin );

    print_log ( 'v_header_division: ' || v_header_division );

    -- SBanchieri



    IF ( cm_trx_type_id_v IS NOT NULL ) THEN



      -- Find the CM trx type name

	     BEGIN



        SELECT name

          INTO csa_cm_trx_type_name_v

          FROM ra_cust_trx_types_all

         WHERE org_id = gv_org_id 

           AND cust_trx_type_id = cm_trx_type_id_v;



      EXCEPTION

        WHEN OTHERS THEN 

          NULL;



      END;



    END IF;



    FOR housebill_rec IN c_select_housebill LOOP



      BEGIN



        print_log ( 'Housebill: ' || housebill_rec.housebill);

        print_log ( 'FK_CVNO: ' || housebill_rec.fk_cvno);



        -- 20231003 find_oracle_customer_p ( housebill_rec.fk_cvno, oracle_cust_id_v, oracle_addr_id_v );

        find_oracle_customer_p ( housebill_rec.fk_cvno, 

                                 oracle_cust_id_v, 

                                 --

                                 oracle_cust_name_v, 

                                 oracle_cust_number_v,

                                 --

                                 oracle_addr_id_v,

                                 --

                                 oracle_addr1_v,

                                 oracle_addr2_v,

                                 oracle_addr3_v );

        -- 20231003



        print_log ( 'Customer ID: ' || oracle_cust_id_v || '|' ||  

                    'Customer Name: ' || oracle_cust_name_v || '|' ||  

                    'Customer Number: ' || oracle_cust_number_v || '|' ||  

                    'Address ID: ' || oracle_addr_id_v || '|' ||  

                    'Address1: ' || oracle_addr1_v || '|' ||  

                    'Address2: ' || oracle_addr2_v || '|' ||  

                    'Address3: ' || oracle_addr3_v );



        csa_file_no_v := housebill_rec.csa_file_no;

        print_log ( 'CSA Extract File Number: ' || csa_file_no_v );



        term_name_v := NULL;

        due_days_v := NULL;



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

				        print_log ( 'Payment term not found for customer ID: ' || oracle_cust_id_v );



          WHEN OTHERS THEN

		          RAISE;



        END;



		      -- Find the stationID from the highest pk_seqno of the housebill

		      stationId_v := NULL;



        BEGIN



          SELECT DISTINCT fk_stationId

            INTO stationId_v

            FROM ajc_csa_interfaceAPAR

           WHERE pk_seqno = ( SELECT MAX(pk_seqno)

                                FROM ajc_csa_interfaceAPAR

                               WHERE housebill = housebill_rec.housebill );

		      EXCEPTION

          WHEN TOO_MANY_ROWS THEN

            print_log ( 'Multiple station ids found for housebill ' || housebill_rec.housebill || ', max pk_seqno' );

            RAISE;



          WHEN OTHERS THEN

            print_log ( 'Station Id not found for housebill ' || housebill_rec.housebill || ', max pk_seqno' );

            RAISE;



        END;



        print_log ( 'Station Id to be used when creating Invoices: ' || stationId_v );



        print_log ( 'AR Status: ' || housebill_rec.ar_status );

        print_log ( 'AR Reversal Ref ID: ' || housebill_rec.ar_reversal_ref_id );



        prev_trx_num_v := NULL;

        prev_trx_seq_no_v := NULL;

        prev_trx_invseq_no_v := NULL;



		      IF ( housebill_rec.ar_reversal_entryno IS NOT NULL OR 

             housebill_rec.ar_reversal_ref_id IS NOT NULL ) THEN



			       -- Find info for the INV that needs to be credited

			       BEGIN



            IF ( housebill_rec.ar_reversal_entryno IS NOT NULL ) THEN



              SELECT transactionno prev_trx_num_v,

                     --

                     CASE

                       WHEN INSTR(transactionno,'-',1,2) != 0 THEN -- cuando tiene 2 guiones

                         DECODE(INSTR(transactionno,'-',1,2), 

                           0,0,

                           SUBSTR(transactionno,INSTR(transactionno,'-',1,2)+1,DECODE(INSTR(transactionno,'-',1,3),0,(LENGTH(transactionno) - INSTR(transactionno,'-',1,2)),( INSTR(transactionno,'-',1,3)- (INSTR(transactionno,'-',1,2)+1) ))))

                       ELSE -- cuando tiene un guion

                         DECODE(INSTR(transactionno,'-',1,1), 

                           0,0,

                           SUBSTR(transactionno,INSTR(transactionno,'-',1,1)+1,DECODE(INSTR(transactionno,'-',1,2),0,(LENGTH(transactionno) - INSTR(transactionno,'-',1,1)),( INSTR(transactionno,'-',1,2)- (INSTR(transactionno,'-',1,1)+1) ))))

                     END prev_trx_seq_no_v,

                     --

                     CASE

                       WHEN INSTR(transactionno,'-',1,2) != 0 THEN -- cuando tiene 2 guiones

                         SUBSTR(transactionno,

                           INSTR(transactionno,'-',1,1) + 1,

                           INSTR(transactionno,'-',1,2) - (INSTR(transactionno,'-',1,1) + 1))

                       ELSE -- cuando tiene un guion

                         SUBSTR(transactionno,

                           1,

                           INSTR(transactionno,'-',1,1) - 1)

                     END prev_trx_invseq_no_v

                INTO prev_trx_num_v,

                     prev_trx_seq_no_v,

                     prev_trx_invseq_no_v

                FROM ajcl_bc_posted_sd_headers  

               WHERE bc_environment = gv_bc_environment

                 AND class = 'INV'

                 AND entryno = housebill_rec.ar_reversal_entryno;



            END IF;



            IF ( housebill_rec.ar_reversal_entryno IS NULL AND housebill_rec.ar_reversal_ref_id IS NOT NULL ) THEN



              SELECT t.trx_number,

                     DECODE(INSTR(t.trx_number, '-',1,2), 0,0,SUBSTR(t.trx_number,INSTR(trx_number,'-',1,2)+1, 

                       DECODE(INSTR(trx_number,'-',1,3),0,(LENGTH(trx_number) - INSTR(trx_number,'-',1,2)),

                         ( INSTR(trx_number,'-',1,3)- (INSTR(trx_number,'-',1,2)+1) )))),

                     -- SUBSTR( trx_number, 4, INSTR(trx_number,'-',1,2)-4 )

                     SUBSTR(trx_number,

                       INSTR(trx_number,'-',1,1) + 1,

                       INSTR(trx_number,'-',1,2) - (INSTR(trx_number,'-',1,1) + 1))

                INTO prev_trx_num_v,

                     prev_trx_seq_no_v,

                     prev_trx_invseq_no_v

                FROM ra_cust_trx_types_all tt,

                     ra_customer_trx_all t 

               WHERE t.cust_trx_type_id = tt.cust_trx_type_id

                 AND tt.type = 'INV'

                 AND t.customer_trx_id = housebill_rec.ar_reversal_ref_id;



            END IF;



          EXCEPTION

            WHEN NO_DATA_FOUND THEN

              RAISE skip_housebill;

            WHEN OTHERS THEN

              RAISE;



          END;



          print_log ( 'Reversal Trx: ' || housebill_rec.ar_reversal_ref_name );

          print_log ( 'Reversal Trx id: ' || housebill_rec.ar_reversal_ref_id );

          print_log ( 'Reversal Entry No.: ' || housebill_rec.ar_reversal_entryno );

          print_log ( 'Prev Trx Num: ' || prev_trx_num_v );

          print_log ( 'Prev Trx Seq No: ' || prev_trx_seq_no_v );



        END IF;



		      IF ( housebill_rec.ar_status = 'CM' ) THEN



          create_credit_memo_from_trx_p ( p_entryno_in => housebill_rec.ar_reversal_entryno,

                                          p_inv_id_in => housebill_rec.ar_reversal_ref_id,

                                          p_trx_date_in => housebill_rec.trx_date,

                                          p_gl_date_in => housebill_rec.gl_date,

                                          p_reversal_source_in => housebill_rec.reversal_source,

                                          p_total_credit_amount_in => housebill_rec.total_credit_amount,

                                          p_csa_file_no_in => housebill_rec.csa_file_no,

                                          p_csa_batch_source_name => csa_batch_source_name_v,

                                          p_csa_cm_trx_type_name => csa_cm_trx_type_name_v,

                                          p_ies_batch_source_name => ies_batch_source_name_v );

		      END IF;



		      print_log ( 'Build the invoice number' );



        -- Build the invoice number

        trx_number_v := NULL;

        inv_distr_attr1_v := NULL;



        -- Se cambia la forma de numerar los comprobantes

        -- next_invseq_v := NULL;



		      IF ( prev_trx_num_v IS NOT NULL ) THEN



          IF ( SUBSTR(prev_trx_num_v,1,3) = '70-' ) THEN -- Si tiene numeracion de Oracle



            trx_number_v := '70-' || TO_CHAR(prev_trx_invseq_no_v) || '-' || TO_CHAR(prev_trx_seq_no_v + 1);



          ELSE -- Si tiene la nueva numeracion de BC



            trx_number_v := TO_CHAR(prev_trx_invseq_no_v) || '-' || TO_CHAR(prev_trx_seq_no_v + 1);



          END IF;



          -- This will be a rebill invoice

          -- Get the ies worksheet number from original invoice

          BEGIN



            IF ( housebill_rec.ar_reversal_entryno IS NOT NULL ) THEN 



              -- 20241022

              /*

              SELECT worksheetno

                INTO inv_distr_attr1_v

                FROM ajcl_bc_posted_sd_headers

               WHERE bc_environment = gv_bc_environment

                 AND entryno = housebill_rec.ar_reversal_entryno;

              */

              SELECT MAX(l.worksheetno)

                INTO inv_distr_attr1_v

                FROM ajcl_bc_posted_sd_lines l,

                     ajcl_bc_posted_sd_headers h

               WHERE l.bc_environment = gv_bc_environment

                 AND l.transactionno = h.transactionno

                 AND l.bc_environment = h.bc_environment

                 AND l.billtocustomerno = h.billtocustomerno

                 AND h.entryno = housebill_rec.ar_reversal_entryno;

              -- 20241022



            END IF;



            IF ( housebill_rec.ar_reversal_entryno IS NULL AND housebill_rec.ar_reversal_ref_id IS NOT NULL ) THEN 



              SELECT MAX(attribute1)

                INTO inv_distr_attr1_v        

                FROM ra_cust_trx_line_gl_dist_all

               WHERE customer_trx_id = housebill_rec.ar_reversal_ref_id;



            END IF;



          EXCEPTION

            WHEN OTHERS THEN 

              NULL;



          END;



			       print_log ( 'Rebill Invoice Number to create: ' || trx_number_v );

          print_log ( 'inv_distr_attr1_v: ' || inv_distr_attr1_v );



       	ELSE



          trx_number_v := stationId_v || housebill_rec.housebill || '-1';



          inv_distr_attr1_v := '70-' || housebill_rec.housebill;

          fnd_file.put_line (fnd_file.log, 'Trx Number to create: ' || trx_number_v);



        END IF;



        create_ar_invoice_p ( p_trx_number_in => trx_number_v, 

                              p_housebill_in => housebill_rec.housebill,

                              p_inv_distr_attr1_in => inv_distr_attr1_v, 

                              p_stationId_in => stationId_v,

                              --

                              -- p_default_division => p_default_division,

                              -- p_stationid_set_id => stationid_set_id_v,

                              p_csa_batch_source_name => csa_batch_source_name_v,

                              p_csa_file_no => csa_file_no_v,

                              p_inv_trx_type_name => inv_trx_type_name_v,

                              p_oracle_cust_id => oracle_cust_id_v,

                              --

                              p_oracle_cust_name => oracle_cust_name_v,

                              p_oracle_cust_number => oracle_cust_number_v,

                              --

                              p_oracle_addr_id => oracle_addr_id_v,

                              --

                              p_oracle_addr1 => oracle_addr1_v,

                              p_oracle_addr2 => oracle_addr2_v,

                              p_oracle_addr3 => oracle_addr3_v,

                              --

                              p_term_name => term_name_v,

                              p_due_days => due_days_v,

                              p_header_company => v_header_company,

                              p_header_account => v_header_account,

                              p_header_department => v_header_department,

                              p_header_destination => v_header_destination,

                              p_header_origin => v_header_origin,

                              p_header_office => v_header_office,

                              p_header_division => v_header_division );



        UPDATE ajc_csa_interfaceAPAR

           SET ar_status = 'INTERFACED'

         WHERE housebill = housebill_rec.housebill

           AND csa_file_no =  csa_file_no_v

           AND fk_orderno = housebill_rec.fk_orderno

           AND fk_cvno = housebill_rec.fk_cvno

           AND poddatetime = housebill_rec.poddatetime

           AND aparcode = 'C' 

           AND finalize = 'Y'

           AND validation_status = 'Y';



        -- COMMIT;



      EXCEPTION

        WHEN skip_housebill THEN 

          print_log ( 'Housebill skipped' );



      END;



    END LOOP;



    print_log ( 'Antes de generar las cabeceras, se marcan con ERROR todas las lineas de los comprobantes que tengan al menos una linea con ERROR.' );



    UPDATE ajcl_bc_csa_ar_lines a

       SET status = 'ERROR'

     WHERE request_id = gv_request_id

       AND bc_environment = gv_bc_environment

       AND transactionno IN ( SELECT transactionno 

                                FROM ajcl_bc_csa_ar_lines b 

                               WHERE b.request_id = a.request_id

                                 AND b.bc_environment = gv_bc_environment

                                 AND b.status = 'ERROR' );



    -- COMMIT;



    -- Se generan las cabeceras a partir de las lineas insertadas

    FOR ch IN c_headers LOOP



      SELECT ajc_csa_inv_trx_dff_s.nextval 

        INTO inv_trx_dff_seq_no_v

        FROM dual;



	     print_log('Inv Trx dff seq no:' || inv_trx_dff_seq_no_v);



      INSERT

        INTO ajcl_bc_csa_ar_headers

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

             origin,

             office,

             division,

             billtocustomerid,

             billtocustomername,

             billtocustomerno,

             billtoaddress1,

             billtoaddress2,

             billtoaddress3,

             worksheetno,

             appliestodoctype,

             appliestodocno,

             overrideflag,

             commentsajc_ine,

             invoicereference1,

             invoicereference2,

             dff_housebill,

             dff_max_csa_pk_seq,

             dff_cust_vend,

             dff_seq_num,

             dff_file_extract_number,

             org_id,

             request_id,

             creation_date,

             created_by,

             last_update_date,

             last_updated_by,

             status )

    VALUES ( gv_bc_environment,

             ch.company,

             ch.transactionno,

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

             ch.origin,

             ch.office,

             ch.division,

             ch.billtocustomerid,

             ch.billtocustomername,

             ch.billtocustomerno,

             ch.billtoaddress1,

             ch.billtoaddress2,

             ch.billtoaddress3,

             ch.header_worksheet,

             ch.appliestodoctype,

             ch.appliestodocno,

             ch.overrideflag,

             ch.commentsajc_ine,

             ch.invoicereference1,

             ch.invoicereference2,

             ch.dff_housebill,

             ch.dff_max_csa_pk_seq,

             ch.dff_cust_vend,

             inv_trx_dff_seq_no_v, -- ch.dff_seq_num,

             ch.dff_file_extract_number,

             gv_org_id,

             gv_request_id,

             SYSDATE, -- creation_date

             gv_user_id,

             SYSDATE, -- last_update_date

             gv_user_id,

             'NEW' );



    END LOOP;



    p_status := 'S';



    print_log('ajcl_bc_csa_pkg.ar_insert_p (-)');



  EXCEPTION

    WHEN no_data_to_process THEN

      p_status := 'W';

      p_error_message := 'No data to process.';

      print_log('ajcl_bc_csa_pkg.ar_insert_p (!). Error: no data to process.');

    WHEN OTHERS THEN

      p_status := 'E';

      p_error_message := 'Error: ' || SQLERRM;

      print_log('ajcl_bc_csa_pkg.ar_insert_p (!). Error: ' || SQLERRM);



  END ar_insert_p;



  PROCEDURE ar_call_ws ( p_status          OUT   VARCHAR2,

                         p_trx_count       OUT   NUMBER,

                         p_lines_count     OUT   NUMBER ) IS



    CURSOR c_headers_reprocess IS

    SELECT *

      FROM ajcl_bc_csa_ar_headers h

     WHERE bc_environment = gv_bc_environment

       AND ( ( request_id != gv_request_id AND status = 'ERROR' AND NOT EXISTS ( SELECT 1 

                                                                                   FROM ajcl_bc_csa_ar_lines l 

                                                                                  WHERE h.transactionno = l.transactionno 

                                                                                    AND h.class = l.class

                                                                                    AND NVL(h.billtocustomerno,-1) = NVL(l.billtocustomerno,-1)

                                                                                    AND h.request_id = l.request_id

                                                                                    AND l.bc_environment = h.bc_environment

                                                                                    AND UPPER(l.error_message) LIKE UPPER('%Line%already%exists%') ) ) OR

             ( request_id != gv_request_id AND status NOT IN ('SUCCESS','ERROR') ) ); 



    CURSOR c_headers IS

    SELECT *

      FROM ajcl_bc_csa_ar_headers h

     WHERE bc_environment = gv_bc_environment

       AND request_id = gv_request_id 

       AND status = 'NEW';



      CURSOR c_lines ( pc_transactionNo         IN   VARCHAR2,

                       pc_billToCustomerNo      IN   NUMBER,

                       pc_class                 IN   VARCHAR2 ) IS

      SELECT *

        FROM ajcl_bc_csa_ar_lines

       WHERE transactionNo = pc_transactionNo

         AND NVL(billToCustomerNo,-1) = NVL(pc_billToCustomerNo,-1)

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



    oracle_cust_id_v	      hz_cust_accounts.cust_account_id%TYPE;

    oracle_cust_name_v	    hz_parties.party_name%TYPE;

    oracle_cust_number_v	  hz_cust_accounts.account_number%TYPE;

    oracle_addr_id_v	      hz_cust_acct_sites.cust_acct_site_id%TYPE;

    oracle_addr1_v         VARCHAR2(100);

    oracle_addr2_v         VARCHAR2(50);

    oracle_addr3_v         VARCHAR2(50);

    term_name_v		          ra_terms.name%TYPE;

    due_days_v             NUMBER;



    v_linea_con_error      VARCHAR2(1);

    v_error_message        VARCHAR2(2000);



  BEGIN



    print_log ( 'ajcl_bc_csa_pkg.ar_call_ws (+)' ); 



    print_log ('Headers are traversed to obtain the client and the payment term in the reprocesses that failed because that data was not found (+)');



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



        find_oracle_customer_p ( ch.dff_cust_vend, -- fk_cvno

                                 oracle_cust_id_v, 

                                 --

                                 oracle_cust_name_v, 

                                 oracle_cust_number_v,

                                 --

                                 oracle_addr_id_v,

                                 --

                                 oracle_addr1_v,

                                 oracle_addr2_v,

                                 oracle_addr3_v );

        -- 20231003



        print_log ( 'Customer ID: ' || oracle_cust_id_v || '|' ||

                    'Customer Name: ' || oracle_cust_name_v || '|' ||

                    'Customer Number: ' || oracle_cust_number_v || '|' ||

                    'Address ID: ' || oracle_addr_id_v || '|' ||

                    'Address1: ' || oracle_addr1_v || '|' ||

                    'Address2: ' || oracle_addr2_v || '|' ||

                    'Address3: ' || oracle_addr3_v);



        term_name_v := NULL;

        due_days_v := NULL;



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

				        print_log ( 'Payment term not found for customer' );



          WHEN OTHERS THEN

		          RAISE;



        END;



        UPDATE ajcl_bc_csa_ar_headers

           SET termName = term_name_v,

               termDueDate = TO_CHAR(TO_DATE(NVL(ch.transactionDate,ch.glDate),'YYYY-MM-DD') + due_days_v,'YYYY-MM-DD'),

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



        UPDATE ajcl_bc_csa_ar_lines

           SET termName = term_name_v,

               termDueDate = TO_CHAR(TO_DATE(NVL(ch.transactionDate,ch.glDate),'YYYY-MM-DD') + due_days_v,'YYYY-MM-DD'),

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



      UPDATE ajcl_bc_csa_ar_headers

         SET -- Se ponen estos valores para que lo levante el proceso

             request_id = gv_request_id,

             status = 'NEW',

             error_message = NULL,

             --

             reprocess = 'Y'

       WHERE bc_environment = gv_bc_environment

         AND transactionno = ch.transactionno

         AND class = ch.class

         AND request_id = ch.request_id;



      UPDATE ajcl_bc_csa_ar_lines

         SET -- Se ponen estos valores para que lo levante el proceso

             request_id = gv_request_id,

             status = 'NEW',

             error_message = NULL

       WHERE bc_environment = gv_bc_environment

         AND transactionno = ch.transactionno

         AND class = ch.class

         AND request_id = ch.request_id;



    END LOOP;



    print_log ('Headers are traversed to obtain the client and the payment term in the reprocesses that failed because that data was not found (-)');



    print_log ('Transactions with no customer number are updated to ERROR (+)');



    -- Se actualizan a ERROR las que no tienen customer number

    UPDATE ajcl_bc_csa_ar_headers

       SET status = 'ERROR',

           error_message = 'Customer not found for Source ID ' || dff_cust_vend

     WHERE billtocustomerno IS NULL

       AND request_id = gv_request_id

       AND bc_environment = gv_bc_environment;



    print_log ('Transactions with no customer number are updated to ERROR (-)');



    COMMIT;



    FOR ch IN c_headers LOOP



      print_log ('transactionNo: ' || ch.transactionNo);

      print_log ('billtocustomerno: ' || ch.billtocustomerno);



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

        APEX_JSON.write('csaPKSeqNumber',cl.dff_pk_seq_number,TRUE); 

        APEX_JSON.write('csaSeqofCharge',cl.dff_seq_of_charge,TRUE); 

        APEX_JSON.write('csaCreationDate',cl.dff_creation_date,TRUE); 

        APEX_JSON.write('csaOrderNo',cl.dff_order_no,TRUE);   

        APEX_JSON.write('csaStationId',cl.dff_station_id,TRUE);   

        APEX_JSON.write('csaSubAccount',cl.dff_sub_account,TRUE);   

        APEX_JSON.write('csaDivision',cl.dff_division,TRUE);  

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



          UPDATE ajcl_bc_csa_ar_lines

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



          UPDATE ajcl_bc_csa_ar_lines

             SET status = 'SENT',

                 error_message = NULL,

                 json_data = v_body_line,

                 json_data_response = v_clob_result_line

           WHERE transactionNo = ch.transactionNo

             AND billtocustomerno = ch.billtocustomerno

             AND lineNo = cl.lineNo

             AND request_id = cl.request_id

             AND bc_environment = gv_bc_environment;



          print_log ( 'Line was sent successfully.' );



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

        -- Se usan solo en CSA

        APEX_JSON.write('invoiceReference1',ch.invoiceReference1,true);

        APEX_JSON.write('invoiceReference2',ch.invoiceReference2,true);



        -- nuevos logistics

        APEX_JSON.write('source','CSA');

        APEX_JSON.write('csaHousebill',ch.dff_housebill,true);

        APEX_JSON.write('csaMaxCSAPKSeqNo',ch.dff_max_csa_pk_seq,true);

        APEX_JSON.write('csaCustomerVendor',ch.dff_cust_vend,true);

        APEX_JSON.write('csaSeqNum',ch.dff_seq_num,true);

        APEX_JSON.write('csaFileExtractNumber',ch.dff_file_extract_number,true);

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



          UPDATE ajcl_bc_csa_ar_headers

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



          UPDATE ajcl_bc_csa_ar_headers

             SET status = 'SENT',

                 error_message = NULL,

                 json_data = v_body_header,

                 json_data_response = v_clob_result_header

           WHERE transactionNo = ch.transactionNo

             AND billtocustomerno = ch.billtocustomerno

             AND class = ch.class

             AND request_id = ch.request_id

             AND bc_environment = gv_bc_environment;



          print_log ( 'Header was sent successfully.' );



        END IF;



      ELSE



        UPDATE ajcl_bc_csa_ar_headers

           SET status = 'ERROR',

               error_message = 'An error occurred on some line of the document',

               request_id = gv_request_id

         WHERE transactionNo = ch.transactionNo

           AND billtocustomerno = ch.billtocustomerno

           AND class = ch.class

           AND request_id = ch.request_id

           AND bc_environment = gv_bc_environment;



      END IF;



      p_trx_count := NVL(p_trx_count,0) + 1;



    END LOOP;



    p_status := 'S';

    print_log('ajcl_bc_csa_pkg.ar_call_ws (-)' ); 



  EXCEPTION

    WHEN OTHERS THEN

      print_log('ajcl_bc_csa_pkg.ar_call_ws (!)');

      p_status := 'E';       



  END ar_call_ws;



  PROCEDURE ar_call_job ( p_status          OUT   VARCHAR2 ) IS



    v_object_id        NUMBER;

    v_status           VARCHAR2(20);

    v_clob_response    CLOB;



  BEGIN



    print_log ( 'ajcl_bc_csa_pkg.ar_call_job (+)' ); 



    v_object_id := ajcl_bc_ws_utils_pkg.get_object_id_f ( 'SALES DOCUMENTS' ); 

    print_log ( 'v_object_id: ' || v_object_id || ' - ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24:MI:SS'));



    v_clob_response := ajcl_bc_ws_utils_pkg.run_job_queue_f ( p_bc_environment => gv_bc_environment,

                                                              p_company_id => gv_bc_company_id,

                                                              p_object_id => v_object_id );



    IF ( UPPER(v_clob_response) LIKE '%"ERROR":%' ) THEN



      print_log('An error occurred while running Sales Invoices Logistics job.');

      v_status := 'ERROR';

      p_status := 'E';



    ELSE



      print_log('Sales Invoices Logistics job was executed successfully.');

      v_status := 'SUCCESS';

      p_status := 'S';



    END IF;



    -- Se inserta registro de control

    INSERT

      INTO ajcl_bc_csa_ar_control

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



    print_log ( 'ajcl_bc_csa_pkg.ar_call_job (-)' );    



  EXCEPTION    

    WHEN OTHERS THEN

      p_status := 'E';

      print_log ( 'Not caught error when calling job, Error: ' || SQLERRM );

      print_log ('ajcl_bc_csa_pkg.ar_call_job (!)');



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

        FROM ajcl_bc_csa_ar_lines

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



    print_log ('ajcl_bc_csa_pkg.ar_delete_inbound_records (+)');



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



    print_log ('ajcl_bc_csa_pkg.ar_delete_inbound_records (-)');



  END ar_delete_inbound_records;



  PROCEDURE ar_call_status ( p_status          OUT   VARCHAR2 ) IS



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



    print_log ( 'ajcl_bc_csa_pkg.ar_call_status (+)' ); 



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



    FOR cs IN c_status ( v_clob_result ) LOOP



      IF ( cs.status != 'Success' ) THEN



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

        UPDATE ajcl_bc_csa_ar_headers

           SET status = 'REJECTED',

               error_message = cs.statusRemarks

         WHERE request_id = gv_request_id

           AND transactionNo = cs.transactionNo

           AND bc_environment = gv_bc_environment;



        -- Se actualiza el status de sus lineas   

        UPDATE ajcl_bc_csa_ar_lines

           SET status = 'REJECTED'

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND transactionNo = cs.transactionNo;



        -- Se borra cabecera y lineas de las tablas inbound

        ar_delete_inbound_records ( p_transactionNo => cs.transactionno,

                                    p_billToCustomerNo => cs.billToCustomerNo,

                                    p_class => cs.class );



      ELSE



        -- Se actualiza la tabla custom con el status IMPORTED

        UPDATE ajcl_bc_csa_ar_headers

           SET status = 'SUCCESS'

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND transactionNo = cs.transactionNo;



        -- Se actualizan sus lineas   

        UPDATE ajcl_bc_csa_ar_lines

           SET status = 'SUCCESS'

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND transactionNo = cs.transactionNo;



      END IF;



    END LOOP;



    p_status := 'S';



    print_log ( 'ajcl_bc_csa_pkg.ar_call_status (-)' );    



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      print_log (v_error_message);

      print_log ('ajcl_bc_csa_pkg.call_status (!)');



    WHEN others THEN

      p_status := 'E';

      print_log ( 'Uncaught error when calling query status. Error: ' || SQLERRM );

      print_log ('ajcl_bc_csa_pkg.call_status (!)');



  END ar_call_status;



  -- GL ------------------------------------------------------------------------------------------------------------------------

  PROCEDURE create_je_line ( p_journaltemplatename            IN   VARCHAR2,

                             p_journalbatchname               IN   VARCHAR2,

                             p_oraclelineno                   IN   NUMBER,

                             p_documentno                     IN   VARCHAR2,

                             p_postingdate                    IN   VARCHAR2,

                             p_userjesourcename               IN   VARCHAR2,

                             p_userjecategoryname             IN   VARCHAR2,

                             p_company                        IN   VARCHAR2,

                             p_account                        IN   VARCHAR2,

                             p_department                     IN   VARCHAR2,

                             p_destination                    IN   VARCHAR2,

                             p_office                         IN   VARCHAR2,

                             p_origin                         IN   VARCHAR2,

                             p_division                       IN   VARCHAR2,

                             p_entereddr                      IN   NUMBER,

                             p_enteredcr                      IN   NUMBER,

                             p_description                    IN   VARCHAR2,

                             p_worksheetnumber                IN   VARCHAR2,

                             p_csaseqnumber                   IN   VARCHAR2,

                             p_csaorderno                     IN   VARCHAR2,

                             p_csacustomervendorno            IN   VARCHAR2,

                             p_csaoraclevendornumber          IN   VARCHAR2,

                             p_csaoraclevendorname            IN   VARCHAR2,

                             p_csalinenumber                  IN   VARCHAR2,

                             p_csaquantity                    IN   VARCHAR2,

                             p_csastation                     IN   VARCHAR2,

                             p_csacreationdate                IN   VARCHAR2,

                             p_csavendorreference             IN   VARCHAR2,

                             p_csasubaccount                  IN   VARCHAR2,

                             p_csadivision                    IN   VARCHAR2,

                             p_csaextractfilenumber           IN   VARCHAR2

                             -- 20240930

                             -- ,p_type                           IN   VARCHAR2 DEFAULT NULL 

                             -- 20240930

                             ) IS 



    currency_code_c    gl_interface.currency_code%TYPE := 'USD';

    v_jelineid         NUMBER;



  BEGIN



    print_log ( 'ajcl_bc_csa_pkg.create_je_line (+)' );



    print_log ( 'Inserting into ajcl_bc_csa_gl_lines with values: ' ||

                 p_journaltemplatename || ', ' || p_journalbatchname || ', ' || p_oraclelineno || ', ' ||

                 p_documentno || ', ' || p_postingdate || ', ' || p_userjesourcename || ', ' ||

                 p_userjecategoryname || ', ' || p_company || ', ' || p_department || ', ' ||

                 p_account || ', ' || p_destination || ', ' ||

                 p_office || ', ' || p_origin || ', ' || p_division || ', ' || p_entereddr || ', ' ||

                 p_enteredcr || ', ' || p_description || ', ' || p_worksheetnumber || ', ' ||

                 p_csaseqnumber || ', ' || p_csaorderno || ', ' ||

                 p_csacustomervendorno || ', ' || p_csaoraclevendornumber || ', ' || p_csaoraclevendorname || ', ' ||

                 p_csalinenumber || ', ' || p_csaquantity || ', ' || p_csastation || ', ' ||

                 p_csacreationdate || ', ' || p_csavendorreference || ', ' || p_csasubaccount || ', ' ||

                 p_csadivision || ', ' || p_csaextractfilenumber );



      SELECT AJCL_BC_JE_LINE_ID_S.NEXTVAL

        INTO v_jelineid

        FROM DUAL; 



      -- Create the line

      INSERT

        INTO ajcl_bc_csa_gl_lines

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

             entereddr,

             enteredcr,

             description,

             worksheetnumber,

             oraclelineno,

             --

             dff_seq_number,

             dff_order_no,

             dff_customer_vendor_no,

             dff_oracle_vendor_number,

             dff_oracle_vendor_name,

             dff_line_number,

             dff_quantity,

             dff_station,

             dff_creation_date,

             dff_vendor_reference,

             dff_sub_account,

             dff_division,

             dff_extract_file_number,

             -- dff_trx_currency_code,

             -- dff_trx_orig_curr_amount,

             -- dff_trx_contract_rate,

             jelineid,

             -- 20240930

             -- type,

             -- 20240930

             --

             status,

             creation_date,

             created_by,

             last_update_date,

             last_updated_by,

             request_id )

    VALUES ( gv_bc_environment,

             p_journaltemplatename,

             p_journalbatchname,

             p_documentno,

             p_postingdate,

             p_userjesourcename,

             p_userjecategoryname,

             p_account,

             p_company,

             p_department,

             p_destination,

             p_office,

             p_origin,

             p_division,

             currency_code_c,

             p_entereddr,

             p_enteredcr,

             p_description,

             p_worksheetnumber,

             p_oraclelineno,

             --

             p_csaseqnumber,

             p_csaorderno,

             p_csacustomervendorno,

             p_csaoraclevendornumber,

             p_csaoraclevendorname,

             p_csalinenumber,

             p_csaquantity,

             p_csastation,

             p_csacreationdate,

             p_csavendorreference,

             p_csasubaccount,

             p_csadivision,

             p_csaextractfilenumber,

             -- p_csatrxcurrencycode,

             -- p_csatrxorigcurramount,

             -- p_csatrxcontractrate,

             --

             v_jelineid,

             -- 20240930

             -- p_type,

             -- 20240930

             --

             'NEW', -- status

             SYSDATE, -- creation_date

             gv_user_id, -- created_by

             SYSDATE, -- last_update_date

             gv_user_id, -- last_updated_by

             gv_request_id );          



    IF ( SQL%ROWCOUNT > 0 ) THEN



      print_log ('1 record inserted into ajcl_bc_csa_gl_lines.');



    END IF;



    print_log ( 'ajcl_bc_csa_pkg.create_je_line (-)' );



  END create_je_line;



  PROCEDURE gl_generate_document_no_p IS



    -- Documents

      CURSOR c_documents IS

      SELECT documentno, 

             userjesourcename, 

             userjecategoryname

        FROM ajcl_bc_csa_gl_lines

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

    GROUP BY documentno, 

             userjesourcename, 

             userjecategoryname

    ORDER BY documentno, 

             userjesourcename, 

             userjecategoryname;



    v_documentno_ant   ajcl_bc_csa_gl_lines.documentno%TYPE;

    v_seq              NUMBER; 



  BEGIN



    print_log ( 'ajcl_bc_csa_pkg.gl_generate_document_no_p (+)' );



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



      UPDATE ajcl_bc_csa_gl_lines

         SET documentno = documentno || '.' || v_seq

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND documentno = cd.documentno

         AND userjesourcename = cd.userjesourcename

         AND userjecategoryname = cd.userjecategoryname;



    END LOOP;



    -- COMMIT;



    print_log ( 'ajcl_bc_csa_pkg.gl_generate_document_no_p (-)' );



  END gl_generate_document_no_p;



  PROCEDURE gl_generate_line_number_p IS



    -- Documents

      CURSOR c_documents IS

      SELECT documentno

        FROM ajcl_bc_csa_gl_lines

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

    GROUP BY documentno

    ORDER BY documentno;



      -- Lines

      CURSOR c_lines ( p_documentno   IN   VARCHAR2 ) IS

      SELECT cl.rowid row_id,

             cl.*

        FROM ajcl_bc_csa_gl_lines cl

       WHERE documentno = p_documentno

         AND request_id = gv_request_id

         AND bc_environment = gv_bc_environment

    ORDER BY dff_order_no;



    v_line_no   NUMBER;



  BEGIN



    print_log ( 'ajcl_bc_csa_pkg.gl_generate_line_number_p (+)' );



    FOR cd IN c_documents LOOP



      v_line_no := 0;



      FOR cl IN c_lines ( p_documentno => cd.documentno ) LOOP



        v_line_no := v_line_no + 1;



        -- 20240930

        -- IF ( NVL(cl.type,'X') = 'ORACLE' ) THEN



          UPDATE ajcl_bc_csa_gl_lines

             SET oraclelineno = v_line_no

           WHERE request_id = cl.request_id

             AND bc_environment = gv_bc_environment

             AND documentno = cl.documentno

             -- AND account = cl.account

             -- AND dff_seq_number = cl.dff_seq_number

             AND rowid = cl.row_id;



        -- ELSE

        -- 20240930



          /*

          UPDATE ajcl_bc_csa_gl_lines

             SET oraclelineno = v_line_no

           WHERE request_id = cl.request_id

             AND bc_environment = gv_bc_environment

             AND documentno = cl.documentno

             AND account = cl.account

             AND dff_seq_number = cl.dff_seq_number;



          */



        -- 20240930     

        -- END IF;

        -- 20240930



      END LOOP;



    END LOOP;



    -- COMMIT;



    print_log ( 'ajcl_bc_csa_pkg.gl_generate_line_number_p (-)' );



  END gl_generate_line_number_p;



  PROCEDURE gl_insert_p ( p_status             OUT   VARCHAR2,

                          p_error_message   IN OUT   VARCHAR2 ) IS



      CURSOR sel_csa IS

      SELECT rowid gl_rowid, 

             csa_file_no, 

             pk_seqno, 

             fk_orderno, 

             fk_cvno, 

             fk_seqno,

             quantity, 

             createdate, 

             subaccount, 

             division, 

             gl_status,

             fk_serviceid, 

             invoiceamount, 

             refno, 

             gl_reversal_entryno,

             gl_reversal_ref_id, 

             gl_reversal_ref_name, 

             housebill, 

             worksheet

        FROM ajc_csa_interfaceAPAR

       WHERE aparcode = 'V'

         AND validation_status = 'Y'

         AND gl_status NOT IN ('INTERFACED','NONE')

    ORDER BY 18,3;



      CURSOR sel_rvrs IS

      SELECT housebill, 

             gl_status, 

             csa_file_no, 

             MAX(pk_seqno) max_pk_seqno

        FROM ajc_csa_interfaceAPAR a

       WHERE aparcode = 'V'

         AND validation_status = 'Y'

         AND gl_status LIKE '%RVRS%'

    GROUP BY housebill, 

             gl_status, 

             csa_file_no

    ORDER BY 1,3;



    CURSOR sel_je_lines ( p_entryno           NUMBER,

                          p_je_header_id      NUMBER, 

                          p_worksheetnumber   VARCHAR2 ) IS

    -- Posted Journals de BC

    SELECT journaltemplatename,

           -- 20250214

           -- journalbatchname,

           NVL(journalbatchname,gv_journal_batch_name) journalbatchname,

           -- 20250214

           TO_CHAR(oraclelineno) oraclelineno,

           documentNo,

           postingdate,

           userjesourcename,

           userjecategoryname,

           company,

           account,

           department,

           destination,

           office,

           origin,

           division,

           entereddr,

           enteredcr,

           description,

           -- 20241004

           -- worksheetnumber,

           worksheetno worksheetnumber,

           -- 20241004

           csaseqnumber,

           csaorderno,

           csacustomervendorno,

           csaoraclevendornumber,

           csaoraclevendorname,

           csalinenumber,

           csaquantity,

           csastation,

           csacreationdate,

           csavendorreference,

           csasubaccount,

           csadivision,

           csaextractfilenumber

           -- ,csatrxcurrencycode

           -- ,csatrxorigcurramount

           -- ,csatrxcontractrate

           -- 20240930

           ,'BC' type

           -- 20240930

      FROM ajcl_bc_gen_jnl_entries a

     WHERE bc_environment = gv_bc_environment

       -- 20241003 AND entryno = p_entryno

       AND a.documentno = ( SELECT b.documentno

                              FROM ajcl_bc_gen_jnl_entries b

                             WHERE bc_environment = gv_bc_environment

                               AND entryno = p_entryno

                               AND worksheetno = p_worksheetnumber )

       -- 20241003

       AND a.worksheetno = p_worksheetnumber

       AND gv_gl_match = 'BC'

       AND p_entryno IS NOT NULL 

     UNION

    -- Journals generados por este request_id, que estan pendientes de envio a BC

    SELECT journaltemplatename,

           journalbatchname,

           TO_CHAR(oraclelineno),

           documentNo,

           postingdate,

           userjesourcename,

           userjecategoryname,

           company,

           account,

           department,

           destination,

           office,

           origin,

           division,

           -1 * entereddr,

           -1 * enteredcr,

           description,

           worksheetnumber,

           TO_CHAR(dff_seq_number) csaseqnumber,

           TO_CHAR(dff_order_no) csaorderno,

           dff_customer_vendor_no csacustomervendorno,

           dff_oracle_vendor_number csaoraclevendornumber,

           dff_oracle_vendor_name csaoraclevendorname,

           TO_CHAR(dff_line_number) csalinenumber,

           TO_CHAR(dff_quantity) csaquantity,

           dff_station csastation,

           dff_creation_date csacreationdate,

           dff_vendor_reference csavendorreference,

           dff_sub_account csasubaccount,

           dff_division csadivision,

           dff_extract_file_number csaextractfilenumber

           -- ,dff_trx_currency_code csatrxcurrencycode

           -- ,TO_CHAR(dff_trx_orig_curr_amount) csatrxorigcurramount

           -- ,TO_CHAR(dff_trx_contract_rate) csatrxcontractrate

           -- 20240930

           ,'BC' type

           -- 20240930

      FROM ajcl_bc_csa_gl_lines

     WHERE status = 'NEW'

       AND request_id = gv_request_id

       AND bc_environment = gv_bc_environment

       AND worksheetnumber = p_worksheetnumber

       AND UPPER(userjecategoryname) IN (UPPER(gv_gl_category_cogs_accrual),UPPER(gv_gl_category_transit))

       AND p_entryno IS NULL

       -- 20241001

       AND p_je_header_id IS NULL

       -- 20241001

     UNION

    -- Journals de Oracle

    SELECT gv_journal_template_name journaltemplatename,

           gv_journal_batch_name journalbatchname,

           NULL oraclelineno,

           TO_CHAR(gv_request_id) || '.' || TO_CHAR(gv_gl_date,'YYYYMMDD') documentNo,

           -- 20241001 TO_CHAR(a.effective_date,'YYYY-MM-DD') postingdate,

           TO_CHAR(gv_gl_date,'YYYY-MM-DD') postingdate,

           -- 20241001

           e.user_je_source_name userjesourcename,

           d.user_je_category_name userjecategoryname,

           --

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'COMPANY',gcc.segment1) company,

           aba.bc_account account,

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'DEPARTMENT',gcc.segment3) department,

           /* -- 20241001

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'DESTINATION',

             DECODE(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                               p_oracle_value => gcc.segment5,

                                                               p_bc_dimension => 'OFFICE' ),NULL,gcc.segment5,'000') ) destination,

           */                                                    

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'DESTINATION',gcc.segment5) destination,

           /* -- 20241001

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'OFFICE',

             NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                            p_oracle_value => gcc.segment5,

                                                            p_bc_dimension => 'OFFICE'),'000') ) office,

           */

           NULL office, -- 20241001

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'ORIGIN',gcc.segment6) origin,

           ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,aba.bc_account,'DIVISION',

                     NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4',

                                                                    p_oracle_value => gcc.segment4,

                                                                    p_bc_dimension => 'DIVISION'),'000') ) division,

           a.entered_dr entereddr,

           a.entered_cr enteredcr,

           -- 20240930

           -- a.description description,

           SUBSTR(a.description,1,100) description,

           -- 20240930

           a.attribute11 worksheetnumber,

           a.attribute17 csaseqnumber,

           a.attribute2 csaorderno,

           a.attribute3 csacustomervendorno,

           a.attribute4 csaoraclevendornumber,

           a.attribute5 csaoraclevendorname,

           a.attribute6 csalinenumber,

           a.attribute14 csaquantity,

           a.attribute15 csastation,

           -- 20240930

           a.attribute16 csacreationdate,

           -- TO_CHAR(TO_DATE(a.attribute16,'YYYY/MM/DD HH24:MI:SS'),'YYYY-MM-DD'),

           -- 20240930

           a.attribute1 csavendorreference,

           a.attribute18 csasubaccount,

           a.attribute19 csadivision,

           a.attribute20 csaextractfilenumber

           -- ,a.attribute8 csatrxcurrencycode,

           -- ,a.attribute9 csatrxorigcurramount

           -- ,a.attribute10 csatrxcontractrate

           -- 20240930

           ,'ORACLE' type

           -- 20240930

      FROM gl_je_lines a, 

           gl_code_combinations gcc, 

           gl_je_headers c, 

           gl_je_categories_tl d, 

           gl_je_sources_tl e,

           ajc_bc_accounts aba

     WHERE a.je_header_id = p_je_header_id

       AND a.code_combination_id = gcc.code_combination_id

       AND a.attribute11 = p_worksheetnumber

       AND p_je_header_id > 0

       AND c.je_header_id = p_je_header_id

       AND e.je_source_name = c.je_source

       AND d.je_category_name = c.je_category

       AND gv_gl_match = 'ORACLE'

       AND p_entryno IS NULL

       AND p_je_header_id IS NOT NULL

       AND gcc.segment2 = aba.oracle_account;



    v_fk_seqno              INTEGER := 0;

    v_quantity              NUMBER := 0;

    v_gl_rev_ref_entryno    INTEGER;

    v_gl_reversal_ref_id    INTEGER;

    v_gl_proc_count         INTEGER := 0;

    v_je_line_desc          VARCHAR2(100);

    v_in_transit_account    VARCHAR2(30);

    v_fk_serviceid          VARCHAR2(2);

    v_fk_stationid          VARCHAR2(3);

    v_ora_vend_num          po_vendors.segment1%TYPE; 

    v_ora_vend_name         po_vendors.vendor_name%TYPE;

    v_destination           VARCHAR2(3);

    v_createdate            VARCHAR2(10); 

    v_subaccount            ajc_csa_interfaceAPAR.subaccount%TYPE; 

    v_division              ajc_csa_interfaceAPAR.division%TYPE;

    v_fk_orderno            ajc_csa_interfaceAPAR.fk_orderno%TYPE;

    v_fk_cvno               ajc_csa_interfaceAPAR.fk_cvno%TYPE;

    v_refno                 ajc_csa_interfaceAPAR.refno%TYPE;

    v_je_category           gl_interface.user_je_category_name%TYPE;

    v_gl_date               ajc_csa_interfaceAPAR.gl_date%TYPE;

    v_worksheet             ajc_csa_interfaceAPAR.worksheet%TYPE;



    v_cogs_company          VARCHAR2(200); 

    v_cogs_account          VARCHAR2(200); 

    v_cogs_department       VARCHAR2(200); 

    v_cogs_destination      VARCHAR2(200); 

    v_cogs_office           VARCHAR2(200); 

    v_cogs_origin           VARCHAR2(200); 

    v_cogs_division         VARCHAR2(200); 



    v_offset_company        VARCHAR2(200); 

    v_offset_account        VARCHAR2(200); 

    v_offset_department     VARCHAR2(200); 

    v_offset_destination    VARCHAR2(200); 

    v_offset_office         VARCHAR2(200); 

    v_offset_origin         VARCHAR2(200); 

    v_offset_division       VARCHAR2(200); 



    v_rev_company           VARCHAR2(200); 

    v_rev_account           VARCHAR2(200); 

    v_rev_department        VARCHAR2(200); 

    v_rev_destination       VARCHAR2(200); 

    v_rev_office            VARCHAR2(200); 

    v_rev_origin            VARCHAR2(200); 

    v_rev_division          VARCHAR2(200); 



    -- 20240930

    v_csacreationdate       VARCHAR2(10);

    -- 20240930



    no_data_to_process      EXCEPTION;



  BEGIN



    print_log ( 'ajcl_bc_csa_pkg.gl_insert_p (+)' );



    SELECT COUNT(*)

      INTO v_gl_proc_count

      FROM ajc_csa_interfaceAPAR

     WHERE gl_status NOT IN ('INTERFACED','NONE')

       AND validation_status = 'Y'

       AND aparcode = 'V';



    IF ( v_gl_proc_count = 0 ) THEN



      RAISE no_data_to_process;



    END IF;



    FOR sel_csa_rec IN sel_csa LOOP



      print_log ('housebill: ' || sel_csa_rec.housebill);

      print_log ('fk_orderno: ' || sel_csa_rec.fk_orderno);

      print_log ('fk_seqno: ' || sel_csa_rec.fk_seqno);

      print_log ('pk_seqno: ' || sel_csa_rec.pk_seqno);

      print_log ('fk_cvno: ' || sel_csa_rec.fk_cvno);

      print_log ('gl_status: ' || sel_csa_rec.gl_status);

      print_log ('gl_reversal_ref_name: ' || sel_csa_rec.gl_reversal_ref_name);

      print_log ('gl_reversal_entryno: ' || sel_csa_rec.gl_reversal_entryno);

      print_log ('gl_reversal_ref_id: ' || sel_csa_rec.gl_reversal_ref_id);



      -- Initialize variables

      BEGIN



        -- 20240905

        v_ora_vend_num := NULL;

        v_ora_vend_name := NULL;

        v_createdate := NULL;

        v_subaccount := NULL;

        v_division := NULL;

        -- 20240905



        SELECT segment1, 

               vendor_name, 

               TO_CHAR(NVL(sel_csa_rec.createdate, SYSDATE),'YYYY-MM-DD'), 

               NVL(sel_csa_rec.subaccount,gv_default_subaccount) subaccount, 

               NVL(sel_csa_rec.division,gv_default_division) division

          INTO v_ora_vend_num, 

               v_ora_vend_name, 

               v_createdate, 

               v_subaccount, 

               v_division

          -- FROM ajc_bplus_cust_xref,

          FROM ajcl_bc_cust_xref,

               po_vendors

         WHERE bc_environment = gv_bc_environment

           AND bp_cust_id = sel_csa_rec.fk_cvno

           AND source_type = 'VENDOR'

           AND source = 'CSA'

           AND oracle_vendor_id = vendor_id;



      EXCEPTION

        WHEN OTHERS THEN

          print_log ('Vendor not found for bc_cust_id: ' || sel_csa_rec.fk_cvno);

          v_ora_vend_num := NULL;

          v_ora_vend_name := NULL;

          v_createdate := TO_CHAR(NVL(sel_csa_rec.createdate, SYSDATE),'YYYY-MM-DD');

          v_subaccount := NVL(sel_csa_rec.subaccount,gv_default_subaccount);

          v_division := NVL(sel_csa_rec.division,gv_default_division);



      END;



      v_je_line_desc := SUBSTR('Housebill:' || sel_csa_rec.housebill || 

                               '|Quantity:' || sel_csa_rec.quantity ||

                               '|Service ID:' || sel_csa_rec.fk_serviceid || 

                               '|Vendor:' || v_ora_vend_name || 

                               '|Vendor No.:' || v_ora_vend_num,1,100);



      print_log ('JE Line Descr: ' || v_je_line_desc);



      SELECT fk_stationid

        INTO v_fk_stationid

        FROM ajc_csa_interfaceAPAR

       WHERE csa_file_no = sel_csa_rec.csa_file_no

         AND pk_seqno = ( SELECT MAX(pk_seqno)

                            FROM ajc_csa_interfaceAPAR

                           WHERE housebill = sel_csa_rec.housebill 

                             -- 20231228

                             AND csa_file_no = sel_csa_rec.csa_file_no

                             -- 20231228 

                             );



      print_log ('Stationid: ' || v_fk_stationid);



      IF ( v_fk_stationid IS NOT NULL ) THEN



        SELECT destination

          INTO v_destination

          FROM ajcl_bc_csa_station_id

         WHERE bc_environment = gv_bc_environment

           AND station_id = v_fk_stationid;



      END IF;



      print_log ('Destination: ' || v_destination);



      -- Retrieve accounting 

      BEGIN



        v_cogs_account := NULL;

        v_cogs_company := NULL;

        v_cogs_department := NULL;

        v_cogs_destination := NULL;

        v_cogs_office := NULL;

        v_cogs_origin := NULL;

        v_cogs_division := NULL;



        v_offset_account := NULL;

        v_offset_company := NULL;

        v_offset_department := NULL;

        v_offset_destination := NULL;

        v_offset_office := NULL;

        v_offset_origin := NULL;

        v_offset_division := NULL;



        v_rev_account := NULL;

        v_rev_company := NULL;

        v_rev_department := NULL;

        v_rev_destination := NULL;

        v_rev_office := NULL;

        v_rev_origin := NULL;

        v_rev_division := NULL;



        SELECT -- CGS

               cgs_company,

               cgs_accountno,

               cgs_department,

               cgs_destination,

               cgs_office,

               cgs_origin,

               cgs_division,

               -- OFFSET

               offset_company,

               offset_accountno,

               offset_department,

               offset_destination,

               offset_office,

               offset_origin,

               offset_division,

               -- REVENUE

               rev_company,

               rev_accountno,

               rev_department,

               rev_destination,

               rev_office,

               rev_origin,

               rev_division 

          INTO -- COGS

               v_cogs_company,

               v_cogs_account,

               v_cogs_department,

               v_cogs_destination,

               v_cogs_office,

               v_cogs_origin,

               v_cogs_division,

               -- OFFSET

               v_offset_company,

               v_offset_account,

               v_offset_department,

               v_offset_destination,

               v_offset_office,

               v_offset_origin,

               v_offset_division,

               -- REVENUE

               v_rev_company,

               v_rev_account,

               v_rev_department,

               v_rev_destination,

               v_rev_office,

               v_rev_origin,

               v_rev_division

          FROM ajcl_bc_ies_items

         WHERE bc_environment = gv_bc_environment

           AND charge_type_code = sel_csa_rec.fk_serviceid

           AND business_line = '76'

           AND NVL(inactive_date, SYSDATE + 1) > SYSDATE;



      EXCEPTION

        WHEN NO_DATA_FOUND THEN

          print_log ('Could not retrieve accounting');



      END;



      v_cogs_destination := v_destination;



      print_log ('COGS account: ' || v_cogs_company || '.' || v_cogs_account || '.' || 

                                     v_cogs_department || '.' || v_cogs_destination || '.' || 

                                     v_cogs_office || '.' || v_cogs_origin || '.' || 

                                     v_cogs_division );

      print_log ('Offset account: ' || v_offset_company || '.' || v_offset_account || '.' || 

                                       v_offset_department || '.' || v_offset_destination || '.' || 

                                       v_offset_office || '.' || v_offset_origin || '.' || 

                                       v_offset_division );

      print_log ('Revenue account: ' || v_rev_company || '.' || v_rev_account || '.' || 

                                        v_rev_department || '.' || v_rev_destination || '.' || 

                                        v_rev_office || '.' || v_rev_origin || '.' || 

                                        v_rev_division );



      -- print_log ('COGS account=' || v_cogs_account);

      -- print_log ('Offset account=' || v_offset_account);

      -- print_log ('Revenue account=' || v_revenue_account);



      SELECT MAX(gl_date)

        INTO v_gl_date

        FROM ajc_csa_interfaceAPAR

       WHERE housebill = sel_csa_rec.housebill

         AND validation_status = 'Y'

         -- 20231228

         AND csa_file_no = sel_csa_rec.csa_file_no;

         -- 20231228



      print_log ('GL Date: ' || v_gl_date);



      -- Populate gl_interface 

      IF ( sel_csa_rec.gl_status LIKE 'COGS%' ) THEN



        create_je_line ( p_journaltemplatename => gv_journal_template_name,

                         p_journalbatchname => gv_journal_batch_name, 

                         p_oraclelineno => NULL, -- sel_csa_rec.fk_seqno,

                         p_documentno => TO_CHAR(gv_request_id) || '.' || TO_CHAR(v_gl_date,'YYYYMMDD'), 

                         p_postingdate => TO_CHAR(v_gl_date,'YYYY-MM-DD'), 

                         p_userjesourcename => gv_csa_je_source, 

                         p_userjecategoryname => gv_gl_category_cogs_accrual, 

                         p_company => v_cogs_company,

                         p_account => v_cogs_account,

                         p_department => v_cogs_department,

                         p_destination => v_cogs_destination,

                         p_office => v_cogs_office,

                         p_origin => v_cogs_origin,

                         p_division => v_cogs_division,

                         p_entereddr => sel_csa_rec.invoiceamount,

                         p_enteredcr => 0, 

                         p_description => v_je_line_desc, 

                         p_worksheetnumber => sel_csa_rec.worksheet, 

                         p_csaseqnumber => sel_csa_rec.pk_seqno, 

                         p_csaorderno => sel_csa_rec.fk_orderno,

                         p_csacustomervendorno => sel_csa_rec.fk_cvno, 

                         p_csaoraclevendornumber => v_ora_vend_num,

                         p_csaoraclevendorname => v_ora_vend_name, 

                         p_csalinenumber => sel_csa_rec.fk_seqno,

                         p_csaquantity => sel_csa_rec.quantity,

                         p_csastation => v_fk_stationid, 

                         p_csacreationdate => v_createdate, 

                         p_csavendorreference => sel_csa_rec.refno, 

                         p_csasubaccount => v_subaccount, 

                         p_csadivision => v_division,

                         p_csaextractfilenumber => sel_csa_rec.csa_file_no );



        create_je_line ( p_journaltemplatename => gv_journal_template_name, 

                         p_journalbatchname => gv_journal_batch_name,

                         p_oraclelineno => NULL, -- sel_csa_rec.fk_seqno, 

                         p_documentno => TO_CHAR(gv_request_id) || '.' || TO_CHAR(v_gl_date,'YYYYMMDD'), 

                         p_postingdate => TO_CHAR(v_gl_date,'YYYY-MM-DD'), 

                         p_userjesourcename => gv_csa_je_source, 

                         p_userjecategoryname => gv_gl_category_cogs_accrual, 

                         p_company => v_offset_company,

                         p_account => v_offset_account,

                         p_department => v_offset_department,

                         p_destination => v_offset_destination,

                         p_office => v_offset_office,

                         p_origin => v_offset_origin,

                         p_division => v_offset_division,

                         p_entereddr => 0, 

                         p_enteredcr => sel_csa_rec.invoiceamount,

                         p_description => v_je_line_desc, 

                         p_worksheetnumber => sel_csa_rec.worksheet, 

                         p_csaseqnumber => sel_csa_rec.pk_seqno, 

                         p_csaorderno => sel_csa_rec.fk_orderno,

                         p_csacustomervendorno => sel_csa_rec.fk_cvno, 

                         p_csaoraclevendornumber => v_ora_vend_num, 

                         p_csaoraclevendorname => v_ora_vend_name, 

                         p_csalinenumber => sel_csa_rec.fk_seqno, 

                         p_csaquantity => sel_csa_rec.quantity, 

                         p_csastation => v_fk_stationid, 

                         p_csacreationdate => v_createdate, 

                         p_csavendorreference => sel_csa_rec.refno, 

                         p_csasubaccount => v_subaccount, 

                         p_csadivision => v_division, 

                         p_csaextractfilenumber => sel_csa_rec.csa_file_no );



      END IF;



      IF ( sel_csa_rec.gl_status LIKE 'INTRANSIT%' ) THEN



        create_je_line ( p_journaltemplatename => gv_journal_template_name, 

                         p_journalbatchname => gv_journal_batch_name, 

                         p_oraclelineno => NULL, -- sel_csa_rec.fk_seqno, 

                         p_documentno => TO_CHAR(gv_request_id) || '.' || TO_CHAR(v_gl_date,'YYYYMMDD'), 

                         p_postingdate => TO_CHAR(v_gl_date,'YYYY-MM-DD'), 

                         p_userjesourcename => gv_csa_je_source, 

                         p_userjecategoryname => gv_gl_category_transit, 

                         p_company => v_rev_company,

                         p_account => v_rev_account,

                         p_department => v_rev_department,

                         p_destination => v_rev_destination,

                         p_office => v_rev_office,

                         p_origin => v_rev_origin,

                         p_division => v_rev_division,

                         p_entereddr => sel_csa_rec.invoiceamount, 

                         p_enteredcr => 0, 

                         p_description => v_je_line_desc, 

                         p_worksheetnumber => sel_csa_rec.worksheet, 

                         p_csaseqnumber => sel_csa_rec.pk_seqno,

                         p_csaorderno => sel_csa_rec.fk_orderno, 

                         p_csacustomervendorno => sel_csa_rec.fk_cvno, 

                         p_csaoraclevendornumber => v_ora_vend_num,

                         p_csaoraclevendorname => v_ora_vend_name, 

                         p_csalinenumber => sel_csa_rec.fk_seqno, 

                         p_csaquantity => sel_csa_rec.quantity, 

                         p_csastation => v_fk_stationid, 

                         p_csacreationdate => v_createdate,

                         p_csavendorreference => sel_csa_rec.refno, 

                         p_csasubaccount => v_subaccount, 

                         p_csadivision => v_division, 

                         p_csaextractfilenumber => sel_csa_rec.csa_file_no );



        create_je_line ( p_journaltemplatename => gv_journal_template_name, 

                         p_journalbatchname => gv_journal_batch_name, 

                         p_oraclelineno => NULL, -- sel_csa_rec.fk_seqno,

                         p_documentno => TO_CHAR(gv_request_id) || '.' || TO_CHAR(v_gl_date,'YYYYMMDD'), 

                         p_postingdate => TO_CHAR(v_gl_date,'YYYY-MM-DD'),

                         p_userjesourcename => gv_csa_je_source,

                         p_userjecategoryname => gv_gl_category_transit, 

                         p_company => v_offset_company,

                         p_account => v_offset_account,

                         p_department => v_offset_department,

                         p_destination => v_offset_destination,

                         p_office => v_offset_office,

                         p_origin => v_offset_origin,

                         p_division => v_offset_division,

                         p_entereddr => 0, 

                         p_enteredcr => sel_csa_rec.invoiceamount, 

                         p_description => v_je_line_desc, 

                         p_worksheetnumber => sel_csa_rec.worksheet,

                         p_csaseqnumber => sel_csa_rec.pk_seqno, 

                         p_csaorderno => sel_csa_rec.fk_orderno, 

                         p_csacustomervendorno => sel_csa_rec.fk_cvno,

                         p_csaoraclevendornumber => v_ora_vend_num, 

                         p_csaoraclevendorname => v_ora_vend_name, 

                         p_csalinenumber => sel_csa_rec.fk_seqno, 

                         p_csaquantity => sel_csa_rec.quantity,

                         p_csastation => v_fk_stationid, 

                         p_csacreationdate => v_createdate, 

                         p_csavendorreference => sel_csa_rec.refno,

                         p_csasubaccount => v_subaccount, 

                         p_csadivision => v_division, 

                         p_csaextractfilenumber => sel_csa_rec.csa_file_no );



      END IF;



      -- Update gl_status to INTERFACED except rvrs records



      UPDATE ajc_csa_interfaceAPAR

         SET gl_status = 'INTERFACED',

             last_update_date = SYSDATE,

             last_updated_by = gv_user_id

       WHERE rowid = sel_csa_rec.gl_rowid

         AND gl_status NOT LIKE '%RVRS%';



    END LOOP; -- FOR sel_csa_rec IN sel_csa



    -- Process COGS Reversal or In Transit Reversal 

    FOR sel_rvrs_rec IN sel_rvrs LOOP



      print_log ('Processing file#/housebill/status: ' || sel_rvrs_rec.csa_file_no || '/' || sel_rvrs_rec.housebill || '/' || sel_rvrs_rec.gl_status);



      -- 20241004

      v_gl_rev_ref_entryno := NULL;

      v_gl_reversal_ref_id := NULL;

      gv_gl_match := NULL;

      -- 20241004



      SELECT DISTINCT 

             gl_reversal_entryno,

             worksheet

        INTO v_gl_rev_ref_entryno,

             v_worksheet

        FROM ajc_csa_interfaceAPAR

       WHERE pk_seqno = sel_rvrs_rec.max_pk_seqno

         AND validation_status = 'Y'

         AND gl_status LIKE '%RVRS%';



      -- print_log ( v_worksheet || 'SB1|v_gl_rev_ref_entryno: ' || v_gl_rev_ref_entryno );



      IF ( v_gl_rev_ref_entryno IS NOT NULL ) THEN



        -- 20241004

        gv_gl_match := 'BC';

        -- 20241004 



        print_log ('Reversal Ref Entry No.: ' || v_gl_rev_ref_entryno);



      ELSE 



        print_log ( 'v_gl_rev_ref_entryno IS NULL' );



        SELECT DISTINCT 

               gl_reversal_ref_id, 

               worksheet

          INTO v_gl_reversal_ref_id, 

               v_worksheet

          FROM ajc_csa_interfaceAPAR

         WHERE pk_seqno = sel_rvrs_rec.max_pk_seqno

           AND validation_status = 'Y'

           AND gl_status LIKE '%RVRS%';



        -- 20241004

        gv_gl_match := 'ORACLE';

        -- 20241004 



        print_log ('Reversal Ref id: ' || v_gl_reversal_ref_id);



      END IF;



      print_log ('Attribute11 to match: ' || v_worksheet);



      SELECT MAX(gl_date)

        INTO v_gl_date

        FROM ajc_csa_interfaceAPAR

       WHERE housebill = sel_rvrs_rec.housebill

         AND validation_status = 'Y'

         -- 20231228

         AND csa_file_no = sel_rvrs_rec.csa_file_no;

         -- 20231228



      print_log ('GL Date: ' || v_gl_date);



      -- print_log ( v_worksheet || 'SB2|v_gl_rev_ref_entryno: ' || v_gl_rev_ref_entryno || '|v_gl_reversal_ref_id: ' || v_gl_reversal_ref_id );



      -- Loop through the original JE lines and create reversal entries 

      FOR sel_je_lines_rec IN sel_je_lines ( p_entryno => v_gl_rev_ref_entryno,

                                             p_je_header_id => v_gl_reversal_ref_id, 

                                             p_worksheetnumber => v_worksheet ) LOOP



        -- print_log ( v_worksheet || 'SB3|sel_rvrs_rec.gl_status: ' || sel_rvrs_rec.gl_status );



        IF ( sel_rvrs_rec.gl_status LIKE '%COGS RVRS%' ) THEN



          v_je_category := gv_gl_cat_cogs_accrual_rev;



        END IF;



        IF ( sel_rvrs_rec.gl_status LIKE '%INTRANSIT RVRS%' ) THEN



          v_je_category := gv_gl_category_transit_rev;



        END IF;



        -- print_log ( v_worksheet || 'SB4|v_je_category: ' || v_je_category);



        -- 20240930

        IF ( sel_je_lines_rec.type = 'BC' ) THEN



          v_csacreationdate := sel_je_lines_rec.csacreationdate;



        ELSIF ( sel_je_lines_rec.type = 'ORACLE' ) THEN



          BEGIN



            v_csacreationdate := TO_CHAR(TO_DATE(sel_je_lines_rec.csacreationdate,'DD-MON-YY'),'YYYY-MM-DD'); 



          EXCEPTION

            WHEN OTHERS THEN



              BEGIN



                v_csacreationdate := TO_CHAR(TO_DATE(sel_je_lines_rec.csacreationdate,'YYYY-MM-DD'),'YYYY-MM-DD');



              EXCEPTION

                WHEN OTHERS THEN



                  BEGIN



                    v_csacreationdate := TO_CHAR(TO_DATE(sel_je_lines_rec.csacreationdate,'YYYY/MM/DD HH24:MI:SS'),'YYYY-MM-DD');



                  EXCEPTION

                    WHEN OTHERS THEN

                      v_csacreationdate := NULL; 



                  END;





              END;



          END;  



        END IF;

        -- 20240930



        create_je_line ( p_journaltemplatename => sel_je_lines_rec.journaltemplatename,

                         p_journalbatchname => sel_je_lines_rec.journalbatchname,

                         p_oraclelineno => sel_je_lines_rec.oraclelineno,

                         p_documentno => sel_je_lines_rec.documentNo,

                         -- 20241030 

                         -- p_postingdate => sel_je_lines_rec.postingdate,

                         p_postingdate => TO_CHAR(v_gl_date,'YYYY-MM-DD'),

                         -- 20241030

                         p_userjesourcename => sel_je_lines_rec.userjesourcename,

                         p_userjecategoryname => v_je_category, -- 20240625 sel_je_lines_rec.userjecategoryname,

                         p_company => sel_je_lines_rec.company,

                         p_account => sel_je_lines_rec.account,

                         p_department => sel_je_lines_rec.department,

                         p_destination => sel_je_lines_rec.destination,

                         p_office => sel_je_lines_rec.office,

                         p_origin => sel_je_lines_rec.origin,

                         p_division => sel_je_lines_rec.division,

                         -- 20241001 Se envia invertido

                         -- p_entereddr => sel_je_lines_rec.entereddr,

                         p_entereddr => sel_je_lines_rec.enteredcr,

                         -- p_enteredcr => sel_je_lines_rec.enteredcr,

                         p_enteredcr => sel_je_lines_rec.entereddr,

                         -- 20241001

                         p_description => sel_je_lines_rec.description,

                         p_worksheetnumber => sel_je_lines_rec.worksheetnumber,

                         p_csaseqnumber => sel_je_lines_rec.csaseqnumber,

                         p_csaorderno => sel_je_lines_rec.csaorderno,

                         p_csacustomervendorno => sel_je_lines_rec.csacustomervendorno,

                         p_csaoraclevendornumber => sel_je_lines_rec.csaoraclevendornumber,

                         p_csaoraclevendorname => sel_je_lines_rec.csaoraclevendorname,

                         p_csalinenumber => sel_je_lines_rec.csalinenumber,

                         p_csaquantity => sel_je_lines_rec.csaquantity,

                         p_csastation => sel_je_lines_rec.csastation,

                         -- 20240930 

                         -- p_csacreationdate => sel_je_lines_rec.csacreationdate,

                         p_csacreationdate => v_csacreationdate,

                         -- 20240930

                         p_csavendorreference => sel_je_lines_rec.csavendorreference,

                         p_csasubaccount => sel_je_lines_rec.csasubaccount,

                         p_csadivision => sel_je_lines_rec.csadivision,

                         p_csaextractfilenumber => sel_je_lines_rec.csaextractfilenumber

                         -- 20240930

                         -- ,p_type => sel_je_lines_rec.type

                         -- 20240930

                         );



      END LOOP;  -- FOR sel_je_lines_rec IN sel_je_lines 



      -- Update gl_status to INTERFACED 

      UPDATE ajc_csa_interfaceAPAR

         SET gl_status = 'INTERFACED',

             last_update_date = SYSDATE,

             last_updated_by = gv_user_id

       WHERE housebill = sel_rvrs_rec.housebill

         AND validation_status = 'Y'

         AND gl_status NOT IN ('INTERFACED','NONE')

         -- 20240917

         AND csa_file_no = sel_rvrs_rec.csa_file_no

         -- 20240917

         ;



    END LOOP;



    -- Se genera el documentno por documentno, source y category

    gl_generate_document_no_p;



    -- Se numeran las lineas por documentno

    gl_generate_line_number_p;



    p_status := 'S';



    print_log('ajcl_bc_csa_pkg.gl_insert_p (-)');



  EXCEPTION

    WHEN no_data_to_process THEN

      p_status := 'W';

      p_error_message := 'No data to process.';

    WHEN OTHERS THEN

      p_status := 'E';

      p_error_message := 'Error: ' || SQLERRM;

      print_log('ajcl_bc_csa_pkg.gl_insert_p (!). Error: ' || SQLERRM);



  END gl_insert_p;



  PROCEDURE gl_insert_json_table ( p_status_code            IN OUT VARCHAR2,

                                   p_error_message          IN OUT VARCHAR2,

                                   p_record_count               IN NUMBER,

                                   p_json_number                IN NUMBER,

                                   p_json_data                  IN CLOB ) IS

  BEGIN



      INSERT 

        INTO ajcl_bc_csa_gl_jsons

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



  END gl_insert_json_table;  



  PROCEDURE gl_insert_request_table ( p_status_code            IN OUT VARCHAR2,

                                      p_error_message          IN OUT VARCHAR2,

                                      p_record_count           IN     NUMBER ) IS  

  BEGIN



      INSERT 

        INTO ajcl_bc_csa_gl_requests

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



  END gl_insert_request_table;



  PROCEDURE gl_generate_jsons ( p_journals_count   OUT   NUMBER,

                                p_error_message    OUT   VARCHAR2,

                                p_status           OUT   VARCHAR2 ) IS



      CURSOR c_journals IS

      SELECT *

        FROM ajcl_bc_csa_gl_lines

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



    print_log('ajcl_bc_csa_pkg.gl_generate_jsons (+)');



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



        APEX_JSON.open_object('body'); -- body{

        APEX_JSON.write('source','CSA');

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

        APEX_JSON.write('csaseqnumber',cj.dff_seq_number,true);

        APEX_JSON.write('csaorderno',cj.dff_order_no,true);

        APEX_JSON.write('csacustomervendorno',cj.dff_customer_vendor_no,true);

        APEX_JSON.write('csaoraclevendornumber',cj.dff_oracle_vendor_number,true);

        APEX_JSON.write('csaoraclevendorname',cj.dff_oracle_vendor_name,true);

        APEX_JSON.write('csalinenumber',cj.dff_line_number,true);

        APEX_JSON.write('csaquantity',cj.dff_quantity,true);

        APEX_JSON.write('csastation',cj.dff_station,true);

        APEX_JSON.write('csacreationdate',cj.dff_creation_date,true);

        APEX_JSON.write('csavendorreference',cj.dff_vendor_reference,true);

        APEX_JSON.write('csasubaccount',cj.dff_sub_account,true);

        APEX_JSON.write('csadivision',cj.dff_division,true);

        APEX_JSON.write('csaextractfilenumber',cj.dff_extract_file_number,true);

        -- APEX_JSON.write('csatrxcurrency',cj.dff_trx_currency_code,true);

        -- APEX_JSON.write('csatrxorigcurramount',cj.dff_trx_orig_curr_amount,true);

        -- APEX_JSON.write('csatrxcontractrate',cj.dff_trx_contract_rate,true);

        -- DFF

        --

        APEX_JSON.write('requestid',gv_request_id,true);

        APEX_JSON.close_object; -- } body



        APEX_JSON.close_object; -- }



        -- Se actualiza en la tabla de lineas

        UPDATE ajcl_bc_csa_gl_lines

           SET json_number = v_json_number,

               -- 20240917

               request_id = gv_request_id, -- Se pone el request_id actual a lo nuevo y a lo reprocesado

               -- 20240917

               error_message = NULL

         WHERE documentNo = cj.documentNo

           AND oraclelineno = cj.oraclelineno

           AND request_id = cj.request_id

           AND bc_environment = gv_bc_environment;



        -- COMMIT;



        IF ( v_split_quantity = gv_lines_per_json ) THEN



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



    print_log('ajcl_bc_csa_pkg.gl_generate_jsons (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('ajcl_bc_csa_pkg.gl_generate_jsons (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));

    WHEN others THEN

        v_error_message := 'Not caught error when creating JSON, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('ajcl_bc_csa_pkg.gl_generate_jsons (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));



  END gl_generate_jsons;



  PROCEDURE gl_call_ws ( p_error_message    IN OUT   VARCHAR2,

                         p_status           IN OUT   VARCHAR2 ) IS



      CURSOR c_jsons IS

      SELECT REPLACE(json_data,'\/','/') json_data,

             json_number

        FROM ajcl_bc_csa_gl_jsons

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

    ORDER BY json_number;



    v_url                     VARCHAR2(200);



    v_error_message           VARCHAR2(2000);

    e_cust_exception          EXCEPTION;

    v_clob_response           CLOB;



  BEGIN



    print_log('ajcl_bc_csa_pkg.gl_call_ws (+)');



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_batch_url_f ( p_bc_environment => gv_bc_environment,

                                                                p_entity => 'INBOUND JOURNALS',

                                                                p_subentity => 'LINES',

                                                                p_method => 'POST',

                                                                p_company_id => gv_bc_company_id );



    print_log ( 'v_url: ' || v_url );



    FOR cj IN c_jsons LOOP



      BEGIN



        print_log ( 'Json Data Number: ' || cj.json_number || ' - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') );



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



          UPDATE ajcl_bc_csa_gl_jsons

             SET json_data_response = v_clob_response,

                 last_update_date = sysdate

           WHERE request_id = gv_request_id

             AND bc_environment = gv_bc_environment

             AND json_number = cj.json_number;



        EXCEPTION

          WHEN OTHERS THEN

            v_error_message := 'Error al Actualizar tabla ajcl_bc_csa_gl_jsons con respuesta generada al llamar al Web Service. Error: ' || SQLERRM;

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

          v_error_message := 'Error al procesar JSON nro: ' || cj.json_number || ', Error:' || v_error_message;

          RAISE e_cust_exception;



        WHEN others THEN

          v_error_message := 'Error general al procesar JSON nro: ' || cj.json_number || ', Error:' || SQLERRM;

          RAISE e_cust_exception;



      END;



    END LOOP;



    print_log('ajcl_bc_csa_pkg.gl_call_ws (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_csa_pkg.gl_call_ws (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));



    WHEN others THEN

      v_error_message := 'Not caught error when calling web service. Error: '||sqlerrm;

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_csa_pkg.gl_call_ws (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));



  END gl_call_ws;



  PROCEDURE gl_call_job ( p_error_message   IN OUT   VARCHAR2,

                          p_status          IN OUT   VARCHAR2 ) IS



    v_object_id         NUMBER;

    v_error_message     VARCHAR2(2000);

    e_cust_exception    EXCEPTION;

    v_clob_response     CLOB;



  BEGIN



    print_log('ajcl_bc_csa_pkg.gl_call_job (+)');



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



      UPDATE ajcl_bc_csa_gl_requests

         SET json_job_response = v_clob_response,

             last_update_date = SYSDATE

       WHERE request_id = gv_request_id;



    EXCEPTION

      WHEN OTHERS THEN

        v_error_message := 'Error al Actualizar tabla ajcl_bc_csa_gl_requests con respuesta generada al llamar al Web Service. Error: ' || SQLERRM;

        RAISE e_cust_exception;



    END; 



    IF REPLACE(substr(v_clob_response,INSTR(v_clob_response,'"value"')+8,LENGTH(v_clob_response)),'}') in ('"Success"','""','"Job Queue Scheduled successfully."') THEN



      p_status := 'S';



    ELSE



      v_error_message := 'Job Error: ' || REPLACE(substr(v_clob_response,INSTR(v_clob_response,'"value"')+8,LENGTH(v_clob_response)),'}');

      print_log(v_clob_response);

      RAISE e_cust_exception;



    END IF;



    print_log('ajcl_bc_csa_pkg.gl_call_job (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_csa_pkg.gl_call_job (!). '|| TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));

    WHEN OTHERS THEN

      v_error_message := 'Job Error: ' || SQLERRM;

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_csa_pkg.gl_call_job (!). '|| TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));



  END gl_call_job;



  PROCEDURE gl_call_ws_staging_pending ( p_pending_rows     OUT VARCHAR2,

                                         p_error_message IN OUT VARCHAR2,

                                         p_status        IN OUT VARCHAR2 ) IS



    v_url               VARCHAR2(2000);



    v_error_message     VARCHAR2(2000);

    e_cust_exception    EXCEPTION;

    v_clob_response     CLOB;

    v_count             NUMBER := 0;  



  BEGIN



    print_log('ajcl_bc_csa_pkg.gl_call_ws_staging_pending (+)');



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



    print_log ( 'ajcl_bc_csa_pkg.gl_call_ws_staging_pending (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_csa_pkg.gl_call_ws_staging_pending (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));

    WHEN others THEN

      v_error_message := 'Not caught error when calling Staging Table, Error: ' || SQLERRM;

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_csa_pkg.gl_call_ws_staging_pending (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));



  END gl_call_ws_staging_pending;



  PROCEDURE gl_call_ws_staging ( p_error_message   IN OUT   VARCHAR2,

                                 p_status          IN OUT   VARCHAR2 ) IS



    v_url               VARCHAR2(2000);



    v_status            VARCHAR2(1);

    v_error_message     VARCHAR2(2000);

    e_cust_exception    EXCEPTION;

    v_clob_response     CLOB;    



  BEGIN



    print_log ( 'ajcl_bc_csa_pkg.gl_call_ws_staging (+)');



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



      UPDATE ajcl_bc_csa_gl_requests

         SET json_staging_response = v_clob_response,

             last_update_date = sysdate

       WHERE request_id = gv_request_id;



    EXCEPTION

      WHEN OTHERS THEN

        v_error_message := 'Error al Actualizar tabla ajcl_bc_csa_gl_requests con respuesta generada al llamar al Web Service ' || '. Error: ' || SQLERRM;

        RAISE e_cust_exception;



    END; 



    print_log ( 'ajcl_bc_csa_pkg.gl_call_ws_staging (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_csa_pkg.gl_call_ws_staging (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));

    WHEN others THEN

      v_error_message := 'Not caught error when calling Staging, Error: ' || SQLERRM;

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_csa_pkg.gl_call_ws_staging (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));



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



    v_error_message     VARCHAR2(2000);

    v_clob_result       CLOB;

    e_cust_exception    EXCEPTION;



  BEGIN



    print_log ( 'ajcl_bc_csa_pkg.gl_validate_ws_data (+)');



    BEGIN



      SELECT json_staging_response

        INTO v_clob_result

        FROM ajcl_bc_csa_gl_requests

       WHERE request_id = gv_request_id;



    EXCEPTION

      WHEN OTHERS THEN

        v_error_message := 'Error al obtener json almacenado en tabla ajcl_bc_csa_gl_requests del Web Service. Error: ' || SQLERRM;

        RAISE e_cust_exception;



    END;



    FOR cl IN c_lines ( v_clob_result ) LOOP



      BEGIN



        UPDATE ajcl_bc_csa_gl_lines abagl

           SET status = UPPER(cl.status),

               error_message = cl.statusremarks,

               last_update_date = SYSDATE

         WHERE abagl.documentno = cl.documentno

           AND abagl.oraclelineno = cl.oraclelineno

           AND request_id = gv_request_id

           AND bc_environment = gv_bc_environment;



      EXCEPTION

        WHEN OTHERS THEN

          v_error_message := 'Error updating table ajcl_bc_csa_gl_lines with response generated when calling Web Service. Error: ' || SQLERRM;

          RAISE e_cust_exception;



      END;



    END LOOP;



    -- COMMIT;



    p_status := 'S';



    print_log ( 'ajcl_bc_csa_pkg.gl_validate_ws_data (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_csa_pkg.gl_validate_ws_data (!)');

    WHEN others THEN

      v_error_message := 'Error not caught when updating transaction lines sent by the process. Error: ' || SQLERRM;

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_csa_pkg.gl_validate_ws_data (!)');



  END gl_validate_ws_data;   



  /*

  PROCEDURE gl_check_lines_status ( p_error_message   IN OUT   VARCHAR2,

                                    p_status          IN OUT   VARCHAR2 ) IS



    v_error_lines   NUMBER;

    e_error_lines   EXCEPTION;



  BEGIN



    print_log ( 'ajcl_bc_csa_pkg.gl_check_lines_status (+)');



      SELECT COUNT(1) 

        INTO v_error_lines

        FROM ajcl_bc_csa_gl_lines 

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND status IN ('ERROR','REJECTED');



    -- Si hay lineas con ERROR o REJECTED, se borran de la inbound

    IF ( v_error_lines != 0 ) THEN



      RAISE e_error_lines;



    END IF;



    p_status := 'S';



    print_log ( 'ajcl_bc_csa_pkg.gl_check_lines_status (-)');



  EXCEPTION

    WHEN e_error_lines THEN

      p_status := 'E';

      p_error_message := 'Journal with error.';

      print_log ( 'ajcl_bc_csa_pkg.gl_check_lines_status (!). Error: ' || p_error_message);



    WHEN OTHERS THEN

      p_status := 'E';

      p_error_message := SQLERRM;

      print_log ( 'ajcl_bc_csa_pkg.gl_check_lines_status (!). Error: ' || SQLERRM);



  END gl_check_lines_status; 

  */



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



    print_log ( 'ajcl_bc_csa_pkg.gl_call_ws_delete (+)');



    print_log ( 'p_documentno:' || p_documentno );

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



    print_log ( 'ajcl_bc_csa_pkg.gl_call_ws_delete (-)');



  EXCEPTION

      WHEN OTHERS THEN

        p_status := 'E';

        p_error_message := 'Not caught error when Delete General Journal Inbounds, Error: ' || SQLERRM;

        print_log (p_error_message);

        print_log ('ajcl_bc_csa_pkg.gl_call_ws_delete (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));



  END gl_call_ws_delete;



  -- 20240917

  PROCEDURE gl_check_lines_status_p ( p_error_message   IN OUT   VARCHAR2,

                                      p_status          IN OUT   VARCHAR2 ) IS



    v_error_lines   NUMBER;

    e_error_lines   EXCEPTION;



      CURSOR c_documentno_error IS

      SELECT documentno

        FROM ajcl_bc_csa_gl_lines

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND status IN ('ERROR','REJECTED')

    GROUP BY documentno;



  BEGIN



    print_log ( 'ajcl_bc_csa_gl_pkg.gl_check_lines_status_p (+)');



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



    print_log ( 'ajcl_bc_csa_gl_pkg.gl_check_lines_status_p (-)');



  EXCEPTION

    WHEN e_error_lines THEN

      p_status := 'E';

      p_error_message := 'Cant delete journal line.';

      print_log ( 'ajcl_bc_csa_gl_pkg.gl_check_lines_status_p (!). Error: ' || p_error_message);



    WHEN OTHERS THEN

      p_status := 'E';

      p_error_message := SQLERRM;

      print_log ( 'ajcl_bc_csa_gl_pkg.gl_check_lines_status_p (!). Error: ' || SQLERRM);



  END gl_check_lines_status_p; 

  -- 20240917



  -- Inserta los worksheets a enviar a BC en la tabla AJCL_BC_WORKSHEETS

  -- y ejecuta el concurrente que los envia: AJCL BC Worksheets Interface

  PROCEDURE worksheets_to_bc_p ( p_status             IN OUT   VARCHAR2 ) IS



      CURSOR c_worksheets IS

      -- AR

      SELECT line_worksheet ws_ies_num

        FROM ajcl_bc_csa_ar_lines

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND line_worksheet IS NOT NULL

    GROUP BY line_worksheet

       UNION 

      -- GL

      SELECT worksheetnumber ws_ies_num

        FROM ajcl_bc_csa_gl_lines

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND worksheetnumber IS NOT NULL

    GROUP BY worksheetnumber;



    v_total_worksheets   NUMBER;

    e_error              EXCEPTION;



  BEGIN



    print_log( 'ajcl_bc_csa_pkg.worksheets_to_bc_p (+)' );



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

    print_log( 'ajcl_bc_csa_pkg.worksheets_to_bc_p (-)' );



  EXCEPTION

    WHEN e_error THEN

      print_log( 'ajcl_bc_csa_pkg.worksheets_to_bc_p (!)' );

      p_status := 'E';

    WHEN OTHERS THEN

      print_log( 'ajcl_bc_csa_pkg.worksheets_to_bc_p (!)' );

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

        FROM ajcl_bc_csa_gl_lines abagl

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

        FROM ajcl_bc_csa_gl_lines abagl

       WHERE abagl.request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND UPPER(abagl.status) = 'ERROR'

         AND abagl.error_message IS NOT NULL

    ORDER BY abagl.documentno,

             abagl.postingdate,

             abagl.json_number,

             abagl.oraclelineno;



  BEGIN



    print_log( 'ajcl_bc_csa_pkg.gl_final_report_csv_p (+)' );



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



    print_log( 'ajcl_bc_csa_pkg.gl_final_report_csv_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_csa_pkg.gl_final_report_csv_p (!). Error: ' || SQLERRM );



  END gl_final_report_csv_p;



  PROCEDURE gen_proc_journals_detail_p IS



      CURSOR c_total IS

      SELECT SUM(abagl.entereddr) debit,

             SUM(abagl.enteredcr) credit

        FROM ajcl_bc_csa_gl_lines abagl

       WHERE abagl.request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND UPPER(abagl.status) NOT IN ('ERROR','REJECTED');



      CURSOR c_csa_ext_file_number_total IS

      SELECT abagl.dff_extract_file_number csa_extract_file_number,

             SUM(abagl.entereddr) debit,

             SUM(abagl.enteredcr) credit

        FROM ajcl_bc_csa_gl_lines abagl

       WHERE abagl.request_id = gv_request_id

         AND abagl.bc_environment = gv_bc_environment

         AND UPPER(abagl.status) NOT IN ('ERROR','REJECTED')

    GROUP BY abagl.dff_extract_file_number

    ORDER BY abagl.dff_extract_file_number;



      CURSOR c_source_total ( p_dff_extract_file_number   IN   VARCHAR2 ) IS

      SELECT abagl.userjesourcename source,

             SUM(abagl.entereddr) debit,

             SUM(abagl.enteredcr) credit

        FROM ajcl_bc_csa_gl_lines abagl

       WHERE abagl.request_id = gv_request_id

         AND abagl.bc_environment = gv_bc_environment

         AND UPPER(abagl.status) NOT IN ('ERROR','REJECTED')

         AND dff_extract_file_number = p_dff_extract_file_number

    GROUP BY abagl.userjesourcename

    ORDER BY abagl.userjesourcename;     



      CURSOR c_category_total ( p_dff_extract_file_number   IN   VARCHAR2, 

                                p_userjesourcename          IN   VARCHAR2 ) IS

      SELECT abagl.userjecategoryname category,

             SUM(abagl.entereddr) debit,

             SUM(abagl.enteredcr) credit

        FROM ajcl_bc_csa_gl_lines abagl

       WHERE abagl.request_id = gv_request_id

         AND abagl.bc_environment = gv_bc_environment

         AND UPPER(abagl.status) NOT IN ('ERROR','REJECTED')

         AND dff_extract_file_number = p_dff_extract_file_number

         AND abagl.userjesourcename = p_userjesourcename

    GROUP BY abagl.userjecategoryname

    ORDER BY abagl.userjecategoryname; 



      CURSOR c_worksheet_total ( p_dff_extract_file_number   IN   VARCHAR2, 

                                 p_userjesourcename          IN   VARCHAR2,

                                 p_userjecategoryname        IN   VARCHAR2 ) IS

      SELECT abagl.worksheetnumber worksheet,

             SUM(abagl.entereddr) debit,

             SUM(abagl.enteredcr) credit

        FROM ajcl_bc_csa_gl_lines abagl

       WHERE abagl.request_id = gv_request_id

         AND abagl.bc_environment = gv_bc_environment

         AND UPPER(abagl.status) NOT IN ('ERROR','REJECTED')

         AND dff_extract_file_number = p_dff_extract_file_number

         AND abagl.userjesourcename = p_userjesourcename

         AND userjecategoryname = p_userjecategoryname

    GROUP BY abagl.worksheetnumber

    ORDER BY abagl.worksheetnumber;   



    v_seq   NUMBER := 0;



  BEGIN



    print_log( 'ajcl_bc_csa_pkg.gen_proc_journals_detail_p (+)' );



    DELETE ajcl_bc_csa_gl_detail_report;



    FOR ccefnt IN c_csa_ext_file_number_total LOOP



      FOR cst IN c_source_total ( p_dff_extract_file_number => ccefnt.csa_extract_file_number ) LOOP



        FOR cct IN c_category_total ( p_dff_extract_file_number => ccefnt.csa_extract_file_number,

                                      p_userjesourcename => cst.source ) LOOP



          FOR cwt IN c_worksheet_total ( p_dff_extract_file_number => ccefnt.csa_extract_file_number,

                                         p_userjesourcename => cst.source,

                                         p_userjecategoryname => cct.category ) LOOP



            v_seq := v_seq + 1;



            INSERT 

              INTO ajcl_bc_csa_gl_detail_report

                 ( seq,

                   bc_environment,

                   dff_extract_file_number,

                   userjesourcename,

                   userjecategoryname,

                   worksheetnumber,

                   entereddr,

                   enteredcr,

                   creation_date,

                   created_by,

                   last_update_date,

                   last_updated_by,

                   request_id )

          VALUES ( v_seq,

                   gv_bc_environment,

                   ccefnt.csa_extract_file_number,

                   cst.source,

                   cct.category,

                   cwt.worksheet,

                   cwt.debit,

                   cwt.credit,

                   SYSDATE,

                   gv_user_id,

                   SYSDATE,

                   gv_user_id,

                   gv_request_id );



          END LOOP;       



          v_seq := v_seq + 1;



            INSERT 

              INTO ajcl_bc_csa_gl_detail_report

                 ( seq,

                   bc_environment,

                   dff_extract_file_number,

                   userjesourcename,

                   userjecategoryname,

                   worksheetnumber,

                   entereddr,

                   enteredcr,

                   creation_date,

                   created_by,

                   last_update_date,

                   last_updated_by,

                   request_id )

          VALUES ( v_seq,

                   gv_bc_environment,

                   ccefnt.csa_extract_file_number,

                   cst.source,

                   'Category Total',

                   NULL,

                   cct.debit,

                   cct.credit,

                   SYSDATE,

                   gv_user_id,

                   SYSDATE,

                   gv_user_id,

                   gv_request_id );



        END LOOP;



        v_seq := v_seq + 1;



          INSERT 

            INTO ajcl_bc_csa_gl_detail_report

               ( seq,

                 bc_environment,

                 dff_extract_file_number,

                 userjesourcename,

                 userjecategoryname,

                 worksheetnumber,

                 entereddr,

                 enteredcr,

                 creation_date,

                 created_by,

                 last_update_date,

                 last_updated_by,

                 request_id )

        VALUES ( v_seq,

                 gv_bc_environment,

                 ccefnt.csa_extract_file_number,

                 'Source Total',

                 NULL,

                 NULL,

                 cst.debit,

                 cst.credit,

                 SYSDATE,

                 gv_user_id,

                 SYSDATE,

                 gv_user_id,

                 gv_request_id );



      END LOOP;



      v_seq := v_seq + 1;



        INSERT 

          INTO ajcl_bc_csa_gl_detail_report

             ( seq,

               bc_environment,

               dff_extract_file_number,

               userjesourcename,

               userjecategoryname,

               worksheetnumber,

               entereddr,

               enteredcr,

               creation_date,

               created_by,

               last_update_date,

               last_updated_by,

               request_id )

      VALUES ( v_seq,

               gv_bc_environment,

               'CSA Extract File Number Total',

               NULL,

               NULL,

               NULL,

               ccefnt.debit,

               ccefnt.credit,

               SYSDATE,

               gv_user_id,

               SYSDATE,

               gv_user_id,

               gv_request_id );



    END LOOP;



    FOR crt IN c_total LOOP



      v_seq := v_seq + 1;



        INSERT 

          INTO ajcl_bc_csa_gl_detail_report

             ( seq,

               bc_environment,

               dff_extract_file_number,

               userjesourcename,

               userjecategoryname,

               worksheetnumber,

               entereddr,

               enteredcr,

               creation_date,

               created_by,

               last_update_date,

               last_updated_by,

               request_id )

      VALUES ( v_seq,

               gv_bc_environment,

               'Report Total',

               NULL,

               NULL,

               NULL,

               crt.debit,

               crt.credit,

               SYSDATE,

               gv_user_id,

               SYSDATE,

               gv_user_id,

               gv_request_id );



    END LOOP; 



    print_log( 'ajcl_bc_csa_pkg.gen_proc_journals_detail_p (-)' );



  END gen_proc_journals_detail_p;



  PROCEDURE gl_final_report_xlsx_p ( p_status   OUT   VARCHAR2 ) IS



    c_cursor   SYS_REFCURSOR;

    v_sheet    NUMBER := 1;



  BEGIN



    print_log( 'ajcl_bc_csa_pkg.gl_final_report_xlsx_p (+)' );



    gv_directory_report := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_REPORT' );



    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_gl_ifc || ' Report',

                                                p_request_id => gv_request_id,

                                                p_bc_environment => gv_bc_environment,

                                                p_jenkins_build_number => gv_jenkins_build_number,

                                                --

                                                p_param_1_title => ' ',

                                                p_param_1_value => ' ',

                                                p_param_2_title => 'IF_ERRORS_STOP',

                                                p_param_2_value => gv_if_errors_stop,

                                                p_param_3_title => 'STARTING_PK_SEQNO',

                                                p_param_3_value => gv_starting_pk_seqno );



    -- Processed Journals

        OPEN c_cursor FOR

      SELECT abagl.documentno document_no,

             abagl.postingdate posting_date,

             UPPER(abagl.userjesourcename) user_je_source_name,

             UPPER(abagl.userjecategoryname) user_je_category_name,

             abagl.currencycode currency_code,

             UPPER(abagl.status) status,

             SUM(NVL(abagl.entereddr,0)) entered_dr,

             SUM(NVL(abagl.enteredcr,0)) entered_cr,

             COUNT(1) quantity

        FROM ajcl_bc_csa_gl_lines abagl

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



    v_sheet := v_sheet + 1;

    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Processed Journals',

                                       p_sheet => v_sheet,

                                       p_cursor => c_cursor );



    -- Processed Detail

    gen_proc_journals_detail_p;



        OPEN c_cursor FOR

      SELECT dff_extract_file_number csa_extract_file_number,

             UPPER(userjesourcename) source,

             UPPER(userjecategoryname) category,

             worksheetnumber worksheet,

             entereddr debit,

             enteredcr credit

        FROM ajcl_bc_csa_gl_detail_report

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

    ORDER BY seq;



    v_sheet := v_sheet + 1;

    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Processed Detail',

                                       p_sheet => v_sheet,

                                       p_cursor => c_cursor );



    -- Error Journals

        OPEN c_cursor FOR

      SELECT abagl.documentno document_no,

             abagl.postingdate posting_date,

             UPPER(abagl.userjesourcename) user_je_source_name,

             UPPER(abagl.userjecategoryname) user_je_category_name,

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

        FROM ajcl_bc_csa_gl_lines abagl

       WHERE abagl.request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         AND UPPER(abagl.status) = 'ERROR'

         -- AND abagl.error_message IS NOT NULL

    ORDER BY abagl.documentno,

             abagl.postingdate,

             abagl.json_number,

             abagl.oraclelineno;



    v_sheet := v_sheet + 1;

    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Error Journals',

                                       p_sheet => v_sheet,

                                       p_cursor => c_cursor );



    as_xlsx.save ( gv_directory_report, gv_gl_report_filename || '.' || LOWER(gv_file_format) );



    p_status := 'S';



    print_log( 'ajcl_bc_csa_pkg.gl_final_report_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_csa_pkg.gl_final_report_xlsx_p (!). Error: ' || SQLERRM );



  END gl_final_report_xlsx_p;



  PROCEDURE ar_final_report_csv_p ( p_status   OUT   VARCHAR2 ) IS



      CURSOR c_invoices IS

      SELECT h.billToCustomerName,

             h.billToCustomerNo,

             h.transactionNo,

             h.transactionDate,

             h.class,

             h.invoiceCurrencyCode,

             TRIM(TO_CHAR(h.amount,'999,999,999.00')) amount,

             l.lineNo,

             l.description,

             TRIM(TO_CHAR(l.quantity,'999,999,999.00')) quantity,

             TRIM(TO_CHAR(l.unitSellingPrice,'999,999,999.00')) unitSellingPrice,

             TRIM(TO_CHAR(l.extendedAmount,'999,999,999.00')) extendedAmount,

             h.status h_status,

             h.error_message h_error_message,

             l.status l_status,

             l.error_message l_error_message

        FROM ajcl_bc_csa_ar_headers h,

             ajcl_bc_csa_ar_lines l

       WHERE h.request_id = gv_request_id

         AND h.bc_environment = gv_bc_environment

         AND h.request_id = l.request_id

         AND l.bc_environment = gv_bc_environment

         AND NVL(h.billToCustomerNo,-999) = NVL(l.billToCustomerNo,-999)

         AND h.transactionNo = l.transactionNo

         AND h.class = l.class

    ORDER BY h.billToCustomerName,

             h.transactionNo, 

             l.lineNo;



  BEGIN



    print_log( 'ajcl_bc_csa_pkg.ar_final_report_csv_p (+)' );



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



    print_log( 'ajcl_bc_csa_pkg.ar_final_report_csv_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_csa_pkg.ar_final_report_csv_p (!). Error: ' || SQLERRM );



  END ar_final_report_csv_p;



  PROCEDURE ar_final_report_xlsx_p ( p_status   OUT   VARCHAR2 ) IS



    c_cursor            SYS_REFCURSOR;



  BEGIN



    print_log( 'ajcl_bc_csa_pkg.ar_final_report_xlsx_p (+)' );



    gv_directory_report := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_REPORT' );



    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ar_ifc || ' Report',

                                                p_request_id => gv_request_id,

                                                p_bc_environment => gv_bc_environment,

                                                p_jenkins_build_number => gv_jenkins_build_number,

                                                --

                                                p_param_1_title => ' ',

                                                p_param_1_value => ' ',

                                                p_param_2_title => 'IF_ERRORS_STOP',

                                                p_param_2_value => gv_if_errors_stop,

                                                p_param_3_title => 'STARTING_PK_SEQNO',

                                                p_param_3_value => gv_starting_pk_seqno );



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

               FROM ajcl_bc_csa_ar_headers 

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

                        FROM ajcl_bc_csa_ar_headers 

                       WHERE request_id = gv_request_id 

                         AND reprocess IS NOT NULL ) > 0

              UNION                

             SELECT 3 order_by,

                    class, 

                    UPPER(status) status, 

                    COUNT(1) qty

               FROM ajcl_bc_csa_ar_headers 

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

             -- 20241018

             h.dff_housebill housebill,

             -- 20241018

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

        FROM ajcl_bc_csa_ar_headers h,

             ajcl_bc_csa_ar_lines l

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

             -- 20241018

             h.dff_housebill housebill,

             -- 20241018

             UPPER(h.status) header_status,

             h.error_message header_error_message,

             l.lineNo line_num,

             l.description,

             TRIM(TO_CHAR(l.quantity,'999,999,999.00')) quantity,

             TRIM(TO_CHAR(l.unitSellingPrice,'999,999,999.00')) unit_selling_price,

             TRIM(TO_CHAR(l.extendedAmount,'999,999,999.00')) extended_amount,

             UPPER(l.status) line_status,

             l.error_message line_error_message

        FROM ajcl_bc_csa_ar_headers h,

             ajcl_bc_csa_ar_lines l

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



    print_log( 'ajcl_bc_csa_pkg.ar_final_report_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_csa_pkg.ar_final_report_xlsx_p (!). Error: ' || SQLERRM );



  END ar_final_report_xlsx_p;



  -- 20241001

  -- FIX ACCOUNT 1110.1200

  PROCEDURE fix_dim_DATAMIG_inv_to_cm_p IS



    CURSOR c_lines IS

    SELECT l.rowid row_id,

           l.*

      FROM ajcl_bc_csa_ar_lines l

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



    print_log('ajcl_bc_csa_ar_pkg.fix_dim_DATAMIG_inv_to_cm_p (+)');



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



        UPDATE ajcl_bc_csa_ar_lines

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



    print_log('ajcl_bc_csa_ar_pkg.fix_dim_DATAMIG_inv_to_cm_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      NULL;



  END fix_dim_DATAMIG_inv_to_cm_p;

  -- 20241001



  PROCEDURE main_bc_p ( p_status      OUT   VARCHAR2,

                        p_module      OUT   VARCHAR2,

                        p_error_msg   OUT   VARCHAR2 ) IS



    v_send_ar_data_to_bc    VARCHAR2(1) := 'Y';

    v_send_gl_data_to_bc    VARCHAR2(1) := 'Y';



    v_phase                 VARCHAR2(200);



    v_status                VARCHAR2(1);

    v_error_message         VARCHAR2(2000);



    -- AR

    v_trx_count             NUMBER;

    v_lines_count           NUMBER;

    e_ar_error              EXCEPTION;

    -- 20260108

    e_ar_job_error          EXCEPTION;

    -- 20260108

    e_ar_exception          EXCEPTION;



    -- GL

    v_journals_count        NUMBER;

    v_pending_rows          NUMBER := -1;

    e_gl_error              EXCEPTION;

    -- 20260108

    e_gl_job_error          EXCEPTION;

    -- 20260108

    e_gl_exception          EXCEPTION;



  BEGIN



    print_log( 'ajcl_bc_csa_pkg.main_bc_p (+)' );



    -- Se hace el insert de lo nuevo solo si el archivo no fue procesado aun

    IF ( gv_only_reprocess = 'N' ) THEN



      -- AR --------------------------------------------------------------------------------------------------------------------



      -- AJCL CSA AR Interface

      ar_insert_p ( p_status => v_status,

                    p_error_message => v_error_message );



      -- 20241001

      fix_dim_DATAMIG_inv_to_cm_p;

      -- 20241001



      IF ( v_status = 'W' ) THEN



        -- No data to process.

        v_send_ar_data_to_bc := 'N';



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_ar_email,

                                         p_subject => gv_bc_ar_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => 'No data to process.' || CHR(10) || 'Request ID: ' || gv_request_id );



      ELSIF ( v_status = 'E' ) THEN



        v_phase := 'ar_insert_p';

        RAISE e_ar_exception;



      END IF;



      -- GL ----------------------------------------------------------------------------------------------------------------------



      -- AJCL CSA GL Interface

      gl_insert_p ( p_status => v_status,

                    p_error_message => v_error_message );



      IF ( v_status = 'W' ) THEN



        -- No data to process.

        v_send_gl_data_to_bc := 'N';



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_gl_email,

                                         p_subject => gv_bc_gl_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => 'No data to process.' || CHR(10) || 'Request ID: ' || gv_request_id );



      ELSIF ( v_status = 'E' ) THEN



        v_phase := 'gl_insert_p';

        RAISE e_gl_exception;



      END IF;



      worksheets_to_bc_p ( p_status => v_status );



      IF ( v_status != 'S' ) THEN



        v_phase := 'worksheets_to_bc_p';

        RAISE e_ar_error;



      END IF;



    END IF; -- gv_only_reprocess = 'N'



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

          RAISE e_ar_error;



        END IF;



        print_log ( 'v_trx_count: ' || v_trx_count );



        -- Si se envió al menos un comprobante, se ejecuta el job

        IF ( v_trx_count > 0 ) THEN



          -- Se ejecuta el JOB -----------------------------------------------------------------------------------------------------

          ar_call_job ( p_status => v_status );



          IF v_status != 'S' THEN



            v_phase := 'ar_call_job';

            -- 20260108

            -- RAISE e_ar_error;

            RAISE e_ar_job_error;

            -- 20260108



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

        WHEN ge_ar_lock THEN -- Lock & Release

          print_log ('ajcl_bc_csa_pkg.main_bc_p. Error al intentar hacer el lock del proceso ' || gv_ar_process_name || 

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

          print_log ( 'Error general AR.' );



          -- dbms_lock - Release -----------------------------------------------------------------------------------------------

          ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_ar_id_lock,

                                           p_release_status => gv_ar_release_status );  

          -- dbms_lock - Release ----------------------------------------------------------------------------------------------- 



          RAISE e_ar_exception;



      END;



    END IF;

    -- AR



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



        ELSE



          print_log('No journals to process.');



          ajcl_bc_utils_pkg.send_email_p ( p_to => gv_gl_email,

                                           p_subject => gv_bc_gl_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                           p_message => 'No journals to process.' || CHR(10) || 'Request ID: ' || gv_request_id );



        END IF;



      EXCEPTION

        -- dbms_lock -----------------------------------------------------------------------------------------------------------

        WHEN ge_gl_lock THEN 

          print_log ('ajcl_bc_csa_pkg.main_bc_p. Error al intentar hacer el lock del proceso ' || gv_gl_process_name || 

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

          print_log ( 'Error general GL.' );



          -- dbms_lock - Release -----------------------------------------------------------------------------------------------

          ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_gl_id_lock,

                                           p_release_status => gv_gl_release_status );  

          -- dbms_lock - Release -----------------------------------------------------------------------------------------------



          RAISE e_gl_exception;



      END; 



    END IF; -- GL



    p_status := 'S';



    print_log( 'ajcl_bc_csa_pkg.main_bc_p (-)' );



  EXCEPTION

    WHEN e_ar_exception THEN

      print_log( 'ajcl_bc_csa_pkg.main_bc_p (!)' );

      p_status := 'E';

      p_module := 'AR';

      print_log ('Phase: ' || v_phase);

      print_log (v_error_message);

      p_error_msg := v_error_message;



    WHEN e_gl_exception THEN

      print_log( 'ajcl_bc_csa_pkg.main_bc_p (!)' );

      p_status := 'E';

      p_module := 'GL';

      print_log ('Phase: ' || v_phase);

      print_log (v_error_message);

      p_error_msg := v_error_message;



    WHEN OTHERS THEN

      print_log( 'ajcl_bc_csa_pkg.main_bc_p (!). Error: ' || SQLERRM );

      p_error_msg := SQLERRM;



  END main_bc_p;



  PROCEDURE main_p ( p_bc_environment              IN   VARCHAR2,

                     p_if_errors_stop              IN   VARCHAR2,

                     p_starting_pk_seqno           IN   VARCHAR2, -- Prompt Starting PK Seqno

                     -- 20240905 p_check_integrations_source   IN   VARCHAR2,

                     p_jenkins_build_number        IN   VARCHAR2 ) IS



    -- 20241211 v_db_name                VARCHAR2(100);



    v_status                 VARCHAR2(1);

    v_module                 VARCHAR2(10);

    v_phase                  VARCHAR2(200);



    v_argument1              VARCHAR2(100);

    v_argument2              VARCHAR2(100);

    v_argument3              VARCHAR2(100);



    -- 20250507

    -- 20260108 v_support_email          VARCHAR2(200);

    v_ar_not_success         NUMBER;

    v_gl_not_success         NUMBER;

    -- 20250507



    e_error                  EXCEPTION;

    e_validate_preprocess    EXCEPTION;

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

                                                     p_argument2 => p_if_errors_stop,

                                                     p_argument3 => p_starting_pk_seqno

                                                     -- 20240905 ,p_argument4 => p_check_integrations_source 

                                                     );



    print_log('ajcl_bc_csa_pkg.main_p (+)');

    print_log('gv_request_id: ' || gv_request_id);



    -- Validacion parametro p_bc_environment -----------------------------------------------------------------------------------

    IF ( ajcl_bc_utils_pkg.is_bc_environment_valid_f ( p_bc_environment ) = 'N' ) THEN



      v_error_msg := 'Invalid value (' || p_bc_environment || ') for parameter BC_ENVIRONMENT.';

      RAISE e_parameter_value;



    END IF;



    gv_bc_environment := p_bc_environment;

    print_log ( 'gv_bc_environment: ' || gv_bc_environment );



    gv_if_errors_stop := p_if_errors_stop;

    print_log ( 'gv_if_errors_stop: ' || gv_if_errors_stop );



    -- Validacion parametro p_starting_pk_seqno -----------------------------------------------------------------------------------    

    IF ( LENGTH(regexp_replace(p_starting_pk_seqno, '[0-9]', '')) IS NOT NULL ) THEN



      v_error_msg := 'Invalid value (' || p_starting_pk_seqno || ') for parameter STARTING_PK_SEQNO.';

      RAISE e_parameter_value;



    END IF;



    gv_starting_pk_seqno := p_starting_pk_seqno;

    print_log ( 'gv_starting_pk_seqno: ' || gv_starting_pk_seqno );



    gv_file_format := ajcl_bc_ws_utils_pkg.get_parameter_f ( 'FILE_FORMAT' );

    print_log( 'gv_file_format: ' || gv_file_format ); 



    gv_gl_email := ajcl_bc_utils_pkg.get_emails_f ( 'CSA JOURNALS' );

    print_log( 'gv_gl_email: ' || gv_gl_email );



    gv_gl_process_name := ajcl_bc_ws_utils_pkg.get_lock_process_name_f ( p_integration => 'JOURNALS' );

    print_log( 'gv_gl_process_name: ' || gv_gl_process_name );



    gv_ar_email := ajcl_bc_utils_pkg.get_emails_f ( 'CSA SALES DOC' );

    print_log( 'gv_ar_email: ' || gv_ar_email );



    gv_ar_process_name := ajcl_bc_ws_utils_pkg.get_lock_process_name_f ( p_integration => 'SALES DOCUMENTS' );

    print_log( 'gv_ar_process_name: ' || gv_ar_process_name );



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



    -- Se setea el valor de gv_filename segun la db donde estamos

    /* 20241211 - La ruta y nombre del file se maneja desde Jenkins

    v_db_name := ajcl_bc_utils_pkg.get_db_name_f;



    IF ( v_db_name = 'PROD' ) THEN



      gv_filename := '/d01/csa_interface/AJCCSAEXT.csv';



    ELSIF ( v_db_name != 'PROD' ) THEN



      gv_filename := '/CSA_TEST/AJCCSAEXT.csv';



    END IF;

    */



    -- 20241211 print_log ( 'gv_filename: ' || gv_filename );

    print_log ( 'gv_csa_je_source: ' || gv_csa_je_source );

    print_log ( 'gv_gl_category_cogs_accrual: ' || gv_gl_category_cogs_accrual );

    print_log ( 'gv_gl_cat_cogs_accrual_rev: ' || gv_gl_cat_cogs_accrual_rev );

    print_log ( 'gv_gl_category_transit: ' || gv_gl_category_transit );

    print_log ( 'gv_gl_category_transit_rev: ' || gv_gl_category_transit_rev );

    print_log ( 'gv_default_subaccount: ' || gv_default_subaccount );

    print_log ( 'gv_default_division: ' || gv_default_division );

    print_log ( 'gv_default_csa_inv_type: ' || gv_default_csa_inv_type );

    print_log ( 'gv_default_csa_batch_source: ' || gv_default_csa_batch_source );

    print_log ( 'gv_default_ies_batch_source: ' || gv_default_ies_batch_source );

    print_log ( 'gv_starting_pk_seqno: ' || gv_starting_pk_seqno );

    print_log ( 'gv_ies_je_source: ' || gv_ies_je_source );



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



    ajcl_bc_get_entities_pkg.get_ies_items_p ( p_bc_environment => gv_bc_environment,

                                               p_bc_ifc => gv_bc_ifc,

                                               p_request_id => gv_request_id,

                                               p_log_seq => gv_log_seq,

                                               p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'ajcl_bc_get_entities_pkg.get_ies_items_p';

      RAISE e_error;



    END IF;



    ajcl_bc_get_entities_pkg.get_csa_station_id_p ( p_bc_environment => gv_bc_environment,

                                                    p_bc_ifc => gv_bc_ifc,

                                                    p_request_id => gv_request_id,

                                                    p_log_seq => gv_log_seq,

                                                    p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'ajcl_bc_get_entities_pkg.get_csa_station_id_p';

      RAISE e_error;



    END IF;



    ajcl_bc_get_entities_pkg.get_cust_xref_p ( p_bc_environment => gv_bc_environment,

                                               p_bc_ifc => gv_bc_ifc,

                                               p_request_id => gv_request_id,

                                               p_log_seq => gv_log_seq,

                                               p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'ajcl_bc_get_entities_pkg.get_cust_xref_p';

      RAISE e_error;



    END IF;



    print_log ( 'The required dimensions of the accounts are refreshed.' );

    ajcl_bc_accounts_pkg.main_p ( p_bc_environment => gv_bc_environment );



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



    -- 20240916

    IF ( ajcl_bc_utils_pkg.get_db_name_f IN ('PROD') ) THEN



      gv_ftp_loader := 'Y'; 



    ELSIF ( ajcl_bc_utils_pkg.get_db_name_f IN ('FINUPG5','FINUPG6') ) THEN



      gv_ftp_loader := 'N'; -- TRIGGER



    END IF;



    print_log ( 'gv_ftp_loader: ' || gv_ftp_loader );

    -- 20240916



    -- AJCL Load CSA Data Extract ----------------------------------------------------------------------------------------------

    /* 20241211

    -- Se reemplaza con un build step en Jenkins

    IF ( gv_ftp_loader = 'Y' ) THEN



      print_log ( 'Run job AJC_LOAD_CSA_TEMP' );



      -- 20240923 v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJCL_EXECUTE_CTL.sh';

      v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_EXECUTE_CTL' );

      print_log ( 'v_argument1: ' || v_argument1 );



      -- 20240923 v_argument2 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJC_LOAD_CSA_TEMP';

      v_argument2 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_BC_CSA_LOADER' );

      print_log ( 'v_argument2: ' || v_argument2 );



      v_argument3 := gv_filename; -- /d01/csa_interface/AJCCSAEXT.csv

      print_log ( 'v_argument3: ' || v_argument3 );



      ajc_bc_scheduler_pkg.create_run_wait_job_p ( p_job_name => 'AJC_LOAD_CSA_TEMP',

                                                   p_comments => 'AJCL Load CSA Data Extract',

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



        v_phase := 'AJCL Load CSA Data Extract';

        RAISE e_error;



      END IF;



    END IF; -- gv_ftp_loader



    -- 20241206

    DBMS_LOCK.SLEEP(30);

    COMMIT;

    -- 20241206



    -- 20241211

    */



    -- AJCL CSA Data File Validation -------------------------------------------------------------------------------------------

    file_validation_p ( p_status => v_status,

                        p_error_msg => v_error_msg );



    IF ( v_status = 'E' ) THEN



      v_phase := 'file_validation_p';

      RAISE e_error;



    END IF;



    -- Solo si no es un reproceso, se ejecutan estos procedures

    IF ( gv_only_reprocess = 'N' ) THEN



      -- Validate and Preprocessing ----------------------------------------------------------------------------------------------

      validate_preprocess_p ( p_status => v_status,

                              p_error_msg => v_error_msg );    



      IF ( v_status != 'S' ) THEN



        v_phase := 'validate_preprocess_p';

        RAISE e_validate_preprocess;



      END IF;



    END IF;



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



    IF ( gv_ftp_loader = 'N' ) THEN



      DELETE AJC_CSA_INTERFACEAPAR_TEMP;

      COMMIT;



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

        FROM ajcl_bc_csa_ar_headers

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

        FROM ajcl_bc_csa_gl_lines

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



    print_log('ajcl_bc_csa_pkg.main_p (-)');



  EXCEPTION

    WHEN e_bc_setup THEN

      print_log('ajcl_bc_csa_pkg.main_p (!). BC setup error. please contact support.');



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



    WHEN e_parameter_value THEN

      ROLLBACK;

      print_log('ajcl_bc_csa_pkg.main_p (!)');

      print_log(v_error_msg);



      BEGIN



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_gl_email,

                                         p_subject => gv_bc_gl_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => v_error_msg || CHR(10) || 'Request ID: ' || gv_request_id );



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_ar_email,

                                         p_subject => gv_bc_ar_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => v_error_msg || CHR(10) || 'Request ID: ' || gv_request_id );



      EXCEPTION

        WHEN OTHERS THEN

          print_log ( 'SMTP NOT WORKING.' );



      END;                                       



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );     



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );



    WHEN e_error THEN

      ROLLBACK;

      print_log('ajcl_bc_csa_pkg.main_p (!)');

      print_log('phase: ' || v_phase);



      BEGIN



        IF ( v_module = 'GL' ) THEN



          ajcl_bc_utils_pkg.send_email_p ( p_to => gv_gl_email,

                                           p_subject => gv_bc_gl_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                           p_message => v_error_msg || CHR(10) || 'Request ID: ' || gv_request_id );



        ELSIF ( v_module = 'AR' ) THEN



          ajcl_bc_utils_pkg.send_email_p ( p_to => gv_ar_email,

                                           p_subject => gv_bc_ar_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                           p_message => v_error_msg || CHR(10) || 'Request ID: ' || gv_request_id );



        ELSE



          ajcl_bc_utils_pkg.send_email_p ( p_to => gv_gl_email,

                                           p_subject => gv_bc_gl_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                           p_message => v_error_msg || CHR(10) || 'Request ID: ' || gv_request_id );



          IF ( gv_gl_email != gv_ar_email ) THEN



            ajcl_bc_utils_pkg.send_email_p ( p_to => gv_ar_email,

                                             p_subject => gv_bc_ar_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                             p_message => v_error_msg || CHR(10) || 'Request ID: ' || gv_request_id );



          END IF;



        END IF;                                 



      EXCEPTION

        WHEN OTHERS THEN

          print_log ( 'SMTP NOT WORKING.' );



      END;                                         



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );     



      RAISE_APPLICATION_ERROR(-20000,'Error at phase: ' || v_phase );



    WHEN e_validate_preprocess THEN

      ROLLBACK;

      print_log('ajcl_bc_csa_pkg.main_p (!)');

      print_log('phase: ' || v_phase);



      BEGIN



        IF ( v_module = 'GL' ) THEN



          ajcl_bc_utils_pkg.send_email_p ( p_to => gv_gl_email,

                                           p_subject => gv_bc_gl_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                           p_message => 'The process could not be executed due to errors. Please review the output, correct any errors and rerun the process.' || CHR(10) || 'Request ID: ' || gv_request_id );



        ELSIF ( v_module = 'AR' ) THEN



          ajcl_bc_utils_pkg.send_email_p ( p_to => gv_ar_email,

                                           p_subject => gv_bc_ar_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                           p_message => 'The process could not be executed due to errors. Please review the output, correct any errors and rerun the process.' || CHR(10) || 'Request ID: ' || gv_request_id );



        ELSE



          ajcl_bc_utils_pkg.send_email_p ( p_to => gv_gl_email,

                                           p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                           p_message => 'The process could not be executed due to errors. Please review the output, correct any errors and rerun the process.' || CHR(10) || 'Request ID: ' || gv_request_id );



          IF ( gv_gl_email != gv_ar_email ) THEN



            ajcl_bc_utils_pkg.send_email_p ( p_to => gv_ar_email,

                                             p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                             p_message => 'The process could not be executed due to errors. Please review the output, correct any errors and rerun the process.' || CHR(10) || 'Request ID: ' || gv_request_id );



          END IF;



        END IF;                                 



      EXCEPTION

        WHEN OTHERS THEN

          print_log ( 'SMTP NOT WORKING.' );



      END;                                         



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );     



      RAISE_APPLICATION_ERROR(-20000,'Error at phase: ' || v_phase );      



    WHEN OTHERS THEN

      ROLLBACK;

      print_log('v_phase: ' || v_phase);     

      print_log('ajcl_bc_csa_pkg.main_p (!). General Error: ' || SQLERRM);     



      BEGIN



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_gl_email,

                                         p_subject => gv_bc_gl_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => 'General Error: ' || SQLERRM || CHR(10) || 'Request ID: ' || gv_request_id );



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_ar_email,

                                         p_subject => gv_bc_ar_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => 'General Error: ' || SQLERRM || CHR(10) || 'Request ID: ' || gv_request_id );



      EXCEPTION

        WHEN OTHERS THEN

          print_log ( 'SMTP NOT WORKING.' );



      END;



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );     



      RAISE_APPLICATION_ERROR(-20000,'General Error: ' || SQLERRM );  



  END main_p;



END ajcl_bc_csa_pkg;
