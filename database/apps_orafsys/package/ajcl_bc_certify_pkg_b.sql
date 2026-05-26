CREATE OR REPLACE PACKAGE BODY              ajcl_bc_certify_pkg AS



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

      FROM AJCL_BC_AP_CERTIFY_INVOICES 

     WHERE 1=1--request_id = gv_request_id -- Se comenta para que pueda reprocesar facturas rechazadas de ejecuciones anteriores

       AND status IN ('NEW','ERROR','REJECTED')

       AND UPPER(NVL(error_message,'-')) NOT LIKE '%PURCHASE INVOICE%ALREADY EXISTS FOR THIS VENDOR%' --excluyo las facturas que ya existen en BC para que no siga reprocesandolas infinitamente

      AND vendor_num IS NOT NULL; -- puede venir null en el archivo, no se debe procesar 



      CURSOR c_invoice_lines ( pc_invoice_id   IN   NUMBER ) IS

      SELECT *

        FROM AJCL_BC_AP_CERTIFY_LINES 

       WHERE 1=1--request_id = gv_request_id -- Se comenta para que pueda reprocesar facturas rechazadas de ejecuciones anteriores

         AND invoice_id = pc_invoice_id

       --  AND status = 'NEW'

    ORDER BY line_number;



    v_company_id           VARCHAR2(100);

    v_status               VARCHAR2(2000);      



    v_url_header           VARCHAR2(2000);      

    v_body_header          VARCHAR2(2000);

    v_clob_result_header   CLOB;



    v_url_line             VARCHAR2(2000);

    v_body_line            VARCHAR2(2000);

    v_clob_result_line     CLOB;



    v_linea_con_error      VARCHAR2(1);

    v_clob_result_job      CLOB;



    v_error_message        VARCHAR2(1000);



  --  v_period_name          gl_periods.period_name%TYPE;

    v_message              VARCHAR2(32000);



  BEGIN



    print_log('ajcl_bc_certify_pkg.call_ws (+)');



    FOR cinv IN c_invoices LOOP



      print_log(' ');

      print_log('invoice_num: ' || cinv.invoice_num);



      -- Se obtiene el v_company_id

      ajc_bc_ws_utils_pkg.get_bc_company_id_f ( p_org_id => NULL,

                                                p_company_number => cinv.company,

                                                p_set_of_books_id  => NULL,

                                                p_bc_company_id => v_company_id,

                                                p_status => v_status );



      print_log('v_company_id: ' || v_company_id);



    --  v_url_header := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, v_company_id ) || v_api_header;

      v_url_header := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => p_bc_environment,

                                                    p_entity => 'PURCHASE INVOICES',

                                                    p_subentity => 'HEADERS',

                                                    p_method => 'POST',

                                                    p_company_id => v_company_id );

                                                    

      print_log('v_url_header: ' || v_url_header);



  --    v_url_line := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, v_company_id ) || v_api_line;

      

      v_url_line := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => p_bc_environment,

                                                    p_entity => 'PURCHASE INVOICES',

                                                    p_subentity => 'LINES',

                                                    p_method => 'POST',

                                                    p_company_id => v_company_id );

      

      print_log('v_url_line: ' || v_url_line);



      v_linea_con_error := 'N';



      -- Se envian las líneas

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

         -- APEX_JSON.write('requestID', TO_CHAR(cinv.request_id));

          APEX_JSON.write('requestID', TO_CHAR(gv_request_id));

          APEX_JSON.write('lineNo', clin.line_number);

          APEX_JSON.write('amount', clin.amount);

          -- 20230518 No se envia mas valor porque da error y se esta enviando el dato en accountDescription

          -- APEX_JSON.write('description', clin.description, TRUE);

          APEX_JSON.write('description', '', TRUE);

          --  --KHRONUS/MBetti 20240731 - Se definió utilizar parametro gv_gl_date , y si es null --> SYSDATE

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



          APEX_JSON.write('company',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,clin.account,'COMPANY',clin.company),TRUE);        



          APEX_JSON.write('account', clin.account); 



          APEX_JSON.write('accountDescription', clin.description, TRUE); -- Se envia la descripcion de la linea en Oracle



          APEX_JSON.write('department',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,clin.account,'DEPARTMENT',clin.department),TRUE);   



          APEX_JSON.write('product',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,clin.account,'PRODUCT',clin.product),TRUE);   

          

          -- Modificado KHRONUS/PBonadeo 20240722: Se envia el valor correspondiente a division en la dimension de intercompany ya que en BC sigue mapeado al shorcutDim7

          APEX_JSON.write('intercompany',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,clin.account,'DIVISION',clin.division),TRUE);    

          -- Fin Modificado KHRONUS/PBonadeo 20240722: Se envia el valor correspondiente a division en la dimension de intercompany ya que en BC sigue mapeado al shorcutDim7         

         

          -- 20221205 NO SE DEBE ENVIAR MAS APEX_JSON.write('intercompany', clin.intercompany);         



          APEX_JSON.write('destination',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,clin.account,'DESTINATION',clin.destination),TRUE);   



          APEX_JSON.write('office',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,clin.account,'OFFICE',clin.office),TRUE);   



          APEX_JSON.write('origin',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,clin.account,'ORIGIN',clin.origin),TRUE); 



          APEX_JSON.write('pdfFileUrl',clin.pdf_file_url, TRUE);



          APEX_JSON.close_object;



          v_body_line := APEX_JSON.get_clob_output;



          print_log('v_body_line: ' || v_body_line);                          



          v_clob_result_line := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url_line,

                                                                          p_request_header_name1 => 'Content-Type',

                                                                          p_request_header_value1 => 'application/json',

                                                                          p_request_header_name2 => NULL,

                                                                          p_request_header_value2 => NULL, 

                                                                          p_http_method => 'POST',

                                                                          p_body => v_body_line );  



          print_log('v_clob_result_line: ' || v_clob_result_line);



          APEX_JSON.free_output;



          IF ( INSTR(v_clob_result_line,'error') != 0 ) OR (v_clob_result_line IS NULL) THEN



            print_log('Error al enviar la línea del comprobante.');



            IF v_clob_result_line IS NULL THEN

                v_error_message :=  'Could not get result after sending the invoice line to BC';

            ELSE

                v_error_message := 'Error when sending invoice line to BC: ' ||

                                SUBSTR(v_clob_result_line,INSTR(v_clob_result_line,'message') + 10);

            END IF;

            

            print_log(v_error_message);



            UPDATE AJCL_BC_AP_CERTIFY_LINES

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



            UPDATE AJCL_BC_AP_CERTIFY_LINES

               SET status = 'SENT',

                    error_message=NULL,

                   json_data = v_body_line,

                   json_data_response = v_clob_result_line,

                   request_id = gv_request_id

             WHERE invoice_id = cinv.invoice_id

               AND line_number = clin.line_number;

             --  AND request_id = gv_request_id; -- Se comenta para que pueda reprocesar facturas rechazadas de ejecuciones anteriores



            print_log('La línea se envió correctamente.');



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

        --APEX_JSON.write('gLDate', TO_CHAR(cinv.gl_date,'YYYY-MM-DD')); --KHRONUS/MBetti 20240731 - Se definió utilizar parametro gv_gl_date , y si es null --> SYSDATE

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



        APEX_JSON.write('company',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,cinv.account,'COMPANY',cinv.company),TRUE);    



        APEX_JSON.write('account', cinv.account, TRUE ); 

        APEX_JSON.write('accountDescription', cinv.account_description, TRUE);



        APEX_JSON.write('department',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,cinv.account,'DEPARTMENT',cinv.department),TRUE); 



        APEX_JSON.write('product',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,cinv.account,'PRODUCT',cinv.product),TRUE);

        

          -- MB: REVISAR - DESCOMENTAR cuando esté disponible el campo division en la API

         -- APEX_JSON.write('division',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,cinv.account,'DIVISION',cinv.division),TRUE);            



        APEX_JSON.write('destination',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,cinv.account,'DESTINATION',cinv.destination),TRUE);



        APEX_JSON.write('origin',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,cinv.account,'ORIGIN',cinv.origin),TRUE);



        -- 20221205 NO SE DEBE ENVIAR MAS APEX_JSON.write('intercompany', cinv.intercompany, TRUE);

        -- Se debe enviar a nivel linea 

        -- APEX_JSON.write('pdfFileUrl',cinv.pdf_file_url, TRUE);

        --

        APEX_JSON.write('source', cinv.source, TRUE);



        APEX_JSON.write('office',ajcl_bc_accounts_pkg.account_dim_required(gv_bc_environment,cinv.account,'OFFICE',cinv.office),TRUE); 



        APEX_JSON.close_object;

        v_body_header := APEX_JSON.get_clob_output;



        print_log(' ');

        print_log('v_body_header: ' || v_body_header);



        v_clob_result_header := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url_header,

                                                                          p_request_header_name1 => 'Content-Type',

                                                                          p_request_header_value1 => 'application/json',

                                                                          p_request_header_name2 => NULL,

                                                                          p_request_header_value2 => NULL, 

                                                                          p_http_method => 'POST',

                                                                          p_body => v_body_header );  





        print_log('v_clob_result_header: ' || v_clob_result_header);



        APEX_JSON.free_output;



        IF ( INSTR(v_clob_result_header,'error') != 0 ) OR (v_clob_result_header IS NULL) THEN



          print_log('Error al enviar la cabecera del comprobante.');



          IF v_clob_result_header IS NULL THEN

            v_error_message :=  'Could not get result after sending the invoice header to BC';

          ELSE

            v_error_message := 'Error when sending invoice header to BC: ' ||

                              SUBSTR(v_clob_result_header,INSTR(v_clob_result_header,'message') + 10);

          END IF;

          

          print_log(v_error_message);



          UPDATE AJCL_BC_AP_CERTIFY_INVOICES

             SET status = 'ERROR',

                 error_message = v_error_message,

                 json_data = v_body_header,

                 json_data_response = v_clob_result_header,

                 request_id = gv_request_id,

                 last_update_date=SYSDATE

           WHERE invoice_id = cinv.invoice_id;

            -- AND request_id = gv_request_id;-- Se comenta para que pueda reprocesar facturas rechazadas de ejecuciones anteriores



        ELSE



          UPDATE AJCL_BC_AP_CERTIFY_INVOICES

             SET status = 'SENT',

                 json_data = v_body_header,

                 json_data_response = v_clob_result_header,

                 request_id = gv_request_id,

                 last_update_date=SYSDATE,

                 error_message = NULL

           WHERE invoice_id = cinv.invoice_id;

            -- AND request_id = gv_request_id;-- Se comenta para que pueda reprocesar facturas rechazadas de ejecuciones anteriores



          print_log('El comprobante se envió correctamente.');



        END IF;



        p_invoice_count := NVL(p_invoice_count,0) + 1;



      ELSE



        UPDATE AJCL_BC_AP_CERTIFY_INVOICES

           SET status = 'ERROR',

               error_message = 'Se produjo un error en alguna línea del comprobante.',

               request_id = gv_request_id,

               last_update_date=SYSDATE

         WHERE invoice_id = cinv.invoice_id;

          -- AND request_id = gv_request_id;-- Se comenta para que pueda reprocesar facturas rechazadas de ejecuciones anteriores



      END IF;



    END LOOP;



    p_status := 'S';



    print_log('ajcl_bc_certify_pkg.call_ws (-)');



  EXCEPTION

    WHEN OTHERS THEN

      print_log('ajcl_bc_certify_pkg.call_ws (!)');

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

      FROM AJCL_BC_AP_CERTIFY_INVOICES abci,

           ajc_BC_COMPANIES abcc

     WHERE abci.status = 'SENT'

    --  AND abci.request_id = gv_request_id -- 20240927 se comenta request_id para poder re-procesar facturas que quedaron SENT en ejecucion anterior porque falló call_job

       AND abci.company = abcc.oracle_company_number;



    v_job_object_id     NUMBER;

    v_status            VARCHAR2(20);

    v_error_message     VARCHAR2(2000);

    v_clob_result_job   CLOB;

    v_status_gral VARCHAR2(20):='SUCCESS';



  BEGIN



    print_log ('ajcl_bc_certify_pkg.call_job (+)');



    FOR cc IN c_companies LOOP



      print_log ( 'company_id: ' || cc.company_id );



      v_job_object_id := ajcl_bc_ws_utils_pkg.get_object_id_f ( 'PURCHASE INVOICES' );

      print_log ( 'v_job_object_id: ' || v_job_object_id );





      v_clob_result_job := ajcl_bc_ws_utils_pkg.run_job_queue_f ( p_bc_environment => p_bc_environment

                                                                ,p_company_id => cc.company_id

                                                                ,p_object_id => v_job_object_id );



      print_log('v_clob_result_job: '||v_clob_result_job);

      

      IF ( INSTR(UPPER(v_clob_result_job),'ERROR') > 0 ) THEN



        print_log ( 'Se produjo un error al ejecutar el job Purchase Document.');

        v_status := 'ERROR';



      ELSE



        print_log ( 'Se ejecutó el job Purchase Document con éxito.');

        v_status := 'SUCCESS';



      END IF;



      -- Se inserta registro de control

      INSERT

        INTO AJCL_BC_AP_CERTIFY_CONTROL

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



        IF v_status = 'ERROR' THEN -- si al menos un job falla, marco como falla general

            v_status_gral := 'ERROR';

        END IF;

        

    END LOOP;



    IF v_status_gral = 'ERROR' THEN

        p_status := 'E';

    ELSE    

        p_status := 'S';

    END IF;

    

    print_log ('ajcl_bc_certify_pkg.call_job (-)');   



  EXCEPTION

    WHEN others THEN

        v_error_message := 'Error no atrapado al llamar Web Service de Job, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('ajcl_bc_certify_pkg.call_job (!)');



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

    SELECT DISTINCT abcc.bc_company_id company_id, abci.request_id-- 20240927 se agrega request_id para poder re-procesar facturas que quedaron SENT en ejecucion anterior porque falló call_job

      FROM AJCL_BC_AP_CERTIFY_INVOICES abci,

           ajc_BC_COMPANIES abcc

     WHERE abci.status = 'SENT'

      -- AND abci.request_id = gv_request_id-- 20240927 se comenta request_id para poder re-procesar facturas que quedaron SENT en ejecucion anterior porque falló call_job

       AND abci.company = abcc.oracle_company_number;



    v_status               VARCHAR2(1);

    v_error_message        VARCHAR2(2000);

    v_get_url              VARCHAR2(2000);

    v_clob_result_status   CLOB;

    v_header_delete_url    VARCHAR2(2000);

    v_lines_delete_url     VARCHAR2(2000);

    v_header_delete_clob   CLOB;

    v_lines_delete_clob    CLOB;



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



    print_log ('ajcl_bc_certify_pkg.call_status (+)');



    FOR cc IN c_companies LOOP



--      v_get_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, cc.company_id ) || v_api_status

--                   || '?$filter=requestID eq ' || gv_request_id

--                   ; 

      v_get_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => p_bc_environment,

                                                    p_entity => 'PURCHASE INVOICES',

                                                    p_subentity => 'STATUS',

                                                    p_method => 'GET',

                                                    p_company_id => cc.company_id ) || '?$filter=requestID eq ' || cc.request_id;--gv_request_id;-- 20240927 se agrega cc.request_id para poder re-procesar facturas que quedaron SENT en ejecucion anterior porque falló call_job

                                                    

      print_log ( 'v_get_url: ' || v_get_url );



      v_clob_result_status := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );



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

          UPDATE AJCL_BC_AP_CERTIFY_INVOICES 

             SET status = 'REJECTED',

                 error_message = cs.status||'-'||cs.statusRemarks,

                 last_update_date=SYSDATE,

                 request_id=gv_request_id

           WHERE request_id = cs.requestID--gv_request_id -- 20240927 se agrega cs.request_id para poder re-procesar facturas que quedaron SENT en ejecucion anterior porque falló call_job

             AND invoice_id = cs.invoiceID;



          -- Se actualiza la tabla desde la cual se levantan los invoices a procesar, para que sean reprocesados en la proxima ejecución

          -- UPDATE ajc_expense_rpt_int -- IMPLEMENTACION DEFINITIVA -- Descomentar

    /*      UPDATE AJCL_BC_EXPENSE_RPT_INT -- IMPLEMENTACION TRANSITORIA -- Descomentar

             SET status = 'ERROR'

           WHERE invoice_number = cs.invoiceNo

             AND supplier_number = cs.vendorNo

             -- AND TRUNC(creation_date) = TRUNC(SYSDATE)

             AND nvl(status,'NEW') <> 'INTERFACED'

             ;*/



          -- Se arma la URL para borrar lineas de la tabla staging

--          v_lines_delete_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, cc.company_id ) || v_api_delete_lines

--                                -- || '?$filter=requestID eq ' || gv_request_id

--                                || '(''' || cs.invoiceID || ''',0,0)' -- invoice id, request id, line no

--                                ; 

                                

          v_lines_delete_url :=ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => p_bc_environment,

                                                    p_entity => 'PURCHASE INVOICES',

                                                    p_subentity => 'LINES',

                                                    p_method => 'DELETE',

                                                    p_company_id => cc.company_id ) || '(''' || cs.invoiceID || ''',0,0)'; -- invoice id, request id, line no

                                                    

          print_log ( 'v_lines_delete_url: ' || v_lines_delete_url );



          -- Se borran las lineas de la tabla staging

          v_lines_delete_clob := ajcl_bc_ws_utils_pkg.delete_bc_row_f ( p_url => v_lines_delete_url );



          IF ( INSTR(v_lines_delete_clob,'error') != 0 )  THEN



            print_log('Error al borrar lineas de la tabla stage de BC');

            print_log(v_lines_delete_clob);



          ELSE



            print_log('Lineas borradas de la tabla stage de BC');



          END IF;  



          -- Se arma la URL para borrar cabecera de la tabla staging

--          v_header_delete_url := ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, cc.company_id ) || v_api_delete_header

--                                 -- || '?$filter=requestID eq ' || gv_request_id

--                                 || '(''' || cs.invoiceID || ''',0)' -- invoice id, request id

--                                 ; 

          v_header_delete_url :=ajcl_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment => p_bc_environment,

                                                    p_entity => 'PURCHASE INVOICES',

                                                    p_subentity => 'HEADERS',

                                                    p_method => 'DELETE',

                                                    p_company_id => cc.company_id ) || '(''' || cs.invoiceID || ''',0)'; -- invoice id, request id



          print_log ( 'v_header_delete_url: ' || v_header_delete_url );



          -- Se borra la cabecera de la tabla staging

          v_header_delete_clob := ajcl_bc_ws_utils_pkg.delete_bc_row_f ( p_url => v_header_delete_url );



          IF ( INSTR(v_header_delete_clob,'error') != 0 )  THEN



            print_log('Error al borrar cabecera de la tabla stage de BC');

            print_log(v_header_delete_clob);



          ELSE



            print_log('Cabecera borrada de la tabla stage de BC');



          END IF; 



        ELSE



          -- Se actualiza la tabla custom con el status SUCCESS

          UPDATE AJCL_BC_AP_CERTIFY_INVOICES

             SET status = 'SUCCESS',

             last_update_date=SYSDATE,

             error_message = NULL,

             request_id=gv_request_id

           WHERE request_id = cs.requestID--gv_request_id -- 20240927 se agrega cs.request_id para poder re-procesar facturas que quedaron SENT en ejecucion anterior porque falló call_job

             AND invoice_id = cs.invoiceID;



        END IF;



      END LOOP;  



    END LOOP;



    -- 20241002 Si quedaron registros SENT significa que call status no pudo obtener estado de procesamiento. Asumo que no se procesaron. Los marco como REJECTED para que se re-procesen el la próxima ejecución

    UPDATE AJCL_BC_AP_CERTIFY_INVOICES

    SET status='REJECTED',

        last_update_date=SYSDATE,

        error_message='Could not get processing status',

        request_id=gv_request_id

    WHERE status='SENT';

    --AND request_id=gv_request_id;

    

    p_status := 'S';



    print_log ('ajcl_bc_certify_pkg.call_status (-)');   



  EXCEPTION

    WHEN OTHERS THEN

        v_error_message := 'Error no atrapado al llamar Web Service de Status, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        

        -- 20241002 Si quedaron registros SENT significa que call status no pudo obtener estado de procesamiento. Asumo que no se procesaron. Los marco como REJECTED para que se re-procesen el la próxima ejecución

        UPDATE AJCL_BC_AP_CERTIFY_INVOICES

        SET status='REJECTED',

            last_update_date=SYSDATE,

            error_message='Could not get processing status',

            request_id=gv_request_id

        WHERE status='SENT';

        --AND request_id=gv_request_id;

    

        print_log ('ajcl_bc_certify_pkg.call_status (!)');



  END call_status;



  -- ------------------------------------------------------------------------------------------------------------------------

  -- AJC Delete Expense Report Files Older than 60 Days

  -- ------------------------------------------------------------------------------------------------------------------------

  PROCEDURE ajcl_del_expense_rpt_files ( p_status   OUT   VARCHAR2 ) IS --MB: REVISAR



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



    print_log('ajcl_del_expense_rpt_files (+)');



    v_request_id := fnd_request.submit_request ( 'XXAJC'

                                                ,'ajcl_DELETE_EXP_RPT_FILES' ) ; 



    IF v_request_id = 0 THEN



      v_message := fnd_message.get;

      print_log('Error Ejecutando FND_REQUEST.SUBMIT_REQUEST. ajcl_DELETE_EXP_RPT_FILES. Error: ' || 

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

      print_log('Error Ejecutando FND_REQUEST.WAIT_FOR_REQUEST. ajcl_DELETE_EXP_RPT_FILES con nro. solicitud ' || 

                 TO_CHAR (v_request_id) || '. Error: ' || v_message || ' ' || SQLERRM);

      RAISE e_cust_exception;



    END IF ;



    IF v_conc_dev_phase != 'COMPLETE' OR v_conc_dev_status != 'NORMAL' THEN



      v_error_message := fnd_message.get;

      print_log('Error en la ejecucion del concurrente ajcl_DELETE_EXP_RPT_FILES con nro. solicitud ' || 

                 TO_CHAR (v_request_id) || '. Error: ' || v_error_message || ' ' || SQLERRM);

      RAISE e_cust_exception;



    END IF ; 



    p_status := 'S';



    print_log('ajcl_del_expense_rpt_files (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

      print_log('ajcl_del_expense_rpt_files (!)');

      p_status := 'E'; 



  END ajcl_del_expense_rpt_files;

  

    -- Inserta los worksheets a enviar a BC en la tabla AJCL_BC_WORKSHEETS

  -- y ejecuta el procedure que los envia a BC

  PROCEDURE worksheets_to_bc_p ( p_status             IN OUT   VARCHAR2 ) IS



      CURSOR c_worksheets IS

      SELECT attribute1 ws_ies_num

        FROM  AJCL_BC_AP_CERTIFY_LINES

       WHERE request_id = gv_request_id

       AND attribute1 IS NOT NULL

    GROUP BY attribute1;



    v_total_worksheets   NUMBER;

    e_error              EXCEPTION;



  BEGIN



    print_log( 'ajcl_bc_certify_pkg.worksheets_to_bc_p (+)' );



    v_total_worksheets := 0;



    FOR cw IN c_worksheets LOOP



      v_total_worksheets := v_total_worksheets + ajcl_bc_worksheets_pkg.insert_p ( p_ws_ies_num => cw.ws_ies_num,

                                                                                   p_bc_environment => gv_bc_environment );



    END LOOP;



    IF ( v_total_worksheets != 0 ) THEN



      ajcl_bc_worksheets_pkg.main_p ( p_bc_environment => gv_bc_environment,

                                      p_bc_company_id => gv_bc_company_id,

                                      p_bc_ifc => gv_bc_ifc,

                                      p_request_id => gv_request_id,

                                      p_log_seq => gv_log_seq,

                                      p_status => p_status );



      IF ( p_status != 'S' ) THEN



        RAISE e_error;



      END IF;



    END IF;



    p_status := 'S';

    print_log( 'ajcl_bc_certify_pkg.worksheets_to_bc_p (-)' );



  EXCEPTION

    WHEN e_error THEN

      print_log( 'ajcl_bc_certify_pkg.worksheets_to_bc_p (!)' );

      p_status := 'E';

    WHEN OTHERS THEN

      print_log( 'ajcl_bc_certify_pkg.worksheets_to_bc_p (!)' );

      p_status := 'E';



  END worksheets_to_bc_p;



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

        FROM AJCL_BC_AP_CERTIFY_INVOICES a,

                AJCL_BC_AP_CERTIFY_LINES b

     WHERE a.request_id = gv_request_id

     AND a.invoice_id=b.invoice_id

   --  AND ( a.status IN ('ERROR','REJECTED') OR b.status IN ('ERROR','REJECTED'))

        ORDER by 1,6,11; 



  BEGIN



    print_log( 'ajcl_bc_certify_pkg.final_report_p (+)' );



    -- Insert Report Title

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => gv_bc_ifc || ' Report',

                                        p_request_id => gv_request_id );

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Request ID|' || gv_request_id,

                                        p_request_id => gv_request_id ); 



    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Tabla 1 -----------------------------------------------------------------------------------------------------------------                                    

    -- Insert Table Title

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Processed Invoice Lines',

                                        p_request_id => gv_request_id );



    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Insert Table Column Names                            

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

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



      ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

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



    print_log( 'ajcl_bc_certify_pkg.final_report_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_certify_pkg.final_report_p (!). Error: ' || SQLERRM );



  END final_report_p;



  PROCEDURE final_report_xlsx_p ( p_status   OUT   VARCHAR2 ) IS



    c_processed   SYS_REFCURSOR;

    c_errors       SYS_REFCURSOR;



  BEGIN



    print_log( 'ajcl_bc_certify_pkg.final_report_xlsx_p (+)' );



    gv_directory_report := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_REPORT' );



    -- Solapa Report Information

    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc || ' Report Information',

                                                                       p_request_id => gv_request_id,

                                                                       p_bc_environment => gv_bc_environment,

                                                                       p_jenkins_build_number => gv_jenkins_build_number,

                                                                       p_param_1_title => 'GL Date',

                                                                       p_param_1_value =>  TO_CHAR(NVL(gv_gl_date,TRUNC(SYSDATE)),'YYYY-MM-DD'));                 



    -- Solapa Processed Data

        OPEN c_processed FOR

        SELECT

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

        FROM AJCL_BC_AP_CERTIFY_INVOICES a,

                AJCL_BC_AP_CERTIFY_LINES b

     WHERE a.request_id = gv_request_id

     AND a.invoice_id=b.invoice_id

  --   AND ( a.status IN ('ERROR','REJECTED') OR b.status IN ('ERROR','REJECTED'))

        ORDER by 1,6,11; 



    -- Processed Data

    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Processed Data',

                                                        p_sheet => 2,

                                                        p_cursor => c_processed );



    as_xlsx.save ( gv_directory_report, gv_report_filename || '.' || LOWER(gv_file_format) );



    p_status := 'S';



    print_log( 'ajcl_bc_certify_pkg.final_report_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_certify_pkg.final_report_xlsx_p (!). Error: ' || SQLERRM );



  END final_report_xlsx_p;

  -- ------------------------------------------------------------------------------------------------------------------------

  -- Main

  -- ------------------------------------------------------------------------------------------------------------------------

  PROCEDURE main_p ( p_bc_environment   IN   VARCHAR2,

                                p_gl_date   IN VARCHAR2,

                                p_jenkins_build_number   IN   VARCHAR2,

                                p_file_date   IN VARCHAR2,

                                p_execute_ftp_loader IN VARCHAR2) IS



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

    v_support_email          VARCHAR2(200);

    v_not_success         NUMBER;

    -- 20250514

    

  BEGIN



    print_log('ajcl_bc_certify_pkg.main_p (+)');

    

    gv_jenkins_build_number := p_jenkins_build_number;

    gv_request_id := ajcl_bc_utils_pkg.get_request_id_f;

    -- Se inserta el concurrent_job

    ajcl_bc_utils_pkg.ins_jenkins_concurrent_job_p ( p_request_id => gv_request_id,

                                                     p_job_name => gv_bc_ifc,

                                                     p_jenkins_build_number => gv_jenkins_build_number,

                                                     p_argument1 => p_bc_environment );

                                                     

    print_log ( 'gv_request_id: ' || gv_request_id );                                                         



    gv_file_format :=ajcl_bc_ws_utils_pkg.get_parameter_f ( 'FILE_FORMAT' );

    print_log( 'gv_file_format: ' || gv_file_format );

    

    gv_email := ajcl_bc_utils_pkg.get_emails_f ( 'CERTIFY' );

    print_log( 'gv_email: ' || gv_email );



    gv_process_name := ajcl_bc_ws_utils_pkg.get_lock_process_name_f ( p_integration => 'PURCHASE INVOICES' );

    print_log( 'gv_process_name: ' || gv_process_name );



    -- Validacion parametro p_bc_environment -----------------------------------------------------------------------------------

    IF ( ajcl_bc_utils_pkg.is_bc_environment_valid_f ( p_bc_environment ) = 'N' ) THEN



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



    gv_org_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                                                              p_column => 'ORG_ID' );  

    print_log ( 'gv_org_id: ' || gv_org_id );

    

    gv_set_of_books_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                                                                               p_column => 'SET_OF_BOOKS_ID' );

    print_log ( ' gv_set_of_books_id  : ' ||  gv_set_of_books_id   );



    gv_set_of_books_name := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                                                                                     p_column => 'SET_OF_BOOKS_NAME' );       

    print_log ( ' gv_set_of_books_name  : ' ||  gv_set_of_books_name   );



    gv_bc_company_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                                                                              p_column => 'BC_COMPANY_ID' );       

    print_log ( ' gv_bc_company_id  : ' ||  gv_bc_company_id   );



    ajcl_bc_utils_pkg.initialize_p ( p_org_id => gv_org_id );

    print_log ( 'ajcl_bc_utils_pkg.initialize_p' );

           

    --Sincronizo default dimensions para mapeo de segmentos

    ajcl_bc_accounts_pkg.main_p ( p_bc_environment => p_bc_environment );

    print_log ( 'ajcl_bc_accounts_pkg.main_p' );      

    

    -- 20240917

    IF (ajcl_bc_utils_pkg.get_db_name_f IN ('FINUPG5','PROD') ) THEN

        gv_ftp_loader := 'Y'; -- FTP, LOADER

    ELSIF (ajcl_bc_utils_pkg.get_db_name_f IN ('FINUPG6') ) THEN

        gv_ftp_loader := 'N'; -- TRIGGER

    END IF;

    

    print_log('gv_ftp_loader: '||gv_ftp_loader); 

    -- 20240917    

    

    IF ( gv_ftp_loader = 'Y' ) AND ( p_execute_ftp_loader = 'Y') THEN    



              -- Se arma el nombre del archivo a copiar del FTP, con el prefijo pasado como parametro, si es null con la fecha de hoy

              SELECT 'Certify_Oracle_Output_'||NVL(p_file_date,to_char(sysdate,'YYYYMMDD'))||'*' 

                INTO v_file_prefix

                FROM dual;



              print_log('v_file_prefix: ' || v_file_prefix);

              

            -- 20230706

            -- Se verifica si el FTP y Loader ya corrieron para la fecha pasada como parametro

            -- Si ya corrieron, no se vuelven a correr y se ejecuta directamente el procesamiento de lo que hay en tabla

            

            SELECT DECODE(COUNT(1),0,'Y','N')

              INTO v_execute_ftp_ldr

              FROM  AJC_BC_JENKINS_CONCURRENT_JOBS

             WHERE 1=1

               AND job_name = gv_bc_ifc_ftp --'AJCL BC Certify FTP'

               AND TRUNC(start_date) = TRUNC(SYSDATE)

               AND status='S'

               AND argument1 = v_file_prefix;--LIKE '%' || TO_CHAR(TO_DATE(SYSDATE,'YYYY/MM/DD'),'YYYYMMDD') || '%';

        

            print_log('Execute FTP and Loader?: ' || v_execute_ftp_ldr);



            -- Solo se ejecuta FTP y Loader cuando no se ejecuto para la fecha pasada como parametro

            IF ( v_execute_ftp_ldr = 'Y' ) THEN



              -- ------------------------------------------------------------------------------------------------------------------------

              -- FTP

              -- ------------------------------------------------------------------------------------------------------------------------

              ajcl_ftp_expense_rpt ( p_file_prefix => v_file_prefix, 

                                                p_status => v_status );                                           



               -- Se hace que no falle, para que procese lo que no se proceso aun que esta en tabla. MB: REVISAR

               

              IF ( v_status != 'S' ) THEN

                v_error_msg := 'Process failed when trying to get file from SFTP server. Please check email with attached log file. (ajcl_ftp_expense_rpt)';

                RAISE e_error;



              END IF;

              



              -- ------------------------------------------------------------------------------------------------------------------------

              -- Loader

              -- ------------------------------------------------------------------------------------------------------------------------                                            

              ajcl_load_expense_rpt_int ( p_file_name => gv_file_name,

                                             p_status => v_status );



               -- Se hace que no falle, para que procese lo que no se proceso aun que esta en tabla. MB: Revisar

               IF ( v_status != 'S' ) THEN



                v_error_msg := 'Process failed when trying to load Certify file. Please check email with attached log file. (ajcl_load_expense_rpt_int)';

                RAISE e_error;



              END IF;

             

            END IF;

            

                DBMS_LOCK.SLEEP(10);

    END IF; --    IF ( gv_ftp_loader = 'Y' ) 

     

    -- 20230705

    -- ------------------------------------------------------------------------------------------------------------------------

    -- Transformaciones e Insert a tablas

    -- ------------------------------------------------------------------------------------------------------------------------

    expense_report_interface_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_error_msg := 'Process failed when trying to process Certify records. Please check email with attached log file. (expense_report_interface_p)';

      RAISE e_error;



    END IF;



    print_log (' '); 

    -- ------------------------------------------------------------------------------------------------------------------------ 

    -- Envío de Worksheets a BC   

    -- ------------------------------------------------------------------------------------------------------------------------

    worksheets_to_bc_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_error_msg := 'Error en worksheets_to_bc_p';

      print_log('Error!');

      print_log('v_error_msg: '||v_error_msg);

      

      --20240910 se comenta el raise para que se procesen las lineas igual. si alguna falla por ws inexistente, se reprocesaran en la próxima ejecución      

      --RAISE e_error; 



    END IF;



    -- 20240909 

    -- Se verifica si los concurrentes 'AJC BC INC Certify Interface' o 'AJC BC ABBYY Invoice Interface' (FOODS) están por correr o corriendo

    -- En tal caso, se espera hasta que terminen

    BEGIN



      v_continue := 'N';

      print_log ( 'Checks if AJC BC INC Certify Interface or AJC BC ABBYY Invoice Interface are running or are about to be executed.' );

      v_start := SYSDATE;



      WHILE ( v_continue = 'N' ) LOOP



        SELECT DECODE(COUNT(1),0,'Y','N')

          INTO v_continue

          FROM fnd_concurrent_requests r,

               fnd_concurrent_programs_vl p

         WHERE r.concurrent_program_id = p.concurrent_program_id

           AND p.user_concurrent_program_name IN ('AJC BC INC Certify Interface','AJC BC ABBYY Invoice Interface')

           AND ( ( r.phase_code = 'R' ) or -- Running

                 ( r.phase_code = 'P' and r.status_code = 'Q' ) or -- Pending | Standby / Scheduled

                 ( r.phase_code = 'P' and r.status_code = 'R' ) ) -- Pending | Normal

           AND NVL(r.hold_flag,'N')='N' -- no tengo en cuenta los holdeados                 

           AND r.requested_start_date < SYSDATE + interval '15' minute; -- Si existe algun concurrente programado Once, pero faltan mas de 30 minutos, continúa

           

        IF ( v_continue = 'N' ) THEN



          print_log ( 'Another Certify or ABBYY request is running or is about to be executed in AJC. Wait 1 minute.' );

          DBMS_LOCK.SLEEP(60);



        END IF;



        v_elapsed_seconds := TRUNC( ( SYSDATE - v_start ) * 24 * 60 * 60 );



        -- Si se supero el timeout, se sigue

        IF ( v_elapsed_seconds > v_timeout_seconds ) THEN



          v_continue := 'Y';



        END IF;



      END LOOP;



    END;

    -- 20240909

    

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



    -- Si se envió al menos un comprobante, se ejecuta el job

    IF ( v_invoice_count > 0 ) THEN



      print_log (' '); 

      -- Se ejecuta el JOB -----------------------------------------------------------------------------------------------------

      call_job ( p_status         => v_status

                ,p_error_message  => v_error_msg

                ,p_bc_environment => p_bc_environment );



       print_log('Se espera 1 segundo por cada linea procesada: '||v_lines_count);

       

          DBMS_LOCK.sleep(seconds => v_lines_count);-- / 2);

          

      IF v_status != 'S' THEN



        IF v_status = 'W' THEN



         -- retcode := 1;

         -- errbuf  := v_error_message;

            NULL;

        ELSE

                  

          -- si call_job terminó con error , llamo a call_status para que elimine los registros de la inbound purchase documents y los marque como REJECTED

            call_status ( p_status => v_status

               ,p_error_message => v_error_msg

               ,p_bc_environment => p_bc_environment );

                   

          v_error_msg := 'Process failed when calling BC import job. Please check email with attached log file. (call_job)';

          RAISE e_error;



        END IF;



      END IF;



      print_log ( 'v_lines_count: ' || v_lines_count );

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

    

      -- INSERT REPORT IN TABLE AJCL_BC_REPORTS --------------------------------------------------------------------------------

      final_report_p ( p_status => v_status );     



      IF ( v_status != 'S' ) THEN



        v_error_msg := 'Error en final_report_p';

        RAISE e_error;



      END IF;  

      

      IF ( gv_file_format = 'CSV' ) THEN



          -- CREATE CSV FROM TABLE AJCL_BC_REPORTS --------------------------------------------------------------------------------

          ajcl_bc_utils_pkg.create_csv_p ( p_ifc => gv_bc_ifc,

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

          ajcl_bc_utils_pkg.send_mail_with_attach ( p_to_mail => gv_email,

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

    --ajcl_inc_del_expense_rpt_files ( p_status => v_status ); MB:REVISAR



   -- IF ( v_status != 'S' ) THEN



     -- RAISE e_error;



    --END IF;

    

    -- borro registros de tabla loader espejo, para emular TRUNCATE del ctl sobre la tabla principal y no queden registros de una ejecución a otra. Comentar si la tabla espejo se vuelve tabla principal 

    --DELETE AJCL_BC_EXPENSE_RPT_INT; MB: REVISAR



        -- 20250514

        -- Se agrega envio de mail para soporte, para informar que no se pudo importar todo en la ejecucion

        BEGIN

           

          v_support_email := ajcl_bc_utils_pkg.get_emails_f ( 'SUPPORT' );

             

          SELECT COUNT(1)

               INTO v_not_success

             FROM   AJCL_BC_AP_CERTIFY_INVOICES a,

                        AJCL_BC_AP_CERTIFY_LINES b

            WHERE a.request_id = gv_request_id

            AND a.invoice_id=b.invoice_id

            AND ( a.status IN ('ERROR','REJECTED') OR b.status IN ('ERROR','REJECTED'));

             

          print_log ('v_not_success: ' || v_not_success);  

                 

          IF ( v_not_success > 0 ) THEN

             

            ajcl_bc_utils_pkg.send_email_p ( p_to => v_support_email,

                                                                  p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - WARNING - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                                                  p_message => 'Some journals could not be imported. Please review the integration report.' || CHR(10) || 'Request ID: ' || gv_request_id );

          

          END IF;

           

        EXCEPTION

            WHEN OTHERS THEN

               NULL;

               

        END;

         -- 20250514

         

      -- Se actualiza el concurrent_job

    ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'S' );

    

    COMMIT;

     

    print_log('ajcl_bc_certify_pkg.main_p (-)');



  EXCEPTION

      -- dbms_lock ---------------------------------------------------------------------------------------------------------------

    WHEN ge_lock THEN -- Lock and Release

      print_log ('ajcl_bc_certify_pkg.main_p (!). Error al intentar hacer el lock del proceso ' || gv_process_name || 

              ' | request_status: ' || gv_request_status);

              

      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject =>  gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',   

                                       p_message => v_error_msg|| CHR(10) ||'Request Id: '||gv_request_id );



      ajcl_bc_utils_pkg.send_log_by_mail_p(gv_request_id,gv_email);

      

      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );                                       



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );    

      

    WHEN ge_release THEN -- Lock and Release

      print_log ('ajcl_bc_certify_pkg.main_p (!). Error al intentar hacer el release del proceso ' || gv_process_name || 

              ' | request_status: ' || gv_release_status);

              

      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject =>  gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',   

                                       p_message => v_error_msg|| CHR(10) ||'Request Id: '||gv_request_id );



      ajcl_bc_utils_pkg.send_log_by_mail_p(gv_request_id,gv_email);

      

      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );                                       



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );    

                    

    -- dbms_lock ---------------------------------------------------------------------------------------------------------------

    

    WHEN e_parameter_value THEN

      print_log('ajcl_bc_certify_pkg.main_p (!)');

      print_log('Parameter Value Error!');

      print_log(v_error_msg);

      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject =>  gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',   

                                       p_message => v_error_msg|| CHR(10) ||'Request Id: '||gv_request_id );



      ajcl_bc_utils_pkg.send_log_by_mail_p(gv_request_id,gv_email);

      

      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );              

 

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------                                         



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg ); 

                  

    WHEN e_error THEN

      print_log('ajcl_bc_certify_pkg.main_p (!)');

      print_log('Error!');

      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject =>  gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',   

                                       p_message => v_error_msg || CHR(10) ||'Request Id: '||gv_request_id);



      ajcl_bc_utils_pkg.send_log_by_mail_p(gv_request_id,gv_email);

                                                   

          -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------     

                                     

      RAISE_APPLICATION_ERROR(-20000,'General Error: ' || SQLERRM );   

  END main_p;



END ajcl_bc_certify_pkg;
