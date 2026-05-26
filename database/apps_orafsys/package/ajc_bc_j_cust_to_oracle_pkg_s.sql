PACKAGE AJC_BC_J_CUST_TO_ORACLE_PKG IS

  gv_user_id                NUMBER := 0;
  gv_org_id                 ajc_bc_companies.org_id%TYPE;
  gv_request_id             NUMBER;
  gv_ar_resp_id             ajc_bc_companies.ar_resp_id%TYPE;

  gv_bc_environment         VARCHAR2(100);
  gv_log_seq                NUMBER := 0;
  gv_bc_ifc                 VARCHAR2(200) := 'AJC BC Customers Interface';
  gv_report_filename        VARCHAR2(100) := 'AJCBCCIR';
  gv_email                  ajc_bc_integration_emails.emails%TYPE;  

  gv_bc_support_email       ajc_bc_integration_emails.emails%TYPE; 

  gv_file_format            VARCHAR2(4); 
  gv_directory_report       all_directories.directory_name%TYPE; 
  gv_jenkins_build_number   VARCHAR2(100);

  gv_ifc                    VARCHAR2(100) := 'CUSTOMERS';

  gv_company_id             VARCHAR2(200) := '26fb86f1-2b58-ec11-9f08-002248210987'; 
  gv_company_name           VARCHAR2(200) := 'Master Data'; 

  PROCEDURE main_p ( p_bc_environment          IN   VARCHAR2,
                     p_jenkins_build_number    IN   VARCHAR2 );

END AJC_BC_J_CUST_TO_ORACLE_PKG;
