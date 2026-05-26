PACKAGE BODY ajcl_bc_get_entities_pkg IS
-- Creation: SBANCHIERI 23-AUG-2023

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    gv_log_seq := gv_log_seq + 1;
    ajcl_bc_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );

  END print_log;

  PROCEDURE get_company_parameters_p IS
  BEGIN

      -- Se obtienen los parametros de la company 
      SELECT bc_company_id, 
             bc_company_name 
        INTO gv_bc_company_id,
             gv_bc_company_name
        FROM ajc_bc_companies
       WHERE bc_company_name = 'LOGIS-USA-USD'
    GROUP BY org_id, 
             set_of_books_id, 
             bc_company_id, 
             bc_company_name;

    print_log ( 'gv_bc_company_id: ' || gv_bc_company_id );
    print_log ( 'gv_bc_company_name: ' || gv_bc_company_name );

  END get_company_parameters_p;

  PROCEDURE get_journals_p ( p_bc_environment   IN   VARCHAR2,
                             p_bc_ifc           IN   VARCHAR2,
                             p_request_id       IN   NUMBER,
                             p_log_seq      IN OUT   NUMBER,
                             p_status          OUT   VARCHAR2 ) IS

    v_url                      VARCHAR2(2000);
    v_url_page                 VARCHAR2(2000);
    v_clob_result              CLOB;
    v_exists                   VARCHAR2(1);
    v_first_download           VARCHAR2(1);

    v_ifc                      VARCHAR2(200) := 'JOURNALS';
    v_total_record_count       NUMBER := 0;

    v_run_date                 TIMESTAMP;
    v_last_processed_date      TIMESTAMP;
    v_last_bc_processed_date   TIMESTAMP;

    -- Lock & Release
    v_process_name             VARCHAR2(200) := 'AJCL BC GET JOURNALS';

    v_request_status           VARCHAR2(200);
    v_id_lock                  VARCHAR2(200);
    e_lock                     EXCEPTION;

    v_release_status           VARCHAR2(200);
    e_release                  EXCEPTION;   
    -- Lock & Release

    v_entryNo                  NUMBER;

    CURSOR c_lines ( p_clob_result   IN   CLOB ) IS
    SELECT systemid,
           sourcecode,
           entryno,
           documentno,
           worksheetno,
           userjesourcename,
           userjecategoryname,
           -- REPLACE(amount,'.',',') amount,
           amount,
           reversed,
           reversedentryno,
           reversedbyentryno,
           --
           journaltemplatename,
           journalbatchname,
           source,
           oraclelineno,
           CASE
             WHEN postingdate = '0001-01-01' THEN
               NULL
             ELSE
               postingdate
           END postingdate,
           company,
           department,
           account,
           destination,
           office,
           origin,
           division,
           currencycode,
           CASE
             WHEN currencyconversiondate = '0001-01-01' THEN
               NULL
             ELSE
               currencyconversiondate
           END currencyconversiondate,
           currencyconversionrate,
           currencyconversiontype,
           -- REPLACE(entereddr,'.',',') entereddr,
           entereddr,
           -- REPLACE(enteredcr,'.',',') enteredcr,
           enteredcr,
           description,
           worksheetnumber,
           -- IES
           iesapfinancialparty,
           iesorigapinternal,
           iesoraclevendornumber,
           iesoraclevendorname,
           iestrxcurrencycode,
           iestrxorigcurramount,
           iestrxcontractrate,
           -- CSA
           csaseqnumber,
           csaorderno,
           csacustomervendorno,
           csaoraclevendornumber,
           csaoraclevendorname,
           csalinenumber,
           csaquantity,
           csastation,
           CASE
             WHEN csacreationdate = '0001-01-01' THEN
               NULL
             ELSE
               csacreationdate
           END csacreationdate,
           csavendorreference,
           csasubaccount,
           csadivision,
           csaextractfilenumber,
           csatrxcurrencycode,
           csatrxorigcurramount,
           csatrxcontractrate,
           -- TRV
           trvinvoicenum,
           trvponum,
           trvcustomercarrieracctnum,
           trvoraclevendornumber,
           trvoraclevendorname,
           trvxmlfilename,
           trvoraclexmlrunid,
           CASE
             WHEN trvxmlfiledate = '0001-01-01' THEN
               NULL
             ELSE
               trvxmlfiledate
           END trvxmlfiledate,
           trvloadid,
           trvitemsequence,
           trvediitemcode,
           CASE
             WHEN trvdeliverydate = '0001-01-01' THEN
               NULL
             ELSE
               trvdeliverydate
           END trvdeliverydate,
           trvorderid
      FROM json_table( p_clob_result,  
                       '$.value[*]' COLUMNS ( systemid                    VARCHAR2(4000)  path '$.systemid',
                                              sourcecode                  VARCHAR2(4000)  path '$.sourcecode',
                                              entryno                     VARCHAR2(4000)  path '$.entryno',
                                              documentno                  VARCHAR2(4000)  path '$.documentno',
                                              worksheetno                 VARCHAR2(4000)  path '$.worksheetno',
                                              userjesourcename            VARCHAR2(4000)  path '$.userjesourcename',
                                              userjecategoryname          VARCHAR2(4000)  path '$.userjecategoryname',
                                              amount                      VARCHAR2(4000)  path '$.amount',
                                              reversed                    VARCHAR2(4000)  path '$.reversed',
                                              reversedentryno             VARCHAR2(4000)  path '$.reversedentryno',
                                              reversedbyentryno           VARCHAR2(4000)  path '$.reversedbyentryno',
                                              --
                                              journaltemplatename         VARCHAR2(4000)  path '$.journaltemplatename',
                                              journalbatchname            VARCHAR2(4000)  path '$.journalbatchname',
                                              source                      VARCHAR2(4000)  path '$.source',
                                              oraclelineno                VARCHAR2(4000)  path '$.oraclelineno',
                                              postingdate                 VARCHAR2(4000)  path '$.postingdate',
                                              company                     VARCHAR2(4000)  path '$.company',
                                              department                  VARCHAR2(4000)  path '$.department',
                                              account                     VARCHAR2(4000)  path '$.account',
                                              destination                 VARCHAR2(4000)  path '$.destination',
                                              office                      VARCHAR2(4000)  path '$.office',
                                              origin                      VARCHAR2(4000)  path '$.origin',
                                              division                    VARCHAR2(4000)  path '$.division',
                                              currencycode                VARCHAR2(4000)  path '$.currencycode',
                                              currencyconversiondate      VARCHAR2(4000)  path '$.currencyconversiondate',
                                              currencyconversionrate      VARCHAR2(4000)  path '$.currencyconversionrate',
                                              currencyconversiontype      VARCHAR2(4000)  path '$.currencyconversiontype',
                                              entereddr                   VARCHAR2(4000)  path '$.entereddr',
                                              enteredcr                   VARCHAR2(4000)  path '$.enteredcr',
                                              description                 VARCHAR2(4000)  path '$.description',
                                              worksheetnumber             VARCHAR2(4000)  path '$.worksheetnumber',
                                              -- IES
                                              iesapfinancialparty         VARCHAR2(4000)  path '$.iesapfinancialparty',
                                              iesorigapinternal           VARCHAR2(4000)  path '$.iesorigapinternal',
                                              iesoraclevendornumber       VARCHAR2(4000)  path '$.iesoraclevendornumber',
                                              iesoraclevendorname         VARCHAR2(4000)  path '$.iesoraclevendorname',
                                              iestrxcurrencycode          VARCHAR2(4000)  path '$.iestrxcurrencycode',
                                              iestrxorigcurramount        VARCHAR2(4000)  path '$.iestrxorigcurramount',
                                              iestrxcontractrate          VARCHAR2(4000)  path '$.iestrxcontractrate',
                                              -- CSA
                                              csaseqnumber                VARCHAR2(4000)  path '$.csaseqnumber',
                                              csaorderno                  VARCHAR2(4000)  path '$.csaorderno',
                                              csacustomervendorno         VARCHAR2(4000)  path '$.csacustomervendorno',
                                              csaoraclevendornumber       VARCHAR2(4000)  path '$.csaoraclevendornumber',
                                              csaoraclevendorname         VARCHAR2(4000)  path '$.csaoraclevendorname',
                                              csalinenumber               VARCHAR2(4000)  path '$.csalinenumber',
                                              csaquantity                 VARCHAR2(4000)  path '$.csaquantity',
                                              csastation                  VARCHAR2(4000)  path '$.csastation',
                                              csacreationdate             VARCHAR2(4000)  path '$.csacreationdate',
                                              csavendorreference          VARCHAR2(4000)  path '$.csavendorreference',
                                              csasubaccount               VARCHAR2(4000)  path '$.csasubaccount',
                                              csadivision                 VARCHAR2(4000)  path '$.csadivision',
                                              csaextractfilenumber        VARCHAR2(4000)  path '$.csaextractfilenumber',
                                              csatrxcurrencycode          VARCHAR2(4000)  path '$.csatrxcurrencycode',
                                              csatrxorigcurramount        VARCHAR2(4000)  path '$.csatrxorigcurramount',
                                              csatrxcontractrate          VARCHAR2(4000)  path '$.csatrxcontractrate',
                                              -- TRV
                                              trvinvoicenum               VARCHAR2(4000)  path '$.trvinvoicenum',
                                              trvponum                    VARCHAR2(4000)  path '$.trvponum',
                                              trvcustomercarrieracctnum   VARCHAR2(4000)  path '$.trvcustomercarrieracctnum',
                                              trvoraclevendornumber       VARCHAR2(4000)  path '$.trvoraclevendornumber',
                                              trvoraclevendorname         VARCHAR2(4000)  path '$.trvoraclevendorname',
                                              trvxmlfilename              VARCHAR2(4000)  path '$.trvxmlfilename',
                                              trvoraclexmlrunid           VARCHAR2(4000)  path '$.trvoraclexmlrunid',
                                              trvxmlfiledate              VARCHAR2(4000)  path '$.trvxmlfiledate',
                                              trvloadid                   VARCHAR2(4000)  path '$.trvloadid',
                                              trvitemsequence             VARCHAR2(4000)  path '$.trvitemsequence',
                                              trvediitemcode              VARCHAR2(4000)  path '$.trvediitemcode',
                                              trvdeliverydate             VARCHAR2(4000)  path '$.trvdeliverydate',
                                              trvorderid                  VARCHAR2(4000)  path '$.trvorderid' ) ); 

    v_record_count             NUMBER;
    v_iteraciones              NUMBER;
    v_skip                     NUMBER := 0;

  BEGIN

    -- Lock & Release
    ajc_bc_dbms_lock_pkg.lock_p ( p_process_name => v_process_name,
                                  p_id_lock => v_id_lock,
                                  p_request_status => v_request_status ); 

    IF ( v_request_status != 'success' ) THEN

      RAISE e_lock;

    END IF;
    -- Lock & Release

    gv_bc_ifc := p_bc_ifc;
    gv_request_id := p_request_id;
    gv_log_seq := p_log_seq;

    print_log ( 'ajcl_bc_get_entities_pkg.get_journals_p (+)' );

    get_company_parameters_p;

    -- Se guarda la fecha y hora actual
    v_run_date := systimestamp;
    print_log ( 'v_run_date: ' || v_run_date );

    -- Se obtiene la fecha y hora de Oracle de la ultima ejecucion de la interface
    v_last_processed_date := ajcl_bc_ws_utils_pkg.get_ifc_last_processed_date_f ( p_bc_environment, v_ifc );
    print_log ( 'Oracle last processed date: ' || v_last_processed_date );    

    -- Se obtiene la fecha y hora de BC de la ultima ejecucion de la interface
    v_last_bc_processed_date := ajcl_bc_ws_utils_pkg.get_bc_last_processed_date_f ( v_last_processed_date );
    print_log ( 'BC last processed date: ' || v_last_bc_processed_date );

    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,
                                                          p_entity => 'GL JNL ENTRIES',
                                                          p_subentity => 'LINES',
                                                          p_method => 'GET',
                                                          p_company_id => gv_bc_company_id );

    print_log ( 'v_url: ' || v_url );

    -- Se verifica si ya se hizo una bajada, si no hay nada en la tabla, se baja todo
    SELECT DECODE(COUNT(1),0,'Y','N')
      INTO v_first_download
      FROM ajcl_bc_gen_jnl_entries 
     WHERE bc_environment = p_bc_environment;

    print_log ( 'v_first_download: ' || v_first_download );

    IF ( v_first_download = 'Y' ) THEN

      -- Get quantity of records in BC
      v_record_count := TO_NUMBER( regexp_replace(
                          TO_CHAR ( ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url || '/$count' ) )
                        , '[^0-9]', '') );
      print_log ( 'v_record_count: ' || v_record_count );

      v_iteraciones := CEIL(v_record_count / gv_api_records_limit);
      print_log ( 'v_iteraciones: ' || v_iteraciones );

      -- Se pagina la llamada a la api
      FOR i IN 1..v_iteraciones LOOP

        v_url_page := v_url || '?$top=' || gv_api_records_limit || '&$skip=' || v_skip;
        print_log ( 'v_url_page: ' || v_url_page );

        v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url_page ); 

        -- Se calcula la cantidad de registros a skipear en la siguiente iteracion
        v_skip := v_skip + gv_api_records_limit;

        FOR cl IN c_lines ( p_clob_result => v_clob_result ) LOOP

          v_entryNo := cl.entryNo;
          v_total_record_count := v_total_record_count + 1;

          INSERT 
            INTO ajcl_bc_gen_jnl_entries
               ( bc_environment,
                 systemid,
                 sourcecode,
                 entryno,
                 documentno,
                 worksheetno,
                 userjesourcename,
                 userjecategoryname,
                 amount,
                 reversed,
                 reversedentryno,
                 reversedbyentryno,
                 --
                 journaltemplatename,
                 journalbatchname,
                 source,
                 oraclelineno,
                 postingdate,
                 company,
                 department,
                 account,
                 destination,
                 office,
                 origin,
                 division,
                 currencycode,
                 currencyconversiondate,
                 currencyconversionrate,
                 currencyconversiontype,
                 entereddr,
                 enteredcr,
                 description,
                 worksheetnumber,
                 -- IES
                 iesapfinancialparty,
                 iesorigapinternal,
                 iesoraclevendornumber,
                 iesoraclevendorname,
                 iestrxcurrencycode,
                 iestrxorigcurramount,
                 iestrxcontractrate,
                 -- CSA
                 csaseqnumber,
                 csaorderno,
                 csacustomervendorno,
                 csaoraclevendornumber,
                 csaoraclevendorname,
                 csalinenumber,
                 csaquantity,
                 csastation,
                 csacreationdate,
                 csavendorreference,
                 csasubaccount,
                 csadivision,
                 csaextractfilenumber,
                 csatrxcurrencycode,
                 csatrxorigcurramount,
                 csatrxcontractrate,
                 -- TRV
                 trvinvoicenum,
                 trvponum,
                 trvcustomercarrieracctnum,
                 trvoraclevendornumber,
                 trvoraclevendorname,
                 trvxmlfilename,
                 trvoraclexmlrunid,
                 trvxmlfiledate,
                 trvloadid,
                 trvitemsequence,
                 trvediitemcode,
                 trvdeliverydate,
                 trvorderid,
                 --
                 request_id,
                 creation_date,
                 created_by,
                 last_update_date,
                 last_updated_by )
        VALUES ( p_bc_environment,
                 cl.systemid,
                 cl.sourcecode,
                 cl.entryno,
                 cl.documentno,
                 cl.worksheetno,
                 cl.userjesourcename,
                 cl.userjecategoryname,
                 cl.amount,
                 cl.reversed,
                 cl.reversedentryno,
                 cl.reversedbyentryno,
                 --
                 cl.journaltemplatename,
                 cl.journalbatchname,
                 cl.source,
                 cl.oraclelineno,
                 cl.postingdate,
                 cl.company,
                 cl.department,
                 cl.account,
                 cl.destination,
                 cl.office,
                 cl.origin,
                 cl.division,
                 'USD', -- currencycode
                 cl.currencyconversiondate,
                 cl.currencyconversionrate,
                 cl.currencyconversiontype,
                 cl.entereddr,
                 cl.enteredcr,
                 cl.description,
                 cl.worksheetnumber,
                 -- IES
                 cl.iesapfinancialparty,
                 cl.iesorigapinternal,
                 cl.iesoraclevendornumber,
                 cl.iesoraclevendorname,
                 cl.iestrxcurrencycode,
                 cl.iestrxorigcurramount,
                 cl.iestrxcontractrate,
                 -- CSA
                 cl.csaseqnumber,
                 cl.csaorderno,
                 cl.csacustomervendorno,
                 cl.csaoraclevendornumber,
                 cl.csaoraclevendorname,
                 cl.csalinenumber,
                 cl.csaquantity,
                 cl.csastation,
                 cl.csacreationdate,
                 cl.csavendorreference,
                 cl.csasubaccount,
                 cl.csadivision,
                 cl.csaextractfilenumber,
                 cl.csatrxcurrencycode,
                 cl.csatrxorigcurramount,
                 cl.csatrxcontractrate,
                 -- TRV
                 cl.trvinvoicenum,
                 cl.trvponum,
                 cl.trvcustomercarrieracctnum,
                 cl.trvoraclevendornumber,
                 cl.trvoraclevendorname,
                 cl.trvxmlfilename,
                 cl.trvoraclexmlrunid,
                 cl.trvxmlfiledate,
                 cl.trvloadid,
                 cl.trvitemsequence,
                 cl.trvediitemcode,
                 cl.trvdeliverydate,
                 cl.trvorderid,
                 p_request_id,
                 SYSDATE, -- creation_date
                 gv_user_id, -- created_by
                 SYSDATE, -- last_update_date
                 gv_user_id -- last_updated_by 
                 );

        END LOOP;

      END LOOP;

    ELSE -- Incremental

      v_url := v_url || '?$filter=systemmodifiedat gt ' || TO_CHAR(v_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');
      print_log ( 'v_url: ' || v_url );

      v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );

      FOR cl IN c_lines ( v_clob_result ) LOOP

        v_entryNo := cl.entryNo;

        SELECT DECODE(COUNT(1),0,'N','Y')
          INTO v_exists
          FROM ajcl_bc_gen_jnl_entries
         WHERE entryNo = cl.entryNo
           AND bc_environment = p_bc_environment;

        v_total_record_count := v_total_record_count + 1;

        IF ( v_exists = 'N' ) THEN

          INSERT 
            INTO ajcl_bc_gen_jnl_entries
               ( bc_environment,
                 systemid,
                 sourcecode,
                 entryno,
                 documentno,
                 worksheetno,
                 userjesourcename,
                 userjecategoryname,
                 amount,
                 reversed,
                 reversedentryno,
                 reversedbyentryno,
                 --
                 journaltemplatename,
                 journalbatchname,
                 source,
                 oraclelineno,
                 postingdate,
                 company,
                 department,
                 account,
                 destination,
                 office,
                 origin,
                 division,
                 currencycode,
                 currencyconversiondate,
                 currencyconversionrate,
                 currencyconversiontype,
                 entereddr,
                 enteredcr,
                 description,
                 worksheetnumber,
                 -- IES
                 iesapfinancialparty,
                 iesorigapinternal,
                 iesoraclevendornumber,
                 iesoraclevendorname,
                 iestrxcurrencycode,
                 iestrxorigcurramount,
                 iestrxcontractrate,
                 -- CSA
                 csaseqnumber,
                 csaorderno,
                 csacustomervendorno,
                 csaoraclevendornumber,
                 csaoraclevendorname,
                 csalinenumber,
                 csaquantity,
                 csastation,
                 csacreationdate,
                 csavendorreference,
                 csasubaccount,
                 csadivision,
                 csaextractfilenumber,
                 csatrxcurrencycode,
                 csatrxorigcurramount,
                 csatrxcontractrate,
                 -- TRV
                 trvinvoicenum,
                 trvponum,
                 trvcustomercarrieracctnum,
                 trvoraclevendornumber,
                 trvoraclevendorname,
                 trvxmlfilename,
                 trvoraclexmlrunid,
                 trvxmlfiledate,
                 trvloadid,
                 trvitemsequence,
                 trvediitemcode,
                 trvdeliverydate,
                 trvorderid,
                 --
                 request_id,
                 creation_date,
                 created_by,
                 last_update_date,
                 last_updated_by )
        VALUES ( p_bc_environment,
                 cl.systemid,
                 cl.sourcecode,
                 cl.entryno,
                 cl.documentno,
                 cl.worksheetno,
                 cl.userjesourcename,
                 cl.userjecategoryname,
                 cl.amount,
                 cl.reversed,
                 cl.reversedentryno,
                 cl.reversedbyentryno,
                 --
                 cl.journaltemplatename,
                 cl.journalbatchname,
                 cl.source,
                 cl.oraclelineno,
                 cl.postingdate,
                 cl.company,
                 cl.department,
                 cl.account,
                 cl.destination,
                 cl.office,
                 cl.origin,
                 cl.division,
                 'USD', -- currencycode
                 cl.currencyconversiondate,
                 cl.currencyconversionrate,
                 cl.currencyconversiontype,
                 cl.entereddr,
                 cl.enteredcr,
                 cl.description,
                 cl.worksheetnumber,
                 -- IES
                 cl.iesapfinancialparty,
                 cl.iesorigapinternal,
                 cl.iesoraclevendornumber,
                 cl.iesoraclevendorname,
                 cl.iestrxcurrencycode,
                 cl.iestrxorigcurramount,
                 cl.iestrxcontractrate,
                 -- CSA
                 cl.csaseqnumber,
                 cl.csaorderno,
                 cl.csacustomervendorno,
                 cl.csaoraclevendornumber,
                 cl.csaoraclevendorname,
                 cl.csalinenumber,
                 cl.csaquantity,
                 cl.csastation,
                 cl.csacreationdate,
                 cl.csavendorreference,
                 cl.csasubaccount,
                 cl.csadivision,
                 cl.csaextractfilenumber,
                 cl.csatrxcurrencycode,
                 cl.csatrxorigcurramount,
                 cl.csatrxcontractrate,
                 -- TRV
                 cl.trvinvoicenum,
                 cl.trvponum,
                 cl.trvcustomercarrieracctnum,
                 cl.trvoraclevendornumber,
                 cl.trvoraclevendorname,
                 cl.trvxmlfilename,
                 cl.trvoraclexmlrunid,
                 cl.trvxmlfiledate,
                 cl.trvloadid,
                 cl.trvitemsequence,
                 cl.trvediitemcode,
                 cl.trvdeliverydate,
                 cl.trvorderid,
                 p_request_id,
                 SYSDATE, -- creation_date
                 gv_user_id, -- created_by
                 SYSDATE, -- last_update_date
                 gv_user_id -- last_updated_by 
                 );

        ELSE

          UPDATE ajcl_bc_gen_jnl_entries
             SET sourcecode = cl.sourcecode,
                 entryno = cl.entryno,
                 documentno = cl.documentno,
                 worksheetno = cl.worksheetno,
                 userjesourcename = cl.userjesourcename,
                 userjecategoryname = cl.userjecategoryname,
                 amount = cl.amount,
                 reversed = cl.reversed,
                 reversedentryno = cl.reversedentryno,
                 reversedbyentryno = cl.reversedbyentryno,
                 --
                 journaltemplatename = cl.journaltemplatename,
                 journalbatchname = cl.journalbatchname,
                 source = cl.source,
                 oraclelineno = cl.oraclelineno,
                 postingdate = cl.postingdate,
                 company = cl.company,
                 department = cl.department,
                 account = cl.account,
                 destination = cl.destination,
                 office = cl.office,
                 origin = cl.origin,
                 division = cl.division,
                 currencyconversiondate = cl.currencyconversiondate,
                 currencyconversionrate = cl.currencyconversionrate,
                 currencyconversiontype = cl.currencyconversiontype,
                 entereddr = cl.entereddr,
                 enteredcr = cl.enteredcr,
                 description = cl.description,
                 worksheetnumber = cl.worksheetnumber,
                 -- IES
                 iesapfinancialparty = cl.iesapfinancialparty,
                 iesorigapinternal = cl.iesorigapinternal,
                 iesoraclevendornumber = cl.iesoraclevendornumber,
                 iesoraclevendorname = cl.iesoraclevendorname,
                 iestrxcurrencycode = cl.iestrxcurrencycode,
                 iestrxorigcurramount = cl.iestrxorigcurramount,
                 iestrxcontractrate = cl.iestrxcontractrate,
                 -- CSA
                 csaseqnumber = cl.csaseqnumber,
                 csaorderno = cl.csaorderno,
                 csacustomervendorno = cl.csacustomervendorno,
                 csaoraclevendornumber = cl.csaoraclevendornumber,
                 csaoraclevendorname = cl.csaoraclevendorname,
                 csalinenumber = cl.csalinenumber,
                 csaquantity = cl.csaquantity,
                 csastation = cl.csastation,
                 csacreationdate = cl.csacreationdate,
                 csavendorreference = cl.csavendorreference,
                 csasubaccount = cl.csasubaccount,
                 csadivision = cl.csadivision,
                 csaextractfilenumber = cl.csaextractfilenumber,
                 csatrxcurrencycode = cl.csatrxcurrencycode,
                 csatrxorigcurramount = cl.csatrxorigcurramount,
                 csatrxcontractrate = cl.csatrxcontractrate,
                 -- TRV
                 trvinvoicenum = cl.trvinvoicenum,
                 trvponum = cl.trvponum,
                 trvcustomercarrieracctnum = cl.trvcustomercarrieracctnum,
                 trvoraclevendornumber = cl.trvoraclevendornumber,
                 trvoraclevendorname = cl.trvoraclevendorname,
                 trvxmlfilename = cl.trvxmlfilename,
                 trvoraclexmlrunid = cl.trvoraclexmlrunid,
                 trvxmlfiledate = cl.trvxmlfiledate,
                 trvloadid = cl.trvloadid,
                 trvitemsequence = cl.trvitemsequence,
                 trvediitemcode = cl.trvediitemcode,
                 trvdeliverydate = cl.trvdeliverydate,
                 trvorderid = cl.trvorderid,
                 --
                 last_update_date = SYSDATE,
                 request_id = p_request_id
           WHERE systemid = cl.systemid
             AND bc_environment = p_bc_environment;

        END IF;

      END LOOP;

    END IF;

    -- Se actualiza la tabla de control
    ajcl_bc_ws_utils_pkg.upd_ifc_last_processed_date_p ( p_bc_environment,
                                                         v_ifc,
                                                         p_request_id,
                                                         v_run_date );

    print_log ( 'v_total_record_count: ' || v_total_record_count );

    COMMIT;

    p_status := 'S';

    print_log ( 'ajcl_bc_get_entities_pkg.get_journals_p (-)' );
    p_log_seq := gv_log_seq;

    -- Lock & Release
    ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,
                                     p_release_status => v_release_status );

    IF ( v_release_status != 'success' ) THEN

      RAISE e_release;

    END IF;                                     
    -- Lock & Release

  EXCEPTION
    -- Lock & Release
    WHEN e_lock THEN
      print_log ('ajcl_bc_get_entities_pkg.get_journals_p. Error al intentar hacer el lock del proceso: ' || v_process_name || ' | v_request_status: ' || v_request_status);
      p_status := 'E';
      p_log_seq := gv_log_seq;
    WHEN e_release THEN
      print_log ('ajcl_bc_get_entities_pkg.get_journals_p. Error al intentar hacer el release del proceso: ' || v_process_name || ' | v_release_status: ' || v_release_status);
      p_status := 'E';
      p_log_seq := gv_log_seq;
    -- Lock & Release
    WHEN OTHERS THEN
      p_status := 'E';
      print_log('ajcl_bc_get_entities_pkg.get_journals_p (!). Error: ' || SQLERRM || ' | Entry No.: ' || v_entryNo ); 
      -- Lock & Release
      ajc_bc_db
