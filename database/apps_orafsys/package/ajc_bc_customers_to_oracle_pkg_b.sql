CREATE OR REPLACE PACKAGE BODY ajc_bc_customers_to_oracle_pkg IS

  

  -- 20240220

  gv_bc_support_email     VARCHAR2(200) := 'bcsupport@ajcgroup.com';

  gv_bc_support_subject   VARCHAR2(200) := 'AJC BC Customers Interface - ERROR';

  -- 20240220



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



    fnd_file.put_line(fnd_file.log, p_message);



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



  -- 20250617

  PROCEDURE send_oracle_cust_id_to_bc_p ( p_bc_environment   IN   VARCHAR2, 

                                          p_system_id        IN   VARCHAR2,

                                          p_customer_id      IN   NUMBER ) IS



    v_db_name       VARCHAR2(100);

    v_patch_api     VARCHAR2(1000);

    v_patch_url     VARCHAR2(2000);

    v_etag          VARCHAR2(1000);

    v_body          VARCHAR2(2000);

    v_clob_result   CLOB;



  BEGIN



    print_log ( 'ajc_bc_customers_to_oracle_pkg.send_oracle_cust_id_to_bc_p (+)' );



    -- Se obtiene el nombre de la base de datos

    SELECT name

      INTO v_db_name

      FROM V$DATABASE;



    -- --------------------------------------------------------------------------------------------- --

    -- Se actualiza el vendor_id en BC - Solo si se ejecuta en Oracle PROD                           -- 

    -- o si se ejecuta en Oracle FINUPG5 apuntando a Sandbox                                         --

    -- --------------------------------------------------------------------------------------------- --

    IF ( ( v_db_name = 'PROD' 

         ) OR 

         ( v_db_name = 'FINUPG5' AND p_bc_environment IN ('OPS_UAT') )  ) THEN



      v_patch_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'CUSTOMERS',

                                                     p_subentity => 'CUSTOMER_ID',

                                                     p_method => 'PATCH' );

      print_log ( 'v_patch_api: ' || v_patch_api );



      -- Patch URL

      v_patch_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, gv_company_id ) || v_patch_api || '(' || p_system_id || ')';

      print_log ( 'v_patch_url: ' || v_patch_url );



      -- 1

      print_log ( 'Se obtiene el etag del customer.' );

      v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_patch_url );



      v_etag := SUBSTR(v_clob_result,INSTR(v_clob_result,'@odata.etag') + 14);

      v_etag := REPLACE(SUBSTR(v_etag,1,INSTR(v_etag,',') - 2),'\');



      print_log ( 'v_etag: ' || v_etag );



      -- 2

      print_log ( 'Se actualiza el Oracle Customer ID en BC.');



      v_body := '{"oraclecustomerID":"' || p_customer_id || '"}';



      v_clob_result := ajc_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_patch_url

                                                                ,p_request_header_name1 => 'Content-Type'

                                                                ,p_request_header_value1 => 'application/json'

                                                                ,p_request_header_name2 => 'If-Match'

                                                                ,p_request_header_value2 => v_etag

                                                                ,p_http_method => 'PATCH'

                                                                ,p_body => v_body );           



      print_log ( 'v_clob_result: ' || v_clob_result );



    END IF;



    print_log ( 'ajc_bc_customers_to_oracle_pkg.send_oracle_cust_id_to_bc_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      print_log ( 'ajc_bc_customers_to_oracle_pkg.send_oracle_cust_id_to_bc_p (!). Error: ' || SQLERRM );



  END send_oracle_cust_id_to_bc_p;

  -- 20250617



  PROCEDURE update_ajc_bc_customers_p ( p_customer_number     VARCHAR2,

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



    print_log ( 'ajc_bc_customers_to_oracle_pkg.update_ajc_bc_customers_p (+)' );  



    UPDATE ajc_bc_customers

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



    print_log ( 'ajc_bc_customers_to_oracle_pkg.update_ajc_bc_customers_p (-)' ); 



  EXCEPTION

    WHEN OTHERS THEN

      print_log ( 'ajc_bc_customers_to_oracle_pkg.update_ajc_bc_customers_p (!). Error: ' || SQLERRM ); 



  END update_ajc_bc_customers_p;



  -- 20250117 - BCPGL-458

  PROCEDURE get_other_fields_p ( p_bc_environment    IN       VARCHAR2,

                                 p_customer_number   IN       VARCHAR2,

                                 p_aig_limit         IN OUT   VARCHAR2 ) IS



    v_api           VARCHAR2(100);

    v_url           VARCHAR2(2000);

    v_clob_result   CLOB;



    CURSOR c_other_fields ( p_clob_result   CLOB ) IS

    SELECT no,

           aig_limit

      FROM json_table ( p_clob_result,

                        '$.value[*]' COLUMNS ( no          VARCHAR2(4000)  path '$.no',

                                               aig_limit   VARCHAR2(4000)  path '$.AIGLimitAJCINE' ) );



  BEGIN



    print_log ( 'ajc_bc_customers_to_oracle_pkg.get_other_fields_p (+)' ); 



    v_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'CUSTOMERS',

                                             p_subentity => 'OTHERS',

                                             p_method => 'GET' );



    v_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, gv_company_id ) || v_api 

             || '?$filter=no eq ''' || p_customer_number || '''';



    print_log ('v_url: ' || v_url);



    v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



    FOR cof IN c_other_fields ( p_clob_result => v_clob_result ) LOOP



      print_log ( 'aig_limit: ' || cof.aig_limit ); 



      -- 20250122

      -- p_aig_limit := cof.aig_limit;

      -- Si no tiene parte decimal, se le agrega .00 para que los reportes de ATIS muestren el valor, ya que sin parte decimal no lo muestran

      IF(INSTR(cof.aig_limit,'.') = 0) THEN



        p_aig_limit := cof.aig_limit || '.00';



      ELSE



        p_aig_limit := cof.aig_limit;



      END IF;        

      -- 20250122



    END LOOP;    



    print_log ( 'ajc_bc_customers_to_oracle_pkg.get_other_fields_p (-)' ); 



  EXCEPTION

    WHEN OTHERS THEN

      print_log ('ajc_bc_customers_to_oracle_pkg.get_other_fields_p (!). Error: ' || SQLERRM);



  END get_other_fields_p;

  -- 20250117 - BCPGL-458



  -- ------------------------------------------------------------------------------------------------------------------------ --

  -- GET CUSTOMERS ---------------------------------------------------------------------------------------------------------- --

  -- ------------------------------------------------------------------------------------------------------------------------ --

  PROCEDURE get_customers_p ( p_last_bc_processed_date   IN    TIMESTAMP,

                              p_bc_environment           IN    VARCHAR2,

                              p_return                   OUT   VARCHAR2, 

                              p_message                  OUT   VARCHAR2 ) IS



    v_get_url               VARCHAR2(2000);

    -- 20230414 v_get_api               VARCHAR2(100) := 'customerreadonlyAPIINE';

    v_get_api               VARCHAR2(100);

    v_customer_number       VARCHAR2(100);

    v_clob_result           CLOB;



    CURSOR c_customers ( p_clob_result   CLOB ) IS

    SELECT systemid,

           regexp_replace(No, '[^0-9]', '') customer_number,

           -- 20231025

           -- Name customer_name,

           TRIM(Name) customer_name,

           -- 20231025

           'R' customer_type,

           0 profile_class_id,

           -- 20240220

           -- Address address,

           -- Address2 address2,

           -- Address3 address3,

           -- Address4 address4,

           SUBSTR(Address,1,100) address, 

           SUBSTR(Address2,1,50) address2, 

           SUBSTR(Address3,1,80) address3, 

           SUBSTR(Address4,1,80) address4, 

           -- 20240220

           -- 20250107

           -- DECODE(CountryRegionCode,'TBD',NULL,' ',NULL,'',NULL,CountryRegionCode) country,

           DECODE(CountryRegionCode,'TBD',NULL,

                                    ' ',NULL,

                                    '',NULL,

                                    'HDL','NLD', -- Netherlands

                                    CountryRegionCode) country,

           -- 20250107

           DECODE(City,'TBD',NULL,' ',NULL,'',NULL,City) city,

           NULL state,

           postCode zip,

           MobilePhoneNo mobile,

           PhoneNo phone, 

           VatRegistrationNo tax_no, 

           paymentTermsCode standard_terms,  

           NULL pending_balance,

           -- 20230629 DECODE(UPPER(lob),'UNDEFINED',NULL,UPPER(lob)) lob,

           -- 20240617

           -- UPPER(lob) lob

           CASE

             WHEN lob = '_x0020_' THEN

               NULL

             ELSE

               -- 20250107 - BCPGL-461

               -- UPPER(lob) 

               DECODE(UPPER(lob),'FOOD_X0020_SERVICE','FOOD SERVICE',UPPER(lob))

               -- 20250107 - BCPGL-461

           END lob,

           --

           DECODE(account_status,'true','ELITE',NULL) account_status,

           /* -- 20230925

           DECODE(review_cycle,'Monthly','MONTHLY',

                               'Quarterly','QUARTERLY',

                               'Weekly','WEEKLY',

                               'Semiannually','HALF_YEARLY',

                               'Annually','YEARLY',

                               '12 months','12_MONTHS',

                               '18 months','18_MONTHS',

                               '24 months','24_MONTHS',     

                               'Custom','CUSTOM',                          

                               NULL) review_cycle,

           */

           -- 20240617 review_cycle,

           DECODE(REPLACE(review_cycle,'_x0020_',' '),'QUARTERLY','Quarterly',

                                                      'WEEKLY','Weekly',

                                                      'HALF_YEARLY','Semiannually',

                                                      'YEARLY','Annually',

                                                      'MONTHLY','Monthly',

                                                      'CUSTOM','Custom',

                                                      '18_MONTHS','18 months',

                                                      '12_MONTHS','12 months',

                                                      '18_MONTHS','18 months',

                                                      '24_MONTHS','24 months',                                                      

                                                      REPLACE(review_cycle,'_x0020_',' ')) review_cycle,

           -- 20240617

           -- 20230925

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

             -- 20240617

             WHEN credit_rating = '_x0020_' THEN

               NULL

             -- 20240617

             ELSE

               SUBSTR(credit_rating,1,2) 

           END credit_rating,

           collector,

           DECODE(send_statements,'true','Y','N') send_statements,

           DECODE(credit_balance_statements,'true','Y','N') credit_balance_statements,

           -- 20240624

           -- DECODE(cycle,'TBD',NULL,' ',NULL,'',NULL,cycle) cycle,

           DECODE(cycle,'TBD',NULL,

                        ' ',NULL,

                        '',NULL,

                        'MONTHLY','Monthly',

                        'QUARTERLY','Quarterly',

                        'WEEKLY','Weekly',

                        cycle) cycle,

           -- 20240624

           -- 20240617

           -- blocked,

           CASE

             WHEN ( blocked = '_x0020_' ) THEN

               NULL

             ELSE

               blocked

           END blocked,

           -- 20240617

           DECODE(salesperson_code,'TBD',NULL,' ',NULL,'',NULL,salesperson_code) salesperson_code,

           oracleCustomerIDAJCINE,

           systemModifiedBy,

           exposureNotes,

           gv_org_id org_id,

           TRUNC(SYSDATE) creation_date,

           gv_request_id,

           'NEW' status

      FROM json_table( p_clob_result,

                       '$.value[*]' COLUMNS ( systemid                    VARCHAR2(4000)  path '$.systemId',

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

                                              lob                         VARCHAR2(4000)  path '$.lobAJCINE',

                                              account_status              VARCHAR2(4000)  path '$.accountStatusAJCINE',

                                              review_cycle                VARCHAR2(4000)  path '$.reviewCycleAJCINE',

                                              last_file_review            VARCHAR2(4000)  path '$.lastFileReviewAJCINE',

                                              scoring_model               VARCHAR2(4000)  path '$.scoringModelAJCINE',

                                              -- 20231027 deactivation_reason         VARCHAR2(4000)  path '$.deactivationReasonAJCINE',

                                              deactivation_reason         VARCHAR2(4000)  path '$.deactivationReason',

                                              -- 20231027

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

                                              exposureNotes               VARCHAR2(4000)  path '$.exposureNotes'

                                              ) );



    -- 20250117 - BCPGL-458

    v_aig_limit   VARCHAR2(150);

    -- 20250117 - BCPGL-458



  BEGIN



    print_log ('ajc_bc_customers_to_oracle_pkg.get_customers_p (+)');



    mo_global.set_policy_context ('S',84);



    print_log ('gv_company_id: ' || gv_company_id);



    v_get_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'CUSTOMERS',

                                                 p_subentity => NULL,

                                                 p_method => 'GET' );

    print_log ('v_get_api: ' || v_get_api);                                                



    v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, gv_company_id ) || v_get_api 

                 || '?$filter=systemModifiedAt gt ' || TO_CHAR(p_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z')

                 -- se usa lookup || ' and systemModifiedBy ne 79ee8266-81b2-4694-9b2d-363f6dc49ca2' -- not equal to BC

                 -- || '?$filter=no eq ' || '''710785'''

                 ;



    print_log ('v_get_url: ' || v_get_url);



    v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );



    print_log ('Se obtienen los clientes y se insertan en la tabla ajc_bc_customers.');



    FOR cc IN c_customers ( p_clob_result => v_clob_result ) LOOP



      v_customer_number := cc.customer_number;



      -- 20250117 - BCPGL-458

      -- Se obtienen otros campos de la api CUSTOMERS | OTHERS

      -- Los nuevos campos que no existan en la api CUSTOMERS | NULL, deben agregarse en la api CUSTOMERS | OTHERS

      v_aig_limit := NULL;      



      get_other_fields_p ( p_bc_environment => p_bc_environment,

                           p_customer_number => cc.customer_number,

                           p_aig_limit => v_aig_limit );      

      -- 20250117 - BCPGL-458



      INSERT

        INTO ajc_bc_customers 

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

               -- 20250117 - BCPGL-458

               -- cc.aig_limit,

               v_aig_limit,

               -- 20250117 - BCPGL-458

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

               gv_org_id,

               cc.creation_date,

               gv_request_id,

               cc.status );        



    END LOOP;



    -- Agregado 20230327   

    -- Se actualizan como SKIPPED aquellos que fueron modificados por usuarios que no existe en la lookup

    UPDATE ajc_bc_customers

       SET status = 'SKIPPED'

     WHERE status = 'NEW'

       AND request_id = gv_request_id

       AND systemModifiedBy NOT IN ( SELECT description

                                       FROM fnd_lookup_values

                                      WHERE lookup_type = 'AJC_BC_CUSTOMERS_IFC_USERS'

                                        AND enabled_flag = 'Y'

                                        AND SYSDATE BETWEEN start_date_active AND NVL(end_date_active,SYSDATE + 1) );



    COMMIT;

    -- Agregado 20230327 



    p_return := 'S';

    print_log ('ajc_bc_customers_to_oracle_pkg.get_customers_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      ROLLBACK;

      print_log ('ajc_bc_customers_to_oracle_pkg.get_customers_p (!)');

      print_log ('Customer: ' || v_customer_number);

      p_return := 'E';

      p_message := SQLCODE || ': ' || SQLERRM || ' - Customer Number: ' || v_customer_number;



  END get_customers_p;



  -- ------------------------------------------------------------------------------------------------------------------------ --

  -- PROCESS CUSTOMERS ------------------------------------------------------------------------------------------------------ --

  -- ------------------------------------------------------------------------------------------------------------------------ --

  PROCEDURE process_customers_p ( p_bc_environment   IN       VARCHAR2,

                                  p_count            IN OUT   NUMBER,

                                  p_return           OUT      VARCHAR2, 

                                  p_message          OUT      VARCHAR2 ) IS



    CURSOR c_customers IS

    SELECT *

      FROM ajc_bc_customers

     WHERE status = 'NEW'

       AND request_id = gv_request_id;



    v_statement_cycle_id   NUMBER;

    v_payment_terms_id     NUMBER;

    v_payment_term_active  VARCHAR2(1);

    v_collector_id         NUMBER;



    v_salesperson_name     jtf_rs_salesreps.name%TYPE;

    v_salesperson_id       jtf_rs_salesreps.salesrep_id%TYPE;



    -- 20230330

    v_campos_sin_valor     VARCHAR2(2000);

    -- 20230330



    -- 20230925

    v_review_cycle         fnd_lookup_values.lookup_code%TYPE;

    v_rowid                VARCHAR2(200);

    v_review_cycle_active  VARCHAR2(1);

    -- 20230925



    e_exception            EXCEPTION;



  BEGIN



    print_log ('ajc_bc_customers_to_oracle_pkg.process_customers_p (+)');



    p_count := 0;



    FOR cc IN c_customers LOOP



      BEGIN



        p_message := NULL;

        p_count := p_count + 1;



        v_statement_cycle_id := NULL;

        v_payment_terms_id := NULL;

        v_collector_id := NULL;



        -- 20230330

        v_campos_sin_valor := NULL;

        -- 20230330



        print_log ( 'Customer Number: ' || cc.customer_number );



        -- Customer Name -------------------------------------------------------------------------------------------------------

        print_log ( 'Check Customer Name' );



        IF ( cc.customer_name IS NULL OR cc.customer_name = ' ' ) THEN



          print_log ( 'Customer Name cannot be empty.' );

          v_campos_sin_valor := 'Customer Name, ';



        END IF;



        -- Salesperson Code ----------------------------------------------------------------------------------------------------

        -- 20230629

        /*

        print_log ( 'Check Salesperson Code' );



        IF ( cc.salesperson_code IS NULL OR cc.salesperson_code = ' ' ) THEN



          print_log ( 'Salesperson Code cannot be empty.' );

          v_campos_sin_valor := v_campos_sin_valor || 'Salesperson Code, ';



        END IF;

        */

        -- 20230629



        -- LOB -----------------------------------------------------------------------------------------------------------------

        print_log ( 'Check LOB' );



        IF ( cc.lob IS NULL OR cc.lob = ' ' ) THEN



          print_log ( 'LOB cannot be empty.' );

          v_campos_sin_valor := v_campos_sin_valor || 'LOB, ';



        END IF;



        -- Review Cycle --------------------------------------------------------------------------------------------------------

        print_log ( 'Check Review Cycle' );



        IF ( cc.review_cycle IS NULL OR cc.review_cycle = ' ' ) THEN



          print_log ( 'Review Cycle cannot be empty.' );

          v_campos_sin_valor := v_campos_sin_valor || 'Review Cycle, ';



        -- 20230925

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

          --20230925



          IF ( v_review_cycle_active = 'N' ) THEN



            v_review_cycle := NULL;

            p_message := 'Review Cycle ' || cc.review_cycle || ' is inactive in Oracle.';

            print_log ( p_message );

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

        -- 20230629

        /*

        print_log ( 'Check City' );



        IF ( cc.city IS NULL OR cc.city = ' ' ) THEN



          print_log ( 'City cannot be empty.' );

          v_campos_sin_valor := v_campos_sin_valor || 'City, ';



        END IF;

        */

        -- 20230629



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



          p_message := v_campos_sin_valor;

          RAISE e_exception;



        END IF;



        -- Salesperson Code



        -- 20230629

        v_salesperson_name := NULL;

        v_salesperson_id := NULL;

        -- 20230629



        -- Se busca si existe en la lookup AJC_BC_CUSTOMERS_IFC_SALESPERS  

        -- 20230629

        IF ( cc.salesperson_code IS NOT NULL ) THEN

        -- 20230629

          BEGIN



            -- v_salesperson_name := NULL;

            -- v_salesperson_id := NULL;



            print_log ( 'BC Salesperson Code: ' || cc.salesperson_code );



            SELECT lookup_code

              INTO v_salesperson_name

              FROM fnd_lookup_values l

             WHERE l.lookup_type = 'AJC_BC_CUSTOMERS_IFC_SALESPERS'

               AND l.meaning = cc.salesperson_code;



            print_log ( 'Oracle Salesperson Code: ' || v_salesperson_name );



          EXCEPTION

            WHEN OTHERS THEN

              p_message := 'Cant get Salesperson mapping for Salesperson Code (lookup AJC_BC_CUSTOMERS_IFC_SALESPERS).';

              print_log ( p_message );

              RAISE e_exception;



          END;



          -- Si se encontró en la lookup AJC_BC_CUSTOMERS_IFC_SALESPERS, se busca el id con el name de Oracle

          BEGIN



            SELECT salesrep_id

              INTO v_salesperson_id

              FROM jtf_rs_salesreps sr

             WHERE sr.name = v_salesperson_name

             -- 20231017

               AND NVL(status,'A') = 'A'

               AND SYSDATE BETWEEN start_date_active AND NVL(end_date_active,SYSDATE + 1)

             -- 20231017

             ;



            print_log ( 'salesperson_id: ' || v_salesperson_id );



          EXCEPTION

            WHEN OTHERS THEN

              p_message := 'Cant get Salesperson ID for Oracle Salesperson Code.';

              print_log ( 'Cant get Salesperson ID for Oracle Salesperson Code.' );

              RAISE e_exception;



          END;

        -- 20230629

        END IF;

        -- 20230629



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

          v_payment_terms_id := ajc_bc_create_entities_pkg.payment_terms_f ( cc.payment_terms, 'AR', gv_company_id, p_bc_environment );                                                                                            

          print_log ( 'v_payment_terms_id: ' || v_payment_terms_id );



          -- Se verifica si el payment terms está activo en Oracle

          SELECT DECODE(COUNT(1),0,'N','Y')

            INTO v_payment_term_active

            FROM ra_terms

           WHERE term_id = v_payment_terms_id

             AND TRUNC(SYSDATE) BETWEEN TRUNC(start_date_active) AND TRUNC(NVL(end_date_active - 1,SYSDATE + 1));



          IF ( v_payment_term_active = 'N' ) THEN



            print_log ( 'Payment Term is inactive.' );

            p_message := 'Payment Term ' || cc.payment_terms || ' is inactive in Oracle.';

            RAISE e_exception;



          END IF;



        END IF;



        UPDATE ajc_bc_customers

           SET statement_cycle_id = v_statement_cycle_id,

               payment_terms_id = v_payment_terms_id,

               collector_id = v_collector_id,

               salesperson_id = v_salesperson_id,

               -- 20230925

               review_cycle = v_review_cycle,

               -- 20230925

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



          UPDATE ajc_bc_customers

             SET status = 'ERROR',

                 processed_date = TRUNC(SYSDATE),

                 message = p_message

           WHERE customer_number = cc.customer_number

             AND status = 'NEW'

             AND request_id = gv_request_id

             AND message IS NULL

             AND processed_date IS NULL;    



          print_log ( 'Record Updated. ERROR' );



          COMMIT;



        WHEN OTHERS THEN



          ROLLBACK;



          UPDATE ajc_bc_customers

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



    p_return := 'S';

    print_log ('ajc_bc_customers_to_oracle_pkg.process_customers_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      print_log ('ajc_bc_customers_to_oracle_pkg.process_customers_p (!)');

      p_return := 'E';

      p_message := SQLCODE || ': ' || SQLERRM;



  END process_customers_p;



  PROCEDURE address_p ( p_tbl_status                VARCHAR2,

                        p_customer_id               NUMBER,

                        p_address1                  VARCHAR2,

                        p_address2                  VARCHAR2,

                        -- 20230310

                        p_address3                  VARCHAR2,

                        p_address4                  VARCHAR2,

                        p_ajc_destination_country   VARCHAR2,

                        -- 20230310

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

    -- 20230310

    print_log ('p_address3: ' || p_address3);

    print_log ('p_address4: ' || p_address4);

    print_log ('p_ajc_destination_country: ' || p_ajc_destination_country);

    -- 20230310

    print_log ('p_country: ' || p_country);

    print_log ('p_city: ' || p_city);

    print_log ('p_state: ' || p_state);

    print_log ('p_zip: ' || p_zip);



    -- Se mapea el country

    /* 20230322

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

    -- 20230322



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

           AND hcas.org_id = 5244

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

    -- 20230310

    v_location_rec.address3 := NVL(p_address3,FND_API.G_MISS_CHAR);

    v_location_rec.address4 := NVL(p_address4,FND_API.G_MISS_CHAR);

    -- 20230310

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

    -- 20230404

    v_cust_acct_site_rec.attribute1 := NVL(p_ajc_destination_country,FND_API.G_MISS_CHAR);

    -- 20230404



    IF ( v_cust_acct_site_id IS NULL ) THEN



      print_log ('Cust Acct Site no existe. Se crea.');

      -- v_cust_acct_site_rec.org_id := 5244; -- r_cust.bill_to_org;

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

    -- 20230518 v_cust_site_use_rec.location                  := 'BC';

    v_cust_site_use_rec.location                  := 'NONE';

    --

    v_cust_site_use_rec.primary_flag              := 'Y';



    -- BILL-TO

    IF ( v_bill_to_site_use_id IS NULL ) THEN



      print_log ('Cust Site Use BILL-TO no existe. Se crea.');

      v_cust_site_use_rec.created_by_module := 'TCA_V2_API';



      print_log ('HZ_CUST_ACCOUNT_SITE_V2PUB.CREATE_CUST_SITE_USE');  

      HZ_CUST_ACCOUNT_SITE_V2PUB.CREATE_CUST_SITE_USE ( p_init_msg_list         => FND_API.G_TRUE,

                                                        p_cust_site_use_rec     => v_cust_site_use_rec,

                                                        p_customer_profile_rec  => v_customer_profile_rec,

                                                        -- 20230420 p_create_profile        => FND_API.G_TRUE,

                                                        p_create_profile        => FND_API.G_FALSE,

                                                        -- 

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

    -- 20230518 v_cust_site_use_rec.location                  := 'BC';

    v_cust_site_use_rec.location                  := 'NONE';

    --

    v_cust_site_use_rec.primary_flag              := 'Y';



    -- SHIP_TO

    IF ( v_ship_to_site_use_id IS NULL ) THEN



      print_log ('Cust Site Use SHIP-TO no existe. Se crea.');      

      v_cust_site_use_rec.created_by_module := 'TCA_V2_API';



      print_log ('HZ_CUST_ACCOUNT_SITE_V2PUB.CREATE_CUST_SITE_USE');

      HZ_CUST_ACCOUNT_SITE_V2PUB.CREATE_CUST_SITE_USE ( p_init_msg_list         => FND_API.G_TRUE,

                                                        p_cust_site_use_rec     => v_cust_site_use_rec,

                                                        p_customer_profile_rec  => v_customer_profile_rec,

                                                        -- 20230420 p_create_profile        => FND_API.G_TRUE,

                                                        p_create_profile        => FND_API.G_FALSE,

                                                        -- 

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

    print_log ( 'ajc_bc_customers_to_oracle_pkg.contact_p (+)' );



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



    print_log ( 'ajc_bc_customers_to_oracle_pkg.contact_p (-)' );



  EXCEPTION

    WHEN e_exception THEN

      print_log ( 'ajc_bc_customers_to_oracle_pkg.contact_p (!)' );

      p_status := 'E';

    WHEN OTHERS THEN

      print_log ( 'ajc_bc_customers_to_oracle_pkg.contact_p (!)' );

      p_status := 'E';

      p_return_msg := 'Error general: ' || SQLERRM;



  END contact_p;



  -- ------------------------------------------------------------------------------------------------------------------------ --

  -- CREATE / UPDATE CUSTOMERS ---------------------------------------------------------------------------------------------- --

  -- ------------------------------------------------------------------------------------------------------------------------ --

  PROCEDURE create_customers_p ( p_bc_environment   IN       VARCHAR2,

                                 p_return           OUT      VARCHAR2, 

                                 p_message          OUT      VARCHAR2 ) IS



    CURSOR c_customers IS

    SELECT *

      FROM ajc_bc_customers

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



    -- v_oracle_dae                 VARCHAR2(15);



    v_return_status              VARCHAR2(1);

    v_msg_count                  NUMBER;

    v_msg_data                   VARCHAR2(4000);

    v_err_msg                    VARCHAR2(4000);



    v_clob_result                CLOB;



    -- 20230414 v_patch_api                  VARCHAR2(100) := 'oraclecustomerIDINE'; 

    v_patch_api                  VARCHAR2(100);

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



    print_log ('ajc_bc_customers_to_oracle_pkg.create_customers_p (+)');



    fnd_global.apps_initialize ( user_id => 0,

                                 resp_id => 20678,

                                 resp_appl_id => 222 );



    mo_global.set_policy_context ('S', 5244);



    FOR cc IN c_customers LOOP



      BEGIN



        print_log ( ' ' );

        print_log ( 'Customer Number: ' || cc.customer_number );

        print_log ( 'Customer Name: ' || cc.customer_name );



        v_customer_id := NULL;

        v_party_id := NULL;

        v_party_number := NULL;

        -- 20230330

        -- v_oracle_dae := NULL;

        -- 20230330

        v_tbl_status := NULL;



        rec_organization := NULL;

        rec_cust_account := NULL;

        rec_customer_profile := NULL;

        rec_customer_profile_amt := NULL;



        -- 20230317

        -- El customer ya fue creado en Oracle, por eso el campo oracleCustomerIDAJCINE ya tiene el ID

        -- Se agrega porque en BC es posible cambiarle el nro a un customer

        IF ( cc.oracleCustomerIDAJCINE IS NOT NULL ) THEN



          -- Primero se busca por customer_id

          BEGIN



            SELECT customer_id,

                   party_id,

                   party_number

                   -- 20230330

                   -- ,attribute2

                   -- 20230330

              INTO v_customer_id,

                   v_party_id,

                   v_party_number

                   -- 20230330

                   -- ,v_oracle_dae

                   -- 20230330

              FROM ra_customers

             WHERE customer_id = cc.oracleCustomerIDAJCINE;



          print_log ('Customer found for customer id ' || cc.oracleCustomerIDAJCINE);



          EXCEPTION

            WHEN OTHERS THEN

              v_customer_id := NULL;

              v_party_id := NULL;

              v_party_number := NULL;

              -- 20230330

              -- v_oracle_dae := NULL;

              -- 20230330



          END;



        ELSE

        -- 20230317



          -- Se verifica si existe o no el customer en Oracle

          BEGIN



            -- Primero se busca por numero

            SELECT customer_id,

                   party_id,

                   party_number

                   -- 20230330

                   -- ,attribute2

                   -- 20230330

              INTO v_customer_id,

                   v_party_id,

                   v_party_number

                   -- 20230330

                   -- ,v_oracle_dae

                   -- 20230330

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

                       -- 20230330

                       -- ,attribute2

                       -- 20230330

                  INTO v_customer_id,

                       v_party_id,

                       v_party_number

                       -- 20230330

                       -- ,v_oracle_dae

                       -- 20230330

                  FROM ra_customers

                 WHERE UPPER(customer_name) = UPPER(cc.customer_name);



                print_log ('Customer found for customer name ' || cc.customer_name);



              EXCEPTION

                WHEN NO_DATA_FOUND THEN

                  v_customer_id := NULL;

                  v_party_id := NULL;

                  v_party_number := NULL;

                  -- 20230330

                  -- v_oracle_dae := NULL;

                  -- 20230330



                WHEN TOO_MANY_ROWS THEN

                  v_tbl_message := 'Customer ' || cc.customer_name || ' duplicated.';

                  RAISE e_customer;



                WHEN OTHERS THEN

                  v_tbl_message := 'Customer ' || cc.customer_name || ' general error.';

                  RAISE e_customer;



              END;



          END; 



        -- 20230317

        END IF;

        -- 20230317



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

        -- 20230524

        IF ( v_customer_id IS NULL ) THEN



          rec_cust_account.attribute1 := 0; -- Pending Balance



        END IF;

        -- 20230524



        -- 20230411 

        -- Se valida DAE

        IF ( TO_NUMBER(REPLACE(cc.dae,',','.'),'990.99') >= 0 AND TO_NUMBER(REPLACE(cc.dae,',','.'),'990.99') < 1 ) THEN



          rec_cust_account.attribute2 := '0'; 



        ELSE



          rec_cust_account.attribute2 := NVL(cc.dae,FND_API.G_MISS_CHAR);



        END IF;

        -- 20230411

        --print_log ( '2' );

        rec_cust_account.attribute3 := NVL(cc.ajc_destination_country,FND_API.G_MISS_CHAR);

        --print_log ( '3' );

        rec_cust_account.attribute4 := NVL(cc.bank_charge,FND_API.G_MISS_CHAR);

        --print_log ( '4' );

        rec_cust_account.attribute5 := NVL(cc.account_created,FND_API.G_MISS_CHAR);

        --print_log ( '5' );

        rec_cust_account.attribute9 := NVL(TO_CHAR(cc.customer_priority),FND_API.G_MISS_CHAR);

        --print_log ( '6' );

        -- 20230524

        IF ( cc.adop IS NULL OR cc.adop = ' ' ) THEN



          rec_cust_account.attribute10 := 0; 



        ELSE



          rec_cust_account.attribute10 := cc.adop;



        END IF; 

        -- 20230524

        rec_cust_account.attribute11 := NVL(cc.insured_country,FND_API.G_MISS_CHAR);

        --print_log ( '7' );

        rec_cust_account.attribute12 := NVL(cc.coface_limit,FND_API.G_MISS_CHAR);

        --print_log ( '8' );

        rec_cust_account.attribute13 := NVL(cc.deactivation_reason,FND_API.G_MISS_CHAR);

        --print_log ( '9' );

        rec_cust_account.attribute14 := NVL(cc.aig_limit,FND_API.G_MISS_CHAR);

        --print_log ( '10' );

        rec_cust_account.attribute15 := NVL(cc.scoring_model,FND_API.G_MISS_CHAR);

        --print_log ( '11' );

        rec_cust_account.attribute16 := NVL(cc.last_file_review,FND_API.G_MISS_CHAR); 

        --print_log ( '12' );

        rec_cust_account.attribute20 := NVL(cc.open_acct_limit,FND_API.G_MISS_CHAR); 

        --print_log ( '13' );

        rec_cust_account.primary_salesrep_id := NVL(cc.salesperson_id,FND_API.G_MISS_NUM); 

        --print_log ( '14' );



        rec_organization.organization_name := cc.customer_name;

        rec_organization.jgzz_fiscal_code := NVL(SUBSTR(TRIM(REPLACE(cc.tax_no,'-')),1,10),FND_API.G_MISS_CHAR);

        --print_log ( '15' );

        rec_organization.created_by_module := 'TCA_V2_API';



        rec_customer_profile.profile_class_id := NVL(cc.profile_class_id,FND_API.G_MISS_NUM);  -- Default

        --print_log ( '16' );

        rec_customer_profile.collector_id := NVL(cc.collector_id,FND_API.G_MISS_NUM); 

        --print_log ( '17' );



        rec_customer_profile.risk_code := cc.lob; 

        --print_log ( '18' );

        rec_customer_profile.account_status := NVL(cc.account_status,FND_API.G_MISS_CHAR); 

        --print_log ( '19' );

        rec_customer_profile.review_cycle := NVL(cc.review_cycle,FND_API.G_MISS_CHAR); 

        --print_log ( '20' );

        rec_customer_profile.credit_hold := NVL(cc.credit_hold,FND_API.G_MISS_CHAR); 

        --print_log ( '21' );

        rec_customer_profile.credit_checking := NVL(cc.credit_check,FND_API.G_MISS_CHAR); 

        --print_log ( '22' );

        rec_customer_profile.tolerance := NVL(cc.tolerance,FND_API.G_MISS_NUM); 

        --print_log ( '23' );

        rec_customer_profile.credit_classification := NVL(cc.credit_classification,FND_API.G_MISS_CHAR); 

        --print_log ( '24' );

        rec_customer_profile.credit_rating := NVL(cc.credit_rating,FND_API.G_MISS_CHAR); 

        --print_log ( '25' );

        rec_customer_profile.send_statements := NVL(cc.send_statements,FND_API.G_MISS_CHAR);

        --print_log ( '26' );

        rec_customer_profile.credit_balance_statements := NVL(cc.credit_balance_statements,FND_API.G_MISS_CHAR);

        --print_log ( '27' );

        rec_customer_profile.statement_cycle_id := NVL(cc.statement_cycle_id,FND_API.G_MISS_NUM);

        --print_log ( '28' );



        rec_customer_profile_amt.currency_code := 'USD';

        rec_customer_profile_amt.created_by_module := 'TCA_V2_API';

        -- 20230411

        -- Se valida order_credit_limit

        IF ( cc.order_credit_limit >= 0 AND cc.order_credit_limit < 1 ) THEN



          rec_customer_profile_amt.trx_credit_limit := 0;



        ELSE



          rec_customer_profile_amt.trx_credit_limit := NVL(cc.order_credit_limit,FND_API.G_MISS_NUM);



        END IF;

        -- 20230411

        --print_log ( '29' );

        rec_customer_profile_amt.overall_credit_limit := NVL(cc.ar_limit,FND_API.G_MISS_NUM);

        --print_log ( '30' );



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



              -- 20250617

              /*

              -- Se obtiene el nombre de la base de datos

              SELECT name

                INTO v_db_name

                FROM V$DATABASE;



              -- --------------------------------------------------------------------------------------------- --

              -- Se actualiza el customer_id en BC - Solo si se ejecuta en Oracle PROD                         -- 

              -- o si se ejecuta en Oracle FINUPG5 apuntando a Sandbox                                         --

              -- --------------------------------------------------------------------------------------------- --

              IF ( ( v_db_name = 'PROD' -- AND p_bc_environment IN ('Production','Production-UAT') 

                   ) OR 

                   ( v_db_name = 'FINUPG5' AND p_bc_environment = 'Sandbox' ) ) THEN



                v_patch_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'CUSTOMERS',

                                                               p_subentity => 'CUSTOMER_ID',

                                                               p_method => 'PATCH' );



                print_log ('v_patch_api: ' || v_patch_api);                                                               



                -- Patch URL

                v_patch_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, gv_company_id ) || v_patch_api || '(' || cc.systemid || ')';

                print_log ('v_patch_url: ' || v_patch_url);



                -- 1

                print_log ('Se obtiene el etag del customer.');            



                v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_patch_url );



                v_etag := SUBSTR(v_clob_result,INSTR(v_clob_result,'@odata.etag') + 14);

                v_etag := REPLACE(SUBSTR(v_etag,1,INSTR(v_etag,',') - 2),'\');



                print_log ('v_etag: ' || v_etag);



                -- 2

                print_log ( 'Se actualiza el oracle_customer_id en BC.');



                v_body := '{"oraclecustomerID":"' || v_customer_id || '"}';



                v_clob_result := ajc_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_patch_url

                                                                          ,p_request_header_name1 => 'Content-Type'

                                                                          ,p_request_header_value1 => 'application/json'

                                                                          ,p_request_header_name2 => 'If-Match'

                                                                          ,p_request_header_value2 => v_etag

                                                                          ,p_http_method => 'PATCH'

                                                                          ,p_body => v_body );            



                print_log ('v_clob_result: ' || v_clob_result);



              END IF;

              */

              send_oracle_cust_id_to_bc_p ( p_bc_environment => p_bc_environment,

                                            p_system_id => cc.systemid,

                                            p_customer_id => v_customer_id );

              -- 20250617



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



            -- 20221108 -- Se actualiza el nombre

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



            -- 20230927

            -- Se agrega update porque a veces no actualiza el AR Limit

            UPDATE hz_cust_profile_amts

               SET overall_credit_limit = cc.ar_limit

             WHERE cust_account_id = v_customer_id

               AND site_use_id IS NULL;

            -- 20230927



            print_log ( 'Cliente actualizado. v_customer_id: ' || v_customer_id);

            v_tbl_status := 'UPDATED';



            -- 20250617

            IF ( cc.oracleCustomerIDAJCINE IS NULL ) THEN 



              send_oracle_cust_id_to_bc_p ( p_bc_environment => p_bc_environment,

                                            p_system_id => cc.systemid,

                                            p_customer_id => v_customer_id );



            END IF;

            -- 20250617



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

                    -- 20230310

                    p_address3 => cc.address3,

                    p_address4 => cc.address4,

                    p_ajc_destination_country => cc.ajc_destination_country,

                    -- 20230310

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



        -- 20230411

        -- Se actualizan los atributos de la hz_parties para el party creado o actualizado.

        print_log ( 'Se actualizan los atributos de la hz_parties para el party creado o actualizado (party_id: ' || v_party_id || ').' );



        UPDATE hz_parties

           SET attribute2 = rec_cust_account.attribute2,

               attribute3 = rec_cust_account.attribute3,

               attribute4 = rec_cust_account.attribute4,

               attribute5 = rec_cust_account.attribute5,

               attribute9 = rec_cust_account.attribute9,

               attribute11 = rec_cust_account.attribute11,

               attribute12 = rec_cust_account.attribute12,

               attribute13 = rec_cust_account.attribute13,

               attribute14 = rec_cust_account.attribute14,

               attribute15 = rec_cust_account.attribute15,

               attribute16 = rec_cust_account.attribute16,

               attribute20 = rec_cust_account.attribute20,

               last_update_date = SYSDATE

         WHERE party_id = v_party_id;

        -- 20230411



        -- HABILITAR CUANDO TENGAMOS EXPOSURE NOTES HABILITADO EN EL WS

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

        update_ajc_bc_customers_p ( p_customer_number     => cc.customer_number,

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



        -- 20250129 

        BEGIN



          print_log ('Executing oms.adm_customer_pkg.sync_companies.' );

          oms.adm_customer_pkg.sync_companies ( p_customer_id => v_customer_id );



        EXCEPTION

          WHEN OTHERS THEN

            print_log ('Error calling oms.adm_customer_pkg.sync_companies. ' || SQLERRM);



        END;



        BEGIN



          print_log ('Executing oms.adm_customer_pkg.sync_divisions.' );

          oms.adm_customer_pkg.sync_divisions ( p_customer_id => v_customer_id );



        EXCEPTION

          WHEN OTHERS THEN

            print_log ('Error calling oms.adm_customer_pkg.sync_divisions. ' || SQLERRM);



        END;

        -- 20250129



        COMMIT;



      EXCEPTION

        WHEN e_customer THEN



          ROLLBACK;          



          update_ajc_bc_customers_p ( p_customer_number     => cc.customer_number,

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



          update_ajc_bc_customers_p ( p_customer_number     => cc.customer_number,

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



    p_return := 'S';

    print_log ('ajc_bc_customers_to_oracle_pkg.create_customers_p (-)');    



  EXCEPTION

    WHEN OTHERS THEN

      print_log ('ajc_bc_customers_to_oracle_pkg.create_customers_p (!)');

      p_return := 'E';

      p_message := SQLCODE || ': ' || SQLERRM;



  END create_customers_p;



  -- 20231121

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

           -- 20240325

          ,p.city hz_party_city

          ,hl.city hz_loc_city

           -- 20240325

      FROM hz_parties p,

           hz_party_sites ps,

           hz_locations hl,

           hz_cust_accounts c,

           (  SELECT party_id, MAX(request_id) req_id

                FROM ajc_bc_customers

               WHERE status IN ('UPDATED','CREATED')

            GROUP BY party_id) bc,

           ajc_bc_customers  bcdet

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

             NVL(p.address4,'NULL ADDRESS4') <> NVL(hl.address4,'NULL ADDRESS4') 

             -- 20240325

             OR NVL(p.city,'NULL CITY') <> NVL(hl.city,'NULL CITY') 

             -- 20240325

             )

       AND bcdet.party_id = bc.party_id

       AND bc.req_id = bcdet.request_id;



    v_cantidad   NUMBER;



  BEGIN



    print_log ('ajc_bc_customers_to_oracle_pkg.update_hz_parties_address_p (+)');



    v_cantidad := 0;



    FOR cd IN c_diferencias LOOP



      print_log ('account_number: ' || cd.account_number || ' | party_id: ' || cd.party_id || ' | party_name: ' || cd.party_name);



      UPDATE hz_parties

         SET address1 = cd.hz_loc_addr1,

             address2 = cd.hz_loc_addr2,

             address3 = cd.hz_loc_addr3,

             address4 = cd.hz_loc_addr4

             -- 20240325

            ,city = cd.hz_loc_city

             -- 20240325

       WHERE party_id = cd.party_id;



      v_cantidad := v_cantidad + SQL%ROWCOUNT;



    END LOOP;



    COMMIT;



    print_log ('Cantidad de registros actualizados: ' || v_cantidad);

    print_log ('ajc_bc_customers_to_oracle_pkg.update_hz_parties_address_p (-)');



  END update_hz_parties_address_p;

  -- 20231121



  PROCEDURE customers_p ( retcode                  OUT   NUMBER,

                          errbuf                   OUT   VARCHAR2,

                          p_bc_environment          IN   VARCHAR2,

                          p_refresh_payment_terms   IN   VARCHAR2 ) IS



    v_email                    VARCHAR2(2000);



    v_run_date                 TIMESTAMP;

    v_last_processed_date      TIMESTAMP;

    v_last_bc_processed_date   TIMESTAMP;



    v_return                   VARCHAR2(1);

    v_message                  VARCHAR2(2000);

    v_count                    NUMBER := 0;



    e_org                      EXCEPTION;  

    e_get                      EXCEPTION;  

    e_process                  EXCEPTION;

    e_create                   EXCEPTION;



    v_request_id_excel         NUMBER;



  BEGIN



    print_log ('ajc_bc_customers_to_oracle_pkg.customers_p (+)');



    v_email := ajc_bc_ws_utils_pkg.get_emails_f ( 'CUSTOMERS' );



    -- Se guarda la fecha y hora actual

    v_run_date := systimestamp;

    print_log ( 'v_run_date: ' || v_run_date );



    -- Se obtiene la fecha y hora de Oracle de la ultima ejecucion de la interface

    v_last_processed_date := ajc_bc_ws_utils_pkg.get_ifc_last_processed_date_f ( gv_ifc );

    print_log ( 'Oracle last processed date: ' || v_last_processed_date );    



    -- Se obtiene la fecha y hora de BC de la ultima ejecucion de la interface

    v_last_bc_processed_date := ajc_bc_ws_utils_pkg.get_bc_last_processed_date_f ( v_last_processed_date );

    print_log ( 'BC last processed date: ' || v_last_bc_processed_date );



    IF ( gv_org_id != 5244 ) THEN



      RAISE e_org;



    END IF;    



    -- Se sincronizan las novedades de payment terms antes de traer los customers

    IF ( p_refresh_payment_terms = 'Y' ) THEN



      ajc_bc_payment_terms_pkg.caller_p ( p_bc_environment => p_bc_environment );



    END IF;



    get_customers_p ( p_last_bc_processed_date => v_last_bc_processed_date,

                      p_bc_environment => p_bc_environment,

                      p_return => v_return, 

                      p_message => v_message );



    IF ( v_return != 'S' ) THEN



      RAISE e_get;



    END IF;



    process_customers_p ( p_bc_environment => p_bc_environment,

                          p_count => v_count,

                          p_return => v_return, 

                          p_message => v_message );



    IF ( v_return != 'S' ) THEN



      RAISE e_process;



    END IF;                          



    create_customers_p ( p_bc_environment => p_bc_environment,

                         p_return => v_return, 

                         p_message => v_message );



    IF ( v_return != 'S' ) THEN



      RAISE e_create;



    END IF; 



    IF ( v_count > 0 ) THEN



      -- EXCEL REPORT ------------------------------------------------------------------------------------------------------------

      v_request_id_excel := ajc_bc_ws_utils_pkg.print_excel_report ( p_request_id => gv_request_id,

                                                                     p_program => 'AJCBCCIR', -- AJC BC Customers Interface Report

                                                                     p_template => 'AJCBCCIR' );



      -- 20230317 send_email ( p_email, v_request_id_excel );



      ajc_bc_ws_utils_pkg.send_unix_mail_attach ( p_mail => v_email,

                                                  p_report_request_id => v_request_id_excel ); 



    END IF;



    -- 20231121

    -- Verifica diferencias en las direcciones de customers entre la hz_parties y hz_locations

    -- En caso de haber diferencia, pone los valores de address1, address2, address3, address4, city de hz_locations

    -- en hz_parties

    update_hz_parties_address_p;

    -- 20231121



    -- Se actualiza la tabla de control

    ajc_bc_ws_utils_pkg.upd_ifc_last_processed_date_p ( gv_ifc,

                                                        gv_request_id,

                                                        v_run_date );



    COMMIT;



    print_log ('ajc_bc_customers_to_oracle_pkg.customers_p (-)');



  EXCEPTION

    WHEN e_org THEN

      print_log ( 'ajc_bc_customers_to_oracle_pkg.customers_p (!)' );

      print_log ( 'El request solo puede ser ejecutado desde una responsabilidad de AJC OU.' );

      retcode := 2;

      errbuf := 'El request solo puede ser ejecutado desde una responsabilidad de AJC OU.';

      -- 20240220

      ajc_bc_ws_utils_pkg.send_email ( p_to => gv_bc_support_email

                                      ,p_subject => gv_bc_support_subject

                                      ,p_message => 'This request can only be executed from AJC OU responsibility.' );

      -- 20240220                                      

    WHEN e_get THEN

      print_log ( 'ajc_bc_customers_to_oracle_pkg.customers_p (!)' );

      print_log ( 'Error al obtener los clientes de BC. ' || v_message );

      retcode := 2;

      errbuf := v_message;

      -- 20240220

      ajc_bc_ws_utils_pkg.send_email ( p_to => gv_bc_support_email

                                      ,p_subject => gv_bc_support_subject

                                      ,p_message => 'Error getting customers from BC. ' || v_message );

      -- 20240220

    WHEN e_process THEN

      print_log ( 'ajc_bc_customers_to_oracle_pkg.customers_p (!)' );

      print_log ( 'Error al procesar los clientes de BC. ' || v_message );

      retcode := 2;

      errbuf := v_message;

      -- 20240220

      ajc_bc_ws_utils_pkg.send_email ( p_to => gv_bc_support_email

                                      ,p_subject => gv_bc_support_subject

                                      ,p_message => 'Error processing customers from BC. ' || v_message );

      -- 20240220



    WHEN e_create THEN

      print_log ( 'ajc_bc_customers_to_oracle_pkg.customers_p (!)' );

      print_log ( 'Error al intentar crear / actualizar los clientes de BC. ' || v_message );

      retcode := 2;

      errbuf := v_message;

      -- 20240220

      ajc_bc_ws_utils_pkg.send_email ( p_to => gv_bc_support_email

                                      ,p_subject => gv_bc_support_subject

                                      ,p_message => 'Error creating / updating BC customers. ' || v_message );

      -- 20240220



    WHEN OTHERS THEN

      print_log ('customers_p (!)');

      print_log ('Error general customers_p. ' || SQLERRM);

      retcode := 2;

      errbuf := 'Error general customers_p. ' || SQLERRM;

      -- 20240220

      ajc_bc_ws_utils_pkg.send_email ( p_to => gv_bc_support_email

                                      ,p_subject => gv_bc_support_subject

                                      ,p_message => 'General error customers_p ' || v_message );

      -- 20240220



  END customers_p;



END ajc_bc_customers_to_oracle_pkg; 
