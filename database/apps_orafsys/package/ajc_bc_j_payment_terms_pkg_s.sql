CREATE OR REPLACE PACKAGE AJC_BC_J_PAYMENT_TERMS_PKG IS



  gv_user_id                 NUMBER := 0;

  gv_request_id              NUMBER;



  gv_bc_environment          VARCHAR2(100);

  gv_log_seq                 NUMBER := 0;

  gv_bc_ifc                  VARCHAR2(200);



  gv_ifc                     VARCHAR2(100) := 'PAYMENT TERMS';



  gv_company_id              VARCHAR2(200) := '26fb86f1-2b58-ec11-9f08-002248210987'; 

  gv_company_name            VARCHAR2(200) := 'Master Data'; 



  PROCEDURE main_p ( p_bc_environment   IN   VARCHAR2,

                     p_bc_ifc           IN   VARCHAR2,

                     p_request_id       IN   NUMBER,

                     p_log_seq      IN OUT   NUMBER,

                     p_status          OUT   VARCHAR2 );



END AJC_BC_J_PAYMENT_TERMS_PKG;
