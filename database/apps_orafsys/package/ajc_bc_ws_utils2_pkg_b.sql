PACKAGE BODY ajc_bc_ws_utils2_pkg AS

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line (fnd_file.log, p_message);

  END print_log;

  FUNCTION get_parameter_f ( p_parameter_code   IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_parameter_value   AJC_BC_PARAMETERS.parameter_value%TYPE;

  BEGIN

    SELECT parameter_value
      INTO v_parameter_value
      FROM AJC_BC_PARAMETERS
     WHERE parameter_code = p_parameter_code;

    RETURN v_parameter_value;

  END get_parameter_f;

  FUNCTION get_api_f ( p_entity      IN   VARCHAR2,
                       p_subentity   IN   VARCHAR2,
                       p_method      IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_api   AJC_BC_APIS.api%TYPE;

  BEGIN

    SELECT api
      INTO v_api
      FROM AJC_BC_APIS
     WHERE entity = p_entity
       AND DECODE(subentity,NULL,'NULL',subentity) = NVL(p_subentity,'NULL')
       AND DECODE(p_method,'GET',get,'N') = DECODE(p_method,'GET','Y','N')
       AND DECODE(p_method,'POST',post,'N') = DECODE(p_method,'POST','Y','N')
       AND DECODE(p_method,'PATCH',patch,'N') = DECODE(p_method,'PATCH','Y','N')
       AND DECODE(p_method,'DELETE',del,'N') = DECODE(p_method,'DELETE','Y','N');

    RETURN v_api;

  END get_api_f;

  FUNCTION get_emails_f ( p_integration   IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_emails   AJC_BC_INTEGRATION_EMAILS.emails%TYPE;

  BEGIN

    SELECT emails
      INTO v_emails
      FROM AJC_BC_INTEGRATION_EMAILS
     WHERE integration = p_integration;

    RETURN v_emails;

  END get_emails_f;

  FUNCTION get_object_id_f ( p_integration   IN   VARCHAR2 ) RETURN NUMBER IS

    v_object_id   AJC_BC_INTEGRATION_JOBS.object_id%TYPE;

  BEGIN

    SELECT object_id
      INTO v_object_id
      FROM AJC_BC_INTEGRATION_JOBS
     WHERE integration = p_integration;

    RETURN v_object_id;

  END get_object_id_f;

  FUNCTION get_base_inecta_url_f ( p_environment   IN   VARCHAR2,
                                   p_company_id    IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_base_inecta_url   VARCHAR2(300);

  BEGIN

    v_base_inecta_url := get_parameter_f ( p_parameter_code => 'BASE_INECTA_URL' );

    RETURN REPLACE(REPLACE(v_base_inecta_url,'$ENV',p_environment),'$COMPANY_ID',p_company_id);

  END get_base_inecta_url_f;

  FUNCTION get_base_standard_url_f ( p_environment   IN   VARCHAR2,
                                     p_api           IN   VARCHAR2,
                                     p_company_id    IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_base_standard_url   VARCHAR2(300);

  BEGIN

    v_base_standard_url := get_parameter_f ( p_parameter_code => 'BASE_STANDARD_URL' );

    RETURN REPLACE(REPLACE(REPLACE(v_base_standard_url,'$ENV',p_environment),'$API',p_api),'$COMPANY_ID',p_company_id);

  END get_base_standard_url_f;

  FUNCTION get_base_ajc_url_f ( p_environment   IN   VARCHAR2,
                                p_company       IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_base_ajc_url   VARCHAR2(300);

  BEGIN

    v_base_ajc_url := get_parameter_f ( p_parameter_code => 'BASE_AJC_URL' );

    RETURN REPLACE(REPLACE(v_base_ajc_url,'$ENV',p_environment),'$COMPANY',p_company);

  END get_base_ajc_url_f;    

  FUNCTION get_base_ajc_url_v2_f ( p_environment   IN   VARCHAR2,
                                   p_company_id    IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_base_ajc_url_v2   VARCHAR2(300);

  BEGIN

    v_base_ajc_url_v2 := get_parameter_f ( p_parameter_code => 'BASE_AJC_URL_V2' );

    RETURN REPLACE(REPLACE(v_base_ajc_url_v2,'$ENV',p_environment),'$COMPANY_ID',p_company_id);

  END get_base_ajc_url_v2_f;

  PROCEDURE set_request_headers_p ( p_request_header_name1    IN   VARCHAR2,
                                    p_request_header_value1   IN   VARCHAR2,
                                    p_request_header_name2    IN   VARCHAR2,
                                    p_request_header_value2   IN   VARCHAR2 ) IS
  BEGIN

    apex_web_service.g_request_headers.DELETE;  

    IF ( p_request_header_name1 IS NOT NULL AND p_request_header_value1 IS NOT NULL ) THEN

      apex_web_service.g_request_headers(1).name := p_request_header_name1;  
      apex_web_service.g_request_headers(1).value := p_request_header_value1; 

    END IF;

    IF ( p_request_header_name2 IS NOT NULL AND p_request_header_value2 IS NOT NULL ) THEN

      apex_web_service.g_request_headers(2).name := p_request_header_name2;  
      apex_web_service.g_request_headers(2).value := p_request_header_value2; 

    END IF;

  END set_request_headers_p;

  FUNCTION run_job_queue_token_v2_f ( p_environment          IN   VARCHAR2
                                     ,p_company_id           IN   VARCHAR2
                                     ,p_object_id            IN   NUMBER
                                     ,p_seconds_to_wait      IN   NUMBER DEFAULT 10 ) RETURN CLOB IS

    v_token_url       VARCHAR2(200);
    v_client_id       VARCHAR2(100);
    v_client_secret   VARCHAR2(100);
    v_grant_type      VARCHAR2(20);
    v_username        VARCHAR2(20);
    v_password        VARCHAR2(100);
    v_scope           VARCHAR2(100);

    v_body_token      CLOB;
    v_clob_token      CLOB;
    v_token           VARCHAR2(32767);
    v_body            VARCHAR2(200);
    v_url             VARCHAR2(500);
    v_clob_result     CLOB;
    -- 20230414 v_api             VARCHAR2(300) := 'ProcessJobQueueEntry_ProcessJobQueue';
    v_api             VARCHAR2(300);

  BEGIN

    -- print_log ( 'ajc_bc_ws_utils2_pkg.run_job_queue_token_v2_f (+)');

    v_api := ajc_bc_ws_utils2_pkg.get_api_f ( p_entity => 'JOB QUEUE',
                                              p_subentity => NULL,
                                              p_method => 'POST' );
    print_log ('v_api: ' || v_api);

    /*
    v_client_id := get_parameter_f ( p_parameter_code => 'CLIENT_ID' );
    v_client_secret := get_parameter_f ( p_parameter_code => 'CLIENT_SECRET' );
    v_grant_type := get_parameter_f ( p_parameter_code => 'GRANT_TYPE' );
    v_username := get_parameter_f ( p_parameter_code => 'USERNAME' );
    v_password := get_parameter_f ( p_parameter_code => 'PASSWORD' );
    v_scope := get_parameter_f ( p_parameter_code => 'SCOPE' );

    v_body_token := 'client_id=' || v_client_id || '&' ||
                    'client_secret=' || v_client_secret || '&' ||
                    'grant_type=' || v_grant_type || '&' ||
                    'username=' || v_username || '&' ||
                    'password=' || v_password || '&' ||
                    'scope=' || v_scope;                    

    print_log ( 'v_body_token: ' || v_body_token );

    v_token_url := get_parameter_f ( p_parameter_code => 'TOKEN_URL' );

    v_clob_token := patch_post_bc_row_job_f ( p_url => v_token_url
                                             ,p_request_header_name1 => 'Content-Type'
                                             ,p_request_header_value1 => 'application/x-www-form-urlencoded'
                                             ,p_request_header_name2 => NULL
                                             ,p_request_header_value2 => NULL
                                             ,p_http_method => 'POST'
                                             ,p_body => v_body_token );

    print_log ( 'v_clob_token: ' || v_clob_token );

    apex_json.parse ( v_clob_token );
    v_token := apex_json.get_varchar2 ( p_path => 'access_token' );     

    print_log ( 'v_token: ' || v_token );
    */

    v_body := '{"objectID":' || p_object_id || '}';

    v_url := get_base_standard_url_f ( p_environment, v_api, p_company_id );
    print_log ( 'v_url: ' || v_url );

    /*
    v_clob_result := patch_post_bc_row_job_f ( p_url => v_url
                                              ,p_request_header_name1 => 'Content-Type'
                                              ,p_request_header_value1 => 'application/json'
                                              ,p_request_header_name2 => 'Authorization'
                                              ,p_request_header_value2 => 'Bearer ' || v_token
                                              ,p_http_method => 'POST'
                                              ,p_body => v_body );
    */

    -- Quitar esto y descomentar el resto, asi queda como en prod
    v_clob_result := patch_post_bc_row_f ( p_url => v_url
                                          ,p_request_header_name1 => 'Content-Type'
                                          ,p_request_header_value1 => 'application/json'
                                          ,p_request_header_name2 => NULL
                                          ,p_request_header_value2 => NULL
                                          ,p_http_method => 'POST'
                                          ,p_body => v_body );

    -- Se agrega sleep porque el job se envia scheduled
    IF ( p_seconds_to_wait > 0 ) THEN

      DBMS_LOCK.sleep ( seconds => p_seconds_to_wait );

    END IF;

    -- print_log ( 'ajc_bc_ws_utils2_pkg.run_job_queue_token_v2_f (-)');

    RETURN v_clob_result;

  END run_job_queue_token_v2_f;

  PROCEDURE get_bc_company_id_f ( p_org_id            IN   NUMBER,
                                  p_company_number    IN   VARCHAR2,
                                  p_set_of_books_id   IN   NUMBER,
                                  p_bc_company_id    OUT   VARCHAR2,
                                  p_status           OUT   VARCHAR2 ) IS
  BEGIN

      SELECT bc_company_id
        INTO p_bc_company_id
        FROM ajc.ajc_bc_companies
       WHERE org_id = NVL(p_org_id,org_id)
         AND oracle_company_number = NVL(p_company_number,oracle_company_number)
         AND set_of_books_id = NVL(p_set_of_books_id,set_of_books_id)
    GROUP BY bc_company_id;

    p_status := 'S';

  EXCEPTION
    WHEN OTHERS THEN
      p_status := 'E'; 

  END get_bc_company_id_f;

  FUNCTION get_bc_clob_result_f ( p_url   IN   VARCHAR2 ) RETURN CLOB IS

    v_credential_static_id   VARCHAR2(100);
    v_token_url              VARCHAR2(200);
    v_clob_result            CLOB;

  BEGIN

    -- print_log ( 'ajc_bc_ws_utils2_pkg.get_bc_clob_result_f (+)');

    set_request_headers_p ( p_request_header_name1 => 'Content-Type',
                            p_request_header_value1 => 'application/json',
                            p_request_header_name2 => NULL,
                            p_request_header_value2 => NULL );

    v_credential_static_id := get_parameter_f ( 'CREDENTIAL_STATIC_ID' );
    v_token_url := get_parameter_f ( p_parameter_code => 'TOKEN_URL' );

    SELECT APEX_WEB_SERVICE.MAKE_REST_REQUEST ( p_url => utl_url.escape(p_url), 
                                                p_http_method => 'GET',
                                                p_credential_static_id => v_credential_static_id,
                                                p_token_url => v_token_url ) 
      INTO v_clob_result
      FROM dual;

    -- print_log ( 'ajc_bc_ws_utils2_pkg.get_bc_clob_result_f (-)');

    RETURN v_clob_result;

  END get_bc_clob_result_f;  

  FUNCTION patch_post_bc_row_f ( p_url                     IN   VARCHAR2
                                ,p_request_header_name1    IN   VARCHAR2
                                ,p_request_header_value1   IN   VARCHAR2
                                ,p_request_header_name2    IN   VARCHAR2
                                ,p_request_header_value2   IN   VARCHAR2
                                ,p_http_method             IN   VARCHAR2
                                ,p_body                    IN   VARCHAR2 ) RETURN CLOB IS

    v_credential_static_id   VARCHAR2(100);
    v_token_url              VARCHAR2(200);
    v_clob_result            CLOB;

  BEGIN

    -- print_log ( 'ajc_bc_ws_utils2_pkg.patch_post_bc_row_f (+)');

    set_request_headers_p ( p_request_header_name1 => p_request_header_name1,
                            p_request_header_value1 => p_request_header_value1,
                            p_request_header_name2 => p_request_header_name2,
                            p_request_header_value2 => p_request_header_value2 );

    v_credential_static_id := get_parameter_f ( 'CREDENTIAL_STATIC_ID' );
    v_token_url := get_parameter_f ( p_parameter_code => 'TOKEN_URL' );

    v_clob_result := APEX_WEB_SERVICE.MAKE_REST_REQUEST ( p_url => utl_url.escape(p_url), 
                                                          p_http_method => p_http_method,
                                                          p_body => p_body,
                                                          p_credential_static_id => v_credential_static_id,
                                                          p_token_url => v_token_url );

    -- print_log ( 'ajc_bc_ws_utils2_pkg.patch_post_bc_row_f (-)');

    RETURN v_clob_result;

  END patch_post_bc_row_f;

  FUNCTION patch_post_bc_row_job_f ( p_url                     IN   VARCHAR2
                                    ,p_request_header_name1    IN   VARCHAR2
                                    ,p_request_header_value1   IN   VARCHAR2
                                    ,p_request_header_name2    IN   VARCHAR2
                                    ,p_request_header_value2   IN   VARCHAR2
                                    ,p_http_method             IN   VARCHAR2
                                    ,p_body                    IN   VARCHAR2 ) RETURN CLOB IS

    v_clob_result   CLOB;

  BEGIN

    -- print_log ( 'ajc_bc_ws_utils2_pkg.patch_post_bc_row_job_f (+)');

    set_request_headers_p ( p_request_header_name1 => p_request_header_name1,
                            p_request_header_value1 => p_request_header_value1,
                            p_request_header_name2 => p_request_header_name2,
                            p_request_header_value2 => p_request_header_value2 );

    v_clob_result := APEX_WEB_SERVICE.MAKE_REST_REQUEST ( p_url => utl_url.escape(p_url), 
                                                          p_http_method => p_http_method,
                                                          p_body => p_body );

    -- print_log ( 'ajc_bc_ws_utils2_pkg.patch_post_bc_row_job_f (-)');

    RETURN v_clob_result;

  END patch_post_bc_row_job_f;

  FUNCTION delete_bc_row_f ( p_url   IN   VARCHAR2 ) RETURN CLOB IS

    v_credential_static_id   VARCHAR2(100);
    v_token_url              VARCHAR2(200);
    v_clob_del               CLOB;

  BEGIN

    -- print_log ( 'ajc_bc_ws_utils2_pkg.delete_bc_row_f (+)');

    set_request_headers_p ( p_request_header_name1 => 'Content-Type',
                            p_request_header_value1 => 'application/json',
                            p_request_header_name2 => NULL,
                            p_request_header_value2 => NULL );

    v_credential_static_id := get_parameter_f ( 'CREDENTIAL_STATIC_ID' );
    v_token_url := get_parameter_f ( p_parameter_code => 'TOKEN_URL' );

    v_clob_del := APEX_WEB_SERVICE.MAKE_REST_REQUEST ( p_url => utl_url.escape(p_url),
                                                       p_http_method => 'DELETE',
                                                       p_body => '',
                                                       p_credential_static_id => v_credential_static_id,
                                                       p_token_url => v_token_url );    

    -- print_log ( 'ajc_bc_ws_utils2_pkg.delete_bc_row_f (-)');

    RETURN v_clob_del;

  END delete_bc_row_f;

  FUNCTION get_ifc_last_processed_date_f ( p_ifc   IN   VARCHAR2 ) RETURN TIMESTAMP IS

    v_last_processed_date   TIMESTAMP;

  BEGIN

    print_log ( 'ajc_bc_ws_utils2_pkg.get_ifc_last_processed_date_f (+)');

    SELECT last_processed_date
      INTO v_last_processed_date
      FROM ajc_bc_ifc_control_table
     WHERE ifc = p_ifc; 

    print_log ( 'ajc_bc_ws_utils2_pkg.get_ifc_last_processed_date_f (-)');

    RETURN v_last_processed_date;

  EXCEPTION 
    WHEN NO_DATA_FOUND THEN
      print_log ( 'ajc_bc_ws_utils2_pkg.get_ifc_last_processed_date_f (!)');
      print_log ( 'Se crea el registro en la tabla de control para la ifc ' || p_ifc );

      v_last_processed_date := systimestamp;

      INSERT 
        INTO ajc_bc_ifc_control_table 
             ( ifc,
               last_processed_date )
      VALUES ( p_ifc,
               v_last_processed_date );

      RETURN v_last_processed_date;

  END get_ifc_last_processed_date_f;

  FUNCTION get_bc_last_processed_date_f ( p_last_processed_date   IN   TIMESTAMP ) RETURN TIMESTAMP IS

    v_last_bc_processed_date   TIMESTAMP;

  BEGIN

    SELECT TO_NUMBER(TO_CHAR(SYSTIMESTAMP,'TZH')) * -1 
      INTO gv_bc_oracle_diff_hours
      FROM dual;

    print_log ( 'gv_bc_oracle_diff_hours: ' || gv_bc_oracle_diff_hours );

    v_last_bc_processed_date := p_last_processed_date + NUMTODSINTERVAL(gv_bc_oracle_diff_hours, 'HOUR');

    -- Si cuando cambien nuevamente el horario esto da error, se puede probar con 
    /*
    SELECT p_last_processed_date AT TIME ZONE 'UTC' 
      INTO v_last_bc_processed_date
      FROM dual;
    */

    RETURN v_last_bc_processed_date;

  END;

  PROCEDURE upd_ifc_last_processed_date_p ( p_ifc                   IN   VARCHAR2,
                                            p_request_id            IN   NUMBER,
                                            p_last_processed_date   IN   TIMESTAMP ) IS
  BEGIN

    print_log ( 'ajc_bc_ws_utils2_pkg.upd_ifc_last_processed_date_p (+)');

    UPDATE ajc_bc_ifc_control_table
       SET last_processed_date = p_last_processed_date,
           request_id = p_request_id
     WHERE ifc = p_ifc;

    print_log ( 'ajc_bc_ws_utils2_pkg.upd_ifc_last_processed_date_p (-)');

  END;

  PROCEDURE send_email ( p_to        IN   VARCHAR2
                        ,p_subject   IN   VARCHAR2
                        ,p_message   IN   VARCHAR2 ) IS
  BEGIN

    EXECUTE IMMEDIATE 'ALTER SESSION SET smtp_out_server = ''smtp.ajc.bz''';

    utl_mail.send( SENDER     => 'Appstech@ajcfood.com',
                   RECIPIENTS => p_to,
                   SUBJECT    => p_subject,
                   MESSAGE    => p_message,
                   mime_type  => 'text; charset=us-ascii' );

  END send_email;

  /*==========================================================================+
  |                                                                           |
  | Private Function                                                          |
  |    print_excel_report                                                     |
  |                                                                           |
  | Description                                                               |
  |    Impresion de reporte en excel para Purchase Invoices (ABBYY y Certify) |
  |                                                                           |
  | Parameters                                                                |
  |                                                                           |
  +==========================================================================*/  
  FUNCTION print_excel_report ( p_request_id   IN   NUMBER,
                                p_program      IN   VARCHAR2,
                                p_template     IN   VARCHAR2 ) RETURN NUMBER IS

    v_request_id           NUMBER;
    v_message              VARCHAR2(2000);
    v_error_message        VARCHAR2(2000);
    e_cust_exception       EXCEPTION;
    v_conc_phase           VARCHAR2 (50);
    v_conc_status          VARCHAR2 (50);
    v_conc_dev_phase       VARCHAR2 (50);
    v_conc_dev_status      VARCHAR2 (50);
    v_conc_message         VARCHAR2 (250);

    v_template_appl_name   xdo_templates_b.application_short_name%TYPE;
    v_template_code        xdo_templates_b.template_code%TYPE;
    v_template_language    xdo_templates_b.default_language%TYPE;
    v_template_territory   xdo_templates_b.default_territory%TYPE;
    v_output_format        VARCHAR2(10);
    v_status_code          VARCHAR2(1);

  BEGIN

    BEGIN

      SELECT application_short_name, 
             template_code, 
             default_language, 
             default_territory, 
             'EXCEL'
        INTO v_template_appl_name,
             v_template_code,
             v_template_language,
             v_template_territory,
             v_output_format
        FROM xdo_templates_b
       WHERE template_code = p_template;

    EXCEPTION
      WHEN OTHERS THEN
        v_error_message := 'Error al buscar los datos del template correspondiente al código: ' || p_template || ': ' || SQLERRM;
        v_status_code := 'W';
        RAISE e_cust_exception;

    END;  

    IF NOT fnd_request.add_layout ( template_appl_name  => v_template_appl_name,
                                    template_code       => v_template_code,
                                    template_language   => v_template_language,
                                    template_territory  => v_template_territory,
                                    output_format       => v_output_format ) THEN

      v_error_message := 'Error al setear el Template Publisher';
      v_status_code := 'E';
      RAISE e_cust_exception;

    END IF; 

    IF NOT fnd_request.set_options ( 'NO','YES',NULL,NULL ) THEN

      v_message := fnd_message.get;
      v_error_message := 'Error ejecutando FND_REQUEST.SET_OPTIONS. ' || v_message || ' ' || SQLERRM;
      v_status_code := 'W';
      RAISE e_cust_exception;

    END IF;

    v_request_id := fnd_request.submit_request ( 'XXAJC',
                                                 p_program,
                                                 argument1 => p_request_id ) ;

    IF v_request_id = 0 THEN

      v_message := fnd_message.get;
      print_log ( 'Error Ejecutando FND_REQUEST.SUBMIT_REQUEST. ' || p_program || '. Error: ' || v_message || ', ' || SQLERRM );
      RAISE e_cust_exception;

    END IF ;

    COMMIT;

    IF NOT fnd_concurrent.wait_for_request ( v_request_id,
                                             10,
                                             18000,
                                             v_conc_phase,
                                             v_conc_status,
                                             v_conc_dev_phase,
                                             v_conc_dev_status,
                                             v_conc_message) THEN

      v_message := fnd_message.get;
      print_log ( 'Error Ejecutando FND_REQUEST.WAIT_FOR_REQUEST. ' || p_program || ' con nro. solicitud ' || 
                   TO_CHAR (v_request_id) || '. Error: ' || v_message || ' ' || SQLERRM );
      RAISE e_cust_exception;

    END IF ;

    IF v_conc_dev_phase != 'COMPLETE' OR v_conc_dev_status != 'NORMAL' THEN

      v_error_message := fnd_message.get;
      print_log ( 'Error en la ejecucion del concurrente ' || p_program || ' con nro. solicitud ' || 
                   TO_CHAR (v_request_id) || '. Error: ' || v_error_message || ' ' || SQLERRM );
      RAISE e_cust_exception;

    END IF ; 

    RETURN v_request_id;

  END print_excel_report;

  PROCEDURE send_unix_mail_attach ( p_mail                IN   VARCHAR2
                                   ,p_report_request_id   IN   NUMBER ) IS

    v_db_name           VARCHAR2(100);
    v_file_name         VARCHAR2(100);  
    v_file_name_new     VARCHAR2(100);  
    v_interface_name    VARCHAR2(100);

    v_subject           VARCHAR2(100);
    v_body              VARCHAR2(100);

    v_request_id        NUMBER;
    v_conc_phase        VARCHAR2(50);
    v_conc_status       VARCHAR2(50);
    v_conc_dev_phase    VARCHAR2(50);
    v_conc_dev_status   VARCHAR2(50);
    v_conc_message      VARCHAR2(250);
    v_message           VARCHAR2(32000);
    v_error_message     VARCHAR2(2000);
    e_cust_exception    EXCEPTION;

  BEGIN

    -- Se obtiene el nombre de la base de datos
    SELECT name
      INTO v_db_name
      FROM V$DATABASE;

    print_log ( 'v_db_name: ' || v_db_name );

    IF ( v_db_name = 'PROD' ) THEN

      -- Se obtiene el nombre del excel generado
      BEGIN

        SELECT pr.concurrent_program_name || '_' || rr.request_id || '_1.EXCEL',
               pr.concurrent_program_name || '.xls',
               pi.user_concurrent_program_name
          INTO v_file_name,
               v_file_name_new,
               v_interface_name
          FROM fnd_concurrent_requests rr,
               fnd_concurrent_programs_vl pr,
               fnd_concurrent_requests ri,
               fnd_concurrent_programs_vl pi
         WHERE rr.concurrent_program_id = pr.concurrent_program_id
           AND rr.request_id = p_report_request_id
           AND rr.parent_request_id = ri.request_id
           AND ri.concurrent_program_id = pi.concurrent_program_id;

      EXCEPTION
        WHEN NO_DATA_FOUND THEN

          SELECT pr.concurrent_program_name || '_' || rr.request_id || '_1.EXCEL',
                 pr.concurrent_program_name || '.xls',
                 pr.user_concurrent_program_name
            INTO v_file_name,
                 v_file_name_new,
                 v_interface_name
            FROM fnd_concurrent_requests rr,
                 fnd_concurrent_programs_vl pr
           WHERE rr.concurrent_program_id = pr.concurrent_program_id
             AND rr.request_id = p_report_request_id; 

      END;

      print_log ( 'v_file_name: ' || v_file_name );
      print_log ( 'v_file_name_new: ' || v_file_name_new );
      print_log ( 'v_interface_name: ' || v_interface_name );

      v_subject := v_interface_name || ' - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS');
      -- v_body := 'Se adjunta reporte excel correspondiente a la ejecución de ' || v_interface_name;
      v_body := v_interface_name || ' excel report attached.';

      print_log ( 'v_subject: ' || v_subject );
      print_log ( 'v_body: ' || v_body );

      -- Se ejecuta el concurrente AJC BC Mail
      v_request_id := fnd_request.submit_request ( 'XXAJC',
                                                   'AJCBCMAIL',
                                                   argument1 => v_file_name,
                                                   argument2 => v_file_name_new,
                                                   argument3 => v_subject,
                                                   argument4 => v_body,
                                                   argument5 => REPLACE(p_mail,';',',') ) ; 

      IF v_request_id = 0 THEN

        v_message := fnd_message.get;
        print_log ('Error Ejecutando FND_REQUEST.SUBMIT_REQUEST. AJCBCM - AJC BC Mail. Error: ' || v_message || ', ' || SQLERRM);
        RAISE e_cust_exception;

      END IF ;

      COMMIT;

      IF NOT fnd_concurrent.wait_for_request ( v_request_id,
                                               10,
                                               18000,
                                               v_conc_phase,
                                               v_conc_status,
                                               v_conc_dev_phase,
                                               v_conc_dev_status,
                                               v_conc_message) THEN
        v_message := fnd_message.get;
        print_log('Error Ejecutando FND_REQUEST.WAIT_FOR_REQUEST. AJCBCM - AJC BC Mail, con nro. solicitud ' || 
                   TO_CHAR (v_request_id) || '. Error: ' || v_message || ' ' || SQLERRM);
        RAISE e_cust_exception;

      END IF ;

      IF v_conc_dev_phase != 'COMPLETE' OR v_conc_dev_status != 'NORMAL' THEN

        v_error_message := fnd_message.get;
        print_log('Error en la ejecucion del concurrente AJCBCM - AJC BC Mail, con nro. solicitud ' || 
                   TO_CHAR (v_request_id) || '. Error: ' || v_error_message || ' ' || SQLERRM);
        RAISE e_cust_exception;

      END IF ;

    END IF;

  END send_unix_mail_attach;

END ajc_bc_ws_utils2_pkg;
