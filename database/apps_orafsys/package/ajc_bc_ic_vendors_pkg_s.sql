PACKAGE ajc_bc_ic_vendors_pkg AS

  gv_company_id             VARCHAR2(200) := '26fb86f1-2b58-ec11-9f08-002248210987'; 
  gv_company_name           VARCHAR2(200) := 'Master Data';

  gv_log_seq                NUMBER := 0;
  gv_request_id             NUMBER;
  gv_bc_ifc                 VARCHAR2(200) := 'AJC BC Intercompany Vendors Interface';
  gv_jenkins_build_number   VARCHAR2(100);

  PROCEDURE main_p ( p_bc_environment         IN   VARCHAR2,
                     p_jenkins_build_number   IN   VARCHAR2 );

END ajc_bc_ic_vendors_pkg;
