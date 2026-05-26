CREATE OR REPLACE PACKAGE AJC_BC_J_VENDORS_TO_ORACLE_PKG IS

  

  gv_user_id                NUMBER := 0;



  gv_request_id             NUMBER;

  gv_org_id                 NUMBER;



  gv_set_of_books_id        NUMBER := 1; 

  gv_ap_resp_id             ajc_bc_companies.ap_resp_id%TYPE;



  gv_company_id             VARCHAR2(200) := '26fb86f1-2b58-ec11-9f08-002248210987'; -- Master Data



  gv_ifc                    VARCHAR2(100) := 'VENDORS';



  gv_bc_environment         VARCHAR2(100);

  gv_file_format            VARCHAR2(4); 

  gv_directory_report       all_directories.directory_name%TYPE; 

  gv_jenkins_build_number   VARCHAR2(100);

  gv_process_multiple_sites VARCHAR2(1);



  gv_log_seq                NUMBER := 0;

  gv_bc_ifc                 VARCHAR2(200) := 'AJC BC Vendors Interface';

  gv_report_filename        VARCHAR2(100) := 'AJCBCVIR';

  gv_email                  ajc_bc_integration_emails.emails%TYPE;  



  gv_bc_support_email       ajc_bc_integration_emails.emails%TYPE;  



  PROCEDURE main_p ( p_bc_environment           IN   VARCHAR2,

                     p_jenkins_build_number     IN   VARCHAR2 );                                    



END AJC_BC_J_VENDORS_TO_ORACLE_PKG;
