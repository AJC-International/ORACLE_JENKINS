PACKAGE ajc_bc_customers_to_oracle_pkg IS
  
  gv_user_id        NUMBER := fnd_global.user_id;
  gv_org_id         NUMBER := fnd_global.org_id;
  gv_request_id     NUMBER := fnd_global.conc_request_id;
  gv_ifc            VARCHAR2(100) := 'CUSTOMERS';

  gv_company_id     VARCHAR2(200) := '26fb86f1-2b58-ec11-9f08-002248210987'; 
  gv_company_name   VARCHAR2(200) := 'Master Data'; 

  PROCEDURE customers_p ( retcode                  OUT   NUMBER,
                          errbuf                   OUT   VARCHAR2,
                          p_bc_environment          IN   VARCHAR2,
                          p_refresh_payment_terms   IN   VARCHAR2 );

END ajc_bc_customers_to_oracle_pkg;
