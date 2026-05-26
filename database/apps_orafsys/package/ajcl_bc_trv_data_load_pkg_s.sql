CREATE OR REPLACE PACKAGE ajcl_bc_trv_data_load_pkg IS

-- Creation: SBANCHIERI 25-JUN-2024

  

  gv_request_id                  NUMBER;

  gv_bc_ifc                      VARCHAR2(200) := 'AJCL BC TRV Data Load';

  gv_jenkins_build_number        VARCHAR2(100);

  gv_file_format                 VARCHAR2(4);



  gv_oracle_db                   VARCHAR2(100);



  gv_output_filename             VARCHAR2(100) := 'AJCLBCTRVDLO';

  gv_email                       ajcl_bc_integration_emails.emails%TYPE;



  gv_directory_output            all_directories.directory_name%TYPE;



  gv_user_id                     NUMBER := 0;

  gv_log_seq                     NUMBER := 0;

  gv_run_id                      NUMBER;



  PROCEDURE main_p ( p_jenkins_build_number   IN   VARCHAR2 );



END ajcl_bc_trv_data_load_pkg;  
