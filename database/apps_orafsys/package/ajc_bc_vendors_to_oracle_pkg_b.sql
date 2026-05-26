PACKAGE BODY ajc_bc_vendors_to_oracle_pkg IS

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
       
