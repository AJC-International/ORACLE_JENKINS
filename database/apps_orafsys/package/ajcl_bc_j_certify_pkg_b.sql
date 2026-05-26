PACKAGE BODY              ajcl_bc_j_certify_pkg AS
  
  -- Parameters
  gv_file_name VARCHAR2(200):='data/CERTIFY/AJC_CERTIFY_INVOICES.csv';
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
    ajcl_bc_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );
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

    ajcl_bc_utils_pkg.insert_output_p ( gv_bc_ifc, p_message, gv_request_id );

  END print_output;

  -- ------------------------------------------------------------------------------------------------------------------------
  -- AJC Expense Report Interface
  -- ------------------------------------------------------------------------------------------------------------------------
  PROCEDURE expense_report_interface_p ( p_status                       OUT   VARCHAR2 ) IS


    -- constants
    -- source_c             ap_invoices_interface.source%TYPE := 'EXPENSE REPORT';
    source_c             ap_invoices_interface.source%TYPE := 'CERTIFY';


    -- variables
    invoice_number_v        ajc_expense_rpt_int.invoice_number%TYPE;
    oracle_invoice_num_v        ap_invoices_all.invoice_num%TYPE;
    supplier_number_v        ajc_expense_rpt_int.supplier_number%TYPE;    
    invoice_date_v            ajc_expense_rpt_int.invoice_date%TYPE;
    supplier_site_code_v        ajc_expense_rpt_int.supplier_site_code%TYPE;
    supplier_name_v            ajc_expense_rpt_int.supplier_name%TYPE;
    invoice_amount_v        ajc_expense_rpt_int.invoice_amount%TYPE;
    description_v            ajc_expense_rpt_int.description%TYPE;
    invoice_type_v            ajc_expense_rpt_int.invoice_type%TYPE;
    currency_code_v            ajc_expense_rpt_int.currency_code%TYPE;
    gl_date_from_int_v        ajc_expense_rpt_int.gl_date%TYPE;
    inv_id_v                number;
    inv_line_id_v           number;
    error_code_v            number;
    error_text_v            varchar2(200);
    terms_id_v            po_vendor_sites.terms_id%TYPE;
    payment_method_lookup_code_v    po_vendor_sites.payment_method_lookup_code%TYPE;
    pay_group_lookup_code_v        po_vendor_sites.pay_group_lookup_code%TYPE;
    gl_date_v            date;
    oracle_vendor_site_id_v        po_vendor_sites.vendor_site_id%TYPE;
    liab_code_concat_v        ap_invoices_interface.accts_pay_code_concatenated%TYPE := null; 
    base_currency_code_v        ap_system_parameters.base_currency_code%TYPE;
    distr_account_v             ap_invoices_interface.accts_pay_code_concatenated%TYPE;     
    distr_acct_num_v            gl_code_combinations.segment1%TYPE;    

    rec_cnt_v            number := 0;
    stmt_v                number;
    prog_failed_v            boolean;
    NO_INVOICES_FOUND        exception;

    -- MB
    v_vendor_id           po_vendors.vendor_id%TYPE;
    v_vendor_name         po_vendors.vendor_name%TYPE;
    v_vendor_site_id      po_vendor_sites_all.vendor_site_id%TYPE;
    v_line_number       NUMBER;
    terms_name_v          ap_terms_tl.name%TYPE; 
    v_error_message     ajcl_bc_ap_certify_invoices.error_message%TYPE;
    --
    v_dist_code_combination VARCHAR2(10);
    v_company               VARCHAR2(10);
    v_account               VARCHAR2(20);
    v_account_description   VARCHAR2(240);
    v_department            VARCHAR2(10);
    v_product               VARCHAR2(10);
    v_division               VARCHAR2(10);    
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
    v_l_division                  VARCHAR2(10);    
    v_l_destination              VARCHAR2(10);
    v_l_office                   VARCHAR2(10); 
    v_l_origin                   VARCHAR2(10);
    v_l_intercompany             VARCHAR2(10);

    v_division_h              VARCHAR2(10);    
    -- MB

    e_account_not_exist     EXCEPTION;
    e_no_invoices_found           EXCEPTION;

    Cursor Select_Inv is 
    SELECT distinct invoice_number, 
                    supplier_number, 
                    supplier_name
    --FROM --ajc_expense_rpt_int -- IMPLEMENTACION DEFINITIVA -- Descomentar
    FROM AJCL_BC_EXPENSE_RPT_INT -- IMPLEMENTACION TRANSITORIA -- Descomentar
    WHERE nvl(status,'NEW') <> 'INTERFACED';

    Cursor Select_Inv_Line is
    
    SELECT *
   -- FROM --ajc_expense_rpt_int -- IMPLEMENTACION DEFINITIVA -- Descomentar
     FROM AJCL_BC_EXPENSE_RPT_INT -- IMPLEMENTACION TRANSITORIA -- Descomentar    
    WHERE nvl(supplier_number,'XXXXX') = nvl(supplier_number_v,'XXXXX')
    AND   nvl(supplier_name,'XXXXX') = nvl(supplier_name_v,'XXXXX')
    AND invoice_number = invoice_number_v
    AND nvl(status,'NEW') <> 'INTERFACED';

  BEGIN

    print_log('expense_report_interface_p (+)');

    -- Get the default liability account combination
    Begin
          SELECT gcc.segment1||'.'||gcc.segment2||'.'||gcc.segment3||'.'||gcc.segment4||'.'||gcc.segment5||'.'||gcc.segment6||'.'||gcc.segment7, 
                 asp.base_currency_code,
                 -- SB
                 gcc.code_combination_id,
                 -- ltrim(gcc.segment1,'0') company,
                 gcc.segment1 company,
                 aba.bc_account account,
                 aba.description account_description,
                 gcc.segment3 department,
                 DECODE(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4'
                                                                            ,p_oracle_value   => gcc.segment4
                                                                            ,p_bc_dimension   => 'DIVISION'), NULL,gcc.segment4,'000') product,
                 NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4'
                                                                            ,p_oracle_value   => gcc.segment4
                                                                            ,p_bc_dimension   => 'DIVISION'), '000') division,                                                                              
                 DECODE(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'
                                                                            ,p_oracle_value   => gcc.segment5
                                                                            ,p_bc_dimension   => 'OFFICE'), NULL,gcc.segment5,'000') destination,
                 NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'
                                                                         ,p_oracle_value   => gcc.segment5
                                                                         ,p_bc_dimension   => 'OFFICE'),'000') office,                                                                          
                 gcc.segment6 origin,
                 gcc.segment7 intercompany
                 -- SB
            INTO liab_code_concat_v, 
                 base_currency_code_v,
                 -- SB
                 v_dist_code_combination,
                 v_company,
                 v_account,
                 v_account_description,
                 v_department,
                 v_product,
                 v_division,
                 v_destination,
                 v_office,
                 v_origin,
                 v_intercompany
                 -- SB
            FROM gl_code_combinations gcc, 
                 ap_system_parameters_all asp,
                 ajc.ajc_bc_accounts aba
           WHERE gcc.code_combination_id = asp.accts_pay_code_combination_id
             AND asp.org_id = gv_org_id
             AND gcc.segment2 = aba.oracle_account (+); 
    Exception
        When OTHERS then null;
    End;

        print_log ( 'liab_code_concat_v: ' || liab_code_concat_v );
        print_log ( 'base_currency_code_v: ' || base_currency_code_v );
        print_log ( 'v_dist_code_combination: ' || v_dist_code_combination );
        print_log ( 'v_company: ' || v_company );
        print_log ( 'v_account: ' || v_account );
        print_log ( 'v_account_description: ' || v_account_description );
        print_log ( 'v_department: ' || v_department );
        print_log ( 'v_product: ' || v_product );
        print_log ( 'v_division: ' || v_division );        
        print_log ( 'v_destination: ' || v_destination );
        print_log ( 'v_office: ' || v_office );
        print_log ( 'v_origin: ' || v_origin );
        print_log ( 'v_intercompany: ' || v_intercompany );
        
    FOR inv_rec in Select_Inv LOOP

        invoice_number_v := inv_rec.invoice_number;
        supplier_number_v := inv_rec.supplier_number;
        supplier_name_v := inv_rec.supplier_name;

        print_log( 'Invoice: '||invoice_number_v);
        print_log('Supplier: '||supplier_number_v);
        print_log( 'Supplier Name: '||supplier_name_v);

        -- Initialize variables
        gl_date_from_int_v        := null;
        gl_date_v             := null;
        terms_id_v            := null;
        oracle_vendor_site_id_v        := null;
        pay_group_lookup_code_v        := null;
        payment_method_lookup_code_v     := null;
        invoice_type_v             := null;
        currency_code_v         := null;
        invoice_amount_v        :=null;
        v_error_message := NULL;

      -- SB
      v_vendor_site_id := NULL;
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
      v_l_division := NULL;      
      v_l_destination := NULL;
      v_l_office := NULL;
      v_l_origin := NULL;
      v_l_intercompany := NULL;
      --
      -- SB
      
      base_currency_code_v := NULL;
      terms_id_v := NULL;
      terms_name_v := NULL;

      supplier_site_code_v := NULL;
      oracle_invoice_num_v := NULL;
      pay_group_lookup_code_v := NULL;
      payment_method_lookup_code_v := NULL;

      stmt_v := 10;
        -- Get the invoice header info from the interface table 
        SELECT to_date(invoice_date,'MM/DD/YYYY'),  supplier_site_code, invoice_amount, description,
            upper(invoice_type), currency_code, to_date(gl_date,'MM/DD/YYYY'),substr(distr_account,1,2),substr(distr_account,13,3)
        INTO invoice_date_v, supplier_site_code_v,  invoice_amount_v, description_v,
            invoice_type_v, currency_code_v, gl_date_from_int_v, v_company, v_division_h
        FROM AJCL_BC_EXPENSE_RPT_INT
        WHERE nvl(supplier_number,'XXXXX') = nvl(inv_rec.supplier_number,'XXXXX')
        AND   nvl(supplier_name,'XXXXX') = nvl(inv_rec.supplier_name,'XXXXX')
        AND invoice_number = inv_rec.invoice_number
        AND nvl(status,'NEW') <> 'INTERFACED'
        AND rownum =1;
        print_log('v_division_h: '||v_division_h);
        
        -- Get KANO company based on division 927 for liability account
        IF v_division_h = '927' THEN
            v_company:='52';
        END IF;

      stmt_v := 20;    

      print_log ( 'invoice_date_v: ' || invoice_date_v );
      print_log ( 'description_v: ' || description_v );
      print_log ( 'invoice_type_v: ' || invoice_type_v );
      print_log ( 'currency_code_v: ' || currency_code_v );
      print_log ( 'gl_date_from_int_v: ' || gl_date_from_int_v );
      print_log ( 'invoice_amount_v: ' || invoice_amount_v );
      print_log ( 'v_company: ' || v_company );

        IF supplier_number_v is not null THEN        

            stmt_v := 20;
            -- Find the terms_id and pay group from vendor site
            Begin
                SELECT terms_id, vendor_site_id, pay_group_lookup_code, payment_method_lookup_code, vendor_id
                INTO terms_id_v, oracle_vendor_site_id_v, pay_group_lookup_code_v, payment_method_lookup_code_v, v_vendor_id
                FROM po_vendor_sites  
                WHERE vendor_site_code = supplier_site_code_v
                AND vendor_id = (SELECT vendor_id 
                        FROM po_vendors  
                        WHERE segment1 = supplier_number_v);
            Exception
                When NO_DATA_FOUND then
                    print_log( 'Supplier Site: '||supplier_site_code_v||
                                    ' Not found in Oracle for Supplier: '||supplier_number_v);
                    v_error_message :=  'Supplier Site: '||supplier_site_code_v|| ' Not found in Oracle for Supplier: '||supplier_number_v;
                When OTHERS then null;
                    v_error_message := 'Error when getting data from Oracle vendor site: '||supplier_site_code_v||' - '||SQLERRM;
            End;
        ELSE

            print_log( 'Supplier Number missing from data file');
            v_error_message:='Supplier Number missing from data file';
        
        END IF;
        
            -- Determine the gl date
      --      gl_date_v := gl_date_from_int_v; --KHRONUS/MBetti 20240731 - Se definió utilizar SYSDATE por default, a menos que venga predefinido por el parametro gv_gl_date
                gl_date_v := NVL(gv_gl_date,TRUNC(SYSDATE));

      stmt_v := 30;    


      stmt_v := 40;    


        oracle_invoice_num_v := supplier_number_v || '-' || invoice_number_v;

        -- Find the terms_id, and pay group
        stmt_v := 60;


      SELECT ap_invoices_interface_s.nextval
           INTO inv_id_v
           FROM dual;

        v_line_number := 0;
        
      -- Create Invoice Lines
      For inv_line_rec in Select_Inv_Line LOOP

        distr_account_v := null;
        distr_acct_num_v := null;

        distr_acct_num_v := substr(inv_line_rec.distr_account,4,4);

        print_log ( 'distr_acct_num_v: ' || distr_acct_num_v ); 

        distr_account_v := inv_line_rec.distr_account;

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
                 DECODE(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4'
                                                                            ,p_oracle_value   => v_l_segment4
                                                                            ,p_bc_dimension   => 'DIVISION'), NULL,v_l_segment4,'000') product,
                 NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4'
                                                                            ,p_oracle_value   => v_l_segment4
                                                                            ,p_bc_dimension   => 'DIVISION'), '000') division,                                                                               
                 DECODE(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'
                                                                            ,p_oracle_value   => v_l_segment5
                                                                            ,p_bc_dimension   => 'OFFICE'), NULL,v_l_segment5,'000') destination,
                 NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'
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
                 v_l_division,                 
                 v_l_destination,
                 v_l_office,
                 v_l_origin,
                 v_l_intercompany
            FROM ajc.ajc_bc_accounts aba
           WHERE aba.oracle_account = v_l_segment2;

        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            RAISE e_account_not_exist;

        END;

        -- Get KANO company based on division 927 for expense account
        IF v_l_division = '927' THEN
            v_l_company:='52';
        END IF;
        print_log ( 'v_l_company: ' || v_l_company );
        print_log ( 'v_l_account: ' || v_l_account );
        print_log ( 'v_l_account_description: ' || v_l_account_description );
        print_log ( 'v_l_department: ' || v_l_department );
        print_log ( 'v_l_product: ' || v_l_product );
        print_log ( 'v_l_division: ' || v_l_division );        
        print_log ( 'v_l_destination: ' || v_l_destination );
        print_log ( 'v_l_office: ' || v_l_office );
        print_log ( 'v_l_origin: ' || v_l_origin );
        print_log ( 'v_l_intercompany: ' || v_l_intercompany );
        -- SB

        print_log ( 'distr_account_v: ' || distr_account_v );


        SELECT ap_invoice_lines_interface_s.nextval
          INTO inv_line_id_v
          FROM dual;

        v_line_number := v_line_number + 1;
        
        stmt_v := 70;

        INSERT 
          INTO AJCL_BC_AP_CERTIFY_LINES
             ( invoice_id,
               invoice_line_id,
               line_number,
               line_type_lookup_code,
               amount,
               accounting_date,
               description,
               dist_code_concatenated,
               --
               set_of_books_id,
               set_of_books_name,
               dist_code_combination_id,
               company,
               account,
               account_description,
               department,
               product,
               division,
               destination,
               office,
               origin,
               intercompany,
               --
               last_updated_by, 
               last_update_date, 
               last_update_login,
               created_by, 
               creation_date,
               org_id,
               attribute1,
               attribute3,
               status,
               request_id,
               pdf_file_url )
      VALUES ( inv_id_v,
               inv_line_id_v,
               v_line_number,--inv_line_rec.line_num,
               upper(inv_line_rec.line_type),
               inv_line_rec.line_amount,
               gl_date_v,
               inv_line_rec.line_num ||' - '|| inv_line_rec.description,
               distr_account_v,
               --
               gv_set_of_books_id,
               gv_set_of_books_name,
               v_l_dist_code_combination_id,
               v_l_company,
               v_l_account,
               v_l_account_description,
               v_l_department,
               v_l_product,
               v_l_division,
               v_l_destination,
               v_l_office,
               v_l_origin,
               v_l_intercompany,
               --
               gv_user_id, 
               sysdate, 
               gv_user_id,
               gv_user_id,
               sysdate,
               gv_org_id,
               inv_line_rec.worksheet_number,
               inv_line_rec.record_id,
               'NEW',
               gv_request_id,
               inv_line_rec.invoice_image_url );


      End LOOP; -- inv_line_rec

      -- Create Invoice Header Record
      stmt_v := 90;

      -- Inicio Agregado SBanchieri 20220412
      IF ( terms_id_v IS NOT NULL ) THEN

        BEGIN

          SELECT SUBSTR(name,1,10)
            INTO terms_name_v
            FROM ap_terms_tl
           WHERE term_id = terms_id_v;

        EXCEPTION
          WHEN OTHERS THEN
            terms_name_v := NULL;

        END;

      END IF;
      -- Fin Agregado SBanchieri 20220412

      INSERT 
        INTO AJCL_BC_AP_CERTIFY_INVOICES
           ( invoice_id,
             invoice_num,
             invoice_type_lookup_code,
             invoice_date,
             vendor_num,
             vendor_id,
             vendor_name,
             vendor_site_code,
             vendor_site_id,
             invoice_amount,
             terms_id,
             terms_name,
             last_update_date, 
             last_updated_by, 
             last_update_login,
             creation_date, 
             created_by,
             source,
             gl_date,
             org_id,
             accts_pay_code_concatenated,
             dist_code_combination,
             -- SB
             set_of_books_id,
             set_of_books_name,
             company,
             account,
             account_description,
             department,
             product,
             division,
             destination,
             office,
             origin,
             intercompany,
             -- SB
             invoice_currency_code,
             description,
             payment_method_lookup_code,
             pay_group_lookup_code,
             -- pdf_file_url,
             status,
             request_id,
             error_message )
    VALUES ( inv_id_v,
             oracle_invoice_num_v,
             invoice_type_v,
             invoice_date_v,
             --SB 
             supplier_number_v, -- '426247', 
             v_vendor_id, -- 8619601,
             inv_rec.supplier_name, -- 'AMERICAN EXPRESS.',
             -- 20230426 SUBSTR(supplier_site_code_v,1,10), -- 'OFFICE',
             supplier_site_code_v,
             -- 20230426
             v_vendor_site_id, -- 673464, 
             --SB 
             invoice_amount_v,
             terms_id_v,
             terms_name_v,
             sysdate, 
             gv_user_id, 
             gv_user_id,
             sysdate, 
             gv_user_id,
             source_c,
             gl_date_v,
             gv_org_id,
             liab_code_concat_v,
             v_dist_code_combination,
             -- SB
             gv_set_of_books_id,
             gv_set_of_books_name,
             v_company,
             v_account,
             v_account_description,
             v_department,
             v_product,
             v_division,
             v_destination,
             v_office,
             v_origin,
             v_intercompany,
             -- SB
             nvl(currency_code_v,base_currency_code_v),
             description_v,
             payment_method_lookup_code_v, 
             pay_group_lookup_code_v,
             -- inv_rec.invoice_image_url,
             DECODE(v_error_message,NULL,'NEW','ERROR'),
             gv_request_id,
             v_error_message );

        rec_cnt_v := rec_cnt_v + 1;

        stmt_v := 100;    
        -- The status will be used by the program that loads the invoice attachment
        -- UPDATE ajcl_inc_expense_rpt_int -- IMPLEMENTACION DEFINITIVA -- Descomentar
        UPDATE AJCL_BC_EXPENSE_RPT_INT -- IMPLEMENTACION TRANSITORIA -- Descomentar
        SET status='INTERFACED',
                last_update_date=SYSDATE
        WHERE nvl(supplier_number,'XXXXX') = nvl(inv_rec.supplier_number,'XXXXX')
        AND   nvl(supplier_name,'XXXXX') = nvl(inv_rec.supplier_name,'XXXXX')
        AND invoice_number = inv_rec.invoice_number
        AND nvl(status,'NEW') <> 'INTERFACED';

    End LOOP; --  Select_Inv LOOP

/*
    IF rec_cnt_v = 0 THEN

      raise e_no_invoices_found;

    END IF;
*/

    COMMIT;

    p_status := 'S';

    print_log('expense_report_interface_p (-)');

  EXCEPTION
    WHEN e_no_invoices_found THEN
      print_log('expense_report_interface_p (!): ' || SQLERRM);
      print_log ( 'AJC Certify Expense Reports Interface Control');
      print_log ( '-----------------------------------------------------------------------------');
      print_log ( 'No NEW Invoices found to process');
      p_status := 'E';

    WHEN e_account_not_exist THEN
      print_log('expense_report_interface_p (!)');
            error_text_v := 'Account ' || v_l_segment2 || ' not exist in table ajcl_bc_accounts.';

      ajcl_bc_utils_pkg.send_email_p ( p_to => 'agilardi@ajcgroup.com',
                                       p_subject => 'AJC BC INC Certify Interface - ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS')|| ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',
                                       p_message => 'Error processing: ' || error_text_v || CHR(10) ||'Request Id: '||gv_request_id );

      print_log ( error_text_v );
      p_status := 'E';
      ROLLBACK;

    WHEN OTHERS THEN
            print_log('expense_report_interface_p (!)');
      error_code_v := SQLCODE;
            error_text_v := SQLERRM;
      print_log ( '**********************************');
      print_log ( 'Program encountered an unexpected error:');
      print_log ( to_char(error_code_v) || ' - ' || error_text_v || ' | stmt_v: ' || stmt_v);
      print_log ( '**********************************');
      p_status := 'E';

  END expense_report_interface_p;

  /*=========================================================================+
  |                                                                          |
  | Private Function                                                        |
  |    delete_inv                                                           |
  |                                                                          |
  | Description                                                              |
  |    Elimino facturas de la tabla inbound de bc |
  |                                                                          |
  | Parameters                                                               |
  |    p_invoice_id                   IN     NUMBER                    |
  |                                                                          |
  +=========================================================================*/
PROCEDURE delete_inv (p_company_id IN VARCHAR2,
                                      p_invoice_id IN  NUMBER) IS
v_api_delete_header    VARCHAR2(200);    
v_api_delete_lines     VARCHAR2(200);    
v_get_url              VARCHAR2(2000);
v_clob_result_status   CLOB;
v_header_delete_url    VARCHAR2(2000);
v_lines_delete_url     VARCHAR2(2000);
v_header_delete_clob   CLOB;
v_lines_delete_clob    CLOB;
BEGIN
    print_log ('ajc_bc_certify_pkg.delete_inv (+)');
    
      -- Se arma la URL para borrar lineas de la tabla staging
      v_lines_delete_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => gv_bc_environment,
                                                    p_entity => 'PURCHASE INVOICES',
                                                    p_subentity => 'LINES',
                                                    p_method => 'DELETE',
                                                    p_company_id => p_company_id ) || '(''' || p_invoice_ID || ''',0,0)'; -- invoice id, request id, line no

      print_log ( 'v_lines_delete_url: ' || v_lines_delete_url );

      -- Se borran las lineas de la tabla staging
      v_lines_delete_clob := ajcl_bc_ws_utils_pkg.delete_bc_row_f ( p_url => v_lines_delete_url );

      IF ( INSTR(v_lines_delete_clob,'error') != 0 )  THEN

        print_log('Error deleting invoice lines from BC staging table');
        print_log(v_lines_delete_clob);

      ELSE

        print_log('Invoice lines deleted from BC staging table');

      END IF;  

      -- Se arma la URL para borrar cabecera de la tabla staging
        v_header_delete_url :=ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => gv_bc_environment,
                                            p_entity => 'PURCHASE INVOICES',
                                            p_subentity => 'HEADERS',
                                            p_method => 'DELETE',
                                            p_company_id => p_company_id ) || '(''' || p_invoice_ID || ''',0)'; -- invoice id, request id

      print_log ( 'v_header_delete_url: ' || v_header_delete_url );

      -- Se borra la cabecera de la tabla staging
      v_header_delete_clob := ajcl_bc_ws_utils_pkg.delete_bc_row_f ( p_url => v_header_delete_url );

      IF ( INSTR(v_header_delete_clob,'error') != 0 )  THEN

        print_log('Error deleting invoice header from BC staging table');
        print_log(v_header_delete_clob);

      ELSE

        print_log('Invoice Header deleted from BC staging table');

      END IF; 
      
    print_log ('ajc_bc_certify_pkg.delete_inv (-)');      
END;          

  /*=========================================================================+
  |                                                                          |
  | Private Procedure                                                        |
  |    call_ws                                                               |
  |                                                                          |
  | Description                                                              |
  |    Llamo al Web Service que inserta en tablas de staging de              |
  |    Purchase Invoices en BC            
