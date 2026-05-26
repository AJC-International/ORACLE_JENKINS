CREATE OR REPLACE PACKAGE BODY              AJCL_BC_ABBYY_INTERFACE_PK AS



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



        EXCEPTION 

          WHEN NO_DATA_FOUND THEN 

             p_error_message := 'Vendor: ' || p_vendor_name || ' is not active in Oracle';

          WHEN OTHERS THEN 

             p_error_message := 'Error verifying if vendor ' || p_vendor_name || ' is active in Oracle. Error: ' || SQLERRM;

        END;



        print_log ('Proveedor activo');

        print_log ('vendor_type_lookup_code : ' || p_vendor_type_lookup_code);



        /*

        IF ( p_vendor_type_lookup_code IS NOT NULL ) THEN 



          BEGIN



            SELECT flv_dfv.ajc_ap_accrual_account

              INTO p_account

              FROM fnd_lookup_values flv

                  ,fnd_lookup_values_dfv flv_dfv

             WHERE flv.rowid = flv_dfv.row_id

               AND flv.lookup_type = 'VENDOR TYPE'

               AND flv.lookup_code = p_vendor_type_lookup_code

               AND enabled_flag = 'Y'

               AND NVL(start_date_active,TRUNC(SYSDATE)) <= TRUNC(SYSDATE)

               AND NVL(end_date_active,TRUNC(SYSDATE)) >= TRUNC(SYSDATE);



          EXCEPTION 

            WHEN NO_DATA_FOUND THEN 

               p_error_message := 'Vendor: ' || p_vendor_name || ' is not active in Oracle';

            WHEN OTHERS THEN 

               p_error_message := 'Error verifying if vendor ' || p_vendor_name || ' is active in Oracle. Error: ' || SQLERRM;

          END;



          -- Inicio Agregado SBanchieri 05032021

          -- Operating Unit: LOGISTICS OP UNIT

          p_account := p_logistics_actual_acct;



        END IF;

        */

         p_account := p_logistics_actual_acct;





          print_log ('Verificando Sucursal del proveedor');



        -- KHRONUS/MBetti 20240802 - Se reemplaza la siguiente lógica por la obtención del vendor site code desde BC

       /*   IF p_vendor_site_code IS NULL THEN



            p_error_message := 'Vendor site has not been specified.'; 



          ELSE



            print_log ('Sucursal: ' || p_vendor_site_code);

            p_invoice.vendorSiteCode := p_vendor_site_code;



            BEGIN



              SELECT vendor_site_id

                INTO v_vendor_site_id

                FROM po_vendor_sites_all

               WHERE org_id = p_org_id

                 AND vendor_site_code = p_vendor_site_code

                 AND vendor_id = v_vendor_id

                 AND nvl(inactive_date,trunc(sysdate)) >= trunc(sysdate);



            EXCEPTION

              WHEN NO_DATA_FOUND THEN

                p_error_message := 'Vendor site does not exist in Oracle';

              WHEN OTHERS THEN  

                p_error_message := 'Error verifying vendor site. Error: ' || SQLERRM;

            END;



            IF v_vendor_site_id IS NOT NULL THEN 



              BEGIN



                SELECT vendor_site_id

                  INTO v_vendor_site_id

                  FROM po_vendor_sites_all

                 WHERE org_id = p_org_id

                   AND vendor_site_code = p_vendor_site_code

                   AND vendor_id = v_vendor_id

                   AND nvl(inactive_date,trunc(sysdate)) >= TRUNC(sysdate)

                   AND NVL(pay_site_flag,'N') = 'Y';



              EXCEPTION

                WHEN NO_DATA_FOUND THEN

                  p_error_message := 'Vendor site is not configured as payment site';

                WHEN OTHERS THEN  

                  p_error_message := 'Error verifying vendor payment site. Error: ' || SQLERRM;

              END;



            END IF;



          END IF;

          */

          p_vendor_site_code := get_vendor_site(p_vendor_num);

          

          print_log ('p_vendor_site_code: ' || p_vendor_site_code);

          

          IF p_vendor_site_code IS NULL THEN

                      p_error_message := 'Vendor does not exist in BC';

                      RAISE e_error;

          END IF;



        print_log('Validando invoice_type_lookup_code');



          IF p_invoice_type_lookup_code NOT IN ('STANDARD','CREDIT') THEN 



            p_error_message := 'El tipo de comprobante: ''' || p_invoice_type_lookup_code || ''' no es valido';



          ELSE



            p_invoice.invoiceType := p_invoice_type_lookup_code;

            print_log ('Invoice_type_lookup_code: ' || p_invoice_type_lookup_code);



            IF p_invoice_type_lookup_code = 'CREDIT' THEN



              p_invoice.invoiceAmount := p_invoice_amount * -1;



            ELSE



              p_invoice.invoiceAmount := p_invoice_amount;



            END IF;



            print_log ('Invoice_amount: ' || p_invoice.invoiceAmount);



          END IF;



        print_log('Asignando invoiceno e invoiceDate ');



            p_invoice.invoiceNo := p_invoice_num;

          p_invoice.invoiceDate := TO_CHAR(TRUNC(p_invoice_date),'YYYY-MM-DD');



          IF ( p_invoice_currency_code IS NULL ) THEN 



            print_log('No se informo una moneda, buscando la moneda de la sucursal');



            BEGIN



              SELECT NVL(pvs.invoice_currency_code,pv.invoice_currency_code)

                INTO p_invoice.invoiceCurrencyCode

                FROM po_vendor_sites_all pvs

                    ,po_vendors pv

               WHERE pvs.org_id = gv_org_id

                 AND pv.vendor_id = v_vendor_id

                 AND pv.vendor_id = pvs.vendor_id

                 AND vendor_site_code = p_vendor_site_code

                 AND NVL(pvs.invoice_currency_code,pv.invoice_currency_code) IS NOT NULL;



            EXCEPTION    

              WHEN OTHERS THEN

                p_error_message := 'Currency has not been informed and the vendor does not have a currency configured. Error: ' || SQLERRM;



            END;



          ELSE



            print_log('Validando Moneda informada: ' || p_invoice_currency_code);



            BEGIN



              SELECT currency_code

                INTO p_invoice.invoiceCurrencyCode

                FROM fnd_currencies_vl

               WHERE currency_code = p_invoice_currency_code;



            EXCEPTION 

              WHEN NO_DATA_FOUND THEN 

                p_error_message := 'Currency code ' || p_invoice_currency_code || ' does not exist in Oracle. Error: ' || SQLERRM;

              WHEN OTHERS THEN 

                p_error_message := 'Error validating currency code: ' || p_invoice_currency_code || '. Error: ' || SQLERRM;

            END;



          END IF;



          IF p_func_currency_code != p_invoice.invoiceCurrencyCode THEN



            print_log('Moneda del comprobante difiere de la moneda funcional. Verificando Tipo de Cambio');



            print_log('Fecha: ' || p_invoice_date);



            p_invoice.exchangeDate := p_invoice_date;



          END IF;



        print_log('Validando description');

        

          IF p_description IS NULL THEN 



            p_invoice.description := p_worksheet_number;



          ELSE



            IF ( p_worksheet_number IS NOT NULL ) THEN



              p_invoice.description := p_description || '. ' || p_worksheet_number;



            ELSE



              p_invoice.description := p_description;



            END IF;



          END IF;



            print_log('p_invoice.description: '||p_invoice.description);

             

          SELECT ap_invoices_interface_s.NEXTVAL

            INTO p_invoice.invoiceId

            FROM dual;



          p_account2 := NULL;



          BEGIN



            SELECT description

              INTO p_account2

              FROM fnd_lookup_values_vl

             WHERE lookup_type = 'AJC_AP_ABBYY_VENDOR_ACCT_MAP'

               AND lookup_code = p_vendor_num

               -- 20230227 Se agrega que mire solo los activos

               AND enabled_flag = 'Y'

               AND NVL(start_date_active,TRUNC(SYSDATE)) <= TRUNC(SYSDATE)

               AND NVL(end_date_active,TRUNC(SYSDATE)) >= TRUNC(SYSDATE)

               -- 20230227 

               ;



          EXCEPTION

           WHEN OTHERS THEN

              p_account2 := null;



          END;



          BEGIN



            SELECT AP_INVOICES_UTILITY_PKG.get_total_prepays(p_vendor_id)

              INTO p_qty_prepay

              FROM dual;



          EXCEPTION

            WHEN OTHERS THEN

              p_qty_prepay := 0; 



          END;

    END IF; --v_vendor_id not null

  END IF; -- p_vendor_id not null

  EXCEPTION

  WHEN OTHERS THEN

  print_log('Error en vendor_inv_validation - SQLERRM: ' ||SQLERRM);

  p_error_message := p_error_message ||' - '||SQLERRM;

END vendor_inv_validation;





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

    v_body          VARCHAR2(2000);

    v_clob_result   CLOB;

    v_status        VARCHAR2(1);



BEGIN



    print_log('insert_inv_header_bc - Inicio');



   -- v_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( gv_environment, p_company_id ) || v_api;

   v_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => gv_bc_environment,

                                                    p_entity => 'PURCHASE INVOICES',

                                                    p_subentity => 'HEADERS',

                                                    p_method => 'POST',

                                                    p_company_id => p_company_id );



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

    -- MB: REVISAR - DESCOMENTAR cuando esté disponible el campo division en la API    

    --APEX_JSON.write('division', p_invoice.division ,TRUE);

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



    v_clob_result := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url,

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

    v_body          VARCHAR2(2000);

    v_clob_result   CLOB;

    v_status        VARCHAR2(1);



BEGIN



    print_log('insert_inv_line_bc - Inicio');



   -- v_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( gv_environment, p_company_id ) || v_api;

    v_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => gv_bc_environment,

                                                    p_entity => 'PURCHASE INVOICES',

                                                    p_subentity => 'LINES',

                                                    p_method => 'POST',

                                                    p_company_id => p_company_id );



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

    APEX_JSON.write('distCodeCombination','-1' );

    APEX_JSON.write('company', p_inv_line.company );

    APEX_JSON.write('account',p_inv_line.account );

    APEX_JSON.write('accountDescription',p_inv_line.accountDescription);

    APEX_JSON.write('department', p_inv_line.department);

    APEX_JSON.write('product',p_inv_line.product );

    -- MB: REVISAR - DESCOMENTAR cuando esté disponible el campo division en la API    

    --APEX_JSON.write('division',p_inv_line.division );    

    APEX_JSON.write('destination', p_inv_line.destination );

    APEX_JSON.write('origin', p_inv_line.origin );

  --  APEX_JSON.write('intercompany',p_inv_line.intercompany);

    APEX_JSON.write('requestID',gv_request_id,TRUE);

    APEX_JSON.write('office',p_inv_line.office);



    APEX_JSON.close_object;



    v_body:=APEX_JSON.get_clob_output;



    print_log('v_body: '||v_body);





    v_clob_result := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url,

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

|                                                                          |

+=========================================================================*/

PROCEDURE process_invoices (p_status            OUT VARCHAR2

                           ,p_error_message     OUT VARCHAR2

                           -- Inicio Agregado 05032021

                           ,p_logistics_actual_acct IN VARCHAR2

                           --

                           ) IS



CURSOR c_inv is 



SELECT rowid row_id,org_id,vendor_id,vendor_site_code,invoice_num,invoice_date,invoice_type_lookup_code

,invoice_amount,invoice_currency_code,description,worksheet_number,status_code,request_id,

         decode(SUBSTR(file_path,1,2),'\\', 'http://'||REPLACE(SUBSTR(file_path,3),'\','/'),file_path) file_path,last_update_date,creation_date,error_message,invoice_id,

         vendor_num,vendor_name

FROM AJC_BC_ABBYY_INVOICES_INT a

WHERE 1 = 1 

AND ORG_ID = gv_org_id

AND creation_date >= TO_DATE('26/09/2024','DD/MM/YYYY')

--AND invoice_num IN ('17324993','VSSL001291067/A','ZJF-134976','20-174994-2','CLZ173762E','TINV33851','200023133701','553601810036','206561','SWX969')

AND ((STATUS_CODE = 'NEW' AND request_id IS NULL)

OR (STATUS_CODE IN ('ERROR','REJECTED') AND request_id is not null))

AND NOT EXISTS ( SELECT 1

                        FROM ap_invoices_all ai

                       WHERE ai.vendor_id = a.vendor_id

                         AND ai.invoice_num = a.invoice_num );



-- Cursor con las lineas que son creadas en este proceso (cuando no envian lineas de ABBYY)

-- REVISAR BC

CURSOR c_lin (p_org_id NUMBER,p_vendor_id NUMBER, p_vendor_site_code VARCHAR2,p_inv_type_lookup_code VARCHAR2,p_invoice_num VARCHAR2) IS

SELECT *

FROM AJC_BC_ABBYY_INV_LINES_INT

WHERE  ORG_ID = p_org_id

AND vendor_id = p_vendor_id

and vendor_site_code = p_vendor_site_code

and invoice_type_lookup_code = p_inv_type_lookup_code

and invoice_num = p_invoice_num

and request_id = gv_request_id

-- Inicio Agregado SBanchieri 26042021

and source_type = 'ORACLE'

-- Fin Agregado SBanchieri 26042021

;



-- Inicio Agregado SBanchieri 26042021

-- Cursor con las linas que son creadas por ABBYY

CURSOR c_lin_abbyy (p_org_id NUMBER,p_vendor_id NUMBER, p_vendor_site_code VARCHAR2,p_inv_type_lookup_code VARCHAR2,p_invoice_num VARCHAR2) IS

SELECT rowid row_id,

       ail.*

FROM AJC_BC_ABBYY_INV_LINES_INT ail

WHERE  ORG_ID = p_org_id

AND vendor_id = p_vendor_id

and vendor_site_code = p_vendor_site_code

and invoice_type_lookup_code = p_inv_type_lookup_code

and invoice_num = p_invoice_num

--and request_id IS NULL

and NVL(source_type,'ABBYY') != 'ORACLE'

;

-- Fin Agregado SBanchieri 26042021



v_invoice_id                ap_invoices_all.invoice_id%type; 

-- Inicio Comentado SBanchieri 20210611

-- v_line_number               ap_invoice_lines_interface.line_number%type;

-- Fin Comentado SBanchieri 20210611

v_vendor_name               po_vendors.vendor_name%type;

v_vendor_num                po_vendors.segment1%type;

v_func_currency_code        gl_sets_of_books.currency_code%type;

v_vendor_type_lookup_code   po_vendors.vendor_type_lookup_code%type;

v_company                   gl_code_combinations.segment1%type;

v_account                   gl_code_combinations.segment2%type;

v_account2                  gl_code_combinations.segment2%type;

v_account_new               gl_code_combinations.segment2%type;

v_qty_prepay                NUMBER;

v_ws_qty                    NUMBER;

v_ws                        VARCHAR2(240);

v_total_ws_amount           NUMBER;

v_total_func_amount         NUMBER;

v_line_func_amount          NUMBER;

v_diference                 NUMBER;

v_exclude                   VARCHAR2(1);



v_amount_dif NUMBER;

v_qty_lin NUMBER;



e_inv_exception      EXCEPTION;

e_cust_exception     EXCEPTION;



-- Inicio Agregado SBanchieri 23022021

v_vendor_code        po_vendors.ATTRIBUTE1%TYPE;

-- Fin Agregado SBanchieri 23022021



-- Inicio Agregado SBanchieri 26042021

v_cant_lineas_abbyy   NUMBER;

v_abbyy_line_number   ap_invoice_lines_interface.line_number%TYPE; 

v_error_line_abbyy    VARCHAR2(1);

-- Fin Agregado SBanchieri 26042021



v_invoice_bc    t_invoice_bc;

v_invoice_line_bc    t_inv_line_bc;

v_status    VARCHAR2(1);

v_period_name gl_periods.period_name%TYPE;

v_org_id    NUMBER;

v_company_id    VARCHAR2(100);

v_bc_account VARCHAR2(50);

v_oracle_account VARCHAR2(50);

v_error_message VARCHAR2(1000);

v_vendor_site_code VARCHAR2(200);



BEGIN



    print_log ('AJCL_BC_ABBYY_INTERFACE_PK.PROCESS_INVOICES (+)');



    print_log ('Obteniendo Segmento Compa?ia');



    -- Modificado KHRONUS/PBonadeo 20210520: Por definicion Yairaliz la compañia por defecto debe ser 53, excepto para OPM (PO, DL, SN) que es 54

    v_company := '53';

    -- Fin Modificado KHRONUS/PBonadeo 20210520: Por definicion Yairaliz la compañia por defecto debe ser 53, excepto para OPM (PO, DL, SN) que es 54



    print_log('Obteniendo moneda funcional de la organizacion.');

    BEGIN



        SELECT currency_code

          INTO v_func_currency_code

          FROM gl_sets_of_books gsob

              ,hr_operating_units hou

         WHERE gsob.set_of_books_id = hou.set_of_books_id

           AND hou.organization_id = gv_org_id;



    EXCEPTION

     WHEN OTHERS THEN

        p_error_message := 'Error getting company functional currency. Error: '||SQLERRM;

        RAISE e_inv_exception; 

    END;



    print_log('Moneda Funcional: '||v_func_currency_code);



    FOR r_inv IN c_inv LOOP



        print_log('');

        print_log('>> org_id: '||r_inv.org_id);

        print_log('>> vendor_id: '||r_inv.vendor_id);

        print_log('>> invoice_type_lookup_code: '||r_inv.invoice_type_lookup_code);

        print_log('>> invoice_num: '||r_inv.invoice_num);



        -- Inicio Agregado SBanchieri 26042021

        v_cant_lineas_abbyy := 0;



        -- Se verifica si se enviaron lineas desde ABBYY

        FOR cla IN c_lin_abbyy (r_inv.org_id,r_inv.vendor_id,r_inv.vendor_site_code,r_inv.invoice_type_lookup_code,r_inv.invoice_num) LOOP



          v_cant_lineas_abbyy := v_cant_lineas_abbyy + 1;



          -- Inicio Agregado 20210611 SBanchieri

          -- Se va seteando el line number

          UPDATE AJC_BC_ABBYY_INV_LINES_INT

             SET line_number = v_cant_lineas_abbyy

           WHERE rowid = cla.row_id;



          COMMIT;

          -- Fin Agregado 20210611 SBanchieri



        END LOOP;



        IF ( v_cant_lineas_abbyy = 0 ) THEN

        -- Si no se enviaron lineas desde ABBYY



          print_log('No se enviaron lineas para la factura desde ABBYY');

        -- Fin Agregado SBanchieri 26042021

        IF r_inv.status_code = 'ERROR' THEN --Elimino las lineas para reconstruir por si los ws cambian



           DELETE ajc_bc_abbyy_inv_lines_int

            WHERE org_id = r_inv.org_id

              AND vendor_id = r_inv.vendor_id

              and vendor_site_code = r_inv.vendor_site_code

              and invoice_type_lookup_code = r_inv.invoice_type_lookup_code

              and invoice_num = r_inv.invoice_num

              -- Inicio Agregado SBanchieri 26042021

              and source_type = 'ORACLE'

              -- Fin Agregado SBanchieri 26042021

              ;



           UPDATE ajc_bc_abbyy_invoices_int

           set error_message = null

           where rowid = r_inv.row_id;



           COMMIT; 

        END IF;



      BEGIN



        v_invoice_bc := NULL;

        v_invoice_bc.organisationId := r_inv.org_id;

        v_invoice_bc.source := gv_source;

        v_invoice_bc.pdfFileUrl := r_inv.file_path;        

        v_vendor_num := r_inv.vendor_num;

        v_vendor_name := r_inv.vendor_name;

        v_vendor_site_code := NULL;



        -- Inicio Modificado SBanchieri 26042021

        -- Se reemplaza el código por una funcion

        p_error_message := NULL;



        vendor_inv_validation ( p_invoice => v_invoice_bc,

                                p_vendor_id => r_inv.vendor_id,

                                p_vendor_name => v_vendor_name,

                                p_vendor_num => v_vendor_num,

                                p_vendor_type_lookup_code => v_vendor_type_lookup_code,

                                p_exclude => v_exclude,  

                                p_account => v_account,

                                p_logistics_actual_acct => p_logistics_actual_acct,

                                --

                                p_vendor_site_code => v_vendor_site_code,

                                p_org_id => r_inv.org_id,

                                --

                                p_invoice_type_lookup_code => r_inv.invoice_type_lookup_code,

                                p_invoice_amount => r_inv.invoice_amount,

                                p_invoice_num => r_inv.invoice_num,

                                p_invoice_id => v_invoice_id,

                                p_invoice_date => r_inv.invoice_date,

                                p_invoice_currency_code => r_inv.invoice_currency_code,

                                p_func_currency_code => v_func_currency_code,

                                p_worksheet_number => r_inv.worksheet_number,

                                p_description => r_inv.description,

                                p_account2 => v_account2,

                                p_qty_prepay => v_qty_prepay,

                                --

                                p_error_message => p_error_message );



        print_log('p_error_message: '||p_error_message);

        

        IF ( p_error_message IS NOT NULL ) THEN



          RAISE e_inv_exception;



        END IF;            

        -- Fin Modificado SBanchieri 26042021



        v_invoice_bc.vendorNo := v_vendor_num;

        v_invoice_bc.vendorSiteCode := v_vendor_site_code;

        

        v_company := get_company ( r_inv.worksheet_number );

        

        v_invoice_bc.company := v_company;

        v_invoice_bc.account := '2000';

        v_invoice_bc.accountDescription := 'ACCOUNTS PAYABLE-TRADE';

        

        print_log ('Obteniendo v_company_id');



        ajc_bc_ws_utils_pkg.get_bc_company_id_f(r_inv.org_id,NULL,NULL,v_company_id,v_status);        

        

        v_invoice_bc.glDate := TO_CHAR(TRUNC(SYSDATE),'YYYY-MM-DD');



        IF v_qty_prepay > 0 OR --REVISAR

           v_exclude = 'Y' THEN 



            -- Inicio Agregado SBanchieri 20210616

            IF ( v_qty_prepay > 0 ) THEN

              v_invoice_line_bc.description := '[PP] ' || v_invoice_bc.description;

              v_invoice_line_bc.accountDescription :=  '[PP] ' || v_invoice_bc.description;              

              -- Fin Agregado SBanchieri 20210616

              v_invoice_bc.description := '[PP] ' || v_invoice_bc.description;

            -- Inicio Agregado SBanchieri 20210616

            ELSE

              v_invoice_line_bc.description := v_invoice_bc.description;

              v_invoice_line_bc.accountDescription :=   v_invoice_bc.description;              

              v_invoice_bc.description := v_invoice_bc.description;

            END IF;

            -- Fin Agregado SBanchieri 20210616



            print_log('Prepays without Applied: ' || v_qty_prepay);



            v_invoice_line_bc := null; 

            v_invoice_line_bc.invoiceId := v_invoice_bc.invoiceId;

            v_invoice_line_bc.lineNo := 1;

         --   v_invoice_line_bc.line_type_lookup_code := 'ITEM';

            v_invoice_line_bc.amount := 0;

            v_invoice_line_bc.baseAmount := 0;



            v_account_new := get_account ( r_inv.worksheet_number, r_inv.vendor_id, gv_dft_account,r_inv.invoice_amount );



            -- v_invoice_line_bc.distCodeCombination := v_company || '.' || g_dft_account || '.000.000.000.000.00';

           -- v_invoice_line_bc.distCodeCombination := v_company || '.' || v_account_new || '.000.000.000.000.00';

            

            v_invoice_line_bc.company := v_company;

            v_invoice_line_bc.account := v_account_new;

            v_invoice_line_bc.department := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DEPARTMENT', '000');

            v_invoice_line_bc.product:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'PRODUCT', '000');

                                                                                        

            v_invoice_line_bc.division:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DIVISION', '000');

            

            v_invoice_line_bc.destination := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DESTINATION', '000');

            v_invoice_line_bc.origin := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'ORIGIN', '000');            



            print_log('Before get_dimension_value');

            v_invoice_line_bc.office := NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                                                                ,p_oracle_value   => '000'

                                                                                                                                ,p_bc_dimension   => 'OFFICE'),'000');



            v_invoice_line_bc.office := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'OFFICE', v_invoice_line_bc.office);



            print_log('After get_dimension_value');



            v_invoice_line_bc.worksheetNo := 'N/A';

            v_invoice_line_bc.organisationID := v_invoice_bc.organisationId;



            print_log('Insertando linea en la interfaz');

            

             insert_inv_line_bc (v_company_id,v_invoice_line_bc,v_status,v_error_message);

             

            IF v_status = 'E' THEN

                p_error_message := 'Error al insertar registro de linea en stage de BC: '||v_error_message;

                RAISE e_inv_exception;

            END IF;

            



        ELSIF v_account2 IS NOT NULL THEN 



            print_log('El proveedor tiene asignada la cuenta: ' || v_account2);



            v_invoice_line_bc := null; 

            v_invoice_line_bc.invoiceId := v_invoice_bc.invoiceId;

            v_invoice_line_bc.lineNo := 1;

      --      v_invoice_line_bc.line_type_lookup_code := 'ITEM';



            v_invoice_line_bc.amount  := v_invoice_bc.invoiceAmount;

            v_invoice_line_bc.baseAmount := 0;            



            v_account_new := get_account ( r_inv.worksheet_number, r_inv.vendor_id, v_account2,r_inv.invoice_amount );





            --v_invoice_line_bc.distCodeCombination := v_company || '.' || v_account_new || '.000.000.000.000.00';



            v_invoice_line_bc.company := v_company;

            v_invoice_line_bc.account := v_account_new;

            v_invoice_line_bc.department := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DEPARTMENT', '000');

            v_invoice_line_bc.product:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'PRODUCT', '000');

                                                                                                                                            

            v_invoice_line_bc.division:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DIVISION', '000');       

                 

            v_invoice_line_bc.destination := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DESTINATION', '000');

            v_invoice_line_bc.origin := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'ORIGIN', '000');            



            print_log('Before get_dimension_value');

            v_invoice_line_bc.office := NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                                                                ,p_oracle_value   => '000'

                                                                                                                                ,p_bc_dimension   => 'OFFICE'),'000');



            v_invoice_line_bc.office := ajc_bc_account_dim_pkg.account_dim_required(v_invoice_line_bc.account,'OFFICE', v_invoice_line_bc.office);



            print_log('After get_dimension_value');

            

            v_invoice_line_bc.description := v_invoice_bc.description;

            v_invoice_line_bc.accountDescription :=  v_invoice_bc.description;

            v_invoice_line_bc.worksheetNo := 'N/A';

            v_invoice_line_bc.organisationId := v_invoice_bc.organisationId;





            print_log('Insertando linea en la interfaz');



             insert_inv_line_bc (v_company_id,v_invoice_line_bc,v_status,v_error_message);

             

            IF v_status = 'E' THEN

                p_error_message := 'Error al insertar registro de linea en stage de BC: '||v_error_message;

                RAISE e_inv_exception;

            END IF;



        ELSIF r_inv.worksheet_number IS NULL THEN



            print_log('Worksheet NULO');



            v_invoice_line_bc := null; 

            v_invoice_line_bc.invoiceId := v_invoice_bc.invoiceId;

            v_invoice_line_bc.lineNo := 1;

         --   v_invoice_line_bc.line_type_lookup_code := 'ITEM';

            v_invoice_line_bc.amount := 0;



            v_account_new := get_account ( r_inv.worksheet_number, r_inv.vendor_id, gv_dft_account,r_inv.invoice_amount );



            -- v_invoice_line_bc.distCodeCombination := v_company || '.' || g_dft_account || '.000.000.000.000.00';

           -- v_invoice_line_bc.distCodeCombination := v_company || '.' || v_account_new || '.000.000.000.000.00';



            v_invoice_line_bc.company := v_company;

            v_invoice_line_bc.account := v_account_new;

            v_invoice_line_bc.department := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DEPARTMENT', '000');

            v_invoice_line_bc.product:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'PRODUCT', '000');



            v_invoice_line_bc.division:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DIVISION', '000');         

               

            v_invoice_line_bc.destination := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DESTINATION', '000');

            v_invoice_line_bc.origin := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'ORIGIN', '000');            



            print_log('Before get_dimension_value');

            v_invoice_line_bc.office := NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                                                                ,p_oracle_value   => '000'

                                                                                                                                ,p_bc_dimension   => 'OFFICE'),'000');



            v_invoice_line_bc.office := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'OFFICE', v_invoice_line_bc.office);



            print_log('After get_dimension_value');

            

            v_invoice_line_bc.description := v_invoice_bc.description;

            v_invoice_line_bc.accountDescription :=  v_invoice_bc.description;

            v_invoice_line_bc.worksheetNo := 'N/A';

            v_invoice_line_bc.organisationId := v_invoice_bc.organisationId;



            print_log('Insertando linea en la interfaz');

            

             insert_inv_line_bc (v_company_id,v_invoice_line_bc,v_status,v_error_message);

             

            IF v_status = 'E' THEN

                p_error_message := 'Error al insertar registro de linea en stage de BC: '||v_error_message;

                RAISE e_inv_exception;

            END IF;

            

        ELSE



          SELECT CASE WHEN INSTR(REPLACE(r_inv.worksheet_number,' '),'|') > 0 then

               (SELECT DECODE(substr(REPLACE(r_inv.worksheet_number,' '),-1)

               ,'|',REGEXP_COUNT(REPLACE(REPLACE(r_inv.worksheet_number,' '),'|','@'),'@')

                   ,REGEXP_COUNT(REPLACE(REPLACE(r_inv.worksheet_number,' '),'|','@'),'@')+1)

              from dual)

              ELSE

              1 end 

            INTO v_ws_qty

            FROM dual;



            print_log ('Cantidad de Worksheet informados: '||v_ws_qty);



            v_total_ws_amount := 0;



            FOR i in 1..v_ws_qty LOOP



                v_ws := get_text(REPLACE(r_inv.worksheet_number,' '),i);



                v_company := get_company ( v_ws );

                v_account_new := get_account ( v_ws, r_inv.vendor_id, v_account,r_inv.invoice_amount );



                print_log ('Segmento Compania: ' || v_company);

                -- print_log ('Cuenta: '||v_account);

                print_log ('Cuenta: ' || v_account_new);



                print_log ('Worksheet Number: ' || v_ws);



                   v_invoice_line_bc.lineNo := i;

                   v_invoice_line_bc.amount := round(v_invoice_bc.invoiceAmount/v_ws_qty,2);

                   v_total_ws_amount := v_total_ws_amount + v_invoice_line_bc.amount;

                   v_invoice_line_bc.description :=  v_ws;

                   v_invoice_line_bc.accountDescription :=  v_ws;



                  print_log ('Insertando Registro en ajc_bc_ABBYY_INV_LINES_INT');



                  INSERT 

                    INTO ajc_bc_ABBYY_INV_LINES_INT 

                         ( org_id, vendor_id, vendor_site_code, invoice_type_lookup_code, invoice_num,

                           worksheet_number, accrual_func_amount,accrual_amount,request_id,creation_date,created_by,last_update_date,last_updated_by,

                           line_amount,source_type,line_number)

                  VALUES (r_inv.org_id,r_inv.vendor_id,r_inv.vendor_site_code,r_inv.invoice_type_lookup_code

                                                                ,r_inv.invoice_num,v_ws,v_invoice_line_bc.amount,ROUND(v_invoice_line_bc.amount,2)

                                                                ,gv_request_id,sysdate,gv_user_id,sysdate,gv_user_id

                                                                -- Inicio Agregado SBanchieri 26042021

                                                                ,NULL -- line_amount

                                                                ,'ORACLE' -- source_type

                                                                -- Fin Agregado SBanchieri 26042021

                                                                -- Inicio Agregado 20210611 SBanchieri

                                                                ,i -- Se inserta el numero de linea

                                                                -- Fin Agregado 20210611 SBanchieri

                                                                );





              END LOOP;



              print_log ('Total Accrual: ' || v_total_ws_amount);



              v_total_func_amount := r_inv.invoice_amount;





              IF r_inv.invoice_type_lookup_code = 'CREDIT' THEN 

                v_total_func_amount := v_total_func_amount *-1;

              END IF;



              IF v_func_currency_code = v_invoice_bc.invoiceCurrencyCode THEN



                print_log ('WS Amount: '||ROUND(v_total_ws_amount,2));

                print_log ('Invoice Amount: '||ROUND(v_total_func_amount,2));



                IF  ROUND(v_total_ws_amount,2) <> ROUND(v_total_func_amount,2) THEN



                  v_diference := 1;

                  print_log ('El monto del comprobante no es igual al monto total de los worksheets.');



                  -- Inicio Agregado SBanchieri 20210629

                  p_error_message := 'WS Amount: ' || ROUND(v_total_ws_amount,2) || 

                                     ' | Invoice Amount: ' || ROUND(v_total_func_amount,2) ||

                                     ' | El monto del comprobante no es igual al monto total de los worksheets.';

                  -- Fin Agregado SBanchieri 20210629



                ELSE

                  v_diference := 0;

                  v_amount_dif := ROUND(v_total_func_amount,2) - ROUND(v_total_ws_amount,2);

                  print_log('Monto de Diferencia: '||v_amount_dif);

                END IF;



              END IF;



            -- Inicio Comentado SBanchieri 20210611

            -- v_line_number := 0;

            -- Fin Comentado SBanchieri 20210611

            v_qty_lin := 0;



            print_log('- 20230119 ---------------------------------------------');

            print_log('r_inv.org_id: |' || r_inv.org_id || '|');

            print_log('r_inv.vendor_id: |'|| r_inv.vendor_id || '|');

            print_log('r_inv.vendor_site_code: |'|| r_inv.vendor_site_code || '|');

            print_log('r_inv.invoice_type_lookup_code: |'|| r_inv.invoice_type_lookup_code || '|');

            print_log('r_inv.invoice_num: |'|| r_inv.invoice_num || '|');

            print_log('- 20230119 ---------------------------------------------');



            IF v_amount_dif != 0 THEN 

                FOR r_lin in c_lin (r_inv.org_id,r_inv.vendor_id,r_inv.vendor_site_code,r_inv.invoice_type_lookup_code,r_inv.invoice_num) LOOP

                 v_qty_lin := v_qty_lin + 1;

                END LOOP;

            END IF;



            print_log ('Cantidad de Lineas: '||v_qty_lin);



            FOR r_lin in c_lin (r_inv.org_id,r_inv.vendor_id,r_inv.vendor_site_code,r_inv.invoice_type_lookup_code,r_inv.invoice_num) LOOP



                print_log('Insertando Linea para worksheet:'||r_lin.worksheet_number);



                v_invoice_line_bc := null; 



                -- Inicio Comentado SBanchieri 20210611

                -- v_line_number := v_line_number + 1;

                -- Fin Comentado SBanchieri 20210611



                v_invoice_line_bc.invoiceId := v_invoice_bc.invoiceId;



                -- Inicio Modificado SBanchieri 20210611

                -- v_invoice_line_bc.line_number := v_line_number;

                v_invoice_line_bc.lineNo := r_lin.line_number;

                -- Inicio Modificado SBanchieri 20210611



          --      v_invoice_line_bc.line_type_lookup_code := 'ITEM';



                v_company := get_company ( r_lin.worksheet_number );



                IF r_lin.accrual_amount = 0 THEN 



                    v_invoice_line_bc.amount := v_invoice_bc.invoiceAmount;--r_lin.accrual_amount; REVISAR

                    v_account_new := get_account ( r_lin.worksheet_number, r_inv.vendor_id, gv_dft_account,r_inv.invoice_amount );



                    -- v_invoice_line_bc.distCodeCombination := v_company||'.'||g_dft_account||'.000.000.000.000.00';

                    --v_invoice_line_bc.distCodeCombination := v_company||'.'||v_account_new||'.000.000.000.000.00';



                    v_invoice_line_bc.company := v_company;

                    v_invoice_line_bc.account := v_account_new;

                    v_invoice_line_bc.department := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DEPARTMENT', '000');

                    v_invoice_line_bc.product:=ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'PRODUCT', '000');

                                                                                                                                                    

                    v_invoice_line_bc.division:=ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DIVISION', '000');       

                    

                                 

                    v_invoice_line_bc.destination := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DESTINATION', '000');

                    v_invoice_line_bc.origin := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'ORIGIN', '000');            



                    print_log('Before get_dimension_value 1');

                    v_invoice_line_bc.office := NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                                                                        ,p_oracle_value   => '000'

                                                                                                                                        ,p_bc_dimension   => 'OFFICE'),'000');



                    v_invoice_line_bc.office := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'OFFICE', v_invoice_line_bc.office);



                    print_log('After get_dimension_value 1');                    



                ELSE



                    IF v_diference = 0 THEN 

                      IF v_qty_lin = 1 THEN 

                          v_invoice_line_bc.amount := v_total_func_amount;

                      -- Inicio Modificado SBanchieri 20210611

                      -- ELSIF v_qty_lin > v_line_number THEN

                      ELSIF v_qty_lin > r_lin.line_number THEN

                      -- Fin Modificado SBanchieri 20210611

                          v_invoice_line_bc.amount := r_lin.accrual_amount + TRUNC(v_amount_dif/v_qty_lin,2);

                          v_amount_dif := v_amount_dif - TRUNC(v_amount_dif/v_qty_lin,2);

                      ELSE 

                          v_invoice_line_bc.amount := r_lin.accrual_amount + v_amount_dif;

                      END IF;



                      v_account_new := get_account ( r_lin.worksheet_number, r_inv.vendor_id, v_account,r_inv.invoice_amount );



                      -- v_invoice_line_bc.distCodeCombination := v_company||'.'||v_account||'.000.000.000.000.00';

                      --v_invoice_line_bc.distCodeCombination := v_company||'.'||v_account_new||'.000.000.000.000.00';

                      

                        v_invoice_line_bc.company := v_company;

                        v_invoice_line_bc.account := v_account_new;

                        v_invoice_line_bc.department := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DEPARTMENT', '000');

                        v_invoice_line_bc.product:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'PRODUCT', '000');

                        

                        v_invoice_line_bc.division:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DIVISION', '000');     

                                           

                        v_invoice_line_bc.destination := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DESTINATION', '000');

                        v_invoice_line_bc.origin := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'ORIGIN', '000');            



                        print_log('Before get_dimension_value 2');

                        v_invoice_line_bc.office := NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                                                                            ,p_oracle_value   => '000'

                                                                                                                                            ,p_bc_dimension   => 'OFFICE'),'000');



                        v_invoice_line_bc.office := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'OFFICE', v_invoice_line_bc.office);



                        print_log('After get_dimension_value 2');                      



                    ELSE

                      v_invoice_line_bc.amount := 0;



                      v_account_new := get_account ( r_lin.worksheet_number, r_inv.vendor_id, gv_dft_account,r_inv.invoice_amount );



                      -- v_invoice_line_bc.distCodeCombination := v_company||'.'||g_dft_account||'.000.000.000.000.00';

                      --v_invoice_line_bc.distCodeCombination := v_company||'.'||v_account_new||'.000.000.000.000.00';

                      

                                  v_invoice_line_bc.company := v_company;

                                    v_invoice_line_bc.account := v_account_new;

                                    v_invoice_line_bc.department := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DEPARTMENT', '000');

                                    v_invoice_line_bc.product:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'PRODUCT', '000');

                                    v_invoice_line_bc.division:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DIVISION', '000');                                    

                                    v_invoice_line_bc.destination := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DESTINATION', '000');

                                    v_invoice_line_bc.origin := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'ORIGIN', '000');            



                                    print_log('Before get_dimension_value 3');

                                    v_invoice_line_bc.office := NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                                                                                        ,p_oracle_value   => '000'

                                                                                                                                                        ,p_bc_dimension   => 'OFFICE'),'000');



                                    v_invoice_line_bc.office := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'OFFICE', v_invoice_line_bc.office);



                                    print_log('After get_dimension_value 3');



                    END IF;

                END IF;



                print_log ('Monto: '||v_invoice_line_bc.amount);

                print_log ('Cuenta: '||v_invoice_line_bc.distCodeCombination);



                v_invoice_line_bc.description := v_invoice_bc.description;

                v_invoice_line_bc.accountDescription :=  v_invoice_bc.description;                

                v_invoice_line_bc.worksheetNo := r_lin.worksheet_number;

                v_invoice_line_bc.organisationId := v_invoice_bc.organisationId;



                print_log('Insertando linea en la interfaz');



                 insert_inv_line_bc (v_company_id,v_invoice_line_bc,v_status,v_error_message);

                 

                IF v_status = 'E' THEN

                    p_error_message := 'Error al insertar registro de linea en stage de BC: '||v_error_message;

                    RAISE e_inv_exception;

                END IF;



            END LOOP;



        END IF;

    -- Inserto Cabecera

        BEGIN       

           insert_inv_header_bc (v_company_id,v_invoice_bc,v_status,v_error_message);



           IF v_status = 'E' THEN

                p_error_message := 'Error al insertar registro de cabecera en stage de BC: '||v_error_message;

                RAISE e_inv_exception;

           END IF;

        END;



           UPDATE ajc_bc_abbyy_invoices_int

              SET status_code = 'SENT'

                 ,error_message = p_error_message

                 ,request_id = gv_request_id

                 ,invoice_id = v_invoice_bc.invoiceId

                 ,last_update_date = sysdate

                 ,last_updated_by = gv_user_id

                 ,last_update_login = -1

            WHERE rowid = r_inv.row_id;



            COMMIT;



      EXCEPTION

        WHEN e_inv_exception THEN 

           print_log (p_error_message);



           ROLLBACK;



           UPDATE ajc_bc_abbyy_invoices_int

              SET status_code = 'ERROR'

                 ,error_message = p_error_message

                 ,request_id = gv_request_id

                 ,last_update_date = sysdate

                 ,last_updated_by = gv_user_id

                 ,last_update_login = -1

            WHERE rowid = r_inv.row_id;



            p_status := 'W';



            COMMIT;



        WHEN OTHERS THEN 

           p_error_message := 'Error OTHERS processing the invoice ' || r_inv.invoice_num || '. Error: '||SQLERRM;

           print_log (p_error_message);



           ROLLBACK; 



           UPDATE ajc_bc_abbyy_invoices_int

              SET status_code = 'ERROR'

                 ,error_message = p_error_message

                 ,request_id = gv_request_id

                 ,last_update_date = sysdate

                 ,last_updated_by = gv_user_id

                 ,last_update_login = -1

            WHERE rowid = r_inv.row_id;



            COMMIT;



            p_status := 'W';

      END;



      -- Inicio Agregado SBanchieri 26042021

      ELSE 

      -- Se enviaron lineas desde ABBYY



        BEGIN 



          print_log('Se enviaron lineas desde ABBYY');



          v_invoice_bc := NULL;

          v_invoice_bc.organisationId := r_inv.org_Id;

          v_invoice_bc.source := gv_source;

          v_invoice_bc.pdfFileUrl := r_inv.file_path;          

          v_vendor_num := r_inv.vendor_num;

          v_vendor_name := r_inv.vendor_name;

          v_vendor_site_code := NULL;



          p_error_message := NULL;



          vendor_inv_validation ( p_invoice => v_invoice_bc,

                                  p_vendor_id => r_inv.vendor_id,

                                  p_vendor_name => v_vendor_name,

                                  p_vendor_num => v_vendor_num,

                                  p_vendor_type_lookup_code => v_vendor_type_lookup_code,

                                  p_exclude => v_exclude,  

                                  p_account => v_account,

                                  p_logistics_actual_acct => p_logistics_actual_acct,

                                  --

                                  p_vendor_site_code => v_vendor_site_code,

                                  p_org_id => r_inv.org_id,

                                  --

                                  p_invoice_type_lookup_code => r_inv.invoice_type_lookup_code,

                                  p_invoice_amount => r_inv.invoice_amount,

                                  p_invoice_num => r_inv.invoice_num,

                                  p_invoice_id => v_invoice_id,

                                  p_invoice_date => r_inv.invoice_date,

                                  p_invoice_currency_code => r_inv.invoice_currency_code,

                                  p_func_currency_code => v_func_currency_code,

                                  p_worksheet_number => r_inv.worksheet_number,

                                  p_description => r_inv.description,

                                  p_account2 => v_account2,

                                  p_qty_prepay => v_qty_prepay,

                                  --

                                  p_error_message => p_error_message );



          IF ( p_error_message IS NOT NULL ) THEN



            RAISE e_inv_exception;



          END IF;  



        v_invoice_bc.vendorNo := v_vendor_num;

        v_invoice_bc.vendorSiteCode := v_vendor_site_code;

        

        v_company := get_company ( r_inv.worksheet_number );  

        

        v_invoice_bc.company := v_company;

        v_invoice_bc.account := '2000';

        v_invoice_bc.accountDescription := 'ACCOUNTS PAYABLE-TRADE';

        

        print_log ('Obteniendo v_company_id');



        ajc_bc_ws_utils_pkg.get_bc_company_id_f(r_inv.org_id,NULL,NULL,v_company_id,v_status);        

        

        v_invoice_bc.glDate := TO_CHAR(TRUNC(SYSDATE),'YYYY-MM-DD');



          --

          IF v_qty_prepay > 0 OR

             v_exclude = 'Y' THEN 



            -- Inicio Agregado SBanchieri 20210616

            IF ( v_qty_prepay > 0 ) THEN

              v_invoice_line_bc.description := '[PP] ' || v_invoice_bc.description;

              v_invoice_line_bc.accountDescription :=  '[PP] ' ||  v_invoice_bc.description;              

            -- Fin Agregado SBanchieri 20210616

              v_invoice_bc.description := '[PP] ' || v_invoice_bc.description;

            -- Inicio Agregado SBanchieri 20210616

            ELSE

              v_invoice_line_bc.description := v_invoice_bc.description;

              v_invoice_line_bc.accountDescription :=  v_invoice_bc.description;                 

              v_invoice_bc.description := v_invoice_bc.description;

            END IF;

            -- Fin Agregado SBanchieri 20210616



            print_log('Prepays without Applied: ' || v_qty_prepay);



            v_invoice_line_bc := null; 

            v_invoice_line_bc.invoiceId := v_invoice_bc.invoiceId;

            v_invoice_line_bc.lineNo := 1;

       --     v_invoice_line_bc.line_type_lookup_code := 'ITEM';

            v_invoice_line_bc.amount := 0;



            v_account_new := get_account ( r_inv.worksheet_number, r_inv.vendor_id, gv_dft_account,r_inv.invoice_amount );



            -- v_invoice_line_bc.distCodeCombination := v_company || '.' || g_dft_account || '.000.000.000.000.00';

            --v_invoice_line_bc.distCodeCombination := v_company || '.' || v_account_new || '.000.000.000.000.00';



            v_invoice_line_bc.company := v_company;

            v_invoice_line_bc.account := v_account_new;

            v_invoice_line_bc.department := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DEPARTMENT', '000');

            v_invoice_line_bc.product:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'PRODUCT', '000');

            v_invoice_line_bc.division:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DIVISION', '000');            

            v_invoice_line_bc.destination := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DESTINATION', '000');

            v_invoice_line_bc.origin := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'ORIGIN', '000');            



            print_log('Before get_dimension_value');

            v_invoice_line_bc.office := NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                                                                ,p_oracle_value   => '000'

                                                                                                                                ,p_bc_dimension   => 'OFFICE'),'000');



            v_invoice_line_bc.office := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'OFFICE', v_invoice_line_bc.office);



            print_log('After get_dimension_value');



            v_invoice_line_bc.worksheetNo := 'N/A';

            v_invoice_line_bc.organisationId := v_invoice_bc.organisationId;



            print_log('Insertando linea en la interfaz');



                 insert_inv_line_bc (v_company_id,v_invoice_line_bc,v_status,v_error_message);

                 

                IF v_status = 'E' THEN

                    p_error_message := 'Error al insertar registro de linea en stage de BC: '||v_error_message;

                    RAISE e_inv_exception;

                END IF;



              -- Inicio Agregado SBanchieri 11052021

              -- Se actualiza la linea procesada con el request_id

              UPDATE ajc_bc_ABBYY_INV_LINES_INT

                 SET request_id =gv_request_id

               WHERE ORG_ID = r_inv.org_id

                 AND vendor_id = r_inv.vendor_id

                 AND vendor_site_code = r_inv.vendor_site_code

                 AND invoice_type_lookup_code = r_inv.invoice_type_lookup_code

                 AND invoice_num = r_inv.invoice_num

              --   AND request_id IS NULL

                 AND NVL(source_type,'ABBYY') != 'ORACLE';





          ELSIF v_account2 IS NOT NULL THEN 



            print_log('El proveedor tiene asignada la cuenta: ' || v_account2);



            v_invoice_line_bc := null; 

            v_invoice_line_bc.invoiceId := v_invoice_bc.invoiceId;

            v_invoice_line_bc.lineNo := 1;

         --   v_invoice_line_bc.line_type_lookup_code := 'ITEM';



            v_invoice_line_bc.amount  := v_invoice_bc.invoiceAmount;



            v_account_new := get_account ( r_inv.worksheet_number, r_inv.vendor_id, v_account2,r_inv.invoice_amount );



           -- v_invoice_line_bc.distCodeCombination := v_company || '.' || v_account_new || '.000.000.000.000.00';

            

            v_invoice_line_bc.company := v_company;

            v_invoice_line_bc.account := v_account_new;

            v_invoice_line_bc.department := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DEPARTMENT', '000');

            v_invoice_line_bc.product:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'PRODUCT', '000');

            v_invoice_line_bc.division:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DIVISION', '000');            

            v_invoice_line_bc.destination := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DESTINATION', '000');

            v_invoice_line_bc.origin := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'ORIGIN', '000');            



            print_log('Before get_dimension_value');

            v_invoice_line_bc.office := NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                                                                ,p_oracle_value   => '000'

                                                                                                                                ,p_bc_dimension   => 'OFFICE'),'000');



            v_invoice_line_bc.office := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'OFFICE', v_invoice_line_bc.office);



            print_log('After get_dimension_value');            



            v_invoice_line_bc.description := v_invoice_bc.description;

            v_invoice_line_bc.accountDescription :=  v_invoice_bc.description;                  

            v_invoice_line_bc.worksheetNo := 'N/A';

            v_invoice_line_bc.organisationId := v_invoice_bc.organisationId;



            print_log('Insertando linea en la interfaz');



                 insert_inv_line_bc (v_company_id,v_invoice_line_bc,v_status,v_error_message);

                 

                IF v_status = 'E' THEN

                    p_error_message := 'Error al insertar registro de linea en stage de BC: '||v_error_message;

                    RAISE e_inv_exception;

                END IF;



              -- Inicio Agregado SBanchieri 11052021

              -- Se actualiza la linea procesada con el request_id

              UPDATE ajc_bc_ABBYY_INV_LINES_INT

                 SET request_id = gv_request_id

               WHERE ORG_ID = r_inv.org_id

                 AND vendor_id = r_inv.vendor_id

                 AND vendor_site_code = r_inv.vendor_site_code

                 AND invoice_type_lookup_code = r_inv.invoice_type_lookup_code

                 AND invoice_num = r_inv.invoice_num

               --  AND request_id IS NULL

                 AND NVL(source_type,'ABBYY') != 'ORACLE';





          ELSE 



            v_abbyy_line_number := 0;



            -- Inicio Agregado SBanchieri 20210615

            v_error_line_abbyy := 'N';

            -- Fin Agregado SBanchieri 20210615



            FOR cla IN c_lin_abbyy (r_inv.org_id,r_inv.vendor_id,r_inv.vendor_site_code,r_inv.invoice_type_lookup_code,r_inv.invoice_num) LOOP



              -- Inicio Agregado SBanchieri 20210615

              BEGIN



                IF ( cla.line_amount IS NULL ) THEN



                  p_error_message := 'line_amount in table ajc_bc_ABBYY_INV_LINES_INT cannot be null.';

                  RAISE e_inv_exception;



                END IF;

              -- Fin Agregado SBanchieri 20210615



              v_abbyy_line_number := v_abbyy_line_number + 1;



              -- Inicio Agregado SBanchieri 20210611

              -- Se le pone line_number a cada linea

              UPDATE ajc_bc_ABBYY_INV_LINES_INT

                 SET line_number = v_abbyy_line_number

               WHERE rowid = cla.row_id;



              COMMIT;

              -- Fin Agregado SBanchieri 20210611



              v_company := get_company ( cla.worksheet_number );  



              IF cla.worksheet_number IS NULL THEN



                print_log('Worksheet NULO');



                v_invoice_line_bc := null; 

                v_invoice_line_bc.invoiceId := v_invoice_bc.invoiceId;

                v_invoice_line_bc.lineNo := v_abbyy_line_number;

             --   v_invoice_line_bc.line_type_lookup_code := 'ITEM';

                v_invoice_line_bc.amount := 0;



                v_account_new := get_account ( cla.worksheet_number, r_inv.vendor_id, gv_dft_account,r_inv.invoice_amount );



                --v_invoice_line_bc.distCodeCombination := v_company || '.' || v_account_new || '.000.000.000.000.00';



                v_invoice_line_bc.company := v_company;

                v_invoice_line_bc.account := v_account_new;

                v_invoice_line_bc.department := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DEPARTMENT', '000');

                v_invoice_line_bc.product:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'PRODUCT', '000');

                v_invoice_line_bc.division:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DIVISION', '000');                

                v_invoice_line_bc.destination := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DESTINATION', '000');

                v_invoice_line_bc.origin := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'ORIGIN', '000');            



                print_log('Before get_dimension_value');

                v_invoice_line_bc.office := NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                                                                    ,p_oracle_value   => '000'

                                                                                                                                    ,p_bc_dimension   => 'OFFICE'),'000');



                v_invoice_line_bc.office := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'OFFICE', v_invoice_line_bc.office);



                print_log('After get_dimension_value');

            

                v_invoice_line_bc.description := v_invoice_bc.description;

                v_invoice_line_bc.accountDescription :=  v_invoice_bc.description;                      

                v_invoice_line_bc.worksheetNo := 'N/A';

                v_invoice_line_bc.organisationId := v_invoice_bc.organisationId;



                print_log('Insertando linea en la interfaz');



                 insert_inv_line_bc (v_company_id,v_invoice_line_bc,v_status,v_error_message);

                 

                IF v_status = 'E' THEN

                    p_error_message := 'Error al insertar registro de linea en stage de BC: '||v_error_message;

                    RAISE e_inv_exception;

                END IF;



                  -- Inicio Agregado SBanchieri 11052021

                  -- Se actualiza la linea procesada con el request_id

                  UPDATE ajc_bc_ABBYY_INV_LINES_INT

                     SET request_id = gv_request_id

                   WHERE rowid = cla.row_id;

                  -- Fin Agregado SBanchieri 11052021



              ELSE

              -- Worksheet NO NULO



                v_ws := cla.worksheet_number;



                v_account_new := get_account ( v_ws, r_inv.vendor_id, v_account,r_inv.invoice_amount );



                print_log ('Segmento Compania: ' || v_company);



                -- print_log ('Cuenta: ' || v_account);

                print_log ('Cuenta: ' || v_account_new);



                print_log ('Worksheet Number: ' || v_ws);



                v_line_func_amount := cla.line_amount;



                IF r_inv.invoice_type_lookup_code = 'CREDIT' THEN 



                  v_line_func_amount := v_line_func_amount * -1;



                END IF;

                -- MB REVISAR

                    v_diference := 0;

                    v_amount_dif := 0;

                    print_log('Monto de Diferencia: '||v_amount_dif);



                print_log('Insertando Linea para worksheet:' || cla.worksheet_number);



                v_invoice_line_bc := null; 



                v_invoice_line_bc.invoiceId := v_invoice_bc.invoiceId;

                v_invoice_line_bc.lineNo := v_abbyy_line_number;

             --   v_invoice_line_bc.line_type_lookup_code := 'ITEM';



                IF cla.accrual_amount = 0 THEN 



                  v_invoice_line_bc.amount := cla.accrual_amount;



                  v_account_new := get_account ( v_ws, r_inv.vendor_id, gv_dft_account,r_inv.invoice_amount );



                 -- v_invoice_line_bc.distCodeCombination := v_company || '.' || v_account_new || '.000.000.000.000.00';



                    v_invoice_line_bc.company := v_company;

                    v_invoice_line_bc.account := v_account_new;

                    v_invoice_line_bc.department := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DEPARTMENT', '000');

                    v_invoice_line_bc.product:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'PRODUCT', '000');

                    v_invoice_line_bc.division:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DIVISION', '000');                    

                    v_invoice_line_bc.destination := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DESTINATION', '000');

                    v_invoice_line_bc.origin := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'ORIGIN', '000');            



                    print_log('Before get_dimension_value');

                    v_invoice_line_bc.office := NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                                                                        ,p_oracle_value   => '000'

                                                                                                                                        ,p_bc_dimension   => 'OFFICE'),'000');



                    v_invoice_line_bc.office := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'OFFICE', v_invoice_line_bc.office);



                    print_log('After get_dimension_value');



                ELSE



                  IF v_diference = 0 THEN 



                    v_invoice_line_bc.amount := v_line_func_amount;



                    v_account_new := get_account ( v_ws, r_inv.vendor_id, v_account,r_inv.invoice_amount );



                    --v_invoice_line_bc.distCodeCombination := v_company || '.' || v_account_new || '.000.000.000.000.00';



                    v_invoice_line_bc.company := v_company;

                    v_invoice_line_bc.account := v_account_new;

                    v_invoice_line_bc.department := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DEPARTMENT', '000');

                    v_invoice_line_bc.product:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'PRODUCT', '000');

                    v_invoice_line_bc.division:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DIVISION', '000');                    

                    v_invoice_line_bc.destination := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DESTINATION', '000');

                    v_invoice_line_bc.origin := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'ORIGIN', '000');            



                    print_log('Before get_dimension_value');

                    v_invoice_line_bc.office := NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                                                                        ,p_oracle_value   => '000'

                                                                                                                                        ,p_bc_dimension   => 'OFFICE'),'000');



                    v_invoice_line_bc.office := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'OFFICE', v_invoice_line_bc.office);



                    print_log('After get_dimension_value');

            

                  ELSE



                    v_invoice_line_bc.amount := 0;



                    v_account_new := get_account ( v_ws, r_inv.vendor_id, gv_dft_account,r_inv.invoice_amount );



                   -- v_invoice_line_bc.distCodeCombination := v_company || '.' || v_account_new || '.000.000.000.000.00';



                    v_invoice_line_bc.company := v_company;

                    v_invoice_line_bc.account := v_account_new;

                    v_invoice_line_bc.department := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DEPARTMENT', '000');

                    v_invoice_line_bc.product:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'PRODUCT', '000');

                    v_invoice_line_bc.division:= ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DIVISION', '000');                    

                    v_invoice_line_bc.destination := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'DESTINATION', '000');

                    v_invoice_line_bc.origin := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'ORIGIN', '000');            



                    print_log('Before get_dimension_value');

                    v_invoice_line_bc.office := NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                                                                        ,p_oracle_value   => '000'

                                                                                                                                        ,p_bc_dimension   => 'OFFICE'),'000');



                    v_invoice_line_bc.office := ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,v_invoice_line_bc.account,'OFFICE', v_invoice_line_bc.office);



                    print_log('After get_dimension_value');

            

                  END IF;



                END IF;



                print_log ('Monto: ' || v_invoice_line_bc.amount);

                print_log ('Cuenta: ' || v_invoice_line_bc.distCodeCombination);



                v_invoice_line_bc.description := v_invoice_bc.description;

                v_invoice_line_bc.accountDescription :=  v_invoice_bc.description;                      

                v_invoice_line_bc.worksheetNo := cla.worksheet_number;

                v_invoice_line_bc.organisationId := v_invoice_bc.organisationId;



                 insert_inv_line_bc (v_company_id,v_invoice_line_bc,v_status,v_error_message);

                 

                IF v_status = 'E' THEN

                    p_error_message := 'Error al insertar registro de linea en stage de BC: '||v_error_message;

                    RAISE e_inv_exception;

                END IF;



                  -- Inicio Agregado SBanchieri 11052021

                  -- Se actualiza la linea procesada con el request_id

                  UPDATE ajc_bc_ABBYY_INV_LINES_INT

                     SET request_id = gv_request_id

                   WHERE rowid = cla.row_id;

                  -- Fin Agregado SBanchieri 11052021



              END IF;



              -- Inicio Agregado SBanchieri 20210615

              EXCEPTION

                WHEN e_inv_exception THEN

                  print_log ( p_error_message );

                  v_error_line_abbyy := 'Y';



              END;

              -- Fin Agregado SBanchieri 20210615



            END LOOP;



            -- Inicio Agregado SBanchieri 20210615

            IF ( v_error_line_abbyy = 'N' ) THEN

            -- Fin Agregado SBanchieri 20210615



        -- Inserto Cabecera

            BEGIN       

               insert_inv_header_bc (v_company_id,v_invoice_bc,v_status,v_error_message);



               IF v_status = 'E' THEN

                    p_error_message := 'Error al insertar registro de cabecera en stage de BC: '||v_error_message;

                    RAISE e_inv_exception;

               END IF;

            END;

                

            UPDATE ajc_bc_abbyy_invoices_int

               SET status_code = 'SENT'

                   -- Inicio Agregado SBanchieri 20210629

                  ,error_message = p_error_message

                   -- Fin Agregado SBanchieri 20210629

                  ,request_id = gv_request_id

                  ,invoice_id = v_invoice_bc.invoiceId

                  ,last_update_date = sysdate

                  ,last_updated_by = gv_user_id

                  ,last_update_login = -1

             WHERE rowid = r_inv.row_id;



            COMMIT;



            -- Inicio Agregado SBanchieri 20210615

            ELSE



              UPDATE ajc_bc_abbyy_invoices_int

                 SET status_code = 'ERROR'

                    ,error_message = p_error_message

                    ,request_id = gv_request_id

                    ,invoice_id = v_invoice_bc.invoiceId

                    ,last_update_date = sysdate

                    ,last_updated_by = gv_user_id

                    ,last_update_login = -1

               WHERE rowid = r_inv.row_id;



            END IF;

            -- Fin Agregado SBanchieri 20210615



          END IF;



        EXCEPTION

          WHEN e_inv_exception THEN 



            print_log (p_error_message);



            ROLLBACK;



            UPDATE ajc_bc_abbyy_invoices_int

               SET status_code = 'ERROR'

                  ,error_message = p_error_message

                  ,request_id = gv_request_id

                  ,last_update_date = sysdate

                  ,last_updated_by = gv_user_id

                  ,last_update_login = -1

             WHERE rowid = r_inv.row_id;



            p_status := 'W';



            COMMIT;



          WHEN OTHERS THEN 

            p_error_message := 'Error OTHERS processing invoice ' || r_inv.invoice_num || '. Error: ' || SQLERRM;

            print_log (p_error_message);



            ROLLBACK; 



            UPDATE ajc_bc_abbyy_invoices_int

               SET status_code = 'ERROR'

                  ,error_message = p_error_message

                  ,request_id = gv_request_id

                  ,last_update_date = sysdate

                  ,last_updated_by = gv_user_id

                  ,last_update_login = -1

             WHERE rowid = r_inv.row_id;



            COMMIT;



            p_status := 'W';



        END;



      END IF;

      -- Fin Agregado SBanchieri 26042021



    END LOOP;



    IF p_status IS NULL THEN 

      p_status := 'S';

      print_log ('AJCL_BC_ABBYY_INTERFACE_PK.PROCESS_INVOICES (-)');

    ELSE

      print_log ('AJCL_BC_ABBYY_INTERFACE_PK.PROCESS_INVOICES (!)');

    END IF;



EXCEPTION

 WHEN e_cust_Exception THEN 

    p_status := 'W';

    print_log (p_error_message);

    print_log ('AJCL_BC_ABBYY_INTERFACE_PK.PROCESS_INVOICES (!)');

 WHEN OTHERS THEN

    p_status := 'W';

    p_error_message := 'Error OTHERS en AJCL_BC_ABBYY_INTERFACE_PK.PROCESS_INVOICES. Error: '||SQLERRM;

    print_log (p_error_message);

    print_log ('AJCL_BC_ABBYY_INTERFACE_PK.PROCESS_INVOICES (!)');

END process_invoices;



PROCEDURE delete_interfaces(p_status         OUT VARCHAR2

                           ,p_error_message  OUT VARCHAR2) IS



v_qty NUMBER;



BEGIN



    print_log ('AJCL_BC_ABBYY_INTERFACE_PK.DELETE_INTERFACES (+)');



    delete ap_invoice_lines_interface

    where invoice_id IN (select invoice_id from ap_invoices_interface where source = gv_source)

    -- Inicio Agregado SBanchieri 20230119

      and org_id = gv_org_id

    -- Fin Agregado SBanchieri 20230119

    ;



    v_qty := SQL%ROWCOUNT;

    print_log ('Lineas de interfaz borradas: '||v_qty);



    delete ap_invoices_interface

    where source = gv_source

    -- Inicio Agregado SBanchieri 20230119

      and org_id = gv_org_id

    -- Fin Agregado SBanchieri 20230119

    ;



    v_qty := SQL%ROWCOUNT;

    print_log ('Cabeceras de Facturas borradas de la interfaz: '||v_qty);



    p_status := 'S';

    print_log ('AJCL_BC_ABBYY_INTERFACE_PK.DELETE_INTERFACES (-)');



EXCEPTION

 WHEN OTHERS THEN 

    p_status := 'W';

    p_error_message := 'Error OTHERS in DELETE_INTERFACES. Error: '||SQLERRM;

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

 WHERE aaii.org_id = gv_org_id

   AND aaii.request_id = gv_request_id

   --and aaii.vendor_id = pv.vendor_id(+); 

   AND aaii.vendor_num = pv.segment1(+); 



BEGIN



    print_log( 'ajcl_bc_interface_pk.final_report_p (+)' );



    -- Insert Report Title

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => gv_bc_ifc || ' Report',

                                        p_request_id => gv_request_id );

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Request ID|' || gv_request_id,

                                        p_request_id => gv_request_id ); 



    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Insert Table Column Names                            

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

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

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );                                                                                      



    FOR r_trx in c_trx loop



      ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                          p_text => r_trx.vendor_name || '|' || 

                                                    r_trx.invoice_type_lookup_code || '|' || 

                                                    r_trx.invoice_num || '|' || 

                                                    r_trx.status_code || '|' || 

                                                    r_trx.error_message,

                                          p_request_id => gv_request_id );           



    END LOOP;



    p_status := 'S';



    print_log( 'ajcl_bc_abby_interface_pk.final_report_p (-)' );

    

EXCEPTION

 WHEN OTHERS THEN 

      p_status := 'E';

      print_log( 'ajcl_bc_abbyy_interface_pk.final_report_p (!). Error: ' || SQLERRM );

END;



  PROCEDURE final_report_xlsx_p ( p_status   OUT   VARCHAR2 ) IS



    c_processed   SYS_REFCURSOR;



  BEGIN



    print_log( 'ajcl_bc_abbyy_interface_pkg.final_report_xlsx_p (+)' );



    gv_directory_report := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_REPORT' );



    -- Solapa Report Information

    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc || ' Report Information',

                                                                       p_request_id => gv_request_id,

                                                                       p_bc_environment => gv_bc_environment,

                                                                       p_jenkins_build_number => gv_jenkins_build_number );

                   

    -- Solapa Processed Data

        OPEN c_processed FOR

            SELECT NVL(aaii.vendor_name,pv.vendor_name) vendor_name

              ,NVL(aaii.vendor_num,pv.segment1) vendor_num

              ,aaii.vendor_site_code

              ,aaii.invoice_type_lookup_code

              ,aaii.invoice_num

              ,aaii.status_code

              ,aaii.error_message

          FROM ajc_bc_abbyy_invoices_int aaii

              ,po_vendors pv

         WHERE aaii.org_id = gv_org_id

           AND aaii.request_id = gv_request_id

          -- and aaii.vendor_id = pv.vendor_id(+); 

           and aaii.vendor_num = pv.segment1(+); 



    -- Processed Data

    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Processed Data',

                                                        p_sheet => 2,

                                                        p_cursor => c_processed );

                          



    as_xlsx.save ( gv_directory_report, gv_report_filename || '.' || LOWER(gv_file_format) );



    p_status := 'S';



    print_log( 'ajcl_bc_abbyy_interface_pkg.final_report_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_abbyy_interface_pkg.final_report_xlsx_p (!). Error: ' || SQLERRM );



  END final_report_xlsx_p;

  

      -- Inserta los worksheets a enviar a BC en la tabla AJCL_BC_WORKSHEETS

  -- y ejecuta el procedure que los envia a BC

  PROCEDURE worksheets_to_bc_p ( p_status             IN OUT   VARCHAR2 ) IS



      CURSOR c_worksheets IS

      SELECT distinct worksheet_number

        FROM AJC_BC_ABBYY_INV_LINES_INT

        WHERE request_id = gv_request_id

        AND worksheet_number IS NOT NULL

        UNION

       SELECT distinct worksheet_number

        FROM AJC_BC_ABBYY_INVOICES_INT

        WHERE  request_id = gv_request_id

        AND worksheet_number IS NOT NULL;

        

    v_total_worksheets   NUMBER;

    e_error              EXCEPTION;



  BEGIN



    print_log( 'ajcl_bc_abbyy_interface_pkg.worksheets_to_bc_p (+)' );



    v_total_worksheets := 0;



    FOR cw IN c_worksheets LOOP



      v_total_worksheets := v_total_worksheets + ajcl_bc_worksheets_pkg.insert_p ( p_ws_ies_num => cw.worksheet_number,

                                                                                   p_bc_environment => gv_bc_environment );



    END LOOP;



    IF ( v_total_worksheets != 0 ) THEN



      ajcl_bc_worksheets_pkg.main_p ( p_bc_environment => gv_bc_environment,

                                      p_bc_company_id => gv_bc_company_id,

                                      p_bc_ifc => gv_bc_ifc,

                                      p_request_id => gv_request_id,

                                      p_log_seq => gv_log_seq,

                                      p_status => p_status );



      IF ( p_status != 'S' ) THEN



        RAISE e_error;



      END IF;



    END IF;



    p_status := 'S';

    print_log( 'ajcl_bc_abbyy_interface_pkg.worksheets_to_bc_p (-)' );



  EXCEPTION

    WHEN e_error THEN

      print_log( 'ajcl_bc_abbyy_interface_pkg.worksheets_to_bc_p (!)' );

      p_status := 'E';

    WHEN OTHERS THEN

      print_log( 'ajcl_bc_abbyy_interface_pkg.worksheets_to_bc_p (!)' );

      p_status := 'E';



  END worksheets_to_bc_p;



/*=========================================================================+

|                                                                          |

| Public Function                                                          |

|    main_p                                                         |

|                                                                          |

| Description                                                              |

|    ABBYY Invoice Import Process                                          |

|                                                                          |

| Parameters                                                               |

|    p_source                   IN     VARCHAR2  Origen de Importacion.    |

|                                                                          |

+=========================================================================*/

PROCEDURE main_p (p_bc_environment       IN VARCHAR2,

                                p_jenkins_build_number   IN   VARCHAR2) IS



v_status VARCHAR2(1);

v_error_msg VARCHAR2(2000);

e_parameter_value        EXCEPTION;

e_error        EXCEPTION;



-- 20240909

v_continue              VARCHAR2(1);

v_start                 DATE;

v_elapsed_seconds       NUMBER;

v_timeout_seconds       NUMBER := 2700; -- 45 minutos

-- 20240909    



-- 20250514

v_support_email          VARCHAR2(200);

v_not_success         NUMBER;

-- 20250514    



BEGIN



    print_log ('AJCL_BC_ABBYY_INTERFACE_PK.MAIN_PROCESS (+)');

    print_log('begin : '||current_timestamp);



    gv_jenkins_build_number := p_jenkins_build_number;

    gv_request_id := ajcl_bc_utils_pkg.get_request_id_f;

    -- Se inserta el concurrent_job

    ajcl_bc_utils_pkg.ins_jenkins_concurrent_job_p ( p_request_id => gv_request_id,

                                                     p_job_name => gv_bc_ifc,

                                                     p_jenkins_build_number => gv_jenkins_build_number,

                                                     p_argument1 => p_bc_environment,

                                                     p_argument2 => NULL, -- MB REVISAR

                                                     p_argument3 => NULL ); -- MB REVISAR

                                                     

    print_log ( 'gv_request_id: ' || gv_request_id );               

    print_log( 'gv_file_format: ' || gv_file_format );                                              

    print_log('gv_source: '||gv_source);

    print_log('gv_dft_account: '||gv_dft_account);

    print_log('gv_logistics_actual_acct: '||gv_logistics_actual_acct);

    print_log('gv_delete_flag: '||gv_delete_flag);

    

    gv_email := ajcl_bc_utils_pkg.get_emails_f ( 'ABBYY' );

    print_log( 'gv_email: ' || gv_email );



    gv_process_name := ajcl_bc_ws_utils_pkg.get_lock_process_name_f ( p_integration => 'PURCHASE INVOICES' );

    print_log( 'gv_process_name: ' || gv_process_name );

    

    -- Validacion parametro p_bc_environment -----------------------------------------------------------------------------------

    IF ( ajcl_bc_utils_pkg.is_bc_environment_valid_f ( p_bc_environment ) = 'N' ) THEN



      v_error_msg := 'Invalid value (' || p_bc_environment || ') for parameter BC_ENVIRONMENT.';

      RAISE e_parameter_value;



    END IF;



    gv_bc_environment := p_bc_environment;

    print_log ( 'gv_bc_environment: ' || gv_bc_environment );

    

    -- Se obtienen los parametros de la company 

    print_log ( 'gv_bc_company_name: ' || gv_bc_company_name );  



    gv_org_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                                                              p_column => 'ORG_ID' );  

    print_log ( 'gv_org_id: ' || gv_org_id );

    

    gv_set_of_books_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                                                                               p_column => 'SET_OF_BOOKS_ID' );

    print_log ( ' gv_set_of_books_id  : ' ||  gv_set_of_books_id   );



    gv_set_of_books_name := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                                                                                     p_column => 'SET_OF_BOOKS_NAME' );       

    print_log ( ' gv_set_of_books_name  : ' ||  gv_set_of_books_name   );



    gv_bc_company_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                                                                              p_column => 'BC_COMPANY_ID' );       

    print_log ( ' gv_bc_company_id  : ' ||  gv_bc_company_id   );



    ajcl_bc_utils_pkg.initialize_p ( p_org_id => gv_org_id );

    print_log ( 'ajcl_bc_utils_pkg.initialize_p' );    

    

    --Sincronizo default dimensions para mapeo de segmentos

    ajcl_bc_accounts_pkg.main_p ( p_bc_environment => p_bc_environment );    

    print_log ( 'ajcl_bc_accounts_pkg.main_p' );      

        

--REVISAR

  /*  delete_interfaces(p_status             => v_status

                     ,p_error_message      => v_error_msg);



    IF v_status NOT IN ('S','W') THEN

       RAISE e_cust_exception;

    END IF;          */



        -- 20240909 

        -- Se verifica si los concurrentes 'AJC BC INC Certify Interface' o 'AJC BC ABBYY Invoice Interface' (FOODS) están por correr o corriendo

        -- En tal caso, se espera hasta que terminen

        BEGIN



          v_continue := 'N';

          print_log ( 'Checks if AJC BC INC Certify Interface or AJC BC ABBYY Invoice Interface are running or are about to be executed.' );

          v_start := SYSDATE;



          WHILE ( v_continue = 'N' ) LOOP



            SELECT DECODE(COUNT(1),0,'Y','N')

              INTO v_continue

              FROM fnd_concurrent_requests r,

                   fnd_concurrent_programs_vl p

             WHERE r.concurrent_program_id = p.concurrent_program_id

               AND p.user_concurrent_program_name IN ('AJC BC INC Certify Interface','AJC BC ABBYY Invoice Interface')

               AND ( ( r.phase_code = 'R' ) or -- Running

                     ( r.phase_code = 'P' and r.status_code = 'Q' ) or -- Pending | Standby / Scheduled

                     ( r.phase_code = 'P' and r.status_code = 'R' ) ) -- Pending | Normal

               AND NVL(r.hold_flag,'N')='N' -- no tengo en cuenta los holdeados

               AND r.requested_start_date < SYSDATE + interval '20' minute; -- Si existe algun concurrente programado Once, pero faltan mas de 30 minutos, continúa

               

            IF ( v_continue = 'N' ) THEN



              print_log ( 'Another Certify or ABBYY request is running or is about to be executed in AJC. Wait 1 minute.' );

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

      

    print_log('process_invoices : '||current_timestamp);

    

    process_invoices (p_status             => v_status

                     ,p_error_message      => v_error_msg

                     -- Inicio Agregado 05032021

                     ,p_logistics_actual_acct => gv_logistics_actual_acct

                     --

                     );



    IF v_status NOT IN ('S','W') THEN

       RAISE e_error;

    END IF;



    -- ------------------------------------------------------------------------------------------------------------------------ 

    -- Envío de Worksheets a BC   

    -- ------------------------------------------------------------------------------------------------------------------------

    print_log('worksheets_to_bc_p : '||current_timestamp);    

    worksheets_to_bc_p ( p_status => v_status );

    

    IF ( v_status != 'S' ) THEN



      v_error_msg := 'Error en worksheets_to_bc_p';

      print_log('Error!');

      print_log('v_error_msg: '||v_error_msg);

      

      --20240910 se comenta el raise para que se procesen las lineas ya enviadas a la inbound. si fallan por ws inexistente, se reprocesaran en la próxima ejecución      

      --RAISE e_error; 



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

        RAISE e_error;

    END IF;



    print_log('validate_import : '||current_timestamp);        

   validate_import ( 

                     p_delete_flag => gv_delete_flag,

                     p_status => v_status,

                     p_error_message => v_error_msg);





    --IF v_status != 'S' THEN

    IF v_status NOT IN ('S','W') THEN

        RAISE e_error;

    END IF;



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );



      IF ( gv_release_status != 'success' ) THEN



        v_error_msg := 'ajc_bc_dbms_lock_pkg.release_p';

        RAISE ge_release;



      END IF;                                     

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      

      -- INSERT REPORT IN TABLE AJCL_BC_REPORTS --------------------------------------------------------------------------------

      print_log('final_report_p : '||current_timestamp);        

      final_report_p ( p_status => v_status );     



      IF ( v_status != 'S' ) THEN



        v_error_msg := 'Error en final_report_p';

        RAISE e_error;



      END IF;  



      IF ( gv_file_format = 'CSV' ) THEN

              -- CREATE CSV FROM TABLE AJCL_BC_REPORTS --------------------------------------------------------------------------------

              ajcl_bc_utils_pkg.create_csv_p ( p_ifc => gv_bc_ifc,

                                               p_request_id => gv_request_id,

                                               p_log_seq => gv_log_seq,

                                               p_type => 'REPORT',

                                               p_filename => gv_report_filename,

                                               p_status => v_status );



              IF ( v_status != 'S' ) THEN



                v_error_msg := 'Error en create_csv_p | REPORT';

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

          ajcl_bc_utils_pkg.send_mail_with_attach ( p_to_mail => gv_email,

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

           

          v_support_email := ajcl_bc_utils_pkg.get_emails_f ( 'SUPPORT' );

             

          SELECT COUNT(1)

               INTO v_not_success

             FROM AJC_BC_ABBYY_INVOICES_INT a

                WHERE 1 = 1 

                AND a.request_id = gv_request_id

                AND a.org_id = gv_org_id 

                AND a.creation_date >= TO_DATE('26/09/2024','DD/MM/YYYY')

                AND a.STATUS_CODE IN ('ERROR','REJECTED');

             

          print_log ('v_not_success: ' || v_not_success);  

                 

          IF ( v_not_success > 0 ) THEN

             

            ajcl_bc_utils_pkg.send_email_p ( p_to => v_support_email,

                                                                  p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - WARNING - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                                                  p_message => 'Some journals could not be imported. Please review the integration report.' || CHR(10) || 'Request ID: ' || gv_request_id );

          

          END IF;

           

        EXCEPTION

            WHEN OTHERS THEN

               NULL;

               

        END;

         -- 20250514



    -- Se actualiza el concurrent_job

    ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'S' );    

      

    print_log ('  v_status => ' || v_status);

    print_log('end : '||current_timestamp);        

    print_log ('ajcl_bc_abbyy_interface_pk.main_p (-)');



EXCEPTION 

      -- dbms_lock ---------------------------------------------------------------------------------------------------------------

    WHEN ge_lock THEN -- Lock and Release

      print_log ('ajcl_bc_abbyy_interface_pk.main_p (!). Error al intentar hacer el lock del proceso ' || gv_process_name || 

              ' | request_status: ' || gv_request_status);

              

      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject =>  gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',   

                                       p_message => v_error_msg|| CHR(10) ||'Request Id: '||gv_request_id );



      ajcl_bc_utils_pkg.send_log_by_mail_p(gv_request_id,gv_email);

      

      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );                                       



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );    

      

    WHEN ge_release THEN -- Lock and Release

      print_log ('ajcl_bc_abbyy_interface_pk.main_p (!). Error al intentar hacer el release del proceso ' || gv_process_name || 

              ' | request_status: ' || gv_release_status);

              

      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject =>  gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',   

                                       p_message => v_error_msg|| CHR(10) ||'Request Id: '||gv_request_id );



      ajcl_bc_utils_pkg.send_log_by_mail_p(gv_request_id,gv_email);

      

      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );                                       



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );    

                    

    -- dbms_lock ---------------------------------------------------------------------------------------------------------------

    WHEN e_parameter_value THEN

      print_log('ajcl_bc_abby_interface_pk.main_p (!)');

      print_log('Parameter Value Error!');

      print_log('v_error_msg: '||v_error_msg);

      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => v_error_msg || CHR(10) ||'Request Id: '||gv_request_id);



      ajcl_bc_utils_pkg.send_log_by_mail_p(gv_request_id,gv_email);

      

      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );                   



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------                                         



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );         

WHEN e_error THEN

      print_log('ajcl_bc_abbyy_interface_pk.main_p (!)');

      print_log('Error!');

      print_log('v_error_msg: '||v_error_msg);

      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')', 

                                       p_message => v_error_msg || CHR(10) ||'Request Id: '||gv_request_id );

 

      ajcl_bc_utils_pkg.send_log_by_mail_p(gv_request_id,gv_email);

                                                  

          -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );               



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------                                             



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );         

  WHEN others THEN

      print_log('ajcl_bc_abbyy_interface_pk.main_p (!)');

      print_log('Error others!');

      print_log('v_error_msg: '||v_error_msg);

      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')', 

                                       p_message => v_error_msg|| CHR(10) ||'Request Id: '||gv_request_id );



      ajcl_bc_utils_pkg.send_log_by_mail_p(gv_request_id,gv_email);

      

          -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );                  



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------                                          



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );         

END;



-- Inicio Agregado SBanchieri 20210812 --MB REVISAR

PROCEDURE delete_error_records ( retcode   OUT NUMBER

                                ,errbuf    OUT VARCHAR2

                                ,p_draft   IN  VARCHAR2 ) IS



  CURSOR c_invoices IS

  SELECT NVL(aaii.vendor_name,pv.vendor_name) vendorn

        ,( SELECT COUNT(1)

             FROM ajc_bc_ABBYY_INV_LINES_INT aaili

            WHERE aaii.org_id = aaili.org_id

              AND aaii.status_code = 'ERROR'

              AND aaii.invoice_num = aaili.invoice_num

              AND aaii.vendor_id = aaili.vendor_id

              AND aaii.vendor_site_code = aaili.vendor_site_code

              AND aaii.invoice_type_lookup_code = aaili.invoice_type_lookup_code ) lines_count

        ,aaii.*

    FROM ajc_bc_ABBYY_INVOICES_INT aaii,

         po_vendors pv

   WHERE aaii.org_id = gv_org_id

     AND aaii.status_code = 'ERROR'

    -- AND aaii.vendor_id = pv.vendor_id;

    AND aaii.vendor_num = pv.segment1;



  CURSOR c_inv_lines IS

  SELECT *

    FROM ajc_bc_ABBYY_INV_LINES_INT a

   WHERE org_id = gv_org_id

     AND EXISTS ( SELECT invoice_num

                    FROM ajc_bc_ABBYY_INVOICES_INT b

                   WHERE a.org_id = b.org_id

                     AND b.status_code = 'ERROR'

                     AND a.invoice_num = b.invoice_num

                     AND a.vendor_id = b.vendor_id

                     AND a.vendor_site_code = b.vendor_site_code

                     AND a.invoice_type_lookup_code = b.invoice_type_lookup_code );



  v_invoices_count   NUMBER := 0;   



BEGIN



  print_output(RPAD('Proveedor',30,' ')||'  '||RPAD('Tipo Comprobante',16,' ')||'  '||RPAD('Nro Comprobante',20,' ')||'  '||RPAD('Estado',7,' ')||'  '||RPAD('Cant. Líneas',12,' ')||'  '||'Observaciones');

  print_output(RPAD('-',30,'-')||'  '||RPAD('-',16,'-')||'  '||RPAD('-',20,'-')||'  '||RPAD('-',7,'-')||'  '||RPAD('-',12,'-')||'  '||'--------------------------------------------------------------------------------------------------------------------');

  print_output('');                                                                                           



  FOR ci in c_invoices loop



    print_output (RPAD(ci.vendorn,30,' ')||'  '||RPAD(ci.invoice_type_lookup_code,16,' ')||'  '||RPAD(ci.invoice_num,20,' ')||'  '||RPAD(ci.status_code,7,' ')||'  '||RPAD(ci.lines_count,12,' ')||'  '||ci.error_message); 

    v_invoices_count := v_invoices_count + 1;



    IF ( p_draft = 'N' ) THEN



      -- Se recorren las cabeceras y se copian a la tabla _e

      INSERT 

        INTO AJC_AP_ABBYY_INVOICES_INT_E ( --REVISAR

             ORG_ID,

             VENDOR_ID,

             VENDOR_SITE_CODE,

             ADDRESS_LINE1,

             ADDRESS_LINE2,

             ADDRESS_LINE3,

             CITY,

             STATE,

             ZIP,

             PROVINCE,

             COUNTRY,

             INVOICE_NUM,

             INVOICE_DATE,

             INVOICE_TYPE_LOOKUP_CODE,

             INVOICE_AMOUNT,

             INVOICE_CURRENCY_CODE,

             DESCRIPTION,

             WORKSHEET_NUMBER,

             STATUS_CODE,

             ERROR_MESSAGE,

             CREATED_BY,

             CREATION_DATE,

             LAST_UPDATED_BY,

             LAST_UPDATE_DATE,

             LAST_UPDATE_LOGIN,

             REQUEST_ID,

             ABBYY_USER_NAME,

             FILE_PATH,

             INVOICE_ID,

             VENDOR_NAME,

             VENDOR_NUM )

    VALUES ( ci.ORG_ID,

             ci.VENDOR_ID,

             ci.VENDOR_SITE_CODE,

             ci.ADDRESS_LINE1,

             ci.ADDRESS_LINE2,

             ci.ADDRESS_LINE3,

             ci.CITY,

             ci.STATE,

             ci.ZIP,

             ci.PROVINCE,

             ci.COUNTRY,

             ci.INVOICE_NUM,

             ci.INVOICE_DATE,

             ci.INVOICE_TYPE_LOOKUP_CODE,

             ci.INVOICE_AMOUNT,

             ci.INVOICE_CURRENCY_CODE,

             ci.DESCRIPTION,

             ci.WORKSHEET_NUMBER,

             ci.STATUS_CODE,

             ci.ERROR_MESSAGE,

             ci.CREATED_BY,

             ci.CREATION_DATE,

             ci.LAST_UPDATED_BY,

             ci.LAST_UPDATE_DATE,

             ci.LAST_UPDATE_LOGIN,

             ci.REQUEST_ID,

             ci.ABBYY_USER_NAME,

             ci.FILE_PATH,

             ci.INVOICE_ID,

             ci.VENDOR_NAME,

             ci.VENDOR_NUM );



    END IF;



  END LOOP;



  print_output(' ');



  IF ( v_invoices_count != 0 ) THEN



    IF ( p_draft = 'Y' ) THEN



      print_output('Se borrará/n ' || v_invoices_count || ' factura/s con error.');



    ELSE



      -- Se recorren las lineas y se copian a la tabla _e

      FOR cil IN c_inv_lines LOOP



        INSERT

          INTO AJC_AP_ABBYY_INV_LINES_INT_E ( --REVISAR

               ORG_ID,

               VENDOR_ID,

               VENDOR_SITE_CODE,

               INVOICE_TYPE_LOOKUP_CODE,

               INVOICE_NUM,

               WORKSHEET_NUMBER,

               ACCRUAL_FUNC_AMOUNT,

               ACCRUAL_AMOUNT,

               REQUEST_ID,

               CREATION_DATE,

               CREATED_BY,

               LAST_UPDATE_DATE,

               LAST_UPDATED_BY,

               LINE_AMOUNT,

               SOURCE_TYPE,

               LINE_NUMBER )

      VALUES ( cil.ORG_ID,

               cil.VENDOR_ID,

               cil.VENDOR_SITE_CODE,

               cil.INVOICE_TYPE_LOOKUP_CODE,

               cil.INVOICE_NUM,

               cil.WORKSHEET_NUMBER,

               cil.ACCRUAL_FUNC_AMOUNT,

               cil.ACCRUAL_AMOUNT,

               cil.REQUEST_ID,

               cil.CREATION_DATE,

               cil.CREATED_BY,

               cil.LAST_UPDATE_DATE,

               cil.LAST_UPDATED_BY,

               cil.LINE_AMOUNT,

               cil.SOURCE_TYPE,

               cil.LINE_NUMBER );



      END LOOP;



      DELETE ajc_bc_ABBYY_INV_LINES_INT a

       WHERE org_id = gv_org_id

         AND EXISTS ( SELECT invoice_num

                        FROM ajc_bc_ABBYY_INVOICES_INT b

                       WHERE a.org_id = b.org_id

                         AND b.status_code = 'ERROR'

                         AND a.invoice_num = b.invoice_num

                         AND a.vendor_id = b.vendor_id

                         AND a.vendor_site_code = b.vendor_site_code

                         AND a.invoice_type_lookup_code = b.invoice_type_lookup_code );



      print_log('Líneas borradas: ' || SQL%ROWCOUNT );



      DELETE ajc_bc_ABBYY_INVOICES_INT

       WHERE org_id = gv_org_id

         AND status_code = 'ERROR';



      print_log('Facturas borradas: ' || SQL%ROWCOUNT );



      IF ( v_invoices_count = 1 ) THEN



        print_output('Se borró ' || v_invoices_count || ' factura con error.');



      ELSE



        print_output('Se borraron ' || v_invoices_count || ' facturas con error.');



      END IF;



      COMMIT;



    END IF;



  ELSE



    print_output('No existen facturas con error.');



  END IF;



END delete_error_records;

-- Fin Agregado SBanchieri 20210812



END AJCL_BC_ABBYY_INTERFACE_PK;
