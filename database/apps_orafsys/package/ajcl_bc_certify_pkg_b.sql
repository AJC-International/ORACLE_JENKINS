PACKAGE BODY              ajcl_bc_certify_pkg AS

  -- Setear en N cuando se usan los triggers de PROD a FINUPG5/FINUPG6
  -- Setear en Y cuando se necesite cargar la data de files / tables
  gv_ftp_loader        VARCHAR2(1) := 'N'; -- se resuelve mas abajo segun la db
  
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
  -- AJC Ftp Expense Report File
  -- ------------------------------------------------------------------------------------------------------------------------
  PROCEDURE ajcl_ftp_expense_rpt ( p_file_prefix   IN   VARCHAR2,
                                      p_status       OUT   VARCHAR2 ) IS

    v_request_id        NUMBER;
    v_message           VARCHAR2(2000);
    v_error_msg     VARCHAR2(2000);
    e_cust_exception    EXCEPTION;
    v_phase        VARCHAR2 (200);
    v_status       VARCHAR2 (1);
    v_argument1              VARCHAR2(100);

  BEGIN

    print_log('ajcl_ftp_expense_rpt (+)');

    -- Se obtiene nuevo request_id para poder registrar la ejecucion del ftp
    v_request_id := ajcl_bc_utils_pkg.get_request_id_f;
    -- Se inserta el concurrent_job
    ajcl_bc_utils_pkg.ins_jenkins_concurrent_job_p ( p_request_id => v_request_id,
                                                     p_job_name => gv_bc_ifc_ftp ,--'AJCL BC Certify FTP',
                                                     p_jenkins_build_number => gv_jenkins_build_number,
                                                     p_argument1 => p_file_prefix );
                                                
    print_log ( 'Run job AJCL_BC_FTP_EXPENSE_RPT' );
    --v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJCL_BC_FTP_EXPENSE_RPT';
    v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_BC_CERTIFY_FTP' );
    print_log ( 'v_argument1: ' || v_argument1 );

    ajc_bc_scheduler_pkg.create_run_wait_job_p ( p_job_name => 'AJCL_BC_FTP_EXPENSE_RPT',
                                                 p_comments => gv_bc_ifc_ftp,
                                                 p_number_of_arguments => 2,
                                                 p_argument1 => v_argument1,
                                                 p_argument2 => p_file_prefix,
                                                 --
                                                 p_bc_ifc => gv_bc_ifc,
                                                 p_request_id => gv_request_id,
                                                 p_log_seq => gv_log_seq,
                                                 --
                                                 p_status => v_status,
                                                 p_error_msg => v_error_msg );

    IF ( v_status != 'S' OR v_error_msg IS NOT NULL ) THEN

      v_phase := gv_bc_ifc_ftp;
      print_log ( v_error_msg );
      RAISE e_cust_exception;

    END IF;                                                 

    p_status := 'S';

      -- Se actualiza el concurrent_job
      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => v_request_id, p_status => 'S' );       
      
    print_log('ajcl_ftp_expense_rpt (-)');

  EXCEPTION
    WHEN e_cust_exception THEN
      print_log('ajcl_ftp_expense_rpt (!)');
      p_status := 'E';
            -- Se actualiza el concurrent_job
      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => v_request_id, p_status => 'E' );       

  END ajcl_ftp_expense_rpt;

  -- ------------------------------------------------------------------------------------------------------------------------
  -- AJC Load Expense Report Data
  -- ------------------------------------------------------------------------------------------------------------------------
  PROCEDURE ajcl_load_expense_rpt_int ( p_file_name   IN   VARCHAR2,
                                           p_status     OUT   VARCHAR2 ) IS

    v_request_id        NUMBER;
    v_message           VARCHAR2(2000);
    v_error_msg     VARCHAR2(2000);
    e_cust_exception    EXCEPTION;
    v_phase        VARCHAR2 (200);
    v_status       VARCHAR2 (10);
    v_argument1              VARCHAR2(100);
    v_argument2              VARCHAR2(100);    
    v_argument3              VARCHAR2(100);    

  BEGIN

    print_log('ajcl_load_expense_rpt_int (+)');

    -- Se obtiene nuevo request_id para poder registrar la ejecucion del ftp
    v_request_id := ajcl_bc_utils_pkg.get_request_id_f;
    -- Se inserta el concurrent_job
    ajcl_bc_utils_pkg.ins_jenkins_concurrent_job_p ( p_request_id => v_request_id,
                                                     p_job_name => gv_bc_ifc_loader,--'AJCL BC Certify Loader',
                                                     p_jenkins_build_number => gv_jenkins_build_number,
                                                     p_argument1 => p_file_name );                           

    print_log ( 'Run job AJC_LOAD_EXPENSE_RPT_INT' );
    --v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJCL_EXECUTE_CTL.sh';
    v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_EXECUTE_CTL' );    
    print_log ( 'v_argument1: ' || v_argument1 );
    --v_argument2 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJC_LOAD_EXPENSE_RPT_INT';
    v_argument2 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_BC_CERTIFY_LOADER' );    
    print_log ( 'v_argument2: ' || v_argument2 );
    v_argument3 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || p_file_name; 
    print_log ( 'v_argument3: ' || v_argument3 );    

    ajc_bc_scheduler_pkg.create_run_wait_job_p ( p_job_name => 'AJC_LOAD_EXPENSE_RPT_INT',
                                                 p_comments => 'AJCL BC Certify Loader',
                                                 p_number_of_arguments => 3,
                                                 p_argument1 => v_argument1,
                                                 p_argument2 => v_argument2,
                                                 p_argument3 => v_argument3,
                                                 --
                                                 p_bc_ifc => gv_bc_ifc,
                                                 p_request_id => gv_request_id,
                                                 p_log_seq => gv_log_seq,
                                                 --
                                                 p_status => v_status,
                                                 p_error_msg => v_error_msg );
     
    print_log('After ajc_bc_scheduler_pkg.create_run_wait_job_p. v_status: '||v_status);                                

    IF ( v_status != 'S' ) THEN

      v_phase := 'AJCL BC Certify Loader';
      print_log( 'v_status: '||v_status );
      print_log ( 'v_error_msg: '|| v_error_msg );
      RAISE e_cust_exception;

    END IF;                                                 

    p_status := 'S';

      -- Se actualiza el concurrent_job
      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => v_request_id, p_status => 'S' );       

    print_log('ajcl_load_expense_rpt_int (-)');

  EXCEPTION
    WHEN e_cust_exception THEN
      print_log('ajcl_load_expense_rpt_int (!)');
      p_status := 'E';  
      -- Se actualiza el concurrent_job
      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => v_request_id, p_status => 'E' ); 
  END ajcl_load_expense_rpt_int;

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
    v_t_division                  VARCHAR2(10);    
    v_t_destination              VARCHAR2(10);
    v_t_office                   VARCHAR2(10);
    v_t_origin                   VARCHAR2(10);
    v_t_intercompany             VARCHAR2(10);
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
      v_t_division := NULL;      
      v_t_destination := NULL;
      v_t_office := NULL;
      v_t_origin := NULL;
      v_t_intercompany := NULL;
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
            upper(invoice_type), currency_code, to_date(gl_date,'MM/DD/YYYY'),substr(distr_account,1,2)
        INTO invoice_date_v, supplier_site_code_v,  invoice_amount_v, description_v,
            invoice_type_v, currency_code_v, gl_date_from_int_v, v_company
        FROM AJCL_BC_EXPENSE_RPT_INT
        WHERE nvl(supplier_number,'XXXXX') = nvl(inv_rec.supplier_number,'XXXXX')
        AND   nvl(supplier_name,'XXXXX') = nvl(inv_rec.supplier_name,'XXXXX')
        AND invoice_number = inv_rec.invoice_number
        AND nvl(status,'NEW') <> 'INTERFACED'
        AND rownum =1;

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
             dist_code_comb
