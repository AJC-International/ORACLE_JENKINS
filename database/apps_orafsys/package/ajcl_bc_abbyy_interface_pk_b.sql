PACKAGE BODY              AJCL_BC_ABBYY_INTERFACE_PK AS

/* ----------------------------------------------------------------------------------------------|
| Historial                                                                                      |
|   Date      Version  Modified    Detail                                                        |
|   --------- -------  ----------  --------------------------------------------------------------|
|   10-JAN-24    1     MBETTI    Creation                                                      |
|------------------------------------------------------------------------------------------------*/

-- Fixed parameters
gv_source                     ap_invoices_interface.source%type:='ABBYY'; -- BC Purchase Invoice source
gv_dft_account              VARCHAR2(10):='9105.9890';  -- Default account - ex ZERO
gv_dft_ora_account        VARCHAR2(10):='9890'; -- Default Oracle account - ex ZERO
gv_logistics_actual_acct  VARCHAR(10):='2215'; -- Default logistics account
gv_file_format               VARCHAR2(4):='XLSX'; -- Report file format
gv_delete_flag               VARCHAR2(4):='Y';  -- Deletes rejecte records from BC Inbound Purchase Document table

/*=========================================================================+
|                                                                          |
| Private Function                                                         |
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
     ajcl_bc_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );
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
    ajcl_bc_utils_pkg.insert_output_p ( gv_bc_ifc, p_message, gv_request_id );
  END;

/*=========================================================================+
|                                                                          |
| Private Function                                                         |
|    get_company                                                           |
|                                                                          |
| Description                                                              |
|    Obtiene la compañía                                                   |
|                                                                          |
|                                                                          |
| Parameters                                                               |
|    p_ws                   IN   VARCHAR2    Worksheet Number              |
|                                                                          |
+=========================================================================*/
  FUNCTION get_company ( p_ws   IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_company   gl_code_combinations.segment1%type;

  BEGIN

    print_log('get_company (+)');

    print_log('p_ws: ' || p_ws);

-- Modificado KHRONUS/MB 20241025: Por definicion Yairaliz la compañia debe ser 53, siempre
--    IF ( p_ws IS NULL ) THEN
--
--      RETURN '53';
--
--    END IF;
--
--    IF substr(p_ws, 1, 2) IN ('PO', 'DL', 'SN') THEN
--
--      v_company := '54';
--
--    ELSE
--
--      v_company := '53';
--
--    END IF;
-- Modificado KHRONUS/MB 20241025: Por definicion Yairaliz la compañia debe ser 53, siempre
    v_company := '53';

    print_log('v_company: ' || v_company);  
    print_log('get_company (-)');    

    RETURN v_company;

  EXCEPTION 
    WHEN OTHERS THEN
      print_log('get_company (!)');

  END get_company;
  

/*=========================================================================+
|                                                                          |
| Private Function                                                         |
|    get_account                                                           |
|                                                                          |
| Description                                                              |
|    Obtiene la cuenta                                                     |
|                                                                          |
|                                                                          |
| Parameters                                                               |
|    p_ws                   IN   VARCHAR2    Worksheet Number              |
|    p_account              IN   VARCHAR2    Account                       |
|                                                                          |
+=========================================================================*/
  FUNCTION get_account ( p_ws          IN   VARCHAR2,
                         p_vendor_id   IN   NUMBER,
                         p_account     IN   VARCHAR2,
                         p_invoice_amount   NUMBER ) RETURN VARCHAR2 IS

    v_account   gl_code_combinations.segment2%type;
    v_bc_account VARCHAR2(20);
    v_split    VARCHAR2(1);

  BEGIN

    print_log('get_account (+)');

    print_log('p_ws: ' || p_ws);
    print_log('p_account: ' || p_account);
    
      -- Se verifica si el vendor esta cargado en la lookup con el mismo monto que la factura
    SELECT DECODE(COUNT(1),0,'N','Y')
    INTO v_split
    FROM fnd_lookup_values flv,
         po_vendors v
   WHERE flv.lookup_type = 'AJC_ABBYY_LOG_SPECIAL_VENDORS'
     AND flv.description = v.segment1
     AND v.vendor_id = p_vendor_id
     AND TO_NUMBER(REPLACE(flv.tag,',','.')) = p_invoice_amount
     AND NVL(flv.enabled_flag,'N') = 'Y';

    IF v_split ='Y' THEN
        v_account:=gv_logistics_actual_acct; 
    ELSE    
        IF ( p_ws IS NULL ) THEN

          v_account:=p_account;

        ELSIF substr(p_ws, 1, 2) IN ('PO', 'DL', 'SN') THEN

          BEGIN

            SELECT dfv.xxlog_abbyy_accounts
              INTO v_account
              FROM po_vendors v,
                   po_vendors_dfv dfv
             WHERE v.rowid = dfv.row_id
               AND v.vendor_id = p_vendor_id;

          EXCEPTION
            WHEN OTHERS THEN
              print_log('Error al intentar obtener la cuenta del flexfield del proveedor.');

          END;

          IF ( v_account IS NULL ) THEN

            print_log('El proveedor no tiene seteada la cuenta en el flexfield XXLOG ABBYY Account.');
            v_account := gv_dft_account;

          END IF;

        ELSE

          v_account := p_account;

        END IF;
    END IF;
    -- mapeo con cuenta BC
    BEGIN

        SELECT bc_account
        INTO v_bc_account 
        FROM AJC_BC_ACCOUNTS
        WHERE oracle_account=DECODE(v_account,gv_dft_account,gv_dft_ora_account,v_account);

    EXCEPTION
    WHEN OTHERS THEN
         print_log( 'Error al obtener mapeo de cuenta Oracle: '||v_account||' con BC. Error: '||SQLERRM);
         v_bc_account:=NULL;           
    END;

    print_log('v_account: ' || v_bc_account);  
    print_log('get_account (-)');    

    RETURN v_bc_account;

  EXCEPTION 
    WHEN OTHERS THEN
      print_log('get_account (!)');

  END get_account;


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

SELECT distinct org_id,request_id
FROM AJC_BC_ABBYY_INVOICES_INT
WHERE STATUS_CODE = 'SENT'
AND ORG_ID=gv_org_id
;
--AND request_id = gv_request_id; 

CURSOR c_imp (p_org_id NUMBER,p_request_id NUMBER) IS
SELECT rowid row_id,invoice_id,vendor_id,org_id,invoice_num,invoice_type_lookup_code
FROM AJC_BC_ABBYY_INVOICES_INT
WHERE STATUS_CODE = 'SENT'
AND ORG_ID = p_org_id
AND request_id = p_request_id; 

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

v_clob_int   CLOB;
v_clob_del CLOB;
v_STime  NUMBER(30);
v_ETime  NUMBER(30);
v_cant_sin_procesar NUMBER;
v_company_id VARCHAR2(100);
v_status    VARCHAR2(1);
v_error_message VARCHAR2(1000);

BEGIN

    print_log ('AJCL_BC_ABBYY_INTERFACE_PK.VALIDATE_IMPORT (+)');

    print_log ('Se obtienen los comprobantes procesados en el día de hoy.');


    FOR r_org IN c_org_ids LOOP

        print_log('org_id: '||r_org.org_id);
        print_log('request_id: '||r_org.request_id);

        ajc_bc_ws_utils_pkg.get_bc_company_id_f(r_org.org_id,NULL,NULL,v_company_id,v_status);        

        print_log('v_company_id: '||v_company_id);

        IF v_status = 'E' THEN
                v_error_message := 'Error al obtener v_company_id. Error: '||SQLERRM;
                v_company_id:=null;
                RAISE e_cust_exception;
        END IF;

        --v_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( gv_environment, v_company_id ) || v_api_st|| '?$filter=requestID eq '|| TO_CHAR(gv_request_id);
          v_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => gv_bc_environment,
                                                    p_entity => 'PURCHASE INVOICES',
                                                    p_subentity => 'STATUS',
                                                    p_method => 'GET',
                                                    p_company_id =>v_company_id )|| '?$filter=requestID eq '|| TO_CHAR(r_org.request_id);

        print_log('v_url: ' || v_url);   

        v_cant_sin_procesar := -1;

        -- seteo tiempo de inicio
            Select To_Number(((To_Char(Sysdate, 'J') - 1 ) * 86400) + To_Char(Sysdate, 'SSSSS'))
            Into v_STime 
            From Sys.Dual;

        -- Espero a que el job haya procesado todos los registros del request_id                  
        WHILE v_cant_sin_procesar <> 0
        LOOP

            v_clob_int := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url) ;

            SELECT count(*)
            INTO v_cant_sin_procesar
            FROM json_table( v_clob_int,
                         '$.value[*]' COLUMNS ( status VARCHAR2(4000) path '$.status',
                                                            requestID VARCHAR2(4000) path '$.requestID'))
            WHERE requestID=TO_CHAR(r_org.request_id)--TO_CHAR(gv_request_id)
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

        FOR r_imp in c_imp(r_org.org_id,r_org.request_id) LOOP

            print_log ('');
            print_log ('>> Org_id: '||r_imp.org_id);
            print_log ('>> Vendor_id: '||r_imp.vendor_id);
            print_log ('>> Invoice_Type_lookup_Code: '||r_imp.invoice_type_lookup_code);
            print_log ('>> Invoice_num: '||r_imp.invoice_num);
            print_log ('>> Invoice_num: '||r_imp.invoice_id);


            FOR r_bc_st in c_bc_status(v_clob_int,r_imp.invoice_id) LOOP

                v_exists :=1;
                p_error_message := null;
                print_log ('>> StatusTimeStamp: '||r_bc_st.StatusTimeStamp);
                print_log ('>> Status: '||r_bc_st.status);

                IF r_bc_st.status != 'Success' THEN

                    p_error_message := r_bc_st.statusRemarks;

                    print_log ('El comprobante no se ha importado. Errores: '||p_error_message);

                    UPDATE ajc_bc_abbyy_invoices_int
                      SET status_code = 'REJECTED'
                         ,error_message = 'El comprobante no se ha importado. Status: '|| r_bc_st.status||' - '||p_error_message
                         ,last_update_date = sysdate
                         ,request_id = gv_request_id
                    WHERE rowid = r_imp.row_id;

                    -- borro registros con error de la stage de BC
                    IF p_delete_flag = 'Y' THEN

                        BEGIN
                            -- borro lineas 
                           --
                         --   v_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( gv_environment, v_company_id ) || v_api_del_line|| '('''||r_bc_st.invoiceID||''',0,0)'; 
                            v_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => gv_bc_environment,
                                                    p_entity => 'PURCHASE INVOICES',
                                                    p_subentity => 'LINES',
                                                    p_method => 'DELETE',
                                                    p_company_id => v_company_id )|| '('''||r_bc_st.invoiceID||''',0,0)';

                            print_log('v_url: ' || v_url);

                            v_clob_del := ajcl_bc_ws_utils_pkg.delete_bc_row_f(v_url);

                            IF ( INSTR(v_clob_del,'error') != 0 )  THEN
                                    print_log('Error al borrar lineas de la tabla stage de BC');
                                    print_log(v_clob_del);
                            ELSE
                                print_log('Lineas borradas de la tabla stage de BC');

                            END IF;     

                            -- borro headers                    
                           --
                         -- v_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( gv_environment, v_company_id ) || v_api_del_hdr|| '('''||r_bc_st.invoiceID||''',0)'; 
                            v_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => gv_bc_environment,
                                                    p_entity => 'PURCHASE INVOICES',
                                                    p_subentity => 'HEADERS',
                                                    p_method => 'DELETE',
                                                    p_company_id => v_company_id )|| '('''||r_bc_st.invoiceID||''',0)'; 
                            
                            print_log('v_url: ' || v_url);

                            v_clob_del := ajcl_bc_ws_utils_pkg.delete_bc_row_f(v_url);

                            IF ( INSTR(v_clob_del,'error') != 0 )  THEN
                                    print_log('Error al borrar header de la tabla stage de BC');
                                    print_log(v_clob_del);
                            ELSE
                                print_log('Header borrado de la tabla stage de BC');

                            END IF;     

                        EXCEPTION
                        WHEN OTHERS THEN
                              print_log('Error al borrar registros de las tablas stage de BC');
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
                          ,error_message = 'El comprobante fue enviado a BC pero no se pudo obtener estado de procesamiento.'
                          ,last_update_date = sysdate
                          ,request_id =gv_request_id
                    WHERE rowid = r_imp.row_id;
            ELSE
                v_exists := 0;                        
            END IF;
        END LOOP;

   END LOOP; --org_ids,request_ids

    IF p_status IS NULL THEN 
       p_status := 'S';
    ELSE
     RAISE e_cust_exception;
    END IF;

    print_log ('AJCL_BC_ABBYY_INTERFACE_PK.VALIDATE_IMPORT (-)');

EXCEPTION 
 WHEN e_cust_exception THEN 
  p_status := 'W';
  print_log (p_error_message);
  print_log ('AJCL_BC_ABBYY_INTERFACE_PK.VALIDATE_IMPORT (!)');
 WHEN OTHERS THEN 
  p_status := 'E';
  p_error_message := 'Error OTHERS en AJCL_BC_ABBYY_INTERFACE_PK.VALIDATE_IMPORT. Error: '||SQLERRM;
  print_log (p_error_message);
  print_log ('AJCL_BC_ABBYY_INTERFACE_PK.VALIDATE_IMPORT (!)');
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
|    p_status                  OUT     VARCAHR2  Codigo Estado.            |
|    p_error_message           OUT     VARCHAR2  Mensaje de Error.         |
|                                                                          |
+=========================================================================*/
procedure run_import (p_status OUT VARCHAR2
                     ,p_error_message OUT VARCHAR2) IS

v_job_object_id     NUMBER;
v_qty NUMBER;
e_cust_exception EXCEPTION;

v_request_id        NUMBER;
v_message           VARCHAR2 (2000);
v_conc_phase        VARCHAR2 (50);
v_conc_status       VARCHAR2 (50);
v_conc_dev_phase    VARCHAR2 (50);
v_conc_dev_status   VARCHAR2 (50);
v_conc_message      VARCHAR2 (250);

  CURSOR c_org_ids IS
  SELECT distinct org_id
    FROM AJC_BC_ABBYY_INVOICES_INT
   WHERE STATUS_CODE = 'SENT'
     AND request_id = gv_request_id; 

  v_company_id        VARCHAR2(100);
  v_status            VARCHAR2(1);
  v_clob_ret          CLOB;
  v_ws_status         VARCHAR2(10);
BEGIN

    print_log ('AJCL_BC_ABBYY_INTERFACE_PK.RUN_IMPORT (+)');
    
    v_job_object_id :=  ajcl_bc_ws_utils_pkg.get_object_id_f ( p_integration => 'PURCHASE INVOICES' ); 
    print_log ( 'v_job_object_id: ' || v_job_object_id );    

    print_log ('Verifico si existen comprobantes a importar');
    BEGIN

        SELECT COUNT(1)
          INTO v_qty
          FROM ajc_bc_ABBYY_INVOICES_INT
         WHERE STATUS_CODE = 'SENT'
           AND ORG_ID = gv_org_id;
        --   AND request_id = gv_request_id;
    EXCEPTION
     WHEN OTHERS THEN 
       p_error_message := 'Error obteniendo cantidad de comprobantes a importar. Error: '||SQLERRM;
       RAISE e_cust_exception;
    END;

    print_log ('Cantidad: '||v_qty);
--    RAISE e_cust_exception; --MB ELIMINAR

    IF v_qty > 0 THEN 
        FOR r_org IN c_org_ids LOOP

            print_log('org_id: '||r_org.org_id);

            ajc_bc_ws_utils_pkg.get_bc_company_id_f(r_org.org_id,NULL,NULL,v_company_id,v_status);        

            print_log('v_company_id: '||v_company_id);

            IF v_status = 'E' THEN
                    p_error_message := 'Error al obtener v_company_id. Error: '||SQLERRM;
                    v_company_id:=null;
                    RAISE e_cust_exception;
            END IF;

                v_clob_ret := ajcl_bc_ws_utils_pkg.run_job_queue_f ( p_bc_environment => gv_bc_environment
                                                                                             ,p_company_id   => v_company_id
                                                                                             ,p_object_id        => v_job_object_id ); 
                                                                                                            

                  IF ( INSTR(UPPER(v_clob_ret),'ERROR') != 0 ) OR ( INSTR(v_clob_ret,'404') != 0 ) THEN
                    print_log('Error al ejecutar le job 70004: '||v_clob_ret);
                     p_status :='W';
                     v_ws_status := 'ERROR';
                  ELSE
                    print_log('Job ejecutado ok');
                    v_ws_status := 'SUCCESS';
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

    print_log ('AJCL_BC_ABBYY_INTERFACE_PK.RUN_IMPORT (-)');

EXCEPTION
 WHEN OTHERS THEN 
  p_status := 'W';
  p_error_message := 'Error OTHERS en AJCL_BC_ABBYY_INTERFACE_PK.RUN_IMPORT. Error: '||SQLERRM;
  print_log (p_error_message); 
  print_log ('AJCL_BC_ABBYY_INTERFACE_PK.RUN_IMPORT (!)');
  
    INSERT INTO AJC_BC_ABBYY_REQUESTS
  VALUES
  (gv_request_id,'ERROR',v_clob_ret,SYSDATE);

  COMMIT;
END;

FUNCTION get_vendor_site (p_vendor_num IN NUMBER) RETURN VARCHAR2
IS

  v_get_url varchar2(200);
  v_clob_result clob;
  v_vendor_site_code VARCHAR2(200);

BEGIN
 
  v_get_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,
                                                            p_entity => 'VENDORS',
                                                            p_subentity => NULL,
                                                            p_method => 'GET',
                                                            p_company_id => gv_bc_company_id )  || '?$filter=vendorno eq ''' || p_vendor_num || '''';

  print_log('v_get_url: ' || v_get_url);
 
  v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );
  
  print_log('v_clob_result: ' || v_clob_result);

  SELECT vendor_site_code
  INTO v_vendor_site_code
  FROM json_table( v_clob_result,
                     '$.value[*]' COLUMNS ( vendor_site_code VARCHAR2(4000)  path '$.legacyVendorSiteNmAJCINE' ) );
                     
    print_log('vendor_site_code: ' || v_vendor_site_code);
    
    RETURN v_vendor_site_code;
    
EXCEPTION
WHEN OTHERS THEN
RETURN NULL;

END;
-- Inicio Agregado SBanchieri 26042021
PROCEDURE vendor_inv_validation ( p_invoice                    IN OUT    t_invoice_bc,
                                  p_vendor_id                  IN       po_vendors.vendor_id%TYPE,
                                  p_vendor_name                IN OUT   po_vendors.vendor_name%TYPE,
                                  p_vendor_num                 IN OUT   po_vendors.segment1%TYPE,
                                  p_vendor_type_lookup_code    IN OUT   po_vendors.vendor_type_lookup_code%TYPE,
                                  p_exclude                    IN OUT   VARCHAR2,  
                                  p_account                    IN OUT   gl_code_combinations.segment2%TYPE,
                                  p_logistics_actual_acct      IN       VARCHAR2,
                                  --
                                  p_vendor_site_code           IN  OUT     po_vendor_sites_all.vendor_site_code%TYPE,
                                  p_org_id                     IN       po_vendor_sites_all.org_id%TYPE,
                                  --
                                  p_invoice_type_lookup_code   IN       ap_invoices_all.invoice_type_lookup_code%TYPE,
                                  p_invoice_amount             IN       NUMBER,
                                  p_invoice_num                IN       ap_invoices_all.invoice_num%TYPE,
                                  p_invoice_id                 IN OUT   ap_invoices_all.invoice_id%TYPE,
                                  p_invoice_date               IN       ap_invoices_all.invoice_date%TYPE,
                                  p_invoice_currency_code      IN       ap_invoices_all.invoice_currency_code%TYPE,
                                  p_func_currency_code         IN       ap_invoices_all.invoice_currency_code%TYPE,
                                  p_worksheet_number           IN       ajc_bc_abbyy_invoices_int.worksheet_number%TYPE,
                                  p_description                IN       ajc_bc_abbyy_invoices_int.description%TYPE,
                                  p_account2                   IN OUT   gl_code_combinations.segment2%TYPE,
                                  p_qty_prepay                 IN OUT   NUMBER,
                                  --
                                  p_error_message              IN OUT   VARCHAR2 ) IS
v_vendor_id NUMBER;         
v_vendor_site_id NUMBER;    
e_error              EXCEPTION;                     
BEGIN

  IF p_vendor_id IS NULL THEN

    p_error_message := 'No vendor specified.'; 

  ELSE

    print_log('Valido proveedor');

    BEGIN

      SELECT vendor_id
       --      vendor_name,
       --      segment1
        INTO v_vendor_id
        --     p_vendor_name,
         --    p_vendor_num
        FROM po_vendors
     -- KHRONUS/MBetti 20240801 - Se valida utilizando vendor_num para resolver diferencias de sincronizacion entre ambientes. 
     -- Se creó un trigger en AJC_AP_ABBYY_INVOICES_INT de PROD que completa el vendor_num y vendor_name en   AJC_BC_ABBYY_INVOICES_INT de finupg5  finupg6
     --  WHERE vendor_id = p_vendor_id;
     WHERE segment1 = p_vendor_num;

    EXCEPTION 
      WHEN NO_DATA_FOUND THEN 
         p_error_message := 'Vendor ID does not exist in Oracle. Error: ' || SQLERRM;
      WHEN OTHERS THEN 
         p_error_message := 'Error verifying vendor. Error: ' || SQLERRM;
    END;

    print_log('vendor_id: ' || v_vendor_id);
    print_log('vendor_name: ' || p_vendor_name);

  
    IF v_vendor_id IS NOT NULL THEN  
        print_log('Valido si esta activo y obtengo el tipo de proveedor');

        BEGIN

          SELECT pv.vendor_id,
                 pv.vendor_type_lookup_code,
                 NVL(pv_dfv.ajc_ap_re_val_exclude,'N')
            INTO v_vendor_id,
                 p_vendor_type_lookup_code,
                 p_exclude
            FROM po_vendors pv,
                 po_vendors_dfv pv_dfv
           WHERE vendor_id = v_vendor_id
             AND enabled_flag = 'Y'
             AND NVL(TRUNC(start_date_active),TRUNC(SYSDATE)) <= TRUNC(SYSDATE)
             AND NVL(TRUNC(end_date_active),TRUNC(SYSDATE)) >= TRUNC(SYSDATE)
             AND pv.rowid = pv_dfv.row_id;

   
