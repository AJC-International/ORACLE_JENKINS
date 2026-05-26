PACKAGE BODY ajcl_bc_vendors_to_oracle_pkg IS
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

  PROCEDURE send_oracle_vendor_id_to_bc_p ( p_system_id        IN   VARCHAR2,
                                            p_vendor_id        IN   NUMBER ) IS

    v_db_name       VARCHAR2(100);
    v_patch_url     VARCHAR2(2000);
    v_etag          VARCHAR2(1000);
    v_body          VARCHAR2(2000);
    v_clob_result   CLOB;

  BEGIN

    print_log ( 'ajcl_bc_vendors_to_oracle_pkg.send_oracle_vendor_id_to_bc_p (+)' );

    -- Se obtiene el nombre de la base de datos
    v_db_name := ajcl_bc_utils_pkg.get_db_name_f;

    -- --------------------------------------------------------------------------------------------- --
    -- Se actualiza el vendor_id en BC - Solo si se ejecuta en Oracle PROD                           -- 
    -- o si se ejecuta en Oracle no PROD apuntando a un ambiente distinto a Production               --
    -- --------------------------------------------------------------------------------------------- --
    IF ( ( v_db_name = 'PROD' ) OR 
         ( v_db_name != 'PROD' AND gv_bc_environment != 'Production' ) ) THEN

      v_patch_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,
                                                                  p_entity => 'VENDORS',
                                                                  p_subentity => 'VENDOR_ID',
                                                                  p_method => 'PATCH',
                                                                  p_company_id => gv_bc_company_id )
                     || '(' || p_system_id || ')';

      print_log ( 'v_patch_url: ' || v_patch_url );

      -- 1
      print_log ( 'Getting vendor etag.' );

      v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_patch_url );

      v_etag := ajcl_bc_ws_utils_pkg.get_etag_f ( p_clob_result => v_clob_result );
      print_log ( 'v_etag: ' || v_etag );

      -- 2
      print_log ( 'Patching Oracle Vendor ID.' );

      v_body := '{"oraclevendorIDAJCGINE":"' || p_vendor_id || '"}';

      v_clob_result := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_patch_url
                                                                 ,p_request_header_name1 => 'Content-Type'
                                                                 ,p_request_header_value1 => 'application/json'
                                                                 ,p_request_header_name2 => 'If-Match'
                                                                 ,p_request_header_value2 => v_etag
                                                                 ,p_http_method => 'PATCH'
                                                                 ,p_body => v_body );            

      print_log ( 'v_clob_result: ' || v_clob_result );

    END IF;

    print_log ( 'ajcl_bc_vendors_to_oracle_pkg.send_oracle_vendor_id_to_bc_p (-)' );

  EXCEPTION
    WHEN OTHERS THEN
      print_log ( 'ajcl_bc_vendors_to_oracle_pkg.send_oracle_vendor_id_to_bc_p (!). Error: ' || SQLERRM );

  END send_oracle_vendor_id_to_bc_p;

  PROCEDURE get_vendors_p ( p_last_bc_processed_date   IN       TIMESTAMP,
                            p_count                    IN OUT   NUMBER,
                            p_status                   OUT      VARCHAR2, 
                            p_error_message            OUT      VARCHAR2 ) IS

    v_get_url               VARCHAR2(2000);
    v_vendorno              VARCHAR2(100);
    v_clob_result           CLOB;

    -- 20240925
    v_without_permissions   NUMBER;
    v_invalid_carrier       NUMBER;
    -- 20240925

    CURSOR c_vendors ( p_clob_result   CLOB ) IS
    SELECT systemid,
           no segment1,
           TRIM(name) vendor_name,
           vat_registration_num,
           DECODE(payment_terms,'TBD',NULL,' ',NULL,'',NULL,payment_terms) payment_terms,
           payment_method,
           address1,
           address2,
           country,
           DECODE(city,'TBD',NULL,' ',NULL,'',NULL,city) city,
           -- 20240920
           state,
           -- 20240920
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
           CASE
             WHEN ( blocked = '_x0020_' ) THEN
               NULL
             ELSE
               blocked
           END blocked,
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
                                            -- 20240920
                                            state                            VARCHAR2(4000)  path '$.county',
                                            -- 20240920
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
                                            oraclevendorIDAJCGINE            VARCHAR2(4000)  path '$.oraclevendorIDAJCGINE' ) );

  BEGIN

    print_log ( 'ajcl_bc_vendors_to_oracle_pkg.get_vendors_p (+)' );

    v_get_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,
                                                              p_entity => 'VENDORS',
                                                              p_subentity => NULL,
                                                              p_method => 'GET',
                                                              p_company_id => gv_bc_company_id )
                 || '?$filter=systemmodifiedat gt ' || TO_CHAR(p_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');                                                              

    print_log ( 'v_get_url: ' || v_get_url );

    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );

    print_log ( 'The created or modified vendors are obtained and inserted into the ajcl_bc_vendors table.' );

    FOR cv IN c_vendors ( p_clob_result => v_clob_result ) LOOP

      v_vendorno := cv.segment1;

      INSERT
        INTO ajcl_bc_vendors 
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
               -- 20240920
               state,
               -- 20240920
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
               creation_date )
      VALUES ( cv.systemid,
               cv.segment1,
               cv.vendor_name,
               cv.vat_registration_num,
               cv.payment_terms,
               cv.payment_method,
               cv.address1,
               cv.address2,
               cv.country,
               cv.city,
               -- 20240920
               cv.state,
               -- 20240920
               cv.zip,
               cv.email,
               gv_org_id,
               cv.vendor_site_code,
               cv.organization_type,   
               cv.atis_valid_vendor,
               cv.sad,
               cv.ajc_kingdee_translated_name,
               cv.ajc_ap_revalidation_exclude,
               cv.blocked,
               cv.payment_currency,
               cv.ajc_country_code,
               cv.ajc_parent_site_credit_limit,
               cv.ajc_credit_limit_amount,
               cv.ajc_prepay_credit_limit_amount,
               cv.pay_group,
               cv.systemmodifiedby,
               cv.oraclevendorIDAJCGINE,
               cv.creation_date );

    END LOOP;           

    -- Se actualizan como SKIPPED aquellos que fueron modificados por usuarios que no existe en la lookup
    print_log ( 'Updating vendors with SKIPPED status when the user that created/updated them in BC does not have sync permissions.');

    UPDATE ajcl_bc_vendors
       SET status = 'SKIPPED',
           processed_date = TRUNC(SYSDATE),
           request_id = gv_request_id
     WHERE status IS NULL
       AND request_id IS NULL
       AND processed_date IS NULL
       AND systemmodifiedby NOT IN ( SELECT user_security_id
                                       FROM ajc_bc_vend_cust_ifc_users
                                      WHERE bc_environment = gv_bc_environment
                                        AND company = 'LOG'
                                        AND type = 'VENDORS'
                                        AND enabled = 'Y' );

    -- 20240925
    -- p_count := SQL%ROWCOUNT;
    v_without_permissions := SQL%ROWCOUNT;
    print_log ( 'Records updated: ' || v_without_permissions );
    -- 20240925

    -- 20240925
    -- Si el vendor que viene existe en la tabla de carriers con este error, significa que TRV no pudo crearlo y que el usuario tiene que crearlo con otro name
    -- Se marca como error para que no pise vendors distintos que tienen mismo name en Oracle
    print_log ( 'Updating vendor with status SKIPPED when the user created it manually in BC with the same name as a Carrier that could not be created.');

    UPDATE ajcl_bc_vendors v
       SET status = 'SKIPPED',
           processed_date = TRUNC(SYSDATE),
           request_id = gv_request_id,
           message = 'Please, change vendor name in BC. A different vendor already exists with the same name in Oracle.'
     WHERE status IS NULL
       AND request_id IS NULL
       AND processed_date IS NULL
       AND EXISTS ( SELECT 1 
                      FROM ajcl_bc_trv_vendors c
                     WHERE v.vendor_name = c.name
                       AND c.oracle_status = 'SKIPPED'
                       AND c.bc_status = 'SKIPPED'
                       AND c.error_message = 'A vendor with the same name already exists in Oracle/BC. Please, create the vendor (with a different name) and the integration source mapping manually in BC.' );

    v_invalid_carrier := SQL%ROWCOUNT;
    print_log ( 'Records updated: ' || v_invalid_carrier );

    p_count := v_without_permissions + v_invalid_carrier;
    print_log ( 'Total records updated: ' || p_count );
    -- 20240925

    COMMIT;      

    p_status := 'S';
    print_log ('ajcl_bc_vendors_to_oracle_pkg.get_vendors_p (-)');

  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK;
      print_log ('ajcl_bc_vendors_to_oracle_pkg.get_vendors_p (!)');
      print_log ('Vendor: ' || v_vendorno);
      p_status := 'E';
      p_error_message := SQLCODE || ': ' || SQLERRM;

  END get_vendors_p;                            

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
                        p_count                    IN OUT   NUMBER,
                        p_error_message            OUT      VARCHAR2,
                        p_status                   OUT      VARCHAR2 ) IS

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
           -- 20240920
           state,
           -- 20240920
           zip,
           vendor_site_code,
           email_address,
           org_id,
           --
           atis_valid_vendor,
           sad,
           ajc_kingdee_translated_name,
           ajc_ap_revalidation_exclude,
           blocked,
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
      FROM ajcl_bc_vendors
     WHERE status IS NULL
       AND request_id IS NULL
       AND processed_date IS NULL;

    v_get_url                  VARCHAR2(2000);

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

    e_get                      EXCEPTION;
    e_vendor                   EXCEPTION;
    e_vendor_site              EXCEPTION;

    v_tbl_status_vendor        VARCHAR2(30);
    v_tbl_status_site          VARCHAR2(30);
    v_tbl_message              VARCHAR2(1000);

    v_clob_result              CLOB;
    v_country                  VARCHAR2(80);
    v_territory_short_name     fnd_territories_vl.territory_short_name%TYPE;
    -- 20240920 v_state                    po_vendor_sites_all.state%TYPE;

    v_vendor_type_lookup_code  VARCHAR2(100);

    v_payment_term_active      VARCHAR2(1);

    v_hold_all_payments_flag   po_vendor_sites_all.hold_all_payments_flag%TYPE;

  BEGIN

    print_log ( 'ajcl_bc_vendors_to_oracle_pkg.vendors_p (+)' );

    fnd_global.apps_initialize ( user_id => 0,
                                 resp_id => gv_ap_resp_id,
                                 resp_appl_id => 200 ); -- SQLAP

    mo_global.set_policy_context ('S', gv_org_id);
    /*
    v_get_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,
                                                              p_entity => 'VENDORS',
                                                              p_subentity => NULL,
                                                              p_method => 'GET',
                                                              p_company_id => gv_bc_company_id )
                 || '?$filter=systemmodifiedat gt ' || TO_CHAR(p_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');                                                              

    print_log ( 'v_get_url: ' || v_get_url );

    v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );

    print_log ( 'The created or modified vendors are obtained and inserted into the ajcl_bc_vendors table.' );

    INSERT
      INTO ajcl_bc_vendors 
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
             -- 20240920
             state,
             -- 20240920
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
             creation_date )
    SELECT systemid,
           no segment1,
           TRIM(name) vendor_name,
           vat_registration_num,
           DECODE(payment_terms,'TBD',NULL,' ',NULL,'',NULL,payment_terms) payment_terms,
           payment_method,
           address1,
           address2,
           country,
           DECODE(city,'TBD',NULL,' ',NULL,'',NULL,city) city,
           -- 20240920
           state,
           -- 20240920
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
           CASE
             WHEN ( blocked = '_x0020_' ) THEN
               NULL
             ELSE
               blocked
           END blocked,
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
                                            -- 20240920
                                            state                            VARCHAR2(4000)  path '$.county',
                                            -- 20240920
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
                                            oraclevendorIDAJCGINE            VARCHAR2(4000)  path '$.oraclevendorIDAJCGINE' ) );

    -- Se actualizan como SKIPPED aquellos que fueron modificados por usuarios que no existe en la lookup
    UPDATE ajcl_bc_vendors
       SET status = 'SKIPPED',
           processed_date = TRUNC(SYSDATE),
           request_id = gv_request_id
     WHERE status IS NULL
       AND request_id IS NULL
       AND processed_date IS NULL
       AND systemmodifiedby NOT IN ( SELECT user_security_id
                                       FROM ajc_bc_vend_cust_ifc_users
                                      WHERE bc_environment = gv_bc_environment
                                        AND company = 'LOG'
                                        AND type = 'VENDORS'
                                        AND enabled = 'Y' );

    p_count := SQL%ROWCOUNT;

    COMMIT;
    */

    -- 20240921
    get_vendors_p ( p_last_bc_processed_date => p_last_bc_processed_date,
                    p_count => p_count,
                    p_status => v_status,
                    p_error_message => p_error_message );

    print_log ( 'p_count: ' || p_count );

    IF ( v_status != 'S' ) THEN

      RAISE e_get;

    END IF; 
    -- 20240921

    FOR cv IN c_vendors LOOP

      BEGIN

        -- ----------- --
        -- Proveedores --
        -- ----------- --

        v_vendor_name := cv.vendor_name;
        p_count := p_count + 1;

        print_log ( 'Vendor Num: ' || cv.segment1 || 
                 ' | Vendor Name: ' || cv.vendor_name );

        IF ( cv.vendor_name IS NULL ) THEN

          v_tbl_status_vendor := 'ERROR';
          v_tbl_message := 'Vendor Name could not be null in BC.';
          RAISE e_vendor;

        END IF;

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

            print_log ('Vendor found for vendor number ' || cv.segment1 || '. vendor_id: ' || v_vendor_id);

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

                print_log ('Vendor found for vendor name ' || cv.vendor_name || '. vendor_id: ' || v_vendor_id);

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

        IF ( cv.payment_terms IS NOT NULL ) THEN

          v_terms_id := ajc_bc_create_entities_pkg.payment_terms_f ( cv.payment_terms, 'AP', gv_bc_company_id, gv_bc_environment );

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

        ELSIF ( cv.payment_method IS NULL AN
