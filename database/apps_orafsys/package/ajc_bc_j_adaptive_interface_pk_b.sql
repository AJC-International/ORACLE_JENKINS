PACKAGE BODY              AJC_BC_J_ADAPTIVE_INTERFACE_PK IS
/* --------------------------------------------------------------------------------------------|
| Historial                                                                                    |
|   Date      Version Modified   Detail                                                        |
|   --------- ------- ---------- --------------------------------------------------------------|
|   17-JUN-20       1 SBANCHIERI Creation                                                      |
|   03-OCT-22       1.1 MBETTI Update                                                           |
|   18-DEC-25       1.2 MBETTI Jenkins Migration                                            |
|---------------------------------------------------------------------------------------------*/

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

  -- 20260113 REINTENTO
  gv_retry_in_seconds   NUMBER;
  gv_retry              VARCHAR2(1);
  -- 20260113 REINTENTO

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    dbms_output.put_line( p_message);
    gv_log_seq := gv_log_seq + 1;
    ajc_bc_j_utils_pkg.insert_log_p ( gv_bc_ifc, substr(p_message,1,2000), gv_request_id, gv_log_seq );

  END print_log;

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

  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    ajc_bc_j_utils_pkg.insert_output_p ( gv_bc_ifc, p_message, gv_request_id );

  END print_output;

/*=========================================================================+
|                                                                          |
| Private Function                                                         |
|    get_attach_url                                                        |
|                                                                          |
| Description                                                              |
|    Recover URL from AP Standard Attachs                                  |
|                                                                          |
|                                                                          |
| Parameters                                                               |
|    p_invoice_id                   IN     NUMBER                          |
|                                                                          |
+=========================================================================*/

  PROCEDURE get_attach_url ( p_entity_name    IN      VARCHAR2
                            ,p_trx_hdr_id     IN      NUMBER
                            ,p_attachment_1   IN OUT  VARCHAR2
                            ,p_attachment_2   IN OUT  VARCHAR2
                            ,p_attachment_3   IN OUT  VARCHAR2
                            ,p_attachment_4   IN OUT  VARCHAR2
                            ,p_attachment_5   IN OUT  VARCHAR2 ) IS

      CURSOR c_attachments IS 
      SELECT file_name,
             datatype,
             media_id
        FROM ( SELECT fdt.file_name
                     ,fdd.user_name datatype
                     ,fdt.media_id
                 FROM fnd_attached_documents fad
                     ,fnd_documents_tl fdt
                     ,fnd_documents fd
                     ,fnd_document_datatypes fdd
                WHERE fad.entity_name = p_entity_name
                  AND fad.document_id = fdt.document_id
                  AND DECODE(p_entity_name,'GL_JE_HEADERS',fad.pk2_value,fad.pk1_value) = TO_CHAR(p_trx_hdr_id)
                  AND fdt.document_id = fd.document_id
                  AND fd.datatype_id = fdd.datatype_id
             ORDER BY fdt.document_id,
                      fdt.media_id )
       WHERE ROWNUM < 6;

    v_url        VARCHAR2(2000);
    v_count      NUMBER;

  BEGIN

    v_count := 0;

    FOR ca IN c_attachments LOOP

      v_count := v_count + 1;

      v_url := ca.file_name;

      IF ( ca.datatype = 'File' ) THEN

        SELECT fnd_gfm.construct_download_URL ( fnd_web_config.gfm_agent, ca.media_id ) 
          INTO v_url
          FROM dual;

        -- Se actualiza el timestamp de la tabla donde se guardan los accesos a las url,
        -- para que este disponible hasta la fecha seteada en el update
        UPDATE fnd_lob_access
           SET timestamp = TO_DATE('20501231','yyyymmdd')
         WHERE file_id = ca.media_id
           AND timestamp > SYSDATE;

        COMMIT;

      END IF;

      IF ( v_count = 1 ) THEN

        p_attachment_1 := v_url;

      ELSIF ( v_count = 2 ) THEN

        p_attachment_2 := v_url;

      ELSIF ( v_count = 3 ) THEN

        p_attachment_3 := v_url;

      ELSIF ( v_count = 4 ) THEN

        p_attachment_4 := v_url;

      ELSIF ( v_count = 5 ) THEN

        p_attachment_5 := v_url;

      END IF; 

    END LOOP;

  END get_attach_url;

  -- 20260113
  PROCEDURE del_account_bal_p IS

      CURSOR c_current_account_bal IS
      SELECT company_description,
             period_end_date
        FROM ajc_gl_adaptive_account_bal 
       WHERE request_id = gv_request_id
    GROUP BY company_description,
             period_end_date;

  BEGIN

    print_log('AJC_BC_J_ADAPTIVE_INTERFACE_PK.del_account_bal_p (+)');

    FOR ccab IN c_current_account_bal LOOP

      -- Old account bal for same company_description and period_end_date, different request_id
      DELETE ajc_gl_adaptive_account_bal
       WHERE request_id != gv_request_id
         AND company_description = ccab.company_description
         AND period_end_date = ccab.period_end_date;

      print_log ('Company Description: ' || ccab.company_description || ' | Period End Date:' || ccab.period_end_date || ' | Registros borrados: ' || SQL%ROWCOUNT);

    END LOOP;

    COMMIT;

    print_log('AJC_BC_J_ADAPTIVE_INTERFACE_PK.del_account_bal_p (-)');

  EXCEPTION
    WHEN OTHERS THEN
      print_log('AJC_BC_J_ADAPTIVE_INTERFACE_PK.del_account_bal_p (!). Error: ' || SQLERRM);

  END del_account_bal_p;
  -- 20260113

/*=========================================================================+
|                                                                          |
| Private Function                                                         |
|    process_journals                                                      |
|                                                                          |
| Description                                                              |
|    Procesa la informacion necesaria para la tabla de journals            |
|                                                                          |
| Parameters                                                               |
|    p_status                  OUT     NUMBER    Codigo Estado.            |
|    p_error_message           OUT     VARCHAR2  Mensaje de Error.         |
|                                                                          |
+=========================================================================*/
PROCEDURE process_journals ( p_company_id IN VARCHAR2
                            ,p_status_code   OUT VARCHAR2
                            ,p_error_message OUT VARCHAR2 ) IS

  -- ---------------------------------------------------------------------------
  -- Declaracion de Variables
  -- ---------------------------------------------------------------------------
 v_url VARCHAR2(500);
v_api_st VARCHAR2(100):= 'adaptiveGLEntryINE';
v_clob_int   CLOB;
v_status    VARCHAR2(1);
v_error_message VARCHAR2(1000);
e_cust_exception EXCEPTION;
e_max_exception EXCEPTION;
v_cant_ins                              NUMBER:=-1;
v_url_post                                 VARCHAR2(2000);
v_api_post                                 VARCHAR2(100) := 'UpdateOutboundEntries_UpdateOutboundGLEntryINE';
v_body_post                              VARCHAR2(2000);
v_clob_result_post                     CLOB;
v_status_post                           VARCHAR2(1);
v_min_entry NUMBER;
v_max_entry NUMBER;
v_journal_name_ant varchar2(100);
v_je_header_id NUMBER;
v_record_count NUMBER;
v_cant_call NUMBER;

BEGIN

    print_log('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_journals (+)');
    print_log('Comienzo insert'||' - '||to_char(sysdate,'hh24:mi:ss'));
    print_log('p_company_id: '||p_company_id);
    print_log('gv_request_id: '||gv_request_id);
    print_log('gv_user_id: '||gv_user_id);

     v_url := ajc_bc_j_ws_utils_pkg.get_base_inecta_url_f ( gv_bc_environment, p_company_id ) || v_api_st;--||'?$filter=periodEndDate eq '|| '2023-02-25' ;
     print_log('v_url: '||v_url);

    v_cant_call:=0;
   v_record_count:=-1;

 WHILE v_record_count<>0  LOOP 
    begin
        BEGIN

         -- 20260113 REINTENTO
         gv_retry := 'N';

         BEGIN
         -- 20260113 REINTENTO

           v_clob_int := ajc_bc_j_ws_utils_pkg.get_bc_clob_result_f ( v_url) ;

           -- 20260113 REINTENTO
           IF ( UPPER(v_clob_int) LIKE UPPER('%502 Bad Gateway%') ) THEN

             print_log('502 Bad Gateway'); 
             gv_retry := 'Y';

           END IF;

         EXCEPTION
           WHEN OTHERS THEN
             print_log('Error calling ajcl_bc_ws_utils_pkg.patch_post_bc_row_f: ' || SQLCODE || '|' || SQLERRM ); 
             gv_retry := 'Y';

         END;

         IF ( gv_retry = 'Y' ) THEN

           print_log( 'Connection error detected. Retrying in ' || gv_retry_in_seconds || ' seconds.' );
           DBMS_LOCK.sleep(gv_retry_in_seconds);

           v_clob_int := ajc_bc_j_ws_utils_pkg.get_bc_clob_result_f ( v_url) ;

         END IF;
         -- 20260113 REINTENTO

         insert into   ajc_gl_adaptive_journals          
             ( je_header_id,
               je_batch_id,
               user_je_source_name,
               user_je_category_name,
               set_of_books_name,
               company,
               account,
               dept,
               product, 
               dest,
               origin,
               intercompany,
               code_combination_id,
               set_of_books_id,
               period_name,
               period_year,
               period_num,
               period_end_date,
               batch_name,
               journal_name,
               currency_code,
               je_line_num,
               entered_dr,
               entered_cr,
               accounted_dr,
               accounted_cr,
               description,
               worksheet_number,
               error_message,
               created_by,
               creation_date,
               last_updated_by,
               last_update_date,
               last_update_login,
               request_id,
               parent_request_id,
               attachment_1, 
               attachment_2,
               attachment_3,
               attachment_4,
               attachment_5,
               office,
               dest_bc,
               product_bc,
               division_bc)          
        SELECT 
                companySegment,--gLJournalEntryHeaderId, changed to make unique key. entryNo can be duplicated accross companies
                gLJournalEntryHeaderId,
                journalEntrySourceName,
                journalEntryCategoryName,
                setofBooksName,
                companySegment,
                substr(accountSegment,6,4),
                nvl(deptSegment,'000'),
                nvl(productSegment,'000'),
                '000',--nvl(destSegment,'000'), MB - Para BC se usará dest_bc, dest queda con los valores originales de Oracle
                nvl(originSegment,'000'),
                NVL(intercompanySegment,'00'),
                -1 code_combination_id, --code_combination_id
                -1 set_of_books_id, --set_of_books_id
                gLPeriodName, --El formato es incorrecto RAINE
                periodYear,
                periodNum,
                to_date(periodEndDate,'yyyy-mm-dd'),
                journalEntryBatchId,
                gLJournalEntryHeaderId, --journal_name
                currencyCode,
                entryNo, --je_line_num
                replace(origCurrencyDebit,',',''),-- replace(replace(origCurrencyDebit,',',''),'.',','),
                replace(origCurrencyCredit,',',''),--replace(replace(origCurrencyCredit,',',''),'.',','),
                replace(functionalCurrencyDebit,',',''),--replace(replace(functionalCurrencyDebit,',',''),'.',','),
                replace(functionalCurrencyCredit,',',''),--replace(replace(functionalCurrencyCredit,',',''),'.',','),
                description,
                worksheetNumber,
                NULL "error_message", --error_message
                gv_user_id,
                sysdate,
                gv_user_id,
                sysdate,
                gv_login_id,
                gv_request_id,
                -1, --marca para identificar no procesados en BC : parent_request_id
                attachment1,
                attachment2,
                attachment3,
                attachment4,
                attachment5,
                office,
                nvl(destSegment,'000'),
                nvl(productSegment,'000'),
                NVL(intercompanySegment,'000')                
        FROM json_table( v_clob_int,
                         '$.value[*]' COLUMNS ( 
                                                                entryNo VARCHAR2(4000)  path '$.entryNo',
                                                                gLJournalEntryHeaderId VARCHAR2(4000)  path '$.gLJournalEntryHeaderId',
                                                                journalEntrySourceName VARCHAR2(4000)  path '$.journalEntrySourceName',
                                                                journalEntryCategoryName VARCHAR2(4000)  path '$.journalEntryCategoryName',
                                                                setofBooksName VARCHAR2(4000)  path '$.setofBooksName',
                                                                companySegment VARCHAR2(4000)  path '$.companySegment',
                                                                accountSegment VARCHAR2(4000)  path '$.accountSegment',
                                                                deptSegment VARCHAR2(4000)  path '$.deptSegment',
                                                                productSegment VARCHAR2(4000)  path '$.productSegment',
                                                                destSegment VARCHAR2(4000)  path '$.destSegment',
                                                                originSegment VARCHAR2(4000)  path '$.originSegment',
                                                                intercompanySegment VARCHAR2(4000)  path '$.intercompanySegment',
                                                                gLPeriodName VARCHAR2(4000)  path '$.gLPeriodName',
                                                                periodYear VARCHAR2(4000)  path '$.periodYear',
                                                                periodNum VARCHAR2(4000)  path '$.periodNum',
                                                                periodEndDate VARCHAR2(4000)  path '$.periodEndDate',
                                                                journalEntryBatchId VARCHAR2(4000)  path '$.journalEntryBatchId',
                                                                currencyCode VARCHAR2(4000)  path '$.currencyCode',
                                                                origCurrencyDebit VARCHAR2(4000)  path '$.origCurrencyDebit',
                                                                origCurrencyCredit VARCHAR2(4000)  path '$.origCurrencyCredit',
                                                                functionalCurrencyDebit VARCHAR2(4000)  path '$.functionalCurrencyDebit',
                                                                functionalCurrencyCredit VARCHAR2(4000)  path '$.functionalCurrencyCredit',
                                                                description VARCHAR2(4000)  path '$.description',
                                                                worksheetNumber VARCHAR2(4000)  path '$.worksheetNumber',
                                                                processedinOracle VARCHAR2(4000)  path '$.processedinOracle',
                                                                attachment1 VARCHAR2(4000)  path '$.attachment1', 
                                                                attachment2 VARCHAR2(4000)  path '$.attachment2',
                                                                attachment3 VARCHAR2(4000)  path '$.attachment3',
                                                                attachment4 VARCHAR2(4000)  path '$.attachment4',
                                                                attachment5 VARCHAR2(4000)  path '$.attachment5',
                                                                office VARCHAR2(4000)  path '$.office'));

             v_record_count:=sql%rowcount;

            print_log('v_count: '||v_record_count);
            print_log('Luego del call get e insert: '||to_char(sysdate,'hh24:mi:ss'));

            v_cant_call:=v_cant_call + 1;
            print_log('v_cant_call: '||v_cant_call);

            COMMIT;

      EXCEPTION
      WHEN OTHERS THEN

        p_status_code:='E';
        p_error_message:=('Error al insertar journals: '||SQLERRM);
        print_log(p_error_message);
         raise e_cust_exception;
      END;
      -- POST
      IF v_record_count<>0 THEN -- si el get pudo insertar algun registro
          BEGIN
            print_log('Comienzo post'||' - '||to_char(sysdate,'hh24:mi:ss'));

             v_url_post := ajc_bc_j_ws_utils_pkg.get_base_standard_url_f ( gv_bc_environment,  v_api_post, p_company_id );

            print_log('v_url_post: '||v_url_post);

             BEGIN

                select min(je_line_num),max(je_line_num)
                into v_min_entry,v_max_entry
                from ajc_gl_adaptive_journals
                where parent_request_id = -1; --no posteados
                -- last_update_login=-1; --no posteados
                --request_id=gv_request_id;

             END;

            IF v_min_entry IS NOT NULL and v_max_entry IS NOT NULL THEN
                BEGIN

                      v_body_post:= '{"entryNo":"'||v_min_entry||'..'||v_max_entry||'","processedinOracle":true}';
                      print_log('v_body_post: '||v_body_post);
                      print_log('before post'||' - '||to_char(sysdate,'hh24:mi:ss'));

                      -- 20260113 REINTENTO
                      gv_retry := 'N';

                      BEGIN
                      -- 20260113 REINTENTO

                        v_clob_result_post := ajc_bc_j_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url_post,
                                                                                          p_request_header_name1 => 'Content-Type',
                                                                                          p_request_header_value1 => 'application/json',
                                                                                          p_request_header_name2 => NULL,
                                                                                          p_request_header_value2 => NULL, 
                                                                                          p_http_method => 'POST',
                                                                                          p_body => v_body_post );  
                        -- 20260113 REINTENTO
                        IF ( UPPER(v_clob_result_post) LIKE UPPER('%502 Bad Gateway%') ) THEN

                          print_log('502 Bad Gateway'); 
                          gv_retry := 'Y';

                        END IF;

                      EXCEPTION
                        WHEN OTHERS THEN
                          print_log('Error calling ajcl_bc_ws_utils_pkg.patch_post_bc_row_f: ' || SQLCODE || '|' || SQLERRM ); 
                          gv_retry := 'Y';

                      END;

                      IF ( gv_retry = 'Y' ) THEN

                        print_log( 'Connection error detected. Retrying in ' || gv_retry_in_seconds || ' seconds.' );
                        DBMS_LOCK.sleep(gv_retry_in_seconds);

                        v_clob_result_post := ajc_bc_j_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url_post,
                                                                                          p_request_header_name1 => 'Content-Type',
                                                                                          p_request_header_value1 => 'application/json',
                                                                                          p_request_header_name2 => NULL,
                                                                                          p_request_header_value2 => NULL, 
                                                                                          p_http_method => 'POST',
                                                                                          p_body => v_body_post );  

                      END IF;
                      -- 20260113 REINTENTO

                      print_log('after post'||' - '||to_char(sysdate,'hh24:mi:ss'));

                    IF ( INSTR(v_clob_result_post,'error') != 0 )  THEN
                                            print_log('Error al hacer el post de processedInOracle');
                                            print_log(v_clob_result_post);
                                            raise e_cust_exception;
                    ELSE -- post ok
                            --marco los posteados, independientemente del request_id actual, quizas falló el posteo en un proceso anterior
                            update ajc_gl_adaptive_journals
                            set parent_request_id=request_id--request_id=gv_request_id
                            where parent_request_id=-1;
                            --last_update_login=-1 ;
                            --and je_line_num between v_min_entry and v_max_entry;

                            print_log('Update post ok');
                            print_log('after update'||' - '||to_char(sysdate,'hh24:mi:ss'));    
                     END IF;     

                    COMMIT;
                    print_log('commit post');
                 exception
                    when others then
                     print_log('Error al postear el processedInOracle '||SQLERRM);
                     raise e_cust_exception;
                END;
            END IF;
              print_log('Luego del post processedInOracle: '||to_char(sysdate,'hh24:mi:ss'));
        EXCEPTION
        when others then
            p_error_message:=p_error_message||('Error post: '||SQLERRM);         
            p_status_code:='E';
            print_log(p_error_message);
            raise e_cust_exception;
        END;
     END IF; -- end if record count post   

        IF v_cant_call >= 30 THEN
            v_error_message:='Se corta el loop de insert de JOURNALS porque se llamó mas de 30 veces';
            raise e_max_exception;
        END IF;

    exception
    when others then
        p_error_message:=p_error_message||v_error_message;
        p_status_code:='E';
        print_log(p_error_message);
        raise e_cust_exception;
    END;
END LOOP;

  print_log('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_journals (-)');

exception
when others then
  print_log('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_journals (!)');
  print_log('Error: '||SQLERRM);         
END process_journals;

/*=========================================================================+
|                                                                          |
| Private Function                                                         |
|    process_subledgers                                                    |
|                                                                          |
| Description                                                              |
|    Procesa la informacion necesaria para la tabla de subledgers          |
|                                                                          |
| Parameters                                                               |
|    p_status                  OUT     NUMBER    Codigo Estado.            |
|    p_error_message           OUT     VARCHAR2  Mensaje de Error.         |
|                                                                          |
+=========================================================================*/
PROCEDURE process_subledgers ( p_company_id IN VARCHAR2
                            ,p_status_code   OUT VARCHAR2
                            ,p_error_message OUT VARCHAR2 ) IS

  -- ---------------------------------------------------------------------------
  -- Declaracion de Variables
  -- ---------------------------------------------------------------------------
 v_url VARCHAR2(500);
v_api_st VARCHAR2(100):= 'adaptiveSubLederEntryINE';
v_clob_int   CLOB;
v_status    VARCHAR2(1);
v_error_message VARCHAR2(1000);
e_cust_exception EXCEPTION;
e_max_exception EXCEPTION;
v_cant_ins                              NUMBER:=-1;
v_url_post                                 VARCHAR2(2000);
 v_api_post                                 VARCHAR2(100) := 'UpdateOutboundEntries_UpdateOutboundSubLedgerEntryINE';
v_body_post                              VARCHAR2(2000);
v_clob_result_post                     CLOB;
v_status_post                           VARCHAR2(1);
v_min_entry NUMBER;
v_max_entry NUMBER;
v_journal_name_ant varchar2(100);
v_je_header_id NUMBER;
v_record_count NUMBER;
v_cant_call NUMBER;

BEGIN
    print_log ('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_subledgers (+)');
    print_log('Comienzo insert'||' - '||to_char(sysdate,'hh24:mi:ss'));
    print_log('p_company_id: '||p_company_id);
    print_log('gv_request_id: '||gv_request_id);
    print_log('gv_user_id: '||gv_user_id);

     v_url := ajc_bc_j_ws_utils_pkg.get_base_inecta_url_f ( gv_bc_environment, p_company_id ) || v_api_st;--||'?$filter=periodEndDate eq '|| '2023-02-25' ;
     print_log('v_url: '||v_url);

    v_cant_call:=0;
   v_record_count:=-1;

 WHILE v_record_count<>0  LOOP 
    begin
        BEGIN

          -- 20260113 REINTENTO
          gv_retry := 'N';

          BEGIN
          -- 20260113 REINTENTO

            v_clob_int := ajc_bc_j_ws_utils_pkg.get_bc_clob_result_f ( v_url) ;

            -- 20260113 REINTENTO
            IF ( UPPER(v_clob_int) LIKE UPPER('%502 Bad Gateway%') ) THEN

              print_log('502 Bad Gateway'); 
              gv_retry := 'Y';

            END IF;

          EXCEPTION
            WHEN OTHERS THEN
              print_log('Error calling ajcl_bc_ws_utils_pkg.patch_post_bc_row_f: ' || SQLCODE || '|' || SQLERRM ); 
              gv_retry := 'Y';

          END;

          IF ( gv_retry = 'Y' ) THEN

            print_log( 'Connection error detected. Retrying in ' || gv_retry_in_seconds || ' seconds.' );
            DBMS_LOCK.sleep(gv_retry_in_seconds);

            v_clob_int := ajc_bc_j_ws_utils_pkg.get_bc_clob_result_f ( v_url) ;

          END IF;
          -- 20260113 REINTENTO

     insert into ajc_gl_adaptive_subledger
                ( je_header_id,
             je_line_num,
             application_id,
             company,
             account,
             dept,  
             product,
             dest, 
             origin,
             intercompany,  
             code_combination_id,
             transaction_type,
             transaction_number,
             transaction_date,
             accounting_date,
             cust_supp_name,
             entered_dr,
             entered_cr,
             currency_code,
             accounted_dr,
             accounted_cr,
             transaction_class_name,
             transaction_source_name,
             description,
             asset_number,
             asset_book,
             asset_category_segment1,
             asset_category_segment2,
             currency_conversion_rate,
             comments,
             error_message, 
             attachment_1,
             attachment_2,
             attachment_3,
             attachment_4,
             attachment_5,
             created_by, 
             creation_date, 
             last_updated_by, 
             last_update_date, 
             last_update_login, 
             request_id, 
             parent_request_id,
             office,
             dest_bc,
             product_bc,
             division_bc ) 
    SELECT 
            companySegment,--gLJournalEntryHeaderId, changed to make unique key. entryNo can be duplicated accross companies 
              entryNo,
            --journalEntryBatchId,
            DECODE(oracleApplicationID,'PURCHASES',200,'SALES',222,'BNKDEPOSIT',222,'CASHRECJNL',222,'PAYMENTJNL',200,-1), -- CORREGIR? LO USA ADAPTIVE?
            companySegment,
            substr(accountSegment,6,4),
            nvl(deptSegment,'000'),
            nvl(productSegment,'000'),
            '000',--nvl(destSegment,'000'), MB: El dato de BC se inserta en dest_bc, este campo queda reservado para los valores originales de Oracle
            nvl(originSegment,'000'),
            nvl(intercompanySegment,'00'),
            NULL, --code_combination_id      
            CASE 
            WHEN  transactionClassName = 'Customer' AND transactionType = 'Payment' 
                THEN 'Cash'
            ELSE
                    transactionType
            END "transactionType",
            transactionNumber,
            to_date(transactionDate,'yyyy-mm-dd'),
            to_date(accountingDate,'yyyy-mm-dd'),
            customerSupplierName,
            replace(origCurrencyDebit,',',''),--replace(replace(origCurrencyDebit,',',''),'.',','),
            replace(origCurrencyCredit,',',''),--replace(replace(origCurrencyCredit,',',''),'.',','),
            originalCurrencyCode,
            replace(functionalCurrencyDebit,',',''),--replace(replace(functionalCurrencyDebit,',',''),'.',','),
            replace(functionalCurrencyCredit,',',''),--replace(replace(functionalCurrencyCredit,',',''),'.',','),
            CASE 
            WHEN  transactionClassName = 'Customer' AND transactionType = 'Payment' 
                THEN 'Cash'
            ELSE
                    transactionType
            END "transactionClassName",
            transactionSourceName,
            transactionDescription,
            fAAssetNumber,
            substr(fAAssetBook,1,15),
            fAAssetCategorySegment1,
            fAAssetCategorySegment2,
            --processedinOracle,
            r
