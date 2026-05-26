CREATE OR REPLACE PACKAGE BODY AJC_BC_ATIS_BATCH_INTERFACE_PK IS

/* -----------------------------------------------------------------------------------------------|

| Historial                                                                                       |

|   Date      Version  Modified      Detail                                                       |

|   --------- -------  ----------    -------------------------------------------------------------|

|   14-ENE-22       1  MNazarre      Creation                                                     |

|   19-DEC-22       2  SBanchieri    Update                                                       |  

|------------------------------------------------------------------------------------------------*/



  g_user_id         number := fnd_global.user_id;

  g_login_id        number := fnd_global.login_id;

  g_request_id      number := fnd_global.conc_request_id;



  g_user_name       varchar2(100);

  g_mail_host       varchar2(100) := 'smtp.ajc.bz';



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

     fnd_file.put_line (fnd_file.log, p_message);

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

     fnd_file.put_line(fnd_file.output,p_message);

  END;





  function get_outfile_name (p_request_id in number) return varchar2

  is

    v_outfile_name fnd_concurrent_requests.outfile_name%type;

  begin



      print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.get_outfile_name(+)');

      print_log('p_request_id = ' || to_char(p_request_id));



      if p_request_id = 0 then

        return null;

      end if;



      select substr(outfile_name,INSTR(outfile_name,'/',-1)+1) --fcp.concurrent_program_name||'_'||fcr.request_id||'_1.EXCEL'

      into v_outfile_name

      from fnd_concurrent_requests fcr

          ,fnd_concurrent_programs fcp

      where fcr.request_id = p_request_id

      and   fcr.concurrent_program_id = fcp.concurrent_program_id;





      print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.get_outfile_name(-)');



      return v_outfile_name;



  exception

    when others then

      print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.get_outfile_name(!)');

      return null;

  end get_outfile_name;





  --------------------------------------------------------------

  function run_concurrent (p_concurrent_program in varchar2

                          ,p_application_short_name in varchar2

                          ,p_argument1   IN varchar2 default CHR(0)

                          ,p_argument2   IN varchar2 default CHR(0)

                          ,p_argument3   IN varchar2 default CHR(0)

                          ,p_argument4   IN varchar2 default CHR(0)

                          ,p_argument5   IN varchar2 default CHR(0)

                          ,p_argument6   IN varchar2 default CHR(0)

                          ,p_argument7   IN varchar2 default CHR(0)

                          ,p_argument8   IN varchar2 default CHR(0)

                          ,p_argument9   IN varchar2 default CHR(0)

                          ,p_argument10  IN varchar2 default CHR(0)

                          ,p_argument11  IN varchar2 default CHR(0)

                          ,p_request_id  OUT number

                          ,p_error_message OUT varchar2) return varchar2

  is

    v_conc_phase        varchar2(50);

    v_conc_status       varchar2(50);

    v_conc_dev_phase    varchar2(50);

    v_conc_dev_status   varchar2(50);

    v_conc_message      varchar2(250);

    v_message           varchar2(1000);



    v_template_appl_name   xdo_templates_b.application_short_name%TYPE;

    v_template_code        xdo_templates_b.template_code%TYPE;

    v_template_language    xdo_templates_b.default_language%TYPE;

    v_template_territory   xdo_templates_b.default_territory%TYPE;

    v_output_format        VARCHAR2(10);

    -- v_status_code          VARCHAR2(1);



  begin



    print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.run_concurrent(+)');

    print_log('  p_concurrent_program = ' || p_concurrent_program);

    print_log('  p_application_short_name = ' || p_application_short_name);

    print_log('  p_argument1 = ' || p_argument1);

    print_log('  p_argument2 = ' || p_argument2);

    print_log('  p_argument3 = ' || p_argument3);

    print_log('  p_argument1 = ' || p_argument4);

    print_log('  p_argument1 = ' || p_argument5);

    print_log('  p_argument1 = ' || p_argument6);

    print_log('  p_argument1 = ' || p_argument7);

    print_log('  p_argument1 = ' || p_argument8);

    print_log('  p_argument1 = ' || p_argument9);

    print_log('  p_argument10 = '|| p_argument10);



    BEGIN



      SELECT application_short_name, 

             template_code, 

             default_language, 

             default_territory, 

             'EXCEL'

        INTO v_template_appl_name,

             v_template_code,

             v_template_language,

             v_template_territory,

             v_output_format

        FROM xdo_templates_b

       WHERE template_code = p_concurrent_program;



    EXCEPTION

      WHEN OTHERS THEN

        p_error_message := 'Error al buscar los datos del template correspondiente al código: '||p_concurrent_program||': '||sqlerrm;

        return 'W';

    END;  



    IF NOT fnd_request.add_layout ( template_appl_name  => v_template_appl_name,

                                    template_code       => v_template_code,

                                    template_language   => v_template_language,

                                    template_territory  => v_template_territory,

                                    output_format       => v_output_format ) THEN



      p_error_message := 'Error al setear el Template Publisher';

      return 'E';



    END IF; 



    if not fnd_request.set_options('NO','YES',NULL,NULL) then

      v_message := fnd_message.get;

      p_error_message := 'Error ejecutando FND_REQUEST.SET_OPTIONS. ' || v_message || ' ' || sqlerrm;

      return 'W';

    end if;



    p_request_id := fnd_request.submit_request(

                                               p_application_short_name,

                                               p_concurrent_program,

                                               '',

                                               '',

                                               FALSE,

                                               p_argument1,                       -- Parametro 1

                                               p_argument2,                       -- Parametro 2

                                               p_argument3,                       -- Parametro 3

                                               p_argument4,                       -- Parametro 4

                                               p_argument5,                       -- Parametro 5

                                               p_argument6,                       -- Parametro 6

                                               p_argument7,                       -- Parametro 7

                                               p_argument8,                       -- Parametro 8

                                               p_argument9,                       -- Parametro 9

                                               p_argument10,                      -- Parametro 10

                                               p_argument11                       -- Parametro 11

                                               );





      if p_request_id = 0 then

        v_message := fnd_message.get;

        p_error_message := 'Error ejecutando el concurrente ' || p_concurrent_program || '. ' || v_message || ' ' || sqlerrm;

        return 'W';

      end if;



      commit;



      if not fnd_concurrent.wait_for_request(

                              p_request_id

                             ,10

                             ,18000

                             ,v_conc_phase

                             ,v_conc_status

                             ,v_conc_dev_phase

                             ,v_conc_dev_status

                             ,v_conc_message) then

        v_message := fnd_message.get;

        p_error_message := 'Error ejecutando FND_REQUEST.WAIT_FOR_REQUEST. ' || v_message || ' ' || sqlerrm;

        return 'W';

      end if;



      if v_conc_dev_phase != 'COMPLETE' or v_conc_dev_status != 'NORMAL' then

        v_message := fnd_message.get;

        p_error_message := 'Error en la ejecucion de la solicitud ' || to_char(p_request_id) || '. ' || v_message || ' ' || sqlerrm;

        return 'W';

      end if;



      print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.run_concurrent(-)');

      return 'S';



  exception

    when others then

      print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.run_concurrent(!)');

      p_error_message := 'Exception OTHERS en AJB_BC_ATIS_BATCH_INTERFACE_PK.run_concurrent: ' || sqlerrm;

      return 'E';



  end run_concurrent;



  function get_dimension_value (p_oracle_segment in varchar2

                               ,p_oracle_value   in varchar2

                               ,p_bc_dimension   in varchar2) return varchar2

  is

    v_bc_value  varchar2(20);

  begin





      select    bc_value

      into      v_bc_value

      from      ajc_bc_gl_mapping

      where     oracle_segment = p_oracle_segment

      and       oracle_value = p_oracle_value

      and       bc_dimension = p_bc_dimension

      and       nvl(active,'N') = 'Y';



      return v_bc_value;



  exception

    when no_data_found then

      return null;

    when others then

      print_log('p_oracle_segment:'||p_oracle_segment);

      print_log('p_oracle_value:'||p_oracle_value);

      print_log('p_bc_dimension:'||p_bc_dimension);

      print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value(!)');

      print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value Error:'||sqlerrm);

      return null;

  end get_dimension_value;



---------------------------------------------------------------------------------------------

  PROCEDURE insert_request_table  (p_status_code            IN OUT VARCHAR2,

                                   p_error_message          IN OUT VARCHAR2,

                                   p_record_count               IN NUMBER,

                                   --p_json_data                  IN CLOB,

                                   p_environment             IN VARCHAR2)

                                   --p_je_category_name           IN VARCHAR2)

   IS  

   BEGIN



          print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.insert_request_table (+)');





          insert into ajc_bc_atis_gl_requests

           (request_id,

            enviroment,

            record_count,

            --json_data,

            creation_date,

            created_by,

            last_update_date,

            last_updated_by)

          values

            (g_request_id,

             p_environment,

             p_record_count,

             --p_json_data,

             sysdate,

             g_user_id,

             sysdate,

             g_user_id);



        commit; --ver



        p_status_code := 'S';



        print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.insert_request_table (-)');



   exception

       when others then

          p_status_code := 'E';

          p_error_message := 'Error al insertar registro insert_request_table, Error: '||sqlerrm;

          print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.insert_request_table. Error: '||sqlerrm);

          print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.insert_request_table (!)');

   end insert_request_table;  





---------------------------------------------------------------------------------------------

  PROCEDURE insert_json_table (p_status_code            IN OUT VARCHAR2,

                               p_error_message          IN OUT VARCHAR2,

                               p_record_count               IN NUMBER,

                               p_json_number                IN NUMBER,

                               p_json_data                  IN CLOB)

   IS  

   BEGIN



          --print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.insert_json_table (+)');





          insert into ajc_bc_atis_gl_jsons

           (request_id,

            record_count,

            json_number,

            json_data,

            creation_date,

            created_by,

            last_update_date,

            last_updated_by)

          values

            (g_request_id,

             p_record_count,

             p_json_number,

             p_json_data,

             sysdate,

             g_user_id,

             sysdate,

             g_user_id);



        commit; --ver



        p_status_code := 'S';



        --print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.insert_json_table (-)');



   exception

       when others then

          p_status_code := 'E';

          p_error_message := 'Error al insertar registro insert_json_table, Error: '||sqlerrm;

          print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.insert_json_table. Error: '||sqlerrm);

          print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.insert_json_table (!)');

   end insert_json_table; 





---------------------------------------------------------------------------------------------

  PROCEDURE insert_gl_lines_table  (p_status_code           IN OUT VARCHAR2,

                                    p_error_message         IN OUT VARCHAR2,

                                    p_je_header_id              IN NUMBER,

                                    p_je_line_num               IN NUMBER,

                                    p_documentno                IN VARCHAR2,

                                    p_bc_account                IN VARCHAR2,

                                    p_company                   IN VARCHAR2,

                                    p_department                IN VARCHAR2,

                                    p_product                   IN VARCHAR2,

                                    p_destination               IN VARCHAR2,

                                    p_office                    IN VARCHAR2,

                                    p_origin                    IN VARCHAR2,

                                    p_division                  IN VARCHAR2,

                                    p_worksheet                 IN VARCHAR2,

                                    p_json_number               IN NUMBER)



   IS  

   BEGIN



          --print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.insert_gl_lines_table (+)');



          insert into ajc_bc_atis_gl_lines

           (request_id,

            json_number,

            je_header_id,

            je_line_num,

            documentno,

            bc_account,

            company,

            department,

            product,

            destination,

            office,

            origin,

            division,

            worksheet,

            status,

            creation_date,

            created_by,

            last_update_date,

            last_updated_by)

          values

            (g_request_id,

             p_json_number,

             p_je_header_id,

             p_je_line_num,

             p_documentno,

             p_bc_account,

             p_company,

             p_department,

             p_product,

             p_destination,

             p_office,

             p_origin,

             p_division,

             p_worksheet,

             'Pending',

             sysdate,

             g_user_id,

             sysdate,

             g_user_id);



        commit; --ver



        p_status_code := 'S';



        --print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.insert_gl_lines_table (-)');



   exception

       when others then

          p_status_code := 'E';

          p_error_message := 'Error al insertar registro insert_gl_lines_table, Error: '||sqlerrm;

          print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.insert_gl_lines_table. Error: '||sqlerrm);

          print_log('AJB_BC_ATIS_BATCH_INTERFACE_PK.insert_gl_lines_table (!)');

   end insert_gl_lines_table;  





-- Genero registros que seran enviados a BC, insertando en tabla del proceso y json por linea de asiento

---------------------------------------------------------------------------------------------------

  PROCEDURE insert_journals ( p_status          OUT VARCHAR2

                            , p_error_message   OUT VARCHAR2

                            , p_environment      IN VARCHAR2

                            , p_date_from        IN VARCHAR2

                            , p_date_to          IN VARCHAR2

                            , p_journalbatchname IN VARCHAR2 --DAILYINT

                            , p_bc_company_id    IN VARCHAR2

                            , p_count_created   OUT NUMBER)  

  IS



    CURSOR c_main

    IS

    SELECT   'GENERAL'                      journaltemplatename,

             p_journalbatchname             journalbatchname,

             --to_char(gjh.je_header_id)||'.'||to_char(gjl.effective_date,'YYYYMMDD')      documentNo,

             to_char(gjh.je_header_id)||'.'||to_char(gjh.default_effective_date,'YYYYMMDD')      documentNo,

             gjb.name                       batch_name,

             gjh.name                       journal_header_name,

             --to_char(gjl.effective_date,'YYYY-MM-DD')   postingdate,

             to_char(gjh.default_effective_date,'YYYY-MM-DD')   postingdate,

             gjs.user_je_source_name        userjesourcename,

             gjc.user_je_category_name      userjecategoryname,

             aba.bc_account                 account,

             --Dimensions

             gcc.segment1                                                                                           shortcutcimCode1, --Company

             --ltrim(gcc.segment1,'0')                                                                                shortcutcimCode1, --Company

             gcc.segment3                                                                                           shortcutcimCode2, --Department

             decode(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value (p_oracle_segment => 'SEGMENT4'

                                        ,p_oracle_value   => gcc.segment4

                                        ,p_bc_dimension   => 'DIVISION'), NULL,gcc.segment4,'000')                  shortcutcimCode3, --Product

             decode(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value (p_oracle_segment => 'SEGMENT5'

                                        ,p_oracle_value   => gcc.segment5

                                        ,p_bc_dimension   => 'OFFICE'), NULL,gcc.segment5,'000')                    shortcutdimCode4, --Destination

             nvl(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value (p_oracle_segment => 'SEGMENT5'

                                 ,p_oracle_value   => gcc.segment5

                                 ,p_bc_dimension   => 'OFFICE'),'000')                                              shortcutdimCode5, --Office

             gcc.segment6                                                                                           shortcutdimCode6, --Origin

            /*get_dimension_value (p_oracle_segment => 'SEGMENT4'

                                 ,p_oracle_value   => gcc.segment4

                                 ,p_bc_dimension   => 'DIVISION')                                                   shortcutdimCode7, --Division*/

             --Modified Khronus/MNazarre 20221206: Always send empty

             gcc.segment7                                                                                           shortcutdimCode7, --Intercompany

             --''                                                                                                     shortcutdimCode7, --Intercompany

             -- 20230829

             -- nvl(gjl.attribute11,'NA')                                                                              shortcutdimCode8, --Worksheet

             nvl(gjl.attribute11,'N/A')                                                                              shortcutdimCode8, --Worksheet

             -- 20230829

             --Dimensions

             gcc.segment2,

             gjh.je_header_id               jeheaderid,

             gjl.je_line_num                oraclelineno,

             gjh.currency_code              currencycode,

             to_char(gjh.currency_conversion_date,'YYYY-MM-DD')  currencyconversiondate,

             gjh.currency_conversion_rate   currencyconversionrate,

             gjh.currency_conversion_type   currencyconversiontype,

             nvl(gjl.entered_dr,0)          eneterddr,

             nvl(gjl.entered_cr,0)          eneterdcr,

             gjl.description                description,

             gjl.reference_1                reference1,

             gjl.reference_2                reference2,

             gjl.reference_3                reference3,

             gjl.reference_4                reference4,

             gjl.reference_5                reference5,

             gjl.reference_6                tkpostbatch,

             gjl.attribute11                woksheetnumber,

             gjl.attribute12                attribute12,

             gjl.attribute13                attribute13,  

             gjl.attribute4                 atisvendornum, 

             gjl.attribute5                 atisvendorname, 

             gjl.attribute8                 atiscurrcode, 

             gjl.attribute9                 atisamt, 

             gjl.attribute10                atis_exch_rate

    FROM  gl_je_lines gjl

         ,gl_je_headers gjh

         ,gl_je_batches gjb

         --,gl_code_combinations_kfv gcc

         ,gl_code_combinations gcc

         ,gl_je_sources gjs

         ,gl_sets_of_books gsob

         ,gl_sets_of_books_dfv gsob_dfv

         ,gl_je_categories gjc

         ,gl_periods gp

         ,ajc_bc_accounts aba

         ,ajc_bc_companies abc

   WHERE gjl.je_header_id = gjh.je_header_id

     AND gjh.je_batch_id = gjb.je_batch_id

     AND gjl.code_combination_id = gcc.code_combination_id

     AND gjl.set_of_books_id = gsob.set_of_books_id

     AND gjh.actual_flag = 'A'

     AND gjh.status = 'P'

     AND gp.period_set_name = gsob.period_set_name

     AND gsob.rowid = gsob_dfv.row_id

     AND gp.period_name = gjl.period_name

     AND gjl.period_name = gjh.period_name --Agregado performance

     AND gjh.je_source = gjs.je_source_name

     AND gjh.je_category = gjc.je_category_name

     --AND gjl.effective_date BETWEEN TO_DATE(p_date_from,'YYYY/MM/DD HH24:MI:SS') and to_date(substr(p_date_to,1,11)||'23:59:59','YYYY/MM/DD HH24:MI:SS') 

     AND gjh.default_effective_date BETWEEN TO_DATE(p_date_from,'YYYY/MM/DD HH24:MI:SS') and to_date(substr(p_date_to,1,11)||'23:59:59','YYYY/MM/DD HH24:MI:SS')

     AND gjs.user_je_source_name IN ('ATIS INVENTORY','ATIS REV CGS','ATIS TRAFFIC')     

     --AND gjc.user_je_category_name = NVL(p_je_category_name,gjc.user_je_category_name)

     AND gjs.user_je_source_name not in ('Payables','Consolidation') 

     --AND gjh.je_header_id = 1553965

    --AND gjb.name = 'ATIS INVENTORY 19171718: A 209543'

    /* AND gjl.attribute11 in ('2690187')

                            '2684577',

                            '2684705',

                            '2672730',

                            '2694057',

                            '2682250',

                            '2672696',

                            '2662821',

                            '2662957',

                            '2682278'

                            '2662939',

                            '2662940',

                            '2662941'

                            '2670928',

                            '2684578',

                            '2677365'

                            '2672771')*/

     AND gcc.segment2 = aba.oracle_account (+)

     AND abc.oracle_company_number = gcc.segment1

     AND abc.set_of_books_id = gsob.set_of_books_id

     AND abc.bc_company_id = p_bc_company_id

     -- 20221219 SBanchieri

     AND gjh.attribute5 IS NULL

     -- 20221219 SBanchieri

     -- 20230203

     -- ORDER BY gjl.je_header_id, gjl.je_line_num

     -- 20230203

     ;

     --agregado condicion

/*

     AND not exists (select 1 

                     from   ajc_bc_atis_gl_lines aa

                     where  aa.je_header_id = gjl.je_header_id

                     and    aa.je_line_num = gjl.je_line_num

                     and    aa.status = 'Success');*/



    v_count             NUMBER :=0;

    v_split_quantity    NUMBER :=0;

    v_json_number       NUMBER :=1;

    v_ticketing_number  NUMBER :=50; --90;

    r_id                VARCHAR2(20);

    v_clob_response     CLOB;

    v_error_message     VARCHAR2(2000);

    v_status            VARCHAR2(1);

    e_cust_exception    EXCEPTION;



  BEGIN



      print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.insert_journals (+). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));



      APEX_JSON.initialize_clob_output;



      APEX_JSON.open_object;



      APEX_JSON.open_array('requests'); -- requests: [





      FOR c_rec IN c_main LOOP

      BEGIN



        IF c_rec.account IS NULL THEN

            v_error_message := 'No existe Cuenta BC para la Cuenta '||c_Rec.segment2;

            RAISE e_cust_exception;

        END IF;



        v_count := v_count+1;

        r_id    := 'r'||v_count;



        v_split_quantity := v_split_quantity + 1;



        APEX_JSON.open_object; -- {

        APEX_JSON.write('method','POST');

        APEX_JSON.write('id',r_id);      

        APEX_JSON.write('url',utl_url.escape('companies('||p_bc_company_id||')/inboundGenJnlLinesINE'));



        APEX_JSON.open_object('headers'); -- headers{

            APEX_JSON.write('Content-Type','application/json');

            --APEX_JSON.write('Content-Type',utl_url.escape('application/json;IEEE754Compatible=true'));

        APEX_JSON.close_object; -- } headers



        APEX_JSON.open_object('body'); -- body{

            APEX_JSON.write('journaltemplatename',c_rec.journaltemplatename);

            APEX_JSON.write('journalbatchname',c_rec.journalbatchname);

            APEX_JSON.write('documentNo',c_rec.documentNo);

            APEX_JSON.write('postingdate',c_rec.postingdate);

            APEX_JSON.write('userjesourcename',c_rec.userjesourcename);

            APEX_JSON.write('userjecategoryname',c_rec.userjecategoryname);

            APEX_JSON.write('oracleBatchName',c_rec.batch_name);

            APEX_JSON.write('oracleJournalName',c_rec.journal_header_name);

            APEX_JSON.write('account',c_rec.account,true);



            --Modified Khronus/MNazarre 20221206: Send value only if it is mandatory

            --APEX_JSON.write('shortcutcimCode1',c_rec.shortcutcimCode1,true);

            /*IF ( ajc_bc_account_dim_pkg.account_dim_required(c_rec.account,'COMPANY') = 'Y' ) THEN

              APEX_JSON.write('shortcutcimCode1',c_rec.shortcutcimCode1,true);

            ELSE

              APEX_JSON.write('shortcutcimCode1','',true);

            END IF;*/

            APEX_JSON.write('shortcutcimCode1', ajc_bc_account_dim_pkg.account_dim_required(c_rec.account,'COMPANY',c_rec.shortcutcimCode1),true);





            --Modified Khronus/MNazarre 20221206: Send value only if it is mandatory

            --APEX_JSON.write('shortcutcimCode2',c_rec.shortcutcimCode2,true);

            /*IF ( ajc_bc_account_dim_pkg.account_dim_required(c_rec.account,'DEPARTMENT') = 'Y' ) THEN

              APEX_JSON.write('shortcutcimCode2',c_rec.shortcutcimCode2,true);

            ELSE

              APEX_JSON.write('shortcutcimCode2','',true);

            END IF;*/

            APEX_JSON.write('shortcutcimCode2', ajc_bc_account_dim_pkg.account_dim_required(c_rec.account,'DEPARTMENT',c_rec.shortcutcimCode2),true);



            --Modified Khronus/MNazarre 20221206: Send value only if it is mandatory

            --APEX_JSON.write('shortcutcimCode3',c_rec.shortcutcimCode3,true);

            /*IF ( ajc_bc_account_dim_pkg.account_dim_required(c_rec.account,'PRODUCT') = 'Y' ) THEN

              APEX_JSON.write('shortcutcimCode3',c_rec.shortcutcimCode3,true);

            ELSE

              APEX_JSON.write('shortcutcimCode3','',true);

            END IF;*/

            APEX_JSON.write('shortcutcimCode3',ajc_bc_account_dim_pkg.account_dim_required(c_rec.account,'PRODUCT',c_rec.shortcutcimCode3),true);



            --Modified Khronus/MNazarre 20221206: Send value only if it is mandatory

            --APEX_JSON.write('shortcutdimCode4',c_rec.shortcutdimCode4,true);

            /*IF ( ajc_bc_account_dim_pkg.account_dim_required(c_rec.account,'DESTINATION') = 'Y' ) THEN

              APEX_JSON.write('shortcutdimCode4',c_rec.shortcutdimCode4,true);

            ELSE

              APEX_JSON.write('shortcutdimCode4','',true);

            END IF;*/

            APEX_JSON.write('shortcutdimCode4', ajc_bc_account_dim_pkg.account_dim_required(c_rec.account,'DESTINATION',c_rec.shortcutdimCode4),true);



            --Modified Khronus/MNazarre 20221206: Send value only if it is mandatory

            --APEX_JSON.write('shortcutdimCode5',c_rec.shortcutdimCode5,true);

            /*IF ( ajc_bc_account_dim_pkg.account_dim_required(c_rec.account,'OFFICE') = 'Y' ) THEN

              APEX_JSON.write('shortcutdimCode5',c_rec.shortcutdimCode5,true);

            ELSE

              APEX_JSON.write('shortcutdimCode5','',true);

            END IF;*/

            APEX_JSON.write('shortcutdimCode5',ajc_bc_account_dim_pkg.account_dim_required(c_rec.account,'OFFICE',c_rec.shortcutdimCode5),true);



            --Modified Khronus/MNazarre 20221206: Send value only if it is mandatory

            --APEX_JSON.write('shortcutdimCode6',c_rec.shortcutdimCode6,true);

            /*IF ( ajc_bc_account_dim_pkg.account_dim_required(c_rec.account,'ORIGIN') = 'Y' ) THEN

              APEX_JSON.write('shortcutdimCode6',c_rec.shortcutdimCode6,true);

            ELSE

              APEX_JSON.write('shortcutdimCode6','',true);

            END IF;*/

            APEX_JSON.write('shortcutdimCode6',ajc_bc_account_dim_pkg.account_dim_required(c_rec.account,'ORIGIN',c_rec.shortcutdimCode6),true);



            --Modified Khronus/MNazarre 20221206: Send value only if it is mandatory

            --APEX_JSON.write('shortcutdimCode7',c_rec.shortcutdimCode7,true);

            APEX_JSON.write('shortcutdimCode7','',true);



            --Modified Khronus/MNazarre 20221206: Send value only if it is mandatory

            --APEX_JSON.write('shortcutdimCode8',c_rec.shortcutdimCode8,true);

            /*IF ( ajc_bc_account_dim_pkg.account_dim_required(c_rec.account,'WORKSHEET') = 'Y' ) THEN

              APEX_JSON.write('shortcutdimCode8',c_rec.shortcutdimCode8,true);

            ELSE

              APEX_JSON.write('shortcutdimCode8','',true);

            END IF;*/

            APEX_JSON.write('shortcutdimCode8',ajc_bc_account_dim_pkg.account_dim_required(c_rec.account,'WORKSHEET',c_rec.shortcutdimCode8),true);





            APEX_JSON.write('jeheaderid',c_rec.jeheaderid);

            APEX_JSON.write('currencycode',c_rec.currencycode);

            APEX_JSON.write('currencyconversiondate',c_rec.currencyconversiondate,true);

            APEX_JSON.write('currencyconversionrate',c_rec.currencyconversionrate,true);

            APEX_JSON.write('currencyconversiontype',c_rec.currencyconversiontype,true);

            APEX_JSON.write('eneterddr',c_rec.eneterddr);

            APEX_JSON.write('eneterdcr',c_rec.eneterdcr);

--            APEX_JSON.write('eneterddr',to_number(c_rec.eneterddr));

--            APEX_JSON.write('eneterdcr',to_number(c_rec.eneterdcr));

            APEX_JSON.write('description',c_rec.description,true);

            APEX_JSON.write('reference1',c_rec.reference1,true);

            APEX_JSON.write('reference2',c_rec.reference2,true);

            APEX_JSON.write('reference3',c_rec.reference3,true);

            APEX_JSON.write('reference4',c_rec.reference4,true);

            APEX_JSON.write('reference5',c_rec.reference5,true);

            APEX_JSON.write('tkpostbatch',c_rec.tkpostbatch);

            APEX_JSON.write('woksheetnumber',c_rec.woksheetnumber);

            APEX_JSON.write('oraclelineno',c_rec.oracleLineNo,true);

            APEX_JSON.write('attribute12',c_rec.attribute12,true);

            APEX_JSON.write('attribute13',c_rec.attribute13,true);

            APEX_JSON.write('atisvendornum',c_rec.atisvendornum,true);

            APEX_JSON.write('atisvendorname',c_rec.atisvendorname,true);

            APEX_JSON.write('atiscurrcode',c_rec.atiscurrcode,true);

            APEX_JSON.write('atisamt',c_rec.atisamt,true);

            APEX_JSON.write('atisexchrate',c_rec.atis_exch_rate,true);

            APEX_JSON.write('requestID',g_request_id,true);

        APEX_JSON.close_object; -- } body



        APEX_JSON.close_object; -- }



        insert_gl_lines_table(p_status_code          => v_status

                             ,p_error_message        => v_error_message

                             ,p_je_header_id         => c_rec.jeheaderid

                             ,p_je_line_num          => c_rec.oraclelineno

                             ,p_documentno           => c_rec.documentNo

                             ,p_bc_account           => c_rec.account

                             ,p_company              => c_rec.shortcutcimCode1

                             ,p_department           => c_rec.shortcutcimCode2

                             ,p_product              => c_rec.shortcutcimCode3

                             ,p_destination          => c_rec.shortcutdimCode4

                             ,p_office               => c_rec.shortcutdimCode5

                             ,p_origin               => c_rec.shortcutdimCode6

                             ,p_division             => c_rec.shortcutdimCode7

                             ,p_worksheet            => c_rec.shortcutdimCode8

                             ,p_json_number          => v_json_number);





        IF v_status != 'S' THEN

           IF v_status = 'W' THEN

              RAISE e_cust_exception;

           ELSE

              RAISE e_cust_exception;

           END IF;

        END IF;



        --Valido si llego al limite de registros a enviar

        IF v_split_quantity = v_ticketing_number THEN



            APEX_JSON.close_array; -- ] requests



            APEX_JSON.close_object;





            insert_json_table(p_status_code          => v_status

                             ,p_error_message        => v_error_message

                             ,p_record_count         => v_split_quantity

                             ,p_json_number          => v_json_number

                             ,p_json_data            => APEX_JSON.get_clob_output);



            v_split_quantity :=0;

            v_json_number := v_json_number + 1;



            --Libero memoria

            APEX_JSON.free_output;



            --Vuelvo a inciar Clob

            APEX_JSON.initialize_clob_output;



            APEX_JSON.open_object;



            APEX_JSON.open_array('requests'); -- requests: [



            IF v_status != 'S' THEN

               IF v_status = 'W' THEN

                  RAISE e_cust_exception;

               ELSE

                  RAISE e_cust_exception;

               END IF;

            END IF;



        END IF;



      EXCEPTION

        WHEN e_cust_exception THEN

            v_error_message := 'Error al crear detalle de JSON para Lote: '||c_Rec.batch_name||' Asiento '||c_Rec.journal_header_name||' Linea '||c_rec.oracleLineNo||', Error:'||v_error_message;

            RAISE e_cust_exception;

        WHEN others THEN

            v_error_message := 'Error general al crear detalle de JSON para Lote: '||c_Rec.batch_name||' Asiento '||c_Rec.journal_header_name||' Linea '||c_rec.oracleLineNo||', Error:'||sqlerrm;

            RAISE e_cust_exception;

      END;

      END LOOP;



    p_count_created := v_count;



    IF v_split_quantity > 0 THEN



        APEX_JSON.close_array; -- ] requests



        APEX_JSON.close_object;



        --v_json_number := v_json_number + 1;



        insert_json_table(p_status_code          => v_status

                         ,p_error_message        => v_error_message

                         ,p_record_count         => v_split_quantity

                         ,p_json_number          => v_json_number

                         ,p_json_data            => APEX_JSON.get_clob_output);





        --Libero memoria

        APEX_JSON.free_output;



        IF v_status != 'S' THEN

           IF v_status = 'W' THEN

              RAISE e_cust_exception;

           ELSE

              RAISE e_cust_exception;

           END IF;

        END IF;



    END IF;



    insert_request_table(p_status_code          => v_status

                        ,p_error_message        => v_error_message

                        ,p_record_count         => v_count

                        --,p_json_data            => APEX_JSON.get_clob_output

                        ,p_environment          => p_environment);





    IF v_status != 'S' THEN

       IF v_status = 'W' THEN

          RAISE e_cust_exception;

       ELSE

          RAISE e_cust_exception;

       END IF;

    END IF;



    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.insert_journals (-). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));





  EXCEPTION

    WHEN e_cust_exception THEN

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.insert_journals (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));

    WHEN others THEN

        v_error_message := 'Error no atrapado al crear listado JSON, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.insert_journals (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));

  END insert_journals;







   --Llamo al Web Service que borra tablas de staging de General Journals en BC

  PROCEDURE call_ws_delete (p_status        IN OUT VARCHAR2

                           ,p_error_message IN OUT VARCHAR2

                           ,p_environment       IN VARCHAR2

                           ,p_bc_company_id     IN VARCHAR2)

  IS



    v_status            VARCHAR2(1);

    v_error_message     VARCHAR2(2000);

    e_cust_exception    EXCEPTION;

    v_clob_response     CLOB;

    --v_json_data         CLOB;

    v_get_api           VARCHAR2(100) := 'inboundGenJnlLinesINE';

    v_url               VARCHAR2(200);



  BEGIN



    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_delete (+). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));





--    print_log('Username: '||ajc_bc_ws_utils_pkg.gv_bc_user);

--    print_log('Password: '||ajc_bc_ws_utils_pkg.gv_bc_user_access_key);





    v_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f (p_environment   => p_environment,

                                                        p_company_id    => p_bc_company_id);



    print_log('Url: '||v_url);



    v_url := v_url||'/'||v_get_api||'('||g_request_id||')'; 



    v_clob_response := ajc_bc_ws_utils_pkg.delete_bc_row_f(v_url);



    IF ( INSTR(v_clob_response,'error') != 0 ) THEN

        v_error_message := substr(v_clob_response,INSTR(v_clob_response,'message')+9,length(v_clob_response));

        RAISE e_cust_exception;

    ELSE

        p_status:='S';

    END IF; 



    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_delete (-). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));   



  EXCEPTION

    WHEN e_cust_exception THEN

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_delete (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));

    WHEN others THEN

        v_error_message := 'Error no atrapado al Web Service Delete General Journal Inbounds, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_delete (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));

  END call_ws_delete;



   --Llamo al Web Service que inserta en tablas de staging de General Journals en BC

  PROCEDURE call_ws_journals (p_status        IN OUT VARCHAR2

                             ,p_error_message IN OUT VARCHAR2

                             ,p_environment       IN VARCHAR2

                             ,p_bc_company_id     IN VARCHAR2)

  IS



      CURSOR c_jsons IS

      SELECT replace(json_data,'\/','/') json_data

             ,json_number

        FROM ajc_bc_atis_gl_jsons

       WHERE request_id = g_request_id

    ORDER BY json_number;



    v_status                  VARCHAR2(1);

    v_error_message           VARCHAR2(2000);

    e_cust_exception          EXCEPTION;

    v_clob_response           CLOB;

    -- v_json_data               CLOB;



    v_base_inecta_batch_url   VARCHAR2(300);



    v_url                     VARCHAR2(200);



  BEGIN



    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_journals (+). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));



  /*

    BEGIN

        SELECT  replace(json_data,'\/','/') --modificado

        INTO    v_json_data

        FROM    ajc_bc_atis_gl_requests

        WHERE   request_id = g_request_id;

    EXCEPTION

        WHEN NO_DATA_FOUND THEN

            v_error_message := 'No se encuentra registro en tabla  ajc_bc_atis_gl_requests para el Request ID:'||g_request_id;

            RAISE e_cust_exception;

        WHEN OTHERS THEN

            v_error_message := 'Error al obtener el Json generado para llamar al Web Service. Error: '||sqlerrm;

            RAISE e_cust_exception;

    END; */



--    print_log('Username: '||ajc_bc_ws_utils_pkg.gv_bc_user);

--    print_log('Password: '||ajc_bc_ws_utils_pkg.gv_bc_user_access_key);





    v_base_inecta_batch_url := ajc_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'BASE_INECTA_BATCH_URL' );



    -- 20230410 v_url := REPLACE(ajc_bc_ws_utils_pkg.gv_base_inecta_batch_url,'$ENV',p_environment);

    v_url := REPLACE(v_base_inecta_batch_url,'$ENV',p_environment);



    print_log('Url: '||v_url);





    FOR r_rec IN c_jsons LOOP

    BEGIN

        print_log('Json Data Number: '||r_rec.json_number);

        print_log(to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));



        apex_web_service.g_request_headers.delete;  

        apex_web_service.g_request_headers(1).name := 'Content-Type';  

        apex_web_service.g_request_headers(1).value := 'application/json;IEEE754Compatible=true';

        --apex_web_service.g_request_headers(1).value := utl_url.escape('application/json;IEEE754Compatible=true');



        print_log('apex_web_service.g_request_headers(1).value: '||apex_web_service.g_request_headers(1).value);

        --Ver gv_base_inecta_url



        --Conexion user/pass

        /*v_clob_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(p_url         =>utl_url.escape('http://lbdck.ajc.bz:8084/bc/v2.0/d177100e-4225-4db2-a0af-d7a0feae584f/'||p_environment||'/api/inecta/ajcg/v2.0/$batch')

                                                             ,p_http_method => 'POST'

                                                             ,p_body        => r_rec.json_data

                                                             ,p_username    => ajc_bc_ws_utils_pkg.gv_bc_user

                                                             ,p_password    => ajc_bc_ws_utils_pkg.gv_bc_user_access_key

                                                              );*/



        v_clob_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(p_url         => utl_url.escape(v_url) -- utl_url.escape('http://lbdck.ajc.bz:8084/bc/v2.0/d177100e-4225-4db2-a0af-d7a0feae584f/'||p_environment||'/api/inecta/ajcg/v2.0/$batch')

                                                             ,p_http_method => 'POST'

                                                             ,p_body        => r_rec.json_data

                                                             ,p_credential_static_id => 'BC_Prod'

                                                             ,p_token_url            => 'http://lbdck.ajc.bz:8085/bc/d177100e-4225-4db2-a0af-d7a0feae584f/oauth2/v2.0/token'

                                                              );



        -- 20230911

        /*

        v_clob_response := ajc_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_url)

                                                                    ,p_request_header_name1 => 'Content-Type'

                                                                    ,p_request_header_value1 => 'application/json;IEEE754Compatible=true'

                                                                    ,p_request_header_name2 => NULL

                                                                    ,p_request_header_value2 => NULL

                                                                    ,p_http_method => 'POST'

                                                                    ,p_body => r_rec.json_data );

        */

        -- 20230911



        /*

        v_clob_response := ajc_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url                      => 'http://lbdck.ajc.bz:8084/bc/v2.0/d177100e-4225-4db2-a0af-d7a0feae584f/Sandbox/api/inecta/ajcg/v2.0/$batch' --v_url

                                                                    ,p_request_header_name1     => 'Content-Type' --'Content-Type'

                                                                    ,p_request_header_value1    => 'application/json;IEEE754Compatible=true'--'application/json'

                                                                    ,p_request_header_name2     => null

                                                                    ,p_request_header_value2    => null

                                                                    ,p_http_method              => 'POST'

                                                                    ,p_body                     => v_json_data);

        */





        BEGIN

            UPDATE  ajc_bc_atis_gl_jsons

            SET     json_data_response = v_clob_response

                   ,last_update_date = sysdate

            WHERE   request_id = g_request_id

            AND     json_number = r_rec.json_number;



            commit; --ver



        EXCEPTION

            WHEN OTHERS THEN

                v_error_message := 'Error al Actualizar tabla ajc_bc_atis_gl_requests con respuesta generada al llamar al Web Service. Error: '||sqlerrm;

                RAISE e_cust_exception;

        END; 





        -- 20230203 -- Se cambia porque hay un asiento que en la descripcion dice la palabra error y esta logica

        -- interpreta que fallo el asiento, cuando no es correcto

        -- IF ( INSTR(v_clob_response,'error') != 0 ) THEN

        IF ( INSTR(v_clob_response,'%"error":%') != 0 ) THEN

        -- 20230203

            v_error_message := substr(v_clob_response,INSTR(v_clob_response,'error'),length(v_clob_response));

            RAISE e_cust_exception;

        ELSE

            p_status:='S';

        END IF;





    EXCEPTION

    WHEN e_cust_exception THEN

        v_error_message := 'Error al procesar JSON nro: '||r_Rec.json_number||', Error:'||v_error_message;

        RAISE e_cust_exception;

    WHEN others THEN

        v_error_message := 'Error general al procesar JSON nro: '||r_Rec.json_number||', Error:'||sqlerrm;

        RAISE e_cust_exception;

    END;

    END LOOP;





    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_journals (-). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));   



  EXCEPTION

    WHEN e_cust_exception THEN

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_journals (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));

    WHEN others THEN

        v_error_message := 'Error no atrapado al Web Service General Journal Inbounds, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_journals (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));

  END call_ws_journals;





  --Llamo al Web Service que ejecuta Job que procesa tablas de Journals de General Journals en BC

  PROCEDURE call_ws_job (p_status        IN OUT VARCHAR2

                        ,p_error_message IN OUT VARCHAR2

                        ,p_environment       IN VARCHAR2

                        ,p_bc_company_id     IN VARCHAR2)

  IS



    v_job_object_id     NUMBER;

    v_status            VARCHAR2(1);

    v_error_message     VARCHAR2(2000);

    e_cust_exception    EXCEPTION;

    v_clob_response     CLOB;



  BEGIN



    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_job (+). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));



    v_job_object_id := ajc_bc_ws_utils_pkg.get_object_id_f ( 'JOURNALS' ); 

    print_log ( 'v_job_object_id: ' || v_job_object_id );



    /*v_clob := ajc_bc_ws_utils_pkg.run_job_queue_f  ( p_environment=>'Sandbox'

                                                ,p_company_id=>'c9225800-2b58-ec11-9f08-002248210987'

                                                ,p_object_id=>70010);*/



    --v_clob_response := ajc_bc_ws_utils_pkg.run_job_queue_f (p_environment   => p_environment --quitar

    /*

    v_clob_response := ajc_bc_ws_utils_pkg.run_job_queue_token_v2_f (p_environment   => p_environment

                                                                    ,p_company_id    => p_bc_company_id

                                                                    ,p_object_id     => v_job_object_id);

    */



    -- 20230911

    v_clob_response := ajc_bc_ws_utils_pkg.run_job_queue_f ( p_environment => p_environment

                                                            ,p_company_id => p_bc_company_id

                                                            ,p_object_id => v_job_object_id 

                                                            ,p_seconds_to_wait => 1 );

    -- 20230911



    BEGIN

        UPDATE  ajc_bc_atis_gl_requests

        SET     json_job_response = v_clob_response

               ,last_update_date = sysdate

        WHERE   request_id = g_request_id;



        commit; --ver



    EXCEPTION

        WHEN OTHERS THEN

            v_error_message := 'Error al Actualizar tabla ajc_bc_atis_gl_requests con respuesta generada al llamar al Web Service. Error: '||sqlerrm;

            RAISE e_cust_exception;

    END; 





    IF replace(substr(v_clob_response,INSTR(v_clob_response,'"value"')+8,length(v_clob_response)),'}') in ('"Success"','""','"Job Queue Scheduled successfully."') THEN

        p_status:='S';

    ELSE

        v_error_message := 'Error al llamar al Job, Mensaje: ' || replace(substr(v_clob_response,INSTR(v_clob_response,'"value"')+8,length(v_clob_response)),'}');

        print_log(v_clob_response);

        RAISE e_cust_exception;

      END IF;





    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_job (-). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));   



  EXCEPTION

    WHEN e_cust_exception THEN

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_job (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));

    WHEN others THEN

        v_error_message := 'Error no atrapado al llamar Web Service de Job, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_job (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));

  END call_ws_job;





  --Llamo al Web Service que consulta las tablas de staging de Journals de General Journals en BC para registros pendientes

  PROCEDURE call_ws_staging_pending (p_status        IN OUT VARCHAR2

                                    ,p_error_message IN OUT VARCHAR2

                                    ,p_pending_rows     OUT VARCHAR2

                                    ,p_environment       IN VARCHAR2

                                    ,p_bc_company_id     IN VARCHAR2)

  IS



    v_status            VARCHAR2(1);

    v_error_message     VARCHAR2(2000);

    e_cust_exception    EXCEPTION;

    v_clob_response     CLOB;

    v_count             NUMBER :=0;



    v_get_url           VARCHAR2(2000);

    v_get_api           VARCHAR2(100) := 'getInboundGenJnlLinesINE';



  BEGIN



    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_staging_pending (+). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));



    v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_environment, p_bc_company_id ) || v_get_api

                 || '?$filter=requestID eq ' ||g_request_id

                 ||' and status eq ''Pending''';





    LOOP



        DBMS_LOCK.sleep(seconds =>10*v_count);



        v_count := v_count+1;





        v_clob_response := ajc_bc_ws_utils_pkg.get_bc_clob_result_f (p_url => v_get_url);



        BEGIN

            select  count(1)

            into    p_pending_rows

            from

               (SELECT status

                FROM json_table( v_clob_response,

                                 '$.value[*]' COLUMNS ( status              VARCHAR2(4000)  path '$.status') ))

            where status ='Pending';

        EXCEPTION

            WHEN OTHERS THEN

                v_error_message := 'Error obteniendo cantidad de registros pendientes al llamar al Web Service getInboundGenJnlLinesINE. Error: '||sqlerrm;

                RAISE e_cust_exception;

        END; 



    EXIT WHEN p_pending_rows = 0 OR v_count = 20;

    END LOOP;



    print_log ('Number of pending records WS calls: '||v_count);

    print_log ('Number pending records: '||p_pending_rows);

    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_staging_pending (-). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));   



  EXCEPTION

    WHEN e_cust_exception THEN

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_staging_pending (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));

    WHEN others THEN

        v_error_message := 'Error no atrapado al llamar Web Service Staging Table, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_staging_pending (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));

  END call_ws_staging_pending;



  --Llamo al Web Service que consulta las tablas de staging de Journals de General Journals en BC                        

  PROCEDURE call_ws_staging (p_status        IN OUT VARCHAR2

                            ,p_error_message IN OUT VARCHAR2

                            ,p_environment       IN VARCHAR2

                            ,p_bc_company_id     IN VARCHAR2)

  IS



    v_status            VARCHAR2(1);

    v_error_message     VARCHAR2(2000);

    e_cust_exception    EXCEPTION;

    v_clob_response     CLOB;





    v_get_url           VARCHAR2(2000);

    v_get_api           VARCHAR2(100) := 'getInboundGenJnlLinesINE';



  BEGIN



    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_staging (+). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));



    v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_environment, p_bc_company_id ) || v_get_api

                 --|| '?$filter=documentNo eq ' ||''''||'TEST_INB_BATCH03'||'''';

                 --|| '?$filter=documentNo eq ' ||''''||'1554897.20211006'||''''; 

                 || '?$filter=requestID eq ' ||g_request_id;

                 --||'?$filter=StatusTimestamp ge ' || TO_CHAR(SYSDATE,'YYYY-MM-DD') || 'T00:00:00.000Z'; 





    print_log('v_get_url: '|| v_get_url);





    v_clob_response := ajc_bc_ws_utils_pkg.get_bc_clob_result_f (p_url => v_get_url);



    BEGIN

        UPDATE  ajc_bc_atis_gl_requests

        SET     json_staging_response = v_clob_response

               ,last_update_date = sysdate

        WHERE   request_id = g_request_id;



        commit; --ver



    EXCEPTION

        WHEN OTHERS THEN

            v_error_message := 'Error al Actualizar tabla ajc_bc_atis_gl_requests con respuesta generada al llamar al Web Service getInboundGenJnlLinesINE. Error: '||sqlerrm;

            RAISE e_cust_exception;

    END; 



    /*

    IF replace(substr(:v_clob_response,INSTR(:v_clob_response,'"value"')+8,length(:v_clob_response)),'}') = "Success" THEN

        p_status:='S';

    ELSE

        v_error_message := 'Error al llamar al Job, Mensaje: ' || replace(substr(:v_clob_response,INSTR(:v_clob_response,'"value"')+8,length(:v_clob_response)),'}');

        RAISE e_cust_exception;

      END IF;*/





    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_staging (-). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));   



  EXCEPTION

    WHEN e_cust_exception THEN

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_staging (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));

    WHEN others THEN

        v_error_message := 'Error no atrapado al llamar Web Service de Job, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.call_ws_staging (!). '||to_char(sysdate,'DD/MM/YYYY HH24:MI:SS'));

  END call_ws_staging;









  --Comparo las tablas de staging de Journals de General Journals en BC VS lo enviado           

  PROCEDURE validate_ws_data (p_status        IN OUT VARCHAR2

                             ,p_error_message IN OUT VARCHAR2)                        

  IS



    CURSOR c_lines (p_clob_result IN CLOB)

    IS

    SELECT systemid,

           journalTemplateName,

           journalBatchName,

           oracleLineNo,

           documentNo,

           postingDate,

           accountNo,

           creditAmount,

           debitAmount,        

           status,     

           statusRemarks,    

           statusTimestamp

    FROM json_table(p_clob_result,

                     '$.value[*]' COLUMNS ( systemid            VARCHAR2(4000)  path '$.systemId',

                                            journalTemplateName VARCHAR2(4000)  path '$.journalTemplateName',

                                            journalBatchName    VARCHAR2(4000)  path '$.journalBatchName',

                                            oracleLineNo        VARCHAR2(4000)  path '$.oracleLineNo',

                                            documentNo          VARCHAR2(4000)  path '$.documentNo',

                                            postingDate         VARCHAR2(4000)  path '$.postingDate', 

                                            accountNo           VARCHAR2(4000)  path '$.accountNo',

                                            creditAmount        VARCHAR2(4000)  path '$.creditAmount',

                                            debitAmount         VARCHAR2(4000)  path '$.debitAmount',

                                            status              VARCHAR2(4000)  path '$.status', 

                                            statusRemarks       VARCHAR2(4000)  path '$.statusRemarks',

                                            statusTimestamp     VARCHAR2(4000)  path '$.statusTimestamp') );





    v_status            VARCHAR2(1);

    v_error_message     VARCHAR2(2000);

    v_clob_result       CLOB;

    e_cust_exception    EXCEPTION;



  BEGIN



    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.validate_ws_data (+)');



    BEGIN

        SELECT  json_staging_response

        INTO    v_clob_result

        FROM    ajc_bc_atis_gl_requests

        WHERE   request_id = g_request_id;

    EXCEPTION

        WHEN OTHERS THEN

            v_error_message := 'Error al obtener json almacenado en tabla ajc_bc_atis_gl_requests del Web Service getInboundGenJnlLinesINE. Error: '||sqlerrm;

            RAISE e_cust_exception;

    END;



    FOR r_line IN c_lines (v_clob_result) LOOP

    BEGIN



           UPDATE   ajc_bc_atis_gl_lines abagl

           SET      status = r_line.status

                   ,error_message = r_line.statusRemarks

                   ,last_update_date = sysdate

           WHERE    abagl.documentNo = r_line.documentNo

           AND      abagl.je_line_num = r_line.oracleLineNo

           AND      request_id = g_request_id;

--           AND      abagl.je_header_id = r.jeheaderid



    EXCEPTION

        WHEN OTHERS THEN

            v_error_message := 'Error al Actualizar tabla ajc_bc_atis_gl_lines con respuesta generada al llamar al Web Service getInboundGenJnlLinesINE. Error: '||sqlerrm;

            RAISE e_cust_exception;

    END;    

    END LOOP;



    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.validate_ws_data (-)');   



  EXCEPTION

    WHEN e_cust_exception THEN

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.validate_ws_data (!)');

    WHEN others THEN

        v_error_message := 'Error no atrapado al actualizar lineas de asientos enviadas por el proceso, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.validate_ws_data (!)');

  END validate_ws_data;





  PROCEDURE send_mail  (p_status                OUT VARCHAR2,

                        p_error_message         OUT VARCHAR2,

                        p_to_address         IN     VARCHAR2,

                        p_from_address       IN     VARCHAR2,

                        p_cc_address         IN     VARCHAR2,

                        p_bcc_address        IN     VARCHAR2,

                        p_reply_to_address   IN     VARCHAR2,

                        p_subject            IN     VARCHAR2,

                        p_body_text          IN     VARCHAR2,

                        p_attachment1        IN     VARCHAR2,

                        p_attachment2        IN     VARCHAR2,

                        p_attachment_name1   IN     VARCHAR2,

                        p_attachment_name2   IN     VARCHAR2)

   AS

      CRLF CONSTANT             VARCHAR2 (10) := UTL_TCP.CRLF;

      BOUNDARY CONSTANT         VARCHAR2 (256) := '-----7D81B75CCC90D2974F7A1CBD';

      FIRST_BOUNDARY CONSTANT   VARCHAR2 (256) := '--' || BOUNDARY || CRLF;

      LAST_BOUNDARY CONSTANT VARCHAR2 (256) := '--' || BOUNDARY || '--' || CRLF ;

      MULTIPART_MIME_TYPE CONSTANT VARCHAR2 (256)  := 'multipart/mixed; boundary="' || BOUNDARY || '"' ;

      MIME_TYPE CONSTANT        VARCHAR2 (255) := 'text; charset=us-ascii'; --'text/html';

      TZ_OFFSET                 NUMBER := 0;

      mail_host                 VARCHAR2 (30) := g_mail_host;

      mail_conn                 UTL_SMTP.connection;



      PROCEDURE send_header (p_Name IN VARCHAR2, p_Header IN VARCHAR2)

      IS

      BEGIN

         UTL_SMTP.write_data (mail_conn,

                              p_Name || ': ' || p_Header || UTL_TCP.CRLF);

      END;



      PROCEDURE attach_bin (p_filename           IN VARCHAR2,

                            p_filename_newname   IN VARCHAR2)

      IS

         p_blob          BFILE;

         v_length        BINARY_INTEGER;

         v_raw           RAW (57);

         v_buffer_size   INTEGER := 57;

         i               INTEGER := 1;

         v_type          VARCHAR2 (3);

      BEGIN

         v_type :=

            UPPER(SUBSTR (p_filename_newname,

                          LENGTH (p_filename_newname) - 2,

                          3));

         UTL_SMTP.write_data (mail_conn, FIRST_BOUNDARY);



         IF v_type = 'ZIP'

         THEN

            send_header ('Content-Type', 'application/zip');

         ELSIF v_type = 'PDF'

         THEN

            send_header ('Content-Type', 'application/pdf');

         ELSIF v_type = 'DOC'

         THEN

            send_header ('Content-Type', 'application/msword');

         ELSIF v_type = 'XLS'

         THEN

            send_header ('Content-Type', 'application/excel');

         ELSIF v_type = 'GIF'

         THEN

            send_header ('Content-Type', 'image/gif');

         ELSIF v_type = 'BMP'

         THEN

            send_header ('Content-Type', 'image/bmp');

         ELSIF v_type = 'JPG'

         THEN

            send_header ('Content-Type', 'image/jpeg');

         ELSIF v_type = 'TXT'

         THEN

            send_header ('Content-Type', 'text/plain');

         ELSIF v_type = 'HTML'

         THEN

            send_header ('Content-Type', 'text/html');

         END IF;



         send_header ('Content-Transfer-Encoding', 'base64');

         send_header ('Content-Disposition',

                      'attachment; filename= ' || p_filename_newname);

         UTL_SMTP.write_data (mail_conn, CRLF);







         p_blob := BFILENAME ('BC_OUTDIR', p_filename);







         v_length := DBMS_LOB.getlength (p_blob);





         DBMS_LOB.open (p_blob, DBMS_LOB.lob_readonly);





         WHILE i < v_length

         LOOP

            DBMS_LOB.read (p_blob,

                           v_buffer_size,

                           i,

                           v_raw);

            UTL_SMTP.write_raw_data (mail_conn,

                                     UTL_ENCODE.base64_encode (v_raw));

            UTL_SMTP.write_data (mail_conn, UTL_TCP.crlf);

            i := i + v_buffer_size;

         END LOOP WHILE_LOOP;





         UTL_SMTP.write_data (mail_conn, UTL_TCP.crlf);



         DBMS_LOB.fileclose (p_blob);

      END;



      PROCEDURE attach_file (p_filename IN VARCHAR2)

      IS

         v_fh       UTL_FILE.file_type;

         vNewLine   VARCHAR2 (200);

      BEGIN

         UTL_SMTP.write_data (mail_conn, FIRST_BOUNDARY);

         send_header ('Content-Type', MIME_TYPE);

         send_header ('Content-Disposition',

                      'attachment; filename= ' || p_filename);

         UTL_SMTP.write_data (mail_conn, CRLF);



         v_fh := UTL_FILE.FOPEN ('c:\temp', p_filename, 'R');



         IF UTL_FILE.is_open (v_fh)

         THEN

            LOOP

               BEGIN

                  UTL_FILE.GET_LINE (v_fh, vNewLine);



                  IF vNewLine IS NULL

                  THEN

                     EXIT;

                  END IF;



                  UTL_SMTP.write_data (mail_conn, vNewLine);

                  UTL_SMTP.write_data (mail_conn, CRLF);

               EXCEPTION

                  WHEN NO_DATA_FOUND

                  THEN

                     EXIT;

               END;

            END LOOP;

         END IF;



         UTL_FILE.FCLOSE (v_fh);

      END;

   BEGIN

      BEGIN

         SELECT   TO_NUMBER (REPLACE (DBTIMEZONE, ':00')) / 24

           INTO   TZ_OFFSET

           FROM   DUAL;

      EXCEPTION

         WHEN OTHERS

         THEN

            NULL;

      END;





      mail_conn := UTL_SMTP.open_connection (mail_host, 25);

      UTL_SMTP.helo (mail_conn, mail_host);

      UTL_SMTP.mail (mail_conn, p_from_address);



      DECLARE

         v_var   VARCHAR2 (200) := p_to_address;

      BEGIN

         v_var := REPLACE (v_var, ',', ';');



         LOOP

            IF INSTR (v_var, ';') = 0

            THEN

               UTL_SMTP.rcpt (mail_conn, v_var);

               EXIT;

            END IF;



            UTL_SMTP.rcpt (mail_conn,

                           SUBSTR (v_var, 1, INSTR (v_var, ';') - 1));

            v_var := SUBSTR (v_var, INSTR (v_var, ';') + 1, LENGTH (v_var));

         END LOOP;

      END;





      IF p_cc_address IS NOT NULL

      THEN

         DECLARE

            v_var   VARCHAR2 (200) := p_cc_address;

         BEGIN

            v_var := REPLACE (v_var, ',', ';');



            LOOP

               IF INSTR (v_var, ';') = 0

               THEN

                  UTL_SMTP.rcpt (mail_conn, v_var);

                  EXIT;

               END IF;



               UTL_SMTP.rcpt (mail_conn,

                              SUBSTR (v_var, 1, INSTR (v_var, ';') - 1));

               v_var := SUBSTR (v_var, INSTR (v_var, ';') + 1, LENGTH (v_var));

            END LOOP;

         END;

      END IF;





      IF p_bcc_address IS NOT NULL

      THEN

         DECLARE

            v_var   VARCHAR2 (200) := p_bcc_address;

         BEGIN

            v_var := REPLACE (v_var, ',', ';');



            LOOP

               IF INSTR (v_var, ';') = 0

               THEN

                  UTL_SMTP.rcpt (mail_conn, v_var);

                  EXIT;

               END IF;



               UTL_SMTP.rcpt (mail_conn,

                              SUBSTR (v_var, 1, INSTR (v_var, ';') - 1));

               v_var := SUBSTR (v_var, INSTR (v_var, ';') + 1, LENGTH (v_var));

            END LOOP;

         END;

      END IF;



      UTL_SMTP.open_data (mail_conn);

      UTL_SMTP.write_data (mail_conn,

                           'Subject: ' || p_subject || UTL_TCP.crlf);



      UTL_SMTP.write_data (mail_conn,

                           'From: ' || p_from_address || UTL_TCP.crlf);

      UTL_SMTP.write_data (

         mail_conn,

            'Reply-To: '

         || NVL (p_reply_to_address, p_to_address)

         || UTL_TCP.crlf

      );



      DECLARE

         v_var   VARCHAR2 (200) := p_to_address;

      BEGIN

         v_var := REPLACE (v_var, ',', ';');



         LOOP

            IF INSTR (v_var, ';') = 0

            THEN

               UTL_SMTP.write_data (

                  mail_conn,

                  'To: "' || v_var || '" <' || v_var || '>' || UTL_TCP.crlf

               );

               EXIT;

            END IF;



            UTL_SMTP.write_data (

               mail_conn,

                  'To: "'

               || SUBSTR (v_var, 1, INSTR (v_var, ';') - 1)

               || '" <'

               || SUBSTR (v_var, 1, INSTR (v_var, ';') - 1)

               || '>'

               || UTL_TCP.crlf

            );

            v_var := SUBSTR (v_var, INSTR (v_var, ';') + 1, LENGTH (v_var));

         END LOOP;

      END;



      IF p_cc_address IS NOT NULL

      THEN

         DECLARE

            v_var   VARCHAR2 (200) := p_cc_address;

         BEGIN

            v_var := REPLACE (v_var, ',', ';');



            LOOP

               IF INSTR (v_var, ';') = 0

               THEN

                  UTL_SMTP.write_data (

                     mail_conn,

                        'CC: "'

                     || v_var

                     || '" <'

                     || v_var

                     || '>'

                     || UTL_TCP.crlf

                  );

                  EXIT;

               END IF;



               UTL_SMTP.write_data (

                  mail_conn,

                     'CC: "'

                  || SUBSTR (v_var, 1, INSTR (v_var, ';') - 1)

                  || '" <'

                  || SUBSTR (v_var, 1, INSTR (v_var, ';') - 1)

                  || '>'

                  || UTL_TCP.crlf

               );

               v_var := SUBSTR (v_var, INSTR (v_var, ';') + 1, LENGTH (v_var));

            END LOOP;

         END;

      END IF;



      IF p_bcc_address IS NOT NULL

      THEN

         DECLARE

            v_var   VARCHAR2 (200) := p_bcc_address;

         BEGIN

            v_var := REPLACE (v_var, ',', ';');



            LOOP

               IF INSTR (v_var, ';') = 0

               THEN

                  UTL_SMTP.write_data (

                     mail_conn,

                        'Bcc: "'

                     || v_var

                     || '" <'

                     || v_var

                     || '>'

                     || UTL_TCP.crlf

                  );

                  EXIT;

               END IF;



               UTL_SMTP.write_data (

                  mail_conn,

                     'Bcc: "'

                  || SUBSTR (v_var, 1, INSTR (v_var, ';') - 1)

                  || '" <'

                  || SUBSTR (v_var, 1, INSTR (v_var, ';') - 1)

                  || '>'

                  || UTL_TCP.crlf

               );

               v_var := SUBSTR (v_var, INSTR (v_var, ';') + 1, LENGTH (v_var));

            END LOOP;

         END;

      END IF;



      send_header ('Content-Type', MULTIPART_MIME_TYPE);

      -- Cierro el header con un CRLF

      UTL_SMTP.write_data (mail_conn, CRLF);



      --

      -- Body

      UTL_SMTP.write_data (mail_conn, FIRST_BOUNDARY);

      send_header ('Content-Type', MIME_TYPE);



      UTL_SMTP.write_data (mail_conn, CRLF);



      UTL_SMTP.write_data (mail_conn, p_body_text);

      UTL_SMTP.write_data (mail_conn, CRLF);



      IF p_attachment1 IS NOT NULL

      THEN

         attach_bin (p_attachment1, NVL (p_attachment_name1, p_attachment1));

      END IF;



      IF p_attachment2 IS NOT NULL

      THEN

         attach_bin (p_attachment2, NVL (p_attachment_name2, p_attachment2));

      END IF;



      UTL_SMTP.write_data (mail_conn, CRLF);

      UTL_SMTP.write_data (mail_conn, LAST_BOUNDARY);

      --

      UTL_SMTP.close_data (mail_conn);

      UTL_SMTP.quit (mail_conn);



      p_status := 'S';

   EXCEPTION

      WHEN OTHERS

      THEN

         UTL_SMTP.quit (mail_conn);

         p_status := 'E';

         p_error_message :=

            'Error no atrapado al enviar mail, Error: ' || SQLERRM;

   END send_mail;





  /*=========================================================================+

  |                                                                          |

  | Private Procedure                                                        |

  |    send_email                                                            |

  |                                                                          |

  | Description                                                              |

  |    Sent Email to IT Support                                              |

  |                                                                          |

  | Parameters                                                               |

  |                                                                          |

  +=========================================================================*/

  PROCEDURE send_email (p_status            OUT VARCHAR2

                       ,p_error_message     OUT VARCHAR2

                       ,p_subject            IN VARCHAR2

                       ,p_mail_list          IN VARCHAR2

                       ,p_request_id         IN NUMBER

                       ,p_report_request_id  IN NUMBER

                       ,p_date_from          IN VARCHAR2

                       ,p_date_to            IN VARCHAR2

                       ,p_bc_company_name    IN VARCHAR2

                       ,p_environment        IN VARCHAR2) 





  IS



    v_rejected_count   NUMBER;

    v_success_count    NUMBER;



    v_body_text        VARCHAR2(2000);

    v_actual_start_date DATE;

    v_attachment_name1 VARCHAR2(100);

    v_status           VARCHAR2(10);

    v_error_message    VARCHAR2(2000);

    e_cust_exception   EXCEPTION;





  BEGIN



    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.send_email (+)');



    SELECT  COUNT(1)

    INTO    v_success_count

    FROM    ajc_bc_atis_gl_lines

    WHERE   request_id = p_request_id

    AND     status = 'Success';



    print_log ( 'Success: ' || v_success_count );



    SELECT  COUNT(1)

    INTO    v_rejected_count

    FROM    ajc_bc_atis_gl_lines

    WHERE   request_id = p_request_id

    AND     status = 'Error';



    SELECT  actual_start_date

    INTO    v_actual_start_date

    FROM    fnd_concurrent_requests

    WHERE   request_id = p_request_id;



    print_log ( 'Error: ' || v_rejected_count );



    v_body_text := v_body_text ||'BC Company : '|| p_bc_company_name || CHR(13) || CHR(10);

    v_body_text := v_body_text ||'Environment : '|| p_environment || CHR(13) || CHR(10);

    v_body_text := v_body_text ||''|| CHR(13) || CHR(10);



    v_body_text := v_body_text ||'Parameters'|| p_bc_company_name || CHR(13) || CHR(10);

    v_body_text := v_body_text ||'Date From : '|| p_date_from || CHR(13) || CHR(10);

    v_body_text := v_body_text ||'Date To : '|| p_date_to || CHR(13) || CHR(10);



    v_body_text := v_body_text ||''|| CHR(13) || CHR(10);



    v_body_text := v_body_text ||'Comprobantes procesados con éxito: ' || v_success_count || CHR(13) || CHR(10);

    v_body_text := v_body_text || 'Comprobantes rechazados: ' || v_rejected_count || CHR(13) || CHR(10) || CHR(13) || CHR(10);

    v_body_text := v_body_text || 'Para mayor detalle, revise el output del request ' || p_report_request_id || '.'|| CHR(13) || CHR(10);

    v_body_text := v_body_text ||''|| CHR(13) || CHR(10);

    v_body_text := v_body_text ||'Fecha Inicio Concurrente '||to_char(v_actual_start_date,'DD/MON/YYYY HH24:MI:SS')|| CHR(13) || CHR(10);

    v_body_text := v_body_text ||'Fecha Fin Concurrente    '||to_char(sysdate,'DD/MON/YYYY HH24:MI:SS');





    print_log ( 'To: ' || p_mail_list );

    print_log ( 'Subject: ' || p_subject );

    print_log ( 'Message: ' || v_body_text );



    v_attachment_name1 := 'Detail Request ID '||p_report_request_id||'.xls';



--'appstech@ajcfood.com'





/*    ajc_bc_ws_utils_pkg.send_email ( p_to => p_mail_list

                                    ,p_subject => p_subject

                                    ,p_message => v_message );*/



    send_mail  (p_status            => v_status

               ,p_error_message     => v_error_message

               ,p_to_address        => p_mail_list                     --p_to_address

               ,p_from_address      => 'appstech@ajcfood.com'          --p_from_address 

               ,p_cc_address        => null                            --p_cc_address

               ,p_bcc_address       => null                            --p_bcc_address 

               ,p_reply_to_address  => 'appstech@ajcfood.com'          --p_reply_to_address

               ,p_subject           => p_subject                       --p_subject --'Envio de Documentos por Mail'

               ,p_body_text         => v_body_text                     --p_body_text

               ,p_attachment1       => ''--get_outfile_name(p_report_request_id) --p_attachment1

               ,p_attachment2       => ''                              --p_attachment2

               ,p_attachment_name1  => ''--v_attachment_name1              --p_attachment_name1

               ,p_attachment_name2  => ''                              --p_attachment_name2

               );                    



    if v_status != 'S' then

        print_log('Error llamando al proceso send_mail(!)');

        print_log(substr(v_error_message, 1, 255));

        raise e_cust_exception;

    end if;



    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.send_email (-)');    



  EXCEPTION

    WHEN e_cust_exception THEN

      print_log ( 'AJB_BC_ATIS_BATCH_INTERFACE_PK.send_email (!)' );  

      print_log ( 'Error: ' || v_error_message );

    WHEN others THEN

      print_log ( 'AJB_BC_ATIS_BATCH_INTERFACE_PK.send_email (!)' );  

      print_log ( 'Error: ' || SQLERRM );



  END send_email;





/*=========================================================================+

|                                                                          |

| Public Function                                                          |

|    main_process                                                          |

|                                                                          |

| Description                                                              |

|    ATIS GL/AR Batches Interface Main Process                             |

|    Concurrent Program Executable                                         |

|                                                                          |

|                                                                          |

| Parameters                                                               |

|    retcode                   OUT     NUMBER    Codigo Estado.            |

|    errbuf                    OUT     VARCHAR2  Mensaje de Finalizacion.  |

|                                                                          |

+=========================================================================*/

  PROCEDURE main_process   (retcode                   OUT NUMBER

                          , errbuf                    OUT VARCHAR2

                          , p_date_from                IN VARCHAR2

                          , p_date_to                  IN VARCHAR2

                          , p_journalbatchname         IN VARCHAR2 --DAILYINT

                          , p_bc_company_name          IN VARCHAR2

                          , p_environment               IN VARCHAR2

                          , p_mail_list                IN VARCHAR2

                          ) IS



    v_status          varchar2(1);

    v_error_message   varchar2(2000);

    e_cust_exception  exception;

    v_group_id        number;

    v_bc_company_id   varchar2(100);

    v_count_created   number;

    v_pending_rows    number :=-1;

    v_report_request_id number;



  BEGIN 



    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.main_process (+)');



    BEGIN

        SELECT  bc_company_id

        INTO    v_bc_company_id

        FROM    ajc_bc_companies

        WHERE   bc_company_name = p_bc_company_name

        GROUP BY bc_company_id;

    EXCEPTION

        WHEN NO_DATA_FOUND THEN

            v_error_message := 'No se encuentra la Compañia BC '||p_bc_company_name;

            RAISE e_cust_exception;

        WHEN OTHERS THEN

            v_error_message := 'Error al obtener el ID de la Compañia BC '||p_bc_company_name||'. Error: '||sqlerrm;

            RAISE e_cust_exception;

    END; 



    -- Genero registros que seran enviados a BC, insertando en tabla del proceso y json por linea de asiento

    insert_journals (p_status               => v_status

                    ,p_error_message        => v_error_message

                    ,p_environment          => p_environment

                    ,p_date_from            => p_date_from

                    ,p_date_to              => p_date_to

                    ,p_journalbatchname     => p_journalbatchname

                    ,p_bc_company_id        => v_bc_company_id

                    ,p_count_created        => v_count_created);





    IF v_status != 'S' THEN

       IF v_status = 'W' THEN

          retcode := 1;

          errbuf  := v_error_message;

       ELSE

            Raise e_cust_exception;

       END IF;

    END IF;





    IF NVL(v_count_created,0) > 0 THEN



        --Llamo al Web Service que inserta en tablas de staging de General Journals en BC

        call_ws_journals (p_status        => v_status

                         ,p_error_message => v_error_message

                         ,p_environment   => p_environment

                         ,p_bc_company_id => v_bc_company_id);





        IF v_status != 'S' THEN

          IF v_status = 'W' THEN

              retcode := 1;

              errbuf  := v_error_message;

          ELSE

              raise e_cust_exception;

          END IF;

        END IF;





        --Ver tema de Espera que termine el WS Job

        DBMS_LOCK.sleep(seconds =>10);





        --Llamo al Web Service que ejecuta Job que procesa tablas de Journals de General Journals en BC

        call_ws_job (p_status        => v_status

                    ,p_error_message => v_error_message

                    ,p_environment   => p_environment

                    ,p_bc_company_id => v_bc_company_id);





        IF v_status != 'S' THEN

          IF v_status = 'W' THEN

              retcode := 1;

              errbuf  := v_error_message;

          ELSE

              raise e_cust_exception;

          END IF;

        END IF;



        --Ver tema de Espera que termine el WS Job

        -- 20240503

        -- DBMS_LOCK.sleep(seconds => 3);

        print_log ('2024-05-27: Se esperan 180 segundos (3 minutos).');

        DBMS_LOCK.sleep(seconds => 180);

        -- 20240503



  --Llamo al Web Service que consulta las tablas de staging de Journals de General Journals en BC para registros pendientes

        call_ws_staging_pending (p_status        => v_status

                                ,p_error_message => v_error_message

                                ,p_pending_rows  => v_pending_rows

                                ,p_environment   => p_environment

                                ,p_bc_company_id => v_bc_company_id);





        IF v_status != 'S' OR v_pending_rows != 0 THEN

          IF v_status = 'W' THEN

              retcode := 1;

              errbuf  := v_error_message;

          ELSE

              raise e_cust_exception;

          END IF;

        END IF;



        --Llamo al Web Service que consulta las tablas de staging de Journals de General Journals en BC

        call_ws_staging (p_status        => v_status

                        ,p_error_message => v_error_message

                        ,p_environment   => p_environment

                        ,p_bc_company_id => v_bc_company_id);





        IF v_status != 'S' THEN

          IF v_status = 'W' THEN

              retcode := 1;

              errbuf  := v_error_message;

          ELSE

              raise e_cust_exception;

          END IF;

        END IF;





        --Comparo las tablas de staging de Journals de General Journals en BC VS lo enviado

        validate_ws_data (p_status        => v_status

                         ,p_error_message  => v_error_message);





        IF v_status != 'S' THEN

          IF v_status = 'W' THEN

              retcode := 1;

              errbuf  := v_error_message;

          ELSE

              raise e_cust_exception;

          END IF;

        END IF;



        IF ( p_environment LIKE 'Production%' ) THEN

            --Mark Journal with request_id in flexfield

            UPDATE  gl_je_headers gjh

            SET     attribute5 = g_request_id

            WHERE   gjh.je_header_id IN

                                       (SELECT  je_header_id

                                        FROM    ajc_bc_atis_gl_lines

                                        WHERE   status = 'Success'

                                        AND     request_id = g_request_id

                                        GROUP BY je_header_id);

        END IF;





/*

        --Genero output plano con report

        print_report (p_status        => v_status

                     ,p_error_message => v_error_message

                     ,p_group_id      => v_group_id);





        IF v_status != 'S' THEN

          IF v_status = 'W' THEN

              retcode := 1;

              errbuf  := v_error_message;

          ELSE

              raise e_cust_exception;

          END IF;

        END IF;

   */     



        -- Excel Publisher "AJC BC ATIS Journal Interface Report"

        v_status := run_concurrent(p_concurrent_program => 'AJCBCAJR'

                                  ,p_application_short_name => 'XXAJC'

                                  ,p_argument1 => g_request_id

                                  ,p_argument2 => v_bc_company_id

                                  ,p_argument3 => ''                                      

                                  ,p_argument4 => ''

                                  ,p_argument5 => ''

                                  ,p_argument6 => ''

                                  ,p_argument7 => ''

                                  ,p_argument8 => ''

                                  ,p_argument9 => ''

                                  ,p_request_id => v_report_request_id

                                  ,p_error_message => v_error_message);



        IF v_status != 'S' THEN

              print_log('Error running concurrent AJC BC ATIS Journal Interface Report, Executable: AJCBCAJR');

              print_log(substr(v_error_message, 1, 255));

              raise e_cust_exception;

        END IF;





        -- 20230317

        --Genero Excel Publisher para ser enviado por Email

        /* 

        send_email (p_status            => v_status

                   ,p_error_message     => v_error_message

                   ,p_subject           => 'Interface ATIS Journals to Business Central Request '||g_request_id

                   ,p_mail_list         => p_mail_list

                   ,p_request_id        => g_request_id

                   ,p_report_request_id => v_report_request_id

                   ,p_date_from         => p_date_from

                   ,p_date_to           => p_date_to

                   ,p_bc_company_name   => p_bc_company_name

                   ,p_environment       => p_environment);

        */



        ajc_bc_ws_utils_pkg.send_unix_mail_attach ( p_mail => p_mail_list,

                                                    p_report_request_id => v_report_request_id ); 

        -- 20230317



        IF v_status != 'S' THEN

          IF v_status = 'W' THEN

              retcode := 1;

              errbuf  := v_error_message;

          ELSE

              raise e_cust_exception;

          END IF;

        END IF;





        /*

        IF NVL(p_draft_flag,'N') = 'Y' THEN

            --limpio la tabla de interfaz 

            gl_rollback_all (p_status        => v_status

                            ,p_error_message => v_error_message

                            ,p_group_id      => v_group_id);



            IF v_status != 'S' THEN

              IF v_status = 'W' THEN

                  retcode := 1;

                  errbuf  := v_error_message;

              ELSE

                  raise e_cust_exception;

              END IF;

            END IF;



        END IF;*/



    ELSE



        print_output('No se recuperaron registros');



    END IF;



    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.main_process (-)');



    IF retcode IS NULL THEN

     retcode := 0;

    ELSE

     print_log (errbuf);

        IF NOT fnd_concurrent.set_completion_status('WARNING',errbuf) THEN

            print_log ('Error seteando estado de finalizacion');

        ELSE

            print_log ('Estado de finalizacion seteado');

        END IF; 

    END IF;          



  EXCEPTION

  WHEN e_cust_exception THEN



     retcode := 2;

     errbuf  := v_error_message;

     print_log (v_error_message);



   --Llamo al Web Service que borra tablas de staging de General Journals en BC

     call_ws_delete (p_status        => v_status

                    ,p_error_message => v_error_message

                    ,p_environment    => p_environment

                    ,p_bc_company_id => v_bc_company_id);





     IF v_status = 'E' THEN

        IF v_status = 'W' THEN

          print_log(v_error_message);

        ELSE

          raise e_cust_exception;

        END IF;

     END IF;



     RAISE_APPLICATION_ERROR(-20000,v_error_message);     

     print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.main_process (!)');

  WHEN others THEN





   --Llamo al Web Service que borra tablas de staging de General Journals en BC

     call_ws_delete (p_status        => v_status

                    ,p_error_message => v_error_message

                    ,p_environment    => p_environment

                    ,p_bc_company_id => v_bc_company_id);



     errbuf  := 'Error al Ejecutar el Proceso: '||SQLERRM;

     retcode := 2;

     print_log (errbuf);

     RAISE_APPLICATION_ERROR(-20000,errbuf);

     print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.main_process (!)');

  END main_process;



  -- 20231017

  -- Se envia los worksheets que no cumplen con la condicion de >= en el package ajc_bc_worksheets_pkg,

  -- porque son menores a 2706304

  PROCEDURE worksheet_exceptions_p ( p_bc_environment     IN   VARCHAR2,

                                     p_date_from          IN   VARCHAR2,

                                     p_status         IN OUT   VARCHAR2 ) IS



    v_request_id        NUMBER;

    v_conc_phase        VARCHAR2(50);

    v_conc_status       VARCHAR2(50);

    v_conc_dev_phase    VARCHAR2(50);

    v_conc_dev_status   VARCHAR2(50);

    v_conc_message      VARCHAR2(250);

    v_message           VARCHAR2(1000);

    v_error_message     VARCHAR2(2000);

    e_cust_exception    EXCEPTION;



      CURSOR c_worksheet_exceptions IS

      SELECT gjl.attribute11 worksheet

        FROM gl_je_lines gjl,

             gl_je_headers gjh,

             gl_je_batches gjb,

             gl_code_combinations gcc,

             gl_je_sources gjs,

             gl_sets_of_books gsob,

             gl_sets_of_books_dfv gsob_dfv,

             gl_je_categories gjc,

             gl_periods gp,

             ajc_bc_accounts aba,

             ajc_bc_companies abc

       WHERE gjl.je_header_id = gjh.je_header_id

         AND gjh.je_batch_id = gjb.je_batch_id

         AND gjl.code_combination_id = gcc.code_combination_id

         AND gjl.set_of_books_id = gsob.set_of_books_id

         AND gjh.actual_flag = 'A'

         AND gjh.status = 'P'

         AND gp.period_set_name = gsob.period_set_name

         AND gsob.rowid = gsob_dfv.row_id

         AND gp.period_name = gjl.period_name

         AND gjl.period_name = gjh.period_name -- Agregado performance

         AND gjh.je_source = gjs.je_source_name

         AND gjh.je_category = gjc.je_category_name

         AND gjh.default_effective_date >= TO_DATE(p_date_from,'YYYY/MM/DD HH24:MI:SS')

         AND gjh.default_effective_date >= TO_DATE('2023/07/02','YYYY/MM/DD')

         --

         AND gjs.user_je_source_name IN ('ATIS INVENTORY','ATIS REV CGS','ATIS TRAFFIC')     

         AND gjs.user_je_source_name NOT IN ('Payables','Consolidation') 

         AND gcc.segment2 = aba.oracle_account (+)

         AND abc.oracle_company_number = gcc.segment1

         AND abc.set_of_books_id = gsob.set_of_books_id

         AND gjh.attribute5 IS NULL

         AND NOT EXISTS ( SELECT 1

                            FROM ajc_bc_worksheets w

                           WHERE w.ws_ies_num = gjl.attribute11 )

         AND gjl.attribute11 < ( SELECT MIN(TO_CHAR(set_wrksht_num)) 

                                   FROM inventory_value )                        

    GROUP BY gjl.attribute11;



  BEGIN



    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.worksheet_exceptions_p (+)');



    FOR cwe IN c_worksheet_exceptions LOOP



      v_request_id := fnd_request.submit_request ( 'XXAJC',

                                                   'AJCBCWS', -- AJC BC Worksheets Interface

                                                    argument1 => p_bc_environment,

                                                    argument2 => cwe.worksheet ) ; 



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

        print_log('Error Ejecutando FND_REQUEST.WAIT_FOR_REQUEST. AJCBCWS - AJC BC Worksheets Interface con nro. solicitud ' || 

                  TO_CHAR (v_request_id) || '. Error: ' || v_message || ' ' || SQLERRM);

        RAISE e_cust_exception;



      END IF ;



      IF v_conc_dev_phase != 'COMPLETE' OR v_conc_dev_status != 'NORMAL' THEN



        v_error_message := fnd_message.get;

        print_log('Error en la ejecucion del concurrente AJCBCWS - AJC BC Worksheets Interface con nro. solicitud ' || 

                  TO_CHAR (v_request_id) || '. Error: ' || v_error_message || ' ' || SQLERRM);

        RAISE e_cust_exception;



      END IF ;



    END LOOP;



    p_status := 'S';

    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.worksheet_exceptions_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.worksheet_exceptions_p (!). Error: ' || SQLERRM);



  END worksheet_exceptions_p;

  -- 20231017



  -- 20221219 SBanchieri

  PROCEDURE pending_caller ( retcode             OUT   NUMBER,

                             errbuf              OUT   VARCHAR2,

                             p_date_from          IN   VARCHAR2,

                             p_journalbatchname   IN   VARCHAR2,

                             p_bc_environment     IN   VARCHAR2 ) IS



      CURSOR c_pending_journals IS

      SELECT -- TO_CHAR(MIN(gjh.default_effective_date),'YYYY/MM/DD HH24:MI:SS') date_from,

             TO_CHAR(gjh.default_effective_date,'YYYY/MM/DD HH24:MI:SS') date_from,

             -- TO_CHAR(MAX(gjh.default_effective_date),'YYYY/MM/DD HH24:MI:SS') date_to,

             TO_CHAR(gjh.default_effective_date,'YYYY/MM/DD HH24:MI:SS') date_to,

             abc.bc_company_id,

             abc.bc_company_name

        FROM gl_je_lines gjl,

             gl_je_headers gjh,

             gl_je_batches gjb,

             gl_code_combinations gcc,

             gl_je_sources gjs,

             gl_sets_of_books gsob,

             gl_sets_of_books_dfv gsob_dfv,

             gl_je_categories gjc,

             gl_periods gp,

             ajc_bc_accounts aba,

             ajc_bc_companies abc

       WHERE gjl.je_header_id = gjh.je_header_id

         AND gjh.je_batch_id = gjb.je_batch_id

         AND gjl.code_combination_id = gcc.code_combination_id

         AND gjl.set_of_books_id = gsob.set_of_books_id

         AND gjh.actual_flag = 'A'

         AND gjh.status = 'P'

         AND gp.period_set_name = gsob.period_set_name

         AND gsob.rowid = gsob_dfv.row_id

         AND gp.period_name = gjl.period_name

         AND gjl.period_name = gjh.period_name --Agregado performance

         AND gjh.je_source = gjs.je_source_name

         AND gjh.je_category = gjc.je_category_name

         AND gjh.default_effective_date >= TO_DATE(p_date_from,'YYYY/MM/DD HH24:MI:SS')

         AND gjh.default_effective_date >= TO_DATE('2023/07/02','YYYY/MM/DD')

         --

         AND gjs.user_je_source_name IN ('ATIS INVENTORY','ATIS REV CGS','ATIS TRAFFIC')     

         AND gjs.user_je_source_name NOT IN ('Payables','Consolidation') 

         AND gcc.segment2 = aba.oracle_account (+)

         AND abc.oracle_company_number = gcc.segment1

         AND abc.set_of_books_id = gsob.set_of_books_id

         -- AND abc.bc_company_id = p_bc_company_id

         -- AND TO_CHAR(gjh.default_effective_date,'YYYY/MM/DD HH24:MI:SS') = '2023/01/25 00:00:00'

         AND gjh.attribute5 IS NULL

    GROUP BY gjh.default_effective_date,

             abc.bc_company_id,

             abc.bc_company_name

    ORDER BY gjh.default_effective_date,

             abc.bc_company_id,

             abc.bc_company_name; 



    v_email             VARCHAR2(2000);

    v_status            VARCHAR2(1);

    v_request_id        NUMBER;

    v_conc_phase        VARCHAR2(50);

    v_conc_status       VARCHAR2(50);

    v_conc_dev_phase    VARCHAR2(50);

    v_conc_dev_status   VARCHAR2(50);

    v_conc_message      VARCHAR2(250);

    v_message           VARCHAR2(1000);

    v_error_message     VARCHAR2(2000);



    e_worksheet_exceptions   EXCEPTION;

    e_cust_exception         EXCEPTION;



  BEGIN



    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.pending_caller (+)');



    v_email := ajc_bc_ws_utils_pkg.get_emails_f ( 'JOURNALS' );



    print_log ( 'p_date_from: ' || p_date_from );

    print_log ( 'p_journalbatchname: ' || p_journalbatchname );

    print_log ( 'p_bc_environment: ' || p_bc_environment );

    print_log ( 'p_mail: ' || v_email );    



    -- 20231017

    worksheet_exceptions_p ( p_bc_environment => p_bc_environment,

                             p_date_from => p_date_from,

                             p_status => v_status );



    IF ( v_status != 'S' ) THEN



      RAISE e_worksheet_exceptions;



    END IF;

    -- 20231017



    -- 20230228

    -- Se ejecuta el concurrente AJC BC Worksheets Interface

    ajc_bc_worksheets_pkg.caller_p ( p_bc_environment => p_bc_environment );



    FOR cpj IN c_pending_journals LOOP



      BEGIN



        print_log ( 'Se llama al concurrente AJC BC ATIS Journal Interface' );

        print_log ( 'Date From: ' || cpj.date_from );

        print_log ( 'Date To: ' || cpj.date_to );

        print_log ( 'BC Company: ' || cpj.bc_company_name );

        print_log ( ' ' );



        -- AJC BC ATIS Journal Interface

        v_request_id := fnd_request.submit_request ( 'XXAJC',

                                                     'AJCBCAJL',

                                                     argument1 => cpj.date_from,

                                                     argument2 => cpj.date_to,

                                                     argument3 => p_journalbatchname,

                                                     argument4 => cpj.bc_company_name,

                                                     argument5 => p_bc_environment,

                                                     argument6 => v_email ) ;



        IF v_request_id = 0 THEN



          v_message := fnd_message.get;

          print_log('Error Ejecutando FND_REQUEST.SUBMIT_REQUEST. AJCBCAJL - AJC BC ATIS Journal Interface. Error: ' || v_message || ', ' || SQLERRM);

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

          print_log('Error Ejecutando FND_REQUEST.WAIT_FOR_REQUEST. AJCBCAJL - AJC BC ATIS Journal Interface con nro. solicitud ' || 

                    TO_CHAR (v_request_id) || '. Error: ' || v_message || ' ' || SQLERRM);

          RAISE e_cust_exception;



        END IF ;



        IF v_conc_dev_phase != 'COMPLETE' OR v_conc_dev_status != 'NORMAL' THEN



          v_error_message := fnd_message.get;

          print_log('Error en la ejecucion del concurrente AJCBCSIIR con nro. solicitud ' || 

                    TO_CHAR (v_request_id) || '. Error: ' || v_error_message || ' ' || SQLERRM);

          RAISE e_cust_exception;



        END IF ;



      EXCEPTION

        WHEN e_cust_exception THEN

          print_log('Error general caller: ' || SQLERRM);

          print_log('Se envia mail de error a agilardi@ajcgroup.com');



          ajc_bc_ws_utils_pkg.send_email ( p_to => 'agilardi@ajcgroup.com',

                                           p_subject => 'Error: AJC BC ATIS Journal Interface - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'),

                                           p_message => 'Revise el log del concurrente ' || v_request_id || ' para más detalle sobre el error.' );



      END;



    END LOOP;



    print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.pending_caller (-)');



  EXCEPTION

    WHEN e_worksheet_exceptions THEN

      print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.pending_caller (!)');

      ajc_bc_ws_utils_pkg.send_email ( p_to => 'agilardi@ajcgroup.com',

                                       p_subject => 'Error: AJC BC ATIS Journal Pending Interface - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'),

                                       p_message => 'Revise el log del concurrente ' || gv_request_id || ' para más detalle sobre el error.' );



    WHEN OTHERS THEN

      print_log('Error general caller: ' || SQLERRM);

      print_log ('AJB_BC_ATIS_BATCH_INTERFACE_PK.pending_caller (!)');

      ajc_bc_ws_utils_pkg.send_email ( p_to => 'agilardi@ajcgroup.com',

                                       p_subject => 'Error: AJC BC ATIS Journal Pending Interface - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'),

                                       p_message => 'Revise el log del concurrente ' || gv_request_id || ' para más detalle sobre el error.' );



  END pending_caller;

  -- 20221219 SBanchieri



END AJC_BC_ATIS_BATCH_INTERFACE_PK; 
