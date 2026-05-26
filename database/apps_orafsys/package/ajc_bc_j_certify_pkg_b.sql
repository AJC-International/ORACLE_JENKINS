PACKAGE BODY              ajc_bc_j_certify_pkg AS

  -- Setear en N cuando se usan los triggers de PROD a FINUPG5/FINUPG6
  -- Setear en Y cuando se necesite cargar la data de files / tables
  gv_ftp_loader        VARCHAR2(1) := 'N'; -- se resuelve mas abajo segun la db
  
  -- Parameters
  gv_file_name VARCHAR2(200):='data/CERTIFY_INC/AJC_INC_CERTIFY_INVOICES.csv';
  gv_american_express_supplier VARCHAR2(100):='AMERICAN EXPRESS';
  gv_travel_advance_account_num VARCHAR2(100):='1252';
  /*=========================================================================+
  |                                                                          |
  | Private Procedure                                                        |
  |    print_log                                                             |
  |                                                                          |
  | Description                                                              |
  |    Impresion de log                                                      |
  |                                                                          |
  | Parameters                                                               |
  |    p_message                   IN     NUMBER    Mensaje.                 |
  |                                                                          |
  +=========================================================================*/
  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    gv_log_seq := gv_log_seq + 1;
    ajc_bc_j_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );
    dbms_output.put_line( p_message);

  END print_log;

  /*=========================================================================+
  |                                                                          |
  | Private Procedure                                                        |
  |    print_output                                                          |
  |                                                                          |
  | Description                                                              |
  |    Impresion de output                                                   |
  |                                                                          |
  | Parameters                                                               |
  |    p_message                   IN     NUMBER    Mensaje.                 |
  |                                                                          |
  +=========================================================================*/

  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    ajc_bc_j_utils_pkg.insert_output_p ( gv_bc_ifc, p_message, gv_request_id );

  END print_output;
  
  -- ------------------------------------------------------------------------------------------------------------------------
  -- AJC Ftp Expense Report File
  -- ------------------------------------------------------------------------------------------------------------------------
  -- ------------------------------------------------------------------------------------------------------------------------
  -- AJC Expense Report Interface
  -- ------------------------------------------------------------------------------------------------------------------------
  PROCEDURE expense_report_interface_p ( p_gl_date                       IN   DATE,
                                                                 p_american_express_supplier     IN   VARCHAR2,
                                                                 p_travel_advance_account_num    IN   VARCHAR2,
                                                                 p_file_date IN VARCHAR2,
                                                                 p_status                       OUT   VARCHAR2 ) IS
    -- constants
    source_c             ajc_bc_inc_ap_certify_invoices.source%TYPE := 'CERTIFY';
    amex_c                  varchar2(4) := 'AMEX';
    true_c                  varchar2(4) := 'TRUE';
    advance_c            varchar2(7) := 'ADVANCE';

    -- variables
    invoice_number_v            ajc_inc_expense_rpt_int.invoice_number%TYPE;
    oracle_invoice_num_v        ajc_bc_inc_ap_certify_invoices.invoice_num%TYPE;
    supplier_number_v           ajc_inc_expense_rpt_int.supplier_number%TYPE;    
    invoice_date_v                 ajc_inc_expense_rpt_int.invoice_date%TYPE;
    supplier_site_code_v        ajc_inc_expense_rpt_int.supplier_site_code%TYPE;
    supplier_name_v                ajc_inc_expense_rpt_int.supplier_name%TYPE;
    invoice_amount_v            ajc_inc_expense_rpt_int.invoice_amount%TYPE;
    description_v                  ajc_inc_expense_rpt_int.description%TYPE;
    invoice_type_v                 ajc_inc_expense_rpt_int.invoice_type%TYPE;
    currency_code_v                ajc_inc_expense_rpt_int.currency_code%TYPE;
    gl_date_from_int_v          ajc_inc_expense_rpt_int.gl_date%TYPE;
    inv_id_v                    number;
    inv_line_id_v               number;
    error_code_v                number;
    error_text_v                varchar2(200);
    terms_id_v                     po_vendor_sites.terms_id%TYPE;
    terms_name_v          ap_terms_tl.name%TYPE; 
    payment_method_lookup_code_v      po_vendor_sites.payment_method_lookup_code%TYPE;
    pay_group_lookup_code_v              po_vendor_sites.pay_group_lookup_code%TYPE;
    gl_date_v                      date;
    liab_code_concat_v          ap_invoices_interface.accts_pay_code_concatenated%TYPE := null; 
    base_currency_code_v        ajc_bc_companies.currency%TYPE;
    company_v                      fnd_flex_values.flex_value%TYPE := null;
    org_id_v                       ap_invoices_interface.org_id%TYPE    := null; 
    rec_cnt_v                      number := 0;
    stmt_v                            number;
    prog_failed_v                  boolean;
    employee_number_v           ajc_inc_expense_rpt_int.supplier_number%TYPE;    
    employee_site_code_v        ajc_inc_expense_rpt_int.supplier_site_code%TYPE;
    employee_name_v                ajc_inc_expense_rpt_int.supplier_name%TYPE;
    reimburse_flag_v            ajc_inc_expense_rpt_int.reimburse_flag%TYPE;
    amex_supplier_num_v         po_vendors.segment1%TYPE;
    amex_supplier_name_v         po_vendors.vendor_name%TYPE;
    amex_vendor_id_v         po_vendors.vendor_id%TYPE;    
    line_num_v                     number;
    distr_account_v             ap_invoices_interface.accts_pay_code_concatenated%TYPE; 
    travel_adv_distr_account_v      ap_invoices_interface.accts_pay_code_concatenated%TYPE; 
    distr_acct_num_v            gl_code_combinations.segment1%TYPE;
    dept_override_v             gl_code_combinations.segment1%TYPE;

    -- SB
    v_vendor_id           po_vendors.vendor_id%TYPE;
    v_vendor_name         po_vendors.vendor_name%TYPE;
    v_vendor_site_id      po_vendor_sites_all.vendor_site_id%TYPE;
    --
    v_set_of_books_id       NUMBER; 
    v_set_of_books_name     VARCHAR2(240); 
    v_dist_code_combination VARCHAR2(10);
    v_company               VARCHAR2(10);
    v_account               VARCHAR2(20);
    v_account_description   VARCHAR2(240);
    v_department            VARCHAR2(10);
    v_product               VARCHAR2(10);
    v_destination           VARCHAR2(10);
    v_office                VARCHAR2(10);
    v_origin                VARCHAR2(10);
    v_intercompany          VARCHAR2(10);
    --
    v_l_segment1            VARCHAR2(10);
    v_l_segment2            VARCHAR2(10);
    v_l_segment3            VARCHAR2(10);
    v_l_segment4            VARCHAR2(10);
    v_l_segment5            VARCHAR2(10);
    v_l_segment6            VARCHAR2(10);
    v_l_segment7            VARCHAR2(10);

    v_l_dist_code_combination_id VARCHAR2(10);
    v_l_company                  VARCHAR2(10);
    v_l_account                  VARCHAR2(20);
    v_l_account_description      VARCHAR2(240);
    v_l_department               VARCHAR2(10);
    v_l_product                  VARCHAR2(10);
    v_l_destination              VARCHAR2(10);
    v_l_office                   VARCHAR2(10); 
    v_l_origin                   VARCHAR2(10);
    v_l_intercompany             VARCHAR2(10);

    --
    v_t_segment1            VARCHAR2(10);
    v_t_segment2            VARCHAR2(10);
    v_t_segment3            VARCHAR2(10);
    v_t_segment4            VARCHAR2(10);
    v_t_segment5            VARCHAR2(10);
    v_t_segment6            VARCHAR2(10);
    v_t_segment7            VARCHAR2(10);

    v_t_dist_code_combination_id VARCHAR2(10);
    v_t_company                  VARCHAR2(10);
    v_t_account                  VARCHAR2(20);
    v_t_account_description      VARCHAR2(240);
    v_t_department               VARCHAR2(10);
    v_t_product                  VARCHAR2(10);
    v_t_destination              VARCHAR2(10);
    v_t_office                   VARCHAR2(10);
    v_t_origin                   VARCHAR2(10);
    v_t_intercompany             VARCHAR2(10);
    -- SB

    e_account_not_exist     EXCEPTION;
    e_no_invoices_found           EXCEPTION;
    e_no_amex_supp_found           EXCEPTION;   
    e_generic   EXCEPTION; 

    Cursor Select_Inv is 
    
    SELECT distinct invoice_number, 
             supplier_number, 
             supplier_name, 
             decode(reimburse_flag, advance_c, true_c ,reimburse_flag) reimburse_flag
        -- FROM AJC_INC_EXPENSE_RPT_INT -- IMPLEMENTACION DEFINITIVA -- Descomentar
--select * 
    FROM AJC_BC_INC_EXPENSE_RPT_INT -- IMPLEMENTACION TRANSITORIA -- Descomentar
    WHERE nvl(status,'NEW') <> 'INTERFACED';
    --AND invoice_number='7972'
    --AND TO_CHAR(TRUNC(creation_date),'yyyymmdd')=p_file_date; MB REVISAR


    Cursor Select_Inv_Line is
    SELECT *
        -- FROM AJC_INC_EXPENSE_RPT_INT -- IMPLEMENTACION DEFINITIVA -- Descomentar
        FROM AJC_BC_INC_EXPENSE_RPT_INT -- IMPLEMENTACION TRANSITORIA -- Descomentar
     WHERE nvl(supplier_number,'XXXXX') = nvl(employee_number_v,'XXXXX')
       AND nvl(supplier_name,'XXXXX') = nvl(employee_name_v,'XXXXX')
       AND decode(reimburse_flag, advance_c , true_c, reimburse_flag) = reimburse_flag_v
       AND invoice_number = invoice_number_v
       AND nvl(status,'NEW') <> 'INTERFACED';

  BEGIN

    print_log('expense_report_interface_p (+)');

    print_log('p_gl_date: ' || p_gl_date);
    print_log('p_american_express_supplier: ' || p_american_express_supplier);
    print_log('p_travel_advance_account_num: ' || p_travel_advance_account_num);

    BEGIN

      SELECT segment1
             -- SB
            ,vendor_id
            ,vendor_name
             -- SB
        INTO amex_supplier_num_v
             -- SB
            ,amex_vendor_id_v --v_vendor_id
            ,amex_supplier_name_v --v_vendor_name
             -- SB
        FROM po_vendors
       WHERE vendor_name = p_american_express_supplier;

      print_log('amex_supplier_num_v: ' || amex_supplier_num_v);
      print_log('amex_vendor_id_v: ' || amex_vendor_id_v);
      print_log('amex_supplier_name_v: ' || amex_supplier_name_v);

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        error_text_v:='amex_supplier_num_v NOT FOUND.';
        raise e_no_amex_supp_found;
    END;

    FOR inv_rec in Select_Inv LOOP
    BEGIN
      invoice_number_v := inv_rec.invoice_number;
      employee_number_v := inv_rec.supplier_number;
      employee_name_v := inv_rec.supplier_name;
      reimburse_flag_v := inv_rec.reimburse_flag;

         print_log ( 'Invoice: '||invoice_number_v);
      print_log ( 'Employee Supplier Num: '||employee_number_v);
      print_log ( 'Employee Supplier Name: '||employee_name_v);
      print_log ( 'Reimburse Flag: '||inv_rec.reimburse_flag);

      -- Initialize variables
      invoice_date_v := NULL;
      employee_site_code_v := NULL;
      invoice_amount_v := 0;
      description_v := NULL;
      invoice_type_v := NULL;
      currency_code_v := NULL;
      gl_date_from_int_v := NULL; 
      company_v := NULL;
      org_id_v := NULL;
      liab_code_concat_v := NULL;
      -- SB
      v_vendor_site_id := NULL;
      --
      v_dist_code_combination := NULL;
      v_company := NULL;
      v_account := NULL;
      v_account_description := NULL;
      v_department := NULL;
      v_product := NULL;
      v_destination := NULL;
      v_office := NULL;
      v_origin := NULL;
      v_intercompany := NULL;
      --
      v_l_segment1 := NULL;
      v_l_segment2 := NULL;
      v_l_segment3 := NULL;
      v_l_segment4 := NULL;
      v_l_segment5 := NULL;
      v_l_segment6 := NULL;
      v_l_segment7 := NULL;
      --
      v_l_dist_code_combination_id := NULL;
      v_l_company := NULL;
      v_l_account := NULL;
      v_l_account_description := NULL;
      v_l_department := NULL;
      v_l_product := NULL;
      v_l_destination := NULL;
      v_l_office := NULL;
      v_l_origin := NULL;
      v_l_intercompany := NULL;
      --
      v_t_segment1 := NULL;
      v_t_segment2 := NULL;
      v_t_segment3 := NULL;
      v_t_segment4 := NULL;
      v_t_segment5 := NULL;
      v_t_segment6 := NULL;
      v_t_segment7 := NULL;
      --
      v_t_dist_code_combination_id := NULL;
      v_t_company := NULL;
      v_t_account := NULL;
      v_t_account_description := NULL;
      v_t_department := NULL;
      v_t_product := NULL;
      v_t_destination := NULL;
      v_t_office := NULL;
      v_t_origin := NULL;
      v_t_intercompany := NULL;
      -- SB
      base_currency_code_v := NULL;
      terms_id_v := NULL;
      terms_name_v := NULL;
      supplier_number_v := NULL;
      supplier_site_code_v := NULL;
      oracle_invoice_num_v := NULL;
      pay_group_lookup_code_v := NULL;
      payment_method_lookup_code_v := NULL;
      gl_date_v := NULL;
      line_num_v := 1;

      stmt_v := 10;

      -- Get the invoice header info from the interface table 
      SELECT to_date(invoice_date,'DD-MON-YYYY'),  supplier_site_code, description,
             upper(invoice_type), 
             -- 20250310 
             -- currency_code, 
             DECODE(currency_code,'MEX','MXN',
                                  currency_code),
             -- 20250310 
             to_date(gl_date,'DD-MON-YYYY'), substr(distr_account, 1,2) 
        INTO invoice_date_v, employee_site_code_v,   description_v,
             invoice_type_v, currency_code_v, gl_date_from_int_v, company_v
        -- FROM ajc_inc_expense_rpt_int -- IMPLEMENTACION DEFINITIVA -- Descomentar
        FROM AJC_BC_INC_EXPENSE_RPT_INT -- IMPLEMENTACION TRANSITORIA -- Descomentar
       WHERE nvl(supplier_number,'XXXXX') = nvl(inv_rec.supplier_number,'XXXXX')
         AND nvl(supplier_name,'XXXXX') = nvl(inv_rec.supplier_name,'XXXXX')
         AND decode(reimburse_flag, advance_c, true_c, reimburse_flag)  = inv_rec.reimburse_flag
         AND invoice_number = inv_rec.invoice_number
         AND rownum =1;

      stmt_v := 20;    

      print_log ( 'invoice_date_v: ' || invoice_date_v );
      print_log ( 'employee_site_code_v: ' || employee_site_code_v );
      print_log ( 'description_v: ' || description_v );
      print_log ( 'invoice_type_v: ' || invoice_type_v );
      print_log ( 'currency_code_v: ' || currency_code_v );
      print_log ( 'gl_date_from_int_v: ' || gl_date_from_int_v );
      print_log ( 'company_v: ' || company_v );

      -- Get the org and responsibility for the company
      Begin

          SELECT org_id,
                 set_of_books_id,
--                 set_of_books_name -- MB REVISAR reemplazo para mostrar en el output el bc company name
                bc_company_name
            INTO org_id_v, 
                 v_set_of_books_id,
                 v_set_of_books_name
            FROM ajc_bc_companies bcc
           WHERE bcc.oracle_company_number = company_v;

      Exception
        When OTHERS  then
          error_text_v :='Could not get Org defined in Oracle for Company: ' || company_v||' - '||SQLERRM;
         raise e_generic;
      End;

      print_log ( 'org_id_v: ' || org_id_v );
      print_log ( 'v_set_of_books_id: ' || v_set_of_books_id );
      print_log ( 'v_set_of_books_name: ' || v_set_of_books_name );

      IF org_id_v IS NULL THEN

        error_text_v :=  'Org not defined for Company: '||company_v;
        raise e_generic;
      END IF;

      stmt_v := 30;    

      IF ( org_id_v IS NOT NULL ) THEN     

        -- Get the default liability account combination for the org
        Begin

                  SELECT oracle_company_number || '.2000.000.000.000.000.00',
                         -- 20250310 
                         -- currency,
                         DECODE(currency,'MEX','MXN',
                                         currency),
                         -- 20250310 
                         -1,
                         oracle_company_number,
                         '2105.2000',
                         'ACCOUNTS PAYABLE-TRADE',
                         '000' department,
                         '000' product,
                         '000' destination,
                         '000' office,
                         '000' origin,
                         '00' intercompany
                    INTO liab_code_concat_v, 
                         base_currency_code_v,
                         v_dist_code_combination,
                         v_company,
                         v_account,
                         v_account_description,
                         v_department,
                         v_product,
                         v_destination,
                         v_office,
                         v_origin,
                         v_intercompany
                    FROM ajc_bc_companies
                   WHERE oracle_company_number = company_v;
                   
        Exception
          WHEN OTHERS THEN
            BEGIN
                -- 20241104
                -- La company no existe en Oracle, se obtienen los datos de ajc_bc_companies
   /*             IF ( org_id_v = -1 ) THEN

                  SELECT oracle_company_number || '.2000.000.000.000.000.00',
                         -- 20250310 
                         -- currency,
                         DECODE(currency,'MEX','MXN',
                                         currency),
                         -- 20250310 
                         -1,
                         oracle_company_number,
                         '2105.2000',
                         'ACCOUNTS PAYABLE-TRADE',
                         '000' department,
                         '000' product,
                         '000' destination,
                         '000' office,
                         '000' origin,
                         '00' intercompany
                    INTO liab_code_concat_v, 
                         base_currency_code_v,
                         v_dist_code_combination,
                         v_company,
                         v_account,
                         v_account_description,
                         v_department,
                         v_product,
                         v_destination,
                         v_office,
                         v_origin,
                         v_intercompany
                    FROM ajc_bc_companies
                   WHERE oracle_company_number = company_v;

                END IF;            
                -- 20241104
            Exception
                When OTHERS  then */
                  error_text_v :='Could not get Liability account for Company: ' || company_v||' - '||SQLERRM;
                 raise e_account_not_exist;
            END;
        End;
--        End;

        print_log ( 'liab_code_concat_v: ' || liab_code_concat_v );
        print_log ( 'base_currency_code_v: ' || base_currency_code_v );
        print_log ( 'v_dist_code_combination: ' || v_dist_code_combination );
        print_log ( 'v_company: ' || v_company );
        print_log ( 'v_account: ' || v_account );
        print_log ( 'v_account_description: ' || v_account_description );
        print_log ( 'v_department: ' || v_department );
        print_log ( 'v_product: ' || v_product );
        print_log ( 'v_destination: ' || v_destination );
        print_log ( 'v_office: ' || v_office );
        print_log ( 'v_origin: ' || v_origin );
        print_log ( 'v_intercompany: ' || v_intercompany );

      ELSE 

        error_text_v :=  'Org is null - Unable to retrieve the liability account combination for the invoice';
        raise e_generic;
      END IF;

      stmt_v := 40;    
      -- For AMEX reimburseable expense reports the supplier will be the American Express supplier number 
      -- The supplier site code ALTERNATE for the American Express supplier will be the employee supplier number from the expense report file.

      IF inv_rec.reimburse_flag = amex_c THEN

        supplier_number_v := amex_supplier_num_v;
        v_vendor_name := amex_supplier_name_v;
        v_vendor_id := amex_vendor_id_v;
        
        oracle_invoice_num_v := supplier_number_v || '-' || employee_number_v || '-' || invoice_number_v;

        -- Find the supplier site code, terms_id, and pay group
        stmt_v := 50;

        Begin

          SELECT vendor_site_code, terms_id, pay_group_lookup_code, payment_method_lookup_code
                 -- SB
                ,vendor_site_id
                 -- SB
            INTO supplier_site_code_v, terms_id_v, pay_group_lookup_code_v, payment_method_lookup_code_v
                 -- SB
                ,v_vendor_site_id
                 -- SB
            FROM po_vendor_sites_all  
           WHERE vendor_site_code_ALT = employee_number_v 
             AND org_id = org_id_v
             AND vendor_id = ( SELECT vendor_id 
                                 FROM po_vendors  
                                WHERE segment1 = supplier_number_v );

        Exception
          When NO_DATA_FOUND then
            print_log ( 'ALTERNATE Supplier Site: ' || employee_number_v || ' not found in Oracle for Supplier: ' || supplier_number_v );

            -- 20241104
            SELECT vendor_site_code, terms_id, pay_group_lookup_code, payment_method_lookup_code
                  ,vendor_site_id
              INTO supplier_site_code_v, terms_id_v, pay_group_lookup_code_v, payment_method_lookup_code_v
                  ,v_vendor_site_id
              FROM po_vendor_sites_all  
             WHERE vendor_site_code_ALT = employee_number_v 
               AND org_id = 5244
               AND vendor_id = ( SELECT vendor_id 
                                   FROM po_vendors  
                                  WHERE segment1 = supplier_number_v );
            -- 20241104

          When OTHERS then 
            null;

        End;
              
      ELSE

        supplier_number_v := employee_number_v; 
    
        Begin

          -- SB 20220331
          SELECT vendor_id,
                 vendor_name
            INTO v_vendor_id,
                 v_vendor_name
            FROM po_vendors
           WHERE segment1 = supplier_number_v;
          -- SB 20220331

        Exception
          When NO_DATA_FOUND then
            error_text_v :=  'Supplier not found in Oracle for supplier number: '||supplier_number_v;
            raise e_generic;
          When OTHERS then 
            error_text_v :=  'Supplier not found in Oracle for supplier number: '||supplier_number_v||' - '||SQLERRM;
            raise e_generic;

        End;

        oracle_invoice_num_v := supplier_number_v || '-' || invoice_number_v;
        supplier_site_code_v := employee_site_code_v;

        -- Find the terms_id, and pay group
        stmt_v := 60;

        Begin

          SELECT terms_id, pay_group_lookup_code, payment_method_lookup_code
                  -- SB
                ,vendor_site_id
                 -- SB
            INTO terms_id_v, pay_group_lookup_code_v, payment_method_lookup_code_v
                 -- SB
                ,v_vendor_site_id
                 -- SB
            FROM po_vendor_sites_all  
           WHERE vendor_site_code = employee_site_code_v
             AND org_id = org_id_v
             AND vendor_id = ( SELECT vendor_id 
                                 FROM po_vendors  
                                WHERE segment1 = supplier_number_v);

        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            print_log ( 'Supplier Site: ' || employee_site_code_v || ' not found in Oracle for Supplier: ' || supplier_number_v);
            error_text_v :=  'Supplier Site: ' || employee_site_code_v || ' not found in Oracle for Supplier: ' || supplier_number_v;
            -- 20241104
            -- La company no existe en Oracle, se mira el site en la 5244
            IF ( org_id_v = -1 ) THEN

              SELECT terms_id, 
                     pay_group_lookup_code, 
                     payment_method_lookup_code,
                     vendor_site_id
                INTO terms_id_v, 
                     pay_group_lookup_code_v, 
                     payment_method_lookup_code_v,
                     v_vendor_site_id
                FROM po_vendor_sites_all  
               WHERE vendor_site_code = employee_site_code_v
                 AND org_id = 5244
                 AND vendor_id = ( SELECT vendor_id 
                                     FROM po_vendors  
                                    WHERE segment1 = supplier_number_v);

            END IF;                                    
            -- 20241104

          WHEN OTHERS THEN
            NULL;

        END;

      END IF; -- reimburse_flag = amex_c

      -- Determine the gl date
      IF p_gl_date is null THEN

        gl_date_v := gl_date_from_int_v;

      ELSE

        gl_date_v := p_gl_date;

      END IF;

      SELECT ap_invoices_interface_s.nextval
           INTO inv_id_v
           FROM dual;

      -- Create Invoice Lines
      For inv_line_rec in Select_Inv_Line LOOP
      BEGIN
        travel_adv_distr_account_v := null; 
        distr_account_v := null;
        distr_acct_num_v := null; 
        dept_override_v := null;

        invoice_amount_v := invoice_amount_v + inv_line_rec.line_amount;

        travel_adv_distr_account_v := substr(inv_line_rec.distr_account,1,2) || '.' || p_travel_advance_account_num || '.000.000.000.000.00';

        print_log ( 'travel_adv_distr_account_v: ' || travel_adv_distr_account_v );

        v_t_segment1 := SUBSTR(travel_adv_distr_account_v,1,2);
        v_t_segment2 := SUBSTR(travel_adv_distr_account_v,4,4);
        v_t_segment3 := SUBSTR(travel_adv_distr_account_v,9,3);
        v_t_segment4 := SUBSTR(travel_adv_distr_account_v,13,3);
        v_t_segment5 := SUBSTR(travel_adv_distr_account_v,17,3);
        v_t_segment6 := SUBSTR(travel_adv_distr_account_v,21,3);
        v_t_segment7 := SUBSTR(travel_adv_distr_account_v,25,2);

        print_log ( 'v_t_segment1: ' || v_t_segment1 );
        print_log ( 'v_t_segment2: ' || v_t_segment2 );
        print_log ( 'v_t_segment3: ' || v_t_segment3 );
        print_log ( 'v_t_segment4: ' || v_t_segment4 );
        print_log ( 'v_t_segment5: ' || v_t_segment5 );
        print_log ( 'v_t_segment6: ' || v_t_segment6 );
        print_log ( 'v_t_segment7: ' || v_t_segment7 );

        SELECT NULL code_combination_id,
               v_t_segment1 company,
               aba.bc_account account,
               aba.description account_description,
               v_t_segment3 department,
               decode(AJC_BC_J_UTILS_PKG.get_dimension_value ( p_oracle_segment => 'SEGMENT4'
                                                                          ,p_oracle_value   => v_t_segment4
                                                                          ,p_bc_dimension   => 'DIVISION'), NULL,v_t_segment4,'000') product,
               decode(AJC_BC_J_UTILS_PKG.get_dimension_value ( p_oracle_segment => 'SEGMENT5'
                                                                          ,p_oracle_value   => v_t_segment5
                                                                          ,p_bc_dimension   => 'OFFICE'), NULL,v_t_segment5,'000') destination,
               nvl(AJC_BC_J_UTILS_PKG.get_dimension_value ( p_oracle_segment => 'SEGMENT5'
                                                                       ,p_oracle_value   => v_t_segment5
                                                                       ,p_bc_dimension   => 'OFFICE'),'000') office,                                                                      
               v_t_segment6 origin,
               v_t_segment7 intercompany                                                                          
          INTO v_t_dist_code_combination_id,
               v_t_company,
               v_t_account,
               v_t_account_description,
               v_t_department,
               v_t_product,
               v_t_destination,
               v_t_office,
               v_t_origin,
               v_t_intercompany
          FROM ajc.ajc_bc_accounts aba
         WHERE aba.oracle_account = v_t_segment2;

        print_log ( 'v_t_company: ' || v_t_company );
        print_log ( 'v_t_account: ' || v_t_account );
        print_log ( 'v_t_account_description: ' || v_t_account_description );
        print_log ( 'v_t_department: ' || v_t_department );
        print_log ( 'v_t_product: ' || v_t_product );
        print_log ( 'v_t_destination: ' || v_t_destination );
        print_log ( 'v_t_office: ' || v_t_office );
        print_log ( 'v_t_origin: ' || v_t_origin );
        print_log ( 'v_t_intercompany: ' || v_t_intercompany );  
        -- SB

        distr_acct_num_v := substr(inv_line_rec.distr_account,4,4);

        print_log ( 'distr_acct_num_v: ' || distr_acct_num_v ); 
        print_log ( 'p_travel_advance_account_num: ' || p_travel_advance_account_num );  

        IF distr_acct_num_v = p_travel_advance_account_num THEN

          distr_account_v := travel_adv_distr_account_v;

        ELSE

          distr_account_v := inv_line_rec.distr_account;

        END IF;

        print_log ( 'distr_account_v: ' || distr_account_v ); 


        v_l_segment1 := SUBSTR(distr_account_v,1,2);
        v_l_segment2 := SUBSTR(distr_account_v,4,4);
        v_l_segment3 := SUBSTR(distr_account_v,9,3);
        v_l_segment4 := SUBSTR(distr_account_v,13,3);
        v_l_segment5 := SUBSTR(distr_account_v,17,3);
        v_l_segment6 := SUBSTR(distr_account_v,21,3);
        v_l_segment7 := SUBSTR(distr_account_v,25,2);

        print_log ( 'v_l_segment1: ' || v_l_segment1 );
        print_log ( 'v_l_segment2: ' || v_l_segment2 );
        print_log ( 'v_l_segment3: ' || v_l_segment3 );
        print_log ( 'v_l_segment4: ' || v_l_segment4 );
        print_log ( 'v_l_segment5: ' || v_l_segment5 );
        print_log ( 'v_l_segment6: ' || v_l_segment6 );
        print_log ( 'v_l_segment7: ' || v_l_segment7 );

        BEGIN

          SELECT NULL code_combination_id,
                 v_l_segment1 company,
                 aba.bc_account account,
                 aba.description account_description,
                 v_l_segment3 department,
                 decode(AJC_BC_J_UTILS_PKG.get_dimension_value ( p_oracle_segment => 'SEGMENT4'
                                                                            ,p_oracle_value   => v_l_segment4
                                                                            ,p_bc_dimension   => 'DIVISION'), NULL,v_l_segment4,'000') product,
                 decode(AJC_BC_J_UTILS_PKG.get_dimension_value ( p_oracle_segment => 'SEGMENT5'
                                                                            ,p_oracle_value   => v_l_segment5
                                                                            ,p_bc_dimension   => 'OFFICE'), NULL,v_l_segment5,'000') destination,
                 nvl(AJC_BC_J_UTILS_PKG.get_dimension_value ( p_oracle_segment => 'SEGMENT5'
                                                                         ,p_oracle_value   => v_l_segment5
                                                                         ,p_bc_dimension   => 'OFFICE'),'000') office,
                 v_l_segment6 origin,
                 v_l_segment7 intercompany                                                                          
            INTO v_l_dist_code_combination_id,
                 v_l_company,
                 v_l_account,
                 v_l_account_description,
                 v_l_department,
                 v_l_product,
                 v_l_destination,
                 v_l_office,
                 v_l_origin,
                 v_l_intercompany
            FROM ajc.ajc_bc_accounts aba
           WHERE aba.oracle_account = v_l_segment2;
