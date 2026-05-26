PACKAGE BODY AJC_BC_J_WS_UTILS_PKG AS

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

  FUNCTION get_lock_process_name_f ( p_integration   IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_lock_process_name   ajc_bc_integration_jobs.lock_process_name%TYPE;

  BEGIN

    SELECT lock_process_name
      INTO v_lock_process_name
      FROM ajc_bc_integration_jobs
     WHERE integration = p_integration;

    RETURN v_lock_process_name;

  END get_lock_process_name_f;

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

  PROCEDURE initialize_job_p ( p_bc_environment   IN   VARCHAR2,
                               p_company_id       IN   VARCHAR2,
                               p_object_id        IN   NUMBER,
                               p_status          OUT   VARCHAR2 ) IS

    v_clob_result      CLOB;

    v_url              VARCHAR2(2000);
    v_current_userID   VARCHAR2(2000);

    v_patch_url        VARCHAR2(2000);
    v_body             VARCHAR2(2000);
    v_etag             VARCHAR2(1000);    

    CURSOR c_job_current_user ( p_clob_result   IN   CLOB ) IS
    SELECT userID
      FROM json_table( p_clob_result,  
                       '$.value[*]' COLUMNS ( userID        VARCHAR2(4000)  path '$.userID' ) )
     WHERE rownum = 1;

  BEGIN

    -- Se consulta con que user está el job en BC
    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,
                                                          p_entity => 'INITIALIZE JOB', 
                                                          p_subentity => NULL,
                                                          p_method => 'GET',
                                                          p_company_id => p_company_id )
             || '?$filter=objectIDToRun eq ' || p_object_id;

    v_clob_result := AJC_BC_J_WS_UTILS_PKG.get_bc_clob_result_f ( p_url => v_url );

    FOR cjcu IN c_job_current_user ( v_clob_result ) LOOP

      v_current_userID := cjcu.userID;

    END LOOP;
    -- Se consulta con que user está el job en BC

    -- Si no esta con OAUTH, se intenta inicializar el job con OAUTH
    IF ( v_current_userID != 'OAUTH' ) THEN

      v_patch_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,
                                                                  p_entity => 'INITIALIZE JOB', 
                                                                  p_subentity => NULL,
                                                                  p_method => 'PATCH',
                                                                  p_company_id => p_company_id )
                     || '(' || p_object_id || ')'; -- ODataKeyFields

      -- Se obtiene el etag
      v_clob_result := AJC_BC_J_WS_UTILS_PKG.get_bc_clob_result_f ( p_url => v_patch_url );

      v_etag := SUBSTR(v_clob_result,INSTR(v_clob_result,'@odata.etag') + 14);
      v_etag := REPLACE(SUBSTR(v_etag,1,INSTR(v_etag,',') - 2),'\');

      -- Se hace patch con el user OAUTH
      v_body := '{"userID":"OAUTH"}';

      v_clob_result := AJC_BC_J_WS_UTILS_PKG.patch_post_bc_row_f ( p_url => v_patch_url
                                                                  ,p_request_header_name1 => 'Content-Type'
                                                                  ,p_request_header_value1 => 'application/json'
                                                                  ,p_request_header_name2 => 'If-Match'
                                                                  ,p_request_header_value2 => v_etag
                                                                  ,p_http_method => 'PATCH'
                                                                  ,p_body => v_body );   

    END IF;                                                                  

    p_status := 'S';

  EXCEPTION
    WHEN OTHERS THEN
      p_status := 'E';

  END initialize_job_p;

  PROCEDURE check_job_status ( p_bc_environment       IN   VARCHAR2
                              ,p_company_id           IN   VARCHAR2
                              ,p_object_id            IN   NUMBER
                              ,p_status              OUT   VARCHAR2 ) IS

    v_clob_status             CLOB;
    v_url                     VARCHAR2(2000);
    v_status                  VARCHAR2(100);
    -- 20240510
    v_timeout_seconds         NUMBER;
    v_check_every_x_seconds   NUMBER;
    v_start_check_date        DATE;
    v_elapsed_seconds         NUMBER;
    -- 20240510

  BEGIN

    -- Se obtiene el maximo de segundos a esperar
    BEGIN

      SELECT TO_NUMBER(ajc_bc_j_ws_utils_pkg.get_parameter_f ( 'CHECK_JOB_STATUS_TIMEOUT_IN_SECONDS' ))
        INTO v_timeout_seconds
        FROM DUAL;

    EXCEPTION
      WHEN OTHERS THEN
        v_timeout_seconds := 3600;

    END;

    -- Se obtiene los segundos a esperar entre comprobaciones
    BEGIN

      SELECT TO_NUMBER(ajc_bc_j_ws_utils_pkg.get_parameter_f ( 'CHECK_JOB_STATUS_EVERY_X_SECONDS' ))
        INTO v_check_every_x_seconds 
        FROM DUAL;

    EXCEPTION
      WHEN OTHERS THEN
        v_check_every_x_seconds := 15;

    END;

    -- Se usa el de LOGIS
    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,
                                                          p_entity => 'CHECK JOB STATUS', 
                                                          p_subentity => NULL,
                                                          p_method => 'GET',
                                                          p_company_id => p_company_id )
             || '?$filter=objectIDToRun eq ' || p_object_id
             || ' and userID eq ''OAUTH''';    

    DBMS_LOCK.sleep ( seconds => v_check_every_x_seconds );

    -- Se chequea el status
    v_clob_status := ajc_bc_j_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );

    SELECT status
      INTO v_status
      FROM json_table( v_clob_status,  
                       '$.value[*]' COLUMNS ( objectIDToRun        VARCHAR2(4000)  path '$.objectIDToRun',
                                              objectCaptionToRun   VARCHAR2(4000)  path '$.objectCaptionToRun',
                                              status               VARCHAR2(4000)  path '$.status' ) );

    -- Se obtiene el momento en el que se comienza a chequear status del job
    v_start_check_date := SYSDATE;
    -- Se calculan los segundos transcurridos desde el ultimo chequeo
    v_elapsed_seconds := TRUNC(( SYSDATE - v_start_check_date ) * 24 * 60 * 60 );

    WHILE ( NVL(v_status,'In Process') = 'In Process' AND 
            v_elapsed_seconds <= v_timeout_seconds ) LOOP -- Aun no se supero la cantidad maxima de segundos a esperar

      DBMS_LOCK.sleep ( seconds => v_check_every_x_seconds );

      v_clob_status := ajc_bc_j_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );

      SELECT status
        INTO v_status
        FROM json_table( v_clob_status,  
                         '$.value[*]' COLUMNS ( objectIDToRun        VARCHAR2(4000)  path '$.objectIDToRun',
                                                objectCaptionToRun   VARCHAR2(4000)  path '$.objectCaptionToRun',
                                                status               VARCHAR2(4000)  path '$.status' ) );

      -- Se calculan los segundos transcurridos desde el ultimo chequeo
      v_elapsed_seconds := TRUNC(( SYSDATE - v_start_check_date ) * 24 * 60 * 60 );

    END LOOP;  

    p_status := 'S';

    -- Se comprueba si salio por timeout
    IF ( v_elapsed_seconds > v_timeout_seconds ) THEN

      p_status := 'E';

    END IF;

  END check_job_status;

  FUNCTION run_job_queue_f ( p_bc_environment   IN   VARCHAR2,
                             p_company_id       IN   VARCHAR2,
                             p_object_id        IN   NUMBER ) RETURN CLOB IS

    v_api             VARCHAR2(300);
    v_body            CLOB;
    v_url             VARCHAR2(500);
    v_clob_result     CLOB;    

    -- 20240510
    v_status          VARCHAR2(1);
    e_timeout         EXCEPTION;
    e_initialize      EXCEPTION;
    -- 20240510

  BEGIN

    -- print_log ( 'ajc_bc_j_ws_utils_pkg.run_job_queue_f (+)');

    -- Se inicializa el job con OAUTH
    initialize_job_p ( p_bc_environment => p_bc_environment, 
                       p_company_id => p_company_id, 
                       p_object_id => p_object_id, 
                       p_status => v_status );

    IF ( v_status = 'E' ) THEN

      RAISE e_initialize;

    END IF;

    v_api := get_api_f ( p_entity => 'JOB QUEUE',
                         p_subentity => NULL,
                         p_method => 'POST' );
    -- print_log ('v_api: ' || v_api);

    v_body := '{"objectID":' || p_object_id || '}';

    v_url := get_base_standard_url_f ( p_bc_environment, v_api, p_company_id );
    -- print_log ( 'v_url: ' || v_url );

    v_clob_result := patch_post_bc_row_f ( p_url => v_url
                                          ,p_request_header_name1 => 'Content-Type'
                                          ,p_request_header_value1 => 'application/json'
                                          ,p_request_header_name2 => NULL
                                          ,p_request_header_value2 => NULL
                                          ,p_http_method => 'POST'
                                          ,p_body => v_body );

    -- DBMS_LOCK.sleep ( seconds => 15 );
    DBMS_LOCK.sleep ( seconds => 5 );

    check_job_status ( p_bc_environment => p_bc_environment,
                       p_company_id => p_company_id,
                       p_object_id => p_object_id,
                       p_status => v_status );

    -- Si termino en error es porque la comprobacion dio timeout
    IF ( v_status = 'E' ) THEN

      RAISE e_timeout;

    END IF;

    -- print_log ( 'ajc_bc_j_ws_utils_pkg.run_job_queue_f (-)');

    RETURN v_clob_result;

  EXCEPTION
    WHEN e_initialize THEN
      RETURN 'ERROR - BC Job cant be initialized with OAUTH user.';
    WHEN e_timeout THEN
      RETURN 'ERROR - BC Job status check ended due to timeout.';

  END run_job_queue_f;

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

    set_request_headers_p ( p_request_header_name1 => p_request_header_name1,
                            p_request_header_value1 => p_request_header_value1,
                            p_request_header_name2 => p_request_header_name2,
                            p_request_header_value2 => p_request_header_value2 );

    v_clob_result := APEX_WEB_SERVICE.MAKE_REST_REQUEST ( p_url => utl_url.escape(p_url), 
                                                          p_http_method => p_http_method,
                                                          p_body => p_body );

    RETURN v_clob_result;

  END patch_post_bc_row_job_f;

  FUNCTION delete_bc_row_f ( p_url   IN   VARCHAR2 ) RETURN CLOB IS

    v_credential_static_id   VARCHAR2(100);
    v_token_url              VARCHAR2(200);
    v_clob_del               CLOB;

  BEGIN

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

    RETURN v_clob_del;

  END delete_bc_row_f;

  FUNCTION get_ifc_last_processed_date_f ( p_ifc   IN   VARCHAR2 ) RETURN TIMESTAMP IS

    v_last_processed_date   TIMESTAMP;

  BEGIN

    -- print_log ( 'AJC_BC_J_WS_UTILS_PKG.get_ifc_last_processed_date_f (+)');

    SELECT last_processed_date
      INTO v_last_processed_date
      FROM ajc_bc_ifc_control_table
     WHERE ifc = p_ifc; 

    -- print_log ( 'AJC_BC_J_WS_UTILS_PKG.get_ifc_last_processed_date_f (-)');

    RETURN v_last_processed_date;

  EXCEPTION 
    WHEN NO_DATA_FOUND THEN
      -- print_log ( 'AJC_BC_J_WS_UTILS_PKG.get_ifc_last_processed_date_f (!)');
      -- print_log ( 'Se crea el registro en la tabla de control para la ifc ' || p_ifc );

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

    -- print_log ( 'gv_bc_oracle_diff_hours: ' || gv_bc_oracle_diff_hours );

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

    -- print_log ( 'AJC_BC_J_WS_UTILS_PKG.upd_ifc_last_processed_date_p (+)');

    UPDATE ajc_bc_ifc_control_table
       SET last_processed_date = p_last_processed_date,
           request_id = p_request_id
     WHERE ifc = p_ifc;

    -- print_log ( 'AJC_BC_J_WS_UTILS_PKG.upd_ifc_last_processed_date_p (-)');

  END;

END AJC_BC_J_WS_UTILS_PKG;
