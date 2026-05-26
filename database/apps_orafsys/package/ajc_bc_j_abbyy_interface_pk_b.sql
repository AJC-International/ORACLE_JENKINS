PACKAGE BODY              AJC_BC_J_ABBYY_INTERFACE_PK AS

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
    
