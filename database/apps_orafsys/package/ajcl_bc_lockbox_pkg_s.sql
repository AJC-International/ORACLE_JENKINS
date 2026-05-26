CREATE OR REPLACE PACKAGE ajcl_bc_lockbox_pkg IS

-- Creation: SBANCHIERI 06-FEB-2024

-- Modified: SBANCHIERI 2025 - KANO

-- Modified: SBANCHIERI DEC2025 - RETRY



  gv_bc_company_name          ajc_bc_companies.bc_company_name%TYPE := 'LOGIS-USA-USD';

  gv_bc_company_id            ajc_bc_companies.bc_company_id%TYPE;  

  gv_set_of_books_id          ajc_bc_companies.set_of_books_id%TYPE;  

  gv_org_id                   ajc_bc_companies.org_id%TYPE;



  gv_user_id                  NUMBER := 0;

  gv_ar_resp_id               NUMBER;  

  gv_request_id               NUMBER;

  gv_log_seq                  NUMBER := 0;



  gv_bc_start_date            DATE;

  gv_bc_end_date              DATE;



  gv_oracle_db                VARCHAR2(100);



  gv_bc_environment           VARCHAR2(100);



  -- 2025 - KANO

  /*

  gv_bc_ifc                   VARCHAR2(200) := 'AJCL BC Lockbox Interface';

  gv_report_filename          VARCHAR2(100) := 'AJCLBCLBXIR';

  gv_output_filename          VARCHAR2(100) := 'AJCLBCLBXIO';

  */

  -- Se asignan los valores en ejecucion, segun parametro p_journal_batch_name

  gv_bc_ifc                   VARCHAR2(200);

  gv_report_filename          VARCHAR2(100);

  gv_output_filename          VARCHAR2(100);



  gv_journal_batch_name       VARCHAR2(10);

  -- 2025 - KANO



  gv_email                    ajcl_bc_integration_emails.emails%TYPE; 



  gv_file_format              VARCHAR2(4);

  gv_directory_report         all_directories.directory_name%TYPE; 



  gv_jenkins_build_number     VARCHAR2(100);



  -- dbms_lock -----------------------------------------------------------------------------------------------------------------

  gv_process_name             VARCHAR2(200);

  gv_id_lock                  VARCHAR2(200);

  gv_request_status           VARCHAR2(200);

  ge_lock                     EXCEPTION;



  gv_release_status           VARCHAR2(200);

  ge_release                  EXCEPTION; 

  -- dbms_lock -----------------------------------------------------------------------------------------------------------------



  PROCEDURE archive_purge_p ( p_number_of_days         IN   VARCHAR2,

                              p_archive                IN   VARCHAR2,

                              p_jenkins_build_number   IN   VARCHAR2 ); 



  PROCEDURE main_p ( p_bc_environment         IN   VARCHAR2,

                     -- 2025 - KANO

                     p_journal_batch_name     IN   VARCHAR2,

                     -- 2025 - KANO

                     p_gl_date                IN   VARCHAR2,

                     p_jenkins_build_number   IN   VARCHAR2 );



END ajcl_bc_lockbox_pkg;
