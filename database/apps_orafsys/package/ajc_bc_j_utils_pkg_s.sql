PACKAGE AJC_BC_J_UTILS_PKG IS
-- Creation: SBANCHIERI 15-APR-2025
  
  gv_log_seq      NUMBER := 0;
  gv_request_id   NUMBER;
  gv_bc_ifc       VARCHAR2(200);
  gv_from_mail    VARCHAR2(100); -- 'Appstech@ajcfood.com' | 'no-reply@ajcfood.com'

  FUNCTION get_dimension_value ( p_oracle_segment   IN   VARCHAR2,
                                 p_oracle_value     IN   VARCHAR2,
                                 p_bc_dimension     IN   VARCHAR2 ) RETURN VARCHAR2;

  FUNCTION get_db_name_f RETURN VARCHAR2;

  FUNCTION get_company_parameters_p ( p_bc_company_name   IN   VARCHAR2,
                                      p_column            IN   VARCHAR2 ) RETURN VARCHAR2; 

  -- Funciones para formatear reports / outputs en formato xlsx
  FUNCTION get_alignment_f RETURN as_xlsx.tp_alignment;

  FUNCTION get_fill_id_f RETURN PLS_INTEGER;

  FUNCTION get_font_f ( p_bold   IN   BOOLEAN ) RETURN PLS_INTEGER;

  FUNCTION get_default_column_width_f RETURN NUMBER;

  PROCEDURE create_rep_info_sheet_p ( p_report_title           IN   VARCHAR2,
                                      p_request_id             IN   NUMBER,
                                      p_bc_environment         IN   VARCHAR2,
                                      p_jenkins_build_number   IN   VARCHAR2,
                                      -- 
                                      p_param_1_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_1_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_2_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_2_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_3_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_3_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_4_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_4_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_5_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_5_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_6_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_6_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_7_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_7_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_8_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_8_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_9_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_9_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_10_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_10_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_11_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_11_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_12_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_12_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_13_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_13_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_14_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_14_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_15_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_15_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_16_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_16_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_17_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_17_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_18_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_18_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_19_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_19_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_20_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_20_value         IN   VARCHAR2 DEFAULT NULL );

  PROCEDURE create_sheet_p ( p_sheet_title   IN       VARCHAR2,
                             p_sheet         IN       NUMBER,
                             p_cursor        IN OUT   SYS_REFCURSOR );

  -- Para formatear reports / outputs en formato xlsx

  FUNCTION get_emails_f ( p_integration   IN   VARCHAR2 ) RETURN VARCHAR2;

  PROCEDURE send_email_p ( p_to        IN   VARCHAR2,
                           p_subject   IN   VARCHAR2,
                           p_message   IN   VARCHAR2 );

  -- Crear un archivo csv en el db server, separado por | 
  PROCEDURE create_csv_p ( p_ifc            IN       VARCHAR2,
                           p_request_id     IN       NUMBER,
                           p_log_seq        IN OUT   NUMBER,
                           p_type           IN       VARCHAR2, -- 'LOG' | 'OUTPUT' | 'REPORT'
                           p_filename       IN       VARCHAR2,
                           p_status        OUT       VARCHAR2 );

  gv_file_format   VARCHAR2(4);

  -- Genera y envia tantos mails como destinatarios haya, solo usa TO y no usa CC
  PROCEDURE send_mail_with_attach ( p_to_mail            VARCHAR2,
                                    p_subject            VARCHAR2,
                                    p_body               VARCHAR2,
                                    p_type               VARCHAR2,
                                    p_filename           VARCHAR2,
                                    p_file_format        VARCHAR2 DEFAULT 'CSV',
                                    p_attach_filename    VARCHAR2 );      

  -- Inserta en la tabla AJC_BC_LOGS
  PROCEDURE insert_log_p ( p_ifc          VARCHAR2,
                           p_text         VARCHAR2,
                           p_request_id   NUMBER,
                           p_seq          NUMBER );

  -- Se llama desde Jenkins - AJC BC Purge Log
  PROCEDURE purge_log_p ( p_keep_x_days   IN   VARCHAR2 );

  -- Se llama desde Jenkins - AJC BC Send Log by Mail
  PROCEDURE send_log_by_mail_p ( p_request_id             IN   VARCHAR2,
                                 p_mail                   IN   VARCHAR2,
                                 p_jenkins_build_number   IN   VARCHAR2 DEFAULT NULL );

  -- Inserta en la tabla AJC_BC_OUTPUTS
  PROCEDURE insert_output_p ( p_ifc          VARCHAR2,
                              p_text         VARCHAR2,
                              p_request_id   NUMBER ); 

  -- Inserta en la tabla AJC_BC_OUTPUTS_XLSX
  PROCEDURE insert_output_xlsx_p ( p_ifc          VARCHAR2,
                                   p_section      VARCHAR2,
                                   p_column1      VARCHAR2,
                                   p_column2      VARCHAR2 DEFAULT NULL,
                                   p_column3      VARCHAR2 DEFAULT NULL,
                                   p_column4      VARCHAR2 DEFAULT NULL,
                                   p_column5      VARCHAR2 DEFAULT NULL,
                                   p_column6      VARCHAR2 DEFAULT NULL,
                                   p_column7      VARCHAR2 DEFAULT NULL,
                                   p_column8      VARCHAR2 DEFAULT NULL,
                                   p_column9      VARCHAR2 DEFAULT NULL,
                                   p_column10     VARCHAR2 DEFAULT NULL,
                                   p_column11     VARCHAR2 DEFAULT NULL,
                                   p_column12     VARCHAR2 DEFAULT NULL,
                                   p_column13     VARCHAR2 DEFAULT NULL,
                                   p_column14     VARCHAR2 DEFAULT NULL,
                                   p_column15     VARCHAR2 DEFAULT NULL,
                                   p_column16     VARCHAR2 DEFAULT NULL,
                                   p_column17     VARCHAR2 DEFAULT NULL,
                                   p_column18     VARCHAR2 DEFAULT NULL,
                                   p_column19     VARCHAR2 DEFAULT NULL,
                                   p_column20     VARCHAR2 DEFAULT NULL,
                                   p_request_id   NUMBER ); 

  -- Inserta en la tabla AJC_BC_REPORTS
  PROCEDURE insert_report_p ( p_ifc          VARCHAR2,
                              p_text         VARCHAR2,
                              p_request_id   NUMBER ); 

  gv_directory_output   all_directories.directory_name%TYPE; 
  gv_directory_report   all_directories.directory_name%TYPE; 

  FUNCTION get_request_id_f RETURN NUMBER;   

  FUNCTION get_env_variable_value_f ( p_variable   IN   VARCHAR2 ) RETURN VARCHAR2;   

  FUNCTION is_bc_environment_valid_f ( p_bc_environment   IN   VARCHAR2 ) RETURN VARCHAR2;

  PROCEDURE initialize_p ( p_org_id   IN   NUMBER );

  PROCEDURE ins_jenkins_concurrent_job_p ( p_request_id             IN   NUMBER,
                                           p_job_name               IN   VARCHAR2,
                                           p_jenkins_build_number   IN   VARCHAR2 DEFAULT NULL,
                                           p_argument1              IN   VARCHAR2 DEFAULT NULL,
                                           p_argument2              IN   VARCHAR2 DEFAULT NULL,
                                           p_argument3              IN   VARCHAR2 DEFAULT NULL,
                                           p_argument4              IN   VARCHAR2 DEFAULT NULL,
                                           p_argument5              IN   VARCHAR2 DEFAULT NULL,
                                           p_argument6              IN   VARCHAR2 DEFAULT NULL,
                                           p_argument7              IN   VARCHAR2 DEFAULT NULL,
                                           p_argument8              IN   VARCHAR2 DEFAULT NULL,
                                           p_argument9              IN   VARCHAR2 DEFAULT NULL,
                                           p_argument10             IN   VARCHAR2 DEFAULT NULL,
                                           p_argument11             IN   VARCHAR2 DEFAULT NULL,
                                           p_argument12             IN   VARCHAR2 DEFAULT NULL,
                                           p_argument13             IN   VARCHAR2 DEFAULT NULL,
                                           p_argument14             IN   VARCHAR2 DEFAULT NULL,
                                           p_argument15             IN   VARCHAR2 DEFAULT NULL,
                                           p_argument16             IN   VARCHAR2 DEFAULT NULL,
                                           p_argument17             IN   VARCHAR2 DEFAULT NULL,
                                           p_argument18             IN   VARCHAR2 DEFAULT NULL,
                                           p_argument19             IN   VARCHAR2 DEFAULT NULL,
                                           p_argument20             IN   VARCHAR2 DEFAULT NULL );

  PROCEDURE upd_jenkins_concurrent_job_p ( p_request_id   IN   NUMBER,
                                           p_status       IN   VARCHAR2 );

END AJC_BC_J_UTILS_PKG;
