CREATE OR REPLACE PACKAGE BODY ajcl_bc_lockbox_pkg IS

-- Creation: SBANCHIERI 06-FEB-2024

-- Modified: SBANCHIERI 2025 - KANO

-- Modified: SBANCHIERI 06-JAN-2026 - RETRY



  -- Se usa para probar en otros ambientes el mismo file n veces

  -- gv_rcp_number_suffix          VARCHAR2(5) := 'SB';



  -- Parametros

  gv_gl_date                    DATE;

  gv_receipt_method_id          NUMBER := 2643; -- CASH-TRUIST-LOCKBOX



  gv_unidentified_no            VARCHAR2(20) := '998021';

  gv_unidentified_name          VARCHAR2(20) := 'UNIDENTIFIED';

  gv_unidentified_customer_id   NUMBER;



  -- 20260106 REINTENTO

  gv_retry_in_seconds           NUMBER;

  gv_retry                      VARCHAR2(1);

  -- 20260106 REINTENTO



  -- PRINT LOG ----------------------------------------------------------------------------------------------------------------- 

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    gv_log_seq := gv_log_seq + 1;

    ajcl_bc_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );



  END print_log;



  -- PRINT OUTPUT -------------------------------------------------------------------------------------------------------------- 

  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    ajcl_bc_utils_pkg.insert_output_p ( gv_bc_ifc, p_message, gv_request_id );



  END print_output;



  -- ARCHIVE / PURGE -----------------------------------------------------------------------------------------------------------

  PROCEDURE archive_purge_p ( p_number_of_days         IN   VARCHAR2,

                              p_archive                IN   VARCHAR2,

                              p_jenkins_build_number   IN   VARCHAR2 ) IS



    CURSOR c_data IS

    SELECT COUNT(*) cnt, 

           p_number_of_days ndk, 

           TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI:SS') rd

      FROM ajc_truist_ar_lbx_bank_data

     WHERE deposit_date <= SYSDATE - p_number_of_days;



    v_error_msg         VARCHAR2(200);

    v_status            VARCHAR2(1);



    e_parameter_value   EXCEPTION;

    e_error             EXCEPTION;



  BEGIN



    gv_request_id := ajcl_bc_utils_pkg.get_request_id_f;

    gv_jenkins_build_number := p_jenkins_build_number;

    gv_bc_ifc := 'AJCL BC Lockbox Archive Purge';



    -- Se inserta el concurrent_job

    ajcl_bc_utils_pkg.ins_jenkins_concurrent_job_p ( p_request_id => gv_request_id,

                                                     p_job_name => gv_bc_ifc,

                                                     p_jenkins_build_number => gv_jenkins_build_number,

                                                     p_argument1 => p_number_of_days,

                                                     p_argument2 => p_archive );



    print_log ('ajcl_bc_lockbox_pkg.archive_purge_p (+)');

    print_log('gv_request_id: ' || gv_request_id);

    print_log('gv_jenkins_build_number: ' || gv_jenkins_build_number);

    print_log('gv_bc_ifc: ' || gv_bc_ifc);



    gv_oracle_db := ajcl_bc_utils_pkg.get_db_name_f;

    print_log ( 'gv_oracle_db: ' || gv_oracle_db );



    gv_email := ajcl_bc_utils_pkg.get_emails_f ( 'LOCKBOX ARCHIVE' );

    print_log( 'gv_email: ' || gv_email );



    IF ( p_number_of_days IS NULL ) THEN 



      v_error_msg := 'Parameter NUMBER_OF_DAYS_TO_KEEP cannot be null.';

      RAISE e_parameter_value;



    ELSE



      IF ( LENGTH(REGEXP_REPLACE(p_number_of_days, '[0-9]', '')) IS NOT NULL ) THEN



        v_error_msg := 'Invalid NUMBER_OF_DAYS_TO_KEEP format. Only numbers are accepted.';

        RAISE e_parameter_value;



      END IF;



    END IF;



    print_output ('AJC Truist 823 AR Archive/Purge');

    print_output (' ');



    print_output ( 'Count' || '|' || 

                   'Num of Days to Keep' || '|' || 

                   'Archive' || '|' ||

                   'Date' );



    FOR cd IN c_data LOOP



      print_output ( cd.cnt || '|' ||

                     cd.ndk || '|' ||

                     p_archive || '|' ||

                     cd.rd );



    END LOOP;



    IF ( p_archive = 'Y' ) THEN



      INSERT 

        INTO ajc_truist_ar_lbx_archive

      SELECT *

        FROM ajc_truist_ar_lbx_bank_data

       WHERE deposit_date <= SYSDATE - p_number_of_days;



      print_output (' ');

      print_output ('Records backed up in ajc_truist_ar_lbx_archive|' || SQL%ROWCOUNT);



      COMMIT;



    END IF;



    DELETE ajc_truist_ar_lbx_bank_data

     WHERE deposit_date <= SYSDATE - p_number_of_days;



    print_output (' ');

    print_output ('Records deleted from ajc_truist_ar_lbx_bank_data|' || SQL%ROWCOUNT);



    COMMIT;   



    -- CREATE OUTPUT -----------------------------------------------------------------------------------------------------------

    ajcl_bc_utils_pkg.create_csv_p ( p_ifc => gv_bc_ifc,

                                     p_request_id => gv_request_id,

                                     p_log_seq => gv_log_seq,

                                     p_type => 'OUTPUT',

                                     p_filename => gv_output_filename,

                                     --

                                     p_status => v_status );



    IF ( v_status != 'S' ) THEN



      RAISE e_error;



    END IF;



    -- MAIL OUTPUT -----------------------------------------------------------------------------------------------------------

    ajcl_bc_utils_pkg.send_mail_with_attach ( p_to_mail => gv_email,

                                              p_subject => gv_bc_ifc || ' Output - ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_oracle_db || ' (' || gv_jenkins_build_number || ')',

                                              p_body => gv_bc_ifc || ' Output.',

                                              p_type => 'OUTPUT',

                                              p_filename => gv_output_filename, 

                                              p_attach_filename => gv_bc_ifc || ' Output ' || TO_CHAR(SYSDATE,'MMDDYYYY HH24MISS') || ' ' || gv_oracle_db || '.csv' );



    -- Se actualiza el concurrent_job

    ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'S' );



    print_log ('ajcl_bc_lockbox_pkg.archive_purge_p (-)');



  EXCEPTION

    WHEN e_parameter_value THEN

      print_log ('ajcl_bc_lockbox_pkg.archive_purge_p (!). Error: ' || SQLERRM);

      print_log ( v_error_msg );

      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_oracle_db || ' (' || gv_jenkins_build_number || ')',

                                       p_message => v_error_msg || CHR(10) || 'Request ID: ' || gv_request_id );



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );     



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );



    WHEN e_error THEN 

      print_log ('ajcl_bc_lockbox_pkg.archive_purge_p (!). Error: ' || SQLERRM);

      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_oracle_db || ' (' || gv_jenkins_build_number || ')',

                                       p_message => v_error_msg || CHR(10) || 'Request ID: ' || gv_request_id );



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );     



    WHEN OTHERS THEN

      print_log ('ajcl_bc_lockbox_pkg.archive_purge_p (!). Error: ' || SQLERRM);

      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_oracle_db || ' (' || gv_jenkins_build_number || ')',

                                       p_message => 'General Error: ' || SQLERRM || CHR(10) || 'Request ID: ' || gv_request_id );



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );     



      RAISE_APPLICATION_ERROR(-20000,'General Error: ' || SQLERRM );  



  END archive_purge_p; 



  -- PARSE ---------------------------------------------------------------------------------------------------------------------

  -- AJC Truist Parse 823 AR Data File 

  PROCEDURE parse_p ( p_status      OUT   VARCHAR2,

                      p_error_msg   OUT   VARCHAR2 ) IS



      CURSOR sel_lbx_file IS

      SELECT line, 

             line_num

             -- 2025 - KANO

            ,journal_batch_name

             -- 2025 - KANO

        FROM ajc_truist_lbx_file

       WHERE REPLACE(line,'~') IS NOT NULL

    ORDER BY line_num;



    v_line           VARCHAR2(250);

    v_line_delim     VARCHAR2(1) := '~';



    v_col_delim      VARCHAR2(1) := '*';

    v_new_line_num   INTEGER := 0;

    v_delim_count    INTEGER := 0;

    v_start_pos      INTEGER := 0;

    v_length         INTEGER := 0;

    i                INTEGER := 0;



  BEGIN



    print_log ('ajcl_bc_lockbox_pkg.parse_p (+)');



    DELETE ajc_truist_parsed_lbx_file;



    FOR sel_lbx_file_rec IN sel_lbx_file LOOP



      -- print_log ( 'Processing line#/line: ' || sel_lbx_file_rec.line_num || '/' || sel_lbx_file_rec.line );



      IF ( INSTR(sel_lbx_file_rec.line,v_line_delim,1,1) = 0 ) THEN



         -- print_log ( 'No delim found' );

         v_line := v_line || sel_lbx_file_rec.line;



      ELSE



         i := 1;

         v_start_pos := 0;

         v_delim_count := LENGTH(sel_lbx_file_rec.line) - LENGTH(REPLACE(sel_lbx_file_rec.line,v_line_delim));

         -- print_log ( 'Delim count ' || v_delim_count );



         FOR i IN 1..v_delim_count + 1 LOOP



           IF ( i = 1 ) THEN



             v_start_pos := 1;

             v_length := INSTR(sel_lbx_file_rec.line,v_line_delim,1,i) - 1;



           ELSE



             v_start_pos := INSTR(sel_lbx_file_rec.line,v_line_delim,1,i-1) + 1;



             IF ( i = v_delim_count + 1 ) THEN



               v_length := LENGTH(sel_lbx_file_rec.line) -

                           INSTR(sel_lbx_file_rec.line,v_line_delim,1,i-1);



             ELSE



               v_length := INSTR(sel_lbx_file_rec.line,v_line_delim,1,i) - 

                           INSTR(sel_lbx_file_rec.line,v_line_delim,1,i-1) - 1;



             END IF;



           END IF;



           -- print_log ( 'Start pos/length ' || v_start_pos || '/' || v_length );

           v_line := v_line || SUBSTR(sel_lbx_file_rec.line,v_start_pos,v_length);

           -- print_log ( 'v_line before col parsing ' || v_line );



           IF ( i <= v_delim_count ) THEN



             v_new_line_num := v_new_line_num + 1;



             INSERT 

               INTO ajc_truist_parsed_lbx_file

                  ( line_num,

                    line,

                    rec_type,

                    column1,

                    column2,

                    column3,

                    column4,

                    column5,

                    column6,

                    column7,

                    column8,

                    column9,

                    column10,

                    column11,

                    column12,

                    column13,

                    column14,

                    column15,

                    column16,

                    column17,

                    column18,

                    column19,

                    column20

                    -- 2025 - KANO

                   ,journal_batch_name

                    -- 2025 - KANO

                    )

           VALUES ( v_new_line_num,

                    v_line,

                    TRIM(SUBSTR(v_line,1,INSTR(v_line,v_col_delim,1,1)-1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,1),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,1)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,2),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,2)) -

                                DECODE(INSTR(v_line,v_col_delim,1,1),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,1)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,2),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,2)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,3),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,3)) -

                                DECODE(INSTR(v_line,v_col_delim,1,2),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,2)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,3),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,3)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,4),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,4)) -

                                DECODE(INSTR(v_line,v_col_delim,1,3),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,3)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,4),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,4)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,5),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,5)) -

                                DECODE(INSTR(v_line,v_col_delim,1,4),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,4)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,5),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,5)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,6),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,6)) -

                                DECODE(INSTR(v_line,v_col_delim,1,5),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,5)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,6),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,6)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,7),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,7)) -

                                DECODE(INSTR(v_line,v_col_delim,1,6),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,6)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,7),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,7)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,8),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,8)) -

                                DECODE(INSTR(v_line,v_col_delim,1,7),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,7)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,8),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,8)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,9),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,9)) -

                                DECODE(INSTR(v_line,v_col_delim,1,8),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,8)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,9),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,9)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,10),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,10)) -

                                DECODE(INSTR(v_line,v_col_delim,1,9),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,9)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,10),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,10)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,11),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,11)) -

                                DECODE(INSTR(v_line,v_col_delim,1,10),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,10)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,11),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,11)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,12),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,12)) -

                                DECODE(INSTR(v_line,v_col_delim,1,11),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,11)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,12),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,12)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,13),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,13)) -

                                DECODE(INSTR(v_line,v_col_delim,1,12),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,12)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,13),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,13)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,14),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,14)) -

                                DECODE(INSTR(v_line,v_col_delim,1,13),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,13)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,14),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,14)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,15),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,15)) -

                                DECODE(INSTR(v_line,v_col_delim,1,14),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,14)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,15),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,15)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,16),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,16)) -

                                DECODE(INSTR(v_line,v_col_delim,1,15),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,15)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,16),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,16)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,17),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,17)) -

                                DECODE(INSTR(v_line,v_col_delim,1,16),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,16)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,17),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,17)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,18),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,18)) -

                                DECODE(INSTR(v_line,v_col_delim,1,17),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,17)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,18),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,18)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,19),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,19)) -

                                DECODE(INSTR(v_line,v_col_delim,1,18),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,18)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,19),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,19)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,20),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,20)) -

                                DECODE(INSTR(v_line,v_col_delim,1,19),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,19)) - 1)),

                    TRIM(SUBSTR(v_line, 

                                DECODE(INSTR(v_line,v_col_delim,1,20),

                                       '0',LENGTH(v_line),

                                       INSTR(v_line,v_col_delim,1,20)) + 1,

                                DECODE(INSTR(v_line,v_col_delim,1,21),

                                       '0',LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,21)) -

                                DECODE(INSTR(v_line,v_col_delim,1,20),

                                       '0', LENGTH(v_line) + 1,

                                       INSTR(v_line,v_col_delim,1,20)) - 1))

                    -- 2025 - KANO

                   ,sel_lbx_file_rec.journal_batch_name

                    -- 2025 - KANO

                                       );



             -- print_log ( '1 parsed record inserted with line#/line: ' || v_new_line_num || '/' || v_line);



             v_line := null;



           END IF ;  -- IF i < v_delim_count + 1 THEN



         END LOOP;



       END IF;



     END LOOP;



     IF ( LENGTH(v_line) > 0 ) THEN



       v_new_line_num := v_new_line_num + 1;



       INSERT 

         INTO ajc_truist_parsed_lbx_file

            ( line_num,

              line,

              rec_type,

              column1,

              column2,

              column3,

              column4,

              column5,

              column6,

              column7,

              column8,

              column9,

              column10,

              column11,

              column12,

              column13,

              column14,

              column15,

              column16,

              column17,

              column18,

              column19,

              column20

              -- 2025 - KANO

             ,journal_batch_name

              -- 2025 - KANO

              )

     VALUES ( v_new_line_num,

              v_line,

              TRIM(SUBSTR(v_line,1,INSTR(v_line,v_col_delim,1,1)-1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,1),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,1)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,2),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,2)) -

                          DECODE(INSTR(v_line,v_col_delim,1,1),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,1)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,2),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,2)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,3),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,3)) -

                          DECODE(INSTR(v_line,v_col_delim,1,2),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,2)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,3),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,3)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,4),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,4)) -

                          DECODE(INSTR(v_line,v_col_delim,1,3),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,3)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,4),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,4)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,5),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,5)) -

                          DECODE(INSTR(v_line,v_col_delim,1,4),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,4)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,5),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,5)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,6),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,6)) -

                          DECODE(INSTR(v_line,v_col_delim,1,5),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,5)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,6),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,6)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,7),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,7)) -

                          DECODE(INSTR(v_line,v_col_delim,1,6),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,6)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,7),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,7)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,8),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,8)) -

                          DECODE(INSTR(v_line,v_col_delim,1,7),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,7)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,8),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,8)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,9),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,9)) -

                          DECODE(INSTR(v_line,v_col_delim,1,8),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,8)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,9),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,9)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,10),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,10)) -

                          DECODE(INSTR(v_line,v_col_delim,1,9),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,9)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,10),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,10)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,11),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,11)) -

                          DECODE(INSTR(v_line,v_col_delim,1,10),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,10)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,11),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,11)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,12),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,12)) -

                          DECODE(INSTR(v_line,v_col_delim,1,11),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,11)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,12),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,12)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,13),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,13)) -

                          DECODE(INSTR(v_line,v_col_delim,1,12),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,12)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,13),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,13)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,14),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,14)) -

                          DECODE(INSTR(v_line,v_col_delim,1,13),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,13)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,14),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,14)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,15),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,15)) -

                          DECODE(INSTR(v_line,v_col_delim,1,14),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,14)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,15),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,15)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,16),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,16)) -

                          DECODE(INSTR(v_line,v_col_delim,1,15),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,15)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,16),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,16)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,17),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,17)) -

                          DECODE(INSTR(v_line,v_col_delim,1,16),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,16)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,17),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,17)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,18),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,18)) -

                          DECODE(INSTR(v_line,v_col_delim,1,17),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,17)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,18),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,18)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,19),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,19)) -

                          DECODE(INSTR(v_line,v_col_delim,1,18),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,18)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,19),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,19)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,20),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,20)) -

                          DECODE(INSTR(v_line,v_col_delim,1,19),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,19)) - 1)),

              TRIM(SUBSTR(v_line, 

                          DECODE(INSTR(v_line,v_col_delim,1,20),

                                 '0',LENGTH(v_line),

                                 INSTR(v_line,v_col_delim,1,20)) + 1,

                          DECODE(INSTR(v_line,v_col_delim,1,21),

                                 '0',LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,21)) -

                          DECODE(INSTR(v_line,v_col_delim,1,20),

                                 '0', LENGTH(v_line) + 1,

                                 INSTR(v_line,v_col_delim,1,20)) - 1))

              -- 2025 - KANO

             ,gv_journal_batch_name

              -- 2025 - KANO

                                 );



      -- print_log ( '1 parsed record inserted with line#/line: ' || v_new_line_num || '/' || v_line);



    END IF; -- IF length(v_line) > 0 THEN



    -- If this was a concatenated file, delete all ISA lines except the first and all IEA lines except the last 

    DELETE ajc_truist_parsed_lbx_file

     WHERE rec_type = 'ISA'

       AND line_num > ( SELECT MIN(line_num)

                          FROM ajc_truist_parsed_lbx_file

                         WHERE rec_type = 'ISA'

                           -- 2025 - KANO

                           AND journal_batch_name = gv_journal_batch_name

                           -- 2025 - KANO

                      )

    -- 2025 - KANO

       AND journal_batch_name = gv_journal_batch_name

    -- 2025 - KANO

    ;



    -- print_log(sql%rowcount || ' ISA records deleted.');



    DELETE ajc_truist_parsed_lbx_file

     WHERE rec_type = 'IEA'

       AND line_num < ( SELECT MAX(line_num)

                          FROM ajc_truist_parsed_lbx_file

                         WHERE rec_type = 'IEA'

                           -- 2025 - KANO

                           AND journal_batch_name = gv_journal_batch_name

                           -- 2025 - KANO

                       )

    -- 2025 - KANO

       AND journal_batch_name = gv_journal_batch_name

    -- 2025 - KANO

    ;



    -- print_log(sql%rowcount || ' IEA records deleted.');



    p_status := 'S';



    print_log ('ajcl_bc_lockbox_pkg.parse_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      p_error_msg := SQLERRM;

      print_log ('ajcl_bc_lockbox_pkg.parse_p (!). Error: ' || SQLERRM);



  END parse_p;



  -- PREPROCESS ----------------------------------------------------------------------------------------------------------------

  -- AJC Truist Preprocess 823 AR Data

  PROCEDURE preprocess_p ( p_status      OUT   VARCHAR2,

                           p_error_msg   OUT   VARCHAR2 ) IS



    deposit_line_num_v		            NUMBER;

    prev_batch_line_num_v		         NUMBER := 0;

    prev_payment_line_num_v		       NUMBER := 0;

    receiving_bank_aba_v		          VARCHAR2(25);

    receiving_customer_acct_num_v	  VARCHAR2(25);

    num_batches_in_deposit_v	       NUMBER;

    next_deposit_line_num_v		       NUMBER;

    batch_line_num_v		              NUMBER;

    batch_seq_v			                  VARCHAR2(25);

    num_payments_in_batch_v		       NUMBER;

    batch_total_v			                NUMBER;

    next_batch_line_num_v		         NUMBER;

    payment_line_num_v		            NUMBER;

    payment_amt_v			                NUMBER;

    originating_bank_aba_v		        VARCHAR2(25);

    payor_account_num_v		           VARCHAR2(25);

    next_payment_line_num_v		       NUMBER;

    check_num_v 			                 VARCHAR2(25);

    invoice_num_v			                VARCHAR2(25);

    invoice_amt_v			                NUMBER;

    check_date_v			                 VARCHAR2(25);

    deposit_date_v			               VARCHAR2(25);



    num_batches_processed_v		       NUMBER; 

    ach_ref_v 			                   VARCHAR2(50);

    wire_7u_ref_v			                VARCHAR2(25);

    wire_8i_ref_v			                VARCHAR2(60);

    ach_wire_cust_name_v		          VARCHAR2(60);

    wire_zzz_ref_v			               VARCHAR2(2000);

    receipt_comments_v		            VARCHAR2(2000);

    data_trx_type_v		              	VARCHAR2(1);

    bpr_type_of_receipt_v		         VARCHAR2(20);

    group_id_v			                   NUMBER;

    run_datetime_v			               VARCHAR2(30); 

    user_id_v			                    NUMBER;

    num_inv_v		                    	NUMBER;



      CURSOR select_deposit_line_num IS

      SELECT line_num, 

             column2 deposit_date

        FROM ajc_truist_parsed_lbx_file

       WHERE rec_type = 'DEP'

         -- 2025 - KANO

         AND journal_batch_name = gv_journal_batch_name

         -- 2025 - KANO

    ORDER BY line_num;



    CURSOR select_batch_line_num IS

    SELECT MIN(line_num) line_num

      FROM ajc_truist_parsed_lbx_file

     WHERE rec_type = 'BAT'

       AND line_num > deposit_line_num_v

       AND line_num > prev_batch_line_num_v

       -- 2025 - KANO

       AND journal_batch_name = gv_journal_batch_name

       -- 2025 - KANO

       ;



      CURSOR select_payment_data IS

      SELECT *

        FROM ajc_truist_parsed_lbx_file

       WHERE line_num > payment_line_num_v

         AND line_num < next_payment_line_num_v

         -- 2025 - KANO

         AND journal_batch_name = gv_journal_batch_name

         -- 2025 - KANO

    ORDER BY line_num;



  BEGIN



    print_log ('ajcl_bc_lockbox_pkg.preprocess_p (+)');



    SELECT ajc_truist_ar_group_id_s.NEXTVAL,

           TO_CHAR(SYSDATE, 'DD-MON-YYYY HH:MI:SS AM')

      INTO group_id_v, 

           run_datetime_v 

      FROM dual;



    print_log ( 'group_id_v: ' || group_id_v || ' | Date: ' || run_datetime_v );



    user_id_v := gv_user_id;    



    -- print_log ( 'Date: ' || run_datetime_v || ' AJC Truist 823 Preprocess Detail' );



    FOR deposit_rec IN select_deposit_line_num LOOP



      deposit_line_num_v := deposit_rec.line_num;

      deposit_date_v := TO_DATE(deposit_rec.deposit_date,'YYYYMMDD');



	     -- print_log ( 'DEP line: ' || deposit_line_num_v );

      -- print_log ( 'DEP Date: ' || deposit_date_v );



      receiving_bank_aba_v := NULL;

      receiving_customer_acct_num_v := NULL;



      SELECT column6,

             column8

        INTO receiving_bank_aba_v, 

             receiving_customer_acct_num_v

        FROM ajc_truist_parsed_lbx_file

       WHERE line_num = deposit_line_num_v

         -- 2025 - KANO

         AND journal_batch_name = gv_journal_batch_name

         -- 2025 - KANO

         ;



      -- print_log ( 'Receiving Bank ABA: ' || receiving_bank_aba_v );

      -- print_log ( 'Receiving Customer Account Number: ' || receiving_customer_acct_num_v );



      num_batches_in_deposit_v := NULL;



      SELECT column2

        INTO num_batches_in_deposit_v

        FROM ajc_truist_parsed_lbx_file

       WHERE rec_type = 'QTY'

         AND column1 = '41'

         AND line_num = ( SELECT MIN(line_num)

                            FROM ajc_truist_parsed_lbx_file

                           WHERE rec_type = 'QTY'

                             AND column1 = '41'

                             AND line_num > deposit_line_num_v 

                             -- 2025 - KANO

                             AND journal_batch_name = gv_journal_batch_name

                             -- 2025 - KANO

                         )

         -- 2025 - KANO

         AND journal_batch_name = gv_journal_batch_name

         -- 2025 - KANO

      ;



	     -- print_log ( 'Num batches in deposit: ' || num_batches_in_deposit_v );



      next_deposit_line_num_v := NULL;



      -- Determine the line of the next deposit

      SELECT MIN(line_num)

        INTO next_deposit_line_num_v

        FROM ajc_truist_parsed_lbx_file

       WHERE rec_type = 'DEP'

         AND line_num > deposit_line_num_v

         -- 2025 - KANO

         AND journal_batch_name = gv_journal_batch_name

         -- 2025 - KANO

         ;



      IF ( next_deposit_line_num_v IS NULL ) THEN



        SELECT line_num

          INTO next_deposit_line_num_v

          FROM ajc_truist_parsed_lbx_file

         WHERE rec_type = 'SE'

           AND line_num > deposit_line_num_v

           -- 2025 - KANO

           AND journal_batch_name = gv_journal_batch_name

           -- 2025 - KANO

           ;



      END IF;



      -- print_log ( 'NEXT Deposit Line: ' || next_deposit_line_num_v );



	     FOR j IN 1..num_batches_in_deposit_v LOOP 



        SELECT MIN(line_num)

          INTO batch_line_num_v 

          FROM ajc_truist_parsed_lbx_file

         WHERE rec_type = 'BAT'

           AND line_num > deposit_line_num_v

           AND line_num > prev_batch_line_num_v

           -- 2025 - KANO

           AND journal_batch_name = gv_journal_batch_name

           -- 2025 - KANO

           ; 



		      num_batches_processed_v := j;



        batch_seq_v := NULL;



        SELECT column3

          INTO batch_seq_v

          FROM ajc_truist_parsed_lbx_file

         WHERE line_num = batch_line_num_v

           -- 2025 - KANO

           AND journal_batch_name = gv_journal_batch_name

           -- 2025 - KANO

         ;



		      -- print_log ( 'Batch: line num- ' || batch_line_num_v || '; Seq- ' || batch_seq_v );



		      num_payments_in_batch_v := NULL;



        SELECT column2

          INTO num_payments_in_batch_v

          FROM ajc_truist_parsed_lbx_file

         WHERE rec_type = 'QTY'

           AND column1 = '42'

           AND line_num = ( SELECT MIN(line_num)

                              FROM ajc_truist_parsed_lbx_file

                             WHERE rec_type = 'QTY'

                               AND column1='42'

                               AND line_num > batch_line_num_v 

                               -- 2025 - KANO

                               AND journal_batch_name = gv_journal_batch_name

                               -- 2025 - KANO

                               )

           -- 2025 - KANO

           AND journal_batch_name = gv_journal_batch_name

           -- 2025 - KANO

        ;



		      -- print_log ( 'Num payments in batch: ' || num_payments_in_batch_v );



        batch_total_v := null;



        SELECT column2

          INTO batch_total_v

          FROM ajc_truist_parsed_lbx_file

         WHERE rec_type = 'AMT'

           AND column1 = '2'

           AND line_num = ( SELECT MIN(line_num)

                              FROM ajc_truist_parsed_lbx_file

                             WHERE rec_type = 'AMT'

                               AND column1 = '2'

                               AND line_num > batch_line_num_v 

                               -- 2025 - KANO

                               AND journal_batch_name = gv_journal_batch_name

                               -- 2025 - KANO

           -- 2025 - KANO

           AND journal_batch_name = gv_journal_batch_name

           -- 2025 - KANO

        );



        IF ( num_batches_in_deposit_v > 1 ) THEN



          --  Determine the line of the next batch in this deposit

          SELECT MIN(line_num)

            INTO next_batch_line_num_v

            FROM ajc_truist_parsed_lbx_file

           WHERE rec_type = 'BAT'

             AND line_num > batch_line_num_v

             AND line_num < next_deposit_line_num_v

             -- 2025 - KANO

             AND journal_batch_name = gv_journal_batch_name

             -- 2025 - KANO

             ;



        ELSE



          -- since there is only 1 batch in the deposit then this batch contains all the data until the next deposit starts

          next_batch_line_num_v := next_deposit_line_num_v;



        END IF;



        IF ( next_batch_line_num_v IS NULL ) THEN



          next_batch_line_num_v := next_deposit_line_num_v;



        END IF;



		      FOR i IN 1..num_payments_in_batch_v LOOP 



          SELECT MIN(line_num) 

            INTO payment_line_num_v

            FROM ajc_truist_parsed_lbx_file

           WHERE rec_type = 'BPR'

             AND line_num > batch_line_num_v

             AND line_num > prev_payment_line_num_v

             -- 2025 - KANO

             AND journal_batch_name = gv_journal_batch_name

             -- 2025 - KANO

             ;



          data_trx_type_v := NULL;

          bpr_type_of_receipt_v := NULL;

          payment_amt_v := NULL;

          originating_bank_aba_v := NULL;

          payor_account_num_v := NULL;



          -- Get the payment info from BPR segment

          SELECT column1 data_trx_type_v, 

                 column2 payment_amt_v, 

                 DECODE(column1,'X', column4 || DECODE(column5,NULL,NULL,'-' || column5), 

                                'C', column4 || DECODE(column5,NULL,NULL,'-' || column5), 

                                column4) bpr_type_of_receipt_v,

                 DECODE(column1,'I',column7,

                                'X',column7,

                                NULL) originating_bank_aba_v, 

                 DECODE(column1,'I',column9, 

                                'X',column9,

                                NULL) originating_bank_aba_v 

            INTO data_trx_type_v, 

                 payment_amt_v, 

                 bpr_type_of_receipt_v, 

                 originating_bank_aba_v, 

                 payor_account_num_v

            FROM ajc_truist_parsed_lbx_file

           WHERE line_num = payment_line_num_v

             -- 2025 - KANO

             AND journal_batch_name = gv_journal_batch_name

             -- 2025 - KANO

             ;



          -- print_log ( '-- PAYMENT --' );

          -- print_log ( 'Data Trx type: '|| data_trx_type_v );

          -- print_log ( 'BPR TYPE OF RECEIPT: ' || bpr_type_of_receipt_v );

          -- print_log ( 'Payment line: ' || payment_line_num_v || '; Amt: ' || payment_amt_v );

          -- print_log ( 'Next batch line num : '||next_batch_line_num_v );



          IF ( num_payments_in_batch_v > 1 ) THEN



            -- Determine the line of the next payment in this batch

            SELECT MIN(line_num)

              INTO next_payment_line_num_v

              FROM ajc_truist_parsed_lbx_file

             WHERE rec_type = 'BPR'

               AND line_num > payment_line_num_v

               AND line_num < next_batch_line_num_v

               -- 2025 - KANO

               AND journal_batch_name = gv_journal_batch_name

               -- 2025 - KANO

               ;



            IF ( next_payment_line_num_v IS NULL ) THEN



              IF ( num_batches_in_deposit_v = num_batches_processed_v ) THEN



                -- we've processed all the batches in this deposit so the next deposit is next up

                next_payment_line_num_v := next_deposit_line_num_v ;



              ELSE

                -- more batches to process

                next_payment_line_num_v := next_batch_line_num_v ;



              END IF;



            END IF;



          ELSE 



            -- since if there is only 1 payment in this batch then this payment contains all the data until the next batch starts

            next_payment_line_num_v := next_batch_line_num_v;



          END IF;



          -- print_log ( 'NEXT Payment line: ' || next_payment_line_num_v );



          -- Gather the payment data

          check_num_v := NULL;

          check_date_v := NULL;

          invoice_num_v := NULL;

          invoice_amt_v := NULL;



          ach_ref_v := NULL;

          ach_wire_cust_name_v := NULL;

          wire_7u_ref_v := NULL;

          wire_8i_ref_v := NULL;

          wire_zzz_ref_v := NULL;



       			FOR pay_data_rec IN select_payment_data LOOP



            -- Lockbox Trx

            IF ( data_trx_type_v = 'I' ) THEN



              IF ( pay_data_rec.rec_type = 'REF' ) THEN



                check_num_v := pay_data_rec.column2;



              END IF;



              IF ( pay_data_rec.rec_type = 'DTM' ) THEN



                check_date_v := pay_data_rec.column2;



              END IF;



            ELSIF ( data_trx_type_v = 'X' ) THEN



              IF ( pay_data_rec.rec_type = 'TRN' ) THEN



                ach_ref_v := 'ACH: ' || pay_data_rec.column2;



              END IF;



              IF ( pay_data_rec.rec_type = 'N1' AND pay_data_rec.column1 = 'PR' ) THEN



                ach_wire_cust_name_v := pay_data_rec.column2;



              END IF;



            ELSIF ( data_trx_type_v = 'C' ) THEN



              IF ( pay_data_rec.rec_type = 'REF' ) THEN



                IF ( pay_data_rec.column1 = '7U' ) THEN



                  wire_7u_ref_v := pay_data_rec.column2;



                ELSIF ( pay_data_rec.column1 = '8I' ) THEN



                  wire_8i_ref_v := pay_data_rec.column2;



                ELSIF ( pay_data_rec.column1 = 'ZZZ' ) THEN



                  IF ( LENGTH(wire_zzz_ref_v) > 0 ) THEN

                    wire_zzz_ref_v := wire_zzz_ref_v || '|' || pay_data_rec.column2;



                  ELSE



                    wire_zzz_ref_v := pay_data_rec.column2;



                  END IF;



                END IF;



              END IF;



              IF ( pay_data_rec.rec_type = 'N1' AND pay_data_rec.column1 = 'PR' ) THEN



                ach_wire_cust_name_v := pay_data_rec.column2;



              END IF;



            END IF; -- data_trx_type_v = I



			       END LOOP; -- Select_Payment_Data LOOP



          receipt_comments_v := NULL;



          -- Build the receipt comments 

          IF ( data_trx_type_v = 'C' ) THEN



            IF ( LENGTH(wire_7u_ref_v) > 0 ) THEN 



              receipt_comments_v := wire_7u_ref_v;



            END IF;



            IF ( LENGTH(wire_8i_ref_v) > 0 ) THEN



              IF ( LENGTH(receipt_comments_v) > 0 ) THEN



                receipt_comments_v := receipt_comments_v || '|' || wire_8i_ref_v;



              ELSE



                receipt_comments_v := wire_8i_ref_v;



              END IF; 



            END IF; 



            IF ( LENGTH(wire_zzz_ref_v) > 0 ) THEN



              IF ( LENGTH(receipt_comments_v) > 0 ) THEN



                receipt_comments_v := receipt_comments_v || '|' || wire_zzz_ref_v;



              ELSE



                receipt_comments_v := wire_zzz_ref_v;



              END IF; 



            END IF; 



            -- prefix the receipt comments with the WIRE type 

            IF ( LENGTH(receipt_comments_v) > 0 ) THEN



              receipt_comments_v := 'WIRE: ' || receipt_comments_v;



            END IF; 



			       ELSIF ( data_trx_type_v = 'X' ) THEN



            receipt_comments_v := ach_ref_v;



			       ELSE 



				        receipt_comments_v := 'LOCKBOX: ' || check_num_v;



	       		END IF;



          -- print_log ( 'Count num invoices --' );

          -- print_log ( 'Payment Line Num: ' || payment_line_num_v );

          -- print_log ( 'Next Payment Line Num: ' || next_payment_line_num_v );



			       -- Determine if there are invoices to load for ACH-CTX payments

			       num_inv_v := 0;



          IF ( data_trx_type_v = 'X' ) OR

             ( data_trx_type_v = 'C' and bpr_type_of_receipt_v IN ('ACH-CTX','CHK-PBC') ) THEN



            SELECT COUNT(*)

              INTO num_inv_v

              FROM ajc_truist_parsed_lbx_file

             WHERE rec_type = 'RMR' 

               AND column1 = 'IV' 

               AND line_num > payment_line_num_v

               AND line_num < next_payment_line_num_v

               -- 2025 - KANO

               AND journal_batch_name = gv_journal_batch_name

               -- 2025 - KANO

               ;



			       END IF; 



          -- print_log ( 'Num invoices to load: ' || num_inv_v );



			       IF ( data_trx_type_v = 'I' 

               OR ( data_trx_type_v = 'C' AND bpr_type_of_receipt_v IN ('ACH-CTX','CHK-PBC') AND num_inv_v > 0 ) 

               OR ( data_trx_type_v = 'X' AND num_inv_v > 0 ) 

             ) THEN



				        FOR pay_data_rec IN Select_Payment_Data LOOP



              IF ( pay_data_rec.rec_type = 'RMR' and pay_data_rec.column1 = 'IV' ) THEN



                -- Se agrega para evitar procesar el invoice num que viene con todos 0

                IF ( LENGTH(REPLACE(pay_data_rec.column2,'0')) != 0 ) THEN



                  -- 20260106

                  -- Se agrega para que no falle si viene mal el nro de invoice.

                  -- Muestra un mensaje de error en el log e inserta el registro sin valor en invoice num e invoice amt

                  BEGIN

                  -- 20260106



                    invoice_num_v := pay_data_rec.column2;

                    invoice_amt_v := pay_data_rec.column4;



                  -- 20260105

                  EXCEPTION

                    WHEN OTHERS THEN

                      print_log ( 'ERROR when trying to get the invoice number to which the receipt applies. Value: ' || pay_data_rec.column2 );

                      invoice_num_v := NULL;

                      invoice_amt_v := NULL;



                  END;

                  -- 20260106



                ELSE



                  invoice_num_v := NULL;

                  invoice_amt_v := NULL;



                END IF;



                  INSERT 

                    INTO ajc_truist_ar_lbx_bank_data 

                       ( group_id,

                         deposit_line_num,

                         deposit_date,

                         receiving_bank_aba,

                         receiving_customer_acct_num,

                         batch_num,

                         payment_num,

                         originating_bank_aba, 

                         payor_account_num,

                         payment_amt,

                         payment_date,

                         invoice_num,

                         invoice_amt,

                         data_inv_line_num,

                         data_payment_line_num,

                         data_trx_type,

                         receipt_comments,

                         bpr_type_of_receipt,

                         creation_date,

                         created_by,

                         last_update_date,

                         last_updated_by,

                         ach_wire_cust_name

                         -- 2025 - KANO

                        ,journal_batch_name

                         -- 2025 - KANO

                         )					

                VALUES ( group_id_v,

                         deposit_line_num_v,

                         deposit_date_v,

                         DECODE(data_trx_type_v, 'I', receiving_bank_aba_v, 'X', receiving_bank_aba_v, NULL),

                         DECODE(data_trx_type_v, 'I', receiving_customer_acct_num_v, 'X', receiving_customer_acct_num_v, NULL),

                         batch_seq_v,

                         DECODE(data_trx_type_v, 'I', check_num_v, NULL) ,

                         originating_bank_aba_v, 

                         payor_account_num_v, 

                         payment_amt_v,

                         DECODE(data_trx_type_v, 'I', check_date_v, NULL),

                         invoice_num_v,

                         invoice_amt_v,

                         pay_data_rec.line_num,

                         payment_line_num_v,

                         data_trx_type_v,

                         receipt_comments_v,

                         bpr_type_of_receipt_v,

                         SYSDATE,

                         user_id_v,

                         SYSDATE,

                         user_id_v,

                         DECODE(data_trx_type_v, 'I', NULL, ach_wire_cust_name_v)

                         -- 2025 - KANO

                        ,gv_journal_batch_name

                         -- 2025 - KANO

                         ) ;



 	              -- print_log ( 'Payment: ' || check_num_v || '; Invoice: ' || invoice_num_v || '; Invoice amt: ' || invoice_amt_v );



				          END IF;



				        END LOOP; -- Select_Payment_Data LOOP



          END IF; -- trx_type = I



          IF ( data_trx_type_v = 'X' AND num_inv_v = 0 ) OR

             ( data_trx_type_v = 'C' AND bpr_type_of_receipt_v IN ('ACH-CTX','CHK-PBC') AND num_inv_v = 0 ) OR 

             ( data_trx_type_v = 'C' AND bpr_type_of_receipt_v NOT IN ('ACH-CTX','CHK-PBC') ) THEN 



              INSERT 

                INTO ajc_truist_ar_lbx_bank_data 

                   ( group_id,

                     deposit_line_num,

                     deposit_date,

                     batch_num,

                     originating_bank_aba, 

                     payor_account_num,

                     data_payment_line_num,

                     data_trx_type,

                     receipt_comments,

                     ach_wire_cust_name,

                     bpr_type_of_receipt,

                     payment_amt,

                     creation_date,

                     created_by,

                     last_update_date,

                     last_updated_by

                     -- 2025 - KANO

                    ,journal_batch_name

                     -- 2025 - KANO

                     )					

            VALUES ( group_id_v,

                     deposit_line_num_v,

                     deposit_date_v,

                     batch_seq_v,

                     originating_bank_aba_v, 

                     payor_account_num_v, 

                     payment_line_num_v,

                     data_trx_type_v,

                     receipt_comments_v,

                     ach_wire_cust_name_v,

                     bpr_type_of_receipt_v,

                     payment_amt_v,

                     SYSDATE,

                     user_id_v,

                     SYSDATE,

                     user_id_v 

                     -- 2025 - KANO

                    ,gv_journal_batch_name

                     -- 2025 - KANO

                     );



		        END IF;	



        		prev_payment_line_num_v :=  payment_line_num_v;



		      END LOOP; -- For num_payments_in_batch_v LOOP 



		      prev_batch_line_num_v :=  batch_line_num_v;



	     END LOOP; -- Select_Batch_Line_Num LOOP



    END LOOP; -- Select_Deposit_Line_Num LOOP



    p_status := 'S';



    print_log ('ajcl_bc_lockbox_pkg.preprocess_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      p_error_msg := SQLERRM;

      print_log ('ajcl_bc_lockbox_pkg.preprocess_p (!). Error: ' || SQLERRM);



  END preprocess_p; 



  -- BC ------------------------------------------------------------------------------------------------------------------------

  -- Procedimientos para CREACION DE RECIBOS -----------------------------------------------------------------------------------

  ------------------------------------------------------------------------------------------------------------------------------

  PROCEDURE insert_rcp_bc_p ( p_lockboxReceiptNumber      IN   VARCHAR2,

                              p_customerNo                IN   VARCHAR2,

                              p_customerName              IN   VARCHAR2,

                              p_postingDate               IN   VARCHAR2,

                              p_currencyCode              IN   VARCHAR2,

                              p_amount                    IN   NUMBER,

                              p_comments                  IN   VARCHAR2,

                              p_customerBankABA           IN   VARCHAR2,

                              p_customerBankAccount       IN   VARCHAR2,

                              p_ACHWireBankCustCodeName   IN   VARCHAR2,

                              p_typeOfReceipt             IN   VARCHAR2,     

                              --

                              p_payment_num               IN   VARCHAR2,

                              p_payment_date              IN   VARCHAR2,

                              p_payor_account_num         IN   VARCHAR2,

                              p_originating_bank_aba      IN   VARCHAR2,

                              p_data_payment_line_num     IN   NUMBER,

                              --

                              p_lockboxID                OUT   NUMBER,

                              p_status                   OUT   VARCHAR2,

                              p_error_msg                OUT   VARCHAR2 ) IS



    v_json_data      CLOB;



  BEGIN



    print_log ('ajcl_bc_lockbox_pkg.insert_rcp_bc_p (+)');



    -- Se obtiene el valor de la secuencia

    SELECT AJCL_BC_LOCKBOX_ID_S.NEXTVAL

      INTO p_lockboxID

      FROM DUAL;



    print_log ('p_lockboxID: ' || p_lockboxID);



    -- Se arma el json

    APEX_JSON.initialize_clob_output;

    APEX_JSON.open_object;



    APEX_JSON.write('lockboxID',p_lockboxID,true);

    APEX_JSON.write('lockboxReceiptNumber',p_lockboxReceiptNumber,true);

    APEX_JSON.write('accountNo',p_customerNo,true);

    APEX_JSON.write('postingDate',TO_CHAR(TO_DATE(p_postingDate,'DD-MON-YY'),'YYYY-MM-DD'),true);

    APEX_JSON.write('comment',SUBSTR(p_comments,1,250),true);

    APEX_JSON.write('currencyCode',p_currencyCode,true);

    APEX_JSON.write('amount',-1 * ABS(p_amount),true);

    APEX_JSON.write('customerBankABA',p_customerBankABA,true);

    APEX_JSON.write('customerBankAccount',p_customerBankAccount,true);

    APEX_JSON.write('aCHWireBankCustCodeName',p_ACHWireBankCustCodeName,true);

    APEX_JSON.write('typeOfReceipt',p_typeOfReceipt,true);

    APEX_JSON.write('requestID',gv_request_id,true);

    -- 2025 - KANO

    APEX_JSON.write('journalBatchName',gv_journal_batch_name,true);

    -- 2025 - KANO



    APEX_JSON.close_object;



    v_json_data := APEX_JSON.get_clob_output;

    -- print_log ( 'v_json_data: ' || v_json_data );



    APEX_JSON.free_output;



      INSERT

        INTO ajcl_bc_lbx_receipts

           ( bc_environment,

             lockboxID,

             lockboxReceiptNumber,

             customerNo,

             customerName,

             postingDate,

             currencyCode,

             amount,

             comments,

             customerBankABA,

             customerBankAccount,

             ACHWireBankCustCodeName,

             typeOfReceipt,

             --

             json_data,

             request_id,

             status,

             --

             payment_num,

             payment_date,

             payor_account_num,

             originating_bank_aba,

             data_payment_line_num,

             -- 2025 - KANO

             journal_batch_name,

             -- 2025 - KANO

             creation_date,

             created_by,

             last_update_date,

             last_updated_by )

    VALUES ( gv_bc_environment,

             p_lockboxID,

             p_lockboxReceiptNumber,

             p_customerNo,

             p_customerName,

             TO_CHAR(TO_DATE(p_postingDate,'DD-MON-YY'),'YYYY-MM-DD'), -- postingDate

             p_currencyCode,

             -1 * ABS(p_amount),

             SUBSTR(p_comments,1,250),

             p_customerBankABA,

             p_customerBankAccount,

             p_ACHWireBankCustCodeName,

             p_typeOfReceipt,            

             --

             v_json_data,

             gv_request_id, 

             'NEW', -- status

             --

             p_payment_num,

             p_payment_date,

             p_payor_account_num,

             p_originating_bank_aba,

             p_data_payment_line_num,

             -- 2025 - KANO

             gv_journal_batch_name,

             -- 2025 - KANO

             SYSDATE, -- creation_date

             gv_user_id, -- created_by

             SYSDATE, -- last_update_date

             gv_user_id -- last_updated_by 

             );



    COMMIT; 



    p_status := 'S';



    print_log ('ajcl_bc_lockbox_pkg.insert_rcp_bc_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_error_msg := SQLERRM;

      print_log ('ajcl_bc_lockbox_pkg.insert_rcp_bc_p (!). Error: ' || SQLERRM);

      p_status := 'E';



  END insert_rcp_bc_p;



  PROCEDURE call_rcp_ws_p ( p_lockboxID    IN   NUMBER,

                            p_status      OUT   VARCHAR2,

                            p_error_msg   OUT   VARCHAR2 ) IS



    CURSOR c_rcp IS

    SELECT *

      FROM ajcl_bc_lbx_receipts

     WHERE status = 'NEW'

       AND lockboxID = p_lockboxID

       AND request_id = gv_request_id

       AND bc_environment = gv_bc_environment

       -- 2025 - KANO

       AND journal_batch_name = gv_journal_batch_name

       -- 2025 - KANO

       ;



    v_url             VARCHAR2(2000);

    v_error_message   VARCHAR2(2000);

    v_body            VARCHAR2(2000);

    v_clob_result     CLOB;



  BEGIN



    print_log ('ajcl_bc_lockbox_pkg.call_rcp_ws_p (+)');



    FOR crcp IN c_rcp LOOP



      v_error_message := NULL;

      print_log ('lockboxReceiptNumber: ' || crcp.lockboxReceiptNumber); 

      print_log ('customerNo: ' || crcp.customerNo); 



      v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                            p_entity => 'INBOUND RECEIPTS',

                                                            p_subentity => NULL,

                                                            p_method => 'POST',

                                                            p_company_id => gv_bc_company_id );



      print_log('v_url: ' || v_url);



      -- 20260106 REINTENTO

      gv_retry := 'N';



      BEGIN

      -- 20260106 REINTENTO



        v_clob_result := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_url),

                                                                    p_request_header_name1 => 'Content-Type',

                                                                    p_request_header_value1 => 'application/json',

                                                                    p_request_header_name2 => NULL,

                                                                    p_request_header_value2 => NULL,

                                                                    p_http_method => 'POST',

                                                                    p_body => crcp.json_data );



        print_log ( 'v_clob_result: ' || v_clob_result);



        -- 20260106 REINTENTO

        IF ( UPPER(v_clob_result) LIKE UPPER('%502 Bad Gateway%') ) THEN



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



        v_clob_result := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_url),

                                                                    p_request_header_name1 => 'Content-Type',

                                                                    p_request_header_value1 => 'application/json',

                                                                    p_request_header_name2 => NULL,

                                                                    p_request_header_value2 => NULL,

                                                                    p_http_method => 'POST',

                                                                    p_body => crcp.json_data );



      END IF;

      -- 20260106 REINTENTO



      IF ( UPPER(v_clob_result) LIKE '%"ERROR":%' ) THEN



        print_log ( 'Error sending receipt.' );



        v_error_message := SUBSTR(SUBSTR(v_clob_result,INSTR(v_clob_result,'message') + 10),1,INSTR(SUBSTR(v_clob_result,INSTR(v_clob_result,'message') + 10),'CorrelationId') - 1);



        print_log ( v_error_message );



        UPDATE ajcl_bc_lbx_receipts

           SET status = 'ERROR',

               error_message = v_error_message,

               json_data_response = v_clob_result

         WHERE status = 'NEW'

           AND lockboxID = crcp.lockboxID

           AND request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           -- 2025 - KANO

           AND journal_batch_name = gv_journal_batch_name

           -- 2025 - KANO

           ;



        p_status := 'E';



      ELSE



        UPDATE ajcl_bc_lbx_receipts

           SET status = 'SENT',

               json_data_response = v_clob_result

         WHERE status = 'NEW'

           AND lockboxID = crcp.lockboxID

           AND request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           -- 2025 - KANO

           AND journal_batch_name = gv_journal_batch_name

           -- 2025 - KANO

           ;



        print_log ( 'The receipt was sent successfully.' );

        p_status := 'S';



      END IF;



    END LOOP;



    p_status := 'S';



    print_log ('ajcl_bc_lockbox_pkg.call_rcp_ws_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_error_msg := SQLERRM;

      print_log ('ajcl_bc_lockbox_pkg.call_rcp_ws_p (!). Error: ' || SQLERRM);

      p_status := 'E';



  END call_rcp_ws_p;



  PROCEDURE call_rcp_job_p ( p_lockboxID              IN   NUMBER,

                             p_lockboxReceiptNumber   IN   VARCHAR2,

                             p_customerNo             IN   VARCHAR2,

                             p_status                OUT   VARCHAR2,

                             p_error_msg             OUT   VARCHAR2 ) IS



    v_api                   VARCHAR2(500);

    v_url                   VARCHAR2(500);

    v_body                  CLOB;         



    v_status                VARCHAR2(20);

    v_clob_response         CLOB;



  BEGIN



    print_log ('ajcl_bc_lockbox_pkg.call_rcp_job_p (+)');

    print_log ( TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS') );



    v_api := ajcl_bc_ws_utils_pkg.get_api_f ( p_entity => 'JOB QUEUE RECEIPTS',

                                              p_subentity => NULL,

                                              p_method => 'POST' );

    print_log('v_api: ' || v_api);



    v_url := ajcl_bc_ws_utils_pkg.get_base_standard_url_f ( gv_bc_environment, v_api, gv_bc_company_id );

    print_log('v_url: ' || v_url);



    v_body := '{"pLockBoxID": "' || p_lockboxID || '"}';



    print_log('v_body: ' || v_body);



    v_clob_response := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url,

                                                                  p_request_header_name1 => 'Content-Type',

                                                                  p_request_header_value1 => 'application/json',

                                                                  p_request_header_name2 => NULL,

                                                                  p_request_header_value2 => NULL,

                                                                  p_http_method => 'POST',

                                                                  p_body => v_body );



    print_log ( v_clob_response );



    IF ( UPPER(v_clob_response) LIKE '%SUCCESS%' ) THEN



      print_log('The Receipts job was executed successfully and the receipt could be created/posted.');

      v_status := 'SUCCESS'; 



    ELSIF ( UPPER(v_clob_response) LIKE '%ERROR%' ) THEN



      print_log('An error occurred while running the Receipts job and the receipt could not be created/posted.');

      v_status := 'ERROR'; 



    END IF;



    -- Se inserta registro de control

    INSERT

      INTO ajcl_bc_lbx_control

           ( bc_environment,

             request_id,

             action,

             lockbox_receipt_number,

             customer_number,

             org_id,

             status,

             job_response,

             creation_date )

    VALUES ( gv_bc_environment,

             gv_request_id, 

             'CREATE',

             p_lockboxReceiptNumber,

             p_customerNo,

             gv_org_id,

             v_status,

             v_clob_response,

             SYSDATE );



    p_status := 'S';



    print_log ('ajcl_bc_lockbox_pkg.call_rcp_job_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_error_msg := SQLERRM;

      print_log ('ajcl_bc_lockbox_pkg.call_rcp_job_p (!). Error: ' || SQLERRM);

      p_status := 'E';



  END call_rcp_job_p; 



  PROCEDURE call_rcp_del_p ( p_lockboxID        IN   NUMBER,

                             p_error_message   OUT   VARCHAR2,

                             p_status          OUT   VARCHAR2 ) IS



    v_del_url    VARCHAR2(2000);

    v_del_clob   CLOB;



  BEGIN



    print_log ('ajcl_bc_lockbox_pkg.call_rcp_del_p (+)');



    v_del_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                              p_entity => 'INBOUND RECEIPTS',

                                                              p_subentity => NULL,

                                                              p_method => 'DELETE',

                                                              p_company_id => gv_bc_company_id ) 

                 || '(' || p_lockboxID || ')';



    print_log ('v_del_url: ' || v_del_url);



    v_del_clob := ajcl_bc_ws_utils_pkg.delete_bc_row_f ( p_url => v_del_url );



    IF ( UPPER(v_del_clob) LIKE '%"ERROR":%' ) THEN



      print_log('Error deleting Receipt from inbound table.');

      print_log (v_del_clob);



    ELSE



      print_log('Receipt deleted from inbound table.');



    END IF;



    print_log ('ajcl_bc_lockbox_pkg.call_rcp_del_p (-)');



  END call_rcp_del_p;



  PROCEDURE call_rcp_status_p ( p_lockboxID     IN   NUMBER,

                                --

                                p_documentNo   OUT   VARCHAR2,

                                p_entryNo      OUT   NUMBER,

                                p_status       OUT   VARCHAR2,

                                p_error_msg    OUT   VARCHAR2 ) IS



    v_url                  VARCHAR2(2000);

    v_clob_response        CLOB;



    v_status               VARCHAR2(1);

    v_error_message        VARCHAR2(2000);



    CURSOR c_status ( p_clob_result_status   IN   CLOB ) IS

    SELECT lockboxID,

           entryNo,

           documentNo,

           customerNo,

           amount,

           status,

           statusRemarks,

           lockboxReceiptNumber,

           requestID

      FROM json_table( p_clob_result_status,

                       '$.value[*]' COLUMNS ( lockboxID              VARCHAR2(4000)  path '$.lockboxID',

                                              entryNo                VARCHAR2(4000)  path '$.entryNo',

                                              documentNo             VARCHAR2(4000)  path '$.documentNo',

                                              customerNo             VARCHAR2(4000)  path '$.accountNo',

                                              amount                 VARCHAR2(4000)  path '$.amount',

                                              status                 VARCHAR2(4000)  path '$.status',

                                              statusremarks          VARCHAR2(4000)  path '$.statusRemarks',

                                              lockboxReceiptNumber   VARCHAR2(4000)  path '$.lockboxReceiptNumber',

                                              requestID              VARCHAR2(4000)  path '$.requestID' ) );



    e_cust_exception       EXCEPTION;



  BEGIN



    print_log ('ajcl_bc_lockbox_pkg.call_rcp_status_p (+)');



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                          p_entity => 'INBOUND RECEIPTS',

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id )

             || '?$filter=lockboxID eq ' || p_lockboxID; 



    print_log ( 'v_url: ' || v_url );



    -- 20260106 REINTENTO

    gv_retry := 'N';



    BEGIN

    -- 20260106 REINTENTO



      v_clob_response := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



      -- 20260106 REINTENTO

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

    -- 20260106 REINTENTO 



    FOR cs IN c_status ( v_clob_response ) LOOP



      IF ( cs.status != 'Success' ) THEN



        print_log ( SUBSTR(cs.lockboxID || '-' || 

                           cs.lockboxReceiptNumber || '-' || 

                           cs.documentNo || '-' || 

                           cs.entryNo || '-' || 

                           cs.customerNo || '-' || 

                           cs.amount || '-' || 

                           cs.status || '-' || 

                           cs.statusRemarks,1,2000) );



        print_log ( ' ' );



        -- Se actualiza la tabla custom con el status REJECTED

        UPDATE ajcl_bc_lbx_receipts

           SET status = 'REJECTED',

               error_message = cs.statusRemarks

         WHERE status = 'SENT'

           AND lockboxID = cs.lockboxID

           AND request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           -- 2025 - KANO

           AND journal_batch_name = gv_journal_batch_name

           -- 2025 - KANO

           ;



        -- Se borra el receipt de las tabla inbound

        call_rcp_del_p ( p_lockboxID => cs.lockboxID,

                         p_error_message => v_error_message,

                         p_status => v_status );



        p_status := 'E';



      ELSE



        p_documentNo := cs.documentNo;

        p_entryNo := cs.entryNo;



        -- Se actualiza la tabla custom con el status SUCCESS

        UPDATE ajcl_bc_lbx_receipts

           SET status = 'SUCCESS',

               entryNo = cs.entryNo,

               documentNo = cs.documentNo

         WHERE status = 'SENT'

           AND lockboxID = cs.lockboxID

           AND request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           -- 2025 - KANO

           AND journal_batch_name = gv_journal_batch_name

           -- 2025 - KANO

           ;



        p_status := 'S';



      END IF;



    END LOOP;



    p_status := 'S';



    print_log ('ajcl_bc_lockbox_pkg.call_rcp_status_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_error_msg := SQLERRM;

      print_log ('ajcl_bc_lockbox_pkg.call_rcp_status_p (!). Error: ' || SQLERRM);

      p_status := 'E';



  END call_rcp_status_p; 



  PROCEDURE create_rcp_bc_p ( p_lockboxReceiptNumber      IN   VARCHAR2,

                              p_customer_id               IN   NUMBER,

                              p_postingDate               IN   VARCHAR2,

                              p_currencyCode              IN   VARCHAR2,

                              p_amount                    IN   NUMBER,

                              p_comments                  IN   VARCHAR2,

                              p_customerBankABA           IN   VARCHAR2,

                              p_customerBankAccount       IN   VARCHAR2,

                              p_ACHWireBankCustCodeName   IN   VARCHAR2,

                              p_typeOfReceipt             IN   VARCHAR2,

                              --

                              p_payment_num               IN   VARCHAR2,

                              p_payment_date              IN   VARCHAR2,

                              p_payor_account_num         IN   VARCHAR2,

                              p_originating_bank_aba      IN   VARCHAR2,

                              p_data_payment_line_num     IN   NUMBER,

                              --

                              p_documentNo               OUT   VARCHAR2,

                              p_entryNo                  OUT   NUMBER,

                              p_status                   OUT   VARCHAR2,

                              p_error_msg                OUT   VARCHAR2 ) IS



    v_customerNo     VARCHAR2(20);

    v_customerName   VARCHAR2(100);

    v_lockboxID      NUMBER;

    v_status         VARCHAR2(1);



    e_rcp_error      EXCEPTION; 



  BEGIN



    print_log ('ajcl_bc_lockbox_pkg.create_rcp_bc_p (+)');



    -- Se obtiene customerNo y customerName del customer_id

    SELECT customer_number,

           customer_name

      INTO v_customerNo,

           v_customerName

      FROM ra_customers

     WHERE customer_id = p_customer_id;



    print_log ('v_customerNo: ' || v_customerNo);

    print_log ('v_customerName: ' || v_customerName);



    insert_rcp_bc_p ( p_lockboxReceiptNumber => p_lockboxReceiptNumber,

                      p_customerNo => v_customerNo,

                      p_customerName => v_customerName,

                      p_postingDate => p_postingDate,

                      p_currencyCode => p_currencyCode,

                      p_amount => p_amount,

                      p_comments => p_comments,

                      p_customerBankABA => p_customerBankABA,

                      p_customerBankAccount => p_customerBankAccount,

                      p_ACHWireBankCustCodeName => p_ACHWireBankCustCodeName,

                      p_typeOfReceipt => p_typeOfReceipt,

                      --

                      p_payment_num => p_payment_num,

                      p_payment_date => p_payment_date,

                      p_payor_account_num => p_payor_account_num,

                      p_originating_bank_aba => p_originating_bank_aba,

                      p_data_payment_line_num => p_data_payment_line_num,

                      --

                      p_lockboxID => v_lockboxID,

                      p_status => v_status,

                      p_error_msg => p_error_msg );



    IF ( v_status != 'S' ) THEN



      RAISE e_rcp_error;



    END IF;  



    gv_process_name := ajcl_bc_ws_utils_pkg.get_lock_process_name_f ( p_integration => 'RECEIPTS' );

    print_log ( 'gv_process_name: ' || gv_process_name );



    -- Lock & Release

    ajc_bc_dbms_lock_pkg.lock_p ( p_process_name => gv_process_name,

                                  p_id_lock => gv_id_lock,

                                  p_request_status => gv_request_status ); 



    IF ( gv_request_status != 'success' ) THEN



      RAISE ge_lock;



    END IF;

    -- Lock & Release



    call_rcp_ws_p ( p_lockboxID => v_lockboxID,

                    --

                    p_status => p_status,

                    p_error_msg => p_error_msg );



    IF ( p_status != 'S' ) THEN



      RAISE e_rcp_error;



    END IF;



    call_rcp_job_p ( p_lockboxID => v_lockboxID,

                     p_lockboxReceiptNumber => p_lockboxReceiptNumber,

                     p_customerNo => v_customerNo,

                     --

                     p_status => v_status,

                     p_error_msg => p_error_msg );



    IF ( v_status != 'S' ) THEN



      RAISE e_rcp_error;



    END IF;



    -- Lock & Release

    ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                     p_release_status => gv_release_status );



    IF ( gv_release_status != 'success' ) THEN



      RAISE ge_release;



    END IF;                                     

    -- Lock & Release



    call_rcp_status_p ( p_lockboxID => v_lockboxID,

                        p_documentNo => p_documentNo,

                        p_entryNo => p_entryNo,

                        --

                        p_status => v_status,

                        p_error_msg => p_error_msg );



    IF ( v_status != 'S' ) THEN



      RAISE e_rcp_error;



    END IF;                      



    print_log ('p_documentNo: ' || p_documentNo);

    print_log ('p_entryNo: ' || p_entryNo);



    p_status := 'S';



    print_log ('ajcl_bc_lockbox_pkg.create_rcp_bc_p (-)');



  EXCEPTION

    -- Lock & Release

    WHEN ge_lock THEN

      print_log ('Error when trying to lock the process: ' || gv_process_name || ' | gv_request_status: ' || gv_request_status);

      p_status := 'E';



    WHEN ge_release THEN

      print_log ('Error when trying to release the process: ' || gv_process_name || ' | gv_release_status: ' || gv_release_status);

      p_status := 'E';

    -- Lock & Release



    WHEN e_rcp_error THEN

      p_status := 'E';

      p_error_msg := 'Receipt creation failed for Lockbox Receipt Number ' || p_lockboxReceiptNumber;



      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );

      -- Lock & Release



      print_log ('ajcl_bc_lockbox_pkg.create_rcp_bc_p (!). Error: ' || p_error_msg);



    WHEN OTHERS THEN

      p_status := 'E';

      p_error_msg := SQLERRM;



      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );

      -- Lock & Release



      print_log ('ajcl_bc_lockbox_pkg.create_rcp_bc_p (!). Error: ' || SQLERRM);



  END create_rcp_bc_p;



  -- BC ------------------------------------------------------------------------------------------------------------------------

  -- Procedimientos para APLICACION DE RECIBOS -----------------------------------------------------------------------------------

  ------------------------------------------------------------------------------------------------------------------------------

  PROCEDURE insert_app_bc_p ( p_rcp_entryNo      IN   NUMBER,

                              p_trx_entryNo      IN   NUMBER,

                              p_trx_id           IN   NUMBER,

                              p_posting_date     IN   DATE,

                              p_currency_code    IN   VARCHAR2,

                              p_amount           IN   NUMBER,                           

                              --

                              p_status          OUT   VARCHAR2,

                              p_error_msg       OUT   VARCHAR2 ) IS



    v_customerNo          ajcl_bc_lbx_receipts.customerNo%TYPE;

    v_customerName        ajcl_bc_lbx_receipts.customerName%TYPE;

    v_documentNo          ajcl_bc_lbx_receipts.documentNo%TYPE;

    v_appliesToDocType    ajcl_bc_lbx_rcp_applications.appliesToDocType%TYPE;

    v_appliesToDocNo      ajcl_bc_lbx_rcp_applications.appliesToDocNo%TYPE; 

    -- 2025 - KANO

    v_posted_sd_company   ajcl_bc_posted_sd_headers.company%TYPE;

    -- 2025 - KANO



    v_tbl_status          ajcl_bc_lbx_rcp_applications.status%TYPE;    

    v_tbl_error_msg       ajcl_bc_lbx_rcp_applications.error_message%TYPE;    



    v_json_data           CLOB;

    e_get_rcp_trx_data    EXCEPTION;



  BEGIN



    print_log ('ajcl_bc_lockbox_pkg.insert_app_bc_p (+)');



    -- Se obtienen los datos del rcp para generar la aplicacion

    BEGIN



      -- Datos del recibo

      SELECT customerNo,

             customerName,

             documentNo

        INTO v_customerNo,

             v_customerName,

             v_documentNo

        FROM ajcl_bc_lbx_receipts rcp

       WHERE status = 'SUCCESS'

         AND entryNo = p_rcp_entryNo

         AND request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         -- 2025 - KANO

         AND journal_batch_name = gv_journal_batch_name

         -- 2025 - KANO

         ;



      -- Datos del Sales Document al que aplica

      IF ( p_trx_entryNo IS NOT NULL ) THEN



        SELECT psdh.transactionNo,

               DECODE(psdh.class,'INV','Invoice','CM','Credit Memo',psdh.class),

               -- 2025 - KANO

               psdh.company

               -- 2025 - KANO

          INTO v_appliesToDocNo,

               v_appliesToDocType,

               -- 2025 - KANO

               v_posted_sd_company

               -- 2025 - KANO

          FROM ajcl_bc_posted_sd_headers psdh

         WHERE psdh.bc_environment = gv_bc_environment

           AND psdh.entryNo = p_trx_entryNo;



        -- 2025 - KANO

        IF ( ( gv_journal_batch_name = 'LOCKBOX' AND v_posted_sd_company = '53' ) OR

             ( gv_journal_batch_name = 'LBX KANO' AND v_posted_sd_company = '52' ) ) THEN

        -- 2025 - KANO             



          -- Se inserta con este status para procesarla

          v_tbl_status := 'NEW';

          v_tbl_error_msg := NULL;



        -- 2025 - KANO  

        ELSE



          -- Se inserta con este status para NO procesarla, pero que se informe en el reporte

          v_tbl_status := 'ERROR';

          v_tbl_error_msg := 'Cannot apply receipt to this document: company mismatch.';



        END IF;

        -- 2025 - KANO



       END IF;



    EXCEPTION 

      WHEN OTHERS THEN

        p_error_msg := 'Error when obtaining rcp and trx data.';

        RAISE e_get_rcp_trx_data;



    END;



    -- Solo se arma el json cuando aplica a una trx de BC y quedo con status para ser procesada

    -- 2025 - KANO

    -- IF ( p_trx_entryNo IS NOT NULL ) THEN

    IF ( p_trx_entryNo IS NOT NULL AND v_tbl_status = 'NEW' ) THEN

    -- 2025 - KANO



      -- Se arma el json

      APEX_JSON.initialize_clob_output;

      APEX_JSON.open_object;



      APEX_JSON.write('customerNo',v_customerNo,true);

      APEX_JSON.write('documentNo',v_documentNo,true);

      APEX_JSON.write('receiptEntryNo',p_rcp_entryNo,true);

      APEX_JSON.write('currencyCode',p_currency_code,true);

      APEX_JSON.write('amountToApply',-1 * ABS(p_amount),true);

      APEX_JSON.write('appliesToDocType',v_appliesToDocType,true);

      APEX_JSON.write('appliesToDocNo',v_appliesToDocNo,true);

      APEX_JSON.write('appliesToEntryNo',p_trx_entryNo,true);    

      APEX_JSON.write('postingDate',TO_CHAR(NVL(p_posting_date,SYSDATE),'YYYY-MM-DD'),true); 

      APEX_JSON.write('requestID',gv_request_id,true);

      APEX_JSON.close_object;



      v_json_data := APEX_JSON.get_clob_output;

      print_log ( 'v_json_data: ' || v_json_data );



      APEX_JSON.free_output;



    END IF;      



    INSERT

        INTO ajcl_bc_lbx_rcp_applications

           ( bc_environment,

             receiptEntryNo,

             documentNo,

             customerNo,

             customerName,

             currencyCode,

             postingDate,

             --

             appliesToDocType,

             appliesToEntryNo,

             appliesToDocNo,             

             --

             amountToApply,

             -- 2025 - KANO

             journal_batch_name,

             -- 2025 - KANO

             json_data,

             request_id,

             status,

             error_message,

             creation_date,

             created_by,

             last_update_date,

             last_updated_by )

    VALUES ( gv_bc_environment,

             p_rcp_entryNo,

             v_documentNo,

             v_customerNo,

             v_customerName,

             p_currency_code,

             TO_CHAR(p_posting_date,'YYYY-MM-DD'),

             --

             v_appliesToDocType, 

             p_trx_entryNo, -- appliesToEntryNo

             v_appliesToDocNo, 

             --

             -1 * ABS(p_amount), -- amountToApply

             -- 2025 - KANO

             gv_journal_batch_name,

             -- 2025 - KANO

             v_json_data,

             gv_request_id, 

             v_tbl_status,

             v_tbl_error_msg,

             SYSDATE, -- creation_date

             gv_user_id, -- created_by

             SYSDATE, -- last_update_date

             gv_user_id -- last_updated_by 

             );



    COMMIT;



    p_status := 'S';



    print_log ('ajcl_bc_lockbox_pkg.insert_app_bc_p (-)');



  EXCEPTION

    WHEN e_get_rcp_trx_data THEN

      print_log ('ajcl_bc_lockbox_pkg.insert_app_bc_p (!). Error: ' || p_error_msg);

      p_status := 'E';



    WHEN OTHERS THEN

      p_error_msg := SQLERRM;

      print_log ('ajcl_bc_lockbox_pkg.insert_app_bc_p (!). Error: ' || SQLERRM);

      p_status := 'E';



  END insert_app_bc_p;



  PROCEDURE call_app_ws_p ( p_rcp_entryNo   IN   NUMBER,

                            p_trx_entryNo   IN   NUMBER,

                            p_status       OUT   VARCHAR2,

                            p_error_msg    OUT   VARCHAR2 ) IS



    CURSOR c_app IS

    SELECT *

      FROM ajcl_bc_lbx_rcp_applications

     WHERE request_id = gv_request_id

       AND bc_environment = gv_bc_environment

       AND status = 'NEW'

       AND receiptEntryNo = p_rcp_entryNo

       AND appliesToEntryNo = p_trx_entryNo

       -- 2025 - KANO

       AND journal_batch_name = gv_journal_batch_name

       -- 2025 - KANO

       ;



    v_url             VARCHAR2(2000);

    v_error_message   VARCHAR2(2000);

    v_body            VARCHAR2(2000);

    v_clob_result     CLOB;



  BEGIN



    print_log ('ajcl_bc_lockbox_pkg.call_app_ws_p (+)');



    FOR capp IN c_app LOOP



      v_error_message := NULL;

      print_log ('DocumentNo: ' || capp.DocumentNo); 

      print_log ('trxDocumentNo: ' || capp.appliesToDocNo); 

      print_log ('customerNo: ' || capp.customerNo); 

      print_log ('customerName: ' || capp.customerName); 



      v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                            p_entity => 'INBOUND RECEIPT APPLICATIONS',

                                                            p_subentity => NULL,

                                                            p_method => 'POST',

                                                            p_company_id => gv_bc_company_id );



      print_log('v_url: ' || v_url);



      -- 20260106 REINTENTO

      gv_retry := 'N';



      BEGIN

      -- 20260106 REINTENTO



        v_clob_result := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_url),

                                                                    p_request_header_name1 => 'Content-Type',

                                                                    p_request_header_value1 => 'application/json',

                                                                    p_request_header_name2 => NULL,

                                                                    p_request_header_value2 => NULL,

                                                                    p_http_method => 'POST',

                                                                    p_body => capp.json_data );



        -- 20260106 REINTENTO

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



        v_clob_result := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_url),

                                                                    p_request_header_name1 => 'Content-Type',

                                                                    p_request_header_value1 => 'application/json',

                                                                    p_request_header_name2 => NULL,

                                                                    p_request_header_value2 => NULL,

                                                                    p_http_method => 'POST',

                                                                    p_body => capp.json_data );



      END IF;

      -- 20260106 REINTENTO 



      print_log ( 'v_clob_result: ' || v_clob_result);



      IF ( UPPER(v_clob_result) LIKE '%"ERROR":%' ) THEN



        print_log ( 'Error sending receipt application.' );



        v_error_message := SUBSTR(v_clob_result,INSTR(v_clob_result,'message') + 10);



        -- Se captura el error de no poder aplicar el mismo recibo al mismo comprobante y se muestra un mensaje mas amigable para el usuario

        IF ( UPPER(v_error_message) LIKE UPPER('%The record in table%already exists%Identification fields and values%Receipt Entry No%Applies To Entry No%') ) THEN



          v_error_message := 'Receipt cannot be applied more than once to the same ' || LOWER(capp.appliestodoctype) || '.';



        END IF;



        print_log ( v_error_message );



        UPDATE ajcl_bc_lbx_rcp_applications

           SET status = 'ERROR',

               error_message = v_error_message,

               json_data_response = v_clob_result

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND status = 'NEW'

           AND receiptEntryNo = capp.receiptEntryNo

           AND appliesToEntryNo = capp.appliesToEntryNo

           -- 2025 - KANO

           AND journal_batch_name = gv_journal_batch_name

           -- 2025 - KANO

           ;



      ELSE



        UPDATE ajcl_bc_lbx_rcp_applications

           SET status = 'SENT',

               json_data_response = v_clob_result

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND status = 'NEW'

           AND receiptEntryNo = capp.receiptEntryNo

           AND appliesToEntryNo = capp.appliesToEntryNo

           -- 2025 - KANO

           AND journal_batch_name = gv_journal_batch_name

           -- 2025 - KANO

           ;



        print_log ( 'The receipt application was successfully submitted.' );



      END IF;



    END LOOP;



    p_status := 'S';



    print_log ('ajcl_bc_lockbox_pkg.call_app_ws_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_error_msg := SQLERRM;

      print_log ('ajcl_bc_lockbox_pkg.call_app_ws_p (!). Error: ' || SQLERRM);

      p_status := 'E';



  END call_app_ws_p;



  PROCEDURE call_app_job_p ( p_rcp_entryNo    IN   NUMBER,

                             p_trx_entryNo    IN   NUMBER,

                             --

                             p_status       OUT   VARCHAR2,

                             p_error_msg    OUT   VARCHAR2 ) IS



    v_api               VARCHAR2(500);

    v_url               VARCHAR2(500);

    v_body              CLOB;         



    v_status            VARCHAR2(20);

    v_clob_response     CLOB;



  BEGIN



    print_log ('ajcl_bc_lockbox_pkg.call_app_job_p (+)');

    print_log ( TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS') );



    v_api := ajcl_bc_ws_utils_pkg.get_api_f ( p_entity => 'JOB QUEUE RECEIPT APPLICATIONS',

                                              p_subentity => NULL,

                                              p_method => 'POST' );

    print_log('v_api: ' || v_api);



    v_url := ajcl_bc_ws_utils_pkg.get_base_standard_url_f ( gv_bc_environment, v_api, gv_bc_company_id );

    print_log('v_url: ' || v_url);



    v_body := '{"p_rcpEntryNo": "' || p_rcp_entryNo || '",' ||

              ' "p_trxEntryNo": "' || p_trx_entryNo || '"}';



    print_log('v_body: ' || v_body);



    v_clob_response := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url,

                                                                  p_request_header_name1 => 'Content-Type',

                                                                  p_request_header_value1 => 'application/json',

                                                                  p_request_header_name2 => NULL,

                                                                  p_request_header_value2 => NULL,

                                                                  p_http_method => 'POST',

                                                                  p_body => v_body );



    IF ( UPPER(v_clob_response) LIKE '%SUCCESS%' ) THEN



      print_log('The Receipts Applications job was executed successfully and the application could be created/posted.');

      v_status := 'SUCCESS'; 



    ELSIF ( UPPER(v_clob_response) LIKE '%ERROR%' ) THEN



      print_log('An error occurred while running the Receipts Applications job and the application could not be created/posted.');

      v_status := 'ERROR'; 



    END IF;



    -- Se inserta registro de control

    INSERT

      INTO ajcl_bc_lbx_control

           ( bc_environment,

             request_id,

             action,

             entryNo,

             appliesToEntryNo,

             org_id,

             status,

             job_response,

             creation_date )

    VALUES ( gv_bc_environment,

             gv_request_id, 

             'APPLY',

             p_rcp_entryNo,

             p_trx_entryNo,

             gv_org_id,

             v_status,

             v_clob_response,

             SYSDATE );



    p_status := 'S';



    print_log ('ajcl_bc_lockbox_pkg.call_app_job_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_error_msg := SQLERRM;

      print_log ('ajcl_bc_lockbox_pkg.call_app_job_p (!). Error: ' || SQLERRM);

      p_status := 'E';



  END call_app_job_p; 



  PROCEDURE call_app_del_p ( p_rcp_entryNo   IN   NUMBER,

                             p_trx_entryNo   IN   NUMBER,

                             p_customerNo    IN   NUMBER,

                             --

                             p_status       OUT   VARCHAR2,

                             p_error_msg    OUT   VARCHAR2 ) IS



    v_del_url    VARCHAR2(2000);

    v_del_clob   CLOB;



  BEGIN



    print_log ('ajcl_bc_lockbox_pkg.call_app_del_p (+)');



    v_del_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                              p_entity => 'INBOUND RECEIPT APPLICATIONS',

                                                              p_subentity => NULL,

                                                              p_method => 'DELETE',

                                                              p_company_id => gv_bc_company_id ) 

                 || '(' || p_rcp_entryNo || ',' || p_trx_entryNo || ')';



    print_log ('v_del_url: ' || v_del_url);



    v_del_clob := ajcl_bc_ws_utils_pkg.delete_bc_row_f ( p_url => v_del_url );



    IF ( UPPER(v_del_clob) LIKE '%"ERROR":%' ) THEN



      print_log('Error deleting receipt application from inbound table.');

      print_log (v_del_clob);



    ELSE



      print_log('Receipt application deleted from inbound table.');



    END IF;

    --



    p_status := 'S';  



    print_log ('ajcl_bc_lockbox_pkg.call_app_del_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_error_msg := SQLERRM;

      print_log ('ajcl_bc_lockbox_pkg.call_app_del_p (!)');

      p_status := 'E';



  END call_app_del_p;



  PROCEDURE call_app_status_p ( p_rcp_entryNo   IN   NUMBER,

                                p_trx_entryNo   IN   NUMBER,

                                --

                                p_status       OUT   VARCHAR2,

                                p_error_msg    OUT   VARCHAR2 ) IS



    v_url                  VARCHAR2(2000);

    v_clob_response        CLOB;



    v_status               VARCHAR2(1);

    v_error_message        VARCHAR2(2000);



    CURSOR c_status ( p_clob_result_status   IN   CLOB ) IS

    SELECT receiptEntryNo,

           documentNo,

           customerNo,

           appliesToEntryNo,

           appliesToDocNo,

           amountToApply,

           applicationEntryNo,

           status,

           statusRemarks,

           requestID

      FROM json_table( p_clob_result_status,

                       '$.value[*]' COLUMNS ( receiptEntryNo       VARCHAR2(4000)  path '$.receiptEntryNo',

                                              documentNo           VARCHAR2(4000)  path '$.documentNo',

                                              customerNo           VARCHAR2(4000)  path '$.customerNo',

                                              appliesToEntryNo     VARCHAR2(4000)  path '$.appliesToEntryNo',

                                              appliesToDocNo       VARCHAR2(4000)  path '$.appliesToDocNo',

                                              amountToApply        VARCHAR2(4000)  path '$.amountToApply',

                                              applicationEntryNo   VARCHAR2(4000)  path '$.applicationEntryNo',

                                              status               VARCHAR2(4000)  path '$.status',

                                              statusRemarks        VARCHAR2(4000)  path '$.statusRemarks',

                                              requestID            VARCHAR2(4000)  path '$.requestID' ) )

     WHERE receiptEntryNo = p_rcp_entryNo

       AND appliesToEntryNo = p_trx_entryNo

       AND requestID = gv_request_id;



    e_cust_exception       EXCEPTION;



  BEGIN



    print_log ('ajcl_bc_lockbox_pkg.call_app_status_p (+)');



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                          p_entity => 'INBOUND RECEIPT APPLICATIONS',

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id )

             || '?$filter=requestID eq ' || gv_request_id;



    print_log ( 'v_url: ' || v_url );



    -- 20260106 REINTENTO

    gv_retry := 'N';



    BEGIN

    -- 20260106 REINTENTO



      v_clob_response := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



      -- 20260106 REINTENTO

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

    -- 20260106 REINTENTO 



    FOR cs IN c_status ( v_clob_response ) LOOP



      IF ( cs.status != 'Success' ) THEN



        print_log ( SUBSTR(cs.documentNo || '-' ||  

                           cs.customerNo || '-' ||  

                           cs.appliesToEntryNo || '-' ||  

                           cs.appliesToDocNo || '-' ||  

                           cs.amountToApply || '-' ||  

                           cs.status || '-' ||  

                           cs.statusRemarks,1,2000) );



        -- Se actualiza la tabla custom con el status REJECTED

        UPDATE ajcl_bc_lbx_rcp_applications

           SET status = 'REJECTED',

               error_message = cs.statusremarks

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND status = 'SENT'

           AND receiptEntryNo = cs.receiptEntryNo

           AND appliesToEntryNo = cs.appliesToEntryNo

           AND customerNo = cs.customerNo

           -- 2025 - KANO

           AND journal_batch_name = gv_journal_batch_name

           -- 2025 - KANO

           ;



        -- Se borra el receipt de las tabla inbound

        call_app_del_p ( p_rcp_entryNo => cs.receiptEntryNo,

                         p_trx_entryNo => cs.appliesToEntryNo,

                         p_customerNo => cs.customerNo,

                         --

                         p_status => v_status,

                         p_error_msg => p_error_msg );



        p_status := 'E';



      ELSE



        -- Se actualiza la tabla custom con el status SUCCESS

        UPDATE ajcl_bc_lbx_rcp_applications

           SET status = 'SUCCESS',

               applicationEntryNo = cs.applicationEntryNo

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND status = 'SENT'

           AND receiptEntryNo = cs.receiptEntryNo

           AND appliesToEntryNo = cs.appliesToEntryNo

           AND customerNo = cs.customerNo

           -- 2025 - KANO

           AND journal_batch_name = gv_journal_batch_name

           -- 2025 - KANO

           ;



        p_status := 'S';



      END IF;



    END LOOP;



    p_status := 'S';



    print_log ('ajcl_bc_lockbox_pkg.call_app_status_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_error_msg := SQLERRM;

      print_log ('ajcl_bc_lockbox_pkg.call_app_status_p (!). Error: ' || SQLERRM);

      p_status := 'E';



  END call_app_status_p; 



  PROCEDURE process_app_bc_p ( p_rcp_entryNo     IN   NUMBER,

                               p_trx_entryNo     IN   NUMBER,

                               p_trx_id          IN   NUMBER,

                               p_posting_date    IN   DATE,

                               p_currency_code   IN   VARCHAR2,

                               p_amount          IN   NUMBER,

                               --

                               p_status         OUT   VARCHAR2,

                               p_error_msg      OUT   VARCHAR2 ) IS



    e_app_error      EXCEPTION; 



  BEGIN



    print_log ('ajcl_bc_lockbox_pkg.process_app_bc_p (+)');



    IF ( p_trx_entryNo IS NOT NULL ) THEN



      insert_app_bc_p ( p_rcp_entryNo => p_rcp_entryNo,

                        p_trx_entryNo => p_trx_entryNo,

                        p_trx_id => p_trx_id,

                        p_posting_date => p_posting_date,

                        p_currency_code => p_currency_code,

                        p_amount => p_amount,

                        --

                        p_status => p_status,

                        p_error_msg => p_error_msg );



      IF ( p_status != 'S' ) THEN



        RAISE e_app_error;



      END IF;  



      gv_process_name := ajcl_bc_ws_utils_pkg.get_lock_process_name_f ( p_integration => 'RECEIPT APPLICATIONS' );

      print_log ( 'gv_process_name: ' || gv_process_name );



      -- Lock & Release

      ajc_bc_dbms_lock_pkg.lock_p ( p_process_name => gv_process_name,

                                    p_id_lock => gv_id_lock,

                                    p_request_status => gv_request_status ); 



      IF ( gv_request_status != 'success' ) THEN



        RAISE ge_lock;



      END IF;

      -- Lock & Release



      call_app_ws_p ( p_rcp_entryNo => p_rcp_entryNo,

                      p_trx_entryNo => p_trx_entryNo,

                      --

                      p_status => p_status,

                      p_error_msg => p_error_msg );



      IF ( p_status != 'S' ) THEN



        RAISE e_app_error;



      END IF;



      call_app_job_p ( p_rcp_entryNo => p_rcp_entryNo,

                       p_trx_entryNo => p_trx_entryNo,

                       --

                       p_status => p_status,

                       p_error_msg => p_error_msg );



      IF ( p_status != 'S' ) THEN



        RAISE e_app_error;



      END IF;



      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );



      IF ( gv_release_status != 'success' ) THEN



        RAISE ge_release;



      END IF;                                     

      -- Lock & Release



      call_app_status_p ( p_rcp_entryNo => p_rcp_entryNo,

                          p_trx_entryNo => p_trx_entryNo,

                          --

                          p_status => p_status,

                          p_error_msg => p_error_msg );



      IF ( p_status != 'S' ) THEN



        RAISE e_app_error;



      END IF;



    END IF;



    p_status := 'S';



    print_log ('ajcl_bc_lockbox_pkg.process_app_bc_p (-)');



  EXCEPTION

    -- Lock & Release

    WHEN ge_lock THEN

      p_status := 'E';

      print_log ('Error when trying to lock the process: ' || gv_process_name || ' | gv_request_status: ' || gv_request_status);



    WHEN ge_release THEN

      p_status := 'E';

      print_log ('Error when trying to release the process: ' || gv_process_name || ' | gv_release_status: ' || gv_release_status);

    -- Lock & Release



    WHEN e_app_error THEN

      p_status := 'E';

      p_error_msg := 'Receipt application failed for rcp_entryNo ' || p_rcp_entryNo || ' and trx_entryNo ' || p_trx_entryNo;

      print_log (p_error_msg);



      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );

      -- Lock & Release



      print_log ('ajcl_bc_lockbox_pkg.process_app_bc_p (!)');



    WHEN OTHERS THEN

      p_status := 'E';

      p_error_msg := SQLERRM;



      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );

      -- Lock & Release



      print_log ('ajcl_bc_lockbox_pkg.process_app_bc_p (!). Error: ' || SQLERRM);



  END process_app_bc_p; 



  -- Reprocesa los recibos que no se pudieron enviar o fueron rechazados, asignandole el customer UNIDENTIFIED

  PROCEDURE reprocess_rcp_error_rejected_p ( p_status      OUT   VARCHAR2, 

                                             p_error_msg   OUT   VARCHAR2 ) IS



    CURSOR c_rcp_error_rejected IS

    SELECT lockboxID,

           lockboxReceiptNumber,

           customerNo,

           customerName,

           payment_num,

           payment_date,

           payor_account_num,

           originating_bank_aba,

           data_payment_line_num,

           TRIM(error_message) || ' - Customer replaced.' error_message

      FROM ajcl_bc_lbx_receipts

     WHERE status IN ('ERROR','REJECTED')

       AND request_id = gv_request_id

       AND bc_environment = gv_bc_environment

       -- 2025 - KANO

       AND journal_batch_name = gv_journal_batch_name

       -- 2025 - KANO

       ;



    v_documentNo             ajcl_bc_lbx_receipts.documentNo%TYPE;

    v_entryNo                ajcl_bc_lbx_receipts.entryNo%TYPE;



    v_url                    VARCHAR2(2000);

    v_clob_result            CLOB;



    v_status                 VARCHAR2(1);

    e_rcp_error              EXCEPTION;



  BEGIN



    print_log ('ajcl_bc_lockbox_pkg.reprocess_rcp_error_rejected_p (+)');



    FOR crer IN c_rcp_error_rejected LOOP



      BEGIN



        print_log ('lockboxID: ' || crer.lockboxID || ' | lockboxReceiptNumber: ' || crer.lockboxReceiptNumber || ' | v_customerNo: ' || crer.customerNo );



        UPDATE ajcl_bc_lbx_receipts

           SET status = 'NEW',

               error_message = crer.error_message,

               originalCustomerNo = crer.customerNo,

               originalCustomerName = crer.customerName,

               customerNo = gv_unidentified_no,

               customerName = gv_unidentified_name,

               json_data = REPLACE(json_data,'"accountNo":"' || crer.customerNo || '"','"accountNo":"' || gv_unidentified_no || '"'),

               json_data_response = NULL

         WHERE lockboxID = crer.lockboxID

           AND bc_environment = gv_bc_environment

           AND request_id = gv_request_id

           -- 2025 - KANO

           AND journal_batch_name = gv_journal_batch_name

           -- 2025 - KANO

           ;



        COMMIT;



        gv_process_name := ajcl_bc_ws_utils_pkg.get_lock_process_name_f ( p_integration => 'RECEIPTS' );

        print_log ( 'gv_process_name: ' || gv_process_name );



        -- Lock & Release

        ajc_bc_dbms_lock_pkg.lock_p ( p_process_name => gv_process_name,

                                      p_id_lock => gv_id_lock,

                                      p_request_status => gv_request_status ); 



        IF ( gv_request_status != 'success' ) THEN



          RAISE ge_lock;



        END IF;

        -- Lock & Release



        call_rcp_ws_p ( p_lockboxID => crer.lockboxID,

                        --

                        p_status => p_status,

                        p_error_msg => p_error_msg );



        IF ( p_status != 'S' ) THEN



          RAISE e_rcp_error;



        END IF;



        call_rcp_job_p ( p_lockboxID => crer.lockboxID,

                         p_lockboxReceiptNumber => crer.lockboxReceiptNumber,

                         p_customerNo => gv_unidentified_no,

                         --

                         p_status => p_status,

                         p_error_msg => p_error_msg );



        IF ( p_status != 'S' ) THEN



          RAISE e_rcp_error;



        END IF;



        -- Lock & Release

        ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                         p_release_status => gv_release_status );



        IF ( gv_release_status != 'success' ) THEN



          RAISE ge_release;



        END IF;                                     

        -- Lock & Release



        call_rcp_status_p ( p_lockboxID => crer.lockboxID,

                            p_documentNo => v_documentNo,

                            p_entryNo => v_entryNo,

                            --

                            p_status => p_status,

                            p_error_msg => p_error_msg );



        IF ( p_status != 'S' ) THEN



          RAISE e_rcp_error;



        END IF;   



        -- Se marca como procesado

        UPDATE ajc_truist_ar_lbx_bank_data

           SET processed_flag = 'Y',

               processed_date = SYSDATE

         WHERE NVL(payment_num,'X') = NVL(crer.payment_num,'X')

           AND NVL(payment_date,'X') = NVL(crer.payment_date,'X')

           AND NVL(processed_flag,'N') = 'N'

           AND NVL(payor_account_num,'X') = NVL(crer.payor_account_num,'X')

           AND NVL(originating_bank_aba,'X') = NVL(crer.originating_bank_aba,'X')

           AND data_payment_line_num = crer.data_payment_line_num

           -- 2025 - KANO

           AND journal_batch_name = gv_journal_batch_name

           -- 2025 - KANO

           ;



        print_log ('v_documentNo: ' || v_documentNo);

        print_log ('v_entryNo: ' || v_entryNo);



      EXCEPTION

        -- Lock & Release

        WHEN ge_lock THEN

          print_log ('Error when trying to lock the process: ' || gv_process_name || ' | gv_request_status: ' || gv_request_status);

          p_status := 'E';



        WHEN ge_release THEN

          print_log ('Error when trying to release the process: ' || gv_process_name || ' | gv_release_status: ' || gv_release_status);

          p_status := 'E';

        -- Lock & Release



        WHEN e_rcp_error THEN



          -- Lock & Release

          ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                           p_release_status => gv_release_status );

          -- Lock & Release



          print_log ('ajcl_bc_lockbox_pkg.reprocess_rcp_error_rejected_p (!)');

          print_log ('Receipt creation failed for Lockbox Receipt Number ' || crer.lockboxReceiptNumber);



        WHEN OTHERS THEN



          -- Lock & Release

          ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                           p_release_status => gv_release_status );

          -- Lock & Release



          print_log ('ajcl_bc_lockbox_pkg.reprocess_rcp_error_rejected_p (!). Error: ' || SQLERRM);



      END;



    END LOOP;



    COMMIT;



    p_status := 'S';



    print_log ('ajcl_bc_lockbox_pkg.reprocess_rcp_error_rejected_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_error_msg := SQLERRM;

      print_log ('ajcl_bc_lockbox_pkg.reprocess_rcp_error_rejected_p (!). Error: ' || SQLERRM);

      p_status := 'E';



  END reprocess_rcp_error_rejected_p;



  ------------------------------------------------------------------------------------------------------------------------------



  PROCEDURE final_report_csv_p ( p_status      OUT   VARCHAR2,

                                 p_error_msg   OUT   VARCHAR2 ) IS



      CURSOR c_receipts IS

      SELECT *

        FROM ajcl_bc_lbx_receipts

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         -- 2025 - KANO

         AND journal_batch_name = gv_journal_batch_name

         -- 2025 - KANO

    ORDER BY documentNo;



      CURSOR c_applications IS

      SELECT *

        FROM ajcl_bc_lbx_rcp_applications

       WHERE request_id = gv_request_id 

         AND bc_environment = gv_bc_environment

         -- 2025 - KANO

         AND journal_batch_name = gv_journal_batch_name

         -- 2025 - KANO

    ORDER BY documentNo,

             appliesToDocNo;



  BEGIN



    print_log( 'ajcl_bc_lockbox_pkg.final_report_csv_p (+)' );



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

                                        p_text => 'Receipts',

                                        p_request_id => gv_request_id );



    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Insert Table Column Names                            

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Document No.' || '|' ||

                                                  'Posting Date' || '|' ||

                                                  'Customer No.' || '|' ||

                                                  'Customer Name' || '|' ||

                                                  'Currency Code' || '|' ||

                                                  'Amount' || '|' ||

                                                  'Lockbox Receipt Number' || '|' ||

                                                  'Status' || '|' ||

                                                  'Error Message',

                                        p_request_id => gv_request_id );                                        



    -- Se insertan los registros

    FOR cr IN c_receipts LOOP



      ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                          p_text => cr.documentNo || '|' || 

                                                    cr.postingDate || '|' || 

                                                    cr.customerNo || '|' || 

                                                    cr.customerName || '|' || 

                                                    cr.currencyCode || '|' || 

                                                    cr.amount || '|' || 

                                                    cr.lockboxReceiptNumber || '|' ||  

                                                    cr.status || '|' || 

                                                    cr.error_message,

                                          p_request_id => gv_request_id );                                                          



    END LOOP;



    -- Tabla 2 -----------------------------------------------------------------------------------------------------------------

    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Insert Table Title

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Applications',

                                        p_request_id => gv_request_id );



    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Insert Table Column Names                            

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Receipt No.' || '|' ||

                                                  'Transaction No.' || '|' ||

                                                  'Amount To Apply' || '|' ||

                                                  'Status' || '|' ||

                                                  'Error Message',

                                        p_request_id => gv_request_id );  



    -- Se insertan los registros

    FOR ca IN c_applications LOOP



      ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                          p_text => ca.documentNo || '|' || 

                                                    ca.appliesToDocType || '|' || 

                                                    ca.appliesToDocNo || '|' || 

                                                    ca.amountToApply || '|' || 

                                                    ca.status || '|' || 

                                                    ca.error_message,

                                          p_request_id => gv_request_id );  



    END LOOP;



    p_status := 'S';



    print_log( 'ajcl_bc_lockbox_pkg.final_report_csv_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      p_error_msg := SQLERRM;

      print_log( 'ajcl_bc_lockbox_pkg.final_report_csv_p (!). Error: ' || SQLERRM );



  END final_report_csv_p;



  PROCEDURE final_report_xlsx_p ( p_status      OUT   VARCHAR2,

                                  p_error_msg   OUT   VARCHAR2 ) IS



    c_cursor            SYS_REFCURSOR;



  BEGIN



    print_log( 'ajcl_bc_lockbox_pkg.final_report_xlsx_p (+)' );



    gv_directory_report := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_REPORT' );



    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc || ' Report',

                                                p_request_id => gv_request_id,

                                                p_bc_environment => gv_bc_environment,

                                                p_jenkins_build_number => gv_jenkins_build_number,

                                                --

                                                p_param_1_title => ' ',

                                                p_param_1_value => ' ',

                                                -- 2025 - KANO

                                                p_param_2_title => 'JOURNAL_BATCH_NAME',

                                                p_param_2_value => gv_journal_batch_name,

                                                -- 2025 - KANO

                                                p_param_3_title => 'GL_DATE',

                                                p_param_3_value => TO_CHAR(gv_gl_date,'YYYY-MM-DD') );



    -- Summary

        OPEN c_cursor FOR

      SELECT 'Receipts' type, 

             UPPER(status) status, 

             COUNT(1) "COUNT"

        FROM ajcl_bc_lbx_receipts 

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         -- 2025 - KANO

         AND journal_batch_name = gv_journal_batch_name

         -- 2025 - KANO

    GROUP BY status

       UNION ALL

      SELECT 'Applications' type, 

             UPPER(status) status, 

             COUNT(1) "COUNT"

        FROM ajcl_bc_lbx_rcp_applications 

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         -- 2025 - KANO

         AND journal_batch_name = gv_journal_batch_name

         -- 2025 - KANO

    GROUP BY status

    ORDER BY type DESC, 

             status DESC;



    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Summary',

                                       p_sheet => 2,

                                       p_cursor => c_cursor );



    -- Receipts

        OPEN c_cursor FOR

      SELECT lockboxID lockbox_id,

             lockboxReceiptNumber lockbox_receipt_number,

             postingDate posting_date,

             documentNo document_no,

             -- entryNo entry_no,             

             customerNo customer_no,

             customerName customer_name,

             currencyCode currency_code,

             amount,

             UPPER(status) status, 

             error_message,

             originalCustomerNo original_customer_no,

             originalCustomerName original_customer_name,

             comments,

             customerBankABA customer_bank_ABA,

             customerBankAccount customer_bank_account,

             achWireBankCustCodeName ACH_WIRE_bank_cust_code_name,

             typeOfReceipt type_of_receipt

        FROM ajcl_bc_lbx_receipts

       WHERE request_id = gv_request_id

         AND bc_environment = gv_bc_environment

         -- 2025 - KANO

         AND journal_batch_name = gv_journal_batch_name

         -- 2025 - KANO

    ORDER BY documentNo,

             customerNo;



    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Receipts',

                                       p_sheet => 3,

                                       p_cursor => c_cursor );



    -- Applications

        OPEN c_cursor FOR

      SELECT app.customerno customer_no,

             app.customername customer_name,

             app.postingdate posting_date,

             -- app.receiptentryno receipt_entry_no,

             rcp.lockboxreceiptnumber lockbox_receipt_number, 

             app.documentNo receipt_no,

             -- app.appliestoentryno applies_to_entry_no,

             app.appliesToDocType applies_to_doc_type,

             app.appliesToDocNo applies_to_doc_no,

             app.currencycode currency_code,

             app.amountToApply app_amount,

             UPPER(app.status) status,

             app.error_message

        FROM ajcl_bc_lbx_rcp_applications app,

             ajcl_bc_lbx_receipts rcp   

       WHERE app.request_id = gv_request_id 

         AND app.bc_environment = gv_bc_environment

         AND app.request_id = app.request_id

         AND rcp.bc_environment = app.bc_environment

         AND app.receiptentryno = rcp.entryno

         -- 2025 - KANO

         AND rcp.journal_batch_name = gv_journal_batch_name

         AND rcp.journal_batch_name = app.journal_batch_name

         -- 2025 - KANO

    ORDER BY app.documentNo,

             DECODE(app.status,'SUCCESS',1,'ERROR',2,'REJECTED',3,4),

             app.appliesToDocNo; 



    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Applications',

                                       p_sheet => 4,

                                       p_cursor => c_cursor );



    as_xlsx.save ( gv_directory_report, gv_report_filename || '.' || LOWER(gv_file_format) );



    p_status := 'S';



    print_log( 'ajcl_bc_lockbox_pkg.final_report_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      p_error_msg := SQLERRM;

      print_log( 'ajcl_bc_lockbox_pkg.final_report_xlsx_p (!). Error: ' || SQLERRM );



  END final_report_xlsx_p;



  -- Se inserta la aplicacion en la tabla, pero no se procesa aunque el recibo haya fallado y/o no exista el documento al que aplica

  PROCEDURE insert_app_inv_not_found_p ( p_rcp_entryNo     IN   NUMBER,

                                         p_posting_date    IN   DATE,

                                         p_currency_code   IN   VARCHAR2,

                                         p_amount          IN   NUMBER,

                                         p_trx_number      IN   VARCHAR2,

                                         --

                                         p_status         OUT   VARCHAR2,

                                         p_error_msg      OUT   VARCHAR2 ) IS



    v_documentNo     ajcl_bc_lbx_receipts.documentNo%TYPE;

    v_customerNo     ajcl_bc_lbx_receipts.customerNo%TYPE;

    v_customerName   ajcl_bc_lbx_receipts.customerName%TYPE;



    e_get_rcp_data   EXCEPTION;



  BEGIN



    print_log ('ajcl_bc_lockbox_pkg.insert_app_inv_not_found_p (+)' );



    print_log ( 'p_rcp_entryNo: ' || p_rcp_entryNo );

    print_log ( 'p_posting_date: ' || p_posting_date );

    print_log ( 'p_currency_code: ' || p_currency_code );

    print_log ( 'p_amount: ' || p_amount );

    print_log ( 'p_trx_number: ' || p_trx_number );



    -- Se obtienen los datos del rcp

    BEGIN



      -- Datos del recibo

      SELECT documentNo,

             customerNo,

             customerName

        INTO v_documentNo,

             v_customerNo,

             v_customerName

        FROM ajcl_bc_lbx_receipts rcp

       WHERE entryNo = p_rcp_entryNo

         -- AND status = 'SUCCESS' -- Se genera la aplicacion en la tabla, aunque el recibo haya fallado. Para que el usuario la vea.

         AND bc_environment = gv_bc_environment

         AND request_id = gv_request_id

         -- 2025 - KANO

         AND journal_batch_name = gv_journal_batch_name

         -- 2025 - KANO

         ;



      print_log ( 'v_documentNo: ' || v_documentNo );

      print_log ( 'v_customerNo: ' || v_customerNo );

      print_log ( 'v_customerName: ' || v_customerName );



    EXCEPTION 

      WHEN OTHERS THEN

        p_error_msg := 'Error obtaining receipt data.';

        RAISE e_get_rcp_data;



    END;



      INSERT

        INTO ajcl_bc_lbx_rcp_applications

           ( bc_environment,

             receiptEntryNo,

             documentNo,

             customerNo,

             customerName,

             currencyCode,

             postingDate,

             appliesToDocNo,             

             amountToApply,

             -- 2025 - KANO

             journal_batch_name,

             -- 2025 - KANO

             request_id,

             status,

             error_message,

             creation_date,

             created_by,

             last_update_date,

             last_updated_by )

    VALUES ( gv_bc_environment,

             p_rcp_entryNo,

             v_documentNo,

             v_customerNo,

             v_customerName,

             p_currency_code,

             TO_CHAR(p_posting_date,'YYYY-MM-DD'),

             p_trx_number, -- appliesToDocNo

             -1 * ABS(p_amount), -- amountToApply

             -- 2025 - KANO

             gv_journal_batch_name,

             -- 2025 - KANO

             gv_request_id, 

             'ERROR', -- status

             'Doc No. does not exist or has not yet been posted.', -- error_message

             SYSDATE, -- creation_date

             gv_user_id, -- created_by

             SYSDATE, -- last_update_date

             gv_user_id -- last_updated_by 

             );



    print_log ( 'app with ERROR status inserted.' );



    p_status := 'S';



    print_log ('ajcl_bc_lockbox_pkg.insert_app_inv_not_found_p (-)' );



  EXCEPTION

    WHEN e_get_rcp_data THEN

      p_status := 'E';

      print_log ('ajcl_bc_lockbox_pkg.insert_app_inv_not_found_p (!).' );    



    WHEN OTHERS THEN

      p_status := 'E';

      print_log ('ajcl_bc_lockbox_pkg.insert_app_inv_not_found_p (!). Error: ' || SQLERRM );      



  END insert_app_inv_not_found_p;



  -- INTERFACE -----------------------------------------------------------------------------------------------------------------

  -- AJC Truist 823 AR Interface

  PROCEDURE main_bc_p ( p_status      OUT   VARCHAR2,

                        p_error_msg   OUT   VARCHAR2 ) IS 



    return_status_v                  VARCHAR2(50);

    v_status                         VARCHAR2(1);

    msg_count_v                      NUMBER;

    msg_data_v                       VARCHAR2(2000);

    msg_v                            VARCHAR2(2000);

    msg_out                          VARCHAR2(2000);



    rcp_entryNo_v                    ajcl_bc_lbx_receipts.entryNo%TYPE; 

    rcp_documentNo_v                 ajcl_bc_lbx_receipts.documentNo%TYPE;



    receipt_attribute_rec            ar_receipt_api_pub.attribute_rec_type;



    customer_id_v                    ra_customer_trx_all.bill_to_customer_id%TYPE;



    trx_id_v                         ra_customer_trx_all.customer_trx_id%TYPE;

    trx_entryNo_v                    ajcl_bc_posted_sd_headers.entryNo%TYPE; 

    trx_id_used_to_find_cust_v       ra_customer_trx_all.customer_trx_id%TYPE;

    entryNo_used_to_find_cust_v      ajcl_bc_posted_sd_headers.entryNo%TYPE; 



    neg_trx_customer_id_v            ra_customer_trx_all.bill_to_customer_id%TYPE;

    neg_trx_id_v                     ra_customer_trx_all.customer_trx_id%TYPE;

    neg_trx_entryNo_v                ajcl_bc_posted_sd_headers.entryNo%TYPE; -- BC

    num_neg_trx_v                    NUMBER;



    cust_bank_account_id_v           ap_bank_accounts.bank_account_id%TYPE;

    cr_id_v                          ar_cash_receipts_all.cash_receipt_id%TYPE;



    receipt_num_v                    ajcl_bc_lbx_receipts.lockboxreceiptnumber%TYPE;



    api_action_v                     VARCHAR2(50);

    api_status_v                     VARCHAR2(50);

    gl_date_v                        DATE;

    customer_num_v                   hz_cust_accounts_all.account_number%TYPE;

    customer_name_v                  hz_parties.party_name%TYPE;    

    p_count                          NUMBER;

    payment_num_v                    ajc_ar_lbx_bank_data.payment_num%TYPE;

    payment_amt_v                    ajc_ar_lbx_bank_data.payment_amt%TYPE;

    payment_date_v                   ajc_ar_lbx_bank_data.payment_date%TYPE;

    cust_bank_acct_num_v             ajc_ar_lbx_bank_data.payor_account_num%TYPE;

    customer_bank_v                  ajc_ar_lbx_bank_data.originating_bank_aba%TYPE;

    receipt_date_v                   ajc_ar_lbx_bank_data.deposit_date%TYPE;

    invoice_num_v                    ajc_ar_lbx_bank_data.invoice_num%TYPE;

    invoice_amt_v                    ajc_ar_lbx_bank_data.invoice_amt%TYPE;

    inv_num_used_to_find_cust_v      ajc_ar_lbx_bank_data.invoice_num%TYPE;

    inv_amt_used_to_find_cust_v      ajc_ar_lbx_bank_data.invoice_amt%TYPE;

    achinv_num_used_to_find_cust_v   ajc_ar_lbx_bank_data.invoice_num%TYPE;

    achinv_amt_used_to_find_cust_v   ajc_ar_lbx_bank_data.invoice_amt%TYPE;

    ach_wire_cust_name_v             ajc_ar_lbx_bank_data.ach_wire_cust_name%TYPE;

    short_ach_wire_cust_name_v       VARCHAR2(15);

    bpr_type_of_receipt_v            ajc_ar_lbx_bank_data.bpr_type_of_receipt%TYPE;

    receipt_comments_v               ajc_ar_lbx_bank_data.receipt_comments%TYPE;

    data_trx_type_v                  ajc_ar_lbx_bank_data.data_trx_type%TYPE;

    receipt_already_exists_v         VARCHAR2(1);



    inv_amt_due_v                    NUMBER;



    error_loc_v                      VARCHAR2(20);

    data_payment_line_num_v          ajc_ar_lbx_bank_data.data_payment_line_num%TYPE;

    trx_num_v                        ra_customer_trx_all.trx_number%TYPE;

    l                                NUMBER;

    receipt_created_v                VARCHAR2(1);

    receipt_exists_v                 VARCHAR2(1);

    applied_amt_v                    NUMBER;

    onaccount_amt_v                  NUMBER;

    unid_amt_v                       NUMBER;

    misc_amt_v                       NUMBER;

    receipt_status_v                 VARCHAR2(25);

    v_party_name                     VARCHAR2(60);

    amt_due_v                        NUMBER;

    duplicate_receipt_v              VARCHAR2(1);

    num_ach_ctx_inv_v                NUMBER;

    customer_id_not_found            BOOLEAN; 



    -- 20260107

    v_rcp_count                      NUMBER;

    -- 20260107



    e_error                          EXCEPTION;

    e_api_failed                     EXCEPTION;

    e_skip_payment_missing_cm        EXCEPTION;

    e_duplicate_receipt              EXCEPTION;



      CURSOR select_payment IS

      SELECT DISTINCT

             data_trx_type,

             data_payment_line_num,

             payment_num,

             payment_date,

             payment_amt,

             payor_account_num customer_bank_acct_num,

             originating_bank_aba customer_bank,

             deposit_date receipt_date,

             ach_wire_cust_name,

             SUBSTR(ach_wire_cust_name, 1, 15) short_ach_wire_cust_name,

             bpr_type_of_receipt,

             receipt_comments,

             group_id

        FROM ajc_truist_ar_lbx_bank_data

       WHERE NVL(processed_flag,'N') = 'N'

         -- 2025 - KANO

         AND journal_batch_name = gv_journal_batch_name

         -- 2025 - KANO

    ORDER BY data_payment_line_num;



      -- Cursor Select_Invoice is sorted by the invoice amt so that credits are processed first

      -- Added NVL to the and clauses below because ACH-CTX records do not have bank info

      CURSOR select_invoice IS

      SELECT invoice_num, 

             invoice_amt

        FROM ajc_truist_ar_lbx_bank_data

       WHERE NVL(payment_num,'XXX') = NVL(payment_num_v,'XXX')

         AND NVL(payment_date,TRUNC(SYSDATE)) = NVL(payment_date_v,TRUNC(SYSDATE))

         AND NVL(payor_account_num,'XXX') = NVL(cust_bank_acct_num_v,'XXX')

         AND NVL(originating_bank_aba,'XXX') = NVL(customer_bank_v,'XXX')

         AND data_payment_line_num = data_payment_line_num_v

         AND NVL(processed_flag,'N') = 'N'

         -- 2025 - KANO

         AND journal_batch_name = gv_journal_batch_name

         -- 2025 - KANO

    ORDER BY invoice_amt;



    CURSOR select_negative_trx IS

    SELECT invoice_num,

           invoice_amt

      FROM ajc_truist_ar_lbx_bank_data

     WHERE payment_num = payment_num_v

       AND payment_date = payment_date_v

       AND NVL(processed_flag,'N') = 'N'

       AND payor_account_num = cust_bank_acct_num_v

       AND originating_bank_aba = customer_bank_v

       AND data_payment_line_num = data_payment_line_num_v

       AND invoice_amt < 0

       -- 2025 - KANO

       AND journal_batch_name = gv_journal_batch_name

       -- 2025 - KANO

       ;



      CURSOR select_receipt_from_log IS

      SELECT DISTINCT l.receipt_num,

             l.payment_amt,

             l.receipt_date,

             l.customer_id,

             l.ach_wire_cust_name,

             l.bpr_type_of_receipt,

             l.payment_num,

             un.amt_known,

             un.appl_amt,

             un.onacct_amt,

             un.unid_amt,

             un.misc_amt,

             ( l.payment_amt - un.amt_known ) unapply_amt

        FROM ajc_truist_ar_rec_int_log l,

             ( SELECT receipt_num,

                      payment_amt,

                      SUM(NVL(applied_amt, 0)) appl_amt,

                      SUM(NVL(onaccount_amt, 0)) onacct_amt,

                      SUM(NVL(unid_amt, 0)) unid_amt,

                      SUM(NVL(misc_amt, 0)) misc_amt,

                      SUM(NVL(applied_amt, 0) + NVL(onaccount_amt, 0) + NVL(unid_amt, 0) + NVL(misc_amt, 0)) amt_known

                 FROM ajc_truist_ar_rec_int_log

                WHERE api_status <> 'DUPLICATE_RECEIPT'

                  -- 2025 - KANO

                  AND journal_batch_name = gv_journal_batch_name

                  -- 2025 - KANO

             GROUP BY receipt_num,

                      payment_amt ) un

       WHERE l.receipt_num = un.receipt_num

         AND l.api_status <> 'DUPLICATE_RECEIPT'

         -- 2025 - KANO

         AND journal_batch_name = gv_journal_batch_name

         -- 2025 - KANO

    ORDER BY l.receipt_num;



    -- ==========================================================

    -- Procedure Create_Log_Record

    -- This procedure creates records in the ajc_truist_ar_rec_int_log table which is used for control reporting

    -- ==========================================================

    PROCEDURE create_log_record ( payment_num_in           IN   VARCHAR2,

                                  receipt_date_in          IN   VARCHAR2,

                                  payment_amt_in           IN   NUMBER,

                                  cust_bank_acct_num_in    IN   VARCHAR2,

                                  cust_bank_in             IN   VARCHAR2,

                                  invoice_num_in           IN   VARCHAR2,

                                  invoice_amt_in           IN   NUMBER,

                                  customer_id_in           IN   NUMBER,

                                  trx_id_in                IN   NUMBER,

                                  comments_in              IN   VARCHAR2,

                                  api_action_in            IN   VARCHAR2,

                                  api_status_in            IN   VARCHAR2,

                                  receipt_num_in           IN   VARCHAR2,

                                  ach_wire_cust_name_in    IN   VARCHAR2,

                                  bpr_type_of_receipt_in   IN   VARCHAR2,

                                  data_trx_type_in         IN   VARCHAR2,

                                  receipt_comments_in      IN   VARCHAR2,

                                  applied_amt_in           IN   NUMBER,

                                  onaccount_amt_in         IN   NUMBER,

                                  unid_amt_in              IN   NUMBER,

                                  misc_amt_in              IN   NUMBER,

                                  --

                                  rcp_documentNo_in        IN   VARCHAR2,

                                  rcp_entryNo_in           IN   NUMBER,

                                  trx_entryNo_in           IN   NUMBER ) IS



      comments_v   VARCHAR2(2000);



    BEGIN



      IF ( LENGTH(comments_in) > 2000 ) THEN



        comments_v := SUBSTR(comments_in, 1, 2000);



      ELSE



        comments_v := comments_in;



      END IF;



      INSERT 

        INTO ajc_truist_ar_rec_int_log 

             ( payment_num,

               receipt_date,

               payment_amt,

               cust_bank_acct_num,

               cust_bank,

               invoice_num,

               invoice_amt,

               customer_id,

               trx_id,

               comments,

               api_action,

               api_status,

               receipt_num,

               ach_wire_cust_name,

               bpr_type_of_receipt,

               data_trx_type,

               receipt_comments,

               applied_amt,

               onaccount_amt,

               unid_amt,

               misc_amt,

               --

               rcp_documentNo,

               rcp_entryNo,

               trx_entryNo

               -- 2025 - KANO

              ,journal_batch_name

               -- 2025 - KANO

               ) 

      VALUES ( payment_num_in,

               receipt_date_in,

               payment_amt_in,

               cust_bank_acct_num_in,

               cust_bank_in,

               invoice_num_in,

               invoice_amt_in,

               customer_id_in,

               trx_id_in,

               comments_v,

               api_action_in,

               api_status_in,

               receipt_num_in,

               ach_wire_cust_name_in,

               bpr_type_of_receipt_in,

               data_trx_type_in,

               receipt_comments_in,

               applied_amt_in,

               onaccount_amt_in,

               unid_amt_in,

               misc_amt_in,

               --

               rcp_documentNo_in,

               rcp_entryNo_in,

               trx_entryNo_in

               --

               -- 2025 - KANO

              ,gv_journal_batch_name

               -- 2025 - KANO

               );



    EXCEPTION

      WHEN OTHERS THEN

        error_loc_v := 'E10';

        RAISE;



    END create_log_record;



    -- ==========================================================

    -- Procedure Get_Receipt_Number

    -- This procedure determines if the receipt number passed in has already been processed in the current run. If it 

    -- has then a sequence number is added to the receipt number.

    -- ==========================================================

    PROCEDURE get_receipt_number ( receipt_num_in          IN    VARCHAR2,

                                   receipt_num_out         OUT   VARCHAR2,

                                   duplicate_receipt_out   OUT   VARCHAR2 ) IS



      receipt_num_seq_v NUMBER;



    BEGIN



      print_log ( 'ajcl_bc_lockbox_pkg.get_receipt_number (+)' );

      print_log ( 'receipt_num_in: ' || receipt_num_in );



      -- Has this receipt_num_in already been used in this run?

      receipt_already_exists_v := 'N';



      BEGIN



        SELECT 'Y'

          INTO receipt_already_exists_v

          FROM ajc_truist_ar_rec_int_log

         WHERE receipt_num = receipt_num_in

           -- 2025 - KANO

           AND journal_batch_name = gv_journal_batch_name

           -- 2025 - KANO

           ;



      EXCEPTION

        WHEN no_data_found THEN

          NULL;

        WHEN OTHERS THEN

          NULL;



      END;



      IF ( receipt_already_exists_v = 'Y' ) THEN



        SELECT ajc_truist_ar_receipt_num_s.NEXTVAL

          INTO receipt_num_seq_v

          FROM dual;



        receipt_num_out := receipt_num_in || '-' || receipt_num_seq_v;



      ELSE



        receipt_num_out := receipt_num_in;



      END IF;



      duplicate_receipt_out := 'N';



      -- Does this receipt exists in AR? If so, then flag this as a duplicate

      BEGIN



        SELECT 'Y'

          INTO duplicate_receipt_out

          FROM ajcl_bc_cash_rec_jnl

         WHERE bc_environment = gv_bc_environment

           AND lockboxReceiptNumber = receipt_num_out

           -- 2025 - KANO

           -- 20251211

           AND journalbatchname = gv_journal_batch_name;

           -- 20251211

           -- 2025 - KANO           



        print_log ('BC - Receipt exists.'); 



      EXCEPTION

        WHEN NO_DATA_FOUND THEN



          BEGIN



            SELECT 'Y'

              INTO duplicate_receipt_out

              FROM ar_cash_receipts_all

             WHERE org_id = gv_org_id

               AND receipt_number = receipt_num_out;



            print_log ('ORACLE - Receipt exists.'); 



          EXCEPTION

            WHEN NO_DATA_FOUND THEN

              NULL;

            WHEN OTHERS THEN

              NULL;



          END;



        WHEN OTHERS THEN

          NULL;



      END;



      print_log ( 'ajcl_bc_lockbox_pkg.get_receipt_number (-)' );



    END get_receipt_number;



    -- ==========================================================

    -- Procedure Customer_Match_On_Invoice 

    -- Find the customer by matching on the invoice number 

    -- ==========================================================

    PROCEDURE customer_match_on_invoice ( inv_num_in                  IN    VARCHAR2,

                                          inv_amt_in                  IN    NUMBER,

                                          customer_id_out             OUT   NUMBER,

                                          trx_id_out                  OUT   NUMBER,

                                          trx_entryNo_out             OUT   NUMBER,

                                          customer_id_not_found_out   OUT   BOOLEAN ) IS

    BEGIN



      print_log ( 'ajcl_bc_lockbox_pkg.customer_match_on_invoice (+)' );

      print_log ( 'inv_num_in: ' || inv_num_in );

      print_log ( 'inv_amt_in: ' || inv_amt_in );



      -- CM

      IF ( inv_amt_in < 0 ) THEN



        -- BC

        BEGIN



          SELECT DISTINCT rc.customer_id,

                 psdh.entryNo

            INTO customer_id_out,

                 trx_entryNo_out

            FROM ajcl_bc_posted_sd_headers psdh,

                 ra_customers rc

           WHERE psdh.bc_environment = gv_bc_environment

             AND psdh.class = 'CM'

             AND ( psdh.transactionNo2 = REPLACE(inv_num_in,'-') OR psdh.trvinvoicenum = REPLACE(inv_num_in, '-') )

             AND psdh.remainingAmount = inv_amt_in

             AND psdh.billToCustomerNo = rc.customer_number;



          customer_id_not_found := false;

          print_log ( 'BC - Customer found by exact match on CM number. customer_id_out: ' || customer_id_out || ' trx_entryNo_out: ' || trx_entryNo_out || ' inv_amt_in: ' || inv_amt_in); 



        EXCEPTION

          WHEN NO_DATA_FOUND THEN



            BEGIN



              SELECT DISTINCT rc.customer_id,

                     psdh.entryNo

                INTO customer_id_out,

                     trx_entryNo_out

                FROM ajcl_bc_posted_sd_headers psdh,

                     ra_customers rc

               WHERE psdh.bc_environment = gv_bc_environment

                 AND class = 'CM'

                 AND LENGTH(psdh.transactionNo) > 3

                 AND REPLACE(REPLACE(DECODE(INSTR(inv_num_in,'-',1,2),0,inv_num_in,SUBSTR(inv_num_in,1,INSTR(inv_num_in,'-',1,2) - 1)),'-'),' ') LIKE psdh.transactionNo3 || '%'

                 AND psdh.remainingAmount = inv_amt_in

                 AND psdh.billToCustomerNo = rc.customer_number;



              customer_id_not_found := FALSE;

              print_log ( 'BC - Customer found by like matching on CM number, ' || ' customer_id_out: ' || customer_id_out || ' trx_entryNo_out: ' || trx_entryNo_out || ' inv_amt_in: ' || inv_amt_in);



          EXCEPTION

            WHEN NO_DATA_FOUND THEN

              NULL;



            WHEN TOO_MANY_ROWS THEN

              -- the invoices for this receipt are for different customers, pick one invoice 

              BEGIN



                SELECT MAX(rc.customer_id)

                  INTO customer_id_out

                  FROM ajcl_bc_posted_sd_headers psdh,

                       ra_customers rc

                 WHERE psdh.bc_environment = gv_bc_environment

                   AND psdh.class = 'CM'

                   AND LENGTH(psdh.transactionNo) > 3

                   AND REPLACE(REPLACE(DECODE(INSTR(inv_num_in,'-',1,2),0,inv_num_in,SUBSTR(inv_num_in,1,INSTR(inv_num_in,'-',1,2) - 1)),'-'),' ') LIKE psdh.transactionNo3 || '%'

                   AND psdh.remainingAmount = inv_amt_in

                   AND psdh.billToCustomerNo = rc.customer_number;



                customer_id_not_found := FALSE;

                print_log ( 'BC - Multiple customers found matching on invoice, selecting MAX customer_id_out: ' || customer_id_out );



              EXCEPTION

                WHEN NO_DATA_FOUND THEN

                  NULL;

                WHEN OTHERS THEN

                  NULL;



              END;            



            WHEN OTHERS THEN

              NULL;



          END;



          WHEN OTHERS THEN

            NULL;



        END;

        -- BC



        -- ORACLE

        IF ( customer_id_out IS NULL ) THEN



          BEGIN



            SELECT DISTINCT t.bill_to_customer_id,

                   t.customer_trx_id

              INTO customer_id_out,

                   trx_id_out

              FROM ra_customer_trx_all t,

                   ( SELECT customer_trx_id,

                            SUM(amount_due_remaining) amt_due

                       FROM ar_payment_schedules_all

                      WHERE org_id = gv_org_id

                        AND status = 'OP'

                   GROUP BY customer_trx_id ) ps

             WHERE t.org_id = gv_org_id

               AND t.cust_trx_type_id IN ( SELECT cust_trx_type_id

                                             FROM ra_cust_trx_types_all

                                            WHERE type = 'CM'

                                              AND org_id = gv_org_id )

               AND REPLACE(t.trx_number, '-') = REPLACE(inv_num_in, '-')

               AND ps.amt_due = inv_amt_in

               AND ps.customer_trx_id = t.customer_trx_id;



            customer_id_not_found_out := false;

            print_log ( 'ORACLE - Customer found by exact match on CM number. customer_id_out: ' || customer_id_out || ' trx_id_out: ' || trx_id_out || ' inv_amt_in: ' || inv_amt_in);



          EXCEPTION

            WHEN no_data_found THEN



              BEGIN



                SELECT DISTINCT t.bill_to_customer_id,

                       t.customer_trx_id

                  INTO customer_id_out,

                       trx_id_out

                  FROM ra_customer_trx_all t,

                       ( SELECT customer_trx_id,

                                SUM(amount_due_remaining) amt_due

                           FROM ar_payment_schedules_all

                          WHERE org_id = gv_org_id

                            AND status = 'OP'

                       GROUP BY customer_trx_id ) ps

                 WHERE t.org_id = gv_org_id

                   AND t.cust_trx_type_id IN ( SELECT cust_trx_type_id

                                                 FROM ra_cust_trx_types_all

                                                WHERE type = 'CM'

                                                  AND org_id = gv_org_id )

                   AND REPLACE(REPLACE(DECODE(INSTR(inv_num_in, '-', 1, 2), 0, inv_num_in, SUBSTR(inv_num_in, 1, INSTR(inv_num_in, '-', 1, 2)

                       - 1)), '-'), ' ') LIKE REPLACE(REPLACE(DECODE(INSTR(t.trx_number, '-', 1, 2), 0, t.trx_number, SUBSTR(t.trx_number, 1, 

                       INSTR (t.trx_number, '-', 1, 2) - 1)), '-'), ' ') || '%'

                   AND ps.amt_due = inv_amt_in

                   AND ps.customer_trx_id = t.customer_trx_id;



                customer_id_not_found_out := false;

                print_log ( 'ORACLE - Customer found by like matching on CM number. customer_id_out: ' || customer_id_out || ' trx_id_out: ' || trx_id_out || ' inv_amt_in: ' || inv_amt_in);



              EXCEPTION

                WHEN no_data_found THEN

                  NULL;

                WHEN too_many_rows THEN



                  -- the invoices for this receipt are for different customers, pick one invoice 

                  BEGIN



                    SELECT MAX(t.bill_to_customer_id)

                      INTO customer_id_out

                      FROM ra_customer_trx_all t,

                           ( SELECT customer_trx_id,

                                    SUM(amount_due_remaining) amt_due

                               FROM ar_payment_schedules_all

                              WHERE org_id = gv_org_id

                                AND status = 'OP'

                           GROUP BY customer_trx_id ) ps

                     WHERE t.org_id = gv_org_id

                       AND t.cust_trx_type_id IN ( SELECT cust_trx_type_id

                                                     FROM ra_cust_trx_types_all

                                                    WHERE type = 'CM'

                                                      AND org_id = gv_org_id )

                       AND REPLACE(REPLACE(DECODE(INSTR(inv_num_in, '-', 1, 2), 0, inv_num_in, SUBSTR(inv_num_in, 1, INSTR(inv_num_in, '-', 1, 2

                           ) - 1)), '-'), ' ') LIKE REPLACE(REPLACE(DECODE(INSTR(t.trx_number, '-', 1, 2), 0, t.trx_number, SUBSTR(t.trx_number, 1,

                           INSTR(t.trx_number, '-', 1, 2) - 1)), '-'), ' ') || '%'

                       AND ps.amt_due = inv_amt_in

                       AND ps.customer_trx_id = t.customer_trx_id;



                    customer_id_not_found_out := false;

                    print_log ( 'ORACLE - Multiple customers found matching on invoice. Selecting max cust id. customer_id_out: ' || customer_id_out );



                  EXCEPTION

                    WHEN no_data_found THEN

                      NULL;

                    WHEN OTHERS THEN

                      NULL;

                  END;



                WHEN OTHERS THEN

                  NULL;



              END;



            WHEN OTHERS THEN

              NULL;



          END;



        END IF;

        -- ORACLE



      ELSE -- INV



        -- BC

        BEGIN



          SELECT DISTINCT rc.customer_id,

                 psdh.entryNo

            INTO customer_id_out,

                 trx_entryNo_out

            FROM ajcl_bc_posted_sd_headers psdh,

                 ra_customers rc

           WHERE psdh.bc_environment = gv_bc_environment

             AND psdh.class = 'INV'

             AND ( psdh.transactionNo2 = REPLACE(inv_num_in, '-') OR psdh.trvinvoicenum = REPLACE(inv_num_in, '-') ) 

             AND psdh.remainingAmount = inv_amt_in

             AND psdh.billToCustomerNo = rc.customer_number;



          customer_id_not_found := FALSE;

          print_log ( 'BC - Customer found by exact match on invoice number, ' || ' customer_id_out: ' || customer_id_out || ' trx_entryNo_out: ' || trx_entryNo_out);



        EXCEPTION

          WHEN NO_DATA_FOUND THEN



            BEGIN



              SELECT DISTINCT rc.customer_id,

                     psdh.entryNo

                INTO customer_id_out,

                     trx_entryNo_out

                FROM ajcl_bc_posted_sd_headers psdh,

                     ra_customers rc

               WHERE psdh.bc_environment = gv_bc_environment

                 AND psdh.transactionNo != '-1'

                 AND LENGTH(psdh.transactionNo) > 3

                 AND psdh.class = 'INV'

                 AND REPLACE(REPLACE(DECODE(INSTR(inv_num_in,'-',1,2),0,inv_num_in,SUBSTR(inv_num_in,1,INSTR(inv_num_in,'-',1,2) - 1)),'-'),' ') LIKE psdh.transactionNo3 || '%'

                 AND psdh.remainingAmount = inv_amt_in

                 AND psdh.billToCustomerNo = rc.customer_number;



              customer_id_not_found := FALSE;

              print_log ( 'BC - Customer found by like matching on invoice number, ' || ' customer_id_out: ' || customer_id_out || ' trx_entryNo_out: ' || trx_entryNo_out);



            EXCEPTION

              WHEN NO_DATA_FOUND THEN

                NULL;



              WHEN TOO_MANY_ROWS THEN



                -- the invoices for this receipt are for different customers, pick one invoice 

                BEGIN



                  SELECT MAX(rc.customer_id)

                    INTO customer_id_out

                    FROM ajcl_bc_posted_sd_headers psdh,

                         ra_customers rc

                   WHERE psdh.bc_environment = gv_bc_environment

                     AND psdh.class = 'INV'

                     AND LENGTH(psdh.transactionNo) > 3

                     AND REPLACE(REPLACE(DECODE(INSTR(inv_num_in,'-',1,2),0,inv_num_in,SUBSTR(inv_num_in,1,INSTR(inv_num_in,'-',1,2) - 1)),'-'),' ') LIKE psdh.transactionNo3 || '%'; 



                  customer_id_not_found := FALSE;

                  print_log ( 'BC - Multiple customers found matching on invoice, Selecting MAX customer_id_out: ' || customer_id_out );



                EXCEPTION

                  WHEN NO_DATA_FOUND THEN

                    NULL;

                  WHEN OTHERS THEN

                    NULL;



                END;



              WHEN OTHERS THEN

                NULL;



            END;



          WHEN OTHERS THEN

            NULL;



        END;

        -- BC



        -- ORACLE

        IF ( customer_id_out IS NULL ) THEN



          BEGIN



            SELECT DISTINCT bill_to_customer_id,

                   customer_trx_id

              INTO customer_id_out,

                   trx_id_out

              FROM ra_customer_trx_all t

             WHERE org_id = gv_org_id

               AND cust_trx_type_id IN ( SELECT cust_trx_type_id

                                           FROM ra_cust_trx_types_all

                                          WHERE type = 'INV'

                                            AND org_id = gv_org_id )

               AND REPLACE(trx_number, '-') = REPLACE(inv_num_in, '-');



            customer_id_not_found := false;

            print_log ( 'ORACLE - Customer found by exact match on invoice number. customer_id_out: ' || customer_id_out || ' trx_id_out: ' || trx_id_out);



          EXCEPTION

            WHEN no_data_found THEN



              BEGIN



                SELECT DISTINCT bill_to_customer_id,

                       customer_trx_id

                  INTO customer_id_out,

                       trx_id_out

                  FROM ra_customer_trx_all t

                 WHERE org_id = gv_org_id

                   -- 20231220

                   AND trx_number != '-1'

                   -- 20231220

                   AND cust_trx_type_id IN ( SELECT cust_trx_type_id

                                               FROM ra_cust_trx_types_all

                                              WHERE type = 'INV'

                                                AND org_id = gv_org_id )

                   AND REPLACE(REPLACE(DECODE(INSTR(inv_num_in, '-', 1, 2), 0, inv_num_in, SUBSTR(inv_num_in, 1, INSTR(inv_num_in, '-', 1, 2)

                       - 1)), '-'), ' ') LIKE REPLACE(REPLACE(DECODE(INSTR(t.trx_number, '-', 1, 2), 0, t.trx_number, SUBSTR(t.trx_number, 1, INSTR

                       (t.trx_number, '-', 1, 2) - 1)), '-'), ' ') || '%';



                customer_id_not_found := false;

                print_log ( 'ORACLE - Customer found by like matching on invoice number. customer_id_out: ' || customer_id_out || ' trx_id_out: ' || trx_id_out);



              EXCEPTION

                WHEN no_data_found THEN

                  NULL;



                WHEN too_many_rows THEN



                  -- the invoices for this receipt are for different customers, pick one invoice 

                  BEGIN



                    SELECT MAX(bill_to_customer_id)

                      INTO customer_id_out

                      FROM ra_customer_trx_all t

                     WHERE org_id = gv_org_id

                       AND cust_trx_type_id IN ( SELECT cust_trx_type_id

                                                   FROM ra_cust_trx_types_all

                                                  WHERE type = 'INV'

                                                    AND org_id = gv_org_id )

                      AND REPLACE(REPLACE(DECODE(INSTR(inv_num_in, '-', 1, 2), 0, inv_num_in, SUBSTR(inv_num_in, 1, INSTR(inv_num_in, '-', 1, 2

                      ) - 1)), '-'), ' ') LIKE REPLACE(REPLACE(DECODE(INSTR(t.trx_number, '-', 1, 2), 0, t.trx_number, SUBSTR(t.trx_number, 1,

                      INSTR(t.trx_number, '-', 1, 2) - 1)), '-'), ' ') || '%';



                    customer_id_not_found := false;

                    print_log ( 'ORACLE - Multiple customers found matching on invoice. Selecting max cust id. customer_id_out: ' || customer_id_out );



                  EXCEPTION

                    WHEN no_data_found THEN

                      NULL;

                    WHEN OTHERS THEN

                      NULL;



                  END;



                WHEN OTHERS THEN

                  NULL;



              END;



            WHEN OTHERS THEN

              NULL;



          END;

          -- ORACLE



        END IF;



      END IF; -- inv_amt_used_to_find_cust_v < 0	



      print_log ( 'ajcl_bc_lockbox_pkg.customer_match_on_invoice (-)' );



    EXCEPTION

      WHEN OTHERS THEN

        NULL;



    END customer_match_on_invoice;



    PROCEDURE customer_match_on_housebill ( inv_num_in                  IN    VARCHAR2,

                                            inv_amt_in                  IN    NUMBER,

                                            customer_id_out             OUT   NUMBER,

                                            trx_entryNo_out             OUT   NUMBER,

                                            customer_id_not_found_out   OUT   BOOLEAN ) IS

    BEGIN



      print_log ( 'ajcl_bc_lockbox_pkg.customer_match_on_housebill (+)' );

      print_log ( 'inv_num_in: ' || inv_num_in );

      print_log ( 'inv_amt_in: ' || inv_amt_in );



      BEGIN



        SELECT DISTINCT rc.customer_id,

               psdh.entryNo

          INTO customer_id_out,

               trx_entryNo_out

          FROM ajcl_bc_posted_sd_headers psdh,

               ra_customers rc

         WHERE psdh.bc_environment = gv_bc_environment

           AND psdh.class = 'INV'

           AND psdh.source = 'CSA'

           AND psdh.csahousebill = TO_CHAR(TO_NUMBER(inv_num_in)) -- Quita los 0 delante

           AND psdh.remainingAmount = inv_amt_in

           AND psdh.billToCustomerNo = rc.customer_number;



        customer_id_not_found := FALSE;



        print_log ( 'BC - Customer found by exact match on housebill and remaining amount, ' || ' customer_id_out: ' || customer_id_out || ' trx_entryNo_out: ' || trx_entryNo_out);



      EXCEPTION

        WHEN NO_DATA_FOUND THEN



          print_log ( 'BC - Customer not found by exact match on housebill and remaining amount.' );



        WHEN TOO_MANY_ROWS THEN



          -- Find the max entry no.

          BEGIN



            SELECT rc.customer_id,

                   psdh.entryNo

              INTO customer_id_out,

                   trx_entryNo_out

              FROM ra_customers rc,

                   ajcl_bc_posted_sd_headers psdh,

                   ( SELECT MAX(entryNo) entryNo

                       FROM ajcl_bc_posted_sd_headers 

                      WHERE bc_environment = gv_bc_environment

                        AND class = 'INV'

                        AND source = 'CSA'

                        AND csahousebill = TO_CHAR(TO_NUMBER(inv_num_in)) -- Quita los 0 delante

                        AND remainingAmount = inv_amt_in ) psdh_max

             WHERE psdh.entryNo = psdh_max.entryNo

               AND psdh.billToCustomerNo = rc.customer_number;



            customer_id_not_found := FALSE;



            print_log ( 'BC - Customer found by exact match on housebill and remaining amount, Selection MAX Entry No. ' || ' customer_id_out: ' || customer_id_out || ' trx_entryNo_out: ' || trx_entryNo_out);



          EXCEPTION

            WHEN NO_DATA_FOUND THEN



              print_log ( 'customer_match_on_housebill - TOO_MANY_ROWS - NO_DATA_FOUND exception' || SQLERRM );



            WHEN OTHERS THEN



              print_log ( 'customer_match_on_housebill - TOO_MANY_ROWS - OTHERS exception' || SQLERRM );



          END;



        WHEN OTHERS THEN

          print_log ( 'customer_match_on_housebill - OTHERS exception' || SQLERRM );



      END;



      print_log ( 'ajcl_bc_lockbox_pkg.customer_match_on_housebill (-)' );



    EXCEPTION

      WHEN OTHERS THEN

        print_log ( 'customer_match_on_housebill - ' || SQLERRM );



    END customer_match_on_housebill;



    -- ==========================================================

    -- Procedure Customer_Match_On_PO

    -- Find the customer by matching on the purchase order 

    -- ==========================================================

    PROCEDURE customer_match_on_po ( inv_num_in                  IN    VARCHAR2,

                                     inv_amt_in                  IN    NUMBER,

                                     customer_id_out             OUT   NUMBER,

                                     trx_id_out                  OUT   NUMBER,

                                     trx_entryNo_out             OUT   NUMBER,

                                     customer_id_not_found_out   OUT   BOOLEAN ) IS



    BEGIN



      print_log ( 'ajcl_bc_lockbox_pkg.customer_match_on_po (+)' );



      print_log ( 'inv_num_in: ' || inv_num_in );

      print_log ( 'inv_amt_in: ' || inv_amt_in );



      -- CM

      IF ( inv_amt_in < 0 ) THEN



        -- BC

        BEGIN



          SELECT DISTINCT rc.customer_id,

                 psdh.entryNo

            INTO customer_id_out,

                 trx_entryNo_out

            FROM ajcl_bc_posted_sd_headers psdh,

                 ra_customers rc

           WHERE psdh.bc_environment = gv_bc_environment

             AND psdh.class = 'CM'

             AND REPLACE(psdh.purchaseorder,'-') = REPLACE(inv_num_in, '-')

             AND psdh.remainingAmount = inv_amt_in;



          customer_id_not_found_out := FALSE;

          print_log ( 'BC - Customer found by matching on PO,' || ' customer_id_out: ' || customer_id_out || ' trx_entryNo_out: ' || trx_entryNo_out || ' inv_amt_in: ' || inv_amt_in );



        EXCEPTION

          WHEN NO_DATA_FOUND THEN

            NULL;



          WHEN TOO_MANY_ROWS THEN



            -- the invoices for this receipt are for different customers, pick one invoice 

            BEGIN



              SELECT MAX(rc.customer_id)

                INTO customer_id_out

                FROM ajcl_bc_posted_sd_headers psdh,

                     ra_customers rc

               WHERE psdh.bc_environment = gv_bc_environment

                 AND class = 'CM'

                 AND REPLACE(psdh.purchaseorder,'-') = REPLACE(inv_num_in, '-')

                 AND psdh.remainingAmount = inv_amt_in;



              customer_id_not_found_out := FALSE;

              print_log ( 'BC - Multiple customers found matching on PO, Using Max customer_id_out: ' || customer_id_out);



            EXCEPTION

              WHEN NO_DATA_FOUND THEN

                NULL;



              WHEN OTHERS THEN

                NULL;



            END;



          WHEN OTHERS THEN

            NULL;



        END;

        -- BC



        -- ORACLE

        IF ( customer_id_out IS NULL ) THEN



          BEGIN



            SELECT DISTINCT t.bill_to_customer_id,

                   t.customer_trx_id

              INTO customer_id_out,

                   trx_id_out

              FROM ra_customer_trx_all t,

                   ( SELECT customer_trx_id,

                            SUM(amount_due_remaining) amt_due

                       FROM ar_payment_schedules_all

                      WHERE org_id = gv_org_id

                        AND status = 'OP'

                   GROUP BY customer_trx_id ) ps

             WHERE t.org_id = gv_org_id

               AND t.cust_trx_type_id IN ( SELECT cust_trx_type_id

                                             FROM ra_cust_trx_types_all

                                            WHERE type = 'CM'

                                              AND org_id = gv_org_id )

               AND REPLACE(t.purchase_order, '-') = REPLACE(inv_num_in, '-')

               AND ps.amt_due = inv_amt_in

               AND ps.customer_trx_id = t.customer_trx_id;



            customer_id_not_found_out := false;

            print_log ( 'ORACLE - Customer found by matching on PO. customer_id_out: ' || customer_id_out || ' trx_id_out: ' || trx_id_out || ' inv_amt_in: ' || inv_amt_in);



          EXCEPTION

            WHEN no_data_found THEN

              NULL;



            WHEN too_many_rows THEN



              -- the invoices for this receipt are for different customers, pick one invoice 

              BEGIN



                SELECT MAX(t.bill_to_customer_id)

                  INTO customer_id_out

                  FROM ra_customer_trx_all t,

                       ( SELECT customer_trx_id,

                                SUM(amount_due_remaining) amt_due

                           FROM ar_payment_schedules_all

                          WHERE org_id = gv_org_id

                            AND status = 'OP'

                       GROUP BY customer_trx_id ) ps

                 WHERE t.org_id = gv_org_id

                   AND t.cust_trx_type_id IN ( SELECT cust_trx_type_id

                                                 FROM ra_cust_trx_types_all

                                                WHERE type = 'CM'

                                                  AND org_id = gv_org_id )

                   AND REPLACE(t.purchase_order, '-') = REPLACE(inv_num_in, '-')

                   AND ps.amt_due = inv_amt_in

                   AND ps.customer_trx_id = t.customer_trx_id;



                customer_id_not_found_out := false;

                print_log ( 'ORACLE - Multiple customers found matching on PO. Using Max Cust id. customer_id_out: ' || customer_id_out);



              EXCEPTION

                WHEN no_data_found THEN

                  NULL;



                WHEN OTHERS THEN

                  NULL;



              END;



            WHEN OTHERS THEN

              NULL;



          END;



        END IF;

        -- ORACLE



      ELSE -- INV



        -- BC

        BEGIN



          SELECT DISTINCT rc.customer_id,

                 psdh.entryNo

            INTO customer_id_out,

                 trx_entryNo_out

            FROM ajcl_bc_posted_sd_headers psdh,

                 ra_customers rc

           WHERE psdh.bc_environment = gv_bc_environment

             AND psdh.class = 'INV'

             AND REPLACE(psdh.purchaseorder,'-') = REPLACE(inv_num_in, '-')

             AND psdh.remainingAmount = inv_amt_in;



          customer_id_not_found_out := FALSE;

          print_log ( 'BC - Customer found by matching on PO,' || ' customer_id_out: ' || customer_id_out || ' trx_entryNo_out: ' || trx_entryNo_out );



        EXCEPTION

          WHEN NO_DATA_FOUND THEN

            NULL;



          WHEN TOO_MANY_ROWS THEN



            -- the invoices for this receipt are for different customers, pick one invoice 

            BEGIN



              SELECT MAX(rc.customer_id)

                INTO customer_id_out

                FROM ajcl_bc_posted_sd_headers psdh,

                     ra_customers rc

               WHERE psdh.bc_environment = gv_bc_environment

                 AND psdh.class = 'INV'

                 AND REPLACE(psdh.purchaseorder,'-') = REPLACE(inv_num_in,'-')

                 AND psdh.remainingAmount = inv_amt_in;



              customer_id_not_found_out := FALSE;

              print_log ( 'BC - Multiple customers found matching on PO, Using Max customer_id_out: ' || customer_id_out);



            EXCEPTION

              WHEN NO_DATA_FOUND THEN

                NULL;



              WHEN OTHERS THEN

                NULL;



            END;



          WHEN OTHERS THEN

            NULL;



        END;

        -- BC



        -- ORACLE

        IF ( customer_id_out IS NULL ) THEN

          BEGIN



            SELECT DISTINCT bill_to_customer_id,

                   customer_trx_id

              INTO customer_id_out,

                   trx_id_out

              FROM ra_customer_trx_all

             WHERE org_id = gv_org_id

               AND cust_trx_type_id IN ( SELECT cust_trx_type_id

                                           FROM ra_cust_trx_types_all

                                          WHERE type = 'INV'

                                            AND org_id = gv_org_id )

               AND REPLACE(purchase_order, '-') = REPLACE(inv_num_in, '-');



            customer_id_not_found_out := false;

            print_log ( 'ORACLE - Customer found by matching on PO. customer_id_out: ' || customer_id_out || ' trx_id_out: ' || trx_id_out);



          EXCEPTION

            WHEN no_data_found THEN

              NULL;



            WHEN too_many_rows THEN



              -- the invoices for this receipt are for different customers, pick one invoice 

              BEGIN



                SELECT MAX(bill_to_customer_id)

                  INTO customer_id_out

                  FROM ra_customer_trx_all

                 WHERE org_id = gv_org_id

                   AND cust_trx_type_id IN ( SELECT cust_trx_type_id

                                               FROM ra_cust_trx_types_all

                                              WHERE type = 'INV'

                                                AND org_id = gv_org_id )

                   AND REPLACE(purchase_order, '-') = REPLACE(inv_num_in, '-');



                customer_id_not_found := false;

                print_log ( 'ORACLE - Multiple customers found matching on PO. Using Max Cust id. customer_id_out: ' || customer_id_out);



              EXCEPTION

                WHEN no_data_found THEN

                  NULL;



                WHEN OTHERS THEN

                  NULL;



              END;



            WHEN OTHERS THEN

              NULL;



          END;



        END IF;

        -- ORACLE



      END IF; 



      print_log ( 'ajcl_bc_lockbox_pkg.customer_match_on_po (-)' );



    END customer_match_on_po;



    -- ==========================================================

    -- Procedure Cust_Match_On_Recpt_Bank_Acct

    -- ==========================================================

    PROCEDURE cust_match_on_recpt_bank_acct ( customer_bank_in            IN    VARCHAR2,

                                              customer_bank_acct_num_in   IN    VARCHAR2,

                                              customer_id_out             OUT   NUMBER ) IS

    BEGIN



      print_log ( 'ajcl_bc_lockbox_pkg.cust_match_on_recpt_bank_acct (+)' );



      print_log ( 'customer_bank_in: ' || customer_bank_in);

      print_log ( 'customer_bank_acct_num_in: ' || customer_bank_acct_num_in);



      IF ( customer_bank_in IS NOT NULL ) THEN



        -- BC

        -- Find the latest receipt that uses this bank account

        BEGIN 



          -- Recibos vinculados a recibos con UNIDENTIFIED

          SELECT rc.customer_id

            INTO customer_id_out 

            FROM ( SELECT MAX(rcp.entryNo) entryNo       

                     FROM ( SELECT entryno,

                                   amount,

                                   documentdate,

                                   bc_environment,

                                   customerNo

                              FROM ajcl_bc_cash_rec_jnl

                             WHERE bc_environment = gv_bc_environment

                               AND customerno = gv_unidentified_no

                               AND closedbyentryno IS NOT NULL

                               AND customerbankaba = customer_bank_in 

                               AND customerbankaccount = customer_bank_acct_num_in ) uni_rcp

                         ,ajcl_bc_cash_rec_jnl rcp

                    WHERE uni_rcp.bc_environment = rcp.bc_environment 

                      AND uni_rcp.amount = rcp.amount 

                      AND uni_rcp.entryno < rcp.entryno

                      AND rcp.customerbankaba IS NULL

                      AND rcp.customerbankaccount IS NULL 

                      AND TO_DATE(rcp.documentdate,'YYYY-MM-DD') BETWEEN TO_DATE(uni_rcp.documentdate,'YYYY-MM-DD') 

                                                                     AND TO_DATE(uni_rcp.documentdate,'YYYY-MM-DD') + 1

                      AND rcp.customerNo != uni_rcp.customerNo ) rcp

                ,ajcl_bc_cash_rec_jnl max_rcp 

                ,ra_customers rc

           WHERE rcp.entryNo = max_rcp.entryNo

             AND max_rcp.bc_environment = gv_bc_environment

             AND max_rcp.customerNo = rc.customer_number

           UNION

          -- Recibos que se crearon bien desde Lockbox, con el customer ok  

          SELECT rc.customer_id

            FROM ( SELECT MAX(rcp.entryNo) entryNo  

                     FROM ajcl_bc_cash_rec_jnl rcp

                    WHERE rcp.bc_environment = gv_bc_environment

                      AND rcp.customerno != gv_unidentified_no

                      AND rcp.closedbyentryno IS NULL

                      AND rcp.customerbankaba = customer_bank_in 

                      AND rcp.customerbankaccount = customer_bank_acct_num_in ) rcp

                 ,ajcl_bc_cash_rec_jnl max_rcp 

                 ,ra_customers rc

            WHERE rcp.entryNo = max_rcp.entryNo

              AND max_rcp.bc_environment = gv_bc_environment

              AND max_rcp.customerNo = rc.customer_number;



          print_log ( 'BC - Customer found (1st attemp) by matching bank info to prior receipt, customer_id_out: ' || customer_id_out);



        EXCEPTION

          WHEN OTHERS THEN

            print_log ( 'BC - Customer not found (1st attemp) by matching bank info to prior receipt, customer_id_out: ' || customer_id_out);      



            BEGIN



              -- 20240724

              /*

              SELECT rc.customer_id

                INTO customer_id_out

                FROM ajcl_bc_cash_rec_jnl crj,

                     ra_customers rc,

                     ( SELECT MAX(entryNo) entryNo 

                         FROM ajcl_bc_cash_rec_jnl

                        WHERE bc_environment = gv_bc_environment

                          AND NOT ( customerNo = gv_unidentified_no OR customerName = gv_unidentified_name )

                          AND customerBankABA = customer_bank_in

                          AND customerBankAccount = customer_bank_acct_num_in ) cr2

               WHERE crj.bc_environment = gv_bc_environment

                 AND crj.customerno = rc.customer_number

                 AND crj.entryNo = cr2.entryNo

                 AND NOT ( crj.customerNo = gv_unidentified_no OR crj.customerName = gv_unidentified_name )

                 AND crj.customerBankABA = customer_bank_in

                 AND LTRIM(crj.customerBankAccount,'0') = LTRIM(customer_bank_acct_num_in,'0');

              */

              -- Recibos vinculados a recibos con UNIDENTIFIED

              SELECT rc.customer_id

                INTO customer_id_out 

                FROM ( SELECT MAX(rcp.entryNo) entryNo       

                         FROM ( SELECT entryno,

                                       amount,

                                       documentdate,

                                       bc_environment,

                                       customerNo

                                  FROM ajcl_bc_cash_rec_jnl

                                 WHERE bc_environment = gv_bc_environment

                                   AND customerno = gv_unidentified_no

                                   AND closedbyentryno IS NOT NULL

                                   AND customerbankaba = customer_bank_in 

                                   AND LTRIM(customerbankaccount,'0') = LTRIM(customer_bank_acct_num_in,'0') ) uni_rcp

                             ,ajcl_bc_cash_rec_jnl rcp

                        WHERE uni_rcp.bc_environment = rcp.bc_environment 

                          AND uni_rcp.amount = rcp.amount 

                          AND uni_rcp.entryno < rcp.entryno

                          AND rcp.customerbankaba IS NULL

                          AND rcp.customerbankaccount IS NULL 

                          AND TO_DATE(rcp.documentdate,'YYYY-MM-DD') BETWEEN TO_DATE(uni_rcp.documentdate,'YYYY-MM-DD') 

                                                                         AND TO_DATE(uni_rcp.documentdate,'YYYY-MM-DD') + 1

                          AND rcp.customerNo != uni_rcp.customerNo ) rcp

                    ,ajcl_bc_cash_rec_jnl max_rcp 

                    ,ra_customers rc

               WHERE rcp.entryNo = max_rcp.entryNo

                 AND max_rcp.bc_environment = gv_bc_environment

                 AND max_rcp.customerNo = rc.customer_number

               UNION

              -- Recibos que se crearon bien desde Lockbox, con el customer ok

              SELECT rc.customer_id

                FROM ( SELECT MAX(rcp.entryNo) entryNo  

                         FROM ajcl_bc_cash_rec_jnl rcp

                        WHERE rcp.bc_environment = gv_bc_environment

                          AND rcp.customerno != gv_unidentified_no

                          AND rcp.closedbyentryno IS NULL

                          AND rcp.customerbankaba = customer_bank_in 

                          AND LTRIM(rcp.customerbankaccount,'0') = LTRIM(customer_bank_acct_num_in,'0') ) rcp

                     ,ajcl_bc_cash_rec_jnl max_rcp 

                     ,ra_customers rc

                WHERE rcp.entryNo = max_rcp.entryNo

                  AND max_rcp.bc_environment = gv_bc_environment

                  AND max_rcp.customerNo = rc.customer_number;

              -- 20240724



              print_log ( 'BC - Customer found (2st attemp) by matching bank info to prior receipt, customer_id_out: ' || customer_id_out);



            EXCEPTION

              WHEN OTHERS THEN

                print_log ( 'BC - Customer not found (2st attemp) by matching bank info to prior receipt, customer_id_out: ' || customer_id_out);



            END;



        END;

        -- BC



        -- ORACLE

        IF ( customer_id_out IS NULL ) THEN



          BEGIN



            SELECT -- cr.type,

                   -- cr.cash_receipt_id,

                   cr.pay_from_customer

              INTO -- prev_receipt_type_out,

                   -- prev_cr_id_out,

                   customer_id_out

              FROM ar_cash_receipts_all cr,

                   ( SELECT MAX(cash_receipt_id) cash_receipt_id

                       FROM ar_cash_receipts_all

                      WHERE status <> 'UNID'

                        AND org_id = gv_org_id

                        AND attribute3 = customer_bank_in

                        AND attribute4 = customer_bank_acct_num_in ) cr2

             WHERE cr.cash_receipt_id = cr2.cash_receipt_id

               AND cr.org_id = gv_org_id

               AND cr.status <> 'UNID'

               AND cr.attribute3 = customer_bank_in

               AND cr.attribute4 = customer_bank_acct_num_in;



            print_log ( 'ORACLE - Customer found (1st attemp) by matching bank info to prior receipt. customer_id_out: ' || customer_id_out);



          EXCEPTION

            WHEN OTHERS THEN



              print_log ( 'ORACLE - Customer not found (1st attemp) by matching bank info to prior receipt. customer_id_out: ' || customer_id_out);            



              BEGIN



                SELECT -- cr.type,

                       -- cr.cash_receipt_id,

                       cr.pay_from_customer

                  INTO -- prev_receipt_type_out,

                       -- prev_cr_id_out,

                       customer_id_out

                  FROM ar_cash_receipts_all cr,

                       ( SELECT MAX(cash_receipt_id) cash_receipt_id

                           FROM ar_cash_receipts_all

                          WHERE status <> 'UNID'

                            AND org_id = gv_org_id

                            AND attribute3 = customer_bank_in

                            AND LTRIM(attribute4,'0') = LTRIM(customer_bank_acct_num_in,'0') ) cr2

                 WHERE cr.cash_receipt_id = cr2.cash_receipt_id

                   AND cr.org_id = gv_org_id

                   AND cr.status <> 'UNID'

                   AND cr.attribute3 = customer_bank_in

                   AND LTRIM(cr.attribute4,'0') = LTRIM(customer_bank_acct_num_in,'0');



                print_log ( 'ORACLE - Customer found (2st attemp) by matching bank info to prior receipt. customer_id_out: ' || customer_id_out);



              EXCEPTION

                WHEN OTHERS THEN

                  print_log ( 'ORACLE - Customer not found (2st attemp) by matching bank info to prior receipt. customer_id_out: ' || customer_id_out);



              END;



          END;



        END IF;

        -- ORACLE



      END IF;



      print_log ( 'ajcl_bc_lockbox_pkg.cust_match_on_recpt_bank_acct (-)' );



    END cust_match_on_recpt_bank_acct;



    -- ==========================================================

    -- Procedure Inv_Match_On_Inv_Num_and_Cust 

    -- ==========================================================

    PROCEDURE inv_match_on_inv_num_and_cust ( inv_num_in       IN    VARCHAR2,

                                              inv_amt_in       IN    NUMBER,

                                              customer_id_in   IN    NUMBER,

                                              trx_id_out       OUT   NUMBER,

                                              trx_entryNo_out  OUT   NUMBER ) IS

    BEGIN



      print_log ( 'ajcl_bc_lockbox_pkg.inv_match_on_inv_num_and_cust (+)' );



      print_log ( 'inv_num_in: ' || inv_num_in);

      print_log ( 'inv_amt_in: ' || inv_amt_in);



      -- CM

      IF ( inv_amt_in < 0 ) THEN



        -- BC

        BEGIN



          SELECT psdh.entryNo

            INTO trx_entryNo_out

            FROM ajcl_bc_posted_sd_headers psdh,

                 ra_customers rc

           WHERE psdh.bc_environment = gv_bc_environment

             AND psdh.billToCustomerNo = rc.customer_number

             AND rc.customer_id = customer_id_in

             AND psdh.class = 'CM'

             AND ( psdh.transactionNo2 = REPLACE(inv_num_in,'-') OR psdh.trvinvoicenum = REPLACE(inv_num_in, '-') )

             AND psdh.remainingAmount = inv_amt_in;



          print_log ( 'BC - CM found by exact match on invoice number for receipt customer, trx_entryNo_out: ' || trx_entryNo_out );



        EXCEPTION

          WHEN NO_DATA_FOUND THEN



            BEGIN



              SELECT psdh.entryNo

                INTO trx_entryNo_out

                FROM ajcl_bc_posted_sd_headers psdh,

                     ra_customers rc 

               WHERE psdh.bc_environment = gv_bc_environment

                 AND psdh.billToCustomerNo = rc.customer_number

                 AND rc.customer_id = customer_id_in

                 AND LENGTH(psdh.transactionNo) > 3

                 AND psdh.class = 'CM'

                 AND REPLACE(REPLACE(DECODE(INSTR(inv_num_in,'-',1,2),0,inv_num_in,SUBSTR(inv_num_in,1,INSTR(inv_num_in,'-',1,2) - 1)),'-'),' ') LIKE psdh.transactionNo3 || '%'

                 AND psdh.remainingAmount = inv_amt_in;



              print_log ( 'BC - CM found by like matching on invoice number for receipt customer, trx_entryNo_out: ' || trx_entryNo_out );



            EXCEPTION

              WHEN NO_DATA_FOUND THEN

                NULL;



              WHEN OTHERS THEN

                NULL;



            END;



          WHEN OTHERS THEN

            NULL;



        END;

        -- BC



        -- ORACLE

        IF ( trx_entryNo_out IS NULL ) THEN



          BEGIN



            SELECT t.customer_trx_id

              INTO trx_id_out

              FROM ra_customer_trx_all t,

                   ( SELECT customer_trx_id,

                            SUM(amount_due_remaining) amt_due

                       FROM ar_payment_schedules_all

                      WHERE org_id = gv_org_id

                        AND status = 'OP'

                   GROUP BY customer_trx_id ) ps

             WHERE t.org_id = gv_org_id

               AND bill_to_customer_id = customer_id_in

               AND t.cust_trx_type_id IN ( SELECT cust_trx_type_id

                                             FROM ra_cust_trx_types_all

                                            WHERE type = 'CM'

                                              AND org_id = gv_org_id )

               AND REPLACE(t.trx_number, '-') = REPLACE(inv_num_in, '-')

               AND ps.amt_due = inv_amt_in

               AND ps.customer_trx_id = t.customer_trx_id;



            print_log ( 'ORACLE - CM found by exact match on invoice number for receipt customer. trx_id_out: ' || trx_id_out);



          EXCEPTION

            WHEN no_data_found THEN



              BEGIN



                SELECT t.customer_trx_id

                  INTO trx_id_out

                  FROM ra_customer_trx_all t,

                       ( SELECT customer_trx_id,

                                SUM(amount_due_remaining) amt_due

                           FROM ar_payment_schedules_all

                          WHERE org_id = gv_org_id

                            AND status = 'OP'

                       GROUP BY customer_trx_id ) ps

                 WHERE t.org_id = gv_org_id

                   AND bill_to_customer_id = customer_id_in

                   AND t.cust_trx_type_id IN ( SELECT cust_trx_type_id

                                                 FROM ra_cust_trx_types_all

                                                WHERE type = 'CM' AND org_id = gv_org_id )

                   AND REPLACE(REPLACE(DECODE(INSTR(inv_num_in, '-', 1, 2), 0, inv_num_in, SUBSTR(inv_num_in, 1, INSTR(inv_num_in, '-', 1, 2)

                        - 1)), '-'), ' ') LIKE REPLACE(REPLACE(DECODE(INSTR(t.trx_number, '-', 1, 2), 0, t.trx_number, SUBSTR(t.trx_number, 1, INSTR

                        (t.trx_number, '-', 1, 2) - 1)), '-'), ' ') || '%'

                   AND ps.amt_due = inv_amt_in

                   AND ps.customer_trx_id = t.customer_trx_id;



                print_log ( 'ORACLE - CM found by like matching on invoice number for receipt customer. trx_id_out: ' || trx_id_out );



              EXCEPTION

                WHEN no_data_found THEN

                  NULL;



                WHEN OTHERS THEN

                  NULL;



              END;



            WHEN OTHERS THEN

              NULL;



          END;



        END IF;

        -- ORACLE



      ELSE -- INV



        -- BC

        BEGIN



          SELECT psdh.entryNo

            INTO trx_entryNo_out

            FROM ajcl_bc_posted_sd_headers psdh,

                 ra_customers rc

           WHERE psdh.bc_environment = gv_bc_environment

             AND psdh.billToCustomerNo = rc.customer_number

             AND rc.customer_id = customer_id_in

             AND psdh.class = 'INV'

             AND ( psdh.transactionNo2 = REPLACE(inv_num_in,'-') OR psdh.trvinvoicenum = REPLACE(inv_num_in, '-') );



          print_log ( 'BC - Invoice found by exact match on invoice number for receipt customer, trx_entryNo_out: ' || trx_entryNo_out);



        EXCEPTION

          WHEN NO_DATA_FOUND THEN



            BEGIN



              SELECT psdh.entryNo

                INTO trx_entryNo_out

                FROM ajcl_bc_posted_sd_headers psdh,

                     ra_customers rc

               WHERE psdh.bc_environment = gv_bc_environment

                 AND psdh.billToCustomerNo = rc.customer_number

                 AND LENGTH(psdh.transactionNo) > 3

                 AND rc.customer_id = customer_id_in

                 AND psdh.class = 'INV'

                 AND REPLACE(REPLACE(DECODE(INSTR(inv_num_in,'-',1,2),0,inv_num_in,SUBSTR(inv_num_in,1,INSTR(inv_num_in,'-',1,2) - 1)),'-'),' ') LIKE psdh.transactionNo3 || '%';



              print_log ( 'BC - Invoice found by like matching on invoice number for receipt customer, trx_entryNo_out: ' || trx_entryNo_out );



            EXCEPTION

              WHEN NO_DATA_FOUND THEN

                NULL;



              WHEN OTHERS THEN

                NULL;



            END;



          WHEN OTHERS THEN

            NULL;



        END;

        -- BC



        -- ORACLE

        IF ( trx_entryNo_out IS NULL ) THEN



          BEGIN



            SELECT customer_trx_id

              INTO trx_id_out

              FROM ra_customer_trx_all t

             WHERE bill_to_customer_id = customer_id_in

               AND org_id = gv_org_id

               AND cust_trx_type_id IN ( SELECT cust_trx_type_id

                                           FROM ra_cust_trx_types_all

                                          WHERE type = 'INV'

                                            AND org_id = gv_org_id )

               AND REPLACE(trx_number, '-') = REPLACE(inv_num_in, '-');



            print_log ( 'ORACLE - Invoice found by exact match on invoice number for the receipt customer. trx_id_out: ' || trx_id_out );



          EXCEPTION

            WHEN no_data_found THEN



              BEGIN



                SELECT customer_trx_id

                  INTO trx_id_out

                  FROM ra_customer_trx_all t

                 WHERE bill_to_customer_id = customer_id_in

                   AND org_id = gv_org_id

                   AND cust_trx_type_id IN ( SELECT cust_trx_type_id

                                               FROM ra_cust_trx_types_all

                                              WHERE type = 'INV'

                                                AND org_id = gv_org_id )

                   AND REPLACE(REPLACE(DECODE(INSTR(inv_num_in, '-', 1, 2), 0, inv_num_in, SUBSTR(inv_num_in, 1, INSTR(inv_num_in, '-', 1, 2)

                       - 1)), '-'), ' ') LIKE REPLACE(REPLACE(DECODE(INSTR(t.trx_number, '-', 1, 2), 0, t.trx_number, SUBSTR(t.trx_number, 1, INSTR

                       (t.trx_number, '-', 1, 2) - 1)), '-'), ' ') || '%';



                print_log ( 'ORACLE - Invoice found matching on invoice number for the receipt customer. trx_id_out: ' || trx_id_out );



              EXCEPTION

                WHEN no_data_found THEN

                  NULL;



                WHEN OTHERS THEN

                  NULL;



              END;



            WHEN OTHERS THEN

              NULL;



          END;



        END IF;

        -- ORACLE



      END IF;



      print_log ( 'ajcl_bc_lockbox_pkg.inv_match_on_inv_num_and_cust (-)' );



    END inv_match_on_inv_num_and_cust;



    PROCEDURE inv_match_on_housebill_cust ( inv_num_in       IN    VARCHAR2,

                                            inv_amt_in       IN    NUMBER,

                                            customer_id_in   IN    NUMBER,

                                            trx_entryNo_out  OUT   NUMBER ) IS

    BEGIN



      print_log ( 'ajcl_bc_lockbox_pkg.inv_match_on_housebill_cust (+)' );



      print_log ( 'inv_num_in: ' || inv_num_in);

      print_log ( 'inv_amt_in: ' || inv_amt_in);



      BEGIN



        SELECT psdh.entryNo

          INTO trx_entryNo_out

          FROM ajcl_bc_posted_sd_headers psdh,

               ra_customers rc

         WHERE psdh.bc_environment = gv_bc_environment

           AND psdh.billToCustomerNo = rc.customer_number

           AND rc.customer_id = customer_id_in

           AND psdh.class = 'INV'

           AND psdh.csahousebill = TO_CHAR(TO_NUMBER(inv_num_in)); -- Quita los 0 delante



        print_log ( 'inv_match_on_housebill_cust - Invoice found by exact match on invoice number for receipt customer, trx_entryNo_out: ' || trx_entryNo_out);



      EXCEPTION

        WHEN NO_DATA_FOUND THEN



          BEGIN



            SELECT psdh.entryNo

              INTO trx_entryNo_out

              FROM ajcl_bc_posted_sd_headers psdh,

                   ra_customers rc

             WHERE psdh.bc_environment = gv_bc_environment

               AND psdh.billToCustomerNo = rc.customer_number

               AND LENGTH(psdh.transactionNo) > 3

               AND rc.customer_id = customer_id_in

               AND psdh.class = 'INV'

               AND psdh.csahousebill = TO_CHAR(TO_NUMBER(inv_num_in)); -- Quita los 0 delante



            print_log ( 'inv_match_on_housebill_cust - Invoice found by like matching on invoice number for receipt customer, trx_entryNo_out: ' || trx_entryNo_out );



          EXCEPTION

            WHEN NO_DATA_FOUND THEN

              NULL;



            WHEN OTHERS THEN

              NULL;



          END;



        WHEN OTHERS THEN

          NULL;



      END;



      print_log ( 'ajcl_bc_lockbox_pkg.inv_match_on_housebill_cust (-)' );



    END inv_match_on_housebill_cust;



    -- ==========================================================

    -- Procedure Inv_Match_On_PO_and_Cust

    -- Find the invoice by matching on purchase order and customer

    -- ==========================================================

    PROCEDURE inv_match_on_po_and_cust ( inv_num_in       IN    VARCHAR2,

                                         inv_amt_in       IN    NUMBER,

                                         customer_id_in   IN    NUMBER,

                                         trx_id_out       OUT   NUMBER,

                                         trx_entryNo_out  OUT   NUMBER ) IS

    BEGIN



      print_log ( 'ajcl_bc_lockbox_pkg.inv_match_on_po_and_cust (+)' );



      print_log ( 'inv_num_in: ' || inv_num_in);

      print_log ( 'inv_amt_in: ' || inv_amt_in);

      print_log ( 'customer_id_in: ' || customer_id_in);



      -- CM

      IF ( invoice_amt_v < 0 ) THEN



        -- BC

        BEGIN



          SELECT psdh.entryNo

            INTO trx_entryNo_out

            FROM ajcl_bc_posted_sd_headers psdh

           WHERE psdh.bc_environment = gv_bc_environment

             AND psdh.billToCustomerNo = customer_id_in

             AND psdh.class = 'CM'

             AND REPLACE(psdh.purchaseOrder,'-') = REPLACE(inv_num_in, '-')

             AND psdh.remainingAmount = inv_amt_in;



          print_log ( 'BC - CM found matching on PO,customer,' || ' p_trx_entryNo: ' || trx_entryNo_out );



        EXCEPTION

          WHEN NO_DATA_FOUND THEN

            NULL;



          WHEN OTHERS THEN

            NULL;



        END;

        -- BC



        -- ORACLE

        IF ( trx_entryNo_out IS NULL ) THEN



          BEGIN



            SELECT t.customer_trx_id

              INTO trx_id_out

              FROM ra_customer_trx_all t,

                   ( SELECT customer_trx_id,

                            SUM(amount_due_remaining) amt_due

                       FROM ar_payment_schedules_all

                      WHERE org_id = gv_org_id

                        AND status = 'OP'

                   GROUP BY customer_trx_id ) ps

             WHERE t.org_id = gv_org_id

               AND bill_to_customer_id = customer_id_in

               AND t.cust_trx_type_id IN ( SELECT cust_trx_type_id

                                             FROM ra_cust_trx_types_all

                                            WHERE type = 'CM'

                                              AND org_id = gv_org_id )

               AND REPLACE(t.purchase_order, '-') = REPLACE(inv_num_in, '-')

               AND ps.amt_due = inv_amt_in

               AND ps.customer_trx_id = t.customer_trx_id;



            print_log ( 'ORACLE - CM found matching on PO. trx_id_out: ' || trx_id_out);



          EXCEPTION

            WHEN no_data_found THEN

              NULL;



            WHEN OTHERS THEN

              NULL;



          END;



        END IF;

        -- ORACLE



      ELSE -- INV



        -- BC

        BEGIN



          SELECT psdh.entryNo

            INTO trx_entryNo_out

            FROM ajcl_bc_posted_sd_headers psdh

           WHERE psdh.bc_environment = gv_bc_environment

             AND psdh.billToCustomerNo = customer_id_in

             AND psdh.class = 'INV'

             AND REPLACE(psdh.purchaseOrder,'-') = REPLACE(inv_num_in, '-');





          print_log ( 'BC - Invoice found matching on PO, customer,' || ' p_trx_entryNo: ' || trx_entryNo_out );



        EXCEPTION

          WHEN NO_DATA_FOUND THEN

            NULL;



          WHEN OTHERS THEN

            NULL;



        END;



        -- ORACLE

        IF ( trx_entryNo_out IS NULL ) THEN



          BEGIN



            SELECT customer_trx_id

              INTO trx_id_out

              FROM ra_customer_trx_all

             WHERE bill_to_customer_id = customer_id_in

               AND org_id = gv_org_id

               AND cust_trx_type_id IN ( SELECT cust_trx_type_id

                                           FROM ra_cust_trx_types_all

                                          WHERE type = 'INV'

                                            AND org_id = gv_org_id )

               AND REPLACE(purchase_order, '-') = REPLACE(inv_num_in, '-');



            print_log ( 'ORACLE - Invoice found matching on PO. trx_id_out: ' || trx_id_out);



          EXCEPTION

            WHEN no_data_found THEN

              NULL;



            WHEN OTHERS THEN

              NULL;



          END;



        END IF;

        -- ORACLE



      END IF; 



      print_log ( 'ajcl_bc_lockbox_pkg.inv_match_on_po_and_cust (-)' );



    END inv_match_on_po_and_cust;



    -- ==========================================================

    -- Procedure Inv_Match_On_Inv_Num 

    -- ==========================================================

    PROCEDURE inv_match_on_inv_num ( inv_num_in       IN    VARCHAR2,

                                     inv_amt_in       IN    NUMBER,

                                     customer_id_in   IN    NUMBER,

                                     -- 202250723 

                                     -- trx_id_out       OUT   NUMBER,

                                     -- 202250723 

                                     trx_entryNo_out  OUT   NUMBER ) IS



      trx_num_v   ra_customer_trx_all.trx_number%TYPE := NULL;



    BEGIN



      print_log ( 'ajcl_bc_lockbox_pkg.inv_match_on_inv_num (+)' );



      print_log ( 'inv_num_in: ' || inv_num_in);

      print_log ( 'inv_amt_in: ' || inv_amt_in);

      print_log ( 'customer_id_in: ' || customer_id_in);



      -- CM

      IF ( inv_amt_in < 0 ) THEN 



        -- BC

        BEGIN



          SELECT psdh.transactionNo,

                 psdh.entryNo

            INTO trx_num_v,

                 trx_entryNo_out

            FROM ajcl_bc_posted_sd_headers psdh

           WHERE psdh.bc_environment = gv_bc_environment

             AND psdh.class = 'CM'

             AND psdh.remainingAmount = inv_amt_in

             AND ( psdh.transactionNo2 = REPLACE(inv_num_in,'-') OR psdh.trvinvoicenum = REPLACE(inv_num_in, '-') );



          print_log ( 'BC - Credit Memo ' || trx_num_v || ' found exact match on trx number, inv_amt_in: ' || inv_amt_in || ' trx_entryNo_out: ' || trx_entryNo_out);



        EXCEPTION

          WHEN NO_DATA_FOUND THEN



            BEGIN



              SELECT psdh.transactionNo,

                     psdh.entryNo

                INTO trx_num_v,

                     trx_entryNo_out

                FROM ajcl_bc_posted_sd_headers psdh

               WHERE psdh.bc_environment = gv_bc_environment

                 AND psdh.class = 'CM'

                 AND LENGTH(psdh.transactionNo) > 3

                 AND psdh.remainingAmount = inv_amt_in

                 AND REPLACE(REPLACE(DECODE(INSTR(inv_num_in,'-',1,2),0,inv_num_in,SUBSTR(inv_num_in,1,INSTR(inv_num_in,'-',1,2) - 1)),'-'),' ') LIKE psdh.transactionNo3 || '%';



              print_log ( 'BC - Credit Memo ' || trx_num_v || ' found by like matching on trx number, inv_amt_in: ' || inv_amt_in || ' trx_entryNo_out: ' || trx_entryNo_out);



            EXCEPTION

              WHEN NO_DATA_FOUND THEN

                NULL;



              WHEN OTHERS THEN

                NULL;



            END;



          WHEN OTHERS THEN

            NULL;



        END;

        -- BC



      ELSE -- INV



        -- BC

        BEGIN



          SELECT psdh.entryNo

            INTO trx_entryNo_out

            FROM ajcl_bc_posted_sd_headers psdh

           WHERE psdh.bc_environment = gv_bc_environment

             AND psdh.class = 'INV'

             AND REPLACE(psdh.transactionNo, '-') = REPLACE(inv_num_in, '-');



          print_log ( 'BC - Invoice found by exact match on trx number, trx_entryNo_out: ' || trx_entryNo_out);



        EXCEPTION

          WHEN NO_DATA_FOUND THEN



            BEGIN



              SELECT psdh.entryNo

                INTO trx_entryNo_out

                FROM ajcl_bc_posted_sd_headers psdh

               WHERE psdh.bc_environment = gv_bc_environment

                 AND psdh.class = 'INV'

                 AND LENGTH(psdh.transactionNo) > 3

                 AND REPLACE(REPLACE(DECODE(INSTR(inv_num_in,'-',1,2),0,inv_num_in,SUBSTR(inv_num_in,1,INSTR(inv_num_in,'-',1,2) - 1)),'-'),' ') LIKE psdh.transactionNo3 || '%';



              print_log ( 'BC - Invoice found by like matching on transactionNo, trx_entryNo_out: ' || trx_entryNo_out);



            EXCEPTION

              WHEN NO_DATA_FOUND THEN

                NULL;



              WHEN TOO_MANY_ROWS THEN



                print_log ( 'BC - Multiple Invoices found for invoice matching on trx number');

                -- If there are multiple matches then check to see if one of the invoices is for the customer of the receipt. 

                BEGIN



                  SELECT psdh.entryNo

                    INTO trx_entryNo_out

                    FROM ajcl_bc_posted_sd_headers psdh

                   WHERE psdh.bc_environment = gv_bc_environment

                     AND psdh.billToCustomerNo = customer_id_in

                     AND psdh.class = 'INV'

                     AND LENGTH(psdh.transactionNo) > 3

                     AND REPLACE(REPLACE(DECODE(INSTR(inv_num_in,'-',1,2),0,inv_num_in,SUBSTR(inv_num_in,1,INSTR(inv_num_in,'-',1,2) - 1)),'-'),' ') LIKE psdh.transactionNo3 || '%';



                  print_log ( 'BC - Invoice found matching on trx number, receipt customer, trx_entryNo_out: ' || trx_entryNo_out );



                EXCEPTION

                  WHEN NO_DATA_FOUND THEN

                    NULL;



                  WHEN OTHERS THEN

                    NULL;



                END;



              WHEN OTHERS THEN

                NULL;



            END;



          WHEN OTHERS THEN

            NULL;



        END;

        -- BC



      END IF; 



      print_log ( 'ajcl_bc_lockbox_pkg.inv_match_on_inv_num (-)' );



    END inv_match_on_inv_num;



    -- ==========================================================

    -- Procedure Inv_Match_On_PO

    -- ==========================================================

    PROCEDURE inv_match_on_po ( inv_num_in       IN    VARCHAR2,

                                inv_amt_in       IN    NUMBER,

                                customer_id_in   IN    NUMBER,

                                trx_entryNo_out  OUT   NUMBER ) IS



      trx_num_v ra_customer_trx_all.trx_number%TYPE;



    BEGIN



      print_log ( 'ajcl_bc_lockbox_pkg.inv_match_on_po (+)' );



      print_log ( 'inv_num_in: ' || inv_num_in );

      print_log ( 'inv_amt_in: ' || inv_amt_in );

      print_log ( 'customer_id_in: ' || customer_id_in );



      -- CM

      IF ( inv_amt_in < 0 ) THEN 



        trx_num_v := NULL;



        -- BC

        BEGIN



          SELECT psdh.transactionNo,

                 psdh.entryNo

            INTO trx_num_v,

                 trx_entryNo_out

            FROM ajcl_bc_posted_sd_headers psdh

           WHERE psdh.bc_environment = gv_bc_environment

             AND psdh.class = 'CM'

             AND psdh.remainingAmount = inv_amt_in

             AND REPLACE(psdh.purchaseOrder,'-') = REPLACE(inv_num_in,'-');



          print_log ( 'BC - Credit Memo ' || trx_num_v || ' found matching on PO, inv_amt_in: ' || inv_amt_in || ' trx_entryNo_out: ' || trx_entryNo_out );



        EXCEPTION

          WHEN NO_DATA_FOUND THEN

            NULL;



          WHEN OTHERS THEN

            NULL;



        END;

        -- BC



      ELSE -- INV



        -- BC

        BEGIN



          SELECT psdh.entryNo

            INTO trx_entryNo_out

            FROM ajcl_bc_posted_sd_headers psdh

           WHERE psdh.bc_environment = gv_bc_environment

             AND psdh.class = 'INV'

             AND REPLACE(psdh.purchaseOrder,'-') = REPLACE(inv_num_in,'-');



          print_log ( 'BC - Invoice found matching on PO, trx_entryNo_out: ' || trx_entryNo_out);



        EXCEPTION

          WHEN NO_DATA_FOUND THEN

            NULL;



          WHEN TOO_MANY_ROWS THEN

            print_log ( 'BC - Multiple Invoices found in AR for invoice');

            -- If there are multiple matches then check to see if one of the invoices is for the customer of the receipt. 



            BEGIN



              SELECT psdh.entryNo

                INTO trx_entryNo_out

                FROM ajcl_bc_posted_sd_headers psdh,

                     ra_customers rc

               WHERE psdh.bc_environment = gv_bc_environment

                 AND psdh.billToCustomerNo = rc.customer_number

                 AND rc.customer_id = customer_id_in

                 AND psdh.class = 'INV'

                 AND REPLACE(psdh.purchaseOrder,'-') = REPLACE(inv_num_in,'-');



              print_log ( 'Invoice found matching on PO, receipt customer, trx_entryNo_out: ' || trx_entryNo_out );



            EXCEPTION

              WHEN NO_DATA_FOUND THEN

                NULL;



              WHEN TOO_MANY_ROWS THEN

                NULL;



              WHEN OTHERS THEN

                NULL;



            END;



          WHEN OTHERS THEN

            NULL;



        END;

        -- BC



      END IF;



      print_log ( 'ajcl_bc_lockbox_pkg.inv_match_on_po (-)' );



    END inv_match_on_po;  



  BEGIN -- begin main_bc_p



    print_log ('ajcl_bc_lockbox_pkg.main_bc_p (+)');



    -- print_log ( 'Processing Log' );

    fnd_global.apps_initialize(gv_user_id, gv_ar_resp_id, 222);



    -- Clear out the message log table

    DELETE ajc_truist_ar_rec_int_log;

    COMMIT;



    FOR payment_rec IN select_payment LOOP 



      BEGIN



        error_loc_v := 'F1';	



        -- Initialize variables

        customer_id_v := NULL;



        trx_id_v := NULL;

        trx_entryNo_v := NULL;

        trx_id_used_to_find_cust_v := NULL;

        entryNo_used_to_find_cust_v := NULL;



        receipt_num_v := NULL;

        api_action_v := NULL;

        api_status_v := NULL;

        cust_bank_account_id_v := NULL;

        cr_id_v := NULL;

        customer_num_v := NULL;

        return_status_v := NULL;

        msg_count_v := NULL;

        msg_data_v := NULL;

        gl_date_v := NULL;



        rcp_entryNo_v := NULL;



        error_loc_v := NULL;

        payment_num_v := payment_rec.payment_num;

        payment_amt_v := payment_rec.payment_amt;

        payment_date_v := payment_rec.payment_date;

        cust_bank_acct_num_v := payment_rec.customer_bank_acct_num;

        customer_bank_v := payment_rec.customer_bank;

        error_loc_v := 'F2';

        receipt_date_v := payment_rec.receipt_date;

        ach_wire_cust_name_v := payment_rec.ach_wire_cust_name;

        short_ach_wire_cust_name_v := payment_rec.short_ach_wire_cust_name;

        bpr_type_of_receipt_v := payment_rec.bpr_type_of_receipt;

        error_loc_v := 'F3';

        receipt_comments_v := payment_rec.receipt_comments;

        data_trx_type_v := payment_rec.data_trx_type;

        data_payment_line_num_v := payment_rec.data_payment_line_num;

        receipt_created_v := NULL;

        amt_due_v := NULL;

        duplicate_receipt_v := 'N';

        applied_amt_v := NULL;

        onaccount_amt_v := NULL;

        unid_amt_v := NULL;

        misc_amt_v := NULL;



        print_log (' ' );

        print_log ('- Orig ACH/Wire Cust Name: ' || ach_wire_cust_name_v);



        receipt_attribute_rec.attribute3 := NULL;

        receipt_attribute_rec.attribute4 := NULL;

        receipt_attribute_rec.attribute5 := NULL;

        receipt_attribute_rec.attribute6 := NULL;

        error_loc_v := 'F4';	



        -- determine the gl_date

        IF ( gv_gl_date IS NULL ) THEN



          print_log ( 'Use payment_rec.receipt_date ' || payment_rec.receipt_date || ' as gl_date_v' );

          gl_date_v := payment_rec.receipt_date;



        ELSE



          print_log ( 'Use gv_gl_date ' || gv_gl_date || ' as gl_date_v' );

          gl_date_v := gv_gl_date;



        END IF;



        -- Se valida que la gl_date_v determinada este dentro de allow posting from - allow posting to Caso contrario, se usa la fecha gv_bc_start_date

        IF ( NOT TRUNC(gl_date_v) BETWEEN gv_bc_start_date AND gv_bc_end_date ) THEN



          print_log ( 'gl_date_v ' || gl_date_v || ' is not between gv_bc_start_date ' || gv_bc_start_date || ' and gv_bc_end_date ' || gv_bc_end_date );

          print_log ( 'Use gv_bc_start_date ' || gv_bc_start_date || ' as gl_date_v' );

          gl_date_v := gv_bc_start_date;



        END IF;



        IF ( payment_rec.data_trx_type = 'I' ) THEN



          -- ---------------------------------------------------------------------

          -- Lockbox Transaction (check and invoices)

          -- ---------------------------------------------------------------------

          print_log ( 'Data Trx Type I - Check: ' || payment_num_v || ' Check Date: ' || payment_date_v);



          -- Determine the Customer for the receipt to be created

          -- Find the first invoice number from the bank data that exists in Oracle. Use the customer from this invoice.



          OPEN select_invoice;

          customer_id_not_found := TRUE;



          WHILE customer_id_not_found LOOP



            error_loc_v := 'F5';

            FETCH select_invoice INTO inv_num_used_to_find_cust_v, inv_amt_used_to_find_cust_v;



            IF ( select_invoice%notfound ) THEN



              customer_id_not_found := FALSE;



            ELSE



              error_loc_v := 'F6';	

              -- 1. Find the invoice by matching on invoice number

              customer_match_on_invoice ( inv_num_in => inv_num_used_to_find_cust_v, 

                                          inv_amt_in => inv_amt_used_to_find_cust_v, 

                                          customer_id_out => customer_id_v, 

                                          trx_id_out => trx_id_used_to_find_cust_v, 

                                          trx_entryNo_out => entryNo_used_to_find_cust_v,

                                          customer_id_not_found_out => customer_id_not_found );



              error_loc_v := 'F7';	

              -- 2.5 Match on Purchase Order

              IF ( customer_id_v IS NULL ) THEN



                customer_match_on_po ( inv_num_in => inv_num_used_to_find_cust_v, 

                                       inv_amt_in => inv_amt_used_to_find_cust_v, 

                                       customer_id_out => customer_id_v, 

                                       trx_id_out => trx_id_used_to_find_cust_v, 

                                       trx_entryNo_out => entryNo_used_to_find_cust_v,

                                       customer_id_not_found_out => customer_id_not_found );



              END IF;



              -- Se vuelve a buscar en los invoices, Se quitan los espacios al nro de invoice del file

              IF ( customer_id_v IS NULL ) THEN



                -- inv_num_used_to_find_cust_v := REPLACE(inv_num_used_to_find_cust_v,' ');

                -- print_log ( 'Se vuelve a buscar en los invoices, se quitan los espacios al nro de invoice del file: ' || inv_num_used_to_find_cust_v);

                print_log ( 'Se vuelve a buscar en los invoices, se quitan los espacios al nro de invoice del file.' );



                customer_match_on_invoice ( inv_num_in => REPLACE(inv_num_used_to_find_cust_v,' '), 

                                            inv_amt_in => inv_amt_used_to_find_cust_v, 

                                            customer_id_out => customer_id_v, 

                                            trx_id_out => trx_id_used_to_find_cust_v, 

                                            trx_entryNo_out => entryNo_used_to_find_cust_v,

                                            customer_id_not_found_out => customer_id_not_found );



              END IF;



              -- Se quitan los espacios y los 00 del final al nro de invoice del file

              IF ( customer_id_v IS NULL ) THEN



                -- Si los ultimos 2 caracteres son 00 y estan a partir de la posicion 10 o posterior, se quitan y se busca

                IF ( SUBSTR(inv_num_used_to_find_cust_v, -2) = '00' AND

                     LENGTH(REPLACE(inv_num_used_to_find_cust_v,' ')) > 10 ) THEN



                  -- inv_num_used_to_find_cust_v := REPLACE(SUBSTR(inv_num_used_to_find_cust_v,1,LENGTH(inv_num_used_to_find_cust_v) - 2),' ');

                  -- print_log ( 'Se vuelve a buscar en los invoices, Se quitan los espacios y los 00 del final al nro de invoice del file: ' || inv_num_used_to_find_cust_v);

                  print_log ( 'Se vuelve a buscar en los invoices, Se quitan los espacios y los 00 del final al nro de invoice del file.' );



                  customer_match_on_invoice ( inv_num_in => REPLACE(SUBSTR(inv_num_used_to_find_cust_v,1,LENGTH(inv_num_used_to_find_cust_v) - 2),' '), 

                                              inv_amt_in => inv_amt_used_to_find_cust_v, 

                                              customer_id_out => customer_id_v, 

                                              trx_id_out => trx_id_used_to_find_cust_v, 

                                              trx_entryNo_out => entryNo_used_to_find_cust_v,

                                              customer_id_not_found_out => customer_id_not_found );



                END IF;



              END IF;



              -- Se busca agregando TINV adelante

              IF ( customer_id_v IS NULL ) THEN



                -- inv_num_used_to_find_cust_v := 'TINV' || inv_num_used_to_find_cust_v;

                -- print_log ( 'Se vuelve a buscar en los invoices, se agrega el TINV delante: ' || inv_num_used_to_find_cust_v );

                print_log ( 'Se vuelve a buscar en los invoices, se agrega el TINV delante. ' );



                customer_match_on_invoice ( inv_num_in => 'TINV' || REPLACE(inv_num_used_to_find_cust_v,' '), 

                                            inv_amt_in => inv_amt_used_to_find_cust_v, 

                                            customer_id_out => customer_id_v, 

                                            trx_id_out => trx_id_used_to_find_cust_v, 

                                            trx_entryNo_out => entryNo_used_to_find_cust_v,

                                            customer_id_not_found_out => customer_id_not_found );



              END IF;



              IF ( customer_id_v IS NULL ) THEN



                print_log ( 'Se vuelve a buscar en los invoices, por Housebill. ' );



                customer_match_on_housebill ( inv_num_in => REPLACE(inv_num_used_to_find_cust_v,' '),

                                              inv_amt_in => inv_amt_used_to_find_cust_v,

                                              customer_id_out => customer_id_v,

                                              trx_entryNo_out => entryNo_used_to_find_cust_v,

                                              customer_id_not_found_out => customer_id_not_found );



              END IF;



            END IF; --  Select_Invoice%NOTFOUND then



          END LOOP; -- WHILE CUSTOMER ID NOT FOUND LOOP



          CLOSE select_invoice;



         	-- The customer could not be found by matching on the invoices so these variables need to be set to null

          IF ( customer_id_v IS NULL ) THEN



            inv_num_used_to_find_cust_v := NULL;

            inv_amt_used_to_find_cust_v := NULL;



          END IF;



          -- 3. Find the invoice by matching on bank account of a prior receipt to determine customer

          IF ( customer_id_v IS NULL AND payment_rec.customer_bank IS NOT NULL ) THEN



            error_loc_v := 'F9';

            cust_match_on_recpt_bank_acct ( customer_bank_in => payment_rec.customer_bank, 

                                            customer_bank_acct_num_in => payment_rec.customer_bank_acct_num, 

                                            customer_id_out => customer_id_v );



          END IF;



          -- No match on invoice is found which means the customer could not be determined. The receipt will be created as unidentified or misc.



          IF ( customer_id_v IS NULL ) THEN



            error_loc_v := 'F12';	



            -- ================================

            -- CUSTOMER DOES NOT EXISTS

            -- ================================



            -- store the bank info from the 823 file in receipt dffs 

            receipt_attribute_rec.attribute3 := payment_rec.customer_bank;

            receipt_attribute_rec.attribute4 := payment_rec.customer_bank_acct_num;

            receipt_attribute_rec.attribute6 := payment_rec.bpr_type_of_receipt;

            receipt_attribute_rec.attribute5 := payment_rec.ach_wire_cust_name;



            print_log ( 'Customer for receipt not found');



            api_action_v := 'Unidentified Rec';

            unid_amt_v := payment_amt_v;

            error_loc_v := 'F15';

            get_receipt_number ( receipt_num_in => payment_rec.payment_num || '-' || payment_rec.receipt_date || '-U', 

                                 receipt_num_out => receipt_num_v, 

                                 duplicate_receipt_out => duplicate_receipt_v );



            IF ( duplicate_receipt_v = 'Y' ) THEN



              create_log_record ( payment_num_in => payment_rec.payment_num, 

                                  receipt_date_in => payment_rec.receipt_date, 

                                  payment_amt_in => payment_rec.payment_amt, 

                                  cust_bank_acct_num_in => payment_rec.customer_bank_acct_num, 

                                  cust_bank_in => payment_rec.customer_bank,

                                  invoice_num_in => NULL, 

                                  invoice_amt_in => NULL, 

                                  customer_id_in => gv_unidentified_customer_id, 

                                  trx_id_in => trx_id_v, 

                                  comments_in => NULL, 

                                  api_action_in => 'DUPLICATE_RECEIPT', 

                                  api_status_in => 'DUPLICATE_RECEIPT', 

                                  receipt_num_in => receipt_num_v, 

                                  ach_wire_cust_name_in => NULL, 

                                  bpr_type_of_receipt_in => payment_rec.bpr_type_of_receipt, 

                                  data_trx_type_in => payment_rec.data_trx_type, 

                                  receipt_comments_in => payment_rec.receipt_comments, 

                                  applied_amt_in => applied_amt_v, 

                                  onaccount_amt_in => onaccount_amt_v, 

                                  unid_amt_in => unid_amt_v,

                                  misc_amt_in => misc_amt_v,

                                  rcp_documentNo_in => rcp_documentNo_v,

                                  rcp_entryNo_in => rcp_entryNo_v, 

                                  trx_entryNo_in => trx_entryNo_v );



              RAISE e_duplicate_receipt;



            END IF;



            print_log ( 'Creating Unidentified receipt, ' || receipt_num_v);



            error_loc_v := 'F16';



            print_log ( 'create_rcp_bc_p 1 - lockboxReceiptNumber: ' || receipt_num_v );



            create_rcp_bc_p ( p_lockboxReceiptNumber => receipt_num_v 

                              -- || gv_rcp_number_suffix

                              ,

                              p_customer_id => gv_unidentified_customer_id,

                              p_postingDate => gl_date_v,

                              p_currencyCode => 'USD',

                              p_amount => payment_amt_v, 

                              p_comments => payment_rec.receipt_comments,

                              p_customerBankABA => payment_rec.customer_bank,

                              p_customerBankAccount => payment_rec.customer_bank_acct_num,

                              p_ACHWireBankCustCodeName => payment_rec.ach_wire_cust_name,

                              p_typeOfReceipt => payment_rec.bpr_type_of_receipt,                                 

                              --

                              p_payment_num => payment_num_v,

                              p_payment_date => payment_date_v,

                              p_payor_account_num => cust_bank_acct_num_v,

                              p_originating_bank_aba => customer_bank_v,

                              p_data_payment_line_num => data_payment_line_num_v,

                              --

                              p_documentNo => rcp_documentNo_v,

                              p_entryNo => rcp_entryNo_v,

                              --

                              p_status => v_status,

                              p_error_msg => p_error_msg );



            IF ( v_status = 'S' ) THEN



              return_status_v := 'S';

              receipt_created_v := 'Y';



            END IF;



            IF ( return_status_v = 'S' ) THEN



              error_loc_v := 'F17';

              api_status_v := 'SUCCESS';



              create_log_record ( payment_num_in => payment_rec.payment_num, 

                                  receipt_date_in => payment_rec.receipt_date, 

                                  payment_amt_in => payment_rec.payment_amt, 

                                  cust_bank_acct_num_in => payment_rec.customer_bank_acct_num, 

                                  cust_bank_in => payment_rec.customer_bank,

                                  invoice_num_in => NULL, 

                                  invoice_amt_in => NULL, 

                                  customer_id_in => customer_id_v, 

                                  trx_id_in => trx_id_v, 

                                  comments_in => NULL, 

                                  api_action_in => api_action_v, 

                                  api_status_in => api_status_v, 

                                  receipt_num_in => receipt_num_v, 

                                  ach_wire_cust_name_in => NULL,

                                  bpr_type_of_receipt_in => payment_rec.bpr_type_of_receipt, 

                                  data_trx_type_in => payment_rec.data_trx_type, 

                                  receipt_comments_in => payment_rec.receipt_comments, 

                                  applied_amt_in => applied_amt_v, 

                                  onaccount_amt_in => onaccount_amt_v, 

                                  unid_amt_in => unid_amt_v, 

                                  misc_amt_in => misc_amt_v,

                                  rcp_documentNo_in => rcp_documentNo_v,

                                  rcp_entryNo_in => rcp_entryNo_v,

                                  trx_entryNo_in => NULL );





            ELSE



              api_status_v := 'FAILED';

              RAISE e_api_failed;



            END IF; -- status = S



          ELSE  -- customer_id_v is not null



            -- ===========================

            -- CUSTOMER EXISTS

            -- ===========================

            error_loc_v := 'F18';



            SELECT account_number,

                   hp.party_name

              INTO customer_num_v,

                   customer_name_v

              FROM hz_cust_accounts_all hca,

                   hz_parties hp

             WHERE hca.cust_account_id = customer_id_v

               AND hca.party_id = hp.party_id;



            print_log ( 'Customer found: ' || customer_num_v || ' - ' || customer_name_v);



            error_loc_v := 'F19';

            receipt_attribute_rec.attribute3 := payment_rec.customer_bank;

            receipt_attribute_rec.attribute4 := payment_rec.customer_bank_acct_num;

            receipt_attribute_rec.attribute6 := payment_rec.bpr_type_of_receipt;

            receipt_attribute_rec.attribute5 := payment_rec.ach_wire_cust_name;



            error_loc_v := 'F20';



            get_receipt_number ( receipt_num_in => payment_rec.payment_num || '-' || customer_num_v, 

                                 receipt_num_out => receipt_num_v, 

                                 duplicate_receipt_out => duplicate_receipt_v );



            IF ( duplicate_receipt_v = 'Y' ) THEN



              create_log_record ( payment_num_in => payment_rec.payment_num, 

                                  receipt_date_in => payment_rec.receipt_date, 

                                  payment_amt_in => payment_rec.payment_amt, 

                                  cust_bank_acct_num_in => payment_rec.customer_bank_acct_num, 

                                  cust_bank_in => payment_rec.customer_bank,

                                  invoice_num_in => NULL, 

                                  invoice_amt_in => NULL, 

                                  customer_id_in => customer_id_v, 

                                  trx_id_in => trx_id_v, 

                                  comments_in => NULL, 

                                  api_action_in => 'DUPLICATE_RECEIPT', 

                                  api_status_in => 'DUPLICATE_RECEIPT', 

                                  receipt_num_in => receipt_num_v, 

                                  ach_wire_cust_name_in => NULL,

                                  bpr_type_of_receipt_in => payment_rec.bpr_type_of_receipt, 

                                  data_trx_type_in => payment_rec.data_trx_type, 

                                  receipt_comments_in => payment_rec.receipt_comments, 

                                  applied_amt_in => applied_amt_v, 

                                  onaccount_amt_in => onaccount_amt_v, 

                                  unid_amt_in => unid_amt_v, 

                                  misc_amt_in => misc_amt_v,

                                  rcp_documentNo_in => NULL,

                                  rcp_entryNo_in => NULL,

                                  trx_entryNo_in => NULL );



              RAISE e_duplicate_receipt;



            END IF;



            print_log ( 'Creating receipt: ' || receipt_num_v);

            api_action_v := '1 Cash Receipt';



            error_loc_v := 'F21';	



            print_log ( 'create_rcp_bc_p 2 - lockboxReceiptNumber: ' || receipt_num_v );



            -- CREATE RECEIPT HERE

            create_rcp_bc_p ( p_lockboxReceiptNumber => receipt_num_v 

                              -- || gv_rcp_number_suffix

                              ,

                              p_customer_id => customer_id_v,

                              p_postingDate => gl_date_v,

                              p_currencyCode => 'USD',

                              p_amount => payment_amt_v, 

                              p_comments => payment_rec.receipt_comments,

                              p_customerBankABA => payment_rec.customer_bank,

                              p_customerBankAccount => payment_rec.customer_bank_acct_num,

                              p_ACHWireBankCustCodeName => payment_rec.ach_wire_cust_name,

                              p_typeOfReceipt => payment_rec.bpr_type_of_receipt,

                              --

                              p_payment_num => payment_num_v,

                              p_payment_date => payment_date_v,

                              p_payor_account_num => cust_bank_acct_num_v,

                              p_originating_bank_aba => customer_bank_v,

                              p_data_payment_line_num => data_payment_line_num_v,

                              --

                              p_documentNo => rcp_documentNo_v,

                              p_entryNo => rcp_entryNo_v,

                              --

                              p_status => v_status,

                              p_error_msg => p_error_msg );



            IF ( v_status = 'S' ) THEN



              return_status_v := 'S';

              receipt_created_v := 'Y';



            END IF;



            IF ( return_status_v = 'S' ) THEN



              print_log ( 'Receipt creation successful');

              error_loc_v := 'F22';

              api_status_v := 'SUCCESS';



              create_log_record ( payment_num_in => payment_rec.payment_num, 

                                  receipt_date_in => payment_rec.receipt_date, 

                                  payment_amt_in => payment_rec.payment_amt, 

                                  cust_bank_acct_num_in => payment_rec.customer_bank_acct_num, 

                                  cust_bank_in => payment_rec.customer_bank,

                                  invoice_num_in => NULL, 

                                  invoice_amt_in => NULL, 

                                  customer_id_in => customer_id_v, 

                                  trx_id_in => trx_id_v, 

                                  comments_in => NULL, 

                                  api_action_in => api_action_v, 

                                  api_status_in => api_status_v, 

                                  receipt_num_in => receipt_num_v, 

                                  ach_wire_cust_name_in => NULL,

                                  bpr_type_of_receipt_in => payment_rec.bpr_type_of_receipt, 

                                  data_trx_type_in => payment_rec.data_trx_type, 

                                  receipt_comments_in => payment_rec.receipt_comments, 

                                  applied_amt_in => applied_amt_v, 

                                  onaccount_amt_in => onaccount_amt_v,

                                  unid_amt_in => unid_amt_v, 

                                  misc_amt_in => misc_amt_v,

                                  rcp_documentNo_in => rcp_documentNo_v,

                                  rcp_entryNo_in => rcp_entryNo_v,

                                  trx_entryNo_in => NULL );



            ELSE



              print_log ( 'Receipt creation FAILED');

              api_status_v := 'FAILED';

              RAISE e_api_failed;



            END IF; -- status = S



            -- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

            -- PREPROCESSING STEP FOR INVOICES

            -- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++



            -- Check to see if there are any negative amount transactions for this check



            num_neg_trx_v := 0;



            BEGIN



              error_loc_v := 'F23';



              SELECT COUNT(*)

                INTO num_neg_trx_v

                FROM ajc_truist_ar_lbx_bank_data

               WHERE invoice_amt < 0

                 AND NVL(processed_flag,'N') = 'N'

                 AND data_payment_line_num = payment_rec.data_payment_line_num

                 -- 2025 - KANO

                 AND journal_batch_name = gv_journal_batch_name

                 -- 2025 - KANO

                 ;



            EXCEPTION

              WHEN no_data_found THEN

                NULL;

              WHEN OTHERS THEN

                RAISE;



            END;



            IF ( num_neg_trx_v > 0 ) THEN



              print_log ( 'Negative Transactions found in bank data for this check' );



              -- Does a credit memo exists in Oracle AR for ALL the negative amount transactions?

              -- If not, then don't process the invoices and leave the receipt unapplied.

              FOR neg_trx_rec IN select_negative_trx LOOP



                neg_trx_customer_id_v := NULL;

                neg_trx_id_v := NULL;



                -- 1. Match by invoice number

                BEGIN



                  error_loc_v := 'F24';



                  SELECT DISTINCT bill_to_customer_id,

                         customer_trx_id

                    INTO neg_trx_customer_id_v,

                         neg_trx_id_v

                    FROM ra_customer_trx_all

                   WHERE org_id = gv_org_id

                     AND cust_trx_type_id IN ( SELECT cust_trx_type_id

                                                 FROM ra_cust_trx_types_all

                                                WHERE type = 'CM'

                                                  AND org_id = gv_org_id )

                     AND REPLACE(trx_number, '-') = neg_trx_rec.invoice_num;



                EXCEPTION

                  WHEN no_data_found THEN



                    print_log ( 'Invoice not found for Neg inv : ' || neg_trx_rec.invoice_num );

                    RAISE e_skip_payment_missing_cm;



                  WHEN OTHERS THEN

                    RAISE;



                END;



              END LOOP; -- neg_trx_rec loop



            END IF; -- if num_neg_trx_v > 1



            -- ===============================================

            -- PROCESS INVOICES FOR CHECK 

            -- ===============================================



            FOR inv_rec IN select_invoice LOOP



              applied_amt_v := NULL;

              onaccount_amt_v := NULL;

              unid_amt_v := NULL;

              error_loc_v := 'F26';

              invoice_num_v := inv_rec.invoice_num;

              invoice_amt_v := inv_rec.invoice_amt;

              trx_id_v := NULL;



              print_log ( '> Processing Invoice for check: ' || invoice_num_v || ' Amt: ' || invoice_amt_v);



              -- If the invoice being processed is the same invoice used to find the customer of the receipt then we can use the customer in the selection criteria



              IF ( invoice_num_v = inv_num_used_to_find_cust_v AND 

                   invoice_amt_v = inv_amt_used_to_find_cust_v ) THEN



                print_log ( 'This is the invoice that was used to find the receipt customer');



                IF ( trx_id_used_to_find_cust_v IS NOT NULL OR entryNo_used_to_find_cust_v IS NOT NULL ) THEN



                  trx_id_v := trx_id_used_to_find_cust_v;

                  trx_entryNo_v := entryNo_used_to_find_cust_v;



                ELSE



                  error_loc_v := 'F27';

                  inv_match_on_inv_num_and_cust ( inv_num_in => invoice_num_v, 

                                                  inv_amt_in => inv_amt_used_to_find_cust_v, 

                                                  customer_id_in => customer_id_v, 

                                                  trx_id_out => trx_id_v,

                                                  trx_entryNo_out => trx_entryNo_v );



                  -- Match on purchase order and customer

                  IF ( trx_id_v IS NULL AND trx_entryNo_v IS NULL ) THEN



                    error_loc_v := 'F29';

                    inv_match_on_po_and_cust ( inv_num_in => invoice_num_v, 

                                               inv_amt_in => inv_amt_used_to_find_cust_v, 

                                               customer_id_in => customer_id_v, 

                                               trx_id_out => trx_id_v,

                                               trx_entryNo_out => trx_entryNo_v );



                  END IF;



                  -- Se vuelve a buscar en los invoices

                  -- Se quitan los espacios al nro de invoice del file

                  IF ( trx_entryNo_v IS NULL ) THEN



                    -- invoice_num_v := REPLACE(invoice_num_v,' ');

                    -- print_log ( 'Se vuelve a buscar en los invoices, Se quitan los espacios al nro de invoice del file: ' || invoice_num_v); 

                    print_log ( 'Se vuelve a buscar en los invoices, Se quitan los espacios al nro de invoice del file.' ); 



                    inv_match_on_inv_num_and_cust ( inv_num_in => REPLACE(invoice_num_v,' '), 

                                                    inv_amt_in => inv_amt_used_to_find_cust_v, 

                                                    customer_id_in => customer_id_v, 

                                                    trx_id_out => trx_id_v,

                                                    trx_entryNo_out => trx_entryNo_v );



                  END IF;



                  -- Se quitan los espacios y los 00 del final al nro de invoice del file

                  IF ( trx_entryNo_v IS NULL ) THEN



                    -- Si los ultimos 2 caracteres son 00 y estan a partir de la posicion 10 o posterior, se quitan y se busca

                    IF ( SUBSTR(invoice_num_v, -2) = '00' AND

                         LENGTH(REPLACE(invoice_num_v,' ')) > 10 ) THEN



                      -- invoice_num_v := REPLACE(SUBSTR(invoice_num_v,1,LENGTH(invoice_num_v) - 2),' ');

                      -- print_log ( 'Se vuelve a buscar en los invoices, Se quitan los espacios y los 00 del final al nro de invoice del file: ' || invoice_num_v);

                      print_log ( 'Se vuelve a buscar en los invoices, Se quitan los espacios y los 00 del final al nro de invoice del file. ' );



                      inv_match_on_inv_num_and_cust ( inv_num_in => REPLACE(SUBSTR(invoice_num_v,1,LENGTH(invoice_num_v) - 2),' '), 

                                                      inv_amt_in => inv_amt_used_to_find_cust_v, 

                                                      customer_id_in => customer_id_v, 

                                                      trx_id_out => trx_id_v,

                                                      trx_entryNo_out => trx_entryNo_v );



                    END IF;



                  END IF;



                  -- Se busca agregando TINV adelante

                  IF ( trx_entryNo_v IS NULL ) THEN



                    -- inv_amt_used_to_find_cust_v := 'TINV' || inv_amt_used_to_find_cust_v;

                    -- print_log ( 'Se vuelve a buscar en los invoices, se agrega el TINV delante: ' || inv_amt_used_to_find_cust_v );

                    print_log ( 'Se vuelve a buscar en los invoices, se agrega el TINV delante.' );



                    inv_match_on_inv_num_and_cust ( inv_num_in => 'TINV' || REPLACE(invoice_num_v,' '), 

                                                    inv_amt_in => inv_amt_used_to_find_cust_v, 

                                                    customer_id_in => customer_id_v, 

                                                    trx_id_out => trx_id_v,

                                                    trx_entryNo_out => trx_entryNo_v );



                  END IF;



                  IF ( trx_entryNo_v IS NULL ) THEN



                    -- invoice_num_v := REPLACE(invoice_num_v,' ');

                    -- print_log ( 'Se vuelve a buscar en los invoices, Se quitan los espacios al nro de invoice del file: ' || invoice_num_v); 

                    print_log ( 'Se vuelve a buscar en los invoices, por Housebill. ' );



                    inv_match_on_housebill_cust ( inv_num_in => REPLACE(invoice_num_v,' '), 

                                                  inv_amt_in => inv_amt_used_to_find_cust_v, 

                                                  customer_id_in => customer_id_v, 

                                                  trx_entryNo_out => trx_entryNo_v );



                  END IF;



                END IF; --  trx_id_used_to_find_cust_v is null 



              ELSE



                -- If the invoice being processed is not the invoice used to find the customer of the receipt then we can not use the customer in the selection criteria Match on invoice number

                error_loc_v := 'F30';

                inv_match_on_inv_num ( inv_num_in => invoice_num_v, 

                                       inv_amt_in => invoice_amt_v, 

                                       customer_id_in => customer_id_v, 

                                       trx_entryNo_out => trx_entryNo_v ); 



                -- Match invoice number to purchase order 

                IF ( trx_id_v IS NULL AND trx_entryNo_v IS NULL ) THEN



                  error_loc_v := 'F32';

                  inv_match_on_po ( inv_num_in => invoice_num_v, 

                                    inv_amt_in => invoice_amt_v, 

                                    customer_id_in => customer_id_v, 

                                    trx_entryNo_out => trx_entryNo_v );



                END IF;



                -- Se vuelve a buscar en los invoices

                -- Se quitan los espacios al nro de invoice del file

                IF ( trx_entryNo_v IS NULL ) THEN



                  -- invoice_num_v := REPLACE(invoice_num_v,' ');

                  -- print_log ( 'Se vuelve a buscar en los invoices, se quitan los espacios al nro de invoice del file. ' || invoice_num_v);

                  print_log ( 'Se vuelve a buscar en los invoices, se quitan los espacios al nro de invoice del file.' );



                  inv_match_on_inv_num ( inv_num_in => REPLACE(invoice_num_v,' '), 

                                         inv_amt_in => invoice_amt_v, 

                                         customer_id_in => customer_id_v, 

                                         trx_entryNo_out => trx_entryNo_v ); 



                END IF;



                -- Se quitan los espacios y los 00 del final al nro de invoice del file

                IF ( trx_entryNo_v IS NULL ) THEN



                  -- Si los ultimos 2 caracteres son 00 y estan a partir de la posicion 10 o posterior, se quitan y se busca

                  IF ( SUBSTR(invoice_num_v, -2) = '00' AND

                       LENGTH(REPLACE(invoice_num_v,' ')) > 10 ) THEN



                    -- invoice_num_v := REPLACE(SUBSTR(invoice_num_v,1,LENGTH(invoice_num_v) - 2),' ');

                    -- print_log ( 'Se vuelve a buscar en los invoices, Se quitan los espacios y los 00 del final al nro de invoice del file: ' || invoice_num_v);

                    print_log ( 'Se vuelve a buscar en los invoices, Se quitan los espacios y los 00 del final al nro de invoice del file.');



                    inv_match_on_inv_num ( inv_num_in => REPLACE(SUBSTR(invoice_num_v,1,LENGTH(invoice_num_v) - 2),' '), 

                                           inv_amt_in => invoice_amt_v, 

                                           customer_id_in => customer_id_v, 

                                           trx_entryNo_out => trx_entryNo_v ); 



                  END IF;



                END IF;



                -- Se busca agregando TINV adelante

                IF ( trx_entryNo_v IS NULL ) THEN



                  -- invoice_num_v := 'TINV' || invoice_num_v;

                  -- print_log ( 'Se vuelve a buscar en los invoices, se agrega el TINV delante: ' || invoice_num_v );

                  print_log ( 'Se vuelve a buscar en los invoices, se agrega el TINV delante.' );



                  inv_match_on_inv_num ( inv_num_in => 'TINV' || REPLACE(invoice_num_v,' '), 

                                         inv_amt_in => invoice_amt_v, 

                                         customer_id_in => customer_id_v, 

                                         trx_entryNo_out => trx_entryNo_v ); 



                END IF;



                IF ( trx_entryNo_v IS NULL ) THEN



                  print_log ( 'Se vuelve a buscar en los invoices, por Housebill. ' );



                  inv_match_on_housebill_cust ( inv_num_in => REPLACE(invoice_num_v,' '), 

                                                inv_amt_in => invoice_amt_v, 

                                                customer_id_in => customer_id_v, 

                                                trx_entryNo_out => trx_entryNo_v );



                END IF;



              END IF; 



              -- Si no se encontro el inv, se inserta en la tabla de app con ERROR, para que le aparezca en el reporte al user

              IF ( trx_id_v IS NULL AND trx_entryNo_v IS NULL AND invoice_num_v IS NOT NULL ) THEN           



                insert_app_inv_not_found_p ( p_rcp_entryNo => rcp_entryNo_v,

                                             p_posting_date => gl_date_v,

                                             p_currency_code => 'USD',

                                             p_amount => inv_rec.invoice_amt,

                                             p_trx_number => invoice_num_v,

                                             p_status => p_status,

                                             p_error_msg => p_error_msg );



              END IF;



              IF ( trx_id_v IS NOT NULL OR trx_entryNo_v IS NOT NULL ) THEN



                -- ================================

                -- CUSTOMER AND INVOICE EXIST

                -- ================================

                inv_amt_due_v := 0;

                -- Get the amount due remaining. If the amount due is <>0 then apply the receipt to the invoice, otherwise,apply the receipt Onaccount.

                error_loc_v := 'F33';



                BEGIN



                  IF ( trx_entryNo_v IS NOT NULL ) THEN



                    SELECT psdh.remainingAmount

                      INTO inv_amt_due_v

                      FROM ajcl_bc_posted_sd_headers psdh

                     WHERE psdh.bc_environment = gv_bc_environment

                       AND psdh.entryNo = trx_entryNo_v;



                  END IF;



                EXCEPTION

                  WHEN NO_DATA_FOUND THEN

                    NULL;

                  WHEN OTHERS THEN

                    error_loc_v := 'E190';

                    RAISE;

                END;



                -- Si el invoice tiene monto disponible

                IF ( inv_amt_due_v <> 0 ) THEN



                  api_action_v := 'Apply Rec to Inv';

                  applied_amt_v := inv_rec.invoice_amt;



                  -- APPLY RECEIPT TO INVOICE 

                  error_loc_v := 'F34'; 



                  -- Solo se procesan aplicaciones de recibos que pudieron ser creados

                  IF ( rcp_entryNo_v IS NOT NULL ) THEN



                    print_log ( 'Amount Remaining <> 0, Apply receipt to invoice.' );



                    process_app_bc_p ( p_rcp_entryNo => rcp_entryNo_v,

                                       p_trx_entryNo => trx_entryNo_v,

                                       p_trx_id => trx_id_v,

                                       p_posting_date => gl_date_v,

                                       p_currency_code => 'USD',

                                       p_amount => inv_rec.invoice_amt,

                                       --

                                       p_status => p_status,

                                       p_error_msg => p_error_msg );



                  ELSE



                    p_status := 'E';



                  END IF;



                  IF ( p_status = 'S' ) THEN



                    return_status_v := 'S';



                  END IF;



                END IF;



              END IF; -- trx_id is not null



            END LOOP; -- For inv_rec in Select_Invoice LOOP



          END IF; -- customer_id_v is null



        ELSIF ( payment_rec.data_trx_type IN ('X','C') ) THEN



          -- ----------------------------------------------------------------------

          -- ACH and Wire Processing 

          -- ----------------------------------------------------------------------



          -- STEP 1 - FIND THE CUSTOMER

          -- Determine the customer by matching the banks aba and acct to the bank dffs on prior receipts

          -- prev_receipt_type_v := NULL;

          -- prev_cr_id_v := NULL;

          customer_id_v := NULL;

          num_ach_ctx_inv_v := 0;

          error_loc_v := 'F40';



          cust_match_on_recpt_bank_acct ( customer_bank_in => payment_rec.customer_bank, 

                                          customer_bank_acct_num_in => payment_rec.customer_bank_acct_num,

                                          customer_id_out => customer_id_v );



          IF ( customer_id_v IS NULL ) THEN 



            -- try to match the customer code from the bank to the ach/wire customer code dff on the customer

            v_party_name := NULL;



            BEGIN



              SELECT cust_account_id

                INTO customer_id_v

                FROM hz_cust_accounts

               WHERE UPPER(attribute8) = UPPER(ach_wire_cust_name_v);



              print_log ( 'Found customer match via rcpt hdr; new ACH/wire customer id: ' || customer_id_v);



            EXCEPTION

              WHEN NO_DATA_FOUND THEN 



                error_loc_v := 'F41';



                -- BC

                BEGIN



                  -- 200250724

                  /*

                  SELECT DISTINCT SUBSTR(hp.party_name,1,60),

                         rc.customer_id

                    INTO v_party_name,

                         customer_id_v

                    FROM ajcl_bc_cash_rec_jnl crj,

                         ra_customers rc,

                         hz_parties hp

                   WHERE crj.bc_environment = gv_bc_environment

                     AND UPPER(crj.ACHWireBankCustCodeName) = UPPER(ach_wire_cust_name_v)

                     AND crj.source != 'REVERSAL'

                     AND crj.customerNo != gv_unidentified_no

                     AND crj.customerNo = rc.customer_number

                     AND rc.customer_id = hp.party_id;

                  */

                  -- Recibos vinculados a recibos con UNIDENTIFIED

                  SELECT DISTINCT SUBSTR(hp.party_name,1,60),

                         rc.customer_id

                    INTO v_party_name,

                         customer_id_v

                    FROM ( SELECT entryno,

                                  amount,

                                  documentdate,

                                  bc_environment,

                                  customerNo

                             FROM ajcl_bc_cash_rec_jnl 

                            WHERE customerno = gv_unidentified_no

                              AND UPPER(ACHWireBankCustCodeName) = UPPER(ach_wire_cust_name_v)

                              AND closedbyentryno IS NOT NULL

                              AND bc_environment = gv_bc_environment ) uni_rcp

                        ,ajcl_bc_cash_rec_jnl rcp

                        ,ra_customers rc

                        ,hz_parties hp

                   WHERE uni_rcp.amount = rcp.amount  

                     AND uni_rcp.entryno < rcp.entryno

                     AND TO_DATE(rcp.documentdate,'YYYY-MM-DD') BETWEEN TO_DATE(uni_rcp.documentdate,'YYYY-MM-DD') 

                                                                    AND TO_DATE(uni_rcp.documentdate,'YYYY-MM-DD') + 1

                     AND uni_rcp.bc_environment = rcp.bc_environment

                     AND rcp.customerNo != uni_rcp.customerNo

                     AND rcp.customerNo = rc.customer_number

                     AND rc.party_id = hp.party_id

                    UNION

                   -- Recibos que se crearon bien desde Lockbox, con el customer ok  

                   SELECT DISTINCT SUBSTR(hp.party_name,1,60),

                          rc.customer_id

                     FROM ajcl_bc_cash_rec_jnl rcp

                         ,ra_customers rc

                         ,hz_parties hp

                    WHERE rcp.customerno != gv_unidentified_no

                      AND UPPER(rcp.ACHWireBankCustCodeName) = UPPER(ach_wire_cust_name_v)

                      AND rcp.closedbyentryno IS NULL

                      AND rcp.bc_environment = gv_bc_environment

                      AND rcp.customerNo = rc.customer_number

                      AND rc.party_id = hp.party_id;



                  print_log ( 'BC - Found customer match via rcpt hdr; new ACH/wire customer: ' || v_party_name);

                  ach_wire_cust_name_v := v_party_name;

                  receipt_attribute_rec.attribute5 := ach_wire_cust_name_v;



                EXCEPTION

                  WHEN NO_DATA_FOUND THEN



                    print_log ( 'BC - Found no customer match via rcpt hdr for ACH/wire');

                    customer_id_v := NULL;



                  WHEN TOO_MANY_ROWS THEN



                    BEGIN



                      -- Recibos vinculados a recibos con UNIDENTIFIED

                      SELECT DISTINCT SUBSTR(hp.party_name,1,60),

                             rc.customer_id

                        INTO v_party_name,

                             customer_id_v

                        FROM ( SELECT entryno,

                                      amount,

                                      documentdate,

                                      bc_environment,

                                      customerNo 

                                 FROM ajcl_bc_cash_rec_jnl 

                                WHERE customerno = gv_unidentified_no

                                  AND UPPER(ACHWireBankCustCodeName) = UPPER(ach_wire_cust_name_v)

                                  AND closedbyentryno IS NOT NULL

                                  AND bc_environment = gv_bc_environment ) uni_rcp

                            ,ajcl_bc_cash_rec_jnl rcp

                            ,ra_customers rc

                            ,hz_parties hp

                       WHERE uni_rcp.amount = rcp.amount  

                         AND uni_rcp.entryno < rcp.entryno

                         AND TO_DATE(rcp.documentdate,'YYYY-MM-DD') BETWEEN TO_DATE(uni_rcp.documentdate,'YYYY-MM-DD') 

                                                                        AND TO_DATE(uni_rcp.documentdate,'YYYY-MM-DD') + 1

                         AND uni_rcp.bc_environment = rcp.bc_environment

                         AND rcp.customerNo != uni_rcp.customerNo

                         AND rcp.customerNo = rc.customer_number

                         AND rc.party_id = hp.party_id

                         AND SUBSTR(hp.party_name,1,60) = ach_wire_cust_name_v

                        UNION

                       -- Recibos que se crearon bien desde Lockbox, con el customer ok  

                       SELECT DISTINCT SUBSTR(hp.party_name,1,60),

                              rc.customer_id

                         FROM ajcl_bc_cash_rec_jnl rcp

                             ,ra_customers rc

                             ,hz_parties hp

                        WHERE rcp.customerno != gv_unidentified_no

                          AND UPPER(rcp.ACHWireBankCustCodeName) = UPPER(ach_wire_cust_name_v)

                          AND rcp.closedbyentryno IS NULL

                          AND rcp.bc_environment = gv_bc_environment

                          AND rcp.customerNo = rc.customer_number

                          AND rc.party_id = hp.party_id

                          AND SUBSTR(hp.party_name,1,60) = ach_wire_cust_name_v;



                    EXCEPTION

                      WHEN NO_DATA_FOUND THEN

                        print_log ( 'BC - Found no customer match via rcpt hdr for ACH/wire');

                        customer_id_v := NULL;



                      WHEN TOO_MANY_ROWS THEN

                        print_log ( 'BC - Found too many customer matches via rcpt hdr for ACH/wire');

                        customer_id_v := NULL;



                    END;



                END;

                -- BC



                -- ORACLE

                IF ( customer_id_v IS NULL ) THEN



                  BEGIN



                    SELECT DISTINCT SUBSTR(hp.party_name,1,60),

                           hca.cust_account_id

                      INTO v_party_name,

                           customer_id_v

                      FROM ar_cash_receipts_all acr,

                           hz_cust_accounts_all hca,

                           hz_parties hp

                     WHERE UPPER(acr.attribute5) = UPPER(ach_wire_cust_name_v)

                       AND acr.status NOT IN ('UNID','REV')

                       AND acr.org_id = gv_org_id

                       AND acr.pay_from_customer = hca.cust_account_id

                       AND hca.party_id = hp.party_id;



                    print_log ( 'ORACLE - Found customer match via rcpt hdr; new ACH/wire customer: ' || v_party_name);

                    ach_wire_cust_name_v := v_party_name;

                    receipt_attribute_rec.attribute5 := ach_wire_cust_name_v;



                  EXCEPTION

                    WHEN NO_DATA_FOUND THEN



                      print_log ( 'ORACLE - Found no customer match via rcpt hdr for ACH/wire');

                      customer_id_v := NULL;



                    WHEN TOO_MANY_ROWS THEN



                      BEGIN



                        SELECT DISTINCT SUBSTR(party_name,1,60),

                               b.cust_account_id

                          INTO v_party_name,

                               customer_id_v

                          FROM ar_cash_receipts_all   a,

                               hz_cust_accounts_all   b,

                               hz_parties             c

                         WHERE a.attribute5 = ach_wire_cust_name_v

                           AND SUBSTR(party_name,1,60) = ach_wire_cust_name_v

                           AND a.status NOT IN ('UNID','REV')

                           AND a.org_id = gv_org_id

                           AND a.pay_from_customer = b.cust_account_id

                           AND b.party_id = c.party_id;



                      EXCEPTION

                        WHEN NO_DATA_FOUND THEN

                          print_log ( 'ORACLE - Found no customer match via rcpt hdr for ACH/wire');

                          customer_id_v := NULL;



                        WHEN TOO_MANY_ROWS THEN

                          print_log ( 'ORACLE - Found too many customer matches via rcpt hdr for ACH/wire');

                          customer_id_v := NULL;

                      END;



                  END;



                END IF;  

                -- ORACLE 



              WHEN too_many_rows THEN

                customer_id_v := NULL;

              WHEN OTHERS THEN

                RAISE;

            END;



          END IF; -- customer_id_v is null 



          IF ( ( payment_rec.data_trx_type = 'X' ) OR

               ( payment_rec.data_trx_type = 'C' AND payment_rec.bpr_type_of_receipt IN ('ACH-CTX','CHK-PBC') ) ) THEN



            -- Are there invoices for this payment Count the number of invoices for the ACH-CTX payment

            SELECT COUNT(*)

              INTO num_ach_ctx_inv_v

              FROM ajc_truist_ar_lbx_bank_data

             WHERE NVL(processed_flag,'N') = 'N'

               AND group_id = payment_rec.group_id

               AND data_payment_line_num = payment_rec.data_payment_line_num

               AND invoice_num IS NOT NULL

               -- 2025 - KANO

               AND journal_batch_name = gv_journal_batch_name

               -- 2025 - KANO

               ;



            print_log ( 'Number of invoices for ACH-CTX | CHK-PBC payment: ' || num_ach_ctx_inv_v );



          END IF;



          -- If this is ACH-CTX bpr receipt type with invoices and customer id is still null then try to find the customer from the invoices

          IF ( customer_id_v IS NULL AND 

               ( ( payment_rec.data_trx_type = 'X' ) OR ( payment_rec.data_trx_type = 'C' AND payment_rec.bpr_type_of_receipt IN ('ACH-CTX','CHK-PBC') ) ) AND 

               num_ach_ctx_inv_v > 0 ) THEN



            OPEN select_invoice;

            customer_id_not_found := true;



            WHILE customer_id_not_found LOOP



              error_loc_v := 'F42';

              FETCH select_invoice INTO achinv_num_used_to_find_cust_v, achinv_amt_used_to_find_cust_v;



              IF ( select_invoice%notfound ) THEN



                customer_id_not_found := false;



              ELSE



                error_loc_v := 'F43';



                customer_match_on_invoice ( inv_num_in => achinv_num_used_to_find_cust_v, 

                                            inv_amt_in => achinv_amt_used_to_find_cust_v, 

                                            customer_id_out => customer_id_v, 

                                            trx_id_out => trx_id_used_to_find_cust_v, 

                                            trx_entryNo_out => entryNo_used_to_find_cust_v,

                                            customer_id_not_found_out => customer_id_not_found );



                IF ( customer_id_v IS NULL ) THEN



                  error_loc_v := 'F45';



                  customer_match_on_po ( inv_num_in => achinv_num_used_to_find_cust_v, 

                                         inv_amt_in => achinv_amt_used_to_find_cust_v, 

                                         customer_id_out => customer_id_v, 

                                         trx_id_out => trx_id_used_to_find_cust_v, 

                                         trx_entryNo_out => entryNo_used_to_find_cust_v,

                                         customer_id_not_found_out => customer_id_not_found );



                END IF;



                -- Se vuelve a buscar en los invoices

                -- Se quitan los espacios al nro de invoice del file

                IF ( customer_id_v IS NULL ) THEN



                  -- achinv_num_used_to_find_cust_v := REPLACE(achinv_num_used_to_find_cust_v,' ');

                  -- print_log ( 'Se vuelve a buscar en los invoices, Se quitan los espacios al nro de invoice del file: ' || achinv_num_used_to_find_cust_v );

                  print_log ( 'Se vuelve a buscar en los invoices, se quitan los espacios al nro de invoice del file. ' );



                  customer_match_on_invoice ( inv_num_in => REPLACE(achinv_num_used_to_find_cust_v,' '), 

                                              inv_amt_in => achinv_amt_used_to_find_cust_v, 

                                              customer_id_out => customer_id_v, 

                                              trx_id_out => trx_id_used_to_find_cust_v, 

                                              trx_entryNo_out => entryNo_used_to_find_cust_v,

                                              customer_id_not_found_out => customer_id_not_found );



                END IF;



                -- Se quitan los espacios y los 00 del final al nro de invoice del file

                IF ( customer_id_v IS NULL ) THEN



                  -- Si los ultimos 2 caracteres son 00 y estan a partir de la posicion 10 o posterior, se quitan y se busca

                  IF ( SUBSTR(achinv_num_used_to_find_cust_v, -2) = '00' AND

                       LENGTH(REPLACE(achinv_num_used_to_find_cust_v,' ')) > 10 ) THEN



                      -- achinv_num_used_to_find_cust_v := REPLACE(SUBSTR(achinv_num_used_to_find_cust_v,1,LENGTH(achinv_num_used_to_find_cust_v) - 2),' ');

                      -- print_log ( 'Se vuelve a buscar en los invoices, Se quitan los espacios y los 00 del final al nro de invoice del file: ' || achinv_num_used_to_find_cust_v );

                      print_log ( 'Se vuelve a buscar en los invoices, se quitan los espacios y los 00 del final al nro de invoice del file. ' );



                      customer_match_on_invoice ( inv_num_in => REPLACE(SUBSTR(achinv_num_used_to_find_cust_v,1,LENGTH(achinv_num_used_to_find_cust_v) - 2),' '), 

                                                  inv_amt_in => achinv_amt_used_to_find_cust_v, 

                                                  customer_id_out => customer_id_v, 

                                                  trx_id_out => trx_id_used_to_find_cust_v, 

                                                  trx_entryNo_out => entryNo_used_to_find_cust_v,

                                                  customer_id_not_found_out => customer_id_not_found );



                  END IF;



                END IF;



                -- Se busca agregando TINV adelante

                IF ( customer_id_v IS NULL ) THEN



                  -- achinv_num_used_to_find_cust_v := 'TINV' || achinv_num_used_to_find_cust_v;

                  -- print_log ( 'Se vuelve a buscar en los invoices, se agrega el TINV delante: ' || achinv_num_used_to_find_cust_v );

                  print_log ( 'Se vuelve a buscar en los invoices, se agrega el TINV delante. ' );



                  customer_match_on_invoice ( inv_num_in => 'TINV' || REPLACE(achinv_num_used_to_find_cust_v,' '), 

                                              inv_amt_in => achinv_amt_used_to_find_cust_v, 

                                              customer_id_out => customer_id_v, 

                                              trx_id_out => trx_id_used_to_find_cust_v, 

                                              trx_entryNo_out => entryNo_used_to_find_cust_v,

                                              customer_id_not_found_out => customer_id_not_found );



                END IF;



                IF ( customer_id_v IS NULL ) THEN



                  print_log ( 'Se vuelve a buscar en los invoices, por Housebill. ' );



                  customer_match_on_housebill ( inv_num_in => REPLACE(achinv_num_used_to_find_cust_v,' '),

                                                inv_amt_in => achinv_amt_used_to_find_cust_v,

                                                customer_id_out => customer_id_v,

                                                trx_entryNo_out => entryNo_used_to_find_cust_v,

                                                customer_id_not_found_out => customer_id_not_found );



                END IF;



              END IF; -- select_invoice%NOTFOUND



            END LOOP; -- WHILE CUSTOMER_ID NOT FOUND LOOP



            CLOSE select_invoice;



          END IF; --  customer_id_v is null and payment_rec.bpr_type_of_receipt = 'ACH-CTX' 



          -- The customer could not be found by matching on the invoices so these variables need to be set to null

          IF ( customer_id_v IS NULL ) THEN



            achinv_num_used_to_find_cust_v := NULL;

            achinv_amt_used_to_find_cust_v := NULL;



          END IF;



          -- 

          -- STEP 2 - CREATE THE RECEIPT

          -- 

          -- All ACH and Wire transactions will be created as standard cash receipts 

          error_loc_v := 'F46';



          get_receipt_number ( receipt_num_in => payment_rec.short_ach_wire_cust_name || '-' || payment_rec.receipt_date, 

                               receipt_num_out => receipt_num_v, 

                               duplicate_receipt_out => duplicate_receipt_v );



          IF ( duplicate_receipt_v = 'Y' ) THEN



            create_log_record ( payment_num_in => payment_rec.payment_num, 

                                receipt_date_in => payment_rec.receipt_date, 

                                payment_amt_in => payment_rec.payment_amt, 

                                cust_bank_acct_num_in => payment_rec.customer_bank_acct_num,

                                cust_bank_in => payment_rec.customer_bank, 

                                invoice_num_in => NULL, 

                                invoice_amt_in => NULL, 

                                customer_id_in => customer_id_v, 

                                trx_id_in => trx_id_v, 

                                comments_in => NULL, 

                                api_action_in => 'DUPLICATE_RECEIPT', 

                                api_status_in => 'DUPLICATE_RECEIPT', 

                                receipt_num_in => receipt_num_v, 

                                ach_wire_cust_name_in => NULL,

                                bpr_type_of_receipt_in => payment_rec.bpr_type_of_receipt, 

                                data_trx_type_in => payment_rec.data_trx_type, 

                                receipt_comments_in => payment_rec.receipt_comments, 

                                applied_amt_in => applied_amt_v, 

                                onaccount_amt_in => onaccount_amt_v, 

                                unid_amt_in => unid_amt_v, 

                                misc_amt_in => misc_amt_v,

                                rcp_documentNo_in => NULL,

                                rcp_entryNo_in => NULL, 

                                trx_entryNo_in => NULL );



            RAISE e_duplicate_receipt;



          END IF;



          receipt_attribute_rec.attribute5 := ach_wire_cust_name_v;

          receipt_attribute_rec.attribute6 := bpr_type_of_receipt_v;



          print_log ( 'Data Trx Type: ' || payment_rec.data_trx_type);

          print_log ( 'BPR Type of Receipt: ' || bpr_type_of_receipt_v);

          print_log ( 'Receipt Num: ' || receipt_num_v);

          print_log ( 'Amount: ' || payment_amt_v);

          print_log ( 'Customer id: ' || customer_id_v);

          print_log ( 'Receipt Comments: ' || payment_rec.receipt_comments);



          IF ( customer_id_v IS NULL ) THEN



            api_action_v := 'Unidentified Rec';

            unid_amt_v := payment_amt_v;



            error_loc_v := 'F47';



            print_log ( 'create_rcp_bc_p 3 - lockboxReceiptNumber: ' || receipt_num_v );



            create_rcp_bc_p ( p_lockboxReceiptNumber => receipt_num_v 

                              -- || gv_rcp_number_suffix

                              ,

                              p_customer_id => gv_unidentified_customer_id,

                              p_postingDate => gl_date_v,

                              p_currencyCode => 'USD',

                              p_amount => payment_amt_v,

                              p_comments => payment_rec.receipt_comments, 

                              p_customerBankABA => receipt_attribute_rec.attribute3,

                              p_customerBankAccount => receipt_attribute_rec.attribute4,

                              p_ACHWireBankCustCodeName => receipt_attribute_rec.attribute5,

                              p_typeOfReceipt => receipt_attribute_rec.attribute6,                          

                              --

                              p_payment_num => payment_num_v,

                              p_payment_date => payment_date_v,

                              p_payor_account_num => cust_bank_acct_num_v,

                              p_originating_bank_aba => customer_bank_v,

                              p_data_payment_line_num => data_payment_line_num_v,

                              --

                              p_documentNo => rcp_documentNo_v,

                              p_entryNo => rcp_entryNo_v,

                              --

                              p_status => v_status,

                              p_error_msg => p_error_msg );



            IF ( v_status = 'S' ) THEN



              return_status_v := 'S';

              receipt_created_v := 'Y';



            END IF;



          ELSE



            -- Customer is found

            IF ( ( ( data_trx_type_v = 'X' ) OR 

                   ( data_trx_type_v = 'C' AND payment_rec.bpr_type_of_receipt IN ('ACH-CTX','CHK-PBC') ) ) AND 

                 num_ach_ctx_inv_v > 0 ) THEN



              api_action_v := '1 Cash Receipt';



              error_loc_v := 'F48';	



              print_log ( 'create_rcp_bc_p 4 - lockboxReceiptNumber: ' || receipt_num_v );



              -- CREATE RECEIPT HERE

              create_rcp_bc_p ( p_lockboxReceiptNumber => receipt_num_v 

                                -- || gv_rcp_number_suffix

                                ,

                                p_customer_id => customer_id_v,

                                p_postingDate => gl_date_v,

                                p_currencyCode => 'USD',

                                p_amount => payment_amt_v,

                                p_comments => payment_rec.receipt_comments, 

                                p_customerBankABA => receipt_attribute_rec.attribute3,

                                p_customerBankAccount => receipt_attribute_rec.attribute4,

                                p_ACHWireBankCustCodeName => receipt_attribute_rec.attribute5,

                                p_typeOfReceipt => receipt_attribute_rec.attribute6,

                                --

                                p_payment_num => payment_num_v,

                                p_payment_date => payment_date_v,

                                p_payor_account_num => cust_bank_acct_num_v,

                                p_originating_bank_aba => customer_bank_v,

                                p_data_payment_line_num => data_payment_line_num_v,

                                --

                                p_documentNo => rcp_documentNo_v,

                                p_entryNo => rcp_entryNo_v,

                                --

                                p_status => v_status,

                                p_error_msg => p_error_msg );



              IF ( v_status = 'S' ) THEN



                return_status_v := 'S';

                receipt_created_v := 'Y';



              END IF;



            ELSE



              api_action_v := 'Create,Apply OnAccount';

              error_loc_v := 'F49';	



              print_log ( 'create_rcp_bc_p 5 - lockboxReceiptNumber: ' || receipt_num_v );



              -- CREATE RECEIPT *AND APPLY IT ON ACCOUNT*

              create_rcp_bc_p ( p_lockboxReceiptNumber => receipt_num_v 

                                -- || gv_rcp_number_suffix

                                ,

                                p_customer_id => customer_id_v,

                                p_postingDate => gl_date_v,

                                p_currencyCode => 'USD',

                                p_amount => payment_amt_v,

                                p_comments => payment_rec.receipt_comments,

                                p_customerBankABA => receipt_attribute_rec.attribute3,

                                p_customerBankAccount => receipt_attribute_rec.attribute4,

                                p_ACHWireBankCustCodeName => receipt_attribute_rec.attribute5,

                                p_typeOfReceipt => receipt_attribute_rec.attribute6,

                                --

                                p_payment_num => payment_num_v,

                                p_payment_date => payment_date_v,

                                p_payor_account_num => cust_bank_acct_num_v,

                                p_originating_bank_aba => customer_bank_v,

                                p_data_payment_line_num => data_payment_line_num_v,

                                --

                                p_documentNo => rcp_documentNo_v,

                                p_entryNo => rcp_entryNo_v,

                                --

                                p_status => v_status,

                                p_error_msg => p_error_msg );



              IF ( v_status = 'S' ) THEN 



                return_status_v := 'S';

                receipt_created_v := 'Y';



              END IF;



            END IF;  -- payment_rec.bpr_type_of_receipt = 'ACH-CTX' and num_ach_ctx_inv_v > 0



          END IF; -- customer_id is null 



          IF ( return_status_v = 'S' ) THEN



            print_log ( 'Receipt creation successful');

            error_loc_v := 'F50';

            api_status_v := 'SUCCESS';



            create_log_record ( payment_num_in => payment_rec.payment_num, 

                                receipt_date_in => payment_rec.receipt_date, 

                                payment_amt_in => payment_rec.payment_amt, 

                                cust_bank_acct_num_in => payment_rec.customer_bank_acct_num, 

                                cust_bank_in => payment_rec.customer_bank,

                                invoice_num_in => NULL, 

                                invoice_amt_in => NULL, 

                                customer_id_in => NVL(customer_id_v,gv_unidentified_customer_id),

                                trx_id_in => trx_id_v, 

                                comments_in => NULL, 

                                api_action_in => api_action_v, 

                                api_status_in => api_status_v, 

                                receipt_num_in => receipt_num_v, 

                                ach_wire_cust_name_in => NULL,

                                bpr_type_of_receipt_in => payment_rec.bpr_type_of_receipt, 

                                data_trx_type_in => payment_rec.data_trx_type, 

                                receipt_comments_in => payment_rec.receipt_comments, 

                                applied_amt_in => applied_amt_v, 

                                onaccount_amt_in => onaccount_amt_v,

                                unid_amt_in => unid_amt_v, 

                                misc_amt_in => misc_amt_v,

                                rcp_documentNo_in => rcp_documentNo_v,

                                rcp_entryNo_in => rcp_entryNo_v,

                                trx_entryNo_in => NULL );



          ELSE



            print_log ( 'Receipt creation FAILED');

            api_status_v := 'FAILED';

            RAISE e_api_failed;



          END IF; -- status = S



          --

          -- STEP 3 - APPLY INVOICES TO RECEIPT FOR ACH-CTX receipt type

          --



          print_log ( 'STEP 3: ACH PROCESSING');

          print_log ( 'Customer id: ' || customer_id_v);

          print_log ( 'Type of Receipt: ' || payment_rec.bpr_type_of_receipt);



          IF ( customer_id_v IS NOT NULL AND 

               ( ( data_trx_type_v = 'X' ) OR ( data_trx_type_v = 'C' AND payment_rec.bpr_type_of_receipt IN ('ACH-CTX','CHK-PBC') ) ) AND 

               num_ach_ctx_inv_v > 0 ) THEN



          -- ===============================================

          -- PROCESS INVOICES FOR ACH-CTX

          -- ===============================================

          error_loc_v := 'F51';



          FOR achinv_rec IN select_invoice LOOP



            applied_amt_v := NULL;

            onaccount_amt_v := NULL;

            unid_amt_v := NULL;

            invoice_num_v := achinv_rec.invoice_num;

            invoice_amt_v := achinv_rec.invoice_amt;



            print_log ( '> Processing Invoice for ACH-CTX: ' || invoice_num_v || ' Amt: ' || invoice_amt_v );



            -- If the invoice being processed is the same invoice used to find the customer of the receipt then we can use the customer in the selection criteria



            IF ( invoice_num_v = inv_num_used_to_find_cust_v AND invoice_amt_v = inv_amt_used_to_find_cust_v ) THEN



              print_log ( 'This is the invoice that was used to find the receipt customer.');



              IF ( trx_id_used_to_find_cust_v IS NOT NULL ) THEN



                trx_id_v := trx_id_used_to_find_cust_v;

                trx_entryNo_v := entryNo_used_to_find_cust_v;



              ELSE



                error_loc_v := 'F52';

                inv_match_on_inv_num_and_cust ( inv_num_in => invoice_num_v, 

                                                inv_amt_in => inv_amt_used_to_find_cust_v, 

                                                customer_id_in => customer_id_v, 

                                                trx_id_out => trx_id_v,

                                                trx_entryNo_out => trx_entryNo_v );



                -- Match on purchase order and customer

                IF ( trx_entryNo_v IS NULL ) THEN



                  error_loc_v := 'F54';

                  inv_match_on_po_and_cust ( inv_num_in => invoice_num_v, 

                                             inv_amt_in => inv_amt_used_to_find_cust_v, 

                                             customer_id_in => customer_id_v, 

                                             trx_id_out => trx_id_v,

                                             trx_entryNo_out => trx_entryNo_v );



                END IF;



                -- Se vuelve a buscar en los invoices

                -- Se quitan los espacios al nro de invoice del file

                IF ( trx_entryNo_v IS NULL ) THEN



                  -- invoice_num_v := REPLACE(invoice_num_v,' ');

                  -- print_log ( 'Se vuelve a buscar en los invoices, Se quitan los espacios al nro de invoice del file: ' || invoice_num_v);

                  print_log ( 'Se vuelve a buscar en los invoices, se quitan los espacios al nro de invoice del file.' );



                  inv_match_on_inv_num_and_cust ( inv_num_in => REPLACE(invoice_num_v,' '), 

                                                  inv_amt_in => inv_amt_used_to_find_cust_v, 

                                                  customer_id_in => customer_id_v, 

                                                  trx_id_out => trx_id_v,

                                                  trx_entryNo_out => trx_entryNo_v );



                END IF;



                -- Se quitan los espacios y los 00 del final al nro de invoice del file

                IF ( trx_entryNo_v IS NULL ) THEN



                  -- Si los ultimos 2 caracteres son 00 y estan a partir de la posicion 10 o posterior, se quitan y se busca

                  IF ( SUBSTR(invoice_num_v, -2) = '00' AND

                       LENGTH(REPLACE(invoice_num_v,' ')) > 10 ) THEN



                    -- invoice_num_v := REPLACE(SUBSTR(invoice_num_v,1,LENGTH(invoice_num_v) - 2),' ');

                    -- print_log ( 'Se vuelve a buscar en los invoices, Se quitan los espacios y los 00 del final al nro de invoice del file: ' || invoice_num_v);

                    print_log ( 'Se vuelve a buscar en los invoices, se quitan los espacios y los 00 del final al nro de invoice del file.' );



                    inv_match_on_inv_num_and_cust ( inv_num_in => REPLACE(SUBSTR(invoice_num_v,1,LENGTH(invoice_num_v) - 2),' '), 

                                                    inv_amt_in => inv_amt_used_to_find_cust_v, 

                                                    customer_id_in => customer_id_v, 

                                                    trx_id_out => trx_id_v,

                                                    trx_entryNo_out => trx_entryNo_v );



                  END IF;



                END IF;



                -- Se busca agregando TINV adelante

                IF ( trx_entryNo_v IS NULL ) THEN



                  -- invoice_num_v := 'TINV' || invoice_num_v;

                  -- print_log ( 'Se vuelve a buscar en los invoices, se agrega el TINV delante: ' || invoice_num_v );

                  print_log ( 'Se vuelve a buscar en los invoices, se agrega el TINV delante.' );



                  inv_match_on_inv_num_and_cust ( inv_num_in => 'TINV' || REPLACE(invoice_num_v,' '), 

                                                  inv_amt_in => inv_amt_used_to_find_cust_v, 

                                                  customer_id_in => customer_id_v, 

                                                  trx_id_out => trx_id_v,

                                                  trx_entryNo_out => trx_entryNo_v );



                END IF;



              END IF; --  trx_id_used_to_find_cust_v is null 



            ELSE



              -- If the invoice being processed is not the invoice used to find the customer

              -- of the receipt then we can not use the customer in the selection criteria

              -- Match on invoice number

              error_loc_v := 'F55';

              inv_match_on_inv_num ( inv_num_in => invoice_num_v, 

                                     inv_amt_in => invoice_amt_v, 

                                     customer_id_in => customer_id_v, 

                                     trx_entryNo_out => trx_entryNo_v ); 



              -- Match invoice number to purchase order 

              IF ( trx_entryNo_v IS NULL ) THEN



                error_loc_v := 'F57';

                inv_match_on_po ( inv_num_in => invoice_num_v, 

                                  inv_amt_in => invoice_amt_v, 

                                  customer_id_in => customer_id_v, 

                                  trx_entryNo_out => trx_entryNo_v );



              END IF; -- trx_id_v is null



              -- Se vuelve a buscar en los invoices

              -- Se quitan los espacios al nro de invoice del file

              IF ( trx_entryNo_v IS NULL ) THEN



                -- invoice_num_v := REPLACE(invoice_num_v,' ');

                -- print_log ( 'Se vuelve a buscar en los invoices, Se quitan los espacios al nro de invoice del file: ' || invoice_num_v);

                print_log ( 'Se vuelve a buscar en los invoices, se quitan los espacios al nro de invoice del file.' );



                inv_match_on_inv_num ( inv_num_in => REPLACE(invoice_num_v,' '), 

                                       inv_amt_in => invoice_amt_v, 

                                       customer_id_in => customer_id_v, 

                                       trx_entryNo_out => trx_entryNo_v ); 



              END IF;



              -- Se quitan los espacios y los 00 del final al nro de invoice del file

              IF ( trx_entryNo_v IS NULL ) THEN



                -- Si los ultimos 2 caracteres son 00 y estan a partir de la posicion 10 o posterior, se quitan y se busca

                IF ( SUBSTR(invoice_num_v, -2) = '00' AND

                     LENGTH(REPLACE(invoice_num_v,' ')) > 10 ) THEN



                  -- invoice_num_v := REPLACE(SUBSTR(invoice_num_v,1,LENGTH(invoice_num_v) - 2),' ');

                  -- print_log ( 'Se vuelve a buscar en los invoices, Se quitan los espacios y los 00 del final al nro de invoice del file: ' || invoice_num_v);

                  print_log ( 'Se vuelve a buscar en los invoices, se quitan los espacios y los 00 del final al nro de invoice del file.' );



                  inv_match_on_inv_num ( inv_num_in => REPLACE(SUBSTR(invoice_num_v,1,LENGTH(invoice_num_v) - 2),' '), 

                                         inv_amt_in => invoice_amt_v, 

                                         customer_id_in => customer_id_v, 

                                         trx_entryNo_out => trx_entryNo_v ); 



                END IF;



              END IF;



              -- Se busca agregando TINV adelante

              IF ( trx_entryNo_v IS NULL ) THEN



                -- invoice_num_v := 'TINV' || invoice_num_v;

                -- print_log ( 'Se vuelve a buscar en los invoices, se agrega el TINV delante: ' || invoice_num_v );

                print_log ( 'Se vuelve a buscar en los invoices, se agrega el TINV delante.' );



                inv_match_on_inv_num ( inv_num_in => 'TINV' || REPLACE(invoice_num_v,' '), 

                                       inv_amt_in => invoice_amt_v, 

                                       customer_id_in => customer_id_v, 

                                       trx_entryNo_out => trx_entryNo_v ); 



              END IF;



              IF ( trx_entryNo_v IS NULL ) THEN



                print_log ( 'Se vuelve a buscar en los invoices, por Housebill. ' );



                inv_match_on_housebill_cust ( inv_num_in => REPLACE(invoice_num_v,' '), 

                                              inv_amt_in => invoice_amt_v, 

                                              customer_id_in => customer_id_v, 

                                              trx_entryNo_out => trx_entryNo_v );



              END IF;



            END IF; -- if invoice_num_v = inv_num_used_to_find_cust_v then	



            -- Si no se encontro el inv, se inserta en la tabla de app con ERROR, para que le aparezca en el reporte al user

            IF ( trx_entryNo_v IS NULL AND invoice_num_v IS NOT NULL ) THEN           



              insert_app_inv_not_found_p ( p_rcp_entryNo => rcp_entryNo_v,

                                           p_posting_date => gl_date_v,

                                           p_currency_code => 'USD',

                                           p_amount => achinv_rec.invoice_amt,

                                           p_trx_number => invoice_num_v,

                                           p_status => p_status,

                                           p_error_msg => p_error_msg );



            END IF;



            IF ( trx_entryNo_v IS NOT NULL ) THEN



              -- ================================

              -- CUSTOMER AND INVOICE EXIST

              -- ================================

              inv_amt_due_v := 0;



              -- Get the amount due remaining. If the amount due is <>0 then apply the receipt to the invoice, otherwise, apply the receipt Onaccount.

              IF ( trx_entryNo_v IS NOT NULL ) THEN 



                BEGIN



                  SELECT psdh.remainingAmount

                    INTO inv_amt_due_v

                    FROM ajcl_bc_posted_sd_headers psdh

                   WHERE psdh.bc_environment = gv_bc_environment

                     AND psdh.entryno = trx_entryNo_v;



                EXCEPTION

                  WHEN NO_DATA_FOUND THEN

                    NULL;

                  WHEN OTHERS THEN

                    error_loc_v := 'E900';

                    RAISE;

                END;



              END IF;



              IF ( inv_amt_due_v <> 0 ) THEN



                api_action_v := 'Apply Rec to Inv';

                applied_amt_v := achinv_rec.invoice_amt;



                -- APPLY RECEIPT TO INVOICE 

                -- Solo se procesan aplicaciones de recibos que pudieron ser creados

                IF ( rcp_entryNo_v IS NOT NULL ) THEN



                  print_log ( 'Amount Remaining <> 0, Apply receipt to invoice.');



                  process_app_bc_p ( p_rcp_entryNo => rcp_entryNo_v,

                                     p_trx_entryNo => trx_entryNo_v,

                                     p_trx_id => trx_id_v,

                                     p_posting_date => gl_date_v,

                                     p_currency_code => 'USD',

                                     p_amount => achinv_rec.invoice_amt,

                                     --

                                     p_status => p_status,

                                     p_error_msg => p_error_msg );



                ELSE



                  p_status := 'E';



                END IF;



                error_loc_v := 'F58';



                IF ( v_status = 'S' ) THEN



                  return_status_v := 'S';



                END IF;



              END IF; -- inv_amt_due <> 0



              IF ( return_status_v = 'S' ) THEN



                api_status_v := 'SUCCESS';

                print_log ( 'Receipt application successful');

                error_loc_v := 'F61';

                create_log_record ( payment_num_in => payment_num_v, 

                                    receipt_date_in => receipt_date_v, 

                                    payment_amt_in => payment_amt_v, 

                                    cust_bank_acct_num_in => cust_bank_acct_num_v, 

                                    cust_bank_in => customer_bank_v,

                                    invoice_num_in => achinv_rec.invoice_num, 

                                    invoice_amt_in => achinv_rec.invoice_amt, 

                                    customer_id_in => customer_id_v, 

                                    trx_id_in => trx_id_v, 

                                    comments_in => NULL, 

                                    api_action_in => api_action_v, 

                                    api_status_in => api_status_v, 

                                    receipt_num_in => receipt_num_v, 

                                    ach_wire_cust_name_in => NULL, 

                                    bpr_type_of_receipt_in => payment_rec.bpr_type_of_receipt, 

                                    data_trx_type_in => payment_rec.data_trx_type, 

                                    receipt_comments_in => payment_rec.receipt_comments, 

                                    applied_amt_in => applied_amt_v, 

                                    onaccount_amt_in => onaccount_amt_v,

                                    unid_amt_in => unid_amt_v, 

                                    misc_amt_in => misc_amt_v,

                                    rcp_documentNo_in => rcp_documentNo_v,

                                    rcp_entryNo_in => rcp_entryNo_v,

                                    trx_entryNo_in => trx_entryNo_v );



              ELSE



                print_log ( 'Receipt application FAILED');

                api_status_v := 'FAILED';

                RAISE e_api_failed;



              END IF; -- status = S



            END IF;  -- trx_id_v is not null then



          END LOOP; -- Select_Invoice LOOP



        END IF; -- payment_rec.bpr_type_of_receipt = 'ACH-CTX' and num_ach_ctx_inv_v > 0 



      END IF; -- if data_trx_type = 'I' 



      -- Update the processed flag

      IF ( receipt_created_v = 'Y' ) THEN



        error_loc_v := 'F63';



        UPDATE ajc_truist_ar_lbx_bank_data

           SET processed_flag = 'Y',

               processed_date = SYSDATE

         WHERE NVL(payment_num,'X') = NVL(payment_num_v,'X')

           AND NVL(payment_date,'X') = NVL(payment_date_v,'X')

           AND NVL(processed_flag,'N') = 'N'

           AND NVL(payor_account_num,'X') = NVL(cust_bank_acct_num_v,'X')

           AND NVL(originating_bank_aba,'X') = NVL(customer_bank_v,'X')

           AND data_payment_line_num = data_payment_line_num_v

           -- 2025 - KANO

           AND journal_batch_name = gv_journal_batch_name

           -- 2025 - KANO

           ;



        COMMIT;



      END IF;



    EXCEPTION

      WHEN e_api_failed THEN



        IF ( msg_count_v = 1 ) THEN



          msg_out := msg_data_v;



        ELSIF ( msg_count_v > 1 ) THEN



          msg_v := NULL;



          LOOP



            p_count := p_count + 1;

            msg_data_v := fnd_msg_pub.get(fnd_msg_pub.g_next, fnd_api.g_false);



            IF ( msg_data_v IS NULL ) THEN



              EXIT;



            END IF;



            msg_v := msg_v || ';' || msg_data_v;



          END LOOP;



          msg_out := msg_v;



        END IF; -- msg_count_v =1



        error_loc_v := 'F62';

        -- print_log ( 'API error message: ' || msg_out);



        create_log_record ( payment_num_in => payment_num_v, 

                            receipt_date_in => receipt_date_v, 

                            payment_amt_in => payment_amt_v, 

                            cust_bank_acct_num_in => cust_bank_acct_num_v, 

                            cust_bank_in => customer_bank_v,

                            invoice_num_in => invoice_num_v, 

                            invoice_amt_in => invoice_amt_v, 

                            customer_id_in => customer_id_v, 

                            trx_id_in => trx_id_v, 

                            comments_in => msg_out, 

                            api_action_in => api_action_v, 

                            api_status_in => api_status_v, 

                            receipt_num_in => receipt_num_v, 

                            ach_wire_cust_name_in => ach_wire_cust_name_v,

                            bpr_type_of_receipt_in => bpr_type_of_receipt_v, 

                            data_trx_type_in => data_trx_type_v, 

                            receipt_comments_in => receipt_comments_v, 

                            applied_amt_in => applied_amt_v, 

                            onaccount_amt_in => onaccount_amt_v,

                            unid_amt_in => unid_amt_v, 

                            misc_amt_in => misc_amt_v,

                            rcp_documentNo_in => rcp_documentNo_v,

                            rcp_entryNo_in => rcp_entryNo_v,

                            trx_entryNo_in => trx_entryNo_v );



        -- If the receipt was created then mark all the records for this receipt as processed even if the applications failed. The user will have to handle the applications manually.



        IF ( receipt_created_v = 'Y' ) THEN



          UPDATE ajc_truist_ar_lbx_bank_data

             SET processed_flag = 'Y',

                 processed_date = SYSDATE

           WHERE NVL(payment_num,'X') = NVL(payment_num_v, 'X')

             AND NVL(payment_date,'X') = NVL(payment_date_v, 'X')

             AND NVL(processed_flag,'N') = 'N'

             AND NVL(payor_account_num,'X') = NVL(cust_bank_acct_num_v, 'X')

             AND NVL(originating_bank_aba,'X') = NVL(customer_bank_v, 'X')

             AND data_payment_line_num = data_payment_line_num_v

             -- 2025 - KANO

             AND journal_batch_name = gv_journal_batch_name

             -- 2025 - KANO

             ;



          COMMIT;



        END IF;



      WHEN e_skip_payment_missing_cm THEN



        print_log ( 'WARNING: Invoices will not be processed for payment ' || payment_num_v || ' because of missing credit memos.');



        -- If the receipt was created then mark all the records for this receipt as processed even if the applications failed. The user will have to handle the applications manually.

        IF ( receipt_created_v = 'Y' ) THEN



          UPDATE ajc_truist_ar_lbx_bank_data

             SET processed_flag = 'Y',

                 processed_date = SYSDATE

           WHERE NVL(payment_num,'X') = NVL(payment_num_v, 'X')

             AND NVL(payment_date,'X') = NVL(payment_date_v, 'X')

             AND NVL(processed_flag,'N') = 'N'

             AND NVL(payor_account_num,'X') = NVL(cust_bank_acct_num_v, 'X')

             AND NVL(originating_bank_aba,'X') = NVL(customer_bank_v, 'X')

             AND data_payment_line_num = data_payment_line_num_v

             -- 2025 - KANO

             AND journal_batch_name = gv_journal_batch_name

             -- 2025 - KANO

             ;



          COMMIT;



        END IF;



      WHEN e_duplicate_receipt THEN



        print_log ( 'WARNING: Receipt ' || receipt_num_v || ' already exists in AR');



      WHEN OTHERS THEN

        print_log ('Program encountered an unexpected error: ' || SQLERRM);

        print_log ('Payment being processed: ' || payment_num_v);



        create_log_record ( payment_num_in => payment_num_v, 

                            receipt_date_in => receipt_date_v, 

                            payment_amt_in => payment_amt_v, 

                            cust_bank_acct_num_in => cust_bank_acct_num_v, 

                            cust_bank_in => customer_bank_v,

                            invoice_num_in => invoice_num_v, 

                            invoice_amt_in => invoice_amt_v, 

                            customer_id_in => customer_id_v, 

                            trx_id_in => trx_id_v, 

                            comments_in => TO_CHAR(SQLCODE) || '-' || SQLERRM, 

                            api_action_in => api_action_v, 

                            api_status_in => api_status_v, 

                            receipt_num_in => receipt_num_v, 

                            ach_wire_cust_name_in => ach_wire_cust_name_v,

                            bpr_type_of_receipt_in => bpr_type_of_receipt_v, 

                            data_trx_type_in => data_trx_type_v, 

                            receipt_comments_in => receipt_comments_v, 

                            applied_amt_in => applied_amt_v, 

                            onaccount_amt_in => onaccount_amt_v,

                            unid_amt_in => unid_amt_v, 

                            misc_amt_in => misc_amt_v,

                            rcp_documentNo_in => rcp_documentNo_v,

                            rcp_entryNo_in => rcp_entryNo_v,

                            trx_entryNo_in => trx_entryNo_v );



        -- If the receipt was created then mark all the records for this receipt as processed even if the applications failed. The user will have to handle the applications manually.



        IF ( receipt_created_v = 'Y' ) THEN



          UPDATE ajc_truist_ar_lbx_bank_data

             SET processed_flag = 'Y',

                 processed_date = SYSDATE

           WHERE NVL(payment_num,'X') = NVL(payment_num_v,'X')

             AND NVL(payment_date,'X') = NVL(payment_date_v,'X')

             AND NVL(processed_flag,'N') = 'N'

             AND NVL(payor_account_num,'X') = NVL(cust_bank_acct_num_v,'X')

             AND NVL(originating_bank_aba,'X') = NVL(customer_bank_v,'X')

             AND data_payment_line_num = data_payment_line_num_v

             -- 2025 - KANO

             AND journal_batch_name = gv_journal_batch_name

             -- 2025 - KANO

             ;



          COMMIT;



        END IF;



      END;



    END LOOP; -- Select_Payment LOOP



    -- Update the receipt status in the log table for reporting purposes. This is needed when the interface is run in report only=Y mode.

    FOR receipt_rec IN select_receipt_from_log LOOP



      receipt_status_v := NULL;



      IF ( receipt_rec.unid_amt > 0 ) THEN



        receipt_status_v := 'Unidentified';



      ELSIF ( receipt_rec.unapply_amt > 0 ) THEN



        receipt_status_v := 'Unapplied';



           -- Create a record for the Unapplied amount that is reported in the detail control report. This is needed when when the interface is run in report only=Y mode.

           INSERT 

             INTO ajc_truist_ar_rec_int_log 

                ( payment_num,

                  receipt_date,

                  payment_amt,

                  invoice_amt,

                  customer_id,

                  api_action,

                  api_status,

                  receipt_status,

                  ach_wire_cust_name,

                  bpr_type_of_receipt,

                  receipt_num

                  -- 2025 - KANO

                 ,journal_batch_name

                  -- 2025 - KANO

                  ) 

         VALUES ( receipt_rec.payment_num,

                  receipt_rec.receipt_date,

                  receipt_rec.payment_amt,

                  receipt_rec.unapply_amt,

                  receipt_rec.customer_id,

                  'Unapplied',

                  'SUCCESS',

                  'Unapplied',

                  receipt_rec.ach_wire_cust_name,

                  receipt_rec.bpr_type_of_receipt,

                  receipt_rec.receipt_num

                  -- 2025 - KANO

                 ,gv_journal_batch_name

                  -- 2025 - KANO

                  );



      ELSIF ( receipt_rec.onacct_amt > 0 ) THEN



        receipt_status_v := 'OnAccount';



      ELSIF ( receipt_rec.misc_amt > 0 ) THEN



        receipt_status_v := 'Misc Receipt';



      ELSE



        receipt_status_v := 'Applied';



      END IF;



      UPDATE ajc_truist_ar_rec_int_log

         SET receipt_status = receipt_status_v

       WHERE receipt_num = receipt_rec.receipt_num

         -- 2025 - KANO

         AND journal_batch_name = gv_journal_batch_name

         -- 2025 - KANO

       ;



    END LOOP;



    COMMIT;



    -- Se reprocesan los recibos que no pudieron crearse porque tienen algun error con el customer que se determino. Se vuelven a enviar con el customer UNIDENTIFIED

    print_log ( ' ' );



    reprocess_rcp_error_rejected_p ( p_status => p_status,

                                     p_error_msg => p_error_msg );



    -- 20260107

    -- Se cuentan la cantidad de recibos procesados por el request actual

    v_rcp_count := 0;



    SELECT COUNT(1)

      INTO v_rcp_count

      FROM ajcl_bc_lbx_receipts

     WHERE request_id = gv_request_id

       AND bc_environment = gv_bc_environment

       AND journal_batch_name = gv_journal_batch_name;



    IF ( v_rcp_count > 0 ) THEN

    -- 20260107



      IF ( gv_file_format = 'CSV' ) THEN



        final_report_csv_p ( p_status => p_status,

                             p_error_msg => p_error_msg );



        IF ( p_status != 'S' ) THEN



          RAISE e_error;



        END IF;



        -- CREATE REPORT -----------------------------------------------------------------------------------------------------------

        ajcl_bc_utils_pkg.create_csv_p ( p_ifc => gv_bc_ifc,

                                         p_request_id => gv_request_id,

                                         p_log_seq => gv_log_seq,

                                         p_type => 'REPORT',

                                         p_filename => gv_report_filename,

                                         --

                                         p_status => p_status );



        IF ( p_status != 'S' ) THEN



          RAISE e_error;



        END IF;



      ELSIF ( gv_file_format = 'XLSX' ) THEN 



        -- No inserta en tabla, genera el xlsx directamente en el filesystem

        final_report_xlsx_p ( p_status => p_status,

                              p_error_msg => p_error_msg );     



        IF ( p_status != 'S' ) THEN



          RAISE e_error;



        END IF;  



      END IF;



      -- MAIL REPORT -------------------------------------------------------------------------------------------------------------

      ajcl_bc_utils_pkg.send_mail_with_attach ( p_to_mail => gv_email,

                                                p_subject => gv_bc_ifc || ' Report - ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                                p_body => gv_bc_ifc || ' Report.',

                                                p_type => 'REPORT',

                                                p_filename => gv_report_filename, 

                                                p_file_format => gv_file_format,

                                                p_attach_filename => gv_bc_ifc || ' Report ' || TO_CHAR(SYSDATE,'MMDDYYYY HH24MISS') || ' ' || gv_bc_environment || '.' || LOWER(gv_file_format) ); 



    ELSE



      print_log('No receipts to process.');



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => 'No receipts to process.' || CHR(10) || 'Request ID: ' || gv_request_id );



    END IF;

    -- 20260107



    p_status := 'S';



    print_log ('ajcl_bc_lockbox_pkg.main_bc_p (-)');



  EXCEPTION

    WHEN e_error THEN

      p_status := 'E';

      print_log ('ajcl_bc_lockbox_pkg.main_bc_p (-). Error: ' || p_error_msg);



    WHEN OTHERS THEN

      p_status := 'E';

      p_error_msg := SQLERRM;

      print_log ('ajcl_bc_lockbox_pkg.main_bc_p (-)' || SQLERRM);



  END main_bc_p; 



  -- MAIN ----------------------------------------------------------------------------------------------------------------------

  PROCEDURE main_p ( p_bc_environment         IN   VARCHAR2,

                     -- 2025 - KANO

                     p_journal_batch_name     IN   VARCHAR2,

                     -- 2025 - KANO

                     p_gl_date                IN   VARCHAR2,

                     p_jenkins_build_number   IN   VARCHAR2 ) IS 



    v_status           VARCHAR2(200);

    v_phase            VARCHAR2(100);



    v_argument1        VARCHAR2(100);

    v_argument2        VARCHAR2(100);

    v_argument3        VARCHAR2(100);



    v_error_msg        VARCHAR2(200);



    e_parameter_value  EXCEPTION;

    e_error            EXCEPTION;

    e_bc_setup         EXCEPTION;



  BEGIN



    gv_request_id := ajcl_bc_utils_pkg.get_request_id_f;

    gv_jenkins_build_number := p_jenkins_build_number;



    -- 2025 - KANO

    gv_journal_batch_name := p_journal_batch_name;



    IF ( gv_journal_batch_name = 'LOCKBOX' ) THEN



      gv_bc_ifc := 'AJCL BC Lockbox Interface';

      gv_report_filename := 'AJCLBCLBXIR';

      gv_output_filename := 'AJCLBCLBXIO';



    ELSE



      gv_bc_ifc := 'AJCL BC Lockbox KANO Interface';

      gv_report_filename := 'AJCLBCLBXKIR';

      gv_output_filename := 'AJCLBCLBXKIO';



    END IF;   



    -- Se pone el journal batch name en los registros que cargó el loader

    BEGIN



      UPDATE AJC_TRUIST_LBX_FILE

         SET journal_batch_name = gv_journal_batch_name;



      COMMIT;



    END;

    -- 2025 - KANO



    -- Se inserta el concurrent_job

    ajcl_bc_utils_pkg.ins_jenkins_concurrent_job_p ( p_request_id => gv_request_id,

                                                     p_job_name => gv_bc_ifc,

                                                     p_jenkins_build_number => gv_jenkins_build_number,

                                                     p_argument1 => p_bc_environment,

                                                     p_argument2 => p_gl_date );



    print_log ('ajcl_bc_lockbox_pkg.main_p (+)');



    print_log ( 'gv_request_id: ' || gv_request_id );

    print_log ( 'gv_jenkins_build_number: ' || gv_jenkins_build_number );

    -- 2025 - KANO

    print_log( 'gv_journal_batch_name: ' || gv_journal_batch_name );

    -- 2025 - KANO



    gv_file_format := ajcl_bc_ws_utils_pkg.get_parameter_f ( 'FILE_FORMAT' );

    print_log( 'FILE_FORMAT: ' || gv_file_format ); 



    -- gv_email := 'sbanchieri@gmail.com';

    gv_email := ajcl_bc_utils_pkg.get_emails_f ( 'LOCKBOX' );

    print_log( 'gv_email: ' || gv_email );



    -- 20260106 REINTENTO

    gv_retry_in_seconds := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'POST_RETRY_IN_SECONDS' );

    print_log ( 'POST_RETRY_IN_SECONDS: ' || gv_retry_in_seconds );    

    -- 20260106 REINTENTO



    -- Se valida que en BC el setup sea el correcto

    print_log( 'Checking if General Ledger Setup | Sales and Receivables Setup are ok in BC..' );



    ajcl_bc_get_entities_pkg.check_logistics_setup_p ( p_bc_environment => p_bc_environment,

                                                       p_status => v_status );



    IF ( v_status != 'S' ) THEN  



      RAISE e_bc_setup;



    END IF;



    -- Se obtiene customer_id de customer unidentified

    SELECT customer_id

      INTO gv_unidentified_customer_id

      FROM ra_customers

     WHERE customer_number = gv_unidentified_no;



    print_log( 'gv_unidentified_customer_id: ' || gv_unidentified_customer_id );



    -- Se obtienen los parametros de la company 

    print_log ( 'gv_bc_company_name: ' || gv_bc_company_name ); 



    gv_org_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                              p_column => 'ORG_ID' );



    print_log ( 'gv_org_id: ' || gv_org_id );



    gv_set_of_books_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                       p_column => 'SET_OF_BOOKS_ID' );



    print_log ( 'gv_set_of_books_id: ' || gv_set_of_books_id );



    gv_ar_resp_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                  p_column => 'AR_RESP_ID' );



    print_log ( 'gv_ar_resp_id: ' || gv_ar_resp_id );



    gv_bc_company_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                     p_column => 'BC_COMPANY_ID' );



    print_log ( 'gv_bc_company_id: ' || gv_bc_company_id );



    ajcl_bc_utils_pkg.initialize_p ( p_org_id => gv_org_id );

    print_log ( 'ajcl_bc_utils_pkg.initialize_p' );



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

    print_log ( 'gv_receipt_method_id: ' || gv_receipt_method_id );



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



    -- Se obtienen los Cash Rec Jnl de BC

    ajcl_bc_get_entities_pkg.get_cash_receipts_p ( p_bc_environment => gv_bc_environment,

                                                   p_bc_ifc => gv_bc_ifc,

                                                   p_request_id => gv_request_id,

                                                   p_log_seq => gv_log_seq,

                                                   p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'ajcl_bc_get_entities_pkg.get_cash_receipts_p';

      RAISE e_error;



    END IF;



    print_log ( 'Se obtienen las fechas Allow Posting From y Allow Posting To de General Ledger Setup de BC.' );

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



    -- AJC Truist Parse 823 AR Data File 

    parse_p ( p_status => v_status,

              p_error_msg => v_error_msg );



    IF ( v_status != 'S' ) THEN



      v_phase := 'parse_p';

      RAISE e_error;



    END IF;



    -- AJC Truist Preprocess 823 AR Data

    preprocess_p ( p_status => v_status,

                   p_error_msg => v_error_msg );



    IF ( v_status != 'S' ) THEN



      v_phase := 'preprocess_p';

      RAISE e_error;



    END IF;



    -- AJC Truist 823 AR Interface

    main_bc_p ( p_status => v_status,

                p_error_msg => v_error_msg ); 



    IF ( v_status != 'S' ) THEN



      v_phase := 'main_bc_p';

      RAISE e_error;



    END IF;



    -- Si no es PROD, se borra la tabla que carga el loader, porque la info llega con trigger desde PROD a estos ambientes    

    IF ( ajcl_bc_utils_pkg.get_db_name_f != 'PROD' ) THEN



      DELETE ajc_truist_lbx_file;

      COMMIT;



    END IF;



    -- Se actualiza el concurrent_job

    ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'S' );



    print_log ('ajcl_bc_lockbox_pkg.main_p (-)');



  EXCEPTION

    WHEN e_bc_setup THEN

      print_log('ajcl_bc_lockbox_pkg.main_p (!). BC setup error. please contact support.');



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



    WHEN e_error THEN

      print_log ('ajcl_bc_lockbox_pkg.main_p (!). Phase: ' || v_phase);

      print_log ('Error: ' || v_error_msg);

      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => v_error_msg || CHR(10) || 'Request ID: ' || gv_request_id );



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



      RAISE_APPLICATION_ERROR(-20000,'Error at phase: ' || v_phase );



    WHEN OTHERS THEN

      print_log ('ajcl_bc_lockbox_pkg.main_p (!). Phase: ' || v_phase);

      print_log ('Error: ' || SQLERRM);

      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => 'General Error: ' || SQLERRM || CHR(10) || 'Request ID: ' || gv_request_id );



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



      RAISE_APPLICATION_ERROR(-20000,'General Error: ' || SQLERRM );              



  END main_p;



END ajcl_bc_lockbox_pkg;
