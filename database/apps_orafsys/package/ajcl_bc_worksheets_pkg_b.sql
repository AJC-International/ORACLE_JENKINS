PACKAGE BODY ajcl_bc_worksheets_pkg IS
  
  -- 20251219 REINTENTO
  gv_retry_in_seconds              NUMBER;
  gv_retry                         VARCHAR2(1);
  -- 20251219 REINTENTO

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    gv_log_seq := gv_log_seq + 1;
    ajcl_bc_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );

  END print_log;

  /*=========================================================================+
  |                                                                          |
  | Private Procedure                                                        |
  |    send_email                                                            |
  |                                                                          |
  | Description                                                              |
  |    Envio de reporte por mail                                             |
  |                                                                          |
  | Parameters                                                               |
  |                                                                          |
  +=========================================================================*/

  PROCEDURE send_email ( p_request_id   IN   NUMBER,
                         p_mail         IN   VARCHAR2 ) IS

    v_rejected_count   NUMBER;
    v_success_count    NUMBER;

    v_subject          VARCHAR2(2000) := 'AJCL BC Worksheets Interface - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS');
    v_message          VARCHAR2(2000);

  BEGIN

    print_log ( 'ajcl_bc_worksheets_pkg.send_email (+)' );

    -- Se obtiene la cantidad de worksheet SUCCESS   
    SELECT COUNT(1)
      INTO v_success_count
      FROM ajcl_bc_worksheets
     WHERE request_id = gv_request_id
       AND status = 'SUCCESS';

    print_log ( 'SUCCESS: ' || v_success_count );

    -- Se obtiene la cantidad de worksheet REJECTED
    SELECT COUNT(1)
      INTO v_rejected_count
      FROM ajcl_bc_worksheets
     WHERE request_id = gv_request_id
       AND status IN ('REJECTED','ERROR');

    print_log ( 'REJECTED: ' || v_rejected_count );

    v_message := 'Worksheets procesados con éxito: ' || v_success_count || CHR(13) || CHR(10);
    v_message := v_message || 'Worksheets rechazados / con error: ' || v_rejected_count || CHR(13) || CHR(10) || CHR(13) || CHR(10);

    print_log ( 'To: ' || p_mail );
    print_log ( 'Subject: ' || v_subject );
    print_log ( 'Message: ' || v_message );

    ajcl_bc_utils_pkg.send_email_p ( p_to => p_mail,
                                     p_subject => v_subject,
                                     p_message => v_message );

    print_log ( 'ajcl_bc_worksheets_pkg.send_email (-)' );

  EXCEPTION
    WHEN others THEN
      print_log ( 'ajcl_bc_worksheets_pkg.send_email (!). Error: ' || SQLERRM );

  END send_email;

  FUNCTION insert_p ( p_ws_ies_num       IN    VARCHAR2,
                      p_bc_environment   IN    VARCHAR2 ) RETURN NUMBER IS

    v_exists        VARCHAR2(1);
    v_description   VARCHAR2(50);

  BEGIN

   -- Verifica si ya fue insertado y enviado satisfactoriamente
   SELECT DECODE(COUNT(1),0,'N','Y')
     INTO v_exists 
     FROM ajcl_bc_worksheets
    WHERE ws_ies_num = p_ws_ies_num
      AND UPPER(bc_environment) = UPPER(p_bc_environment)
      AND status = 'SUCCESS';

   IF ( v_exists = 'N' ) THEN

     -- Se intenta obtener la description de la tabla de worksheets
     BEGIN

       SELECT REPLACE(SUBSTR(description,1,50),'"','')
         INTO v_description
         FROM ajc_worksheet_ies_num
        WHERE ws_ies_num = p_ws_ies_num;

     EXCEPTION
       WHEN OTHERS THEN
         v_description := NULL;

     END;

        INSERT
          INTO ajcl_bc_worksheets
             ( ws_ies_num,
               description,
               bc_environment,
               status,
               creation_date )
      VALUES ( p_ws_ies_num,
               v_description,
               p_bc_environment,
               'NEW',
               SYSDATE );

      COMMIT;

      RETURN 1;

    ELSE

      RETURN 0;

    END IF;

  END insert_p;           

  PROCEDURE main_p ( p_bc_environment     IN   VARCHAR2,
                     p_bc_company_id      IN   VARCHAR2,
                     p_bc_ifc             IN   VARCHAR2,
                     p_request_id         IN   NUMBER,
                     p_log_seq        IN OUT   NUMBER,
                     p_status            OUT   VARCHAR2 ) IS

    CURSOR c_ws IS 
    SELECT ws_ies_num dimValueCode,
           description dimValueName
      FROM ajcl_bc_worksheets
     WHERE status = 'NEW'
       AND request_id IS NULL
       AND bc_environment = p_bc_environment;

    -- 20251103
    -- Reintento de envios fallidos
    CURSOR c_ws_reprocess IS 
    SELECT ws_ies_num dimValueCode,
           description dimValueName
      FROM ajcl_bc_worksheets
     WHERE ( status = 'ERROR' OR ( status = 'SENT' AND UPPER(json_data_response) LIKE UPPER('%502 Bad Gateway%') ) )
       AND request_id = p_request_id
       AND bc_environment = p_bc_environment;
    -- 20251103

    v_email                 VARCHAR2(2000);

    v_url                   VARCHAR2(2000); 
    v_body                  VARCHAR2(2000);
    v_clob_result           CLOB;
    v_clob_job_result       CLOB;

    v_get_url               VARCHAR2(500);
    v_clob_result_status    CLOB;

    v_delete_url            VARCHAR2(2000);
    v_clob_delete_result    CLOB;

    v_worksheet_status      VARCHAR2(20);

    v_count                 NUMBER := 0;

    v_job_object_id         NUMBER;
    v_job_status            VARCHAR2(20);
    v_job_message           VARCHAR2(60);

    e_job_error             EXCEPTION;
    v_conc_status           BOOLEAN;

    CURSOR c_status ( p_clob_result_status   IN   CLOB ) IS
    SELECT dimValueCode,
           status,
           StatusRemarks
      FROM json_table( p_clob_result_status,
                       '$.value[*]' COLUMNS ( dimValueCode     VARCHAR2(4000) path '$.dimValueCode',
                                              status           VARCHAR2(4000) path '$.status' ,
                                              StatusRemarks    VARCHAR2(4000) path '$.statusRemarks',
                                              requestID        VARCHAR2(4000) path '$.requestID'));

    -- 20240909
    v_continue              VARCHAR2(1);
    v_start                 DATE;
    v_elapsed_seconds       NUMBER;
    v_timeout_seconds       NUMBER := 1800; -- 30 minutos
    -- 20240909

  BEGIN

    gv_request_id := p_request_id;
    gv_bc_ifc := p_bc_ifc;
    gv_log_seq := p_log_seq;

    print_log ( 'ajcl_bc_worksheets_pkg.main_p (+)' );

    v_email := ajcl_bc_utils_pkg.get_emails_f ( 'WORKSHEETS' );
    print_log ( 'v_email: ' || v_email );

    gv_process_name := ajcl_bc_ws_utils_pkg.get_lock_process_name_f ( p_integration => 'WORKSHEETS' );
    print_log ( 'gv_process_name: ' || gv_process_name );

    -- 20251219 REINTENTO
    gv_retry_in_seconds := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'POST_RETRY_IN_SECONDS' );
    print_log ( 'POST_RETRY_IN_SECONDS: ' || gv_retry_in_seconds );    
    -- 20251219 REINTENTO

    -- Lock & Release
    ajc_bc_dbms_lock_pkg.lock_p ( p_process_name => gv_process_name,
                                  p_id_lock => gv_id_lock,
                                  p_request_status => gv_request_status ); 

    IF ( gv_request_status != 'success' ) THEN

      RAISE ge_lock;

    END IF;
    -- Lock & Release

    v_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => p_bc_environment, 
                                                          p_entity => 'WORKSHEETS',
                                                          p_subentity => NULL,
                                                          p_method => 'POST',
                                                          p_company_id => p_bc_company_id );

    print_log ( 'v_url: ' || v_url );

    -- 20240909
    -- Se verifica si el concurrente AJC BC Worksheets Interface (FOODS) esta por correr o corriendo
    -- En tal caso, se espera hasta que termine
    BEGIN

      v_continue := 'N';
      print_log ( 'Checks if AJC BC Worksheets Interface is running or is about to be executed.' );
      v_start := SYSDATE;

      WHILE ( v_continue = 'N' ) LOOP

        SELECT DECODE(COUNT(1),0,'Y','N')
          INTO v_continue
          FROM fnd_concurrent_requests r,
               fnd_concurrent_programs_vl p
         WHERE r.concurrent_program_id = p.concurrent_program_id
           AND p.user_concurrent_program_name = 'AJC BC Worksheets Interface'
           AND ( ( r.phase_code = 'R' ) or -- Running
                 ( r.phase_code = 'P' and r.status_code = 'I' ) ); -- Pending | Inactive | Está por correr

        IF ( v_continue = 'N' ) THEN

          print_log ( 'AJC BC Worksheets Interface request is running or is about to be executed. Wait 1 minute.' );
          DBMS_LOCK.SLEEP(60);

        END IF;

        v_elapsed_seconds := TRUNC( ( SYSDATE - v_start ) * 24 * 60 * 60 );

        -- Si se supero el timeout, se sigue
        IF ( v_elapsed_seconds > v_timeout_seconds ) THEN

          v_continue := 'Y';

        END IF;

      END LOOP;

    END;
    -- 20240909

    FOR cws IN c_ws LOOP

      v_body := '{"requestID":"' || gv_request_id || '",' ||
                 '"dimValueCode":"' || cws.dimValueCode || '",' ||
                 '"dimValueName":"' || cws.dimValueName || '",' ||
                 '"blocked":false}';

      -- Se envia el worksheet a BC --------------------------------------------------------------------------------------------
      -- 20251219 REINTENTO
      gv_retry := 'N';

      BEGIN
      -- 20251219 REINTENTO

        v_clob_result := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url
                                                                   ,p_request_header_name1 => 'Content-Type'
                                                                   ,p_request_header_value1 => 'application/json'
                                                                   ,p_request_header_name2 => NULL
                                                                   ,p_request_header_value2 => NULL
                                                                   ,p_http_method => 'POST'
                                                                   ,p_body => v_body );  

        -- 20251219 REINTENTO
        IF ( UPPER(v_clob_result) LIKE UPPER('%502 Bad Gateway%') ) THEN

          print_log('502 Bad Gateway'); 
          gv_retry := 'Y';

        END IF;

      EXCEPTION
        WHEN OTHERS THEN
          print_log('Error calling ajcl_bc_ws_utils_pkg.get_bc_clob_result_f: ' || SQLCODE || '|' || SQLERRM ); 
          gv_retry := 'Y';

      END;

      IF ( gv_retry = 'Y' ) THEN

        print_log( 'Connection error detected. Retrying in ' || gv_retry_in_seconds || ' seconds.' );
        DBMS_LOCK.sleep(gv_retry_in_seconds);

        v_clob_result := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url
                                                                   ,p_request_header_name1 => 'Content-Type'
                                                                   ,p_request_header_value1 => 'application/json'
                                                                   ,p_request_header_name2 => NULL
                                                                   ,p_request_header_value2 => NULL
                                                                   ,p_http_method => 'POST'
                                                                   ,p_body => v_body );  

      END IF;
      -- 20251219 REINTENTO 

      IF ( INSTR(v_clob_result,'error') != 0 ) THEN

        print_log ( 'WS: ' || cws.dimValueCode || ' - Error: ' || v_clob_result );
        v_worksheet_status := 'ERROR';

      ELSE

        print_log ( 'WS: ' || cws.dimValueCode || ' - Sent.' );
        v_worksheet_status := 'SENT';

      END IF;

      v_count := v_count + 1;

      UPDATE ajcl_bc_worksheets
         SET json_data = v_body,
             json_data_response = v_clob_result,
             status = v_worksheet_status, 
             request_id = gv_request_id
       WHERE ws_ies_num = cws.dimValueCode
         AND status = 'NEW'
         AND request_id IS NULL;

    END LOOP;

    -- 20251103
    -- Reintento de envios fallidos
    FOR cws IN c_ws_reprocess LOOP

      print_log ( 'Inicio reintento envío ws ' || cws.dimValueCode );    

      v_body := '{"requestID":"' || gv_request_id || '",' ||
                 '"dimValueCode":"' || cws.dimValueCode || '",' ||
                 '"dimValueName":"' || cws.dimValueName || '",' ||
                 '"blocked":false}';

      -- Se envia el worksheet a BC --------------------------------------------------------------------------------------------
      -- 20251219 REINTENTO
      gv_retry := 'N';

      BEGIN
      -- 20251219 REINTENTO

        v_clob_result := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url
                                                                   ,p_request_header_name1 => 'Content-Type'
                                                                   ,p_request_header_value1 => 'application/json'
                                                                   ,p_request_header_name2 => NULL
                                                                   ,p_request_header_value2 => NULL
                                                                   ,p_http_method => 'POST'
                                                                   ,p_body => v_body );  

        -- 20251219 REINTENTO
        IF ( UPPER(v_clob_result) LIKE UPPER('%502 Bad Gateway%') ) THEN

          print_log('502 Bad Gateway'); 
          gv_retry := 'Y';

        END IF;

      EXCEPTION
        WHEN OTHERS THEN
          print_log('Error calling ajcl_bc_ws_utils_pkg.get_bc_clob_result_f: ' || SQLCODE || '|' || SQLERRM ); 
          gv_retry := 'Y';

      END;

      IF ( gv_retry = 'Y' ) THEN

        print_log( 'Connection error detected. Retrying in ' || gv_retry_in_seconds || ' seconds.' );
        DBMS_LOCK.sleep(gv_retry_in_seconds);

        v_clob_result := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url
                                                                   ,p_request_header_name1 => 'Content-Type'
                                                                   ,p_request_header_value1 => 'application/json'
                                                                   ,p_request_header_name2 => NULL
                                                                   ,p_request_header_value2 => NULL
                                                                   ,p_http_method => 'POST'
                                                                   ,p_body => v_body ); 

      END IF;
      -- 20251219 REINTENTO 

      IF ( INSTR(v_clob_result,'error') != 0 ) THEN

        print_log ( 'WS: ' || cws.dimValueCode || ' - Error: ' || v_clob_result );
        v_worksheet_status := 'ERROR';

      ELSE

        print_log ( 'WS: ' || cws.dimValueCode || ' - Sent.' );
        v_worksheet_status := 'SENT';

      END IF;

      UPDATE ajcl_bc_worksheets
         SET json_data = v_body,
             json_data_response = v_clob_result,
             status = v_worksheet_status
       WHERE ws_ies_num = cws.dimValueCode
         AND ( status = 'ERROR' OR ( status = 'SENT' AND UPPER(json_data_response) LIKE UPPER('%502 Bad Gateway%') ) )
         AND request_id = gv_request_id
         AND bc_environment = p_bc_environment;

      print_log ( 'Fin reintento envío ws ' || cws.dimValueCode );    

    END LOOP;
    -- 20251103

    -- Si se envio al menos un worksheet
    IF ( v_count > 0 ) THEN

      v_job_object_id := ajcl_bc_ws_utils_pkg.get_object_id_f ( p_integration => 'WORKSHEETS' );

      print_log ( 'Job execution, object_id: ' || v_job_object_id );

      v_clob_job_result := ajcl_bc_ws_utils_pkg.run_job_queue_f ( p_bc_environment => p_bc_environment,
                                                                  p_company_id => p_bc_company_id,
                                                                  p_object_id => v_job_object_id );

      print_log ( 'v_clob_job_result: ' || v_clob_job_result );

      IF ( INSTR(UPPER(v_clob_job_result),'ERROR') = 0 ) THEN 

        v_job_message := 'Job was executed successfully';
        print_log ( 'Job ProcessDimensionValuesAJC_INE was executed successfully.' );
        v_job_status := 'SUCCESS';

      ELSE

        v_job_message := 'Error executing job ProcessDimensionValuesAJC_INE.';
        print_log ( 'Error executing job ProcessDimensionValuesAJC_INE.' );
        v_job_status := 'ERROR';

      END IF;

      -- Se inserta registro de control ------------------------------------------------------------------------------------
        INSERT 
          INTO ajcl_bc_worksheet_control
             ( request_id,
               count,
               bc_environment,
               status,
               job_response,
               creation_date )
      VALUES ( gv_request_id,
               v_count,
               p_bc_environment,
               v_job_status,
               v_clob_job_result,
               SYSDATE );

      -- Se consultan los registros enviados y procesados por el job -------------------------------------------------------------
      print_log ( 'Checking status of worksheets sent and processed by the job.' );

      DBMS_LOCK.SLEEP(60);

      v_get_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => p_bc_environment, 
                                                                p_entity => 'WORKSHEETS',
                                                                p_subentity => NULL,
                                                                p_method => 'GET',
                                                                p_company_id => p_bc_company_id )
                   || '?$filter=requestID eq ' || gv_request_id;

      print_log ( 'v_get_url: ' || v_get_url );

      -- 20251219 REINTENTO
      gv_retry := 'N';

      BEGIN
      -- 20251219 REINTENTO

        v_clob_result_status := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );

        -- 20251219 REINTENTO
        IF ( UPPER(v_clob_result_status) LIKE UPPER('%502 Bad Gateway%') ) THEN

          print_log('502 Bad Gateway'); 
          gv_retry := 'Y';

        END IF;

      EXCEPTION
        WHEN OTHERS THEN
          print_log('Error calling ajcl_bc_ws_utils_pkg.get_bc_clob_result_f: ' || SQLCODE || '|' || SQLERRM ); 
          gv_retry := 'Y';

      END;

      IF ( gv_retry = 'Y' ) THEN

        print_log( 'Connection error detected. Retrying in ' || gv_retry_in_seconds || ' seconds.' );
        DBMS_LOCK.sleep(gv_retry_in_seconds);

        v_clob_result_status := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );

      END IF;
      -- 20251219 REINTENTO 

      -- Se arma la url parcial de borrado ---------------------------------------------------------------------------------------
      v_delete_url := v_url || '(' || gv_request_id || ')';
      print_log ( 'v_delete_url: ' || v_delete_url );

      -- Se consultan los estados de lo enviado ----------------------------------------------------------------------------------
      FOR cs IN c_status ( v_clob_result_status ) LOOP

        print_log ( 'WS: ' || cs.dimValueCode || ' | Status: ' || cs.status );

        IF ( UPPER(cs.status) != 'SUCCESS' ) THEN

          UPDATE ajcl_bc_worksheets
             SET status = 'REJECTED',
                 error_message = cs.statusRemarks
           WHERE request_id = gv_request_id
             AND ws_ies_num = cs.dimValueCode;

          -- Se borra el worksheet rechazadoo ------------------------------------------------------------------------------------
          v_clob_delete_result := ajcl_bc_ws_utils_pkg.delete_bc_row_f ( v_delete_url || '?$filter=dimValueCode eq ''' || 
                                  cs.dimValueCode || '''' ); 

          print_log ( 'Deleted.' );

        ELSE

          UPDATE ajcl_bc_worksheets
             SET status = 'SUCCESS'
           WHERE request_id = gv_request_id
             AND ws_ies_num = cs.dimValueCode;

          print_log ( 'Processed.' );

        END IF;

      END LOOP;

      -- Si el job no se pudo ejecutar, se actualizan todos los worksheets con el mensaje de error
      IF ( v_job_status = 'ERROR' ) THEN

        UPDATE ajcl_bc_worksheets
           SET error_message = v_job_message
         WHERE request_id = gv_request_id;

        RAISE e_job_error;

      END IF;

      COMMIT;

    ELSE

      print_log ( 'No worksheets to process.' );

    END IF;

    -- Si se envio al menos un worksheet, se envia el mail
    IF ( v_count > 0 ) THEN

      print_log ( 'Se envía el mail con el detalle.' );
      -- Se comenta para que no lleguen tantos mails en las pruebas 
      -- send_email ( gv_request_id, v_email );
      --

    ELSE

      print_log ( 'No workshet has been sent.' );

    END IF;

    p_status := 'S';

    print_log ( 'ajcl_bc_worksheets_pkg.main_p (-)' );
    p_log_seq := gv_log_seq;

    -- Lock & Release
    ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,
                                     p_release_status => gv_release_status );

    IF ( gv_release_status != 'success' ) THEN

      RAISE ge_release;

    END IF;                                     
    -- Lock & Release

  EXCEPTION
    -- Lock & Release
    WHEN ge_lock THEN
      print_log ('Error trying to lock the process: ' || gv_process_name || ' | gv_request_status: ' || gv_request_status);
      p_status := 'E';
      p_log_seq := gv_log_seq;
    WHEN ge_release THEN
      print_log ('Error trying to release the process: ' || gv_process_name || ' | gv_release_status: ' || gv_release_status);
      p_status := 'E';
      p_log_seq := gv_log_seq;
    -- Lock & Release

    WHEN e_job_error THEN
      print_log ( 'ajcl_bc_worksheets_pkg.main_p (!) | ' || v_job_status );
      p_status := 'E';
      p_log_seq := gv_log_seq;

      -- Lock & Release
      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,
                                       p_release_status => gv_release_status );
      -- Lock & Release

    WHEN OTHERS THEN
      print_log ( 'ajcl_bc_worksheets_pkg.main_p (!) | ' || SQLERRM );
      p_status := 'E';
      p_log_seq := gv_log_seq;

      -- Lock & Release
      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,
                                       p_release_status => gv_release_status );
      -- Lock & Release

  END main_p;

END ajcl_bc_worksheets_pkg;
