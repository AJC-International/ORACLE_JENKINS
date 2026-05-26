CREATE OR REPLACE PACKAGE ajc_bc_account_dim_pkg AS

  

  gv_request_id     NUMBER := fnd_global.conc_request_id;



  gv_company_id     VARCHAR2(200) := '26fb86f1-2b58-ec11-9f08-002248210987'; 

  gv_company_name   VARCHAR2(200) := 'Master Data';



  PROCEDURE main_p ( retcode            OUT   NUMBER,

                     errbuf             OUT   VARCHAR2,

                     p_bc_environment    IN   VARCHAR2 );



  FUNCTION account_dim_required ( p_account     IN   VARCHAR2,

                                  p_dimension   IN   VARCHAR2,

                                  p_value       IN   VARCHAR2 ) RETURN VARCHAR2;



  PROCEDURE caller_p ( p_bc_environment   IN   VARCHAR2 );



END ajc_bc_account_dim_pkg;
