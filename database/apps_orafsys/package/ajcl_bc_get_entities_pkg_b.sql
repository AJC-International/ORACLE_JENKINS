CREATE OR REPLACE PACKAGE BODY ajcl_bc_get_entities_pkg IS

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

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,

                                       p_release_status => v_release_status );  

      p_log_seq := gv_log_seq;



  END get_journals_p;



  -- Trae los valores de las dimensiones para cada dimension set entry

  -- VERSION PAGINADO para la primera bajada e INCREMENTAL para las siguientes ejecuciones

  PROCEDURE get_dimension_set_entry_p ( p_bc_environment   IN   VARCHAR2,

                                        p_bc_ifc           IN   VARCHAR2,

                                        p_request_id       IN   NUMBER,

                                        p_log_seq      IN OUT   NUMBER,

                                        p_status          OUT   VARCHAR2 ) IS



    v_url                      VARCHAR2(2000);

    v_url_page                 VARCHAR2(2000);

    v_clob_result              CLOB;



    v_first_download           VARCHAR2(1);

    v_dimension_set_id         NUMBER;



    v_exists                   VARCHAR2(1);



    v_ifc                      VARCHAR2(200) := 'DIMENSION SET ENTRY';

    v_total_record_count       NUMBER := 0;



    v_run_date                 TIMESTAMP;

    v_last_processed_date      TIMESTAMP;

    v_last_bc_processed_date   TIMESTAMP;



    v_record_count             NUMBER;

    v_iteraciones              NUMBER;

    v_skip                     NUMBER := 0;



    -- Lock & Release

    v_process_name     VARCHAR2(200) := 'AJCL BC GET DIMENSION SET ENTRY';



    v_request_status   VARCHAR2(200);

    v_id_lock          VARCHAR2(200);

    e_lock             EXCEPTION;



    v_release_status   VARCHAR2(200);

    e_release          EXCEPTION;   

    -- Lock & Release



    CURSOR c_dimension_set_entry ( p_clob_result   IN   CLOB ) IS

    SELECT dimension_set_id,

           dimension_code,

           dimension_value_code

          ,systemmodifiedat

      FROM json_table( p_clob_result,  

                       '$.value[*]' COLUMNS ( dimension_set_id       VARCHAR2(4000)  path '$.dimensionSetId',

                                              dimension_code         VARCHAR2(4000)  path '$.dimensionCode',

                                              dimension_value_code   VARCHAR2(4000)  path '$.dimensionValueCode'

                                             ,systemmodifiedat       VARCHAR2(4000)  path '$.systemModifiedAt' 

                                            ) ); 



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



    print_log ( 'ajcl_bc_get_entities_pkg.get_dimension_set_entry_p (+)' );



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

                                                          p_entity => 'DIMENSION SET ENTRY', 

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id );



    print_log ( 'v_url: ' || v_url );



    -- Se verifica si ya se hizo una bajada, si no hay nada en la tabla, se baja todo

    SELECT DECODE(COUNT(1),0,'Y','N')

      INTO v_first_download

      FROM ajcl_bc_dimension_set_entry 

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



        FOR cdse IN c_dimension_set_entry ( v_clob_result ) LOOP



          v_dimension_set_id := cdse.dimension_set_id;

          v_total_record_count := v_total_record_count + 1;



          INSERT 

            INTO ajcl_bc_dimension_set_entry

                 (	bc_environment,

                   dimension_set_id,

                   dimension_code,

                   dimension_value_code,

                   --

                   request_id,

                   creation_date,

                   created_by,

                   last_update_date,

                   last_updated_by )

          VALUES ( p_bc_environment,

                   cdse.dimension_set_id,

                   cdse.dimension_code,

                   cdse.dimension_value_code,

                   --

                   gv_request_id,

                   SYSDATE,

                   gv_user_id,

                   SYSDATE,

                   gv_user_id );



        END LOOP;



      END LOOP;



    ELSE -- Incremental



      v_url := v_url || '?$filter=systemmodifiedat gt ' || TO_CHAR(v_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');

      print_log ( 'v_url: ' || v_url );



      v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



      FOR cdse IN c_dimension_set_entry ( p_clob_result => v_clob_result ) LOOP



        v_dimension_set_id := cdse.dimension_set_id;

        v_total_record_count := v_total_record_count + 1;



        SELECT DECODE(COUNT(1),0,'N','Y')

          INTO v_exists

          FROM ajcl_bc_dimension_set_entry

         WHERE dimension_set_id = cdse.dimension_set_id

           -- 20241007

           AND dimension_code = cdse.dimension_code

           -- 20241007

           AND bc_environment = p_bc_environment;



        IF ( v_exists = 'N' ) THEN



          INSERT 

            INTO ajcl_bc_dimension_set_entry

                 (	bc_environment,

                   dimension_set_id,

                   dimension_code,

                   dimension_value_code,

                   --

                   request_id,

                   creation_date,

                   created_by,

                   last_update_date,

                   last_updated_by )

          VALUES ( p_bc_environment,

                   cdse.dimension_set_id,

                   cdse.dimension_code,

                   cdse.dimension_value_code,

                   --

                   gv_request_id,

                   SYSDATE,

                   gv_user_id,

                   SYSDATE,

                   gv_user_id );



        ELSE



          UPDATE ajcl_bc_dimension_set_entry

             SET -- 20241007 dimension_code = cdse.dimension_code,

                 dimension_value_code = cdse.dimension_value_code,

                 request_id = p_request_id,

                 last_update_date = SYSDATE

           WHERE dimension_set_id = cdse.dimension_set_id

             -- 20241007

             AND dimension_code = cdse.dimension_code

             -- 20241007

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



    print_log ( 'ajcl_bc_get_entities_pkg.get_dimension_set_entry_p (-)' );

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

      print_log ('ajcl_bc_get_entities_pkg.get_dimension_set_entry_p. Error al intentar hacer el lock del proceso: ' || v_process_name || ' | v_request_status: ' || v_request_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    WHEN e_release THEN

      print_log ('ajcl_bc_get_entities_pkg.get_dimension_set_entry_p. Error al intentar hacer el release del proceso: ' || v_process_name || ' | v_release_status: ' || v_release_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    -- Lock & Release



    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_get_entities_pkg.get_dimension_set_entry_p (!). Error: ' || SQLERRM); 

      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,

                                       p_release_status => v_release_status );

      p_log_seq := gv_log_seq;



  END get_dimension_set_entry_p;



  -- VERSION CON PAGINADO SIN INCREMENTAL -- Esta se debe comentar luego del deploy del 23/09/2024 y descomentar la de arriba

  /*

  PROCEDURE get_dimension_set_entry_p ( p_bc_environment   IN   VARCHAR2,

                                        p_bc_ifc           IN   VARCHAR2,

                                        p_request_id       IN   NUMBER,

                                        p_log_seq      IN OUT   NUMBER,

                                        p_status          OUT   VARCHAR2 ) IS



    v_url                      VARCHAR2(2000);

    v_url_page                 VARCHAR2(2000);

    v_clob_result              CLOB;

    v_total_record_count       NUMBER := 0;



    v_record_count             NUMBER;

    v_iteraciones              NUMBER;

    v_skip                     NUMBER := 0;



    -- Lock & Release

    v_process_name     VARCHAR2(200) := 'AJCL BC GET DIMENSION SET ENTRY';



    v_request_status   VARCHAR2(200);

    v_id_lock          VARCHAR2(200);

    e_lock             EXCEPTION;



    v_release_status   VARCHAR2(200);

    e_release          EXCEPTION;   

    -- Lock & Release



    CURSOR c_dimension_set_entry ( p_clob_result   IN   CLOB ) IS

    SELECT dimension_set_id,

           dimension_code,

           dimension_value_code

      FROM json_table( p_clob_result,  

                       '$.value[*]' COLUMNS ( dimension_set_id       VARCHAR2(4000)  path '$.dimensionSetId',

                                              dimension_code         VARCHAR2(4000)  path '$.dimensionCode',

                                              dimension_value_code   VARCHAR2(4000)  path '$.dimensionValueCode'  ) ); 



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



    print_log ( 'ajcl_bc_get_entities_pkg.get_dimension_set_entry_p (+)' );



    get_company_parameters_p;



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,

                                                          p_entity => 'DIMENSION SET ENTRY', 

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id );



    DELETE ajcl_bc_dimension_set_entry

     WHERE bc_environment = p_bc_environment;



    COMMIT;



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



      FOR cdse IN c_dimension_set_entry ( v_clob_result ) LOOP



        INSERT 

          INTO ajcl_bc_dimension_set_entry

               (	bc_environment,

                 dimension_set_id,

                 dimension_code,

                 dimension_value_code,

                 --

                 request_id,

                 creation_date,

                 created_by,

                 last_update_date,

                 last_updated_by )

        VALUES ( p_bc_environment,

                 cdse.dimension_set_id,

                 cdse.dimension_code,

                 cdse.dimension_value_code,

                 --

                 gv_request_id,

                 SYSDATE,

                 gv_user_id,

                 SYSDATE,

                 gv_user_id );



      END LOOP;



    END LOOP;



    COMMIT;



    p_status := 'S';



    print_log ( 'ajcl_bc_get_entities_pkg.get_dimension_set_entry_p (-)' );

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

      print_log ('ajcl_bc_get_entities_pkg.get_dimension_set_entry_p. Error al intentar hacer el lock del proceso: ' || v_process_name || ' | v_request_status: ' || v_request_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    WHEN e_release THEN

      print_log ('ajcl_bc_get_entities_pkg.get_dimension_set_entry_p. Error al intentar hacer el release del proceso: ' || v_process_name || ' | v_release_status: ' || v_release_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    -- Lock & Release



    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_get_entities_pkg.get_dimension_set_entry_p (!). Error: ' || SQLERRM); 

      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,

                                       p_release_status => v_release_status );

      p_log_seq := gv_log_seq;



  END get_dimension_set_entry_p;

  */



  FUNCTION get_dimension_value_f ( p_bc_environment     IN   VARCHAR2,

                                   p_dimension_set_id   IN   VARCHAR2,

                                   p_dimension_code     IN   VARCHAR2 ) RETURN VARCHAR2 IS



    v_dimension_value_code   VARCHAR2(20);



  BEGIN



    SELECT dimension_value_code

      INTO v_dimension_value_code

      FROM ajcl_bc_dimension_set_entry

     WHERE bc_environment = p_bc_environment

       AND dimension_set_id = p_dimension_set_id

       AND dimension_code = p_dimension_code;



    RETURN v_dimension_value_code;



  EXCEPTION

    WHEN OTHERS THEN

      RETURN NULL;



  END get_dimension_value_f;  

  -- 20240916   



  -- 20250714

  -- Se agrega la bajada incremental de Customer Ledger Entries para traer el Remaining Amount

  PROCEDURE get_customer_ledger_entries_p ( p_bc_environment           IN   VARCHAR2,

                                            p_last_bc_processed_date   IN   TIMESTAMP ) IS



    v_url              VARCHAR2(2000);

    v_clob_result      CLOB;



    v_insert_count     NUMBER := 0;

    v_update_count     NUMBER := 0;



    CURSOR c_cle ( p_clob_result   IN   CLOB ) IS

    SELECT systemId,

           customerNo,

           customerName,

           documentNo,

           documentDate,           

           REPLACE(REPLACE(documentType,'_x0020_',' '),'_x002F_','/') documentType,

           entryNo,

           remainingAmount,

           systemModifiedAt

      FROM json_table( p_clob_result,

                       '$.value[*]' COLUMNS ( systemId                 VARCHAR2(4000) path '$.systemId',

                                              customerNo               VARCHAR2(4000) path '$.customerNo',

                                              customerName             VARCHAR2(4000) path '$.customerName',

                                              documentNo               VARCHAR2(4000) path '$.documentNo',

                                              documentDate             VARCHAR2(4000) path '$.documentDate',

                                              documentType             VARCHAR2(4000) path '$.documentType',

                                              entryNo                  VARCHAR2(4000) path '$.entryNo',

                                              remainingAmount          VARCHAR2(4000) path '$.remainingAmount',

                                              systemModifiedAt         VARCHAR2(4000) path '$.systemModifiedAt' ));



    CURSOR c_pósted_sd_cle ( p_bc_environment   IN   VARCHAR2,

                             p_entryNo          IN   NUMBER ) IS

    SELECT *

      FROM ajcl_bc_posted_sd_headers

     WHERE bc_environment = p_bc_environment

       AND entryNo = p_entryNo;



  BEGIN



    print_log ('ajcl_bc_get_entities_pkg.get_customer_ledger_entries_p (+).');



    -- Se usa la API de FOODS para no crear una nueva

    v_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, gv_bc_company_id ) || 

             ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'CUSTOMER LEDGER ENTRIES',

                                             p_subentity => NULL,

                                             p_method => 'GET' );



    v_url := v_url || '?$filter=systemModifiedAt gt ' || TO_CHAR(p_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');

    print_log ('v_url: ' || v_url);



    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



    FOR ccle IN c_cle ( p_clob_result => v_clob_result ) LOOP



      -- print_log ( 'Entry No.: ' || ccle.entryNo);



      FOR cpsdcle IN c_pósted_sd_cle ( p_bc_environment => p_bc_environment,

                                       p_entryNo => ccle.entryNo ) LOOP



        IF ( cpsdcle.remainingAmount != ccle.remainingAmount ) THEN



          UPDATE ajcl_bc_posted_sd_headers

             SET remainingamount = ccle.remainingAmount

           WHERE bc_environment = cpsdcle.bc_environment

             AND entryno = cpsdcle.entryNo;



          v_update_count := v_update_count + SQL%ROWCOUNT;



        END IF;



      END LOOP;



    END LOOP;



    print_log ('Registros actualizados en ajcl_bc_posted_sd_headers: ' || v_update_count);

    print_log ('ajcl_bc_get_entities_pkg.get_customer_ledger_entries_p (-).');



  END get_customer_ledger_entries_p;

  -- 20250714



  PROCEDURE get_sales_documents_p ( p_bc_environment   IN   VARCHAR2,

                                    p_bc_ifc           IN   VARCHAR2,

                                    p_request_id       IN   NUMBER,

                                    p_log_seq      IN OUT   NUMBER,

                                    p_status          OUT   VARCHAR2 ) IS



    v_url                      VARCHAR2(2000);

    v_clob_result              CLOB;

    v_exists                   VARCHAR2(1);

    v_first_download           VARCHAR2(1);



    v_ifc                      VARCHAR2(200) := 'SALES DOCUMENTS';



    v_run_date                 TIMESTAMP;

    v_last_processed_date      TIMESTAMP;

    v_last_bc_processed_date   TIMESTAMP;



    v_transactionno            ajcl_bc_posted_sd_headers.transactionno%TYPE;

    -- 20250711

    v_transactionno3           ajcl_bc_posted_sd_headers.transactionno%TYPE;

    -- 20250711



    v_lineno                   ajcl_bc_posted_sd_lines.lineno%TYPE;



    v_total_headers_count      NUMBER := 0;

    v_total_lines_count        NUMBER := 0;



    -- 20240916

    v_destination              ajcl_bc_posted_sd_lines.destination%TYPE;

    v_origin                   ajcl_bc_posted_sd_lines.origin%TYPE;

    v_worksheet                ajcl_bc_posted_sd_lines.worksheetno%TYPE;

    -- 20240916



    -- Lock & Release

    v_process_name             VARCHAR2(200) := 'AJCL BC GET SALES DOCUMENTS';



    v_request_status           VARCHAR2(200);

    v_id_lock                  VARCHAR2(200);

    e_lock                     EXCEPTION;



    v_release_status           VARCHAR2(200);

    e_release                  EXCEPTION;   

    -- Lock & Release



    CURSOR c_class IS

    SELECT 'POSTED SALES INV' entity,

           'INV' class

      FROM dual

     UNION

    SELECT 'POSTED SALES CM' entity,

           'CM' class

      FROM dual;



    CURSOR c_headers ( p_clob_result   IN   CLOB ) IS

    SELECT systemid,

           entryno,

           transactionno,

           REPLACE(transactionno,'-') transactionno2,           

           -- 20250711 

           -- Se arma en el cuerpo del procedure

           -- REPLACE(REPLACE(DECODE(INSTR(transactionno, '-', 1, 2), 0, transactionno, SUBSTR(transactionno, 1,INSTR(transactionno, '-', 1, 2) - 1)), '-'), ' ') transactionno3,

           -- 20250711 

           invoicereference1,

           invoicereference2,

           source,

           -- class, -- Se completa segun la api que se llama

           -- REPLACE(amount,'.',',') amount,

           amount,

           -- REPLACE(remainingamount,'.',',') remainingamount,

           remainingamount,

           appliestodocno,

           CASE 

             WHEN ( appliestodoctype = '_x0020_' ) THEN

               NULL

             ELSE

               appliestodoctype

           END appliestodoctype,

           billtocustomername,

           billtocustomerno,

           billtoaddress,

           billtoaddress2,

           billtoaddress3,

           termname,

           CASE

             WHEN duedate = '0001-01-01' THEN

               NULL

             ELSE

               duedate

           END duedate,

           currencycode,

           purchaseorder,

           company,

           account,

           department,

           destination,

           office,

           origin,

           -- worksheetno,

           division,

           -- IES

           iesinvoicecompany,

           iesinvoicenumber,

           iesnumber,

           -- CSA

           csahousebill,

           csamaxpkseqno,

           csacustomervendorno,

           csaseqnum,

           csafileextractnumber,

           -- TRV

           trvshippingorder,

           trvinvoicenum,

           trvcustomercarrieracctnum,

           trvxmlfilename,

           trvoraclexmlrunid,

           CASE

             WHEN trvxmlfiledate = '0001-01-01' THEN

               NULL

             ELSE

               trvxmlfiledate

           END trvxmlfiledate

      FROM json_table( p_clob_result,  

                       '$.value[*]' COLUMNS ( systemid                    VARCHAR2(4000)  path '$.systemid',

                                              entryno                     VARCHAR2(4000)  path '$.entryno',

                                              transactionno               VARCHAR2(4000)  path '$.transactionno',

                                              invoicereference1           VARCHAR2(4000)  path '$.invoicereference1',

                                              invoicereference2           VARCHAR2(4000)  path '$.invoicereference2',

                                              source                      VARCHAR2(4000)  path '$.source',

                                              amount                      VARCHAR2(4000)  path '$.amount',

                                              remainingamount             VARCHAR2(4000)  path '$.remainingamount',

                                              appliestodocno              VARCHAR2(4000)  path '$.appliestodocno',

                                              appliestodoctype            VARCHAR2(4000)  path '$.appliestodoctype',

                                              billtocustomername          VARCHAR2(4000)  path '$.billtocustomername',

                                              billtocustomerno            VARCHAR2(4000)  path '$.billtocustomerno',

                                              billtoaddress               VARCHAR2(4000)  path '$.billtoaddress',

                                              billtoaddress2              VARCHAR2(4000)  path '$.billtoaddress2',

                                              billtoaddress3              VARCHAR2(4000)  path '$.billtoaddress3',

                                              termname                    VARCHAR2(4000)  path '$.termname',

                                              duedate                     VARCHAR2(4000)  path '$.duedate',

                                              currencycode                VARCHAR2(4000)  path '$.currencycode',

                                              purchaseorder               VARCHAR2(4000)  path '$.purchaseorder',

                                              company                     VARCHAR2(4000)  path '$.company',

                                              account                     VARCHAR2(4000)  path '$.account',

                                              department                  VARCHAR2(4000)  path '$.department',

                                              destination                 VARCHAR2(4000)  path '$.destination',

                                              office                      VARCHAR2(4000)  path '$.office',

                                              origin                      VARCHAR2(4000)  path '$.origin',

                                              -- worksheetno                 VARCHAR2(4000)  path '$.worksheetno',

                                              division                    VARCHAR2(4000)  path '$.division',

                                              -- IES

                                              iesinvoicecompany           VARCHAR2(4000)  path '$.iesinvoicecompany',

                                              iesinvoicenumber            VARCHAR2(4000)  path '$.iesinvoicenumber',

                                              iesnumber                   VARCHAR2(4000)  path '$.iesnumber',

                                              -- CSA

                                              csahousebill                VARCHAR2(4000)  path '$.csahousebill',

                                              csamaxpkseqno               VARCHAR2(4000)  path '$.csamaxpkseqno',

                                              csacustomervendorno         VARCHAR2(4000)  path '$.csacustomervendorno',

                                              csaseqnum                   VARCHAR2(4000)  path '$.csaseqnum',

                                              csafileextractnumber        VARCHAR2(4000)  path '$.csafileextractnumber',

                                              -- TRV

                                              trvshippingorder            VARCHAR2(4000)  path '$.trvshippingorder',

                                              trvinvoicenum               VARCHAR2(4000)  path '$.trvinvoicenum',

                                              trvcustomercarrieracctnum   VARCHAR2(4000)  path '$.trvcustomercarrieracctnum',

                                              trvxmlfilename              VARCHAR2(4000)  path '$.trvxmlfilename',

                                              trvoraclexmlrunid           VARCHAR2(4000)  path '$.trvoraclexmlrunid',

                                              trvxmlfiledate              VARCHAR2(4000)  path '$.trvxmlfiledate' ) ); 



    CURSOR c_lines ( p_clob_result   IN   CLOB ) IS

    SELECT systemid,

           transactionno,

           lineno,

           description,

           -- REPLACE(quantity,'.',',') quantity,

           quantity,

           -- REPLACE(amount,'.',',') amount,

           amount,

           billtocustomerno,

           company,

           account,

           department,

           -- 20240916 destination,

           office,

           -- 20240916 origin,

           -- 20240916 worksheetno,

           -- 20240916

           dimension_set_id,

           -- 20240916

           division,

           -- IES

           iesinvoiceline,

           CASE

             WHEN iesPickupdate = '0001-01-01' THEN

               NULL

             ELSE

               iesPickupdate

           END iesPickupdate,

           CASE

             WHEN iesetd = '0001-01-01' THEN

               NULL

             ELSE

               iesetd

           END iesetd,

           CASE

             WHEN ieseta = '0001-01-01' THEN

               NULL

             ELSE

               ieseta

           END ieseta,

           iesdestination,

           iesorigin,

           -- CSA

           csapkseqnumber,

           csaseqofcharge,

           CASE

             WHEN csacreationdate = '0001-01-01' THEN

               NULL

             ELSE

               csacreationdate

           END csacreationdate,

           csaorderno,

           csastationid,

           csasubaccount,

           csadivision,

           -- TRV

           trvitemsequence,

           trvmgloadid,

           trvediitemcodechargetype,

           CASE

             WHEN trvdeliverydate = '0001-01-01' THEN

               NULL

             ELSE

               trvdeliverydate

           END trvdeliverydate

      FROM json_table( p_clob_result,  -- REVISAR ESTA ASIGNACION --

                       '$.value[*]' COLUMNS ( systemid                    VARCHAR2(4000)  path '$.systemid', 

                                              transactionno               VARCHAR2(4000)  path '$.transactionno',

                                              lineno                      VARCHAR2(4000)  path '$.lineno',

                                              description                 VARCHAR2(4000)  path '$.description',

                                              quantity                    VARCHAR2(4000)  path '$.quantity',

                                              amount                      VARCHAR2(4000)  path '$.amount',

                                              billtocustomerno            VARCHAR2(4000)  path '$.billtocustomerno',

                                              company                     VARCHAR2(4000)  path '$.company',

                                              account                     VARCHAR2(4000)  path '$.account',

                                              department                  VARCHAR2(4000)  path '$.department',

                                              -- 20240916 destination                 VARCHAR2(4000)  path '$.destination',

                                              office                      VARCHAR2(4000)  path '$.office',

                                              -- 20240916 origin                      VARCHAR2(4000)  path '$.origin',

                                              -- 20240916 worksheetno                 VARCHAR2(4000)  path '$.worksheetno',

                                              -- 20240916

                                              dimension_set_id            VARCHAR2(4000)  path '$.dimensionSetId',

                                              -- 20240916

                                              division                    VARCHAR2(4000)  path '$.division',

                                              -- IES

                                              iesinvoiceline              VARCHAR2(4000)  path '$.iesinvoiceline',

                                              iespickupdate               VARCHAR2(4000)  path '$.iespickupdate',

                                              iesetd                      VARCHAR2(4000)  path '$.iesetd',

                                              ieseta                      VARCHAR2(4000)  path '$.ieseta',

                                              iesdestination              VARCHAR2(4000)  path '$.iesdestination',

                                              iesorigin                   VARCHAR2(4000)  path '$.iesorigin',

                                              -- CSA

                                              csapkseqnumber              VARCHAR2(4000)  path '$.csapkseqnumber',

                                              csaseqofcharge              VARCHAR2(4000)  path '$.csaseqofcharge',

                                              csacreationdate             VARCHAR2(4000)  path '$.csacreationdate',

                                              csaorderno                  VARCHAR2(4000)  path '$.csaorderno',

                                              csastationid                VARCHAR2(4000)  path '$.csastationid',

                                              csasubaccount               VARCHAR2(4000)  path '$.csasubaccount',

                                              csadivision                 VARCHAR2(4000)  path '$.csadivision',

                                              -- TRV

                                              trvitemsequence             VARCHAR2(4000)  path '$.trvitemsequence',

                                              trvmgloadid                 VARCHAR2(4000)  path '$.trvmgloadid',

                                              trvediitemcodechargetype    VARCHAR2(4000)  path '$.trvediitemcodechargetype',

                                              trvdeliverydate             VARCHAR2(4000)  path '$.trvdeliverydate' ) ); 



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



    print_log ( 'ajcl_bc_get_entities_pkg.get_sales_documents_p (+)' );



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



    -- 20240916

    -- Se traen los dimension set, para determinar los valores de las dimensiones de las lineas que se bajan

    ajcl_bc_get_entities_pkg.get_dimension_set_entry_p ( p_bc_environment => p_bc_environment,

                                                         p_bc_ifc => p_bc_ifc,

                                                         p_request_id => p_request_id,

                                                         p_log_seq => gv_log_seq,

                                                         p_status => p_status );

    -- 20240916



    -- HEADERS -----------------------------------------------------------------------------------------------------------------

    FOR cc IN c_class LOOP



      print_log ( 'entity: ' || cc.entity );



      -- Headers

      v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,

                                                            p_entity => cc.entity, 

                                                            p_subentity => 'HEADERS',

                                                            p_method => 'GET',

                                                            p_company_id => gv_bc_company_id )

               -- || '?$filter=systemmodifiedat gt ' || TO_CHAR(v_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z')

               ;



      -- Se verifica si ya se hizo una bajada, si no hay nada en la tabla, se baja todo

      SELECT DECODE(COUNT(1),0,'Y','N')

        INTO v_first_download

        FROM ajcl_bc_posted_sd_headers 

       WHERE bc_environment = p_bc_environment

         AND class = cc.class;



      print_log ( 'v_first_download: ' || v_first_download ); 



      -- Si no es la primera bajada, se agrega como filtro la fecha

      IF ( v_first_download = 'N' ) THEN



        v_url := v_url || '?$filter=systemmodifiedat gt ' || TO_CHAR(v_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');



      END IF;



      print_log ( 'HEADERS v_url: ' || v_url );



      v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



      FOR ch IN c_headers ( v_clob_result ) LOOP



        v_transactionno := ch.transactionno;

        -- print_log ( 'v_transactionno: ' || v_transactionno );

        -- print_log ( 'amount: ' || ch.amount );



        -- 20250711

        v_transactionno3 := NULL;



        IF ( ch.source = 'CSA' ) THEN



          -- Se quita el - y todo lo que venga detras

          v_transactionno3 := SUBSTR(ch.transactionno,1,INSTR(ch.transactionno,'-') - 1);



        ELSE



          -- Se arma tal como estaba para lo que no es CSA

          SELECT REPLACE(REPLACE(DECODE(INSTR(ch.transactionno, '-', 1, 2), 0, ch.transactionno, SUBSTR(ch.transactionno, 1,INSTR(ch.transactionno, '-', 1, 2) - 1)), '-'), ' ')

            INTO v_transactionno3

            FROM DUAL;



        END IF;

        -- 20250711



        v_total_headers_count := v_total_headers_count + 1;



        SELECT DECODE(COUNT(1),0,'N','Y')

          INTO v_exists

          FROM ajcl_bc_posted_sd_headers

         WHERE bc_environment = p_bc_environment

           AND entryno = ch.entryno;



        IF ( v_exists = 'N' ) THEN



            -- Se inserta en la tabla

            INSERT 

              INTO ajcl_bc_posted_sd_headers

                 ( bc_environment,

                   systemid,

                   entryno,

                   transactionno,

                   transactionno2,

                   transactionno3,

                   invoicereference1,

                   invoicereference2,

                   source,

                   class,

                   amount,

                   remainingamount,

                   appliestodocno,

                   appliestodoctype,

                   billtocustomername,

                   billtocustomerno,

                   billtoaddress,

                   billtoaddress2,

                   billtoaddress3,

                   termname,

                   duedate,

                   currencycode,

                   purchaseorder,

                   company,

                   account,

                   department,

                   destination,

                   office,

                   origin,

                   -- worksheetno,

                   division,

                   -- IES

                   iesinvoicecompany,

                   iesinvoicenumber,

                   iesnumber,

                   -- CSA

                   csahousebill,

                   csamaxpkseqno,

                   csacustomervendorno,

                   csaseqnum,

                   csafileextractnumber,

                   -- TRV

                   trvshippingorder,

                   trvinvoicenum,

                   trvcustomercarrieracctnum,

                   trvxmlfilename,

                   trvoraclexmlrunid,

                   trvxmlfiledate,

                   --

                   request_id,

                   creation_date,

                   created_by,

                   last_update_date,

                   last_updated_by )

          VALUES ( p_bc_environment,

                   ch.systemid,

                   ch.entryno,

                   ch.transactionno,

                   ch.transactionno2,

                   -- 20250711

                   -- ch.transactionno3,

                   v_transactionno3,

                   -- 20250711

                   ch.invoicereference1,

                   ch.invoicereference2,

                   ch.source,

                   cc.class,

                   ch.amount,

                   ch.remainingamount,

                   ch.appliestodocno,

                   ch.appliestodoctype,

                   ch.billtocustomername,

                   ch.billtocustomerno,

                   ch.billtoaddress,

                   ch.billtoaddress2,

                   ch.billtoaddress3,

                   ch.termname,

                   ch.duedate,

                   ch.currencycode,

                   ch.purchaseorder,

                   ch.company,

                   ch.account,

                   ch.department,

                   ch.destination,

                   ch.office,

                   ch.origin,

                   -- ch.worksheetno,

                   ch.division,

                   -- IES

                   ch.iesinvoicecompany,

                   ch.iesinvoicenumber,

                   ch.iesnumber,

                   -- CSA

                   ch.csahousebill,

                   ch.csamaxpkseqno,

                   ch.csacustomervendorno,

                   ch.csaseqnum,

                   ch.csafileextractnumber,

                   -- TRV

                   ch.trvshippingorder,

                   ch.trvinvoicenum,

                   ch.trvcustomercarrieracctnum,

                   ch.trvxmlfilename,

                   ch.trvoraclexmlrunid,

                   ch.trvxmlfiledate,

                   --

                   p_request_id,

                   SYSDATE, -- creation_date

                   gv_user_id, -- created_by

                   SYSDATE, -- last_update_date

                   gv_user_id -- last_updated_by 

                   );



        ELSE



          -- Se actualiza

          UPDATE ajcl_bc_posted_sd_headers

             SET systemid = ch.systemid,

                 transactionno = ch.transactionno,

                 transactionno2 = ch.transactionno2,

                 -- 20250711

                 -- transactionno3 = ch.transactionno3,

                 transactionno3 = v_transactionno3,

                 -- 20250711

                 invoicereference1 = ch.invoicereference1,

                 invoicereference2 = ch.invoicereference2,

                 source = ch.source,

                 class = cc.class,

                 amount = ch.amount,

                 remainingamount = ch.remainingamount,

                 appliestodocno = ch.appliestodocno,

                 appliestodoctype = ch.appliestodoctype,

                 billtocustomername = ch.billtocustomername,

                 billtocustomerno = ch.billtocustomerno,

                 billtoaddress = ch.billtoaddress,

                 billtoaddress2 = ch.billtoaddress2,

                 billtoaddress3 = ch.billtoaddress3,

                 termname = ch.termname,

                 duedate = ch.duedate,

                 currencycode = ch.currencycode,

                 purchaseorder = ch.purchaseorder,

                 company = ch.company,

                 account = ch.account,

                 department = ch.department,

                 destination = ch.destination,

                 office = ch.office,

                 origin = ch.origin,

                 -- worksheetno = ch.worksheetno,

                 division = ch.division,

                 -- IES

                 iesinvoicecompany = ch.iesinvoicecompany,

                 iesinvoicenumber = ch.iesinvoicenumber,

                 iesnumber = ch.iesnumber,

                 -- CSA

                 csahousebill = ch.csahousebill,

                 csamaxpkseqno = ch.csamaxpkseqno,

                 csacustomervendorno = ch.csacustomervendorno,

                 csaseqnum = ch.csaseqnum,

                 csafileextractnumber = ch.csafileextractnumber,

                 -- TRV

                 trvshippingorder = ch.trvshippingorder,

                 trvinvoicenum = ch.trvinvoicenum,

                 trvcustomercarrieracctnum = ch.trvcustomercarrieracctnum,

                 trvxmlfilename = ch.trvxmlfilename,

                 trvoraclexmlrunid = ch.trvoraclexmlrunid,

                 trvxmlfiledate = ch.trvxmlfiledate,

                 --

                 last_update_date = SYSDATE,

                 request_id = p_request_id

           WHERE bc_environment = p_bc_environment

             AND entryno = ch.entryno;



        END IF;



      END LOOP;



      -- Lines -----------------------------------------------------------------------------------------------------------------

      v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,

                                                            p_entity => cc.entity, 

                                                            p_subentity => 'LINES',

                                                            p_method => 'GET',

                                                            p_company_id => gv_bc_company_id )

               -- || '?$filter=systemmodifiedat gt ' || TO_CHAR(v_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z')

               ;



      -- Si no es la primera bajada, se agrega como filtro la fecha

      IF ( v_first_download = 'N' ) THEN



        v_url := v_url || '?$filter=systemmodifiedat gt ' || TO_CHAR(v_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');



      END IF;



      print_log ( 'LINES v_url: ' || v_url );



      v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



      FOR cl IN c_lines ( v_clob_result ) LOOP



        v_lineno := cl.lineno;



        v_total_lines_count := v_total_lines_count + 1;



        SELECT DECODE(COUNT(1),0,'N','Y')

          INTO v_exists

          FROM ajcl_bc_posted_sd_lines

         WHERE bc_environment = p_bc_environment

           AND systemid = cl.systemid;



        -- 20240916

        -- Se obtienen los valores de las dimensiones

        v_destination := get_dimension_value_f ( p_bc_environment => p_bc_environment,

                                                 p_dimension_set_id => cl.dimension_set_id,

                                                 p_dimension_code => 'DESTINATION' );



        v_origin := get_dimension_value_f ( p_bc_environment => p_bc_environment,

                                            p_dimension_set_id => cl.dimension_set_id,

                                            p_dimension_code => 'ORIGIN' );



        v_worksheet := get_dimension_value_f ( p_bc_environment => p_bc_environment,

                                               p_dimension_set_id => cl.dimension_set_id,

                                               p_dimension_code => 'WORKSHEET' );

        -- 20240916



        IF ( v_exists = 'N' ) THEN



            -- Se inserta en la tabla

            INSERT 

              INTO ajcl_bc_posted_sd_lines

                 ( bc_environment,

                   systemid,

                   transactionno,

                   lineno,

                   description,

                   quantity,

                   amount,

                   billtocustomerno,

                   company,

                   account,

                   dimension_set_id,

                   department,

                   destination,

                   office,

                   origin,

                   worksheetno,

                   division,

                   -- IES

                   iesinvoiceline,

                   iesPickupdate,

                   iesetd,

                   ieseta,

                   iesdestination,

                   iesorigin,

                   -- CSA

                   csapkseqnumber,

                   csaseqofcharge,

                   csacreationdate,

                   csaorderno,

                   csastationid,

                   csasubaccount,

                   csadivision,

                   -- TRV

                   trvitemsequence,

                   trvmgloadid,

                   trvediitemcodechargetype,

                   trvdeliverydate,

                   --

                   request_id,

                   creation_date,

                   created_by,

                   last_update_date,

                   last_updated_by )

          VALUES ( p_bc_environment,

                   cl.systemid,

                   cl.transactionno,

                   cl.lineno,

                   cl.description,

                   cl.quantity,

                   cl.amount,

                   cl.billtocustomerno,

                   cl.company,

                   cl.account,

                   cl.dimension_set_id,

                   cl.department,

                   -- 20240916 cl.destination,

                   v_destination,

                   --

                   cl.office,

                   -- 20240916 cl.origin,

                   v_origin,

                   --

                   -- 20240916 cl.worksheetno,

                   v_worksheet,

                   --

                   cl.division,

                   -- IES

                   cl.iesinvoiceline,

                   cl.iesPickupdate,

                   cl.iesetd,

                   cl.ieseta,

                   cl.iesdestination,

                   cl.iesorigin,

                   -- CSA

                   cl.csapkseqnumber,

                   cl.csaseqofcharge,

                   cl.csacreationdate,

                   cl.csaorderno,

                   cl.csastationid,

                   cl.csasubaccount,

                   cl.csadivision,

                   -- TRV

                   cl.trvitemsequence,

                   cl.trvmgloadid,

                   cl.trvediitemcodechargetype,

                   cl.trvdeliverydate,

                   --

                   p_request_id,

                   SYSDATE, -- creation_date

                   gv_user_id, -- created_by

                   SYSDATE, -- last_update_date

                   gv_user_id -- last_updated_by 

                   );



        ELSE



          -- Se actualiza

          UPDATE ajcl_bc_posted_sd_lines

             SET transactionno = cl.transactionno,

                 lineno = cl.lineno,

                 description = cl.description,

                 quantity = cl.quantity,

                 amount = cl.amount,

                 billtocustomerno = cl.billtocustomerno,

                 company = cl.company,

                 account = cl.account,

                 dimension_set_id = cl.dimension_set_id,

                 department = cl.department,

                 -- 20240916 destination = cl.destination,

                 destination = v_destination,

                 --

                 office = cl.office,

                 -- 20240916 origin = cl.origin,

                 origin = v_origin,

                 --

                 -- 20240916 worksheetno = cl.worksheetno,

                 worksheetno = v_worksheet,

                 --

                 division = cl.division,

                 -- IES

                 iesinvoiceline = cl.iesinvoiceline,

                 iesPickupdate = cl.iesPickupdate,

                 iesetd = cl.iesetd,

                 ieseta = cl.ieseta,

                 iesdestination = cl.iesdestination,

                 iesorigin = cl.iesorigin,

                 -- CSA

                 csapkseqnumber = cl.csapkseqnumber,

                 csaseqofcharge = cl.csaseqofcharge,

                 csacreationdate = cl.csacreationdate,

                 csaorderno = cl.csaorderno,

                 csastationid = cl.csastationid,

                 csasubaccount = cl.csasubaccount,

                 csadivision = cl.csadivision,

                 -- TRV

                 trvitemsequence = cl.trvitemsequence,

                 trvmgloadid = cl.trvmgloadid,

                 trvediitemcodechargetype = cl.trvediitemcodechargetype,

                 trvdeliverydate = cl.trvdeliverydate,

                 --

                 last_update_date = SYSDATE,

                 request_id = p_request_id

           WHERE bc_environment = p_bc_environment

             AND systemid = cl.systemid;



        END IF;



      END LOOP;



    END LOOP;



    -- 20250714

    -- Se obtienen los Customer Ledger Entries para actualizar el remaining amount en la tabla ajcl_bc_posted_sd_headers

    BEGIN



      get_customer_ledger_entries_p ( p_bc_environment => p_bc_environment,

                                      p_last_bc_processed_date => v_last_bc_processed_date);



    EXCEPTION

      WHEN OTHERS THEN

        print_log ('ajcl_bc_get_entities_pkg.get_customer_ledger_entries_p (!).');



    END;

    -- 20250714



    COMMIT;



    -- Se actualiza la tabla de control

    ajcl_bc_ws_utils_pkg.upd_ifc_last_processed_date_p ( p_bc_environment,

                                                         v_ifc,

                                                         p_request_id,

                                                         v_run_date );



    print_log ( 'v_total_headers_count: ' || v_total_headers_count );

    print_log ( 'v_total_lines_count: ' || v_total_lines_count );



    p_status := 'S';



    print_log ( 'ajcl_bc_get_entities_pkg.get_sales_documents_p (-)' );

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

      print_log ('ajcl_bc_get_entities_pkg.get_sales_documents_p. Error al intentar hacer el lock del proceso: ' || v_process_name || ' | v_request_status: ' || v_request_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    WHEN e_release THEN

      print_log ('ajcl_bc_get_entities_pkg.get_sales_documents_p. Error al intentar hacer el release del proceso: ' || v_process_name || ' | v_release_status: ' || v_release_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    -- Lock & Release



    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_get_entities_pkg.get_sales_documents_p (!). Error: ' || SQLERRM || ' - transactionno: ' || v_transactionno || ' - lineno: ' || v_lineno); 

      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,

                                       p_release_status => v_release_status );

      p_log_seq := gv_log_seq;



  END get_sales_documents_p;



  PROCEDURE get_cash_receipts_p ( p_bc_environment   IN   VARCHAR2,

                                  p_bc_ifc           IN   VARCHAR2,

                                  p_request_id       IN   NUMBER,

                                  p_log_seq      IN OUT   NUMBER,

                                  p_status          OUT   VARCHAR2 ) IS



    v_url                      VARCHAR2(2000);

    v_clob_result              CLOB;

    v_exists                   VARCHAR2(1);

    v_first_download           VARCHAR2(1);

    v_total_record_count       NUMBER := 0;



    v_ifc                      VARCHAR2(200) := 'CASH RECEIPTS';



    v_run_date                 TIMESTAMP;

    v_last_processed_date      TIMESTAMP;

    v_last_bc_processed_date   TIMESTAMP;



    v_receipt_number           AJCL_BC_CASH_REC_JNL.documentNo%TYPE;



    -- Lock & Release

    v_process_name             VARCHAR2(200) := 'AJCL BC GET CASH RECEIPTS';



    v_request_status           VARCHAR2(200);

    v_id_lock                  VARCHAR2(200);

    e_lock                     EXCEPTION;



    v_release_status           VARCHAR2(200);

    e_release                  EXCEPTION;   

    -- Lock & Release



    CURSOR c_cash_receipts ( p_clob_result   IN   CLOB ) IS

    SELECT systemid,

           entryno,

           source,

           lockboxReceiptNumber,

           documentno,

           CASE

             WHEN documentdate = '0001-01-01' THEN

               NULL

             ELSE

               documentdate

           END documentdate,

           -- documenttype,

           REPLACE(documenttype,'_x0020_',' ') documenttype,

           --

           customerno,

           customername,

           currencycode,

           -- REPLACE(amount,'.',',') amount,

           amount,

           -- REPLACE(amountLCY,'.',',') amountLCY,

           amountLCY,

           -- REPLACE(remainingamount,'.',',') remainingamount,

           remainingamount,

           -- REPLACE(remainingamountLCY,'.',',') remainingamountLCY,

           remainingamountLCY,

           closedbyentryno,

           customerBankABA,

           customerBankAccount,

           aCHWireBankCustCodeName,

           typeOfReceipt

           -- 20251211

          ,journalBatchName

           -- 20251211

      FROM json_table( p_clob_result,  

                       '$.value[*]' COLUMNS ( systemid                    VARCHAR2(4000)  path '$.systemId',

                                              entryno                     VARCHAR2(4000)  path '$.entryNo',

                                              source                      VARCHAR2(4000)  path '$.source', 

                                              lockboxReceiptNumber        VARCHAR2(4000)  path '$.lockboxReceiptNumber',

                                              documentno                  VARCHAR2(4000)  path '$.documentNo',

                                              documentdate                VARCHAR2(4000)  path '$.documentDate',

                                              documenttype                VARCHAR2(4000)  path '$.documentType',

                                              customerno                  VARCHAR2(4000)  path '$.customerNo',

                                              customername                VARCHAR2(4000)  path '$.customerName',

                                              currencycode                VARCHAR2(4000)  path '$.currencyCode',

                                              amount                      VARCHAR2(4000)  path '$.amount',

                                              amountLCY                   VARCHAR2(4000)  path '$.amountLCY',

                                              remainingamount             VARCHAR2(4000)  path '$.remainingAmount',

                                              remainingamountLCY          VARCHAR2(4000)  path '$.remainingAmountLCY',

                                              closedbyentryno             VARCHAR2(4000)  path '$.closedByEntryNo',

                                              customerBankABA             VARCHAR2(4000)  path '$.customerBankABA',

                                              customerBankAccount         VARCHAR2(4000)  path '$.customerBankAccount',

                                              aCHWireBankCustCodeName     VARCHAR2(4000)  path '$.aCHWireBankCustCodeName',

                                              typeOfReceipt               VARCHAR2(4000)  path '$.typeOfReceipt'

                                              -- 20251211

                                             ,journalBatchName           VARCHAR2(4000)  path '$.journalBatchName'

                                              -- 20251211

                                             ) ); 



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



    print_log ( 'ajcl_bc_get_entities_pkg.get_cash_receipts_p (+)' );



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

                                                          p_entity => 'CASH RECEIPTS', 

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id );



    print_log ( 'v_url: ' || v_url ); 



    -- Se verifica si ya se hizo una bajada, si no hay nada en la tabla, se baja todo

    SELECT DECODE(COUNT(1),0,'Y','N')

      INTO v_first_download

      FROM AJCL_BC_CASH_REC_JNL

     WHERE bc_environment = p_bc_environment;



    print_log ( 'v_first_download: ' || v_first_download ); 



    -- Si no es la primera bajada, se agrega como filtro la fecha

    IF ( v_first_download = 'N' ) THEN



      v_url := v_url || '?$filter=systemmodifiedat gt ' || TO_CHAR(v_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');



    END IF;                                                                           



    -- v_url := v_url || '&$schemaversion=1.0';

    print_log ( 'v_url: ' || v_url );



    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



    FOR ccr IN c_cash_receipts ( v_clob_result ) LOOP



      v_receipt_number := ccr.documentno;

      -- print_log ( 'Receipt Number: ' || v_receipt_number );

      -- print_log ( 'Amount: ' || ccr.amount );



      v_total_record_count := v_total_record_count + 1;



      SELECT DECODE(COUNT(1),0,'N','Y')

        INTO v_exists

        FROM AJCL_BC_CASH_REC_JNL

       WHERE bc_environment = p_bc_environment

         AND entryno = ccr.entryno;



      IF ( v_exists = 'N' ) THEN



            -- Se inserta en la tabla

            INSERT 

              INTO AJCL_BC_CASH_REC_JNL

                 ( bc_environment,

                   systemId,

                   entryNo,

                   source,

                   lockboxReceiptNumber,

                   documentNo,

                   documentDate,

                   documentType,

                   customerNo,

                   customerName,

                   currencyCode,

                   amount,

                   amountLCY,

                   remainingamount,

                   remainingamountLCY,

                   closedbyentryno,

                   customerBankABA,

                   customerBankAccount,

                   aCHWireBankCustCodeName,

                   typeOfReceipt,

                   -- 20251211

                   journalBatchName,

                   -- 20251211

                   request_id,

                   creation_date,

                   created_by,

                   last_update_date,

                   last_updated_by )

          VALUES ( p_bc_environment,

                   ccr.systemId,

                   ccr.entryNo,

                   ccr.source,

                   ccr.lockboxReceiptNumber,

                   ccr.documentNo,

                   ccr.documentDate,

                   ccr.documentType,

                   ccr.customerNo,

                   ccr.customerName,

                   ccr.currencyCode,

                   ccr.amount,

                   ccr.amountLCY,

                   ccr.remainingamount,

                   ccr.remainingamountLCY,

                   ccr.closedbyentryno,

                   ccr.customerBankABA,

                   ccr.customerBankAccount,

                   ccr.aCHWireBankCustCodeName,

                   ccr.typeOfReceipt,

                   -- 20251211

                   ccr.journalBatchName,

                   -- 20251211

                   p_request_id,

                   SYSDATE, -- creation_date

                   gv_user_id, -- created_by

                   SYSDATE, -- last_update_date

                   gv_user_id -- last_updated_by 

                   );



      ELSE



        -- Se actualiza

        UPDATE AJCL_BC_CASH_REC_JNL

           SET systemId = ccr.systemId,

               entryNo = ccr.entryNo,

               source = ccr.source,

               lockboxReceiptNumber = ccr.lockboxReceiptNumber,

               documentNo = ccr.documentNo,

               documentDate = ccr.documentDate,

               documentType = ccr.documentType,

               customerNo = ccr.customerNo,

               customerName = ccr.customerName,

               currencyCode = ccr.currencyCode,

               amount = ccr.amount,

               amountLCY = ccr.amountLCY,

               remainingamount = ccr.remainingamount,

               remainingamountLCY = ccr.remainingamountLCY,

               closedbyentryno = ccr.closedbyentryno,

               customerBankABA = ccr.customerBankABA,

               customerBankAccount = ccr.customerBankAccount,

               aCHWireBankCustCodeName = ccr.aCHWireBankCustCodeName,

               typeOfReceipt = ccr.typeOfReceipt,

               -- 20251211

               journalBatchName = ccr.journalBatchName,

               -- 20251211

               last_update_date = SYSDATE,

               request_id = p_request_id

         WHERE bc_environment = p_bc_environment

           AND entryno = ccr.entryno;



      END IF;



    END LOOP;



    COMMIT;



    print_log ( 'v_total_record_count: ' || v_total_record_count );



    -- Se actualiza la tabla de control

    ajcl_bc_ws_utils_pkg.upd_ifc_last_processed_date_p ( p_bc_environment,

                                                         v_ifc,

                                                         p_request_id,

                                                         v_run_date );



    p_status := 'S';



    print_log ( 'ajcl_bc_get_entities_pkg.get_cash_receipts_p (-)' );

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

      print_log ('ajcl_bc_get_entities_pkg.get_cash_receipts_p. Error al intentar hacer el lock del proceso: ' || v_process_name || ' | v_request_status: ' || v_request_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    WHEN e_release THEN

      print_log ('ajcl_bc_get_entities_pkg.get_cash_receipts_p. Error al intentar hacer el release del proceso: ' || v_process_name || ' | v_release_status: ' || v_release_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    -- Lock & Release



    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_get_entities_pkg.get_cash_receipts_p (!). Error: ' || SQLERRM || ' - receipt number: ' || v_receipt_number); 

      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,

                                       p_release_status => v_release_status );

      p_log_seq := gv_log_seq;



  END get_cash_receipts_p;



  -- IES    

  -- Obtiene de BC los Charge Types, los baja a la tabla ajcl_bc_ies_charge_types

  PROCEDURE get_ies_charge_types_p ( p_bc_environment   IN   VARCHAR2,

                                     p_bc_ifc           IN   VARCHAR2,

                                     p_request_id       IN   NUMBER,

                                     p_log_seq      IN OUT   NUMBER,

                                     p_status          OUT   VARCHAR2 ) IS



    v_url                      VARCHAR2(2000);

    v_clob_result              CLOB;

    v_exists                   VARCHAR2(1);

    v_ifc                      VARCHAR2(200) := 'IES CHARGE TYPES';

    v_total_record_count       NUMBER := 0;



    v_run_date                 TIMESTAMP;

    v_last_processed_date      TIMESTAMP;

    v_last_bc_processed_date   TIMESTAMP;

    v_first_download           VARCHAR2(1);



    -- Lock & Release

    v_process_name     VARCHAR2(200) := 'AJCL BC GET CHARGE TYPES';



    v_request_status   VARCHAR2(200);

    v_id_lock          VARCHAR2(200);

    e_lock             EXCEPTION;



    v_release_status   VARCHAR2(200);

    e_release          EXCEPTION;   

    -- Lock & Release



    CURSOR c_charge_types ( p_clob_result   IN   CLOB ) IS

    SELECT systemid,

           charge_type_code,

           description,

           substitute,

           DECODE(enabled,'true','Y','N') enabled

      FROM json_table( p_clob_result,  

                       '$.value[*]' COLUMNS ( systemid           VARCHAR2(4000)  path '$.systemid',      

                                              charge_type_code   VARCHAR2(4000)  path '$.chargetypecode',      

                                              description        VARCHAR2(4000)  path '$.description',      

                                              substitute         VARCHAR2(4000)  path '$.substitute',     

                                              enabled            VARCHAR2(4000)  path '$.enabled' ) );   



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



    print_log ( 'ajcl_bc_get_entities_pkg.get_ies_charge_types_p (+)' );



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

                                                          p_entity => 'IES CHARGE TYPES', 

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id );



    print_log ( 'v_url: ' || v_url ); 



    -- Se verifica si ya se hizo una bajada, si no hay nada en la tabla, se baja todo

    SELECT DECODE(COUNT(1),0,'Y','N')

      INTO v_first_download

      FROM ajcl_bc_ies_charge_types

     WHERE bc_environment = p_bc_environment;



    print_log ( 'v_first_download: ' || v_first_download ); 



    -- Si no es la primera bajada, se agrega como filtro la fecha

    IF ( v_first_download = 'N' ) THEN



      v_url := v_url || '?$filter=systemmodifiedat gt ' || TO_CHAR(v_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');



    END IF;                  



    print_log ( 'v_url: ' || v_url );



    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



    FOR cbl IN c_charge_types ( v_clob_result ) LOOP



      v_total_record_count := v_total_record_count + 1;



      BEGIN



        SELECT DECODE(COUNT(1),0,'N','Y')

          INTO v_exists

          FROM ajcl_bc_ies_charge_types

         WHERE bc_environment = p_bc_environment

           AND systemid = cbl.systemid;



        IF ( v_exists = 'N' ) THEN



            INSERT

              INTO ajcl_bc_ies_charge_types

                 ( bc_environment,

                   systemid,

                   charge_type_code,

                   description,

                   substitute,

                   enabled,

                   --

                   request_id,

                   creation_date,

                   created_by,

                   last_update_date,

                   last_updated_by )

          VALUES ( p_bc_environment,

                   cbl.systemid,

                   cbl.charge_type_code,

                   cbl.description,

                   cbl.substitute,

                   cbl.enabled,

                   --

                   p_request_id,

                   SYSDATE,

                   gv_user_id,

                   SYSDATE,

                   gv_user_id );



        ELSE



          UPDATE ajcl_bc_ies_charge_types

             SET charge_type_code = cbl.charge_type_code,

                 description = cbl.description,

                 substitute = cbl.substitute,

                 enabled = cbl.enabled,

                 request_id = p_request_id,

                 last_update_date = SYSDATE,

                 last_updated_by = gv_user_id

           WHERE bc_environment = p_bc_environment

             AND systemid = cbl.systemid;



        END IF; 



      EXCEPTION 

        WHEN OTHERS THEN

          print_log ( 'ajcl_bc_get_entities_pkg.get_ies_charge_types_p (!). Error insertando / actualizando ajcl_bc_ies_charge_types. Error: ' || SQLERRM );



      END;



    END LOOP;



    COMMIT;



    print_log ( 'v_total_record_count: ' || v_total_record_count );



    -- Se actualiza la tabla de control

    ajcl_bc_ws_utils_pkg.upd_ifc_last_processed_date_p ( p_bc_environment,

                                                         v_ifc,

                                                         p_request_id,

                                                         v_run_date );



    p_status := 'S';



    print_log ( 'ajcl_bc_get_entities_pkg.get_ies_charge_types_p (-)' );

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

      print_log ('ajcl_bc_get_entities_pkg.get_ies_charge_types_p. Error al intentar hacer el lock del proceso: ' || v_process_name || ' | v_request_status: ' || v_request_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    WHEN e_release THEN

      print_log ('ajcl_bc_get_entities_pkg.get_ies_charge_types_p. Error al intentar hacer el release del proceso: ' || v_process_name || ' | v_release_status: ' || v_release_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    -- Lock & Release



    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_get_entities_pkg.get_ies_charge_types_p (!). Error: ' || SQLERRM); 

      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,

                                       p_release_status => v_release_status );

      p_log_seq := gv_log_seq; 



  END get_ies_charge_types_p;  



  -- Obtiene de BC los Business Lines, los baja a la tabla ajcl_bc_ies_business_lines

  PROCEDURE get_ies_business_lines_p ( p_bc_environment   IN   VARCHAR2,

                                       p_bc_ifc           IN   VARCHAR2,

                                       p_request_id       IN   NUMBER,

                                       p_log_seq      IN OUT   NUMBER,

                                       p_status          OUT   VARCHAR2 ) IS



    v_url                      VARCHAR2(2000);

    v_clob_result              CLOB;

    v_exists                   VARCHAR2(1);

    v_ifc                      VARCHAR2(200) := 'IES BUSINESS LINES';

    v_total_record_count       NUMBER := 0;



    v_run_date                 TIMESTAMP;

    v_last_processed_date      TIMESTAMP;

    v_last_bc_processed_date   TIMESTAMP;

    v_first_download           VARCHAR2(1);



    -- Lock & Release

    v_process_name     VARCHAR2(200) := 'AJCL BC GET BUSINESS LINES';



    v_request_status   VARCHAR2(200);

    v_id_lock          VARCHAR2(200);

    e_lock             EXCEPTION;



    v_release_status   VARCHAR2(200);

    e_release          EXCEPTION;   

    -- Lock & Release



    CURSOR c_business_lines ( p_clob_result   IN   CLOB ) IS

    SELECT systemid,

           business_line,

           description,

           fs_office_code,

           DECODE(trv_default,'true','Y','N') trv_default,

           DECODE(enabled,'true','Y','N') enabled

      FROM json_table( p_clob_result,  

                       '$.value[*]' COLUMNS ( systemid         VARCHAR2(4000)  path '$.systemid',      

                                              business_line    VARCHAR2(4000)  path '$.businessline',      

                                              description      VARCHAR2(4000)  path '$.description',      

                                              fs_office_code   VARCHAR2(4000)  path '$.fsofficecode',      

                                              trv_default      VARCHAR2(4000)  path '$.trvdefault',      

                                              enabled          VARCHAR2(4000)  path '$.enabled' ) );   





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



    print_log ( 'ajcl_bc_get_entities_pkg.get_ies_business_lines_p (+)' );



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

                                                          p_entity => 'IES BUSINESS LINES', 

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id );



    print_log ( 'v_url: ' || v_url ); 



    -- Se verifica si ya se hizo una bajada, si no hay nada en la tabla, se baja todo

    SELECT DECODE(COUNT(1),0,'Y','N')

      INTO v_first_download

      FROM ajcl_bc_ies_business_lines

     WHERE bc_environment = p_bc_environment;



    print_log ( 'v_first_download: ' || v_first_download ); 



    -- Si no es la primera bajada, se agrega como filtro la fecha

    IF ( v_first_download = 'N' ) THEN



      v_url := v_url || '?$filter=systemmodifiedat gt ' || TO_CHAR(v_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');



    END IF;                  



    print_log ( 'v_url: ' || v_url );



    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



    FOR cbl IN c_business_lines ( v_clob_result ) LOOP



      v_total_record_count := v_total_record_count + 1;



      BEGIN



        SELECT DECODE(COUNT(1),0,'N','Y')

          INTO v_exists

          FROM ajcl_bc_ies_business_lines

         WHERE bc_environment = p_bc_environment

           AND systemid = cbl.systemid;



        IF ( v_exists = 'N' ) THEN



            INSERT

              INTO ajcl_bc_ies_business_lines

                 ( bc_environment,

                   systemid,

                   business_line,

                   description,

                   fs_office_code,

                   trv_default,

                   enabled,

                   --

                   request_id,

                   creation_date,

                   created_by,

                   last_update_date,

                   last_updated_by )

          VALUES ( p_bc_environment,

                   cbl.systemid,

                   cbl.business_line,

                   cbl.description,

                   cbl.fs_office_code,

                   cbl.trv_default,

                   cbl.enabled,

                   --

                   p_request_id,

                   SYSDATE,

                   gv_user_id,

                   SYSDATE,

                   gv_user_id );



        ELSE



          UPDATE ajcl_bc_ies_business_lines

             SET business_line = cbl.business_line,

                 description = cbl.description,

                 fs_office_code = cbl.fs_office_code,

                 trv_default = cbl.trv_default,

                 enabled = cbl.enabled,

                 request_id = p_request_id,

                 last_update_date = SYSDATE,

                 last_updated_by = gv_user_id

           WHERE bc_environment = p_bc_environment

             AND systemid = cbl.systemid;



        END IF; 



      EXCEPTION 

        WHEN OTHERS THEN

          print_log ( 'ajcl_bc_get_entities_pkg.get_business_lines_p (!). Error insertando / actualizando ajcl_bc_ies_business_lines. Error: ' || SQLERRM );



      END;



    END LOOP;



    COMMIT;



    print_log ( 'v_total_record_count: ' || v_total_record_count );



    -- Se actualiza la tabla de control

    ajcl_bc_ws_utils_pkg.upd_ifc_last_processed_date_p ( p_bc_environment,

                                                         v_ifc,

                                                         p_request_id,

                                                         v_run_date );



    p_status := 'S';



    print_log ( 'ajcl_bc_get_entities_pkg.get_business_lines_p (-)' );

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

      print_log ('ajcl_bc_get_entities_pkg.get_business_lines_p. Error al intentar hacer el lock del proceso: ' || v_process_name || ' | v_request_status: ' || v_request_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    WHEN e_release THEN

      print_log ('ajcl_bc_get_entities_pkg.get_business_lines_p. Error al intentar hacer el release del proceso: ' || v_process_name || ' | v_release_status: ' || v_release_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    -- Lock & Release



    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_get_entities_pkg.get_business_lines_p (!). Error: ' || SQLERRM); 

      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,

                                       p_release_status => v_release_status );

      p_log_seq := gv_log_seq;  



  END get_ies_business_lines_p;



  -- Obtiene de BC los IES Items, los baja a la tabla ajcl_bc_ies_items

  PROCEDURE get_ies_items_p ( p_bc_environment   IN   VARCHAR2,

                              p_bc_ifc           IN   VARCHAR2,

                              p_request_id       IN   NUMBER,

                              p_log_seq      IN OUT   NUMBER,

                              p_status          OUT   VARCHAR2 ) IS



    v_url                      VARCHAR2(2000);

    v_clob_result              CLOB;

    v_exists                   VARCHAR2(1);

    v_ifc                      VARCHAR2(200) := 'IES ITEMS';

    v_total_record_count       NUMBER := 0;



    v_run_date                 TIMESTAMP;

    v_last_processed_date      TIMESTAMP;

    v_last_bc_processed_date   TIMESTAMP;

    v_first_download           VARCHAR2(1);



    -- Lock & Release

    v_process_name     VARCHAR2(200) := 'AJCL BC GET IES ITEMS';



    v_request_status   VARCHAR2(200);

    v_id_lock          VARCHAR2(200);

    e_lock             EXCEPTION;



    v_release_status   VARCHAR2(200);

    e_release          EXCEPTION;   

    -- Lock & Release



    CURSOR c_items ( p_clob_result   IN   CLOB ) IS

    SELECT systemid,

           chargetypecode,

           substitute,

           businessline,

           CASE

             WHEN inactivedate = '0001-01-01' THEN

               NULL

             ELSE

               TO_DATE(inactivedate,'YYYY-MM-DD') 

           END inactivedate,

           -- CGS

           cgsaccountno,

           cgscompany,

           cgsdepartment,

           cgsdestination,

           cgsoffice,

           cgsorigin,

           cgsdivision,

           -- OFFSET

           offsetaccountno,

           offsetcompany,

           offsetdepartment,

           offsetdestination,

           offsetoffice,

           offsetorigin,

           offsetdivision,

           -- REVENUE

           revaccountno,

           revcompany,

           revdepartment,

           revdestination,

           revoffice,

           revorigin,

           revdivision

      FROM json_table( p_clob_result,  

                       '$.value[*]' COLUMNS ( systemid                    VARCHAR2(4000)  path '$.systemid',

                                              chargetypecode              VARCHAR2(4000)  path '$.chargetypecode',

                                              substitute                  VARCHAR2(4000)  path '$.substitute',

                                              businessline                VARCHAR2(4000)  path '$.businessline',

                                              inactivedate                VARCHAR2(4000)  path '$.inactivedate',

                                              -- CGS

                                              cgsaccountno                VARCHAR2(4000)  path '$.cgsaccountno',

                                              cgscompany                  VARCHAR2(4000)  path '$.cgscompany',

                                              cgsdepartment               VARCHAR2(4000)  path '$.cgsdepartment',

                                              cgsdestination              VARCHAR2(4000)  path '$.cgsdestination',

                                              cgsoffice                   VARCHAR2(4000)  path '$.cgsoffice',

                                              cgsorigin                   VARCHAR2(4000)  path '$.cgsorigin',

                                              cgsdivision                 VARCHAR2(4000)  path '$.cgsdivision',

                                              -- OFFSET

                                              offsetaccountno             VARCHAR2(4000)  path '$.offsetaccountno',

                                              offsetcompany               VARCHAR2(4000)  path '$.offsetcompany',

                                              offsetdepartment            VARCHAR2(4000)  path '$.offsetdepartment',

                                              offsetdestination           VARCHAR2(4000)  path '$.offsetdestination',

                                              offsetoffice                VARCHAR2(4000)  path '$.offsetoffice',

                                              offsetorigin                VARCHAR2(4000)  path '$.offsetorigin',

                                              offsetdivision              VARCHAR2(4000)  path '$.offsetdivision',

                                              -- REVENUE

                                              revaccountno                VARCHAR2(4000)  path '$.revaccountno',

                                              revcompany                  VARCHAR2(4000)  path '$.revcompany',

                                              revdepartment               VARCHAR2(4000)  path '$.revdepartment',

                                              revdestination              VARCHAR2(4000)  path '$.revdestination',

                                              revoffice                   VARCHAR2(4000)  path '$.revoffice',

                                              revorigin                   VARCHAR2(4000)  path '$.revorigin',

                                              revdivision                 VARCHAR2(4000)  path '$.revdivision'

                                              ) ); 



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



    print_log ( 'ajcl_bc_get_entities_pkg.get_ies_items_p (+)' );



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

                                                          p_entity => 'IES ITEMS', 

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id );



    print_log ( 'v_url: ' || v_url ); 



    -- Se verifica si ya se hizo una bajada, si no hay nada en la tabla, se baja todo

    SELECT DECODE(COUNT(1),0,'Y','N')

      INTO v_first_download

      FROM ajcl_bc_ies_items

     WHERE bc_environment = p_bc_environment;



    print_log ( 'v_first_download: ' || v_first_download ); 



    -- Si no es la primera bajada, se agrega como filtro la fecha

    IF ( v_first_download = 'N' ) THEN



      v_url := v_url || '?$filter=systemmodifiedat gt ' || TO_CHAR(v_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');



    END IF;                  



    print_log ( 'v_url: ' || v_url );



    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



    FOR ci IN c_items ( v_clob_result ) LOOP



      v_total_record_count := v_total_record_count + 1;



      BEGIN



        SELECT DECODE(COUNT(1),0,'N','Y')

          INTO v_exists

          FROM ajcl_bc_ies_items

         WHERE bc_environment = p_bc_environment

           AND systemid = ci.systemid;



        IF ( v_exists = 'N' ) THEN



            INSERT

              INTO ajcl_bc_ies_items

                 ( bc_environment,

                   systemid,

                   charge_type_code,

                   substitute,

                   business_line,

                   inactive_date,

                   -- CSA

                   cgs_accountno,

                   cgs_company,

                   cgs_department,

                   cgs_destination,

                   cgs_office,

                   cgs_origin,

                   cgs_division,

                   -- OFFSET

                   offset_accountno,

                   offset_company,

                   offset_department,

                   offset_destination,

                   offset_office,

                   offset_origin,

                   offset_division,

                   -- REVENUE

                   rev_accountno,

                   rev_company,

                   rev_department,

                   rev_destination,

                   rev_office,

                   rev_origin,

                   rev_division,

                   --

                   -- status,

                   request_id,

                   creation_date,

                   created_by,

                   last_update_date,

                   last_updated_by )

          VALUES ( p_bc_environment,

                   ci.systemid,

                   ci.chargetypecode,

                   ci.substitute,

                   ci.businessline,

                   ci.inactivedate,

                   -- CSA

                   ci.cgsaccountno,

                   ci.cgscompany,

                   ci.cgsdepartment,

                   ci.cgsdestination,

                   ci.cgsoffice,

                   ci.cgsorigin,

                   ci.cgsdivision,

                   -- OFFSET

                   ci.offsetaccountno,

                   ci.offsetcompany,

                   ci.offsetdepartment,

                   ci.offsetdestination,

                   ci.offsetoffice,

                   ci.offsetorigin,

                   ci.offsetdivision,

                   -- REVENUE

                   ci.revaccountno,

                   ci.revcompany,

                   ci.revdepartment,

                   ci.revdestination,

                   ci.revoffice,

                   ci.revorigin,

                   ci.revdivision,

                   --

                   p_request_id,

                   SYSDATE,

                   gv_user_id,

                   SYSDATE,

                   gv_user_id );



        ELSE



          UPDATE ajcl_bc_ies_items

             SET charge_type_code = ci.chargetypecode,

                 substitute = ci.substitute,

                 business_line = ci.businessline,

                 inactive_date = ci.inactivedate,

                 -- CSA

                 cgs_accountno = ci.cgsaccountno,

                 cgs_company = ci.cgscompany,

                 cgs_department = ci.cgsdepartment,

                 cgs_destination = ci.cgsdestination,

                 cgs_office = ci.cgsoffice,

                 cgs_origin = ci.cgsorigin,

                 cgs_division = ci.cgsdivision,

                 -- OFFSET

                 offset_accountno = ci.offsetaccountno,

                 offset_company = ci.offsetcompany,

                 offset_department = ci.offsetdepartment,

                 offset_destination = ci.offsetdestination,

                 offset_office = ci.offsetoffice,

                 offset_origin = ci.offsetorigin,

                 offset_division = ci.offsetdivision,

                 -- REVENUE

                 rev_accountno = ci.revaccountno,

                 rev_company = ci.revcompany,

                 rev_department = ci.revdepartment,

                 rev_destination = ci.revdestination,

                 rev_office = ci.revoffice,

                 rev_origin = ci.revorigin,

                 rev_division = ci.revdivision,

                 request_id = p_request_id,

                 last_update_date = SYSDATE,

                 last_updated_by = gv_user_id

           WHERE bc_environment = p_bc_environment

             AND systemid = ci.systemid;



        END IF; 



      EXCEPTION 

        WHEN OTHERS THEN

          print_log ( 'ajcl_bc_get_entities_pkg.get_ies_items_p (!). Error insertando / actualizando ajcl_bc_ies_items. Error: ' || SQLERRM );



      END;



    END LOOP;



    COMMIT;



    print_log ( 'v_total_record_count: ' || v_total_record_count );



    -- Se actualiza la tabla de control

    ajcl_bc_ws_utils_pkg.upd_ifc_last_processed_date_p ( p_bc_environment,

                                                         v_ifc,

                                                         p_request_id,

                                                         v_run_date );



    p_status := 'S';



    print_log ( 'ajcl_bc_get_entities_pkg.get_ies_items_p (-)' );

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

      print_log ('ajcl_bc_get_entities_pkg.get_ies_items_p. Error al intentar hacer el lock del proceso: ' || v_process_name || ' | v_request_status: ' || v_request_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    WHEN e_release THEN

      print_log ('ajcl_bc_get_entities_pkg.get_ies_items_p. Error al intentar hacer el release del proceso: ' || v_process_name || ' | v_release_status: ' || v_release_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    -- Lock & Release



    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_get_entities_pkg.get_ies_items_p (!). Error: ' || SQLERRM); 

      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,

                                       p_release_status => v_release_status );

      p_log_seq := gv_log_seq;                                       



  END get_ies_items_p;



  -- Obtiene de BC los IES Country Codes, los baja a la tabla ajcl_bc_ies_country_codes

  PROCEDURE get_ies_country_codes_p ( p_bc_environment   IN   VARCHAR2,

                                      p_bc_ifc           IN   VARCHAR2,

                                      p_request_id       IN   NUMBER,

                                      p_log_seq      IN OUT   NUMBER,

                                      p_status          OUT   VARCHAR2 ) IS



    v_url                      VARCHAR2(2000);

    v_clob_result              CLOB;

    v_exists                   VARCHAR2(1);

    v_ifc                      VARCHAR2(200) := 'IES COUNTRY CODES';

    v_total_record_count       NUMBER := 0;



    v_run_date                 TIMESTAMP;

    v_last_processed_date      TIMESTAMP;

    v_last_bc_processed_date   TIMESTAMP;

    v_first_download           VARCHAR2(1);



    -- Lock & Release

    v_process_name     VARCHAR2(200) := 'AJCL BC GET IES COUNTRY CODES';



    v_request_status   VARCHAR2(200);

    v_id_lock          VARCHAR2(200);

    e_lock             EXCEPTION;



    v_release_status   VARCHAR2(200);

    e_release          EXCEPTION;   

    -- Lock & Release



    CURSOR c_country_codes ( p_clob_result   IN   CLOB ) IS

    SELECT systemid,

           countrycode,

           description,

           origin,

           destination

      FROM json_table( p_clob_result,  

                       '$.value[*]' COLUMNS ( systemid                    VARCHAR2(4000)  path '$.systemid',

                                              countrycode                 VARCHAR2(4000)  path '$.countrycode',

                                              description                 VARCHAR2(4000)  path '$.description',

                                              origin                      VARCHAR2(4000)  path '$.origin',

                                              destination                 VARCHAR2(4000)  path '$.destination'

                                              ) ); 



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



    print_log ( 'ajcl_bc_get_entities_pkg.get_ies_country_codes_p (+)' );



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

                                                          p_entity => 'IES COUNTRY CODES', 

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id );



    print_log ( 'v_url: ' || v_url ); 



    -- Se verifica si ya se hizo una bajada, si no hay nada en la tabla, se baja todo

    SELECT DECODE(COUNT(1),0,'Y','N')

      INTO v_first_download

      FROM ajcl_bc_ies_country_codes

     WHERE bc_environment = p_bc_environment;



    print_log ( 'v_first_download: ' || v_first_download ); 



    -- Si no es la primera bajada, se agrega como filtro la fecha

    IF ( v_first_download = 'N' ) THEN



      v_url := v_url || '?$filter=systemmodifiedat gt ' || TO_CHAR(v_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');



    END IF;                  



    print_log ( 'v_url: ' || v_url );



    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



    FOR ccc IN c_country_codes ( v_clob_result ) LOOP



      v_total_record_count := v_total_record_count + 1;



      BEGIN



        SELECT DECODE(COUNT(1),0,'N','Y')

          INTO v_exists

          FROM ajcl_bc_ies_country_codes

         WHERE bc_environment = p_bc_environment

           AND systemid = ccc.systemid;



        IF ( v_exists = 'N' ) THEN



            INSERT

              INTO ajcl_bc_ies_country_codes

                 ( bc_environment,

                   systemid,

                   country_code,

                   description,

                   origin,

                   destination,

                   request_id,

                   creation_date,

                   created_by,

                   last_update_date,

                   last_updated_by )

          VALUES ( p_bc_environment,

                   ccc.systemid,

                   ccc.countrycode,

                   ccc.description,

                   ccc.origin,

                   ccc.destination,

                   --

                   p_request_id,

                   SYSDATE,

                   gv_user_id,

                   SYSDATE,

                   gv_user_id );



        ELSE



          UPDATE ajcl_bc_ies_country_codes

             SET country_code = ccc.countrycode,

                 description = ccc.description,

                 origin = ccc.origin,

                 destination = ccc.destination,

                 request_id = p_request_id,

                 last_update_date = SYSDATE,

                 last_updated_by = gv_user_id

           WHERE bc_environment = p_bc_environment

             AND systemid = ccc.systemid;



        END IF; 



      EXCEPTION 

        WHEN OTHERS THEN

          print_log ( 'ajcl_bc_get_entities_pkg.get_ies_country_codes_p (!). Error insertando / actualizando ajcl_bc_ies_country_codes. Error: ' || SQLERRM );



      END;



    END LOOP;



    COMMIT;



    print_log ( 'v_total_record_count: ' || v_total_record_count );



    -- Se actualiza la tabla de control

    ajcl_bc_ws_utils_pkg.upd_ifc_last_processed_date_p ( p_bc_environment,

                                                         v_ifc,

                                                         p_request_id,

                                                         v_run_date );



    p_status := 'S';



    print_log ( 'ajcl_bc_get_entities_pkg.get_ies_country_codes_p (-)' );

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

      print_log ('ajcl_bc_get_entities_pkg.get_ies_country_codes_p. Error al intentar hacer el lock del proceso: ' || v_process_name || ' | v_request_status: ' || v_request_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    WHEN e_release THEN

      print_log ('ajcl_bc_get_entities_pkg.get_ies_country_codes_p. Error al intentar hacer el release del proceso: ' || v_process_name || ' | v_release_status: ' || v_release_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    -- Lock & Release



    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_get_entities_pkg.get_ies_country_codes_p (!). Error: ' || SQLERRM); 

      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,

                                       p_release_status => v_release_status );

      p_log_seq := gv_log_seq;



  END get_ies_country_codes_p;



  -- Obtiene de BC los CSA Station Id, los baja a la tabla ajcl_bc_csa_station_id

  PROCEDURE get_csa_station_id_p ( p_bc_environment   IN   VARCHAR2,

                                   p_bc_ifc           IN   VARCHAR2,

                                   p_request_id       IN   NUMBER,

                                   p_log_seq      IN OUT   NUMBER,

                                   p_status          OUT   VARCHAR2 ) IS



    v_url                      VARCHAR2(2000);

    v_clob_result              CLOB;

    v_exists                   VARCHAR2(1);

    v_total_record_count       NUMBER := 0;

    v_ifc                      VARCHAR2(200) := 'CSA STATION ID';



    v_run_date                 TIMESTAMP;

    v_last_processed_date      TIMESTAMP;

    v_last_bc_processed_date   TIMESTAMP;

    v_first_download           VARCHAR2(1);



    -- Lock & Release

    v_process_name     VARCHAR2(200) := 'AJCL BC GET CSA STATION ID';



    v_request_status   VARCHAR2(200);

    v_id_lock          VARCHAR2(200);

    e_lock             EXCEPTION;



    v_release_status   VARCHAR2(200);

    e_release          EXCEPTION;   

    -- Lock & Release



    CURSOR c_station_id ( p_clob_result   IN   CLOB ) IS

    SELECT systemid,

           stationid,

           description,

           destination

      FROM json_table( p_clob_result,  

                       '$.value[*]' COLUMNS ( systemid                    VARCHAR2(4000)  path '$.systemid',

                                              stationid                   VARCHAR2(4000)  path '$.stationid',

                                              description                 VARCHAR2(4000)  path '$.description',

                                              destination                 VARCHAR2(4000)  path '$.destination'

                                              ) ); 



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



    print_log ( 'ajcl_bc_get_entities_pkg.get_csa_station_id_p (+)' );



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

                                                          p_entity => 'CSA STATION ID', 

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id );



    print_log ( 'v_url: ' || v_url ); 



    -- Se verifica si ya se hizo una bajada, si no hay nada en la tabla, se baja todo

    SELECT DECODE(COUNT(1),0,'Y','N')

      INTO v_first_download

      FROM ajcl_bc_csa_station_id

     WHERE bc_environment = p_bc_environment;



    print_log ( 'v_first_download: ' || v_first_download ); 



    -- Si no es la primera bajada, se agrega como filtro la fecha

    IF ( v_first_download = 'N' ) THEN



      v_url := v_url || '?$filter=systemmodifiedat gt ' || TO_CHAR(v_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');



    END IF;                  



    print_log ( 'v_url: ' || v_url );



    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



    FOR csid IN c_station_id ( v_clob_result ) LOOP



      v_total_record_count := v_total_record_count + 1;



      BEGIN



        SELECT DECODE(COUNT(1),0,'N','Y')

          INTO v_exists

          FROM ajcl_bc_csa_station_id

         WHERE bc_environment = p_bc_environment

           AND station_id = csid.stationid; -- Se hace por station_id porque el systemid a veces cambia en BC



        IF ( v_exists = 'N' ) THEN



            INSERT

              INTO ajcl_bc_csa_station_id

                 ( bc_environment,

                   systemid,

                   station_id,

                   description,

                   destination,

                   request_id,

                   creation_date,

                   created_by,

                   last_update_date,

                   last_updated_by )

          VALUES ( p_bc_environment,

                   csid.systemid,

                   csid.stationid,

                   csid.description,

                   csid.destination,

                   --

                   p_request_id,

                   SYSDATE,

                   gv_user_id,

                   SYSDATE,

                   gv_user_id );



        ELSE



          UPDATE ajcl_bc_csa_station_id

             SET station_id = csid.stationid,

                 description = csid.description,

                 destination = csid.destination,

                 request_id = p_request_id,

                 last_update_date = SYSDATE,

                 last_updated_by = gv_user_id

           WHERE bc_environment = p_bc_environment

             AND systemid = csid.systemid;



        END IF; 



      EXCEPTION 

        WHEN OTHERS THEN

          print_log ( 'ajcl_bc_get_entities_pkg.get_csa_station_id_p (!). Error insertando / actualizando ajcl_bc_csa_station_id. Error: ' || SQLERRM );



      END;



    END LOOP;



    COMMIT;



    print_log ( 'v_total_record_count: ' || v_total_record_count );



    -- Se actualiza la tabla de control

    ajcl_bc_ws_utils_pkg.upd_ifc_last_processed_date_p ( p_bc_environment,

                                                         v_ifc,

                                                         p_request_id,

                                                         v_run_date );



    p_status := 'S';



    print_log ( 'ajcl_bc_get_entities_pkg.get_csa_station_id_p (-)' );

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

      print_log ('ajcl_bc_get_entities_pkg.get_csa_station_id_p. Error al intentar hacer el lock del proceso: ' || v_process_name || ' | v_request_status: ' || v_request_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    WHEN e_release THEN

      print_log ('ajcl_bc_get_entities_pkg.get_csa_station_id_p. Error al intentar hacer el release del proceso: ' || v_process_name || ' | v_release_status: ' || v_release_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    -- Lock & Release



    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_get_entities_pkg.get_csa_station_id_p (!). Error: ' || SQLERRM); 

      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,

                                       p_release_status => v_release_status );

      p_log_seq := gv_log_seq;



  END get_csa_station_id_p;



  -- Obtiene los usuarios que tienen permiso para sincronizar Vendors y Customers de INC y LOG de BC a Oracle

  PROCEDURE get_vend_cust_ifc_users_p ( p_bc_environment   IN   VARCHAR2,

                                        p_bc_ifc           IN   VARCHAR2,

                                        p_request_id       IN   NUMBER,

                                        p_log_seq      IN OUT   NUMBER,

                                        p_status          OUT   VARCHAR2 ) IS



    v_url                      VARCHAR2(2000);

    v_clob_result              CLOB;

    v_total_record_count       NUMBER := 0;



    -- Lock & Release

    v_process_name             VARCHAR2(200) := 'AJCL BC GET VENDORS CUSTOMERS IFC USERS';



    v_request_status           VARCHAR2(200);

    v_id_lock                  VARCHAR2(200);

    e_lock                     EXCEPTION;



    v_release_status           VARCHAR2(200);

    e_release                  EXCEPTION;   

    -- Lock & Release



    CURSOR c_vend_cust_ifc_users ( p_clob_result   IN   CLOB ) IS

    SELECT company,

           type,

           bc_user,

           full_name,

           user_security_id,

           DECODE(enabled,'true','Y','N') enabled

      FROM json_table( p_clob_result,  

                       '$.value[*]' COLUMNS ( company            VARCHAR2(4000)  path '$.company',

                                              type               VARCHAR2(4000)  path '$.type',

                                              bc_user            VARCHAR2(4000)  path '$.user',

                                              full_name          VARCHAR2(4000)  path '$.fullname',

                                              user_security_id   VARCHAR2(4000)  path '$.usersecurityid',

                                              enabled            VARCHAR2(4000)  path '$.enabled' ) ); 



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



    print_log ( 'ajcl_bc_get_entities_pkg.get_vend_cust_ifc_users_p (+)' );



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,

                                                          p_entity => 'VENDORS CUSTOMERS IFC USERS', 

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => '26fb86f1-2b58-ec11-9f08-002248210987' ); -- Master Data



    print_log ( 'v_url: ' || v_url );



    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



    -- print_log ( 'v_clob_result: ' || v_clob_result );



    DELETE AJC_BC_VEND_CUST_IFC_USERS

     WHERE bc_environment = p_bc_environment;



    COMMIT;



    print_log ( 'DELETE AJC_BC_VEND_CUST_IFC_USERS' );



    FOR cvciu IN c_vend_cust_ifc_users ( v_clob_result ) LOOP



      v_total_record_count := v_total_record_count + 1;      

      -- print_log ( 'user: ' || cvciu.bc_user );



      BEGIN



          INSERT

            INTO ajc_bc_vend_cust_ifc_users

               ( bc_environment,

                 company,

                 type,

                 bc_user,

                 full_name,

                 user_security_id,

                 enabled,

                 creation_date )

        VALUES ( p_bc_environment,

                 cvciu.company,

                 cvciu.type,

                 cvciu.bc_user,

                 cvciu.full_name,

                 cvciu.user_security_id,

                 cvciu.enabled,

                 SYSDATE );



      EXCEPTION 

        WHEN OTHERS THEN

          print_log ( 'ajcl_bc_get_entities_pkg.get_vend_cust_ifc_users_p (!). Error insertando ajc_bc_vend_cust_ifc_users. Error: ' || SQLERRM );



      END;



    END LOOP;



    COMMIT;



    print_log ( 'v_total_record_count: ' || v_total_record_count );



    p_status := 'S';



    print_log ( 'ajcl_bc_get_entities_pkg.get_vend_cust_ifc_users_p (-)' );

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

      print_log ('ajcl_bc_get_entities_pkg.get_vend_cust_ifc_users_p. Error al intentar hacer el lock del proceso: ' || v_process_name || ' | v_request_status: ' || v_request_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    WHEN e_release THEN

      print_log ('ajcl_bc_get_entities_pkg.get_vend_cust_ifc_users_p. Error al intentar hacer el release del proceso: ' || v_process_name || ' | v_release_status: ' || v_release_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    -- Lock & Release



    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_get_entities_pkg.get_vend_cust_ifc_users_p (!). Error: ' || SQLERRM); 

      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,

                                       p_release_status => v_release_status );

      p_log_seq := gv_log_seq;



  END get_vend_cust_ifc_users_p;



  -- Obtiene de la page de BC Logistic Integration Source los registros para la tabla ajcl_bc_cust_xref -- copia de la tabla ajc_bplus_cust_xref

  PROCEDURE get_cust_xref_p ( p_bc_environment   IN   VARCHAR2,

                              p_bc_ifc           IN   VARCHAR2,

                              p_request_id       IN   NUMBER,

                              p_log_seq      IN OUT   NUMBER,

                              p_status          OUT   VARCHAR2 ) IS



    v_url                      VARCHAR2(2000);

    v_url_page                 VARCHAR2(2000);

    v_clob_result              CLOB;

    v_total_record_count       NUMBER := 0;



    v_record_count             NUMBER;

    v_iteraciones              NUMBER;

    v_skip                     NUMBER := 0;



    -- Lock & Release

    v_process_name     VARCHAR2(200) := 'AJCL BC GET INTEGRATIONS SOURCE';



    v_request_status   VARCHAR2(200);

    v_id_lock          VARCHAR2(200);

    e_lock             EXCEPTION;



    v_release_status   VARCHAR2(200);

    e_release          EXCEPTION;   

    -- Lock & Release



    CURSOR c_bc_cust_xref ( p_clob_result   IN   CLOB ) IS

    SELECT UPPER(source) source,

           UPPER(sourceType) sourceType,

           sourceID,

           sourceName,

           oracleNumber,

           oracleName

      FROM json_table( p_clob_result,  

                       '$.value[*]' COLUMNS ( source         VARCHAR2(4000)  path '$.source',

                                              sourceType     VARCHAR2(4000)  path '$.sourceType',

                                              sourceID       VARCHAR2(4000)  path '$.sourceID',

                                              sourceName     VARCHAR2(4000)  path '$.sourceName',

                                              oracleNumber   VARCHAR2(4000)  path '$.oracleNumber',

                                              oracleName     VARCHAR2(4000)  path '$.oracleName' ) ); 



    CURSOR c_cust_xref IS

    SELECT *

      FROM ajcl_bc_cust_xref

     WHERE bc_environment = p_bc_environment;



    v_customer_id   NUMBER;

    v_vendor_id     NUMBER;



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



    print_log ( 'ajcl_bc_get_entities_pkg.get_cust_xref_p (+)' );



    get_company_parameters_p;



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,

                                                          p_entity => 'CUSTXREF', 

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id );



    -- print_log ( 'v_url: ' || v_url );



    print_log ( 'DELETE ajcl_bc_cust_xref' );



    DELETE ajcl_bc_cust_xref

     WHERE bc_environment = p_bc_environment;



    COMMIT;



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



      FOR cb IN c_bc_cust_xref ( v_clob_result ) LOOP



        IF ( cb.source != 'IES' ) THEN



          v_total_record_count := v_total_record_count + 1;



          BEGIN



                INSERT

                  INTO ajcl_bc_cust_xref

                     ( bc_environment,

                       bp_cust_id,

                       bp_cust_name,

                       source,

                       source_type,

                       oracle_number,

                       request_id,

                       creation_date,

                       created_by,

                       last_update_date,

                       last_updated_by )

              VALUES ( p_bc_environment,

                       cb.sourceID,

                       cb.sourceName,

                       cb.source,

                       cb.sourceType,

                       cb.oracleNumber,

                       --

                       gv_request_id,

                       SYSDATE,

                       gv_user_id,

                       SYSDATE,

                       gv_user_id );



          EXCEPTION

            WHEN OTHERS THEN

              print_log ( 'Error insertando registro. source: ' || cb.source || ' | sourceType: ' || cb.sourceType || ' | sourceID: ' || cb.sourceID );



          END; 



        END IF;



      END LOOP;



    END LOOP;



    COMMIT;



    print_log ( 'v_total_record_count: ' || v_total_record_count );



    -- Se obtiene customer_id o vendor_id de lo bajado

    FOR cb IN c_cust_xref LOOP



      v_customer_id := NULL;

      v_vendor_id := NULL;



      -- Se obtiene el customer_id o vendor_id

      BEGIN



        IF ( cb.source_type = 'CUSTOMER' ) THEN



          SELECT customer_id

            INTO v_customer_id

            FROM ra_customers

           WHERE customer_number = cb.oracle_number;



        ELSIF ( cb.source_type = 'VENDOR' ) THEN



          SELECT vendor_id

            INTO v_vendor_id

            FROM po_vendors

           WHERE segment1 = cb.oracle_number;



        END IF;



        UPDATE ajcl_bc_cust_xref

           SET oracle_cust_id = v_customer_id,

               oracle_vendor_id = v_vendor_id

         WHERE bc_environment = p_bc_environment

           AND source = cb.source

           AND source_type = cb.source_type

           AND bp_cust_id = cb.bp_cust_id;



      EXCEPTION

        WHEN OTHERS THEN

          NULL;



      END;



    END LOOP;



    COMMIT;



    p_status := 'S';



    print_log ( 'ajcl_bc_get_entities_pkg.get_cust_xref_p (-)' );

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

      print_log ('ajcl_bc_get_entities_pkg.get_cust_xref_p. Error al intentar hacer el lock del proceso: ' || v_process_name || ' | v_request_status: ' || v_request_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    WHEN e_release THEN

      print_log ('ajcl_bc_get_entities_pkg.get_cust_xref_p. Error al intentar hacer el release del proceso: ' || v_process_name || ' | v_release_status: ' || v_release_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    -- Lock & Release



    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_get_entities_pkg.get_cust_xref_p (!). Error: ' || SQLERRM); 

      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,

                                       p_release_status => v_release_status );

      p_log_seq := gv_log_seq;



  END get_cust_xref_p;



  -- Obtiene de la page de BC AJCL Truist Lockbox Parameters los parametros de conexion para Lockbox de Truist                           

  PROCEDURE get_truist_lockbox_params_p ( p_bc_environment   IN   VARCHAR2,

                                          p_bc_ifc           IN   VARCHAR2,

                                          p_request_id       IN   NUMBER,

                                          p_log_seq      IN OUT   NUMBER,

                                          p_status          OUT   VARCHAR2 ) IS



    v_url                  VARCHAR2(2000);

    v_url_page             VARCHAR2(2000);

    v_clob_result          CLOB;

    v_total_record_count   NUMBER := 0;



    -- Lock & Release

    v_process_name         VARCHAR2(200) := 'AJCL BC GET TRUIST LOCKBOX PARAMETERS';



    v_request_status       VARCHAR2(200);

    v_id_lock              VARCHAR2(200);

    e_lock                 EXCEPTION;



    v_release_status       VARCHAR2(200);

    e_release              EXCEPTION;   

    -- Lock & Release



    CURSOR c_bc_lbx_params ( p_clob_result   IN   CLOB ) IS

    SELECT oracleDBName,

           oracleFilePath,

           oracleArchivePath,

           fileName,

           remoteServer,

           remotePort,

           remoteUser,

           remotePath

      FROM json_table( p_clob_result,  

                       '$.value[*]' COLUMNS ( oracleDBName        VARCHAR2(4000)  path '$.oracleDBName',

                                              oracleFilePath      VARCHAR2(4000)  path '$.oracleFilePath',

                                              oracleArchivePath   VARCHAR2(4000)  path '$.oracleArchivePath',

                                              fileName            VARCHAR2(4000)  path '$.fileName',

                                              remoteServer        VARCHAR2(4000)  path '$.remoteServer',

                                              remotePort          VARCHAR2(4000)  path '$.remotePort',

                                              remoteUser          VARCHAR2(4000)  path '$.remoteUser',

                                              remotePath          VARCHAR2(4000)  path '$.remotePath'

                                              ) ); 



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



    get_company_parameters_p;



    print_log ( 'ajcl_bc_get_entities_pkg.get_truist_lockbox_params_p (+)' );



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,

                                                          p_entity => 'TRUIST LOCKBOX PARAMETERS', 

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id ); 



    print_log ( 'v_url: ' || v_url );



    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



    print_log ( 'v_clob_result: ' || v_clob_result );



    DELETE AJCL_BC_LOCKBOX_PARAMS

     WHERE bc_environment = p_bc_environment;



    COMMIT;



    print_log ( 'AJCL_BC_LOCKBOX_PARAMS deleted.' );



    FOR clbx IN c_bc_lbx_params ( v_clob_result ) LOOP



      -- print_log ( 'DB: ' || clbx.oracleDBName );

      v_total_record_count := v_total_record_count + 1;



      BEGIN



          INSERT

            INTO AJCL_BC_LOCKBOX_PARAMS

               ( bc_environment,

                 db_name,

                 local_file_path,

                 local_archive_path,

                 file_name,

                 remote_server,

                 remote_port,

                 remote_user,

                 remote_path )

        VALUES ( p_bc_environment,

                 clbx.oracleDBName,

                 clbx.oracleFilePath,

                 clbx.oracleArchivePath,

                 clbx.fileName,

                 clbx.remoteServer,

                 clbx.remotePort,

                 clbx.remoteUser,

                 clbx.remotePath );



      EXCEPTION 

        WHEN OTHERS THEN

          print_log ( 'ajcl_bc_get_entities_pkg.get_truist_lockbox_params_p (!). Error insertando AJCL_BC_LOCKBOX_PARAMS. Error: ' || SQLERRM );



      END;



    END LOOP;



    COMMIT;



    print_log ( 'v_total_record_count: ' || v_total_record_count );



    p_status := 'S';



    print_log ( 'ajcl_bc_get_entities_pkg.get_truist_lockbox_params_p (-)' );

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

      print_log ('ajcl_bc_get_entities_pkg.get_truist_lockbox_params_p. Error al intentar hacer el lock del proceso: ' || v_process_name || ' | v_request_status: ' || v_request_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    WHEN e_release THEN

      print_log ('ajcl_bc_get_entities_pkg.get_truist_lockbox_params_p. Error al intentar hacer el release del proceso: ' || v_process_name || ' | v_release_status: ' || v_release_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;



    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_get_entities_pkg.get_truist_lockbox_params_p (!). Error: ' || SQLERRM); 

      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,

                                       p_release_status => v_release_status );

      p_log_seq := gv_log_seq;



  END get_truist_lockbox_params_p;



  PROCEDURE check_logistics_setup_p ( p_bc_environment      IN   VARCHAR2,

                                      p_status             OUT   VARCHAR2 ) IS



    v_url                     VARCHAR2(2000);

    v_clob_result             CLOB;

    v_error_message           VARCHAR2(2000);



    e_gls_dimension_7_code    EXCEPTION;

    e_gls_ajcl_ext_enabled    EXCEPTION;

    e_srs_division_dim_code   EXCEPTION;



    CURSOR c_general_ledger_setup ( p_clob_result   IN   CLOB ) IS

    SELECT shortcutDimension7Code,

           aJCLExtensionsEnabled

      FROM json_table( p_clob_result,  

                       '$.value[*]' COLUMNS ( shortcutDimension7Code    VARCHAR2(4000)  path '$.shortcutDimension7Code',

                                              aJCLExtensionsEnabled     VARCHAR2(4000)  path '$.aJCLExtensionsEnabled' ) );



    CURSOR c_sales_receivables_setup ( p_clob_result   IN   CLOB ) IS

    SELECT divisionDimensionCode

      FROM json_table( p_clob_result,  

                       '$.value[*]' COLUMNS ( divisionDimensionCode    VARCHAR2(4000)  path '$.divisionDimensionCode' ) );



  BEGIN



    get_company_parameters_p;



    gv_bc_setup_email := ajcl_bc_utils_pkg.get_emails_f ( 'BC SETUP' );



    -- Se obtiene Allow Posting From y To de General Ledger Setup para Logistics

    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,

                                                          p_entity => 'GENERAL LEDGER SETUP',

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id );



    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );  



    -- dbms_output.put_line ( 'v_clob_result: ' || v_clob_result);    



    FOR cgls IN c_general_ledger_setup ( p_clob_result => v_clob_result ) LOOP



      -- Se chequea si la Shortcut Dimension 7 Code tiene valor DIVISION

      IF ( NVL(cgls.shortcutDimension7Code,'NOVALUE') != 'DIVISION' ) THEN



        RAISE e_gls_dimension_7_code;



      END IF;



      -- Se chequea que el toggle AJCL Extensions Enabled este en true

      IF ( NVL(cgls.aJCLExtensionsEnabled,'false') != 'true' ) THEN



        RAISE e_gls_ajcl_ext_enabled;



      END IF;



    END LOOP;



    -- Se obtiene Allow Posting From y To de General Ledger Setup para Logistics

    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,

                                                          p_entity => 'SALES RECEIVABLES SETUP',

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id );



    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );  



    -- dbms_output.put_line ( 'v_clob_result: ' || v_clob_result);    



    FOR cgls IN c_sales_receivables_setup ( p_clob_result => v_clob_result ) LOOP



      IF ( NVL(cgls.divisionDimensionCode,'NOVALUE') != 'DIVISION' ) THEN



        RAISE e_srs_division_dim_code;



      END IF;



    END LOOP;



    p_status := 'S';



  EXCEPTION

    WHEN e_gls_dimension_7_code THEN

      p_status := 'E';

      v_error_message := 'General Ledger Setup - Dimensions - Shortcut Dimension 7 Code should be set to DIVISION in LOGIS-USA-USD.';



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_bc_setup_email,

                                       p_subject => 'General Ledger Setup - ERROR - ' || p_bc_environment,

                                       p_message => v_error_message );



    WHEN e_gls_ajcl_ext_enabled THEN

      p_status := 'E';

      v_error_message := 'General Ledger Setup - General - AJC Logistics Extensions Enabled should be set to true in LOGIS-USA-USD.';



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_bc_setup_email,

                                       p_subject => 'General Ledger Setup - ERROR - ' || p_bc_environment,

                                       p_message => v_error_message );



    WHEN e_srs_division_dim_code THEN

      p_status := 'E';

      v_error_message := 'Sales & Receivables Setup - Dimensions - Division Dimension Code should be set to DIVISION in LOGIS-USA-USD.';



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_bc_setup_email,

                                       p_subject => 'Sales & Receivables Setup - ERROR - ' || p_bc_environment,

                                       p_message => v_error_message );



    WHEN OTHERS THEN 

      p_status := 'E';

      v_error_message := 'Error checking General Ledger Setup | Sales & Receivables Setup.';



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_bc_setup_email,

                                       p_subject => 'BC Setup - ERROR - ' || p_bc_environment,

                                       p_message => v_error_message );



  END check_logistics_setup_p;



  PROCEDURE get_bc_allow_posting_from_to_p ( p_bc_environment   IN   VARCHAR2,

                                             p_bc_company_id    IN   VARCHAR2,

                                             -- p_module           IN   VARCHAR2,

                                             p_bc_start_date   OUT   DATE,

                                             p_bc_end_date     OUT   DATE,

                                             p_status          OUT   VARCHAR2,

                                             p_error_msg       OUT   VARCHAR2 ) IS



    v_url           VARCHAR2(2000);

    v_clob_result   CLOB;



    -- 20240830 CURSOR c_glsetup ( p_clob_result   IN   CLOB ) IS

    CURSOR c_user_setup ( p_clob_result   IN   CLOB ) IS

    -- 20240830

    SELECT TO_DATE(allowPostingFrom,'YYYY-MM-DD') allowPostingFrom,

           TO_DATE(allowPostingTo,'YYYY-MM-DD') allowPostingTo

      FROM json_table( p_clob_result,  

                       '$.value[*]' COLUMNS ( allowPostingFrom   VARCHAR2(4000)  path '$.allowPostingFrom',

                                              allowPostingTo     VARCHAR2(4000)  path '$.allowPostingTo' ) );



    -- 20240830

    v_user   VARCHAR2(100);

    -- 20240830



  BEGIN



    -- 20240830

    v_user := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'ALLOW_POSTING_DATES_USER' );

    /*

    IF ( p_module = 'AR' ) THEN



      v_user := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AR_ALLOW_POSTING_DATES_USER' );



    ELSIF ( p_module = 'GL' ) THEN



      v_user := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'GL_ALLOW_POSTING_DATES_USER' );



    END IF;

    */

    -- 20240830



    -- 20240830 Se obtiene Allow Posting From y To de General Ledger Setup para Logistics

    -- Se obtiene Allow Posting From y To de User Setup para el usuario cargado en la tabla ajc_bc_parameters, code: ALLOW_POSTING_DATES_USER

    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,

                                                          -- 20240830 p_entity => 'GENERAL LEDGER SETUP',

                                                          p_entity => 'USER SETUP',

                                                          -- 20240830

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => p_bc_company_id )

             -- 20240830

             || '?$filter=userID eq ''' || v_user || ''''

             -- 20240830

             ;



    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );  



    -- 20240830 FOR cgls IN c_glsetup ( p_clob_result => v_clob_result ) LOOP

    FOR cus IN c_user_setup ( p_clob_result => v_clob_result ) LOOP



      -- p_bc_start_date := cgls.allowPostingFrom;

      p_bc_start_date := cus.allowPostingFrom;

      -- p_bc_end_date := cgls.allowPostingTo;

      p_bc_end_date := cus.allowPostingTo;

      -- 20240830



    END LOOP;



    p_status := 'S';



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      p_error_msg := SQLERRM;



  END get_bc_allow_posting_from_to_p;



  -- Obtiene los vendors creados en LOGIS

  PROCEDURE get_bc_vendors_p ( p_bc_environment   IN   VARCHAR2,

                               p_bc_ifc           IN   VARCHAR2,

                               p_request_id       IN   NUMBER,

                               p_log_seq      IN OUT   NUMBER,

                               p_status          OUT   VARCHAR2 ) IS



    v_url                      VARCHAR2(2000);

    v_url_page                 VARCHAR2(2000);

    v_clob_result              CLOB;

    v_total_record_count       NUMBER := 0;



    v_record_count             NUMBER;

    v_iteraciones              NUMBER;

    v_skip                     NUMBER := 0;



    -- Lock & Release

    v_process_name             VARCHAR2(200) := 'AJCL BC GET VENDORS';



    v_request_status           VARCHAR2(200);

    v_id_lock                  VARCHAR2(200);

    e_lock                     EXCEPTION;



    v_release_status           VARCHAR2(200);

    e_release                  EXCEPTION;   

    -- Lock & Release



    CURSOR c_vendors ( p_clob_result   IN   CLOB ) IS

    SELECT no,

           name,

           vendor_site_code,

           'VENDOR' type

      FROM json_table( v_clob_result,

                     '$.value[*]' COLUMNS ( no                 VARCHAR2(4000)  path '$.vendorno',

                                            name               VARCHAR2(4000)  path '$.name',

                                            vendor_site_code   VARCHAR2(4000)  path '$.legacyVendorSiteNmAJCINE' ) );



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



    get_company_parameters_p;



    print_log ( 'ajcl_bc_get_entities_pkg.get_bc_vendors_p (+)' );



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,

                                                          p_entity => 'VENDORS', 

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id );



    DELETE AJCL_BC_VENDORS_CUSTOMERS

     WHERE type = 'VENDOR'

       AND bc_environment = p_bc_environment;



    COMMIT;



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



      FOR cv IN c_vendors ( v_clob_result ) LOOP



        v_total_record_count := v_total_record_count + 1;



          INSERT

            INTO ajcl_bc_vendors_customers

               ( bc_environment,

                 type,

                 no,

                 name,

                 vendor_site_code,

                 --

                 request_id,

                 creation_date,

                 created_by,

                 last_update_date,

                 last_updated_by )

        VALUES ( p_bc_environment,

                 cv.type,

                 cv.no,

                 cv.name,

                 cv.vendor_site_code,

                 --

                 gv_request_id,

                 SYSDATE,

                 gv_user_id,

                 SYSDATE,

                 gv_user_id );



      END LOOP;



    END LOOP;



    COMMIT;



    p_status := 'S';



    print_log ( 'ajcl_bc_get_entities_pkg.get_bc_vendors_p (-)' );

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

      print_log ('ajcl_bc_get_entities_pkg.get_bc_vendors_p. Error al intentar hacer el lock del proceso: ' || v_process_name || ' | v_request_status: ' || v_request_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    WHEN e_release THEN

      print_log ('ajcl_bc_get_entities_pkg.get_bc_vendors_p. Error al intentar hacer el release del proceso: ' || v_process_name || ' | v_release_status: ' || v_release_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    -- Lock & Release



    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_get_entities_pkg.get_bc_vendors_p (!). Error: ' || SQLERRM); 

      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,

                                       p_release_status => v_release_status );

      p_log_seq := gv_log_seq;



  END get_bc_vendors_p;



  -- Obtiene los customers creados en LOGIS

  PROCEDURE get_bc_customers_p ( p_bc_environment   IN   VARCHAR2,

                                 p_bc_ifc           IN   VARCHAR2,

                                 p_request_id       IN   NUMBER,

                                 p_log_seq      IN OUT   NUMBER,

                                 p_status          OUT   VARCHAR2 ) IS



    v_url                      VARCHAR2(2000);

    v_url_page                 VARCHAR2(2000);

    v_clob_result              CLOB;

    v_total_record_count       NUMBER := 0;



    v_record_count             NUMBER;

    v_iteraciones              NUMBER;

    v_skip                     NUMBER := 0;



    -- Lock & Release

    v_process_name             VARCHAR2(200) := 'AJCL BC GET CUSTOMERS';



    v_request_status           VARCHAR2(200);

    v_id_lock                  VARCHAR2(200);

    e_lock                     EXCEPTION;



    v_release_status           VARCHAR2(200);

    e_release                  EXCEPTION;   

    -- Lock & Release



    CURSOR c_customers ( p_clob_result   IN   CLOB ) IS

    SELECT no,

           name,

           'CUSTOMER' type 

      FROM json_table( v_clob_result,

                     '$.value[*]' COLUMNS ( no     VARCHAR2(4000)  path '$.no',

                                            name   VARCHAR2(4000)  path '$.name' ) );



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



    get_company_parameters_p;



    print_log ( 'ajcl_bc_get_entities_pkg.get_bc_customers_p (+)' );



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => p_bc_environment,

                                                          p_entity => 'CUSTOMERS', 

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id );



    DELETE AJCL_BC_VENDORS_CUSTOMERS

     WHERE type = 'CUSTOMER'

       AND bc_environment = p_bc_environment;



    COMMIT;



    -- Get quantity of records in BC

    v_record_count := TO_NUMBER( regexp_replace(

                        TO_CHAR ( ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url || '/$count' ) )

                      , '[^0-9]', '') );

    print_log ( 'v_record_count: ' || v_record_count );



    v_iteraciones := CEIL(v_record_count / gv_api_records_limit);

    print_log ( 'v_iteraciones: ' || v_iteraciones );



    --

    -- Se pagina la llamada a la api

    FOR i IN 1..v_iteraciones LOOP



      v_url_page := v_url || '?$top=' || gv_api_records_limit || '&$skip=' || v_skip;

      print_log ( 'v_url_page: ' || v_url_page );



      v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url_page ); 



      -- Se calcula la cantidad de registros a skipear en la siguiente iteracion

      v_skip := v_skip + gv_api_records_limit;



      FOR cv IN c_customers ( v_clob_result ) LOOP



        v_total_record_count := v_total_record_count + 1;



          INSERT

            INTO ajcl_bc_vendors_customers

               ( bc_environment,

                 type,

                 no,

                 name,

                 vendor_site_code,

                 --

                 request_id,

                 creation_date,

                 created_by,

                 last_update_date,

                 last_updated_by )

        VALUES ( p_bc_environment,

                 cv.type,

                 cv.no,

                 cv.name,

                 NULL,

                 --

                 gv_request_id,

                 SYSDATE,

                 gv_user_id,

                 SYSDATE,

                 gv_user_id );



      END LOOP;



    END LOOP;

    --



    COMMIT;



    p_status := 'S';



    print_log ( 'ajcl_bc_get_entities_pkg.get_bc_customers_p (-)' );

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

      print_log ('ajcl_bc_get_entities_pkg.get_bc_customers_p. Error al intentar hacer el lock del proceso: ' || v_process_name || ' | v_request_status: ' || v_request_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    WHEN e_release THEN

      print_log ('ajcl_bc_get_entities_pkg.get_bc_customers_p. Error al intentar hacer el release del proceso: ' || v_process_name || ' | v_release_status: ' || v_release_status);

      p_status := 'E';

      p_log_seq := gv_log_seq;

    -- Lock & Release



    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_get_entities_pkg.get_bc_customers_p (!). Error: ' || SQLERRM); 

      -- Lock & Release

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => v_id_lock,

                                       p_release_status => v_release_status );

      p_log_seq := gv_log_seq;



  END get_bc_customers_p;                                 



END ajcl_bc_get_entities_pkg;  
