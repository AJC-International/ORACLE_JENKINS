PACKAGE BODY              ajcl_bc_j_trv_tpay_pkg AS

  -- 20260406 REINTENTO
  gv_retry_in_seconds   NUMBER;
  gv_retry              VARCHAR2(1);
  -- 20260406 REINTENTO
    
  -- Parameters
 gv_file_name VARCHAR2(100):= 'data/TPAY_TRV/AJCL_TRV_TPAY_INVOICES.csv';
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
  -- AJCL TRV Ftp Triumph Pay File
  -- ------------------------------------------------------------------------------------------------------------------------
  PROCEDURE ajcl_trv_ftp_tpay_file ( p_file_prefix   IN   VARCHAR2,
                                      p_status       OUT   VARCHAR2 ) IS

    v_request_id        NUMBER;
    v_message           VARCHAR2(2000);
    v_error_msg     VARCHAR2(2000);
    e_cust_exception    EXCEPTION;
    v_phase        VARCHAR2 (200);
    v_status       VARCHAR2 (1);
    v_argument1              VARCHAR2(100);

  BEGIN

    print_log('ajcl_ftp_trv_tpay_file (+)');

    -- Se obtiene nuevo request_id para poder registrar la ejecucion del ftp
    v_request_id := ajcl_bc_utils_pkg.get_request_id_f;
    -- Se inserta el concurrent_job
    ajcl_bc_utils_pkg.ins_jenkins_concurrent_job_p ( p_request_id => v_request_id,
                                                     p_job_name => gv_bc_ifc_ftp,--'AJCL BC TRV Triumph Pay FTP',
                                                     p_jenkins_build_number => gv_jenkins_build_number,
                                                     p_argument1 => p_file_prefix );
                                                
    print_log ( 'Run job AJCL_TRV_FTP_TPAY_FILE' );
   -- v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJCL_BC_TRV_FTP_TPAY_FILE';
    v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_BC_TRV_TPAY_FTP' );
    print_log ( 'v_argument1: ' || v_argument1 );

    ajc_bc_scheduler_pkg.create_run_wait_job_p ( p_job_name => 'AJCL_BC_TRV_FTP_TPAY_FILE',
                                                 p_comments => gv_bc_ifc_ftp,--'AJCL BC TRV Triumph Pay FTP',
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
      
    print_log('ajcl_ftp_trv_tpay_file (-)');

  EXCEPTION
    WHEN e_cust_exception THEN
      print_log('ajcl_ftp_trv_tpay_file (!)');
      p_status := 'E';
            -- Se actualiza el concurrent_job
      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => v_request_id, p_status => 'E' );       

  END ajcl_trv_ftp_tpay_file;

  -- ------------------------------------------------------------------------------------------------------------------------
  -- AJCL TRV Triumph Pay Validate Data
    --
    -- Validation and exception processing
    -- a. Verify Vendor Keys from data file are mapped to an Oracle Supplier
    -- If a vendor key has not been mapped to an Oracle supplier the request set will stop processing and display a message in the exceptions report. 
    -- The user can re-run the process after entering the missing vendor in the cross reference table.
    --
    -- b. Verify the invoice number provided by Triumph Pay doesn?t already exist for the supplier. 
    -- If the invoice number already exists in Oracle for the supplier then the invoice will be skipped and reported on the exceptions report.
    --
    -- c. Worksheet number is missing ? the value NA will be used and the invoice will be reported on the exceptions report
    --

    -- 11/3 - SHOULD THE RECORDS MISSING WORKSHEET NUMBERS BE LISTED IN REPORT???  
  -- ------------------------------------------------------------------------------------------------------------------------
  PROCEDURE ajcl_trv_validate_tpay_data ( p_status     OUT   VARCHAR2 ) IS

v_num_errors             number := 0;
prog_failed_v            boolean;
End_In_Error            exception;         

  BEGIN
  
    print_log('ajcl_trv_validate_tpay_data (+)');

    print_log('Map the Vendor key to the oracle supplier and set the status');
    
    UPDATE AJCL_BC_TRV_TPAY_INV_INT t
    SET oracle_vendor_id = ( SELECT oracle_vendor_id
                                        FROM   AJCL_BC_CUST_XREF --AJC_BPLUS_CUST_XREF 
                                        WHERE  source = 'TRV'
                                        AND    source_type = 'VENDOR'  
                                        AND bp_cust_id = t.vendor_key
                                        AND bc_environment = gv_bc_environment),
        status = 'NEW',
        last_updated_by = gv_user_id,
        last_update_date = sysdate,
        oracle_vendor_site_id = NULL -- Added KHRONUS/MB 20241204: to enable Vendor and Site re-mapping
    WHERE NVL(STATUS,'NEW') in ('NEW', 'ERROR');
    --AND oracle_vendor_id is null;

    print_log('Identify records in ERROR');
    
    UPDATE AJCL_BC_TRV_TPAY_INV_INT
    set status='ERROR',
        last_updated_by = gv_user_id,
        last_update_date = sysdate
    WHERE oracle_vendor_id is null;

    print_log('reset the status to NEW if the vendor site has been defined since the prior execution');
    
    UPDATE AJCL_BC_TRV_TPAY_INV_INT t
    SET oracle_vendor_site_id = (SELECT vendor_site_id
                FROM po_vendor_sites_all vs
                WHERE org_id = gv_org_id
                AND vendor_id = t.oracle_vendor_id
                AND vendor_site_code='TRIUMPH'),
        status='NEW',
        last_updated_by = gv_user_id,
        last_update_date = sysdate
    WHERE nvl(status, 'NEW') IN ('NEW','ERROR')
    AND oracle_vendor_id is not null
    AND oracle_vendor_site_id is null
    AND EXISTS (SELECT 'X'
            FROM po_vendor_sites_all vs
            WHERE org_id = gv_org_id
            AND vendor_id = t.oracle_vendor_id
            AND vendor_site_code='TRIUMPH');

    print_log('Identify records in ERROR');
    
    UPDATE AJCL_BC_TRV_TPAY_INV_INT t
    SET status='ERROR',
        last_updated_by = gv_user_id,
        last_update_date = sysdate
    WHERE nvl(status, 'NEW') = 'NEW' 
    AND oracle_vendor_id is not null
    AND oracle_vendor_site_id is null
    AND NOT EXISTS (SELECT 'X'
            FROM po_vendor_sites_all vs
            WHERE org_id = gv_org_id
            AND vendor_id = t.oracle_vendor_id
            AND vendor_site_code='TRIUMPH');

-- check if TRV ws has been created previously , if not --> ERROR
    UPDATE AJCL_BC_TRV_TPAY_INV_INT t
    SET status='ERROR',
           last_updated_by = gv_user_id,
           last_update_date = sysdate
    WHERE nvl(status, 'NEW') IN ('NEW','ERROR')
    AND oracle_vendor_id is not null
    AND oracle_vendor_site_id is not null
    AND NOT EXISTS (SELECT 'X'
                                FROM 
                                    (SELECT ws_ies_num 
                                         FROM ajc_worksheet_ies_num 
                                    UNION
                                    SELECT ws_ies_num
                                        FROM  ajcl_bc_worksheets 
                                    WHERE bc_environment=gv_bc_environment
                                        AND status='SUCCESS'
                                        )
                                    WHERE ws_ies_num LIKE 'TRV'||t.broker_reference_num||'%');
                                    
-- following case should be rejected by BC
/*
    print_log('Identify records in WARNING');
    
    UPDATE AJCL_BC_TRV_TPAY_INV_INT t
    SET status='WARNING'
    WHERE nvl(status, 'NEW') = 'NEW' 
    AND oracle_vendor_id is not null
    AND oracle_vendor_site_id is not null
    AND EXISTS (SELECT 'X' 
            FROM  ap_invoices_all ai
            WHERE ai.org_id = gv_org_id 
            AND ai.vendor_id = t.oracle_vendor_id
            AND ai.vendor_site_id = t.oracle_vendor_site_id
            AND ai.invoice_num = t.carrier_invoice_num);
*/                        
     COMMIT;

    BEGIN

        SELECT count(*)
        INTO v_num_errors
        FROM AJCL_BC_TRV_TPAY_INV_INT
        WHERE status='ERROR';

        IF v_num_errors > 0 THEN
            RAISE End_In_Error;
        END IF;  
    END;
         
     p_status:='S';
     print_log('ajcl_trv_validate_tpay_data (-)');
  EXCEPTION
        WHEN OTHERS THEN
            p_status := 'E';
            print_log('Error al mapear oracle_vendor_id y oracle_vendor_site_id - SQLERRM: '||SQLERRM);
            print_log('ajcl_trv_validate_tpay_data (!)');
  END ajcl_trv_validate_tpay_data;


  -- ------------------------------------------------------------------------------------------------------------------------
  -- AJCL TRV Load Triumph Pay Data
  -- ------------------------------------------------------------------------------------------------------------------------
  PROCEDURE ajcl_trv_load_tpay_data ( p_file_name   IN   VARCHAR2,
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

    print_log('ajcl_load_trv_tpay_data (+)');

    -- Se obtiene nuevo request_id para poder registrar la ejecucion del ftp
    v_request_id := ajcl_bc_utils_pkg.get_request_id_f;
    -- Se inserta el concurrent_job
    ajcl_bc_utils_pkg.ins_jenkins_concurrent_job_p ( p_request_id => v_request_id,
                                                     p_job_name => gv_bc_ifc_loader,--'AJCL BC TRV Triumph Pay Loader',
                                                     p_jenkins_build_number => gv_jenkins_build_number,
                                                     p_argument1 => p_file_name );                           

    print_log ( 'Run job AJCL_TRV_LOAD_TPAY_INV_INT' );
    --v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJCL_EXECUTE_CTL.sh';
    v_argument1 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_EXECUTE_CTL' );
    print_log ( 'v_argument1: ' || v_argument1 );
    --v_argument2 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJCL_TRV_LOAD_TPAY_INV_INT';
    v_argument2 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || ajcl_bc_utils_pkg.get_executable_file_name_f ( 'AJCL_BC_TRV_TPAY_LOADER' );
    print_log ( 'v_argument2: ' || v_argument2 );
    v_argument3 := ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || p_file_name; 
    print_log ( 'v_argument3: ' || v_argument3 );    

    ajc_bc_scheduler_pkg.create_run_wait_job_p ( p_job_name => 'AJCL_TRV_LOAD_TPAY_INV_INT',
                                                 p_comments => 'AJCL BC TRV Triumph Pay Loader',
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

      v_phase := 'AJCL BC TRV Triumph Pay Loader';
      print_log( 'v_status: '||v_status );
      print_log ( 'v_error_msg: '|| v_error_msg );
      RAISE e_cust_exception;

    END IF;                                                 

    p_status := 'S';

      -- Se actualiza el concurrent_job
      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => v_request_id, p_status => 'S' );       

    print_log('ajcl_load_trv_tpay_data (-)');

  EXCEPTION
    WHEN e_cust_exception THEN
      print_log('ajcl_load_trv_tpay_data (!)');
      p_status := 'E';  
      -- Se actualiza el concurrent_job
      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => v_request_id, p_status => 'E' ); 
  END ajcl_trv_load_tpay_data;

  -- ------------------------------------------------------------------------------------------------------------------------
  -- AJCL TRV Triumph Pay Interface
  -- ------------------------------------------------------------------------------------------------------------------------
  PROCEDURE ajcl_trv_tpay_interface ( p_status                       OUT   VARCHAR2 ) IS


    -- constants
    source_c			 ap_invoices_interface.source%TYPE := 'TRIUMPH PAY';
    distr_account_c        AP_INVOICE_LINES_INTERFACE.dist_code_concatenated%TYPE := '53.2215.000.000.000.000.00'; --MB: REVISAR
    line_type_c        AP_INVOICE_LINES_INTERFACE.line_type_lookup_code%TYPE := 'ITEM';


    -- variables
    inv_id_v                number;
    inv_line_id_v           number;
    error_code_v            number;
    error_text_v            varchar2(200);
    terms_id_v            PO_VENDOR_SITES_ALL.terms_id%TYPE;
    payment_method_lookup_code_v    PO_VENDOR_SITES_ALL.payment_method_lookup_code%TYPE;
    pay_group_lookup_code_v        PO_VENDOR_SITES_ALL.pay_group_lookup_code%TYPE;
    gl_date_v            date;
    liab_code_concat_v        AP_INVOICES_INTERFACE.accts_pay_code_concatenated%TYPE := null; 
    base_currency_code_v        AP_SYSTEM_PARAMETERS.base_currency_code%TYPE;
    vendor_site_code_v        PO_VENDOR_SITES_ALL.vendor_site_code%TYPE;
    vendor_num_v            PO_VENDORS.segment1%TYPE;
    rec_cnt_v            number := 0;
    stmt_v                number;
    prog_failed_v            boolean;
    invoice_type_v            AP_INVOICES_INTERFACE.invoice_type_lookup_code%TYPE;
    NO_INVOICES_FOUND        exception;
    -- Modified KHRONUS/PBonadeo 20230921: Changed logic to calculate worksheet number
    v_worksheet_number    VARCHAR2(50);
    -- End Modified KHRONUS/PBonadeo 20230921: Changed logic to calculate worksheet number
    distr_account_v             ap_invoices_interface.accts_pay_code_concatenated%TYPE;     
    distr_acct_num_v            gl_code_combinations.segment1%TYPE;    

    -- MB
    v_vendor_id           po_vendors.vendor_id%TYPE;
    v_vendor_name         po_vendors.vendor_name%TYPE;
    v_vendor_site_id      po_vendor_sites_all.vendor_site_id%TYPE;
    terms_name_v          ap_terms_tl.name%TYPE; 
    --
    v_dist_code_combination VARCHAR2(500);
    v_company               VARCHAR2(10);
    v_account               VARCHAR2(20);
    v_account_description   VARCHAR2(240);
    v_department            VARCHAR2(10);
    v_product               VARCHAR2(10);
    v_division              VARCHAR2(10);
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
    e_no_invoices_found		   EXCEPTION;
    e_no_ora_vendor_found           EXCEPTION;

    Cursor Select_Inv is 
    SELECT *
    --FROM AJCL_TRV_TPAY_INV_INT
    FROM AJCL_BC_TRV_TPAY_INV_INT
    WHERE nvl(status,'NEW') = 'NEW';
   -- WHERE nvl(status,'NEW') <> 'INTERFACED';
    

  BEGIN

    print_log('ajcl_trv_tpay_interface (+)');

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

        -- reemplazo segmento company por default
        v_company := SUBSTR(distr_account_c,1,2);
        
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

      BEGIN -- Added KHRONUS/MB 20241202: Exception handler for avoid sending invoices to BC with missing data
        print_log( 'Invoice: '||inv_rec.carrier_invoice_num);
        print_log( 'Vendor Key: '||inv_rec.vendor_key);

        -- Initialize variables
        gl_date_v                 := null;
        terms_id_v                := null;
        pay_group_lookup_code_v    := null;
        payment_method_lookup_code_v     := 'WIRE'; -- Hardcodeo definido por MCESARIO 20240706
        vendor_site_code_v        := NULL;
        vendor_num_v            := NULL;
        invoice_type_v            := NULL;

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


        stmt_v := 10;

        -- Find the terms_id and pay group from vendor site
        Begin
            SELECT vs.terms_id, vs.pay_group_lookup_code, --vs.payment_method_lookup_code, -- Se hardcodea WIRE -  definido por MCESARIO 20240706
            vs.vendor_site_code, v.segment1, v.vendor_id, v.vendor_name
            INTO terms_id_v, pay_group_lookup_code_v, --payment_method_lookup_code_v,
                vendor_site_code_v, vendor_num_v, v_vendor_id, v_vendor_name
            FROM po_vendor_sites_all vs , po_vendors v 
            WHERE vs.org_id = gv_org_id 
            AND v.vendor_id = vs.vendor_id
            AND vs.vendor_site_id = inv_rec.oracle_vendor_site_id
            AND v.vendor_id = inv_rec.oracle_vendor_id;
        Exception
            When NO_DATA_FOUND then
                    print_log ('Supplier Site: '||vendor_site_code_v||
                                    ' Not found in Oracle for Supplier: '||vendor_num_v);
                    raise e_no_ora_vendor_found;
            When OTHERS then null;
                    raise e_no_ora_vendor_found;
        End;


        v_worksheet_number:= 'TRV'||inv_rec.broker_reference_num;
        
        print_log('v_worksheet_number: '||v_worksheet_number);
        
        -- Modified KHRONUS/PBonadeo 20230921: Changed logic to calculate worksheet number
        BEGIN
        
            select ws_ies_num
            into v_worksheet_number
            from -- Modified KHRONUS/MB 20241031 : Changed logic to check in 2 tables to get ws created before and after BC migration
                (select ws_ies_num 
                     from ajc_worksheet_ies_num 
                UNION
                select ws_ies_num
                    from  ajcl_bc_worksheets 
                where bc_environment=gv_bc_environment
                    and status='SUCCESS')
             where ws_ies_num like 'TRV'||inv_rec.broker_reference_num||'%';
                       
        EXCEPTION
            WHEN OTHERS THEN
                v_worksheet_number :=inv_rec.broker_reference_num;
                print_log( 'BrokerReferenceNum: '||inv_rec.broker_reference_num||' Not found in ajc_worksheet_ies_num . Error: '||sqlerrm);
        END;
        -- End Modified KHRONUS/PBonadeo 20230921: Changed logic to calculate worksheet number    

        -- Determine the gl date
            --gl_date_v := inv_rec.payment_date;--KHRONUS/MBetti 20240731 - Se definió utilizar SYSDATE por default, a menos que venga predefinido por el parametro gv_gl_date
            gl_date_v := NVL(gv_gl_date,TRUNC(SYSDATE));


        -- 03/05/21
        IF inv_rec.net_amount > 0 THEN
            invoice_type_v := 'STANDARD';
        ELSE
            invoice_type_v := 'CREDIT';
        END IF;   

      SELECT ap_invoices_interface_s.nextval
       	INTO inv_id_v
       	FROM dual;
        
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

      -- Create Invoice Header Record

      INSERT 
        INTO AJCL_BC_AP_TRV_TPAY_INVOICES 
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
             request_id )
    VALUES ( inv_id_v,
             inv_rec.carrier_invoice_num,
             invoice_type_v,
             inv_rec.payment_date,
             vendor_num_v, 
             v_vendor_id, 
             v_vendor_name, 
             vendor_site_code_v,
             inv_rec.oracle_vendor_site_id, 
             inv_rec.net_amount,
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
             base_currency_code_v,
             inv_rec.tpay_payment_id,
             payment_method_lookup_code_v, 
             pay_group_lookup_code_v,
             -- inv_rec.invoice_image_url,
             'NEW',
             gv_request_id );
                     

      -- Create Invoice Lines

        distr_account_v := null;
        distr_acct_num_v := null;

        distr_acct_num_v := substr(distr_account_c,4,4);

        print_log ( 'distr_acct_num_v: ' || distr_acct_num_v ); 

        distr_account_v := distr_account_c;

        print_log ( 'distr_account_v: ' || distr_account_v ); 

        v_l_segment1 := SUBSTR(distr_account_v,1,2);
        v_l_segment2 := SUBSTR(distr_account_v,4,4);
        v_l_segment3 := SUBSTR(distr_account_v,9,3);
        v_l_segment4 := SUBSTR(distr_account_v,13,3);
        v_l_seg
