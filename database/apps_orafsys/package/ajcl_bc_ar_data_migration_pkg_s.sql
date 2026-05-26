PACKAGE ajcl_bc_ar_data_migration_pkg IS
  
  gv_bc_environment          VARCHAR2(100);
  -- gv_mail                    VARCHAR2(200) := 'sbanchieri@gmail.com';
  gv_mail                    VARCHAR2(200) := 'sbanchieri@gmail.com,pablobonadeo@gmail.com';
  gv_source                  VARCHAR2(20) := 'DATA MIGRATION';

  gv_bc_company_name         ajc_bc_companies.bc_company_name%TYPE := 'LOGIS-USA-USD';
  gv_bc_company_id           ajc_bc_companies.bc_company_id%TYPE;  
  gv_set_of_books_id         ajc_bc_companies.set_of_books_id%TYPE;  
  gv_org_id                  ajc_bc_companies.org_id%TYPE;

  gv_user_id                 NUMBER := 0;
  gv_request_id              NUMBER;
  gv_seconds_to_wait         NUMBER := 20;
  gv_jenkins_build_number    VARCHAR2(100);

  gv_file_format             VARCHAR2(4) := 'XLSX';
  gv_directory_report        all_directories.directory_name%TYPE; 

  gv_log_seq                 NUMBER := 0;

  gv_period_name             gl_periods.period_name%TYPE;  

  gv_oracle_db               VARCHAR2(100);
  gv_gl_date                 DATE;
  gv_migration_type          VARCHAR2(200);
  gv_export_type             VARCHAR2(200);

  gv_bc_ifc                  VARCHAR2(200) := 'AJCL BC Receivables Data Migration';
  gv_report_filename         VARCHAR2(100) := 'AJCLBCARDM';

  gv_resp_id                 NUMBER;
  gv_trx_num_prefix          VARCHAR2(200);
  gv_trx_num_type            VARCHAR2(20);

  PROCEDURE main_p ( p_bc_environment         IN   VARCHAR2,
                     p_gl_date                IN   VARCHAR2,
                     p_trx_num_prefix         IN   VARCHAR2,
                     p_trx_num_type           IN   VARCHAR2,
                     p_export_type            IN   VARCHAR2,
                     p_migration_type         IN   VARCHAR2,
                     p_jenkins_build_number   IN   VARCHAR2 );

END ajcl_bc_ar_data_migration_pkg;
