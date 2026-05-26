CREATE OR REPLACE PACKAGE BODY ajc_bc_vendors_to_oracle_pkg IS



  -- 20240318

  gv_bc_support_email     VARCHAR2(200) := 'bcsupport@ajcgroup.com';

  gv_bc_support_subject   VARCHAR2(200) := 'AJC BC Vendors Interface - ERROR';

  -- 20240318



  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    fnd_file.put_line (fnd_file.log, p_message);



  END print_log;



  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    fnd_file.put_line(fnd_file.output,p_message);



  END print_output;



  PROCEDURE send_oracle_vendor_id_to_bc_p ( p_bc_environment   IN   VARCHAR2, 

                                            p_system_id        IN   VARCHAR2,

                                            p_vendor_id        IN   NUMBER ) IS



    v_db_name       VARCHAR2(100);

    v_patch_api     VARCHAR2(1000);

    v_patch_url     VARCHAR2(2000);

    v_etag          VARCHAR2(1000);

    v_body          VARCHAR2(2000);

    v_clob_result   CLOB;



  BEGIN



    print_log ( 'ajc_bc_vendors_to_oracle_pkg.send_oracle_vendor_id_to_bc_p (+)' );



    -- Se obtiene el nombre de la base de datos

    SELECT name

      INTO v_db_name

      FROM V$DATABASE;



    -- --------------------------------------------------------------------------------------------- --

    -- Se actualiza el vendor_id en BC - Solo si se ejecuta en Oracle PROD                           -- 

    -- o si se ejecuta en Oracle FINUPG5 apuntando a Sandbox                                         --

    -- --------------------------------------------------------------------------------------------- --

    IF ( ( v_db_name = 'PROD' -- AND p_bc_environment IN ('Production','Production-UAT') 

         ) OR 

         ( v_db_name = 'FINUPG5' AND p_bc_environment IN ('Sandbox','Production-UAT') )  ) THEN



      v_patch_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'VENDORS',

                                                     p_subentity => 'VENDOR_ID',

                                                     p_method => 'PATCH' );

      print_log ( 'v_patch_api: ' || v_patch_api );



      -- Patch URL

      v_patch_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, gv_company_id ) || v_patch_api || '(' || p_system_id || ')';



      print_log ( 'v_patch_url: ' || v_patch_url );



      -- 1

      print_log ( 'Se obtiene el etag del vendor.' );



      v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_patch_url );



      v_etag := SUBSTR(v_clob_result,INSTR(v_clob_result,'@odata.etag') + 14);

      v_etag := REPLACE(SUBSTR(v_etag,1,INSTR(v_etag,',') - 2),'\');



      print_log ( 'v_etag: ' || v_etag );



      -- 2

      print_log ( 'Se actualiza el oracle_vendor_id en BC.' );



      v_body := '{"oraclevendorIDAJCGINE":"' || p_vendor_id || '"}';



      v_clob_result := ajc_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_patch_url

                                                                ,p_request_header_name1 => 'Content-Type'

                                                                ,p_request_header_value1 => 'application/json'

                                                                ,p_request_header_name2 => 'If-Match'

                                                                ,p_request_header_value2 => v_etag

                                                                ,p_http_method => 'PATCH'

                                                                ,p_body => v_body );            



      print_log ( 'v_clob_result: ' || v_clob_result );



    END IF;



    print_log ( 'ajc_bc_vendors_to_oracle_pkg.send_oracle_vendor_id_to_bc_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      print_log ( 'ajc_bc_vendors_to_oracle_pkg.send_oracle_vendor_id_to_bc_p (!). Error: ' || SQLERRM );



  END send_oracle_vendor_id_to_bc_p;



  /*=========================================================================+

  |                                                                          |

  | Private Procedure                                                        |

  |    vendors_p                                                             |

  |                                                                          |

  | Description                                                              |

  |    Creacion Vendor y Vendor Site                                         |

  |                                                                          |

  | Parameters                                                               |

  |                                                                          |

  +=========================================================================*/

  PROCEDURE vendors_p ( p_bc_environment           IN       VARCHAR2,

                        p_last_bc_processed_date   IN       TIMESTAMP,

                        p_count                    IN OUT   NUMBER ) IS



    CURSOR c_vendors IS

    SELECT systemid,

           segment1,

           vendor_name,

           vat_registration_num,

           payment_terms,

           address_line1,

           address_line2,

           country,

           city,

           zip,

           vendor_site_code,

           email_address,

           org_id,

           --

           atis_valid_vendor,

           sad,

           ajc_kingdee_translated_name,

           ajc_ap_revalidation_exclude,

           -- 20240617

           -- blocked,

           CASE

             WHEN ( blocked = '_x0020_' ) THEN

               NULL

             ELSE

               blocked

           END blocked,

           -- 20240617

           --

           payment_currency,

           organization_type,           

           ajc_country_code,

           ajc_parent_site_credit_limit,

           ajc_credit_limit_amount,

           ajc_prepay_credit_limit_amount,

           pay_group,

           payment_method,

           oraclevendorIDAJCGINE

           --

      FROM ajc_bc_vendors

     WHERE status IS NULL

       AND request_id IS NULL

       AND processed_date IS NULL;



    v_get_url                  VARCHAR2(2000);

    -- 20230414 v_get_api                  VARCHAR2(100) := 'vendorINE';

    v_get_api                  VARCHAR2(100);

    -- v_patch_url                VARCHAR2(2000);

    -- 20230414 v_patch_api                VARCHAR2(100) := 'oraclevendorIDINE'; 

    -- v_patch_api                VARCHAR2(100); 



    v_vendor_name              VARCHAR2(240);

    v_vendor_id                NUMBER;

    v_one_time_flag            VARCHAR2(1);

    v_women_owned_flag         VARCHAR2(1);

    v_small_business_flag      VARCHAR2(1);

    v_vendor_site_id           NUMBER;

    v_terms_id                 ap_terms_tl.term_id%TYPE;

    v_payment_method           fnd_lookup_values.lookup_code%TYPE;

    v_pay_group                fnd_lookup_values.lookup_code%TYPE;

    v_address_line_3           po_vendor_sites_all.address_line3%TYPE;

    v_address_line_4           po_vendor_sites_all.address_line4%TYPE;

    v_province                 po_vendor_sites_all.province%TYPE;

    v_county                   po_vendor_sites_all.county%TYPE;

    v_area_code                po_vendor_sites_all.area_code%TYPE;

    v_phone                    po_vendor_sites_all.phone%TYPE;

    v_fax_area_code            po_vendor_sites_all.fax_area_code%TYPE;

    v_fax                      po_vendor_sites_all.fax%TYPE;

    v_email_address            po_vendor_sites_all.email_address%TYPE;

    v_purchasing_site_flag     po_vendor_sites_all.purchasing_site_flag%TYPE;

    v_pay_site_flag            po_vendor_sites_all.pay_site_flag%TYPE;

    v_rfq_only_site_flag       po_vendor_sites_all.rfq_only_site_flag%TYPE;



    v_status                   VARCHAR2(200);

    v_exception_msg            VARCHAR2(3000);



    e_org                      EXCEPTION;

    e_default_country          EXCEPTION;

    e_vendor                   EXCEPTION;

    e_vendor_site              EXCEPTION;



    v_tbl_status_vendor        VARCHAR2(30);

    v_tbl_status_site          VARCHAR2(30);

    v_tbl_message              VARCHAR2(1000);



    v_clob_result              CLOB;

    v_country                  VARCHAR2(80);

    v_territory_short_name     fnd_territories_vl.territory_short_name%TYPE;

    v_state                    po_vendor_sites_all.state%TYPE;



    -- v_db_name                  VARCHAR2(100);

    -- v_etag                     VARCHAR2(1000);

    -- v_body                     VARCHAR2(2000);



    -- 20230105

    v_vendor_type_lookup_code  VARCHAR2(100);

    -- 20230105



    v_payment_term_active      VARCHAR2(1);



    -- 20230720

    v_hold_all_payments_flag   po_vendor_sites_all.hold_all_payments_flag%TYPE;

    -- 20230720



  BEGIN



    print_log ( 'ajc_bc_vendors_to_oracle_pkg.vendors_p (+)' );



    IF ( gv_org_id != 5244 ) THEN



      RAISE e_org;



    END IF;



    IF ( FND_PROFILE.VALUE('DEFAULT_COUNTRY') IS NULL ) THEN



      RAISE e_default_country;



    END IF;



    print_log ( 'p_company_id: ' || gv_company_id );

    print_log ( 'p_bc_environment: ' || p_bc_environment );



    v_get_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'VENDORS',

                                                 p_subentity => NULL,

                                                 p_method => 'GET' );

    print_log ( 'v_get_api: ' || v_get_api );



    v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, gv_company_id ) || v_get_api

                 || '?$filter=systemmodifiedat gt ' || TO_CHAR(p_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z')          

                 -- se reemplazo por la lookup || ' and systemmodifiedby ne 79ee8266-81b2-4694-9b2d-363f6dc49ca2' -- not equal to BC

                 -- || '?$filter=vendorno eq ' || '''600086'''

                 ;



    print_log ( 'v_get_url: ' || v_get_url );



    v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );



    print_log ( 'Se obtienen los proveedores creados o modificados y se insertan en la tabla ajc_bc_vendors.' );



    INSERT

      INTO ajc_bc_vendors 

           ( systemid,

             segment1, 

             vendor_name, 

             vat_registration_num, 

             payment_terms,

             payment_method,

             address_line1,

             address_line2,

             country,

             city,

             zip,

             email_address,

             org_id,

             vendor_site_code,

             --

             organization_type,

             atis_valid_vendor,

             sad,

             ajc_kingdee_translated_name,

             ajc_ap_revalidation_exclude,

             blocked,

             --

             payment_currency,

             ajc_country_code,

             ajc_parent_site_credit_limit,

             ajc_credit_limit_amount,

             ajc_prepay_credit_limit_amount,

             pay_group,

             -- 20230327

             systemmodifiedby,

             -- 20230327

             -- 20230508

             oraclevendorIDAJCGINE,

             -- 20230508

             --

             creation_date )

    SELECT systemid,

           no segment1,

           -- 20231025

           -- name vendor_name,

           TRIM(name) vendor_name,

           -- 20231025

           vat_registration_num,

           DECODE(payment_terms,'TBD',NULL,' ',NULL,'',NULL,payment_terms) payment_terms,

           payment_method,

           address1,

           address2,

           -- 20250129 

           -- country,

           DECODE(country,'TBD',NULL,

                          ' ',NULL,

                          '',NULL,

                          'HDL','NLD',

                          country) country,

           -- 20250129 

           DECODE(city,'TBD',NULL,' ',NULL,'',NULL,city) city,

           zip,

           -- 20230316 email,

           REPLACE(email,';',',') email,

           gv_org_id,

           vendor_site_code,

           --

           -- UPPER(organization_type) 

           NULL organization_type,   

           --

           DECODE(atis_valid_vendor,'true','Y','N') atis_valid_vendor,

           sad,

           ajc_kingdee_translated_name,

           DECODE(ajc_ap_revalidation_exclude,'true','Y','N') ajc_ap_revalidation_exclude,

           blocked,

           --

           payment_currency,

           DECODE(ajc_country_code,'TBD',NULL,' ',NULL,'',NULL,ajc_country_code) ajc_country_code,

           ajc_parent_site_credit_limit,

           ajc_credit_limit_amount,

           ajc_prepay_credit_limit_amount,

           pay_group,

           -- 20230327

           systemmodifiedby,

           -- 20230327

           -- 20230508

           oraclevendorIDAJCGINE,

           -- 20230508

           TRUNC(SYSDATE) creation_date

    FROM json_table( v_clob_result,

                     '$.value[*]' COLUMNS ( systemid                         VARCHAR2(4000)  path '$.systemId',

                                            no                               VARCHAR2(4000)  path '$.vendorno',

                                            name                             VARCHAR2(4000)  path '$.name',

                                            payment_terms                    VARCHAR2(4000)  path '$.paymenttermscode',

                                            payment_method                   VARCHAR2(4000)  path '$.paymentmethodcode',

                                            vat_registration_num             VARCHAR2(4000)  path '$.vatregistrationno',

                                            address1                         VARCHAR2(4000)  path '$.address',

                                            address2                         VARCHAR2(4000)  path '$.address2',

                                            -- 20230329

                                            -- country                          VARCHAR2(4000)  path '$.territorycode', 

                                            country                          VARCHAR2(4000)  path '$.countryregioncode', 

                                            -- 20230329

                                            city                             VARCHAR2(4000)  path '$.city',

                                            zip                              VARCHAR2(4000)  path '$.postcode',

                                            email                            VARCHAR2(4000)  path '$.email',

                                            vendor_site_code                 VARCHAR2(4000)  path '$.legacyVendorSiteNmAJCINE',

                                            --

                                            atis_valid_vendor                VARCHAR2(4000)  path '$.atisValidVendorAJCINE',

                                            sad                              VARCHAR2(4000)  path '$.sadAJCINE',

                                            ajc_kingdee_translated_name      VARCHAR2(4000)  path '$.ajcKingdeeTrnlNameAJCINE',

                                            ajc_ap_revalidation_exclude      VARCHAR2(4000)  path '$.ajcAPRevldExcludeAJCINE',

                                            --

                                            payment_currency                 VARCHAR2(4000)  path '$.paymentCurrencyAJCINE',

                                            organization_type                VARCHAR2(4000)  path '$.organizationTypeAJCINE',

                                            -- 20230329 ajc_country_code                 VARCHAR2(4000)  path '$.countryregioncode',

                                            ajc_country_code                 VARCHAR2(4000)  path '$.territorycode',

                                            -- 20230329

                                            ajc_parent_site_credit_limit     VARCHAR2(4000)  path '$.ajcParentSiteCrLmtAJCINE',

                                            ajc_credit_limit_amount          VARCHAR2(4000)  path '$.ajcCreditLimitAmtAJCINE', 

                                            ajc_prepay_credit_limit_amount   VARCHAR2(4000)  path '$.ajcPrepayCrLmtAmtAJCINE',

                                            blocked                          VARCHAR2(4000)  path '$.blocked',

                                            pay_group                        VARCHAR2(4000)  path '$.vendorcategoryINE',

                                            -- 20230327

                                            systemmodifiedby                 VARCHAR2(4000)  path '$.systemmodifiedby',

                                            -- 20230327

                                            -- 20230508 

                                            oraclevendorIDAJCGINE            VARCHAR2(4000)  path '$.oraclevendorIDAJCGINE'  

                                            -- 20230508

                                            ) );



    -- Agregado 20230327

    -- Se actualizan como SKIPPED aquellos que fueron modificados por usuarios que no existe en la lookup

    UPDATE ajc_bc_vendors

       SET status = 'SKIPPED',

           processed_date = TRUNC(SYSDATE),

           request_id = gv_request_id

     WHERE status IS NULL

       AND request_id IS NULL

       AND processed_date IS NULL

       AND systemmodifiedby NOT IN ( SELECT description

                                       FROM fnd_lookup_values

                                      WHERE lookup_type = 'AJC_BC_VENDORS_IFC_USERS'

                                        AND enabled_flag = 'Y'

                                        AND SYSDATE BETWEEN start_date_active AND NVL(end_date_active,SYSDATE + 1) );



    p_count := SQL%ROWCOUNT;

    -- Agregado 20230327



    COMMIT;



    print_log ( 'gv_company_name: ' || gv_company_name );



    FOR cv IN c_vendors LOOP



      BEGIN



        -- ----------- --

        -- Proveedores --

        -- ----------- --



        v_vendor_name := cv.vendor_name;

        p_count := p_count + 1;



        print_log ( '-------------------------------------------------------------------------------------------------------' );

        print_log ( 'Vendor Num: ' || cv.segment1 );

        print_log ( 'Vendor Name: ' || cv.vendor_name );



        IF ( cv.vendor_site_code IS NULL ) THEN



          v_tbl_status_vendor := 'ERROR';

          v_tbl_message := 'Legacy Vendor Site Name could not be null in BC.';

          RAISE e_vendor;



        END IF;



        -- El vendor ya fue creado en Oracle, por eso el campo oraclevendorIDAJCGINE ya tiene el ID

        -- Se agrega porque en BC es posible cambiarle el nro a un vendor

        IF ( cv.oraclevendorIDAJCGINE IS NOT NULL ) THEN



          print_log ( 'Vendor was already synchronized from BC to Oracle. We use oraclevendorIDAJCGINE (' || cv.oraclevendorIDAJCGINE || ') to get the vendor.' );



          -- Primero se busca por vendor_id

          BEGIN



            SELECT vendor_id,

                   one_time_flag,

                   women_owned_flag,

                   small_business_flag

              INTO v_vendor_id, 

                   v_one_time_flag,

                   v_women_owned_flag,

                   v_small_business_flag

              FROM po_vendors

             WHERE vendor_id = cv.oraclevendorIDAJCGINE;



            print_log ('Vendor found for vendor id ' || cv.oraclevendorIDAJCGINE);



          EXCEPTION

            WHEN OTHERS THEN

              v_vendor_id := NULL; 

              v_one_time_flag := NULL; 

              v_women_owned_flag := NULL; 

              v_small_business_flag := NULL; 



          END;



        ELSE

        -- 20230317



          print_log ( 'Vendor wasnt synchronized from BC to Oracle. First Time.' );



          -- Se verifica si el proveedor existe en Oracle 

          BEGIN



            -- Primero se busca por numero

            SELECT vendor_id,

                   one_time_flag,

                   women_owned_flag,

                   small_business_flag

              INTO v_vendor_id, 

                   v_one_time_flag,

                   v_women_owned_flag,

                   v_small_business_flag

              FROM po_vendors

             WHERE segment1 = cv.segment1;



            print_log ('Vendor found for vendor number ' || cv.segment1);



          EXCEPTION

            WHEN OTHERS THEN



              -- Si no se encuentra por numero, se busca por nombre

              BEGIN



                SELECT vendor_id,

                       one_time_flag,

                       women_owned_flag,

                       small_business_flag

                  INTO v_vendor_id,

                       v_one_time_flag,

                       v_women_owned_flag,

                       v_small_business_flag

                  FROM po_vendors

                 WHERE UPPER(vendor_name) = UPPER(cv.vendor_name);



                print_log ('Vendor found for vendor name ' || cv.vendor_name);



              EXCEPTION

                WHEN NO_DATA_FOUND THEN

                  v_vendor_id := NULL;

                  v_one_time_flag := NULL;

                  v_women_owned_flag := NULL;

                  v_small_business_flag := NULL;



                WHEN TOO_MANY_ROWS THEN

                  v_tbl_message := 'Vendor ' || cv.vendor_name || ' duplicated.';

                  RAISE e_vendor;



                WHEN OTHERS THEN

                  v_tbl_message := 'Vendor ' || cv.vendor_name || ' general error.';

                  RAISE e_vendor;



              END;



          END;



        END IF;



        -- 20230109

        v_terms_id := NULL;

        v_payment_method := NULL;

        v_pay_group := NULL;

        v_vendor_type_lookup_code := NULL;

        -- 20230109



        -- 20230109

        IF ( cv.payment_terms IS NOT NULL ) THEN

          -- 20230109

          v_terms_id := ajc_bc_create_entities_pkg.payment_terms_f ( cv.payment_terms, 'AP', gv_company_id, p_bc_environment );

          -- 20230109



          -- Se verifica si el payment terms está activo en Oracle

          SELECT DECODE(COUNT(1),0,'N','Y')

            INTO v_payment_term_active

            FROM ap_terms

           WHERE term_id = v_terms_id

             AND TRUNC(SYSDATE) BETWEEN TRUNC(start_date_active) AND TRUNC(NVL(end_date_active - 1,SYSDATE + 1));



          IF ( v_payment_term_active = 'N' ) THEN



            print_log ( 'Payment Term is inactive.' );

            v_tbl_message := 'Payment Term ' || cv.payment_terms || ' is inactive in Oracle.';

            RAISE e_vendor;



          END IF;



        ELSE



          v_tbl_message := 'Payment Terms Code cannot be null in BC.';

          RAISE e_vendor;



        END IF;

        -- 20230109



        -- 20230109

        IF ( cv.payment_method IS NOT NULL ) THEN

        -- 20230109

          v_payment_method := ajc_bc_create_entities_pkg.payment_method_f ( cv.payment_method );

        -- 20230109

        -- 20230711 ELSIF ( cv.payment_method IS NULL AND cv.pay_group != 'POTENCIAL SUPPLIER' ) THEN

        ELSIF ( cv.payment_method IS NULL AND cv.pay_group != 'POTENTIAL SUPPLIER' ) THEN



          v_tbl_message := 'Payment Method Code cannot be null in BC.';

          RAISE e_vendor;



        -- 20230711 ELSIF ( cv.payment_method IS NULL AND cv.pay_group = 'POTENCIAL SUPPLIER' ) THEN

        ELSIF ( cv.payment_method IS NULL AND cv.pay_group = 'POTENTIAL SUPPLIER' ) THEN



          v_payment_method := 'CHECK';



        END IF;

        -- 20230109



        -- print_log ( 'cv.pay_group: |' || cv.pay_group || '|' );



        -- 20230109

        -- 20230711 IF ( cv.pay_group IS NOT NULL AND cv.pay_group != 'POTENCIAL SUPPLIER' ) THEN

        IF ( cv.pay_group IS NOT NULL AND cv.pay_group != 'POTENTIAL SUPPLIER' ) THEN

        -- 20230109

          v_pay_group := ajc_bc_create_entities_pkg.pay_group_f ( cv.pay_group );



        -- 20230711 ELSIF ( cv.pay_group = 'POTENCIAL SUPPLIER' ) THEN

        ELSIF ( cv.pay_group = 'POTENTIAL SUPPLIER' ) THEN



          v_pay_group := cv.pay_group;



        -- 20230109

        END IF;

        -- 20230109



        -- print_log ( 'v_pay_group: |' || v_pay_group || '|' );

        -- print_log ( 'v_vendor_type_lookup_code: |' || v_vendor_type_lookup_code || '|' );



        -- 20230105

        IF ( v_pay_group = 'EMPLOYEE' ) THEN



          v_vendor_type_lookup_code := 'VENDOR';



        -- 20230109

        -- 20230711 ELSIF ( v_pay_group = 'POTENCIAL SUPPLIER' ) THEN

        ELSIF ( v_pay_group = 'POTENTIAL SUPPLIER' ) THEN



          v_vendor_type_lookup_code := 'SUPPLIER';

          v_pay_group := 'SUPPLIER';

        -- 20230109

        -- 20230614

        ELSIF ( v_pay_group IN ('SUPPLIER SAM','SUPPLIER EUR') ) THEN



          v_vendor_type_lookup_code := 'SUPPLIER';

        -- 20230614



        ELSIF ( v_pay_group = 'SUNVALLEY' ) THEN



          v_vendor_type_lookup_code := 'WAREHOUSE';



        -- 20230816 - Agregado

        ELSIF ( v_pay_group = 'SUNVALLEY SUPPLIER' ) THEN



          v_vendor_type_lookup_code := 'SUPPLIER';

        -- 20230816 - Agregado

        ELSE        



          v_vendor_type_lookup_code := v_pay_group;



        END IF;

        -- 20230105



        -- Se verifica si el valor a enviar en vendor_type_lookup_code existe en la lookup de Oracle

        -- 20230627

        -- BEGIN



        --  SELECT lookup_code

        --    INTO v_vendor_type_lookup_code

        --    FROM fnd_lookup_values 

        --   WHERE lookup_type = 'VENDOR TYPE'

        --     AND lookup_code = v_vendor_type_lookup_code

        --     AND enabled_flag = 'Y'

        --     AND SYSDATE BETWEEN start_date_active and NVL(end_date_active,SYSDATE + 1);



        -- EXCEPTION

        --   WHEN OTHERS THEN

        --     v_vendor_type_lookup_code := 'SUPPLIER';



        -- END;



        print_log ( 'v_pay_group: ' || v_pay_group );

        print_log ( 'v_vendor_type_lookup_code: ' || v_vendor_type_lookup_code );



        IF ( v_vendor_id IS NULL ) THEN



          print_log ( 'Vendor Num: ' || cv.segment1 );

          print_log ( 'El proveedor no existe. Se crea.' );



          print_log ( 'cv.vendor_name: ' || cv.vendor_name );

          print_log ( 'cv.vat_registration_num: ' || cv.vat_registration_num );

          print_log ( 'cv.segment1: ' || cv.segment1 );

          print_log ( 'v_vendor_id: ' || v_vendor_id );



          AP_PO_VENDORS_APIS_PKG.insert_new_vendor ( p_vendor_name => cv.vendor_name,

                                                     p_vendor_type_lookup_code => v_vendor_type_lookup_code, -- 20230105 v_pay_group,

                                                     p_taxpayer_id => NULL,

                                                     p_tax_registration_id => cv.vat_registration_num,

                                                     p_women_owned_flag => 'N',

                                                     p_small_business_flag => 'N',

                                                     p_minority_group_lookup_code => NULL, 

                                                     p_supplier_number => cv.segment1,

                                                     x_vendor_id => v_vendor_id,

                                                     x_status => v_status,

                                                     x_exception_msg => v_exception_msg,

                                                     p_employee_id => NULL,

                                                     p_source => 'NOT IMPORT',

                                                     p_what_to_import => NULL,

                                                     p_commit_size => 1000,

                                                     p_group_id => '-99' ); 



          IF ( v_status = 'S' ) THEN



            print_log ( 'Proveedor creado. v_vendor_id: ' || v_vendor_id );

            v_tbl_status_vendor := 'VENDOR CREATED';



            COMMIT;



            -- --------------------- --

            -- Se actualizan los dff --

            -- --------------------- --



            UPDATE po_vendors

               SET organization_type_lookup_code = cv.organization_type,

                   attribute1 = cv.atis_valid_vendor,

                   attribute2 = cv.sad,

                   attribute3 = cv.ajc_kingdee_translated_name,

                   attribute4 = cv.ajc_ap_revalidation_exclude,

                   segment1 = cv.segment1,

                   end_date_active = DECODE(cv.blocked,

                                            NULL,NULL,

                                            ' ',NULL,

                                            -- 20230720

                                            'Payment',NULL,

                                            'All',SYSDATE, -- Solo se inactiva el vendor cuando blocked es All                                          

                                            -- 20230720

                                            NULL),

                   invoice_currency_code = cv.payment_currency,

                   payment_currency_code = cv.payment_currency,

                   pay_group_lookup_code = v_pay_group,

                   terms_id = v_terms_id,

                   payment_method_lookup_code = v_payment_method,

                   last_update_date = SYSDATE

             WHERE vendor_id = v_vendor_id;



            -- 20230711 IF ( cv.pay_group = 'POTENCIAL SUPPLIER' ) THEN

            IF ( cv.pay_group = 'POTENTIAL SUPPLIER' ) THEN



              UPDATE po_vendors

                 SET one_time_flag = 'Y',

                     last_update_date = SYSDATE

               WHERE vendor_id = v_vendor_id;



            END IF;



            -- ---------------------------------------------------------------------- --

            -- Se actualiza el vendor_id en BC - Solo si se ejecuta en Oracle PROD    -- 

            -- o si se ejecuta en Oracle FINUPG5 apuntando a Sandbox | Production UAT -- 

            -- ---------------------------------------------------------------------- --



            send_oracle_vendor_id_to_bc_p ( p_bc_environment => p_bc_environment,

                                            p_system_id => cv.systemid,

                                            p_vendor_id => v_vendor_id );



          ELSE



            v_tbl_status_vendor := 'VENDOR CREATE ERROR';

            v_tbl_message := 'Failed to create vendor. ' || v_exception_msg;

            RAISE e_vendor;



          END IF;



        ELSE -- v_vendor_id IS NOT NULL



          print_log ( 'El proveedor existe. Se actualiza.' );



          AP_PO_VENDORS_APIS_PKG.update_vendor ( p_vendor_id => v_vendor_id,

                                                 p_taxpayer_id => NULL,

                                                 p_tax_registration_id => cv.vat_registration_num,

                                                 p_women_owned_flag => v_women_owned_flag,

                                                 p_small_business_flag => v_small_business_flag,

                                                 p_minority_group_lookup_code => NULL,

                                                 x_status => v_status,

                                                 x_exception_msg => v_exception_msg,

                                                 p_calling_source => NULL );



          IF ( v_status = 'S' ) THEN



            print_log ( 'Proveedor actualizado.' );

            v_tbl_status_vendor := 'VENDOR UPDATED';



            -- --------------------- --

            -- Se actualizan los dff --

            -- --------------------- --



            UPDATE po_vendors

               SET -- 20230508 -- Probar en Sandbox - FINUPG5

                   segment1 = cv.segment1,

                   -- 20230508

                   vendor_name = cv.vendor_name,

                   organization_type_lookup_code = cv.organization_type,

                   attribute1 = cv.atis_valid_vendor,

                   attribute2 = cv.sad,

                   attribute3 = cv.ajc_kingdee_translated_name,

                   attribute4 = cv.ajc_ap_revalidation_exclude,

                   end_date_active = DECODE(cv.blocked,

                                            NULL,NULL,

                                            ' ',NULL,

                                            -- 20230720

                                            'Payment',NULL,

                                            'All',SYSDATE, -- Solo se inactiva el vendor cuando blocked es All                                          

                                            -- 20230720

                                            NULL),

                   -- 20230328 invoice_currency_code = cv.payment_currency,

                   -- 20230328 payment_currency_code = cv.payment_currency,

                   pay_group_lookup_code = v_pay_group,

                   terms_id = v_terms_id,

                   payment_method_lookup_code = v_payment_method,

                   vendor_type_lookup_code = v_vendor_type_lookup_code, -- 20230105 v_pay_group

                   last_update_date = SYSDATE

             WHERE vendor_id = v_vendor_id;



            -- 20230109

            -- Si tiene el one time flag en Y y ya no es POTENCIAL SUPPLIER significa que era POTENCIAL SUPPLIER y dejo de serlo, por eso debe desmarcarse el flag 

            -- 20230711 IF ( cv.pay_group != 'POTENCIAL SUPPLIER' AND v_one_time_flag = 'Y' ) THEN

            IF ( cv.pay_group != 'POTENTIAL SUPPLIER' AND v_one_time_flag = 'Y' ) THEN



              UPDATE po_vendors

                 SET one_time_flag = 'N',

                     last_update_date = SYSDATE

               WHERE vendor_id = v_vendor_id;



            -- 20230711 ELSIF ( cv.pay_group = 'POTENCIAL SUPPLIER' AND v_one_time_flag = 'N' ) THEN  

            ELSIF ( cv.pay_group = 'POTENTIAL SUPPLIER' AND v_one_time_flag = 'N' ) THEN  



              UPDATE po_vendors

                 SET one_time_flag = 'Y',

                     last_update_date = SYSDATE

               WHERE vendor_id = v_vendor_id;



            END IF;

            -- 20230109



            -- ---------------------------------------------------------------------- --

            -- Se actualiza el vendor_id en BC - Solo si se ejecuta en Oracle PROD    -- 

            -- o si se ejecuta en Oracle FINUPG5 apuntando a Sandbox | Production UAT -- 

            -- ---------------------------------------------------------------------- --



            -- Si existe en Oracle y viene sin oracle vendor id es porque lo crearon a mano en BC, por lo tanto se actualiza 

            -- el vendor y se envia el vendor id

            IF ( cv.oraclevendorIDAJCGINE IS NULL ) THEN



              send_oracle_vendor_id_to_bc_p ( p_bc_environment => p_bc_environment,

                                              p_system_id => cv.systemid,

                                              p_vendor_id => v_vendor_id );



            END IF;



          ELSE



            v_tbl_status_vendor := 'VENDOR UPDATE ERROR';

            v_tbl_message := 'Failed to update vendor. ' || v_exception_msg;

            RAISE e_vendor;



          END IF;



        END IF; -- v_vendor_id IS NULL



        print_log ( 'Se procesa el site.' );



        -- ----- --

        -- Sites --

        -- ----- --

        print_log ( 'Address1: ' || cv.address_line1 );

        print_log ( 'Address2: ' || cv.address_line2 );

        print_log ( 'City: ' || cv.city );

        print_log ( 'Zip: ' || cv.zip );



        -- Si el Legacy Vendor Site Name es mayor a 15 caracteres, falla

        IF ( LENGTH(cv.vendor_site_code) > 15 ) THEN



          v_tbl_message := 'Legacy Vendor Site Name should have 15 characters or less.';

          v_tbl_status_site := 'SITE ERROR';

          RAISE e_vendor_site;



        END IF;



        -- Se verifica si el site existe en Oracle

        BEGIN



          print_log ( 'v_vendor_id: ' || v_vendor_id );

          print_log ( 'org_id: ' || cv.org_id );

          print_log ( 'vendor_site_code: ' || cv.vendor_site_code );



          SELECT vendor_site_id

                 -- 20230327

                 ,state

                 -- 20230327

                 ,address_line3

                 ,address_line4

                 ,province

                 ,county

                 ,area_code

                 ,phone

                 ,fax_area_code

                 ,fax

                 ,email_address

                 ,purchasing_site_flag

                 ,pay_site_flag

                 ,rfq_only_site_flag

            INTO v_vendor_site_id  

                 -- 20230327

                 ,v_state

                 -- 20230327

                 ,v_address_line_3

                 ,v_address_line_4

                 ,v_province

                 ,v_county

                 ,v_area_code

                 ,v_phone

                 ,v_fax_area_code

                 ,v_fax

                 ,v_email_address

                 ,v_purchasing_site_flag

                 ,v_pay_site_flag

                 ,v_rfq_only_site_flag

            FROM po_vendor_sites_all

           WHERE vendor_id = v_vendor_id

             AND org_id = cv.org_id

             AND UPPER(vendor_site_code) = UPPER(cv.vendor_site_code);



          print_log ( 'Existe el site en Oracle.' );



        EXCEPTION

          WHEN OTHERS THEN

            print_log ( 'No existe el site en Oracle.' );

            v_vendor_site_id := NULL;

            v_address_line_3 := NULL;

            v_address_line_4 := NULL;

            v_province := NULL;

            v_county := NULL;

            v_area_code := NULL;

            v_phone := NULL;

            v_fax_area_code := NULL;

            v_fax := NULL;

            v_email_address := NULL;

            v_purchasing_site_flag := NULL;

            v_pay_site_flag := NULL;

            v_rfq_only_site_flag := NULL;



        END;



        -- Se mapea el country

        -- 20230329

        -- BEGIN



        -- SELECT meaning

        --   INTO v_country

        --   FROM fnd_lookup_values

        --  WHERE lookup_type = 'AJC_BC_COUNTRY_CODES'

        --    AND lookup_code = cv.country;



        --   print_log ( 'BC Country: ' || cv.country );

        --   print_log ( 'Oracle Country: ' || v_country );



        -- EXCEPTION

        --   WHEN NO_DATA_FOUND THEN

        --     print_log ( 'BC Country Code ' || cv.country || ' not found in Oracle.' );

        --     v_country := NULL;



        -- END;



        BEGIN



          SELECT territory_code,

                 territory_short_name

            INTO v_country,

                 v_territory_short_name

            FROM fnd_territories_vl

           WHERE iso_territory_code = cv.country;



          print_log ( 'BC Country: ' || cv.country );

          print_log ( 'Oracle Country: ' || v_country );

          print_log ( 'Oracle Territory Short Name: ' || v_territory_short_name );



          -- 20230329 - Ver si es necesario esto, porque se habia agregado en el caso del iso ANT (AN) que en Oracle está obsoleto

          -- Si Vicky confirma que en BC no debe existir el código ANT, no sería necesario este código

          -- IF ( UPPER(v_territory_short_name) LIKE '%OBSOLETE SEE%TERRITORY%' ) THEN



          --  v_country := SUBSTR(REPLACE(v_territory_short_name,'Obsolete see '),1,INSTR(REPLACE(v_territory_short_name,'Obsolete see '),' ') - 1);



          --END IF;



          print_log ( 'BC Country: ' || cv.country );

          print_log ( 'Oracle Country: ' || v_country );



        EXCEPTION

          WHEN NO_DATA_FOUND THEN

            print_log ( 'BC Country Code ' || cv.country || ' not found in Oracle.' );

            v_country := NULL;

            v_territory_short_name := NULL;



        END;

        -- 20230329



        -- 20230720

        SELECT DECODE(cv.blocked,'Payment','Y','N')

          INTO v_hold_all_payments_flag

          FROM dual;

        -- 20230720



        IF ( v_vendor_site_id IS NULL ) THEN



          print_log ( 'El site no existe. Se crea.' );



          AP_PO_VENDORS_APIS_PKG.insert_new_vendor_site( p_vendor_site_code => cv.vendor_site_code,

                                                         p_vendor_id => v_vendor_id,

                                                         p_org_id => cv.org_id,

                                                         p_address_line1 => cv.address_line1,

                                                         p_address_line2 => cv.address_line2,

                                                         p_address_line3 => NULL,

                                                         p_address_line4 => NULL,

                                                         p_city => cv.city,

                                                         p_state => NULL,

                                                         p_zip => cv.zip,

                                                         p_province => NULL,

                                                         p_county => NULL,

                                                         p_country => v_country,

                                                         p_area_code => NULL,

                                                         p_phone => NULL,

                                                         p_fax_area_code => NULL,

                                                         p_fax => NULL,

                                                         p_email_address => NULL, 

                                                         p_purchasing_site_flag => 'Y',

                                                         p_pay_site_flag => 'Y',

                                                         p_rfq_only_site_flag => 'N',

                                                         x_vendor_site_id => v_vendor_site_id,

                                                         x_status => v_status,

                                                         x_exception_msg => v_exception_msg,

                                                         p_source => 'NOT IMPORT',

                                                         p_what_to_import => NULL,

                                                         p_commit_size => 1000,

                                                         p_hold_unvalidated_inv_flag => NULL,

                                                         -- 20230720 p_hold_all_payments_flag => NULL,

                                                         p_hold_all_payments_flag => v_hold_all_payments_flag,

                                                         -- 20230720

                                                         p_duns_number => NULL,

                                                         p_group_id => '-99' );



          IF ( v_status = 'S' ) THEN



            print_log ( 'Site creado. v_vendor_site_id: ' || v_vendor_site_id );

            v_tbl_status_site := 'SITE CREATED';



            -- --------------------- --

            -- Se actualizan los dff --

            -- --------------------- --

            UPDATE po_vendor_sites_all

               SET invoice_currency_code = cv.payment_currency,

                   payment_currency_code = cv.payment_currency,

                   pay_group_lookup_code = v_pay_group,

                   terms_id = v_terms_id,

                   payment_method_lookup_code = v_payment_method,

                   remittance_email = cv.email_address,

                   attribute1 = cv.ajc_country_code,

                   -- attribute4 = cv.ajc_parent_site_credit_limit,

                   attribute5 = cv.ajc_credit_limit_amount,

                   attribute6 = cv.ajc_prepay_credit_limit_amount,

                   last_update_date = SYSDATE

                   -- 20250520 - Active / Inactive Site

                  ,inactive_date = DECODE(cv.blocked,

                                          NULL,NULL,

                                          ' ',NULL,

                                          'Payment',NULL,

                                          'All',SYSDATE, 

                                          NULL)

                   -- 20250520 - Active / Inactive Site

             WHERE vendor_site_id = v_vendor_site_id;



          ELSE



            v_tbl_status_site := 'SITE CREATE ERROR';

            v_tbl_message := 'Failed to create vendor site. ' || v_exception_msg;

            RAISE e_vendor_site;



          END IF;



        ELSE -- v_vendor_site_id IS NOT NULL



          print_log ( 'El site existe. Se actualiza.' );



          AP_PO_VENDORS_APIS_PKG.update_vendor_site( p_vendor_site_code => cv.vendor_site_code,

                                                     p_vendor_site_id => v_vendor_site_id,

                                                     p_address_line1 => cv.address_line1,

                                                     p_address_line2 => cv.address_line2,

                                                     p_address_line3 => v_address_line_3, -- Se pone el que tiene Oracle, ver si inecta lo va a mandar

                                                     p_address_line4 => v_address_line_4, -- Se pone el que tiene Oracle, ver si inecta lo va a mandar

                                                     p_city => cv.city,

                                                     p_state => v_state, -- Se deja el state que tiene en Oracle

                                                     p_zip => cv.zip,

                                                     p_province => v_province,

                                                     p_county => v_county,

                                                     p_country => v_country,

                                                     p_area_code => v_area_code,

                                                     p_phone => v_phone,

                                                     p_fax_area_code => v_fax_area_code,

                                                     p_fax => v_fax,

                                                     p_email_address => v_email_address, 

                                                     p_purchasing_site_flag => v_purchasing_site_flag,

                                                     p_pay_site_flag => v_pay_site_flag,

                                                     p_rfq_only_site_flag => v_rfq_only_site_flag,

                                                     x_status => v_status,

                                                     x_exception_msg => v_exception_msg,

                                                     p_hold_unvalidated_inv_flag => NULL,

                                                     -- 20230720 p_hold_all_payments_flag => NULL,

                                                     p_hold_all_payments_flag => v_hold_all_payments_flag,

                                                     -- 20230720

                                                     p_duns_number => NULL,

                                                     p_calling_source => NULL );



          IF ( v_status = 'S' ) THEN



            print_log ( 'Site actualizado.' );

            v_tbl_status_site := 'SITE UPDATED';



            -- --------------------- --

            -- Se actualizan los dff --

            -- --------------------- --

            UPDATE po_vendor_sites_all

               SET invoice_currency_code = cv.payment_currency,

                   payment_currency_code = cv.payment_currency,

                   pay_group_lookup_code = v_pay_group,

                   terms_id = v_terms_id,

                   payment_method_lookup_code = v_payment_method,

                   remittance_email = cv.email_address, -- Se habia comentado el 20230327, se descomenta el 20230621

                   attribute1 = cv.ajc_country_code,

                   -- attribute4 = cv.ajc_parent_site_credit_limit,

                   attribute5 = cv.ajc_credit_limit_amount,

                   attribute6 = cv.ajc_prepay_credit_limit_amount,

                   last_update_date = SYSDATE

                   -- 20250520 - Active / Inactive Site

                  ,inactive_date = DECODE(cv.blocked,

                                          NULL,NULL,

                                          ' ',NULL,

                                          'Payment',NULL,

                                          'All',SYSDATE, 

                                          NULL)

                   -- 20250520 - Active / Inactive Site

             WHERE vendor_site_id = v_vendor_site_id;



          ELSE



            v_tbl_status_site := 'SITE UPDATE ERROR';

            v_tbl_message := 'Failed to update vendor site. ' || v_exception_msg;

            RAISE e_vendor_site;



          END IF;



        END IF; -- IF ( v_vendor_site_id IS NULL ) THEN



        -- 20250129

        BEGIN



          print_log ('Executing oms.adm_vendor_pkg.sync_companies.' );

          oms.adm_vendor_pkg.sync_companies ( p_vendor_id => v_vendor_id );



        EXCEPTION

          WHEN OTHERS THEN

            print_log ('Error calling oms.adm_vendor_pkg.sync_companies. ' || SQLERRM);



        END;

        -- 20250129



        -- Se actualiza el registro en la tabla custom

        UPDATE ajc_bc_vendors

           SET status = NVL(v_tbl_status_site,v_tbl_status_vendor),

               processed_date = TRUNC(SYSDATE),

               request_id = gv_request_id,

               vendor_id = v_vendor_id,

               vendor_site_id = v_vendor_site_id,

               terms_id = v_terms_id

         WHERE systemid = cv.systemid

           AND segment1 = cv.segment1

           AND status IS NULL

           AND request_id IS NULL

           AND message IS NULL

           AND processed_date IS NULL;



        COMMIT;



      EXCEPTION

        WHEN e_vendor THEN

          print_log ( v_tbl_status_vendor );



          ROLLBACK;



          UPDATE ajc_bc_vendors

             SET status = v_tbl_status_vendor,

                 message = v_tbl_message,

                 processed_date = TRUNC(SYSDATE),

                 request_id = gv_request_id,

                 vendor_id = v_vendor_id

           WHERE systemid = cv.systemid

             AND segment1 = cv.segment1

             AND status IS NULL

             AND request_id IS NULL

             AND message IS NULL

             AND processed_date IS NULL;



          COMMIT;



        WHEN e_vendor_site THEN



          print_log ( v_tbl_status_site );



          ROLLBACK;



          UPDATE ajc_bc_vendors

             SET status = v_tbl_status_site,

                 message = v_tbl_message,

                 processed_date = TRUNC(SYSDATE),

                 request_id = gv_request_id,

                 vendor_id = v_vendor_id

           WHERE systemid = cv.systemid

             AND segment1 = cv.segment1

             AND status IS NULL

             AND request_id IS NULL

             AND message IS NULL

             AND processed_date IS NULL;



          IF ( v_tbl_status_vendor = 'VENDOR CREATED' ) THEN   



            DELETE po_vendors

             WHERE vendor_id = v_vendor_id;



          END IF;



          COMMIT;



        WHEN OTHERS THEN



          print_log ( 'Error general. ' || v_exception_msg );

          print_log ( 'Error: ' || SQLERRM );



          ROLLBACK;



          UPDATE ajc_bc_vendors

             SET status = 'ERROR',

                 message = 'Error general. ' || v_tbl_message,

                 processed_date = TRUNC(SYSDATE),

                 request_id = gv_request_id,

                 vendor_id = v_vendor_id

           WHERE systemid = cv.systemid

             AND segment1 = cv.segment1

             AND status IS NULL

             AND request_id IS NULL

             AND message IS NULL

             AND processed_date IS NULL;



          IF ( v_tbl_status_vendor = 'VENDOR CREATED' ) THEN   



            DELETE po_vendors

             WHERE vendor_id = v_vendor_id;



          END IF;



          COMMIT;



      END;



    END LOOP;



    print_log ( 'ajc_bc_vendors_to_oracle_pkg.vendors_p (-)' );



  EXCEPTION

    WHEN e_org THEN

      print_log ( 'ajc_bc_vendors_to_oracle_pkg.vendors_p (!)' );

      print_log ( 'El request solo puede ser ejecutado desde una responsabilidad de AJC OU.' );

    WHEN e_default_country THEN

      print_log ( 'ajc_bc_vendors_to_oracle_pkg.vendors_p (!)' );

      print_log ( 'Debe setear valor para la profile Default Country (DEFAULT_COUNTRY) a nivel Site.' );

    WHEN OTHERS THEN

      print_log ( 'ajc_bc_vendors_to_oracle_pkg.vendors_p (!)' );

      print_log ( 'Error: ' || SQLERRM );



  END vendors_p;



  /*=========================================================================+

  |                                                                          |

  | Private Procedure                                                        |

  |    vendor_site_contacts_p                                                |

  |                                                                          |

  | Description                                                              |

  |    Creacion Vendor Site Contacts                                         |

  |                                                                          |

  | Parameters                                                               |

  |                                                                          |

  +=========================================================================*/

  PROCEDURE vendor_site_contacts_p ( retcode           OUT   NUMBER

                                    ,errbuf            OUT   VARCHAR2

                                    ,p_bc_environment   IN   VARCHAR2 ) IS



    CURSOR c_vendor_site_contacts IS

    SELECT company,

           vendor_name,

           vendor_site_code,

           first,

           last,

           phone,

           email,

           url,

           org_id

      FROM ajc_bc_vendor_site_contacts

     WHERE status IS NULL

       AND request_id IS NULL

       AND processed_date IS NULL;



    v_get_api                 VARCHAR2(100) := 'VendorContact'; -- Pedir a Inecta que creen una



    v_vendor_id               NUMBER;

    v_vendor_name             VARCHAR2(240);

    v_vendor_site_code        VARCHAR2(15);

    v_first                   VARCHAR2(15);

    v_last                    VARCHAR2(20);



    v_vendor_site_id          NUMBER;

    v_vendor_contact_id       NUMBER;



    v_url                     VARCHAR2(2000);

    v_date_today              VARCHAR2(100);

    v_date_yesterday          VARCHAR2(100);



    v_status                  VARCHAR2(200);

    v_exception_msg           VARCHAR2(3000);



    e_contact                 EXCEPTION;



    v_tbl_status              VARCHAR2(10);

    v_tbl_message             VARCHAR2(1000);



    v_clob_result             CLOB;

    v_clob                    CLOB;



  BEGIN



    print_log ( 'ajc_bc_vendors_to_oracle_pkg.vendor_site_contacts_p (+)' );     



    v_date_today := TO_CHAR(SYSDATE,'YYYY-MM-DD') || 'T00:00:00.000Z';

    v_date_yesterday := TO_CHAR(SYSDATE - 1,'YYYY-MM-DD') || 'T00:00:00.000Z';



    v_url := ajc_bc_ws_utils_pkg.get_base_ajc_url_f ( p_bc_environment, gv_company_name ) || v_get_api

             -- || '?$filter=systemmodifiedat ge ' || v_date_yesterday || ' and Last_Date_Modified lt ' || v_date_today

             ;



    v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



    print_log ( 'Se obtienen los contactos creados o modificados y se insertan en la tabla ajc_bc_vendor_site_contacts.' );



    INSERT 

      INTO ajc_bc_vendor_site_contacts 

           ( company,

             org_id,

             vendor_name,

             vendor_site_code,

             first,

             last,

             phone,

             email,

             url,

             creation_date )

      SELECT Company,

             gv_org_id,

             Name vendor_name,

             'BC' vendor_site_code,

             First,

             Last,

             Phone,

             Email,

             Url,

             TRUNC(SYSDATE) creation_date

        FROM json_table( v_clob_result,

                        '$.value[*]' COLUMNS ( Company   VARCHAR2(4000)  path '$.No',

                                               Name      VARCHAR2(4000)  path '$.Name',

                                               First     VARCHAR2(4000)  path '$.First',

                                               Last      VARCHAR2(4000)  path '$.Last', 

                                               Phone     VARCHAR2(4000)  path '$.Phone',

                                               Email     VARCHAR2(4000)  path '$.Email',

                                               Url       VARCHAR2(4000)  path '$.Url' ) );



    COMMIT;



    -- print_output ( 'AJC BC Vendor Site Contacts to Oracle' );



    FOR cvsc IN c_vendor_site_contacts LOOP



      BEGIN



        -- print_output ( ' ' );

        -- print_output ( 'Vendor Name: ' || cvsc.vendor_name );

        -- print_output ( 'Vendor Site Code: ' || cvsc.vendor_site_code );

        -- print_output ( 'Contact First Name: ' || cvsc.first );

        -- print_output ( 'Contact Last Name: ' || cvsc.last );



        v_vendor_name := cvsc.vendor_name;

        v_vendor_site_code := cvsc.vendor_site_code;

        v_first := cvsc.first;

        v_last := cvsc.last;



        -- Se verifica si existe el proveedor

        BEGIN



          SELECT vendor_id                                

            INTO v_vendor_id  

            FROM po_vendors

           WHERE UPPER(vendor_name) = UPPER(cvsc.vendor_name);



        EXCEPTION

          WHEN OTHERS THEN

              v_vendor_id := NULL;



        END;



        IF ( v_vendor_id IS NULL ) THEN



          -- print_output ( 'El proveedor no existe. No puede crearse el contacto.' ); 

          v_tbl_status := 'ERROR';

          v_tbl_message := 'Vendor doesnt exist. Could not create contact.';

          RAISE e_contact;



        ELSE



          -- Se verifica si existe el site        

          BEGIN



            SELECT vendor_site_id                                

              INTO v_vendor_site_id  

              FROM po_vendor_sites_all

             WHERE vendor_id = v_vendor_id

               AND org_id = cvsc.org_id

               AND UPPER(vendor_site_code) = UPPER(cvsc.vendor_site_code);



          EXCEPTION

            WHEN OTHERS THEN

              v_vendor_site_id := NULL;



          END;



          IF ( v_vendor_site_id IS NULL ) THEN



            -- print_output ( 'La sucursal no existe. No puede crearse el contacto.' ); 

            v_tbl_status := 'ERROR';

            v_tbl_message := 'Site doesnt exist. Could not create contact.';

            RAISE e_contact;



          ELSE -- v_vendor_site_id IS NOT NULL 



            -- Se verifica si ya existe el contacto para el site

            BEGIN



              SELECT vendor_contact_id

                INTO v_vendor_contact_id

                FROM po_vendor_contacts

               WHERE vendor_site_id = v_vendor_site_id

                 AND first_name = cvsc.first

                 AND last_name = cvsc.last;



            EXCEPTION

              WHEN OTHERS THEN

                v_vendor_contact_id := NULL;



            END;



            IF ( v_vendor_contact_id IS NULL ) THEN



              AP_PO_VENDORS_APIS_PKG.insert_new_vendor_contact ( p_vendor_site_id => v_vendor_site_id,

                                                                 p_first_name => cvsc.first,

                                                                 p_last_name => cvsc.last,

                                                                 p_middle_name => NULL,

                                                                 p_prefix => NULL,

                                                                 p_title => NULL,

                                                                 p_mail_stop => NULL,

                                                                 p_area_code => NULL,

                                                                 p_phone => cvsc.phone,

                                                                 p_alt_area_code => NULL,

                                                                 p_alt_phone => NULL,

                                                                 p_fax_area_code => NULL,

                                                                 p_fax => NULL,

                                                                 p_email_address => cvsc.email,

                                                                 p_url => cvsc.url,

                                                                 x_vendor_contact_id => v_vendor_contact_id,

                                                                 x_status => v_status,

                                                                 x_exception_msg => v_exception_msg,

                                                                 p_source => 'NOT IMPORT',

                                                                 p_what_to_import => NULL,

                                                                 p_commit_size => 1000 );



              IF ( v_status = 'S' ) THEN



                print_log ( 'Se crea el contacto. v_vendor_contact_id: ' || v_vendor_contact_id );

                v_tbl_status := 'CREATED';



              ELSE



                -- print_output ( 'El contacto no pudo ser creado. ' || v_exception_msg ); 

                v_tbl_status := 'ERROR';

                v_tbl_message := 'Failed to create contact. ' || v_exception_msg;

                RAISE e_contact;



              END IF;



            ELSE -- v_vendor_contact_id IS NOT NULL 



              AP_PO_VENDORS_APIS_PKG.update_vendor_contact ( p_vendor_contact_id => v_vendor_contact_id,

                                                             p_first_name => cvsc.first,

                                                             p_last_name => cvsc.first,

                                                             p_middle_name => NULL,

                                                             p_prefix => NULL,

                                                             p_title => NULL,

                                                             p_mail_stop => NULL,

                                                             p_area_code => NULL,

                                                             p_phone => cvsc.phone,

                                                             p_alt_area_code => NULL,

                                                             p_alt_phone => NULL,

                                                             p_fax_area_code => NULL,

                                                             p_fax => NULL,

                                                             p_email_address => cvsc.email,

                                                             p_url => cvsc.url,

                                                             x_status => v_status,

                                                             x_exception_msg => v_exception_msg );



              IF ( v_status = 'S' ) THEN



                -- print_output ( 'Se actualiza el contacto.' );

                v_tbl_status := 'UPDATED';



              ELSE



                -- print_output ( 'El contacto no pudo ser actualizado. ' || v_exception_msg ); 

                v_tbl_status := 'ERROR';

                v_tbl_message := 'Failed to update contact. ' || v_exception_msg;

                RAISE e_contact;



              END IF;



            END IF; -- v_vendor_contact_id



          END IF; -- v_vendor_site_id



          -- Se actualiza el registro en la tabla custom

          UPDATE ajc_bc_vendor_site_contacts

             SET status = v_tbl_status,

                 processed_date = TRUNC(SYSDATE),

                 request_id = gv_request_id,

                 vendor_id = v_vendor_id,

                 vendor_site_id = v_vendor_site_id,

                 contact_id = v_vendor_contact_id

           WHERE vendor_name = cvsc.vendor_name

             AND vendor_site_code = v_vendor_site_code

             AND first = v_first

             AND last = v_last

             AND status IS NULL

             AND request_id IS NULL

             AND message IS NULL

             AND processed_date IS NULL;



        END IF; -- v_vendor_id



      EXCEPTION

        WHEN e_contact THEN



          -- print_output ( v_tbl_message );



          UPDATE ajc_bc_vendor_site_contacts

             SET status = v_tbl_status,

                 message = v_tbl_message,

                 processed_date = TRUNC(SYSDATE),

                 request_id = gv_request_id

           WHERE vendor_name = v_vendor_name

             AND vendor_site_code = v_vendor_site_code

             AND first = v_first

             AND last = v_last

             AND status IS NULL

             AND request_id IS NULL

             AND message IS NULL

             AND processed_date IS NULL;



      END;



    END LOOP;



    COMMIT;



    print_log ( 'ajc_bc_vendors_to_oracle_pkg.vendor_site_contacts_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      print_log ( 'ajc_bc_vendors_to_oracle_pkg.vendor_site_contacts_p (!)' );

      -- print_output ( 'Error general.' || SQLERRM );



  END vendor_site_contacts_p;



  PROCEDURE create_account_p ( p_bank_name                    IN    ap_bank_branches.bank_name%TYPE,

                               p_bank_branch_name             IN    ap_bank_branches.bank_branch_name%TYPE,

                               p_bank_num                     IN    ap_bank_branches.bank_num%TYPE,

                               p_bank_account_num             IN    ap_bank_accounts_all.bank_account_num%TYPE,

                               p_bank_account_name            IN    ap_bank_accounts_all.bank_account_name%TYPE,

                               p_currency_code                IN    ap_bank_accounts_all.currency_code%TYPE,

                               p_external_bank_account_id    OUT    ap_bank_accounts_all.bank_account_id%TYPE,

                               p_error_message               OUT    VARCHAR2 ) IS



    v_bank_branch_id    ap_bank_branches.bank_branch_id%TYPE;

    v_bank_account_id   ap_bank_accounts_all.bank_account_id%TYPE;



  BEGIN



    print_log ( 'ajc_bc_vendors_to_oracle_pkg.create_account_p (+)' );



    p_error_message := NULL;

    v_bank_branch_id := NULL;

    v_bank_account_id := NULL;



    print_log ( 'Se verifica si existe el banco / sucursal' ); 



    BEGIN



      SELECT bank_branch_id

        INTO v_bank_branch_id

        FROM ap_bank_branches

       WHERE bank_num = p_bank_num;



      print_log ( 'El banco / sucursal existe. No se crea. v_bank_branch_id: ' || v_bank_branch_id );



    EXCEPTION

      WHEN NO_DATA_FOUND THEN

        v_bank_branch_id := NULL;

        print_log ( 'El banco / sucursal no existe. Se crea.' );



    END;



    IF ( v_bank_branch_id IS NULL ) THEN



      -- Se obtiene el bank branch id

      SELECT AP_BANK_BRANCHES_S.NEXTVAL

        INTO v_bank_branch_id

        FROM DUAL;



      -- Se crea banco y sucursal        

      INSERT 

        INTO ap_bank_branches

             ( bank_branch_id,

               bank_name,

               bank_branch_name,

               bank_branch_type, -- 'ABA'

               bank_num, -- transitNo

               institution_type, -- 'BANK'

               creation_date,

               created_by,

               last_update_login,

               last_update_date,

               last_updated_by )

      VALUES ( v_bank_branch_id,

               p_bank_name,

               p_bank_branch_name,

               'ABA', -- bank_branch_type

               p_bank_num, -- transit no

               'BANK', -- institution_type

               SYSDATE,

               gv_user_id,

               gv_user_id,

               SYSDATE,

               gv_user_id );



      print_log ( 'Banco / sucursal creado. v_bank_branch_id: ' || v_bank_branch_id );



    END IF;



    SELECT AP_BANK_ACCOUNTS_S.NEXTVAL

      INTO v_bank_account_id

      FROM dual;



    INSERT 

      INTO ap_bank_accounts_all

           ( bank_account_id,

             bank_account_name,

             bank_account_num,

             bank_branch_id,

             set_of_books_id,

             currency_code,

             account_type,

             multi_currency_flag,

             pooled_flag,

             zero_amounts_allowed,

             receipt_multi_currency_flag,

             org_id,

             allow_multi_assignments_flag,

             creation_date,

             created_by,

             last_update_login,

             last_update_date,

             last_updated_by )

    VALUES ( v_bank_account_id,

             p_bank_account_name,

             p_bank_account_num,

             v_bank_branch_id,

             gv_set_of_books_id,

             p_currency_code,

             'SUPPLIER', -- account_type

             'Y', -- multi_currency_flag

             'N', -- pooled_flag,

             'N', -- zero_amounts_allowed,

             'Y', -- receipt_multi_currency_flag,

             gv_org_id,

             'N', -- allow_multi_assignments_flag,

             SYSDATE,

             gv_user_id,

             gv_user_id,

             SYSDATE,

             gv_user_id );



    p_external_bank_account_id := v_bank_account_id;



    print_log ( 'Cuenta creada. v_bank_account_id: ' || v_bank_account_id );   



    COMMIT;



    print_log ( 'ajc_bc_vendors_to_oracle_pkg.create_account_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_error_message := 'Error al intentar crear el banco / sucursal / cuenta. ' || SQLERRM;

      print_log ( 'ajc_bc_vendors_to_oracle_pkg.create_account_p (!)' );



  END create_account_p;



  PROCEDURE vendor_sites_p ( p_bc_environment           IN       VARCHAR2,

                             p_last_bc_processed_date   IN       TIMESTAMP,

                             p_count                    IN OUT   NUMBER ) IS



    CURSOR c_vendor_sites IS

    SELECT *

      FROM ajc_bc_vendor_sites

     WHERE status IS NULL

       AND request_id IS NULL

       AND processed_date IS NULL;  



    v_get_url                    VARCHAR2(2000);

    v_get_api                    VARCHAR2(100);



    v_clob_result                CLOB;



    v_vendor_id                  ajc_bc_vendors.vendor_id%TYPE;

    v_vendor_name                ajc_bc_vendors.vendor_name%TYPE;

    v_vendor_site_id             ajc_bc_vendors.vendor_site_id%TYPE;



    v_country                    VARCHAR2(80);

    v_territory_short_name       fnd_territories_vl.territory_short_name%TYPE;



    v_tbl_status_vendor_site     VARCHAR2(2000);

    v_error_message              VARCHAR2(200);



    v_status                     VARCHAR2(200);

    v_exception_msg              VARCHAR2(3000);

    v_tbl_status_site            VARCHAR2(30);

    v_tbl_message                VARCHAR2(1000);



    e_exception                  EXCEPTION;

    e_vendor_site                EXCEPTION;



    -- 20240219

    v_vendor_site_code_alt       po_vendor_sites_all.vendor_site_code_alt%TYPE;

    -- 20240219



  BEGIN



    print_log ( ' ' );

    print_log ( 'ajc_bc_vendors_to_oracle_pkg.vendor_sites_p (+)' );



    v_get_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'VENDORS',

                                                 p_subentity => 'SITES',

                                                 p_method => 'GET' );

    print_log ( 'v_get_api: ' || v_get_api );                                                 



    v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, gv_company_id ) || v_get_api

                 || '?$filter=systemModifiedAt gt ' || TO_CHAR(p_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z')

                 -- se reemplazo por la lookup || ' and systemModifiedBy ne 79ee8266-81b2-4694-9b2d-363f6dc49ca2'

                 -- || '?$filter=vendorno eq ' || '''447797'''

                 ;



    print_log ( 'v_get_url: ' || v_get_url );



    v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );



    print_log ( 'Se obtienen las remit address de los proveedores creados o modificados en la ejecucion actual y se insertan en la tabla ajc_bc_vendor_sites.' );



    INSERT 

      INTO ajc_bc_vendor_sites

           ( systemid,

             vendorNo,

             legacyVendorSiteName,

             code,

             name,

             address,

             address2,

             zipCode,

             city,

             state,

             countryRegionCode,

             contact,

             phoneNo,

             -- faxNo,

             eMail,

             homePage,

             systemModifiedBy,

             --

             creation_date )

      SELECT systemId,

             vendorNo,

             legacyVendSiteName, 

             vendorCode,

             name,

             address,

             address2,

             postCode,

             City,

             state,

             countryRegionCode,

             contact,

             phoneNo,

             -- faxNo,

             email,

             homePage,

             systemModifiedBy,

             TRUNC(SYSDATE) creation_date

      FROM json_table( v_clob_result,

                       '$.value[*]' COLUMNS ( systemId                   VARCHAR2(4000)  path '$.systemId',

                                              vendorNo                   VARCHAR2(4000)  path '$.vendorNo',

                                              legacyVendSiteName         VARCHAR2(4000)  path '$.legacyVendSiteName',

                                              vendorCode                 VARCHAR2(4000)  path '$.vendorCode',

                                              name                       VARCHAR2(4000)  path '$.name',

                                              address                    VARCHAR2(4000)  path '$.address',

                                              address2                   VARCHAR2(4000)  path '$.address2',

                                              postCode                   VARCHAR2(4000)  path '$.postCode',

                                              City                       VARCHAR2(4000)  path '$.City',

                                              state                      VARCHAR2(4000)  path '$.state',

                                              countryRegionCode          VARCHAR2(4000)  path '$.countryRegionCode',

                                              contact                    VARCHAR2(4000)  path '$.contact',

                                              phoneNo                    VARCHAR2(4000)  path '$.phoneNo',

                                              -- faxNo                      VARCHAR2(4000)  path '$.faxNo',

                                              email                      VARCHAR2(4000)  path '$.email',

                                              homePage                   VARCHAR2(4000)  path '$.homePage',

                                              systemModifiedBy           VARCHAR2(4000)  path '$.systemModifiedBy' ) );



    -- Se actualizan como SKIPPED aquellos que fueron modificados por usuarios que no existe en la lookup

    UPDATE ajc_bc_vendor_sites

       SET status = 'SKIPPED',

           processed_date = TRUNC(SYSDATE),

           request_id = gv_request_id

     WHERE status IS NULL

       AND request_id IS NULL

       AND processed_date IS NULL

       AND systemModifiedBy NOT IN ( SELECT description

                                       FROM fnd_lookup_values

                                      WHERE lookup_type = 'AJC_BC_VENDORS_IFC_USERS'

                                        AND enabled_flag = 'Y'

                                        AND SYSDATE BETWEEN start_date_active AND NVL(end_date_active,SYSDATE + 1) );



    p_count := SQL%ROWCOUNT;



    COMMIT;



    FOR cvs IN c_vendor_sites LOOP



      v_error_message := NULL;



      print_log ( ' ' );

      print_log ( 'Vendor No: ' || cvs.vendorNo );

      print_log ( 'Legacy Vendor Site Name: ' || cvs.legacyVendorSiteName );

      print_log ( 'Address1: ' || cvs.address );

      print_log ( 'Address2: ' || cvs.address2 );

      print_log ( 'City: ' || cvs.city );

      print_log ( 'Zip: ' || cvs.zipCode );



      BEGIN



        p_count := p_count + 1;



        v_vendor_id := NULL;

        v_vendor_name := NULL;

        v_vendor_site_id := NULL;



        -- 20240219

        v_vendor_site_code_alt := NULL;

        -- 20240219



        -- Se obtienen los datos del vendor

        BEGIN



          SELECT v.vendor_id,

                 v.vendor_name

            INTO v_vendor_id,

                 v_vendor_name

            FROM po_vendors v

           WHERE v.segment1 = cvs.vendorNo;



          print_log ( 'Se encuentra vendor por segment1.' );

          print_log ( 'v_vendor_id: ' || v_vendor_id );

          print_log ( 'v_vendor_name: ' || v_vendor_name );



        EXCEPTION

          WHEN OTHERS THEN

            v_tbl_message := 'Vendor not found.';

            v_tbl_status_site := 'SITE ERROR';

            RAISE e_vendor_site;



        END;



        -- Si viene sin Legacy Vendor Site Name de BC, falla

        IF ( cvs.legacyVendorSiteName IS NULL OR cvs.legacyVendorSiteName = ' ' ) THEN



          v_tbl_message := 'Legacy Vendor Site Name could not be null in BC.';

          v_tbl_status_site := 'SITE ERROR';

          RAISE e_vendor_site;



        END IF;



        -- Si el Legacy Vendor Site Name es mayor a 15 caracteres, falla

        IF ( LENGTH(cvs.legacyVendorSiteName) > 15 ) THEN



          v_tbl_message := 'Legacy Vendor Site Name should have 15 characters or less.';

          v_tbl_status_site := 'SITE ERROR';

          RAISE e_vendor_site;



        END IF;



        -- Se verifica si el site existe en Oracle

        BEGIN



          print_log ( 'vendor_site_code: ' || cvs.legacyVendorSiteName );



          SELECT vendor_site_id

            INTO v_vendor_site_id 

            FROM po_vendor_sites_all

           WHERE vendor_id = v_vendor_id

             AND org_id = gv_org_id

             AND UPPER(vendor_site_code) = UPPER(cvs.legacyVendorSiteName);



          print_log ( 'Existe el site en Oracle.' );



        EXCEPTION

          WHEN OTHERS THEN

            print_log ( 'No existe el site en Oracle.' );



            -- Se verifica si ya vino de BC, para no crear un site nuevo si le cambiaron el Legacy Vendor Site Name

            BEGIN



              SELECT vendor_site_id

                INTO v_vendor_site_id

                FROM ajc_bc_vendor_sites

               WHERE vendor_id = v_vendor_id

                 AND systemID = cvs.systemID

                 AND status = 'SITE CREATED';



              print_log ( 'El site ya fue creado, pero el Legacy Vendor Site Name fue cambiado en el Remit Address. Se obtiene el vendor_site_id de la tabla custom para no crear un nuevo site.' );



            EXCEPTION

              WHEN OTHERS THEN

                print_log ( 'No existe el site en Oracle.' );

                v_vendor_site_id := NULL;              



            END;



        END;



        BEGIN



          SELECT territory_code,

                 territory_short_name

            INTO v_country,

                 v_territory_short_name

            FROM fnd_territories_vl

           WHERE iso_territory_code = cvs.countryRegionCode;



          print_log ( 'BC Country: ' || cvs.countryRegionCode );

          print_log ( 'Oracle Country: ' || v_country );

          print_log ( 'Oracle Territory Short Name: ' || v_territory_short_name );



        EXCEPTION

          WHEN NO_DATA_FOUND THEN

            print_log ( 'BC Country Code ' || cvs.countryRegionCode || ' not found in Oracle.' );

            v_country := NULL;

            v_territory_short_name := NULL;



        END;



        -- 20240219

        BEGIN



          SELECT segment1

            INTO v_vendor_site_code_alt

            FROM po_vendors

           WHERE ( UPPER(vendor_name) = UPPER(cvs.legacyVendorSiteName) OR

                   UPPER(vendor_name) LIKE UPPER(cvs.legacyVendorSiteName) || '%' );



        EXCEPTION

          WHEN OTHERS THEN

            v_tbl_message := 'Vendor ' || UPPER(cvs.legacyVendorSiteName) || ' not found in Oracle.';

            v_tbl_status_site := 'SITE ERROR';

            RAISE e_vendor_site;



        END;        



        print_log ( 'v_vendor_site_code_alt: ' || v_vendor_site_code_alt );

        -- 20240219



        -- sb

        IF ( v_vendor_site_id IS NULL ) THEN



          print_log ( 'El site no existe. Se crea.' );



          AP_PO_VENDORS_APIS_PKG.insert_new_vendor_site( p_vendor_site_code => cvs.legacyVendorSiteName,

                                                         p_vendor_id => v_vendor_id,

                                                         p_org_id => gv_org_id,

                                                         p_address_line1 => cvs.address,

                                                         p_address_line2 => cvs.address2,

                                                         p_address_line3 => NULL,

                                                         p_address_line4 => NULL,

                                                         p_city => cvs.city,

                                                         p_state => NULL,

                                                         p_zip => cvs.zipCode,

                                                         p_province => NULL,

                                                         p_county => NULL,

                                                         p_country => v_country,

                                                         p_area_code => NULL,

                                                         p_phone => NULL,

                                                         p_fax_area_code => NULL,

                                                         p_fax => NULL,

                                                         p_email_address => NULL, 

                                                         p_purchasing_site_flag => 'Y',

                                                         p_pay_site_flag => 'Y',

                                                         p_rfq_only_site_flag => 'N',

                                                         x_vendor_site_id => v_vendor_site_id,

                                                         x_status => v_status,

                                                         x_exception_msg => v_exception_msg,

                                                         p_source => 'NOT IMPORT',

                                                         p_what_to_import => NULL,

                                                         p_commit_size => 1000,

                                                         p_hold_unvalidated_inv_flag => NULL,

                                                         p_hold_all_payments_flag => NULL,

                                                         p_duns_number => NULL,

                                                         p_group_id => '-99' );



          IF ( v_status = 'S' ) THEN



            print_log ( 'Site creado. v_vendor_site_id: ' || v_vendor_site_id );

            v_tbl_status_site := 'SITE CREATED';



            -- --------------------- --

            -- Se actualizan los dff --

            -- --------------------- --

            UPDATE po_vendor_sites_all

               SET remittance_email = cvs.eMail,

                   last_update_date = SYSDATE

                   -- 20240219

                  ,vendor_site_code_alt = v_vendor_site_code_alt

                   -- 20240219

             WHERE vendor_site_id = v_vendor_site_id;



          ELSE



            v_tbl_status_site := 'SITE CREATE ERROR';

            v_tbl_message := 'Failed to create vendor site. ' || v_exception_msg;

            RAISE e_vendor_site;



          END IF;



        ELSE -- v_vendor_site_id IS NOT NULL



          print_log ( 'El site existe. Se actualiza.' );



          AP_PO_VENDORS_APIS_PKG.update_vendor_site( p_vendor_site_code => cvs.legacyVendorSiteName,

                                                     p_vendor_site_id => v_vendor_site_id,

                                                     p_address_line1 => cvs.address,

                                                     p_address_line2 => cvs.address2,

                                                     p_address_line3 => NULL,

                                                     p_address_line4 => NULL,

                                                     p_city => cvs.city,

                                                     p_state => cvs.state, -- Se deja el state que tiene en Oracle

                                                     p_zip => cvs.zipCode,

                                                     p_province => NULL,

                                                     p_county => NULL,

                                                     p_country => v_country,

                                                     p_area_code => NULL,

                                                     p_phone => NULL,

                                                     p_fax_area_code => NULL,

                                                     p_fax => NULL,

                                                     p_email_address => cvs.eMail, 

                                                     p_purchasing_site_flag => 'Y',

                                                     p_pay_site_flag => 'Y',

                                                     p_rfq_only_site_flag => 'N',

                                                     x_status => v_status,

                                                     x_exception_msg => v_exception_msg,

                                                     p_hold_unvalidated_inv_flag => NULL,

                                                     p_hold_all_payments_flag => NULL,

                                                     p_duns_number => NULL,

                                                     p_calling_source => NULL );



          IF ( v_status = 'S' ) THEN



            print_log ( 'Site actualizado.' );

            v_tbl_status_site := 'SITE UPDATED';



            -- --------------------- --

            -- Se actualizan los dff --

            -- --------------------- --

            UPDATE po_vendor_sites_all

               SET remittance_email = cvs.eMail,

                   last_update_date = SYSDATE

                   -- 20240219

                  ,vendor_site_code_alt = v_vendor_site_code_alt

                   -- 20240219

             WHERE vendor_site_id = v_vendor_site_id;



          ELSE



            v_tbl_status_site := 'SITE UPDATE ERROR';

            v_tbl_message := 'Failed to update vendor site. ' || v_exception_msg;

            RAISE e_vendor_site;



          END IF;



        END IF; -- IF ( v_vendor_site_id IS NULL ) THEN



        -- Se actualiza el registro en la tabla custom

        UPDATE ajc_bc_vendor_sites

           SET status = v_tbl_status_site,

               processed_date = TRUNC(SYSDATE),

               request_id = gv_request_id,

               vendor_id = v_vendor_id,

               vendor_site_id = v_vendor_site_id

         WHERE vendorNo = cvs.vendorNo

           AND legacyVendorSiteName = cvs.legacyVendorSiteName

           AND status IS NULL

           AND request_id IS NULL

           AND message IS NULL

           AND processed_date IS NULL;



        COMMIT;

        -- sb



      EXCEPTION

        WHEN e_vendor_site THEN



          print_log ( v_tbl_status_site );



          ROLLBACK;



          UPDATE ajc_bc_vendor_sites

             SET status = v_tbl_status_site,

                 message = v_tbl_message,

                 processed_date = TRUNC(SYSDATE),

                 request_id = gv_request_id,

                 vendor_id = v_vendor_id

           WHERE vendorNo = cvs.vendorNo

             AND systemId = cvs.systemId -- legacyVendorSiteName = cvs.legacyVendorSiteName

             AND status IS NULL

             AND request_id IS NULL

             AND message IS NULL

             AND processed_date IS NULL;



        WHEN OTHERS THEN



          print_log ( 'Error general. ' || v_exception_msg );

          print_log ( 'Error: ' || SQLERRM );



          ROLLBACK;



          UPDATE ajc_bc_vendor_sites

             SET status = 'ERROR',

                 message = 'Error general. ' || v_tbl_message,

                 processed_date = TRUNC(SYSDATE),

                 request_id = gv_request_id,

                 vendor_id = v_vendor_id

           WHERE vendorNo = cvs.vendorNo

             AND systemId = cvs.systemId -- AND legacyVendorSiteName = cvs.legacyVendorSiteName

             AND status IS NULL

             AND request_id IS NULL

             AND message IS NULL

             AND processed_date IS NULL;



      END;



    END LOOP;



    print_log ( 'ajc_bc_vendors_to_oracle_pkg.vendor_sites_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      print_log ( 'ajc_bc_vendors_to_oracle_pkg.vendor_sites_p (!). Error: ' || SQLERRM );

      RAISE e_exception;



  END vendor_sites_p;



  -- 20230210

  PROCEDURE vendor_bank_accounts_p ( p_bc_environment           IN       VARCHAR2,

                                     p_last_bc_processed_date   IN       TIMESTAMP,

                                     p_count                    IN OUT   NUMBER ) IS



    CURSOR c_vendor_banks IS

    SELECT *

      FROM ajc_bc_vendor_banks

     WHERE status IS NULL

       AND request_id IS NULL

       AND processed_date IS NULL;



    v_get_url                    VARCHAR2(2000);

    -- 20230414 v_get_api                    VARCHAR2(100) := 'vendorBankAccountINE';

    v_get_api                    VARCHAR2(100);



    v_clob_result                CLOB;



    v_vendor_id                  ajc_bc_vendors.vendor_id%TYPE;

    v_vendor_name                ajc_bc_vendors.vendor_name%TYPE;

    v_vendor_site_id             ajc_bc_vendors.vendor_site_id%TYPE;



    v_is_primary                 VARCHAR2(1);



    v_bank_branch_id             ap_bank_branches.bank_branch_id%TYPE;



    v_bank_account_uses_id       ap_bank_account_uses_all.bank_account_uses_id%TYPE;

    v_external_bank_account_id   ap_bank_accounts_all.bank_account_id%TYPE;

    v_row_id                     VARCHAR2(2000);



    v_start_date                 ap_bank_account_uses_all.start_date%TYPE;

    v_end_date                   ap_bank_account_uses_all.end_date%TYPE;

    v_primary_flag               ap_bank_account_uses_all.primary_flag%TYPE;



    v_inactive_bank_acc_uses_id  ap_bank_account_uses_all.bank_account_uses_id%TYPE;

    v_inactive_bank_acc_id       ap_bank_accounts_all.bank_account_id%TYPE;

    v_inactive_bank_acc_num      ap_bank_accounts_all.bank_account_num%TYPE;



    v_tbl_status_vendor_bank     VARCHAR2(2000);

    v_error_message              VARCHAR2(200);

    e_exception                  EXCEPTION;



  BEGIN



    print_log ( ' ' );

    print_log ( 'ajc_bc_vendors_to_oracle_pkg.vendor_bank_accounts_p (+)' );



    v_get_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'VENDORS',

                                                 p_subentity => 'BANK ACCOUNTS',

                                                 p_method => 'GET' );

    print_log ( 'v_get_api: ' || v_get_api );                                                 



    v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, gv_company_id ) || v_get_api

                 || '?$filter=systemModifiedAt gt ' || TO_CHAR(p_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z')

                 -- se reemplazo por la lookup || ' and systemModifiedBy ne 79ee8266-81b2-4694-9b2d-363f6dc49ca2'

                 -- || '?$filter=vendorno eq ' || '''600086'''

                 ;



    print_log ( 'v_get_url: ' || v_get_url );



    v_clob_result := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );



    print_log ( 'Se obtienen las cuentas bancarias de los proveedores creados o modificados en la ejecucion actual y se insertan en la tabla ajc_bc_vendor_banks.' );



    INSERT

      INTO ajc_bc_vendor_banks

           ( systemId,

             vendorNo,

             legacyVendorSiteName,

             bankCode,

             name,

             name2,

             address,

             address2,

             city,

             state,

             zipCode,

             countryRegionCode,

             phoneNo,

             contact,

             currencyCode,

             bankBrancho,

             bankAccountNo,

             transitNo,

             bankTypeCode,

             eMail,

             homePage,

             bankClearingStandard,

             bankClearingCode,

             useForElectronicPayments,

             faxNo,

             swiftCode,

             iban,

             -- 20230327

             systemModifiedBy,

             -- 20230327

             creation_date )

      SELECT systemId,

             vendorNo,

             legacyVendorSiteName, 

             bankCode,

             name,

             name2,

             address,

             address2,

             city,

             state,

             zipCode,

             countryRegionCode,

             phoneNo,

             contact,

             currencyCode,

             bankBrancho,

             bankAccountNo,

             transitNo,

             bankTypeCode,

             eMail,

             homePage,

             bankClearingStandard,

             bankClearingCode,

             useForElectronicPayments,

             faxNo,

             swiftCode,

             iban,

             -- 20230327

             systemModifiedBy,

             -- 20230327

             TRUNC(SYSDATE) creation_date

      FROM json_table( v_clob_result,

                       '$.value[*]' COLUMNS ( systemId                   VARCHAR2(4000)  path '$.systemId',

                                              vendorNo                   VARCHAR2(4000)  path '$.vendorNo',

                                              legacyVendorSiteName       VARCHAR2(4000)  path '$.legacyVendorSiteName',

                                              bankCode                   VARCHAR2(4000)  path '$.bankCode',

                                              name                       VARCHAR2(4000)  path '$.name',

                                              name2                      VARCHAR2(4000)  path '$.name2',

                                              address                    VARCHAR2(4000)  path '$.address',

                                              address2                   VARCHAR2(4000)  path '$.address2',

                                              city                       VARCHAR2(4000)  path '$.city',

                                              state                      VARCHAR2(4000)  path '$.state',

                                              zipCode                    VARCHAR2(4000)  path '$.zipCode',

                                              countryRegionCode          VARCHAR2(4000)  path '$.countryRegionCode',

                                              phoneNo                    VARCHAR2(4000)  path '$.phoneNo',

                                              contact                    VARCHAR2(4000)  path '$.contact',

                                              currencyCode               VARCHAR2(4000)  path '$.currencyCode',

                                              bankBrancho                VARCHAR2(4000)  path '$.bankBrancho',

                                              bankAccountNo              VARCHAR2(4000)  path '$.bankAccountNo',

                                              transitNo                  VARCHAR2(4000)  path '$.transitNo',

                                              bankTypeCode               VARCHAR2(4000)  path '$.bankTypeCode',

                                              eMail                      VARCHAR2(4000)  path '$.eMail',

                                              homePage                   VARCHAR2(4000)  path '$.homePage',

                                              bankClearingStandard       VARCHAR2(4000)  path '$.bankClearingStandard',

                                              bankClearingCode           VARCHAR2(4000)  path '$.bankClearingCode',

                                              useForElectronicPayments   VARCHAR2(4000)  path '$.useForElectronicPayments',

                                              faxNo                      VARCHAR2(4000)  path '$.faxNo',

                                              swiftCode                  VARCHAR2(4000)  path '$.swiftCode',

                                              iban                       VARCHAR2(4000)  path '$.iban',

                                              -- 20230327

                                              systemModifiedBy           VARCHAR2(4000)  path '$.systemModifiedBy'

                                              -- 20230327

                                              ) );



    -- Agregado 20230327

    -- Se actualizan como SKIPPED aquellos que fueron modificados por usuarios que no existe en la lookup

    UPDATE ajc_bc_vendor_banks

       SET status = 'SKIPPED',

           processed_date = TRUNC(SYSDATE),

           request_id = gv_request_id

     WHERE status IS NULL

       AND request_id IS NULL

       AND processed_date IS NULL

       AND systemModifiedBy NOT IN ( SELECT description

                                       FROM fnd_lookup_values

                                      WHERE lookup_type = 'AJC_BC_VENDORS_IFC_USERS'

                                        AND enabled_flag = 'Y'

                                        AND SYSDATE BETWEEN start_date_active AND NVL(end_date_active,SYSDATE + 1) );



    p_count := SQL%ROWCOUNT;

    -- Agregado 20230327



    COMMIT;



    FOR cvb IN c_vendor_banks LOOP



      v_error_message := NULL;



      print_log ( ' ' );

      print_log ( 'Vendor No: ' || cvb.vendorNo );

      print_log ( 'Legacy Vendor Site Name: ' || cvb.legacyVendorSiteName );

      print_log ( 'Bank Account No: ' || cvb.bankAccountNo );



      p_count := p_count + 1; 



      BEGIN



        v_vendor_id := NULL;

        v_vendor_name := NULL;

        v_vendor_site_id := NULL;

        v_is_primary := NULL;

        v_bank_account_uses_id := NULL;

        v_external_bank_account_id := NULL;

        v_row_id := NULL;

        v_start_date := NULL;

        v_end_date := NULL;

        v_primary_flag := NULL;



        -- Se obtienen los datos del vendor y del site

        BEGIN



          SELECT v.vendor_id,

                 v.vendor_name,

                 vs.vendor_site_id

            INTO v_vendor_id,

                 v_vendor_name,

                 v_vendor_site_id

            FROM po_vendors v,

                 po_vendor_sites_all vs

           WHERE v.segment1 = cvb.vendorNo

             AND v.vendor_id = vs.vendor_id

             AND UPPER(vs.vendor_site_code) = UPPER(cvb.legacyVendorSiteName)

             AND vs.org_id = gv_org_id;



          print_log ( 'Se encuentra vendor y site por segment1 y vendor_site_code.' );

          print_log ( 'v_vendor_id: ' || v_vendor_id );

          print_log ( 'v_vendor_name: ' || v_vendor_name );

          print_log ( 'v_vendor_site_id: ' || v_vendor_site_id );



        EXCEPTION

          WHEN NO_DATA_FOUND THEN



            BEGIN



              SELECT bcv.vendor_id,

                     bcv.vendor_name,

                     bcv.vendor_site_id

                INTO v_vendor_id,

                     v_vendor_name,

                     v_vendor_site_id

                FROM ajc_bc_vendors bcv

               WHERE segment1 = cvb.vendorNo

                 AND UPPER(vendor_site_code) = UPPER(cvb.legacyVendorSiteName)

                 AND request_id = ( SELECT MAX(request_id)

                                      FROM ajc_bc_vendors

                                     WHERE segment1 = cvb.vendorNo

                                       AND UPPER(vendor_site_code) = UPPER(cvb.legacyVendorSiteName) );



              print_log ( 'Se encuentra vendor y site en la tabla ajc_bc_vendors' );

              print_log ( 'v_vendor_id: ' || v_vendor_id );

              print_log ( 'v_vendor_name: ' || v_vendor_name );

              print_log ( 'v_vendor_site_id: ' || v_vendor_site_id );



            EXCEPTION

              WHEN OTHERS THEN

              v_error_message := 'Error al buscar los datos del vendor y site.';

              v_tbl_status_vendor_bank := 'BANK ERROR';

              RAISE e_exception;



            END;



          WHEN OTHERS THEN

            v_error_message := 'Error al buscar los datos del vendor y site.';

            v_tbl_status_vendor_bank := 'BANK ERROR';

            RAISE e_exception;



        END;



        -- Se comprueba que ciertos campos requeridos tengan valor

        IF ( cvb.Name IS NULL OR cvb.Name = ' ' ) THEN



          v_error_message := 'Complete el campo Name en BC (Vendor Bank Account Card)';

          v_tbl_status_vendor_bank := 'BANK ERROR';

          RAISE e_exception;



        END IF;



        IF ( cvb.bankAccountNo IS NULL OR cvb.bankAccountNo = ' ' ) THEN



          v_error_message := 'Complete el campo Bank Account No. en BC (Vendor Bank Account Card)';

          v_tbl_status_vendor_bank := 'BANK ERROR';

          RAISE e_exception;



        END IF;



        -- Se verifica si la cuenta ya esta asignada al proveedor

        BEGIN



          SELECT bau.bank_account_uses_id,

                 bau.rowid,

                 bau.start_date,

                 bau.end_date,

                 bau.primary_flag

            INTO v_bank_account_uses_id,

                 v_row_id,

                 v_start_date,

                 v_end_date,

                 v_primary_flag

            FROM ap_bank_account_uses_all bau,

                 ap_bank_accounts_all ba,

                 po_vendor_sites_all vs

           WHERE bau.vendor_id = v_vendor_id       

             AND bau.external_bank_account_id = ba.bank_account_id

             AND ba.bank_account_num = cvb.bankAccountNo

             AND bau.org_id = gv_org_id

             AND bau.org_id = ba.org_id

             AND SYSDATE BETWEEN NVL(bau.start_date,SYSDATE - 1) AND NVL(bau.end_date,SYSDATE + 1)

             AND vs.vendor_id = v_vendor_id

             AND vs.vendor_site_id = v_vendor_site_id

             AND vs.org_id = ba.org_id

             AND bau.vendor_site_id = vs.vendor_site_id;



        EXCEPTION

          WHEN OTHERS THEN

            v_bank_account_uses_id := NULL;



        END;



        -- Se obtienen los datos de la cuenta  

        BEGIN



          SELECT bank_account_id

            INTO v_external_bank_account_id

            FROM ap_bank_accounts_all ba

           WHERE ba.bank_account_num = cvb.bankAccountNo

             AND ba.org_id = gv_org_id;



          print_log ( 'Bank Account ID: ' || v_external_bank_account_id );



        EXCEPTION

          WHEN NO_DATA_FOUND THEN



            -- Se crea la cuenta

            create_account_p ( p_bank_name => NVL(cvb.name2,v_vendor_name),

                               p_bank_branch_name => cvb.legacyVendorSiteName,

                               p_bank_num => cvb.transitNo,

                               p_bank_account_num => cvb.bankAccountNo,

                               p_bank_account_name => cvb.name,

                               p_currency_code => cvb.currencyCode,

                               p_external_bank_account_id => v_external_bank_account_id,

                               p_error_message => v_error_message );



            IF ( v_error_message IS NOT NULL ) THEN



              v_tbl_status_vendor_bank := 'BANK ERROR';

              RAISE e_exception; 



            END IF;



          WHEN OTHERS THEN



            v_error_message := 'Error al buscar los datos de la cuenta ' || cvb.bankAccountNo || ' en la tabla ap_bank_accounts_all.';

            v_tbl_status_vendor_bank := 'BANK ERROR';

            RAISE e_exception; 



        END;



        -- La cuenta no está asignada al proveedor

        IF ( v_bank_account_uses_id IS NULL ) THEN



          print_log ( 'Se verifica si tiene otra cuenta asignada para el vendor / site, para el mismo banco. ABA: ' || cvb.transitNo );



          v_inactive_bank_acc_uses_id := NULL;

          v_inactive_bank_acc_id := NULL;

          v_inactive_bank_acc_num := NULL;



          BEGIN



            SELECT bau.bank_account_uses_id,

                   ba.bank_account_id,

                   ba.bank_account_num

              INTO v_inactive_bank_acc_uses_id,

                   v_inactive_bank_acc_id,

                   v_inactive_bank_acc_num

              FROM ap_bank_account_uses_all bau,

                   ap_bank_accounts_all ba,

                   po_vendor_sites_all vs,

                   ap_bank_branches bb

             WHERE bau.vendor_id = v_vendor_id           

               AND bau.external_bank_account_id = ba.bank_account_id

               AND ba.bank_account_num != cvb.bankAccountNo

               AND bau.org_id = gv_org_id

               AND bau.org_id = ba.org_id

               AND SYSDATE BETWEEN NVL(bau.start_date,SYSDATE - 1) AND NVL(bau.end_date,SYSDATE + 1)

               AND bau.vendor_id = vs.vendor_id

               AND UPPER(vs.vendor_site_code) = UPPER(cvb.legacyVendorSiteName)

               AND vs.org_id = ba.org_id

               AND bau.vendor_site_id = vs.vendor_site_id

               AND ba.bank_branch_id = bb.bank_branch_id

               AND bb.bank_num = cvb.transitNo;



            print_log ( 'La cuenta ' || v_inactive_bank_acc_num || ' del mismo banco está asignada al site del proveedor.' );



            UPDATE ap_bank_account_uses_all

               SET primary_flag = 'N',

                   end_date = SYSDATE,

                   last_update_date = SYSDATE

             WHERE bank_account_uses_id = v_inactive_bank_acc_uses_id;



            print_log ( 'Se inactiva la relación. Registros actualizados: ' || SQL%ROWCOUNT );



            UPDATE ap_bank_accounts_all

               SET inactive_date = SYSDATE,

                   last_update_date = SYSDATE

             WHERE bank_account_id = v_inactive_bank_acc_id;



            COMMIT;



            print_log ( 'Se inactiva la cuenta. Registros actualizados: ' || SQL%ROWCOUNT );



          EXCEPTION

            WHEN OTHERS THEN

              v_inactive_bank_acc_uses_id := NULL;

              v_inactive_bank_acc_id := NULL;

              v_inactive_bank_acc_num := NULL;



          END;



          print_log ( 'La cuenta no está asignada al proveedor. Se asigna.' );



          -- Se verifica las cuentas asignadas al proveedor, si existe alguna primaria, la que se crea no es primaria

          -- Si no existe primaria, la que se crea es primaria

          SELECT DECODE(COUNT(1),0,'Y','N')

            INTO v_is_primary

            FROM ap_bank_account_uses_all bau

           WHERE bau.vendor_id = v_vendor_id 

             AND bau.primary_flag = 'Y'

             AND bau.org_id = gv_org_id;



          print_log ( 'Primary: ' || v_is_primary );



          -- Se obtiene su valor de la secuencia para asignar la cuenta al proveedor

          SELECT	ap_bank_account_uses_s.nextval

            INTO v_bank_account_uses_id

            FROM	dual;



          print_log ( 'v_bank_account_uses_id: ' || v_bank_account_uses_id );



          BEGIN



            ap_bank_account_uses_pkg.insert_row ( X_Rowid => v_row_id,

                                                  X_Bank_Account_Uses_Id => v_bank_account_uses_id,

                                                  X_Last_Update_Date => SYSDATE,

                                                  X_Last_Updated_By => gv_user_id,

                                                  X_Creation_Date => SYSDATE,

                                                  X_Created_By => gv_user_id,

                                                  X_Last_Update_Login => gv_user_id,

                                                  X_Customer_Id => NULL,

                                                  X_Customer_Site_Use_Id => NULL,

                                                  X_Vendor_Id => v_vendor_id,

                                                  X_Vendor_Site_Id => v_vendor_site_id,

                                                  X_External_Bank_Account_Id => v_external_bank_account_id,

                                                  X_Start_Date => SYSDATE,

                                                  X_End_Date => NULL,

                                                  X_Primary_Flag => v_is_primary,

                                                  X_Attribute_Category => NULL,

                                                  X_Attribute1 => NULL,

                                                  X_Attribute2 => NULL,

                                                  X_Attribute3 => NULL,

                                                  X_Attribute4 => NULL,

                                                  X_Attribute5 => NULL,

                                                  X_Attribute6 => NULL,

                                                  X_Attribute7 => NULL,

                                                  X_Attribute8 => NULL,

                                                  X_Attribute9 => NULL,

                                                  X_Attribute10 => NULL,

                                                  X_Attribute11 => NULL,

                                                  X_Attribute12 => NULL,

                                                  X_Attribute13 => NULL,

                                                  X_Attribute14 => NULL,

                                                  X_Attribute15 => NULL );



            v_tbl_status_vendor_bank := 'BANK CREATED';



            UPDATE ajc_bc_vendor_banks

               SET status = v_tbl_status_vendor_bank,

                   request_id = gv_request_id,

                   processed_date = SYSDATE,

                   --

                   vendor_id = v_vendor_id,

                   vendor_site_id = v_vendor_site_id

             WHERE status IS NULL

               AND request_id IS NULL

               AND processed_date IS NULL

               AND systemid = cvb.systemid;

               -- AND vendorNo = cvb.vendorNo

               -- AND bankAccountNo = cvb.bankAccountNo;



          EXCEPTION                                                  

            WHEN OTHERS THEN



              v_error_message := 'Error al intentar asignar la cuenta al site del proveedor (ap_bank_account_uses_pkg.insert_row).';

              v_tbl_status_vendor_bank := 'BANK CREATE ERROR';



              UPDATE ajc_bc_vendor_banks

                 SET status = v_tbl_status_vendor_bank,

                     request_id = gv_request_id,

                     processed_date = SYSDATE,

                     --

                     vendor_id = v_vendor_id,

                     vendor_site_id = v_vendor_site_id,

                     message = v_error_message

               WHERE status IS NULL

                 AND request_id IS NULL

                 AND processed_date IS NULL

                 AND systemid = cvb.systemid;

                 -- AND vendorNo = cvb.vendorNo

                 -- AND bankAccountNo = cvb.bankAccountNo;



          END;



        ELSE 



          print_log ( 'La cuenta ya está asignada al site del proveedor. Se actualiza.' );



          BEGIN



            ap_bank_account_uses_pkg.update_row ( X_Rowid => v_row_id,

                                                  X_Bank_Account_Uses_Id => v_bank_account_uses_id,

                                                  X_Last_Update_Date => SYSDATE,

                                                  X_Last_Updated_By => gv_user_id,

                                                  X_Last_Update_Login => gv_user_id,

                                                  X_Customer_Id => NULL,

                                                  X_Customer_Site_Use_Id => NULL,

                                                  X_Vendor_Id => v_vendor_id,

                                                  X_Vendor_Site_Id => v_vendor_site_id,

                                                  X_External_Bank_Account_Id => v_external_bank_account_id,

                                                  X_Start_Date => v_start_date,

                                                  X_End_Date => v_end_date,

                                                  X_Primary_Flag => v_primary_flag,

                                                  X_Attribute_Category => NULL,

                                                  X_Attribute1 => NULL,

                                                  X_Attribute2 => NULL,

                                                  X_Attribute3 => NULL,

                                                  X_Attribute4 => NULL,

                                                  X_Attribute5 => NULL,

                                                  X_Attribute6 => NULL,

                                                  X_Attribute7 => NULL,

                                                  X_Attribute8 => NULL,

                                                  X_Attribute9 => NULL,

                                                  X_Attribute10 => NULL,

                                                  X_Attribute11 => NULL,

                                                  X_Attribute12 => NULL,

                                                  X_Attribute13 => NULL,

                                                  X_Attribute14 => NULL,

                                                  X_Attribute15 => NULL );



            v_tbl_status_vendor_bank := 'BANK UPDATED';



            UPDATE ajc_bc_vendor_banks

               SET status = v_tbl_status_vendor_bank,

                   request_id = gv_request_id,

                   processed_date = SYSDATE,

                   --

                   vendor_id = v_vendor_id,

                   vendor_site_id = v_vendor_site_id

             WHERE status IS NULL

               AND request_id IS NULL

               AND processed_date IS NULL

               AND systemid = cvb.systemid;

               -- AND vendorNo = cvb.vendorNo

               -- AND bankAccountNo = cvb.bankAccountNo;



          EXCEPTION

            WHEN OTHERS THEN



              v_error_message := 'Error al intentar actualizar la cuenta para el site del proveedor (ap_bank_account_uses_pkg.update_row).';

              v_tbl_status_vendor_bank := 'BANK UPDATE ERROR';



              UPDATE ajc_bc_vendor_banks

                 SET status = v_tbl_status_vendor_bank,

                     request_id = gv_request_id,

                     processed_date = SYSDATE,

                     vendor_id = v_vendor_id,

                     vendor_site_id = v_vendor_site_id,

                     message = v_error_message

               WHERE status IS NULL

                 AND request_id IS NULL

                 AND processed_date IS NULL

                 AND systemid = cvb.systemid;

                 -- AND vendorNo = cvb.vendorNo

                 -- AND bankAccountNo = cvb.bankAccountNo;

          END;



        END IF;  



      EXCEPTION

        WHEN e_exception THEN

          print_log ( 'Error: ' || v_error_message );



          UPDATE ajc_bc_vendor_banks

             SET status = v_tbl_status_vendor_bank,

                 request_id = gv_request_id,

                 processed_date = SYSDATE,

                 --

                 vendor_id = v_vendor_id,

                 vendor_site_id = v_vendor_site_id,

                 message = v_error_message

           WHERE status IS NULL

             AND request_id IS NULL

             AND processed_date IS NULL

             AND systemid = cvb.systemid;

             -- AND vendorNo = cvb.vendorNo

             -- AND bankAccountNo = cvb.bankAccountNo;



        WHEN OTHERS THEN

          v_error_message := SQLERRM;

          print_log ( 'Error general: ' || v_error_message );



          UPDATE ajc_bc_vendor_banks

              SET status = 'ERROR',

                  request_id = gv_request_id,

                  processed_date = SYSDATE,

                  --

                  vendor_id = v_vendor_id,

                  vendor_site_id = v_vendor_site_id,

                  message = v_error_message

            WHERE status IS NULL

              AND request_id IS NULL

              AND processed_date IS NULL

              AND systemid = cvb.systemid;

              -- AND vendorNo = cvb.vendorNo

              -- AND bankAccountNo = cvb.bankAccountNo;



      END;



    END LOOP;



    print_log ( 'ajc_bc_vendors_to_oracle_pkg.vendor_bank_accounts_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      print_log ( 'ajc_bc_vendors_to_oracle_pkg.vendor_bank_accounts_p (!). Error: ' || SQLERRM );

      RAISE e_exception;



  END vendor_bank_accounts_p;

  -- 20230210



  /*=========================================================================+

  |                                                                          |

  | Private Procedure                                                        |

  |    main_p                                                                |

  |                                                                          |

  | Description                                                              |

  |    Main                                                                  |

  |                                                                          |

  +=========================================================================*/

  PROCEDURE main_p ( retcode                   OUT   NUMBER,

                     errbuf                    OUT   VARCHAR2,

                     p_bc_environment           IN   VARCHAR2,

                     p_refresh_payment_terms    IN   VARCHAR2,

                     p_process_multiple_sites   IN   VARCHAR2 ) IS 



    v_email                    VARCHAR2(2000);



    v_vendors_count            NUMBER;

    v_sites_count              NUMBER;

    v_bank_accounts_count      NUMBER;

    v_request_id_excel         NUMBER;



    v_run_date                 TIMESTAMP;

    v_last_processed_date      TIMESTAMP;

    v_last_bc_processed_date   TIMESTAMP;



  BEGIN



    print_log ( 'ajc_bc_vendors_to_oracle_pkg.main_p (+)' );



    v_email := ajc_bc_ws_utils_pkg.get_emails_f ( 'VENDORS' );



    print_log ( 'Parameters' );

    print_log ( ' ' );

    print_log ( 'p_bc_environment: ' || p_bc_environment );

    print_log ( 'p_refresh_payment_terms: ' || p_refresh_payment_terms );

    print_log ( 'p_process_multiple_sites: ' || p_process_multiple_sites );

    print_log ( 'v_email: ' || v_email );



    -- Se guarda la fecha y hora actual

    v_run_date := systimestamp;

    print_log ( 'v_run_date: ' || v_run_date );



    -- Se obtiene la fecha y hora de Oracle de la ultima ejecucion de la interface

    v_last_processed_date := ajc_bc_ws_utils_pkg.get_ifc_last_processed_date_f ( gv_ifc );

    print_log ( 'Oracle last processed date: ' || v_last_processed_date );    



    -- Se obtiene la fecha y hora de BC de la ultima ejecucion de la interface

    v_last_bc_processed_date := ajc_bc_ws_utils_pkg.get_bc_last_processed_date_f ( v_last_processed_date );

    print_log ( 'BC last processed date: ' || v_last_bc_processed_date );



    -- Se sincronizan las novedades de payment terms antes de traer los vendors

    IF ( p_refresh_payment_terms = 'Y' ) THEN



      ajc_bc_payment_terms_pkg.caller_p ( p_bc_environment => p_bc_environment );



    END IF;



    vendors_p ( p_bc_environment, 

                v_last_bc_processed_date,

                v_vendors_count );        



    -- vendor_site_contacts_p ( retcode, errbuf, p_bc_environment );



    IF ( p_process_multiple_sites = 'Y' ) THEN



      vendor_sites_p ( p_bc_environment,

                       v_last_bc_processed_date,

                       v_sites_count );



    END IF;



    vendor_bank_accounts_p ( p_bc_environment,

                             v_last_bc_processed_date,

                             v_bank_accounts_count );



    IF ( v_vendors_count > 0 OR 

         v_sites_count > 0 OR 

         v_bank_accounts_count > 0 ) THEN



      -- EXCEL REPORT ------------------------------------------------------------------------------------------------------------

      v_request_id_excel := ajc_bc_ws_utils_pkg.print_excel_report ( p_request_id => gv_request_id,

                                                                     p_program => 'AJCBCVIR', -- AJC BC Vendors Interface Report 

                                                                     p_template => 'AJCBCVIR' );



      -- 20230317 send_email ( p_mail, v_request_id_excel );

      ajc_bc_ws_utils_pkg.send_unix_mail_attach ( p_mail => v_email,

                                                  p_report_request_id => v_request_id_excel ); 



    END IF;



    -- Se actualiza la tabla de control

    ajc_bc_ws_utils_pkg.upd_ifc_last_processed_date_p ( gv_ifc,

                                                        gv_request_id,

                                                        v_run_date );



    COMMIT;



    print_log ( 'ajc_bc_vendors_to_oracle_pkg.main_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      print_log ( 'ajc_bc_vendors_to_oracle_pkg.main_p (!). ' || SQLERRM );

      -- 20240318

      ajc_bc_ws_utils_pkg.send_email ( p_to => gv_bc_support_email

                                      ,p_subject => gv_bc_support_subject

                                      ,p_message => 'General error ajc_bc_vendors_to_oracle_pkg.main_p ' || SQLERRM );

      -- 20240318



  END main_p;



END ajc_bc_vendors_to_oracle_pkg;
