CREATE OR REPLACE PACKAGE ajcl_bc_cust_to_oracle_pkg IS

-- Creation: SBANCHIERI 23-AUG-2023

  

  gv_bc_company_name        ajc_bc_companies.bc_company_name%TYPE := 'LOGIS-USA-USD';

  gv_bc_company_id          ajc_bc_companies.bc_company_id%TYPE;  

  gv_org_id                 ajc_bc_companies.org_id%TYPE;

  gv_ar_resp_id             ajc_bc_companies.ar_resp_id%TYPE;



  gv_user_id                NUMBER := 0;

  gv_bc_environment         VARCHAR2(100);

  gv_log_seq                NUMBER := 0;



  gv_request_id             NUMBER;

  gv_ifc                    VARCHAR2(100) := 'CUSTOMERS';



  gv_bc_ifc                 VARCHAR2(200) := 'AJCL BC Customer Interface';

  gv_report_filename        VARCHAR2(100) := 'AJCLBCCIR';

  gv_email                  ajcl_bc_integration_emails.emails%TYPE;  



  -- 20240607

  gv_file_format            VARCHAR2(4); 

  gv_directory_report       all_directories.directory_name%TYPE; 

  gv_jenkins_build_number   VARCHAR2(100);

  gv_refresh_payment_terms  VARCHAR2(1);

  -- 20240607



  PROCEDURE main_p ( p_bc_environment          IN   VARCHAR2,

                     p_refresh_payment_terms   IN   VARCHAR2,

                     p_jenkins_build_number    IN   VARCHAR2 );



END ajcl_bc_cust_to_oracle_pkg;
