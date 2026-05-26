PACKAGE BODY ajc_bc_ar_override_flag_pkg AS
  
  -- ---------------------------------------------------------------------------------------------------------------------------
  -- Print Log
  -- ---------------------------------------------------------------------------------------------------------------------------
  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line(fnd_file.log, p_message);

  END print_log;

  -- ---------------------------------------------------------------------------------------------------------------------------
  -- Print Output
  -- ---------------------------------------------------------------------------------------------------------------------------
  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line(fnd_file.output,p_message);

  END print_output;

  -- ---------------------------------------------------------------------------------------------------------------------------
  -- Get Override Flag
  -- ---------------------------------------------------------------------------------------------------------------------------
  PROCEDURE get_override_flag ( p_last_bc_processed_date   IN    TIMESTAMP,
                                p_bc_environment           IN    VARCHAR2,
                                p_return                   OUT   VARCHAR2, 
                                p_message                  OUT   VARCHAR2 ) IS

    v_get_url         VARCHAR2(2000);

    -- 20230414 v_get_api_inv     VARCHAR2(100) := 'salesInvoiceHeaderINE';
    v_get_api_inv     VARCHAR2(100);
    -- 20230414 v_get_api_cm      VARCHAR2(100) := 'salescrmemoheaderINE';
    v_get_api_cm      VARCHAR2(100);

    v_clob_result     CLOB;

      CURSOR c_bc_companies IS
      SELECT bc_company_name,
             bc_company_id
        FROM ajc_bc_companies
    GROUP BY bc_company_name,
             bc_company_id
    ORDER BY bc_company_name;

  BEGIN

    print_log ('ajc_bc_ar_override_flag_pkg.get_override_flag (+)');

    v_get_api_inv := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'POSTED SALES INVOICES',
                                                    p_subentity => NULL,
                                                    p_method => 'GET' );
    print_log ( 'v_get_api_inv: ' || v_get_api_inv );

    v_get_api_cm := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'POSTED SALES CREDIT MEMOS',
                                                    p_subentity => NULL,
                                                    p_method => 'GET' );
    print_log ( 'v_get_api_inv: ' || v_get_api_inv );

    FOR cc IN c_bc_companies LOOP

      print_log ( 'Company: ' || cc.bc_company_name );

      -- Get Posted Sales Invoices - Override Flag
      v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, cc.bc_company_id ) || v_get_api_inv 
                   || '?$filter=systemModifiedAt gt ' || TO_CHAR(p_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');
                   -- || '?$filter=no eq ' || '''1516532''';

      print_log ('v_get_url: ' || v_get_url);
      v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );

      INSERT
        INTO ajc_bc_ar_override_flag
           ( company,
             trx_number,
             customer_number,
             override_flag,
             --
             status,
             creation_date,
             request_id )
      SELECT company,
             trx_number,
             customer_number,
             override_flag,
             --
             'NEW' status,
             TRUNC(SYSDATE) creation_date,
             gv_request_id
        FROM json_table( v_clob_result,
                           '$.value[*]' COLUMNS ( company           VARCHAR2(4000)  path '$.shortcutDimension1Code',
                                                  trx_number        VARCHAR2(4000)  path '$.no',
                                                  customer_number   VARCHAR2(4000)  path '$.billToCustomerNo',
                                                  override_flag     VARCHAR2(4000)  path '$.overrideFlagAJCINE' ) );

      -- Get Posted Credit Memos - Override Flag
      v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, cc.bc_company_id ) || v_get_api_cm 
                   || '?$filter=systemModifiedAt gt ' || TO_CHAR(p_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');
                   -- || '?$filter=no eq ' || '''1512403''';

      print_log ('v_get_url: ' || v_get_url);
      v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );

      INSERT
        INTO ajc_bc_ar_override_flag
           ( company,
             trx_number,
             customer_number,
             override_flag,
             --
             status,
             creation_date,
             request_id )
      SELECT company,
             trx_number,
             customer_number,
             override_flag,
             --
             'NEW' status,
             TRUNC(SYSDATE) creation_date,
             gv_request_id
        FROM json_table( v_clob_result,
                           '$.value[*]' COLUMNS ( company           VARCHAR2(4000)  path '$.shortcutDimension1Code',
                                                  trx_number        VARCHAR2(4000)  path '$.no',
                                                  customer_number   VARCHAR2(4000)  path '$.billToCustomerNo',
                                                  override_flag     VARCHAR2(4000)  path '$.overrideFlagAJCINE' ) );

    END LOOP;

    COMMIT;
    p_return := 'S';

    print_log ('ajc_bc_ar_override_flag_pkg.get_override_flag (-)');

  EXCEPTION
    WHEN OTHERS THEN
      print_log ('ajc_bc_ar_override_flag_pkg.get_override_flag (!)');
      p_return := 'E';
      p_message := SQLCODE || ': ' || SQLERRM;

  END get_override_flag;

  -- Get ORG_ID ----------------------------------------------------------------------------------------------------------------
  PROCEDURE get_org_id_p ( p_company   IN       VARCHAR2,
                           p_org_id    IN OUT   NUMBER,                             
                           p_message   IN OUT   VARCHAR2 ) IS
  BEGIN

    print_log ('ajc_bc_ar_override_flag_pkg.get_org_id_p (+)');

    SELECT org_id 
      INTO p_org_id
      FROM ajc_bc_companies 
     WHERE oracle_company_number = p_company;

    print_log ('p_org_id: ' || p_org_id);

    print_log ('ajc_bc_ar_override_flag_pkg.get_org_id_p (-)');

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      p_message := 'Company ''' || p_company || ''' not found.';
      print_log ('ajc_bc_ar_override_flag_pkg.get_org_id_p (!). ' || p_message);

    WHEN TOO_MANY_ROWS THEN
      p_message := 'Company ''' || p_company || ''' duplicated.';
      print_log ('ajc_bc_ar_override_flag_pkg.get_org_id_p (!). ' || p_message);

    WHEN OTHERS THEN
      p_message := 'Company ''' || p_company || ''' error: ' || SQLERRM;
      print_log ('ajc_bc_ar_override_flag_pkg.get_org_id_p (!). ' || p_message);

  END get_org_id_p;

  -- Get CUSTOMER_ID -----------------------------------------------------------------------------------------------------------
  PROCEDURE get_customer_p ( p_customer_number   IN       VARCHAR2,
                             p_customer_id       IN OUT   NUMBER,
                             p_customer_name     IN OUT   VARCHAR2,                             
                             p_message           IN OUT   VARCHAR2 ) IS

  BEGIN

    print_log ('ajc_bc_ar_override_flag_pkg.get_customer_p (+)');

    p_message := NULL;

    SELECT customer_id,
           customer_name
      INTO p_customer_id,
           p_customer_name
      FROM ra_customers
     WHERE customer_number = p_customer_number;

    print_log ('p_customer_id: ' || p_customer_id);
    print_log ('p_customer_name: ' || p_customer_name);

    print_log ('ajc_bc_ar_override_flag_pkg.get_customer_p (-)');

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      p_message := 'Customer No. ''' || p_customer_number || ''' not found.';
      print_log ('ajc_bc_ar_override_flag_pkg.get_customer_p (!). ' || p_message);

    WHEN TOO_MANY_ROWS THEN
      p_message := 'Customer No. ''' || p_customer_number || ''' duplicated.';
      print_log ('ajc_bc_ar_override_flag_pkg.get_customer_p (!). ' || p_message);

    WHEN OTHERS THEN
      p_message := 'Customer ''' || p_customer_name || ''' error: ' || SQLERRM;
      print_log ('ajc_bc_ar_override_flag_pkg.get_customer_p (!). ' || p_message);

  END get_customer_p;

  -- Get CUSTOMER_TRX_ID -----------------------------------------------------------------------------------------------------------
  PROCEDURE get_customer_trx_p ( p_trx_number            IN       VARCHAR2,
                                 p_customer_id           IN       NUMBER,
                                 p_customer_trx_id       IN OUT   NUMBER,
                                 p_org_id                IN       NUMBER,
                                 p_message               IN OUT   VARCHAR2 ) IS

    v_trx_number   VARCHAR2(100);

  BEGIN

    print_log ('ajc_bc_ar_override_flag_pkg.get_customer_trx_p (+)');

    p_message := NULL;

    -- Si comienza con 'AR-', son migradas, en Oracle existen sin AR-
    SELECT DECODE(SUBSTR(p_trx_number,1,3),'AR-',SUBSTR(p_trx_number,4),p_trx_number)
      INTO v_trx_number 
      FROM dual;

    print_log ('v_trx_number: ' || v_trx_number);

    -- Se obtiene el customer_trx_id
    SELECT rct.customer_trx_id
      INTO p_customer_trx_id
      FROM ra_customer_trx_all rct
     WHERE rct.trx_number = v_trx_number
       AND rct.bill_to_customer_id = p_customer_id
       AND org_id = p_org_id;

    print_log ('p_customer_trx_id: ' || p_customer_trx_id);
    print_log ('p_customer_id: ' || p_customer_id);

    print_log ('ajc_bc_ar_override_flag_pkg.get_customer_trx_p (-)');

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      p_message := 'Trx Number. ''' || v_trx_number || ''' not found.';
      print_log ('ajc_bc_ar_override_flag_pkg.get_customer_trx_p (!). ' || p_message);

    WHEN TOO_MANY_ROWS THEN
      p_message := 'Trx Number. ''' || v_trx_number || ''' duplicated.';
      print_log ('ajc_bc_ar_override_flag_pkg.get_customer_trx_p (!). ' || p_message);

    WHEN OTHERS THEN
      p_message := 'Trx Number. ''' || v_trx_number || ''' error: ' || SQLERRM;
      print_log ('ajc_bc_ar_override_flag_pkg.get_customer_trx_p (!). ' || p_message);

  END get_customer_trx_p;

  -- ---------------------------------------------------------------------------------------------------------------------------
  -- Process Override Flag
  -- ---------------------------------------------------------------------------------------------------------------------------
  PROCEDURE process_override_flag ( p_return    OUT      VARCHAR2, 
                                    p_message   OUT      VARCHAR2,
                                    p_count     IN OUT   NUMBER ) IS

    CURSOR c_override_flag IS
    SELECT *
      FROM ajc_bc_ar_override_flag
     WHERE status = 'NEW'
       AND request_id = gv_request_id;

    v_org_id                 ra_customer_trx_all.org_id%TYPE;
    v_customer_id            ra_customers.customer_id%TYPE;
    v_customer_name          ra_customers.customer_name%TYPE;
    v_customer_trx_id        ra_customer_trx_all.customer_trx_id%TYPE;
    v_override_flag_oracle   ra_customer_trx_all.attribute2%TYPE;
    v_override_flag_bc       ra_customer_trx_all.attribute2%TYPE;

    v_message                VARCHAR2(2000);
    e_error                  EXCEPTION;

  BEGIN

    print_log ('ajc_bc_ar_override_flag_pkg.process_override_flag (+)');

    p_count := 0;

    FOR cof IN c_override_flag LOOP

      v_message := NULL;

      BEGIN

        v_org_id := NULL;
        v_customer_id := NULL;
        v_customer_trx_id := NULL;

        get_org_id_p ( p_company => cof.company,
                       p_org_id => v_org_id,                     
                       p_message => v_message );

        IF ( v_org_id IS NULL ) THEN

          RAISE e_error;

        END IF;

        get_customer_p ( p_customer_number => cof.customer_number,
                         p_customer_id => v_customer_id,                                                  
                         p_customer_name => v_customer_name,          
                         p_message => v_message );

        IF ( v_customer_id IS NULL ) THEN

          RAISE e_error;

        END IF;   

        get_customer_trx_p ( p_trx_number => cof.trx_number,
                             p_customer_id => v_customer_id,
                             p_customer_trx_id => v_customer_trx_id,
                             p_org_id => v_org_id,
                             p_message => v_message );

        IF ( v_customer_trx_id IS NULL ) THEN

          RAISE e_error;

        END IF;

        v_override_flag_oracle := NULL;
        v_override_flag_bc := NULL;

        -- Se obtiene el valor del override_flag de oracle para la fc
        SELECT NVL(attribute2,'N')
          INTO v_override_flag_oracle
          FROM ra_customer_trx_all
         WHERE customer_trx_id = v_customer_trx_id;

        print_log ('v_override_flag_oracle: ' || v_override_flag_oracle);

        -- Se obtiene el valor del override_flag de BC
        SELECT DECODE(cof.override_flag,'false','N','true','Y','N')
          INTO v_override_flag_bc
          FROM dual;

        print_log ('v_override_flag_bc: ' || v_override_flag_bc);

        -- Si el valor del override_flag de oracle es distinto al que viene de BC, se actualiza.
        IF ( v_override_flag_oracle != v_override_flag_bc ) THEN

          UPDATE ra_customer_trx_all
             SET attribute2 = v_override_flag_bc
           WHERE customer_trx_id = v_customer_trx_id;

          UPDATE ajc_bc_ar_override_flag
             SET status = 'PROCESSED',
                 org_id = v_org_id,
                 customer_name = v_customer_name,
                 customer_id = v_customer_id,
                 customer_trx_id = v_customer_trx_id
           WHERE trx_number = cof.trx_number
             AND request_id = gv_request_id
             AND status = 'NEW';

          p_count := p_count + 1;

        -- Si es igual, se marca como SKIPPED    
        ELSE

          UPDATE ajc_bc_ar_override_flag
             SET status = 'SKIPPED'
           WHERE trx_number = cof.trx_number
             AND request_id = gv_request_id
             AND status = 'NEW';

        END IF;

      EXCEPTION
        WHEN e_error THEN

          UPDATE ajc_bc_ar_override_flag
             SET status = 'ERROR',
                 message = v_message
           WHERE trx_number = cof.trx_number
             AND request_id = gv_request_id
             AND status = 'NEW';

          p_count := p_count + 1;

        WHEN OTHERS THEN

          UPDATE ajc_bc_ar_override_flag
             SET status = 'ERROR',
                 message = v_message
           WHERE trx_number = cof.trx_number
             AND request_id = gv_request_id
             AND status = 'NEW';

          p_count := p_count + 1;

      END;

    END LOOP;

    p_return := 'S';

    print_log ('ajc_bc_ar_override_flag_pkg.process_override_flag (-)');

  EXCEPTION
    WHEN OTHERS THEN
      p_return := 'E';
      p_message := 'Error general process_override_flag. ' || SQLERRM;

  END process_override_flag;

  -- ---------------------------------------------------------------------------------------------------------------------------
  -- Print Report
  -- ---------------------------------------------------------------------------------------------------------------------------
  PROCEDURE print_report IS

      CURSOR c_override_flag IS
      SELECT ou.name org_name,
             bcof.trx_number,
             bcof.customer_name,
             bcof.customer_number,
             DECODE(bcof.override_flag,'false','N','true','Y',NULL) override_flag,
             bcof.status,
             bcof.message
        FROM ajc_bc_ar_override_flag bcof,
             hr_operating_units ou
       WHERE bcof.status IN ('PROCESSED','ERROR')
         AND bcof.org_id = ou.organization_id (+)
         AND request_id = gv_request_id
    ORDER BY ou.name,
             bcof.trx_number,
             bcof.customer_name,
             bcof.customer_number;

  BEGIN

    print_output ( 'AJC BC AR Override Flag Interface' );
    print_output ( ' ' );

    print_output ( RPAD('Organization',26,' ') || ' | ' ||
                   RPAD('Trx Number',15,' ') || ' | ' ||
                   RPAD('Customer Name',40,' ') || ' | ' ||
                   RPAD('Customer Number',15,' ') || ' | ' ||
                   RPAD('Override Flag',13,' ') || ' | ' ||
                   RPAD('Status',10,' ') || ' | ' ||
                   RPAD('Message',40,' ') );

    print_output ( RPAD('-',177,'-') );

    FOR cof IN c_override_flag LOOP

      print_output ( RPAD(NVL(cof.org_name,' '),26,' ') || ' | ' ||
                     RPAD(cof.trx_number,15,' ') || ' | ' ||
                     RPAD(NVL(cof.customer_name,' '),40,' ') || ' | ' ||
                     RPAD(cof.customer_number,15,' ') || ' | ' ||
                     RPAD(cof.override_flag,13,' ') || ' | ' ||
                     RPAD(cof.status,10,' ') || ' | ' ||
                     RPAD(cof.message,40,' ') );

    END LOOP;

  END print_report;

  -- ---------------------------------------------------------------------------------------------------------------------------
  -- Main
  -- ---------------------------------------------------------------------------------------------------------------------------
  PROCEDURE main_p ( retcode            OUT   NUMBER,
                     errbuf             OUT   VARCHAR2,
                     p_bc_environment   IN    VARCHAR2 ) IS

    v_run_date                 TIMESTAMP;
    v_last_processed_date      TIMESTAMP;
    v_last_bc_processed_date   TIMESTAMP;

    v_return                   VARCHAR2(1);
    v_message                  VARCHAR2(2000);
    v_count                    NUMBER := 0;
    v_email                    VARCHAR2(250);

    e_get                      EXCEPTION;  
    e_process                  EXCEPTION;
    e_create                   EXCEPTION;

  BEGIN

    print_log ('ajc_bc_ar_notes_pkg.main_p (+)');

    -- Se guarda la fecha y hora actual
    v_run_date := systimestamp;
    print_log ( 'v_run_date: ' || v_run_date );

    -- Se obtiene la fecha y hora de Oracle de la ultima ejecucion de la interface
    v_last_processed_date := ajc_bc_ws_utils_pkg.get_ifc_last_processed_date_f ( gv_ifc );
    print_log ( 'Oracle last processed date: ' || v_last_processed_date );    

    -- Se obtiene la fecha y hora de BC de la ultima ejecucion de la interface
    v_last_bc_processed_date := ajc_bc_ws_utils_pkg.get_bc_last_processed_date_f ( v_last_processed_date );
    print_log ( 'BC last processed date: ' || v_last_bc_processed_date );

    get_override_flag ( p_last_bc_processed_date => v_last_bc_processed_date,
                        p_bc_environment => p_bc_environment,
                        p_return => v_return, 
                        p_message => v_message );

    IF ( v_return != 'S' ) THEN

      RAISE e_get;

    END IF;

    process_override_flag ( p_return => v_return, 
                            p_message => v_message,
                            p_count => v_count );

    IF ( v_return != 'S' ) THEN

      RAISE e_process;

    END IF;

    -- Si hay al menos 1 en SUCCESS o ERROR, se imprime el reporte y se manda un mail
    IF ( v_count > 0 ) THEN

       print_report;

       v_email := ajc_bc_ws_utils_pkg.get_emails_f ( 'AR OVERRIDE FLAG' );
       print_log ( 'v_email: ' || v_email );

       -- 20251007
       /*
       ajc_bc_ws_utils_pkg.send_email ( p_to => v_email,
                                        p_subject => 'AJC BC AR Override Flag Interface - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'),
                                        p_message => 'Para mayor detalle, revise el output del request ' || gv_request_id );
       */
       -- 20251007

    END IF;

    -- Se actualiza la tabla de control
    ajc_bc_ws_utils_pkg.upd_ifc_last_processed_date_p ( gv_ifc,
                                                        gv_request_id,
                                                        v_run_date );

    print_log ('ajc_bc_ar_override_flag_pkg.main_p (+)');

  EXCEPTION
    WHEN e_get THEN
        print_log ( 'ajc_bc_ar_override_flag_pkg.main_p (!)' );
        print_log ( 'Error al obtener las notas de comprobantes de AR de BC. ' || v_message );
        retcode := 2;
        errbuf := v_message;
      WHEN e_process THEN
        print_log ( 'ajc_bc_ar_override_flag_pkg.main_p (!)' );
        print_log ( 'Error al procesar las notas de AR. ' || v_message );
        retcode := 2;
        errbuf := v_message;
      WHEN e_create THEN
        print_log ( 'ajc_bc_ar_override_flag_pkg.main_p (!)' );
        print_log ( 'Error al intentar crear las notas en comprobantes de AR. ' || v_message );
        retcode := 2;
        errbuf := v_message;
      WHEN OTHERS THEN
        print_log ('ajc_bc_ar_override_flag_pkg,main_p (!)');
        print_log ('Error general main_p. ' || SQLERRM);
        retcode := 2;
        errbuf := 'Error general main_p. ' || SQLERRM;

  END main_p;

END ajc_bc_ar_override_flag_pkg;
