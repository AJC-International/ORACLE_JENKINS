PACKAGE BODY              ajc_bc_inc_certify_pkg AS
  
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

    fnd_file.put_line (fnd_file.log, p_message);

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

    fnd_file.put_line(fnd_file.output,p_message);

  END print_output;

  /*=========================================================================+
  |                                                                          |
  | Private Procedure                                                        |
  |    send_email                                                            |
  |                                                                          |
  | Description                                                              |
  |    Envio de reporte por mail                                             |
  |                                                                          |
  | Parameters                                                               |
  |                                                                          |
  +=========================================================================*/

  PROCEDURE send_email ( p_request_id_excel   IN   NUMBER,
                         p_mail               IN   VARCHAR2 ) IS

    v_rejected_count   NUMBER;
    v_success_count    NUMBER;

    -- v_to               VARCHAR2(2000) := 'sbanchieri@gmail.com';
    v_subject          VARCHAR2(2000) := 'AJC BC INC Certify Interface - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS');
    v_message          VARCHAR2(2000);


  BEGIN

    print_log ('ajc_bc_inc_certify_pkg.send_email (+)');

    -- Se obtiene la cantidad de comprobantes SUCCESS   
    SELECT COUNT(1)
      INTO v_success_count
      FROM AJC_BC_INC_AP_CERTIFY_INVOICES
     WHERE request_id = gv_request_id
       AND status = 'SUCCESS';

    print_log ( 'SUCCESS: ' || v_success_count );

    -- Se obtiene la cantidad de comprobantes REJECTED
    SELECT COUNT(1)
      INTO v_rejected_count
      FROM AJC_BC_INC_AP_CERTIFY_INVOICES
     WHERE request_id = gv_request_id
       AND status IN ('REJECTED','ERROR');

    print_log ( 'REJECTED: ' || v_rejected_count );

    v_message := 'Comprobantes procesados con éxito: ' || v_success_count || CHR(13) || CHR(10);
    v_message := v_message || 'Comprobantes rechazados: ' || v_rejected_count || CHR(13) || CHR(10) || CHR(13) || CHR(10);
    v_message := v_message || 'Para mayor detalle, revise el output del request ' || p_request_id_excel || '.';

    print_log ( 'To: ' || p_mail );
    print_log ( 'Subject: ' || v_subject );
    print_log ( 'Message: ' || v_message );

    ajc_bc_ws_utils_pkg.send_email ( p_to => p_mail
                                    ,p_subject => v_subject
                                    ,p_message => v_message );

    print_log ('ajc_bc_inc_certify_pkg.send_email (-)');    

  EXCEPTION
    WHEN others THEN
      print_log ( 'ajc_bc_inc_certify_pkg.send_email (!)' );  
      print_log ( 'Error: ' || SQLERRM );

  END send_email;

  -- ------------------------------------------------------------------------------------------------------------------------
  -- AJC INC Ftp Expense Report File
  -- ------------------------------------------------------------------------------------------------------------------------
  PROCEDURE ajc_inc_ftp_expense_rpt ( p_file_prefix   IN   VARCHAR2,
                                      p_status       OUT   VARCHAR2 ) IS

    v_request_id        NUMBER;
    v_message           VARCHAR2(2000);
    v_error_message     VARCHAR2(2000);
    e_cust_exception    EXCEPTION;
    v_conc_phase        VARCHAR2 (50);
    v_conc_status       VARCHAR2 (50);
    v_conc_dev_phase    VARCHAR2 (50);
    v_conc_dev_status   VARCHAR2 (50);
    v_conc_message      VARCHAR2 (250);

  BEGIN

    print_log('ajc_inc_ftp_expense_rpt (+)');

    v_request_id := fnd_request.submit_request ( 'XXAJC'
                                                ,'AJC_INC_FTP_EXPENSE_RPT'
                                                ,argument1 => p_file_prefix ) ;

    IF v_request_id = 0 THEN

      v_message := fnd_message.get;
      print_log('Error Ejecutando FND_REQUEST.SUBMIT_REQUEST. AJC_INC_FTP_EXPENSE_RPT. Error: ' || v_message || ', ' || SQLERRM);
      RAISE e_cust_exception;

    END IF ;

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
      print_log('Error Ejecutando FND_REQUEST.WAIT_FOR_REQUEST. AJC_INC_FTP_EXPENSE_RPT con nro. solicitud ' || 
                TO_CHAR (v_request_id) || '. Error: ' || v_message || ' ' || SQLERRM);
      RAISE e_cust_exception;

    END IF ;

    IF v_conc_dev_phase != 'COMPLETE' OR v_conc_dev_status != 'NORMAL' THEN

      v_error_message := fnd_message.get;
      print_log('Error en la ejecucion del concurrente AJC_INC_FTP_EXPENSE_RPT con nro. solicitud ' || 
                TO_CHAR (v_request_id) || '. Error: ' || v_error_message || ' ' || SQLERRM);
      RAISE e_cust_exception;

    END IF ; 

    p_status := 'S';

    print_log('ajc_inc_ftp_expense_rpt (-)');

  EXCEPTION
    WHEN e_cust_exception THEN
      print_log('ajc_inc_ftp_expense_rpt (!)');
      p_status := 'E';

  END ajc_inc_ftp_expense_rpt;

  -- ------------------------------------------------------------------------------------------------------------------------
  -- AJC INC Load Expense Report Data
  -- ------------------------------------------------------------------------------------------------------------------------
  PROCEDURE ajc_inc_load_expense_rpt_int ( p_file_name   IN   VARCHAR2,
                                           p_status     OUT   VARCHAR2 ) IS

    v_request_id        NUMBER;
    v_message           VARCHAR2(2000);
    v_error_message     VARCHAR2(2000);
    e_cust_exception    EXCEPTION;
    v_conc_phase        VARCHAR2 (50);
    v_conc_status       VARCHAR2 (50);
    v_conc_dev_phase    VARCHAR2 (50);
    v_conc_dev_status   VARCHAR2 (50);
    v_conc_message      VARCHAR2 (250);

  BEGIN

    print_log('ajc_inc_load_expense_rpt_int (+)');

    v_request_id := fnd_request.submit_request ( 'XXAJC'
                                                ,'AJC_INC_LOAD_EXPENSE_RPT_INT'
                                                ,argument1 => p_file_name ) ;                                               

    IF v_request_id = 0 THEN

      v_message := fnd_message.get;
      print_log('Error Ejecutando FND_REQUEST.SUBMIT_REQUEST. AJC_INC_LOAD_EXPENSE_RPT_INT. Error: ' || 
                 v_message || ', ' || SQLERRM);
      RAISE e_cust_exception;

    END IF ;

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
      print_log('Error Ejecutando FND_REQUEST.WAIT_FOR_REQUEST. AJC_INC_LOAD_EXPENSE_RPT_INT con nro. solicitud ' || 
                 TO_CHAR (v_request_id) || '. Error: ' || v_message || ' ' || SQLERRM);
      RAISE e_cust_exception;

    END IF ;

    IF v_conc_dev_phase != 'COMPLETE' OR v_conc_dev_status NOT IN ('NORMAL','WARNING') THEN

      v_error_message := fnd_message.get;
      print_log('Error en la ejecucion del concurrente AJC_INC_LOAD_EXPENSE_RPT_INT con nro. solicitud ' || 
                 TO_CHAR (v_request_id) || '. Error: ' || v_error_message || ' ' || SQLERRM);
      RAISE e_cust_exception;

    END IF ;  

    p_status := 'S';

    print_log('ajc_inc_load_expense_rpt_int (-)');

  EXCEPTION
    WHEN e_cust_exception THEN
      print_log('ajc_inc_load_expense_rpt_int (!)');
      p_status := 'E';  

  END ajc_inc_load_expense_rpt_int;

  -- ------------------------------------------------------------------------------------------------------------------------
  -- AJC INC Expense Report Interface
  -- ------------------------------------------------------------------------------------------------------------------------
  PROCEDURE expense_report_interface_p ( p_gl_date                       IN   DATE,
                                         p_american_express_supplier     IN   VARCHAR2,
                                         p_travel_advance_account_num    IN   VARCHAR2,
                                         p_status                       OUT   VARCHAR2 ) IS

    user_id_p 			                  NUMBER	:= FND_PROFILE.VALUE('USER_ID');

    -- constants
    -- source_c			 ap_invoices_interface.source%TYPE := 'EXPENSE REPORT';
    source_c			 ap_invoices_interface.source%TYPE := 'CERTIFY';
    amex_c				  varchar2(4) := 'AMEX';
    true_c				  varchar2(4) := 'TRUE';
    advance_c			varchar2(7) := 'ADVANCE';

    -- variables
    invoice_number_v		    ajc_inc_expense_rpt_int.invoice_number%TYPE;
    oracle_invoice_num_v		ap_invoices_all.invoice_num%TYPE;
    supplier_number_v	   	ajc_inc_expense_rpt_int.supplier_number%TYPE;	
    invoice_date_v			     ajc_inc_expense_rpt_int.invoice_date%TYPE;
    supplier_site_code_v		ajc_inc_expense_rpt_int.supplier_site_code%TYPE;
    supplier_name_v			    ajc_inc_expense_rpt_int.supplier_name%TYPE;
    invoice_amount_v		    ajc_inc_expense_rpt_int.invoice_amount%TYPE;
    description_v			      ajc_inc_expense_rpt_int.description%TYPE;
    invoice_type_v			     ajc_inc_expense_rpt_int.invoice_type%TYPE;
    currency_code_v			    ajc_inc_expense_rpt_int.currency_code%TYPE;
    gl_date_from_int_v		  ajc_inc_expense_rpt_int.gl_date%TYPE;
    inv_id_v        		    number;
    inv_line_id_v   		    number;
    error_code_v    		    number;
    error_text_v    		    varchar2(200);
    terms_id_v			         po_vendor_sites.terms_id%TYPE;
    terms_name_v          ap_terms_tl.name%TYPE; 
    payment_method_lookup_code_v	  po_vendor_sites.payment_method_lookup_code%TYPE;
    pay_group_lookup_code_v		      po_vendor_sites.pay_group_lookup_code%TYPE;
    gl_date_v			          date;
    liab_code_concat_v		  ap_invoices_interface.accts_pay_code_concatenated%TYPE := null; 
    base_currency_code_v		ap_system_parameters.base_currency_code%TYPE;
    company_v			          fnd_flex_values.flex_value%TYPE := null;
    org_id_v			           ap_invoices_interface.org_id%TYPE	:= null; 
    resp_id_v			          number	:= null;
    rec_cnt_v			          number := 0;
    stmt_v				            number;
    prog_failed_v			      boolean;
    employee_number_v		   ajc_inc_expense_rpt_int.supplier_number%TYPE;	
    employee_site_code_v		ajc_inc_expense_rpt_int.supplier_site_code%TYPE;
    employee_name_v			    ajc_inc_expense_rpt_int.supplier_name%TYPE;
    reimburse_flag_v	    	ajc_inc_expense_rpt_int.reimburse_flag%TYPE;
    amex_supplier_num_v	 	po_vendors.segment1%TYPE;
    line_num_v			         number;
    distr_account_v 		    ap_invoices_interface.accts_pay_code_concatenated%TYPE; 
    travel_adv_distr_account_v 	 ap_invoices_interface.accts_pay_code_concatenated%TYPE; 
    distr_acct_num_v 		   gl_code_combinations.segment1%TYPE;
    dept_override_v 		    gl_code_combinations.segment1%TYPE;

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
    e_no_invoices_found		   EXCEPTION;

      CURSOR Select_Inv IS 
      SELECT invoice_number, 
             supplier_number, 
             supplier_name, 
             decode(reimburse_flag, advance_c, true_c ,reimburse_flag) reimburse_flag
        -- FROM AJC_INC_EXPENSE_RPT_INT -- IMPLEMENTACION DEFINITIVA -- Descomentar
        FROM AJC_BC_INC_EXPENSE_RPT_INT -- IMPLEMENTACION TRANSITORIA -- Descomentar
       WHERE nvl(status,'NEW') <> 'INTERFACED'
         -- AND oracle_supplier_num = '100218'
    GROUP BY invoice_number, 
             supplier_number, 
             supplier_name, 
             decode(reimburse_flag, advance_c, true_c ,reimburse_flag);

    CURSOR Select_Inv_Line IS
    SELECT *
      -- FROM AJC_INC_EXPENSE_RPT_INT -- IMPLEMENTACION DEFINITIVA -- Descomentar
      FROM AJC_BC_INC_EXPENSE_RPT_INT -- IMPLEMENTACION TRANSITORIA -- Descomentar
     WHERE nvl(supplier_number,'XXXXX') = nvl(employee_number_v,'XXXXX')
       AND nvl(supplier_name,'XXXXX') = nvl(employee_name_v,'XXXXX')
       AND decode(reimburse_flag, advance_c , true_c, reimburse_flag) = reimburse_flag_v
       AND invoice_number = invoice_number_v;

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
            ,v_vendor_id
            ,v_vendor_name
             -- SB
        FROM po_vendors
       WHERE vendor_id = p_american_express_supplier;

      print_log('amex_supplier_num_v: ' || amex_supplier_num_v);
      print_log('v_vendor_id: ' || v_vendor_id);
      print_log('v_vendor_name: ' || v_vendor_name);

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        print_log('amex_supplier_num_v NOT FOUND.');

    END;

    FOR inv_rec in Select_Inv LOOP

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
      resp_id_v := NULL;
      liab_code_concat_v := NULL;
      -- SB
      v_vendor_site_id := NULL;
      --
      v_set_of_books_id := NULL;
      v_set_of_books_name := NULL;
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

       SELECT attribute1, 
              attribute5,
              -- SB
              bcc.set_of_books_id,
              bcc.set_of_books_name
              -- SB
         INTO org_id_v, 
              resp_id_v,
              -- SB
              v_set_of_books_id,
              v_set_of_books_name
              -- SB
         FROM FND_FLEX_VALUES,
              ajc_bc_companies bcc
        WHERE enabled_flag = 'Y' 
          AND flex_value_set_id = ( SELECT flex_value_set_id FROM fnd_flex_value_sets WHERE flex_value_set_name = 'AJC COMPANY' )
          AND flex_value = company_v
          -- SB
          AND flex_value = bcc.oracle_company_number
          AND attribute1 = bcc.org_id;
          --

      Exception
        When NO_DATA_FOUND then
          print_log ( 'Org and responsibility not defined in Oracle for Company: ' || company_v);

          -- 20241104
          -- La company es nueva en BC, no existe en Oracle, solo debe existir en ajc_bc_companies
          SELECT org_id,
                 ap_resp_id,
                 set_of_books_id,
                 set_of_books_name
            INTO org_id_v, 
                 resp_id_v,
                 v_set_of_books_id,
                 v_set_of_books_name
            FROM ajc_bc_companies bcc
           WHERE bcc.oracle_company_number = company_v;
          -- 20241104

        When OTHERS then
          null;

      End;

      print_log ( 'org_id_v: ' || org_id_v );
      print_log ( 'resp_id_v: ' || resp_id_v );
      print_log ( 'v_set_of_books_id: ' || v_set_of_books_id );
      print_log ( 'v_set_of_books_name: ' || v_set_of_books_name );

      IF org_id_v IS NULL THEN

        print_log ( 'Org not defined for Company: '||company_v);

      END IF;

      IF resp_id_v IS NULL THEN

        print_log ( 'Responsibility not defined for Company: '||company_v);

      END IF;

      stmt_v := 30;	

      IF ( org_id_v IS NOT NULL ) THEN 	

        -- Get the default liability account combination for the org
        Begin

          SELECT gcc.segment1||'.'||gcc.segment2||'.'||gcc.segment3||'.'||gcc.segment4||'.'||gcc.segment5||'.'||gcc.segment6||'.'||gcc.segment7, 
                 -- 20250310
                 -- asp.base_currency_code,
                 DECODE(asp.base_currency_code,'MEX','MXN',
                                               asp.base_currency_code),
                 -- 20250310
                 -- SB
                 gcc.code_combination_id,
                 -- ltrim(gcc.segment1,'0') company,
                 gcc.segment1 company,
                 aba.bc_account account,
                 aba.description account_description,
                 gcc.segment3 department,
                 DECODE(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT4'
                                                                            ,p_oracle_value   => gcc.segment4
                                                                            ,p_bc_dimension   => 'DIVISION'), NULL,gcc.segment4,'000') product,
                 DECODE(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT5'
                                                                            ,p_oracle_value   => gcc.segment5
                                                                            ,p_bc_dimension   => 'OFFICE'), NULL,gcc.segment5,'000') destination,
                 NVL(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT5'
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
                 v_destination,
                 v_office,
                 v_origin,
                 v_intercompany
                 -- SB
            FROM gl_code_combinations gcc, 
                 ap_system_parameters_all asp,
                 ajc.ajc_bc_accounts aba
           WHERE gcc.code_combination_id = asp.accts_pay_code_combination_id
             AND asp.org_id = org_id_v
             AND gcc.segment2 = aba.oracle_account (+); 

        Exception
          WHEN OTHERS THEN

            -- 20241104
            -- La company no existe en Oracle, se obtienen los datos de ajc_bc_companies
            IF ( org_id_v = -1 ) THEN

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

        End;

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

        print_log ( 'Org is null - Unable to retrieve the liability account combination for the invoice');

      END IF;

      stmt_v := 40;	
      -- For AMEX reimburseable expense reports the supplier will be the American Express supplier number 
      -- The supplier site code ALTERNATE for the American Express supplier will be the employee supplier number from the expense report file.

      IF inv_rec.reimburse_flag = amex_c THEN

        supplier_number_v := amex_supplier_num_v;
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
            print_log ( 'Supplier not found in Oracle for supplier number: '||supplier_number_v);
          When OTHERS then 
            null;

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
          WHEN NO_DATA_FOUND TH
