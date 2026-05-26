CREATE OR REPLACE PACKAGE ajcl_bc_ies_gl_pkg IS

-- Creation: SBANCHIERI 23-AUG-2023



  gv_bc_company_name         ajc_bc_companies.bc_company_name%TYPE := 'LOGIS-USA-USD';

  gv_bc_company_id           ajc_bc_companies.bc_company_id%TYPE;  

  gv_set_of_books_id         ajc_bc_companies.set_of_books_id%TYPE;  

  gv_org_id                  ajc_bc_companies.org_id%TYPE;



  gv_lines_per_json          NUMBER := 100;

  gv_log_seq                 NUMBER := 0;



  gv_bc_environment          VARCHAR2(100);

  gv_gl_date                 DATE;

  gv_if_errors_stop          VARCHAR2(1);



  gv_request_id              fnd_concurrent_requests.request_id%TYPE;



  gv_bc_ifc                  VARCHAR2(200) := 'AJCL BC IES GL Interface';

  gv_report_filename         VARCHAR2(100) := 'AJCLBCIESGLIR';

  gv_output_filename         VARCHAR2(100) := 'AJCLBCIESGLIO';

  gv_email                   ajcl_bc_integration_emails.emails%TYPE;  



  gv_user_id                 fnd_user.user_id%TYPE := 0;



  gv_journal_template_name   ajcl_bc_ies_gl_lines.journaltemplatename%TYPE := 'GENERAL';

  gv_journal_batch_name      ajcl_bc_ies_gl_lines.journalbatchname%TYPE := 'DAILYINT';



  gv_file_format             VARCHAR2(4);

  gv_directory_report        all_directories.directory_name%TYPE; 

  gv_directory_output        all_directories.directory_name%TYPE; 

  gv_jenkins_build_number    VARCHAR2(100);



  -- dbms_lock -----------------------------------------------------------------------------------------------------------------

  gv_gl_process_name         VARCHAR2(200);

  gv_gl_request_status       VARCHAR2(200);

  gv_gl_id_lock              VARCHAR2(200);

  ge_gl_lock                 EXCEPTION;

  gv_gl_release_status       VARCHAR2(200);

  ge_gl_release              EXCEPTION;  

  -- dbms_lock -----------------------------------------------------------------------------------------------------------------



  PROCEDURE main_p ( p_bc_environment         IN   VARCHAR2,

                     p_gl_date                IN   VARCHAR2,

                     p_if_errors_stop         IN   VARCHAR2,

                     p_jenkins_build_number   IN   VARCHAR2 );



END ajcl_bc_ies_gl_pkg;
