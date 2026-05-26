PACKAGE BODY ajc_bc_exchange_rates_pkg IS

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line(fnd_file.log, p_message);

  END print_log;

  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line(fnd_file.output,p_message);

  END print_output;

  PROCEDURE get_daily_rates_p ( p_bc_environment   IN    VARCHAR2,
                                p_date             IN    DATE,
                                p_return           OUT   VARCHAR2, 
                                p_message          OUT   VARCHAR2,
                                p_count            OUT   NUMBER ) IS

    v_get_url       VARCHAR2(2000);
    -- 20230414 v_get_api       VARCHAR2(100) := 'Currency_Exchange_Rates_Excel';
    v_get_api       VARCHAR2(100);
    v_clob_result   CLOB;

      CURSOR c_companies IS
      SELECT bc_company_name,
             currency,
             bc_company_id
        FROM ajc_bc_companies
       -- WHERE bc_company_name = 'FOODS-USA-USD'
    GROUP BY bc_company_name,
             currency,
             bc_company_id
    ORDER BY bc_company_name;

    CURSOR c_rates ( p_clob_result   CLOB ) IS
    SELECT DECODE(currency,'MXN','MEX',currency) currency,
           TO_DATE(conversion_date,'YYYY-MM-DD') conversion_date,
           conversion_rate
      FROM json_table( p_clob_result,
                       '$.value[*]' COLUMNS ( currency          VARCHAR2(4000)  path '$.Currency_Code'
                                             ,conversion_date   VARCHAR2(4000)  path '$.Starting_Date'
                                             ,conversion_rate   VARCHAR2(4000)  path '$.Exchange_Rate_Amount' ) );

    v_from_currency     gl_daily_rates.from_currency%TYPE;
    v_to_currency       gl_daily_rates.to_currency%TYPE;
    v_conversion_date   gl_daily_rates.conversion_date%TYPE;
    v_conversion_rate   gl_daily_rates.conversion_rate%TYPE;

  BEGIN

    print_log ('ajc_bc_exchange_rates_pkg.get_daily_rates_p (+)');
    print_log (' ');

    v_get_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'EXCHANGE RATES',
                                                 p_subentity => NULL,
                                                 p_method => 'GET' );
    print_log ( 'v_get_api: ' || v_get_api );

    p_count := 0;

    FOR cc IN c_companies LOOP

      print_log ( 'Company: ' || cc.bc_company_name );

      v_get_url := ajc_bc_ws_utils_pkg.get_base_ajc_url_f ( p_bc_environment, cc.bc_company_name ) || v_get_api
                   || '?$filter=Starting_Date eq ' || TO_CHAR(p_date,'YYYY-MM-DD')
                   ;

      print_log ( 'v_get_url: ' || v_get_url );

      v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );

      FOR cr IN c_rates ( v_clob_result ) LOOP

        v_from_currency := cc.currency;
        v_to_currency := cr.currency;
        v_conversion_date := cr.conversion_date;
        v_conversion_rate := cr.conversion_rate;

        print_log ('from_currency: ' || v_from_currency || ' to_currency: ' || v_to_currency || ' conversion_date: ' || v_conversion_date || ' conversion_rate: ' || v_conversion_rate);

        BEGIN

            INSERT 
              INTO AJC_BC_GL_DAILY_RATES 
                 ( bc_company,
                   from_currency,
                   to_currency,
                   conversion_date,
                   conversion_type,
                   conversion_rate,
                   --
                   request_id,
                   status,
                   creation_date,
                   created_by,
                   last_update_date,
                   last_updated_by,
                   last_update_login )
          VALUES ( cc.bc_company_name,
                   cc.currency,
                   cr.currency,
                   cr.conversion_date,
                   'Spot',
                   cr.conversion_rate,
                   --
                   gv_request_id,
                   'NEW',
                   SYSDATE,
                   gv_user_id,
                   SYSDATE,
                   gv_user_id,
                   gv_user_id );

          p_count := p_count + 1;

        EXCEPTION
          -- WHEN DUP_VAL_ON_INDEX THEN
          --   print_log ('Rate exists.');
          WHEN OTHERS THEN
            print_log ('Error: ' || SQLERRM);

        END;

      END LOOP; -- rates

      print_log (' ');

    END LOOP; -- companies

    p_return := 'S';
    print_log ('ajc_bc_exchange_rates_pkg.get_daily_rates_p (-)');

  EXCEPTION
    WHEN OTHERS THEN
      p_return := 'E';
      print_log ('ajc_bc_exchange_rates_pkg.get_daily_rates_p (!). Error: ' || SQLERRM);

  END get_daily_rates_p;

  PROCEDURE create_daily_rates_p ( p_return    OUT   VARCHAR2, 
                                   p_message   OUT   VARCHAR2 ) IS

    v_request_id        NUMBER;
    v_message           VARCHAR2(2000);
    v_error_message     VARCHAR2(2000);
    e_cust_exception    EXCEPTION;
    v_conc_phase        VARCHAR2 (50);
    v_conc_status       VARCHAR2 (50);
    v_conc_dev_phase    VARCHAR2 (50);
    v_conc_dev_status   VARCHAR2 (50);
    v_conc_message      VARCHAR2 (250);  

      CURSOR c_rates_grouped ( p_condition   IN   VARCHAR2 ) IS
      SELECT from_currency, 
             to_currency, 
             conversion_date,
             conversion_type
        FROM ( SELECT from_currency, 
                      to_currency, 
                      conversion_date,
                      conversion_type,
                      conversion_rate
                 FROM ajc_bc_gl_daily_rates
                WHERE request_id = gv_request_id
                  AND status = 'NEW'
             GROUP BY from_currency, 
                      to_currency, 
                      conversion_date,
                      conversion_type,
                      conversion_rate         
             ORDER BY from_currency, 
                      to_currency )
    GROUP BY from_currency, 
             to_currency, 
             conversion_date,
             conversion_type
      HAVING DECODE(COUNT(1),1,'TO_PROCESS','DUPLICATED') = p_condition;     

      CURSOR c_daily_rates ( p_status   IN   VARCHAR2 ) IS
      SELECT from_currency, 
             to_currency, 
             conversion_date,
             conversion_type,
             conversion_rate,
             status
        FROM ajc_bc_gl_daily_rates
       WHERE request_id = gv_request_id
         AND status = p_status
    ORDER BY from_currency, 
             to_currency;

    v_from_currency     gl_daily_rates.from_currency%TYPE;
    v_to_currency       gl_daily_rates.to_currency%TYPE;
    v_conversion_date   gl_daily_rates.conversion_date%TYPE;
    v_conversion_rate   gl_daily_rates.conversion_rate%TYPE;

    v_duplicated        NUMBER;

    v_exists            NUMBER;
    v_inverse_exists    NUMBER;

    v_count             NUMBER;
    v_tbl_status        ajc_bc_gl_daily_rates.status%TYPE;
    v_tbl_message       ajc_bc_gl_daily_rates.message%TYPE;

  BEGIN

    print_log ('ajc_bc_exchange_rates_pkg.create_daily_rates_p (+)');

    -- Se marcan las que tienen misma moneda from y to
    UPDATE ajc_bc_gl_daily_rates
       SET status = 'SKIPPED',
           message = 'Same Currency From - To.'
     WHERE from_currency = to_currency
       AND request_id = gv_request_id
       AND status = 'NEW';

    -- Se marcan las que estan ok para procesar
    FOR cok IN c_rates_grouped ( 'TO_PROCESS' ) LOOP

      -- Se actualiza su estado a TO_PROCESS
      UPDATE ajc_bc_gl_daily_rates
         SET status = 'TO_PROCESS'
       WHERE from_currency = cok.from_currency
         AND to_currency = cok.to_currency
         AND conversion_date = cok.conversion_date
         AND request_id = gv_request_id
         AND status = 'NEW';

    END LOOP;

    v_duplicated := 0;

    -- Se marcan las que NO estan ok para procesar
    FOR cnotok IN c_rates_grouped ( 'DUPLICATED' ) LOOP

      -- Se actualiza su estado a DUPLICATED
      UPDATE ajc_bc_gl_daily_rates
         SET status = 'DUPLICATED',
             message = 'Duplicated. Please, correct the situation in BC.'
       WHERE from_currency = cnotok.from_currency
         AND to_currency = cnotok.to_currency
         AND conversion_date = cnotok.conversion_date
         AND request_id = gv_request_id
         AND status = 'NEW';

      v_duplicated := v_duplicated + 1;

    END LOOP;

    v_count := 0;

    -- Se insertan en la interface las que estan ok para procesar
    FOR cdr IN c_daily_rates ( p_status => 'TO_PROCESS' ) LOOP

      -- Se verifica que no haya sido insertada aun
      SELECT COUNT(1)
        INTO v_exists
        FROM gl_daily_rates_interface
       WHERE from_currency = cdr.from_currency
         AND to_currency = cdr.to_currency
         AND from_conversion_date = cdr.conversion_date;

      -- Se verifica si ya se inserto la tasa inversa, si es asi, no se inserta y se marca como SKIPPED
      SELECT COUNT(1)
        INTO v_inverse_exists
        FROM gl_daily_rates_interface
       WHERE from_currency = cdr.to_currency
         AND to_currency = cdr.from_currency
         AND from_conversion_date = cdr.conversion_date;

      -- Si no existe la inversa, se inserta, sino se marca como SKIPPED
      IF ( v_exists = 0 AND v_inverse_exists = 0 ) THEN

          INSERT 
            INTO gl_daily_rates_interface 
               ( from_currency,
                 to_currency,
                 from_conversion_date,
                 to_conversion_date,
                 user_conversion_type,
                 conversion_rate,
                 mode_flag )
        VALUES ( cdr.from_currency,
                 cdr.to_currency,
                 cdr.conversion_date,
                 cdr.conversion_date,
                 cdr.conversion_type,
                 cdr.conversion_rate,
                 'I' );

        COMMIT;

        v_tbl_status := 'INTERFACED';
        v_tbl_message := NULL;

        v_count := v_count + 1;

      ELSE

        v_tbl_status := 'SKIPPED';
        v_tbl_message := 'Inverse rate processed.';

      END IF;

      -- Se actualiza su estado
      UPDATE ajc_bc_gl_daily_rates
         SET status = v_tbl_status,
             message = v_tbl_message
       WHERE from_currency = cdr.from_currency
         AND to_currency = cdr.to_currency
         AND conversion_date = cdr.conversion_date
         AND conversion_rate = cdr.conversion_rate
         AND request_id = gv_request_id
         AND status = cdr.status;

    END LOOP;

    print_log ( 'Rows Inserted: ' || v_count );
    print_log ( ' ' );

    IF ( v_count > 0 ) THEN

      -- Program - Daily Rates Import and Calculation
      v_request_id := fnd_request.submit_request ( 'SQLGL'
                                                  ,'GLDRICCP' ) ;

      IF v_request_id = 0 THEN

        v_message := fnd_message.get;
        print_log('Error Ejecutando FND_REQUEST.SUBMIT_REQUEST. GLDRICCP. Error: ' || v_message || ', ' || SQLERRM);
        RAISE e_cust_exception;

      END IF;

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
        print_log('Error Ejecutando FND_REQUEST.WAIT_FOR_REQUEST. GLDRICCP con nro. solicitud ' || 
                  TO_CHAR (v_request_id) || '. Error: ' || v_message || ' ' || SQLERRM);
        RAISE e_cust_exception;

      END IF;

      IF v_conc_dev_phase != 'COMPLETE' OR v_conc_dev_status != 'NORMAL' THEN

        v_error_message := fnd_message.get;
        print_log('Error en la ejecucion del concurrente GLDRICCP con nro. solicitud ' || 
                  TO_CHAR (v_request_id) || '. Error: ' || v_error_message || ' ' || SQLERRM);
        RAISE e_cust_exception;

      END IF; 

      -- Se controlan las procesadas contra gl_daily_rates
      FOR cdr IN c_daily_rates ( p_status => 'INTERFACED' ) LOOP

        -- Se verifica si fueron creados los rates
        SELECT DECODE(COUNT(1),0,'ERROR',1,'ERROR',2,'IMPORTED','ERROR') -- 2 significa que creo el rate y el inverso
          INTO v_tbl_status
          FROM gl_daily_rates gldr
         WHERE ( ( gldr.from_currency = cdr.from_currency AND gldr.to_currency = cdr.to_currency ) OR
                 ( gldr.from_currency = cdr.to_currency AND gldr.to_currency = cdr.from_currency ) ) -- inverso
           AND gldr.conversion_date = cdr.conversion_date;

        UPDATE ajc_bc_gl_daily_rates
           SET status = v_tbl_status
         WHERE from_currency = cdr.from_currency
           AND to_currency = cdr.to_currency
           AND conversion_date = cdr.conversion_date
           AND conversion_rate = cdr.conversion_rate
           AND request_id = gv_request_id
           AND status = cdr.status;

      END LOOP;  

    END IF;

    COMMIT;

    IF ( v_duplicated != 0 ) THEN

      p_return := 'W';
      p_message := 'Some rates were not processed because they are duplicated with different rates.';

    ELSE

      p_return := 'S';

    END IF;

    print_log ('ajc_bc_exchange_rates_pkg.create_daily_rates_p (-)');

  EXCEPTION
    WHEN OTHERS THEN
      p_return := 'E';
      p_message := 'ajc_bc_exchange_rates_pkg.create_daily_rates_p (!). Error: ' || SQLERRM;
      print_log ( p_message );

  END create_daily_rates_p;

  PROCEDURE create_translation_rates_p ( p_date       IN    DATE,
                                         p_return    OUT   VARCHAR2, 
                                         p_message   OUT   VARCHAR2 ) IS

      CURSOR c_companies IS
      SELECT c.currency,
             sob.name,
             sob.set_of_books_id,
             p.period_name,
             p.end_date
        FROM ajc_bc_companies c,
             gl_sets_of_books sob,
             gl_periods p
       WHERE c.currency != 'USD'
         AND sob.set_of_books_id = c.set_of_books_id
         AND sob.period_set_name = p.period_set_name
         -- AND p.period_set_name = 'AJC CALENDAR'
         AND p_date = p.end_date
    ORDER BY sob.set_of_books_id;

    v_eop_rate   gl_daily_rates.conversion_rate%TYPE;

  BEGIN

    print_log ('ajc_bc_exchange_rates_pkg.create_translation_rates_p (+)');

    FOR cc IN c_companies LOOP

      BEGIN

        print_log ( 'Set of books: ' || cc.name || ' (' || cc.set_of_books_id || 
                    ') | Currency: ' || cc.currency || 
                    ' | Period Name: ' || cc.period_name || 
                    ' | End Date: ' || cc.end_date );

        v_eop_rate := NULL;

        -- Se obtiene el end of period rate para el periodo
        SELECT conversion_rate
          INTO v_eop_rate
          FROM gl_daily_rates dr
         WHERE dr.from_currency = cc.currency
           AND dr.to_currency = 'USD'
           AND dr.conversion_date = cc.end_date;

        print_log ( 'End of period rate: ' || v_eop_rate );

        -- Se copiaron todos los registros de gl_translation_rates a esta tabla
        DELETE ajc_bc_gl_translation_rates
         WHERE 1 = 1 
           -- AND TRUNC(creation_date) >= TO_DATE('20230330','YYYYMMDD') -- Se borra solo lo que inserto yo con mis pruebas
           AND set_of_books_id = cc.set_of_books_id
           AND period_name = cc.period_name
           -- 20230718
           -- AND to_currency_code = cc.currency;
           AND to_currency_code = 'USD';
           -- 20230718

        print_log ( 'Se borran registros con mismo set of books id y period name de la tabla ajc_bc_gl_translation_rates.' );

          INSERT
            INTO AJC_BC_GL_TRANSLATION_RATES
               ( set_of_books_id,
                 period_name,
                 to_currency_code,
                 avg_rate,
                 eop_rate,
                 update_flag,
                 last_update_date,
                 last_updated_by,
                 creation_date,
                 created_by,
                 last_update_login,
                 actual_flag,
                 eop_rate_numerator,
                 eop_rate_denominator,
                 avg_rate_numerator,
                 avg_rate_denominator )
        VALUES ( cc.set_of_books_id,
                 cc.period_name,
                 -- 20230718 cc.currency,
                 'USD', -- to_currency_code
                 -- 20230718 
                 1, -- avg_rate,
                 v_eop_rate,
                 'N', -- update_flag
                 SYSDATE, -- last_update_date
                 gv_user_id, -- last_updated_by
                 SYSDATE, -- creation_date
                 gv_user_id, -- created_by
                 gv_user_id, -- last_update_login
                 'A', -- actual_flag
                 v_eop_rate, -- eop_rate_numerator
                 1, -- eop_rate_denominator
                 1, -- avg_rate_numerator
                 1 ); -- avg_rate_denominator                 

      EXCEPTION
        WHEN OTHERS THEN
          print_log ('Error: ' || SQLERRM);

      END;

    END LOOP;

    COMMIT;

    p_return := 'S';

    print_log ('ajc_bc_exchange_rates_pkg.create_translation_rates_p (-)');

  EXCEPTION
    WHEN OTHERS THEN
      p_return := 'E';
      p_message := 'Error general create_translation_rates_p: ' || SQLERRM;

  END create_translation_rates_p;

  PROCEDURE main_p ( retcode           OUT   NUMBER,
                     errbuf            OUT   VARCHAR2,
                     p_bc_environment   IN   VARCHAR2,
                     p_date             IN   VARCHAR2 ) IS

    v_email              VARCHAR2(2000);
    v_count              NUMBER;

    v_date               DATE;
    v_return             VARCHAR2(1);
    v_return_dr          VARCHAR2(1);
    v_message            VARCHAR2(2000);
    v_message_dr         VARCHAR2(2000);
    v_conc_status        BOOLEAN;

    v_request_id_excel   NUMBER;

    e_no_rates           EXCEPTION;
    e_warning            EXCEPTION;
    e_error              EXCEPTION;

  BEGIN

    print_log ('ajc_bc_exchange_rates_pkg.main_p (+)');

    v_email := ajc_bc_ws_utils_pkg.get_emails_f ( 'EXCHANGE RATES' );

    print_log ('p_bc_environment: ' || p_bc_environment);   
    print_log ('p_date: ' || p_date);   
    print_log ('v_email: ' || v_email);   

    v_date := TO_DATE(p_date,'YYYY/MM/DD HH24:MI:SS');

    get_daily_rates_p ( p_bc_environment => p_bc_environment,
                        p_date => v_date,
                        p_return => v_return, 
                        p_message => v_message,
                        p_count => v_count );

    IF ( v_return != 'S' ) THEN

      RAISE e_error;

    ELSIF ( v_count = 0 ) THEN

      RAISE e_no_rates;

    END IF;

    create_daily_rates_p ( p_return => v_return_dr, 
                           p_message => v_message_dr );

    v_request_id_excel := ajc_bc_ws_utils_pkg.print_excel_report ( p_request_id => gv_request_id,
                                                                   p_program => 'AJCBCERIR',
                                                                   p_template => 'AJCBCERIR' );

    print_log ( 'Excel Report Request ID: ' || v_request_id_excel );

    COMMIT;

    print_log ( ' ' );

    create_translation_rates_p ( p_date => v_date,
                                 p_return => v_return, 
                                 p_message => v_message );

    IF ( v_return != 'S' ) THEN

      RAISE e_error;

    END IF;

    COMMIT;

    -- Se verifica si daily rates dio warning o error
    IF ( v_return_dr = 'W' ) THEN

      v_message := v_message_dr;
      RAISE e_warning;

    ELSIF ( v_return_dr = 'E' ) THEN

      v_message := v_message_dr;
      RAISE e_error;

    END IF;

    print_log ('ajc_bc_exchange_rates_pkg.main_p (-)');

  EXCEPTION
    WHEN e_no_rates THEN

      print_log ( 'No rates for sync' );
      ajc_bc_ws_utils_pkg.send_email ( p_to => v_email,
                                       p_subject => 'AJC BC - No rates for sync',
                                       p_message => 'No rates for sync from BC ' || p_bc_environment || ' to Oracle for date ' || p_date );

    WHEN e_warning THEN

      -- 20250623
      ajc_bc_ws_utils_pkg.send_email ( p_to => v_email,
                                       p_subject => 'AJC BC Exchange Rates Interface ' || ' - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') || ' - WARNING',
                                       p_message => 'Request ID: ' || gv_request_id );
      -- 20250623

      ajc_bc_ws_utils_pkg.send_unix_mail_attach ( p_mail => v_email,
                                                  p_report_request_id => v_request_id_excel );

      print_log ( v_message );
      retcode := 1;
      v_conc_status := fnd_concurrent.set_completion_status('WARNING',v_message);
      errbuf := v_message;

    WHEN e_error THEN

      -- 20250623
      ajc_bc_ws_utils_pkg.send_email ( p_to => v_email,
                                       p_subject => 'AJC BC Exchange Rates Interface ' || ' - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') || ' - ERROR',
                                       p_message => 'Request ID: ' || gv_request_id );
      -- 20250623

      ajc_bc_ws_utils_pkg.send_unix_mail_attach ( p_mail => v_email,
                                                  p_report_request_id => v_request_id_excel );

      print_log ( v_message );
      retcode := 2;
      v_conc_status := fnd_concurrent.set_completion_status('ERROR',v_message);
      errbuf := v_message;

    WHEN OTHERS THEN

      -- 20250623
      ajc_bc_ws_utils_pkg.send_email ( p_to => v_email,
                                       p_subject => 'AJC BC Exchange Rates Interface ' || ' - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') || ' - ERROR',
                                       p_message => 'Request ID: ' || gv_request_id );
      -- 20250623

      ajc_bc_ws_utils_pkg.send_unix_mail_attach ( p_mail => v_email,
                                                  p_report_request_id => v_request_id_excel );

      print_log ( 'Error general: ' || SQLERRM );
      retcode := 2;
      v_conc_status := fnd_concurrent.set_completion_status('ERROR',v_message);
      errbuf := v_message;

  END main_p;

END ajc_bc_exchange_rates_pkg;
