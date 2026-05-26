PACKAGE BODY ajcl_bc_lockbox_pkg IS
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
                                 INSTR(v_line,v_col_delim,1,12))
