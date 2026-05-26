CREATE OR REPLACE PACKAGE ajcl_bc_ws_utils_pkg AS



  gv_bc_oracle_diff_hours    NUMBER;



  FUNCTION get_parameter_f ( p_parameter_code   IN   VARCHAR2 ) RETURN VARCHAR2;



  FUNCTION get_api_f ( p_entity      IN   VARCHAR2,

                       p_subentity   IN   VARCHAR2,

                       p_method      IN   VARCHAR2 ) RETURN VARCHAR2;



  FUNCTION get_lock_process_name_f ( p_integration   IN   VARCHAR2 ) RETURN VARCHAR2;



  FUNCTION get_object_id_f ( p_integration   IN   VARCHAR2 ) RETURN NUMBER;



  FUNCTION get_base_custom_url_f ( p_bc_environment   IN   VARCHAR2,

                                   p_entity           IN   VARCHAR2,

                                   p_subentity        IN   VARCHAR2,

                                   p_method           IN   VARCHAR2,

                                   p_company_id       IN   VARCHAR2 ) RETURN VARCHAR2;



  FUNCTION get_base_custom_batch_url_f ( p_bc_environment   IN   VARCHAR2,

                                         p_entity           IN   VARCHAR2,

                                         p_subentity        IN   VARCHAR2,

                                         p_method           IN   VARCHAR2,

                                         p_company_id       IN   VARCHAR2 ) RETURN VARCHAR2;



  FUNCTION get_base_inecta_url_f ( p_bc_environment   IN   VARCHAR2,

                                   p_entity           IN   VARCHAR2,

                                   p_subentity        IN   VARCHAR2,

                                   p_method           IN   VARCHAR2,

                                   p_company_id       IN   VARCHAR2 ) RETURN VARCHAR2;



  FUNCTION get_etag_f ( p_clob_result   CLOB ) RETURN VARCHAR2;



  FUNCTION get_base_standard_url_f ( p_bc_environment   IN   VARCHAR2,

                                     p_api              IN   VARCHAR2,

                                     p_company_id       IN   VARCHAR2 ) RETURN VARCHAR2;



  FUNCTION run_job_queue_f ( p_bc_environment   IN   VARCHAR2,

                             p_company_id       IN   VARCHAR2,

                             p_object_id        IN   NUMBER ) RETURN CLOB;



  FUNCTION get_bc_clob_result_f ( p_url   IN   VARCHAR2 ) RETURN CLOB;



  FUNCTION patch_post_bc_row_f ( p_url                     IN   VARCHAR2

                                ,p_request_header_name1    IN   VARCHAR2

                                ,p_request_header_value1   IN   VARCHAR2

                                ,p_request_header_name2    IN   VARCHAR2

                                ,p_request_header_value2   IN   VARCHAR2

                                ,p_http_method             IN   VARCHAR2

                                ,p_body                    IN   CLOB ) RETURN CLOB;



  FUNCTION delete_bc_row_f ( p_url   IN   VARCHAR2 ) RETURN CLOB;



  FUNCTION get_ifc_last_processed_date_f ( p_bc_environment   IN   VARCHAR2,

                                           p_ifc              IN   VARCHAR2 ) RETURN TIMESTAMP;



  FUNCTION get_bc_last_processed_date_f ( p_last_processed_date   IN   TIMESTAMP ) RETURN TIMESTAMP;



  PROCEDURE upd_ifc_last_processed_date_p ( p_bc_environment        IN   VARCHAR2,

                                            p_ifc                   IN   VARCHAR2,

                                            p_request_id            IN   NUMBER,

                                            p_last_processed_date   IN   TIMESTAMP );



  FUNCTION check_vendor_exists_bc_p ( p_bc_environment   IN   VARCHAR2,

                                      p_company_id       IN   VARCHAR2,

                                      p_no               IN   VARCHAR2 ) RETURN VARCHAR2;



  FUNCTION check_customer_exists_bc_p ( p_bc_environment   IN   VARCHAR2,

                                        p_company_id       IN   VARCHAR2,

                                        p_no               IN   VARCHAR2 ) RETURN VARCHAR2;



END ajcl_bc_ws_utils_pkg;
