CREATE OR REPLACE PACKAGE BODY              AJC_BC_J_ADAPTIVE_INTERFACE_PK IS

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

            replace(currencyConverionRate,',',''),--replace(replace(currencyConverionRate,',',''),'.',','),

            gLJournalEntryHeaderId,--NULL --comments

            NULL, --error_message

            attachment1,

            attachment2,

            attachment3,

            attachment4,

            attachment5,

            gv_user_id,

            sysdate,

            gv_user_id,

            sysdate,

            gv_login_id,

            gv_request_id,

            -1, -- parent_request_id . se marca con -1 para identificar los no posteados en BC

            office,

            nvl(destSegment,'000'),

            nvl(productSegment,'000'),     

            nvl(intercompanySegment,'000')                    

    FROM json_table( v_clob_int,

                     '$.value[*]' COLUMNS ( 

                                                            entryNo VARCHAR2(4000)  path '$.entryNo',

                                                            gLJournalEntryHeaderId VARCHAR2(4000)  path '$.gLJournalEntryHeaderId',

                                                            journalEntryBatchId VARCHAR2(4000)  path '$.journalEntryBatchId',

                                                            oracleApplicationID VARCHAR2(4000)  path '$.oracleApplicationID',

                                                            transactionType VARCHAR2(4000)  path '$.transactionType',

                                                            transactionNumber VARCHAR2(4000)  path '$.transactionNumber',

                                                            transactionDate VARCHAR2(4000)  path '$.transactionDate',

                                                            accountingDate VARCHAR2(4000)  path '$.accountingDate',

                                                            customerSupplierName VARCHAR2(4000)  path '$.customerSupplierName',

                                                            origCurrencyDebit VARCHAR2(4000)  path '$.origCurrencyDebit',

                                                            origCurrencyCredit VARCHAR2(4000)  path '$.origCurrencyCredit',

                                                            originalCurrencyCode VARCHAR2(4000)  path '$.originalCurrencyCode',

                                                            currencyConverionRate VARCHAR2(4000) path '$.currencyConverionRate',

                                                            functionalCurrencyDebit VARCHAR2(4000)  path '$.functionalCurrencyDebit',

                                                            functionalCurrencyCredit VARCHAR2(4000)  path '$.functionalCurrencyCredit',

                                                            transactionClassName VARCHAR2(4000)  path '$.transactionClassName',

                                                            transactionSourceName VARCHAR2(4000)  path '$.transactionSourceName',

                                                            transactionDescription VARCHAR2(4000)  path '$.transactionDescription',

                                                            fAAssetNumber VARCHAR2(4000)  path '$.fAAssetNumber',

                                                            fAAssetBook VARCHAR2(4000)  path '$.fAAssetBook',

                                                            fAAssetCategorySegment1 VARCHAR2(4000)  path '$.fAAssetCategorySegment1',

                                                            fAAssetCategorySegment2 VARCHAR2(4000)  path '$.fAAssetCategorySegment2',

                                                            companySegment VARCHAR2(4000)  path '$.companySegment',

                                                            accountSegment VARCHAR2(4000)  path '$.accountSegment',

                                                            deptSegment VARCHAR2(4000)  path '$.deptSegment',

                                                            productSegment VARCHAR2(4000)  path '$.productSegment',

                                                            destSegment VARCHAR2(4000)  path '$.destSegment',

                                                            originSegment VARCHAR2(4000)  path '$.originSegment',

                                                            intercompanySegment VARCHAR2(4000)  path '$.intercompanySegment',

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

                from ajc_gl_adaptive_subledger

                where parent_request_id =-1; -- no posteados

                --last_update_login=-1; --no posteados

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

                      print_log('v_clob_result_post: ' || v_clob_result_post);                      



                    IF ( INSTR(v_clob_result_post,'error') != 0 )  THEN

                                            print_log('Error al hacer el post de processedInOracle');

                                            print_log(v_clob_result_post);

                                            raise e_cust_exception;

                    ELSE -- post ok

                            --marco los posteados, independientemente del request_id actual, quizas falló el posteo en un proceso anterior

                            update ajc_gl_adaptive_subledger

                            set parent_request_id = request_id--last_update_login=gv_login_id--request_id=gv_request_id

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

            v_error_message:='Se corta el loop de insert de SUBLEDGERS porque se llamó mas de 30 veces';

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

 print_log ('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_subledgers (-)');

exception

when others then

print_log('Error: '||SQLERRM);         

END process_subledgers;





/*=========================================================================+

|                                                                          |

| Private Function                                                         |

|    process_accounts                                                      |

|                                                                          |

| Description                                                              |

|    Procesa la informacion necesaria para la tabla de Accounts            |

|                                                                          |

|                                                                          |

| Parameters                                                               |

|    p_company_id           IN          BC Company a procesar

|    p_status                  OUT     NUMBER    Codigo Estado.            |

|    p_error_message           OUT     VARCHAR2  Mensaje de Error.         |

|                                                                          |

+=========================================================================*/

PROCEDURE process_accounts ( p_company_id IN VARCHAR

                            ,p_status_code   OUT VARCHAR2

                            ,p_error_message OUT VARCHAR2 )

IS





  -- ---------------------------------------------------------------------------

  -- Declaracion de Variables

  -- ---------------------------------------------------------------------------

  -- Process Control Variables

  v_warn_flag              VARCHAR2(1);

  v_error_message          VARCHAR2(2000);

  e_cust_exception         EXCEPTION;

  e_resp_exception         EXCEPTION;

  v_request_id             NUMBER;

  v_status_code            VARCHAR2(1);

  v_status    VARCHAR2(1);



  -- Data Variables

  v_record_count         NUMBER;

  v_url VARCHAR2(500);

  v_api_st VARCHAR2(100):= 'adaptiveGLBalINE';

  v_clob_int   CLOB;

  v_company_id VARCHAR2(100);

  v_oracle_account  AJC.AJC_BC_ACCOUNTS.oracle_account%TYPE;

  v_cant_call NUMBER:=0;



BEGIN



  print_log ('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_accounts (+)');



  -- ---------------------------------------------------------------------------

  -- Inicializo variables Grales de Ejecucion.

  -- ---------------------------------------------------------------------------



  p_status_code := null;

  v_record_count := -1;



        v_url := ajc_bc_j_ws_utils_pkg.get_base_inecta_url_f ( gv_bc_environment, p_company_id ) || v_api_st;



        print_log('v_url: '||v_url);



   WHILE v_record_count<>0  LOOP 



      BEGIN



            print_log('Llamada a la API '||v_api_st);



            -- 20260113 REINTENTO

            gv_retry := 'N';



            BEGIN

            -- 20260113 REINTENTO



              v_clob_int := ajc_bc_j_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url) ;



              -- 20260113 REINTENTO

              IF ( UPPER(v_clob_int) LIKE UPPER('%502 Bad Gateway%') ) THEN



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



              v_clob_int := ajc_bc_j_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url) ;



            END IF;

            -- 20260113 REINTENTO



            print_log('Insert en la tabla de adaptive');



            INSERT INTO ajc_gl_adaptive_account_bal 

               (company

               ,account

               ,dept

               ,product

               ,dest

               ,origin

               ,intercompany

               ,company_description

               ,code_combination_id

               ,account_description

               ,account_reference

               ,financial_statement

               ,account_type

               ,active_account

               ,activity_in_period

               ,currency_code

               ,period_end_date

               ,ptd_account_balance

               ,set_of_books_id

               ,period_name

               ,period_year

               ,period_num

               ,error_message

               ,created_by

               ,creation_date

               ,last_updated_by

               ,last_update_date

               ,last_update_login

               ,request_id

               ,parent_request_id

               ,ptd_account_balance_usd

               ,office

               ,dest_bc

               ,product_bc

               ,division_bc) 

          SELECT

          r_bal.company,

              -- Modificado KHRONUS/PBonadeo 20250331: Se solicita utilizar los 8 digitos completos de cuenta que llegan de BC

              --substr(r_bal.account,6,4),

              r_bal.account,

              -- Fin Modificado KHRONUS/PBonadeo 20250331: Se solicita utilizar los 8 digitos completos de cuenta que llegan de BC

              nvl(r_bal.dept,'000'),

             nvl(r_bal.product,'000'),

             '000',-- nvl(r_bal.dest,'000'), MB: El dato de BC se inserta en dest_bc, este campo queda reservado para los valores originales de Oracle

             nvl(r_bal.origin,'000'),

             nvl(r_bal.intercompany,'00'),

             r_bal.companyDescription, -- company_description

             -1, --code_combination_id

             r_bal.accountDescription,

             NULL, -- account_reference

             'A',--financial_statement

             NULL, --account_type

             UPPER(r_bal.ActiveAccount),

             UPPER(r_bal.ActivityInPeriod),

             r_bal.CurrencyCode,

             to_date(r_bal.PeriodEndDate,'yyyy-mm-dd'),

             r_bal.PTDAccountBalance,--replace(r_bal.PTDAccountBalance,'.',','),

             -1, --set_of_books_id

             NULL, --period_name

             r_bal.periodYear,

             NULL, --periodNum

             NULL, --error_message

             gv_user_id,

             sysdate,

             gv_user_id,

             sysdate,

             -1,

             gv_request_id,

             gv_request_id,

             r_bal.additionalCurrencyNetChange,

             r_bal.office,

             nvl(r_bal.dest,'000'),

             nvl(r_bal.product,'000'),   

             nvl(r_bal.intercompany,'000')

    FROM json_table( v_clob_int,

                     '$.value[*]' COLUMNS ( company VARCHAR2(4000)  path '$.company',

                                                        account VARCHAR2(4000)  path '$.account',

                                                        dept VARCHAR2(4000)  path '$.dept',

                                                        product VARCHAR2(4000)  path '$.product',

                                                        dest VARCHAR2(4000)  path '$.dest',

                                                        origin VARCHAR2(4000)  path '$.origin',

                                                        intercompany VARCHAR2(4000)  path '$.intercompany',

                                                        accountDescription VARCHAR2(4000)  path '$.accountDescription',

                                                        activeAccount VARCHAR2(4000)  path '$.activeAccount',

                                                        activityinPeriod VARCHAR2(4000)  path '$.activityinPeriod',

                                                        currencyCode VARCHAR2(4000)  path '$.currencyCode',

                                                        ptdAccountBalance VARCHAR2(4000)  path '$.ptdAccountBalance',

                                                        periodEndDate VARCHAR2(4000)  path '$.periodEndDate',

                                                        periodYear VARCHAR2(4000)  path '$.periodYear',

                                                        entryNo VARCHAR2(4000)  path '$.entryNo',

                                                        companyDescription VARCHAR2(4000)  path '$.companyDescription',

                                                        additionalCurrencyNetChange VARCHAR2(4000)  path '$.additionalCurrencyNetChange',

                                                        office VARCHAR2(4000)  path '$.office' )) r_bal;



        v_record_count:=sql%rowcount;

        print_log('v_record_count: '||v_record_count);

        v_cant_call:=v_cant_call + 1;

        COMMIT;



        IF v_cant_call >= 50 THEN

            v_error_message:='Se corta el loop de insert de saldos porque se llamó mas de 50 veces';

            raise e_cust_exception;

        END IF;



      EXCEPTION

      WHEN OTHERS THEN

        v_error_message :=v_error_message||' - '||SQLERRM;

        RAISE e_cust_exception;   

      END; 

    END LOOP;





  COMMIT;         

  print_log ('  p_status_code => ' || p_status_code);

  print_log ('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_accounts (-)');



EXCEPTION

WHEN e_cust_exception THEN

    print_log('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_accounts(!)');

    p_error_message := v_error_message;

     print_log(p_error_message);

    p_status_code := 'E';



               print_log ('  Se borran los registros de la tabla ajc_gl_adaptive_account_bal para el periodo.');



              DELETE ajc_gl_adaptive_account_bal 

               WHERE period_end_date IN (SELECT distinct period_end_date

                                                            FROM ajc_gl_adaptive_account_bal 

                                                            WHERE request_id=gv_request_id )

               AND request_id<>gv_request_id;

            --   AND company NOT IN ('52','53','54');



               COMMIT;



WHEN OTHERS THEN

    print_log('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_accounts(!)');

    p_error_message := 'Error no tratado en AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_accounts: ' || sqlerrm;

    print_log(p_error_message);

    p_status_code := 'E';

    ROLLBACK;

END process_accounts;





/*=========================================================================+

|                                                                          |

| Private Function                                                         |

|    process_period_rates                                                  |

|                                                                          |

| Description                                                              |

|    Procesa la informacion necesaria para la tabla de Period Rates        |

|                                                                          |

|                                                                          |

| Parameters                                                               |

|    p_status                  OUT     NUMBER    Codigo Estado.            |

|    p_error_message           OUT     VARCHAR2  Mensaje de Error.         |

|                                                                          |

+=========================================================================*/

PROCEDURE process_period_rates (    p_status_code       OUT   VARCHAR2

                                                     ,p_error_message     OUT   VARCHAR2 ) IS



CURSOR c_periods(p_clob_int CLOB) IS

 SELECT distinct

            to_date(periodENDDATE,'yyyy-mm-dd') period_end_date

    FROM json_table( p_clob_int,

                     '$.value[*]' COLUMNS ( 

                                                            entryNo VARCHAR2(4000)  path '$.entryNo',

                                                            name VARCHAR2(4000)  path '$.name',

                                                            currencyCode VARCHAR2(4000)  path '$.currencyCode',

                                                            toCurrencyCode VARCHAR2(4000)  path '$.toCurrencyCode',

                                                            periodName VARCHAR2(4000)  path '$.periodName',

                                                            showAVGRATE VARCHAR2(4000)  path '$.showAVGRATE',

                                                            showEOPRATE VARCHAR2(4000)  path '$.showEOPRATE',

                                                            periodENDDATE VARCHAR2(4000)  path '$.periodENDDATE'));

  -- ---------------------------------------------------------------------------

  -- Declaracion de Variables

  -- ---------------------------------------------------------------------------

  -- Process Control Variables

  v_warn_flag         VARCHAR2(1);

  v_error_message     VARCHAR2(2000);

  e_cust_exception    EXCEPTION;

  e_resp_exception    EXCEPTION;

  v_request_id        NUMBER;

  v_status_code       VARCHAR2(1);

  v_status    VARCHAR2(1);



  v_url VARCHAR2(500);

  v_api_st VARCHAR2(100):= 'adaptiveOutboundPeriodRatesAJCINE';

  v_clob_int   CLOB;

  v_company_id VARCHAR2(100);

  v_count NUMBER;



BEGIN



  print_log ('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_period_rates (+)');



  -- ---------------------------------------------------------------------------

  -- Inicializo variables Grales de Ejecucion.

  -- ---------------------------------------------------------------------------



  p_status_code := null;



        ajc_bc_j_ws_utils_pkg.get_bc_company_id_f(5244,NULL,NULL,v_company_id,v_status);        



        print_log('v_company_id: '||v_company_id);



        IF v_status = 'E' THEN

                v_error_message := 'Error al obtener v_company_id. Error: '||SQLERRM;

                v_company_id:=null;

                print_log(   v_error_message);

                RAISE e_cust_exception;

        END IF;



        v_url := ajc_bc_j_ws_utils_pkg.get_base_inecta_url_f ( gv_bc_environment, v_company_id ) || v_api_st;



        print_log('v_url: '||v_url);



        v_clob_int := ajc_bc_j_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url) ;



        -- elimino registros previos

        FOR r_periods in c_periods (v_clob_int) LOOP



            print_log('period_end_date :'||r_periods.period_End_Date);



            DELETE ajc_gl_adaptive_period_rates

            WHERE period_end_date=r_periods.period_end_date;



        END LOOP;



     insert into ajc_gl_adaptive_period_rates

       ( name

      ,currency_code

      ,to_currency_code

      ,period_name

      ,show_avg_rate

      ,show_eop_rate

      ,period_end_date

      ,error_message

      ,created_by

      ,creation_date

      ,last_updated_by

      ,last_update_date

      ,last_update_login

      ,request_id

      ,parent_request_id) 

    SELECT 

            name,

            currencyCode,

            toCurrencyCode,

            periodName,

            showAVGRATE,

            showEOPRATE,

            to_date(periodENDDATE,'yyyy-mm-dd'),

            NULL, --error_message

            fnd_global.user_id,

            SYSDATE,

            fnd_global.user_id,

            SYSDATE,

            -1,

            gv_request_id,

            gv_request_id            

    FROM json_table( v_clob_int,

                     '$.value[*]' COLUMNS ( 

                                                            entryNo VARCHAR2(4000)  path '$.entryNo',

                                                            name VARCHAR2(4000)  path '$.name',

                                                            currencyCode VARCHAR2(4000)  path '$.currencyCode',

                                                            toCurrencyCode VARCHAR2(4000)  path '$.toCurrencyCode',

                                                            periodName VARCHAR2(4000)  path '$.periodName',

                                                            showAVGRATE VARCHAR2(4000)  path '$.showAVGRATE',

                                                            showEOPRATE VARCHAR2(4000)  path '$.showEOPRATE',

                                                            periodENDDATE VARCHAR2(4000)  path '$.periodENDDATE'));



   v_count:=sql%rowcount;



  print_log('v_count: '||v_count);

  commit;

  print_log ('  p_status_code => ' || p_status_code);

  print_log ('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_period_rates (-)');



EXCEPTION

  WHEN e_cust_exception THEN

    print_log('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_period_rates(!)');

    p_error_message := v_error_message;

    p_status_code := 'E';



WHEN OTHERS THEN

    print_log('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_period_rates(!)');

    p_error_message := 'Error no tratado en AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_period_rates: ' || sqlerrm;

    print_log(p_error_message);

    p_status_code := 'E';



END process_period_rates;





/*=========================================================================+

|                                                                          |

| Private Function                                                         |

|    process_period_avg_rates                                                  |

|                                                                          |

| Description                                                              |

|    Procesa la informacion necesaria para la tabla de Period Rates        |

|                                                                          |

|                                                                          |

| Parameters                                                               |

|    p_status                  OUT     NUMBER    Codigo Estado.            |

|    p_error_message           OUT     VARCHAR2  Mensaje de Error.         |

|                                                                          |

+=========================================================================*/

PROCEDURE process_period_avg_rates (    p_status_code       OUT   VARCHAR2

                                                     ,p_error_message     OUT   VARCHAR2 ) IS



  CURSOR c_periods ( p_clob_result   IN   CLOB ) IS

  SELECT ledgerName,

         fromCurrencyCode,

         toCurrencyCode,

         periodName,

         averageRate,

         endOfPeriodRate,

         periodEndDate

    FROM json_table( p_clob_result,

         '$.value[*]' COLUMNS ( ledgerName                VARCHAR2(4000)  path '$.ledgerName', 

                                fromCurrencyCode          VARCHAR2(4000)  path '$.fromCurrencyCode',

                                toCurrencyCode            VARCHAR2(4000)  path '$.toCurrencyCode',

                                periodName                VARCHAR2(4000)  path '$.periodName',

                                averageRate               VARCHAR2(4000)  path '$.averageRate',

                                endOfPeriodRate           VARCHAR2(4000)  path '$.endOfPeriodRate',

                                periodEndDate             VARCHAR2(4000)  path '$.periodEndDate' ) );



  -- ---------------------------------------------------------------------------

  -- Declaracion de Variables

  -- ---------------------------------------------------------------------------

  -- Process Control Variables

  v_warn_flag         VARCHAR2(1);

  v_error_message     VARCHAR2(2000);

  e_cust_exception    EXCEPTION;

  e_resp_exception    EXCEPTION;

  v_request_id        NUMBER;

  v_status_code       VARCHAR2(1);

  v_status    VARCHAR2(1);



  v_count NUMBER;



  v_company_id       VARCHAR2(200) := 'c0d4e3d4-6dc5-ec11-8e7e-0022482b52d9';

  v_company_name     VARCHAR2(200) := 'CONSO-GRP-USD';

  v_api              VARCHAR2(2000);

  v_url              VARCHAR2(2000);



  v_clob_result      CLOB;



BEGIN



  print_log ('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_period_avg_rates (+)');



  -- ---------------------------------------------------------------------------

  -- Inicializo variables Grales de Ejecucion.

  -- ---------------------------------------------------------------------------



  p_status_code := null;



   v_api := ajc_bc_j_ws_utils_pkg.get_api_f ( p_entity => 'TRANSLATION RATES',

                                           p_subentity => NULL,

                                           p_method => 'GET' );



  print_log ( 'v_api: ' || v_api );



  v_url := ajc_bc_j_ws_utils_pkg.get_base_ajc_url_v2_f ( p_environment => gv_bc_environment,

                                                       p_company_id => v_company_id ) || v_api;



  print_log ( 'v_url: ' || v_url );



  -- 20260113 REINTENTO

  gv_retry := 'N';



  BEGIN

  -- 20260113 REINTENTO



    v_clob_result := ajc_bc_j_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



    -- 20260113 REINTENTO

    IF ( UPPER(v_clob_result) LIKE UPPER('%502 Bad Gateway%') ) THEN



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



    v_clob_result := ajc_bc_j_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



  END IF;

  -- 20260113 REINTENTO



  print_log ( 'v_clob_result: ' || v_clob_result );





        -- elimino registros previos

        FOR r_periods in c_periods (v_clob_result) LOOP



            print_log( 'ledgerName: ' || r_periods.ledgerName || ' | ' || 

                           'fromCurrencyCode: ' || r_periods.fromCurrencyCode || ' | ' || 

                           'toCurrencyCode: ' || r_periods.toCurrencyCode || ' | ' || 

                           'periodName: ' || r_periods.periodName || ' | ' || 

                           'averageRate: ' || r_periods.averageRate || ' | ' || 

                           'endOfPeriodRate: ' || r_periods.endOfPeriodRate || ' | ' || 

                           'periodEndDate: ' || r_periods.periodEndDate );



            SELECT count(*)

            INTO v_count

            FROM ajc_gl_adaptive_period_rates

            WHERE period_end_date= to_date(r_periods.periodENDDATE,'yyyy-mm-dd')

            and currency_code=r_periods.fromCurrencyCode 

            and to_currency_code=r_periods.ToCurrencyCode 

            and name=r_periods.ledgerName;



            IF v_count > 0 THEN -- existe, entonces update



                UPDATE ajc_gl_adaptive_period_rates

                SET 

                    show_avg_rate = ROUND(1/TO_NUMBER(r_periods.averageRate,'999G999G999D9999999999'),10),

                    show_eop_rate = ROUND(1/TO_NUMBER(r_periods.endOfPeriodRate,'999G999G999D9999999999'),10),

                    last_updated_by= fnd_global.user_id,

                    last_update_date=SYSDATE,

                    request_id=gv_request_id,

                    parent_request_id=gv_request_id

                WHERE period_end_date= to_date(r_periods.periodENDDATE,'yyyy-mm-dd')

                    and currency_code=r_periods.fromCurrencyCode

                    and to_currency_code=r_periods.ToCurrencyCode

                    and name=r_periods.ledgerName;

            ELSE -- no existe, inserto



                IF r_periods.periodName IS NULL THEN -- AFBC-77

                    print_log('Cannot be inserted into rates table because Period Name is null.');

                ELSIF  r_periods.ledgerName IN ('LFS-MEX-MXN','LFS-COL-COP') THEN 

                    print_log('Rates not inserted in order to prevent duplicate currencies.');

                ELSE



                         insert into ajc_gl_adaptive_period_rates

                           ( name

                          ,currency_code

                          ,to_currency_code

                          ,period_name

                          ,show_avg_rate

                          ,show_eop_rate

                          ,period_end_date

                          ,error_message

                          ,created_by

                          ,creation_date

                          ,last_updated_by

                          ,last_update_date

                          ,last_update_login

                          ,request_id

                          ,parent_request_id) 

                        VALUES

                              (  r_periods.ledgerName,

                                r_periods.fromCurrencyCode,

                                r_periods.toCurrencyCode,

                                r_periods.periodName,

                                ROUND(1/TO_NUMBER(r_periods.averageRate,'999G999G999D9999999999'),10),

                                ROUND(1/TO_NUMBER(r_periods.endOfPeriodRate,'999G999G999D9999999999'),10),

                                to_date(r_periods.periodENDDATE,'yyyy-mm-dd'),

                                NULL, --error_message

                                fnd_global.user_id,

                                SYSDATE,

                                fnd_global.user_id,

                                SYSDATE,

                                -1,

                                gv_request_id,

                                gv_request_id           ) ;       

                END IF;

        END IF;

    END LOOP;





  commit;

  print_log ('  p_status_code => ' || p_status_code);

  print_log ('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_period_avg_rates (-)');



EXCEPTION

  WHEN e_cust_exception THEN

    print_log('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_period_avg_rates(!)');

    p_error_message := v_error_message;

    p_status_code := 'E';



WHEN OTHERS THEN

    print_log('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_period_avg_rates(!)');

    p_error_message := 'Error no tratado en AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_period_avg_rates: ' || sqlerrm;

    print_log(p_error_message);

    p_status_code := 'E';



END process_period_avg_rates;



/*=========================================================================+

|                                                                          |

| Private Function                                                         |

|    process_origins                                                       |

|                                                                          |

| Description                                                              |

|    Procesa la informacion necesaria para la tabla de Origins             |

|                                                                          |

|                                                                          |

| Parameters                                                               |

|    p_status                  OUT     NUMBER    Codigo Estado.            |

|    p_error_message           OUT     VARCHAR2  Mensaje de Error.         |

|                                                                          |

+=========================================================================*/

PROCEDURE process_origins ( p_status_code       OUT   VARCHAR2

                           ,p_error_message     OUT   VARCHAR2 ) IS



  -- ---------------------------------------------------------------------------

  -- Declaracion de Variables

  -- ---------------------------------------------------------------------------

  -- Process Control Variables

  v_warn_flag         VARCHAR2(1);

  v_error_message     VARCHAR2(2000);

  e_cust_exception    EXCEPTION;

  e_resp_exception    EXCEPTION;

  v_request_id        NUMBER;

  v_status_code       VARCHAR2(1);

  v_status  VARCHAR2(1);



  v_url VARCHAR2(500);

  v_api_st VARCHAR2(100):= 'adaptiveOutboundOriginsAJCINE';

  v_clob_int   CLOB;

  v_company_id VARCHAR2(100);





BEGIN



  print_log ('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_origins (+)');



  -- ---------------------------------------------------------------------------

  -- Inicializo variables Grales de Ejecucion.

  -- ---------------------------------------------------------------------------



  p_status_code := null;



    ajc_bc_j_ws_utils_pkg.get_bc_company_id_f(5244,NULL,NULL,v_company_id,v_status);        



    print_log('v_company_id: '||v_company_id);



    IF v_status = 'E' THEN

            v_error_message := 'Error al obtener v_company_id. Error: '||SQLERRM;

            v_company_id:=null;

            print_log(   v_error_message);

            RAISE e_cust_exception;

    END IF;



    v_url := ajc_bc_j_ws_utils_pkg.get_base_inecta_url_f ( gv_bc_environment, v_company_id ) || v_api_st;



    print_log('v_url: '||v_url);



    v_clob_int := ajc_bc_j_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url) ;



      INSERT 

        INTO AJC_gl_adaptive_origin

             ( flex_value

              ,description

              ,enabled_flag

              ,summary_flag

              ,start_date_active

              ,end_date_active

              ,error_message

              ,created_by

              ,creation_date

              ,last_updated_by

              ,last_update_date

              ,last_update_login

              ,request_id

              ,parent_request_id ) 

    SELECT 

            flexValue,

            description,

            decode(enabledFlag,'true','Y','N'),

            decode(summaryFlag,'true','Y','N'),

            to_date(startDateActive,'yyyy-mm-dd'),

            to_date(endDateActive,'yyyy-mm-dd'),

            NULL, --error_message

            fnd_global.user_id,

            SYSDATE,

            fnd_global.user_id,

            SYSDATE,

            -1,

            gv_request_id,

            gv_request_id 

    FROM json_table( v_clob_int,

                     '$.value[*]' COLUMNS ( 

                                                            entryNo VARCHAR2(4000)  path '$.entryNo',

                                                            dimensionCode VARCHAR2(4000)  path '$.dimensionCode',

                                                            flexValue VARCHAR2(4000)  path '$.flexValue',

                                                            description VARCHAR2(4000)  path '$.description',

                                                            enabledFlag VARCHAR2(4000)  path '$.enabledFlag',

                                                            summaryFlag VARCHAR2(4000)  path '$.summaryFlag',

                                                            startDateActive VARCHAR2(4000)  path '$.startDateActive',

                                                            endDateActive VARCHAR2(4000)  path '$.endDateActive',

                                                            batchNo VARCHAR2(4000)  path '$.batchNo'));



  print_log ('  p_status_code => ' || p_status_code);

  print_log ('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_origins (-)');



EXCEPTION

  WHEN e_cust_exception THEN

    print_log('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_origins(!)');

    p_error_message := v_error_message;

    p_status_code := 'E';



WHEN OTHERS THEN

    print_log('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_origins(!)');

    p_error_message := 'Error no tratado en AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_origins: ' || sqlerrm;

    print_log(p_error_message);

    p_status_code := 'E';



END process_origins;



/*=========================================================================+

|                                                                          |

| Private Function                                                         |

|    process_products                                                       |

|                                                                          |

| Description                                                              |

|    Procesa la informacion necesaria para la tabla de Products            |

|                                                                          |

|                                                                          |

| Parameters                                                               |

|    p_status                  OUT     NUMBER    Codigo Estado.            |

|    p_error_message           OUT     VARCHAR2  Mensaje de Error.         |

|                                                                          |

+=========================================================================*/

PROCEDURE process_products ( p_status_code       OUT   VARCHAR2

                            ,p_error_message     OUT   VARCHAR2 ) IS



  -- ---------------------------------------------------------------------------

  -- Declaracion de Variables

  -- ---------------------------------------------------------------------------

  -- Process Control Variables

  v_warn_flag         VARCHAR2(1);

  v_error_message     VARCHAR2(2000);

  e_cust_exception    EXCEPTION;

  e_resp_exception    EXCEPTION;

  v_request_id        NUMBER;

  v_status_code       VARCHAR2(1);

  v_status  VARCHAR2(1);



  v_url VARCHAR2(500);

  v_api_st VARCHAR2(100):= 'adaptiveOutboundProductsAJCINE';

  v_clob_int   CLOB;

  v_company_id VARCHAR2(100);



BEGIN



  print_log ('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_products (+)');



  -- ---------------------------------------------------------------------------

  -- Inicializo variables Grales de Ejecucion.

  -- ---------------------------------------------------------------------------



  p_status_code := null;



    ajc_bc_j_ws_utils_pkg.get_bc_company_id_f(5244,NULL,NULL,v_company_id,v_status);        



    print_log('v_company_id: '||v_company_id);



    IF v_status = 'E' THEN

            v_error_message := 'Error al obtener v_company_id. Error: '||SQLERRM;

            v_company_id:=null;

            print_log(   v_error_message);

            RAISE e_cust_exception;

    END IF;



    v_url := ajc_bc_j_ws_utils_pkg.get_base_inecta_url_f ( gv_bc_environment, v_company_id ) || v_api_st;



    print_log('v_url: '||v_url);



    v_clob_int := ajc_bc_j_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url) ;



      INSERT 

        INTO AJC_gl_adaptive_product

             ( flex_value

              ,description

              ,enabled_flag

              ,summary_flag

              ,start_date_active

              ,end_date_active

              ,error_message

              ,created_by

              ,creation_date

              ,last_updated_by

              ,last_update_date

              ,last_update_login

              ,request_id

              ,parent_request_id ) 

    SELECT 

            flexValue,

            description,

            decode(enabledFlag,'true','Y','N'),

            decode(summaryFlag,'true','Y','N'),

            to_date(startDateActive,'yyyy-mm-dd'),

            to_date(endDateActive,'yyyy-mm-dd'),

            NULL, --error_message

            fnd_global.user_id,

            SYSDATE,

            fnd_global.user_id,

            SYSDATE,

            -1,

            gv_request_id,

            gv_request_id 

    FROM json_table( v_clob_int,

                     '$.value[*]' COLUMNS ( 

                                                            entryNo VARCHAR2(4000)  path '$.entryNo',

                                                            dimensionCode VARCHAR2(4000)  path '$.dimensionCode',

                                                            flexValue VARCHAR2(4000)  path '$.flexValue',

                                                            description VARCHAR2(4000)  path '$.description',

                                                            enabledFlag VARCHAR2(4000)  path '$.enabledFlag',

                                                            summaryFlag VARCHAR2(4000)  path '$.summaryFlag',

                                                            startDateActive VARCHAR2(4000)  path '$.startDateActive',

                                                            endDateActive VARCHAR2(4000)  path '$.endDateActive',

                                                            batchNo VARCHAR2(4000)  path '$.batchNo'));



  print_log ('  p_status_code => ' || p_status_code);

  print_log ('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_products (-)');



EXCEPTION

  WHEN e_cust_exception THEN

    print_log('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_products(!)');

    p_error_message := v_error_message;

    p_status_code := 'E';



WHEN OTHERS THEN

    print_log('AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_products(!)');

    p_error_message := 'Error no tratado en AJC_BC_J_ADAPTIVE_INTERFACE_PK.process_products: ' || sqlerrm;

    print_log(p_error_message);

    p_status_code := 'E';



END process_products;





/*=========================================================================+

|                                                                          |

| Public Function                                                          |

|    main_process                                                          |

|                                                                          |

| Description                                                              |

|    Adaptive Interface Main Process                                       |

|    Concurrent Program Executable                                         |

|                                                                          |

|                                                                          |

+=========================================================================*/

PROCEDURE main_p ( p_bc_environment         IN   VARCHAR2,

                   p_force_closed_periods   IN   VARCHAR2 DEFAULT 'N',

                   p_jenkins_build_number   IN   VARCHAR2 ) IS





  CURSOR c_bc_companies IS

  SELECT DISTINCT bc_company_name,

         bc_company_id 

    FROM ajc.ajc_bc_companies;    



  v_status_code     varchar2(1);

  v_error_message   varchar2(2000);

  e_cust_exception  exception;

  v_period_end_date DATE;



  v_status  VARCHAR2(1);   

  v_url VARCHAR2(500);

  v_clob_int   CLOB;

  v_company_id VARCHAR2(100);



BEGIN



  print_log ('AJC_BC_J_ADAPTIVE_INTERFACE_PK.main_process (+)');



  gv_jenkins_build_number := p_jenkins_build_number;

  gv_request_id := ajc_bc_j_utils_pkg.get_request_id_f;



  -- Se inserta el concurrent_job

  ajc_bc_j_utils_pkg.ins_jenkins_concurrent_job_p ( p_request_id => gv_request_id,

                                                    p_job_name => gv_bc_ifc,

                                                    p_jenkins_build_number => gv_jenkins_build_number,

                                                    p_argument1 => p_bc_environment );



  print_log ( 'gv_request_id: ' || gv_request_id );                                                         



  gv_file_format :=ajc_bc_j_ws_utils_pkg.get_parameter_f ( 'FILE_FORMAT' );

  print_log( 'gv_file_format: ' || gv_file_format );



  gv_email := ajc_bc_j_utils_pkg.get_emails_f ( 'ADAPTIVE' );

  print_log( 'gv_email: ' || gv_email );



  -- Validacion parametro p_bc_environment -----------------------------------------------------------------------------------

  IF ( ajc_bc_j_utils_pkg.is_bc_environment_valid_f ( p_bc_environment ) = 'N' ) THEN



    v_error_message := 'Invalid value (' || p_bc_environment || ') for parameter BC_ENVIRONMENT.';

    RAISE e_cust_exception;



  END IF;



  gv_bc_environment := p_bc_environment;

  print_log ( 'gv_bc_environment: ' || gv_bc_environment );    



  -- 20260113 REINTENTO

  gv_retry_in_seconds := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'POST_RETRY_IN_SECONDS' );

  print_log ( 'POST_RETRY_IN_SECONDS: ' || gv_retry_in_seconds );    

  -- 20260113 REINTENTO



  print_log ('AJC_BC_J_ADAPTIVE_INTERFACE_PK.main_process (+)');



  print_log ('Iniciando cursor c_bc_companies'); 



  FOR r_bc_companies IN c_bc_companies LOOP



    BEGIN



      v_company_id:=r_bc_companies.bc_company_id;

      print_log('BC Company: '||r_bc_companies.bc_company_name || ' | v_company_id: ' || v_company_id);



      -- Proceso Accounts

      process_accounts ( p_company_id => v_company_id

                        ,p_status_code     => v_status_code

                        ,p_error_message   => v_error_message );



      IF v_status_code != 'S' THEN



        RAISE e_cust_exception;



      END IF;



      -- Proceso Journals

      process_journals ( p_company_id => v_company_id

                        ,p_status_code     => v_status_code

                        ,p_error_message   => v_error_message );



      IF v_status_code != 'S' THEN



        RAISE e_cust_exception; -- Revisar estado de finalizacion



      END IF;



      -- Proceso Subledgers

      process_subledgers ( p_company_id => v_company_id

                          ,p_status_code     => v_status_code

                          ,p_error_message   => v_error_message );



      IF v_status_code != 'S' THEN



        IF v_status_code = 'W' THEN



          RAISE e_cust_exception; 



        END IF;



      END IF;



    END;



  END LOOP;



  -- Proceso Period Rates

  process_period_avg_rates ( p_status_code     => v_status_code

                             ,p_error_message   => v_error_message );



  IF v_status_code != 'S' THEN



    RAISE e_cust_exception; -- Revisar estado de finalizacion



  END IF;



  -- 20260113

  /*

  print_log ('Se borran los registros de la tabla ajc_gl_adaptive_account_bal para el periodo.');



  DELETE ajc_gl_adaptive_account_bal 

   WHERE request_id<>gv_request_id

  -- AND company NOT IN ('52','53','54')

     AND (company_description,period_end_date) IN (SELECT distinct company_description,period_end_date

                                                     FROM ajc_gl_adaptive_account_bal 

                                                    WHERE request_id=gv_request_id );

  */

  del_account_bal_p;

  -- 20260113





  print_log ('v_status_code => ' || v_status_code);

  print_log ('AJC_BC_J_ADAPTIVE_INTERFACE_PK.main_process (-)');



  -- Se actualiza el concurrent_job

  ajc_bc_j_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'S' );



  COMMIT;



  ajc_bc_j_utils_pkg.send_log_by_mail_p(gv_request_id,'betti.matias@gmail.com');



EXCEPTION

  WHEN e_cust_exception THEN

    print_log('ajc_bc_j_adaptive_interface_pk.main_process (!)');

    print_log('Error e_cust_exception!');                                           

    print_log (v_error_message);      



    -- 20260113

    /*

    print_log ('Se borran los registros de la tabla ajc_gl_adaptive_account_bal para el periodo.');



    DELETE ajc_gl_adaptive_account_bal 

     WHERE request_id<>gv_request_id

    -- AND company NOT IN ('52','53','54')

       AND (company_description,period_end_date) IN (SELECT distinct company_description,period_end_date

                                                       FROM ajc_gl_adaptive_account_bal 

                                                      WHERE request_id=gv_request_id );



    COMMIT;

    */

    del_account_bal_p;

    -- 20260113



    ajc_bc_j_utils_pkg.send_email_p ( p_to => gv_email,

                                      p_subject =>  gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',   

                                      p_message => v_error_message || CHR(10) ||'Request Id: '||gv_request_id);



    ajc_bc_j_utils_pkg.send_log_by_mail_p(gv_request_id,gv_email);



    -- Se actualiza el concurrent_job

    ajc_bc_j_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



    RAISE_APPLICATION_ERROR(-20000,'General Error: ' || SQLERRM );         



  WHEN others THEN

    print_log('ajc_bc_j_adaptive_interface_pk.main_process (!)');

    print_log('Error e_cust_exception!');                                           

    print_log (v_error_message);       



    -- 20260113

    /*

    print_log ('Se borran los registros de la tabla ajc_gl_adaptive_account_bal para el periodo.');



    DELETE ajc_gl_adaptive_account_bal 

     WHERE request_id<>gv_request_id

    -- AND company NOT IN ('52','53','54')

       AND (company_description,period_end_date) IN (SELECT distinct company_description,period_end_date

                                                       FROM ajc_gl_adaptive_account_bal 

                                                      WHERE request_id=gv_request_id );



    COMMIT;

    */

    del_account_bal_p;

    -- 20260113



    ajc_bc_j_utils_pkg.send_email_p ( p_to => gv_email,

                                      p_subject =>  gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',   

                                      p_message => v_error_message || CHR(10) ||'Request Id: '||gv_request_id);



    ajc_bc_j_utils_pkg.send_log_by_mail_p(gv_request_id,gv_email);



    -- Se actualiza el concurrent_job

    ajc_bc_j_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



    RAISE_APPLICATION_ERROR(-20000,'General Error: ' || SQLERRM );                                                                                 



END main_p;



END AJC_BC_J_ADAPTIVE_INTERFACE_PK;
