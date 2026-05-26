PACKAGE BODY AJC_BC_J_VENDORS_TO_ORACLE_PKG IS
  
  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    gv_log_seq := gv_log_seq + 1;
    AJC_BC_J_UTILS_PKG.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );

  END print_log;

  PROCEDURE send_oracle_vendor_id_to_bc_p ( p_system_id        IN   VARCHAR2,
                                            p_vendor_id        IN   NUMBER ) IS

    v_db_name       VARCHAR2(100);
    v_patch_api     VARCHAR2(1000);
    v_patch_url     VARCHAR2(2000);
    v_etag          VARCHAR2(1000);
    v_body          VARCHAR2(2000);
    v_clob_result   CLOB;

  BEGIN

    print_log ( 'AJC_BC_J_VENDORS_TO_ORACLE_PKG.send_oracle_vendor_id_to_bc_p (+)' );

    -- Se obtiene el nombre de la base de datos
    v_db_name := AJC_BC_J_UTILS_PKG.get_db_name_f;

    -- --------------------------------------------------------------------------------------------- --
    -- Se actualiza el vendor_id en BC - Solo si se ejecuta en Oracle PROD                           -- 
    -- o si no se ejecuta de PROD a Production                                                       --
    -- --------------------------------------------------------------------------------------------- --
    IF ( ( v_db_name = 'PROD' ) OR 
         ( v_db_name != 'PROD' AND gv_bc_environment != 'Production' ) ) THEN

      v_patch_api := AJC_BC_J_WS_UTILS_PKG.get_api_f ( p_entity => 'VENDORS',
                                                       p_subentity => 'VENDOR_ID',
                                                       p_method => 'PATCH' );
      print_log ( 'v_patch_api: ' || v_patch_api );

      -- Patch URL
      v_patch_url := AJC_BC_J_WS_UTILS_PKG.get_base_inecta_url_f ( gv_bc_environment, gv_company_id ) || v_patch_api || '(' || p_system_id || ')';

      print_log ( 'v_patch_url: ' || v_patch_url );

      -- 1
      print_log ( 'Se obtiene el etag del vendor.' );

      v_clob_result := AJC_BC_J_WS_UTILS_PKG.get_bc_clob_result_f ( p_url => v_patch_url );

      v_etag := SUBSTR(v_clob_result,INSTR(v_clob_result,'@odata.etag') + 14);
      v_etag := REPLACE(SUBSTR(v_etag,1,INSTR(v_etag,',') - 2),'\');

      print_log ( 'v_etag: ' || v_etag );

      -- 2
      print_log ( 'Se actualiza el oracle_vendor_id en BC.' );

      v_body := '{"oraclevendorIDAJCGINE":"' || p_vendor_id || '"}';

      v_clob_result := AJC_BC_J_WS_UTILS_PKG.patch_post_bc_row_f ( p_url => v_patch_url
                                                                  ,p_request_header_name1 => 'Content-Type'
                                                                  ,p_request_header_value1 => 'application/json'
                                                                  ,p_request_header_name2 => 'If-Match'
                                                                  ,p_request_header_value2 => v_etag
                                                                  ,p_http_method => 'PATCH'
                                                                  ,p_body => v_body );            

      print_log ( 'v_clob_result: ' || v_clob_result );

    END IF;

    print_log ( 'AJC_BC_J_VENDORS_TO_ORACLE_PKG.send_oracle_vendor_id_to_bc_p (-)' );

  EXCEPTION
    WHEN OTHERS THEN
      print_log ( 'AJC_BC_J_VENDORS_TO_ORACLE_PKG.send_oracle_vendor_id_to_bc_p (!). Error: ' || SQLERRM );

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
  PROCEDURE vendors_p ( p_last_bc_processed_date   IN       TIMESTAMP,
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
           CASE
             WHEN ( blocked = '_x0020_' ) THEN
               NULL
             ELSE
               blocked
           END blocked,
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
    v_get_api                  VARCHAR2(100);

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

    v_vendor_type_lookup_code  VARCHAR2(100);
    v_payment_term_active      VARCHAR2(1);
    v_hold_all_payments_flag   po_vendor_sites_all.hold_all_payments_flag%TYPE;

  BEGIN

    print_log ( 'AJC_BC_J_VENDORS_TO_ORACLE_PKG.vendors_p (+)' );

    fnd_global.apps_initialize ( user_id => 0,
                                 resp_id => gv_ap_resp_id,
                                 resp_appl_id => 200 ); -- SQLAP

    mo_global.set_policy_context ('S', gv_org_id);

    IF ( FND_PROFILE.VALUE('DEFAULT_COUNTRY') IS NULL ) THEN

      RAISE e_default_country;

    END IF;

    print_log ( 'p_company_id: ' || gv_company_id );
    print_log ( 'gv_bc_environment: ' || gv_bc_environment );

    v_get_api := AJC_BC_J_WS_UTILS_PKG.get_api_f ( p_entity => 'VENDORS',
                                                   p_subentity => NULL,
                                                   p_method => 'GET' );
    print_log ( 'v_get_api: ' || v_get_api );

    v_get_url := AJC_BC_J_WS_UTILS_PKG.get_base_inecta_url_f ( gv_bc_environment, gv_company_id ) || v_get_api
                 || '?$filter=systemmodifiedat gt ' || TO_CHAR(p_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z')          
                 -- se reemplazo por la lookup || ' and systemmodifiedby ne 79ee8266-81b2-4694-9b2d-363f6dc49ca2' -- not equal to BC
                 -- || '?$filter=vendorno eq ' || '''600086'''
                 ;

    print_log ( 'v_get_url: ' || v_get_url );

    v_clob_result := AJC_BC_J_WS_UTILS_PKG.get_bc_clob_result_f ( p_url => v_get_url );

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
             systemmodifiedby,
             oraclevendorIDAJCGINE,
             --
             creation_date )
    SELECT systemid,
           no segment1,
           TRIM(name) vendor_name,
           vat_registration_num,
           DECODE(payment_terms,'TBD',NULL,' ',NULL,'',NULL,payment_terms) payment_terms,
           payment_method,
           address1,
           address2,
           DECODE(country,'TBD',NULL,
                          ' ',NULL,
                          '',NULL,
                          'HDL','NLD',
                          country) country,
           DECODE(city,'TBD',NULL,' ',NULL,'',NULL,city) city,
           zip,
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
           systemmodifiedby,
           oraclevendorIDAJCGINE,
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
                                            country                          VARCHAR2(4000)  path '$.countryregioncode', 
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
                                            ajc_country_code                 VARCHAR2(4000)  path '$.territorycode',
                                            ajc_parent_site_credit_limit     VARCHAR2(4000)  path '$.ajcParentSiteCrLmtAJCINE',
                                            ajc_credit_limit_amount          VARCHAR2(4000)  path '$.ajcCreditLimitAmtAJCINE', 
                                            ajc_prepay_credit_limit_amount   VARCHAR2(4000)  path '$.ajcPrepayCrLmtAmtAJCINE',
                                            blocked                          VARCHAR2(4000)  path '$.blocked',
                                            pay_group                        VARCHAR2(4000)  path '$.vendorcategoryINE',
                                            systemmodifiedby                 VARCHAR2(4000)  path '$.systemmodifiedby',
                                            oraclevendorIDAJCGINE            VARCHAR2(4000)  path '$.oraclevendorIDAJCGINE'  
                                            ) );

    -- Se actualizan como SKIPPED aquellos que fueron modificados por usuarios que no existe en la lookup
    print_log ( 'Updating vendors with SKIPPED status when the user that created/updated them in BC does not have sync permissions.');

    UPDATE ajc_bc_vendors
       SET status = 'SKIPPED',
           processed_date = TRUNC(SYSDATE),
           request_id = gv_request_id
     WHERE status IS NULL
       AND request_id IS NULL
       AND processed_date IS NULL
       AND systemmodifiedby NOT IN ( SELECT user_security_id
                                       FROM ajc_bc_vend_cust_ifc_users
                                      WHERE bc_environment = gv_bc_environment
                                        AND company = 'INC'
                                        AND type = 'VENDORS'
                                        AND enabled = 'Y' );
    p_count := SQL%ROWCOUNT;

    print_log ( 'Records updated: ' || p_count );

    COMMIT;

    FOR cv IN c_vendors LOOP

      BEGIN

        -- ----------- --
        -- Proveedores --
        -- ----------- --

        v_vendor_name := cv.vendor_name;
        p_count := p_count + 1;

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

        v_terms_id := NULL;
        v_payment_method := NULL;
        v_pay_group := NULL;
        v_vendor_type_lookup_code := NULL;

        print_log ( 'payment_terms: ' || cv.payment_terms );

        IF ( cv.payment_terms IS NOT NULL ) THEN

          v_terms_id := ajc_bc_create_entities_pkg.payment_terms_f ( cv.payment_terms, 'AP', gv_company_id, gv_bc_environment );

          print_log ( 'v_terms_id: ' || v_terms_id );

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

        IF ( cv.payment_method IS NOT NULL ) THEN

          v_payment_method := ajc_bc_create_entities_pkg.payment_method_f ( cv.payment_method );

        ELSIF ( cv.payment_method IS NULL AND cv.pay_group != 'POTENTIAL SUPPLIER' ) THEN

          v_tbl_message := 'Payment Method Code cannot be null in BC.';
          RAISE e_vendor;

        ELSIF ( cv.payment_method IS NULL AND cv.pay_group = 'POTENTIAL SUPPLIER' ) THEN

          v_payment_method := 'CHECK';

        END IF;

        IF ( cv.pay_group IS NOT NULL AND cv.pay_group != 'POTENTIAL SUPPLIER' ) THEN

          v_pay_group := ajc_bc_create_entities_pkg.pay_group_f ( cv.pay_group );

        ELSIF ( cv.pay_group = 'POTENTIAL SUPPLIER' ) THEN

          v_pay_group := cv.pay_group;

        END IF;

        IF ( v_pay_group = 'EMPLOYEE' ) THEN

          v_vendor_type_lookup_code := 'VENDOR';

        ELSIF ( v_pay_group = 'POTENTIAL SUPPLIER' ) THEN

          v_vendor_type_lookup_code := 'SUPPLIER';
          v_pay_group := 'SUPPLIER';

        ELSIF ( v_pay_group IN ('SUPPLIER SAM','SUPPLIER EUR') ) THEN

          v_vendor_type_lookup_code := 'SUPPLIER';

        ELSIF ( v_pay_group = 'SUNVALLEY' ) THEN

          v_vendor_type_lookup_code := 'WAREHOUSE';

        ELSIF ( v_pay_group = 'SUNVALLEY SUPPLIER' ) THEN

          v_vendor_type_lookup_code := 'SUPPLIER';

        ELSE        

          v_vendor_type_lookup_code := v_pay_group;

        END IF;

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
                                                     p_vendor_type_lookup_code => v_vendor_type_lookup_code, 
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
                                            'Payment',NULL,
                                            'All',SYSDATE, -- Solo se inactiva el vendor cuando blocked es All                                          
                                            NULL),
                   invoice_currency_code = cv.payment_currency,
                   payment_currency_code = cv.payment_currency,
                   pay_group_lookup_code = v_pay_group,
                   terms_id = v_terms_id,
                   payment_method_lookup_code = v_payment_method,
                   last_update_date = SYSDATE
             WHERE vendor_id = v_vendor_id;

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

            send_oracle_vendor_id_to_bc_p ( p_system_id => cv.systemid,
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
               SET segment1 = cv.segment1,
                   vendor_name = cv.vendor_name,
                   organization_type_lookup_code = cv.organization_type,
                   attribute1 = cv.atis_valid_vendor,
                   attribute2 = cv.sad,
                   attribute3 = cv.ajc_kingdee_translated_name,
                   attribute4 = cv.ajc_ap_revalidation_exclude,
                   end_date_active = DECODE(cv.blocked,
                                            NULL,NULL,
                                            ' ',NULL,
                                            'Payment',NULL,
                                            'All',SYSDATE, -- Solo se inactiva el vendor cuando blocked es All                                          
                                            NULL),
                   pay_group_lookup_code = v_pay_group,
                   terms_id = v_terms_id,
                   payment_method_lookup_code = v_payment_method,
                   vendor_type_lookup_code = v_vendor_type_lookup_code, -- 20230105 v_pay_group
                   last_update_date = SYSDATE
             WHERE vendor_id = v_vendor_id;

            -- Si tiene el one time flag en Y y ya no es POTENCIAL SUPPLIER significa que era POTENCIAL SUPPLIER y dejo de serlo, por eso debe desmarcarse el flag 
            IF ( cv.pay_group != 'POTENTIAL SUPPLIER' AND v_one_time_flag = 'Y' ) THEN

              UPDATE po_vendors
                 SET one_time_flag = 'N',
                     last_update_date = SYSDATE
               WHERE vendor_id = v_vendor_id;

            ELSIF ( cv.pay_group = 'POTENTIAL SUPPLIER' AND v_one_time_flag = 'N' ) THEN  

              UPDATE po_vendors
                 SET one_time_flag = 'Y',
                     last_update_date = SYSDATE
               WHERE vendor_id = v_vendor_id;

            END IF;

            -- ---------------------------------------------------------------------- --
            -- Se actualiza el vendor_id en BC - Solo si se ejecuta en Oracle PROD    -- 
            -- o si se ejecuta en Oracle FINUPG5 apuntando a Sandbox | Production UAT -- 
            -- ---------------------------------------------------------------------- --

            -- Si existe en Oracle y viene sin oracle vendor id es porque lo crearon a mano en BC, por lo tanto se actualiza 
            -- el vendor y se envia el vendor id
            IF ( cv.oraclevendorIDAJCGINE IS NULL ) THEN

              send_oracle_vendor_id_to_bc_p ( p_system_id => cv.systemid,
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
                 ,state
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
                 ,v_state
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
 
