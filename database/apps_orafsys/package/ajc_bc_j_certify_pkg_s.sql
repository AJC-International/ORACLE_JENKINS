CREATE OR REPLACE PACKAGE              ajc_bc_j_certify_pkg AS

  

  gv_bc_environment          VARCHAR2(100);

  gv_jenkins_build_number NUMBER;

  gv_gl_date                 DATE;

  

  gv_request_id              fnd_concurrent_requests.request_id%TYPE;

  gv_set_of_books_id         hr_operating_units.set_of_books_id%TYPE;

  gv_set_of_books_name      gl_sets_of_books.name%TYPE;

  gv_org_id                  hr_operating_units.organization_id%TYPE;

  gv_bc_company_name        ajc_bc_companies.bc_company_name%TYPE := 'FOODS-USA-USD';

  gv_bc_company_id           ajc_bc_companies.bc_company_id%TYPE;

  gv_bc_ifc                  VARCHAR2(200) := 'AJC BC Certify Interface';

  gv_bc_ifc_ftp             VARCHAR2(200) := 'AJC BC Certify FTP';

  gv_bc_ifc_loader        VARCHAR2(200) := 'AJC BC Certify Loader';

  gv_report_filename         VARCHAR2(100) := 'AJCBCCERINT';

  gv_log_seq                 NUMBER := 0;

  

  gv_email                   ajc_bc_integration_emails.emails%TYPE;  

  gv_support_email                   ajc_bc_integration_emails.emails%TYPE;    

  gv_user_id                 fnd_user.user_id%TYPE := 0;

  -- 20230414 gv_job_object_id     NUMBER := 70004; -- Purchase Document

  gv_file_format             VARCHAR2(4);

  gv_directory_report        all_directories.directory_name%TYPE;

  

  -- dbms_lock -----------------------------------------------------------------------------------------------------------------

  gv_process_name         VARCHAR2(200);

  gv_request_status       VARCHAR2(200);

  gv_id_lock              VARCHAR2(200);

  ge_lock                 EXCEPTION;

  gv_release_status       VARCHAR2(200);

  ge_release              EXCEPTION;  

  -- dbms_lock -----------------------------------------------------------------------------------------------------------------  

-- MB REVISAR ELIMINAR

/*                               

  PROCEDURE ajc_ftp_expense_rpt ( p_file_prefix   IN   VARCHAR2,

                                      p_status       OUT   VARCHAR2 ); 



  PROCEDURE ajc_load_expense_rpt_int (  p_file_name   IN   VARCHAR2,

                                                                p_status       OUT   VARCHAR2 ); 

*/

  PROCEDURE expense_report_interface_p (p_gl_date                       IN   DATE,

                                                             p_american_express_supplier     IN   VARCHAR2,

                                                             p_travel_advance_account_num    IN   VARCHAR2,

                                                             p_file_date IN VARCHAR2,                                                             

                                                             p_status                       OUT   VARCHAR2 );



  PROCEDURE main_p (p_bc_environment   IN   VARCHAR2,

                                p_gl_date IN VARCHAR2,

                                p_jenkins_build_number   IN   VARCHAR2,

                                p_file_date   IN VARCHAR2);



END ajc_bc_j_certify_pkg;

