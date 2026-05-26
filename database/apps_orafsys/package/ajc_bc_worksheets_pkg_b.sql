PACKAGE BODY ajc_bc_worksheets_pkg IS

  /*=========================================================================+
  |                                                                          |
  | Private Procedure                                                        |
  |    print_log                                                             |
  |                                                                          |
  | Description                                                              |
  |    Impresion de log                                                      |
  |                                                                          |
  | Parameters                                                               |
  |    p_message                   IN     NUMBER    Mensaje.                 |
  |                                                                          |
  +=========================================================================*/
  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line (fnd_file.log, p_message);

  END print_log;

  /*=========================================================================+
  |                                                                          |
  | Private Procedure                                                        |
  |    print_output                                                          |
  |                                                                          |
  | Description                                                              |
  |    Impresion de output                                                   |
  |                                                                          |
  | Parameters                                                               |
  |    p_message                   IN     NUMBER    Mensaje.                 |
  |                                                                          |
  +=========================================================================*/

  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line(fnd_file.output,p_message);

  END print_output;

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

    v_subject          VARCHAR2(2000) := 'AJC BC Worksheets Interface - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS');
    v_message          VARCHAR2(2000);

  BEGIN

    print_log ('ajc_bc_worksheets_pkg.send_email (+)');

    -- Se obtiene la cantidad de worksheet SUCCESS   
    SELECT COUNT(1)
      INTO v_success_count
      FROM ajc_bc_worksheets
     WHERE request_id = gv_request_id
       AND status = 'SUCCESS';

    print_log ( 'SUCCESS: ' || v_success_count );

    -- Se obtiene la cantidad de worksheet REJECTED
    SELECT COUNT(1)
      INTO v_rejected_count
      FROM ajc_bc_worksheets
     WHERE request_id = gv_request_id
       AND status IN ('REJECTED','ERROR');

    print_log ( 'REJECTED: ' || v_rejected_count );

    v_message := 'Worksheets procesados con éxito: ' || v_success_count || CHR(13) || CHR(10);
    v_message := v_message || 'Worksheets rechazados / con error: ' || v_rejected_count || CHR(13) || CHR(10) || CHR(13) || CHR(10);
    v_message := v_message || 'Para mayor detalle, revise el output del request ' || p_request_id || '.';

    print_log ( 'To: ' || p_mail );
    print_log ( 'Subject: ' || v_subject );
    print_log ( 'Message: ' || v_message );

    ajc_bc_ws_utils_pkg.send_email ( p_to => p_mail
                                    ,p_subject => v_subject
                                    ,p_message => v_message );

    print_log ('ajc_bc_worksheets_pkg.send_email (-)');    

  EXCEPTION
    WHEN others THEN
      print_log ( 'ajc_bc_worksheets_pkg.send_email (!)' );  
      print_log ( 'Error: ' || SQLERRM );

  END send_email;

  PROCEDURE print_report_p IS

      CURSOR c_worksheets IS
      SELECT ws_ies_num,  
             bc_company_name,
             status,
             error_message
        FROM ajc_bc_worksheets
       WHERE request_id = gv_request_id
    ORDER BY ws_ies_num;

  BEGIN

    print_output ( 'AJC Worksheets to BC' );
    print_output ( ' ' );

    print_output ( RPAD('Worksheet Number',16,' ') || ' | ' ||
                   RPAD('BC Company Name',15,' ') || ' | ' ||
                   RPAD('Status',10,' ') || ' | ' ||
                   RPAD('Message',60,' ') );

    print_output ( RPAD('-',110,'-') );

    FOR cw IN c_worksheets LOOP

      print_output ( RPAD(cw.ws_ies_num,16,' ') || ' | ' ||
                     RPAD(cw.bc_company_name,15,' ') || ' | ' ||
                     RPAD(cw.status,10,' ') || ' | ' ||
                     RPAD(cw.error_message,60,' ') );

    END LOOP;

  END print_report_p;

  PROCEDURE main_p ( retcode             OUT   NUMBER,
                     errbuf              OUT   VARCHAR2,
                     p_bc_environment     IN   VARCHAR2,
                     p_worksheet_number   IN   VARCHAR2 ) IS

      CURSOR c_companies IS
      SELECT bc_company_name,
             bc_company_id
        FROM ajc_bc_companies
       -- 20251017
       WHERE bc_company_name IN ('FOODS-CHE-USD',
                                 'FOODS-HKG-HKD',
                                 'FOODS-USA-USD',
                                 'FOODS-CHN-CNY')
       -- 20251017
    GROUP BY bc_company_name,
             bc_company_id
    ORDER BY bc_company_name;

    -- 20251017
    -- CURSOR c_ws ( p_bc_company_id   VARCHAR2 ) IS 
    -- NUEVO
    CURSOR c_ws ( p_bc_company_id        IN   VARCHAR2,
                  p_min_set_wrksht_num   IN   VARCHAR2 ) IS 
    -- 20251017
    SELECT ws_ies_num dimValueCode,
           REPLACE(SUBSTR(description,1,50),'"','') dimValueName,
           bcc.bc_company_name
      FROM ajc_worksheet_ies_num a
          ,worksheet w
          ,company c
          ,ajc_bc_companies bcc
     WHERE LENGTH(regexp_replace(ws_ies_num, '[0-9]', '')) IS NULL
       AND creation_date IS NOT NULL
       AND LENGTH(ws_ies_num) >= 7 
       -- 20251017
       /*
       AND -- 20221229
           ( 
           -- 20221229
           ws_ies_num >= ( SELECT MIN(TO_CHAR(set_wrksht_num)) 
                             FROM inventory_value
                            -- 20221229
                            WHERE p_worksheet_number IS NULL 
                            -- 20221229
                            -- 20231128
                            AND set_wrksht_num >= 2602630
                            -- 20231128
                         ) 
           -- 20221229
           OR ws_ies_num = p_worksheet_number )
           -- 20221229
       */
       -- NUEVO
       AND ( ( p_worksheet_number IS NULL AND ws_ies_num >= p_min_set_wrksht_num ) OR
             ( p_worksheet_number IS NOT NULL AND ws_ies_num = p_worksheet_number ) )
       -- 20251017
       -- Aun no fue enviado
       AND NOT EXISTS ( SELECT 1 
                          FROM ajc_bc_worksheets b
                         WHERE a.ws_ies_num = b.ws_ies_num
                           -- 20230206 -- Se agrega para reenviar lo que no terminaron en SUCCESS (los que terminaron en ERROR o REJECTED)
                           AND status = 'SUCCESS'
                           -- 20230206
                           -- 20230719
                           -- Se agrega para que verifique si no se envio a la compania que intenta enviarlo, porque es posible
                           -- que un worksheet se envie a una compania, luego cambie su compania y tenga que enviarse a la nueva
                           -- Sin esta validacion si lo envia a CHN y luego cambia a USA, solo lo envia a CHN y no lo levanta porque ya lo envio (sin importa a que compania lo envio)
                           AND NVL(bc_company_name,bcc.bc_company_name) = bcc.bc_company_name
                           -- 20230719
                         )
       -- Permite determinar la compañía del worksheet y solo levantar los de la compañía que se pasa como parametro
       AND w.co_tk_org = c.tk_org
       AND w.set_wrksht_num = a.ws_ies_num
       AND c.co_gl_subacct = bcc.oracle_company_number
       AND bcc.bc_company_id = p_bc_company_id
       AND w.set_wrksht_seq = ( SELECT MAX(set_wrksht_seq)
                                  FROM worksheet ws
                                 WHERE ws.set_wrksht_num = a.ws_ies_num );

    v_email                 VARCHAR2(2000);

    v_url                   VARCHAR2(2000); 
    -- 20230414 v_api                   VARCHAR2(100) := 'inboundDimensionValuesINE';
    v_api                   VARCHAR2(100);
    v_body                  VARCHAR2(2000);
    v_clob_result           CLOB;
    v_clob_job_result       CLOB;

    -- 20230414 v_api_status            VARCHAR2(100) := 'inboundDimensionValuesINE';
    v_api_status            VARCHAR2(100);
    v_get_url               VARCHAR2(500);
    v_clob_result_status    CLOB;

    v_delete_url            VARCHAR2(2000);
    v_clob_delete_result    CLOB;

    v_worksheet_status      VARCHAR2(20);

    v_count                 NUMBER := 0;
    v_all_companies_count   NUMBER := 0;

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

    -- 20251017 NUEVO
    v_min_set_wrksht_num   VARCHAR2(200);
    -- 20251017

  BEGIN

    print_log ( 'ajc_bc_worksheets_pkg.main_p (+)');
    print_log ( ' ' );

    v_email := ajc_bc_ws_utils_pkg.get_emails_f ( 'WORKSHEETS' );
    print_log ( 'v_email: ' || v_email );
    print_log ( 'p_worksheet_number: ' || p_worksheet_number );

    v_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'WORKSHEETS',
                                             p_subentity => NULL,
                                             p_method => 'POST' );
    print_log ( 'v_api: ' || v_api );

    v_api_status := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'WORKSHEETS',
                                                    p_subentity => NULL,
                                                    p_method => 'GET' ) ;                                             
    print_log ( 'v_api_status: ' || v_api_status );

    -- 20230712
    -- Se insertan en la tabla ajc_worksheet_ies_num los worksheets validados que no existen en la misma
    BEGIN

      INSERT 
        INTO ajc_worksheet_ies_num
           ( ws_ies_num,
             description,
             created_by,
             creation_date,
             last_updated_by,
             last_update_date )
      SELECT ws_num,
             description,
             0 created_by, -- SYSADMIN
             SYSDATE creation_date,
             0 last_updated_by, -- SYSADMIN
             SYSDATE last_update_date
       FROM ajc_validate_worksheet a
      WHERE NOT EXISTS ( SELECT 1
                           FROM ajc_worksheet_ies_num
                          WHERE a.ws_num = ws_ies_num );

      COMMIT;

    END;    
    -- 20230712

    -- 20251017
    -- Se calcula por unica vez
    print_log ( '- Calculo v_min_set_wrksht_num - Inicio ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') );

    -- NUEVO
    SELECT MIN(TO_CHAR(set_wrksht_num)) 
      INTO v_min_set_wrksht_num
      FROM inventory_value
     WHERE set_wrksht_num >= 2602630;

    print_log ( 'v_min_set_wrksht_num: ' || v_min_set_wrksht_num );

    print_log ( '- Calculo v_min_set_wrksht_num - Fin ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') );    
    -- 20251017

    FOR cc IN c_companies LOOP

      v_count := 0;

      print_log ( ' ' );
      print_log ( 'BC Company Name: ' || cc.bc_company_name || ' | BC Company ID: ' || cc.bc_company_id );

      v_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, cc.bc_company_id ) || v_api;

      print_log ( 'v_url: ' || v_url);

      -- 20251017
      -- FOR cws IN c_ws ( cc.bc_company_id ) LOOP
      -- NUEVO
      FOR cws IN c_ws ( cc.bc_company_id, v_min_set_wrksht_num ) LOOP
      -- 20251017

        v_body := '{"requestID":"' || gv_request_id || '",' ||
                   '"dimValueCode":"' || cws.dimValueCode || '",' ||
                   '"dimValueName":"' || cws.dimValueName || '",' ||
                   '"blocked":false}';

        -- Se envia el worksheet a BC --------------------------------------------------------------------------------------------
        v_clob_result := ajc_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url
                                                                  ,p_request_header_name1 => 'Content-Type'
                                                                  ,p_request_header_value1 => 'application/json'
                                                                  ,p_request_header_name2 => NULL
                                                                  ,p_request_header_value2 => NULL
                                                                  ,p_http_method => 'POST'
                                                                  ,p_body => v_body );  

        IF ( INSTR(v_clob_result,'error') != 0 ) THEN
          print_log ( 'WS: ' || cws.dimValueCode || ' - Error: ' || v_clob_result);
          v_worksheet_status := 'ERROR';

        ELSE

          print_log ( 'WS: ' || cws.dimValueCode || ' - Sent.');
          v_worksheet_status := 'SENT';

        END IF;

        v_count := v_count + 1;
        v_all_companies_count := v_all_companies_count + 1;

        INSERT 
          INTO ajc_bc_worksheets
               ( ws_ies_num,
                 bc_company_name,
                 status,
                 json_data,
                 json_data_response,
                 creation_date,
                 request_id )
        VALUES ( cws.dimValueCode,
                 cc.bc_company_name,
                 v_worksheet_status,
                 v_body,
                 v_clob_result,
                 SYSDATE,
                 gv_request_id );

      END LOOP;

      -- Si se envio al menos un worksheet
      IF ( v_count > 0 ) THEN

        print_log ( ' ' );

        v_job_object_id := ajc_bc_ws_utils_pkg.get_object_id_f ( p_integration => 'WORKSHEETS' );
        print_log ( '- Se ejecuta el job -----------------------------------------------------------------------------------' );
        print_log ( 'v_job_object_id: ' || v_job_object_id );

        -- Se ejecuta el job para crear los worksheets -----------------------------------------------------------------------------
        /* 20230908
        v_clob_job_result := ajc_bc_ws_utils_pkg.run_job_queue_token_v2_f ( p_environment => p_bc_environment
                                                                            -- 20221104
                                                                            -- ,p_company_id => gv_company_id
                                                                           ,p_company_id => cc.bc_company_id 
                                                                            -- 20221104
                                                                           ,p_object_id => v_job_object_id
                                                                           ,p_seconds_to_wait => gv_seconds_to_wait );
        */
        v_clob_job_result := ajc_bc_ws_utils_pkg.run_job_queue_f ( p_environment => p_bc_environment
                                                                  ,p_company_id => cc.bc_company_id
                                                                  ,p_object_id => v_job_object_id
                                                                  ,p_seconds_to_wait => gv_seconds_to_wait );

        -- 20230908

        print_log ( 'v_clob_job_result: ' || v_clob_job_result);
        print_log ( ' ' );

        IF ( INSTR(UPPER(v_clob_job_result),'ERROR') = 0 ) THEN 

          v_job_message := 'Se ejecutó con éxito el job de importación en BC.';
          print_log ( 'Se ejecutó el job ProcessDimensionValuesAJC_INE con éxito.' );
          v_job_status := 'SUCCESS';

        ELSE

          v_job_message := 'Error al ejecutar job de importación en BC.';
          print_log ( 'Se produjo un error al ejecutar el job ProcessDimensionValuesAJC_INE.' );
          v_job_status := 'ERROR';

        END IF;

          -- Se inserta registro de control ------------------------------------------------------------------------------------
          INSERT 
            INTO ajc_bc_worksheet_control
               ( request_id,
                 bc_company_name,
                 count,
                 status,
                 job_response,
                 creation_date )
        VALUES ( gv_request_id,
                 cc.bc_company_name,
                 v_count,
                 v_job_status,
                 v_clob_job_result,
                 SYSDATE );

        -- Se consultan los registros enviados y procesados por el job -------------------------------------------------------------
        print_log ( ' ' );
        print_log ( 'Se consultan los registros enviados y procesados por el job' );
        v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, cc.bc_company_id ) || v_api_status
                     || '?$filter=requestID eq ' || gv_request_id;

        print_log ( 'v_get_url: ' || v_get_url);

        v_clob_result_status := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );

        -- Se arma la url parcial de borrado ---------------------------------------------------------------------------------------
        v_delete_url := v_url || '(' || gv_request_id || ')';
        print_log ( 'v_delete_url: ' || v_delete_url);
        print_log ( ' ' );

        -- Se consultan los estados de lo enviado ----------------------------------------------------------------------------------
        FOR cs IN c_status ( v_clob_result_status ) LOOP

          print_log ( 'WS: ' || cs.dimValueCode || ' | Status: ' || cs.status);

          IF ( UPPER(cs.status) != 'SUCCESS' ) THEN

            UPDATE ajc_bc_worksheets
               SET status = 'REJECTED',
                   error_message = cs.statusRemarks
             WHERE request_id = gv_request_id
               AND ws_ies_num = cs.dimValueCode
               AND bc_company_name = cc.bc_company_name;

            -- Se borra el worksheet rechazadoo ------------------------------------------------------------------------------------
            v_clob_delete_result := ajc_bc_ws_utils_pkg.delete_bc_row_f ( v_delete_url || '?$filter=dimValueCode eq ''' || 
                                    cs.dimValueCode || '''' ); 

            print_log ( 'Borrado.' );

          ELSE

            UPDATE ajc_bc_worksheets
               SET status = 'SUCCESS'
             WHERE request_id = gv_request_id
               AND ws_ies_num = cs.dimValueCode
               AND bc_company_name = cc.bc_company_name;

            print_log ( 'Procesado.' );

          END IF;

        END LOOP;

        -- Si el job no se pudo ejecutar, se actualizan todos los worksheets con el mensaje de error
        IF ( v_job_status = 'ERROR' ) THEN

          UPDATE ajc_bc_worksheets
             SET error_message = v_job_message
           WHERE request_id = gv_request_id
             AND bc_company_name = cc.bc_company_name;

          RAISE e_job_error;

        END IF;

        COMMIT;

      ELSE

        print_log ( 'No existen Worksheets para procesar.');

      END IF;

    END LOOP;

    -- Si se envio al menos un worksheet, se envia el mail
    IF ( v_all_companies_count > 0 ) THEN

      print_log ( 'Se envía el mail con el detalle.' );
      print_log ( ' ' );

      send_email ( gv_request_id, v_email );

    ELSE

      print_log ( 'No se envío ningún worksheet. No se envía el mail.' );
      print_log ( ' ' );

    END IF;

    print_log ( 'Se imprime el reporte en el output.' );
    print_report_p;

    print_log ( 'ajc_bc_worksheets_pkg.main_p (-)');

  EXCEPTION
    WHEN e_job_error THEN
      print_log ( 'ajc_bc_worksheets_pkg.main_p (!) | ' || v_job_status);
      retcode := 2;
      v_conc_status := fnd_concurrent.set_completion_status('ERROR',v_job_status);
      errbuf := v_job_status;

    WHEN OTHERS THEN
      print_log ( 'ajc_bc_worksheets_pkg.main_p (!) | ' || SQLERRM);
      retcode := 2;
      v_conc_status := fnd_concurrent.set_completion_status('ERROR',SQLERRM);
      errbuf := SQLERRM;

  END main_p;

  PROCEDURE caller_p ( p_bc_environment   IN   VARCHAR2 ) IS

    v_request_id        NUMBER;
    v_conc_phase        VARCHAR2(50);
    v_conc_status       VARCHAR2(50);
    v_conc_dev_phase    VARCHAR2(50);
    v_conc_dev_status   VARCHAR2(50);
    v_conc_message      VARCHAR2(250);
    v_message           VARCHAR2(32000);
    e_cust_exception    EXCEPTION;

  BEGIN

    v_request_id := fnd_request.submit_request ( 'XXAJC',
                                                 'AJCBCWS', -- AJC BC Worksheets Interface
                                                 argument1 => p_bc_environment,
                                                 argument2 => NULL ) ; -- worksheet number

    IF v_request_id = 0 THEN

      v_message := fnd_message.get;
      print_log('Error Ejecutando FND_REQUEST.SUBMIT_REQUEST. AJCBCWS - AJC BC Worksheets Interface. Error: ' || v_message || ', ' || SQLERRM);
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
      print_log('Error Ejecutando FND_REQUEST.WAIT_FOR_REQUEST. AJCBCWS - AJC BC Worksheets Interface, con nro. solicitud ' || 
                 TO_CHAR (v_request_id) || '. Error: ' || v_message || ' ' || SQLERRM);
      RAISE e_cust_exception;

    END IF ;

    IF v_conc_dev_phase != 'COMPLETE' OR v_conc_dev_status != 'NORMAL' THEN

      v_message := fnd_message.get;
      print_log('Error en la ejecucion del concurrente AJCBCWS - AJC BC Worksheets Interface, con nro. solicitud ' || 
                 TO_CHAR (v_request_id) || '. Error: ' || v_message || ' ' || SQLERRM);
      RAISE e_cust_exception;

    END IF ;

  END caller_p;

END ajc_bc_worksheets_pkg;
