CREATE OR REPLACE PACKAGE BODY              AJC_BC_J_ABBYY_INTERFACE_PK AS



/* ----------------------------------------------------------------------------------------------|

| Historial                                                                                      |

|   Date      Version  Modified    Detail                                                        |

|   --------- -------  ----------  --------------------------------------------------------------|

|   14-APR-19    1     PBONADEO    Creation                                                      |

|   04-DEC-20    2     SBANCHIERI  Creation                                                      |

|   02-FEB-22    2     MBETTI  BC modifications                                                      |

/   18-JUL-25   3   MBETTI Jenkins Migration                                            /

|------------------------------------------------------------------------------------------------*/



-- Fixed parameters

gv_source                     ap_invoices_interface.source%type:='ABBYY'; -- BC Purchase Invoice source

gv_dft_account              VARCHAR2(10):='9105.9890';  -- Default account - ex ZERO

--gv_dft_ora_account        VARCHAR2(10):='9890'; -- Default Oracle account - ex ZERO

gv_file_format               VARCHAR2(4):='XLSX'; -- Report file format

gv_delete_flag               VARCHAR2(4):='Y';  -- Deletes rejecte records from BC Inbound Purchase Document table



/*=========================================================================+

|                                                                          |

| Private Function                                                       |

|    print_log                                                             |

|                                                                          |

| Description                                                              |

|    Impresion de log                                                      |

|                                                                          |

|                                                                          |

| Parameters                                                               |

|    p_message                   IN     NUMBER    Mensaje.                 |

|                                                                          |

+=========================================================================*/

  PROCEDURE print_log(p_message IN VARCHAR2) IS

  BEGIN

      gv_log_seq := gv_log_seq + 1;

     ajc_bc_j_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );

     dbms_output.put_line ( p_message);

  END;



/*=========================================================================+

|                                                                          |

| Private Function                                                         |

|    print_output                                                          |

|                                                                          |

| Description                                                              |

|    Impresion de output                                                   |

|                                                                          |

|                                                                          |

| Parameters                                                               |

|    p_message                   IN     NUMBER    Mensaje.                 |

|                                                                          |

+=========================================================================*/



  PROCEDURE print_output(p_message IN VARCHAR2) IS

  BEGIN

        ajc_bc_j_utils_pkg.insert_output_p ( gv_bc_ifc, p_message, gv_request_id );

  END;





FUNCTION get_text (p_text  IN VARCHAR2

                  ,p_index IN NUMBER) RETURN VARCHAR2 IS



v_result NUMBER;

v_text VARCHAR2(240);

v_ws VARCHAR2(240);



BEGIN



    IF SUBSTR(p_text,-1) = '|' THEN 

       v_text := SUBSTR(p_text,1,length(p_text)-1);

    ELSE

       v_text := p_text;   

    END IF;



  IF p_index = 1 then



      SELECT INSTR(v_text,'|',1,p_index)

        into v_result

        from dual;



        IF v_result = 0 THEN         

            v_ws := substr(v_text,1);

        ELSE

            v_ws := substr(v_text,1,INSTR(v_text,'|',1,p_index)-1);

        END IF;



  ELSE



    SELECT INSTR(v_text,'|',1,p_index-1)

    into v_result

    from dual;



    IF v_result = 0 then

      v_ws := substr(v_text,INSTR(v_text,'|',1,p_index-2));

    ELSE



        SELECT INSTR(v_text,'|',1,p_index)

        into v_result

        from dual;



        IF v_result = 0 then

            v_ws := substr(v_text,INSTR(v_text,'|',1,p_index-1)+1);

        ELSE

            v_ws := substr(v_text,instr(v_text,'|',1,p_index-1)+1,instr(v_text,'|',1,p_index)-instr(v_text,'|',1,p_index-1)-1);

        END IF;

    END IF;



END IF;



  return (v_ws);

EXCEPTION

 WHEN OTHERS THEN 

  RETURN NULL;



END;





/*=========================================================================+

|                                                                          |

| Private Procedure                                                        |

|    validate_import                                                       |

|                                                                          |

| Description                                                              |

|    Validate Import Procedure                                             |

|                                                                          |

| Parameters                                                               |

|    p_company_id                  IN     VARCHAR2  ID compania para ws BC.            |

|    p_status                  OUT     VARCAHR2  Codigo Estado.            |

|    p_error_message           OUT     VARCHAR2  Mensaje de Error.         |

|                                                                          |

+=========================================================================*/

PROCEDURE validate_import ( -- p_company_id IN VARCHAR2,

                            p_delete_flag      IN   VARCHAR2,

                            p_status          OUT   VARCHAR2,

                            p_error_message   OUT   VARCHAR2 ) IS



CURSOR c_org_ids IS



SELECT distinct org_id

FROM AJC_BC_ABBYY_INVOICES_INT

WHERE STATUS_CODE = 'SENT'

AND ORG_ID != 5387; -- LOGIS-USA-USD

--AND request_id = gv_request_id; 



CURSOR c_imp (p_org_id NUMBER) IS

SELECT rowid row_id,invoice_id,vendor_id,org_id,invoice_num,invoice_type_lookup_code

FROM AJC_BC_ABBYY_INVOICES_INT

WHERE STATUS_CODE = 'SENT'

AND ORG_ID = p_org_id;-- fnd_profile.value('ORG_ID')

--AND request_id = gv_request_id; 



CURSOR c_bc_status (p_clob_result IN CLOB,p_invoice_id NUMBER) IS

    SELECT 

        documentType,

        invoiceID,

        invoiceNo,

        invoiceType,

        invoiceDate,

        vendorNo,

        glDate,

        status,

        StatusRemarks,

        StatusTimeStamp,

        requestID

    FROM json_table( p_clob_result,

                     '$.value[*]' COLUMNS ( documentType     VARCHAR2(4000)  path '$.documentType',

                                                        invoiceID   VARCHAR2(4000)  path '$.invoiceID' ,

                                                        invoiceNo   VARCHAR2(4000) path '$.invoiceNo',

                                                        invoiceType VARCHAR2(4000) path '$.invoiceType',

                                                        invoiceDate VARCHAR2(4000) path '$.invoiceDate',

                                                        vendorNo VARCHAR2(4000) path '$.vendorNo',

                                                        glDate VARCHAR2(4000) path '$.gLDate',

                                                        status VARCHAR2(4000) path '$.status',

                                                        StatusRemarks VARCHAR2(4000) path '$.statusRemarks',

                                                        StatusTimeStamp VARCHAR2(4000) path '$.statusTimestamp',

                                                        requestID VARCHAR2(4000) path '$.requestID'))

    WHERE invoiceID=p_invoice_id;



v_exists NUMBER:=0;

e_cust_exception EXCEPTION;

v_url VARCHAR2(500);

-- 20230414 v_api_st VARCHAR2(100):= 'inboundpurchaseintegrationstatusINE';

v_api_st VARCHAR2(100);



-- v_api_del_line VARCHAR2(100):= 'inboundPurchaseLineINE';

v_api_del_line VARCHAR2(100);



-- v_api_del_hdr VARCHAR2(100):= 'inboundPurchaseHeaderINE';

v_api_del_hdr VARCHAR2(100);



v_clob_int   CLOB;

v_clob_del CLOB;

v_STime  NUMBER(30);

v_ETime  NUMBER(30);

v_cant_sin_procesar NUMBER;

v_company_id VARCHAR2(100);

v_status    VARCHAR2(1);

v_error_message VARCHAR2(1000);



BEGIN



    print_log ('AJC_BC_ABBYY_INTERFACE_PK.VALIDATE_IMPORT (+)');

    print_log ('Se obtienen los comprobantes procesados en el día de hoy.');



    v_api_st := AJC_BC_J_WS_UTILS_PKG.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                                p_subentity => 'STATUS',

                                                p_method => 'GET' );

    print_log ('v_api_st: ' || v_api_st);



    v_api_del_line := AJC_BC_J_WS_UTILS_PKG.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                                      p_subentity => 'LINES',

                                                      p_method => 'DELETE' );

    print_log ('v_api_del_line: ' || v_api_del_line);



    v_api_del_hdr := AJC_BC_J_WS_UTILS_PKG.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                                     p_subentity => 'HEADERS',

                                                     p_method => 'DELETE' );

    print_log ('v_api_del_hdr: ' || v_api_del_hdr);



    FOR r_org IN c_org_ids LOOP



        print_log('org_id: '||r_org.org_id);



        AJC_BC_J_WS_UTILS_PKG.get_bc_company_id_f(r_org.org_id,NULL,NULL,v_company_id,v_status);        



        print_log('v_company_id: '||v_company_id);



        IF v_status = 'E' THEN

                v_error_message := 'Unable to obtain. Error: '||SQLERRM;

                v_company_id:=null;

                RAISE e_cust_exception;

        END IF;



        v_url := AJC_BC_J_WS_UTILS_PKG.get_base_inecta_url_f ( gv_bc_environment, v_company_id ) || v_api_st|| '?$filter=requestID eq '|| TO_CHAR(gv_request_id); 



        print_log('v_url: ' || v_url);   



        v_cant_sin_procesar := -1;



        -- seteo tiempo de inicio

            Select To_Number(((To_Char(Sysdate, 'J') - 1 ) * 86400) + To_Char(Sysdate, 'SSSSS'))

            Into v_STime 

            From Sys.Dual;



        -- Espero a que el job haya procesado todos los registros del request_id                  

        WHILE v_cant_sin_procesar <> 0

        LOOP



            v_clob_int := AJC_BC_J_WS_UTILS_PKG.get_bc_clob_result_f ( p_url => v_url) ;



            SELECT count(*)

            INTO v_cant_sin_procesar

            FROM json_table( v_clob_int,

                         '$.value[*]' COLUMNS ( status VARCHAR2(4000) path '$.status',

                                                            requestID VARCHAR2(4000) path '$.requestID'))

            WHERE requestID=TO_CHAR(gv_request_id)

            AND status NOT IN ('Error','Success');



            print_log('Cantidad de registros sin procesar: '||v_cant_sin_procesar);



            IF v_cant_sin_procesar <> 0 THEN



                    SELECT TO_NUMBER(((TO_CHAR(SYSDATE, 'J') - 1 ) * 86400) + TO_CHAR(SYSDATE, 'SSSSS'))

                    INTO v_ETime 

                    FROM Sys.Dual;



                     IF ( (v_ETime - v_STime) >= 600 ) THEN

                        print_log('La espera del job demoró mas de 600 segundos. Se marcarán todos los registros como REJECTED'); 

                        EXIT;

                    END IF;



                 print_log('Espero 15 segundos');   

                DBMS_LOCK.sleep(15);

            END IF;



        END LOOP;



        FOR r_imp in c_imp(r_org.org_id) LOOP



            print_log ('');

            print_log ('>> Org_id: '||r_imp.org_id);

            print_log ('>> Vendor_id: '||r_imp.vendor_id);

            print_log ('>> Invoice_Type_lookup_Code: '||r_imp.invoice_type_lookup_code);

            print_log ('>> Invoice_num: '||r_imp.invoice_num);





            FOR r_bc_st in c_bc_status(v_clob_int,r_imp.invoice_id) LOOP



                v_exists :=1;

                p_error_message := null;

                print_log ('>> StatusTimeStamp: '||r_bc_st.StatusTimeStamp);

                print_log ('>> Status: '||r_bc_st.status);



                IF r_bc_st.status != 'Success' THEN



                    p_error_message := r_bc_st.statusRemarks;



                    print_log ('The invoice has not been imported. Errors: '||p_error_message);



                    UPDATE ajc_bc_abbyy_invoices_int

                      SET status_code = 'REJECTED'

                         ,error_message = 'The invoice has not been imported. Status: '|| r_bc_st.status||' - '||p_error_message

                         ,last_update_date = sysdate

                         ,request_id = gv_request_id

                    WHERE rowid = r_imp.row_id;



                    -- borro registros con error de la stage de BC

                    IF p_delete_flag = 'Y' THEN



                        BEGIN

                            -- borro lineas 

                           --

                            v_url := AJC_BC_J_WS_UTILS_PKG.get_base_inecta_url_f ( gv_bc_environment, v_company_id ) || v_api_del_line|| '('''||r_bc_st.invoiceID||''',0,0)'; 



                            print_log('v_url: ' || v_url);



                            v_clob_del := AJC_BC_J_WS_UTILS_PKG.delete_bc_row_f(v_url);



                            IF ( INSTR(v_clob_del,'error') != 0 )  THEN

                                    print_log('Error deleting invoice lines from BC stage table');

                                    print_log(v_clob_del);

                            ELSE

                                print_log('Invoice lines deleted from BC stage table');



                            END IF;     



                            -- borro headers                    

                           --

                          v_url := AJC_BC_J_WS_UTILS_PKG.get_base_inecta_url_f ( gv_bc_environment, v_company_id ) || v_api_del_hdr|| '('''||r_bc_st.invoiceID||''',0)'; 



                            print_log('v_url: ' || v_url);



                            v_clob_del := AJC_BC_J_WS_UTILS_PKG.delete_bc_row_f(v_url);



                            IF ( INSTR(v_clob_del,'error') != 0 )  THEN

                                    print_log('Error deleting invoice header from BC stage table');

                                    print_log(v_clob_del);

                            ELSE

                                print_log('Invoice Header deleted from BC stage table');



                            END IF;     



                        EXCEPTION

                        WHEN OTHERS THEN

                              print_log('Error deleting records from BC staging tables');

                              print_log(v_clob_del);       

                        END;

                    END IF;  -- fin borro registros



                    p_status := 'W';



                ELSE --Success



                    UPDATE ajc_bc_abbyy_invoices_int

                       SET status_code = 'SUCCESS'

                          ,last_update_date = sysdate

                          ,invoice_id = r_bc_st.invoiceID

                          ,request_id = gv_request_id

                    WHERE rowid = r_imp.row_id;



                    print_log ('Comprobante Importado. Invoice_id: '||r_bc_st.invoiceID);

                END IF;



            END LOOP;



            IF v_exists = 0 THEN

                print_log('El comprobante fue enviado a BC pero no se pudo obtener estado de procesamiento. Se marca como REJECTED');



                    UPDATE ajc_bc_abbyy_invoices_int

                       SET status_code = 'REJECTED'

                          ,error_message = 'The invoice was sent to BC, but the processing status could not be retrieved.'

                          ,last_update_date = sysdate

                          ,request_id = gv_request_id

                    WHERE rowid = r_imp.row_id;

            ELSE

                v_exists := 0;                        

            END IF;

        END LOOP;



   END LOOP; --org_ids



    IF p_status IS NULL THEN 

       p_status := 'S';

    ELSE

     RAISE e_cust_exception;

    END IF;



    print_log ('AJC_BC_ABBYY_INTERFACE_PK.VALIDATE_IMPORT (-)');



EXCEPTION 

 WHEN e_cust_exception THEN 

  p_status := 'W';

  print_log ('Hubo errores al importar los comprobantes');

  print_log ('AJC_BC_ABBYY_INTERFACE_PK.VALIDATE_IMPORT (!)');

 WHEN OTHERS THEN 

  p_status := 'E';

  p_error_message := 'Error OTHERS en AJC_BC_ABBYY_INTERFACE_PK.VALIDATE_IMPORT. Error: '||SQLERRM;

  print_log ('Hubo errores al importar los comprobantes');

  print_log ('AJC_BC_ABBYY_INTERFACE_PK.VALIDATE_IMPORT (!)');

END;



/*=========================================================================+

|                                                                          |

| Private Procedure                                                        |

|    run_import                                                            |

|                                                                          |

| Description                                                              |

|    Run Payables Invoices Import Process                                  |

|                                                                          |

|                                                                          |

| Parameters                                                               |

|    p_company_id                  IN     VARCHAR2  Company ID para ws BC.            |

|    p_status                  OUT     VARCAHR2  Codigo Estado.            |

|    p_error_message           OUT     VARCHAR2  Mensaje de Error.         |

|                                                                          |

+=========================================================================*/

procedure run_import (--p_company_id  IN VARCHAR2,

                                p_status OUT VARCHAR2

                                ,p_error_message OUT VARCHAR2) IS



  v_job_object_id     NUMBER;

  v_qty               NUMBER;

  e_cust_exception    EXCEPTION;



  v_request_id        NUMBER;

  v_message           VARCHAR2 (2000);

  v_conc_phase        VARCHAR2 (50);

  v_conc_status       VARCHAR2 (50);

  v_conc_dev_phase    VARCHAR2 (50);

  v_conc_dev_status   VARCHAR2 (50);

  v_conc_message      VARCHAR2 (250);

  v_clob_ret          CLOB;

  v_ws_status         VARCHAR2(10);



  CURSOR c_org_ids IS

  SELECT distinct org_id

    FROM AJC_BC_ABBYY_INVOICES_INT

   WHERE STATUS_CODE = 'SENT'

     AND request_id = gv_request_id; 



  v_company_id        VARCHAR2(100);

  v_status            VARCHAR2(1);



BEGIN



    print_log ('AJC_BC_ABBYY_INTERFACE_PK.RUN_IMPORT (+)');



    v_job_object_id := AJC_BC_J_WS_UTILS_PKG.get_object_id_f ( 'PURCHASE INVOICES' );

    print_log ( 'v_job_object_id: ' || v_job_object_id );



    print_log ('Verificando si existen comprobantes a importar');

    BEGIN



        SELECT COUNT(1)

          INTO v_qty

          FROM AJC_BC_ABBYY_INVOICES_INT

         WHERE STATUS_CODE = 'SENT'

           --AND ORG_ID = fnd_profile.value('ORG_ID')

           AND request_id = gv_request_id;

    EXCEPTION

     WHEN OTHERS THEN 

       p_error_message := 'Error retrieving number of invoices to import. Error: '||SQLERRM;

       RAISE e_cust_exception;

    END;



    print_log ('Cantidad: '||v_qty);



    IF v_qty > 0 THEN 



        FOR r_org IN c_org_ids LOOP



            print_log('org_id: '||r_org.org_id);



            AJC_BC_J_WS_UTILS_PKG.get_bc_company_id_f(r_org.org_id,NULL,NULL,v_company_id,v_status);        



            print_log('v_company_id: '||v_company_id);



            IF v_status = 'E' THEN

                    p_error_message := 'Error obtaining v_company_id. Error: '||SQLERRM;

                    v_company_id:=null;

                    RAISE e_cust_exception;

            END IF;





                v_clob_ret := ajc_bc_j_ws_utils_pkg.run_job_queue_f ( p_bc_environment => gv_bc_environment

                                                                   ,p_company_id => v_company_id

                                                                   ,p_object_id => v_job_object_id ); -- 70004 



                  IF ( INSTR(UPPER(v_clob_ret),'ERROR') = 0 ) THEN 

                        print_log('Job ejecutado ok');

                        v_ws_status := 'SUCCESS';               

                  ELSE  

                    print_log('Error al ejecutar le job 70004: '||v_clob_ret);

                     p_status :='W';

                     v_ws_status := 'ERROR';

                  END IF;



                    INSERT INTO AJC_BC_ABBYY_REQUESTS

                    VALUES

                    (gv_request_id,v_ws_status,v_clob_ret,SYSDATE);



                COMMIT;



        END LOOP;

    END IF;



    IF p_status IS NULL THEN 

     p_status := 'S';

    END IF;



    print_log ('AJC_BC_ABBYY_INTERFACE_PK.RUN_IMPORT (-)');



EXCEPTION

 WHEN OTHERS THEN 

  p_status := 'W';

  p_error_message := 'Error OTHERS en AJC_BC_ABBYY_INTERFACE_PK.RUN_IMPORT. Error: '||SQLERRM;

  print_log (p_error_message); 

  print_log ('AJC_BC_ABBYY_INTERFACE_PK.RUN_IMPORT (!)');



  INSERT INTO AJC_BC_ABBYY_REQUESTS

  VALUES

  (gv_request_id,'ERROR',v_clob_ret,SYSDATE);



  COMMIT;

END;



/*=========================================================================+

|                                                                          |

| Private Procedure                                                        |

|    insert_inv_header_bc                                                     |

|                                                                          |

| Description                                                              |

|    Insert invoices in BC                                                      |

|                                                                          |

|                                                                          |

| Parameters                                                               |

|    p_company_id                  IN     VARCHAR2  Company ID para ws BC.            |

|    p_invoice                   IN t_invoice_bc  Invoice Record           |

|    p_status                       OUT      VARCHAR2(1)    Resultado       |

|                                                                          |

+=========================================================================*/

PROCEDURE insert_inv_header_bc ( p_company_id IN VARCHAR2,

                                                    p_invoice IN t_invoice_bc,

                                                    p_status OUT VARCHAR2,

                                                    p_error_message OUT VARCHAR2) IS



    v_url           VARCHAR2(2000);          

    -- 20230414 v_api           VARCHAR2(100) := 'inboundPurchaseHeaderINE';

    v_api           VARCHAR2(100);

    v_body          VARCHAR2(2000);

    v_clob_result   CLOB;

    v_status        VARCHAR2(1);



BEGIN



    print_log('insert_inv_header_bc - Inicio');



    v_api := AJC_BC_J_WS_UTILS_PKG.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                             p_subentity => 'HEADERS',

                                             p_method => 'POST' );

    print_log ('v_api: ' || v_api);



    v_url := AJC_BC_J_WS_UTILS_PKG.get_base_inecta_url_f ( gv_bc_environment, p_company_id ) || v_api;



    print_log('v_url: ' || v_url);   



    APEX_JSON.initialize_clob_output;

    APEX_JSON.open_object;



    APEX_JSON.write('invoiceID',p_invoice.invoiceID);

    APEX_JSON.write('invoiceNo',p_invoice.invoiceNo);

    APEX_JSON.write('invoiceType',p_invoice.invoiceType);

    APEX_JSON.write('invoiceDate',p_invoice.invoiceDate);

    APEX_JSON.write('vendorNo',p_invoice.vendorNo);

    APEX_JSON.write('vendorSiteCode', p_invoice.vendorSiteCode);

    APEX_JSON.write('invoiceAmount', to_number(p_invoice.invoiceAmount) );

    APEX_JSON.write('invoiceCurrencyCode', p_invoice.invoiceCurrencyCode);

    APEX_JSON.write('exchangeRate', to_number(p_invoice.exchangeRate),TRUE);

    APEX_JSON.write('exchangeRateType', p_invoice.exchangeRateType, TRUE);

    APEX_JSON.write('exchangeDate', p_invoice.exchangeDate);

    APEX_JSON.write('baseAmount', to_number(p_invoice.baseAmount),TRUE);

    APEX_JSON.write('gLDate', p_invoice.glDate);

    APEX_JSON.write('organisationID', p_invoice.organisationID);

    APEX_JSON.write('description', substr(p_invoice.description,1,50),TRUE );

    APEX_JSON.write('termName', p_invoice.termName,TRUE);

    APEX_JSON.write('termsDate', p_invoice.termsDate,TRUE);

    APEX_JSON.write('dueDate', p_invoice.dueDate,TRUE);

    APEX_JSON.write('paymentMethodCode', p_invoice.paymentMethodCode,TRUE);

    APEX_JSON.write('payGroupCode', p_invoice.payGroupCode,TRUE);

    APEX_JSON.write('setofBooksID', p_invoice.setofBooksID ,TRUE);

    APEX_JSON.write('setofBooksName', p_invoice.setofBooksName,TRUE );

    APEX_JSON.write('accountsPayCode', p_invoice.accountsPayCode,TRUE);

    APEX_JSON.write('company', p_invoice.company ,TRUE);

    APEX_JSON.write('account', p_invoice.account,TRUE );

    APEX_JSON.write('accountDescription', p_invoice.accountDescription,TRUE);

    APEX_JSON.write('department', p_invoice.department ,TRUE);

    APEX_JSON.write('product', p_invoice.product ,TRUE);

    APEX_JSON.write('destination', p_invoice.destination,TRUE );

    APEX_JSON.write('origin', p_invoice.origin ,TRUE);

 --   APEX_JSON.write('intercompany', p_invoice.intercompany ,TRUE);

    APEX_JSON.write('pdfFileUrl',p_invoice.pdfFileUrl,TRUE);

    APEX_JSON.write('requestID',gv_request_id,TRUE); 

    APEX_JSON.write('office', p_invoice.office ,TRUE);

    APEX_JSON.write('source', p_invoice.source ,TRUE);



    APEX_JSON.close_object;



    v_body:=APEX_JSON.get_clob_output;



    print_log('v_body: '||v_body);                



    v_clob_result := AJC_BC_J_WS_UTILS_PKG.patch_post_bc_row_f ( p_url => v_url,

                                                                 p_request_header_name1 => 'Content-Type',

                                                                 p_request_header_value1 => 'application/json',

                                                                 p_request_header_name2 => NULL,

                                                                 p_request_header_value2 => NULL, 

                                                                 p_http_method => 'POST',

                                                                 p_body => v_body);  





    print_log('v_clob_result): '||v_clob_result);



    APEX_JSON.free_output;



    IF ( INSTR(v_clob_result,'error') != 0 ) THEN

        print_log(p_invoice.invoiceNo||' - Error.');

        p_status:='E';

        p_error_message:=SUBSTR(v_clob_result,INSTR(v_clob_result,'message') + 10);

    ELSE

        print_log(p_invoice.invoiceNo||' - Sent.');

        p_status:='S';

        p_error_message:=NULL;

      END IF;



    INSERT INTO AJC_BC_ABBYY_INV_WS 

    (

    request_id ,

    invoiceID ,

    invoiceNo ,

    lineNo  ,

    ws_url ,

    ws_body ,

    ws_response ,

    status ,

    creation_date  )

    VALUES

    (gv_request_id,

    p_invoice.invoiceID,

    p_invoice.invoiceNo,

    NULL,

    v_url,

    v_body,

    v_clob_result,

    DECODE(p_status,'S','SENT','REJECTED'),

    SYSDATE);



print_log('insert_inv_header_bc - Fin');



EXCEPTION

WHEN OTHERS THEN

    p_status:='E';

    print_log('Error: '||SQLERRM);

    p_error_message:='Error: '||SQLERRM;

END;



/*=========================================================================+

|                                                                          |

| Private Procedure                                                        |

|    insert_inv_line_bc                                                     |

|                                                                          |

| Description                                                              |

|    Insert invoice lines in BC                                                      |

|                                                                          |

|                                                                          |

| Parameters                                                               |

|    p_company_id                  OUT     VARCHAR2  Company ID para ws BC.            |

|    p_inv_line                     IN t_inv_line_bc  Invoice Line Record           |

|    p_status                       OUT      VARCHAR2(1)    Resultado       |

|                                                                          |

+=========================================================================*/

PROCEDURE insert_inv_line_bc (p_company_id  IN VARCHAR2,

                                              p_inv_line IN t_inv_line_bc,

                                              p_status OUT VARCHAR2,

                                              p_error_message OUT VARCHAR2) IS



    v_url           VARCHAR2(2000);          

    -- 20230414 v_api           VARCHAR2(100) := 'inboundPurchaseLineINE';

    v_api           VARCHAR2(100);

    v_body          VARCHAR2(2000);

    v_clob_result   CLOB;

    v_status        VARCHAR2(1);



BEGIN



    print_log('insert_inv_line_bc - Inicio');



    v_api := AJC_BC_J_WS_UTILS_PKG.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                             p_subentity => 'LINES',

                                             p_method => 'POST' );

    print_log ('v_api: ' || v_api);



    v_url := AJC_BC_J_WS_UTILS_PKG.get_base_inecta_url_f ( gv_bc_environment, p_company_id ) || v_api;



    print_log('v_url: ' || v_url);   



    APEX_JSON.initialize_clob_output;

    APEX_JSON.open_object;



    APEX_JSON.write('invoiceID', p_inv_line.invoiceID );

    APEX_JSON.write('lineNo', to_number(p_inv_line.lineNo) );

    APEX_JSON.write('amount', to_number(p_inv_line.amount ));

    APEX_JSON.write('description',substr(p_inv_line.description,1,50),TRUE );

    APEX_JSON.write('accountingDate', p_inv_line.accountingDate );

    APEX_JSON.write('periodName',p_inv_line.periodName );

    APEX_JSON.write('worksheetNo', p_inv_line.worksheetNo,TRUE);

    APEX_JSON.write('baseAmount',to_number(p_inv_line.baseAmount),TRUE); 

    APEX_JSON.write('exchangeRate',to_number(p_inv_line.exchangeRate),TRUE);

    APEX_JSON.write('exchangeRateType', p_inv_line.exchangeRateType ,TRUE);

    APEX_JSON.write('exchangeDate', p_inv_line.exchangeDate,TRUE );

    APEX_JSON.write('organisationID', p_inv_line.organisationID );

    APEX_JSON.write('setOfBooksID', p_inv_line.setofBooksID );

    APEX_JSON.write('setOfBooksName', p_inv_line.setofBooksName );

    APEX_JSON.write('distCodeCombination',p_inv_line.distCodeCombination );

    APEX_JSON.write('company', p_inv_line.company );

    APEX_JSON.write('account',p_inv_line.account );

    APEX_JSON.write('accountDescription',p_inv_line.accountDescription);

    APEX_JSON.write('department', p_inv_line.department);

    APEX_JSON.write('product',p_inv_line.product );

    APEX_JSON.write('destination', p_inv_line.destination );

    APEX_JSON.write('origin', p_inv_line.origin );

  --  APEX_JSON.write('intercompany',p_inv_line.intercompany);

    APEX_JSON.write('requestID',gv_request_id,TRUE);

    APEX_JSON.write('office',p_inv_line.office);



    APEX_JSON.close_object;



    v_body:=APEX_JSON.get_clob_output;



    print_log('v_body: '||v_body);





    v_clob_result := AJC_BC_J_WS_UTILS_PKG.patch_post_bc_row_f ( p_url => v_url,

                                                                 p_request_header_name1 => 'Content-Type',

                                                                 p_request_header_value1 => 'application/json',

                                                                 p_request_header_name2 => NULL,

                                                                 p_request_header_value2 => NULL, 

                                                                 p_http_method => 'POST',

                                                                 p_body => v_body );  



    print_log('v_clob_result): '||v_clob_result);



    APEX_JSON.free_output;



    IF ( INSTR(v_clob_result,'error') != 0 ) THEN

        print_log('Line: '||p_inv_line.lineNo||' - Error.');

        p_status:='E';

        p_error_message:=SUBSTR(v_clob_result,INSTR(v_clob_result,'message') + 10);

    ELSE

        print_log('Line: '||p_inv_line.lineNo||' - Sent.');

        p_status:='S';

        p_error_message:=NULL;

      END IF;



    INSERT INTO AJC_BC_ABBYY_INV_WS 

    (

    request_id ,

    invoiceID ,

    invoiceNo ,

    lineNo  ,

    worksheetNo ,

    description , 

    ws_url ,

    ws_body ,

    ws_response ,

    status ,

    creation_date  )

    VALUES

    (gv_request_id,

    p_inv_line.invoiceID,

    p_inv_line.invoiceNo,

    p_inv_line.lineNo,

    p_inv_line.worksheetNo,

    p_inv_line.description,    

    v_url,

    v_body,

    v_clob_result,

    DECODE(p_status,'S','SENT','REJECTED'),

    SYSDATE);



    print_log('insert_inv_line_bc - Fin');



EXCEPTION

WHEN OTHERS THEN

    p_status:='E';

    print_log('Error: '||SQLERRM);

    p_error_message:='Error: '||SQLERRM;

END;



/*=========================================================================+

|                                                                          |

| Private Function                                                        |

|    existe_ws                                                      |

|                                                                          |

| Description                                                              |

|    Verifica si el worksheet number fue creado en BC                                                       |

|                                                                          |

|                                                                          |

| Parameters                                                               |

|    p_ws                               IN     VARCHAR2  Codigo Estado.            |

|    p_company_id                  IN    VARCHAR2  Company ID para ws BC.            |

|                                                                          |

+=========================================================================*/

-- 20251014

FUNCTION get_ws ( p_ws           IN   VARCHAR2,

                  p_company_id   IN   VARCHAR2 ) RETURN VARCHAR2 IS



  v_ws       VARCHAR2(240);

  v_url      VARCHAR2(500);

  v_clob     CLOB;

  v_api_st   VARCHAR2(30);

  v_code     VARCHAR2(30);



BEGIN



  print_log('get_ws (+)');



  -- Se copia el valor del parametro a la variable

  v_ws := p_ws;



  v_api_st := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'WORKSHEETS',

                                              p_subentity => 'STATUS',

                                              p_method => 'GET' );



  v_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( gv_bc_environment, p_company_id ) || v_api_st || '?$filter=code eq ''' || v_ws || '''';

  print_log('v_url: ' || v_url);



  v_clob := ajc_bc_ws_utils_pkg.get_bc_clob_result_f (v_url);

  print_log('v_clob: ' || v_clob);



  -- 20251103

  -- Da error porque viene con algun separador que no es | e intenta ver si el string de worksheets todo junto existe en BC

  IF ( UPPER(v_clob) LIKE UPPER('%"error":{%') ) THEN



    v_ws := 'N/A';



  -- No existe el valor original

  ELSIF ( v_clob LIKE '%:[]%' ) THEN

  -- IF ( v_clob LIKE '%:[]%' ) THEN

  -- 20251103



    print_log('No existe sin prefijo');



    -- Se vuelve a buscar, pero con el prefijo PO

    v_ws := 'PO' || v_ws;

    v_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( gv_bc_environment, p_company_id ) || v_api_st || '?$filter=code eq ''' || v_ws || '''';

    v_clob := ajc_bc_ws_utils_pkg.get_bc_clob_result_f (v_url);



    -- No existe el valor con prefijo

    IF ( v_clob LIKE '%:[]%' ) THEN



      print_log('No existe con prefijo');



      v_ws := 'N/A';



    END IF;



  END IF;    



  print_log('ws: ' || v_ws);

  print_log('get_ws (-)');



  RETURN v_ws;



EXCEPTION

  WHEN OTHERS THEN

    print_log('get_ws (!)');

    RETURN 'N/A';



END get_ws;

/*FUNCTION existe_ws ( p_ws           IN   VARCHAR2,

                     p_company_id   IN   VARCHAR2 ) RETURN BOOLEAN IS



  v_url      VARCHAR2(500);

  v_clob     CLOB;

  -- 20230414 v_api_st VARCHAR2(30):='worksheetDimensionINE';

  v_api_st   VARCHAR2(30);

  v_code     VARCHAR2(30);



BEGIN



  v_api_st := AJC_BC_J_WS_UTILS_PKG.get_api_f ( p_entity => 'WORKSHEETS',

                                              p_subentity => 'STATUS',

                                              p_method => 'GET' );

  print_log ('v_api_st: ' || v_api_st);



  v_url := AJC_BC_J_WS_UTILS_PKG.get_base_inecta_url_f (gv_bc_environment, p_company_id) ||v_api_st || '?$filter=code eq '''||p_ws||''''; --consulto en master data para ver si existe el ws, si todavía no se replicó, ingresará en la próxima ejecución despues del sync con las compañias



  print_log('v_url: ' || v_url);



  v_clob := AJC_BC_J_WS_UTILS_PKG.get_bc_clob_result_f (v_url);



    BEGIN

        SELECT 

            code

         INTO v_code

        FROM json_table( v_clob ,

                         '$.value[*]' COLUMNS ( 

                                                            dimensionCode   VARCHAR2(4000)  path '$.dimensionCode' ,

                                                            code   VARCHAR2(4000) path '$.code',

                                                            name VARCHAR2(4000) path '$.name'));



        IF v_code =  p_ws THEN

            RETURN (TRUE);

        ELSE

            RETURN (FALSE);

        END IF;



    EXCEPTION

    WHEN OTHERS THEN

        RETURN (FALSE);                                                            

    END;

END;

*/

--20251014

/*=========================================================================+

|                                                                          |

| Private Procedure                                                        |

|    process_invoices                                                      |

|                                                                          |

| Description                                                              |

|    Invoice Process                                                       |

|                                                                          |

|                                                                          |

| Parameters                                                               |

|    p_status                  OUT     VARCHAR2  Codigo Estado.            |

|    p_error_message           OUT     VARCHAR2  Mensaje de Error.         |

|    p_exchange_rate_type       IN     VARCHAR2  Tipo de Cambio            |

|    p_company_id                  OUT     VARCHAR2  Company ID para ws BC.            |

|                                                                          |

+=========================================================================*/

PROCEDURE process_invoices (p_status            OUT VARCHAR2

                           ,p_error_message     OUT VARCHAR2) IS

                        --   ,p_company_id    IN VARCHAR2) IS



  CURSOR c_inv is 



  SELECT rowid row_id,org_id,vendor_id,vendor_site_code,invoice_num invoice_num,invoice_date,invoice_type_lookup_code,

         invoice_amount,invoice_currency_code,description,worksheet_number,status_code,request_id,

         decode(SUBSTR(file_path,1,2),'\\', 'http://'||REPLACE(SUBSTR(file_path,3),'\','/'),file_path) file_path,last_update_date,creation_date,error_message,vendor_num,vendor_name

    FROM AJC_BC_ABBYY_INVOICES_INT a

   WHERE ORG_ID != 5387-- LOGIS-USA-USD

     AND TRUNC(creation_date) >= TO_DATE('15/10/2025','DD/MM/YYYY')

     AND UPPER(NVL(error_message,'-')) NOT LIKE '%PURCHASE INVOICE%ALREADY EXISTS FOR THIS VENDOR%' --excluyo las facturas que ya existen en BC para que no siga reprocesandolas infinitamente   

 -- AND invoice_num in ('1032200','8505879948','CIN0288715','0600139514','135695')

     AND ( ( status_code = 'NEW' AND request_id IS NULL ) OR

           ( status_code IN ('ERROR','REJECTED') AND request_id IS NOT NULL ) )

     AND NOT EXISTS ( SELECT 1

                        FROM ap_invoices_all ai

                       WHERE ai.vendor_id = a.vendor_id

                         AND ai.invoice_num = a.invoice_num );



v_invoice_id         ap_invoices_all.invoice_id%type; 

v_line_number        ap_invoice_lines_interface.line_number%type;

v_vendor_id         po_vendors.vendor_id%type;

v_vendor_site_id  po_vendor_sites_all.vendor_site_id%type;

v_func_currency_code gl_sets_of_books.currency_code%type;

v_vendor_type_lookup_code po_vendors.vendor_type_lookup_code%type;

v_company            gl_code_combinations.segment1%type;

v_account            gl_code_combinations.segment2%type;

v_account2           gl_code_combinations.segment2%type;

v_qty_prepay         NUMBER;

v_ws_qty             NUMBER;

v_ws                 VARCHAR2(240);

v_total_ws_amount    NUMBER;

v_accrual_amount     NUMBER;

v_total_func_amount  NUMBER;

v_diference          NUMBER;

v_conversion_rate_tol NUMBER;

v_tolerance_func     NUMBER;

v_conversion_rate    gl_daily_rates.conversion_rate%type; 

v_exclude            VARCHAR2(1);



v_amount_dif NUMBER;

v_qty_lin NUMBER;



e_inv_exception      EXCEPTION;

e_cust_exception     EXCEPTION;



v_invoice_bc    t_invoice_bc;

v_inv_line_bc    t_inv_line_bc;

v_status    VARCHAR2(1);

v_period_name gl_periods.period_name%TYPE;

v_org_id    NUMBER;

v_company_id    VARCHAR2(100);

v_bc_account VARCHAR2(50);

v_oracle_account VARCHAR2(50);

v_error_message VARCHAR2(1000);

v_bc_company_name VARCHAR2(50);

v_result NUMBER;



BEGIN



    print_log ('AJC_BC_ABBYY_INTERFACE_PK.PROCESS_INVOICES (+)');



    print_log('Obteniendo periodo contable para SYSDATE.');



    BEGIN



            SELECT period_name

               INTO v_period_name

            FROM gl_periods gp

            WHERE 1=1

             AND gp.adjustment_period_flag = 'N'

             AND gp.period_set_name = 'AJC CALENDAR'

             -- 20251231 - SBANCHIERI

             -- AND SYSDATE BETWEEN start_date AND end_date;

             AND TRUNC(SYSDATE) BETWEEN start_date AND end_date;

             -- 20251231 - SBANCHIERI



    EXCEPTION

     WHEN OTHERS THEN

        p_error_message := 'Error retrieving accounting period. Error: '||SQLERRM;

        RAISE e_inv_exception; 

    END;



    print_log('Periodo Contable: '||v_period_name);



    FOR r_inv IN c_inv LOOP



        print_log('');

        print_log('>> org_id: '||r_inv.org_id);

        print_log('>> vendor_id: '||r_inv.vendor_id);

        print_log('>> invoice_type_lookup_code: '||r_inv.invoice_type_lookup_code);

        print_log('>> invoice_num: '||r_inv.invoice_num);



        print_log ('Obteniendo Segmento Compa?ia');



        BEGIN

            select gcc.segment1

            into v_company

            from gl_code_combinations gcc

            ,financials_system_params_all fsp

            where gcc.code_combination_id = fsp.accts_pay_code_combination_id

            and org_id = r_inv.org_id;--fnd_profile.value('ORG_ID');

        EXCEPTION

          WHEN OTHERS THEN

            p_error_message := 'Error retrieving company segment from system financial parameters. Error: '||SQLERRM;

            RAISE e_cust_exception;

        END;



        print_log (' Segmento Compañia: '||v_company);



        print_log ('Obteniendo v_company_id');



        AJC_BC_J_WS_UTILS_PKG.get_bc_company_id_f(r_inv.org_id,NULL,NULL,v_company_id,v_status);        



        IF v_status = 'E' THEN

                v_error_message := 'Error obtaining v_company_id. Error: '||SQLERRM;

                v_company_id:=null;

                RAISE e_cust_exception;

        END IF;



        print_log ('v_company_id:'||v_company_id);



        IF r_inv.status_code IN ('ERROR','REJECTED') THEN --Elimino las lineas para reconstruir por si los ws cambian



/*           DELETE ajc_bc_abbyy_inv_lines_int

            WHERE org_id = r_inv.org_id

              AND vendor_id = r_inv.vendor_id

              and vendor_site_code = r_inv.vendor_site_code

              and invoice_type_lookup_code = r_inv.invoice_type_lookup_code

              and invoice_num = r_inv.invoice_num;*/



           UPDATE ajc_bc_abbyy_invoices_int

           set error_message = null

           where rowid = r_inv.row_id;



           COMMIT; 

        END IF;



      BEGIN



        v_invoice_bc :=NULL;

        v_vendor_id :=NULL;

        v_vendor_site_id:=NULL;

        v_invoice_bc.organisationID := r_inv.org_id;





        -- Fin Agregado SBanchieri 20211102

        v_invoice_bc.glDate := TO_CHAR(TRUNC(SYSDATE),'YYYY-MM-DD');



        print_log('valido proveedor');



        IF r_inv.vendor_id IS NULL THEN

          p_error_message := 'No supplier has been specified.'; 

          RAISE e_inv_exception;

        END IF;



       IF r_inv.vendor_num IS NULL THEN

          p_error_message := 'vendor_num not found in Oracle.'; 

          RAISE e_inv_exception;

       END IF;



          v_invoice_bc.vendorNo := r_inv.vendor_num;



          print_log('valido si esta activo y obtengo el tipo de proveedor');



          BEGIN



            SELECT pv.vendor_id,pv.vendor_type_lookup_code

                   -- Inicio Agregado SBanchieri 04122020

                   ,NVL(pv_dfv.ajc_ap_re_val_exclude,'N')

                   --

              INTO v_vendor_id,v_vendor_type_lookup_code

                   -- Inicio Agregado SBanchieri 04122020

                   ,v_exclude

                   --

              FROM po_vendors pv,

                   -- Inicio Agregado SBanchieri 04122020

                   po_vendors_dfv pv_dfv

                   --

             WHERE vendor_id = r_inv.vendor_id

               AND enabled_flag = 'Y'

               -- Corregido SBanchieri 20240319

               -- AND NVL(start_date_active,TRUNC(SYSDATE)) <= TRUNC(SYSDATE)

               AND NVL(TRUNC(start_date_active),TRUNC(SYSDATE)) <= TRUNC(SYSDATE)

               -- AND NVL(end_date_active,TRUNC(SYSDATE)) >= TRUNC(SYSDATE)

               AND NVL(TRUNC(end_date_active),TRUNC(SYSDATE)) >= TRUNC(SYSDATE)

               -- Corregido SBanchieri 20240319

               -- Inicio Agregado SBanchieri 04122020

               AND pv.rowid = pv_dfv.row_id

               --

               ;



          EXCEPTION 

            WHEN NO_DATA_FOUND THEN 

               p_error_message := 'Vendor: '||r_inv.vendor_name||' is not active in Oracle';

               RAISE e_inv_exception;

            WHEN OTHERS THEN 

               p_error_message := 'Error validating if vendor: '||r_inv.vendor_name||' is active in Oracle. Error: '||SQLERRM;

               RAISE e_inv_exception; 

          END;



          print_log ('Proveedor activo');

          print_log ('Vendor_type_lookup_code : '||v_vendor_type_lookup_code);



          IF v_vendor_type_lookup_code is not null then 



              BEGIN



                SELECT flv_dfv.ajc_ap_accrual_account

                  INTO v_account

                  FROM fnd_lookup_values flv

                      ,fnd_lookup_values_dfv flv_dfv

                 WHERE flv.rowid = flv_dfv.row_id

                   AND flv.lookup_type = 'VENDOR TYPE'

                   AND flv.lookup_code = v_vendor_type_lookup_code

                   AND enabled_flag = 'Y'

                   AND NVL(start_date_active,TRUNC(SYSDATE)) <= TRUNC(SYSDATE)

                   AND NVL(end_date_active,TRUNC(SYSDATE)) >= TRUNC(SYSDATE);



              EXCEPTION 

                WHEN NO_DATA_FOUND THEN 

                   p_error_message := 'Vendor: '|| r_inv.vendor_name||' is not active in Oracle';

                   RAISE e_inv_exception;

                WHEN OTHERS THEN 

                   p_error_message := 'Error validating if vendor: '|| r_inv.vendor_name||' is active in Oracle. Error: '||SQLERRM;

                   RAISE e_inv_exception; 

              END;



         END IF;



        print_log ('Verificando Sucursal del proveedor');



          print_log ('Sucursal: '||r_inv.vendor_site_code);

          v_invoice_bc.vendorSiteCode := r_inv.vendor_site_code;



        IF r_inv.vendor_site_code IS NULL THEN

          p_error_message := 'No supplier address has been specified.'; 

          RAISE e_inv_exception;



        END IF;



        IF r_inv.invoice_type_lookup_code NOT IN ('STANDARD','CREDIT') THEN 

          p_error_message := 'Invoice type: '''||r_inv.invoice_type_lookup_code||''' is not valid';

          RAISE e_inv_exception;

        ELSE



          v_invoice_bc.invoiceType := r_inv.invoice_type_lookup_code;



          print_log ('Invoice_type_lookup_code: '||r_inv.invoice_type_lookup_code);



--          IF r_inv.invoice_type_lookup_code = 'CREDIT' THEN

--             v_invoice_bc.invoiceAmount := r_inv.invoice_amount*-1;

--          ELSE

             v_invoice_bc.invoiceAmount := r_inv.invoice_amount;

--          END IF;



          print_log ('Invoice_amount: '||v_invoice_bc.invoiceAmount);



        END IF;



          v_invoice_bc.invoiceNo := r_inv.invoice_num;



        v_invoice_bc.invoiceDate  := to_char(r_inv.invoice_date,'yyyy-mm-dd');



        IF r_inv.invoice_currency_code IS NULL THEN   -- MB REVISAR 

          print_log('No se informo una moneda, buscando la moneda de la sucursal');

          BEGIN



            select NVL(pvs.invoice_currency_code,pv.invoice_currency_code)

              into v_invoice_bc.invoiceCurrencyCode

              from po_vendor_sites_all pvs

                  ,po_vendors pv

             where pvs.org_id = r_inv.org_id--fnd_profile.value('ORG_ID')

             and pv.vendor_id = r_inv.vendor_id

             and pv.vendor_id = pvs.vendor_id

             and vendor_site_code = r_inv.vendor_site_code

             and NVL(pvs.invoice_currency_code,pv.invoice_currency_code) is not null;



          EXCEPTION    

             when others then 

               p_error_message := 'No currency has been provided, and the supplier has no currency configured. Error: '||SQLERRM;

               RAISE e_inv_exception;  

          END;

        ELSE



          print_log('Validando Moneda informada: '||r_inv.invoice_currency_code);



          BEGIN



            select currency_code

              into v_invoice_bc.invoiceCurrencyCode

              from fnd_currencies_vl

             where currency_code = r_inv.invoice_currency_code;



          EXCEPTION 

           WHEN NO_DATA_FOUND THEN 

             p_error_message := 'Currency code: '||r_inv.invoice_currency_code||' does not exist in Oracle. Error: '||SQLERRM;

             RAISE e_inv_exception;

           WHEN OTHERS THEN 

             p_error_message := 'Error validating currency code: '||r_inv.invoice_currency_code||'. Error: '||SQLERRM;

             RAISE e_inv_exception;

          END;

        END IF;



        IF r_inv.description IS NULL THEN 

            v_invoice_bc.description := r_inv.worksheet_number;

        ELSE

            IF r_inv.worksheet_number IS NOT NULL THEN

              v_invoice_bc.description := r_inv.description || '. '||r_inv.worksheet_number;

            ELSE

              v_invoice_bc.description := r_inv.description;

            END IF;



        END IF;



        SELECT ap_invoices_interface_s.NEXTVAL

        INTO v_invoice_bc.invoiceId

        FROM dual;



        v_account2 := null;



        BEGIN

                SELECT description

                  INTO v_account2

                  FROM fnd_lookup_values_vl

                 WHERE lookup_type = 'AJC_AP_ABBYY_VENDOR_ACCT_MAP'

                   AND lookup_code = r_inv.vendor_num

                   -- 20230227 Se agrega que mire solo los activos

                   AND enabled_flag = 'Y'

                   AND NVL(start_date_active,TRUNC(SYSDATE)) <= TRUNC(SYSDATE)

                   AND NVL(end_date_active,TRUNC(SYSDATE)) >= TRUNC(SYSDATE)

                   -- 20230227 

                   ;



        EXCEPTION

         WHEN OTHERS THEN

            v_account2 := null;

        END;



        v_qty_prepay := 0; 

        print_log('After prepays');



            v_inv_line_bc := null;



            v_inv_line_bc.invoiceID := v_invoice_bc.invoiceId;

            v_inv_line_bc.invoiceNo :=  v_invoice_bc.invoiceNo;

            v_inv_line_bc.lineNo := 1;

            v_inv_line_bc.amount :=v_invoice_bc.invoiceAmount;

            v_inv_line_bc.description :=  v_invoice_bc.description;

            v_inv_line_bc.organisationID := v_invoice_bc.organisationID;



              -- MB hardcodeos a reemplazar

              v_inv_line_bc.accountingDate := TO_CHAR(SYSDATE,'yyyy-mm-dd');

              v_inv_line_bc.periodName := v_period_name;



              -- 20251014

              -- v_inv_line_bc.worksheetNo := r_inv.worksheet_number;

              v_inv_line_bc.worksheetNo := get_ws ( r_inv.worksheet_number, v_company_id );

              -- 20251014



              v_inv_line_bc.baseAmount := 0;

              --v_inv_line_bc.exchangeRate := 0;

              --v_inv_line_bc.exchangeRateType := p_exchange_rate_type;

              v_inv_line_bc.exchangeDate := TO_CHAR(r_inv.invoice_date,'yyyy-mm-dd');

               v_inv_line_bc.setofBooksID := '1';

                v_inv_line_bc.setofBooksName := 'AJC TRADING';

                v_inv_line_bc.distCodeCombination := '-1';

                v_inv_line_bc.company := v_company;



                -- MB: Obtengo mapeo de cuentas para BC

                IF v_account2 IS NOT NULL or v_account IS NOT NULL THEN

                    BEGIN



                        v_oracle_account := nvl(v_account2,v_account);



                        SELECT bc_account

                        INTO v_bc_account 

                        FROM AJC_BC_ACCOUNTS

                        WHERE oracle_account=v_oracle_account;



                    EXCEPTION

                    WHEN OTHERS THEN

                         p_error_message := 'Error retrieving Oracle account mapping: '||v_oracle_account||' with BC. Error: '||SQLERRM;

                         RAISE e_inv_exception;                    

                    END;

                ELSE -- no se pudo obtener cuenta por tipo de proveedor o proveedor, se usa el default - nueva cuenta ZERO

                        v_bc_account := gv_dft_account; -- no requiere mapeo

                        v_inv_line_bc.amount :=0;-- Modified KHRONUS/MBetti 20230830: Line amount must be 0 if account is ZERO             

                END IF;



                v_inv_line_bc.account := v_bc_account;

                v_inv_line_bc.accountDescription := v_bc_account;



                v_inv_line_bc.department := ajc_bc_j_account_dim_pkg.account_dim_required(v_inv_line_bc.account,'DEPARTMENT', '000');





                v_inv_line_bc.product:= ajc_bc_j_account_dim_pkg.account_dim_required(v_inv_line_bc.account,'PRODUCT', '000');





                v_inv_line_bc.destination := ajc_bc_j_account_dim_pkg.account_dim_required(v_inv_line_bc.account,'DESTINATION', '000');





                v_inv_line_bc.origin := ajc_bc_j_account_dim_pkg.account_dim_required(v_inv_line_bc.account,'ORIGIN', '000');





         --       v_inv_line_bc.intercompany := '00';         



                print_log('Before get_dimension_value');





                v_inv_line_bc.office := NVL(AJC_BC_J_UTILS_PKG.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                                ,p_oracle_value   => '000'

                                                                                                ,p_bc_dimension   => 'OFFICE'),'000');



                v_inv_line_bc.office := ajc_bc_j_account_dim_pkg.account_dim_required(v_inv_line_bc.account,'OFFICE', v_inv_line_bc.office);



                print_log('After get_dimension_value');



                -- End Modified KHRONUS/PBonadeo 20221211: Changed after Santiago change of  ajc_bc_j_account_dim_pkg.account_dim_required                



            -- determino cantidad de worksheets

                SELECT CASE WHEN INSTR(REPLACE(r_inv.worksheet_number,' '),'|') > 0 then

                 (SELECT DECODE(substr(REPLACE(r_inv.worksheet_number,' '),-1)

                 ,'|',REGEXP_COUNT(REPLACE(REPLACE(r_inv.worksheet_number,' '),'|','@'),'@')

                     ,REGEXP_COUNT(REPLACE(REPLACE(r_inv.worksheet_number,' '),'|','@'),'@')+1)

                from dual)

                ELSE

                1 end 

                into v_ws_qty

                from dual;



            print_log('llamando al ws de para insertar linea');



            v_ws := NULL;



            IF v_ws_qty > 1 THEN

                FOR i IN 1..v_ws_qty LOOP



                    v_ws := get_text(REPLACE(r_inv.worksheet_number,' '),i);



                    v_status:=NULL;

                    v_error_message:=NULL;



                   v_inv_line_bc.lineNo := i;



                   -- Modified KHRONUS/MBetti 20230830: If account is <> ZERO .9890,  invoice amount per ws is assigned , otherwise zero amount is assigned by previous default

                   --   v_inv_line_bc.amount := round(v_invoice_bc.invoiceAmount/v_ws_qty,2);

                   IF v_inv_line_bc.account != gv_dft_account THEN -- si la cuenta es ZERO .9890 queda el amount en 0 seteado previamente

                         v_inv_line_bc.amount := round(v_invoice_bc.invoiceAmount/v_ws_qty,2);

                   END IF;



                   v_inv_line_bc.description :=  v_ws;



                   -- 20251014

                   /*

                   IF existe_ws(v_ws,v_company_id) THEN -- verifico si existe en BC

                     v_inv_line_bc.worksheetNo := v_ws; 

                   ELSE

                     v_inv_line_bc.worksheetNo := 'N/A'; --ex NULL;-- ex 'NA'

                   END IF;     

                   */

                   v_inv_line_bc.worksheetNo := get_ws ( v_ws, v_company_id );

                   -- 20251014



                   insert_inv_line_bc (v_company_id,v_inv_line_bc,v_status,v_error_message);



                    IF v_status = 'E' THEN

                        p_error_message := 'Error inserting invoice line record into BC staging table: '||v_error_message;

                        RAISE e_inv_exception;

                    END IF;



                END LOOP; 

            ELSE

                BEGIN 

                    v_status:=NULL;

                    v_error_message:=NULL;



                    v_ws :=r_inv.worksheet_number;



                    -- 20251014

                    /*

                    IF NOT existe_ws(v_ws,v_company_id) THEN -- verifico si existe en BC

                      v_inv_line_bc.worksheetNo := 'N/A'; -- ex NULL; --ex 'NA'

                    END IF;   

                    */

                    IF ( get_ws ( v_ws, v_company_id ) = 'N/A' ) THEN



                      v_inv_line_bc.worksheetNo := 'N/A';



                    END IF;

                    -- 20251014



                   insert_inv_line_bc (v_company_id,v_inv_line_bc,v_status,v_error_message);



                    IF v_status = 'E' THEN

                        p_error_message := 'Error inserting invoice line record into BC staging table: '||v_error_message;

                        RAISE e_inv_exception;

                    END IF;



                END;

            END IF;



        -- MB: Fin inserta lineas. Se descomenta luego de verificar insercion de cabecera

        BEGIN       



           v_status := NULL;

           v_error_message:=NULL;

           -- MB: campos pendientes de derivar automaticamente. Quitar hardcodeo

           --v_invoice_bc.exchangeRate := 0;

           v_invoice_bc.exchangeDate := TO_CHAR(r_inv.invoice_date,'yyyy-mm-dd');

           v_invoice_bc.baseAmount := 0;

           --v_invoice_bc.termName := 'NET 14';

           v_invoice_bc.termsDate := TO_CHAR(r_inv.invoice_date,'yyyy-mm-dd');

           v_invoice_bc.dueDate := TO_CHAR(r_inv.invoice_date + 14,'yyyy-mm-dd');

           v_invoice_bc.paymentMethodCode := 'EFT';

           v_invoice_bc.payGroupCode := 'FREIGHT';

           v_invoice_bc.setofBooksID := '1';

            v_invoice_bc.setofBooksName := 'AJC TRADING';

            --v_invoice_bc.accountsPayCode := '1003'; -- no sirve en BC

            v_invoice_bc.company := v_company;

            v_invoice_bc.account := '2000';

            v_invoice_bc.accountDescription := 'ACCOUNTS PAYABLE-TRADE';



                v_invoice_bc.department := '';

                v_invoice_bc.product := '';

                v_invoice_bc.destination := '';

                v_invoice_bc.origin := '';

                v_invoice_bc.office := '';



           -- End Modified KHRONUS/PBonadeo 20221210: Account 2000 defined with all dimensions null     



          --  v_invoice_bc.intercompany := '00';

            v_invoice_bc.pdfFileUrl := r_inv.file_path;

            v_invoice_bc.source := 'ABBYY';





           insert_inv_header_bc (v_company_id,v_invoice_bc,v_status,v_error_message);



           IF v_status = 'E' THEN

                p_error_message := 'Error inserting invoice header record into BC staging table: '||v_error_message;

                RAISE e_inv_exception;

           END IF;

        END;



           UPDATE ajc_bc_abbyy_invoices_int

              SET status_code = 'SENT'

                 ,request_id = gv_request_id

                 ,invoice_id = v_invoice_bc.invoiceId

                 ,last_update_date = sysdate

                 ,last_updated_by = gv_user_id

                 ,last_update_login = gv_login_id

            WHERE rowid = r_inv.row_id;



            COMMIT;



      EXCEPTION

        WHEN e_inv_exception THEN 

           print_log (p_error_message);



          -- MB 20251201 se comenta rollback para poder atrapar error ORA-29259 en tabla AJC_BC_ABBYY_INV_WS 

          -- ROLLBACK;



           UPDATE ajc_bc_abbyy_invoices_int

              SET status_code = 'ERROR'

                 ,error_message = p_error_message

                 ,request_id = gv_request_id

                 ,last_update_date = sysdate

                 ,last_updated_by = gv_user_id

                 ,last_update_login = gv_login_id

                 ,invoice_id = v_invoice_bc.invoiceId

            WHERE rowid = r_inv.row_id;



            p_status := 'W';



            COMMIT;



        WHEN OTHERS THEN 

           p_error_message := 'Error OTHERS when processing the invoice: '||r_inv.invoice_num||'. Error: '||SQLERRM;

           print_log (p_error_message);



          -- MB 20251201 se comenta rollback para poder atrapar error ORA-29259 en tabla AJC_BC_ABBYY_INV_WS 

          -- ROLLBACK;



           UPDATE ajc_bc_abbyy_invoices_int

              SET status_code = 'ERROR'

                 ,error_message = p_error_message

                 ,request_id = gv_request_id

                 ,last_update_date = sysdate

                 ,last_updated_by = gv_user_id

                 ,last_update_login = gv_login_id

                 ,invoice_id = v_invoice_bc.invoiceId

            WHERE rowid = r_inv.row_id;



            COMMIT;



            p_status := 'W';

      END;



    END LOOP;



    IF p_status IS NULL THEN 

      p_status := 'S';

      print_log ('AJC_BC_ABBYY_INTERFACE_PK.PROCESS_INVOICES (-)');

    ELSE

      print_log ('AJC_BC_ABBYY_INTERFACE_PK.PROCESS_INVOICES (!)');

    END IF;



EXCEPTION

 WHEN e_cust_Exception THEN 

    p_status := 'W';

    print_log (p_error_message);

    print_log ('AJC_BC_ABBYY_INTERFACE_PK.PROCESS_INVOICES (!)');

 WHEN OTHERS THEN

    p_status := 'W';

    p_error_message := 'Error OTHERS in AJC_BC_ABBYY_INTERFACE_PK.PROCESS_INVOICES. Error: '||SQLERRM;

    print_log (p_error_message);

    print_log ('AJC_BC_ABBYY_INTERFACE_PK.PROCESS_INVOICES (!)');

END;



PROCEDURE delete_interfaces(p_company_id IN VARCHAR2

                                            ,p_status         OUT VARCHAR2

                                            ,p_error_message  OUT VARCHAR2) IS



CURSOR c_bc_status (p_clob_result IN CLOB) IS

    SELECT 

        documentType,

        invoiceID,

        invoiceNo,

        invoiceType,

        invoiceDate,

        vendorNo,

        glDate,

        status,

        StatusRemarks,

        StatusTimeStamp,

        requestID

    FROM json_table( p_clob_result,

                     '$.value[*]' COLUMNS ( documentType     VARCHAR2(4000)  path '$.documentType',

                                                        invoiceID   VARCHAR2(4000)  path '$.invoiceID' ,

                                                        invoiceNo   VARCHAR2(4000) path '$.invoiceNo',

                                                        invoiceType VARCHAR2(4000) path '$.invoiceType',

                                                        invoiceDate VARCHAR2(4000) path '$.invoiceDate',

                                                        vendorNo VARCHAR2(4000) path '$.vendorNo',

                                                        glDate VARCHAR2(4000) path '$.gLDate',

                                                        status VARCHAR2(4000) path '$.status',

                                                        StatusRemarks VARCHAR2(4000) path '$.statusRemarks',

                                                        StatusTimeStamp VARCHAR2(4000) path '$.statusTimestamp',

                                                        requestID VARCHAR2(4000) path '$.requestID'))

    WHERE status = 'Error';



  v_exists NUMBER:=0;

  e_cust_exception EXCEPTION;

  v_url VARCHAR2(500);

  -- 20230414 v_api_st VARCHAR2(100):= 'inboundpurchaseintegrationstatusINE';

  v_api_st VARCHAR2(100);



  -- 20230414 v_api_del_line VARCHAR2(100):= 'inboundPurchaseLineINE';

  v_api_del_line VARCHAR2(100);



  -- 20230414 v_api_del_hdr VARCHAR2(100):= 'inboundPurchaseHeaderINE';

  v_api_del_hdr VARCHAR2(100);



  v_clob_int   CLOB;

  v_clob_del CLOB;

  v_qty NUMBER:=0;



BEGIN



    print_log ('AJC_BC_ABBYY_INTERFACE_PK.DELETE_INTERFACES (+)');

    print_log ('Se obtienen los comprobantes con error en stage a eliminar.');



    v_api_st := AJC_BC_J_WS_UTILS_PKG.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                                p_subentity => 'STATUS',

                                                p_method => 'GET' );

    print_log ('v_api_st: ' || v_api_st);



    v_api_del_line := AJC_BC_J_WS_UTILS_PKG.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                                      p_subentity => 'LINES',

                                                      p_method => 'DELETE' );

    print_log ('v_api_del_line: ' || v_api_del_line);



    v_api_del_hdr := AJC_BC_J_WS_UTILS_PKG.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                                     p_subentity => 'HEADERS',

                                                     p_method => 'DELETE' );

    print_log ('v_api_del_hdr: ' || v_api_del_hdr);



    v_url := AJC_BC_J_WS_UTILS_PKG.get_base_inecta_url_f ( gv_bc_environment, p_company_id ) || v_api_st; 



    print_log('v_url: ' || v_url);   



    v_clob_int := AJC_BC_J_WS_UTILS_PKG.get_bc_clob_result_f ( p_url => v_url) ;





        FOR r_bc_st in c_bc_status(v_clob_int) LOOP



            v_exists :=1;

            p_error_message := null;

            print_log ('>>invoiceID: '||r_bc_st.invoiceID);

            print_log ('>>invoiceNo: '||r_bc_st.invoiceNo);

            print_log ('>>vendorNo: '||r_bc_st.vendorNo);

            print_log ('>>StatusRemarks: '||r_bc_st.StatusRemarks);

            print_log ('>>requestID: '||r_bc_st.requestID);



                p_error_message := r_bc_st.statusRemarks;



                -- borro registros con error de la stage de BC

                BEGIN

                    -- borro lineas 

                   --

                    v_url := AJC_BC_J_WS_UTILS_PKG.get_base_inecta_url_f ( gv_bc_environment, p_company_id ) || v_api_del_line|| '('''||r_bc_st.invoiceID||''',0)'; 



                    print_log('v_url: ' || v_url);



                    v_clob_del := AJC_BC_J_WS_UTILS_PKG.delete_bc_row_f(v_url);



                    IF ( INSTR(v_clob_del,'error') != 0 )  THEN

                            print_log('Error al borrar lineas de la tabla stage de BC');

                            print_log(v_clob_del);

                            p_status := 'W';

                    ELSE

                        print_log('Lineas borradas de la tabla stage de BC');



                    END IF;     



                    -- borro headers                    

                   --

                  v_url := AJC_BC_J_WS_UTILS_PKG.get_base_inecta_url_f ( gv_bc_environment, p_company_id ) || v_api_del_hdr|| '('''||r_bc_st.invoiceID||''')'; 



                    print_log('v_url: ' || v_url);



                    v_clob_del := AJC_BC_J_WS_UTILS_PKG.delete_bc_row_f(v_url);



                    IF ( INSTR(v_clob_del,'error') != 0 )  THEN

                            print_log('Error al borrar header de la tabla stage de BC');

                            print_log(v_clob_del);

                            p_status := 'W';

                    ELSE

                        print_log('Header borrado de la tabla stage de BC');

                        v_qty := v_qty + 1;



                    END IF;     



                EXCEPTION

                WHEN OTHERS THEN

                      print_log('Error al borrar registros de las tablas stage de BC');

                      print_log(v_clob_del);       

                      p_status := 'W';

                END;



        END LOOP;



    print_log ('Cabeceras de Facturas borradas de la interfaz: '||v_qty);



    IF p_status IS NULL THEN 

       p_status := 'S';

    ELSE

     RAISE e_cust_exception;

    END IF;



    print_log ('AJC_BC_ABBYY_INTERFACE_PK.DELETE_INTERFACES (-)');



EXCEPTION 

 WHEN e_cust_exception THEN 

  p_status := 'W';

  print_log ('Hubo errores al eliminar los comprobantes con error');

  print_log ('AJC_BC_ABBYY_INTERFACE_PK.DELETE_INTERFACES (!)');

 WHEN OTHERS THEN 

  p_status := 'E';

  p_error_message := 'Error OTHERS in AJC_BC_ABBYY_INTERFACE_PK.DELETE_INTERFACES. Error: '||SQLERRM;

  print_log ('Hubo errores al eliminar los comprobantes con error');

  print_log ('AJC_BC_ABBYY_INTERFACE_PK.DELETE_INTERFACES (!)');



END;





PROCEDURE final_report_p ( p_status   OUT   VARCHAR2 )  IS



CURSOR c_trx IS

    SELECT NVL(aaii.vendor_name,pv.vendor_name) vendor_name

      ,NVL(aaii.vendor_num,pv.segment1) vendor_num

      ,aaii.vendor_site_code

      ,aaii.invoice_type_lookup_code

      ,aaii.invoice_num

      ,aaii.status_code

      ,aaii.error_message

  FROM ajc_bc_abbyy_invoices_int aaii

      ,po_vendors pv

 WHERE aaii.org_id != 5387-- LOGIS-USA-USD

   AND aaii.request_id = gv_request_id

   --and aaii.vendor_id = pv.vendor_id(+); 

   AND aaii.vendor_num = pv.segment1(+); 



BEGIN



    print_log( 'ajc_bc_interface_pk.final_report_p (+)' );



    -- Insert Report Title

    ajc_bc_j_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => gv_bc_ifc || ' Report',

                                        p_request_id => gv_request_id );

    ajc_bc_j_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Request ID|' || gv_request_id,

                                        p_request_id => gv_request_id ); 



    -- Fila vacia

    ajc_bc_j_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Insert Table Column Names                            

    ajc_bc_j_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 

                                                  'Vendor Name' || '|' ||

                                                  'Vendor Num' || '|' ||

                                                  'Vendor Site' || '|' ||

                                                  'Invoice Type' || '|' ||

                                                  'Invoice Num' || '|' ||

                                                  'Status' || '|' ||

                                                  'Error Message',

                                        p_request_id => gv_request_id );   



     -- Fila vacia

    ajc_bc_j_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );                                                                                      



    FOR r_trx in c_trx loop



      ajc_bc_j_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                          p_text => r_trx.vendor_name || '|' || 

                                                    r_trx.invoice_type_lookup_code || '|' || 

                                                    r_trx.invoice_num || '|' || 

                                                    r_trx.status_code || '|' || 

                                                    r_trx.error_message,

                                          p_request_id => gv_request_id );           



    END LOOP;



    p_status := 'S';



    print_log( 'ajc_bc_abby_interface_pk.final_report_p (-)' );



EXCEPTION

 WHEN OTHERS THEN 

      p_status := 'E';

      print_log( 'ajc_bc_abbyy_interface_pk.final_report_p (!). Error: ' || SQLERRM );

END;



  PROCEDURE final_report_xlsx_p ( p_status   OUT   VARCHAR2 ) IS



    c_processed   SYS_REFCURSOR;



  BEGIN



    print_log( 'ajc_bc_abbyy_interface_pkg.final_report_xlsx_p (+)' );



    gv_directory_report := AJC_BC_J_WS_UTILS_PKG.get_parameter_f ( p_parameter_code => 'AJC_DIRECTORY_REPORT' );



    -- Solapa Report Information

    ajc_bc_j_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc || ' Report Information',

                                                                       p_request_id => gv_request_id,

                                                                       p_bc_environment => gv_bc_environment,

                                                                       p_jenkins_build_number => gv_jenkins_build_number );



    -- Solapa Processed Data

        OPEN c_processed FOR



            SELECT 

            (SELECT bc_company_name

                FROM ajc.ajc_bc_companies

                WHERE org_id = aaii.org_id

                GROUP BY bc_company_name) bc_company_name

              ,NVL(aaii.vendor_name,pv.vendor_name) vendor_name

              ,NVL(aaii.vendor_num,pv.segment1) vendor_num

              ,aaii.vendor_site_code

              ,aaii.invoice_type_lookup_code

              ,aaii.invoice_num

              ,aaii.invoice_date

              ,aaii.worksheet_number

              ,aaii.invoice_amount

              ,aaii.status_code

              ,aaii.error_message

          FROM ajc_bc_abbyy_invoices_int aaii

              ,po_vendors pv

         WHERE aaii.org_id != 5387-- LOGIS-USA-USD

          AND aaii.request_id = gv_request_id

          -- and aaii.vendor_id = pv.vendor_id(+); 

           and aaii.vendor_num = pv.segment1(+); 



    -- Processed Data

    ajc_bc_j_utils_pkg.create_sheet_p ( p_sheet_title => 'Processed Data',

                                                        p_sheet => 2,

                                                        p_cursor => c_processed );





    as_xlsx.save ( gv_directory_report, gv_report_filename || '.' || LOWER(gv_file_format) );



    p_status := 'S';



    print_log( 'ajc_bc_abbyy_interface_pkg.final_report_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajc_bc_abbyy_interface_pkg.final_report_xlsx_p (!). Error: ' || SQLERRM );



  END final_report_xlsx_p;



/*=========================================================================+

|                                                                          |

| Public Function                                                          |

|    main_p                                                          |

|                                                                          |

| Description                                                              |

|    ABBYY Invoice Import Process                                          |

|                                                                          |

+=========================================================================*/

PROCEDURE main_p (p_bc_environment       IN VARCHAR2,

                                p_jenkins_build_number   IN   VARCHAR2) IS



v_status VARCHAR2(1);

v_error_msg VARCHAR2(2000);

e_cust_exception EXCEPTION;

e_parameter_value        EXCEPTION;

e_error        EXCEPTION;  

c_lob_ret CLOB;

v_request_id_excel NUMBER;

v_support_email          VARCHAR2(200);

v_not_success         NUMBER;



BEGIN



    gv_jenkins_build_number := p_jenkins_build_number;

    gv_request_id := ajc_bc_j_utils_pkg.get_request_id_f;



    print_log ('AJC_BC_ABBYY_INTERFACE_PK.MAIN_PROCESS (+)');



    -- Se inserta el concurrent_job

    ajc_bc_j_utils_pkg.ins_jenkins_concurrent_job_p ( p_request_id => gv_request_id,

                                                     p_job_name => gv_bc_ifc,

                                                     p_jenkins_build_number => gv_jenkins_build_number,

                                                     p_argument1 => p_bc_environment,

                                                     p_argument2 => NULL, -- MB REVISAR

                                                     p_argument3 => NULL ); -- MB REVISAR



    print_log ( 'gv_request_id: ' || gv_request_id );               

    print_log( 'gv_file_format: ' || gv_file_format );                                              

    print_log('gv_source: '||gv_source);

    print_log('gv_dft_account: '||gv_dft_account);

    print_log('gv_delete_flag: '||gv_delete_flag);



    gv_email := AJC_BC_J_UTILS_PKG.get_emails_f ( 'ABBYY' );

    print_log( 'gv_email: ' || gv_email );  



    gv_process_name := ajc_bc_j_ws_utils_pkg.get_lock_process_name_f ( p_integration => 'PURCHASE INVOICES' );

    print_log( 'gv_process_name: ' || gv_process_name );    



    -- Validacion parametro p_bc_environment -----------------------------------------------------------------------------------

    IF ( ajc_bc_j_utils_pkg.is_bc_environment_valid_f ( p_bc_environment ) = 'N' ) THEN



      v_error_msg := 'Invalid value (' || p_bc_environment || ') for parameter BC_ENVIRONMENT.';

      RAISE e_parameter_value;



    END IF;



    gv_bc_environment := p_bc_environment;

    print_log ( 'gv_bc_environment: ' || gv_bc_environment );



    -- Se obtienen los parametros de la company 

    print_log ( 'gv_bc_company_name: ' || gv_bc_company_name );  



    --Sincronizo default dimensions para mapeo de segmentos

    ajc_bc_j_account_dim_pkg.main_p( p_bc_environment => p_bc_environment , 

                                                        p_request_id => gv_request_id);    



    -- 20230228

    -- Se ejecuta el concurrente AJC BC Worksheets Interface

   -- ajc_bc_worksheets_pkg.caller_p ( p_bc_environment => p_bc_environment );



      -- dbms_lock - Lock ------------------------------------------------------------------------------------------------------

      print_log ( 'Trying to lock ' || gv_process_name || '.' );

      print_log ( 'If it stops at this point it is because it is blocked by another integration. It will continue once the other integration releases.' );



      ajc_bc_dbms_lock_pkg.lock_p ( p_process_name => gv_process_name,

                                    p_id_lock => gv_id_lock,

                                    p_request_status => gv_request_status ); 



      IF ( gv_request_status != 'success' ) THEN



        v_error_msg := 'ajc_bc_dbms_lock_pkg.lock_p';

        RAISE ge_lock;



      END IF;

      -- dbms_lock - Lock ------------------------------------------------------------------------------------------------------





    process_invoices (p_status             => v_status

                     ,p_error_message      => v_error_msg);



    IF v_status NOT IN ('S','W') THEN

       RAISE e_cust_exception;

    END IF;



    print_log('run_import : '||current_timestamp);   



    run_import (p_status => v_status 

                    ,p_error_message => v_error_msg);



    IF v_status != 'S' THEN



        print_log('validate_import : '||current_timestamp);        

    -- si run_import terminó en error, llamo a validate import para elimine los registros de la inbound purchase documents y marque los registros como REJECTED

       validate_import ( 

                     p_delete_flag => gv_delete_flag,

                     p_status => v_status,

                     p_error_message => v_error_msg);



        v_error_msg:='Error run_import';  

        RAISE e_cust_exception;

    END IF;



   validate_import ( 

                     p_delete_flag => gv_delete_flag,

                     p_status => v_status,

                     p_error_message => v_error_msg);



    IF v_status NOT IN ('S','W') THEN

        RAISE e_cust_exception;

    END IF;



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );



      IF ( gv_release_status != 'success' ) THEN



        v_error_msg := 'ajc_bc_dbms_lock_pkg.release_p';

        RAISE ge_release;



      END IF;                                     

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------



      -- INSERT REPORT IN TABLE AJC_BC_REPORTS --------------------------------------------------------------------------------

      print_log('final_report_p : '||current_timestamp);        

      final_report_p ( p_status => v_status );     



      IF ( v_status != 'S' ) THEN



        v_error_msg := 'Error in final_report_p';

        RAISE e_error;



      END IF;  



      IF ( gv_file_format = 'CSV' ) THEN

              -- CREATE CSV FROM TABLE AJC_BC_REPORTS --------------------------------------------------------------------------------

              ajc_bc_j_utils_pkg.create_csv_p ( p_ifc => gv_bc_ifc,

                                               p_request_id => gv_request_id,

                                               p_log_seq => gv_log_seq,

                                               p_type => 'REPORT',

                                               p_filename => gv_report_filename,

                                               p_status => v_status );



              IF ( v_status != 'S' ) THEN



                v_error_msg := 'Error in create_csv_p | REPORT';

                RAISE e_error;



              END IF;



      ELSIF ( gv_file_format = 'XLSX' ) THEN 



            -- No inserta en tabla, genera el xlsx directamente en el filesystem

        print_log('final_report_xlsx_p : '||current_timestamp);                

        final_report_xlsx_p ( p_status => v_status );     



        IF ( v_status != 'S' ) THEN



           v_error_msg := 'final_report_xlsx_p';

          RAISE e_error;



        END IF;  



      END IF;



      BEGIN

          -- MAIL REPORT -----------------------------------------------------------------------------------------------------------

          print_log('send_mail_with_attach : '||current_timestamp);                

          ajc_bc_j_utils_pkg.send_mail_with_attach ( p_to_mail => gv_email,

                                                    p_subject => gv_bc_ifc || ' Report - ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                                    p_body => gv_bc_ifc || ' Report.',

                                                    p_type => 'REPORT',

                                                    p_filename => gv_report_filename, 

                                                    p_file_format => gv_file_format,

                                                    p_attach_filename => gv_bc_ifc || ' Report ' || TO_CHAR(SYSDATE,'MMDDYYYY HH24MISS') || ' ' || gv_bc_environment || '.' || LOWER(gv_file_format) );                                            



      EXCEPTION

        WHEN OTHERS THEN

            print_log('SMTP NOT WORKING.');

      END;





        -- 20250514

        -- Se agrega envio de mail para soporte, para informar que no se pudo importar todo en la ejecucion

        BEGIN



          v_support_email := ajc_bc_j_utils_pkg.get_emails_f ( 'SUPPORT' );



          SELECT COUNT(1)

               INTO v_not_success

             FROM AJC_BC_ABBYY_INVOICES_INT a

                WHERE 1 = 1 

                AND a.request_id = gv_request_id

                AND a.org_id  != 5387-- LOGIS-USA-USD

                AND a.creation_date >= TO_DATE('30/06/2023','DD/MM/YYYY')

                AND a.STATUS_CODE IN ('ERROR','REJECTED');



          print_log ('v_not_success: ' || v_not_success);  



          IF ( v_not_success > 0 ) THEN



            ajc_bc_j_utils_pkg.send_email_p ( p_to => v_support_email,

                                                                  p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - WARNING - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                                                  p_message => 'Some journals could not be imported. Please review the integration report.' || CHR(10) || 'Request ID: ' || gv_request_id );



          END IF;



        EXCEPTION

            WHEN OTHERS THEN

               NULL;



        END;

         -- 20250514



    -- Se actualiza el concurrent_job

    ajc_bc_j_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'S' );    



    print_log ('  v_status => ' || v_status);

    print_log('end : '||current_timestamp);        

    print_log ('ajc_bc_abbyy_interface_pk.main_p (-)');



EXCEPTION 

      -- dbms_lock ---------------------------------------------------------------------------------------------------------------

    WHEN ge_lock THEN -- Lock and Release

      print_log ('ajc_bc_abbyy_interface_pk.main_p (!). Error attempting to lock the process' || gv_process_name || 

              ' | request_status: ' || gv_request_status);



      ajc_bc_j_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject =>  gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',   

                                       p_message => v_error_msg|| CHR(10) ||'Request Id: '||gv_request_id );



      ajc_bc_j_utils_pkg.send_log_by_mail_p(gv_request_id,gv_email);



      -- Se actualiza el concurrent_job

      ajc_bc_j_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );                                       



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );    



    WHEN ge_release THEN -- Lock and Release

      print_log ('ajc_bc_abbyy_interface_pk.main_p (!). Error attempting to release the process ' || gv_process_name || 

              ' | request_status: ' || gv_release_status);



      ajc_bc_j_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject =>  gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',   

                                       p_message => v_error_msg|| CHR(10) ||'Request Id: '||gv_request_id );



      ajc_bc_j_utils_pkg.send_log_by_mail_p(gv_request_id,gv_email);



      -- Se actualiza el concurrent_job

      ajc_bc_j_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );                                       



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );    



    -- dbms_lock ---------------------------------------------------------------------------------------------------------------

    WHEN e_parameter_value THEN

      print_log('ajc_bc_abby_interface_pk.main_p (!)');

      print_log('Parameter Value Error!');

      print_log('v_error_msg: '||v_error_msg);

      ajc_bc_j_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => v_error_msg || CHR(10) ||'Request Id: '||gv_request_id);



      ajc_bc_j_utils_pkg.send_log_by_mail_p(gv_request_id,gv_email);



      -- Se actualiza el concurrent_job

      ajc_bc_j_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );                   



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------                                         



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );         



WHEN e_cust_exception THEN

      print_log('ajc_bc_abbyy_interface_pk.main_p (!)');

      print_log('Error!');

      print_log('v_error_msg: '||v_error_msg);

          --process_output;  REVISAR MB

      ajc_bc_j_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')', 

                                       p_message => v_error_msg || CHR(10) ||'Request Id: '||gv_request_id );



      ajc_bc_j_utils_pkg.send_log_by_mail_p(gv_request_id,gv_email);



          -- Se actualiza el concurrent_job

      ajc_bc_j_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );               



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------                                             



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );  

  WHEN others THEN

  --  process_output;

      print_log('ajc_bc_abbyy_interface_pk.main_p (!)');

      print_log('Error others!');

      print_log('v_error_msg: '||v_error_msg);

      ajc_bc_j_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')', 

                                       p_message => v_error_msg|| CHR(10) ||'Request Id: '||gv_request_id );



      ajc_bc_j_utils_pkg.send_log_by_mail_p(gv_request_id,gv_email);



          -- Se actualiza el concurrent_job

      ajc_bc_j_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );                  



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------                                          



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );  

END;



PROCEDURE remove_inv ( p_bc_environment       IN VARCHAR2

                                ,p_jenkins_build_number   IN   VARCHAR2

                                ,p_invoice_num       IN  VARCHAR2

                                ,p_status            IN  VARCHAR2 ) IS



  v_cant_rows_updated   NUMBER;

  v_error_msg VARCHAR2(100);

  e_cust_exception EXCEPTION;

  v_status VARCHAR2(1);



BEGIN



    gv_jenkins_build_number := p_jenkins_build_number;

    gv_request_id := ajc_bc_j_utils_pkg.get_request_id_f;

    gv_bc_ifc := 'AJC BC ABBYY Remove Invoice';

    gv_file_format := 'CSV';

    gv_output_filename := 'AJCBCAIR_output';



    print_log ('AJC_BC_ABBYY_INTERFACE_PK.remove_inv (+)');



    -- Se inserta el concurrent_job

    ajc_bc_j_utils_pkg.ins_jenkins_concurrent_job_p ( p_request_id => gv_request_id,

                                                     p_job_name => gv_bc_ifc,

                                                     p_jenkins_build_number => gv_jenkins_build_number,

                                                     p_argument1 => p_bc_environment,

                                                     p_argument2 => NULL, -- MB REVISAR

                                                     p_argument3 => NULL ); -- MB REVISAR



    print_log ( 'gv_request_id: ' || gv_request_id );               

    print_log( 'gv_file_format: ' || gv_file_format );                                              



    gv_email := AJC_BC_J_UTILS_PKG.get_emails_f ( 'ABBYY' );

    print_log( 'gv_email: ' || gv_email );  



    -- Validacion parametro p_bc_environment -----------------------------------------------------------------------------------

    IF ( ajc_bc_j_utils_pkg.is_bc_environment_valid_f ( p_bc_environment ) = 'N' ) THEN



      v_error_msg := 'Invalid value (' || p_bc_environment || ') for parameter BC_ENVIRONMENT.';

      RAISE e_cust_exception;



    END IF;



    gv_bc_environment := p_bc_environment;

    print_log ( 'gv_bc_environment: ' || gv_bc_environment );



    print_log('Actualizo status');



  UPDATE AJC_BC_ABBYY_INVOICES_INT

     SET status_code = p_status,

         request_id = DECODE(p_status,'NEW',NULL,request_id),

         error_message = DECODE(p_status,'NEW',NULL,error_message)

   WHERE invoice_num = p_invoice_num

     AND status_code IN ('ERROR','REMOVED','REJECTED')

     AND org_id != 5387; -- LOGIS-USA-USD;



  v_cant_rows_updated := SQL%ROWCOUNT;



  print_log ( 'Cantidad de registros actualizados: ' || v_cant_rows_updated );   



  IF ( v_cant_rows_updated = 1 ) THEN



    print_output ( 'Se actualizó el status del invoice ' || p_invoice_num || ' a ' || p_status );



    COMMIT;



  ELSE



    print_log ( 'Error al actualizar el invoice ' || p_invoice_num || '. Error: ' || SQLERRM );

    v_error_msg := 'Error al actualizar el invoice ' || p_invoice_num || '. Error: ' || SQLERRM;

    ROLLBACK;

    RAISE e_cust_exception;



  END IF;



  -- CREATE CSV FROM TABLE AJC_BC_OUTPUT --------------------------------------------------------------------------------

  ajc_bc_j_utils_pkg.create_csv_p ( p_ifc => gv_bc_ifc,

                                   p_request_id => gv_request_id,

                                   p_log_seq => gv_log_seq,

                                   p_type => 'OUTPUT',

                                   p_filename => gv_output_filename,

                                   p_status => v_status );



  IF ( v_status != 'S' ) THEN



    v_error_msg := 'Error in create_csv_p | OUTPUT';

    RAISE e_cust_exception;



  END IF; 



    BEGIN

      -- MAIL REPORT -----------------------------------------------------------------------------------------------------------

      print_log('send_mail_with_attach : '||current_timestamp);                

      ajc_bc_j_utils_pkg.send_mail_with_attach ( p_to_mail => gv_email,

                                                p_subject => gv_bc_ifc || ' Output - ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                                p_body => gv_bc_ifc || ' Output.',

                                                p_type => 'OUTPUT',

                                                p_filename => gv_output_filename, 

                                                p_file_format => gv_file_format,

                                                p_attach_filename => gv_bc_ifc || ' Output ' || TO_CHAR(SYSDATE,'MMDDYYYY HH24MISS') || ' ' || gv_bc_environment || '.' || LOWER('CSV') );                                            



  EXCEPTION

    WHEN OTHERS THEN

        print_log('SMTP NOT WORKING.');

  END;



      -- Se actualiza el concurrent_job

    ajc_bc_j_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'S' );    



    print_log('end : '||current_timestamp);        

    print_log ('ajc_bc_abbyy_interface_pk.remove_inv (-)');



EXCEPTION

  WHEN others THEN

  --  process_output;

      print_log('ajc_bc_abbyy_interface_pk.main_p (!)');

      print_log('Error others!');

      print_log('v_error_msg: '||v_error_msg);

      ajc_bc_j_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')', 

                                       p_message => v_error_msg|| CHR(10) ||'Request Id: '||gv_request_id );



      ajc_bc_j_utils_pkg.send_log_by_mail_p(gv_request_id,gv_email);



          -- Se actualiza el concurrent_job

      ajc_bc_j_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );                                                     



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );  

END remove_inv;



END;
