PACKAGE BODY AJC_BC_TRANS_INSURED_AGING_PKG IS
  
  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line (fnd_file.log, p_message);

  END print_log;

  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line(fnd_file.output,p_message);

  END print_output;

  PROCEDURE call_report ( p_org_id                         IN    NUMBER,
                          p_as_of_date                     IN    VARCHAR2,         
                          p_set_of_books_id                IN    NUMBER,
                          p_translation_currency           IN    VARCHAR2,         
                          p_translation_rate               IN    NUMBER,
                          p_aig_translation_rate           IN    NUMBER,
                          p_open_acct_cus_lim_curr         IN    VARCHAR2,
                          p_open_acct_cus_lim_trans_rate   IN    NUMBER ) IS

    v_request_id        NUMBER;
    v_conc_phase        VARCHAR2(50);
    v_conc_status       VARCHAR2(50);
    v_conc_dev_phase    VARCHAR2(50);
    v_conc_dev_status   VARCHAR2(50);
    v_conc_message      VARCHAR2(250);
    v_message           VARCHAR2(32000);
    e_cust_exception    EXCEPTION;

  BEGIN

    print_log ( 'AJC_BC_TRANS_INSURED_AGING_PKG.call_report (+)');

    v_request_id := fnd_request.submit_request ( 'XXAJC',
                                                 'AJC_BC_TRANS_INSURED_AGING_RPT', -- AJC BC Translated Insured Aging Report
                                                 argument1 => p_org_id,
                                                 argument2 => p_as_of_date,
                                                 argument3 => p_set_of_books_id,
                                                 argument4 => p_translation_currency,
                                                 argument5 => p_translation_rate,
                                                 argument6 => p_aig_translation_rate,
                                                 argument7 => p_open_acct_cus_lim_curr,
                                                 argument8 => p_open_acct_cus_lim_trans_rate ) ; 

    IF v_request_id = 0 THEN

      v_message := fnd_message.get;
      print_log('Error Ejecutando FND_REQUEST.SUBMIT_REQUEST. AJC_BC_TRANS_INSURED_AGING_RPT - AJC BC Translated Insured Aging Report. Error: ' || v_message || ', ' || SQLERRM);
      RAISE e_cust_exception;

    END IF ;

    print_log ( 'Report Request ID: ' || v_request_id); 

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
      print_log('Error Ejecutando FND_REQUEST.WAIT_FOR_REQUEST. AJC_BC_TRANS_INSURED_AGING_RPT - AJC BC Translated Insured Aging Report, con nro. solicitud ' || 
                 TO_CHAR (v_request_id) || '. Error: ' || v_message || ' ' || SQLERRM);
      RAISE e_cust_exception;

    END IF ;

    IF v_conc_dev_phase != 'COMPLETE' OR v_conc_dev_status != 'NORMAL' THEN

      v_message := fnd_message.get;
      print_log('Error en la ejecucion del concurrente AJC_BC_TRANS_INSURED_AGING_RPT - AJC BC Translated Insured Aging Report, con nro. solicitud ' || 
                 TO_CHAR (v_request_id) || '. Error: ' || v_message || ' ' || SQLERRM);
      RAISE e_cust_exception;

    END IF ;

    print_log ( 'AJC_BC_TRANS_INSURED_AGING_PKG.call_report (-)');

  EXCEPTION
    WHEN OTHERS THEN
      print_log ( 'AJC_BC_TRANS_INSURED_AGING_PKG.call_report (!). Error: ' || SQLERRM );

  END call_report; 

  PROCEDURE populate_table ( p_org_id                  IN   NUMBER,
                             p_as_of_date              IN   DATE,
                             p_report_currency         IN   VARCHAR2,
                             p_transaction_type_low    IN    VARCHAR2,
                             p_transaction_type_high   IN    VARCHAR2) IS

    -- Invoices ----------------------------------------------------------------------------------------------------------------
      CURSOR c_invoices IS
      SELECT c.oracle_company_number company,
             rc.customer_id,
             cle.customerNo customer_number,
             cle.customerName customer_name,
             rct.customer_trx_id,
             cle.trx_number,
             cle.documentNo bc_trx_number,
             'IIN' trx_type,
             'INV' trx_class,
             TO_DATE(SUBSTR(cle.documentDate,1,10),'YYYY-MM-DD') trx_date,
             TO_DATE(SUBSTR(cle.dueDate,1,10),'YYYY-MM-DD') due_date,
             TO_DATE(SUBSTR(cle.postingDate,1,10),'YYYY-MM-DD') gl_date,
             CASE
               WHEN cle.currencyCode IS NULL THEN
                 -- Se muestra la moneda funcional de la org
                 c.currency
               ELSE
                 cle.currencyCode
             END currency_code,
             cle.amount original_amount,
             -- cle.amountLCY original_func_amount,
             cle.amount * NVL(rct.exchange_rate,1) original_func_amount,
             t.term_id,
             NVL(t.attribute1,'UNIDENTIFIED') ajc_term_type,
             su.cust_acct_site_id customer_site_id
        FROM ajc_bc_cle_control cle,
             ajc_bc_companies c,
             apps_orafsys.ra_customers rc,
             ar.ra_customer_trx_all rct,
             ar.ra_cust_trx_types_all rctt,
             apps_orafsys.ra_terms t,
             hz_cust_site_uses_all su
       WHERE cle.sourceCode = 'SALES'
         AND cle.documentType = 'Invoice'
         AND TO_DATE(SUBSTR(cle.postingDate,1,10),'YYYY-MM-DD') <= p_as_of_date
         AND c.org_id = p_org_id
         AND cle.globalDimension1Code = c.oracle_company_number
         AND cle.customerNo = rc.customer_number
         AND cle.trx_number = rct.trx_number
         AND rc.customer_id = rct.bill_to_customer_id
         AND rct.cust_trx_type_id = rctt.cust_trx_type_id
         AND rctt.type = 'INV'
         AND rctt.name >= NVL(p_transaction_type_low,rctt.name)
         AND rctt.name <= NVL(p_transaction_type_high,rctt.name)
         AND rct.term_id = t.term_id (+)
         AND rct.bill_to_site_use_id = su.site_use_id
         -- 20230906
         -- Se excluyen los intercompany
         AND NOT EXISTS ( SELECT 1
                            FROM ajc_bc_ic_customers
                           WHERE customer_number = cle.customerNo )
         -- 20230906
    ORDER BY cle.customerNo,
             cle.customerName,
             cle.documentNo;

    -- Aplicaciones a invoices
    CURSOR c_inv_applications ( p_customer_trx_id   NUMBER ) IS
    SELECT amount_applied,
           acctd_amount_applied_from
      FROM atisprod.ar_receivable_applications_all
     WHERE applied_customer_trx_id = p_customer_trx_id
       AND gl_date <= p_as_of_date;

   -- Payments -----------------------------------------------------------------------------------------------------------------
      CURSOR c_payments IS         
      -- CM
      /*
      SELECT c.oracle_company_number company,
             c.org_id,
             rc.customer_id,
             cle.customerNo customer_number,
             cle.customerName customer_name,
             cle.entryNo payment_schedule_id,
             cle.trx_number doc_number,
             cle.documentNo bc_doc_number,
             'Payment' trx_type,
             'PAY' trx_class,
             TO_DATE(SUBSTR(cle.documentDate,1,10),'YYYY-MM-DD') trx_date,
             TO_DATE(SUBSTR(cle.dueDate,1,10),'YYYY-MM-DD') due_date,
             TO_DATE(SUBSTR(cle.postingDate,1,10),'YYYY-MM-DD') gl_date,
             CASE
               WHEN cle.currencyCode IS NULL THEN
                 -- Se muestra la moneda funcional de la org
                 c.currency
               ELSE
                 cle.currencyCode
             END currency_code,
             cle.amount original_amount,
             -- cle.amountLCY original_func_amount,
             cle.amount * NVL(rct.exchange_rate,1) original_func_amount,
             NULL term_id,
             'UNIDENTIFIED' ajc_term_type
        FROM ajc_bc_cle_control cle,
             ajc_bc_companies c,
             apps_orafsys.ra_customers rc,
             ( SELECT rcta.customer_trx_id,
                      rcta.bill_to_customer_id,
                      rcta.trx_number,
                      rcta.org_id,
                      rcta.term_id,
                      rcta.cust_trx_type_id,
                      rcta.bill_to_site_use_id,
                      -- 20230718
                      rcta.exchange_rate,
                      -- 20230718
                      'Credit Memo' type
                 FROM ar.ra_customer_trx_all rcta,
                      ar.ra_cust_trx_types_all rctt
                WHERE rcta.cust_trx_type_id = rctt.cust_trx_type_id
                  AND rctt.type = 'CM'
                  AND rctt.name >= NVL(p_transaction_type_low,rctt.name)
                  AND rctt.name <= NVL(p_transaction_type_high,rctt.name) ) rct
       WHERE cle.sourceCode = 'SALES' 
         AND cle.documentType = 'Credit Memo'
         AND TO_DATE(SUBSTR(cle.postingDate,1,10),'YYYY-MM-DD') <= p_as_of_date
         AND c.org_id = p_org_id
         AND cle.globalDimension1Code = c.oracle_company_number
         AND cle.customerNo = rc.customer_number
         AND cle.trx_number = rct.trx_number (+)
         AND rc.customer_id = rct.bill_to_customer_id (+)
         AND cle.documentType = rct.type (+)
         -- 20230906
         -- Se excluyen los intercompany
         AND NOT EXISTS ( SELECT 1
                            FROM ajc_bc_ic_customers
                           WHERE customer_number = cle.customerNo )
         -- 20230906
       UNION ALL
      */
      -- Payments
      SELECT c.oracle_company_number company,
             c.org_id,
             rc.customer_id,
             cle.customerNo customer_number,
             cle.customerName customer_name,
             cle.entryNo payment_schedule_id,
             cle.trx_number doc_number,
             cle.documentNo bc_doc_number,
             'Payment' trx_type,
             'PAY' trx_class,
             TO_DATE(SUBSTR(cle.documentDate,1,10),'YYYY-MM-DD') trx_date,
             TO_DATE(SUBSTR(cle.dueDate,1,10),'YYYY-MM-DD') due_date,
             TO_DATE(SUBSTR(cle.postingDate,1,10),'YYYY-MM-DD') gl_date,
             CASE
               WHEN cle.currencyCode IS NULL THEN
                 -- Se muestra la moneda funcional de la org
                 c.currency
               ELSE
                 cle.currencyCode
             END currency_code,
             cle.amount original_amount,
             -- cle.amountLCY original_func_amount,
             cle.amount * ( 1 / cle.originalCurrencyFactor ) original_func_amount,
             NULL term_id,
             'UNIDENTIFIED' ajc_term_type
        FROM ajc_bc_cle_control cle,
             ajc_bc_companies c,
             apps_orafsys.ra_customers rc
       WHERE NVL(cle.sourceCode,'X') != 'SALES'
         AND TO_DATE(SUBSTR(cle.postingDate,1,10),'YYYY-MM-DD') <= p_as_of_date
         AND c.org_id = p_org_id
         AND cle.globalDimension1Code = c.oracle_company_number
         AND cle.customerNo = rc.customer_number
         -- 20230906
         -- Se excluyen los intercompany
         AND NOT EXISTS ( SELECT 1
                            FROM ajc_bc_ic_customers
                           WHERE customer_number = cle.customerNo )
         -- 20230906
    ORDER BY customer_number,
             customer_name,
             doc_number;

    -- Aplicaciones de CM / RCP      
    CURSOR c_pay_applications ( p_payment_schedule_id   NUMBER ) IS            
    /*
    SELECT amount_applied,
           acctd_amount_applied_from
      FROM atisprod.ar_receivable_applications_all
     WHERE payment_schedule_id = p_payment_schedule_id
       AND gl_date <= p_as_of_date
       AND status != 'ACC';
    */
    -- 20231201
    SELECT -1 * app.amount amount_applied,
           ROUND(-1 * app.amount * NVL(rct_app.exchange_rate,( 1 / doc.originalCurrencyFactor) ) ,2) acctd_amount_applied_from
      FROM ajc.ajc_bc_cle_control inv,
           ( SELECT rcta.customer_trx_id,
                    rcta.bill_to_customer_id,
                    rcta.trx_number,
                    rcta.org_id,
                    rcta.term_id,
                    rcta.cust_trx_type_id,
                    rcta.bill_to_site_use_id,
                    rcta.exchange_rate,
                    DECODE(rctt.type,'INV','Invoice','CM','Credit Memo') type
               FROM ar.ra_customer_trx_all rcta,
                    ar.ra_cust_trx_types_all rctt
              WHERE rcta.cust_trx_type_id = rctt.cust_trx_type_id
                AND rcta.creation_date >= TO_DATE('13/10/2017 00:00:00','DD/MM/YYYY HH24:MI:SS')            
                AND rcta.interface_header_context IN ('ATIS','NOT ATIS') ) rct,
           apps_orafsys.ra_customers c,
           ajc.ajc_bc_companies bc,
           ajc.ajc_bc_dcle_control app,
           ajc.ajc_bc_cle_control doc,
           ( SELECT rctb.customer_trx_id,
                    rctb.bill_to_customer_id,
                    rctb.trx_number,
                    rctb.org_id,
                    rctb.term_id,
                    rctb.cust_trx_type_id,
                    rctb.bill_to_site_use_id,
                    rctb.exchange_rate,
                    DECODE(rctt.type,'INV','Invoice','CM','Credit Memo') type
               FROM ar.ra_customer_trx_all rctb,
                    ar.ra_cust_trx_types_all rctt
              WHERE rctb.cust_trx_type_id = rctt.cust_trx_type_id
                AND rctb.creation_date >= TO_DATE('13/10/2017 00:00:00','DD/MM/YYYY HH24:MI:SS')            
                AND rctb.interface_header_context IN ('ATIS','NOT ATIS') ) rct_app
     WHERE ( ( inv.documentType = 'Invoice' AND doc.documentType != 'Invoice' ) OR
             ( inv.documentType = 'Credit Memo' AND doc.documentType != 'Credit Memo' ) )
       AND inv.sourceCode = 'SALES'
       AND inv.customerNo = c.customer_number   
       AND c.customer_id = rct.bill_to_customer_id
       AND inv.trx_number = rct.trx_number
       AND inv.documentType = rct.type
       AND inv.globalDimension1Code = bc.oracle_company_number
       AND bc.org_id = rct.org_id
       AND inv.entryNo = app.custLedgerEntryNo
       AND inv.globalDimension1Code = app.initialEntryGlobalDim1
       AND app.entryType = 'Application'
       AND app.appliedCustLedgerEntryNo = doc.entryNo
       AND app.initialEntryGlobalDim1 = doc.globalDimension1Code
       AND c.customer_id = rct_app.bill_to_customer_id (+)
       AND doc.trx_number = rct_app.trx_number (+)
       AND doc.documentType = rct_app.type (+)
       -- 20230807
       -- Se excluyen los intercompany
       AND NOT EXISTS ( SELECT 1
                          FROM ajc_bc_ic_customers
                         WHERE customer_number = inv.customerNo )
       --
       AND TO_DATE(app.postingDate,'YYYY-MM-DD') <= p_as_of_date
       AND doc.entryNo = p_payment_schedule_id
       AND NVL(doc.sourceCode,'X') != 'SALES';
       -- AND doc.documentType IN ('Payment','Credit Memo');

    v_inv_amount_remaining   NUMBER;
    v_pay_amount_remaining   NUMBER;

    v_customer_site_id       NUMBER;
    v_over_60days_amt        NUMBER;
    v_term_id                ra_terms.term_id%TYPE;
    v_ajc_term_type          ra_terms.attribute1%TYPE;

    v_record_id              NUMBER := 0;

  BEGIN

    print_log ( 'AJC_BC_TRANS_INSURED_AGING_PKG.populate_table (+)');
    print_log ( ' ');
    print_log ( '- Invoices');

    -- Invoices ---------------------------------------------------------------------------------------------------------------- 
    FOR cinv IN c_invoices LOOP

      print_log ( ' ');  
      print_log ( 'Customer Number: ' || cinv.customer_number ); 
      print_log ( 'Customer Name: ' || cinv.customer_name ); 
      print_log ( 'Company: ' || cinv.company );
      print_log ( 'BC Trx Number: ' || cinv.bc_trx_number );
      print_log ( 'Trx Number: ' || cinv.trx_number );
      print_log ( 'Currency Code: ' || cinv.currency_code );
      print_log ( 'Original Amount: ' || cinv.original_amount );
      print_log ( 'Original Functional Amount: ' || cinv.original_func_amount );

      v_inv_amount_remaining := cinv.original_func_amount;
      v_over_60days_amt := NULL;

      -- Se recorren las aplicaciones del invoice
      FOR capp IN c_inv_applications ( p_customer_trx_id => cinv.customer_trx_id ) LOOP

        print_log ( 'Amount Applied: ' || capp.amount_applied );
        print_log ( 'Acctd Amount Applied From: ' || capp.acctd_amount_applied_from );

        v_inv_amount_remaining := v_inv_amount_remaining - capp.acctd_amount_applied_from;

      END LOOP;

      print_log ( 'v_inv_amount_remaining: ' || v_inv_amount_remaining );

      -- 20231201
      v_inv_amount_remaining := ROUND(v_inv_amount_remaining,2);
      -- 20231201

      IF ( v_inv_amount_remaining != 0 ) THEN

        v_record_id := v_record_id + 1;

        IF ( CEIL(p_as_of_date - cinv.due_date) > 60 ) THEN

          v_over_60days_amt := v_inv_amount_remaining;

        END IF;        

        INSERT
          INTO AJC_BC_ARXAGE_TEMP 
             ( trx_number,
               trx_type,
               term_id,
               due_date,
               outstanding_amt,
               current_amt,
               customer_id,
               customer_site_id,
               past_due_1_30_amt,
               past_due_31_60_amt,
               over_60days_amt,
               as_of_date,
               org_id,
               creation_date,
               record_id,
               trx_class,
               ajc_term_type,
               ajc_country_code,
               trans_outstanding_amt,
               trans_current_amt,
               trans_past_due_1_30_amt,
               trans_past_due_31_60_amt,
               trans_over_60days_amt )
      VALUES ( cinv.trx_number,
               cinv.trx_type,
               cinv.term_id,
               cinv.due_date,
               v_inv_amount_remaining, -- outstanding_amt
               NULL, -- current_amt
               cinv.customer_id,
               cinv.customer_site_id, -- customer_site_id
               NULL, -- past_due_1_30_amt
               NULL, -- past_due_31_60_amt
               v_over_60days_amt, -- over_60days_amt
               NULL, -- as_of_date
               NULL, -- org_id
               SYSDATE, -- creation_date
               v_record_id, -- record_id
               cinv.trx_class,
               cinv.ajc_term_type,
               NULL, -- ajc_country_code
               v_inv_amount_remaining, -- trans_outstanding_amt
               NULL, -- trans_current_amt
               NULL, -- trans_past_due_1_30_amt
               NULL, -- trans_past_due_31_60_amt
               v_over_60days_amt -- trans_over_60days_amt 
               );

      END IF;

    END LOOP;

    print_log ( ' ');
    print_log ( '- Payments');

    -- Payments ----------------------------------------------------------------------------------------------------------------    
    FOR cpay IN c_payments LOOP

      print_log ( ' ');
      print_log ( 'Customer Number: ' || cpay.customer_number ); 
      print_log ( 'Customer Name: ' || cpay.customer_name ); 
      print_log ( 'Company: ' || cpay.company );
      print_log ( 'BC Doc Number: ' || cpay.bc_doc_number );
      print_log ( 'Doc Number: ' || cpay.doc_number );
      print_log ( 'Currency Code: ' || cpay.currency_code );
      print_log ( 'Original Amount: ' || cpay.original_amount );
      print_log ( 'Original Amount USD: ' || cpay.original_func_amount );

      v_pay_amount_remaining := cpay.original_func_amount;
      v_customer_site_id := NULL;
      v_over_60days_amt := NULL;

      -- Se recorren las aplicaciones del pago
      FOR capp IN c_pay_applications ( p_payment_schedule_id => cpay.payment_schedule_id ) LOOP

        print_log ( ' Amount Applied: ' || capp.amount_applied );
        print_log ( ' Acctd Amount Applied From: ' || capp.acctd_amount_applied_from );

        v_pay_amount_remaining := v_pay_amount_remaining + capp.acctd_amount_applied_from;

      END LOOP;

      print_log ( 'v_pay_amount_remaining: ' || v_pay_amount_remaining );
      -- 20231201
      v_pay_amount_remaining := ROUND(v_pay_amount_remaining,2);
      -- 20231201

      IF ( v_pay_amount_remaining != 0 ) THEN

        v_record_id := v_record_id + 1;

        IF ( CEIL(p_as_of_date - cpay.due_date) > 60 ) THEN

          v_over_60days_amt := v_pay_amount_remaining;

        END IF;        

        BEGIN

          -- Se obtiene el customer_site_id
          SELECT hcsu.cust_acct_site_id
            INTO v_customer_site_id
            FROM hz_cust_acct_sites_all hcas,
                 hz_party_sites hps,
                 hz_cust_site_uses_all hcsu 
           WHERE hcas.cust_account_id = cpay.customer_id
             AND NVL(hcas.status, 'I') = 'A' 
             AND hcas.party_site_id = hps.party_site_id 
             AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id 
             AND hcsu.primary_flag = 'Y' 
             AND hcsu.org_id = cpay.org_id 
             AND hcsu.site_use_code = 'BILL_TO'; 

        EXCEPTION
          WHEN OTHERS THEN
            v_customer_site_id := NULL;

        END;

        INSERT
          INTO AJC_BC_ARXAGE_TEMP 
             ( trx_number,
               trx_type,
               term_id,
               due_date,
               outstanding_amt,
               current_amt,
               customer_id,
               customer_site_id,
               past_due_1_30_amt,
               past_due_31_60_amt,
               over_60days_amt,
               as_of_date,
               org_id,
               creation_date,
               record_id,
               trx_class,
               ajc_term_type,
               ajc_country_code,
               trans_outstanding_amt,
               trans_current_amt,
               trans_past_due_1_30_amt,
               trans_past_due_31_60_amt,
               trans_over_60days_amt )
      VALUES ( cpay.doc_number,
               cpay.trx_type,
               cpay.term_id,
               cpay.due_date,
               v_pay_amount_remaining, -- outstanding_amt
               NULL, -- current_amt
               cpay.customer_id,
               v_customer_site_id, -- customer_site_id
               NULL, -- past_due_1_30_amt
               NULL, -- past_due_31_60_amt
               v_over_60days_amt, -- over_60days_amt
               NULL, -- as_of_date
               NULL, -- org_id
               SYSDATE, -- creation_date
               v_record_id, -- record_id
               cpay.trx_class,
               cpay.ajc_term_type,
               NULL, -- ajc_country_code
               v_pay_amount_remaining, -- trans_outstanding_amt
               NULL, -- trans_current_amt
               NULL, -- trans_past_due_1_30_amt
               NULL, -- trans_past_due_31_60_amt
               v_over_60days_amt -- trans_over_60days_amt 
               );

      END IF;

    END LOOP;

    print_log ( 'AJC_BC_TRANS_INSURED_AGING_PKG.populate_table (-)');

  EXCEPTION
    WHEN OTHERS THEN
      print_log ( 'AJC_BC_TRANS_INSURED_AGING_PKG.populate_table (!). Error: ' || SQLERRM );

  END populate_table;

  PROCEDURE main_p ( retcode                          OUT   NUMBER,
                     errbuf                           OUT   VARCHAR2,
                     p_org_id                         IN    NUMBER,
                     p_as_of_date                     IN    VARCHAR2,         
                     p_set_of_books_id                IN    NUMBER,
                     p_translation_currency           IN    VARCHAR2,         
                     p_translation_rate               IN    NUMBER,
                     p_aig_translation_rate           IN    NUMBER,
                     p_open_acct_cus_lim_curr         IN    VARCHAR2,
                     p_open_acct_cus_lim_trans_rate   IN    NUMBER,
                     p_transaction_type_low           IN    VARCHAR2,
                     p_transaction_type_high          IN    VARCHAR2 ) IS

  BEGIN

    print_log ( ' ');
    print_log ( 'AJC_BC_TRANS_INSURED_AGING_PKG.main_p (+)');
    print_log ( ' ');

    print_log ( '1. DELETE AJC_BC_ARXAGE_TEMP');

    DELETE AJC_BC_ARXAGE_TEMP;
    COMMIT;

    print_log ( ' ');
    print_log ( '2. POPULATE TABLE');
    populate_table ( p_org_id => p_org_id,
                     p_as_of_date => TO_DATE(SUBSTR(p_as_of_date,1,10),'YYYY/MM/DD'),
                     p_report_currency => p_translation_currency,
                     p_transaction_type_low => p_transaction_type_low, 
                     p_transaction_type_high => p_transaction_type_high ); 

    print_log ( ' ');
    print_log ( '3. CALL REPORT');

    call_report ( p_org_id                       => p_org_id,
                  p_as_of_date                   => p_as_of_date,  
                  p_set_of_books_id              => p_set_of_books_id,
                  p_translation_currency         => p_translation_currency,     
                  p_translation_rate             => p_translation_rate,
                  p_aig_translation_rate         => p_aig_translation_rate,
                  p_open_acct_cus_lim_curr       => p_open_acct_cus_lim_curr,
                  p_open_acct_cus_lim_trans_rate => p_open_acct_cus_lim_trans_rate );

    print_log ( ' ');
    print_log ( 'AJC_BC_TRANS_INSURED_AGING_PKG.main_p (-)');
    print_log ( ' ');

  END main_p;

END AJC_BC_TRANS_INSURED_AGING_PKG;
