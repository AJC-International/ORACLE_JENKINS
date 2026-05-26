CREATE OR REPLACE PACKAGE BODY ajc_bc_md_worksheets_pkg IS



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



    v_subject          VARCHAR2(2000) := 'AJC BC Master Data - Worksheets - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS');

    v_message          VARCHAR2(2000);



  BEGIN



    print_log ('ajc_bc_md_worksheets_pkg.send_email (+)');



    -- Se obtiene la cantidad de worksheet SUCCESS   

    SELECT COUNT(1)

      INTO v_success_count

      FROM ajc_bc_md_worksheets

     WHERE request_id = gv_request_id

       AND status = 'SUCCESS';



    print_log ( 'SUCCESS: ' || v_success_count );



    -- Se obtiene la cantidad de worksheet REJECTED

    SELECT COUNT(1)

      INTO v_rejected_count

      FROM ajc_bc_md_worksheets

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



    print_log ('ajc_bc_md_worksheets_pkg.send_email (-)');    



  EXCEPTION

    WHEN others THEN

      print_log ( 'ajc_bc_md_worksheets_pkg.send_email (!)' );  

      print_log ( 'Error: ' || SQLERRM );



  END send_email;



  PROCEDURE print_report_p IS



      CURSOR c_worksheets IS

      SELECT ws_ies_num,  

             bc_company_name,

             status,

             error_message

        FROM ajc_bc_md_worksheets

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

                     p_bc_environment     IN   VARCHAR2 ) IS



      CURSOR c_companies IS

      SELECT bc_company_name,

             oracle_company_number bc_company_number,

             bc_company_id

        FROM ajc_bc_companies

    GROUP BY bc_company_name,

             oracle_company_number,

             bc_company_id

    ORDER BY bc_company_name,

             oracle_company_number;



      CURSOR c_ws ( p_bc_company_number   IN   VARCHAR2 ) IS 

      SELECT mdw.ws_ies_num dimValueCode,

             REPLACE(SUBSTR(NVL(a.description,'Open Accrual Data Migration'),1,50),'"','') dimValueName

        FROM ajc_bc_md_worksheets mdw,

             ajc_worksheet_ies_num a

       WHERE mdw.bc_company_number = p_bc_company_number

         AND mdw.status IS NULL

         AND mdw.ws_ies_num = a.ws_ies_num (+)

    GROUP BY mdw.ws_ies_num,

             a.description;



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



  BEGIN



    print_log ( 'ajc_bc_md_worksheets_pkg.main_p (+)');

    print_log ( ' ' );



    v_email := ajc_bc_ws_utils_pkg.get_emails_f ( 'WORKSHEETS' );

    print_log ( 'v_email: ' || v_email );



    v_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'WORKSHEETS',

                                             p_subentity => NULL,

                                             p_method => 'POST' );

    print_log ( 'v_api: ' || v_api );



    v_api_status := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'WORKSHEETS',

                                                    p_subentity => NULL,

                                                    p_method => 'GET' ) ;                                             

    print_log ( 'v_api_status: ' || v_api_status );



    FOR cc IN c_companies LOOP



      v_count := 0;



      print_log ( ' ' );

      print_log ( 'BC Company Name: ' || cc.bc_company_name || ' | BC Company ID: ' || cc.bc_company_id );



      v_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, cc.bc_company_id ) || v_api;



      print_log ( 'v_url: ' || v_url);



      FOR cws IN c_ws ( p_bc_company_number => cc.bc_company_number ) LOOP



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



        UPDATE ajc_bc_md_worksheets

           SET bc_environment = p_bc_environment,

               bc_company_name = cc.bc_company_name,

               description = cws.dimValueName,

               status = v_worksheet_status,

               json_data = v_body,

               json_data_response = v_clob_result,

               creation_date = SYSDATE,

               request_id = gv_request_id

         WHERE ws_ies_num = cws.dimValueCode

           AND status IS NULL;



      END LOOP;



      -- Si se envio al menos un worksheet

      IF ( v_count > 0 ) THEN



        print_log ( ' ' );



        v_job_object_id := ajc_bc_ws_utils_pkg.get_object_id_f ( p_integration => 'WORKSHEETS' );

        print_log ( '- Se ejecuta el job -----------------------------------------------------------------------------------' );

        print_log ( 'v_job_object_id: ' || v_job_object_id );



        -- Se ejecuta el job para crear los worksheets -----------------------------------------------------------------------------

        v_clob_job_result := ajc_bc_ws_utils_pkg.run_job_queue_token_v2_f ( p_environment => p_bc_environment

                                                                           ,p_company_id => cc.bc_company_id 

                                                                           ,p_object_id => v_job_object_id

                                                                           ,p_seconds_to_wait => gv_seconds_to_wait );



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

            INTO ajc_bc_md_worksheet_control

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



            UPDATE ajc_bc_md_worksheets

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



            UPDATE ajc_bc_md_worksheets

               SET status = 'SUCCESS'

             WHERE request_id = gv_request_id

               AND ws_ies_num = cs.dimValueCode

               AND bc_company_name = cc.bc_company_name;



            print_log ( 'Procesado.' );



          END IF;



        END LOOP;



        -- Si el job no se pudo ejecutar, se actualizan todos los worksheets con el mensaje de error

        IF ( v_job_status = 'ERROR' ) THEN



          UPDATE ajc_bc_md_worksheets

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



    print_log ( 'ajc_bc_md_worksheets_pkg.main_p (-)');



  EXCEPTION

    WHEN e_job_error THEN

      print_log ( 'ajc_bc_md_worksheets_pkg.main_p (!) | ' || v_job_status);

      retcode := 2;

      v_conc_status := fnd_concurrent.set_completion_status('ERROR',v_job_status);

      errbuf := v_job_status;



    WHEN OTHERS THEN

      print_log ( 'ajc_bc_md_worksheets_pkg.main_p (!) | ' || SQLERRM);

      retcode := 2;

      v_conc_status := fnd_concurrent.set_completion_status('ERROR',SQLERRM);

      errbuf := SQLERRM;



  END main_p;



END ajc_bc_md_worksheets_pkg;
