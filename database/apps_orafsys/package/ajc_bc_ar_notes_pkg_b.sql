CREATE OR REPLACE PACKAGE BODY ajc_bc_ar_notes_pkg AS

  

  -- ---------------------------------------------------------------------------------------------------------------------------

  -- Print Log

  -- ---------------------------------------------------------------------------------------------------------------------------

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    fnd_file.put_line(fnd_file.log, p_message);



  END print_log;



  -- ---------------------------------------------------------------------------------------------------------------------------

  -- Print Output

  -- ---------------------------------------------------------------------------------------------------------------------------

  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    fnd_file.put_line(fnd_file.output,p_message);



  END print_output;



  -- Get CUSTOMER_ID -----------------------------------------------------------------------------------------------------------

  PROCEDURE get_customer_p ( p_customer_number   IN       VARCHAR2,

                             p_customer_id       IN OUT   NUMBER,

                             p_customer_name     IN OUT   VARCHAR2,                             

                             p_message           IN OUT   VARCHAR2 ) IS



  BEGIN



    print_log ('ajc_bc_ar_notes_pkg.get_customer_p (+)');



    p_message := NULL;



    SELECT customer_id,

           customer_name

      INTO p_customer_id,

           p_customer_name

      FROM ra_customers

     WHERE customer_number = p_customer_number;



    print_log ('p_customer_id: ' || p_customer_id);

    print_log ('p_customer_name: ' || p_customer_name);



    print_log ('ajc_bc_ar_notes_pkg.get_customer_p (-)');



  EXCEPTION

    WHEN NO_DATA_FOUND THEN

      p_message := 'Customer No. ''' || p_customer_number || ''' not found.';

      print_log ('ajc_bc_ar_notes_pkg.get_customer_p (!). ' || p_message);



    WHEN TOO_MANY_ROWS THEN

      p_message := 'Customer No. ''' || p_customer_number || ''' duplicated.';

      print_log ('ajc_bc_ar_notes_pkg.get_customer_p (!). ' || p_message);



    WHEN OTHERS THEN

      p_message := 'Customer ''' || p_customer_name || ''' error: ' || SQLERRM;

      print_log ('ajc_bc_ar_notes_pkg.get_customer_p (!). ' || p_message);



  END get_customer_p;



  -- ---------------------------------------------------------------------------------------------------------------------------

  -- Get Notes

  -- ---------------------------------------------------------------------------------------------------------------------------

  PROCEDURE get_notes ( p_last_bc_processed_date   IN    TIMESTAMP,

                        p_bc_environment           IN    VARCHAR2,

                        p_notes_count              OUT   NUMBER,

                        p_return                   OUT   VARCHAR2, 

                        p_message                  OUT   VARCHAR2 ) IS



    v_get_url                  VARCHAR2(2000);

    v_get_api                  VARCHAR2(100);

    v_clob_result              CLOB;

    v_notes_count_by_company   NUMBER;



      CURSOR c_bc_companies IS

      SELECT bc_company_name,

             bc_company_id

        FROM ajc_bc_companies

    GROUP BY bc_company_name,

             bc_company_id

    ORDER BY bc_company_name;



      CURSOR c_notes ( p_clob_result   IN   CLOB ) IS

      SELECT system_id,

             'MAINTAIN' note_type,

             text,

             customer_number,

             trx_number,             

             document_type

        FROM json_table( p_clob_result,

                           '$.value[*]' COLUMNS ( system_id         VARCHAR2(4000)  path '$.systemId',

                                                  customer_number   VARCHAR2(4000)  path '$.customerNo',

                                                  text              VARCHAR2(4000)  path '$.note',

                                                  trx_number        VARCHAR2(4000)  path '$.documentNo',

                                                  document_type     VARCHAR2(4000)  path '$.documentType' ) );



  BEGIN



    print_log ('ajc_bc_ar_notes_pkg.get_notes (+)');



    p_notes_count := 0;



    v_get_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'AR NOTES',

                                                 p_subentity => NULL,

                                                 p_method => 'GET' );



    -- print_log ( 'v_get_api: ' || v_get_api );



    FOR cc IN c_bc_companies LOOP



      -- Get Notes

      v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, cc.bc_company_id ) || v_get_api 

                   || '?$filter=systemModifiedAt gt ' || TO_CHAR(p_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');



      -- print_log ('v_get_url: ' || v_get_url);

      v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );



      -- Se pone en 0 el contador de notas para la company

      v_notes_count_by_company := 0;



      FOR cn IN c_notes ( v_clob_result ) LOOP



          INSERT

            INTO ajc_bc_ar_notes     

               ( system_id,

                 note_type,

                 text,

                 customer_number,

                 trx_number,

                 document_type,

                 status,

                 creation_date,

                 request_id,

                 company )

        VALUES ( cn.system_id,

                 cn.note_type,

                 cn.text,

                 cn.customer_number,

                 cn.trx_number,             

                 cn.document_type,

                 'NEW',

                 SYSDATE,

                 gv_request_id,

                 cc.bc_company_name );



        p_notes_count := p_notes_count + 1;

        v_notes_count_by_company := v_notes_count_by_company + 1;



      END LOOP; 



      print_log ( 'Company: ' || cc.bc_company_name || ' | Cantidad de notas sincronizadas: ' || v_notes_count_by_company );



    END LOOP;



    print_log ( 'Cantidad total de notas sincronizadas: ' || p_notes_count );



    COMMIT;

    p_return := 'S';



    print_log ('ajc_bc_ar_notes_pkg.get_notes (-)');



  EXCEPTION

    WHEN OTHERS THEN

      print_log ('ajc_bc_ar_notes_pkg.get_notes (!)');

      p_return := 'E';

      p_message := SQLCODE || ': ' || SQLERRM;



  END get_notes;



  -- Get CUSTOMER_TRX_ID -----------------------------------------------------------------------------------------------------------

  PROCEDURE get_customer_trx_p ( p_trx_number            IN       VARCHAR2,

                                 p_customer_id           IN OUT   NUMBER,

                                 p_customer_trx_id       IN OUT   NUMBER,

                                 p_org_id                IN OUT   NUMBER,

                                 p_message               IN OUT   VARCHAR2 ) IS



    v_trx_number   VARCHAR2(100);



  BEGIN



    print_log ('ajc_bc_ar_notes_pkg.get_customer_trx_p (+)');



    p_message := NULL;



    -- Si comienza con 'AR-', son migradas, en Oracle existen sin AR-

    SELECT DECODE(SUBSTR(p_trx_number,1,3),'AR-',SUBSTR(p_trx_number,4),p_trx_number)

      INTO v_trx_number 

      FROM dual;



    print_log ('v_trx_number: ' || v_trx_number);



    -- Se obtiene el customer_trx_id

    SELECT rct.customer_trx_id,

           rct.org_id

      INTO p_customer_trx_id,

           p_org_id

      FROM ra_customer_trx_all rct

        -- Si comienza con 'AR-', son migradas, en Oracle existen sin AR-

     WHERE rct.trx_number = v_trx_number 

       AND rct.bill_to_customer_id = p_customer_id;



    print_log ('p_customer_trx_id: ' || p_customer_trx_id);

    print_log ('p_org_id: ' || p_org_id);



    print_log ('ajc_bc_ar_notes_pkg.get_customer_trx_p (-)');



  EXCEPTION

    WHEN NO_DATA_FOUND THEN

      p_message := 'Trx Number ' || v_trx_number || ' not found.';

      print_log ('ajc_bc_ar_notes_pkg.get_customer_trx_p (!). ' || p_message);



    WHEN TOO_MANY_ROWS THEN

      p_message := 'Trx Number ' || v_trx_number || ' duplicated.';

      print_log ('ajc_bc_ar_notes_pkg.get_customer_trx_p (!). ' || p_message);



    WHEN OTHERS THEN

      p_message := 'Trx Number ' || v_trx_number || ' error: ' || SQLERRM;

      print_log ('ajc_bc_ar_notes_pkg.get_customer_trx_p (!). ' || p_message);



  END get_customer_trx_p;



  PROCEDURE PSI_notes ( p_system_id         IN   VARCHAR2,

                        p_trx_number        IN   VARCHAR2,

                        p_company           IN   VARCHAR2,

                        p_text              IN   VARCHAR2,

                        p_customer_id       IN   NUMBER,

                        p_customer_name     IN   VARCHAR2 ) IS



    v_exists    VARCHAR2(1);

    v_org_id    ajc_bc_ar_notes.org_id%TYPE;  

    v_note_id   ajc_bc_ar_notes.note_id%TYPE;



  BEGIN



    print_log ('ajc_bc_ar_notes_pkg.PSI_notes (+)');



    -- Se verifica si la nota ya existe en ajc_bc_ar_notes con otro request id y en status CREATED

    SELECT DECODE(COUNT(1),0,'N','Y')

      INTO v_exists

      FROM ajc_bc_ar_notes

     WHERE system_id = p_system_id

       AND request_id != gv_request_id

       AND status = 'CREATED';



    -- Si ya existe, se actualiza el existente y se borra el nuevo registro bajado

    IF ( v_exists = 'Y' ) THEN



      print_log ('La nota ya existe. Se actualiza y se borra el registro bajado en la ejecucion actual.');      



      UPDATE ajc_bc_ar_notes

         SET text = p_text,

             request_id = gv_request_id

       WHERE system_id = p_system_id

         AND request_id != gv_request_id

         AND status = 'CREATED';



      DELETE ajc_bc_ar_notes

       WHERE system_id = p_system_id

         AND request_id = gv_request_id

         AND status = 'NEW';



      COMMIT;



      print_log ('PSI note updated.');



    -- Si no existe es porque nunca bajo a Oracle, debe crearse

    ELSE 



      print_log ('La nota no existe. Se crea.');      



      -- Se obtiene el org_id

      BEGIN



          SELECT org_id

            INTO v_org_id

            FROM ( SELECT bc_company_name,

                          bc_company_id,

                          DECODE(org_id,5526,5375, -- FOODS-CHN-CNY

                                        5608,5627, -- FOODS-NLD-EUR

                                        5376,5244, -- FOODS-USA-USD

                                        org_id) org_id

                     FROM ajc_bc_companies

                    WHERE bc_company_name = p_company

                      AND org_id <> -1 )

        GROUP BY org_id;    



        print_log ('v_org_id: ' || v_org_id);



      EXCEPTION

        WHEN OTHERS THEN

          print_log ('Error obteniendo org_id.');

          v_org_id := NULL;



      END;



      -- Se obtiene el valor de la secuencia standard

      SELECT ar_notes_s.nextval

        INTO v_note_id

        FROM dual;



      print_log ('v_note_id: ' || v_note_id);



      UPDATE ajc_bc_ar_notes

         SET org_id = v_org_id,

             note_id = v_note_id,

             customer_id = p_customer_id,

             customer_name = p_customer_name,

             status = 'CREATED'

       WHERE trx_number = p_trx_number

         AND request_id = gv_request_id

         AND status = 'NEW';



      print_log ('PSI note created.');



    END IF;



    print_log ('ajc_bc_ar_notes_pkg.PSI_notes (-)');



  END PSI_notes;



  -- ---------------------------------------------------------------------------------------------------------------------------

  -- Process Notes

  -- ---------------------------------------------------------------------------------------------------------------------------

  PROCEDURE process_notes ( p_return    OUT   VARCHAR2, 

                            p_message   OUT   VARCHAR2 ) IS



    CURSOR c_notes IS

    SELECT *

      FROM ajc_bc_ar_notes

     WHERE status = 'NEW'

       AND request_id = gv_request_id;



    v_org_id            NUMBER;

    v_customer_id       NUMBER;

    v_customer_name     VARCHAR2(60);



    v_customer_trx_id   NUMBER;



    v_message           VARCHAR2(2000);

    e_error             EXCEPTION;



  BEGIN



    print_log ('ajc_bc_ar_notes_pkg.process_notes (+)');



    -- Se borran las notas que vienen sin texto

    DELETE ajc_bc_ar_notes

     WHERE status = 'NEW'

       AND text IS NULL

       AND request_id = gv_request_id;  



    COMMIT;



    FOR cn IN c_notes LOOP



      v_message := NULL;



      BEGIN



        v_org_id := NULL;

        v_customer_id := NULL;

        v_customer_name := NULL;

        v_customer_trx_id := NULL;



        get_customer_p ( p_customer_number => cn.customer_number,

                         p_customer_id => v_customer_id,  

                         p_customer_name => v_customer_name,                                                

                         p_message => v_message );



        IF ( v_customer_id IS NULL ) THEN



          RAISE e_error;



        END IF;  



        get_customer_trx_p ( p_trx_number => cn.trx_number,

                             p_customer_id => v_customer_id,

                             p_customer_trx_id => v_customer_trx_id,

                             p_org_id => v_org_id,

                             p_message => v_message );



        IF ( v_customer_trx_id IS NULL ) THEN



          RAISE e_error;



        END IF;



        UPDATE ajc_bc_ar_notes

           SET status = 'MAPPED',

               org_id = v_org_id,

               customer_id = v_customer_id,

               customer_name = v_customer_name,

               customer_trx_id = v_customer_trx_id

         WHERE system_id = cn.system_id

           AND request_id = gv_request_id

           AND status = 'NEW';



      EXCEPTION

        WHEN e_error THEN



          -- 20251114

          IF ( cn.trx_number LIKE 'PSI%' ) THEN



            PSI_notes ( cn.system_id,

                        cn.trx_number,

                        cn.company,

                        cn.text,

                        v_customer_id,

                        v_customer_name );



          ELSE

          -- 20251114



            UPDATE ajc_bc_ar_notes

               SET status = 'ERROR',

                   message = v_message

             WHERE system_id = cn.system_id

               AND request_id = gv_request_id

               AND status = 'NEW';



          -- 20251114

          END IF;

          -- 20251114



        WHEN OTHERS THEN



          UPDATE ajc_bc_ar_notes

             SET status = 'ERROR',

                 message = v_message

           WHERE system_id = cn.system_id

             AND request_id = gv_request_id

             AND status = 'NEW';



      END;



    END LOOP;



    p_return := 'S';



    print_log ('ajc_bc_ar_notes_pkg.process_notes (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_return := 'E';

      p_message := 'Error general process_notes. ' || SQLERRM;



  END process_notes;



  -- ---------------------------------------------------------------------------------------------------------------------------

  -- Create Notes

  -- ---------------------------------------------------------------------------------------------------------------------------

  PROCEDURE create_update_notes ( p_return    OUT   VARCHAR2, 

                                  p_message   OUT   VARCHAR2 ) IS



    CURSOR c_notes IS

    SELECT *

      FROM ajc_bc_ar_notes

     WHERE status = 'MAPPED'

       AND request_id = gv_request_id;



    v_note_id      NUMBER;

    rec_ar_notes   ar_notes%ROWTYPE;



    e_error        EXCEPTION;



  BEGIN



    print_log ('ajc_bc_ar_notes_pkg.create_update_notes (+)');



    FOR cn IN c_notes LOOP



      p_message := NULL;

      v_note_id := NULL;



      BEGIN



        -- Se verifica si la nota ya existe en Oracle, si fue creada por la interface

        BEGIN



            SELECT note_id

              INTO v_note_id

              FROM ajc_bc_ar_notes

             WHERE system_id = cn.system_id

               AND request_id != gv_request_id

               AND status = 'CREATED';



        EXCEPTION

          WHEN OTHERS THEN

            v_note_id := NULL;



        END;



        -- La nota nunca fue creada por la interface, se crea

        IF ( v_note_id IS NULL ) THEN



          -- Se limpian los campos del registro

          rec_ar_notes := NULL;



          rec_ar_notes.note_type := cn.note_type;

          rec_ar_notes.text := cn.text;

          rec_ar_notes.customer_trx_id := cn.customer_trx_id;



          ARP_NOTES_PKG.insert_p ( p_notes_rec => rec_ar_notes );



          UPDATE ajc_bc_ar_notes

             SET status = 'CREATED',

                 note_id = rec_ar_notes.note_id

           WHERE system_id = cn.system_id

             AND request_id = gv_request_id

             AND status = 'MAPPED';



        -- Se actualiza la nota

        ELSE



          UPDATE ar_notes                          

             SET text = cn.text

           WHERE note_id = v_note_id;



          UPDATE ajc_bc_ar_notes

             SET status = 'UPDATED',

                 note_id = rec_ar_notes.note_id

           WHERE system_id = cn.system_id

             AND request_id = gv_request_id

             AND status = 'MAPPED';



        END IF;



      EXCEPTION

        WHEN e_error THEN



          UPDATE ajc_bc_ar_notes

             SET status = 'ERROR',

                 message = 'Error'

           WHERE system_id = cn.system_id

             AND request_id = gv_request_id

             AND status = 'MAPPED';



        WHEN OTHERS THEN



          UPDATE ajc_bc_ar_notes

             SET status = 'ERROR',

                 message = 'Error'

           WHERE system_id = cn.system_id

             AND request_id = gv_request_id

             AND status = 'MAPPED';



      END;



    END LOOP;



    p_return := 'S';



    print_log ('ajc_bc_ar_notes_pkg.create_update_notes (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_return := 'E';

      p_message := 'Error general. ' || SQLERRM;



  END create_update_notes;



  -- ---------------------------------------------------------------------------------------------------------------------------

  -- Print Report

  -- ---------------------------------------------------------------------------------------------------------------------------

  PROCEDURE print_report IS



      CURSOR c_notes IS

      SELECT ou.name org_name,

             arn.customer_number,

             arn.customer_name,

             arn.trx_number,

             arn.text,

             arn.status,

             arn.message

        FROM ajc_bc_ar_notes arn,

             hr_operating_units ou

       WHERE arn.status IN ('CREATED','UPDATED','ERROR')

         AND arn.org_id = ou.organization_id (+)

         AND request_id = gv_request_id

    ORDER BY ou.name,

             arn.customer_name,

             arn.trx_number,

             arn.note_id;



  BEGIN



    print_output ( 'AJC BC AR Transactions Notes Interface' );

    print_output ( ' ' );



    print_output ( RPAD('Organization',26,' ') || ' | ' ||

                   RPAD('Customer Number',15,' ') || ' | ' ||

                   RPAD('Customer Name',40,' ') || ' | ' ||

                   RPAD('Trx Number',15,' ') || ' | ' ||

                   RPAD('Note',60,' ') || ' | ' ||

                   RPAD('Status',10,' ') || ' | ' ||

                   RPAD('Message',40,' ') );



    print_output ( RPAD('-',224,'-') );



    FOR cn IN c_notes LOOP



      print_output ( RPAD(NVL(cn.org_name,' '),26,' ') || ' | ' ||

                     RPAD(cn.customer_number,15,' ') || ' | ' ||

                     RPAD(NVL(cn.customer_name,' '),40,' ') || ' | ' ||

                     RPAD(cn.trx_number,15,' ') || ' | ' ||

                     RPAD(cn.text,60,' ') || ' | ' ||

                     RPAD(cn.status,10,' ') || ' | ' ||

                     RPAD(cn.message,40,' ') );



    END LOOP;



  END print_report;



  -- ---------------------------------------------------------------------------------------------------------------------------

  -- Main

  -- ---------------------------------------------------------------------------------------------------------------------------

  PROCEDURE main_p ( retcode            OUT   NUMBER,

                     errbuf             OUT   VARCHAR2,

                     p_bc_environment   IN   VARCHAR2 ) IS



    v_run_date                 TIMESTAMP;

    v_last_processed_date      TIMESTAMP;

    v_last_bc_processed_date   TIMESTAMP;

    v_notes_count              NUMBER;



    v_return                   VARCHAR2(1);

    v_message                  VARCHAR2(2000);



    e_get                      EXCEPTION;  

    e_process                  EXCEPTION;

    e_create                   EXCEPTION;



  BEGIN



    print_log ('ajc_bc_ar_notes_pkg.main_p (+)');



    -- Se guarda la fecha y hora actual

    v_run_date := systimestamp;

    print_log ( 'v_run_date: ' || v_run_date );



    -- Se obtiene la fecha y hora de Oracle de la ultima ejecucion de la interface

    v_last_processed_date := ajc_bc_ws_utils_pkg.get_ifc_last_processed_date_f ( gv_ifc );

    print_log ( 'Oracle last processed date: ' || v_last_processed_date );    



    -- Se obtiene la fecha y hora de BC de la ultima ejecucion de la interface

    v_last_bc_processed_date := ajc_bc_ws_utils_pkg.get_bc_last_processed_date_f ( v_last_processed_date );

    print_log ( 'BC last processed date: ' || v_last_bc_processed_date );



    get_notes ( p_last_bc_processed_date => v_last_bc_processed_date,

                p_bc_environment => p_bc_environment,

                p_notes_count => v_notes_count,

                p_return => v_return, 

                p_message => v_message );



    IF ( v_return != 'S' ) THEN



      RAISE e_get;



    END IF;



    IF ( v_notes_count > 0 ) THEN



      process_notes ( p_return => v_return, 

                      p_message => v_message );



      IF ( v_return != 'S' ) THEN



        RAISE e_process;



      END IF;



      create_update_notes ( p_return => v_return, 

                            p_message => v_message );



      IF ( v_return != 'S' ) THEN



        RAISE e_create;



      END IF;



      print_report;



    END IF;



    -- Se actualiza la tabla de control

    ajc_bc_ws_utils_pkg.upd_ifc_last_processed_date_p ( gv_ifc,

                                                        gv_request_id,

                                                        v_run_date );





    print_log ('ajc_bc_ar_notes_pkg.main_p (+)');



  EXCEPTION

    WHEN e_get THEN

        print_log ( 'ajc_bc_ar_notes_pkg.main_p (!)' );

        print_log ( 'Error al obtener las notas de comprobantes de AR de BC. ' || v_message );

        retcode := 2;

        errbuf := v_message;

      WHEN e_process THEN

        print_log ( 'ajc_bc_ar_notes_pkg.main_p (!)' );

        print_log ( 'Error al procesar las notas de AR. ' || v_message );

        retcode := 2;

        errbuf := v_message;

      WHEN e_create THEN

        print_log ( 'ajc_bc_ar_notes_pkg.main_p (!)' );

        print_log ( 'Error al intentar crear las notas en comprobantes de AR. ' || v_message );

        retcode := 2;

        errbuf := v_message;

      WHEN OTHERS THEN

        print_log ('ajc_bc_ar_notes_pkg,main_p (!)');

        print_log ('Error general main_p. ' || SQLERRM);

        retcode := 2;

        errbuf := 'Error general main_p. ' || SQLERRM;



  END main_p;



END ajc_bc_ar_notes_pkg;
