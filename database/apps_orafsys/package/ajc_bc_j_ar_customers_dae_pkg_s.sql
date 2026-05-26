PACKAGE AJC_BC_J_AR_CUSTOMERS_DAE_PKG IS
  
  gv_bc_environment         VARCHAR2(100);
  gv_request_id             NUMBER;
  gv_user_id                NUMBER := 0;
  gv_org_id                 NUMBER;
  gv_ifc                    VARCHAR2(100) := 'DAE';

  gv_file_format            VARCHAR2(4); 
  gv_directory_report       all_directories.directory_name%TYPE; 
  gv_jenkins_build_number   VARCHAR2(100);

  gv_log_seq                NUMBER := 0;
  gv_bc_ifc                 VARCHAR2(200) := 'AJC BC AR Customers DAE Interface';
  gv_report_filename        VARCHAR2(100) := 'AJCBCARCDAEIR';
  gv_email                  ajc_bc_integration_emails.emails%TYPE;  

  gv_company_id             VARCHAR2(200) := '26fb86f1-2b58-ec11-9f08-002248210987'; 
  gv_company_name           VARCHAR2(200) := 'Master Data';

  PROCEDURE main_p ( p_bc_environment           IN   VARCHAR2,
                     p_jenkins_build_number     IN   VARCHAR2 );                      

END AJC_BC_J_AR_CUSTOMERS_DAE_PKG; 
