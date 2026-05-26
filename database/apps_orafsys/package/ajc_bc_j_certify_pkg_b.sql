CREATE OR REPLACE PACKAGE BODY              ajc_bc_j_certify_pkg AS



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



        EXCEPTION

          WHEN NO_DATA_FOUND THEN

            print_log('ERROR: Account does not exists for v_l_segment2: '||v_l_segment2);

            error_text_v :='ERROR: Account does not exists for v_l_segment2: '||v_l_segment2;

            RAISE e_account_not_exist;



        END;



        print_log ( 'v_l_company: ' || v_l_company );

        print_log ( 'v_l_account: ' || v_l_account );

        print_log ( 'v_l_account_description: ' || v_l_account_description );

        print_log ( 'v_l_department: ' || v_l_department );

        print_log ( 'v_l_product: ' || v_l_product );

        print_log ( 'v_l_destination: ' || v_l_destination );

        print_log ( 'v_l_office: ' || v_l_office );

        print_log ( 'v_l_origin: ' || v_l_origin );

        print_log ( 'v_l_intercompany: ' || v_l_intercompany );

        -- SB



        print_log ( 'distr_account_v: ' || distr_account_v );



        -- 12/7/19, Added Dept override logic

        -- Retrieve the dept override for the account if it exists.

        -- Since lookups are being used its not possible to setup one account

        -- with multiple override dept values so we dont need to check for more than one value

        BEGIN



          SELECT description

            INTO dept_override_v

            FROM fnd_lookup_values

           WHERE lookup_type = 'AJC_INC_EXP_RPT_DEPT_OVERRIDE'

             AND lookup_code = distr_acct_num_v 

             AND enabled_flag = 'Y'

             AND start_date_active <= trunc(sysdate)

             AND nvl(end_date_active,sysdate + 1) >= trunc(sysdate);



        EXCEPTION

          WHEN NO_DATA_FOUND then 

            null;

          WHEN OTHERS then 

            null;



        END;

        

        IF dept_override_v is not null THEN



          print_log ( 'Distr: '||distr_account_v);

          print_log ( 'Dept override found for account ' || distr_acct_num_v || ': ' || dept_override_v );



          distr_account_v := substr(distr_account_v,1,8) || dept_override_v || substr(distr_account_v,12);

          print_log ( 'Distr with dept override: '||distr_account_v);



        END IF;        



        SELECT ap_invoice_lines_interface_s.nextval

          INTO inv_line_id_v

          FROM dual;



        stmt_v := 70;

        print_log('Insertando invoice_line_id: '||inv_line_id_v);

        

        INSERT 

          INTO AJC_BC_INC_AP_CERTIFY_LINES

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

               line_num_v,

               upper(inv_line_rec.line_type),

               inv_line_rec.line_amount,

               gl_date_v,

               inv_line_rec.description,

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

               org_id_v,

               inv_line_rec.worksheet_number,

               inv_line_rec.record_id,

               'NEW',

               gv_request_id,

               inv_line_rec.invoice_image_url );



        line_num_v := line_num_v + 1;



        IF inv_line_rec.reimburse_flag = advance_c THEN



          invoice_amount_v := invoice_amount_v + (inv_line_rec.line_amount * -1) ;



          -- Create a line to credit the travel advance account

          SELECT ap_invoice_lines_interface_s.nextval

            INTO inv_line_id_v

            FROM dual;



          stmt_v := 80;



          INSERT 

            INTO AJC_BC_INC_AP_CERTIFY_LINES

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

                 line_num_v,

                 upper(inv_line_rec.line_type),

                 inv_line_rec.line_amount * -1,

                 gl_date_v,

                 inv_line_rec.description,

                 travel_adv_distr_account_v,

                 --

                 v_set_of_books_id,

                 v_set_of_books_name,

                 v_t_dist_code_combination_id,

                 v_t_company,

                 v_t_account,

                 v_t_account_description,

                 v_t_department,

                 v_t_product,

                 v_t_destination,

                 v_t_office,

                 v_t_origin,

                 v_t_intercompany,

                 --

                 gv_user_id, 

                 sysdate, 

                 gv_user_id,

                 gv_user_id,

                 sysdate,

                 org_id_v,

                 inv_line_rec.worksheet_number,

                 inv_line_rec.record_id,

                 'NEW',

                 gv_request_id,

                 inv_line_rec.invoice_image_url ); 



          line_num_v := line_num_v + 1;



        END IF;

      EXCEPTION

      WHEN OTHERS THEN

        print_log('Error en el loop de lineas. Se ejecuta rollback');

        ROLLBACK;

        raise e_generic;

      END;

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



      print_log('Insertando invoice_id: '||inv_id_v);

      

      INSERT 

        INTO AJC_BC_INC_AP_CERTIFY_INVOICES

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

             request_id )

    VALUES ( inv_id_v,

             oracle_invoice_num_v,

             invoice_type_v,

             invoice_date_v,

             --SB 

             supplier_number_v, -- '426247', 

             v_vendor_id, -- 8619601,

             v_vendor_name, -- 'AMERICAN EXPRESS.',

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

             org_id_v,

             liab_code_concat_v,

             v_dist_code_combination,

             -- SB

             v_set_of_books_id,

             v_set_of_books_name,

             v_company,

             v_account,

             v_account_description,

             v_department,

             v_product,

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

             'NEW',

             gv_request_id );



        rec_cnt_v := rec_cnt_v + 1;



        stmt_v := 100;    

        -- The status will be used by the program that loads the invoice attachment

        -- UPDATE ajc_inc_expense_rpt_int -- IMPLEMENTACION DEFINITIVA -- Descomentar

        UPDATE AJC_BC_INC_EXPENSE_RPT_INT -- IMPLEMENTACION TRANSITORIA -- Descomentar

           SET status = 'INTERFACED', 

               org_id = org_id_v,

               oracle_supplier_num = supplier_number_v,

               oracle_supplier_site_code = supplier_site_code_v,

               oracle_invoice_num = oracle_invoice_num_v

         WHERE nvl(supplier_number,'XXXXX') = nvl(inv_rec.supplier_number,'XXXXX')

           AND nvl(supplier_name,'XXXXX') = nvl(inv_rec.supplier_name,'XXXXX')

           AND decode(reimburse_flag, advance_c, true_c, reimburse_flag)  = inv_rec.reimburse_flag

           AND invoice_number = inv_rec.invoice_number;

    

    EXCEPTION

    WHEN OTHERS THEN

              print_log ( error_text_v );

        -- marco la factura con error para que sea reprocesada en la pr�xima ejecuci�n      

        UPDATE AJC_BC_INC_EXPENSE_RPT_INT -- IMPLEMENTACION TRANSITORIA -- Descomentar

           SET status = 'ERROR', 

               org_id = org_id_v,

               oracle_supplier_num = supplier_number_v,

               oracle_supplier_site_code = supplier_site_code_v,

               oracle_invoice_num = oracle_invoice_num_v

         WHERE nvl(supplier_number,'XXXXX') = nvl(inv_rec.supplier_number,'XXXXX')

           AND nvl(supplier_name,'XXXXX') = nvl(inv_rec.supplier_name,'XXXXX')

           AND decode(reimburse_flag, advance_c, true_c, reimburse_flag)  = inv_rec.reimburse_flag

           AND invoice_number = inv_rec.invoice_number;              

    END;

    End LOOP; --  Select_Inv LOOP



/*    IF rec_cnt_v = 0 THEN



      raise e_no_invoices_found;



    END IF;

*/

    COMMIT;



    p_status := 'S';



    print_log('expense_report_interface_p (-)');



  EXCEPTION

    WHEN e_no_invoices_found THEN

      print_log('expense_report_interface_p (!): ' || SQLERRM);

      dbms_output.put_line('AJC Certify Expense Reports Interface Control');

      dbms_output.put_line('-----------------------------------------------------------------------------');

      dbms_output.put_line('No NEW invoices found to process');

      print_log ( 'AJC Certify Expense Reports Interface Control');

      print_log ( '-----------------------------------------------------------------------------');

      print_log ( 'No NEW Invoices found to process');

      -- prog_failed_v := FND_CONCURRENT.SET_COMPLETION_STATUS('ERROR','NO Data Found');

      p_status := 'E';



    WHEN e_account_not_exist THEN

      print_log('expense_report_interface_p (!)');

            error_text_v := 'Account ' || v_l_segment2 || ' not exist in table ajc_bc_accounts.';



        BEGIN

          AJC_BC_J_UTILS_PKG.send_email_p ( p_to => gv_support_email,

                                           p_subject => 'AJC BC INC Certify Interface - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'),

                                           p_message => 'Error processing: ' || error_text_v );

        EXCEPTION

            WHEN OTHERS THEN

                print_log('SMTP NOT WORKING.');

        END;

                

      print_log ( error_text_v );

      p_status := 'E';

      ROLLBACK;

      

    WHEN e_no_amex_supp_found THEN

      print_log('expense_report_interface_p (!)');

            error_text_v := 'Amex supplier was not found.';



        BEGIN

          ajc_bc_j_utils_pkg.send_email_p ( p_to => gv_support_email,

                                           p_subject => 'AJC BC INC Certify Interface - ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS')|| ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                           p_message => 'Error processing: ' || error_text_v || CHR(10) ||'Request Id: '||gv_request_id );

        EXCEPTION

            WHEN OTHERS THEN

                print_log('SMTP NOT WORKING.');

        END;

        

      print_log ( error_text_v );

      p_status := 'E';

      ROLLBACK;

      

    WHEN OTHERS THEN

            print_log('expense_report_interface_p (!)');

      error_code_v := SQLCODE;

            error_text_v := SQLERRM;

      dbms_output.put_line('******************************************************************************');

      dbms_output.put_line('Program encountered an unexpected error: ');

      dbms_output.put_line(to_char(error_code_v)||'-'||error_text_v);

      dbms_output.put_line('******************************************************************************');

      print_log ( '**********************************');

      print_log ( 'Program encountered an unexpected error:');

      print_log ( to_char(error_code_v) || ' - ' || error_text_v || ' | stmt_v: ' || stmt_v);

      print_log ( '**********************************');

      p_status := 'E';

END;





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



    v_api_delete_header := ajc_bc_j_ws_utils_pkg.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                                           p_subentity => 'HEADERS',

                                                           p_method => 'DELETE' );

    print_log ('v_api_delete_header: ' || v_api_delete_header);



    v_api_delete_lines := ajc_bc_j_ws_utils_pkg.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                                          p_subentity => 'LINES',

                                                          p_method => 'DELETE' );

    print_log ('v_api_delete_lines: ' || v_api_delete_lines);

    

      -- Se arma la URL para borrar lineas de la tabla staging

      v_lines_delete_url := ajc_bc_j_ws_utils_pkg.get_base_inecta_url_f ( gv_bc_environment,p_company_id ) || v_api_delete_lines

                            -- || '?$filter=requestID eq ' || gv_request_id

                            || '(''' || p_invoice_id || ''',0,0)' -- invoice id, request id, line no

                            ; 



      print_log ( 'v_lines_delete_url: ' || v_lines_delete_url );



      -- Se borran las lineas de la tabla staging

      v_lines_delete_clob := ajc_bc_j_ws_utils_pkg.delete_bc_row_f ( p_url => v_lines_delete_url );



      IF ( INSTR(v_lines_delete_clob,'error') != 0 )  THEN



        print_log('Error deleting invoice lines from BC staging table');

        print_log(v_lines_delete_clob);



      ELSE



        print_log('Invoice lines deleted from BC staging table');



      END IF;  



      -- Se arma la URL para borrar cabecera de la tabla staging

      v_header_delete_url := ajc_bc_j_ws_utils_pkg.get_base_inecta_url_f ( gv_bc_environment, p_company_id ) || v_api_delete_header

                             -- || '?$filter=requestID eq ' || gv_request_id

                             || '(''' || p_invoice_id || ''',0)' -- invoice id, request id

                             ; 



      print_log ( 'v_header_delete_url: ' || v_header_delete_url );



      -- Se borra la cabecera de la tabla staging

      v_header_delete_clob := ajc_bc_j_ws_utils_pkg.delete_bc_row_f ( p_url => v_header_delete_url );



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

  |    Purchase Invoices en BC                                               |

  |                                                                          |

  | Parameters                                                               |

  |    p_message                   IN     NUMBER    Mensaje.                 |

  |                                                                          |

  +=========================================================================*/

  PROCEDURE call_ws ( p_status          OUT   VARCHAR2,

                      p_invoice_count   OUT   NUMBER,

                      p_lines_count     OUT   NUMBER,

                      p_bc_environment   IN   VARCHAR2 ) IS



    CURSOR c_invoices IS

    

    SELECT *

      FROM AJC_BC_INC_AP_CERTIFY_INVOICES 

     WHERE 1=1--request_id = gv_request_id -- Se comenta para que pueda reprocesar facturas rechazadas de ejecuciones anteriores

       AND status IN ('NEW','ERROR','REJECTED')

       AND UPPER(NVL(error_message,'-')) NOT LIKE '%PURCHASE INVOICE%ALREADY EXISTS FOR THIS VENDOR%' --excluyo las facturas que ya existen en BC para que no siga reprocesandolas infinitamente   

      AND vendor_num IS NOT NULL; -- puede venir null en el archivo, no se debe procesar 



      CURSOR c_invoice_lines ( pc_invoice_id   IN   NUMBER ) IS

      SELECT *

        FROM AJC_BC_INC_AP_CERTIFY_LINES 

       WHERE 1=1--request_id = gv_request_id -- Se comenta para que pueda reprocesar facturas rechazadas de ejecuciones anteriores

         AND invoice_id = pc_invoice_id

       --  AND status = 'NEW'

    ORDER BY line_number;



    v_company_id           VARCHAR2(100);

    v_status               VARCHAR2(2000);      



    v_url_header           VARCHAR2(2000);    

    v_api_header           VARCHAR2(200);      

    v_body_header          VARCHAR2(2000);

    v_clob_result_header   CLOB;



    v_url_line             VARCHAR2(2000);

    v_api_line             VARCHAR2(200);    

    v_body_line            VARCHAR2(2000);

    v_clob_result_line     CLOB;



    v_linea_con_error      VARCHAR2(1);

    v_header_con_error      VARCHAR2(1);    

    v_clob_result_job      CLOB;



    v_error_message        VARCHAR2(1000);



  --  v_period_name          gl_periods.period_name%TYPE;

    v_message              VARCHAR2(32000);



  BEGIN



    print_log('ajc_bc_certify_pkg.call_ws (+)');

    

    v_api_header := ajc_bc_j_ws_utils_pkg.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                                    p_subentity => 'HEADERS',

                                                    p_method => 'POST' );

    print_log ('v_api_header: ' || v_api_header);



    v_api_line := ajc_bc_j_ws_utils_pkg.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                                  p_subentity => 'LINES',

                                                  p_method => 'POST' );

    print_log ('v_api_line: ' || v_api_line);

        



    FOR cinv IN c_invoices LOOP



      print_log(' ');

      print_log('invoice_num: ' || cinv.invoice_num);      



      -- Se obtiene el v_company_id

      ajc_bc_j_ws_utils_pkg.get_bc_company_id_f ( p_org_id => NULL,

                                                p_company_number => cinv.company,

                                                p_set_of_books_id  => NULL,

                                                p_bc_company_id => v_company_id,

                                                p_status => v_status );



      print_log('v_company_id: ' || v_company_id);

      

      v_url_header := ajc_bc_j_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, v_company_id ) || v_api_header;

      print_log('v_url_header: ' || v_url_header);



      v_url_line := ajc_bc_j_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, v_company_id ) || v_api_line;

      print_log('v_url_line: ' || v_url_line);      



      v_linea_con_error := 'N';

      v_header_con_error :='N';



      -- Se envian las l�neas

      FOR clin IN c_invoice_lines ( cinv.invoice_id ) LOOP



        -- Si hasta el momento, para el comprobante, no se produjo error en alguna linea, se continua enviando las siguientes

        IF ( v_linea_con_error = 'N' ) THEN



          print_log(' ');

          print_log('line_number: ' || clin.line_number);

          

          p_lines_count := NVL(p_lines_count,0) + 1;



          v_error_message := NULL;



          APEX_JSON.initialize_clob_output;

          APEX_JSON.open_object;

             

          -- Se arma la linea

          APEX_JSON.write('invoiceID', TO_CHAR(cinv.invoice_id));

          APEX_JSON.write('requestID', TO_CHAR(gv_request_id));

          APEX_JSON.write('lineNo', clin.line_number);

          APEX_JSON.write('amount', clin.amount);

          -- 20230518 No se envia mas valor porque da error y se esta enviando el dato en accountDescription

          -- APEX_JSON.write('description', clin.description, TRUE);

          APEX_JSON.write('description', '', TRUE);

          --  --KHRONUS/MBetti 20240731 - Se defini� utilizar parametro gv_gl_date , y si es null --> SYSDATE

         -- APEX_JSON.write('accountingDate', TO_CHAR(SYSDATE,'YYYY-MM-DD'));

          APEX_JSON.write('accountingDate', TO_CHAR(NVL(gv_gl_date,TRUNC(SYSDATE)),'YYYY-MM-DD'));

          APEX_JSON.write('periodName',  '', TRUE);--APEX_JSON.write('periodName', v_period_name);

          APEX_JSON.write('worksheetNo', '', TRUE);

          APEX_JSON.write('baseAmount',0,TRUE); -- ?

          APEX_JSON.write('exchangeRate',cinv.exchange_rate, TRUE); 

          APEX_JSON.write('exchangeRateType', cinv.exchange_rate_type, TRUE); 

          APEX_JSON.write('exchangeDate', cinv.exchange_date, TRUE);

          APEX_JSON.write('organisationID', TO_CHAR(clin.org_id) );

          APEX_JSON.write('setOfBooksID', clin.set_of_books_id, TRUE); 

          APEX_JSON.write('setOfBooksName', clin.set_of_books_name); 

          APEX_JSON.write('distCodeCombination', clin.dist_code_combination_id);



          APEX_JSON.write('company',ajc_bc_j_account_dim_pkg.account_dim_required(clin.account,'COMPANY',clin.company),TRUE);       



          APEX_JSON.write('account', clin.account); 



          APEX_JSON.write('accountDescription', clin.description, TRUE); -- Se envia la descripcion de la linea en Oracle



          -- 20221215 APEX_JSON.write('department', clin.department); 

          APEX_JSON.write('department',ajc_bc_j_account_dim_pkg.account_dim_required(clin.account,'DEPARTMENT',clin.department),TRUE);   



          -- 20221215 APEX_JSON.write('product', clin.product); 

          APEX_JSON.write('product',ajc_bc_j_account_dim_pkg.account_dim_required(clin.account,'PRODUCT',clin.product),TRUE);   



          -- 20221215 APEX_JSON.write('destination', clin.destination);

          APEX_JSON.write('destination',ajc_bc_j_account_dim_pkg.account_dim_required(clin.account,'DESTINATION',clin.destination),TRUE);   



          -- 20221215 APEX_JSON.write('office', clin.office);

          APEX_JSON.write('office',ajc_bc_j_account_dim_pkg.account_dim_required(clin.account,'OFFICE',clin.office),TRUE);   



          -- 20221215 APEX_JSON.write('origin', clin.origin);

          APEX_JSON.write('origin',ajc_bc_j_account_dim_pkg.account_dim_required(clin.account,'ORIGIN',clin.origin),TRUE); 



          -- 20221205 NO SE DEBE ENVIAR MAS APEX_JSON.write('intercompany', clin.intercompany);

          

          APEX_JSON.write('pdfFileUrl',clin.pdf_file_url, TRUE);



          APEX_JSON.close_object;



          v_body_line := APEX_JSON.get_clob_output;



          print_log('v_body_line: ' || v_body_line);                          



          v_clob_result_line := ajc_bc_j_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url_line,

                                                                          p_request_header_name1 => 'Content-Type',

                                                                          p_request_header_value1 => 'application/json',

                                                                          p_request_header_name2 => NULL,

                                                                          p_request_header_value2 => NULL, 

                                                                          p_http_method => 'POST',

                                                                          p_body => v_body_line );  



          print_log('v_clob_result_line: ' || v_clob_result_line);



          APEX_JSON.free_output;



          IF ( INSTR(v_clob_result_line,'error') != 0 ) OR (v_clob_result_line IS NULL) THEN



            print_log('Error when sending the invoice line.');



            IF v_clob_result_line IS NULL THEN

                v_error_message :=  'Could not get result after sending the invoice line to BC';

            ELSE

                v_error_message := 'Error when sending invoice line to BC: ' ||

                                SUBSTR(v_clob_result_line,INSTR(v_clob_result_line,'message') + 10);

            END IF;

            

            print_log(v_error_message);



            UPDATE AJC_BC_INC_AP_CERTIFY_LINES

               SET status = 'ERROR',

                   error_message = v_error_message,

                   json_data = v_body_line,

                   json_data_response = v_clob_result_line,

                   request_id = gv_request_id

             WHERE invoice_id = cinv.invoice_id

               AND line_number = clin.line_number;

             --  AND request_id = gv_request_id; -- Se comenta para que pueda reprocesar facturas rechazadas de ejecuciones anteriores



            v_linea_con_error := 'Y';



          ELSE



            UPDATE AJC_BC_INC_AP_CERTIFY_LINES

               SET status = 'SENT',

                    error_message=NULL,

                   json_data = v_body_line,

                   json_data_response = v_clob_result_line,

                   request_id = gv_request_id

             WHERE invoice_id = cinv.invoice_id

               AND line_number = clin.line_number;

             --  AND request_id = gv_request_id; -- Se comenta para que pueda reprocesar facturas rechazadas de ejecuciones anteriores



            print_log('La l�nea se envi� correctamente.');



          END IF;



        END IF;



      END LOOP;



      -- Si todas las lineas se enviaron sin problema

      IF ( v_linea_con_error = 'N' ) THEN



        v_error_message := NULL;



        -- Se envia la cabecera

        APEX_JSON.initialize_clob_output;

        APEX_JSON.open_object;



        --APEX_JSON.write('requestID', TO_CHAR(cinv.request_id));

        APEX_JSON.write('requestID', TO_CHAR(gv_request_id));

        APEX_JSON.write('invoiceID',TO_CHAR(cinv.invoice_id));

        APEX_JSON.write('invoiceNo',cinv.invoice_num);

        --

        APEX_JSON.write('invoiceType',cinv.invoice_type_lookup_code);

        APEX_JSON.write('invoiceDate',TO_CHAR(cinv.invoice_date,'YYYY-MM-DD'), TRUE);

        APEX_JSON.write('vendorNo',cinv.vendor_num);

        --

        APEX_JSON.write('vendorSiteCode', cinv.vendor_site_code);

        APEX_JSON.write('invoiceAmount', cinv.invoice_amount );

        APEX_JSON.write('invoiceCurrencyCode', cinv.invoice_currency_code);

        APEX_JSON.write('exchangeRate', cinv.exchange_rate, TRUE);

        APEX_JSON.write('exchangeRateType', cinv.exchange_rate_type, TRUE);

        APEX_JSON.write('exchangeDate', cinv.exchange_date, TRUE);

        APEX_JSON.write('baseAmount', 0, TRUE); -- ?

        --APEX_JSON.write('gLDate', TO_CHAR(cinv.gl_date,'YYYY-MM-DD')); --KHRONUS/MBetti 20240731 - Se defini� utilizar parametro gv_gl_date , y si es null --> SYSDATE

        APEX_JSON.write('gLDate', TO_CHAR(NVL(gv_gl_date,TRUNC(SYSDATE)),'YYYY-MM-DD'));

        APEX_JSON.write('organisationID', TO_CHAR(cinv.org_id));

        APEX_JSON.write('description', cinv.description, TRUE);

        APEX_JSON.write('termName', cinv.terms_name, TRUE);

        APEX_JSON.write('termsDate', TO_CHAR(cinv.terms_date,'YYYY-MM-DD'), TRUE);

        -- APEX_JSON.write('dueDate', TO_CHAR(cinv.invoice_date + 14,'YYYY-MM-DD'), TRUE); -- Lo tiene que calcular BC

        APEX_JSON.write('paymentMethodCode', cinv.payment_method_lookup_code, TRUE);

        APEX_JSON.write('payGroupCode', cinv.pay_group_lookup_code,TRUE);

        APEX_JSON.write('setofBooksID', cinv.set_of_books_id, TRUE);

        APEX_JSON.write('setofBooksName', cinv.set_of_books_name, TRUE ); 

        -- APEX_JSON.write('accountsPayCode', '1003', TRUE); -- Se enviaba el id de la cuenta, pero ya no es necesario



        -- 20221215 APEX_JSON.write('company', cinv.company, TRUE);

        APEX_JSON.write('company',ajc_bc_j_account_dim_pkg.account_dim_required(cinv.account,'COMPANY',cinv.company),TRUE);    



        APEX_JSON.write('account', cinv.account, TRUE ); 

        APEX_JSON.write('accountDescription', cinv.account_description, TRUE);



        -- 20221215 APEX_JSON.write('department', cinv.department , TRUE);

        APEX_JSON.write('department',ajc_bc_j_account_dim_pkg.account_dim_required(cinv.account,'DEPARTMENT',cinv.department),TRUE); 



        -- 20221215 APEX_JSON.write('product', cinv.product, TRUE); 

        APEX_JSON.write('product',ajc_bc_j_account_dim_pkg.account_dim_required(cinv.account,'PRODUCT',cinv.product),TRUE);



        -- 20221215 APEX_JSON.write('destination', cinv.destination, TRUE); 

        APEX_JSON.write('destination',ajc_bc_j_account_dim_pkg.account_dim_required(cinv.account,'DESTINATION',cinv.destination),TRUE);



        -- 20221215 APEX_JSON.write('origin', cinv.origin, TRUE);

        APEX_JSON.write('origin',ajc_bc_j_account_dim_pkg.account_dim_required(cinv.account,'ORIGIN',cinv.origin),TRUE);



        -- 20221205 NO SE DEBE ENVIAR MAS APEX_JSON.write('intercompany', cinv.intercompany, TRUE);

        -- Se debe enviar a nivel linea 

        -- APEX_JSON.write('pdfFileUrl',cinv.pdf_file_url, TRUE);

        --

        APEX_JSON.write('source', cinv.source, TRUE);



        -- 20221215 APEX_JSON.write('office', cinv.office, TRUE);

        APEX_JSON.write('office',ajc_bc_j_account_dim_pkg.account_dim_required(cinv.account,'OFFICE',cinv.office),TRUE); 



        APEX_JSON.close_object;

        v_body_header := APEX_JSON.get_clob_output;



        print_log(' ');

        print_log('v_body_header: ' || v_body_header);



        v_clob_result_header := ajc_bc_j_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url_header,

                                                                          p_request_header_name1 => 'Content-Type',

                                                                          p_request_header_value1 => 'application/json',

                                                                          p_request_header_name2 => NULL,

                                                                          p_request_header_value2 => NULL, 

                                                                          p_http_method => 'POST',

                                                                          p_body => v_body_header );  





        print_log('v_clob_result_header: ' || v_clob_result_header);



        APEX_JSON.free_output;



        IF (  INSTR(v_clob_result_header,'error') != 0 )  OR (v_clob_result_header IS NULL) THEN



          print_log('Error when sending invoice header to BC.');

          print_log(v_clob_result_header);



          IF v_clob_result_header IS NULL THEN

            v_error_message :=  'Could not get result after sending the invoice header to BC';

          ELSE

            v_error_message := 'Error when sending invoice header to BC: ' ||

                              SUBSTR(v_clob_result_header,INSTR(v_clob_result_header,'message') + 10);

          END IF;

          

          print_log(v_error_message);



          UPDATE AJC_BC_INC_AP_CERTIFY_INVOICES

             SET status = 'ERROR',

                 error_message = v_error_message,

                 json_data = v_body_header,

                 json_data_response = v_clob_result_header,

                 request_id = gv_request_id,

                 last_update_date=SYSDATE

           WHERE invoice_id = cinv.invoice_id;

            -- AND request_id = gv_request_id;-- Se comenta para que pueda reprocesar facturas rechazadas de ejecuciones anteriores

            

            v_header_con_error := 'Y';

            

        ELSE



          UPDATE AJC_BC_INC_AP_CERTIFY_INVOICES

             SET status = 'SENT',

                 json_data = v_body_header,

                 json_data_response = v_clob_result_header,

                 request_id = gv_request_id,

                 last_update_date=SYSDATE,

                 error_message = NULL

           WHERE invoice_id = cinv.invoice_id;

            -- AND request_id = gv_request_id;-- Se comenta para que pueda reprocesar facturas rechazadas de ejecuciones anteriores



          print_log('El comprobante se envi� correctamente.');



        END IF;



        p_invoice_count := NVL(p_invoice_count,0) + 1;



      ELSE



        UPDATE AJC_BC_INC_AP_CERTIFY_INVOICES

           SET status = 'ERROR',

               error_message = 'An error occurred in one of the invoice lines.',

               request_id = gv_request_id,

               last_update_date=SYSDATE

         WHERE invoice_id = cinv.invoice_id;

          -- AND request_id = gv_request_id;-- Se comenta para que pueda reprocesar facturas rechazadas de ejecuciones anteriores



      END IF;



        -- si hubo algun error al insertar header o lineas en la inbound, por las dudas llamo al procedimiento para borrarlas y que no queden registros huerfanos

        IF v_header_con_error = 'Y' OR v_linea_con_error = 'Y' THEN

            delete_inv(v_company_id,cinv.invoice_id);

        END IF;

        

    END LOOP;



    p_status := 'S';



    print_log('ajc_bc_certify_pkg.call_ws (-)');



  EXCEPTION

    WHEN OTHERS THEN

      print_log('ajc_bc_certify_pkg.call_ws (!) '||SQLERRM);

      p_status := 'E';



  END call_ws;



  /*=========================================================================+

  |                                                                          |

  | Private Procedure                                                        |

  |    call_job                                                              |

  |                                                                          |

  | Description                                                              |

  |    Llamo al Web Service que ejecuta Job que procesa tablas de            |

  |    Purchase Document                                                     |

  |                                                                          |

  | Parameters                                                               |

  |    p_message                   IN     NUMBER    Mensaje.                 |

  |                                                                          |

  +=========================================================================*/

  PROCEDURE call_job ( p_status          OUT   VARCHAR2

                      ,p_error_message   OUT   VARCHAR2

                      ,p_bc_environment   IN   VARCHAR2 ) IS



    CURSOR c_companies IS

    SELECT DISTINCT abcc.bc_company_id company_id,

           abci.org_id

      FROM AJC_BC_INC_AP_CERTIFY_INVOICES abci,

           ajc_BC_COMPANIES abcc

     WHERE abci.status = 'SENT'

    --  AND abci.request_id = gv_request_id -- 20240927 se comenta request_id para poder re-procesar facturas que quedaron SENT en ejecucion anterior porque fall� call_job

       AND abci.company = abcc.oracle_company_number;



    v_job_object_id     NUMBER;

    v_status            VARCHAR2(20);

    v_error_message     VARCHAR2(2000);

    v_clob_result_job   CLOB;



  BEGIN



    print_log ('ajc_bc_certify_pkg.call_job (+)');



    FOR cc IN c_companies LOOP



      print_log ( 'company_id: ' || cc.company_id );



      v_job_object_id := ajc_bc_j_ws_utils_pkg.get_object_id_f ( 'PURCHASE INVOICES' );

      print_log ( 'v_job_object_id: ' || v_job_object_id );



        v_clob_result_job := AJC_BC_J_WS_UTILS_PKG.run_job_queue_f ( p_bc_environment => p_bc_environment,

                                                                     p_company_id => cc.company_id,

                                                                     p_object_id => v_job_object_id );                                                                      



        print_log ( 'v_clob_job_result: ' || v_clob_result_job );



        IF ( INSTR(UPPER(v_clob_result_job),'ERROR') = 0 ) THEN 



          print_log ( 'Job was executed successfully.' );

          v_status := 'SUCCESS';



        ELSE



         v_error_message := 'Error executing job 70004 Purchase Documents: '|| v_clob_result_job;

         print_log (v_error_message);

          v_status := 'ERROR';



        END IF;



      -- Se inserta registro de control

      INSERT

        INTO AJC_BC_INC_AP_CERTIFY_CONTROL

             ( request_id,

               org_id,

               status,

               job_response,

               creation_date )

      VALUES ( gv_request_id,

               cc.org_id,

               v_status,

               v_clob_result_job,

               SYSDATE );



    END LOOP;



    IF v_status = 'SUCCESS' THEN 

        p_status := 'S';

    ELSE

        p_status := 'E';

        p_error_message := v_error_message;

    END IF;

        

    print_log ('ajc_bc_certify_pkg.call_job (-)');   



  EXCEPTION

    WHEN others THEN

        v_error_message := 'Unhandled error when calling Job Web Service, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('ajc_bc_certify_pkg.call_job (!)');



  END call_job;



  /*=========================================================================+

  |                                                                          |

  | Private Procedure                                                        |

  |    call_status                                                           |

  |                                                                          |

  | Description                                                              |

  |    Llamo al Web Service que retorna el status de los registros enviados  |

  |    y procesados por el job.                                              |

  |                                                                          |

  | Parameters                                                               |

  |    p_message                   IN     NUMBER    Mensaje.                 |

  |                                                                          |

  +=========================================================================*/

  PROCEDURE call_status ( p_status          OUT   VARCHAR2

                         ,p_error_message   OUT   VARCHAR2

                         ,p_bc_environment  IN   VARCHAR2 ) IS



    CURSOR c_companies IS

    

    SELECT DISTINCT abcc.bc_company_id company_id, abci.request_id, abcc.bc_company_name-- 20240927 se agrega request_id para poder re-procesar facturas que quedaron SENT en ejecucion anterior porque fall� call_job

      FROM AJC_BC_INC_AP_CERTIFY_INVOICES abci,

           ajc_BC_COMPANIES abcc

     WHERE abci.status = 'SENT'

      -- AND abci.request_id = gv_request_id-- 20240927 se comenta request_id para poder re-procesar facturas que quedaron SENT en ejecucion anterior porque fall� call_job

       AND abci.company = abcc.oracle_company_number;



    v_status               VARCHAR2(1);

    v_error_message        VARCHAR2(2000);

    v_api_status           VARCHAR2(200); 

    v_get_url              VARCHAR2(2000);

    v_clob_result_status   CLOB;



    CURSOR c_status ( p_clob_result_status   IN   CLOB ) IS

    SELECT documentType,

           invoiceID,

           invoiceNo,

           invoiceType,

           invoiceDate,

           vendorNo,

           glDate,

           status,

           StatusRemarks,

           StatusTimeStamp,

           requestID

      FROM json_table( p_clob_result_status,

                       '$.value[*]' COLUMNS ( documentType     VARCHAR2(4000) path '$.documentType',

                                              invoiceID        VARCHAR2(4000) path '$.invoiceID' ,

                                              invoiceNo        VARCHAR2(4000) path '$.invoiceNo',

                                              invoiceType      VARCHAR2(4000) path '$.invoiceType',

                                              invoiceDate      VARCHAR2(4000) path '$.invoiceDate',

                                              vendorNo         VARCHAR2(4000) path '$.vendorNo',

                                              glDate           VARCHAR2(4000) path '$.gLDate',

                                              status           VARCHAR2(4000) path '$.status',

                                              StatusRemarks    VARCHAR2(4000) path '$.statusRemarks',

                                              StatusTimeStamp  VARCHAR2(4000) path '$.statusTimestamp',

                                              requestID        VARCHAR2(4000) path '$.requestID'));



  BEGIN



    print_log ('ajc_bc_certify_pkg.call_status (+)');



    v_api_status := ajc_bc_j_ws_utils_pkg.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                                 p_subentity => 'STATUS',

                                                 p_method => 'GET' );

    print_log ('v_api_status: ' || v_api_status);

    

    FOR cc IN c_companies LOOP



      print_log('BC Company Name: '||cc.bc_company_name);

      

      v_get_url := ajc_bc_j_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, cc.company_id ) || v_api_status

                   || '?$filter=requestID eq ' || gv_request_id

                   ; 

                    

      print_log ( 'v_get_url: ' || v_get_url );



      v_clob_result_status := ajc_bc_j_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );



     -- print_log ( 'v_clob_result_status: ' || v_clob_result_status );



      print_output ( 'Status: ' );

      print_output ( ' ' );



      FOR cs IN c_status ( v_clob_result_status ) LOOP



        IF ( cs.status != 'Success' ) THEN



          print_output ( 'documentType: ' || cs.documentType || 

                         ' | invoiceNo: ' || cs.invoiceNo || 

                         ' | invoiceType: ' || cs.invoiceType || 

                         ' | invoiceDate: ' || cs.invoiceDate || 

                         ' | vendorNo: ' || cs.vendorNo || 

                         ' | glDate: ' || cs.glDate || 

                         ' | status: ' || cs.status || 

                         ' | statusRemarks: ' || cs.statusRemarks

                       );



          print_output ( ' ' );



          -- Se actualiza la tabla custom con el status REJECTED

          UPDATE AJC_BC_INC_AP_CERTIFY_INVOICES 

             SET status = 'REJECTED',

                 error_message = cs.status||'-'||cs.statusRemarks,

                 last_update_date=SYSDATE,

                 request_id=gv_request_id

           WHERE request_id = cs.requestID--gv_request_id -- 20240927 se agrega cs.request_id para poder re-procesar facturas que quedaron SENT en ejecucion anterior porque fall� call_job

             AND invoice_id = cs.invoiceID;



          -- Se actualiza la tabla desde la cual se levantan los invoices a procesar, para que sean reprocesados en la proxima ejecuci�n

          -- UPDATE ajc_expense_rpt_int -- IMPLEMENTACION DEFINITIVA -- Descomentar

    /*      UPDATE ajc_BC_EXPENSE_RPT_INT -- IMPLEMENTACION TRANSITORIA -- Descomentar

             SET status = 'ERROR'

           WHERE invoice_number = cs.invoiceNo

             AND supplier_number = cs.vendorNo

             -- AND TRUNC(creation_date) = TRUNC(SYSDATE)

             AND nvl(status,'NEW') <> 'INTERFACED'

             ;*/



            delete_inv(cc.company_id,cs.invoiceID); 



        ELSE



          -- Se actualiza la tabla custom con el status SUCCESS

          UPDATE AJC_BC_INC_AP_CERTIFY_INVOICES

             SET status = 'SUCCESS',

             last_update_date=SYSDATE,

             error_message = NULL,

             request_id=gv_request_id

           WHERE request_id = cs.requestID--gv_request_id -- 20240927 se agrega cs.request_id para poder re-procesar facturas que quedaron SENT en ejecucion anterior porque fall� call_job

             AND invoice_id = cs.invoiceID;



        END IF;



      END LOOP;  



    END LOOP;



    -- 20241002 Si quedaron registros SENT significa que call status no pudo obtener estado de procesamiento. Asumo que no se procesaron. Los marco como REJECTED para que se re-procesen el la pr�xima ejecuci�n

    UPDATE AJC_BC_INC_AP_CERTIFY_INVOICES

    SET status='REJECTED',

        last_update_date=SYSDATE,

        error_message='Could not get processing status',

        request_id=gv_request_id

    WHERE status='SENT';

    --AND request_id=gv_request_id;

    

    p_status := 'S';



    print_log ('ajc_bc_certify_pkg.call_status (-)');   



  EXCEPTION

    WHEN OTHERS THEN

        v_error_message := 'Unhandled error when calling Status Web Service, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        

        -- 20241002 Si quedaron registros SENT significa que call status no pudo obtener estado de procesamiento. Asumo que no se procesaron. Los marco como REJECTED para que se re-procesen el la pr�xima ejecuci�n

        UPDATE AJC_BC_INC_AP_CERTIFY_INVOICES

        SET status='REJECTED',

            last_update_date=SYSDATE,

            error_message='Could not get processing status',

            request_id=gv_request_id

        WHERE status='SENT';

        --AND request_id=gv_request_id;

    

        print_log ('ajc_bc_certify_pkg.call_status (!)');



  END call_status;





  PROCEDURE final_report_p ( p_status   OUT   VARCHAR2 ) IS





      CURSOR c_processed_lines IS

        SELECT

            vendor_num,

            vendor_name,

            vendor_site_code,

            invoice_date,

         --   gl_date,

            invoice_num,

            invoice_type_lookup_code,

            invoice_currency_code currency_code,

            invoice_amount,

            b.description,

            b.line_number line_num,

            b.amount line_amount,

            dist_code_concatenated distr_account,

            b.attribute1 worksheet_number,

            to_char(sysdate,'DD-MON-YYYY HH12:MI:SS') rptdate,

            a.status status_inv,

            a.error_message err_msg_inv,

            b.error_message err_msg_lin

        FROM AJC_BC_INC_AP_CERTIFY_INVOICES a,

                AJC_BC_INC_AP_CERTIFY_LINES b

     WHERE a.request_id = gv_request_id

     AND a.invoice_id=b.invoice_id

   --  AND ( a.status IN ('ERROR','REJECTED') OR b.status IN ('ERROR','REJECTED'))

        ORDER by 1,6,11; 



  BEGIN



    print_log( 'ajc_bc_certify_pkg.final_report_p (+)' );



    -- Insert Report Title

    ajc_bc_j_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => gv_bc_ifc || ' Report',

                                        p_request_id => gv_request_id );

    ajc_bc_j_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Request ID|' || gv_request_id,

                                        p_request_id => gv_request_id ); 



    -- Fila vacia

    ajc_bc_j_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Tabla 1 -----------------------------------------------------------------------------------------------------------------                                    

    -- Insert Table Title

    ajc_bc_j_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Processed Invoice Lines',

                                        p_request_id => gv_request_id );



    -- Fila vacia

    ajc_bc_j_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Insert Table Column Names                            

    ajc_bc_j_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Vendor No.' || '|' ||

                                                  'Vendor Name' || '|' ||

                                                  'Vendor Site Code' || '|' ||

                                                  'Invoice Date' || '|' ||

                                              --    'Gl Date' || '|' ||

                                                  'Invoice Num' || '|' ||

                                                  'Invoice Type' || '|' ||

                                                  'Currency Code' || '|' ||

                                                  'Invoice Amount' || '|' ||

                                                  'Description' || '|' ||

                                                  'Line Num' || '|' ||

                                                  'Line Amount' || '|' ||

                                                  'Distr Account' || '|' ||

                                                  'Worksheet No' || '|' ||

                                                  'RptDate' || '|' ||

                                                  'Status Invoice' || '|' ||

                                                  'Error Message Invoice' || '|' ||

                                                  'Error Message Line',

                                        p_request_id => gv_request_id );  



    -- Se insertan los registros

    FOR ce IN c_processed_lines LOOP



      ajc_bc_j_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                          p_text => ce.vendor_num || '|' || 

                                                    ce.vendor_name || '|' || 

                                                    ce.vendor_site_code || '|' || 

                                                    ce.invoice_date || '|' || 

                                                   -- ce.gl_date || '|' || 

                                                    ce.invoice_num || '|' || 

                                                    ce.invoice_type_lookup_code || '|' || 

                                                    ce.currency_code || '|' || 

                                                    ce.invoice_amount || '|' || 

                                                    ce.description || '|' || 

                                                    ce.line_num || '|' || 

                                                    ce.line_amount || '|' || 

                                                    ce.distr_account || '|' || 

                                                    ce.worksheet_number || '|' || 

                                                    ce.rptdate || '|' || 

                                                    ce.status_inv || '|' || 

                                                    ce.err_msg_inv || '|' || 

                                                    ce.err_msg_lin,

                                          p_request_id => gv_request_id );  



    END LOOP;



    p_status := 'S';



    print_log( 'ajc_bc_certify_pkg.final_report_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajc_bc_certify_pkg.final_report_p (!). Error: ' || SQLERRM );



  END final_report_p;



  PROCEDURE final_report_xlsx_p ( p_status   OUT   VARCHAR2 ) IS



    c_processed   SYS_REFCURSOR;

    c_errors       SYS_REFCURSOR;



  BEGIN



    print_log( 'ajc_bc_certify_pkg.final_report_xlsx_p (+)' );



    gv_directory_report := ajc_bc_j_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJC_DIRECTORY_REPORT' );



    -- Solapa Report Information

    ajc_bc_j_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc || ' Report Information',

                                                                       p_request_id => gv_request_id,

                                                                       p_bc_environment => gv_bc_environment,

                                                                       p_jenkins_build_number => gv_jenkins_build_number,

                                                                       p_param_1_title => 'GL Date',

                                                                       p_param_1_value =>  TO_CHAR(NVL(gv_gl_date,TRUNC(SYSDATE)),'YYYY-MM-DD'));                 



    -- Solapa Processed Data

        OPEN c_processed FOR

        

        SELECT

            a.set_of_books_name bc_company,

            vendor_num,

            vendor_name,

            vendor_site_code,

            invoice_date,

          --  gl_date,

            invoice_num,

            invoice_type_lookup_code,

            invoice_currency_code currency_code,

            invoice_amount,

            b.description,

            b.line_number line_num,

            b.amount line_amount,

            dist_code_concatenated distr_account,

            b.attribute1 worksheet_number,

            to_char(sysdate,'DD-MON-YYYY HH12:MI:SS') rptdate,

            a.status status_inv,

            a.error_message err_msg_inv,

            b.error_message err_msg_lin

        FROM AJC_BC_INC_AP_CERTIFY_INVOICES a,

                AJC_BC_INC_AP_CERTIFY_LINES b

     WHERE a.request_id = gv_request_id

     AND a.invoice_id=b.invoice_id

  --   AND ( a.status IN ('ERROR','REJECTED') OR b.status IN ('ERROR','REJECTED'))

    UNION ALL

     SELECT 

            b.bc_company_name bc_company,

            supplier_number vendor_num,

            supplier_name vendor_name,

            supplier_site_code vendor_site_code,

            to_date(invoice_date,'dd-MON-yyyy'),

          --  gl_date,

            invoice_number invoice_num,

            invoice_type invoice_type_lookup_code,

            currency_code,

            invoice_amount,

            description,

            line_num,

            line_amount,

            distr_account,

            worksheet_number,

            to_char(sysdate,'DD-MON-YYYY HH12:MI:SS') rptdate,

            a.status status_inv,

            'Supplier not found in Oracle' err_msg_inv,

            NULL err_msg_lin                    

        FROM AJC_BC_INC_EXPENSE_RPT_INT a,

                    ajc_bc_companies b

        WHERE a.status='ERROR'

        AND SUBSTR(a.distr_account,1,2) = b.oracle_company_number

        ORDER by 1,2,6,11;         



    -- Processed Data

    ajc_bc_j_utils_pkg.create_sheet_p ( p_sheet_title => 'Processed Data',

                                                        p_sheet => 2,

                                                        p_cursor => c_processed );



    as_xlsx.save ( gv_directory_report, gv_report_filename || '.' || LOWER(gv_file_format) );



    p_status := 'S';



    print_log( 'ajc_bc_certify_pkg.final_report_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajc_bc_certify_pkg.final_report_xlsx_p (!). Error: ' || SQLERRM );



  END final_report_xlsx_p;

  -- ------------------------------------------------------------------------------------------------------------------------

  -- Main

  -- ------------------------------------------------------------------------------------------------------------------------

  PROCEDURE main_p ( p_bc_environment   IN   VARCHAR2,

                                p_gl_date   IN VARCHAR2,

                                p_jenkins_build_number   IN   VARCHAR2,

                                p_file_date   IN VARCHAR2) IS 



    v_email              VARCHAR2(2000);



    v_status             VARCHAR2(1);

    e_error              EXCEPTION;

    v_gl_date            DATE;

    v_invoice_count      NUMBER := 0;

    v_lines_count        NUMBER := 0;

    v_error_msg      VARCHAR2(2000);

    v_message            VARCHAR2(32000);



    -- 20230706

    v_execute_ftp_ldr    VARCHAR2(1);

    v_file_prefix        VARCHAR2(200);

    -- 20230706



    v_request_id_excel   NUMBER;

    e_parameter_value        EXCEPTION;

    

    -- 20240909

    v_continue              VARCHAR2(1);

    v_start                 DATE;

    v_elapsed_seconds       NUMBER;

    v_timeout_seconds       NUMBER := 2700; -- 45 minutos

    -- 20240909    



    -- 20250514

--    v_support_email          VARCHAR2(200);

    v_not_success         NUMBER;

    -- 20250514

    

  BEGIN



    print_log('ajc_bc_certify_pkg.main_p (+)');

    

    gv_jenkins_build_number := p_jenkins_build_number;

    gv_request_id := ajc_bc_j_utils_pkg.get_request_id_f;

    -- Se inserta el concurrent_job

    ajc_bc_j_utils_pkg.ins_jenkins_concurrent_job_p ( p_request_id => gv_request_id,

                                                     p_job_name => gv_bc_ifc,

                                                     p_jenkins_build_number => gv_jenkins_build_number,

                                                     p_argument1 => p_bc_environment );

                                                     

    print_log ( 'gv_request_id: ' || gv_request_id );                                                         



    gv_file_format :=ajc_bc_j_ws_utils_pkg.get_parameter_f ( 'FILE_FORMAT' );

    print_log( 'gv_file_format: ' || gv_file_format );

    

    gv_email := ajc_bc_j_utils_pkg.get_emails_f ( 'CERTIFY' );

    print_log( 'gv_email: ' || gv_email );

           

    gv_support_email := ajc_bc_j_utils_pkg.get_emails_f ( 'SUPPORT' );

    print_log( 'gv_support_email: ' || gv_support_email );    



    gv_process_name := ajc_bc_j_ws_utils_pkg.get_lock_process_name_f ( p_integration => 'PURCHASE INVOICES' );

    print_log( 'gv_process_name: ' || gv_process_name );



    -- Validacion parametro p_bc_environment -----------------------------------------------------------------------------------

    IF ( ajc_bc_j_utils_pkg.is_bc_environment_valid_f ( p_bc_environment ) = 'N' ) THEN



      v_error_msg := 'Invalid value (' || p_bc_environment || ') for parameter BC_ENVIRONMENT.';

      RAISE e_parameter_value;



    END IF;



    gv_bc_environment := p_bc_environment;

    print_log ( 'gv_bc_environment: ' || gv_bc_environment );

   

    -- Validacion parametro p_gl_date ------------------------------------------------------------------------------------------

    -- Validacion para cuando el parametro en jenkins es tipo date y llega como varchar2

    IF ( p_gl_date IS NOT NULL ) THEN 



      BEGIN



        gv_gl_date := TO_DATE(p_gl_date,'YYYY-MM-DD');



      EXCEPTION

        WHEN OTHERS THEN

          v_error_msg := 'Error: ' || SUBSTR(SQLERRM,INSTR(SQLERRM,':') + 2) || ' (' || p_gl_date || ')';

          RAISE e_parameter_value;



      END;



    END IF;



    print_log ( 'gv_gl_date: ' || gv_gl_date ); 

      

    print_log ( 'gv_file_name: ' || gv_file_name );    

       

    -- Se obtienen los parametros de la company 

    print_log ( 'gv_bc_company_name: ' || gv_bc_company_name );  



    gv_set_of_books_id := ajc_bc_j_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                                                                               p_column => 'SET_OF_BOOKS_ID' );

    print_log ( ' gv_set_of_books_id  : ' ||  gv_set_of_books_id   );



    gv_set_of_books_name := ajc_bc_j_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                                                                                     p_column => 'SET_OF_BOOKS_NAME' );       

    print_log ( ' gv_set_of_books_name  : ' ||  gv_set_of_books_name   );



    gv_bc_company_id := ajc_bc_j_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                                                                              p_column => 'BC_COMPANY_ID' );       

    print_log ( ' gv_bc_company_id  : ' ||  gv_bc_company_id   );



    --Sincronizo default dimensions para mapeo de segmentos

    --ajcl_bc_accounts_pkg.main_p ( p_bc_environment => p_bc_environment );

    ajc_bc_j_account_dim_pkg.main_p( p_bc_environment => p_bc_environment , 

                                                        p_request_id => gv_request_id);

    

    print_log ( 'ajc_bc_j_account_dim_pkg.main_p' );      

    

    -- 20230705

    -- ------------------------------------------------------------------------------------------------------------------------

    -- Transformaciones e Insert a tablas

    -- ------------------------------------------------------------------------------------------------------------------------

    expense_report_interface_p ( p_gl_date => v_gl_date,

                                 p_american_express_supplier => gv_american_express_supplier,

                                 p_travel_advance_account_num => gv_travel_advance_account_num,

                                 p_file_date => p_file_date,

                                 p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_error_msg := 'Process failed when trying to process Certify records. Please check email with attached log file. (expense_report_interface_p)';

      RAISE e_error;



    END IF;



    print_log (' '); 

    

      -- dbms_lock - Lock ------------------------------------------------------------------------------------------------------

      print_log ( 'Trying to lock ' || gv_process_name || '.' );

      print_log ( 'If it stops at this point it is because it is blocked by another integration. It will continue once the other integration releases.' );



      ajc_bc_dbms_lock_pkg.lock_p ( p_process_name => gv_process_name,

                                    p_id_lock => gv_id_lock,

                                    p_request_status => gv_request_status ); 



      IF ( gv_request_status != 'success' ) THEN



        v_error_msg := 'ajc_bc_dbms_lock_pkg.lock_p';

        RAISE ge_lock;



      END IF;

      -- dbms_lock - Lock ------------------------------------------------------------------------------------------------------

      

    -- WS para enviar la info a BC ---------------------------------------------------------------------------------------------

    call_ws ( p_status         => v_status

             ,p_invoice_count  => v_invoice_count

             ,p_lines_count    => v_lines_count

             ,p_bc_environment => p_bc_environment );



    IF ( v_status != 'S' ) THEN



      v_error_msg := 'Process failed when trying to send Certify invoices to BC. Please check email with attached log file. (call_ws)';

      RAISE e_error;



    END IF;



 --  DBMS_LOCK.sleep(15); -- lo agrego porque a veces ejecuta el job antes de la cabecera

   

    -- Si se envi� al menos un comprobante, se ejecuta el job

    IF ( v_invoice_count > 0 ) THEN



      print_log (' '); 

      -- Se ejecuta el JOB -----------------------------------------------------------------------------------------------------

      call_job ( p_status         => v_status

                ,p_error_message  => v_error_msg

                ,p_bc_environment => p_bc_environment );



      IF v_status != 'S' THEN



        IF v_status = 'W' THEN



         -- retcode := 1;

         -- errbuf  := v_error_message;

            NULL;

        ELSE

        

          -- si call_job termin� con error , llamo a call_status para que elimine los registros de la inbound purchase documents y los marque como REJECTED

            call_status ( p_status => v_status

               ,p_error_message => v_error_msg

               ,p_bc_environment => p_bc_environment );

                   

          v_error_msg := 'Process failed when calling BC import job. Please check email with attached log file. (call_job)';

          RAISE e_error;



        END IF;



      END IF;



      print_log ( 'v_lines_count: ' || v_lines_count );



          -- Se espera 1 segundo por cada linea procesada

          DBMS_LOCK.sleep(seconds => v_lines_count);-- / 2);

                

    END IF;



      print_log (' '); 

      print_log ('call_status');      

      

      -- Verifico el status de las lineas procesadas por el job ----------------------------------------------------------------

      call_status ( p_status => v_status

                   ,p_error_message => v_error_msg

                   ,p_bc_environment => p_bc_environment );



      IF v_status != 'S' THEN



        IF v_status = 'W' THEN



         -- retcode := 1;

        --  errbuf  := v_error_message;

                NULL;

        ELSE

            v_error_msg := 'Process failed when trying to get status of Certify incoices sent to BC. Please check email with attached log file. (call_status)';

          RAISE e_error;



        END IF;



      END IF;



    

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );



      IF ( gv_release_status != 'success' ) THEN



        v_error_msg := 'ajc_bc_dbms_lock_pkg.release_p';

        RAISE ge_release;



      END IF;                                     

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

    

      -- INSERT REPORT IN TABLE ajc_BC_REPORTS --------------------------------------------------------------------------------

      final_report_p ( p_status => v_status );     



      IF ( v_status != 'S' ) THEN



        v_error_msg := 'Error en final_report_p';

        RAISE e_error;



      END IF;  

      

      IF ( gv_file_format = 'CSV' ) THEN



          -- CREATE CSV FROM TABLE ajc_BC_REPORTS --------------------------------------------------------------------------------

          ajc_bc_j_utils_pkg.create_csv_p ( p_ifc => gv_bc_ifc,

                                           p_request_id => gv_request_id,

                                           p_log_seq => gv_log_seq,

                                           p_type => 'REPORT',

                                           p_filename => gv_report_filename,

                                           p_status => v_status );



          IF ( v_status != 'S' ) THEN



            v_error_msg := 'Error en create_csv_p | REPORT';

            RAISE e_error;



          END IF;

          

      ELSIF ( gv_file_format = 'XLSX' ) THEN 

              

            -- No inserta en tabla, genera el xlsx directamente en el filesystem

        final_report_xlsx_p ( p_status => v_status );     

                                                                             

        IF ( v_status != 'S' ) THEN

                

           v_error_msg := 'Process failed when trying to generate Certify process report. Please check email with attached log file. (final_report_xlsx_p)';

          RAISE e_error;

          

        END IF;  

          

      END IF;

      

      -- MAIL REPORT -----------------------------------------------------------------------------------------------------------

      BEGIN

          ajc_bc_j_utils_pkg.send_mail_with_attach ( p_to_mail => gv_email,

                                                    p_subject => gv_bc_ifc || ' Report - ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                                    p_body => gv_bc_ifc || ' Report.',

                                                    p_type => 'REPORT',

                                                    p_filename => gv_report_filename, 

                                                    p_file_format => gv_file_format,

                                                    p_attach_filename => gv_bc_ifc || ' Report ' || TO_CHAR(SYSDATE,'MMDDYYYY HH24MISS') || ' ' || gv_bc_environment || '.' || LOWER(gv_file_format) );                              

      EXCEPTION

        WHEN OTHERS THEN

            print_log('SMTP NOT WORKING.');

      END;

          

    -- 20230705

    -- BORRADO ARCHIVOS --------------------------------------------------------------------------------------------------------

      -- IMPLEMENTACION DEFINITIVA -- Descomentar

    --ajc_inc_del_expense_rpt_files ( p_status => v_status ); MB:REVISAR



   -- IF ( v_status != 'S' ) THEN



     -- RAISE e_error;



    --END IF;

    

    -- borro registros de tabla loader espejo, para emular TRUNCATE del ctl sobre la tabla principal y no queden registros de una ejecuci�n a otra. Comentar si la tabla espejo se vuelve tabla principal 

    --DELETE ajc_BC_EXPENSE_RPT_INT; MB: REVISAR



        -- 20250514

        -- Se agrega envio de mail para soporte, para informar que no se pudo importar todo en la ejecucion

        BEGIN

             

          SELECT COUNT(1)

               INTO v_not_success

             FROM   AJC_BC_INC_AP_CERTIFY_INVOICES a,

                        AJC_BC_INC_AP_CERTIFY_LINES b

            WHERE a.request_id = gv_request_id

            AND a.invoice_id=b.invoice_id

            AND ( a.status IN ('ERROR','REJECTED') OR b.status IN ('ERROR','REJECTED'));

             

          print_log ('v_not_success: ' || v_not_success);  

                 

          IF ( v_not_success > 0 ) THEN

             

             BEGIN

                ajc_bc_j_utils_pkg.send_email_p ( p_to => gv_support_email,

                                                                      p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - WARNING - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                                                      p_message => 'Some journals could not be imported. Please review the integration report.' || CHR(10) || 'Request ID: ' || gv_request_id );

            EXCEPTION

                WHEN OTHERS THEN

                    print_log('SMTP NOT WORKING.');

            END;          

            

          END IF;

           

        EXCEPTION

            WHEN OTHERS THEN

               NULL;

               

        END;

         -- 20250514

         

      -- Se actualiza el concurrent_job

    ajc_bc_j_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'S' );

    

    COMMIT;

     

    print_log('ajc_bc_certify_pkg.main_p (-)');



  EXCEPTION

      -- dbms_lock ---------------------------------------------------------------------------------------------------------------

    WHEN ge_lock THEN -- Lock and Release

      print_log ('ajc_bc_certify_pkg.main_p (!). Error attempting to lock the process ' || gv_process_name || 

              ' | request_status: ' || gv_request_status);

        

        BEGIN            

          ajc_bc_j_utils_pkg.send_email_p ( p_to => gv_support_email,

                                           p_subject =>  gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',   

                                           p_message => v_error_msg|| CHR(10) ||'Request Id: '||gv_request_id );

    

          ajc_bc_j_utils_pkg.send_log_by_mail_p(gv_request_id,gv_support_email);

        EXCEPTION

            WHEN OTHERS THEN

                print_log('SMTP NOT WORKING.');

        END;

        

      -- Se actualiza el concurrent_job

      ajc_bc_j_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );                                       



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );    

      

    WHEN ge_release THEN -- Lock and Release

      print_log ('ajc_bc_certify_pkg.main_p (!). Error attempting to release the process ' || gv_process_name || 

              ' | request_status: ' || gv_release_status);



        BEGIN              

          ajc_bc_j_utils_pkg.send_email_p ( p_to => gv_support_email,

                                           p_subject =>  gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',   

                                           p_message => v_error_msg|| CHR(10) ||'Request Id: '||gv_request_id );

    

          ajc_bc_j_utils_pkg.send_log_by_mail_p(gv_request_id,gv_support_email);

        EXCEPTION

            WHEN OTHERS THEN

                print_log('SMTP NOT WORKING.');

        END;

        

      -- Se actualiza el concurrent_job

      ajc_bc_j_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );                                       



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );    

                    

    -- dbms_lock ---------------------------------------------------------------------------------------------------------------

    

    WHEN e_parameter_value THEN

      print_log('ajc_bc_certify_pkg.main_p (!)');

      print_log('Parameter Value Error!');

      print_log(v_error_msg);

        BEGIN

          ajc_bc_j_utils_pkg.send_email_p ( p_to => gv_support_email,

                                           p_subject =>  gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',   

                                           p_message => v_error_msg|| CHR(10) ||'Request Id: '||gv_request_id );

    

          ajc_bc_j_utils_pkg.send_log_by_mail_p(gv_request_id,gv_support_email);

        EXCEPTION

            WHEN OTHERS THEN

                print_log('SMTP NOT WORKING.');

        END;

      -- Se actualiza el concurrent_job

      ajc_bc_j_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );              

 

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------                                         



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg ); 

                  

    WHEN e_error THEN

      print_log('ajc_bc_certify_pkg.main_p (!)');

      print_log('Error e_error!');

      

        BEGIN

          ajc_bc_j_utils_pkg.send_email_p ( p_to => gv_support_email,

                                           p_subject =>  gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',   

                                           p_message => v_error_msg || CHR(10) ||'Request Id: '||gv_request_id);

    

          ajc_bc_j_utils_pkg.send_log_by_mail_p(gv_request_id,gv_support_email);

        EXCEPTION

        WHEN OTHERS THEN

                print_log('SMTP NOT WORKING.');

        END;

        

          -- Se actualiza el concurrent_job

      ajc_bc_j_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------     

                                     

      RAISE_APPLICATION_ERROR(-20000,'General Error: ' || SQLERRM );   

    WHEN others  THEN

      print_log('ajc_bc_certify_pkg.main_p (!)');

      print_log('Error others!');

      

      BEGIN

          ajc_bc_j_utils_pkg.send_email_p ( p_to => gv_support_email,

                                           p_subject =>  gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',   

                                           p_message => v_error_msg || CHR(10) ||'Request Id: '||gv_request_id);

    

          ajc_bc_j_utils_pkg.send_log_by_mail_p(gv_request_id,gv_support_email);

      EXCEPTION

            WHEN OTHERS THEN

                print_log('SMTP NOT WORKING.');

        END;

        

          -- Se actualiza el concurrent_job

      ajc_bc_j_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------     

                                     

      RAISE_APPLICATION_ERROR(-20000,'General Error: ' || SQLERRM );         

  END main_p;



END ajc_bc_j_certify_pkg;

