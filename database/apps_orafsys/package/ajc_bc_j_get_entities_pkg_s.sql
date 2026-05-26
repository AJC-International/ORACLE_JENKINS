PACKAGE ajc_bc_j_get_entities_pkg IS
-- Creation: SBANCHIERI 25-APR-2025
  
  gv_log_seq             NUMBER; 
  gv_bc_ifc              VARCHAR2(200);
  gv_request_id          NUMBER;

  gv_company_id          VARCHAR2(200) := '26fb86f1-2b58-ec11-9f08-002248210987'; -- Master Data

  -- Obtiene los usuarios que tienen permiso para sincronizar Vendors y Customers de INC y LOG de BC a Oracle
  PROCEDURE get_vend_cust_ifc_users_p ( p_bc_environment   IN   VARCHAR2,
                                        p_bc_ifc           IN   VARCHAR2,
                                        p_request_id       IN   NUMBER,
                                        p_log_seq      IN OUT   NUMBER,
                                        p_status          OUT   VARCHAR2 ); 

END ajc_bc_j_get_entities_pkg;                                        
