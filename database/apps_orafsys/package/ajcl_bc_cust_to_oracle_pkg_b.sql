PACKAGE BODY ajcl_bc_cust_to_oracle_pkg IS
-- Creation: SBANCHIERI 23-AUG-2023
  
  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    gv_log_seq := gv_log_seq + 1;
    ajcl_bc_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );

  END print_log;

  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    ajcl_bc_utils_pkg.insert_output_p ( gv_bc_ifc, p_message, gv_request_id );

  END print_output;

  PROCEDURE update_ajcl_bc_customers_p ( p_customer_number     VARCHAR2,
                                         p_status              VARCHAR2,
                                         p_customer_id         NUMBER,
                                         p_party_id            NUMBER,
                                         p_party_number        VARCHAR2,
                                         p_location_id         NUMBER,
                                         p_party_site_id       NUMBER,
                                         p_cust_acct_site_id   NUMBER,
                                         p_bill_to_site_use_id NUMBER,
                                         p_ship_to_site_use_id NUMBER,
                                         -- p_collector_id        NUMBER,
                                         -- p_statement_cycle_id  NUMBER,
                                         -- p_payment_terms_id    NUMBER,
                                         p_message             VARCHAR2 ) IS
  BEGIN

    print_log ( 'ajcl_bc_cust_to_oracle_pkg.update_ajcl_bc_customers_p (+)' );  

    UPDATE ajcl_bc_customers
       SET status = p_status,
           processed_date = TRUNC(SYSDATE),
           request_id = gv_request_id,
           customer_id = p_customer_id,
           party_id = p_party_id,
           party_number = p_party_number,
           location_id = p_location_id,
           party_site_id = p_party_site_id,
           cust_acct_site_id = p_cust_acct_site_id,
           bill_to_site_use_id = p_bill_to_site_use_id,
           ship_to_site_use_id = p_ship_to_site_use_id,
           -- collector_id = p_collector_id,
           -- statement_cycle_id = p_statement_cycle_id,
           -- payment_terms_id = p_payment_terms_id,
           message = p_message
     WHERE customer_number = p_customer_number
       AND status = 'PROCESSED'
       AND request_id = gv_request_id
       AND message IS NULL
       AND processed_date = TRUNC(SYSDATE);

    print_log ( 'ajcl_bc_cust_to_oracle_pkg.update_ajcl_bc_customers_p (-)' ); 

  EXCEPTION
    WHEN OTHERS THEN
      print_log ( 'ajcl_bc_cust_to_oracle_pkg.update_ajcl_bc_customers_p (!). Error: ' || SQLERRM ); 

  END update_ajcl_bc_customers_p;

  -- ------------------------------------------------------------------------------------------------------------------------ --
  -- GET CUSTOMERS ---------------------------------------------------------------------------------------------------------- --
  -- ------------------------------------------------------------------------------------------------------------------------ --
  PROCEDURE get_customers_p ( p_last_bc_processed_date   IN    TIMESTAMP,
                              p_status                   OUT   VARCHAR2, 
                              p_error_message            OUT   VARCHAR2 ) IS

    v_get_url               VARCHAR2(2000);
    v_customer_number       VARCHAR2(100);
    v_clob_result           CLOB;

    CURSOR c_customers ( p_clob_result   CLOB ) IS
    SELECT systemid,
           regexp_replace(No, '[^0-9]', '') customer_number,
           TRIM(Name) customer_name,
           'R' customer_type,
           0 profile_class_id,
           Address address,
           Address2 address2,
           Address3 address3,
           Address4 address4,
           DECODE(CountryRegionCode,'TBD',NULL,' ',NULL,'',NULL,CountryRegionCode) country,
           DECODE(City,'TBD',NULL,' ',NULL,'',NULL,City) city,
           NULL state,
           postCode zip,
           MobilePhoneNo mobile,
           PhoneNo phone, 
           VatRegistrationNo tax_no, 
           paymentTermsCode standard_terms,  
           NULL pending_balance,
           -- UPPER(lob) lob,
           CASE
             WHEN lob = '_x0020_' THEN
               NULL
             ELSE
               UPPER(lob)
           END lob,
           --
           DECODE(account_status,'true','ELITE',NULL) account_status,
           review_cycle,
           CASE
             WHEN last_file_review IS NULL THEN
               NULL
             WHEN last_file_review = ' ' THEN
               NULL
             WHEN last_file_review = '0001-01-01' THEN
               NULL
             ELSE
               TO_CHAR(TO_DATE(last_file_review,'YYYY-MM-DD'),'YYYY/MM/DD HH24:MI:SS')
           END last_file_review,
           scoring_model,
           NULL aig_limit,
           deactivation_reason,
           coface_limit,
           ajc_destination_country,
           insured_country,
           CASE
             WHEN account_created IS NULL THEN
               NULL
             WHEN account_created = ' ' THEN
               NULL
             WHEN account_created = '0001-01-01' THEN
               NULL
             ELSE
               TO_CHAR(TO_DATE(account_created,'YYYY-MM-DD'),'DD-MON-YYYY')
           END account_created,
           bank_charge,
           adop,
           dae,
           open_acct_limit,
           ar_limit,
           order_credit_limit,
           customer_priority,
           DECODE(credit_hold,'true','Y','N') credit_hold,
           DECODE(credit_check,'true','Y','N') credit_check,
           tolerance,
           DECODE(credit_classification,'High Risk','HIGH',
                                        'Low Risk','LOW',
                                        'Moderate Risk','MODERATE',
                                         NULL) credit_classification,
           CASE
             WHEN credit_rating IS NULL THEN
               NULL
             WHEN credit_rating = ' ' THEN
               NULL
             WHEN credit_rating = '_x0020_' THEN
               NULL
             ELSE
               SUBSTR(credit_rating,1,2) 
           END credit_rating,
           collector,
           DECODE(send_statements,'true','Y','N') send_statements,
           DECODE(credit_balance_statements,'true','Y','N') credit_balance_statements,
           DECODE(cycle,'TBD',NULL,' ',NULL,'',NULL,cycle) cycle,
           CASE
             WHEN ( blocked = '_x0020_' ) THEN
               NULL
             ELSE
               blocked
           END blocked,
           DECODE(salesperson_code,'TBD',NULL,' ',NULL,'',NULL,salesperson_code) salesperson_code,
           oracleCustomerIDAJCINE,
           systemModifiedBy,
           exposureNotes,
           -- Nuevos Logistics
           iesClientIDFinancialParty,
           DECODE(getIESARAcctFromCustomer,'true','Y','N') getIESARAcctFromCustomer,
           marketingChannel,
           industrySector,
           --
           gv_org_id org_id,
           TRUNC(SYSDATE) creation_date,
           gv_request_id,
           'NEW' status
      FROM json_table( p_clob_result,
                       '$.value[*]' COLUMNS ( systemid                    VARCHAR2(4000)  path '$.systemid',
                                              No                          VARCHAR2(4000)  path '$.no',
                                              Name                        VARCHAR2(4000)  path '$.name',
                                              Address                     VARCHAR2(4000)  path '$.address',
                                              Address2                    VARCHAR2(4000)  path '$.address2',
                                              Address3                    VARCHAR2(4000)  path '$.address3',
                                              Address4                    VARCHAR2(4000)  path '$.address4',
                                              postCode                    VARCHAR2(4000)  path '$.postCode',
                                              CountryRegionCode           VARCHAR2(4000)  path '$.countryRegionCode',
                                              City                        VARCHAR2(4000)  path '$.city',
                                              MobilePhoneNo               VARCHAR2(4000)  path '$.mobilePhoneNo',
                                              PhoneNo                     VARCHAR2(4000)  path '$.phoneNo',
                                              VatRegistrationNo           VARCHAR2(4000)  path '$.vatRegistrationNo',
                                              PaymentTermsCode            VARCHAR2(4000)  path '$.paymentTermsCode',
                                              lob                         VARCHAR2(4000)  path '$.ajclLOB', -- Cambia el origen en logistics
                                              account_status              VARCHAR2(4000)  path '$.accountStatusAJCINE',
                                              review_cycle                VARCHAR2(4000)  path '$.reviewCycleAJCINE',
                                              last_file_review            VARCHAR2(4000)  path '$.lastFileReviewAJCINE',
                                              scoring_model               VARCHAR2(4000)  path '$.scoringModelAJCINE',
                                              deactivation_reason         VARCHAR2(4000)  path '$.deactivationReason',
                                              coface_limit                VARCHAR2(4000)  path '$.cofaceLimitAJCINE',
                                              insured_country             VARCHAR2(4000)  path '$.insuredCountryAJCINE',
                                              ajc_destination_country     VARCHAR2(4000)  path '$.destinationCountryAJCINE',
                                              account_created             VARCHAR2(4000)  path '$.accountCreatedAJCINE',          
                                              bank_charge                 VARCHAR2(4000)  path '$.bankChargeAJCINE',   
                                              pending_balance             VARCHAR2(4000)  path '$.balanceDueLCY',   
                                              adop                        VARCHAR2(4000)  path '$.adopAJCINE',  
                                              dae                         VARCHAR2(4000)  path '$.daeAJCINE',
                                              open_acct_limit             VARCHAR2(4000)  path '$.openAcctLimitAJCINE',
                                              ar_limit                    VARCHAR2(4000)  path '$.creditLimitLCY',
                                              order_credit_limit          VARCHAR2(4000)  path '$.orderCreditLimitAJCINE',
                                              customer_priority           VARCHAR2(4000)  path '$.customerPriorityINE',
                                              credit_hold                 VARCHAR2(4000)  path '$.creditHoldAJCINE',
                                              credit_check                VARCHAR2(4000)  path '$.creditCheckAJCINE',
                                              tolerance                   VARCHAR2(4000)  path '$.toleranceAJCINE',
                                              credit_classification       VARCHAR2(4000)  path '$.creditClassificationAJCINE',
                                              credit_rating               VARCHAR2(4000)  path '$.creditRatingAJCINE',
                                              collector                   VARCHAR2(4000)  path '$.collectorAJCINE',
                                              send_statements             VARCHAR2(4000)  path '$.sendStatementAJCINE',
                                              credit_balance_statements   VARCHAR2(4000)  path '$.sendCreditBalanceAJCINE',
                                              cycle                       VARCHAR2(4000)  path '$.cycleAJCINE',
                                              blocked                     VARCHAR2(4000)  path '$.blocked',
                                              salesperson_code            VARCHAR2(4000)  path '$.salespersonCode',
                                              oracleCustomerIDAJCINE      VARCHAR2(4000)  path '$.oracleCustomerIDAJCINE',
                                              systemModifiedBy            VARCHAR2(4000)  path '$.systemModifiedBy',
                                              exposureNotes               VARCHAR2(4000)  path '$.exposureNotes',
                                              -- Nuevos Logistics
                                              iesClientIDFinancialParty   VARCHAR2(4000)  path '$.iesClientIDFinancialParty',
                                              getIESARAcctFromCustomer    VARCHAR2(4000)  path '$.getIESARAcctFromCustomer',
                                              marketingChannel            VARCHAR2(4000)  path '$.marketingChannel',
                                              industrySector              VARCHAR2(4000)  path '$.industrySector'
                                              ) );

  BEGIN

    print_log ('ajcl_bc_cust_to_oracle_pkg.get_customers_p (+)');

    mo_global.set_policy_context ('S',84);

    v_get_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,
                                                              p_entity => 'CUSTOMERS', 
                                                              p_subentity => NULL,
                                                              p_method => 'GET',
                                                              p_company_id => gv_bc_company_id )
                 || '?$filter=systemmodifiedat gt ' || TO_CHAR(p_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');

    print_log ( 'v_get_url: ' || v_get_url );

    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );

    print_log ('Se obtienen los clientes y se insertan en la tabla ajcl_bc_customers.');

    FOR cc IN c_customers ( p_clob_result => v_clob_result ) LOOP

      v_customer_number := cc.customer_number;

      INSERT
        INTO ajcl_bc_customers 
             ( systemid,
               customer_number, 
               customer_name,
               customer_type,
               profile_class_id,
               address1,
               address2,
               address3,
               address4,
               country,
               city,
               state,
               zip,
               mobile,
               phone,
               tax_no,
               payment_terms,
               pending_balance,
               lob,
               account_status,
               review_cycle,
               last_file_review,
               scoring_model, 
               aig_limit, 
               deactivation_reason,
               coface_limit, 
               ajc_destination_country,
               insured_country,
               account_created, 
               bank_charge, 
               adop, 
               dae, 
               open_acct_limit,
               ar_limit,
               order_credit_limit,
               customer_priority,
               credit_hold,
               credit_check,
               tolerance,
               credit_classification,
               credit_rating,
               collector,
               send_statements,
               credit_balance_statements,
               cycle,
               blocked,
               salesperson_code,
               oracleCustomerIDAJCINE,
               systemModifiedBy,
               exposure_notes,
               -- Nuevos Logistics
               iesClientIDFinancialParty,
               getIESARAcctFromCustomer,
               marketingChannel,
               industrySector,
               --
               org_id,
               creation_date,
               request_id,
               status )
      VALUES ( cc.systemid,
               cc.customer_number, 
               cc.customer_name,
               cc.customer_type,
               cc.profile_class_id,
               cc.address,
               cc.address2,
               cc.address3,
               cc.address4,
               cc.country,
               cc.city,
               cc.state,
               cc.zip,
               cc.mobile,
               cc.phone, 
               cc.tax_no, 
               cc.standard_terms,  
               cc.pending_balance,
               cc.lob,
               cc.account_status,
               cc.review_cycle,
               cc.last_file_review,
               cc.scoring_model,
               cc.aig_limit,
               cc.deactivation_reason,
               cc.coface_limit,
               cc.ajc_destination_country, -- attribute3
               cc.insured_country, -- attribute11
               cc.account_created,
               cc.bank_charge,
               cc.adop,
               cc.dae,
               cc.open_acct_limit,
               cc.ar_limit,
               cc.order_credit_limit,
               cc.customer_priority,
               cc.credit_hold,
               cc.credit_check,
               cc.tolerance,
               cc.credit_classification,
               cc.credit_rating,
               cc.collector,
               cc.send_statements,
               cc.credit_balance_statements,
               cc.cycle,
               cc.blocked,
               cc.salesperson_code,
               cc.oracleCustomerIDAJCINE,
               cc.systemModifiedBy,
               cc.exposureNotes,
               -- Nuevos Logistics
               cc.iesClientIDFinancialParty,
               cc.getIESARAcctFromCustomer,
               cc.marketingChannel,
               cc.industrySector,
               --
               gv_org_id,
               cc.creation_date,
               gv_request_id,
               cc.status );        

    END LOOP;

    -- Se actualizan como SKIPPED aquellos que fueron modificados por usuarios que no existe en la lookup
    UPDATE ajcl_bc_customers
       SET status = 'SKIPPED'
     WHERE status = 'NEW'
       AND request_id = gv_request_id
       AND systemModifiedBy NOT IN ( SELECT user_security_id
                                       FROM ajc_bc_vend_cust_ifc_users
                                      WHERE bc_environment = gv_bc_environment
                                        AND company = 'LOG'
                                        AND type = 'CUSTOMERS'
                                        AND enabled = 'Y' );

    COMMIT;

    p_status := 'S';
    print_log ('ajcl_bc_cust_to_oracle_pkg.get_customers_p (-)');

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      print_log ('ajcl_bc_cust_to_oracle_pkg.get_customers_p (!)');
      print_log ('Customer: ' || v_customer_number);
      p_status := 'E';
      p_error_message := SQLCODE || ': ' || SQLERRM;

  END get_customers_p;

  -- ------------------------------------------------------------------------------------------------------------------------ --
  -- PROCESS CUSTOMERS ------------------------------------------------------------------------------------------------------ --
  -- ------------------------------------------------------------------------------------------------------------------------ --
  PROCEDURE process_customers_p ( p_count            IN OUT   NUMBER,
                                  p_status           OUT      VARCHAR2, 
                                  p_error_message    OUT      VARCHAR2 ) IS

    CURSOR c_customers IS
    SELECT *
      FROM ajcl_bc_customers
     WHERE status = 'NEW'
       AND request_id = gv_request_id;

    v_statement_cycle_id   NUMBER;
    v_payment_terms_id     NUMBER;
    v_payment_term_active  VARCHAR2(1);
    v_collector_id         NUMBER;

    v_salesperson_id       jtf_rs_salesreps.salesrep_id%TYPE;

    v_campos_sin_valor     VARCHAR2(2000);

    v_review_cycle         fnd_lookup_values.lookup_code%TYPE;
    v_rowid                VARCHAR2(200);
    v_review_cycle_active  VARCHAR2(1);

    e_exception            EXCEPTION;

  BEGIN

    print_log ('ajcl_bc_cust_to_oracle_pkg.process_customers_p (+)');

    p_count := 0;

    FOR cc IN c_customers LOOP

      BEGIN

        p_error_message := NULL;
        p_count := p_count + 1;

        v_statement_cycle_id := NULL;
        v_payment_terms_id := NULL;
        v_collector_id := NULL;

        v_campos_sin_valor := NULL;

        print_log ( 'Customer Number: ' || cc.customer_number );

        -- Customer Name -------------------------------------------------------------------------------------------------------
        print_log ( 'Check Customer Name' );

        IF ( cc.customer_name IS NULL OR cc.customer_name = ' ' ) THEN

          print_log ( 'Customer Name cannot be empty.' );
          v_campos_sin_valor := 'Customer Name, ';

        END IF;

        -- Salesperson Code ----------------------------------------------------------------------------------------------------
        /*
        print_log ( 'Check Salesperson Code' );

        IF ( cc.salesperson_code IS NULL OR cc.salesperson_code = ' ' ) THEN

          print_log ( 'Salesperson Code cannot be empty.' );
          v_campos_sin_valor := v_campos_sin_valor || 'Salesperson Code, ';

        END IF;
        */

        -- LOB -----------------------------------------------------------------------------------------------------------------
        print_log ( 'Check AJCL LOB > LOB' );

        IF ( cc.lob IS NULL OR cc.lob = ' ' ) THEN

          print_log ( 'AJCL LOB cannot be empty.' );
          v_campos_sin_valor := v_campos_sin_valor || 'AJCL LOB, ';

        END IF;

        -- Review Cycle --------------------------------------------------------------------------------------------------------
        print_log ( 'Check Review Cycle' );

        IF ( cc.review_cycle IS NULL OR cc.review_cycle = ' ' ) THEN

          print_log ( 'Review Cycle cannot be empty.' );
          v_campos_sin_valor := v_campos_sin_valor || 'Review Cycle, ';

        ELSE

          v_review_cycle := NULL;
          v_review_cycle_active := NULL;

          -- Se verifica si existe en la lookup de Review Cycle
          BEGIN

            SELECT lookup_code
              INTO v_review_cycle
              FROM fnd_lookup_values
             WHERE lookup_type = 'PERIODIC_REVIEW_CYCLE'
               AND meaning = cc.review_cycle
               AND view_application_id = 222;

            print_log ( 'Review Cycle ' || cc.review_cycle || ' found.' );

          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              -- Si no existe, se crea
              v_review_cycle := UPPER(cc.review_cycle);

              fnd_lookup_values_pkg.insert_row ( X_ROWID => v_rowid,
                                                 X_LOOKUP_TYPE => 'PERIODIC_REVIEW_CYCLE',
                                                 X_VIEW_APPLICATION_ID => 222,
                                                 X_LOOKUP_CODE => v_review_cycle,
                                                 X_TAG => 'Y',
                                                 X_ATTRIBUTE_CATEGORY => NULL,
                                                 X_ATTRIBUTE1 => NULL,
                                                 X_ATTRIBUTE2 => NULL,
                                                 X_ATTRIBUTE3 => NULL,
                                                 X_ATTRIBUTE4 => NULL,
                                                 X_ENABLED_FLAG => 'Y',
                                                 X_START_DATE_ACTIVE => SYSDATE,
                                                 X_END_DATE_ACTIVE => NULL,
                                                 X_TERRITORY_CODE => NULL,
                                                 X_ATTRIBUTE5 => NULL,
                                                 X_ATTRIBUTE6 => NULL,
                                                 X_ATTRIBUTE7 => NULL,
                                                 X_ATTRIBUTE8 => NULL,
                                                 X_ATTRIBUTE9 => NULL,
                                                 X_ATTRIBUTE10 => NULL,
                                                 X_ATTRIBUTE11 => NULL,
                                                 X_ATTRIBUTE12 => NULL,
                                                 X_ATTRIBUTE13 => NULL,
                                                 X_ATTRIBUTE14 => NULL,
                                                 X_ATTRIBUTE15 => NULL,
                                                 X_MEANING => cc.review_cycle,
                                                 X_DESCRIPTION => cc.review_cycle,
                                                 X_CREATION_DATE => SYSDATE,
                                                 X_CREATED_BY => gv_user_id,
                                                 X_LAST_UPDATE_DATE => SYSDATE,
                                                 X_LAST_UPDATED_BY => gv_user_id,
                                                 X_LAST_UPDATE_LOGIN => gv_user_id );

            print_log ( 'Review Cycle ' || cc.review_cycle || ' created.' );

          END;

          -- Se verifica si el review cycle está activo en Oracle
          SELECT DECODE(COUNT(1),0,'N','Y')
            INTO v_review_cycle_active
            FROM fnd_lookup_values
           WHERE lookup_type = 'PERIODIC_REVIEW_CYCLE'
             AND meaning = cc.review_cycle
             AND view_application_id = 222
             AND enabled_flag = 'Y'
             AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE - 1) AND NVL(end_date_active,SYSDATE + 1);

          IF ( v_review_cycle_active = 'N' ) THEN

            v_review_cycle := NULL;
            p_error_message := 'Review Cycle ' || cc.review_cycle || ' is inactive in Oracle.';
            print_log ( p_error_message );
            RAISE e_exception;

          END IF;

        END IF;

        -- Last File Review ----------------------------------------------------------------------------------------------------
        print_log ( 'Check Last File Review' );

        IF ( cc.last_file_review IS NULL OR cc.last_file_review = ' ' ) THEN

          print_log ( 'Last File Review cannot be empty.' );
          v_campos_sin_valor := v_campos_sin_valor || 'Last File Review, ';

        END IF;

        -- Next File Review ----------------------------------------------------------------------------------------------------
        -- No se controla, es un campo nuevo de BC, no existe en Oracle

        -- Insured Country -----------------------------------------------------------------------------------------------------
        print_log ( 'Check Insured Country' );

        IF ( cc.insured_country IS NULL OR cc.insured_country = ' ' ) THEN

          print_log ( 'Insured Country cannot be empty.' );
          v_campos_sin_valor := v_campos_sin_valor || 'Insured Country, ';

        END IF;

        -- AJC Destination Country ---------------------------------------------------------------------------------------------
        print_log ( 'Check AJC Destination Country' );

        IF ( cc.ajc_destination_country IS NULL OR cc.ajc_destination_country = ' ' ) THEN

          print_log ( 'AJC Destination Country cannot be empty.' );
          v_campos_sin_valor := v_campos_sin_valor || 'AJC Destination Country, ';

        END IF;

        -- Account Created -----------------------------------------------------------------------------------------------------
        print_log ( 'Check Account Created' );

        IF ( cc.account_created IS NULL OR cc.account_created = ' ' ) THEN

          print_log ( 'Account Created cannot be empty.' );
          v_campos_sin_valor := v_campos_sin_valor || 'Account Created, ';

        END IF;

        -- DAE -----------------------------------------------------------------------------------------------------------------
        print_log ( 'Check DAE' );

        IF ( cc.dae IS NULL OR cc.dae = ' ' ) THEN

          print_log ( 'DAE cannot be empty.' );
          v_campos_sin_valor := v_campos_sin_valor || 'DAE, ';

        END IF;

        -- Open Acct Limit  ----------------------------------------------------------------------------------------------------
        print_log ( 'Check Open Acct Limit' );

        IF ( cc.open_acct_limit IS NULL OR cc.open_acct_limit = ' ' ) THEN

          print_log ( 'Open Acct Limit cannot be empty.' );
          v_campos_sin_valor := v_campos_sin_valor || 'Open Acct Limit, ';

        END IF;

        -- A/R Limit  ----------------------------------------------------------------------------------------------------------
        print_log ( 'Check A/R Limit' );

        IF ( cc.ar_limit IS NULL ) THEN

          print_log ( 'A/R Limit cannot be empty.' );
          v_campos_sin_valor := v_campos_sin_valor || 'A/R Limit, ';

        END IF;

        -- Collector  ----------------------------------------------------------------------------------------------------------
        print_log ( 'Check Collector' );

        IF ( cc.collector IS NULL OR cc.collector = ' ' ) THEN

          print_log ( 'Collector cannot be empty.' );
          v_campos_sin_valor := v_campos_sin_valor || 'Collector, ';

        END IF;

        -- Address -------------------------------------------------------------------------------------------------------------
        print_log ( 'Check Address' );

        IF ( cc.address1 IS NULL OR cc.address1 = ' ' ) THEN

          print_log ( 'Address cannot be empty.' );
          v_campos_sin_valor := v_campos_sin_valor || 'Address, ';

        END IF;

        -- Country/Region Code -------------------------------------------------------------------------------------------------
        print_log ( 'Check Country/Region Code' );

        IF ( cc.country IS NULL OR cc.country = ' ' ) THEN

          print_log ( 'Country/Region Code cannot be empty.' );
          v_campos_sin_valor := v_campos_sin_valor || 'Country/Region Code, ';

        END IF;

        -- City ----------------------------------------------------------------------------------------------------------------
        /*
        print_log ( 'Check City' );

        IF ( cc.city IS NULL OR cc.city = ' ' ) THEN

          print_log ( 'City cannot be empty.' );
          v_campos_sin_valor := v_campos_sin_valor || 'City, ';

        END IF;
        */

        -- Se controla si falta el valor para uno o mas campos
        -- Si es asi, se corta el procesamiento y se manda a la exception
        IF ( v_campos_sin_valor IS NOT NULL ) THEN

          -- Se quita ', ' del final
          v_campos_sin_valor := SUBSTR(v_campos_sin_valor,1,LENGTH(v_campos_sin_valor) - 2);

          -- Se reemplaza la ultima , por un and
          IF ( INSTR(v_campos_sin_valor,',') != 0 ) THEN

            v_campos_sin_valor := regexp_replace(v_campos_sin_valor,',',' and',instr(v_campos_sin_valor,',',-1));

          END IF;

          -- Se agrega string al final
          v_campos_sin_valor := v_campos_sin_valor || ' cannot be empty.';

          p_error_message := v_campos_sin_valor;
          RAISE e_exception;

        END IF;

        -- Salesperson Code
        v_salesperson_id := NULL;

        IF ( cc.salesperson_code IS NOT NULL ) THEN

          -- Se verifica si existe en Oracle
          BEGIN

            SELECT salesrep_id
              INTO v_salesperson_id
              FROM jtf_rs_salesreps sr
             WHERE sr.name = cc.salesperson_code
               AND NVL(status,'A') = 'A'
               AND SYSDATE BETWEEN start_date_active AND NVL(end_date_active,SYSDATE + 1);

            print_log ( 'salesperson_id: ' || v_salesperson_id );

          EXCEPTION
            WHEN NO_DATA_FOUND THEN
              print_log ( 'Salesperson Code ' || cc.salesperson_code || ' not found in jtf_rs_salesreps.' );
              v_salesperson_id := NULL;

          END;

        END IF;

        -- Collector
        print_log ( 'Collector: ' || cc.collector );
        v_collector_id := ajc_bc_create_entities_pkg.collector_f ( cc.collector );
        print_log ( 'v_collector_id: ' || v_collector_id );

        -- Statements  ---------------------------------------------------------------------------------------------------------
        print_log ( 'Check Statements' );

        -- Send Statements
        IF ( cc.send_statements = 'Y' ) THEN

          print_log ( 'Cycle: ' || cc.cycle );
          v_statement_cycle_id := ajc_bc_create_entities_pkg.statement_cycle_f ( cc.cycle );
          print_log ( 'v_statement_cycle_id: ' || v_statement_cycle_id );

        END IF;

        -- Payment Terms -----------------------------------------------------
