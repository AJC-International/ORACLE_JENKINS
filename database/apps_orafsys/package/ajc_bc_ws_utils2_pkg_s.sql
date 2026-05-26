PACKAGE ajc_bc_ws_utils2_pkg AS

  gv_bc_oracle_diff_hours    NUMBER;

  FUNCTION get_parameter_f ( p_parameter_code   IN   VARCHAR2 ) RETURN VARCHAR2;

  FUNCTION get_api_f ( p_entity      IN   VARCHAR2,
                       p_subentity   IN   VARCHAR2,
                       p_method      IN   VARCHAR2 ) RETURN VARCHAR2;

  FUNCTION get_emails_f ( p_integration   IN   VARCHAR2 ) RETURN VARCHAR2;

  FUNCTION get_object_id_f ( p_integration   IN   VARCHAR2 ) RETURN NUMBER;

  FUNCTION get_base_inecta_url_f ( p_environment   IN   VARCHAR2,
                                   p_company_id    IN   VARCHAR2 ) RETURN VARCHAR2;

  FUNCTION get_base_standard_url_f ( p_environment   IN   VARCHAR2,
                                     p_api           IN   VARCHAR2,
                                     p_company_id    IN   VARCHAR2 ) RETURN VARCHAR2; 

  FUNCTION get_base_ajc_url_f ( p_environment   IN   VARCHAR2,
                                p_company       IN   VARCHAR2 ) RETURN VARCHAR2;

  -- 20230303
  FUNCTION get_base_ajc_url_v2_f ( p_environment   IN   VARCHAR2,
                                   p_company_id    IN   VARCHAR2 ) RETURN VARCHAR2;                                
  -- 20230303

  -- Ejecuta job con user y pass          
  -- 20220926 - Deprecated
  /*
  FUNCTION run_job_queue_f ( p_environment          IN   VARCHAR2
                            ,p_company_id           IN   VARCHAR2
                            ,p_object_id            IN   NUMBER ) RETURN CLOB;
  -- 20220926 - Deprecated
  */

  -- Ejecuta job con token
  -- 20220926 - Deprecated
  /*
  FUNCTION run_job_queue_token_f ( p_environment          IN   VARCHAR2
                                  ,p_company_id           IN   VARCHAR2
                                  ,p_object_id            IN   NUMBER ) RETURN CLOB;   
  */

  -- 20220804                                
  FUNCTION run_job_queue_token_v2_f ( p_environment          IN   VARCHAR2
                                     ,p_company_id           IN   VARCHAR2
                                     ,p_object_id            IN   NUMBER
                                     ,p_seconds_to_wait      IN   NUMBER DEFAULT 10 ) RETURN CLOB;                                

  PROCEDURE get_bc_company_id_f ( p_org_id            IN   NUMBER,
                                  p_company_number    IN   VARCHAR2,
                                  p_set_of_books_id   IN   NUMBER,
                                  p_bc_company_id    OUT   VARCHAR2,
                                  p_status           OUT   VARCHAR2 );

  FUNCTION get_bc_clob_result_f ( p_url   IN   VARCHAR2 ) RETURN CLOB;

  FUNCTION patch_post_bc_row_f ( p_url                     IN   VARCHAR2
                                ,p_request_header_name1    IN   VARCHAR2
                                ,p_request_header_value1   IN   VARCHAR2
                                ,p_request_header_name2    IN   VARCHAR2
                                ,p_request_header_value2   IN   VARCHAR2
                                ,p_http_method             IN   VARCHAR2
                                ,p_body                    IN   VARCHAR2 ) RETURN CLOB;

  FUNCTION patch_post_bc_row_job_f ( p_url                     IN   VARCHAR2
                                    ,p_request_header_name1    IN   VARCHAR2
                                    ,p_request_header_value1   IN   VARCHAR2
                                    ,p_request_header_name2    IN   VARCHAR2
                                    ,p_request_header_value2   IN   VARCHAR2
                                    ,p_http_method             IN   VARCHAR2
                                    ,p_body                    IN   VARCHAR2 ) RETURN CLOB;                                

  FUNCTION delete_bc_row_f ( p_url   IN   VARCHAR2 ) RETURN CLOB;

  FUNCTION get_ifc_last_processed_date_f ( p_ifc   IN   VARCHAR2 ) RETURN TIMESTAMP;

  FUNCTION get_bc_last_processed_date_f ( p_last_processed_date   IN   TIMESTAMP ) RETURN TIMESTAMP;

  PROCEDURE upd_ifc_last_processed_date_p ( p_ifc                   IN   VARCHAR2,
                                            p_request_id            IN   NUMBER,
                                            p_last_processed_date   IN   TIMESTAMP );

  PROCEDURE send_email ( p_to        IN   VARCHAR2
                        ,p_subject   IN   VARCHAR2
                        ,p_message   IN   VARCHAR2 );   

  FUNCTION print_excel_report ( p_request_id   IN   NUMBER,
                                p_program      IN   VARCHAR2,
                                p_template     IN   VARCHAR2 ) RETURN NUMBER;                        

  PROCEDURE send_unix_mail_attach ( p_mail                IN   VARCHAR2
                                   ,p_report_request_id   IN   NUMBER );

END ajc_bc_ws_utils2_pkg;
