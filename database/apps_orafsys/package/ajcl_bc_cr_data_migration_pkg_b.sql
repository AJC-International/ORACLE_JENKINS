CREATE OR REPLACE PACKAGE BODY ajcl_bc_cr_data_migration_pkg IS

  

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    gv_log_seq := gv_log_seq + 1;

    ajcl_bc_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );



  END print_log;



  PROCEDURE final_report_xlsx_p IS



    c_cursor   SYS_REFCURSOR;

    v_sheet    NUMBER := 1;



  BEGIN



    print_log( 'ajcl_bc_cr_data_migration_pkg.final_report_xlsx_p (+)' );



    gv_directory_report := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_REPORT' );



    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc,

                                                p_request_id => gv_request_id,

                                                p_bc_environment => NULL,

                                                p_jenkins_build_number => gv_jenkins_build_number,

                                                --

                                                p_param_1_title => ' ',

                                                p_param_1_value => NULL,

                                                --

                                                p_param_2_title => 'GL_DATE',

                                                p_param_2_value => TO_CHAR(gv_gl_date,'YYYY-MM-DD'),

                                                p_param_3_title => 'RECEIPT_NUM_PREFIX',

                                                p_param_3_value => gv_receipt_num_prefix,

                                                p_param_4_title => 'ORACLE_DB',

                                                p_param_4_value => gv_oracle_db );



        OPEN c_cursor FOR 

      SELECT gv_receipt_num_prefix || 'CRJ' || LPAD(ROWNUM,5,'0') documentNo,

             crj.*

        FROM ( SELECT acr.receipt_number lockboxReceiptNumber,

                      NVL(rc.customer_number,gv_unidentified_no) customerNo,

                      TO_CHAR(gv_gl_date,'YYYY-MM-DD') postingDate,

                      'Payment' documentType,

                      SUBSTR(acr.receipt_number || ' | ' || acr.comments,1,100) description,

                      NVL(rc.customer_name,gv_unidentified_name) customerName,

                      TO_CHAR(acr.receipt_date,'YYYY-MM-DD') documentDate,

                      DECODE(acr.currency_code,'USD',NULL,acr.currency_code) currencyCode,

                      aps.amount_due_remaining amount,

                      --

                      'ALL' customerPostingGroup,

                      'TBD' salespersonCode,

                      'OAUTH' userID,

                      'CASHRECJNL' sourceCode,

                      'true' open,

                      NULL due_date,

                      'CASHRCPT' journalTemplateName,

                      'DEFAULT' journalBatchName,

                      'G/L Account' balAccountType,

                      '1110.1200' balAccountNo

                 FROM ar_cash_receipts_all acr,

                      ar_payment_schedules_all aps,

                      ra_customers rc

                WHERE acr.org_id = gv_org_id

                  AND acr.org_id = aps.org_id

                  AND acr.cash_receipt_id = aps.cash_receipt_id

                  AND aps.amount_due_remaining != 0

                  AND aps.status = 'OP'

                  AND aps.class = 'PMT'

                  AND acr.pay_from_customer = rc.customer_id (+)

             ORDER BY TRUNC(acr.creation_date), 

                      acr.receipt_number ) crj;



    v_sheet := v_sheet + 1;

    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Receipts',

                                       p_sheet => v_sheet,

                                       p_cursor => c_cursor );



    /*

        -- Se crea solapa con los customers que no existen en BC

        OPEN c_cursor FOR     

      SELECT customer_number,

             customer_name

        FROM ( SELECT NVL(rc.customer_number,gv_unidentified_no) customer_number,

                      NVL(rc.customer_name,gv_unidentified_name) customer_name  

                 FROM ar_cash_receipts_all acr,

                      ar_payment_schedules_all aps,

                      ra_customers rc

                WHERE acr.org_id = gv_org_id

                  AND acr.org_id = aps.org_id

                  AND acr.cash_receipt_id = aps.cash_receipt_id

                  AND aps.amount_due_remaining != 0

                  AND aps.status = 'OP'

                  AND aps.class = 'PMT'

                  AND acr.pay_from_customer = rc.customer_id (+)

             GROUP BY NVL(rc.customer_number,gv_unidentified_no),

                      NVL(rc.customer_name,gv_unidentified_name) )

       WHERE ajcl_bc_ws_utils_pkg.check_customer_exists_bc_p ( p_bc_environment => gv_bc_environment,

                                                               p_company_id => gv_bc_company_id,

                                                               p_no => customer_number ) = 'N'

    ORDER BY customer_name;

    */



          -- Se crea solapa con los customers que no existen en BC

          OPEN c_cursor FOR    

        SELECT crj.customer_number,

               crj.customer_name  

          FROM ( SELECT NVL(rc.customer_number,gv_unidentified_no) customer_number,

                        NVL(rc.customer_name,gv_unidentified_name) customer_name  

                   FROM ar_cash_receipts_all acr,

                        ar_payment_schedules_all aps,

                        ra_customers rc

                  WHERE acr.org_id = gv_org_id

                    AND acr.org_id = aps.org_id

                    AND acr.cash_receipt_id = aps.cash_receipt_id

                    AND aps.amount_due_remaining != 0

                    AND aps.status = 'OP'

                    AND aps.class = 'PMT'

                    AND acr.pay_from_customer = rc.customer_id (+)

               GROUP BY NVL(rc.customer_number,gv_unidentified_no),

                        NVL(rc.customer_name,gv_unidentified_name) ) crj

         WHERE NOT EXISTS ( SELECT 1

                              FROM ajcl_bc_vendors_customers bcv

                             WHERE type = 'CUSTOMER' 

                               AND bcv.bc_environment = gv_bc_environment 

                               AND bcv.no = crj.customer_number )

      ORDER BY customer_name;



    v_sheet := v_sheet + 1;

    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Customers Missing',

                                       p_sheet => v_sheet,

                                       p_cursor => c_cursor );                                         



    as_xlsx.save ( gv_directory_report, gv_report_filename || '.' || LOWER(gv_file_format) );



    print_log( 'ajcl_bc_cr_data_migration_pkg.final_report_xlsx_p (-)' );



  END final_report_xlsx_p;



  PROCEDURE main_p ( p_bc_environment         IN    VARCHAR2,

                     p_gl_date                IN    VARCHAR2,

                     p_receipt_num_prefix     IN    VARCHAR2,

                     p_jenkins_build_number   IN    VARCHAR2 ) IS



    v_status            VARCHAR2(1);



    v_error_message     VARCHAR2(2000);

    e_parameter_value   EXCEPTION;   

    e_cust_exception    EXCEPTION;



  BEGIN



    gv_request_id := ajcl_bc_utils_pkg.get_request_id_f;

    gv_jenkins_build_number := p_jenkins_build_number;



    DELETE ajcl_bc_logs

     WHERE ifc = gv_bc_ifc;



    COMMIT;



    print_log ( 'ajcl_bc_cr_data_migration_pkg.main_p (+)');



    print_log ( 'gv_request_id: ' || gv_request_id );

    print_log ( 'gv_bc_ifc: ' || gv_bc_ifc );

    print_log ( 'gv_jenkins_build_number: ' || gv_jenkins_build_number );



    gv_oracle_db := ajcl_bc_utils_pkg.get_db_name_f;

    print_log ( 'gv_oracle_db: ' || gv_oracle_db );



    print_log ( 'gv_report_filename: ' || gv_report_filename );



    print_log ( 'p_gl_date: ' || p_gl_date );

    print_log ( 'p_receipt_num_prefix: ' || p_receipt_num_prefix );   



    -- Se obtienen los parametros de la company 

    print_log ( 'gv_bc_company_name: ' || gv_bc_company_name );



    gv_bc_company_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                     p_column => 'BC_COMPANY_ID' );



    print_log ( 'gv_bc_company_id: ' || gv_bc_company_id );



    gv_org_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                              p_column => 'ORG_ID' );



    print_log ( 'gv_org_id: ' || gv_org_id );



    -- Validacion parametro p_bc_environment -----------------------------------------------------------------------------------

    IF ( ajcl_bc_utils_pkg.is_bc_environment_valid_f ( p_bc_environment ) = 'N' ) THEN



      v_error_message := 'Invalid value (' || p_bc_environment || ') for parameter BC_ENVIRONMENT.';

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

          v_error_message := 'Error: ' || SUBSTR(SQLERRM,INSTR(SQLERRM,':') + 2) || ' (' || p_gl_date || ')';

          RAISE e_parameter_value;



      END;



    END IF;



    print_log ( 'gv_gl_date: ' || gv_gl_date );



    gv_receipt_num_prefix := p_receipt_num_prefix;

    print_log ( 'gv_receipt_num_prefix: ' || gv_receipt_num_prefix );



    -- Get Customers from BC

    ajcl_bc_get_entities_pkg.get_bc_customers_p ( p_bc_environment => gv_bc_environment,

                                                  p_bc_ifc => gv_bc_ifc,

                                                  p_request_id => gv_request_id,

                                                  p_log_seq => gv_log_seq,

                                                  p_status => v_status );



    IF ( v_status != 'S' ) THEN



      RAISE e_cust_exception;



    END IF;



    final_report_xlsx_p; 



    ajcl_bc_utils_pkg.send_mail_with_attach ( p_to_mail => gv_mail,

                                              p_subject => gv_bc_ifc || ' - ' || gv_oracle_db || ' - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'),

                                              p_body => gv_oracle_db,

                                              p_type => 'REPORT',

                                              p_filename => gv_report_filename, 

                                              p_file_format => gv_file_format,

                                              p_attach_filename => gv_bc_ifc || ' - ' || TO_CHAR(SYSDATE,'YYYYMMDD HH24MISS') || '.' || LOWER(gv_file_format) );  



    print_log ( 'ajcl_bc_cr_data_migration_pkg.main_p (-)');



  EXCEPTION

    WHEN e_parameter_value THEN

      print_log('ajcl_bc_cr_data_migration_pkg.main_p (!)');

      print_log(v_error_message);



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_mail,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') || ' - ERROR',

                                       p_message => v_error_message );



    WHEN e_cust_exception THEN

      print_log('ajcl_bc_cr_data_migration_pkg.main_p (!)');



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_mail,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') || ' - ERROR',

                                       p_message => v_error_message );



    WHEN OTHERS THEN

      print_log('ajcl_bc_cr_data_migration_pkg.main_p (!)');

      print_log('Error: ' || SQLERRM);



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_mail,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') || ' - ERROR',

                                       p_message => SQLERRM );



  END main_p; 



END ajcl_bc_cr_data_migration_pkg; 
