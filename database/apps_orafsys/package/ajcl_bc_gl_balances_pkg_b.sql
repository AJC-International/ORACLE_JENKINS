CREATE OR REPLACE PACKAGE BODY              ajcl_bc_gl_balances_pkg IS



  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    fnd_file.put_line (fnd_file.log, p_message);



  END print_log;



  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    fnd_file.put_line(fnd_file.output,p_message);



  END print_output;



  /*=========================================================================+

  | Function                                                                 |

  |    print_excel_report                                                    |

  +=========================================================================*/  

  FUNCTION print_excel_report ( p_argument1            IN   VARCHAR2,

                                p_argument2            IN   VARCHAR2,

                                p_program_short_code   IN   VARCHAR2 ) RETURN NUMBER IS



    v_request_id           NUMBER;

    v_message              VARCHAR2(2000);

    v_error_message        VARCHAR2(2000);

    e_cust_exception       EXCEPTION;

    v_conc_phase           VARCHAR2 (50);

    v_conc_status          VARCHAR2 (50);

    v_conc_dev_phase       VARCHAR2 (50);

    v_conc_dev_status      VARCHAR2 (50);

    v_conc_message         VARCHAR2 (250);



    v_template_appl_name   xdo_templates_b.application_short_name%TYPE;

    v_template_code        xdo_templates_b.template_code%TYPE;

    v_template_language    xdo_templates_b.default_language%TYPE;

    v_template_territory   xdo_templates_b.default_territory%TYPE;

    v_output_format        VARCHAR2(10);

    v_status_code          VARCHAR2(1);



  BEGIN



     BEGIN



       SELECT application_short_name, 

              template_code, 

              default_language, 

              default_territory, 

              'EXCEL'

         INTO v_template_appl_name,

              v_template_code,

              v_template_language,

              v_template_territory,

              v_output_format

         FROM xdo_templates_b

        WHERE template_code = p_program_short_code;



    EXCEPTION

      WHEN OTHERS THEN

        v_error_message := 'Error al buscar los datos del template correspondiente al código: ' || p_program_short_code || ': '||sqlerrm;

        v_status_code := 'W';

        RAISE e_cust_exception;



    END;  



    IF NOT fnd_request.add_layout ( template_appl_name  => v_template_appl_name,

                                    template_code       => v_template_code,

                                    template_language   => v_template_language,

                                    template_territory  => v_template_territory,

                                    output_format       => v_output_format ) THEN



      v_error_message := 'Error al setear el Template Publisher';

      v_status_code := 'E';

      RAISE e_cust_exception;



    END IF; 



    IF NOT fnd_request.set_options('NO','YES',NULL,NULL) THEN



      v_message := fnd_message.get;

      v_error_message := 'Error ejecutando FND_REQUEST.SET_OPTIONS. ' || v_message || ' ' || sqlerrm;

      v_status_code := 'W';

      RAISE e_cust_exception;



    END IF;



    -- Submit Report

    IF ( p_argument2 IS NULL ) THEN



      v_request_id := fnd_request.submit_request ( 'XXAJC'

                                                  ,p_program_short_code

                                                  ,argument1 => p_argument1 ) ;



    ELSE



      v_request_id := fnd_request.submit_request ( 'XXAJC'

                                                  ,p_program_short_code

                                                  ,argument1 => p_argument1

                                                  ,argument2 => p_argument2 ) ; 



    END IF;



    IF v_request_id = 0 THEN



      v_message := fnd_message.get;

      print_log('Error Ejecutando FND_REQUEST.SUBMIT_REQUEST. ' || p_program_short_code || '. Error: ' || v_message || ', ' || SQLERRM);

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

      print_log('Error Ejecutando FND_REQUEST.WAIT_FOR_REQUEST. ' || p_program_short_code || ' con nro. solicitud ' || 

                TO_CHAR (v_request_id) || '. Error: ' || v_message || ' ' || SQLERRM);

      RAISE e_cust_exception;



    END IF ;



    IF v_conc_dev_phase != 'COMPLETE' OR v_conc_dev_status != 'NORMAL' THEN



      v_error_message := fnd_message.get;

      print_log('Error en la ejecucion del concurrente ' || p_program_short_code || ' con nro. solicitud ' || 

                TO_CHAR (v_request_id) || '. Error: ' || v_error_message || ' ' || SQLERRM);

      RAISE e_cust_exception;



    END IF ; 



    RETURN v_request_id;



  END print_excel_report;



  /*=========================================================================+

  | Function                                                                 |

  |    get_period_year                                                       |

  +=========================================================================*/

  FUNCTION get_period_year ( pc_oracle_company   IN   VARCHAR2,

                             p_date              IN   DATE,

                             p_oracle_company    IN   VARCHAR2 -- Se agrega y se envia el parametro original del request

                             ) RETURN NUMBER IS



    v_period_year   NUMBER;



  BEGIN



    print_log ('ajcl_bc_gl_balances_pkg.get_period_year (+)' );



    IF ( p_oracle_company IS NOT NULL ) THEN



      BEGIN



          SELECT gp.period_year

            INTO v_period_year

            FROM ajc_bc_companies bcc,

                 gl_sets_of_books gsob,

                 gl_periods gp

           WHERE bcc.oracle_company_number = pc_oracle_company

             AND bcc.set_of_books_id = gsob.set_of_books_id 

             AND gsob.period_set_name = gp.period_set_name

             AND gp.end_date = p_date

        GROUP BY gp.period_year;



      EXCEPTION

        WHEN OTHERS THEN



          SELECT gp.period_year

            INTO v_period_year

            FROM ajc_bc_companies bcc,

                 gl_sets_of_books gsob,

                 gl_periods gp

           WHERE bcc.oracle_company_number = '13' -- Para el consolidado se usa la 13

             AND bcc.set_of_books_id = gsob.set_of_books_id 

             AND gsob.period_set_name = gp.period_set_name

             AND gp.end_date = p_date

        GROUP BY gp.period_year;



        RETURN v_period_year;



      END;



    ELSE

      -- Si el parametro se envio sin valor, es para el consolidado



        SELECT gp.period_year

          INTO v_period_year

          FROM gl_sets_of_books gsob,

               gl_periods gp

         WHERE gsob.set_of_books_id = 203

           AND gsob.period_set_name = gp.period_set_name

           AND gp.end_date = p_date

      GROUP BY gp.period_year;



    END IF;



    print_log ('ajcl_bc_gl_balances_pkg.get_period_year (-)' );



    RETURN v_period_year;



  EXCEPTION 

    WHEN OTHERS THEN

      print_log ('ajcl_bc_gl_balances_pkg.get_period_year (!)' );



  END get_period_year;



  /*=========================================================================+

  | Function                                                                 |

  |    translated_ending_balance                                             |

  +=========================================================================*/

  FUNCTION translated_ending_balance ( p_set_of_books_id       IN   NUMBER,

                                       p_period_set_name       IN   VARCHAR2,

                                       p_period_year           IN   NUMBER,

                                       p_code_combination_id   IN   NUMBER ) RETURN NUMBER IS



    v_translated_ending_balance   NUMBER;



  BEGIN



    SELECT translated_ending_balance

      INTO v_translated_ending_balance

      FROM ( SELECT SUM(t.begin_debits - t.begin_credits) + SUM(t.debits) - SUM(t.credits) translated_ending_balance

               FROM ( SELECT DECODE(gp.period_num,1,gb.begin_balance_dr,0) begin_debits,

                             DECODE(gp.period_num,1,gb.begin_balance_cr,0) begin_credits,

                             gb.period_net_dr debits,

                             gb.period_net_cr credits

                        FROM gl_balances gb,

                             gl_code_combinations gcc,

                             gl_periods gp

                       WHERE gb.code_combination_id = p_code_combination_id

                         AND gcc.code_combination_id = p_code_combination_id

                         AND gb.set_of_books_id = p_set_of_books_id

                         AND gp.period_set_name = p_period_set_name

                         AND gp.period_name = gb.period_name

                         AND gb.actual_flag = 'A'

                         AND nvl(gb.translated_flag,'X') = 'Y'

                         AND gb.template_id IS NULL

                         AND gb.currency_code = 'USD'

                         AND gp.period_year = p_period_year ) t );



    RETURN v_translated_ending_balance;



  EXCEPTION 

    WHEN OTHERS THEN

      print_log ('ajcl_bc_gl_balances_pkg.translated_ending_balance (!). Error: ' || SQLERRM );



  END translated_ending_balance;



  /*=========================================================================+

  | Procedure                                                                |

  |    YTD                                                                   |

  +=========================================================================*/

  PROCEDURE year_to_date_ytd ( retcode               OUT   NUMBER,

                               errbuf                OUT   VARCHAR2,

                               p_oracle_company       IN   VARCHAR2,

                               p_oracle_account       IN   VARCHAR2,

                               p_end_date             IN   VARCHAR2,

                               p_currency_code        IN   VARCHAR2,

                               p_delete_final_table   IN   VARCHAR2,

                               p_bc_environment       IN   VARCHAR2 ) IS



    -- 20230718

      CURSOR c_companies ( p_oracle_company   IN   VARCHAR2 ) IS

      SELECT segment1 company

        FROM gl_code_combinations

       WHERE segment1 = NVL(p_oracle_company,segment1)

    GROUP BY segment1

    ORDER BY segment1;

    -- 20230718



    CURSOR c_ytd ( pc_oracle_company   IN   VARCHAR2,

                   pc_oracle_account   IN   VARCHAR2,

                   pc_period_year      IN   NUMBER,

                   pc_currency_code    IN   VARCHAR2 ) IS

    -- Consolidado

    -- Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

    /*

    SELECT *

      FROM ( SELECT company,

                    account,

                    dept,

                    product, 

                    dest,

                    origin, 

                    bc_company,

                    NVL(bc_account,'XXXX.' || account) bc_account,

                    bc_dept,

                    bc_product,

                    bc_dest,

                    bc_office,

                    bc_origin,

                    beginning_balance, 

                    debits,

                    credits,

                    ending_balance,

                    CASE 

                      WHEN pc_currency_code = 'USD' THEN

                        ending_balance

                      ELSE

                        ajcl_bc_gl_balances_pkg.translated_ending_balance ( p_set_of_books_id => set_of_books_id,

                                                                           p_period_set_name => period_set_name,

                                                                           p_period_year => period_year,

                                                                           p_code_combination_id => code_combination_id ) 

                    END translated_ending_balance 

               FROM ( SELECT -- ORACLE

                             t.company,

                             t.account,

                             t.dept,

                             t.product, 

                             t.dest,

                             t.origin, 

                             -- BC

                             t.company bc_company,

                             aba.bc_account bc_account,

                             t.dept bc_dept,

                             DECODE(

                             ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4'

                                                                                 ,p_oracle_value   => t.product

                                                                                 ,p_bc_dimension   => 'DIVISION' )

                               ,NULL,t.product,'000') bc_product,

                             DECODE(

                             ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                 ,p_oracle_value => t.dest

                                                                                 ,p_bc_dimension => 'OFFICE' )

                               ,NULL,t.dest,'000') bc_dest, 

                             NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                     ,p_oracle_value => t.dest

                                                                                     ,p_bc_dimension => 'OFFICE'),'000') bc_office,          

                             t.origin bc_origin,

                             SUM(t.begin_debits - t.begin_credits) beginning_balance, 

                             SUM(t.debits) debits,

                             SUM(t.credits) credits,

                             SUM(t.begin_debits - t.begin_credits) + SUM(t.debits) - SUM(t.credits) ending_balance,

                             t.code_combination_id,

                             t.set_of_books_id,

                             t.period_set_name,

                             t.period_year

                        FROM ajc.ajc_bc_accounts aba,

                             ( SELECT gcc.segment1 company,

                                      gcc.segment2 account,

                                      gcc.segment3 dept,

                                      gcc.segment4 product,

                                      gcc.segment5 dest,

                                      gcc.segment6 origin,

                                      DECODE(gp.period_num,1,gb.begin_balance_dr,0) begin_debits,

                                      DECODE(gp.period_num,1,gb.begin_balance_cr,0) begin_credits,

                                      gb.period_net_dr debits,

                                      gb.period_net_cr credits,

                                      gcc.code_combination_id,

                                      gsob.set_of_books_id,

                                      gsob.period_set_name,

                                      gp.period_year

                                 FROM gl_balances gb

                                     ,gl_code_combinations_kfv gcc

                                     ,gl_sets_of_books gsob

                                     ,gl_periods gp

                                     ,gl_sets_of_books_dfv gsob_dfv

                                     -- 20230705 ,ajc_bc_companies bcc

                                WHERE gb.code_combination_id = gcc.code_combination_id

                                  AND gcc.enabled_flag = 'Y'

                                  AND gb.set_of_books_id = gsob.set_of_books_id

                                  AND gp.period_set_name = gsob.period_set_name

                                  AND gp.period_name = gb.period_name

                                  AND gb.actual_flag = 'A'

                                  AND nvl(gb.translated_flag,'X') = 'X'

                                  AND gb.template_id IS NULL

                                  AND gb.currency_code = gsob.currency_code

                                  AND gsob.rowid = gsob_dfv.row_id

                                  AND gcc.segment1 NOT IN ('95')

                                  -- 20230705 - Se comenta para sacar el consolidado

                                  -- AND gsob.name not in ('AJC CONS CALENDAR YEAR', 'AJC CONSOLIDATED', 'GLOBAL CHF CONSOLIDATED')

                                  --

                                  AND gcc.segment1 = NVL(pc_oracle_company,gcc.segment1)

                                  AND gcc.segment2 = NVL(pc_oracle_account,gcc.segment2)

                                  AND gcc.segment2 NOT IN ('1152')

                                  AND gb.currency_code = pc_currency_code

                                  -- 20230705 - Se comenta para sacar el consolidado

                                  -- AND gcc.segment1 = bcc.oracle_company_number

                                  -- AND bcc.set_of_books_id = gsob.set_of_books_id

                                  -- 20230705 - Se agrega para sacar el consolidado

                                  AND gsob.set_of_books_id = 203

                                  AND p_oracle_company IS NULL

                                  -- 20230705 

                                  AND gp.period_year = NVL(pc_period_year,gp.period_year) ) t         

                       WHERE t.account = aba.oracle_account (+)

                    GROUP BY t.company,

                             t.account,

                             aba.bc_account,

                             t.dept,

                             t.product,

                             t.dest,

                             t.origin

                             ,t.code_combination_id

                             ,t.set_of_books_id

                             ,t.period_set_name

                             ,t.period_year ) ) 

           WHERE NOT ( ending_balance = 0 AND translated_ending_balance = 0 )

     UNION ALL 

     */

     -- End Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

     -- Por org

     SELECT *

       FROM ( SELECT company,

                     account,

                     dept,

                     product, 

                     dest,

                     origin, 

                     bc_company,

                     NVL(bc_account,'XXXX.' || account) bc_account,

                     bc_dept,

                     bc_product,

                     -- Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

                     bc_division,

                     -- End Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

                     bc_dest,

                     bc_office,

                     bc_origin,

                     beginning_balance, 

                     debits,

                     credits,

                     ending_balance,

                     CASE 

                       WHEN pc_currency_code = 'USD' THEN

                         ending_balance

                       ELSE

                         ajcl_bc_gl_balances_pkg.translated_ending_balance ( p_set_of_books_id => set_of_books_id,

                                                                            p_period_set_name => period_set_name,

                                                                            p_period_year => period_year,

                                                                            p_code_combination_id => code_combination_id ) 

                     END translated_ending_balance 

                FROM ( SELECT -- ORACLE

                              t.company,

                              t.account,

                              t.dept,

                              t.product, 

                              t.dest,

                              t.origin, 

                              -- BC

                              t.company bc_company,

                              aba.bc_account bc_account,

                              t.dept bc_dept,

                              DECODE(

                              ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4'

                                                                                  ,p_oracle_value   => t.product

                                                                                  ,p_bc_dimension   => 'DIVISION' )

                                ,NULL,t.product,'000') bc_product,

                              NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4'

                                                                                      ,p_oracle_value => t.product

                                                                                      ,p_bc_dimension => 'DIVISION'),'000') bc_division,                                

                              -- Modified KHRONUS/PBonadeo 20240717: AJCL BC Implementation: Office vs Dest Mapping

                              /*

                              DECODE(

                              ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                  ,p_oracle_value => t.dest

                                                                                  ,p_bc_dimension => 'OFFICE' )

                                ,NULL,t.dest,'000') bc_dest, 

                              NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                      ,p_oracle_value => t.dest

                                                                                      ,p_bc_dimension => 'OFFICE'),'000') bc_office,  

                              */

                              CASE WHEN t.account BETWEEN '6000' AND '9999' THEN 

                                DECODE(

                                ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                  ,p_oracle_value => t.dest

                                                                                  ,p_bc_dimension => 'OFFICE' )

                                ,NULL,t.dest,'000')                                 

                              ELSE

                                t.dest

                              END bc_dest, 

                              CASE WHEN t.account BETWEEN '6000' AND '9999' THEN                               

                                NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                      ,p_oracle_value => t.dest

                                                                                      ,p_bc_dimension => 'OFFICE'),'000') 

                              ELSE

                                '000'                                                                                      

                              END bc_office,                              

                              -- End Modified KHRONUS/PBonadeo 20240717: AJCL BC Implementation: Office vs Dest Mapping

                              t.origin bc_origin,

                              SUM(t.begin_debits - t.begin_credits) beginning_balance, 

                              SUM(t.debits) debits,

                              SUM(t.credits) credits,

                              SUM(t.begin_debits - t.begin_credits) + SUM(t.debits) - SUM(t.credits) ending_balance,

                              t.code_combination_id,

                              t.set_of_books_id,

                              t.period_set_name,

                              t.period_year

                         FROM ajc.ajc_bc_accounts aba,

                              ( SELECT gcc.segment1 company,

                                       gcc.segment2 account,

                                       gcc.segment3 dept,

                                       gcc.segment4 product,

                                       gcc.segment5 dest,

                                       gcc.segment6 origin,

                                       DECODE(gp.period_num,1,gb.begin_balance_dr,0) begin_debits,

                                       DECODE(gp.period_num,1,gb.begin_balance_cr,0) begin_credits,

                                       gb.period_net_dr debits,

                                       gb.period_net_cr credits,

                                       gcc.code_combination_id,

                                       gsob.set_of_books_id,

                                       gsob.period_set_name,

                                       gp.period_year

                                  FROM gl_balances gb

                                      ,gl_code_combinations_kfv gcc

                                      ,gl_sets_of_books gsob

                                      ,gl_periods gp

                                      ,gl_sets_of_books_dfv gsob_dfv

                                      ,ajc_bc_companies bcc

                                 WHERE gb.code_combination_id = gcc.code_combination_id

                                   AND gcc.enabled_flag = 'Y'

                                   AND gb.set_of_books_id = gsob.set_of_books_id

                                   AND gp.period_set_name = gsob.period_set_name

                                   AND gp.period_name = gb.period_name

                                   AND gb.actual_flag = 'A'

                                   AND nvl(gb.translated_flag,'X') = 'X'

                                   AND gb.template_id IS NULL

                                   AND gb.currency_code = gsob.currency_code

                                   AND gsob.rowid = gsob_dfv.row_id

                                   AND gcc.segment1 NOT IN ('95')

                                   -- 20230705 - Se comenta para sacar el consolidado

                                   -- AND gsob.name not in ('AJC CONS CALENDAR YEAR', 'AJC CONSOLIDATED', 'GLOBAL CHF CONSOLIDATED')

                                   --

                                   AND gcc.segment1 = NVL(pc_oracle_company,gcc.segment1)

                                   AND gcc.segment2 = NVL(pc_oracle_account,gcc.segment2)

                                   AND gcc.segment2 NOT IN ('1152')

                                   AND gb.currency_code = pc_currency_code

                                   -- 20230705 - Se comenta para sacar el consolidado

                                   AND gcc.segment1 = bcc.oracle_company_number

                                   AND bcc.set_of_books_id = gsob.set_of_books_id

                                   -- 20230705 - Se agrega para sacar el consolidado

                                   -- AND gsob.set_of_books_id = 203

                                   AND p_oracle_company IS NOT NULL

                                   -- 20230705 

                                   AND gp.period_year = NVL(pc_period_year,gp.period_year) ) t         

                        WHERE t.account = aba.oracle_account (+)

                     GROUP BY t.company,

                              t.account,

                              aba.bc_account,

                              t.dept,

                              t.product,

                              t.dest,

                              t.origin

                              ,t.code_combination_id

                              ,t.set_of_books_id

                              ,t.period_set_name

                              ,t.period_year ) ) 

            WHERE NOT ( ending_balance = 0 AND translated_ending_balance = 0 );



    v_concurrent_status   BOOLEAN;

    v_period_year         NUMBER;

    v_period_year_real    NUMBER;

    v_request_id_excel    NUMBER;



    -- Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

    /*

    CURSOR c_missing_accounts ( pc_oracle_company   IN   VARCHAR2,

                                pc_oracle_account   IN   VARCHAR2,

                                pc_period_year      IN   NUMBER,

                                pc_currency_code    IN   VARCHAR2 ) IS

    -- Consolidado

    SELECT *

      FROM ( SELECT company,

                    account,

                    dept,

                    product, 

                    dest,

                    origin, 

                    bc_company,

                    NVL(bc_account,'XXXX.' || account) bc_account,

                    bc_dept,

                    bc_product,

                    bc_dest,

                    bc_office,

                    bc_origin,

                    0 beginning_balance, 

                    0 debits,

                    0 credits,

                    0 ending_balance,

                    ajcl_bc_gl_balances_pkg.translated_ending_balance ( p_set_of_books_id => set_of_books_id,

                                                                       p_period_set_name => period_set_name,

                                                                       p_period_year => period_year,

                                                                       p_code_combination_id => code_combination_id ) translated_ending_balance 

               FROM ( SELECT -- ORACLE

                             t.company,

                             t.account,

                             t.dept,

                             t.product, 

                             t.dest,

                             t.origin, 

                             -- BC

                             t.company bc_company,

                             aba.bc_account bc_account,

                             t.dept bc_dept,

                             DECODE(

                             ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4'

                                                                                 ,p_oracle_value   => t.product

                                                                                 ,p_bc_dimension   => 'DIVISION' )

                               ,NULL,t.product,'000') bc_product,

                             DECODE(

                             ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                 ,p_oracle_value => t.dest

                                                                                 ,p_bc_dimension => 'OFFICE' )

                               ,NULL,t.dest,'000') bc_dest, 

                             NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                     ,p_oracle_value => t.dest

                                                                                     ,p_bc_dimension => 'OFFICE'),'000') bc_office,          

                             t.origin bc_origin,

                             SUM(t.begin_debits - t.begin_credits) beginning_balance, 

                             SUM(t.debits) debits,

                             SUM(t.credits) credits,

                             SUM(t.begin_debits - t.begin_credits) + SUM(t.debits) - SUM(t.credits) ending_balance,

                             t.code_combination_id,

                             t.set_of_books_id,

                             t.period_set_name,

                             t.period_year

                        FROM ajc.ajc_bc_accounts aba,

                             ( SELECT gcc.segment1 company,

                                      gcc.segment2 account,

                                      gcc.segment3 dept,

                                      gcc.segment4 product,

                                      gcc.segment5 dest,

                                      gcc.segment6 origin,

                                      DECODE(gp.period_num,1,gb.begin_balance_dr,0) begin_debits,

                                      DECODE(gp.period_num,1,gb.begin_balance_cr,0) begin_credits,

                                      gb.period_net_dr debits,

                                      gb.period_net_cr credits,

                                      gcc.code_combination_id,

                                      gsob.set_of_books_id,

                                      gsob.period_set_name,

                                      gp.period_year

                                 FROM gl_balances gb

                                     ,gl_code_combinations_kfv gcc

                                     ,gl_sets_of_books gsob

                                     ,gl_periods gp

                                     ,gl_sets_of_books_dfv gsob_dfv

                                     --,ajc_bc_companies bcc

                                WHERE gb.code_combination_id = gcc.code_combination_id

                                  AND gcc.enabled_flag = 'Y'

                                  AND gb.set_of_books_id = gsob.set_of_books_id

                                  AND gp.period_set_name = gsob.period_set_name

                                  AND gp.period_name = gb.period_name

                                  AND gb.actual_flag = 'A'

                                  AND nvl(gb.translated_flag,'X') = 'Y'

                                  AND gb.template_id IS NULL

                                  AND gsob.rowid = gsob_dfv.row_id

                                  AND gcc.segment1 NOT IN ('95')

                                  -- 20230705 - Se comenta para sacar el consolidado

                                  -- AND gsob.name not in ('AJC CONS CALENDAR YEAR', 'AJC CONSOLIDATED', 'GLOBAL CHF CONSOLIDATED')

                                  AND gcc.segment1 = NVL(pc_oracle_company,gcc.segment1)

                                  AND gcc.segment2 NOT IN ('1152')

                                  AND gb.currency_code = 'USD'

                                  -- 20230705 - Se comenta para sacar el consolidado

                                  -- AND gcc.segment1 = bcc.oracle_company_number

                                  -- AND bcc.set_of_books_id = gsob.set_of_books_id

                                  -- 20230705 - Se agrega para sacar el consolidado

                                  AND gsob.set_of_books_id = 203

                                  AND p_oracle_company IS NULL

                                  -- 20230705 

                                  AND gp.period_year = NVL(pc_period_year,gp.period_year) ) t         

                       WHERE t.account = aba.oracle_account (+)

                    GROUP BY t.company,

                             t.account,

                             aba.bc_account,

                             t.dept,

                             t.product,

                             t.dest,

                             t.origin

                             ,t.code_combination_id

                             ,t.set_of_books_id

                             ,t.period_set_name

                             ,t.period_year ) ) a 

           -- no fue insertada para otra moneda, misma compania, cuenta y año

           WHERE NOT EXISTS ( SELECT 1 

                                FROM ajcl_bc_gl_balances_ytd bc 

                               WHERE bc.oracle_company = a.company 

                                 AND bc.oracle_account = a.account

                                 AND currency_code != 'USD'

                                 AND period_year = pc_period_year )

             AND translated_ending_balance != 0

     UNION ALL

     -- Por org

     SELECT *

      FROM ( SELECT company,

                    account,

                    dept,

                    product, 

                    dest,

                    origin, 

                    bc_company,

                    NVL(bc_account,'XXXX.' || account) bc_account,

                    bc_dept,

                    bc_product,

                    bc_dest,

                    bc_office,

                    bc_origin,

                    0 beginning_balance, 

                    0 debits,

                    0 credits,

                    0 ending_balance,

                    ajcl_bc_gl_balances_pkg.translated_ending_balance ( p_set_of_books_id => set_of_books_id,

                                                                       p_period_set_name => period_set_name,

                                                                       p_period_year => period_year,

                                                                       p_code_combination_id => code_combination_id ) translated_ending_balance 

               FROM ( SELECT -- ORACLE

                             t.company,

                             t.account,

                             t.dept,

                             t.product, 

                             t.dest,

                             t.origin, 

                             -- BC

                             t.company bc_company,

                             aba.bc_account bc_account,

                             t.dept bc_dept,

                             DECODE(

                             ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4'

                                                                                 ,p_oracle_value   => t.product

                                                                                 ,p_bc_dimension   => 'DIVISION' )

                               ,NULL,t.product,'000') bc_product,

                             DECODE(

                             ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                 ,p_oracle_value => t.dest

                                                                                 ,p_bc_dimension => 'OFFICE' )

                               ,NULL,t.dest,'000') bc_dest, 

                             NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                     ,p_oracle_value => t.dest

                                                                                     ,p_bc_dimension => 'OFFICE'),'000') bc_office,          

                             t.origin bc_origin,

                             SUM(t.begin_debits - t.begin_credits) beginning_balance, 

                             SUM(t.debits) debits,

                             SUM(t.credits) credits,

                             SUM(t.begin_debits - t.begin_credits) + SUM(t.debits) - SUM(t.credits) ending_balance,

                             t.code_combination_id,

                             t.set_of_books_id,

                             t.period_set_name,

                             t.period_year

                        FROM ajc.ajc_bc_accounts aba,

                             ( SELECT gcc.segment1 company,

                                      gcc.segment2 account,

                                      gcc.segment3 dept,

                                      gcc.segment4 product,

                                      gcc.segment5 dest,

                                      gcc.segment6 origin,

                                      DECODE(gp.period_num,1,gb.begin_balance_dr,0) begin_debits,

                                      DECODE(gp.period_num,1,gb.begin_balance_cr,0) begin_credits,

                                      gb.period_net_dr debits,

                                      gb.period_net_cr credits,

                                      gcc.code_combination_id,

                                      gsob.set_of_books_id,

                                      gsob.period_set_name,

                                      gp.period_year

                                 FROM gl_balances gb

                                     ,gl_code_combinations_kfv gcc

                                     ,gl_sets_of_books gsob

                                     ,gl_periods gp

                                     ,gl_sets_of_books_dfv gsob_dfv

                                     ,ajc_bc_companies bcc

                                WHERE gb.code_combination_id = gcc.code_combination_id

                                  AND gcc.enabled_flag = 'Y'

                                  AND gb.set_of_books_id = gsob.set_of_books_id

                                  AND gp.period_set_name = gsob.period_set_name

                                  AND gp.period_name = gb.period_name

                                  AND gb.actual_flag = 'A'

                                  AND nvl(gb.translated_flag,'X') = 'Y'

                                  AND gb.template_id IS NULL

                                  AND gsob.rowid = gsob_dfv.row_id

                                  AND gcc.segment1 NOT IN ('95')

                                  -- 20230705 - Se comenta para sacar el consolidado

                                  -- AND gsob.name not in ('AJC CONS CALENDAR YEAR', 'AJC CONSOLIDATED', 'GLOBAL CHF CONSOLIDATED')

                                  AND gcc.segment1 = NVL(pc_oracle_company,gcc.segment1)

                                  AND gcc.segment2 NOT IN ('1152')

                                  AND gb.currency_code = 'USD'

                                  -- 20230705 - Se comenta para sacar el consolidado

                                  AND gcc.segment1 = bcc.oracle_company_number

                                  AND bcc.set_of_books_id = gsob.set_of_books_id

                                  -- 20230705 - Se agrega para sacar el consolidado

                                  -- AND gsob.set_of_books_id = 203

                                  AND p_oracle_company IS NOT NULL

                                  -- 20230705 

                                  AND gp.period_year = NVL(pc_period_year,gp.period_year) ) t         

                       WHERE t.account = aba.oracle_account (+)

                    GROUP BY t.company,

                             t.account,

                             aba.bc_account,

                             t.dept,

                             t.product,

                             t.dest,

                             t.origin

                             ,t.code_combination_id

                             ,t.set_of_books_id

                             ,t.period_set_name

                             ,t.period_year ) ) a 

           -- no fue insertada para otra moneda, misma compania, cuenta y año

           WHERE NOT EXISTS ( SELECT 1 

                                FROM ajcl_bc_gl_balances_ytd bc 

                               WHERE bc.oracle_company = a.company 

                                 AND bc.oracle_account = a.account

                                 AND currency_code != 'USD'

                                 AND period_year = pc_period_year )

             AND translated_ending_balance != 0;

    */

    -- End Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation



  BEGIN



    print_log ('ajcl_bc_gl_balances_pkg.year_to_date_ytd (+)' );



    print_log ( 'p_oracle_company: ' || p_oracle_company );

    print_log ( 'p_oracle_account: ' || p_oracle_account );

    print_log ( 'p_end_date: ' || p_end_date );

    print_log ( 'p_currency_code: ' || p_currency_code );

    print_log ( 'p_delete_final_table: ' || p_delete_final_table );



    -- Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

    --ajcl_bc_accounts_pkg.caller_p ( p_bc_environment => p_bc_environment );

    -- End Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation



    -- 20230718

    FOR cc IN c_companies ( p_oracle_company => p_oracle_company ) LOOP

    -- 20230718



      print_log ( 'company: ' || cc.company );



      v_period_year := ajcl_bc_gl_balances_pkg.GET_PERIOD_YEAR ( -- 20230718 p_oracle_company,

                                                                cc.company,

                                                                -- 20230718

                                                                TO_DATE(p_end_date,'DD-MON-YY'),

                                                                --

                                                                p_oracle_company

                                                                );

      print_log ( 'v_period_year: ' || v_period_year );



      v_period_year_real := TO_NUMBER(TO_CHAR(TO_DATE(p_end_date,'DD-MON-YY'),'YYYY'));

      print_log ( 'v_period_year_real: ' || v_period_year_real );    



      IF ( p_delete_final_table = 'Y' ) THEN



        DELETE ajcl_bc_gl_balances_ytd

         WHERE 1 = 1 

           -- 20230718

           -- AND oracle_company = NVL(p_oracle_company,oracle_company)

           AND oracle_company = cc.company

           -- 20230718

           AND oracle_account = NVL(p_oracle_account,oracle_account)

           AND period_year = v_period_year_real

           AND currency_code = p_currency_code;



        print_log ('Se borra de la tabla ajcl_bc_gl_balances_ytd..');

        print_log ('company: ' || p_oracle_company);



        IF ( p_oracle_account IS NOT NULL ) THEN



          print_log ('account: ' || p_oracle_account);



        END IF;



        print_log (' '); 



        print_log ('Cantidad registros borrados: ' || SQL%ROWCOUNT );



        COMMIT;



      END IF;



      FOR cytd IN c_ytd ( -- 20230718 

                          -- p_oracle_company,

                          cc.company,

                          -- 20230718 

                          p_oracle_account,

                          v_period_year,

                          p_currency_code ) LOOP



        INSERT 

          INTO ajcl_bc_gl_balances_ytd

             ( oracle_company,

               oracle_account,

               oracle_dept,

               oracle_product,

               oracle_dest,

               oracle_origin,

               bc_company,

               bc_account,

               bc_dept,

               bc_product,

               -- Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

               bc_division,

               -- End Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

               bc_dest,

               bc_office,

               bc_origin,

               beginning_balance,

               debits,

               credits,

               ending_balance,

               request_id,

               period_year,

               currency_code,

               translated_ending_balance )

      VALUES ( cytd.company,

               cytd.account,

               cytd.dept,

               cytd.product, 

               cytd.dest,

               cytd.origin, 

               ajcl_bc_accounts_pkg.account_dim_required(p_bc_environment, cytd.bc_account,'COMPANY',cytd.bc_company),

               cytd.bc_account,

               ajcl_bc_accounts_pkg.account_dim_required(p_bc_environment, cytd.bc_account,'DEPARTMENT',cytd.bc_dept),

               ajcl_bc_accounts_pkg.account_dim_required(p_bc_environment, cytd.bc_account,'PRODUCT',cytd.bc_product),

               -- Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

               ajcl_bc_accounts_pkg.account_dim_required(p_bc_environment, cytd.bc_account,'DIVISION',cytd.bc_division),

               -- End Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation               

               ajcl_bc_accounts_pkg.account_dim_required(p_bc_environment, cytd.bc_account,'DESTINATION',cytd.bc_dest),

               ajcl_bc_accounts_pkg.account_dim_required(p_bc_environment, cytd.bc_account,'OFFICE',cytd.bc_office),

               ajcl_bc_accounts_pkg.account_dim_required(p_bc_environment, cytd.bc_account,'ORIGIN',cytd.bc_origin),

               cytd.beginning_balance, 

               cytd.debits,

               cytd.credits,

               cytd.ending_balance,

               gv_request_id,

               v_period_year_real,

               p_currency_code,

               cytd.translated_ending_balance );



      END LOOP; 



      COMMIT;



      -- Se inserta registro para las cuentas que no levanta el query principal, porque no existen registros en gl_balances con moneda

      -- igual al parametro, pero si existen registros en USD

      -- Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

      /*

      IF ( p_currency_code != 'USD' ) THEN



        FOR cytd IN c_missing_accounts ( -- 20230718 

                                         -- p_oracle_company,

                                         cc.company,

                                         -- 20230718 

                                         p_oracle_account,

                                         v_period_year,

                                         p_currency_code ) LOOP



          INSERT 

            INTO ajcl_bc_gl_balances_ytd

               ( oracle_company,

                 oracle_account,

                 oracle_dept,

                 oracle_product,

                 oracle_dest,

                 oracle_origin,

                 bc_company,

                 bc_account,

                 bc_dept,

                 bc_product,

                 bc_dest,

                 bc_office,

                 bc_origin,

                 beginning_balance,

                 debits,

                 credits,

                 ending_balance,

                 request_id,

                 period_year,

                 currency_code,

                 translated_ending_balance )

        VALUES ( cytd.company,

                 cytd.account,

                 cytd.dept,

                 cytd.product, 

                 cytd.dest,

                 cytd.origin, 

                 ajcl_bc_accounts_pkg.account_dim_required(cytd.bc_account,'COMPANY',cytd.bc_company),

                 cytd.bc_account,

                 ajcl_bc_accounts_pkg.account_dim_required(cytd.bc_account,'DEPARTMENT',cytd.bc_dept),

                 ajcl_bc_accounts_pkg.account_dim_required(cytd.bc_account,'PRODUCT',cytd.bc_product),

                 ajcl_bc_accounts_pkg.account_dim_required(cytd.bc_account,'DESTINATION',cytd.bc_dest),

                 ajcl_bc_accounts_pkg.account_dim_required(cytd.bc_account,'OFFICE',cytd.bc_office),

                 ajcl_bc_accounts_pkg.account_dim_required(cytd.bc_account,'ORIGIN',cytd.bc_origin),

                 cytd.beginning_balance, 

                 cytd.debits,

                 cytd.credits,

                 cytd.ending_balance,

                 gv_request_id,

                 v_period_year_real,

                 p_currency_code,

                 cytd.translated_ending_balance );



        END LOOP; 



        COMMIT;



      END IF;

    */

    -- End Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation



    -- 20230718

    END LOOP;

    -- 20230718



    v_request_id_excel := print_excel_report ( p_argument1 => gv_request_id,

                                               p_argument2 => NULL,

                                               p_program_short_code => 'AJCLBCGLYTDR' ); -- AJCL BC Master Data - GL - Year to Date - YTD - Report



    print_log ('Report request id: ' || v_request_id_excel );



    print_log ('ajcl_bc_gl_balances_pkg.year_to_date_ytd (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      print_log ('ajcl_bc_gl_balances_pkg.year_to_date_ytd (!). Error: ' || SQLERRM );  

      retcode := 2;

      v_concurrent_status := fnd_concurrent.set_completion_status('ERROR',SQLERRM);

      errbuf := SQLERRM;



  END year_to_date_ytd;                                 



  -- ------------------------------------------------------------------------------------------------------------------------ --

  -- ------------------------------------------------------------------------------------------------------------------------ --

  -- ------------------------------------------------------------------------------------------------------------------------ --



  /*=========================================================================+

  | Function                                                                 |

  |    translated_period_net_change                                          |

  +=========================================================================*/   

  FUNCTION translated_period_net_change ( p_set_of_books_id       IN   NUMBER,

                                          p_period_set_name       IN   VARCHAR2,

                                          p_end_date              IN   DATE,

                                          p_period_year           IN   NUMBER,

                                          p_period_num            IN   NUMBER,

                                          p_code_combination_id   IN   NUMBER ) RETURN NUMBER IS



    v_translated_pnc   NUMBER;



  BEGIN



           -- Debits                       -- Credits

    SELECT SUM(nvl(gb2.period_net_dr,0)) - SUM(nvl(gb2.period_net_cr,0))

      INTO v_translated_pnc

      FROM gl_balances gb2,

           gl_periods gp3

     WHERE gb2.set_of_books_id = p_set_of_books_id

       AND gb2.currency_code = 'USD'

       AND gb2.code_combination_id = p_code_combination_id

       AND gb2.actual_flag = 'A'

       AND NVL(gb2.translated_flag,'X') = 'Y'

       AND gb2.template_id IS NULL

       AND gb2.period_name = gp3.period_name

       AND gp3.period_set_name = p_period_set_name

       AND gp3.period_year = p_period_year

       AND gp3.end_date = p_end_date

       AND gp3.period_num = p_period_num;



    RETURN v_translated_pnc;



  EXCEPTION

    WHEN OTHERS THEN

      print_log ('ajcl_bc_gl_balances_pkg.translated_period_net_change (!). Error: ' || SQLERRM );  



  END translated_period_net_change;



  /*=========================================================================+

  | Procedure                                                                |

  |    PTD                                                                   |

  +=========================================================================*/    

  PROCEDURE period_to_date_ptd ( retcode               OUT   NUMBER,

                                 errbuf                OUT   VARCHAR2,

                                 p_oracle_company      IN   VARCHAR2,

                                 p_oracle_account      IN   VARCHAR2,

                                 p_period_year         IN   NUMBER,

                                 p_period_year_real    IN   NUMBER,

                                 p_period_num          IN   NUMBER,

                                 p_currency_code       IN   VARCHAR2,

                                 p_delete_final_table  IN   VARCHAR2,

                                 p_execute_report      IN   VARCHAR2,

                                 p_bc_environment      IN   VARCHAR2 ) IS



    CURSOR c_ptd ( pc_oracle_company   IN   VARCHAR2,

                   pc_oracle_account   IN   VARCHAR2,

                   pc_period_year      IN   NUMBER,

                   pc_period_num       IN   NUMBER, 

                   pc_currency_code    IN   VARCHAR2 ) IS

    -- Consolidado

    -- Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

    /*

    SELECT *

      FROM ( SELECT oracle_company,

                    oracle_account,

                    oracle_dept,

                    oracle_product,

                    oracle_dest,

                    oracle_origin,

                    bc_company,

                    bc_account,

                    bc_dept,

                    bc_product,

                    bc_dest,

                    bc_office,

                    bc_origin,

                    beginning_balance,

                    debits,

                    credits,

                    debits - credits period_net_change,

                    CASE 

                      WHEN pc_currency_code = 'USD' THEN

                        debits - credits

                      ELSE

                        ajcl_bc_gl_balances_pkg.translated_period_net_change ( p_set_of_books_id => set_of_books_id,

                                                                              p_period_set_name => period_set_name,

                                                                              p_end_date => end_date,

                                                                              p_period_year => period_year,

                                                                              p_period_num => period_num,

                                                                              p_code_combination_id => code_combination_id ) 

                    END translated_period_net_change, 

                    ending_balance,

                    period_end_date

               FROM ( SELECT t.company oracle_company,        

                             t.account oracle_account,

                             T.dept oracle_dept,

                             T.product oracle_product,

                             T.dest oracle_dest,

                             T.origin oracle_origin,

                             t.company bc_company,

                             NVL(aba.bc_account,'XXXX.' || t.account) bc_account,

                             t.dept bc_dept,

                             DECODE(

                             ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4',

                                                                                  p_oracle_value   => t.product,

                                                                                  p_bc_dimension   => 'DIVISION' )

                               ,NULL,t.product,'000') bc_product,

                             DECODE(

                             ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                                                  p_oracle_value => t.dest,

                                                                                  p_bc_dimension => 'OFFICE' )

                               ,NULL,t.dest,'000') bc_dest,

                             NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                                                      p_oracle_value => t.dest,

                                                                                      p_bc_dimension => 'OFFICE'),'000') bc_office,

                             t.origin bc_origin,

                             t.begin_balance_dr - t.begin_balance_cr beginning_balance,

                             t.period_net_dr debits,

                             t.period_net_cr credits,

                             (t.begin_balance_dr - t.begin_balance_cr) + t.period_net_dr - t.period_net_cr ending_balance,

                             TRUNC(t.end_date) period_end_date,

                             t.code_combination_id,

                             t.set_of_books_id,

                             t.period_num,

                             t.period_year,

                             t.period_set_name,

                             t.end_date

                        FROM ( SELECT gcc.segment1 company,

                                      gcc.segment2 account,

                                      gcc.segment3 dept,

                                      gcc.segment4 product,

                                      gcc.segment5 dest,

                                      gcc.segment6 origin,

                                      -- gcc.segment7 intercompany,

                                      ( SELECT SUM(nvl(gb2.period_net_dr, 0))

                                          FROM gl_balances gb2,

                                               gl_periods gp3,

                                               gl_code_combinations gcc2

                                         WHERE gb2.set_of_books_id = gsob.set_of_books_id

                                           AND gb2.currency_code = gb.currency_code

                                           AND gb2.code_combination_id = gcc2.code_combination_id

                                           AND gcc2.segment1 = gcc.segment1

                                           AND gcc2.segment2 = gcc.segment2

                                           AND gcc2.segment3 = gcc.segment3

                                           AND gcc2.segment4 = gcc.segment4

                                           AND gcc2.segment5 = gcc.segment5

                                           AND gcc2.segment6 = gcc.segment6

                                           AND gcc2.segment7 = gcc.segment7

                                           AND gb2.actual_flag = 'A'

                                           AND NVL(gb2.translated_flag,'X') = 'X'

                                           AND gb2.template_id is null

                                           AND gb2.period_name = gp3.period_name

                                           AND gp3.period_set_name = gsob.period_set_name

                                           AND gp3.period_year = gp.period_year

                                           AND gp3.end_date = gp.end_date

                                           AND gp3.period_num = gp.period_num ) period_net_dr,

                                      ( SELECT SUM(nvl(gb2.period_net_cr, 0))

                                          FROM gl_balances gb2,

                                               gl_periods gp3,

                                               gl_code_combinations gcc2

                                         WHERE gb2.set_of_books_id = gsob.set_of_books_id

                                           AND gb2.currency_code = gb.currency_code

                                           AND gb2.code_combination_id = gcc2.code_combination_id

                                           AND gcc2.segment1 = gcc.segment1

                                           AND gcc2.segment2 = gcc.segment2

                                           AND gcc2.segment3 = gcc.segment3

                                           AND gcc2.segment4 = gcc.segment4

                                           AND gcc2.segment5 = gcc.segment5

                                           AND gcc2.segment6 = gcc.segment6

                                           AND gcc2.segment7 = gcc.segment7

                                           AND gb2.actual_flag = 'A'

                                           AND NVL(gb2.translated_flag,'X') = 'X'

                                           AND gb2.template_id is null

                                           AND gb2.period_name = gp3.period_name

                                           AND gp3.period_set_name = gsob.period_set_name

                                           AND gp3.period_year = gp.period_year

                                           AND gp3.end_date = gp.end_date 

                                           AND gp3.period_num = gp.period_num ) period_net_cr,            

                                      gb.currency_code, 

                                      gp.end_date,

                                      NVL(gb.begin_balance_dr,0) begin_balance_dr,

                                      NVL(gb.begin_balance_cr,0) begin_balance_cr,

                                      gsob.name,   

                                      gb.period_name,

                                      gb.period_num,

                                      gsob.set_of_books_id,

                                      gcc.code_combination_id,

                                      gp.period_year,

                                      gsob.period_set_name

                                 FROM gl_balances gb,

                                      gl_code_combinations_kfv gcc,

                                      gl_sets_of_books gsob,

                                      gl_periods gp,

                                      gl_sets_of_books_dfv gsob_dfv

                                      --,ajc_bc_companies bcc

                                WHERE gb.code_combination_id = gcc.code_combination_id

                                  AND gb.set_of_books_id = gsob.set_of_books_id

                                  AND gp.period_set_name = gsob.period_set_name

                                  AND gp.period_name = gb.period_name

                                  AND gcc.enabled_flag = 'Y'

                                  AND NVL(gcc.end_date_active,TO_DATE(gp.end_date,'DD/MM/YYYY')) >= TO_DATE(gp.end_date,'DD/MM/YYYY')

                                                                          -- DEC          -- ADJ          -- AUD

                                  AND gp.period_num = DECODE(pc_period_num,12,pc_period_num,13,pc_period_num,14,pc_period_num,( SELECT MAX(gp2.period_num)

                                                                                                                                  FROM gl_periods gp2

                                                                                                                                 WHERE gp2.period_set_name = gp.period_set_name

                                                                                                                                   AND gp2.period_year = gp.period_year

                                                                                                                                   AND gp2.end_date = gp.end_date ))

                                  AND   gb.actual_flag = 'A'

                                  AND   nvl(gb.translated_flag,'X') = 'X'

                                  AND   gb.template_id is null 

                                  AND   gb.currency_code = gsob.currency_code

                                  AND   gsob.rowid = gsob_dfv.row_id

                                  -- AND   gcc.segment1 = NVL(pc_oracle_company,gcc.segment1)

                                  AND   gcc.segment2 = NVL(pc_oracle_account,gcc.segment2)

                                  AND   gcc.segment2 NOT IN ('1152')

                                  AND   gb.currency_code = pc_currency_code

                                  AND   gp.period_year = NVL(pc_period_year,gp.period_year)

                                  AND   gp.period_num = NVL(pc_period_num,gp.period_num)

                                  -- 20230705 - Se comenta para sacar el consolidado

                                  -- AND   gcc.segment1 = bcc.oracle_company_number

                                  -- AND   bcc.set_of_books_id = gsob.set_of_books_id

                                  -- 20230705 - Se agrega para sacar el consolidado

                                  AND   gsob.set_of_books_id = 203

                                  AND   p_oracle_company IS NULL

                                  -- 20230705 

                                  -- 20230705 - Se comenta para sacar el consolidado

                                  -- 20230705 AND   gsob.name NOT IN ('AJC CONS CALENDAR YEAR', 'AJC CONSOLIDATED', 'GLOBAL CHF CONSOLIDATED')

                                  ) t,   

                            ajc.ajc_bc_accounts aba

                      WHERE t.account = aba.oracle_account (+) ) )

     WHERE NOT ( period_net_change = 0 AND translated_period_net_change = 0 )

     UNION ALL

     */

     -- End Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

     -- Por Org

     SELECT *

      FROM ( SELECT oracle_company,

                    oracle_account,

                    oracle_dept,

                    oracle_product,

                    oracle_dest,

                    oracle_origin,

                    bc_company,

                    bc_account,

                    bc_dept,

                    bc_product,

                    bc_division,

                    bc_dest,

                    bc_office,

                    bc_origin,

                    beginning_balance,

                    debits,

                    credits,

                    debits - credits period_net_change,

                    CASE 

                      WHEN pc_currency_code = 'USD' THEN

                        debits - credits

                      ELSE

                        ajcl_bc_gl_balances_pkg.translated_period_net_change ( p_set_of_books_id => set_of_books_id,

                                                                              p_period_set_name => period_set_name,

                                                                              p_end_date => end_date,

                                                                              p_period_year => period_year,

                                                                              p_period_num => period_num,

                                                                              p_code_combination_id => code_combination_id ) 

                    END translated_period_net_change, 

                    ending_balance,

                    period_end_date

               FROM ( SELECT t.company oracle_company,        

                             t.account oracle_account,

                             T.dept oracle_dept,

                             T.product oracle_product,

                             T.dest oracle_dest,

                             T.origin oracle_origin,

                             t.company bc_company,

                             NVL(aba.bc_account,'XXXX.' || t.account) bc_account,

                             t.dept bc_dept,

                             DECODE(

                             ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4',

                                                                                  p_oracle_value   => t.product,

                                                                                  p_bc_dimension   => 'DIVISION' )

                               ,NULL,t.product,'000') bc_product,

                              NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4'

                                                                                      ,p_oracle_value => t.product

                                                                                      ,p_bc_dimension => 'DIVISION'),'000') bc_division,                               

                              -- Modified KHRONUS/PBonadeo 20240717: AJCL BC Implementation: Office vs Dest Mapping

                              /*

                              DECODE(

                              ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                  ,p_oracle_value => t.dest

                                                                                  ,p_bc_dimension => 'OFFICE' )

                                ,NULL,t.dest,'000') bc_dest, 

                              NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                      ,p_oracle_value => t.dest

                                                                                      ,p_bc_dimension => 'OFFICE'),'000') bc_office,  

                              */

                              CASE WHEN t.account BETWEEN '6000' AND '9999' THEN 

                                DECODE(

                                ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                  ,p_oracle_value => t.dest

                                                                                  ,p_bc_dimension => 'OFFICE' )

                                ,NULL,t.dest,'000')                                 

                              ELSE

                                t.dest

                              END bc_dest, 

                              CASE WHEN t.account BETWEEN '6000' AND '9999' THEN                               

                                NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5'

                                                                                      ,p_oracle_value => t.dest

                                                                                      ,p_bc_dimension => 'OFFICE'),'000') 

                              ELSE

                                '000'                                                                                      

                              END bc_office,                              

                              -- End Modified KHRONUS/PBonadeo 20240717: AJCL BC Implementation: Office vs Dest Mapping

                             t.origin bc_origin,

                             t.begin_balance_dr - t.begin_balance_cr beginning_balance,

                             t.period_net_dr debits,

                             t.period_net_cr credits,

                             (t.begin_balance_dr - t.begin_balance_cr) + t.period_net_dr - t.period_net_cr ending_balance,

                             TRUNC(t.end_date) period_end_date,

                             t.code_combination_id,

                             t.set_of_books_id,

                             t.period_num,

                             t.period_year,

                             t.period_set_name,

                             t.end_date

                        FROM ( SELECT gcc.segment1 company,

                                      gcc.segment2 account,

                                      gcc.segment3 dept,

                                      gcc.segment4 product,

                                      gcc.segment5 dest,

                                      gcc.segment6 origin,

                                      -- gcc.segment7 intercompany,

                                      ( SELECT SUM(nvl(gb2.period_net_dr, 0))

                                          FROM gl_balances gb2,

                                               gl_periods gp3,

                                               gl_code_combinations gcc2

                                         WHERE gb2.set_of_books_id = gsob.set_of_books_id

                                           AND gb2.currency_code = gb.currency_code

                                           AND gb2.code_combination_id = gcc2.code_combination_id

                                           AND gcc2.segment1 = gcc.segment1

                                           AND gcc2.segment2 = gcc.segment2

                                           AND gcc2.segment3 = gcc.segment3

                                           AND gcc2.segment4 = gcc.segment4

                                           AND gcc2.segment5 = gcc.segment5

                                           AND gcc2.segment6 = gcc.segment6

                                           AND gcc2.segment7 = gcc.segment7

                                           AND gb2.actual_flag = 'A'

                                           AND NVL(gb2.translated_flag,'X') = 'X'

                                           AND gb2.template_id is null

                                           AND gb2.period_name = gp3.period_name

                                           AND gp3.period_set_name = gsob.period_set_name

                                           AND gp3.period_year = gp.period_year

                                           AND gp3.end_date = gp.end_date

                                           AND gp3.period_num = gp.period_num ) period_net_dr,

                                      ( SELECT SUM(nvl(gb2.period_net_cr, 0))

                                          FROM gl_balances gb2,

                                               gl_periods gp3,

                                               gl_code_combinations gcc2

                                         WHERE gb2.set_of_books_id = gsob.set_of_books_id

                                           AND gb2.currency_code = gb.currency_code

                                           AND gb2.code_combination_id = gcc2.code_combination_id

                                           AND gcc2.segment1 = gcc.segment1

                                           AND gcc2.segment2 = gcc.segment2

                                           AND gcc2.segment3 = gcc.segment3

                                           AND gcc2.segment4 = gcc.segment4

                                           AND gcc2.segment5 = gcc.segment5

                                           AND gcc2.segment6 = gcc.segment6

                                           AND gcc2.segment7 = gcc.segment7

                                           AND gb2.actual_flag = 'A'

                                           AND NVL(gb2.translated_flag,'X') = 'X'

                                           AND gb2.template_id is null

                                           AND gb2.period_name = gp3.period_name

                                           AND gp3.period_set_name = gsob.period_set_name

                                           AND gp3.period_year = gp.period_year

                                           AND gp3.end_date = gp.end_date 

                                           AND gp3.period_num = gp.period_num ) period_net_cr,            

                                      gb.currency_code, 

                                      gp.end_date,

                                      NVL(gb.begin_balance_dr,0) begin_balance_dr,

                                      NVL(gb.begin_balance_cr,0) begin_balance_cr,

                                      gsob.name,   

                                      gb.period_name,

                                      gb.period_num,

                                      gsob.set_of_books_id,

                                      gcc.code_combination_id,

                                      gp.period_year,

                                      gsob.period_set_name

                                 FROM gl_balances gb,

                                      gl_code_combinations_kfv gcc,

                                      gl_sets_of_books gsob,

                                      gl_periods gp,

                                      gl_sets_of_books_dfv gsob_dfv,

                                      ajc_bc_companies bcc

                                WHERE gb.code_combination_id = gcc.code_combination_id

                                  AND gb.set_of_books_id = gsob.set_of_books_id

                                  AND gp.period_set_name = gsob.period_set_name

                                  AND gp.period_name = gb.period_name

                                  AND gcc.enabled_flag = 'Y'

                                  AND NVL(gcc.end_date_active,TO_DATE(gp.end_date,'DD/MM/YYYY')) >= TO_DATE(gp.end_date,'DD/MM/YYYY')

                                                                          -- DEC          -- ADJ          -- AUD

                                  AND gp.period_num = DECODE(pc_period_num,12,pc_period_num,13,pc_period_num,14,pc_period_num,( SELECT MAX(gp2.period_num)

                                                                                                                                  FROM gl_periods gp2

                                                                                                                                 WHERE gp2.period_set_name = gp.period_set_name

                                                                                                                                   AND gp2.period_year = gp.period_year

                                                                                                                                   AND gp2.end_date = gp.end_date ))

                                  AND   gb.actual_flag = 'A'

                                  AND   nvl(gb.translated_flag,'X') = 'X'

                                  AND   gb.template_id is null 

                                  AND   gb.currency_code = gsob.currency_code

                                  AND   gsob.rowid = gsob_dfv.row_id

                                  AND   gcc.segment1 = NVL(pc_oracle_company,gcc.segment1)

                                  AND   gcc.segment2 = NVL(pc_oracle_account,gcc.segment2)

                                  AND   gcc.segment2 NOT IN ('1152')

                                  AND   gb.currency_code = pc_currency_code

                                  AND   gp.period_year = NVL(pc_period_year,gp.period_year)

                                  AND   gp.period_num = NVL(pc_period_num,gp.period_num)

                                  -- 20230705 - Se comenta para sacar el consolidado

                                  AND   gcc.segment1 = bcc.oracle_company_number

                                  AND   bcc.set_of_books_id = gsob.set_of_books_id

                                  -- 20230705 - Se agrega para sacar el consolidado

                                  -- AND   gsob.set_of_books_id = 203

                                  AND p_oracle_company IS NOT NULL

                                  -- 20230705 

                                  -- 20230705 - Se comenta para sacar el consolidado

                                  -- 20230705 AND   gsob.name NOT IN ('AJC CONS CALENDAR YEAR', 'AJC CONSOLIDATED', 'GLOBAL CHF CONSOLIDATED')

                                  ) t,   

                            ajc.ajc_bc_accounts aba

                      WHERE t.account = aba.oracle_account (+) ) )

     WHERE NOT ( period_net_change = 0 AND translated_period_net_change = 0 );



    -- Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

    /*

    CURSOR c_missing_accounts ( pc_oracle_company   IN   VARCHAR2,

                                pc_oracle_account   IN   VARCHAR2,

                                pc_period_year      IN   NUMBER,

                                pc_period_num       IN   NUMBER, 

                                pc_currency_code    IN   VARCHAR2 ) IS

    -- Consolidado

    SELECT *

      FROM ( SELECT oracle_company,

                    oracle_account,

                    oracle_dept,

                    oracle_product,

                    oracle_dest,

                    oracle_origin,

                    bc_company,

                    bc_account,

                    bc_dept,

                    bc_product,

                    bc_dest,

                    bc_office,

                    bc_origin,

                    0 beginning_balance,

                    0 debits,

                    0 credits,

                    0 period_net_change,

                    ajcl_bc_gl_balances_pkg.translated_period_net_change ( p_set_of_books_id => set_of_books_id,

                                                                          p_period_set_name => period_set_name,

                                                                          p_end_date => end_date,

                                                                          p_period_year => period_year,

                                                                          p_period_num => period_num,

                                                                          p_code_combination_id => code_combination_id ) translated_period_net_change, 

                    0 ending_balance,

                    period_end_date

               FROM ( SELECT t.company oracle_company,        

                             t.account oracle_account,

                             T.dept oracle_dept,

                             T.product oracle_product,

                             T.dest oracle_dest,

                             T.origin oracle_origin,

                             t.company bc_company,

                             NVL(aba.bc_account,'XXXX.' || t.account) bc_account,

                             t.dept bc_dept,

                             DECODE(

                             ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4',

                                                                                  p_oracle_value   => t.product,

                                                                                  p_bc_dimension   => 'DIVISION' )

                               ,NULL,t.product,'000') bc_product,

                             DECODE(

                             ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                                                  p_oracle_value => t.dest,

                                                                                  p_bc_dimension => 'OFFICE' )

                               ,NULL,t.dest,'000') bc_dest,

                             NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                                                      p_oracle_value => t.dest,

                                                                                      p_bc_dimension => 'OFFICE'),'000') bc_office,

                             t.origin bc_origin,

                             t.begin_balance_dr - t.begin_balance_cr beginning_balance,

                             t.period_net_dr debits,

                             t.period_net_cr credits,

                             (t.begin_balance_dr - t.begin_balance_cr) + t.period_net_dr - t.period_net_cr ending_balance,

                             TRUNC(t.end_date) period_end_date,

                             t.code_combination_id,

                             t.set_of_books_id,

                             t.period_num,

                             t.period_year,

                             t.period_set_name,

                             t.end_date

                        FROM ( SELECT gcc.segment1 company,

                                      gcc.segment2 account,

                                      gcc.segment3 dept,

                                      gcc.segment4 product,

                                      gcc.segment5 dest,

                                      gcc.segment6 origin,

                                      -- gcc.segment7 intercompany,

                                      ( SELECT SUM(nvl(gb2.period_net_dr, 0))

                                          FROM gl_balances gb2,

                                               gl_periods gp3,

                                               gl_code_combinations gcc2

                                         WHERE gb2.set_of_books_id = gsob.set_of_books_id

                                           AND gb2.currency_code = gb.currency_code

                                           AND gb2.code_combination_id = gcc2.code_combination_id

                                           AND gcc2.segment1 = gcc.segment1

                                           AND gcc2.segment2 = gcc.segment2

                                           AND gcc2.segment3 = gcc.segment3

                                           AND gcc2.segment4 = gcc.segment4

                                           AND gcc2.segment5 = gcc.segment5

                                           AND gcc2.segment6 = gcc.segment6

                                           AND gcc2.segment7 = gcc.segment7

                                           AND gb2.actual_flag = 'A'

                                           AND NVL(gb2.translated_flag,'X') = 'Y'

                                           AND gb2.template_id is null

                                           AND gb2.period_name = gp3.period_name

                                           AND gp3.period_set_name = gsob.period_set_name

                                           AND gp3.period_year = gp.period_year

                                           AND gp3.end_date = gp.end_date

                                           AND gp3.period_num = gp.period_num ) period_net_dr,

                                      ( SELECT SUM(nvl(gb2.period_net_cr, 0))

                                          FROM gl_balances gb2,

                                               gl_periods gp3,

                                               gl_code_combinations gcc2

                                         WHERE gb2.set_of_books_id = gsob.set_of_books_id

                                           AND gb2.currency_code = gb.currency_code

                                           AND gb2.code_combination_id = gcc2.code_combination_id

                                           AND gcc2.segment1 = gcc.segment1

                                           AND gcc2.segment2 = gcc.segment2

                                           AND gcc2.segment3 = gcc.segment3

                                           AND gcc2.segment4 = gcc.segment4

                                           AND gcc2.segment5 = gcc.segment5

                                           AND gcc2.segment6 = gcc.segment6

                                           AND gcc2.segment7 = gcc.segment7

                                           AND gb2.actual_flag = 'A'

                                           AND NVL(gb2.translated_flag,'X') = 'Y'

                                           AND gb2.template_id is null

                                           AND gb2.period_name = gp3.period_name

                                           AND gp3.period_set_name = gsob.period_set_name

                                           AND gp3.period_year = gp.period_year

                                           AND gp3.end_date = gp.end_date 

                                           AND gp3.period_num = gp.period_num ) period_net_cr,            

                                      gb.currency_code, 

                                      gp.end_date,

                                      NVL(gb.begin_balance_dr,0) begin_balance_dr,

                                      NVL(gb.begin_balance_cr,0) begin_balance_cr,

                                      gsob.name,   

                                      gb.period_name,

                                      gb.period_num,

                                      gsob.set_of_books_id,

                                      gcc.code_combination_id,

                                      gp.period_year,

                                      gsob.period_set_name

                                 FROM gl_balances gb,

                                      gl_code_combinations_kfv gcc,

                                      gl_sets_of_books gsob,

                                      gl_periods gp,

                                      gl_sets_of_books_dfv gsob_dfv

                                      -- ,ajc_bc_companies bcc

                                WHERE gb.code_combination_id = gcc.code_combination_id

                                  AND gb.set_of_books_id = gsob.set_of_books_id

                                  AND gp.period_set_name = gsob.period_set_name

                                  AND gp.period_name = gb.period_name

                                  AND gcc.enabled_flag = 'Y'

                                  AND NVL(gcc.end_date_active,TO_DATE(gp.end_date,'DD/MM/YYYY')) >= TO_DATE(gp.end_date,'DD/MM/YYYY')

                                                                          -- DEC          -- ADJ          -- AUD

                                  AND gp.period_num = DECODE(pc_period_num,12,pc_period_num,13,pc_period_num,14,pc_period_num,( SELECT MAX(gp2.period_num)

                                                                                                                                  FROM gl_periods gp2

                                                                                                                                 WHERE gp2.period_set_name = gp.period_set_name

                                                                                                                                   AND gp2.period_year = gp.period_year

                                                                                                                                   AND gp2.end_date = gp.end_date ))

                                  AND   gb.actual_flag = 'A'

                                  AND   nvl(gb.translated_flag,'X') = 'Y'

                                  AND   gb.template_id is null 

                                  AND   gsob.rowid = gsob_dfv.row_id

                                  AND   gcc.segment1 = NVL(pc_oracle_company,gcc.segment1)

                                  AND   gcc.segment2 = NVL(pc_oracle_account,gcc.segment2)

                                  AND   gcc.segment2 NOT IN ('1152')

                                  AND   gb.currency_code = 'USD'

                                  AND   gp.period_year = NVL(pc_period_year,gp.period_year)

                                  AND   gp.period_num = NVL(pc_period_num,gp.period_num)

                                  -- 20230705 - Se comenta para sacar el consolidado

                                  -- AND   gcc.segment1 = bcc.oracle_company_number

                                  -- AND   bcc.set_of_books_id = gsob.set_of_books_id

                                  -- 20230705 - Se agrega para sacar el consolidado

                                  AND gsob.set_of_books_id = 203

                                  AND p_oracle_company IS NULL

                                  -- 20230705 

                                  -- 20230705 - Se comenta para sacar el consolidado

                                  -- AND   gsob.name NOT IN ('AJC CONS CALENDAR YEAR', 'AJC CONSOLIDATED', 'GLOBAL CHF CONSOLIDATED') 

                                  ) t,   

                            ajc.ajc_bc_accounts aba

                      WHERE t.account = aba.oracle_account (+) ) ) a

     WHERE NOT EXISTS ( SELECT 1 

                          FROM ajcl_bc_gl_balances_ptd bc 

                         WHERE bc.oracle_company = a.oracle_company 

                           AND bc.oracle_account = a.oracle_account

                           AND currency_code != 'USD'

                           AND period_year = pc_period_year

                           AND period_num = pc_period_num )

       AND translated_period_net_change != 0

     UNION ALL

    -- Por Org 

    SELECT *

      FROM ( SELECT oracle_company,

                    oracle_account,

                    oracle_dept,

                    oracle_product,

                    oracle_dest,

                    oracle_origin,

                    bc_company,

                    bc_account,

                    bc_dept,

                    bc_product,

                    bc_dest,

                    bc_office,

                    bc_origin,

                    0 beginning_balance,

                    0 debits,

                    0 credits,

                    0 period_net_change,

                    ajcl_bc_gl_balances_pkg.translated_period_net_change ( p_set_of_books_id => set_of_books_id,

                                                                          p_period_set_name => period_set_name,

                                                                          p_end_date => end_date,

                                                                          p_period_year => period_year,

                                                                          p_period_num => period_num,

                                                                          p_code_combination_id => code_combination_id ) translated_period_net_change, 

                    0 ending_balance,

                    period_end_date

               FROM ( SELECT t.company oracle_company,        

                             t.account oracle_account,

                             T.dept oracle_dept,

                             T.product oracle_product,

                             T.dest oracle_dest,

                             T.origin oracle_origin,

                             t.company bc_company,

                             NVL(aba.bc_account,'XXXX.' || t.account) bc_account,

                             t.dept bc_dept,

                             DECODE(

                             ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT4',

                                                                                  p_oracle_value   => t.product,

                                                                                  p_bc_dimension   => 'DIVISION' )

                               ,NULL,t.product,'000') bc_product,

                             DECODE(

                             ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                                                  p_oracle_value => t.dest,

                                                                                  p_bc_dimension => 'OFFICE' )

                               ,NULL,t.dest,'000') bc_dest,

                             NVL(ajcl_bc_accounts_pkg.get_dimension_value ( p_oracle_segment => 'SEGMENT5',

                                                                                      p_oracle_value => t.dest,

                                                                                      p_bc_dimension => 'OFFICE'),'000') bc_office,

                             t.origin bc_origin,

                             t.begin_balance_dr - t.begin_balance_cr beginning_balance,

                             t.period_net_dr debits,

                             t.period_net_cr credits,

                             (t.begin_balance_dr - t.begin_balance_cr) + t.period_net_dr - t.period_net_cr ending_balance,

                             TRUNC(t.end_date) period_end_date,

                             t.code_combination_id,

                             t.set_of_books_id,

                             t.period_num,

                             t.period_year,

                             t.period_set_name,

                             t.end_date

                        FROM ( SELECT gcc.segment1 company,

                                      gcc.segment2 account,

                                      gcc.segment3 dept,

                                      gcc.segment4 product,

                                      gcc.segment5 dest,

                                      gcc.segment6 origin,

                                      -- gcc.segment7 intercompany,

                                      ( SELECT SUM(nvl(gb2.period_net_dr, 0))

                                          FROM gl_balances gb2,

                                               gl_periods gp3,

                                               gl_code_combinations gcc2

                                         WHERE gb2.set_of_books_id = gsob.set_of_books_id

                                           AND gb2.currency_code = gb.currency_code

                                           AND gb2.code_combination_id = gcc2.code_combination_id

                                           AND gcc2.segment1 = gcc.segment1

                                           AND gcc2.segment2 = gcc.segment2

                                           AND gcc2.segment3 = gcc.segment3

                                           AND gcc2.segment4 = gcc.segment4

                                           AND gcc2.segment5 = gcc.segment5

                                           AND gcc2.segment6 = gcc.segment6

                                           AND gcc2.segment7 = gcc.segment7

                                           AND gb2.actual_flag = 'A'

                                           AND NVL(gb2.translated_flag,'X') = 'Y'

                                           AND gb2.template_id is null

                                           AND gb2.period_name = gp3.period_name

                                           AND gp3.period_set_name = gsob.period_set_name

                                           AND gp3.period_year = gp.period_year

                                           AND gp3.end_date = gp.end_date

                                           AND gp3.period_num = gp.period_num ) period_net_dr,

                                      ( SELECT SUM(nvl(gb2.period_net_cr, 0))

                                          FROM gl_balances gb2,

                                               gl_periods gp3,

                                               gl_code_combinations gcc2

                                         WHERE gb2.set_of_books_id = gsob.set_of_books_id

                                           AND gb2.currency_code = gb.currency_code

                                           AND gb2.code_combination_id = gcc2.code_combination_id

                                           AND gcc2.segment1 = gcc.segment1

                                           AND gcc2.segment2 = gcc.segment2

                                           AND gcc2.segment3 = gcc.segment3

                                           AND gcc2.segment4 = gcc.segment4

                                           AND gcc2.segment5 = gcc.segment5

                                           AND gcc2.segment6 = gcc.segment6

                                           AND gcc2.segment7 = gcc.segment7

                                           AND gb2.actual_flag = 'A'

                                           AND NVL(gb2.translated_flag,'X') = 'Y'

                                           AND gb2.template_id is null

                                           AND gb2.period_name = gp3.period_name

                                           AND gp3.period_set_name = gsob.period_set_name

                                           AND gp3.period_year = gp.period_year

                                           AND gp3.end_date = gp.end_date 

                                           AND gp3.period_num = gp.period_num ) period_net_cr,            

                                      gb.currency_code, 

                                      gp.end_date,

                                      NVL(gb.begin_balance_dr,0) begin_balance_dr,

                                      NVL(gb.begin_balance_cr,0) begin_balance_cr,

                                      gsob.name,   

                                      gb.period_name,

                                      gb.period_num,

                                      gsob.set_of_books_id,

                                      gcc.code_combination_id,

                                      gp.period_year,

                                      gsob.period_set_name

                                 FROM gl_balances gb,

                                      gl_code_combinations_kfv gcc,

                                      gl_sets_of_books gsob,

                                      gl_periods gp,

                                      gl_sets_of_books_dfv gsob_dfv,

                                      ajc_bc_companies bcc

                                WHERE gb.code_combination_id = gcc.code_combination_id

                                  AND gb.set_of_books_id = gsob.set_of_books_id

                                  AND gp.period_set_name = gsob.period_set_name

                                  AND gp.period_name = gb.period_name

                                  AND gcc.enabled_flag = 'Y'

                                  AND NVL(gcc.end_date_active,TO_DATE(gp.end_date,'DD/MM/YYYY')) >= TO_DATE(gp.end_date,'DD/MM/YYYY')

                                                                          -- DEC          -- ADJ          -- AUD

                                  AND gp.period_num = DECODE(pc_period_num,12,pc_period_num,13,pc_period_num,14,pc_period_num,( SELECT MAX(gp2.period_num)

                                                                                                                                  FROM gl_periods gp2

                                                                                                                                 WHERE gp2.period_set_name = gp.period_set_name

                                                                                                                                   AND gp2.period_year = gp.period_year

                                                                                                                                   AND gp2.end_date = gp.end_date ))

                                  AND   gb.actual_flag = 'A'

                                  AND   nvl(gb.translated_flag,'X') = 'Y'

                                  AND   gb.template_id is null 

                                  AND   gsob.rowid = gsob_dfv.row_id

                                  AND   gcc.segment1 = NVL(pc_oracle_company,gcc.segment1)

                                  AND   gcc.segment2 = NVL(pc_oracle_account,gcc.segment2)

                                  AND   gcc.segment2 NOT IN ('1152')

                                  AND   gb.currency_code = 'USD'

                                  AND   gp.period_year = NVL(pc_period_year,gp.period_year)

                                  AND   gp.period_num = NVL(pc_period_num,gp.period_num)

                                  -- 20230705 - Se comenta para sacar el consolidado

                                  AND   gcc.segment1 = bcc.oracle_company_number

                                  AND   bcc.set_of_books_id = gsob.set_of_books_id

                                  -- 20230705 - Se agrega para sacar el consolidado

                                  -- AND gsob.set_of_books_id = 203

                                  AND p_oracle_company IS NOT NULL

                                  -- 20230705 

                                  -- 20230705 - Se comenta para sacar el consolidado

                                  -- AND   gsob.name NOT IN ('AJC CONS CALENDAR YEAR', 'AJC CONSOLIDATED', 'GLOBAL CHF CONSOLIDATED') 

                                  ) t,   

                            ajc.ajc_bc_accounts aba

                      WHERE t.account = aba.oracle_account (+) ) ) a

     WHERE NOT EXISTS ( SELECT 1 

                          FROM ajcl_bc_gl_balances_ptd bc 

                         WHERE bc.oracle_company = a.oracle_company 

                           AND bc.oracle_account = a.oracle_account

                           AND currency_code != 'USD'

                           AND period_year = pc_period_year

                           AND period_num = pc_period_num )

       AND translated_period_net_change != 0;

    */

    -- End Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation



       

      CURSOR c_missing_account_mapping IS

      SELECT ptd.oracle_account,

             v.description

        FROM ajcl_bc_gl_balances_ptd ptd,

             fnd_flex_value_sets vs,

             fnd_flex_values_vl v

       WHERE ptd.oracle_company = NVL(p_oracle_company,ptd.oracle_company)

         AND ptd.bc_account LIKE '%XXXX%'

         AND ptd.oracle_account = v.flex_value

         AND ptd.period_year = p_period_year_real

         AND period_num = p_period_num

         AND vs.flex_value_set_name = 'AJC ACCOUNT' 

         AND vs.flex_value_set_id = v.flex_value_set_id

    GROUP BY ptd.oracle_account,

             v.description

    ORDER BY ptd.oracle_account;



    v_request_id_excel    NUMBER;

    v_missing_mapping     NUMBER := 0;

    v_concurrent_status   BOOLEAN;

    e_error               EXCEPTION;



  BEGIN



    print_log ('ajcl_bc_gl_balances_pkg.period_to_date_ptd (+)' );



    IF ( p_delete_final_table = 'Y' ) THEN



      DELETE ajcl_bc_gl_balances_ptd

       WHERE oracle_company = NVL(p_oracle_company,oracle_company)

         AND oracle_account = NVL(p_oracle_account,oracle_account)

         AND period_year = p_period_year_real

         AND period_num = p_period_num

         AND currency_code = p_currency_code;



      print_log ('Se borra de la tabla ajcl_bc_gl_balances_ptd..');

      print_log ('company: ' || p_oracle_company);



      IF ( p_oracle_account IS NOT NULL ) THEN



        print_log ('account: ' || p_oracle_account);



      END IF;



      print_log ('period_year: ' || p_period_year);

      print_log ('p_period_year_real: ' || p_period_year_real); 

      print_log ('period_num: ' || p_period_num);

      print_log ('currency_code: ' || p_currency_code); 

      print_log (' '); 



      print_log ('Cantidad registros borrados: ' || SQL%ROWCOUNT );



      COMMIT;



    END IF;



    -- Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

    /*

    IF ( p_execute_report = 'Y' ) THEN



      ajcl_bc_accounts_pkg.caller_p ( p_bc_environment => p_bc_environment );



    END IF;

    */

    -- End Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation



    FOR cptd IN c_ptd ( p_oracle_company,

                        p_oracle_account,

                        p_period_year,

                        p_period_num,

                        p_currency_code ) LOOP



      INSERT 

        INTO ajcl_bc_gl_balances_ptd

           ( oracle_company,

             oracle_account,

             oracle_dept,

             oracle_product,

             oracle_dest,

             oracle_origin,

             bc_company,

             bc_account,

             bc_dept,

             bc_product,

             bc_division,

             bc_dest,

             bc_office,

             bc_origin,

             beginning_balance,

             debits,

             credits,

             period_net_change,

             translated_period_net_change,

             ending_balance,

             period_end_date,

             request_id,

             period_year,

             period_num,

             currency_code )

    VALUES ( cptd.oracle_company,

             cptd.oracle_account,

             cptd.oracle_dept,

             cptd.oracle_product,

             cptd.oracle_dest,

             cptd.oracle_origin,

             ajcl_bc_accounts_pkg.account_dim_required(p_bc_environment, cptd.bc_account,'COMPANY',cptd.bc_company),

             cptd.bc_account,

             ajcl_bc_accounts_pkg.account_dim_required(p_bc_environment, cptd.bc_account,'DEPARTMENT',cptd.bc_dept),

             ajcl_bc_accounts_pkg.account_dim_required(p_bc_environment, cptd.bc_account,'PRODUCT',cptd.bc_product),

             ajcl_bc_accounts_pkg.account_dim_required(p_bc_environment, cptd.bc_account,'DIVISION',cptd.bc_division),

             ajcl_bc_accounts_pkg.account_dim_required(p_bc_environment, cptd.bc_account,'DESTINATION',cptd.bc_dest),

             ajcl_bc_accounts_pkg.account_dim_required(p_bc_environment, cptd.bc_account,'OFFICE',cptd.bc_office),

             ajcl_bc_accounts_pkg.account_dim_required(p_bc_environment, cptd.bc_account,'ORIGIN',cptd.bc_origin),

             cptd.beginning_balance,

             cptd.debits,

             cptd.credits,

             cptd.period_net_change,

             cptd.translated_period_net_change,

             cptd.ending_balance,

             cptd.period_end_date,

             gv_request_id,

             p_period_year_real,

             p_period_num,

             p_currency_code );



    END LOOP;



    COMMIT;



    -- Se inserta registro para las cuentas que no levanta el query principal, porque no existen registros en gl_balances con moneda

    -- igual al parametro, pero si existen registros en USD

    -- Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

    /*

    IF ( p_currency_code != 'USD' ) THEN



      FOR cptd IN c_missing_accounts ( p_oracle_company,

                                       p_oracle_account,

                                       p_period_year,

                                       p_period_num,

                                       p_currency_code ) LOOP



        INSERT 

          INTO ajcl_bc_gl_balances_ptd

             ( oracle_company,

               oracle_account,

               oracle_dept,

               oracle_product,

               oracle_dest,

               oracle_origin,

               bc_company,

               bc_account,

               bc_dept,

               bc_product,

               bc_dest,

               bc_office,

               bc_origin,

               beginning_balance,

               debits,

               credits,

               period_net_change,

               translated_period_net_change,

               ending_balance,

               period_end_date,

               request_id,

               period_year,

               period_num,

               currency_code )

      VALUES ( cptd.oracle_company,

               cptd.oracle_account,

               cptd.oracle_dept,

               cptd.oracle_product,

               cptd.oracle_dest,

               cptd.oracle_origin,

               ajcl_bc_accounts_pkg.account_dim_required(cptd.bc_account,'COMPANY',cptd.bc_company),

               cptd.bc_account,

               ajcl_bc_accounts_pkg.account_dim_required(cptd.bc_account,'DEPARTMENT',cptd.bc_dept),

               ajcl_bc_accounts_pkg.account_dim_required(cptd.bc_account,'PRODUCT',cptd.bc_product),

               ajcl_bc_accounts_pkg.account_dim_required(cptd.bc_account,'DESTINATION',cptd.bc_dest),

               ajcl_bc_accounts_pkg.account_dim_required(cptd.bc_account,'OFFICE',cptd.bc_office),

               ajcl_bc_accounts_pkg.account_dim_required(cptd.bc_account,'ORIGIN',cptd.bc_origin),

               cptd.beginning_balance,

               cptd.debits,

               cptd.credits,

               cptd.period_net_change,

               cptd.translated_period_net_change,

               cptd.ending_balance,

               cptd.period_end_date,

               gv_request_id,

               p_period_year_real,

               p_period_num,

               p_currency_code );



      END LOOP;  



      COMMIT;



    END IF;

    */ 

    -- End Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation



    IF ( p_execute_report = 'Y' ) THEN



      -- Check if there are missing account mappings

      FOR cmam IN c_missing_account_mapping LOOP



        print_log ( 'Account with no mapping (TABLE: ajc.ajc_bc_accounts): ACCOUNT: ' || cmam.oracle_account || ' | DESCRIPTION: ' || cmam.description );

        v_missing_mapping := v_missing_mapping + 1;



      END LOOP;



      IF ( v_missing_mapping > 0 ) THEN



        print_log ( 'Accounts with missing mapping.' );

        print_log ( '1. Please check if the account exists in BC.' );

        print_log ( '2. Ask Vero / Flor the first 4 numbers of the account and add it to the table ajc.ajc_bc_accounts.' );

        print_log ( '3. Execute this request again.' );



        retcode := 2;

        v_concurrent_status := fnd_concurrent.set_completion_status('ERROR','Accounts with missing mapping.');

        errbuf := 'Accounts with missing mapping.';

        RAISE e_error;



      END IF;



      v_request_id_excel := print_excel_report ( p_argument1 => gv_request_id,

                                                 p_argument2 => NULL,

                                                 p_program_short_code => 'AJCLBCGLPTDR' ); -- AJCL BC Master Data - GL - Period to Date - PTD - Report



    END IF;



    print_log ('Report request id: ' || v_request_id_excel );



    print_log ('ajcl_bc_gl_balances_pkg.period_to_date_ptd (-)' );



  EXCEPTION

    WHEN e_error THEN

      print_log ( errbuf );

    WHEN OTHERS THEN

      print_log ('ajcl_bc_gl_balances_pkg.period_to_date_ptd (!). Error: ' || SQLERRM );

      retcode := 2;

      v_concurrent_status := fnd_concurrent.set_completion_status('ERROR',SQLERRM);

      errbuf := SQLERRM;



  END period_to_date_ptd;



  /*=========================================================================+

  | Procedure                                                                |

  |    PTD Caller                                                            |

  +=========================================================================*/

  PROCEDURE period_to_date_ptd_caller ( retcode               OUT   NUMBER,

                                        errbuf                OUT   VARCHAR2,

                                        p_oracle_company      IN    VARCHAR2,

                                        p_oracle_account      IN    VARCHAR2,

                                        p_start_date          IN    VARCHAR2,

                                        p_end_date            IN    VARCHAR2,

                                        p_currency_code       IN    VARCHAR2,

                                        p_delete_final_table  IN    VARCHAR2,

                                        p_bc_environment      IN    VARCHAR2 ) IS



      /*

        CURSOR c_companies IS

        SELECT segment1 company

          FROM gl_code_combinations

         WHERE segment1 = NVL(p_oracle_company,segment1)

      GROUP BY segment1

      ORDER BY segment1;

      */



      CURSOR c_periods IS

      -- Por Compañía

      SELECT gp.period_year, 

             TO_NUMBER(TO_CHAR(gp.end_date,'YYYY')) period_year_real,

             gp.period_num

        FROM ajc_bc_companies bcc,

             gl_sets_of_books gsob,

             gl_periods gp

       WHERE bcc.set_of_books_id = gsob.set_of_books_id 

         AND gsob.period_set_name = gp.period_set_name

         AND gp.start_date >= TO_DATE(p_start_date,'DD-MON-YY')

         AND gp.end_date <= TO_DATE(p_end_date,'DD-MON-YY')

         AND bcc.oracle_company_number = p_oracle_company

         AND p_oracle_company IS NOT NULL  

    -- Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

    /*

    UNION ALL

      -- Consolidado

      SELECT gp.period_year, 

             TO_NUMBER(TO_CHAR(gp.end_date,'YYYY')) period_year_real,

             gp.period_num

        FROM gl_sets_of_books gsob,

             gl_periods gp

       WHERE gsob.set_of_books_id = 203

         AND gsob.period_set_name = gp.period_set_name

         AND gp.start_date >= TO_DATE(p_start_date,'DD-MON-YY')

         AND gp.end_date <= TO_DATE(p_end_date,'DD-MON-YY')

         AND p_oracle_company IS NULL

    */

    -- End Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation    

    GROUP BY gp.period_year, 

             TO_NUMBER(TO_CHAR(gp.end_date,'YYYY')),

             gp.period_num  

    ORDER BY period_year, 

             period_num;



    v_request_id          NUMBER;

    v_message             VARCHAR2(2000);

    v_error_message       VARCHAR2(2000);

    e_cust_exception      EXCEPTION;

    v_conc_phase          VARCHAR2 (50);

    v_conc_status         VARCHAR2 (50);

    v_conc_dev_phase      VARCHAR2 (50);

    v_conc_dev_status     VARCHAR2 (50);

    v_conc_message        VARCHAR2 (250);

    v_concurrent_status   BOOLEAN;

    e_error               EXCEPTION;



    v_request_id_excel    NUMBER;



      CURSOR c_missing_account_mapping IS

      SELECT ptd.oracle_account,

             v.description

        FROM ajcl_bc_gl_balances_ptd ptd,

             fnd_flex_value_sets vs,

             fnd_flex_values_vl v

       WHERE ptd.oracle_company = NVL(p_oracle_company,ptd.oracle_company)

         AND ptd.currency_code = p_currency_code

         AND ptd.bc_account LIKE '%XXXX%'

         AND ptd.oracle_account = v.flex_value

         AND vs.flex_value_set_name = 'AJC ACCOUNT' 

         AND vs.flex_value_set_id = v.flex_value_set_id

    GROUP BY ptd.oracle_account,

             v.description

    ORDER BY ptd.oracle_account;



    v_missing_mapping   NUMBER := 0;



  BEGIN



    print_log ('ajcl_bc_gl_balances_pkg.period_to_date_ptd_caller (+).' );



    -- Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation

    --ajcl_bc_accounts_pkg.caller_p ( p_bc_environment => p_bc_environment );

    -- End Modified KHRONUS/PBonadeo 20240618: AJCL BC Implementation



    -- FOR cc IN c_companies LOOP



      print_log ( 'Se borra tabla ajcl_bc_gl_balances_ptd para la company ' || p_oracle_company );



      DELETE ajcl_bc_gl_balances_ptd

       WHERE oracle_company = NVL(p_oracle_company,oracle_company)

         AND currency_code = p_currency_code;



      COMMIT;



      FOR cp IN c_periods LOOP



        print_log ( 'Period Year: ' || cp.period_year );

        print_log ( 'Period Num: ' || cp.period_num );



        -- Call AJCL BC Master Data - GL - Period to Date - PTD

        v_request_id := fnd_request.submit_request ( 'XXAJC',

                                                     'AJCLBCGLPTD',

                                                     -- 20230718

                                                     argument1 => p_oracle_company,

                                                     -- argument1 => cc.company,

                                                     -- 20230718

                                                     argument2 => p_oracle_account,

                                                     argument3 => cp.period_year,

                                                     argument4 => cp.period_year_real,

                                                     argument5 => cp.period_num,

                                                     argument6 => p_currency_code,

                                                     argument7 => p_delete_final_table,

                                                     argument8 => 'N',

                                                     argument9 => p_bc_environment ) ; -- p_execute_report



        IF v_request_id = 0 THEN



          v_message := fnd_message.get;

          print_log('Error Ejecutando FND_REQUEST.SUBMIT_REQUEST. AJCLBCGLPTD - AJCL BC Master Data - GL - Period to Date - PTD. Error: ' || v_message || ', ' || SQLERRM);

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

          print_log('Error Ejecutando FND_REQUEST.WAIT_FOR_REQUEST. AJCLBCGLPTD - AJCL BC Master Data - GL - Period to Date - PTD, con nro. solicitud ' || 

                     TO_CHAR (v_request_id) || '. Error: ' || v_message || ' ' || SQLERRM);

          RAISE e_cust_exception;



        END IF ;



        IF v_conc_dev_phase != 'COMPLETE' OR v_conc_dev_status != 'NORMAL' THEN



          v_error_message := fnd_message.get;

          print_log('Error en la ejecucion del concurrente AJCLBCGLPTD - AJCL BC Master Data - GL - Period to Date - PTD, con nro. solicitud ' || 

                     TO_CHAR (v_request_id) || '. Error: ' || v_error_message || ' ' || SQLERRM);

          RAISE e_cust_exception;



        END IF ;



      END LOOP;



      -- Check if there are missing account mappings

      FOR cmam IN c_missing_account_mapping LOOP



        print_log ( 'Account with no mapping (TABLE: ajc_bc_accounts): ACCOUNT: ' || cmam.oracle_account || ' | DESCRIPTION: ' || cmam.description );

        v_missing_mapping := v_missing_mapping + 1;



      END LOOP;



      IF ( v_missing_mapping > 0 ) THEN



        print_log ( 'Accounts with missing mapping.' );

        print_log ( '1. Please check if the account exists in BC.' );

        print_log ( '2. Ask Vero / Flor the first 4 numbers of the account and add it to the table ajc.ajc_bc_accounts.' );

        print_log ( '3. Execute this request again.' );



        retcode := 2;

        v_concurrent_status := fnd_concurrent.set_completion_status('ERROR','Accounts with missing mapping.');

        errbuf := 'Accounts with missing mapping.';

        RAISE e_error;



      END IF;



    -- END LOOP;



    v_request_id_excel := print_excel_report ( p_argument1 => p_oracle_company,

                                               p_argument2 => p_currency_code,

                                               p_program_short_code => 'AJCLBCGLPTDCR' ); -- AJCL BC Master Data - GL - PTD by Company - Report



    print_log ('ajcl_bc_gl_balances_pkg.period_to_date_ptd_caller (-).' );



  EXCEPTION

    WHEN e_error THEN

      print_log ( errbuf );



    WHEN OTHERS THEN

      print_log ('ajcl_bc_gl_balances_pkg.period_to_date_ptd_caller (!). Error: ' || SQLERRM );      

      retcode := 2;

      v_concurrent_status := fnd_concurrent.set_completion_status('ERROR',SQLERRM);

      errbuf := SQLERRM;



  END period_to_date_ptd_caller;



END ajcl_bc_gl_balances_pkg; 
