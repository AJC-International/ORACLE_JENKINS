PACKAGE BODY AJC_BC_ATIS_BATCH_INTERFACE_PK IS
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
            APEX_JSON.write('currencycode',c_rec.cur
