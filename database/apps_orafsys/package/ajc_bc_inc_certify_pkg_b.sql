CREATE OR REPLACE PACKAGE BODY              ajc_bc_inc_certify_pkg AS

  

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

          WHEN NO_DATA_FOUND THEN

            print_log ( 'Supplier Site: ' || employee_site_code_v || ' not found in Oracle for Supplier: ' || supplier_number_v);



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



        travel_adv_distr_account_v := null; 

        distr_account_v := null;

        distr_acct_num_v := null; 

        dept_override_v := null;



        invoice_amount_v := invoice_amount_v + inv_line_rec.line_amount;



        travel_adv_distr_account_v := substr(inv_line_rec.distr_account,1,2) || '.' || p_travel_advance_account_num || '.000.000.000.000.00';



        print_log ( 'travel_adv_distr_account_v: ' || travel_adv_distr_account_v );



        --travel_adv_distr_account_v: 01.1252.000.000.000.000.00

        --distr_account_v: 01.6145.515.000.000.000.00



        -- SB

        /*

        SELECT gcc.code_combination_id,

               -- LTRIM(gcc.segment1,'0') company,

               gcc.segment1 company,

               aba.bc_account account,

               aba.description account_description,

               gcc.segment3 department,

               decode(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT4'

                                                                          ,p_oracle_value   => gcc.segment4

                                                                          ,p_bc_dimension   => 'DIVISION'), NULL,gcc.segment4,'000') product,

               decode(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                          ,p_oracle_value   => gcc.segment5

                                                                          ,p_bc_dimension   => 'OFFICE'), NULL,gcc.segment5,'000') destination,

               gcc.segment6 origin,

               '00' intercompany

          INTO v_t_dist_code_combination_id,

               v_t_company,

               v_t_account,

               v_t_account_description,

               v_t_department,

               v_t_product,

               v_t_destination,

               v_t_origin,

               v_t_intercompany

          FROM gl_code_combinations gcc,

               ajc.ajc_bc_accounts aba

         WHERE segment1 || '.' || segment2 || '.' || segment3 || '.' || segment4 || '.' || segment5 || '.' || segment6 || '.' || segment7 = travel_adv_distr_account_v

           AND gcc.segment2 = aba.oracle_account (+);

        */



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

               decode(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT4'

                                                                          ,p_oracle_value   => v_t_segment4

                                                                          ,p_bc_dimension   => 'DIVISION'), NULL,v_t_segment4,'000') product,

               decode(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                          ,p_oracle_value   => v_t_segment5

                                                                          ,p_bc_dimension   => 'OFFICE'), NULL,v_t_segment5,'000') destination,

               nvl(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

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



        -- SB

        /*

        SELECT gcc.code_combination_id,

               -- LTRIM(gcc.segment1,'0') company,

               gcc.segment1 company,

               aba.bc_account account,

               aba.description account_description,

               gcc.segment3 department,

               decode(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT4'

                                                                          ,p_oracle_value   => gcc.segment4

                                                                          ,p_bc_dimension   => 'DIVISION'), NULL,gcc.segment4,'000') product,

               decode(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                          ,p_oracle_value   => gcc.segment5

                                                                          ,p_bc_dimension   => 'OFFICE'), NULL,gcc.segment5,'000') destination,

               gcc.segment6 origin,

               '00' intercompany

          INTO v_l_dist_code_combination_id,

               v_l_company,

               v_l_account,

               v_l_account_description,

               v_l_department,

               v_l_product,

               v_l_destination,

               v_l_origin,

               v_l_intercompany        

          FROM gl_code_combinations gcc,

               ajc.ajc_bc_accounts aba

         WHERE segment1 || '.' || segment2 || '.' || segment3 || '.' || segment4 || '.' || segment5 || '.' || segment6 || '.' || segment7 = distr_account_v

           AND gcc.segment2 = aba.oracle_account (+);

        */



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

                 decode(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT4'

                                                                            ,p_oracle_value   => v_l_segment4

                                                                            ,p_bc_dimension   => 'DIVISION'), NULL,v_l_segment4,'000') product,

                 decode(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                            ,p_oracle_value   => v_l_segment5

                                                                            ,p_bc_dimension   => 'OFFICE'), NULL,v_l_segment5,'000') destination,

                 nvl(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

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

               v_set_of_books_id,

               v_set_of_books_name,

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

               user_id_p, 

               sysdate, 

               user_id_p,

               user_id_p,

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

                 user_id_p, 

                 sysdate, 

                 user_id_p,

                 user_id_p,

                 sysdate,

                 org_id_v,

                 inv_line_rec.worksheet_number,

                 inv_line_rec.record_id,

                 'NEW',

                 gv_request_id,

                 inv_line_rec.invoice_image_url ); 



          line_num_v := line_num_v + 1;



        END IF;



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

             user_id_p, 

             user_id_p,

             sysdate, 

             user_id_p,

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

               resp_id = resp_id_v,

               oracle_supplier_num = supplier_number_v,

               oracle_supplier_site_code = supplier_site_code_v,

               oracle_invoice_num = oracle_invoice_num_v

         WHERE nvl(supplier_number,'XXXXX') = nvl(inv_rec.supplier_number,'XXXXX')

           AND nvl(supplier_name,'XXXXX') = nvl(inv_rec.supplier_name,'XXXXX')

           AND decode(reimburse_flag, advance_c, true_c, reimburse_flag)  = inv_rec.reimburse_flag

           AND invoice_number = inv_rec.invoice_number;



    End LOOP; --  Select_Inv LOOP



    IF rec_cnt_v = 0 THEN



      raise e_no_invoices_found;



    END IF;



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



      ajc_bc_ws_utils_pkg.send_email ( p_to => 'agilardi@ajcgroup.com',

                                       p_subject => 'AJC BC INC Certify Interface - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'),

                                       p_message => 'Error processing: ' || error_text_v );



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

      FROM AJC_BC_INC_AP_CERTIFY_INVOICES

     WHERE request_id = gv_request_id

       AND status = 'NEW';



      CURSOR c_invoice_lines ( pc_invoice_id   IN   NUMBER ) IS

      SELECT *

        FROM AJC_BC_INC_AP_CERTIFY_LINES

       WHERE request_id = gv_request_id

         AND invoice_id = pc_invoice_id

         AND status = 'NEW'

    ORDER BY line_number;



    v_company_id           VARCHAR2(100);

    v_status               VARCHAR2(2000);      



    v_url_header           VARCHAR2(2000);      

    -- 20230414 v_api_header           VARCHAR2(200) := 'inboundPurchaseHeaderINE';

    v_api_header           VARCHAR2(200);

    v_body_header          VARCHAR2(2000);

    v_clob_result_header   CLOB;



    v_url_line             VARCHAR2(2000);

    -- 20230414 v_api_line             VARCHAR2(200) := 'inboundPurchaseLineINE';

    v_api_line             VARCHAR2(200);

    v_body_line            VARCHAR2(2000);

    v_clob_result_line     CLOB;



    v_linea_con_error      VARCHAR2(1);

    v_clob_result_job      CLOB;



    v_error_message        VARCHAR2(1000);



    v_period_name          gl_periods.period_name%TYPE;

    v_message              VARCHAR2(32000);



  BEGIN



    print_log('ajc_bc_inc_certify_pkg.call_ws (+)');



    v_api_header := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                                    p_subentity => 'HEADERS',

                                                    p_method => 'POST' );

    print_log ('v_api_header: ' || v_api_header);



    v_api_line := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                                  p_subentity => 'LINES',

                                                  p_method => 'POST' );

    print_log ('v_api_line: ' || v_api_line);



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



      v_url_header := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, v_company_id ) || v_api_header;

      print_log('v_url_header: ' || v_url_header);



      v_url_line := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, v_company_id ) || v_api_line;

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



          SELECT period_name

            INTO v_period_name

            FROM gl_periods gp

           WHERE gp.adjustment_period_flag = 'N'

             AND gp.period_set_name = 'AJC CALENDAR'

             AND TRUNC(SYSDATE) BETWEEN start_date AND end_date;



          -- Se arma la linea

          APEX_JSON.write('invoiceID', TO_CHAR(cinv.invoice_id));

          APEX_JSON.write('requestID', TO_CHAR(cinv.request_id));

          APEX_JSON.write('lineNo', clin.line_number);

          APEX_JSON.write('amount', clin.amount);

          -- 20230518 No se envia mas valor porque da error y se esta enviando el dato en accountDescription

          -- APEX_JSON.write('description', clin.description, TRUE);

          APEX_JSON.write('description', '', TRUE);

          -- 

          APEX_JSON.write('accountingDate', TO_CHAR(SYSDATE,'YYYY-MM-DD'));

          APEX_JSON.write('periodName', v_period_name);

          APEX_JSON.write('worksheetNo', '', TRUE);

          APEX_JSON.write('baseAmount',0,TRUE); -- ?

          APEX_JSON.write('exchangeRate',cinv.exchange_rate, TRUE); 

          APEX_JSON.write('exchangeRateType', cinv.exchange_rate_type, TRUE); 

          APEX_JSON.write('exchangeDate', cinv.exchange_date, TRUE);

          APEX_JSON.write('organisationID', TO_CHAR(clin.org_id) );

          APEX_JSON.write('setOfBooksID', clin.set_of_books_id, TRUE); 

          APEX_JSON.write('setOfBooksName', clin.set_of_books_name); 

          APEX_JSON.write('distCodeCombination', clin.dist_code_combination_id);



          -- 20221215 APEX_JSON.write('company', clin.company); 

          APEX_JSON.write('company',ajc_bc_account_dim_pkg.account_dim_required(clin.account,'COMPANY',clin.company),TRUE);        



          APEX_JSON.write('account', clin.account); 

          -- APEX_JSON.write('accountDescription', clin.account_description); 

          APEX_JSON.write('accountDescription', clin.description, TRUE); -- Se envia la descripcion de la linea en Oracle

          --



          -- 20221215 APEX_JSON.write('department', clin.department); 

          APEX_JSON.write('department',ajc_bc_account_dim_pkg.account_dim_required(clin.account,'DEPARTMENT',clin.department),TRUE);   



          -- 20221215 APEX_JSON.write('product', clin.product); 

          APEX_JSON.write('product',ajc_bc_account_dim_pkg.account_dim_required(clin.account,'PRODUCT',clin.product),TRUE);   



          -- 20221215 APEX_JSON.write('destination', clin.destination);

          APEX_JSON.write('destination',ajc_bc_account_dim_pkg.account_dim_required(clin.account,'DESTINATION',clin.destination),TRUE);   



          -- 20221215 APEX_JSON.write('office', clin.office);

          APEX_JSON.write('office',ajc_bc_account_dim_pkg.account_dim_required(clin.account,'OFFICE',clin.office),TRUE);   



          -- 20221215 APEX_JSON.write('origin', clin.origin);

          APEX_JSON.write('origin',ajc_bc_account_dim_pkg.account_dim_required(clin.account,'ORIGIN',clin.origin),TRUE); 



          -- 20221205 NO SE DEBE ENVIAR MAS APEX_JSON.write('intercompany', clin.intercompany);



          APEX_JSON.write('pdfFileUrl',clin.pdf_file_url, TRUE);



          APEX_JSON.close_object;



          v_body_line := APEX_JSON.get_clob_output;



          print_log('v_body_line: ' || v_body_line);                          



          v_clob_result_line := ajc_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url_line,

                                                                          p_request_header_name1 => 'Content-Type',

                                                                          p_request_header_value1 => 'application/json',

                                                                          p_request_header_name2 => NULL,

                                                                          p_request_header_value2 => NULL, 

                                                                          p_http_method => 'POST',

                                                                          p_body => v_body_line );  



          print_log('v_clob_result_line: ' || v_clob_result_line);



          APEX_JSON.free_output;



          IF ( INSTR(v_clob_result_line,'error') != 0 ) THEN



            print_log('Error al enviar la línea del comprobante.');



            v_error_message := 'Se produjo un error al enviar la línea: ' ||

                                SUBSTR(v_clob_result_line,INSTR(v_clob_result_line,'message') + 10);



            print_log(v_error_message);



            UPDATE AJC_BC_INC_AP_CERTIFY_LINES

               SET status = 'ERROR',

                   error_message = v_error_message,

                   json_data = v_body_line,

                   json_data_response = v_clob_result_line

             WHERE invoice_id = cinv.invoice_id

               AND line_number = clin.line_number

               AND request_id = gv_request_id;



            v_linea_con_error := 'Y';



          ELSE



            UPDATE AJC_BC_INC_AP_CERTIFY_LINES

               SET status = 'SENT',

                   json_data = v_body_line,

                   json_data_response = v_clob_result_line

             WHERE invoice_id = cinv.invoice_id

               AND line_number = clin.line_number

               AND request_id = gv_request_id;



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



        APEX_JSON.write('requestID', TO_CHAR(cinv.request_id));

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

        APEX_JSON.write('gLDate', TO_CHAR(cinv.gl_date,'YYYY-MM-DD'));

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

        APEX_JSON.write('company',ajc_bc_account_dim_pkg.account_dim_required(cinv.account,'COMPANY',cinv.company),TRUE);    



        APEX_JSON.write('account', cinv.account, TRUE ); 

        APEX_JSON.write('accountDescription', cinv.account_description, TRUE);



        -- 20221215 APEX_JSON.write('department', cinv.department , TRUE);

        APEX_JSON.write('department',ajc_bc_account_dim_pkg.account_dim_required(cinv.account,'DEPARTMENT',cinv.department),TRUE); 



        -- 20221215 APEX_JSON.write('product', cinv.product, TRUE); 

        APEX_JSON.write('product',ajc_bc_account_dim_pkg.account_dim_required(cinv.account,'PRODUCT',cinv.product),TRUE);



        -- 20221215 APEX_JSON.write('destination', cinv.destination, TRUE); 

        APEX_JSON.write('destination',ajc_bc_account_dim_pkg.account_dim_required(cinv.account,'DESTINATION',cinv.destination),TRUE);



        -- 20221215 APEX_JSON.write('origin', cinv.origin, TRUE);

        APEX_JSON.write('origin',ajc_bc_account_dim_pkg.account_dim_required(cinv.account,'ORIGIN',cinv.origin),TRUE);



        -- 20221205 NO SE DEBE ENVIAR MAS APEX_JSON.write('intercompany', cinv.intercompany, TRUE);

        -- Se debe enviar a nivel linea 

        -- APEX_JSON.write('pdfFileUrl',cinv.pdf_file_url, TRUE);

        --

        APEX_JSON.write('source', cinv.source, TRUE);



        -- 20221215 APEX_JSON.write('office', cinv.office, TRUE);

        APEX_JSON.write('office',ajc_bc_account_dim_pkg.account_dim_required(cinv.account,'OFFICE',cinv.office),TRUE); 



        APEX_JSON.close_object;

        v_body_header := APEX_JSON.get_clob_output;



        print_log(' ');

        print_log('v_body_header: ' || v_body_header);



        v_clob_result_header := ajc_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url_header,

                                                                          p_request_header_name1 => 'Content-Type',

                                                                          p_request_header_value1 => 'application/json',

                                                                          p_request_header_name2 => NULL,

                                                                          p_request_header_value2 => NULL, 

                                                                          p_http_method => 'POST',

                                                                          p_body => v_body_header );  





        print_log('v_clob_result_header: ' || v_clob_result_header);



        APEX_JSON.free_output;



        IF ( INSTR(v_clob_result_header,'error') != 0 ) THEN



          print_log('Error al enviar la cabecera del comprobante.');



          v_error_message := 'Se produjo un error al enviar la cabecera: ' ||

                              SUBSTR(v_clob_result_header,INSTR(v_clob_result_header,'message') + 10);



          print_log(v_error_message);



          UPDATE AJC_BC_INC_AP_CERTIFY_INVOICES

             SET status = 'ERROR',

                 error_message = v_error_message,

                 json_data = v_body_header,

                 json_data_response = v_clob_result_header

           WHERE invoice_id = cinv.invoice_id

             AND request_id = gv_request_id;



        ELSE



          UPDATE AJC_BC_INC_AP_CERTIFY_INVOICES

             SET status = 'SENT',

                 json_data = v_body_header,

                 json_data_response = v_clob_result_header

           WHERE invoice_id = cinv.invoice_id

             AND request_id = gv_request_id;



          print_log('El comprobante se envió correctamente.');



        END IF;



        p_invoice_count := NVL(p_invoice_count,0) + 1;



      ELSE



        UPDATE AJC_BC_INC_AP_CERTIFY_INVOICES

           SET status = 'ERROR',

               error_message = 'Se produjo un error en alguna línea del comprobante.'

         WHERE invoice_id = cinv.invoice_id

           AND request_id = gv_request_id;



      END IF;



    END LOOP;



    p_status := 'S';



    print_log('ajc_bc_inc_certify_pkg.call_ws (-)');



  EXCEPTION

    WHEN OTHERS THEN

      print_log('ajc_bc_inc_certify_pkg.call_ws (!)');

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

           AJC_BC_COMPANIES abcc

     WHERE abci.status = 'SENT'

       AND abci.request_id = gv_request_id

       AND abci.company = abcc.oracle_company_number;



    v_job_object_id     NUMBER;

    v_status            VARCHAR2(20);

    v_error_message     VARCHAR2(2000);

    v_clob_result_job   CLOB;



  BEGIN



    print_log ('ajc_bc_inc_certify_pkg.call_job (+)');



    FOR cc IN c_companies LOOP



      print_log ( 'company_id: ' || cc.company_id );



      v_job_object_id := ajc_bc_ws_utils_pkg.get_object_id_f ( 'PURCHASE INVOICES' );

      print_log ( 'v_job_object_id: ' || v_job_object_id );



      /* 20230908

      v_clob_result_job := ajc_bc_ws_utils_pkg.run_job_queue_token_v2_f ( p_environment => p_bc_environment

                                                                         ,p_company_id => cc.company_id

                                                                         ,p_object_id => v_job_object_id

                                                                         ,p_seconds_to_wait => gv_seconds_to_wait );

      */

      v_clob_result_job := ajc_bc_ws_utils_pkg.run_job_queue_f ( p_environment => p_bc_environment

                                                                ,p_company_id => cc.company_id

                                                                ,p_object_id => v_job_object_id

                                                                ,p_seconds_to_wait => gv_seconds_to_wait );

      -- 20230908



      IF ( INSTR(UPPER(v_clob_result_job),'SUCCESS') > 0 ) THEN



        print_log ( 'Se ejecutó el job Purchase Document con éxito.');

        v_status := 'SUCCESS';



      ELSE



        print_log ( 'Se produjo un error al ejecutar el job Purchase Document.');

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



    p_status := 'S';



    print_log ('ajc_bc_inc_certify_pkg.call_ws_job (-)');   



  EXCEPTION

    WHEN others THEN

        v_error_message := 'Error no atrapado al llamar Web Service de Job, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('ajc_bc_inc_certify_pkg.call_job (!)');



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

    SELECT DISTINCT abcc.bc_company_id company_id

      FROM AJC_BC_INC_AP_CERTIFY_INVOICES abci,

           AJC_BC_COMPANIES abcc

     WHERE abci.status = 'SENT'

       AND abci.request_id = gv_request_id

       AND abci.company = abcc.oracle_company_number;



    v_status               VARCHAR2(1);

    v_error_message        VARCHAR2(2000);



    -- 20230414 v_api_status           VARCHAR2(200) := 'inboundpurchaseintegrationstatusINE';

    v_api_status           VARCHAR2(200);

    v_get_url              VARCHAR2(2000);

    v_clob_result_status   CLOB;



    -- 20230414 v_api_delete_header    VARCHAR2(200) := 'inboundPurchaseHeaderINE';

    v_api_delete_header    VARCHAR2(200);



    -- 20230414 v_api_delete_lines     VARCHAR2(200) := 'inboundPurchaseLineINE';

    v_api_delete_lines     VARCHAR2(200);



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



    print_log ('ajc_bc_inc_certify_pkg.call_status (+)');



    v_api_status := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                                 p_subentity => 'STATUS',

                                                 p_method => 'GET' );

    print_log ('v_api_status: ' || v_api_status);



    v_api_delete_header := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                                           p_subentity => 'HEADERS',

                                                           p_method => 'DELETE' );

    print_log ('v_api_delete_header: ' || v_api_delete_header);



    v_api_delete_lines := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'PURCHASE INVOICES',

                                                          p_subentity => 'LINES',

                                                          p_method => 'DELETE' );

    print_log ('v_api_delete_lines: ' || v_api_delete_lines);



    FOR cc IN c_companies LOOP



      v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, cc.company_id ) || v_api_status

                   || '?$filter=requestID eq ' || gv_request_id

                   ; 



      print_log ( 'v_get_url: ' || v_get_url );



      v_clob_result_status := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );



      print_log ( 'v_clob_result_status: ' || v_clob_result_status );



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

                 error_message = cs.statusRemarks

           WHERE request_id = gv_request_id

             AND invoice_id = cs.invoiceID;



          -- Se actualiza la tabla desde la cual se levantan los invoices a procesar, para que sean reprocesados en la proxima ejecución

          -- UPDATE AJC_INC_EXPENSE_RPT_INT -- IMPLEMENTACION DEFINITIVA -- Descomentar

          UPDATE AJC_BC_INC_EXPENSE_RPT_INT -- IMPLEMENTACION TRANSITORIA -- Descomentar

             SET status = 'ERROR'

           WHERE oracle_invoice_num = cs.invoiceNo

             AND ( supplier_number = cs.vendorNo OR oracle_supplier_num = cs.vendorNo )

             -- AND TRUNC(creation_date) = TRUNC(SYSDATE)

             AND status = 'INTERFACED'

             ;



          -- Se arma la URL para borrar lineas de la tabla staging

          v_lines_delete_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, cc.company_id ) || v_api_delete_lines

                                -- || '?$filter=requestID eq ' || gv_request_id

                                || '(''' || cs.invoiceID || ''',0,0)' -- invoice id, request id, line no

                                ; 



          print_log ( 'v_lines_delete_url: ' || v_lines_delete_url );



          -- Se borran las lineas de la tabla staging

          v_lines_delete_clob := ajc_bc_ws_utils_pkg.delete_bc_row_f ( p_url => v_lines_delete_url );



          IF ( INSTR(v_lines_delete_clob,'error') != 0 )  THEN



            print_log('Error al borrar lineas de la tabla stage de BC');

            print_log(v_lines_delete_clob);



          ELSE



            print_log('Lineas borradas de la tabla stage de BC');



          END IF;  



          -- Se arma la URL para borrar cabecera de la tabla staging

          v_header_delete_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, cc.company_id ) || v_api_delete_header

                                 -- || '?$filter=requestID eq ' || gv_request_id

                                 || '(''' || cs.invoiceID || ''',0)' -- invoice id, request id

                                 ; 



          print_log ( 'v_header_delete_url: ' || v_header_delete_url );



          -- Se borra la cabecera de la tabla staging

          v_header_delete_clob := ajc_bc_ws_utils_pkg.delete_bc_row_f ( p_url => v_header_delete_url );



          IF ( INSTR(v_header_delete_clob,'error') != 0 )  THEN



            print_log('Error al borrar cabecera de la tabla stage de BC');

            print_log(v_header_delete_clob);



          ELSE



            print_log('Cabecera borrada de la tabla stage de BC');



          END IF; 



        ELSE



          -- Se actualiza la tabla custom con el status SUCCESS

          UPDATE AJC_BC_INC_AP_CERTIFY_INVOICES

             SET status = 'SUCCESS'

           WHERE request_id = gv_request_id

             AND invoice_id = cs.invoiceID;



        END IF;



      END LOOP;  



    END LOOP;



    p_status := 'S';



    print_log ('ajc_bc_inc_certify_pkg.call_status (-)');   



  EXCEPTION

    WHEN OTHERS THEN

        v_error_message := 'Error no atrapado al llamar Web Service de Status, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('ajc_bc_inc_certify_pkg.call_status (!)');



  END call_status;



  -- ------------------------------------------------------------------------------------------------------------------------

  -- AJC INC Delete Expense Report Files Older than 60 Days

  -- ------------------------------------------------------------------------------------------------------------------------

  PROCEDURE ajc_inc_del_expense_rpt_files ( p_status   OUT   VARCHAR2 ) IS



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



    print_log('ajc_inc_del_expense_rpt_files (+)');



    v_request_id := fnd_request.submit_request ( 'XXAJC'

                                                ,'AJC_INC_DELETE_EXP_RPT_FILES' ) ; 



    IF v_request_id = 0 THEN



      v_message := fnd_message.get;

      print_log('Error Ejecutando FND_REQUEST.SUBMIT_REQUEST. AJC_INC_DELETE_EXP_RPT_FILES. Error: ' || 

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

      print_log('Error Ejecutando FND_REQUEST.WAIT_FOR_REQUEST. AJC_INC_DELETE_EXP_RPT_FILES con nro. solicitud ' || 

                 TO_CHAR (v_request_id) || '. Error: ' || v_message || ' ' || SQLERRM);

      RAISE e_cust_exception;



    END IF ;



    IF v_conc_dev_phase != 'COMPLETE' OR v_conc_dev_status != 'NORMAL' THEN



      v_error_message := fnd_message.get;

      print_log('Error en la ejecucion del concurrente AJC_INC_DELETE_EXP_RPT_FILES con nro. solicitud ' || 

                 TO_CHAR (v_request_id) || '. Error: ' || v_error_message || ' ' || SQLERRM);

      RAISE e_cust_exception;



    END IF ; 



    p_status := 'S';



    print_log('ajc_inc_del_expense_rpt_files (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

      print_log('ajc_inc_del_expense_rpt_files (!)');

      p_status := 'E'; 



  END ajc_inc_del_expense_rpt_files;



  -- ------------------------------------------------------------------------------------------------------------------------

  -- Main

  -- ------------------------------------------------------------------------------------------------------------------------

  PROCEDURE main_p ( retcode                       OUT   NUMBER,

                     errbuf                        OUT   VARCHAR2,

                     -- p_file_prefix                  IN   VARCHAR2,

                     p_file_name                    IN   VARCHAR2,

                     p_gl_date                      IN   VARCHAR2,

                     p_american_express_supplier    IN   VARCHAR2,

                     p_travel_advance_account_num   IN   VARCHAR2,

                     p_bc_environment               IN   VARCHAR2 ) IS



    v_email              VARCHAR2(2000);



    v_status             VARCHAR2(1);

    e_error              EXCEPTION;

    v_gl_date            DATE;

    v_invoice_count      NUMBER := 0;

    v_lines_count        NUMBER := 0;

    v_error_message      VARCHAR2(2000);

    v_message            VARCHAR2(32000);



    -- 20230706

    v_execute_ftp_ldr    VARCHAR2(1);

    v_file_prefix        VARCHAR2(200);

    -- 20230706



    v_request_id_excel   NUMBER;



  BEGIN



    print_log('ajc_bc_inc_certify_pkg.main_p (+)');



    v_email := ajc_bc_ws_utils_pkg.get_emails_f ( 'CERTIFY' );

    -- v_email := 'sbanchieri@gmail.com'; -- QUITAR



    -- 20230228

    -- Se ejecuta el concurrente AJC BC Worksheets Interface

    ajc_bc_worksheets_pkg.caller_p ( p_bc_environment => p_bc_environment );



    -- 20230706

    -- Se verifica si el FTP y Loader ya corrieron para la fecha pasada como parametro

    -- Si ya corrieron, no se vuelven a correr y se ejecuta directamente el procesamiento de lo que hay en tabla

    SELECT DECODE(COUNT(1),0,'Y','N')

      INTO v_execute_ftp_ldr

      FROM fnd_concurrent_requests r,

           fnd_concurrent_programs_vl p

     WHERE r.concurrent_program_id = p.concurrent_program_id

       AND p.user_concurrent_program_name = 'AJC INC Ftp Expense Report File'

       AND TRUNC(r.requested_start_date) = TRUNC(TO_DATE(p_gl_date,'YYYY/MM/DD HH24:MI:SS'))

       AND r.phase_code = 'C'

       AND r.status_code = 'C'

       AND r.argument1 LIKE '%' || TO_CHAR(TO_DATE(p_gl_date,'YYYY/MM/DD HH24:MI:SS'),'YYYYMMDD') || '%';



    print_log('Execute FTP and Loader?: ' || v_execute_ftp_ldr);



    -- Solo se ejecuta FTP y Loader cuando no se ejecuto para la fecha pasada como parametro

    IF ( v_execute_ftp_ldr = 'Y' ) THEN

    -- 20230706



      -- Se arma el nombre del archivo a copiar del FTP, con la fecha pasada como parametro

      SELECT 'OracleUpload' || TO_CHAR(TO_DATE(p_gl_date,'YYYY/MM/DD HH24:MI:SS'),'YYYYMMDD') || '*' 

        INTO v_file_prefix

        FROM dual;



      print_log('v_file_prefix: ' || v_file_prefix);



      -- ------------------------------------------------------------------------------------------------------------------------

      -- FTP

      -- ------------------------------------------------------------------------------------------------------------------------

      ajc_inc_ftp_expense_rpt ( p_file_prefix => v_file_prefix,

                                p_status => v_status );                                           



      /* -- Se hace que no falle, para que procese lo que no se proceso aun que esta en tabla

      IF ( v_status != 'S' ) THEN



        RAISE e_error;



      END IF;

      */



      -- ------------------------------------------------------------------------------------------------------------------------

      -- Loader

      -- ------------------------------------------------------------------------------------------------------------------------                                            

      ajc_inc_load_expense_rpt_int ( p_file_name => p_file_name,

                                     p_status => v_status );



      /* -- Se hace que no falle, para que procese lo que no se proceso aun que esta en tabla

      IF ( v_status != 'S' ) THEN



        RAISE e_error;



      END IF;

      */



    -- 20230706

    END IF;

    -- 20230706



    v_gl_date := TO_DATE(p_gl_date,'YYYY/MM/DD HH24:MI:SS');



    -- 20230705

    -- ------------------------------------------------------------------------------------------------------------------------

    -- Transformaciones e Insert a tablas

    -- ------------------------------------------------------------------------------------------------------------------------

    expense_report_interface_p ( p_gl_date => v_gl_date,

                                 p_american_express_supplier => p_american_express_supplier,

                                 p_travel_advance_account_num => p_travel_advance_account_num,

                                 p_status => v_status );



    IF ( v_status != 'S' ) THEN



      RAISE e_error;



    END IF;



    print_log (' '); 



    -- WS para enviar la info a BC ---------------------------------------------------------------------------------------------

    call_ws ( p_status         => v_status

             ,p_invoice_count  => v_invoice_count

             ,p_lines_count    => v_lines_count

             ,p_bc_environment => p_bc_environment );



    IF ( v_status != 'S' ) THEN



      RAISE e_error;



    END IF;



    -- 20240702

    -- DBMS_LOCK.sleep(seconds => 15);

    -- 20240702



    -- Si se envió al menos un comprobante, se ejecuta el job

    IF ( v_invoice_count > 0 ) THEN



      print_log (' '); 

      -- Se ejecuta el JOB -----------------------------------------------------------------------------------------------------

      call_job ( p_status         => v_status

                ,p_error_message  => v_error_message

                ,p_bc_environment => p_bc_environment );



      IF v_status != 'S' THEN



        IF v_status = 'W' THEN



          retcode := 1;

          errbuf  := v_error_message;



        ELSE



          RAISE e_error;



        END IF;



      END IF;



      print_log ( 'v_lines_count: ' || v_lines_count );



      -- Se espera 0.5 segundos por cada linea procesada

      DBMS_LOCK.sleep(seconds => v_lines_count / 2);



      print_log (' '); 

      -- Verifico el status de las lineas procesadas por el job ----------------------------------------------------------------

      call_status ( p_status => v_status

                   ,p_error_message => v_error_message

                   ,p_bc_environment => p_bc_environment );



      IF v_status != 'S' THEN



        IF v_status = 'W' THEN



          retcode := 1;

          errbuf  := v_error_message;



        ELSE



          RAISE e_error;



        END IF;



      END IF;



      -- EXCEL REPORT ----------------------------------------------------------------------------------------------------------

      v_request_id_excel := ajc_bc_ws_utils_pkg.print_excel_report ( p_request_id => gv_request_id,  

                                                                     p_program => 'AJCBCINCCIR',

                                                                     p_template => 'AJCBCINCCIR' );



      print_log (' ');



      -- MAIL --------------------------------------------------------------------------------------------------------------------

      -- 20230317 send_email ( v_request_id_excel, p_mail );



      ajc_bc_ws_utils_pkg.send_unix_mail_attach ( p_mail => v_email,

                                                  p_report_request_id => v_request_id_excel ); 



    END IF;

    -- 20230705



    -- BORRADO ARCHIVOS --------------------------------------------------------------------------------------------------------

    /*  -- IMPLEMENTACION DEFINITIVA -- Descomentar

    ajc_inc_del_expense_rpt_files ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      RAISE e_error;



    END IF;

    */



    print_log('ajc_bc_inc_certify_pkg.main_p (-)');



  EXCEPTION

    WHEN e_error THEN

      print_log('main_p (!)');

      print_log('Error!');



  END main_p;



END ajc_bc_inc_certify_pkg;
