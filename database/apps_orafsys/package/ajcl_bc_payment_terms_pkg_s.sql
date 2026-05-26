CREATE OR REPLACE PACKAGE ajcl_bc_payment_terms_pkg IS

-- Creation: SBANCHIERI 23-AUG-2023



  gv_user_id          NUMBER := 0;

  gv_org_id           NUMBER;

  gv_request_id       NUMBER;

  gv_log_seq          NUMBER := 0;



  gv_bc_environment   VARCHAR2(200);



  gv_ifc              VARCHAR2(100) := 'PAYMENT TERMS';

  gv_bc_ifc           VARCHAR2(100);



  gv_company_id       VARCHAR2(200); 

  gv_company_name     VARCHAR2(200); 



  PROCEDURE main_p ( p_bc_environment   IN       VARCHAR2,

                     p_bc_ifc           IN       VARCHAR2,

                     p_request_id       IN       NUMBER,

                     p_log_seq          IN OUT   NUMBER,

                     p_company_id       IN       VARCHAR2,

                     p_company_name     IN       VARCHAR2 );



END ajcl_bc_payment_terms_pkg;
