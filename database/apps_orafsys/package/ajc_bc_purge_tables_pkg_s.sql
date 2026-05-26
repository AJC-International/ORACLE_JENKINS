PACKAGE ajc_bc_purge_tables_pkg IS
-- SBANCHIERI - FEB-2025
   
  gv_company                VARCHAR2(200);
  gv_oracle_db              VARCHAR2(200);
  gv_keep_x_days            NUMBER;

  gv_log_seq                NUMBER := 0;
  gv_request_id             NUMBER;
  gv_bc_ifc                 VARCHAR2(200);

  gv_preview                VARCHAR2(1);
  gv_jenkins_build_number   VARCHAR2(100);

  gv_file_format            VARCHAR2(4) := 'XLSX';
  gv_directory_report       all_directories.directory_name%TYPE;   

  gv_output_filename        VARCHAR2(100) := 'BCPURGETABLESO_';
  gv_report_filename        VARCHAR2(100) := 'BCPURGETABLESR_';

  -- Se ejecuta desde el job de Jenkins AJC BC Purge CLOB
  PROCEDURE foods_main_p ( p_preview                IN   VARCHAR2,
                           p_jenkins_build_number   IN   VARCHAR2 );

  -- Se ejecuta desde el job de Jenkins AJCL BC Purge CLOB
  PROCEDURE logis_main_p ( p_preview                IN   VARCHAR2,
                           p_jenkins_build_number   IN   VARCHAR2 );

END ajc_bc_purge_tables_pkg;
