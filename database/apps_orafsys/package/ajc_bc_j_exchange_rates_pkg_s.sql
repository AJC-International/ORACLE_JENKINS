CREATE OR REPLACE PACKAGE AJC_BC_J_EXCHANGE_RATES_PKG IS



  gv_bc_environment         VARCHAR2(100);

  gv_user_id                NUMBER := 0;

  gv_request_id             NUMBER;

  gv_date                   DATE;



  gv_log_seq                NUMBER := 0;



  gv_bc_ifc                 VARCHAR2(200) := 'AJC BC Exchange Rates Interface';

  gv_report_filename        VARCHAR2(100) := 'AJCBCERIR';



  gv_email                  ajc_bc_integration_emails.emails%TYPE; 

  gv_file_format            VARCHAR2(4); 

  gv_jenkins_build_number   VARCHAR2(100);

  gv_directory_report       all_directories.directory_name%TYPE; 



  PROCEDURE main_p ( p_bc_environment         IN   VARCHAR2,

                     p_date                   IN   VARCHAR2,

                     p_jenkins_build_number   IN   VARCHAR2 );                     



END AJC_BC_J_EXCHANGE_RATES_PKG;
