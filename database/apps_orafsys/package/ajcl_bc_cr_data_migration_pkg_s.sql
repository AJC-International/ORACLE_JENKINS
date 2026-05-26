PACKAGE ajcl_bc_cr_data_migration_pkg IS

  gv_bc_environment          VARCHAR2(100);
  -- gv_mail                    VARCHAR2(200) := 'sbanchieri@gmail.com';
  gv_mail                    VARCHAR2(200) := 'sbanchieri@gmail.com,pablobonadeo@gmail.com,aguslugea@gmail.com';

  gv_bc_company_name         ajc_bc_companies.bc_company_name%TYPE := 'LOGIS-USA-USD';
  gv_bc_company_id           ajc_bc_companies.bc_company_id%TYPE;  
  gv_org_id                  ajc_bc_companies.org_id%TYPE;

  gv_user_id                 NUMBER := 0;
  gv_request_id              NUMBER;
  gv_jenkins_build_number    VARCHAR2(100);

  gv_file_format             VARCHAR2(4) := 'XLSX';
  gv_directory_report        all_directories.directory_name%TYPE; 

  gv_log_seq                 NUMBER := 0;

  gv_gl_date                 DATE;
  gv_oracle_db               VARCHAR2(100);

  gv_bc_ifc                  VARCHAR2(200) := 'AJCL BC Receipts Data Migration';
  gv_report_filename         VARCHAR2(100) := 'AJCLBCRDM';

  gv_unidentified_no         VARCHAR2(20) := '998021';
  gv_unidentified_name       VARCHAR2(20) := 'UNIDENTIFIED';

  gv_receipt_num_prefix      VARCHAR2(200);

  PROCEDURE main_p ( p_bc_environment         IN    VARCHAR2,
                     p_gl_date                IN    VARCHAR2,
                     p_receipt_num_prefix     IN    VARCHAR2,
                     p_jenkins_build_number   IN    VARCHAR2 );

END ajcl_bc_cr_data_migration_pkg;                    
