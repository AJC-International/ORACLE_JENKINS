CREATE OR REPLACE PACKAGE BODY ajcl_bc_cust_to_oracle_pkg IS

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



        -- Payment Terms -------------------------------------------------------------------------------------------------------

        print_log ( 'Check Payment Terms' );



        -- Payment Terms

        IF ( cc.payment_terms IS NOT NULL AND cc.payment_terms != ' ' ) THEN



          print_log ( 'Payment Terms: ' || cc.payment_terms );

          v_payment_terms_id := ajc_bc_create_entities_pkg.payment_terms_f ( cc.payment_terms, 'AR', gv_bc_company_id, gv_bc_environment );                                                                                            

          print_log ( 'v_payment_terms_id: ' || v_payment_terms_id );



          -- Se verifica si el payment terms está activo en Oracle

          SELECT DECODE(COUNT(1),0,'N','Y')

            INTO v_payment_term_active

            FROM ra_terms

           WHERE term_id = v_payment_terms_id

             AND TRUNC(SYSDATE) BETWEEN TRUNC(start_date_active) AND TRUNC(NVL(end_date_active - 1,SYSDATE + 1));



          IF ( v_payment_term_active = 'N' ) THEN



            print_log ( 'Payment Term is inactive.' );

            p_error_message := 'Payment Term ' || cc.payment_terms || ' is inactive in Oracle.';

            RAISE e_exception;



          END IF;



        END IF;



        UPDATE ajcl_bc_customers

           SET statement_cycle_id = v_statement_cycle_id,

               payment_terms_id = v_payment_terms_id,

               collector_id = v_collector_id,

               salesperson_id = v_salesperson_id,

               review_cycle = v_review_cycle,

               status = 'PROCESSED',

               processed_date = TRUNC(SYSDATE)

         WHERE customer_number = cc.customer_number

           AND status = 'NEW'

           AND request_id = gv_request_id

           AND message IS NULL

           AND processed_date IS NULL; 



        COMMIT;



        print_log ( 'Record Updated. PROCESSED' );

        print_log ( ' ' );



      EXCEPTION

        WHEN e_exception THEN



          ROLLBACK;



          UPDATE ajcl_bc_customers

             SET status = 'ERROR',

                 processed_date = TRUNC(SYSDATE),

                 message = p_error_message

           WHERE customer_number = cc.customer_number

             AND status = 'NEW'

             AND request_id = gv_request_id

             AND message IS NULL

             AND processed_date IS NULL;    



          print_log ( 'Record Updated. ERROR' );



          COMMIT;



        WHEN OTHERS THEN



          ROLLBACK;



          UPDATE ajcl_bc_customers

             SET status = 'ERROR',

                 processed_date = TRUNC(SYSDATE),

                 message = 'Error al procesar el cliente.'

           WHERE customer_number = cc.customer_number

             AND status = 'NEW'

             AND request_id = gv_request_id

             AND message IS NULL

             AND processed_date IS NULL;  



          print_log ( 'Record Updated. ERROR' );



          COMMIT;



      END;



    END LOOP;



    p_status := 'S';

    print_log ('ajcl_bc_cust_to_oracle_pkg.process_customers_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      print_log ('ajcl_bc_cust_to_oracle_pkg.process_customers_p (!)');

      p_status := 'E';

      p_error_message := SQLCODE || ': ' || SQLERRM;



  END process_customers_p;



  PROCEDURE address_p ( p_tbl_status                VARCHAR2,

                        p_customer_id               NUMBER,

                        p_address1                  VARCHAR2,

                        p_address2                  VARCHAR2,

                        p_address3                  VARCHAR2,

                        p_address4                  VARCHAR2,

                        p_ajc_destination_country   VARCHAR2,

                        p_country                   VARCHAR2,

                        p_city                      VARCHAR2,

                        p_state                     VARCHAR2,

                        p_zip                       VARCHAR2,

                        p_mobile                    VARCHAR2,

                        p_phone                     VARCHAR2,

                        p_location_id               IN OUT   NUMBER,

                        p_party_id                  NUMBER,

                        p_party_site_id             IN OUT   NUMBER,

                        p_cust_acct_site_id         IN OUT   NUMBER,

                        p_bill_to_site_use_id       IN OUT   NUMBER,

                        p_ship_to_site_use_id       IN OUT   NUMBER,

                        p_addr_status               IN OUT   VARCHAR2,

                        p_return_msg                IN OUT   VARCHAR2 ) IS



    v_return_status             VARCHAR2 (1);

    v_msg_count                 NUMBER;

    v_msg_data                  VARCHAR2 (4000);



    v_location_rec              HZ_LOCATION_V2PUB.LOCATION_REC_TYPE;

    v_location_id               NUMBER;

    v_location_ovn              NUMBER;

    e_location                  EXCEPTION;



    v_party_site_rec            HZ_PARTY_SITE_V2PUB.PARTY_SITE_REC_TYPE;

    v_party_site_id             hz_party_sites.party_site_id%TYPE;

    v_party_site_number         hz_party_sites.party_site_number%TYPE;

    v_party_site_ovn            NUMBER;

    e_party_site                EXCEPTION;



    v_cust_acct_site_rec        HZ_CUST_ACCOUNT_SITE_V2PUB.CUST_ACCT_SITE_REC_TYPE;

    v_cust_acct_site_id         hz_cust_acct_sites_all.cust_acct_site_id%type;

    v_cust_acct_site_ovn        NUMBER;

    e_cust_acct_site            EXCEPTION;



    v_cust_site_use_rec         HZ_CUST_ACCOUNT_SITE_V2PUB.CUST_SITE_USE_REC_TYPE;

    v_customer_profile_rec      HZ_CUSTOMER_PROFILE_V2PUB.CUSTOMER_PROFILE_REC_TYPE;

    v_bill_to_site_use_id       NUMBER;

    v_bill_to_site_use_ovn      NUMBER;

    v_ship_to_site_use_id       NUMBER;

    v_ship_to_site_use_ovn      NUMBER;



    e_address_duplicate         EXCEPTION;

    e_bill_to_site_use          EXCEPTION;

    e_ship_to_site_use          EXCEPTION;



  BEGIN



    print_log ( ' ' );

    print_log ( 'address_p (+)');



    p_addr_status := 'Y';

    v_location_rec := null;



    print_log ('p_address1: ' || p_address1);

    print_log ('p_address2: ' || p_address2);

    print_log ('p_address3: ' || p_address3);

    print_log ('p_address4: ' || p_address4);

    print_log ('p_ajc_destination_country: ' || p_ajc_destination_country);

    print_log ('p_country: ' || p_country);

    print_log ('p_city: ' || p_city);

    print_log ('p_state: ' || p_state);

    print_log ('p_zip: ' || p_zip);



    -- Se mapea el country

    /* 

    BEGIN



      SELECT meaning

        INTO v_location_rec.country

        FROM fnd_lookup_values

       WHERE lookup_type = 'AJC_BC_COUNTRY_CODES'

         AND lookup_code = p_country;



      print_log ( 'BC Country: ' || p_country );

      print_log ( 'Oracle Country: ' || v_location_rec.country );



    EXCEPTION

      WHEN NO_DATA_FOUND THEN

        print_log ( 'BC Country Code ' || p_country || ' not found in Oracle.' );

        v_location_rec.country := p_country;



    END;

    */

    BEGIN



      SELECT territory_code 

        INTO v_location_rec.country

        FROM fnd_territories_vl 

       WHERE iso_territory_code = p_country;



    EXCEPTION

      WHEN NO_DATA_FOUND THEN

        print_log ( 'BC Country Code ' || p_country || ' not found in Oracle.' );

        v_location_rec.country := p_country;



    END;



    -- Se verifica si existen las entidades

    -- Si el cliente se actualizo, se deben obtener los id para actualizar las entidades

    IF ( p_tbl_status = 'UPDATED' ) THEN



      BEGIN



        SELECT hcas.cust_acct_site_id

              ,hcas.object_version_number

              ,hps.party_site_id

              ,hps.object_version_number

              ,hl.location_id

              ,hl.object_version_number

              ,hcsu_bt.site_use_id

              ,hcsu_bt.object_version_number

              ,hcsu_st.site_use_id

              ,hcsu_st.object_version_number

          INTO v_cust_acct_site_id

              ,v_cust_acct_site_ovn

              ,v_party_site_id

              ,v_party_site_ovn

              ,v_location_id

              ,v_location_ovn

              ,v_bill_to_site_use_id

              ,v_bill_to_site_use_ovn

              ,v_ship_to_site_use_id

              ,v_ship_to_site_use_ovn

          FROM hz_cust_acct_sites_all hcas

              ,hz_party_sites hps

              ,hz_locations hl

              ,hz_cust_site_uses_all hcsu_bt

              ,hz_cust_site_uses_all hcsu_st

         WHERE hcas.cust_account_id = p_customer_id

           --

           AND hcas.org_id = gv_org_id

           --

           AND hcas.status = 'A'

           AND hcas.party_site_id = hps.party_site_id (+)

           AND hps.location_id = hl.location_id (+)

           AND hcas.cust_acct_site_id = hcsu_bt.cust_acct_site_id (+)

           AND hcsu_bt.site_use_code (+) = 'BILL_TO'

           --

           AND hcsu_bt.primary_flag = 'Y'

           AND hcsu_bt.status = 'A'

           --

           AND hcas.cust_acct_site_id = hcsu_st.cust_acct_site_id (+)

           AND hcsu_st.site_use_code (+) = 'SHIP_TO'

           /*

           AND NVL(hl.address1,'*') = NVL(p_address1,'*') 

           AND NVL(hl.address2,'*') = NVL(p_address2,'*')

           AND NVL(hl.city,'*') = NVL(p_city,'*')

           AND NVL(hl.country,'*') = NVL(v_location_rec.country,'*')

           AND NVL(hl.state,'*') = NVL(p_state,'*')   

           AND NVL(hl.postal_code,'*') = NVL(p_zip,'*')

           */

           ;



        print_log ('v_cust_acct_site_id: ' || v_cust_acct_site_id);

        print_log ('v_cust_acct_site_ovn: ' || v_cust_acct_site_ovn);

        print_log ('v_party_site_id: ' || v_party_site_id);

        print_log ('v_party_site_ovn: ' || v_party_site_ovn);

        print_log ('v_location_id: ' || v_location_id);

        print_log ('v_location_ovn: ' || v_location_ovn);

        print_log ('v_bill_to_site_use_id: ' || v_bill_to_site_use_id);

        print_log ('v_bill_to_site_use_ovn: ' || v_bill_to_site_use_ovn);

        print_log ('v_ship_to_site_use_id: ' || v_ship_to_site_use_id);

        print_log ('v_ship_to_site_use_ovn: ' || v_ship_to_site_use_ovn); 



      EXCEPTION

        WHEN NO_DATA_FOUND THEN

          v_bill_to_site_use_id := NULL;

          v_ship_to_site_use_id := NULL;

          v_cust_acct_site_id := NULL;

          v_party_site_id := NULL;

          v_location_id := NULL;



        WHEN TOO_MANY_ROWS THEN

          v_bill_to_site_use_id := NULL;

          v_ship_to_site_use_id := NULL;

          v_cust_acct_site_id := NULL;

          v_party_site_id := NULL;

          v_location_id := NULL;



          print_log ('La dirección está duplicada en Oracle, no es posible actualizar solo una.');

          p_return_msg := ('La dirección está duplicada en Oracle, no es posible actualizar solo una.');

          p_addr_status := 'N';



          RAISE e_address_duplicate;



      END; 



    ELSE



      -- Si el cliente se creo, se debe crear la direccion

      v_bill_to_site_use_id := NULL;

      v_ship_to_site_use_id := NULL;

      v_cust_acct_site_id := NULL;

      v_party_site_id := NULL;

      v_location_id := NULL;



    END IF;



    v_location_rec.address1 := NVL(p_address1,FND_API.G_MISS_CHAR);

    v_location_rec.address2 := NVL(p_address2,FND_API.G_MISS_CHAR);

    v_location_rec.address3 := NVL(p_address3,FND_API.G_MISS_CHAR);

    v_location_rec.address4 := NVL(p_address4,FND_API.G_MISS_CHAR);

    v_location_rec.city := NVL(p_city,FND_API.G_MISS_CHAR);

    v_location_rec.state := NVL(p_state,FND_API.G_MISS_CHAR);

    v_location_rec.postal_code := NVL(p_zip,FND_API.G_MISS_CHAR);



    -- LOCATION

    IF ( v_location_id IS NULL ) THEN



      v_location_rec.created_by_module := 'TCA_V2_API';



      print_log ('HZ_LOCATION_V2PUB.CREATE_LOCATION');

      HZ_LOCATION_V2PUB.CREATE_LOCATION( p_init_msg_list => FND_API.G_TRUE,

                                         p_location_rec  => v_location_rec,

                                         x_location_id   => v_location_id,

                                         x_return_status => v_return_status,

                                         x_msg_count     => v_msg_count,

                                         x_msg_data      => v_msg_data );



      IF v_return_status != fnd_api.g_ret_sts_success THEN



        p_addr_status := 'N';

        p_return_msg := v_msg_data;

        RAISE e_location;



      ELSE



        p_location_id := v_location_id;



        print_log ('Se crea el location. location_id: ' || p_location_id);



      END IF;   



    ELSE -- v_location_id IS NOT NULL



      print_log ('La location existe. Se modifica.');



      v_location_rec.location_id := v_location_id;

      p_location_id := v_location_id;



      print_log ('HZ_LOCATION_V2PUB.update_location');

      HZ_LOCATION_V2PUB.update_location ( p_init_msg_list => FND_API.G_FALSE,

                                          p_location_rec => v_location_rec,

                                          p_object_version_number => v_location_ovn,

                                          x_return_status => v_return_status,

                                          x_msg_count => v_msg_count,

                                          x_msg_data => v_msg_data );



      IF v_return_status != fnd_api.g_ret_sts_success THEN



        p_addr_status := 'N';

        p_return_msg := 'La location no pudo ser actualizada. ' || v_msg_data;

        RAISE e_location;



      ELSE



        print_log ( 'Location actualizada.');



      END IF;  



    END IF;



    -- PARTY SITE

    v_party_site_rec := null;



    v_party_site_rec.party_id := p_party_id;

    v_party_site_rec.location_id := p_location_id;

    v_party_site_rec.identifying_address_flag := 'Y';



    IF ( v_party_site_id IS NULL ) THEN



      v_party_site_rec.created_by_module := 'TCA_V2_API';



      print_log ('HZ_PARTY_SITE_V2PUB.CREATE_PARTY_SITE');      

      HZ_PARTY_SITE_V2PUB.CREATE_PARTY_SITE ( p_init_msg_list     => FND_API.G_TRUE,

                                              p_party_site_rec    => v_party_site_rec,

                                              x_party_site_id     => v_party_site_id,

                                              x_party_site_number => v_party_site_number,

                                              x_return_status     => v_return_status,

                                              x_msg_count         => v_msg_count,

                                              x_msg_data          => v_msg_data );



      IF v_return_status != fnd_api.g_ret_sts_success THEN



        p_addr_status := 'N';

        p_return_msg := v_msg_data;

        RAISE e_party_site;



      ELSE



        p_party_site_id := v_party_site_id;



        print_log ('Se crea el party site. party_site_id: ' || p_party_site_id);



      END IF;



    ELSE -- v_party_site_id IS NOT NULL



      print_log ('El party site existe. Se modifica.');



      v_party_site_rec.party_site_id := v_party_site_id;

      p_party_site_id := v_party_site_id;



      print_log ('HZ_PARTY_SITE_V2PUB.update_party_site');  

      HZ_PARTY_SITE_V2PUB.update_party_site ( p_init_msg_list => FND_API.G_FALSE,

                                              p_party_site_rec => v_party_site_rec,

                                              p_object_version_number => v_party_site_ovn,

                                              x_return_status => v_return_status,

                                              x_msg_count => v_msg_count,

                                              x_msg_data => v_msg_data );



      IF v_return_status != fnd_api.g_ret_sts_success THEN



        p_addr_status := 'N';

        p_return_msg := 'Party Site no pudo ser actualizado. ' || v_msg_data;

        RAISE e_party_site;



      ELSE



        print_log ( 'Party Site actualizado.');



      END IF; 



    END IF;



    -- CUST ACCT SITE

    v_cust_acct_site_rec := NULL;



    v_cust_acct_site_rec.cust_account_id := p_customer_id;

    v_cust_acct_site_rec.party_site_id := p_party_site_id;

    v_cust_acct_site_rec.attribute1 := NVL(p_ajc_destination_country,FND_API.G_MISS_CHAR);



    IF ( v_cust_acct_site_id IS NULL ) THEN



      print_log ('Cust Acct Site no existe. Se crea.');

      -- v_cust_acct_site_rec.org_id := gv_org_id; -- r_cust.bill_to_org;

      -- v_cust_acct_site_rec.global_attribute_category := 'JL.AR.ARXCUDCI.Additional';

      v_cust_acct_site_rec.created_by_module := 'TCA_V2_API';



      print_log ('HZ_CUST_ACCOUNT_SITE_V2PUB.CREATE_CUST_ACCT_SITE');

      HZ_CUST_ACCOUNT_SITE_V2PUB.CREATE_CUST_ACCT_SITE ( p_init_msg_list         => FND_API.G_TRUE,

                                                         p_cust_acct_site_rec    => v_cust_acct_site_rec,

                                                         x_cust_acct_site_id     => v_cust_acct_site_id,

                                                         x_return_status         => v_return_status,

                                                         x_msg_count             => v_msg_count,

                                                         x_msg_data              => v_msg_data);



      IF v_return_status != fnd_api.g_ret_sts_success THEN



        p_addr_status := 'N';

        p_return_msg := v_msg_data;

        RAISE e_cust_acct_site;



      ELSE



        p_cust_acct_site_id := v_cust_acct_site_id;



        print_log ('Se crea el cust acct site. cust_acct_site_id: ' || p_cust_acct_site_id);



      END IF;



    ELSE -- v_cust_acct_site_id IS NOT NULL



      print_log ('Cust Acct Site existe. Se modifica.');



      -- v_cust_acct_site_rec.party_site_id := v_cust_acct_site_id;

      v_cust_acct_site_rec.cust_acct_site_id := v_cust_acct_site_id;

      p_cust_acct_site_id := v_cust_acct_site_id;



      print_log ('HZ_CUST_ACCOUNT_SITE_V2PUB.update_cust_acct_site');  

      HZ_CUST_ACCOUNT_SITE_V2PUB.update_cust_acct_site ( p_init_msg_list => FND_API.G_TRUE,

                                                         p_cust_acct_site_rec => v_cust_acct_site_rec,

                                                         p_object_version_number => v_cust_acct_site_ovn,

                                                         x_return_status => v_return_status,

                                                         x_msg_count => v_msg_count,

                                                         x_msg_data => v_msg_data );                             



      IF v_return_status != fnd_api.g_ret_sts_success THEN



        p_addr_status := 'N';

        p_return_msg := 'Cust Acct Site no pudo ser actualizado. ' || v_msg_data;

        RAISE e_cust_acct_site;



      ELSE



        print_log ( 'Cust Acct Site actualizado.');



      END IF;



    END IF;



    v_customer_profile_rec := NULL;

    v_cust_site_use_rec := NULL;



    v_cust_site_use_rec.cust_acct_site_id         := v_cust_acct_site_id;

    v_cust_site_use_rec.site_use_code             := 'BILL_TO';

    v_cust_site_use_rec.location                  := 'NONE';

    v_cust_site_use_rec.primary_flag              := 'Y';



    -- BILL-TO

    IF ( v_bill_to_site_use_id IS NULL ) THEN



      print_log ('Cust Site Use BILL-TO no existe. Se crea.');

      v_cust_site_use_rec.created_by_module := 'TCA_V2_API';



      print_log ('HZ_CUST_ACCOUNT_SITE_V2PUB.CREATE_CUST_SITE_USE');  

      HZ_CUST_ACCOUNT_SITE_V2PUB.CREATE_CUST_SITE_USE ( p_init_msg_list         => FND_API.G_TRUE,

                                                        p_cust_site_use_rec     => v_cust_site_use_rec,

                                                        p_customer_profile_rec  => v_customer_profile_rec,

                                                        p_create_profile        => FND_API.G_FALSE,

                                                        p_create_profile_amt    => FND_API.G_TRUE,

                                                        x_site_use_id           => v_bill_to_site_use_id,

                                                        x_return_status         => v_return_status,

                                                        x_msg_count             => v_msg_count,

                                                        x_msg_data              => v_msg_data );



      IF v_return_status != fnd_api.g_ret_sts_success THEN



        p_addr_status := 'N';

        p_return_msg := v_msg_data;

        RAISE e_bill_to_site_use; 



      ELSE



        p_bill_to_site_use_id := v_bill_to_site_use_id;



        print_log ('Se crea el Site Use BILL-TO. p_site_use_id: ' || p_bill_to_site_use_id);



      END IF;



    /*

    ELSE -- v_bill_to_site_use_id IS NOT NULL



      print_log ('Cust Site Use BILL-TO existe. Se modifica.');



      v_cust_site_use_rec.site_use_id := v_bill_to_site_use_id;



      print_log ('HZ_CUST_ACCOUNT_SITE_V2PUB.update_cust_site_use');                                                     

      HZ_CUST_ACCOUNT_SITE_V2PUB.update_cust_site_use ( p_init_msg_list => FND_API.G_TRUE,

                                                        p_cust_site_use_rec => v_cust_site_use_rec,

                                                        p_object_version_number => v_bill_to_site_use_ovn,

                                                        x_return_status => v_return_status,

                                                        x_msg_count => v_msg_count,

                                                        x_msg_data => v_msg_data );



      IF v_return_status != fnd_api.g_ret_sts_success THEN



        p_addr_status := 'N';

        p_return_msg := v_msg_data;

        RAISE e_bill_to_site_use; 



      ELSE



        p_addr_status := 'Y';



      END IF;

    */  

    END IF;



    v_customer_profile_rec := NULL;

    v_cust_site_use_rec := NULL;



    v_cust_site_use_rec.cust_acct_site_id         := v_cust_acct_site_id;

    v_cust_site_use_rec.site_use_code             := 'SHIP_TO';

    v_cust_site_use_rec.bill_to_site_use_id       := v_bill_to_site_use_id;

    v_cust_site_use_rec.location                  := 'NONE';

    v_cust_site_use_rec.primary_flag              := 'Y';



    -- SHIP_TO

    IF ( v_ship_to_site_use_id IS NULL ) THEN



      print_log ('Cust Site Use SHIP-TO no existe. Se crea.');      

      v_cust_site_use_rec.created_by_module := 'TCA_V2_API';



      print_log ('HZ_CUST_ACCOUNT_SITE_V2PUB.CREATE_CUST_SITE_USE');

      HZ_CUST_ACCOUNT_SITE_V2PUB.CREATE_CUST_SITE_USE ( p_init_msg_list         => FND_API.G_TRUE,

                                                        p_cust_site_use_rec     => v_cust_site_use_rec,

                                                        p_customer_profile_rec  => v_customer_profile_rec,

                                                        p_create_profile        => FND_API.G_FALSE,

                                                        p_create_profile_amt    => FND_API.G_TRUE,

                                                        x_site_use_id           => v_ship_to_site_use_id,

                                                        x_return_status         => v_return_status,

                                                        x_msg_count             => v_msg_count,

                                                        x_msg_data              => v_msg_data );



      IF v_return_status != fnd_api.g_ret_sts_success THEN



        p_addr_status := 'N';

        p_return_msg := v_msg_data;

        RAISE e_ship_to_site_use; 



      ELSE



        p_ship_to_site_use_id := v_ship_to_site_use_id;



        print_log ('Se crea el Site Use SHIP-TO. p_site_use_id: ' || p_ship_to_site_use_id);



      END IF;



    /*

    ELSE -- v_ship_to_site_use_id IS NOT NULL



      print_log ('Cust Site Use SHIP-TO existe. Se modifica.');



      v_cust_site_use_rec.site_use_id := v_ship_to_site_use_id;



      print_log ('HZ_CUST_ACCOUNT_SITE_V2PUB.update_cust_site_use');                                                   

      HZ_CUST_ACCOUNT_SITE_V2PUB.update_cust_site_use ( p_init_msg_list => FND_API.G_TRUE,

                                                        p_cust_site_use_rec => v_cust_site_use_rec,

                                                        p_object_version_number => v_ship_to_site_use_ovn,

                                                        x_return_status => v_return_status,

                                                        x_msg_count => v_msg_count,

                                                        x_msg_data => v_msg_data );



      IF v_return_status != fnd_api.g_ret_sts_success THEN



        p_addr_status := 'N';

        p_return_msg := v_msg_data;

        RAISE e_ship_to_site_use; 



      ELSE



        p_addr_status := 'Y';



      END IF;

    */  

    END IF;



    print_log ('address_p (-)');



  EXCEPTION

    WHEN e_address_duplicate THEN

      print_log ('address_p (!)');

      print_log ('Error al buscar si la dirección existe.');

    WHEN e_location THEN

      print_log ('address_p (!)');

      print_log ('Error al crear el location.');

    WHEN e_party_site THEN

      print_log ('address_p (!)');

      print_log ('Error al crear el party site.');      

    WHEN e_cust_acct_site THEN

      print_log ('address_p (!)');

      print_log ('Error al crear el cust acct site.'); 

    WHEN e_bill_to_site_use THEN

      print_log ('address_p (!)');

      print_log ('Error al crear el site use BILL-TO.'); 

    WHEN e_ship_to_site_use THEN

      print_log ('address_p (!)');

      print_log ('Error al crear el site use SHIP-TO.'); 



  END address_p;



  PROCEDURE contact_p ( p_customer_id               NUMBER,

                        p_customer_party_id         NUMBER,

                        p_person_last_name          VARCHAR2,

                        p_status              OUT   VARCHAR2, 

                        p_return_msg          OUT   VARCHAR2 ) IS



    v_contacts_count          NUMBER;  



    CURSOR c_contacts IS

    SELECT party_id,

           party_number,

           object_version_number

      FROM hz_parties

     WHERE party_id IN ( SELECT r.subject_id

                           FROM hz_cust_account_roles car,

                                hz_relationships r             

                          WHERE car.cust_account_id = p_customer_id

                            AND car.attribute1 = 'Y'

                            AND car.party_id = r.party_id

                            AND r.subject_type = 'PERSON'

                            AND r.relationship_type = 'CONTACT' );



    v_object_version_number   NUMBER;

    v_party_rec               HZ_PARTY_V2PUB.party_rec_type;



    -- Person

    v_person_rec              HZ_PARTY_V2PUB.person_rec_type;

    v_party_id                NUMBER;

    v_party_number            VARCHAR2(2000);

    v_profile_id              NUMBER;



    -- Org Contact

    v_org_contact_rec         HZ_PARTY_CONTACT_V2PUB.ORG_CONTACT_REC_TYPE;

    v_api_message             VARCHAR2(4000);

    v_msg_index_out           NUMBER;

    v_org_contact_id          NUMBER;

    v_party_rel_id            NUMBER;

    v_oc_party_id             NUMBER;

    v_oc_party_number         VARCHAR2(150);



    -- Role

    v_cr_cust_acc_role_rec    HZ_CUST_ACCOUNT_ROLE_V2PUB.CUST_ACCOUNT_ROLE_REC_TYPE;

    v_cust_account_role_id    NUMBER;



    v_return_status       VARCHAR2(2000);

    v_msg_count           NUMBER;

    v_msg_data            VARCHAR2(2000);



    e_exception           EXCEPTION;



  BEGIN



    print_log ( ' ' );

    print_log ( 'ajcl_bc_cust_to_oracle_pkg.contact_p (+)' );



    v_person_rec.person_last_name := p_person_last_name;

    v_person_rec.person_first_name := 'BC EXPOSURE NOTES';



    -- Se verifica si tiene contactos

    SELECT COUNT(1)

      INTO v_contacts_count

      FROM hz_cust_account_roles car,

           hz_relationships r             

     WHERE car.cust_account_id = p_customer_id

       AND car.attribute1 = 'Y'

       AND car.party_id = r.party_id

       AND r.subject_type = 'PERSON'

       AND r.relationship_type = 'CONTACT'; 



    -- Ya existe el rol y el party de la persona

    IF ( v_contacts_count != 0 ) THEN



      print_log ( 'Roles exists.' );

      print_log ( 'Updating Persons..' );



      FOR cc IN c_contacts LOOP



        print_log ( 'party_id: ' || cc.party_id );



        v_party_rec := NULL;



        v_party_rec.party_id := cc.party_id;

        v_party_rec.party_number := cc.party_number;

        v_object_version_number := cc.object_version_number;



        v_person_rec.party_rec := v_party_rec;



        HZ_PARTY_V2PUB.UPDATE_PERSON ( p_init_msg_list => FND_API.G_FALSE,

                                       p_person_rec => v_person_rec,

                                       p_party_object_version_number => v_object_version_number,

                                       x_profile_id => v_profile_id,

                                       x_return_status => v_return_status,

                                       x_msg_count => v_msg_count,

                                       x_msg_data => v_msg_data );



        print_log ( 'Person updated.' );



      END LOOP;                                       



    ELSE



      v_person_rec.created_by_module := 'TCA_V2_API';



    -- Create Person

      print_log ( 'Creating Person..' );



      HZ_PARTY_V2PUB.CREATE_PERSON ( p_init_msg_list => 'T',

                                     p_person_rec => v_person_rec,

                                     x_party_id => v_party_id,

                                     x_party_number => v_party_number,

                                     x_profile_id => v_profile_id,

                                     x_return_status => v_return_status,

                                     x_msg_count => v_msg_count,

                                     x_msg_data => v_msg_data );



      IF v_msg_count > 1 THEN



        FOR I IN 1 .. v_msg_count LOOP



          p_return_msg := 'Error Create - Person. ' || I || '. ' || SUBSTR(FND_MSG_PUB.GET ( p_encoded => FND_API.G_FALSE ), 1, 255);



        END LOOP;



        RAISE e_exception;



      END IF;



      print_log ( 'Person created.' );



      print_log ( 'v_party_id: ' || v_party_id );

      print_log ( 'v_party_number: ' || v_party_number );

      print_log ( 'v_profile_id: ' || v_profile_id );

      print_log ( 'v_return_status: ' || v_return_status );

      print_log ( 'v_msg_count: ' || v_msg_count );

      print_log ( 'v_msg_data: ' || v_msg_data );



    -- Create Org Contact

      print_log ( 'Creating Org Contact..' );



      v_org_contact_rec.party_rel_rec.relationship_code := 'CONTACT_OF';

      v_org_contact_rec.party_rel_rec.relationship_type := 'CONTACT';

      v_org_contact_rec.party_rel_rec.subject_id := v_party_id; -- party_id of the person

      v_org_contact_rec.party_rel_rec.subject_type := 'PERSON';

      v_org_contact_rec.party_rel_rec.subject_table_name := 'HZ_PARTIES';

      v_org_contact_rec.party_rel_rec.object_type := 'ORGANIZATION';

      v_org_contact_rec.party_rel_rec.object_id := p_customer_party_id; -- party_id of the customer

      v_org_contact_rec.party_rel_rec.object_table_name := 'HZ_PARTIES';

      v_org_contact_rec.party_rel_rec.start_date := SYSDATE;

      v_org_contact_rec.created_by_module := 'TCA_V2_API';



      HZ_PARTY_CONTACT_V2PUB.CREATE_ORG_CONTACT ( p_init_msg_list   => fnd_api.g_true,

                                                  p_org_contact_rec => v_org_contact_rec,

                                                  x_org_contact_id  => v_org_contact_id,

                                                  x_party_rel_id    => v_party_rel_id,

                                                  x_party_id        => v_oc_party_id,

                                                  x_party_number    => v_oc_party_number,

                                                  x_return_status   => v_return_status,

                                                  x_msg_count       => v_msg_count,

                                                  x_msg_data        => v_msg_data );



      IF v_return_status <> fnd_api.g_ret_sts_success THEN



        FOR i IN 1 .. fnd_msg_pub.count_msg LOOP



          fnd_msg_pub.get ( p_msg_index => i,

                            p_encoded => fnd_api.g_false,

                            p_data => v_msg_data,

                            p_msg_index_out => v_msg_index_out );



          v_api_message := v_api_message || ' ~ ' || v_msg_data;



        END LOOP;



        p_return_msg := 'Error - Org Contact. ' || v_api_message;

        RAISE e_exception;



      ELSIF ( v_return_status = fnd_api.g_ret_sts_success ) THEN



        print_log ( 'Org Contact created.' );



        print_log ( 'v_org_contact_id: ' || v_org_contact_id );

        print_log ( 'v_oc_party_id: ' || v_oc_party_id );

        print_log ( 'v_party_rel_id: ' || v_party_rel_id );



      END IF;



    -- Create Role

      print_log ( 'Creating Role..' );



      v_cr_cust_acc_role_rec.party_id := v_oc_party_id; -- org contact party id

      v_cr_cust_acc_role_rec.cust_account_id := p_customer_id;

      -- p_cr_cust_acc_role_rec.cust_acct_site_id := 2248; -- << Se usa para crear el contacto a nivel de site. Si debe ser creado a nivel customer, no se debe enviar valor

      v_cr_cust_acc_role_rec.primary_flag := 'Y';



      v_cr_cust_acc_role_rec.role_type := 'CONTACT';

      v_cr_cust_acc_role_rec.created_by_module := 'TCA_V2_API';



      HZ_CUST_ACCOUNT_ROLE_V2PUB.CREATE_CUST_ACCOUNT_ROLE ( p_init_msg_list => 'T',

                                                            p_cust_account_role_rec => v_cr_cust_acc_role_rec,

                                                            x_cust_account_role_id => v_cust_account_role_id,

                                                            x_return_status => v_return_status,

                                                            x_msg_count => v_msg_count,

                                                            x_msg_data => v_msg_data );



      IF v_return_status <> fnd_api.g_ret_sts_success THEN



        FOR i IN 1 .. fnd_msg_pub.count_msg LOOP



          fnd_msg_pub.get ( p_msg_index => i,

                            p_encoded => fnd_api.g_false,

                            p_data => v_msg_data,

                            p_msg_index_out => v_msg_index_out );



          v_api_message := v_api_message || ' - ' || v_msg_data;



        END LOOP;



        p_return_msg := 'Error - Role. ' || v_api_message;

        RAISE e_exception;



      ELSIF ( v_return_status = fnd_api.g_ret_sts_success ) THEN



        print_log ( 'Role created.' );



        print_log ( 'v_cust_account_role_id: ' || v_cust_account_role_id );



        UPDATE hz_cust_account_roles 

           SET attribute1 = 'Y'

         WHERE cust_account_role_id = v_cust_account_role_id;



      END IF;



    END IF;



    p_status := 'S';



    print_log ( 'ajcl_bc_cust_to_oracle_pkg.contact_p (-)' );



  EXCEPTION

    WHEN e_exception THEN

      print_log ( 'ajcl_bc_cust_to_oracle_pkg.contact_p (!)' );

      p_status := 'E';

    WHEN OTHERS THEN

      print_log ( 'ajcl_bc_cust_to_oracle_pkg.contact_p (!)' );

      p_status := 'E';

      p_return_msg := 'Error general: ' || SQLERRM;



  END contact_p;



  -- ------------------------------------------------------------------------------------------------------------------------ --

  -- CREATE / UPDATE CUSTOMERS ---------------------------------------------------------------------------------------------- --

  -- ------------------------------------------------------------------------------------------------------------------------ --

  PROCEDURE create_customers_p ( p_status           OUT      VARCHAR2, 

                                 p_error_message    OUT      VARCHAR2 ) IS



    CURSOR c_customers IS

    SELECT *

      FROM ajcl_bc_customers

     WHERE status = 'PROCESSED'

       AND request_id = gv_request_id;



    v_customer_id                hz_cust_accounts.cust_account_id%TYPE;

    v_party_id                   hz_parties.party_id%TYPE;

    v_party_number               hz_parties.party_number%TYPE;

    v_account_number             hz_cust_accounts.account_number%TYPE;

    v_cust_acct_profile_id       hz_customer_profiles.cust_account_profile_id%TYPE;

    v_cust_acct_profile_amt_id   NUMBER;



    v_cust_status                VARCHAR2(1);

    rec_organization             HZ_PARTY_V2PUB.ORGANIZATION_REC_TYPE;

    rec_cust_account             HZ_CUST_ACCOUNT_V2PUB.CUST_ACCOUNT_REC_TYPE;

    rec_customer_profile         HZ_CUSTOMER_PROFILE_V2PUB.CUSTOMER_PROFILE_REC_TYPE;

    rec_customer_profile_amt     HZ_CUSTOMER_PROFILE_V2PUB.CUST_PROFILE_AMT_REC_TYPE;



    v_return_status              VARCHAR2(1);

    v_msg_count                  NUMBER;

    v_msg_data                   VARCHAR2(4000);

    v_err_msg                    VARCHAR2(4000);



    v_clob_result                CLOB;



    v_patch_url                  VARCHAR2(2000);



    v_db_name                    VARCHAR2(100);



    v_etag                       VARCHAR2(1000);

    v_body                       VARCHAR2(2000);



    v_tbl_status                 VARCHAR2(10);

    v_tbl_message                VARCHAR2(1000);



    v_status                     VARCHAR2(200);



    v_object_version_number      NUMBER;



    v_location_id                NUMBER;

    v_party_site_id              NUMBER;

    v_cust_acct_site_id          NUMBER;

    v_bill_to_site_use_id        NUMBER;

    v_ship_to_site_use_id        NUMBER;

    v_addr_status                VARCHAR2(1);



    e_customer                   EXCEPTION;



  BEGIN



    print_log ('ajcl_bc_cust_to_oracle_pkg.create_customers_p (+)');



    fnd_global.apps_initialize ( user_id => 0,

                                 resp_id => gv_ar_resp_id,

                                 resp_appl_id => 222 );



    mo_global.set_policy_context ('S', gv_org_id);



    FOR cc IN c_customers LOOP



      BEGIN



        print_log ( ' ' );

        print_log ( 'Customer Number: ' || cc.customer_number );

        print_log ( 'Customer Name: ' || cc.customer_name );



        v_customer_id := NULL;

        v_party_id := NULL;

        v_party_number := NULL;

        v_tbl_status := NULL;



        rec_organization := NULL;

        rec_cust_account := NULL;

        rec_customer_profile := NULL;

        rec_customer_profile_amt := NULL;



        -- El customer ya fue creado en Oracle, por eso el campo oracleCustomerIDAJCINE ya tiene el ID

        -- Se agrega porque en BC es posible cambiarle el nro a un customer

        IF ( cc.oracleCustomerIDAJCINE IS NOT NULL ) THEN



          -- Primero se busca por customer_id

          BEGIN



            SELECT customer_id,

                   party_id,

                   party_number

              INTO v_customer_id,

                   v_party_id,

                   v_party_number

              FROM ra_customers

             WHERE customer_id = cc.oracleCustomerIDAJCINE;



          print_log ('Customer found for customer id ' || cc.oracleCustomerIDAJCINE);



          EXCEPTION

            WHEN OTHERS THEN

              v_customer_id := NULL;

              v_party_id := NULL;

              v_party_number := NULL;



          END;



        ELSE



          -- Se verifica si existe o no el customer en Oracle

          BEGIN



            -- Primero se busca por numero

            SELECT customer_id,

                   party_id,

                   party_number

              INTO v_customer_id,

                   v_party_id,

                   v_party_number

              FROM ra_customers

             WHERE customer_number = cc.customer_number;



            print_log ('Customer found for customer number ' || cc.customer_number);



          EXCEPTION

            WHEN OTHERS THEN



              -- Si no se encuentra por numero, se busca por nombre

              BEGIN



                SELECT customer_id,

                       party_id,

                       party_number

                  INTO v_customer_id,

                       v_party_id,

                       v_party_number

                  FROM ra_customers

                 WHERE UPPER(customer_name) = UPPER(cc.customer_name);



                print_log ('Customer found for customer name ' || cc.customer_name);



              EXCEPTION

                WHEN NO_DATA_FOUND THEN

                  v_customer_id := NULL;

                  v_party_id := NULL;

                  v_party_number := NULL;



                WHEN TOO_MANY_ROWS THEN

                  v_tbl_message := 'Customer ' || cc.customer_name || ' duplicated.';

                  RAISE e_customer;



                WHEN OTHERS THEN

                  v_tbl_message := 'Customer ' || cc.customer_name || ' general error.';

                  RAISE e_customer;



              END;



          END; 



        END IF;



        print_log ('Blocked: ' || cc.blocked);



        IF ( cc.blocked IS NULL OR cc.blocked = ' ' ) THEN



          v_cust_status := 'A';



        ELSE



          v_cust_status := 'I';



        END IF;



        print_log ('v_cust_status: ' || v_cust_status);

        print_log ('deactivation_reason: ' || cc.deactivation_reason);



        rec_cust_account.account_number := cc.customer_number;

        rec_cust_account.status := v_cust_status;

        rec_cust_account.created_by_module := 'TCA_V2_API';

        rec_cust_account.customer_type := cc.customer_type; 



        IF ( v_customer_id IS NULL ) THEN



          rec_cust_account.attribute1 := 0; -- Pending Balance



        END IF;



        -- Se valida DAE

        IF ( TO_NUMBER(REPLACE(cc.dae,',','.'),'990.99') >= 0 AND TO_NUMBER(REPLACE(cc.dae,',','.'),'990.99') < 1 ) THEN



          rec_cust_account.attribute2 := '0'; 



        ELSE



          rec_cust_account.attribute2 := NVL(cc.dae,FND_API.G_MISS_CHAR);



        END IF;



        -- Region Country

        rec_cust_account.attribute3 := NVL(cc.ajc_destination_country,FND_API.G_MISS_CHAR);



        -- Bank Charge

        rec_cust_account.attribute4 := NVL(cc.bank_charge,FND_API.G_MISS_CHAR);



        -- File Last Updated

        rec_cust_account.attribute5 := NVL(cc.account_created,FND_API.G_MISS_CHAR);



        -- Nuevos Logistics

        -- IES Client ID / Financial Party

        rec_cust_account.attribute6 := NVL(cc.iesClientIDFinancialParty,FND_API.G_MISS_CHAR);



        -- Get IES AR Acct From Customer

        rec_cust_account.attribute7 := NVL(cc.getIESARAcctFromCustomer,FND_API.G_MISS_CHAR);

        -- Nuevos Logistics



        -- XXLOG_Customer Priority

        rec_cust_account.attribute9 := NVL(TO_CHAR(cc.customer_priority),FND_API.G_MISS_CHAR);



        -- Adop

        IF ( cc.adop IS NULL OR cc.adop = ' ' ) THEN



          rec_cust_account.attribute10 := 0; 



        ELSE



          rec_cust_account.attribute10 := cc.adop;



        END IF; 



        -- AJC Country Code

        rec_cust_account.attribute11 := NVL(cc.insured_country,FND_API.G_MISS_CHAR);



        -- COFACE Limit

        rec_cust_account.attribute12 := NVL(cc.coface_limit,FND_API.G_MISS_CHAR);



        -- Deactivation Reason

        rec_cust_account.attribute13 := NVL(cc.deactivation_reason,FND_API.G_MISS_CHAR);



        -- AIG Limit

        rec_cust_account.attribute14 := NVL(cc.aig_limit,FND_API.G_MISS_CHAR);



        -- Scoring Model

        rec_cust_account.attribute15 := NVL(cc.scoring_model,FND_API.G_MISS_CHAR);



        -- Last File Review

        rec_cust_account.attribute16 := NVL(cc.last_file_review,FND_API.G_MISS_CHAR); 



        -- Release Limit

        rec_cust_account.attribute20 := NVL(cc.open_acct_limit,FND_API.G_MISS_CHAR); 



        -- Nuevos Logistics

        rec_cust_account.attribute17 := NVL(cc.marketingChannel,FND_API.G_MISS_CHAR); 

        rec_cust_account.attribute18 := NVL(cc.industrySector,FND_API.G_MISS_CHAR); 

        -- Nuevos Logistics



        rec_cust_account.primary_salesrep_id := NVL(cc.salesperson_id,FND_API.G_MISS_NUM); 



        rec_organization.organization_name := cc.customer_name;

        rec_organization.jgzz_fiscal_code := NVL(SUBSTR(TRIM(REPLACE(cc.tax_no,'-')),1,10),FND_API.G_MISS_CHAR);



        rec_organization.created_by_module := 'TCA_V2_API';



        rec_customer_profile.profile_class_id := NVL(cc.profile_class_id,FND_API.G_MISS_NUM);  -- Default

        rec_customer_profile.collector_id := NVL(cc.collector_id,FND_API.G_MISS_NUM); 

        rec_customer_profile.risk_code := cc.lob; 

        rec_customer_profile.account_status := NVL(cc.account_status,FND_API.G_MISS_CHAR); 

        rec_customer_profile.review_cycle := NVL(cc.review_cycle,FND_API.G_MISS_CHAR); 

        rec_customer_profile.credit_hold := NVL(cc.credit_hold,FND_API.G_MISS_CHAR); 

        rec_customer_profile.credit_checking := NVL(cc.credit_check,FND_API.G_MISS_CHAR); 

        rec_customer_profile.tolerance := NVL(cc.tolerance,FND_API.G_MISS_NUM); 

        rec_customer_profile.credit_classification := NVL(cc.credit_classification,FND_API.G_MISS_CHAR); 

        rec_customer_profile.credit_rating := NVL(cc.credit_rating,FND_API.G_MISS_CHAR); 

        rec_customer_profile.send_statements := NVL(cc.send_statements,FND_API.G_MISS_CHAR);

        rec_customer_profile.credit_balance_statements := NVL(cc.credit_balance_statements,FND_API.G_MISS_CHAR);

        rec_customer_profile.statement_cycle_id := NVL(cc.statement_cycle_id,FND_API.G_MISS_NUM);



        rec_customer_profile_amt.currency_code := 'USD';

        rec_customer_profile_amt.created_by_module := 'TCA_V2_API';



        -- Se valida order_credit_limit

        IF ( cc.order_credit_limit >= 0 AND cc.order_credit_limit < 1 ) THEN



          rec_customer_profile_amt.trx_credit_limit := 0;



        ELSE



          rec_customer_profile_amt.trx_credit_limit := NVL(cc.order_credit_limit,FND_API.G_MISS_NUM);



        END IF;



        rec_customer_profile_amt.overall_credit_limit := NVL(cc.ar_limit,FND_API.G_MISS_NUM);

        rec_customer_profile.standard_terms := NVL(cc.payment_terms_id,FND_API.G_MISS_NUM);



        print_log ( 'standard terms: ' || rec_customer_profile.standard_terms );



        -- El cliente no existe en Oracle, se crea.

        IF ( v_customer_id IS NULL ) THEN



          print_log ( 'El cliente no existe, se crea. API: hz_cust_account_v2pub.create_cust_account' );

          hz_cust_account_v2pub.create_cust_account ( p_init_msg_list          => 'T', -- fnd_api.g_true,

                                                      p_cust_account_rec       => rec_cust_account,

                                                      p_organization_rec       => rec_organization,

                                                      p_customer_profile_rec   => rec_customer_profile,

                                                      p_create_profile_amt     => 'F', -- fnd_api.g_true,

                                                      x_cust_account_id        => v_customer_id,

                                                      x_account_number         => v_account_number,

                                                      x_party_id               => v_party_id,

                                                      x_party_number           => v_party_number,

                                                      x_profile_id             => v_cust_acct_profile_id,

                                                      x_return_status          => v_return_status,

                                                      x_msg_count              => v_msg_count,

                                                      x_msg_data               => v_msg_data );



          IF ( v_return_status = 'S' ) THEN



            -- Se obtiene el cust_account_profile_id para el cliente creado

            SELECT cust_account_profile_id 

              INTO rec_customer_profile_amt.cust_account_profile_id

              FROM hz_customer_profiles

             WHERE cust_account_id = v_customer_id;



            rec_customer_profile_amt.cust_account_id := v_customer_id;



            print_log ( 'cust_account_profile_id: ' || rec_customer_profile_amt.cust_account_profile_id );



            print_log ( 'API: hz_customer_profile_v2pub.create_cust_profile_amt' );

            hz_customer_profile_v2pub.create_cust_profile_amt ( p_init_msg_list            => 'T', -- fnd_api.g_true,

                                                                p_check_foreign_key        => FND_API.G_TRUE, 

                                                                p_cust_profile_amt_rec     => rec_customer_profile_amt,

                                                                x_cust_acct_profile_amt_id => v_cust_acct_profile_amt_id,

                                                                x_return_status            => v_return_status,

                                                                x_msg_count                => v_msg_count,

                                                                x_msg_data                 => v_msg_data ); 



            IF ( v_return_status = 'S' ) THEN



              print_log ( 'Cliente creado. v_customer_id: ' || v_customer_id);

              v_tbl_status := 'CREATED';



              -- Se obtiene el nombre de la base de datos

              v_db_name := ajcl_bc_utils_pkg.get_db_name_f;



              -- --------------------------------------------------------------------------------------------- --

              -- Se actualiza el customer_id en BC - Solo si se ejecuta en Oracle PROD                         -- 

              -- o si se ejecuta en Oracle no PROD apuntando a un ambiente distinto a Production               --

              -- --------------------------------------------------------------------------------------------- --

              IF ( ( v_db_name = 'PROD' ) OR 

                   ( v_db_name != 'PROD' AND gv_bc_environment != 'Production' ) ) THEN



                -- Patch URL

                v_patch_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                                            p_entity => 'CUSTOMERS',

                                                                            p_subentity => 'CUSTOMER_ID',

                                                                            p_method => 'PATCH',

                                                                            p_company_id => gv_bc_company_id )

                               || '(' || cc.systemid || ')';



                print_log ('v_patch_url: ' || v_patch_url);



                -- 1

                print_log ('Se obtiene el etag del customer.');            



                v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_patch_url );

                v_etag := ajcl_bc_ws_utils_pkg.get_etag_f ( p_clob_result => v_clob_result );



                print_log ('v_etag: ' || v_etag);



                -- 2

                print_log ( 'Se actualiza el oracle_customer_id en BC.');



                v_body := '{"oraclecustomerID":"' || v_customer_id || '"}';



                v_clob_result := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_patch_url

                                                                           ,p_request_header_name1 => 'Content-Type'

                                                                           ,p_request_header_value1 => 'application/json'

                                                                           ,p_request_header_name2 => 'If-Match'

                                                                           ,p_request_header_value2 => v_etag

                                                                           ,p_http_method => 'PATCH'

                                                                           ,p_body => v_body );            



                print_log ('v_clob_result: ' || v_clob_result);



              END IF;



            ELSE



              v_tbl_status := 'ERROR';



              FOR i IN 1 .. v_msg_count LOOP

                v_msg_data := FND_MSG_PUB.get( p_msg_index => i, p_encoded => 'F');

              END LOOP;



              v_tbl_message := 'Cust Profile Amt could not be created. Error: ' || v_msg_data;



              RAISE e_customer;



            END IF;



          ELSE



            v_tbl_status := 'ERROR';



            FOR i IN 1 .. v_msg_count LOOP

              v_msg_data := FND_MSG_PUB.get( p_msg_index => i, p_encoded => 'F');

            END LOOP;



            v_tbl_message := 'Customer could not be created. Error: ' || v_msg_data;



            RAISE e_customer;



          END IF;



        ELSE -- customer_id IS NOT NULL | El cliente existe



          print_log ( 'El cliente existe. Se actualiza. customer_id: ' || v_customer_id);



          rec_cust_account.cust_account_id := v_customer_id;

          rec_customer_profile_amt.cust_account_id := v_customer_id;

          rec_cust_account.created_by_module := NULL; -- Oracle no permite actualizar este campo



          -- Se obtiene el cust_account_profile_id para el cliente creado

          SELECT cp.cust_account_profile_id,

                 cpa.cust_acct_profile_amt_id

            INTO rec_customer_profile_amt.cust_account_profile_id,

                 rec_customer_profile_amt.cust_acct_profile_amt_id

            FROM hz_customer_profiles cp,

                 hz_cust_profile_amts cpa

           WHERE cp.cust_account_id = v_customer_id

             AND cp.cust_account_profile_id = cpa.cust_account_profile_id

             AND cpa.currency_code = 'USD'

             AND cp.site_use_id IS NULL;



          print_log ( 'cust_account_profile_id: ' || rec_customer_profile_amt.cust_account_profile_id);



          -- Se obtiene el object_version_number

          SELECT object_version_number

            INTO v_object_version_number

            FROM hz_cust_accounts

           WHERE cust_account_id = v_customer_id;



          print_log ( 'v_object_version_number: ' || v_object_version_number);

          print_log ( 'API: hz_cust_account_v2pub.update_cust_account' );



          hz_cust_account_v2pub.update_cust_account ( p_init_msg_list => 'T',

                                                      p_cust_account_rec => rec_cust_account,

                                                      p_object_version_number => v_object_version_number,

                                                      x_return_status => v_return_status,

                                                      x_msg_count => v_msg_count,

                                                      x_msg_data => v_msg_data );



          IF ( v_return_status = 'S' ) THEN



            IF ( cc.account_created IS NULL ) THEN



              UPDATE ra_customers

                 SET attribute5 = NULL,

                     last_update_date = SYSDATE

               WHERE customer_id = v_customer_id;



            END IF;



            IF ( cc.last_file_review IS NULL ) THEN



              UPDATE ra_customers

                 SET attribute16 = NULL,

                     last_update_date = SYSDATE

               WHERE customer_id = v_customer_id;



            END IF;



            DECLARE



              v_profile_id   NUMBER;

              rec_party      hz_party_v2pub.party_rec_type;



            BEGIN



              SELECT object_version_number,

                     party_id

                INTO v_object_version_number,

                     rec_party.party_id

                FROM hz_parties

               WHERE party_id = ( SELECT party_id 

                                    FROM ra_customers 

                                   WHERE customer_id = v_customer_id );



              rec_organization.party_rec := rec_party;



              hz_party_v2pub.update_organization ( p_init_msg_list               => 'T', -- fnd_api.g_true,

                                                   p_organization_rec            => rec_organization,

                                                   p_party_object_version_number => v_object_version_number,

                                                   x_profile_id                  => v_profile_id,

                                                   x_return_status               => v_return_status,

                                                   x_msg_count                   => v_msg_count,

                                                   x_msg_data                    => v_msg_data );



            END;



            -- Hace lo mismo que la API de arriba, porque en algunos casos no funciona la api

            UPDATE hz_parties

               SET party_name = cc.customer_name

             WHERE party_id = ( SELECT party_id 

                                  FROM ra_customers 

                                 WHERE customer_id = v_customer_id );



            -- Se actualizan los datos de Profile Transactions y Profile Document Printing

            UPDATE hz_customer_profiles

               SET 

                   -- collector_id = rec_customer_profile.collector_id,  

                   collector_id = cc.collector_id,

                   -- credit_checking = rec_customer_profile.credit_checking,       

                   credit_checking = cc.credit_check,

                   -- tolerance = rec_customer_profile.tolerance,       

                   tolerance = cc.tolerance,

                   -- send_statements = rec_customer_profile.send_statements, 

                   send_statements = cc.send_statements,

                   -- credit_balance_statements = rec_customer_profile.credit_balance_statements, 

                   credit_balance_statements = cc.credit_balance_statements,

                   -- credit_hold = rec_customer_profile.credit_hold, 

                   credit_hold = cc.credit_hold,

                   -- credit_rating = rec_customer_profile.credit_rating, 

                   credit_rating = cc.credit_rating,

                   -- risk_code = rec_customer_profile.risk_code, 

                   risk_code = cc.lob,

                   -- standard_terms = rec_customer_profile.standard_terms, 

                   standard_terms = cc.payment_terms_id,

                   -- account_status = rec_customer_profile.account_status, 

                   account_status = cc.account_status,

                   -- review_cycle = rec_customer_profile.review_cycle, 

                   review_cycle = cc.review_cycle,

                   -- credit_classification = rec_customer_profile.credit_classification

                   credit_classification = cc.credit_classification,

                   last_update_date = SYSDATE

             WHERE cust_account_id = v_customer_id

               AND site_use_id IS NULL;



            -- Se obtiene el object_version_number de la hz_cust_profile_amts

            SELECT object_version_number

              INTO v_object_version_number

              FROM hz_cust_profile_amts

             WHERE cust_account_id = v_customer_id

               AND site_use_id IS NULL;



            rec_customer_profile_amt.created_by_module := NULL; -- Oracle no permite actualizar este campo



            print_log ( 'v_object_version_number: ' || v_object_version_number);

            print_log ( 'API: hz_customer_profile_v2pub.update_cust_profile_amt' );



            hz_customer_profile_v2pub.update_cust_profile_amt ( p_init_msg_list         => 'T', -- fnd_api.g_true,

                                                                p_cust_profile_amt_rec  => rec_customer_profile_amt,

                                                                p_object_version_number => v_object_version_number,

                                                                x_return_status         => v_return_status,

                                                                x_msg_count             => v_msg_count,

                                                                x_msg_data              => v_msg_data );



            -- Se agrega update porque a veces no actualiza el AR Limit

            UPDATE hz_cust_profile_amts

               SET overall_credit_limit = cc.ar_limit

             WHERE cust_account_id = v_customer_id

               AND site_use_id IS NULL;



            print_log ( 'Cliente actualizado. v_customer_id: ' || v_customer_id);

            v_tbl_status := 'UPDATED';



          ELSE



            v_tbl_status := 'ERROR';

            v_tbl_message := 'Customer could not be updated. ' || v_msg_data;

            RAISE e_customer;



          END IF;



        END IF;



        -- Si llego a este punto, se creo el cliente o el cliente ya existia

        -- Se intenta crear la direccion  

        address_p ( p_tbl_status => v_tbl_status,

                    p_customer_id => v_customer_id,

                    p_address1 => cc.address1,

                    p_address2 => cc.address2,

                    p_address3 => cc.address3,

                    p_address4 => cc.address4,

                    p_ajc_destination_country => cc.ajc_destination_country,

                    p_country => cc.country,

                    p_city => cc.city,

                    p_state => cc.state,

                    p_zip => cc.zip,

                    p_mobile => cc.mobile,

                    p_phone => cc.phone,

                    p_location_id => v_location_id,

                    p_party_id => v_party_id,

                    p_party_site_id => v_party_site_id,

                    p_cust_acct_site_id => v_cust_acct_site_id,

                    p_bill_to_site_use_id => v_bill_to_site_use_id,

                    p_ship_to_site_use_id => v_ship_to_site_use_id,

                    p_addr_status => v_status,

                    p_return_msg => v_msg_data );



        IF ( v_status = 'N' ) THEN



          v_tbl_status := 'ERROR';

          v_tbl_message := 'Error creating / updating address: ' || v_msg_data;

          RAISE e_customer;



        END IF;



        -- Se actualizan los datos de Profile Amounts de la dirección creada

        print_log ( 'Se actualizan los datos de Profile Amounts de la dirección creada.' );

        UPDATE hz_cust_profile_amts

           SET -- trx_credit_limit = rec_customer_profile_amt.trx_credit_limit,

               trx_credit_limit = cc.order_credit_limit,

               -- overall_credit_limit = rec_customer_profile_amt.overall_credit_limit

               overall_credit_limit = cc.ar_limit,

               last_update_date = SYSDATE

         WHERE cust_account_id = v_customer_id

           AND site_use_id IS NOT NULL;



        -- Se actualizan los datos de Profile Transactions y Profile Document Printing

        print_log ( 'Se actualizan los datos de Profile Transactions y Profile Document Printing.' );

        UPDATE hz_customer_profiles

           SET -- collector_id = rec_customer_profile.collector_id,  

               collector_id = cc.collector_id,

               -- credit_checking = rec_customer_profile.credit_checking,       

               credit_checking = cc.credit_check,

               -- tolerance = rec_customer_profile.tolerance,  

               tolerance = cc.tolerance,

               -- send_statements = rec_customer_profile.send_statements, 

               send_statements = cc.send_statements,

               -- credit_balance_statements = rec_customer_profile.credit_balance_statements, 

               credit_balance_statements = cc.credit_balance_statements,

               -- credit_hold = rec_customer_profile.credit_hold, 

               credit_hold = cc.credit_hold,

               -- credit_rating = rec_customer_profile.credit_rating, 

               credit_rating = cc.credit_rating,

               -- risk_code = rec_customer_profile.risk_code, 

               risk_code = cc.lob,

               -- standard_terms = rec_customer_profile.standard_terms, 

               standard_terms = cc.payment_terms_id,

               -- account_status = rec_customer_profile.account_status, 

               account_status = cc.account_status,

               -- review_cycle = rec_customer_profile.review_cycle, 

               review_cycle = cc.review_cycle,

               -- credit_classification = rec_customer_profile.credit_classification

               credit_classification = cc.credit_classification,

               last_update_date = SYSDATE

         WHERE cust_account_id = v_customer_id

           AND site_use_id IS NOT NULL;



        -- Se actualizan los atributos de la hz_parties para el party creado o actualizado.

        print_log ( 'Se actualizan los atributos de la hz_parties para el party creado o actualizado (party_id: ' || v_party_id || ').' );



        UPDATE hz_parties

           SET attribute2 = rec_cust_account.attribute2,

               attribute3 = rec_cust_account.attribute3,

               attribute4 = rec_cust_account.attribute4,

               attribute5 = rec_cust_account.attribute5,

               attribute6 = rec_cust_account.attribute6,

               attribute7 = rec_cust_account.attribute7,

               attribute9 = rec_cust_account.attribute9,

               attribute11 = rec_cust_account.attribute11,

               attribute12 = rec_cust_account.attribute12,

               attribute13 = rec_cust_account.attribute13,

               attribute14 = rec_cust_account.attribute14,

               attribute15 = rec_cust_account.attribute15,

               attribute16 = rec_cust_account.attribute16,

               attribute20 = rec_cust_account.attribute20,

               -- Nuevos Logistics

               attribute17 = rec_cust_account.attribute17,

               attribute18 = rec_cust_account.attribute18,

               -- Nuevos Logistics

               last_update_date = SYSDATE

         WHERE party_id = v_party_id;



        -- Crea o actualiza los contactos existentes

        IF ( cc.exposure_notes != ' ' AND cc.exposure_notes IS NOT NULL ) THEN



          contact_p ( p_customer_id => v_customer_id,

                      p_customer_party_id => v_party_id,

                      p_person_last_name => cc.exposure_notes,

                      p_status => v_status,

                      p_return_msg => v_msg_data );



          IF ( v_status = 'E' ) THEN



            v_tbl_status := 'ERROR';

            v_tbl_message := 'Error creating / updating contact: ' || v_msg_data;

            RAISE e_customer;



          END IF;



        END IF;



        -- Se actualiza la tabla custom

        update_ajcl_bc_customers_p ( p_customer_number     => cc.customer_number,

                                     p_status              => v_tbl_status,

                                     p_customer_id         => v_customer_id,

                                     p_party_id            => v_party_id,

                                     p_party_number        => v_party_number,

                                     p_location_id         => v_location_id,

                                     p_party_site_id       => v_party_site_id,

                                     p_cust_acct_site_id   => v_cust_acct_site_id,

                                     p_bill_to_site_use_id => v_bill_to_site_use_id,

                                     p_ship_to_site_use_id => v_ship_to_site_use_id,

                                     -- p_collector_id        => cc.collector_id, -- rec_customer_profile.collector_id,

                                     -- p_statement_cycle_id  => cc.statement_cycle_id, -- rec_customer_profile.statement_cycle_id,

                                     -- p_payment_terms_id    => cc.payment_terms_id, -- rec_customer_profile.standard_terms,

                                     p_message             => NULL );



        COMMIT;



      EXCEPTION

        WHEN e_customer THEN



          ROLLBACK;          



          update_ajcl_bc_customers_p ( p_customer_number     => cc.customer_number,

                                       p_status              => v_tbl_status,

                                       p_customer_id         => v_customer_id,

                                       p_party_id            => v_party_id,

                                       p_party_number        => v_party_number,

                                       p_location_id         => NULL,

                                       p_party_site_id       => NULL,

                                       p_cust_acct_site_id   => NULL,

                                       p_bill_to_site_use_id => NULL,

                                       p_ship_to_site_use_id => NULL,

                                       -- p_collector_id        => NULL,

                                       -- p_statement_cycle_id  => NULL,

                                       -- p_payment_terms_id    => NULL,

                                       p_message             => v_tbl_message );



          COMMIT;



        WHEN OTHERS THEN



          ROLLBACK;



          update_ajcl_bc_customers_p ( p_customer_number     => cc.customer_number,

                                       p_status              => 'ERROR',

                                       p_customer_id         => v_customer_id,

                                       p_party_id            => v_party_id,

                                       p_party_number        => v_party_number,

                                       p_location_id         => NULL,

                                       p_party_site_id       => NULL,

                                       p_cust_acct_site_id   => NULL,

                                       p_bill_to_site_use_id => NULL,

                                       p_ship_to_site_use_id => NULL,

                                       -- p_collector_id        => NULL,

                                       -- p_statement_cycle_id  => NULL,

                                       -- p_payment_terms_id    => NULL,

                                       p_message             => 'Error general. ' || SQLERRM );



          COMMIT;



      END;



    END LOOP;



    p_status := 'S';

    print_log ('ajcl_bc_cust_to_oracle_pkg.create_customers_p (-)');    



  EXCEPTION

    WHEN OTHERS THEN

      print_log ('ajcl_bc_cust_to_oracle_pkg.create_customers_p (!)');

      p_status := 'E';

      p_error_message := SQLCODE || ': ' || SQLERRM;



  END create_customers_p;



  -- Comprueba diferencias de direccion en la tabla hz_parties respecto de la tabla hz_locations

  PROCEDURE update_hz_parties_address_p IS



    CURSOR c_diferencias IS

    SELECT c.account_number,

           p.party_id,

           p.party_name,

           p.address1 hz_party_addr1,

           hl.address1 hz_loc_addr1,

           p.address2 hz_party_addr2,

           hl.address2 hz_loc_addr2,

           p.address3 hz_party_addr3,

           hl.address3 hz_loc_addr3,

           p.address4 hz_party_addr4,

           hl.address4 hz_loc_addr4

      FROM hz_parties p,

           hz_party_sites ps,

           hz_locations hl,

           hz_cust_accounts c,

           (  SELECT party_id, MAX(request_id) req_id

                FROM ajcl_bc_customers

               WHERE status IN ('UPDATED','CREATED')

            GROUP BY party_id) bc,

           ajcl_bc_customers bcdet

     WHERE p.party_id = ps.party_id

       AND hl.location_id = ps.location_id

       AND c.party_id = p.party_id

       AND c.status = 'A'

       AND bc.party_id = p.party_id

       AND p.request_id = hl.request_id

       AND ps.request_id = hl.request_id

       AND ( NVL(p.address1,'NULL ADDRESS1') <> NVL(hl.address1,'NULL ADDRESS1') OR

             NVL(p.address2,'NULL ADDRESS2') <> NVL(hl.address2,'NULL ADDRESS2') OR

             NVL(p.address3,'NULL ADDRESS3') <> NVL(hl.address3,'NULL ADDRESS3') OR

             NVL(p.address4,'NULL ADDRESS4') <> NVL(hl.address4,'NULL ADDRESS4') )

       AND bcdet.party_id = bc.party_id

       AND bc.req_id = bcdet.request_id;



    v_cantidad   NUMBER;



  BEGIN



    print_log ('ajcl_bc_cust_to_oracle_pkg.update_hz_parties_address_p (+)');



    v_cantidad := 0;



    FOR cd IN c_diferencias LOOP



      print_log ('account_number: ' || cd.account_number || ' | party_id: ' || cd.party_id || ' | party_name: ' || cd.party_name);



      UPDATE hz_parties

         SET address1 = cd.hz_loc_addr1,

             address2 = cd.hz_loc_addr2,

             address3 = cd.hz_loc_addr3,

             address4 = cd.hz_loc_addr4

       WHERE party_id = cd.party_id;



      v_cantidad := v_cantidad + SQL%ROWCOUNT;



    END LOOP;



    COMMIT;



    print_log ('Cantidad de registros actualizados: ' || v_cantidad);

    print_log ('ajcl_bc_cust_to_oracle_pkg.update_hz_parties_address_p (-)');



  END update_hz_parties_address_p;



  PROCEDURE final_report_csv_p ( p_status   OUT   VARCHAR2 ) IS



      CURSOR c_customers IS

      SELECT customer_number,

             customer_name,

             customer_id,

             status,

             message

        FROM ajcl_bc_customers

       WHERE request_id = gv_request_id

    ORDER BY customer_name;



  BEGIN



    print_log( 'ajcl_bc_cust_to_oracle_pkg.final_report_csv_p (+)' );



    -- Insert Report Title

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => gv_bc_ifc || ' Report',

                                        p_request_id => gv_request_id );



    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Tabla 1 -----------------------------------------------------------------------------------------------------------------                                    

    -- Insert Table Column Names                            

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Customer Num' || '|' ||

                                                  'Customer Name' || '|' ||

                                                  'Customer ID' || '|' ||

                                                  'Status' || '|' ||

                                                  'Message',

                                        p_request_id => gv_request_id );                                        



    -- Se insertan los registros

    FOR cc IN c_customers LOOP



      ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                          p_text => cc.customer_number || '|' || 

                                                    cc.customer_name || '|' || 

                                                    cc.customer_id || '|' || 

                                                    cc.status || '|' || 

                                                    cc.message,

                                          p_request_id => gv_request_id );     



    END LOOP;



    p_status := 'S';



    print_log( 'ajcl_bc_cust_to_oracle_pkg.final_report_csv_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_cust_to_oracle_pkg.final_report_csv_p (!). Error: ' || SQLERRM );



  END final_report_csv_p;



  PROCEDURE final_report_xlsx_p ( p_status   OUT   VARCHAR2 ) IS



    c_cursor   SYS_REFCURSOR;



  BEGIN



    print_log( 'ajcl_bc_cust_to_oracle_pkg.final_report_xlsx_p (+)' );



    gv_directory_report := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_REPORT' );



    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc || ' Report',

                                                p_request_id => gv_request_id,

                                                p_bc_environment => gv_bc_environment,

                                                p_jenkins_build_number => gv_jenkins_build_number,

                                                --

                                                p_param_1_title => ' ',

                                                p_param_1_value => ' ',

                                                p_param_2_title => 'REFRESH_PAYMENT_TERMS',

                                                p_param_2_value => gv_refresh_payment_terms );



        OPEN c_cursor FOR

      SELECT customer_number,

             customer_name,

             customer_id,

             status,

             message,

             --

             lob ajcl_lob,

             review_cycle,

             TO_CHAR(TO_DATE(last_file_review,'YYYY/MM/DD HH24:MI:SS'),'YYYY-MM-DD') last_file_review,

             TO_CHAR(TO_DATE(account_created,'DD-MON-YYYY'),'YYYY-MM-DD') account_created,

             open_acct_limit,

             ar_limit,

             order_credit_limit,

             credit_hold,

             credit_check,

             collector,

             send_statements,

             credit_balance_statements,

             cycle,

             blocked,

             salesperson_code,

             payment_terms,

             address1,

             address2,

             address3,

             address4,

             country,

             city,

             zip,

             iesclientidfinancialparty ies_client_id_financial_party,

             getiesaracctfromcustomer get_ies_ar_acct_from_customer,

             marketingchannel marketing_channel,

             industrysector industry_sector             

        FROM ajcl_bc_customers

       WHERE request_id = gv_request_id

    ORDER BY customer_name;



    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Customers',

                                       p_sheet => 2,

                                       p_cursor => c_cursor );



    as_xlsx.save ( gv_directory_report, gv_report_filename || '.' || LOWER(gv_file_format) );



    p_status := 'S';



    print_log( 'ajcl_bc_cust_to_oracle_pkg.final_report_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_cust_to_oracle_pkg.final_report_xlsx_p (!). Error: ' || SQLERRM );



  END final_report_xlsx_p;



  PROCEDURE main_p ( p_bc_environment          IN   VARCHAR2,

                     p_refresh_payment_terms   IN   VARCHAR2,

                     p_jenkins_build_number    IN   VARCHAR2 ) IS



    v_run_date                 TIMESTAMP;

    v_last_processed_date      TIMESTAMP;

    v_last_bc_processed_date   TIMESTAMP;



    v_status                   VARCHAR2(1);

    v_error_message            VARCHAR2(2000);

    v_phase                    VARCHAR2(2000);

    v_count                    NUMBER := 0;



    e_get                      EXCEPTION;  

    e_process                  EXCEPTION;

    e_create                   EXCEPTION;

    e_customers                EXCEPTION;

    e_parameter_value          EXCEPTION;

    e_entities                 EXCEPTION;



  BEGIN



    gv_request_id := ajcl_bc_utils_pkg.get_request_id_f;

    gv_jenkins_build_number := p_jenkins_build_number;



    -- Se inserta el concurrent_job

    ajcl_bc_utils_pkg.ins_jenkins_concurrent_job_p ( p_request_id => gv_request_id,

                                                     p_job_name => gv_bc_ifc,

                                                     p_jenkins_build_number => p_jenkins_build_number,

                                                     p_argument1 => p_bc_environment,

                                                     p_argument2 => p_refresh_payment_terms );



    print_log ( 'ajcl_bc_cust_to_oracle_pkg.main_p (+)' );

    print_log ( 'gv_request_id: ' || gv_request_id );

    print_log ( 'gv_jenkins_build_number: ' || gv_jenkins_build_number );



    gv_file_format := ajcl_bc_ws_utils_pkg.get_parameter_f ( 'FILE_FORMAT' );

    print_log( 'FILE_FORMAT: ' || gv_file_format ); 



    -- Validacion parametro p_bc_environment -----------------------------------------------------------------------------------

    IF ( ajcl_bc_utils_pkg.is_bc_environment_valid_f ( p_bc_environment ) = 'N' ) THEN



      v_error_message := 'Invalid value (' || p_bc_environment || ') for parameter BC_ENVIRONMENT.';

      RAISE e_parameter_value;



    END IF;



    gv_bc_environment := p_bc_environment;

    print_log ( 'gv_bc_environment: ' || gv_bc_environment );  



    gv_email := ajcl_bc_utils_pkg.get_emails_f ( 'CUSTOMERS' );

    print_log ( 'gv_email: ' || gv_email );



    gv_refresh_payment_terms := p_refresh_payment_terms;

    print_log ( 'gv_refresh_payment_terms: ' || gv_refresh_payment_terms );



    -- Se guarda la fecha y hora actual

    v_run_date := systimestamp;

    print_log ( 'v_run_date: ' || v_run_date );



    -- Se obtiene la fecha y hora de Oracle de la ultima ejecucion de la interface

    v_last_processed_date := ajcl_bc_ws_utils_pkg.get_ifc_last_processed_date_f ( gv_bc_environment, gv_ifc );

    print_log ( 'Oracle last processed date: ' || v_last_processed_date );    



    -- Se obtiene la fecha y hora de BC de la ultima ejecucion de la interface

    v_last_bc_processed_date := ajcl_bc_ws_utils_pkg.get_bc_last_processed_date_f ( v_last_processed_date );

    print_log ( 'BC last processed date: ' || v_last_bc_processed_date );



    -- Se obtienen los parametros de la compañia

    print_log ( 'gv_bc_company_name: ' || gv_bc_company_name );



    gv_bc_company_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                     p_column => 'BC_COMPANY_ID' );



    print_log ( 'gv_bc_company_id: ' || gv_bc_company_id );



    gv_org_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                              p_column => 'ORG_ID' );



    print_log ( 'gv_org_id: ' || gv_org_id );



    gv_ar_resp_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                  p_column => 'AR_RESP_ID' );



    print_log ( 'gv_ar_resp_id: ' || gv_ar_resp_id );



    -- Se sincronizan las novedades de payment terms antes de traer los customers

    IF ( gv_refresh_payment_terms = 'Y' ) THEN



      -- 20250825

      -- ajc_bc_payment_terms_pkg.caller_p ( p_bc_environment => gv_bc_environment );

      ajcl_bc_payment_terms_pkg.main_p ( p_bc_environment => gv_bc_environment,

                                         p_bc_ifc => gv_bc_ifc,

                                         p_request_id => gv_request_id,

                                         p_log_seq => gv_log_seq,

                                         p_company_id => gv_bc_company_id,

                                         p_company_name => gv_bc_company_name );

      -- 20250825                                   



    END IF;



    -- Se sincronizan los permisos para traer novedades de BC a Oracle - Master Data

    ajcl_bc_get_entities_pkg.get_vend_cust_ifc_users_p ( p_bc_environment => gv_bc_environment,

                                                         p_bc_ifc => gv_bc_ifc,

                                                         p_request_id => gv_request_id,

                                                         p_log_seq => gv_log_seq,

                                                         p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'ajcl_bc_get_entities_pkg.get_vend_cust_ifc_users_p';

      RAISE e_entities;



    END IF;



    get_customers_p ( p_last_bc_processed_date => v_last_bc_processed_date,

                      p_status => v_status, 

                      p_error_message => v_error_message );



    IF ( v_status != 'S' ) THEN



      RAISE e_get;



    END IF;



    process_customers_p ( p_count => v_count,

                          p_status => v_status, 

                          p_error_message => v_error_message );



    IF ( v_status != 'S' ) THEN



      RAISE e_process;



    END IF;                          



    create_customers_p ( p_status => v_status, 

                         p_error_message => v_error_message );



    IF ( v_status != 'S' ) THEN



      RAISE e_create;



    END IF; 



    IF ( v_count > 0 ) THEN



      -- INSERT REPORT IN TABLE AJCL_BC_REPORTS --------------------------------------------------------------------------------

      IF ( gv_file_format = 'CSV' ) THEN



        final_report_csv_p ( p_status => v_status );     



        IF ( v_status != 'S' ) THEN



          v_phase := 'final_report_p';

          RAISE e_customers;



        END IF;  



        -- CREATE CSV FROM TABLE AJCL_BC_REPORTS --------------------------------------------------------------------------------

        ajcl_bc_utils_pkg.create_csv_p ( p_ifc => gv_bc_ifc,

                                         p_request_id => gv_request_id,

                                         p_log_seq => gv_log_seq,

                                         p_type => 'REPORT',

                                         p_filename => gv_report_filename,

                                         p_status => v_status );



      ELSIF ( gv_file_format = 'XLSX' ) THEN 



        -- No inserta en tabla, genera el xlsx directamente en el filesystem

        final_report_xlsx_p ( p_status => v_status );     



        IF ( v_status != 'S' ) THEN



          v_phase := 'final_report_xlsx_p';

          RAISE e_customers;



        END IF;  



      END IF;



      -- MAIL REPORT -----------------------------------------------------------------------------------------------------------

      ajcl_bc_utils_pkg.send_mail_with_attach ( p_to_mail => gv_email,

                                                p_subject => gv_bc_ifc || ' Report - ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                                p_body => gv_bc_ifc || ' Report.',

                                                p_type => 'REPORT',

                                                p_filename => gv_report_filename, 

                                                p_file_format => gv_file_format, 

                                                p_attach_filename => gv_bc_ifc || ' Report ' || TO_CHAR(SYSDATE,'MMDDYYYY HH24MISS') || ' ' || gv_bc_environment || '.' || LOWER(gv_file_format) );     



    END IF;



    -- Verifica diferencias en las direcciones de customers entre la hz_parties y hz_locations

    -- En caso de haber diferencia, pone los valores de address1, address2, address3 y address4 de hz_locations

    -- en hz_parties

    -- 20240626 update_hz_parties_address_p;



    -- Se actualiza la tabla de control

    ajcl_bc_ws_utils_pkg.upd_ifc_last_processed_date_p ( gv_bc_environment,

                                                         gv_ifc,

                                                         gv_request_id,

                                                         v_run_date );



    COMMIT;



    -- Se actualiza el concurrent_job

    ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'S' );



    print_log ('ajcl_bc_cust_to_oracle_pkg.main_p (-)');



  EXCEPTION

    WHEN e_parameter_value THEN

      print_log('ajcl_bc_ies_gl_pkg.main_p (!)');

      print_log(v_error_message);    



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => 'Error: ' || v_error_message || CHR(10) || 'Request ID: ' || gv_request_id );



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );                                       



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_message );



    WHEN e_get THEN

      print_log ( 'ajcl_bc_cust_to_oracle_pkg.main_p (!)' );

      print_log ( 'Error getting BC customers. ' || v_error_message );



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => 'Error getting BC customers. ' || v_error_message || CHR(10) || 'Request ID: ' || gv_request_id );



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || 'Error getting BC customers.' ); 



    WHEN e_process THEN

      print_log ( 'ajcl_bc_cust_to_oracle_pkg.main_p (!)' );

      print_log ( 'Error processing BC customers. ' || v_error_message );



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => 'Error processing BC customers. ' || v_error_message || CHR(10) || 'Request ID: ' || gv_request_id );



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || 'Error processing BC customers.' ); 



    WHEN e_create THEN

      print_log ( 'ajcl_bc_cust_to_oracle_pkg.main_p (!)' );

      print_log ( 'Error creating / updateing BC customers. ' || v_error_message );



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => 'Error creating / updateing BC customers. ' || v_error_message || CHR(10) || 'Request ID: ' || gv_request_id );



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || 'Error creating / updateing BC customers.' ); 



    WHEN e_customers THEN

      print_log ( 'ajcl_bc_cust_to_oracle_pkg.main_p (!). Phase: ' || v_phase || '. Error: ' || v_error_message );



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => 'Error at Phase: ' || v_phase || CHR(10) || 'Request ID: ' || gv_request_id );



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || SQLERRM );   



    WHEN e_entities THEN



      print_log ( 'ajcl_bc_cust_to_oracle_pkg.main_p (!). Phase: ' || v_phase || '. Error: ' || v_error_message );



      -- No se envia mail porque es un error de conexion, y si falla no se actualiza la fecha y hora de ultima bajada

      -- La siguiente ejecucion deberia funcionar bien

      /*

      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => 'Error at Phase: ' || v_phase || CHR(10) || 'Request ID: ' || gv_request_id );

      */



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || SQLERRM );   



    WHEN OTHERS THEN

      print_log ('main_p (!)');

      print_log ('Error general ajcl_bc_cust_to_oracle_pkg.customers_p. ' || SQLERRM);



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                       p_message => 'General error: ' || SQLERRM || CHR(10) || 'Request ID: ' || gv_request_id );



      RAISE_APPLICATION_ERROR(-20000,'General Error: ' || SQLERRM );   



  END main_p;



END ajcl_bc_cust_to_oracle_pkg; 
