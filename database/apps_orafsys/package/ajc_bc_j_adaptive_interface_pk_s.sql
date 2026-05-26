PACKAGE              AJC_BC_J_ADAPTIVE_INTERFACE_PK IS
/* --------------------------------------------------------------------------------------------|
| Historial                                                                                    |
|   Date      Version Modified   Detail                                                        |
|   --------- ------- ---------- --------------------------------------------------------------|
|   17-JUN-20       1 SBANCHIERI Creation                                                      |
|   03-OCT-22       1.1 MBETTI Update                                                           |
|   18-DEC-25       1.2 MBETTI Jenkins Migration                                            |
|---------------------------------------------------------------------------------------------*/

  gv_bc_environment          VARCHAR2(100);
  gv_jenkins_build_number NUMBER;
  gv_request_id              fnd_concurrent_requests.request_id%TYPE;
  gv_log_seq                 NUMBER := 0;
  gv_user_id                 fnd_user.user_id%TYPE := 0;
  gv_login_id               NUMBER :=0;
  gv_bc_ifc                  VARCHAR2(200) := 'AJC BC Adaptive Interface';  
  gv_file_format             VARCHAR2(4);
  gv_email                   ajc_bc_integration_emails.emails%TYPE;    

  /*=========================================================================+
  |                                                                          |
  | Public Function                                                          |
  |    main_process                                                          |
  |                                                                          |
  | Description                                                              |
  |    Expenses Cost Main Process                                            |
  |    Concurrent Program Executable                                         |
  |                                                                          |
  |                                                                          |
  | Parameters                                                               |
  |    retcode                   OUT     NUMBER    Codigo Estado.            |
  |    errbuf                    OUT     VARCHAR2  Mensaje de Finalizacion.  |
  |                                                                          |
  +=========================================================================*/
  PROCEDURE main_p ( p_bc_environment    IN VARCHAR2
                          ,p_force_closed_periods   IN   VARCHAR2 DEFAULT 'N' 
                          ,p_jenkins_build_number IN VARCHAR2);

PROCEDURE process_accounts ( p_company_id IN VARCHAR
                            ,p_status_code   OUT VARCHAR2
                            ,p_error_message OUT VARCHAR2 );

PROCEDURE process_journals ( p_company_id IN VARCHAR2
                            ,p_status_code   OUT VARCHAR2
                            ,p_error_message OUT VARCHAR2 );                            

END AJC_BC_J_ADAPTIVE_INTERFACE_PK;
