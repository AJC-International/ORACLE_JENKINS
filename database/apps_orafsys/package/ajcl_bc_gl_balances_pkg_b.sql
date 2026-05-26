PACKAGE BODY              ajcl_bc_gl_balances_pkg IS

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
                                      gcc.code_combina
