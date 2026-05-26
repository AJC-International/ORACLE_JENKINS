CREATE OR REPLACE PACKAGE ajcl_bc_worksheets_pkg IS

  

  gv_request_id        NUMBER;



  gv_bc_ifc            VARCHAR2(200);

  gv_log_seq           NUMBER;



  -- dbms_lock -----------------------------------------------------------------------------------------------------------------

  gv_process_name      VARCHAR2(200);

  gv_id_lock           VARCHAR2(200);

  gv_request_status    VARCHAR2(200);

  ge_lock              EXCEPTION;



  gv_release_status    VARCHAR2(200);

  ge_release           EXCEPTION; 

  -- dbms_lock -----------------------------------------------------------------------------------------------------------------



  FUNCTION insert_p ( p_ws_ies_num       IN    VARCHAR2,

                      p_bc_environment   IN    VARCHAR2 ) RETURN NUMBER;



  PROCEDURE main_p ( p_bc_environment     IN   VARCHAR2,

                     p_bc_company_id      IN   VARCHAR2,

                     p_bc_ifc             IN   VARCHAR2,

                     p_request_id         IN   NUMBER,

                     p_log_seq        IN OUT   NUMBER,

                     p_status            OUT   VARCHAR2 );



END ajcl_bc_worksheets_pkg;
