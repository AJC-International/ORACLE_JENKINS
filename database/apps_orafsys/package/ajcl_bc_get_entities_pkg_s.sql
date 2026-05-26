PACKAGE ajcl_bc_get_entities_pkg IS
-- Creation: SBANCHIERI 23-AUG-2023

  gv_bc_company_name     VARCHAR2(200);
  gv_bc_company_id       VARCHAR2(200);

  gv_bc_ifc              VARCHAR2(200);
  gv_request_id          NUMBER := 0;
  gv_log_seq             NUMBER; 
  gv_user_id             NUMBER := 0;

  gv_api_records_limit   NUMBER := 20000;
  gv_bc_setup_email      ajcl_bc_integration_emails.emails%TYPE;

  -- Trae Journals a la tabla
  -- ajcl_bc_gl_journals
  PROCEDURE get_journals_p ( p_bc_environment   IN   VARCHAR2,
                             p_bc_ifc           IN   VARCHAR2,
                             p_request_id       IN   NUMBER,
                             p_log_seq      IN OUT   NUMBER,
                             p_status          OUT   VARCHAR2 );                                    

  -- Trae los valores de las dimensiones para cada dimension set entry
  PROCEDURE get_dimension_set_entry_p ( p_bc_environment   IN   VARCHAR2,
                                        p_bc_ifc           IN   VARCHAR2,
                                        p_request_id       IN   NUMBER,
                                        p_log_seq      IN OUT   NUMBER,
                                        p_status          OUT   VARCHAR2 );

  -- Trae Sales Documents a las tablas 
  -- ajcl_bc_posted_sd_headers
  -- ajcl_bc_posted_sd_lines
  PROCEDURE get_sales_documents_p ( p_bc_environment   IN   VARCHAR2,
                                    p_bc_ifc           IN   VARCHAR2,
                                    p_request_id       IN   NUMBER,
                                    p_log_seq      IN OUT   NUMBER,
                                    p_status          OUT   VARCHAR2 );

  -- Trae Cash Rec Jnl a la tabla
  -- ajcl_bc_cash_rec_jnl
  PROCEDURE get_cash_receipts_p ( p_bc_environment   IN   VARCHAR2,
                                  p_bc_ifc           IN   VARCHAR2,
                                  p_request_id       IN   NUMBER,
                                  p_log_seq      IN OUT   NUMBER,
                                  p_status          OUT   VARCHAR2 );

  -- IES
  -- Obtiene de BC los Charge Types, los baja a la tabla ajcl_bc_ies_charge_types
  PROCEDURE get_ies_charge_types_p ( p_bc_environment   IN   VARCHAR2,
                                     p_bc_ifc           IN   VARCHAR2,
                                     p_request_id       IN   NUMBER,
                                     p_log_seq      IN OUT   NUMBER,
                                     p_status          OUT   VARCHAR2 ); 

  -- Obtiene de BC los Business Lines, los baja a la tabla ajcl_bc_ies_business_lines
  PROCEDURE get_ies_business_lines_p ( p_bc_environment   IN   VARCHAR2,
                                       p_bc_ifc           IN   VARCHAR2,
                                       p_request_id       IN   NUMBER,
                                       p_log_seq      IN OUT   NUMBER,
                                       p_status          OUT   VARCHAR2 ); 

  -- Obtiene de BC los IES Items, los baja a la tabla ajcl_bc_ies_items
  PROCEDURE get_ies_items_p ( p_bc_environment   IN   VARCHAR2,
                              p_bc_ifc           IN   VARCHAR2,
                              p_request_id       IN   NUMBER,
                              p_log_seq      IN OUT   NUMBER,
                              p_status          OUT   VARCHAR2 );                                       

  -- Obtiene de BC los IES Country Codes, los baja a la tabla ajcl_bc_ies_country_codes
  PROCEDURE get_ies_country_codes_p ( p_bc_environment   IN   VARCHAR2,
                                      p_bc_ifc           IN   VARCHAR2,
                                      p_request_id       IN   NUMBER,
                                      p_log_seq      IN OUT   NUMBER,
                                      p_status          OUT   VARCHAR2 );       

  -- CSA
  -- Obtiene de BC los CSA Station Id, los baja a la tabla ajcl_bc_csa_station_id
  PROCEDURE get_csa_station_id_p ( p_bc_environment   IN   VARCHAR2,
                                   p_bc_ifc           IN   VARCHAR2,
                                   p_request_id       IN   NUMBER,
                                   p_log_seq      IN OUT   NUMBER,
                                   p_status          OUT   VARCHAR2 );      

  -- Obtiene los usuarios que tienen permiso para sincronizar Vendors y Customers de INC y LOG de BC a Oracle
  PROCEDURE get_vend_cust_ifc_users_p ( p_bc_environment   IN   VARCHAR2,
                                        p_bc_ifc           IN   VARCHAR2,
                                        p_request_id       IN   NUMBER,
                                        p_log_seq      IN OUT   NUMBER,
                                        p_status          OUT   VARCHAR2 ); 

  -- Obtiene de la page de BC Logistic Integration Source los registros para la tabla ajcl_bc_cust_xref -- copia de la tabla ajc_bplus_cust_xref
  PROCEDURE get_cust_xref_p ( p_bc_environment   IN   VARCHAR2,
                              p_bc_ifc           IN   VARCHAR2,
                              p_request_id       IN   NUMBER,
                              p_log_seq      IN OUT   NUMBER,
                              p_status          OUT   VARCHAR2 ); 

  -- Obtiene de la page de BC AJCL Truist Lockbox Parameters los parametros de conexion para Lockbox de Truist                           
  PROCEDURE get_truist_lockbox_params_p ( p_bc_environment   IN   VARCHAR2,
                                          p_bc_ifc           IN   VARCHAR2,
                                          p_request_id       IN   NUMBER,
                                          p_log_seq      IN OUT   NUMBER,
                                          p_status          OUT   VARCHAR2 );                              

  PROCEDURE check_logistics_setup_p ( p_bc_environment      IN   VARCHAR2,
                                      p_status             OUT   VARCHAR2 );

  PROCEDURE get_bc_allow_posting_from_to_p ( p_bc_environment   IN   VARCHAR2,
                                             p_bc_company_id    IN   VARCHAR2,
                                             -- p_module           IN   VARCHAR2,
                                             p_bc_start_date   OUT   DATE,
                                             p_bc_end_date     OUT   DATE,
                                             p_status          OUT   VARCHAR2,
                                             p_error_msg       OUT   VARCHAR2 );                                     

  -- Obtiene los vendors creados en LOGIS
  PROCEDURE get_bc_vendors_p ( p_bc_environment   IN   VARCHAR2,
                               p_bc_ifc           IN   VARCHAR2,
                               p_request_id       IN   NUMBER,
                               p_log_seq      IN OUT   NUMBER,
                               p_status          OUT   VARCHAR2 ); 

  -- Obtiene los customers creados en LOGIS
  PROCEDURE get_bc_customers_p ( p_bc_environment   IN   VARCHAR2,
                                 p_bc_ifc           IN   VARCHAR2,
                                 p_request_id       IN   NUMBER,
                                 p_log_seq      IN OUT   NUMBER,
                                 p_status          OUT   VARCHAR2 );                                

END ajcl_bc_get_entities_pkg;
