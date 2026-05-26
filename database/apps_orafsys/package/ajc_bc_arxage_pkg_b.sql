PACKAGE BODY ajc_bc_arxage_pkg IS
  
  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line (fnd_file.log, p_message);

  END print_log;

  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line(fnd_file.output,p_message);

  END print_output;

  PROCEDURE populate_table ( p_as_of_date              IN   DATE,
                             p_customer_name_low       IN   VARCHAR2,
                             p_customer_name_high      IN   VARCHAR2,
                             p_customer_number_low     IN   VARCHAR2,
                             p_customer_number_high    IN   VARCHAR2,
                             p_transaction_type_low    IN   VARCHAR2,
                             p_transaction_type_high   IN   VARCHAR2,
                             p_org_id                  IN   NUMBER ) IS

      CURSOR c_invoices IS
      SELECT c.oracle_company_number company,
             rc.customer_id,
             rc.customer_name,
             rc.customer_number,
             rct.customer_trx_id,
             cle.trx_number,
             cle.documentNo bc_trx_number,
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
             cle.amount * NVL(rct.exchange_rate,1) original_func_amount,
             rctt.name type
        FROM ajc_bc_cle_control cle,
             ra_customers rc,
             ajc_bc_companies c,
             ar.ra_customer_trx_all rct,
             ar.ra_cust_trx_types_all rctt
       WHERE cle.sourceCode = 'SALES'
         AND cle.documentType = 'Invoice'
         AND TO_DATE(SUBSTR(cle.postingDate,1,10),'YYYY-MM-DD') <= p_as_of_date
         AND cle.customerNo = rc.customer_number
         AND rc.customer_name >= NVL(p_customer_name_low,rc.customer_name)
         AND rc.customer_name <= NVL(p_customer_name_high,rc.customer_name)
         AND rc.customer_number >= NVL(p_customer_number_low,rc.customer_number)
         AND rc.customer_number <= NVL(p_customer_number_high,rc.customer_number)
         AND c.org_id = p_org_id
         AND cle.globalDimension1Code = c.oracle_company_number
         AND cle.trx_number = rct.trx_number
         AND rct.bill_to_customer_id = rc.customer_id
         AND rct.cust_trx_type_id = rctt.cust_trx_type_id
         AND rctt.type = 'INV'
         AND rctt.name >= NVL(p_transaction_type_low,rctt.name)
         AND rctt.name <= NVL(p_transaction_type_high,rctt.name)
         -- 20230906
         -- Se excluyen los intercompany
         AND NOT EXISTS ( SELECT 1
                            FROM ajc_bc_ic_customers
                           WHERE customer_number = cle.customerNo );
         -- 20230906

    -- Aplicaciones a invoices
    CURSOR c_inv_applications ( p_customer_trx_id   NUMBER ) IS
    SELECT amount_applied,
           acctd_amount_applied_from
      FROM atisprod.ar_receivable_applications_all
     WHERE applied_customer_trx_id = p_customer_trx_id
       AND gl_date <= p_as_of_date;

    -- 20230901
    CURSOR c_payments IS
    -- CM
    SELECT c.oracle_company_number company,
           rc.customer_id,
           rc.customer_name,
           rc.customer_number,
           cle.entryNo payment_schedule_id,
           cle.trx_number doc_number,
           cle.documentNo bc_doc_number,
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
           cle.amount * NVL(rct.exchange_rate,1) original_func_amount,
           NVL(rct.name,'ICM') type
      FROM ajc_bc_cle_control cle,
           ra_customers rc,
           ajc_bc_companies c,
           ( SELECT rcta.customer_trx_id,
                      rcta.bill_to_customer_id,
                      rcta.trx_number,
                      rcta.org_id,
                      rcta.term_id,
                      rcta.cust_trx_type_id,
                      rcta.bill_to_site_use_id,
                      rcta.exchange_rate,
                      rctt.name,
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
       AND cle.customerNo = rc.customer_number
       AND rc.customer_name >= NVL(p_customer_name_low,rc.customer_name)
       AND rc.customer_name <= NVL(p_customer_name_high,rc.customer_name)
       AND rc.customer_number >= NVL(p_customer_number_low,rc.customer_number)
       AND rc.customer_number <= NVL(p_customer_number_high,rc.customer_number)
       AND c.org_id = p_org_id
       AND cle.globalDimension1Code = c.oracle_company_number
       AND cle.trx_number = rct.trx_number (+)
       AND rc.customer_id = rct.bill_to_customer_id (+)
       AND cle.documentType = rct.type (+)
       -- 20230906
       -- Se excluyen los intercompany
       AND NOT EXISTS ( SELECT 1
                          FROM ajc_bc_ic_customers
                         WHERE customer_number = cle.customerNo )
       -- 20230906
     UNION   
    -- Payments
    SELECT c.oracle_company_number company,
           rc.customer_id,
           rc.customer_name,
           rc.customer_number,
           cle.entryNo payment_schedule_id,
           cle.trx_number doc_number,
           cle.documentNo bc_doc_number,
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
           cle.amount * ( 1 / cle.originalCurrencyFactor ) original_func_amount,
           'Paym' type
      FROM ajc_bc_cle_control cle,
           ajc_bc_companies c,
           apps_orafsys.ra_customers rc
     WHERE NVL(cle.sourceCode,'X') != 'SALES'
       AND TO_DATE(SUBSTR(cle.postingDate,1,10),'YYYY-MM-DD') <= p_as_of_date
       AND c.org_id = p_org_id
       AND rc.customer_name >= NVL(p_customer_name_low,rc.customer_name)
       AND rc.customer_name <= NVL(p_customer_name_high,rc.customer_name)
       AND rc.customer_number >= NVL(p_customer_number_low,rc.customer_number)
       AND rc.customer_number <= NVL(p_customer_number_high,rc.customer_number)
       AND cle.globalDimension1Code = c.oracle_company_number
       AND cle.customerNo = rc.customer_number
       -- 20230906
       -- Se excluyen los intercompany
       AND NOT EXISTS ( SELECT 1
                          FROM ajc_bc_ic_customers
                         WHERE customer_number = cle.customerNo );

    -- Aplicaciones de CM / RCP      
    CURSOR c_pay_applications ( p_payment_schedule_id   NUMBER ) IS            
    SELECT amount_applied,
           acctd_amount_applied_from
      FROM atisprod.ar_receivable_applications_all
     WHERE payment_schedule_id = p_payment_schedule_id
       AND gl_date <= p_as_of_date
       AND status != 'ACC';    
    -- 20230901

    v_days_late                  NUMBER;
    v_outstanding_amount         NUMBER;
    v_current_amount             NUMBER;
    v_days_past_due_1_30         NUMBER;
    v_days_past_due_31_60        NUMBER;
    v_days_past_due_61_plus      NUMBER;
    v_percentage_unpaid          NUMBER;

  BEGIN

    print_log ( 'ajc_bc_arxage_pkg.populate_table (+)');

    print_log ( 'Invoices --------------------------------------------------------------------------------------------------' );
    FOR cinv IN c_invoices LOOP

      print_log ( ' ');
      print_log ( '- Invoice -');  
      print_log ( 'Customer ID: ' || cinv.customer_id );
      print_log ( 'Customer Name: ' || cinv.customer_name );
      print_log ( 'Customer Number: ' || cinv.customer_number );
      print_log ( 'BC Trx Number: ' || cinv.bc_trx_number );
      print_log ( 'Trx Number: ' || cinv.trx_number );
      print_log ( 'Currency Code: ' || cinv.currency_code );
      print_log ( 'Original Amount: ' || cinv.original_amount );
      print_log ( 'Original Functional Amount: ' || cinv.original_func_amount );

      v_current_amount := 0;
      v_days_past_due_1_30 := 0;
      v_days_past_due_31_60 := 0;
      v_days_past_due_61_plus := 0;
      v_days_late := p_as_of_date - cinv.due_date;

      v_outstanding_amount := cinv.original_func_amount;

      -- Se recorren las aplicaciones del invoice
      FOR capp IN c_inv_applications ( p_customer_trx_id => cinv.customer_trx_id ) LOOP

        print_log ( 'Amount Applied: ' || capp.amount_applied );
        print_log ( 'Acctd Amount Applied From: ' || capp.acctd_amount_applied_from );

        v_outstanding_amount := v_outstanding_amount - capp.acctd_amount_applied_from;

      END LOOP;

      print_log ( 'v_outstanding_amount: ' || v_outstanding_amount );

      -- Buckets
      IF ( CEIL(p_as_of_date - cinv.due_date) < 1 ) THEN

        v_current_amount := v_outstanding_amount;

      ELSIF ( CEIL(p_as_of_date - cinv.due_date) >= 1 AND
              CEIL(p_as_of_date - cinv.due_date) <= 30 ) THEN

        v_days_past_due_1_30 := v_outstanding_amount;

      ELSIF ( CEIL(p_as_of_date - cinv.due_date) > 30 AND
              CEIL(p_as_of_date - cinv.due_date) <= 60 ) THEN

        v_days_past_due_31_60 := v_outstanding_amount;

      ELSIF ( CEIL(p_as_of_date - cinv.due_date) > 60 ) THEN

        v_days_past_due_61_plus := v_outstanding_amount;

      END IF;  

      print_log ( 'v_current_amount: ' || v_current_amount );
      print_log ( 'v_days_past_due_1_30: ' || v_days_past_due_1_30 );
      print_log ( 'v_days_past_due_31_60: ' || v_days_past_due_31_60 );
      print_log ( 'v_days_past_due_61_plus: ' || v_days_past_due_61_plus );

      -- 20230912
      IF ( cinv.original_func_amount = 0 ) THEN

        v_percentage_unpaid := 0;

      ELSE
      -- 20230912  
        v_percentage_unpaid := TRUNC(v_outstanding_amount * 100 / cinv.original_func_amount );
      -- 20230912  
      END IF;
      -- 20230912

        INSERT 
          INTO AJC_BC_ARXAGE (
               customer_id,
               customer_number,
               customer_name,
               invoice_number,
               type,
               due_date,
               reference_number,
               days_late,
               percentage_unpaid,
               original_amount,
               outstanding_amount,
               current_amount,
               days_past_due_1_30,
               days_past_due_31_60,
               days_past_due_61_plus )
      VALUES ( cinv.customer_id,
               cinv.customer_number,
               cinv.customer_name,
               cinv.trx_number,
               cinv.type,
               cinv.due_date,
               NULL, -- reference_number
               v_days_late,
               v_percentage_unpaid,
               cinv.original_func_amount,
               v_outstanding_amount,
               v_current_amount,
               v_days_past_due_1_30,
               v_days_past_due_31_60,
               v_days_past_due_61_plus );                 

    END LOOP;

    -- 20230901
    print_log ( 'Payments --------------------------------------------------------------------------------------------------' );
    FOR cpay IN c_payments LOOP

      print_log ( ' ');
      print_log ( '- Payment -');  
      print_log ( 'Customer ID: ' || cpay.customer_id );
      print_log ( 'Customer Name: ' || cpay.customer_name );
      print_log ( 'Customer Number: ' || cpay.customer_number );
      print_log ( 'BC Doc Number: ' || cpay.bc_doc_number );
      print_log ( 'Doc Number: ' || cpay.doc_number );
      print_log ( 'Currency Code: ' || cpay.currency_code );
      print_log ( 'Original Amount: ' || cpay.original_amount );
      print_log ( 'Original Functional Amount: ' || cpay.original_func_amount );

      v_current_amount := 0;
      v_days_past_due_1_30 := 0;
      v_days_past_due_31_60 := 0;
      v_days_past_due_61_plus := 0;
      v_days_late := p_as_of_date - cpay.due_date;

      v_outstanding_amount := cpay.original_func_amount;

      -- Se recorren las aplicaciones del pago
      FOR capp IN c_pay_applications ( p_payment_schedule_id => cpay.payment_schedule_id ) LOOP

        print_log ( ' Amount Applied: ' || capp.amount_applied );
        print_log ( ' Acctd Amount Applied From: ' || capp.acctd_amount_applied_from );

        v_outstanding_amount := v_outstanding_amount + capp.acctd_amount_applied_from;

      END LOOP;

      print_log ( 'v_outstanding_amount: ' || v_outstanding_amount );

      -- Buckets
      IF ( CEIL(p_as_of_date - cpay.due_date) < 1 ) THEN

        v_current_amount := v_outstanding_amount;

      ELSIF ( CEIL(p_as_of_date - cpay.due_date) >= 1 AND
              CEIL(p_as_of_date - cpay.due_date) <= 30 ) THEN

        v_days_past_due_1_30 := v_outstanding_amount;

      ELSIF ( CEIL(p_as_of_date - cpay.due_date) > 30 AND
              CEIL(p_as_of_date - cpay.due_date) <= 60 ) THEN

        v_days_past_due_31_60 := v_outstanding_amount;

      ELSIF ( CEIL(p_as_of_date - cpay.due_date) > 60 ) THEN

        v_days_past_due_61_plus := v_outstanding_amount;

      END IF;  

      print_log ( 'v_current_amount: ' || v_current_amount );
      print_log ( 'v_days_past_due_1_30: ' || v_days_past_due_1_30 );
      print_log ( 'v_days_past_due_31_60: ' || v_days_past_due_31_60 );
      print_log ( 'v_days_past_due_61_plus: ' || v_days_past_due_61_plus );

      -- 20230912
      IF ( cpay.original_func_amount = 0 ) THEN

        v_percentage_unpaid := 0;

      ELSE
      -- 20230912  

        v_percentage_unpaid := TRUNC(v_outstanding_amount * 100 / cpay.original_func_amount );

      -- 20230912   
      END IF;
      -- 20230912 

        INSERT 
          INTO AJC_BC_ARXAGE (
               customer_id,
               customer_number,
               customer_name,
               invoice_number,
               type,
               due_date,
               reference_number,
               days_late,
               percentage_unpaid,
               original_amount,
               outstanding_amount,
               current_amount,
               days_past_due_1_30,
               days_past_due_31_60,
               days_past_due_61_plus )
      VALUES ( cpay.customer_id,
               cpay.customer_number,
               cpay.customer_name,
               cpay.doc_number,
               cpay.type,
               cpay.due_date,
               NULL, -- reference_number
               v_days_late,
               v_percentage_unpaid,
               cpay.original_func_amount,
               v_outstanding_amount,
               v_current_amount,
               v_days_past_due_1_30,
               v_days_past_due_31_60,
               v_days_past_due_61_plus ); 

    END LOOP;
    -- 20230901

    print_log ( 'ajc_bc_arxage_pkg.populate_table (-)');

  END populate_table;

  PROCEDURE print_report ( p_reporting_level         IN   NUMBER,
                           p_reporting_context       IN   NUMBER, -- org_id
                           p_set_of_books_currency   IN   VARCHAR2,
                           p_chart_of_accounts       IN   NUMBER,
                           p_as_of_date              IN   VARCHAR2,
                           p_order_by                IN   VARCHAR2,
                           p_report_summary          IN   VARCHAR2, -- Customer | Invoice
                           p_report_format           IN   VARCHAR2, -- Brief | Detailed
                           p_aging_bucket_name       IN   VARCHAR2,
                           p_show_open_credits       IN   VARCHAR2,
                           p_show_receipts_at_risk   IN   VARCHAR2,
                           p_customer_name_low       IN   VARCHAR2,
                           p_customer_name_high      IN   VARCHAR2,
                           p_customer_number_low     IN   VARCHAR2,
                           p_customer_number_high    IN   VARCHAR2,
                           p_balance_due_low         IN   NUMBER,
                           p_balance_due_high        IN   NUMBER,
                           p_transaction_type_low    IN   VARCHAR2,
                           p_transaction_type_high   IN   VARCHAR2 ) IS

    v_set_of_books_name       gl_sets_of_books.name%TYPE;
    v_reporting_level         FND_LOOKUPS.meaning%TYPE;
    v_org_name                hr_operating_units.name%TYPE;
    v_report_summary          ar_lookups.meaning%TYPE;
    v_report_format           ar_lookups.meaning%TYPE;
    v_show_open_credits       ar_lookups.meaning%TYPE;
    v_show_receipts_at_risk   ar_lookups.meaning%TYPE;

      -- Customers
      CURSOR c_customers IS
      SELECT customer_id, 
             customer_number, 
             customer_name
        FROM AJC_BC_ARXAGE
       -- 20230906
       WHERE outstanding_amount != 0
       -- 20230906
    GROUP BY customer_id, 
             customer_number, 
             customer_name
    ORDER BY customer_name; 

      -- Invoices and Payments
      CURSOR c_invoices_payments ( p_customer_id   IN   NUMBER ) IS
      SELECT invoice_number,
             type,
             TO_CHAR(due_date,'DD-MON-YY') due_date,
             reference_number,
             days_late,
             percentage_unpaid,
             outstanding_amount,
             current_amount,
             days_past_due_1_30,
             days_past_due_31_60,
             days_past_due_61_plus
        FROM AJC_BC_ARXAGE
       WHERE customer_id = p_customer_id
         -- 20230906
         AND outstanding_amount != 0
         -- 20230906
    ORDER BY DECODE(p_order_by,'Customer',customer_name,'Type',type);

      -- Customer Total 
      CURSOR c_cust_total ( p_customer_id   IN   NUMBER ) IS
      SELECT SUM(outstanding_amount) outstanding_amount,
             SUM(current_amount) current_amount,
             SUM(days_past_due_1_30) days_past_due_1_30,
             SUM(days_past_due_31_60) days_past_due_31_60,
             SUM(days_past_due_61_plus) days_past_due_61_plus,
             -- Percentage
             CASE
               WHEN SUM(outstanding_amount) != 0 THEN
                 ROUND(SUM(current_amount) * 100 / SUM(outstanding_amount),2) 
               ELSE
                 0
             END perc_current_amount,
             CASE
               WHEN SUM(outstanding_amount) != 0 THEN
                 ROUND(SUM(days_past_due_1_30) * 100 / SUM(outstanding_amount),2) 
               ELSE
                 0
             END perc_days_past_due_1_30,
             CASE
               WHEN SUM(outstanding_amount) != 0 THEN
                 ROUND(SUM(days_past_due_31_60) * 100 / SUM(outstanding_amount),2) 
               ELSE
                 0
             END perc_days_past_due_31_60,
             CASE
               WHEN SUM(outstanding_amount) != 0 THEN
                 ROUND(SUM(days_past_due_61_plus) * 100 / SUM(outstanding_amount),2) 
               ELSE
                 0
             END perc_days_past_due_61_plus
             --
        FROM AJC_BC_ARXAGE
       WHERE customer_id = p_customer_id
         -- 20230906
         AND outstanding_amount != 0
      HAVING SUM(outstanding_amount) != 0;
         -- 20230906

      -- Total for All Customers 
      CURSOR c_tot_all_cust IS
      SELECT SUM(outstanding_amount) outstanding_amount,
             SUM(current_amount) current_amount,
             SUM(days_past_due_1_30) days_past_due_1_30,
             SUM(days_past_due_31_60) days_past_due_31_60,
             SUM(days_past_due_61_plus) days_past_due_61_plus,
             -- Percentage
             CASE
               WHEN SUM(outstanding_amount) != 0 THEN
                 ROUND(SUM(current_amount) * 100 / SUM(outstanding_amount),2) 
               ELSE
                 0
             END perc_current_amount,
             CASE
               WHEN SUM(outstanding_amount) != 0 THEN
                 ROUND(SUM(days_past_due_1_30) * 100 / SUM(outstanding_amount),2) 
               ELSE
                 0
             END perc_days_past_due_1_30,
             CASE
               WHEN SUM(outstanding_amount) != 0 THEN
                 ROUND(SUM(days_past_due_31_60) * 100 / SUM(outstanding_amount),2) 
               ELSE
                 0
             END perc_days_past_due_31_60,
             CASE
               WHEN SUM(outstanding_amount) != 0 THEN
                 ROUND(SUM(days_past_due_61_plus) * 100 / SUM(outstanding_amount),2) 
               ELSE
                 0
             END perc_days_past_due_61_plus
             --
        FROM AJC_BC_ARXAGE
       -- 20230906
       WHERE outstanding_amount != 0
      HAVING SUM(outstanding_amount) != 0;
       -- 20230906;

    v_spaces        NUMBER;
    v_spaces_perc   NUMBER;

  BEGIN

    print_log ( 'ajc_bc_arxage_pkg.print_report (+)');

    -- Get Set Of Books Name
    SELECT name 
      INTO v_set_of_books_name
      FROM gl_sets_of_books
     WHERE set_of_books_id = p_set_of_books_currency;

    -- Get Reporting Level
    SELECT meaning 
      INTO v_reporting_level
      FROM fnd_lookups 
     WHERE lookup_type = 'XLA_MO_REPORTING_LEVEL' 
       AND lookup_code = p_reporting_level;

    -- Get Org Name
    SELECT name 
      INTO v_org_name
      FROM hr_operating_units 
     WHERE organization_id = p_reporting_context;

    -- Get Report Summary
    SELECT meaning
      INTO v_report_summary
      FROM ar_lookups
     WHERE lookup_type = 'REPORT_TYPE'
       AND lookup_code = p_report_summary;

    -- Get Report Format
    SELECT meaning
      INTO v_report_format
      FROM ar_lookups
     WHERE lookup_type = 'REPORT_FORMAT'
       AND lookup_code = p_report_format;

    -- Get Show Open Credits   
    SELECT meaning
      INTO v_show_open_credits
      FROM ar_lookups  
     WHERE lookup_type = 'OPEN_CREDITS'
       AND lookup_code = p_show_open_credits;

    -- Get Show Receipts At Risk
    SELECT meaning 
      INTO v_show_receipts_at_risk
      FROM ar_lookups 
     WHERE lookup_type = 'SHOW_RISK' 
       AND lookup_code = p_show_receipts_at_risk;

    print_output ( v_set_of_books_name || '                                                                                           Report Date: ' || TO_CHAR(SYSDATE,'DD-MON-YYYY HH24:MI') );
    print_output ( '                                                   AJC BC Aging - 4 Buckets Report' );
    print_output ( ' ' );
    print_output ( 'Reporting level: ' || v_reporting_level );
    print_output ( 'Reporting context: ' || v_org_name );
    print_output ( 'As of GL Date: ' || TO_CHAR(TO_DATE(SUBSTR(p_as_of_date,1,10),'YYYY/MM/DD'),'DD-MON-YYYY') );
    print_output ( 'Order By: ' || p_order_by );
    print_output ( 'Report Summary: ' || v_report_summary );
    print_output ( 'Report Format: ' || v_report_format );
    print_output ( 'Aging Bucket Name: ' || p_aging_bucket_name );
    print_output ( 'Show Open Credits: ' || v_show_open_credits );
    print_output ( 'Show Receipts at Risk: ' || v_show_receipts_at_risk );
    print_output ( 'Customer Name: ' || RPAD(NVL(p_customer_name_low,' '),40,' ') || ' To ' || p_customer_name_high );
    print_output ( 'Customer Number: ' || RPAD(NVL(p_customer_number_low,' '),38,' ') || ' To ' || p_customer_number_high );
    print_output ( 'Balance Due: ' || RPAD(NVL(TO_CHAR(p_balance_due_low),' '),42,' ') || ' To ' || p_balance_due_high );
    print_output ( 'Transaction Type: ' || RPAD(NVL(p_transaction_type_low,' '),37,' ') || ' To ' || p_transaction_type_high );
    print_output ( ' ' );
    print_output ( ' ' );

    -- Invoices and Payments
    IF ( p_report_summary = 'I' ) THEN -- Invoice

      print_output ( 'Invoice           Due       Reference    Days      %     Outstanding                       1-30 Days      31-60 Days        61+ Days' );
      print_output ( 'Number       Type Date      Number       Late Unpaid          Amount         Current        Past Due        Past Due        Past Due' );
      print_output ( '------------ ---- --------- ----------- ----- ------ --------------- --------------- --------------- --------------- ---------------' );
      print_output ( ' ' );

      FOR cc IN c_customers LOOP

        print_output ( RPAD(cc.customer_name,47,' ') || cc.customer_number );

        FOR cinvpay IN c_invoices_payments ( p_customer_id => cc.customer_id ) LOOP

          print_output ( RPAD(cinvpay.invoice_number,12,' ') || ' ' ||
                         RPAD(cinvpay.type,4,' ') || ' ' ||
                         RPAD(cinvpay.due_date,9,' ') || ' ' ||
                         RPAD(NVL(cinvpay.reference_number,' '),11,' ') || ' ' || 
                         LPAD(cinvpay.days_late,5,' ') || ' ' ||
                         LPAD(cinvpay.percentage_unpaid,6,' ') || ' ' ||
                         LPAD(TRIM(TO_CHAR(cinvpay.outstanding_amount,'999,999,990.00')),15,' ') || ' ' ||
                         LPAD(TRIM(TO_CHAR(cinvpay.current_amount,'999,999,990.00')),15,' ') || ' ' ||
                         LPAD(TRIM(TO_CHAR(cinvpay.days_past_due_1_30,'999,999,990.00')),15,' ') || ' ' ||
                         LPAD(TRIM(TO_CHAR(cinvpay.days_past_due_31_60,'999,999,990.00')),15,' ') || ' ' ||
                         LPAD(TRIM(TO_CHAR(cinvpay.days_past_due_61_plus,'999,999,990.00')),15,' ') );

        END LOOP; -- End Invoices and Payments

        print_output ( '                                                     --------------- --------------- --------------- --------------- ---------------' );

        FOR ccus_tot IN c_cust_total ( p_customer_id => cc.customer_id ) LOOP

          print_output ( '                                             Total:  ' || LPAD(TRIM(TO_CHAR(ccus_tot.outstanding_amount,'999,999,990.00')),15,' ') || ' ' ||
                                                                                    LPAD(TRIM(TO_CHAR(ccus_tot.current_amount,'999,999,990.00')),15,' ') || ' ' ||
                                                                                    LPAD(TRIM(TO_CHAR(ccus_tot.days_past_due_1_30,'999,999,990.00')),15,' ') || ' ' ||
                                                                                    LPAD(TRIM(TO_CHAR(ccus_tot.days_past_due_31_60,'999,999,990.00')),15,' ') || ' ' ||
                                                                                    LPAD(TRIM(TO_CHAR(ccus_tot.days_past_due_61_plus,'999,999,990.00')),15,' ') ); 
          print_output ( '                                                                     ' || LPAD(TRIM(TO_CHAR(ccus_tot.perc_current_amount,'999990.00')) || '%',15,' ') || ' ' || 
                                                                                                    LPAD(TRIM(TO_CHAR(ccus_tot.perc_days_past_due_1_30,'999990.00')) || '%',15,' ') || ' ' ||
                                                                                                    LPAD(TRIM(TO_CHAR(ccus_tot.perc_days_past_due_31_60,'999990.00')) || '%',15,' ') || ' ' ||
                                                                                                    LPAD(TRIM(TO_CHAR(ccus_tot.perc_days_past_due_61_plus,'999990.00')) || '%',15,' ') ); 
          print_output ( '     Customer Balance:' || LPAD(ccus_tot.outstanding_amount,15,' ') );

        END LOOP; -- End Customer Total

        print_output ( ' ' );

      END LOOP; -- End Customer

    ELSE -- Customer

      print_output ( '                                     Customer     Outstanding                       1-30 Days      31-60 Days        61+ Days' );   
      print_output ( 'Customer Name                        Number            Amount         Current        Past Due        Past Due        Past Due' );
      print_output ( '------------------------------------ -------- --------------- --------------- --------------- --------------- ---------------' );

      FOR cc IN c_customers LOOP

        FOR ccus_tot IN c_cust_total ( p_customer_id => cc.customer_id ) LOOP

          print_output ( ' ' );
          print_output ( RPAD(cc.customer_name,36,' ') || ' ' || 
                         RPAD(cc.customer_number,8,' ') || ' ' || 
                         LPAD(TRIM(TO_CHAR(ccus_tot.outstanding_amount,'999,999,990.00')),15,' ') || ' ' ||
                         LPAD(TRIM(TO_CHAR(ccus_tot.current_amount,'999,999,990.00')),15,' ') || ' ' ||
                         LPAD(TRIM(TO_CHAR(ccus_tot.days_past_due_1_30,'999,999,990.00')),15,' ') || ' ' ||
                         LPAD(TRIM(TO_CHAR(ccus_tot.days_past_due_31_60,'999,999,990.00')),15,' ') || ' ' ||
                         LPAD(TRIM(TO_CHAR(ccus_tot.days_past_due_61_plus,'999,999,990.00')),15,' ') ); 
          print_output ( '                                                              ' || 
                         LPAD(TRIM(TO_CHAR(ccus_tot.perc_current_amount,'999990.00')) || '%',15,' ') || ' ' || 
                         LPAD(TRIM(TO_CHAR(ccus_tot.perc_days_past_due_1_30,'999990.00')) || '%',15,' ') || ' ' ||
                         LPAD(TRIM(TO_CHAR(ccus_tot.perc_days_past_due_31_60,'999990.00')) || '%',15,' ') || ' ' ||
                         LPAD(TRIM(TO_CHAR(ccus_tot.perc_days_past_due_61_plus,'999990.00')) || '%',15,' ') ); 

        END LOOP; -- End Customer Total

      END LOOP; -- End Customer

    END IF;

    -- Total For All Customers
    FOR c_tot_all_c IN c_tot_all_cust LOOP

      IF ( p_report_summary = 'I' ) THEN

        v_spaces := 53;
        v_spaces_perc := 69;

      ELSE

        v_spaces := 46;
        v_spaces_perc := 62;

      END IF;      

      print_output ( RPAD(' ',v_spaces,' ') || '--------------- --------------- --------------- --------------- ---------------' );
      print_output ( RPAD('Total For All Customers:',v_spaces,' ') || LPAD(TRIM(TO_CHAR(c_tot_all_c.outstanding_amount,'999,999,990.00')),15,' ') || ' ' ||
                                                                      LPAD(TRIM(TO_CHAR(c_tot_all_c.current_amount,'999,999,990.00')),15,' ') || ' ' ||
                                                                      LPAD(TRIM(TO_CHAR(c_tot_all_c.days_past_due_1_30,'999,999,990.00')),15,' ') || ' ' ||
                                                                      LPAD(TRIM(TO_CHAR(c_tot_all_c.days_past_due_31_60,'999,999,990.00')),15,' ') || ' ' ||
                                                                      LPAD(TRIM(TO_CHAR(c_tot_all_c.days_past_due_61_plus,'999,999,990.00')),15,' ') );

      print_output ( RPAD(' ',v_spaces_perc,' ') || LPAD(TRIM(TO_CHAR(c_tot_all_c.perc_current_amount,'999990.00')) || '%',15,' ') || ' ' || 
                                                    LPAD(TRIM(TO_CHAR(c_tot_all_c.perc_days_past_due_1_30,'999990.00')) || '%',15,' ') || ' ' ||
                                                    LPAD(TRIM(TO_CHAR(c_tot_all_c.perc_days_past_due_31_60,'999990.00')) || '%',15,' ') || ' ' ||
                                                    LPAD(TRIM(TO_CHAR(c_tot_all_c.perc_days_past_due_61_plus,'999990.00')) || '%',15,' ') );

    END LOOP;

    print_log ( 'ajc_bc_arxage_pkg.print_report (-)');

  END print_report;

  PROCEDURE main_p ( retcode                  OUT   NUMBER,
                     errbuf                   OUT   VARCHAR2,
                     p_reporting_level         IN   NUMBER,
                     p_reporting_context       IN   NUMBER, -- org_id
                     p_set_of_books_currency   IN   VARCHAR2,
                     p_chart_of_accounts       IN   NUMBER,
                     p_as_of_date              IN   VARCHAR2,
                     p_order_by                IN   VARCHAR2,
                     p_report_summary          IN   VARCHAR2, -- Customer | Invoice
                     p_report_format           IN   VARCHAR2, -- Brief | Detailed
      
