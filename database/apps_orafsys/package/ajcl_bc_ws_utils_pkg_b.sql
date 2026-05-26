CREATE OR REPLACE PACKAGE BODY ajcl_bc_ws_utils_pkg AS



  /*

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    fnd_file.put_line (fnd_file.log, p_message);



  END print_log;

  */



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



    v_api   AJCL_BC_APIS.api%TYPE;



  BEGIN



    SELECT api

      INTO v_api

      FROM AJCL_BC_APIS

     WHERE entity = p_entity

       AND DECODE(subentity,NULL,'NULL',subentity) = NVL(p_subentity,'NULL')

       AND DECODE(p_method,'GET',get,'N') = DECODE(p_method,'GET','Y','N')

       AND DECODE(p_method,'POST',post,'N') = DECODE(p_method,'POST','Y','N')

       AND DECODE(p_method,'PATCH',patch,'N') = DECODE(p_method,'PATCH','Y','N')

       AND DECODE(p_method,'DELETE',del,'N') = DECODE(p_method,'DELETE','Y','N');



    RETURN v_api;



  END get_api_f;



  FUNCTION get_lock_process_name_f ( p_integration   IN   VARCHAR2 ) RETURN VARCHAR2 IS



    v_lock_process_name   ajcl_bc_integration_jobs.lock_process_name%TYPE;



  BEGIN



    SELECT lock_process_name

      INTO v_lock_process_name

      FROM ajcl_bc_integration_jobs

     WHERE integration = p_integration;



    RETURN v_lock_process_name;



  END get_lock_process_name_f;



  FUNCTION get_object_id_f ( p_integration   IN   VARCHAR2 ) RETURN NUMBER IS



    v_object_id   AJCL_BC_INTEGRATION_JOBS.object_id%TYPE;



  BEGIN



    SELECT object_id

      INTO v_object_id

      FROM AJCL_BC_INTEGRATION_JOBS

     WHERE integration = p_integration;



    RETURN v_object_id;



  END get_object_id_f;



  PROCEDURE get_api_p ( p_entity                IN   VARCHAR2,

                        p_subentity             IN   VARCHAR2,

                        p_method                IN   VARCHAR2,

                        p_api_name             OUT   VARCHAR2,

                        p_api_publisher        OUT   VARCHAR2,

                        p_api_group            OUT   VARCHAR2,

                        p_api_version          OUT   VARCHAR2 ) IS



  BEGIN



    SELECT api, 

           api_publisher, 

           api_group, 

           api_version

      INTO p_api_name,

           p_api_publisher,

           p_api_group,

           p_api_version

      FROM AJCL_BC_APIS

     WHERE entity = p_entity

       AND DECODE(subentity,NULL,'NULL',subentity) = NVL(p_subentity,'NULL')

       AND DECODE(p_method,'GET',get,'N') = DECODE(p_method,'GET','Y','N')

       AND DECODE(p_method,'POST',post,'N') = DECODE(p_method,'POST','Y','N')

       AND DECODE(p_method,'PATCH',patch,'N') = DECODE(p_method,'PATCH','Y','N')

       AND DECODE(p_method,'DELETE',del,'N') = DECODE(p_method,'DELETE','Y','N');



  END get_api_p;



  FUNCTION get_base_custom_url_f ( p_bc_environment   IN   VARCHAR2,

                                   p_entity           IN   VARCHAR2,

                                   p_subentity        IN   VARCHAR2,

                                   p_method           IN   VARCHAR2,

                                   p_company_id       IN   VARCHAR2 ) RETURN VARCHAR2 IS



    v_api_name          ajcl_bc_apis.api%TYPE;

    v_api_publisher     ajcl_bc_apis.api_publisher%TYPE;

    v_api_group         ajcl_bc_apis.api_group%TYPE;

    v_api_version       ajcl_bc_apis.api_version%TYPE;



    v_base_custom_url   VARCHAR2(300);



  BEGIN



    get_api_p ( p_entity => p_entity,

                p_subentity => p_subentity,

                p_method => p_method, 

                p_api_name => v_api_name,

                p_api_publisher => v_api_publisher,

                p_api_group => v_api_group,

                p_api_version => v_api_version );



    -- print_log ('v_api_name: ' || v_api_name);

    -- print_log ('v_api_publisher: ' || v_api_publisher);

    -- print_log ('v_api_group: ' || v_api_group);

    -- print_log ('v_api_version: ' || v_api_version);



    v_base_custom_url := get_parameter_f ( p_parameter_code => 'BASE_CUSTOM_URL' );



    v_base_custom_url := REPLACE(v_base_custom_url,'$ENV',p_bc_environment);

    v_base_custom_url := REPLACE(v_base_custom_url,'$APIPUBLISHER',v_api_publisher);

    v_base_custom_url := REPLACE(v_base_custom_url,'$APIGROUP',v_api_group);

    v_base_custom_url := REPLACE(v_base_custom_url,'$APIVERSION',v_api_version);

    v_base_custom_url := REPLACE(v_base_custom_url,'$COMPANY_ID',p_company_id);

    v_base_custom_url := REPLACE(v_base_custom_url,'$API',v_api_name);



    RETURN v_base_custom_url;



  END get_base_custom_url_f;   



  FUNCTION get_base_custom_batch_url_f ( p_bc_environment   IN   VARCHAR2,

                                         p_entity           IN   VARCHAR2,

                                         p_subentity        IN   VARCHAR2,

                                         p_method           IN   VARCHAR2,

                                         p_company_id       IN   VARCHAR2 ) RETURN VARCHAR2 IS



    v_api_name                ajcl_bc_apis.api%TYPE;

    v_api_publisher           ajcl_bc_apis.api_publisher%TYPE;

    v_api_group               ajcl_bc_apis.api_group%TYPE;

    v_api_version             ajcl_bc_apis.api_version%TYPE;



    v_base_custom_batch_url   VARCHAR2(300);



  BEGIN



    get_api_p ( p_entity => p_entity,

                p_subentity => p_subentity,

                p_method => p_method, 

                p_api_name => v_api_name,

                p_api_publisher => v_api_publisher,

                p_api_group => v_api_group,

                p_api_version => v_api_version );



    -- print_log ('v_api_name: ' || v_api_name);

    -- print_log ('v_api_publisher: ' || v_api_publisher);

    -- print_log ('v_api_group: ' || v_api_group);

    -- print_log ('v_api_version: ' || v_api_version);



    v_base_custom_batch_url := get_parameter_f ( p_parameter_code => 'BASE_CUSTOM_BATCH_URL' );



    v_base_custom_batch_url := REPLACE(v_base_custom_batch_url,'$ENV',p_bc_environment);

    v_base_custom_batch_url := REPLACE(v_base_custom_batch_url,'$APIPUBLISHER',v_api_publisher);

    v_base_custom_batch_url := REPLACE(v_base_custom_batch_url,'$APIGROUP',v_api_group);

    v_base_custom_batch_url := REPLACE(v_base_custom_batch_url,'$APIVERSION',v_api_version);

    v_base_custom_batch_url := REPLACE(v_base_custom_batch_url,'$COMPANY_ID',p_company_id);



    RETURN v_base_custom_batch_url;



  END get_base_custom_batch_url_f;



  FUNCTION get_base_inecta_url_f ( p_bc_environment   IN   VARCHAR2,

                                   p_entity           IN   VARCHAR2,

                                   p_subentity        IN   VARCHAR2,

                                   p_method           IN   VARCHAR2,

                                   p_company_id       IN   VARCHAR2 ) RETURN VARCHAR2 IS



    v_api_name          ajcl_bc_apis.api%TYPE;

    v_api_publisher     ajcl_bc_apis.api_publisher%TYPE;

    v_api_group         ajcl_bc_apis.api_group%TYPE;

    v_api_version       ajcl_bc_apis.api_version%TYPE;



    v_base_inecta_url   VARCHAR2(300);



  BEGIN



    get_api_p ( p_entity => p_entity,

                p_subentity => p_subentity,

                p_method => p_method, 

                p_api_name => v_api_name,

                p_api_publisher => v_api_publisher,

                p_api_group => v_api_group,

                p_api_version => v_api_version );



    -- print_log ('v_api_name: ' || v_api_name);

    -- print_log ('v_api_publisher: ' || v_api_publisher);

    -- print_log ('v_api_group: ' || v_api_group);

    -- print_log ('v_api_version: ' || v_api_version);



    v_base_inecta_url := get_parameter_f ( p_parameter_code => 'BASE_INECTA_URL' );



    v_base_inecta_url := REPLACE(v_base_inecta_url,'$ENV',p_bc_environment);

    v_base_inecta_url := REPLACE(v_base_inecta_url,'$APIPUBLISHER',v_api_publisher);

    v_base_inecta_url := REPLACE(v_base_inecta_url,'$APIGROUP',v_api_group);

    v_base_inecta_url := REPLACE(v_base_inecta_url,'$APIVERSION',v_api_version);

    v_base_inecta_url := REPLACE(v_base_inecta_url,'$COMPANY_ID',p_company_id);

    v_base_inecta_url := v_base_inecta_url || v_api_name;



    RETURN v_base_inecta_url;



  END get_base_inecta_url_f;   



  FUNCTION get_etag_f ( p_clob_result   CLOB ) RETURN VARCHAR2 IS

  BEGIN



    RETURN REPLACE(SUBSTR(SUBSTR(p_clob_result,INSTR(p_clob_result,'@odata.etag') + 14),1,INSTR(SUBSTR(p_clob_result,INSTR(p_clob_result,'@odata.etag') + 14),',') - 2),'\');



  END;



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



  FUNCTION get_base_standard_url_f ( p_bc_environment   IN   VARCHAR2,

                                     p_api              IN   VARCHAR2,

                                     p_company_id       IN   VARCHAR2 ) RETURN VARCHAR2 IS



    v_base_standard_url   VARCHAR2(300);



  BEGIN



    v_base_standard_url := get_parameter_f ( p_parameter_code => 'BASE_STANDARD_URL' );



    RETURN REPLACE(REPLACE(REPLACE(v_base_standard_url,'$ENV',p_bc_environment),'$API',p_api),'$COMPANY_ID',p_company_id);



  END get_base_standard_url_f;



  -- 20240506

  -- Chequea si el job ejecutado en BC ya termino, sino espera y vuelve a comprobar

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



    -- 20260108 REINTENTO

    gv_retry_in_seconds       NUMBER;

    gv_retry                  VARCHAR2(1);

    -- 20260108 REINTENTO



  BEGIN



    -- 20260108 REINTENTO

    gv_retry_in_seconds := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'POST_RETRY_IN_SECONDS' );

    -- 20260108 REINTENTO



    -- Se obtiene el maximo de segundos a esperar

    BEGIN



      SELECT TO_NUMBER(ajcl_bc_ws_utils_pkg.get_parameter_f ( 'CHECK_JOB_STATUS_TIMEOUT_IN_SECONDS' ))

        INTO v_timeout_seconds

        FROM DUAL;



    EXCEPTION

      WHEN OTHERS THEN

        v_timeout_seconds := 3600;



    END;



    -- Se obtiene los segundos a esperar entre comprobaciones

    BEGIN



      SELECT TO_NUMBER(ajcl_bc_ws_utils_pkg.get_parameter_f ( 'CHECK_JOB_STATUS_EVERY_X_SECONDS' ))

        INTO v_check_every_x_seconds 

        FROM DUAL;



    EXCEPTION

      WHEN OTHERS THEN

        v_check_every_x_seconds := 15;



    END;



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,

                                                          p_entity => 'CHECK JOB STATUS', 

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => p_company_id )

             || '?$filter=objectIDToRun eq ' || p_object_id

             || ' and userID eq ''OAUTH''';    



    DBMS_LOCK.sleep ( seconds => v_check_every_x_seconds );



    -- 20260108 REINTENTO

    gv_retry := 'N';



    BEGIN

    -- 20260108 REINTENTO



      -- Se chequea el status

      v_clob_status := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



      -- 20260108 REINTENTO

      IF ( UPPER(v_clob_status) LIKE UPPER('%502 Bad Gateway%') ) THEN



        gv_retry := 'Y';



      END IF;



    EXCEPTION

      WHEN OTHERS THEN

        gv_retry := 'Y';



    END;



    IF ( gv_retry = 'Y' ) THEN



      DBMS_LOCK.sleep(gv_retry_in_seconds);



      v_clob_status := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



    END IF;

    -- 20260108 REINTENTO  



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



      -- 20260108 REINTENTO

      gv_retry := 'N';



      BEGIN

      -- 20260108 REINTENTO



        v_clob_status := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



        -- 20260108 REINTENTO

        IF ( UPPER(v_clob_status) LIKE UPPER('%502 Bad Gateway%') ) THEN



          gv_retry := 'Y';



        END IF;



      EXCEPTION

        WHEN OTHERS THEN

          gv_retry := 'Y';



      END;



      IF ( gv_retry = 'Y' ) THEN



        DBMS_LOCK.sleep(gv_retry_in_seconds);



        v_clob_status := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



      END IF;

      -- 20260108 REINTENTO  



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

  -- 20240506



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

    -- 20240510



  BEGIN



    -- print_log ( 'ajcl_bc_ws_utils_pkg.run_job_queue_f (+)');



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



    -- print_log ( 'ajcl_bc_ws_utils_pkg.run_job_queue_f (-)');



    RETURN v_clob_result;



  EXCEPTION

    WHEN e_timeout THEN

      RETURN 'ERROR - BC Job status check ended due to timeout.';



  END run_job_queue_f;



  FUNCTION get_bc_clob_result_f ( p_url   IN   VARCHAR2 ) RETURN CLOB IS



    v_credential_static_id   VARCHAR2(100);

    v_token_url              VARCHAR2(200);

    v_clob_result            CLOB;



  BEGIN



    -- print_log ( 'ajcl_bc_ws_utils_pkg.get_bc_clob_result_f (+)');



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



    -- print_log ( 'ajcl_bc_ws_utils_pkg.get_bc_clob_result_f (-)');



    RETURN v_clob_result;



  END get_bc_clob_result_f;  



  FUNCTION patch_post_bc_row_f ( p_url                     IN   VARCHAR2

                                ,p_request_header_name1    IN   VARCHAR2

                                ,p_request_header_value1   IN   VARCHAR2

                                ,p_request_header_name2    IN   VARCHAR2

                                ,p_request_header_value2   IN   VARCHAR2

                                ,p_http_method             IN   VARCHAR2

                                ,p_body                    IN   CLOB ) RETURN CLOB IS



    v_credential_static_id   VARCHAR2(100);

    v_token_url              VARCHAR2(200);

    v_clob_result            CLOB;



  BEGIN



    -- print_log ( 'ajcl_bc_ws_utils_pkg.patch_post_bc_row_f (+)');



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



    -- print_log ( 'ajcl_bc_ws_utils_pkg.patch_post_bc_row_f (-)');



    RETURN v_clob_result;



  END patch_post_bc_row_f;



  FUNCTION delete_bc_row_f ( p_url   IN   VARCHAR2 ) RETURN CLOB IS



    v_credential_static_id   VARCHAR2(100);

    v_token_url              VARCHAR2(200);

    v_clob_del               CLOB;



  BEGIN



    -- print_log ( 'ajcl_bc_ws_utils_pkg.delete_bc_row_f (+)');



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



    -- print_log ( 'ajcl_bc_ws_utils_pkg.delete_bc_row_f (-)');



    RETURN v_clob_del;



  END delete_bc_row_f;



  FUNCTION get_ifc_last_processed_date_f ( p_bc_environment   IN   VARCHAR2,

                                           p_ifc              IN   VARCHAR2 ) RETURN TIMESTAMP IS



    v_last_processed_date   TIMESTAMP;



  BEGIN



    -- print_log ( 'ajcl_bc_ws_utils_pkg.get_ifc_last_processed_date_f (+)');



    SELECT last_processed_date

      INTO v_last_processed_date

      FROM ajcl_bc_ifc_control_table

     WHERE bc_environment = p_bc_environment

       AND ifc = p_ifc; 



    -- print_log ( 'ajcl_bc_ws_utils_pkg.get_ifc_last_processed_date_f (-)');



    RETURN v_last_processed_date;



  EXCEPTION 

    WHEN NO_DATA_FOUND THEN

      -- print_log ( 'ajcl_bc_ws_utils_pkg.get_ifc_last_processed_date_f (!)');

      -- print_log ( 'Se crea el registro en la tabla de control para la ifc ' || p_ifc );



      v_last_processed_date := systimestamp;



      INSERT 

        INTO ajcl_bc_ifc_control_table 

             ( bc_environment,

               ifc,

               last_processed_date )

      VALUES ( p_bc_environment,

               p_ifc,

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



  END get_bc_last_processed_date_f;



  PROCEDURE upd_ifc_last_processed_date_p ( p_bc_environment        IN   VARCHAR2,

                                            p_ifc                   IN   VARCHAR2,

                                            p_request_id            IN   NUMBER,

                                            p_last_processed_date   IN   TIMESTAMP ) IS

  BEGIN



    -- print_log ( 'ajcl_bc_ws_utils_pkg.upd_ifc_last_processed_date_p (+)');



    UPDATE ajcl_bc_ifc_control_table

       SET last_processed_date = p_last_processed_date,

           request_id = p_request_id

     WHERE bc_environment = p_bc_environment

       AND ifc = p_ifc;



    -- print_log ( 'ajcl_bc_ws_utils_pkg.upd_ifc_last_processed_date_p (-)');



  END upd_ifc_last_processed_date_p;



  FUNCTION check_vendor_exists_bc_p ( p_bc_environment   IN   VARCHAR2,

                                      p_company_id       IN   VARCHAR2,

                                      p_no               IN   VARCHAR2 ) RETURN VARCHAR2 IS



    v_url           VARCHAR2(2000);

    v_clob_result   CLOB;

    v_exists        VARCHAR2(1) := 'N';



  BEGIN



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,

                                                          p_entity => 'VENDORS',

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => p_company_id )

             || '?$filter=vendorno eq ''' || p_no || '''';



    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



    BEGIN



      SELECT 'Y'

        INTO v_exists

        FROM json_table( v_clob_result,

                         '$.value[*]' COLUMNS ( no VARCHAR2(4000)  path '$.vendorno' ) );



    EXCEPTION

      WHEN OTHERS THEN

        NULL;

    END;



    RETURN v_exists;



  END check_vendor_exists_bc_p;



  FUNCTION check_customer_exists_bc_p ( p_bc_environment   IN   VARCHAR2,

                                        p_company_id       IN   VARCHAR2,

                                        p_no               IN   VARCHAR2 ) RETURN VARCHAR2 IS



    v_url           VARCHAR2(2000);

    v_clob_result   CLOB;

    v_exists        VARCHAR2(1) := 'N';



  BEGIN



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,

                                                          p_entity => 'CUSTOMERS', 

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => p_company_id )

             || '?$filter=no eq ''' || p_no || '''';



    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



    BEGIN



      SELECT 'Y'

        INTO v_exists

        FROM json_table( v_clob_result,

                         '$.value[*]' COLUMNS ( no VARCHAR2(4000)  path '$.no' ) );



    EXCEPTION

      WHEN OTHERS THEN

        NULL;

    END;



    RETURN v_exists;



  END check_customer_exists_bc_p;



END ajcl_bc_ws_utils_pkg;
