CREATE OR REPLACE PACKAGE ajcl_bc_trv_pkg IS

-- Creation: SBANCHIERI 23-AUG-2023 



  gv_bc_company_name             ajc_bc_companies.bc_company_name%TYPE := 'LOGIS-USA-USD';

  gv_bc_company_id               ajc_bc_companies.bc_company_id%TYPE;  

  gv_set_of_books_id             ajc_bc_companies.set_of_books_id%TYPE;  

  gv_org_id                      ajc_bc_companies.org_id%TYPE;



  gv_bc_environment              VARCHAR2(100);

  gv_lines_per_json              NUMBER := 100;

  gv_user_id                     NUMBER := 0;

  gv_log_seq                     NUMBER := 0;

  gv_run_id                      NUMBER;



  gv_request_id                  NUMBER;



  gv_bc_start_date               DATE;

  gv_bc_end_date                 DATE;

  gv_only_reprocess              VARCHAR2(1) := 'N';



  gv_bc_ifc                      VARCHAR2(200) := 'AJCL BC TRV Process Interface';



  gv_bc_gl_ifc                   VARCHAR2(200) := 'AJCL BC TRV Process GL Interface';

  gv_gl_report_filename          VARCHAR2(100) := 'AJCLBCTRVPGLIR';

  gv_gl_email                    ajcl_bc_integration_emails.emails%TYPE;



  gv_bc_ar_ifc                   VARCHAR2(200) := 'AJCL BC TRV Process AR Interface';

  gv_ar_report_filename          VARCHAR2(100) := 'AJCLBCTRVPARIR';

  gv_ar_email                    ajcl_bc_integration_emails.emails%TYPE;



  gv_output_filename             VARCHAR2(100) := 'AJCLBCTRVPIO';



  gv_journal_template_name       VARCHAR2(30) := 'GENERAL';

  gv_journal_batch_name          VARCHAR2(30) := 'DAILYINT';



  gv_file_format                 VARCHAR2(4);

  gv_directory_report            all_directories.directory_name%TYPE; 

  gv_directory_output            all_directories.directory_name%TYPE; 

  -- 20240905 gv_check_integrations_source   VARCHAR2(1);

  gv_jenkins_build_number        VARCHAR2(100);



  -- dbms_lock -----------------------------------------------------------------------------------------------------------------

  gv_gl_process_name             VARCHAR2(200);

  gv_gl_request_status           VARCHAR2(200);

  gv_gl_id_lock                  VARCHAR2(200);

  ge_gl_lock                     EXCEPTION;

  gv_gl_release_status           VARCHAR2(200);

  ge_gl_release                  EXCEPTION;  



  gv_ar_process_name             VARCHAR2(200);

  gv_ar_request_status           VARCHAR2(200);

  gv_ar_id_lock                  VARCHAR2(200);

  ge_ar_lock                     EXCEPTION;

  gv_ar_release_status           VARCHAR2(200);

  ge_ar_release                  EXCEPTION; 

  -- dbms_lock -----------------------------------------------------------------------------------------------------------------



  PROCEDURE main_p ( p_bc_environment              IN   VARCHAR2,

                     -- 20240905 p_check_integrations_source   IN   VARCHAR2,

                     p_jenkins_build_number        IN   VARCHAR2 ); 



END ajcl_bc_trv_pkg;
