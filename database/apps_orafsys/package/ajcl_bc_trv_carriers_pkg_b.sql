CREATE OR REPLACE PACKAGE BODY ajcl_bc_trv_carriers_pkg IS

-- Creation: SBANCHIERI 23-AUG-2022 

  

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    gv_log_seq := gv_log_seq + 1;

    ajcl_bc_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );



  END print_log;



  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    ajcl_bc_utils_pkg.insert_output_p ( gv_bc_ifc, p_message, gv_request_id );



  END print_output;



  PROCEDURE vendor_insert_p ( p_status   OUT   VARCHAR2,

                              p_count    OUT   NUMBER ) IS



    ajc_country_code_c	   VARCHAR2(10) := 'USA';

    terms_name_c		        AP_SUPPLIERS_INT.terms_name%TYPE := 'DUE ON REC'; -- 'DUE ON RECEIPT';

    pay_group_c		         VARCHAR2(10) := 'STCARRIER'; -- 'VENDOR';

    status_c		            VARCHAR2(10) := 'NEW';



    v_vendor_no           ajcl_bc_trv_vendors.no%TYPE;

    v_vendor_id           NUMBER;



    v_bc_status           ajcl_bc_trv_vendors.bc_status%TYPE;

    v_oracle_status       ajcl_bc_trv_vendors.oracle_status%TYPE;

    v_error_message       ajcl_bc_trv_vendors.error_message%TYPE;



    v_rec_cnt		           NUMBER := 0;

    stmt_v	             		NUMBER;

    error_code_v    	     NUMBER;

    error_text_v    	     VARCHAR2(200);

    interface_cnt_v	     	NUMBER := 0;

    int_temp_cnt_v		      NUMBER := 0;

    v_status 			          VARCHAR2(30);



    no_data_to_process	   EXCEPTION;

    data_copy_issue		     EXCEPTION; 



    CURSOR select_carrier IS

    SELECT DISTINCT carriernum, 

           carriername

      FROM ajcl_trv_carrier_int_temp;



    CURSOR select_carrier_site ( carrier_name_in   VARCHAR2 ) IS

    SELECT *

      FROM ajcl_trv_carrier_int_temp

     WHERE carriername = carrier_name_in

       FOR UPDATE OF status;



    CURSOR c_bc_vendor ( p_clob_result   IN   CLOB ) IS

    SELECT vendorno

      FROM json_table( p_clob_result,  

                       '$.value[*]' COLUMNS ( vendorno   VARCHAR2(4000)  path '$.vendorno' ) );



    v_url                 VARCHAR2(2000);

    v_clob_result         CLOB;



  BEGIN



    print_log ( 'ajcl_bc_trv_carriers_pkg.vendor_insert_p (+)');



    DELETE ajcl_trv_carrier_int_temp;

    COMMIT;



    stmt_v := 1;



    LOCK TABLE trv_carriers_interface IN EXCLUSIVE MODE NOWAIT;



    stmt_v := 3;



    INSERT 

      INTO ajcl_trv_carrier_int_temp 

         ( locationcode,

           addressline1,

           addressline2,

           city,

           state,

           postalcode,

           carrierlocationreference,

           carriernum,

           carriername,

           company_type,

           tax_id ) 

    SELECT locationcode,

           addressline1,

           addressline2,

           city,

           state,

           postalcode ,

           carrierlocationreference,

           carriernum,

           carriername,

           company_type,

           tax_id

      FROM trv_carriers_interface; 



    print_log ( '# Vendors inserted to ajcl_trv_carrier_int_temp from trv_carriers_interface: ' || SQL%ROWCOUNT );



    stmt_v := 4;



    COMMIT;



    stmt_v := 5;



    SELECT COUNT(1)

      INTO interface_cnt_v

      FROM trv_carriers_interface;



    print_log ( 'interface_cnt_v: ' || interface_cnt_v );



    stmt_v := 6;



    SELECT COUNT(1)

      INTO int_temp_cnt_v

      FROM ajcl_trv_carrier_int_temp;



    print_log ( 'int_temp_cnt_v: ' || int_temp_cnt_v );



    -- If all the data was copied to the temp table then clear out the interface table

    IF ( NVL(interface_cnt_v,999) = NVL(int_temp_cnt_v,998) ) THEN



      print_log ( 'DELETE TRV_CARRIERS_INTERFACE' );

      DELETE TRV_CARRIERS_INTERFACE;



      COMMIT;



    ELSE



      RAISE data_copy_issue;



    END IF;



    -- Process the data

    FOR carrier_rec IN select_carrier LOOP 



      print_log ( 'Carrier Name: ' || UPPER(carrier_rec.carriername) );

      v_vendor_no := NULL;



      print_log ( 'Determine if the vendor already exists in BC.' );

      stmt_v := 10;



      BEGIN



        v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                              p_entity => 'VENDORS',

                                                              p_subentity => NULL,

                                                              p_method => 'GET',

                                                              p_company_id => gv_bc_company_id )

                 || '?$filter=name eq ''' || UPPER(carrier_rec.carriername) || '''';



        v_clob_result := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



        FOR cv IN c_bc_vendor ( v_clob_result ) LOOP



          v_vendor_no := cv.vendorno; 



        END LOOP;



      EXCEPTION

        WHEN OTHERS THEN

          NULL;



      END;



      print_log ( 'v_vendor_no: ' || v_vendor_no );



      -- Se verifica si existe en Oracle

      BEGIN



        v_vendor_id := NULL;



        SELECT vendor_id

          INTO v_vendor_id

          FROM po_vendors

         WHERE UPPER(vendor_name) = UPPER(carrier_rec.carriername);



      EXCEPTION

        WHEN OTHERS THEN

          NULL;



      END;



      print_log ( 'v_vendor_id: ' || v_vendor_id );



      FOR site_rec in select_carrier_site ( carrier_rec.carriername ) LOOP



        BEGIN



          -- No existe ni en BC ni en Oracle

          IF ( v_vendor_no IS NULL AND v_vendor_id IS NULL ) THEN



            print_log ( 'Vendor does not exist in BC and Oracle.' );



            v_bc_status := 'NEW';

            v_oracle_status := 'NEW';

            v_error_message := NULL;

            v_status := 'Processed';



          ELSE



            v_bc_status := 'SKIPPED';

            v_oracle_status := 'SKIPPED';



            -- DO NOT CHANGE THIS TEXT

            v_error_message := 'A vendor with the same name already exists in Oracle/BC. Please, create the vendor (with a different name) and the integration source mapping manually in BC.';

            -- DO NOT CHANGE THIS TEXT



            v_status := 'Skipped';



            IF ( v_vendor_no IS NOT NULL ) THEN

              print_log ( 'Vendor exists in BC.' );

            END IF;



            IF ( v_vendor_id IS NOT NULL ) THEN

              print_log ( 'Vendor exists in Oracle.' );

            END IF;



          END IF;  



          INSERT 

            INTO ajcl_bc_trv_vendors

               ( bc_environment,

                 no,

                 name,

                 paymenttermscode,

                 vendorcategory,

                 blocked,

                 sad,

                 paymentmethodcode,

                 legacyvendorsitename,

                 address,

                 address2,

                 city,

                 -- 20240925

                 state,

                 -- 20240925

                 zipcode,

                 territorycode,

                 federalTaxClassification,

                 federalIDNo,

                 --

                 creation_date,

                 created_by,

                 last_update_date,

                 last_updated_by,

                 request_id,

                 oracle_status,

                 bc_status,

                 error_message )

        VALUES ( gv_bc_environment,

                 'TRV' || carrier_rec.carriernum, -- no

                 UPPER(carrier_rec.carriername), -- name

                 NVL(terms_name_c,'TBD'), -- payment_terms_code

                 pay_group_c, -- vendor_category

                 NULL, -- blocked NULL: NOT BLOCKED

                 -- 20240129

                 -- ajc_country_code_c, -- sad

                 carrier_rec.carriernum, -- sad

                 -- 20240129

                 'WIRE', -- payment_method_code

                 site_rec.locationcode, -- legacyvendorsitename

                 site_rec.addressline1, -- address

                 site_rec.addressline2, -- address2

                 NVL(SUBSTR(UPPER(site_rec.city),1,30),'TBD'), -- city

                 -- 20240925

                 site_rec.state,

                 -- 20240925

                 site_rec.postalcode, -- zipcode

                 SUBSTR(ajc_country_code_c,1,10), -- territorycode

                 site_rec.company_type, -- federalTaxClassification

                 site_rec.tax_id, -- FederalIDNo

                 --                   

                 SYSDATE, -- creation_date

                 gv_user_id, -- created_by

                 SYSDATE, -- last_update_date

                 gv_user_id, -- last_updated_by

                 gv_request_id,

                 v_oracle_status,

                 v_bc_status,

                 v_error_message ); 



		      END;



        UPDATE ajcl_trv_carrier_int_temp

         		SET status = v_status

		     		WHERE CURRENT OF select_carrier_site;



      END LOOP; -- site_rec



      v_rec_cnt := v_rec_cnt + 1;



    END LOOP; -- carrier_rec



    p_count := v_rec_cnt;



    COMMIT;



    stmt_v := 40;



    IF ( v_rec_cnt = 0 ) THEN



      RAISE no_data_to_process;



    END IF;



    p_status := 'S';



    print_log ( 'ajcl_bc_trv_carriers_pkg.vendor_insert_p (-)');



  EXCEPTION

    WHEN no_data_to_process THEN

      p_status := 'S';

      -- print_log('AJCL Turvo Carrier Interface Control Report');

      print_log('No Carriers found to process');



    WHEN data_copy_issue THEN

      p_status := 'E';

      -- print_log('AJCL Turvo Carrier Interface Control Report');

      print_log('ERROR Occurred copying the carrier data from the interface table to the temp table for processing.');

      print_log('Processing has stoppped. Contact the applications system administrator. ');



    WHEN OTHERS THEN

      p_status := 'E';

      error_code_v := SQLCODE;

      error_text_v := SQLERRM;

      print_log('Program encountered an unexpected error: ');

      print_log('Statement: '||stmt_v);

      print_log(to_char(error_code_v)||'-'||error_text_v);



  END vendor_insert_p;



  PROCEDURE oracle_creation_p ( p_status   OUT   VARCHAR2 ) IS



    CURSOR c_vendors IS

    SELECT *

      FROM ajcl_bc_trv_vendors

     WHERE oracle_status = 'NEW'

       AND request_id = gv_request_id

       AND bc_environment = gv_bc_environment

       AND oraclevendorid IS NULL; 



    v_vendor_exists    VARCHAR2(1);

    v_terms_id         NUMBER;



    v_vendor_id        NUMBER;

    v_vendor_site_id   NUMBER;

    v_country          VARCHAR2(10);



    v_status           VARCHAR2(200);

    v_exception_msg    VARCHAR2(3000);



  BEGIN



    print_log('ajcl_bc_trv_carriers_pkg.oracle_creation_p (+)');



    -- Se inicializa el ambiente

    EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE = ''AMERICAN''';

    dbms_application_info.set_client_info(gv_org_id);



    -- Get terms_id

    SELECT term_id 

      INTO v_terms_id

      FROM ap_terms

     WHERE name = 'DUE ON RECEIPT';



    print_log('v_terms_id: ' || v_terms_id);



    FOR cv IN c_vendors LOOP



      print_log('No.: ' || cv.no);



      v_vendor_exists := NULL;



      v_vendor_id := NULL;

      v_vendor_site_id := NULL;

      v_country := NULL;



      v_status := NULL;

      v_exception_msg := NULL;



      BEGIN



        SELECT DECODE(COUNT(1),0,'N','Y')

          INTO v_vendor_exists

          FROM po_vendors

         WHERE UPPER(vendor_name) = UPPER(cv.name);



        print_log('v_vendor_exists: ' || v_vendor_exists);



      EXCEPTION

        WHEN OTHERS THEN

          NULL;



      END;



      BEGIN



        IF ( v_vendor_exists = 'N' ) THEN



          -- Create Vendor

          AP_PO_VENDORS_APIS_PKG.insert_new_vendor ( p_vendor_name => cv.name,

                                                     p_vendor_type_lookup_code => NULL,

                                                     p_taxpayer_id => NULL,

                                                     p_tax_registration_id => NULL,

                                                     p_women_owned_flag => 'N',

                                                     p_small_business_flag => 'N',

                                                     p_minority_group_lookup_code => NULL, 

                                                     p_supplier_number => cv.no,

                                                     x_vendor_id => v_vendor_id,

                                                     x_status => v_status,

                                                     x_exception_msg => v_exception_msg,

                                                     p_employee_id => NULL,

                                                     p_source => 'NOT IMPORT',

                                                     p_what_to_import => NULL,

                                                     p_commit_size => 1000,

                                                     p_group_id => '-99' ); 





          print_log('v_vendor_id: ' || v_vendor_id);

          print_log('v_status: ' || v_status);

          print_log('v_exception_msg: ' || v_exception_msg);



          IF ( v_status = 'S' ) THEN



            print_log ( 'Vendor created. v_vendor_id: ' || v_vendor_id );



            UPDATE po_vendors

               SET segment1 = cv.no,

                   terms_id = v_terms_id,

                   pay_group_lookup_code = 'STCARRIER',

                   attribute2 = cv.sad,

                   global_attribute20 = 'AJCL_TRV_CARRIER_INT',

                   payment_method_lookup_code = 'WIRE'

             WHERE vendor_id = v_vendor_id;



            -- 20240606

            -- Se inserta la relacion en la tabla ajc_bplus_cust_xref

            BEGIN



                INSERT 

                  INTO ajc_bplus_cust_xref

                     ( bp_cust_id,

                       bp_cust_name,

                       oracle_cust_id,

                       last_update_date,

                       last_updated_by,

                       creation_date,

                       created_by,

                       source,

                       source_type,

                       oracle_vendor_id )

              VALUES ( cv.sad, -- bp_cust_id

                       cv.name, -- bp_cust_name

                       NULL, -- oracle_cust_id

                       SYSDATE,

                       0,

                       SYSDATE,

                       0,

                       'TURVO',

                       'VENDOR',

                       v_vendor_id );



              print_log ( 'Record is created in the ajc_bplus_cust_xref table.' );



            EXCEPTION 

              WHEN OTHERS THEN

                print_log ( 'Error creating record in table ajc_bplus_cust_xref. Error: ' || SQLERRM );



            END;

            -- 20240606



            BEGIN



              SELECT territory_code

                INTO v_country

                FROM fnd_territories_vl

               WHERE iso_territory_code = cv.territoryCode;



            EXCEPTION

              WHEN OTHERS THEN

                v_country := NULL;



            END;



            print_log ( 'Oracle Country: ' || v_country );



            -- Create Site

            AP_PO_VENDORS_APIS_PKG.insert_new_vendor_site( p_vendor_site_code => cv.legacyvendorsitename,

                                                           p_vendor_id => v_vendor_id,

                                                           p_org_id => gv_org_id,

                                                           p_address_line1 => cv.address,

                                                           p_address_line2 => cv.address2,

                                                           p_address_line3 => NULL,

                                                           p_address_line4 => NULL,

                                                           p_city => cv.city,

                                                           -- 20240925

                                                           -- p_state => NULL,

                                                           p_state => cv.state,

                                                           -- 20240925

                                                           p_zip => cv.zipcode,

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

                                                           p_hold_all_payments_flag => 'N',

                                                           p_duns_number => NULL,

                                                           p_group_id => '-99' );



            IF ( v_status = 'S' ) THEN



              print_log ( 'Vendor Site created. v_vendor_site_id: ' || v_vendor_site_id );



              UPDATE po_vendor_sites_all

                 SET global_attribute20 = 'AJCL_TRV_CARRIER_INT',

                     payment_method_lookup_code = 'WIRE',

                     terms_id = v_terms_id,

                     pay_group_lookup_code = 'STCARRIER'

               WHERE vendor_site_id = v_vendor_site_id;



              -- Se actualiza el oracle vendor id en la tabla que manda a BC

              UPDATE ajcl_bc_trv_vendors

                 SET oracle_status = 'SUCCESS',

                     oraclevendorid = v_vendor_id

               WHERE oracle_status = 'NEW'

                 AND no = cv.no

                 AND legacyvendorsitename = cv.legacyvendorsitename

                 AND request_id = gv_request_id

                 AND bc_environment = gv_bc_environment

                 AND oraclevendorid IS NULL;



              COMMIT;



            ELSE



              print_log ( 'Failed to create Vendor Site in Oracle. ' || v_exception_msg );



              UPDATE ajcl_bc_trv_vendors

                 SET oracle_status = 'ERROR',

                     error_message = 'Failed to create Vendor Site in Oracle.'

               WHERE oracle_status = 'NEW'

                 AND no = cv.no

                 AND legacyvendorsitename = cv.legacyvendorsitename

                 AND request_id = gv_request_id

                 AND bc_environment = gv_bc_environment

                 AND oraclevendorid IS NULL;



              COMMIT;



            END IF;



          ELSE



            print_log ( 'Failed to create Vendor in Oracle. ' || v_exception_msg );



            UPDATE ajcl_bc_trv_vendors

               SET oracle_status = 'ERROR',

                   error_message = 'Failed to create Vendor in Oracle.'

             WHERE oracle_status = 'NEW'

               AND no = cv.no

               AND legacyvendorsitename = cv.legacyvendorsitename

               AND request_id = gv_request_id

               AND bc_environment = gv_bc_environment

               AND oraclevendorid IS NULL;



            COMMIT;



          END IF;



        ELSE



          print_log ( 'Vendor already exists in Oracle.' );



          SELECT vendor_id

            INTO v_vendor_id

            FROM po_vendors

           WHERE vendor_name = UPPER(cv.name);



          print_log('v_vendor_id: ' || v_vendor_id);



          print_log ( 'Supplier Number (segment1) updated in Oracle.' );



          UPDATE po_vendors

             SET segment1 = cv.no

           WHERE vendor_id = v_vendor_id;



          UPDATE ajcl_bc_trv_vendors

             SET oracle_status = 'SUCCESS',

                 error_message = 'Vendor already exists in Oracle.',

                 oraclevendorid = v_vendor_id

           WHERE oracle_status = 'NEW'

             AND no = cv.no

             AND legacyvendorsitename = cv.legacyvendorsitename

             AND request_id = gv_request_id

             AND bc_environment = gv_bc_environment

             AND oraclevendorid IS NULL;



        END IF;



      EXCEPTION

        WHEN OTHERS THEN

          print_log ( 'Vendor and Site not created in Oracle due an error. Error: ' || SQLERRM );

          print_log ( 'v_exception_msg: ' || v_exception_msg );



          UPDATE ajcl_bc_trv_vendors

             SET oracle_status = 'ERROR',

                 error_message = 'General error creating vendor / site in Oracle. ' || v_exception_msg

           WHERE oracle_status = 'NEW'

             AND no = cv.no

             AND legacyvendorsitename = cv.legacyvendorsitename

             AND request_id = gv_request_id

             AND bc_environment = gv_bc_environment

             AND oraclevendorid IS NULL;



          COMMIT;



      END;



    END LOOP;



    p_status := 'S';



    print_log('ajcl_bc_trv_carriers_pkg.oracle_creation_p (-)');



  EXCEPTION  

    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_trv_carriers_pkg.oracle_creation_p (!). Error: ' || SQLERRM );



  END oracle_creation_p;



  PROCEDURE call_ws ( p_status   OUT   VARCHAR2,

                      p_count    OUT   NUMBER ) IS



    CURSOR c_vendors IS

    SELECT *

      FROM ajcl_bc_trv_vendors

     WHERE request_id = gv_request_id

       AND bc_environment = gv_bc_environment

       AND bc_status = 'NEW';                        



    v_url             VARCHAR2(2000);

    v_error_message   VARCHAR2(2000);

    v_body            VARCHAR2(2000);

    v_clob_result     CLOB;



  BEGIN



    print_log('ajcl_bc_trv_carriers_pkg.call_ws (+)');

    p_count := 0;



    -- 20250222

    -- Se actualizan los registros a reprocesar para que los levante el cursor

    BEGIN



      UPDATE ajcl_bc_trv_vendors

         SET bc_status = 'NEW',

             error_message = NULL, 

             json_data = NULL,

             json_data_response = NULL,

             request_id = gv_request_id

       WHERE request_id != gv_request_id

         AND bc_environment = gv_bc_environment

         AND bc_status NOT IN ('SUCCESS','SKIPPED','ERROR','REJECTED');



      print_log ( 'Registros a reprocesar: ' || SQL%ROWCOUNT );



      COMMIT;



    END;

    -- 20250222



    FOR cv IN c_vendors LOOP



      print_log ('Vendor No: ' || cv.no);



      v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                            p_entity => 'INBOUND VENDORS',

                                                            p_subentity => NULL,

                                                            p_method => 'POST',

                                                            p_company_id => gv_bc_company_id );



      print_log('v_url: ' || v_url);



      v_error_message := NULL;



      -- Se envia el vendor

      APEX_JSON.initialize_clob_output;

      APEX_JSON.open_object;



      APEX_JSON.write('vendorno',cv.no,true);

      APEX_JSON.write('name',cv.name,true);

      APEX_JSON.write('paymenttermscode',cv.paymenttermscode,true);

      APEX_JSON.write('vendorcategory',cv.vendorcategory,true);

      APEX_JSON.write('blocked',cv.blocked,true);

      APEX_JSON.write('sad',cv.sad,true);

      APEX_JSON.write('paymentmethodcode',cv.paymentmethodcode,true);

      APEX_JSON.write('legacyvendorsitenm',cv.legacyvendorsitename,true);

      APEX_JSON.write('address',cv.address,true);

      APEX_JSON.write('address2',cv.address2,true);

      APEX_JSON.write('city',cv.city,true);

      -- 20240925

      APEX_JSON.write('state',cv.state,true);

      -- 20240925

      APEX_JSON.write('postcode',cv.zipcode,true);

      APEX_JSON.write('territorycode',cv.territorycode,true);

      APEX_JSON.write('federalTaxClassif',cv.federalTaxClassification,true);

      APEX_JSON.write('federalIDNo',cv.federalIDNo,true);

      APEX_JSON.write('oraclevendorid',TO_CHAR(cv.oraclevendorid),true); 

      APEX_JSON.write('requestid',gv_request_id,true);



      APEX_JSON.close_object;



      v_body := APEX_JSON.get_clob_output;



      print_log ( 'v_body: ' || v_body );



      v_clob_result := ajcl_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => utl_url.escape(v_url),

                                                                  p_request_header_name1 => 'Content-Type',

                                                                  p_request_header_value1 => 'application/json;IEEE754Compatible=true',

                                                                  p_request_header_name2 => NULL,

                                                                  p_request_header_value2 => NULL,

                                                                  p_http_method => 'POST',

                                                                  p_body => v_body );



      print_log ( 'v_clob_result: ' || v_clob_result);

      APEX_JSON.free_output;



      IF ( INSTR(UPPER(v_clob_result),'"ERROR":') != 0 ) THEN



        print_log ( 'Error sending vendor.' );



        v_error_message := 'An error occurred while sending carrier: ' ||

                            SUBSTR(v_clob_result,INSTR(v_clob_result,'message') + 10);



        print_log ( v_error_message );



        UPDATE ajcl_bc_trv_vendors

           SET bc_status = 'ERROR',

               error_message = v_error_message,

               json_data = v_body,

               json_data_response = v_clob_result

         WHERE no = cv.no

           AND request_id = gv_request_id

           AND bc_environment = gv_bc_environment;



      ELSE



          UPDATE ajcl_bc_trv_vendors

             SET bc_status = 'SENT',

                 json_data = v_body,

                 json_data_response = v_clob_result

           WHERE no = cv.no

             AND request_id = gv_request_id

             AND bc_environment = gv_bc_environment;



          p_count := p_count + 1;

          print_log ( 'The vendor was sent successfully.' );



      END IF;



    END LOOP;



    p_status := 'S';

    print_log('ajcl_bc_trv_carriers_pkg.call_ws (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log('ajcl_bc_trv_carriers_pkg.call_ws (!)');      



  END call_ws;



  PROCEDURE call_job ( p_status   OUT   VARCHAR2 ) IS



    v_job_object_id     NUMBER;

    v_status            VARCHAR2(20);

    v_clob_response     CLOB;



  BEGIN



    print_log ('ajcl_bc_trv_carriers_pkg.call_job (+)');



    v_job_object_id := ajcl_bc_ws_utils_pkg.get_object_id_f ( 'VENDORS' ); 

    print_log('v_job_object_id: ' || v_job_object_id || ' - ' || TO_CHAR(SYSDATE,'YYYY-MM-DD HH24:MI:SS'));



    v_clob_response := ajcl_bc_ws_utils_pkg.run_job_queue_f ( p_bc_environment => gv_bc_environment,

                                                              p_company_id => gv_bc_company_id,

                                                              p_object_id => v_job_object_id );



    print_log('v_clob_response: ' || v_clob_response);



    IF ( INSTR(UPPER(v_clob_response),'ERROR') = 0 ) THEN



      print_log('Vendors job was executed successfully.');

      v_status := 'SUCCESS';

      p_status := 'S';



    ELSE



      print_log('An error occurred while running Vendors job.');

      v_status := 'ERROR';

      p_status := 'E';



    END IF;



    -- Se inserta registro de control

    INSERT

      INTO ajcl_bc_trv_vendors_control

           ( bc_environment,

             request_id,

             org_id,

             status,

             job_response,

             creation_date )

    VALUES ( gv_bc_environment,

             gv_request_id, 

             gv_org_id,

             v_status,

             v_clob_response,

             SYSDATE );



    print_log ('ajcl_bc_trv_carriers_pkg.call_job (-)');



  EXCEPTION    

    WHEN OTHERS THEN

      p_status := 'E';

      print_log ( 'Not caught error when calling Vendors job. Error: ' || SQLERRM );

      print_log ('ajcl_bc_trv_carriers_pkg.call_job (!)');



  END call_job;



  PROCEDURE call_ws_delete ( p_no              IN       VARCHAR2,

                             p_error_message   IN OUT   VARCHAR2,

                             p_status          IN OUT   VARCHAR2 ) IS



    v_url               VARCHAR2(2000);

    v_error_message     VARCHAR2(2000);

    v_clob_response     CLOB;

    e_cust_exception    EXCEPTION;



  BEGIN



    print_log ('ajcl_bc_trv_carriers_pkg.call_ws_delete (+)');



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                          p_entity => 'INBOUND VENDORS',

                                                          p_subentity => NULL,

                                                          p_method => 'DEL',

                                                          p_company_id => gv_bc_company_id )

             || '(''' || p_no || ''')'; 



    print_log ( 'v_url: ' || v_url );



    -- Se borra el vendor de la tabla staging

    v_clob_response := ajcl_bc_ws_utils_pkg.delete_bc_row_f ( v_url );



    IF ( UPPER(v_clob_response) LIKE '%"ERROR":%' ) THEN



      v_error_message := SUBSTR(v_clob_response,INSTR(v_clob_response,'message')+9,LENGTH(v_clob_response));

      RAISE e_cust_exception;



    ELSE



      p_status := 'S';



    END IF;



    print_log ('ajcl_bc_trv_carriers_pkg.call_ws_delete (-)');



   EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_trv_carriers_pkg.call_ws_delete (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));



    WHEN others THEN

      v_error_message := 'Not caught error when delete General Journal Inbounds. Error: ' || SQLERRM;

      p_status := 'E';

      p_error_message := v_error_message;

      print_log (p_error_message);

      print_log ('ajcl_bc_trv_carriers_pkg.call_ws_delete (!). ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'));



  END call_ws_delete;



  PROCEDURE call_status ( p_status   OUT   VARCHAR2 ) IS



    e_cust_exception       EXCEPTION;

    v_url                  VARCHAR2(2000);

    v_clob_response        CLOB;



    v_cant_sin_procesar    NUMBER;

    v_stime                NUMBER;

    v_etime                NUMBER;



    v_status               VARCHAR2(1);

    v_error_message        VARCHAR2(2000);



    CURSOR c_status ( p_clob_result_status   IN   CLOB ) IS

    SELECT vendorno,

           name,

           address,

           address2,

           status,

           statusremarks,

           requestid

      FROM json_table( p_clob_result_status,

                       '$.value[*]' COLUMNS ( vendorno          VARCHAR2(4000)  path '$.vendorno',

                                              name              VARCHAR2(4000)  path '$.name',

                                              address           VARCHAR2(4000)  path '$.address',

                                              address2          VARCHAR2(4000)  path '$.address2',

                                              status            VARCHAR2(4000)  path '$.status',

                                              statusremarks     VARCHAR2(4000)  path '$.statusremarks',

                                              requestid         VARCHAR2(4000)  path '$.requestid' ) );



  BEGIN



    print_log ('ajcl_bc_trv_carriers_pkg.call_status (+)');



    v_url := ajcl_bc_ws_utils_pkg.get_base_custom_url_f ( p_bc_environment => gv_bc_environment,

                                                          p_entity => 'INBOUND VENDORS',

                                                          p_subentity => NULL,

                                                          p_method => 'GET',

                                                          p_company_id => gv_bc_company_id )

             || '?$filter=requestid eq ' || gv_request_id;



    print_log ( 'v_url: ' || v_url );



    v_cant_sin_procesar := -1;



    -- seteo tiempo de inicio

    SELECT TO_NUMBER(((TO_CHAR(SYSDATE, 'J') - 1 ) * 86400) + TO_CHAR(SYSDATE, 'SSSSS'))

      INTO v_stime

      FROM DUAL;



    WHILE v_cant_sin_procesar <> 0 LOOP



      BEGIN



        v_clob_response := ajcl_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_url );



      EXCEPTION

        WHEN OTHERS THEN

          NULL;



      END;



      SELECT COUNT(*)

        INTO v_cant_sin_procesar

        FROM json_table( v_clob_response,

                         '$.value[*]' COLUMNS ( status      VARCHAR2(4000) path '$.status',

                                                requestid   VARCHAR2(4000) path '$.requestid'))

       WHERE requestid = gv_request_id

         AND status NOT IN ('Error','Success');



      print_log ( 'Number of unprocessed records: ' || v_cant_sin_procesar );



      IF v_cant_sin_procesar <> 0 THEN



        SELECT TO_NUMBER(((TO_CHAR(SYSDATE, 'J') - 1 ) * 86400) + TO_CHAR(SYSDATE, 'SSSSS'))

          INTO v_etime

          FROM DUAL;



        print_log ( 'v_etime: ' || v_etime );



        IF ( ( v_etime - v_stime ) >= 600 ) THEN



          print_log ( 'Waiting for the job took more than 600 seconds. All records will be marked REJECTED.' );

          EXIT;



        END IF;



        print_log ( 'I wait 15 seconds' );  

        DBMS_LOCK.sleep(15);



      END IF;



    END LOOP;



    print_log ( 'Status: ' );



    FOR cs IN c_status ( v_clob_response ) LOOP



      IF ( cs.status != 'Success' ) THEN



        print_log ( 'vendorno: ' || cs.vendorno || 

                    ' | name: ' || cs.name || 

                    ' | address: ' || cs.address || 

                    ' | address2: ' || cs.address2 || 

                    ' | status: ' || cs.status || 

                    ' | statusremarks: ' || cs.statusremarks);



        -- print_log ( ' ' );



        -- Se actualiza la tabla custom con el status REJECTED

        UPDATE ajcl_bc_trv_vendors

           SET bc_status = 'REJECTED',

               error_message = cs.statusremarks

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND no = cs.vendorno;



        -- Se borra el vendor de las tabla inbound

        call_ws_delete ( p_no => cs.vendorno,

                         p_error_message => v_error_message,

                         p_status => v_status );



      ELSE



        -- Se actualiza la tabla custom con el status IMPORTED

        UPDATE ajcl_bc_trv_vendors

           SET bc_status = 'SUCCESS'

         WHERE request_id = gv_request_id

           AND bc_environment = gv_bc_environment

           AND no = cs.vendorno;



      END IF;



    END LOOP;



    p_status := 'S';



    print_log ('ajcl_bc_trv_carriers_pkg.call_status (-)');   



  EXCEPTION

    WHEN e_cust_exception THEN

      p_status := 'E';

      print_log (v_error_message);

      print_log ('ajcl_bc_trv_carriers_pkg.call_status (!)');



    WHEN others THEN

      p_status := 'E';

      print_log ( 'Not caught error when checking status. Error: ' || SQLERRM );

      print_log ('ajcl_bc_trv_carriers_pkg.call_status (!)');



  END call_status;



  PROCEDURE final_report_csv_p ( p_status   OUT   VARCHAR2 ) IS



      CURSOR c_vendors IS

      SELECT v.no,

             v.name,

             v.address,

             v.address2,

             v.oracle_status,

             v.bc_status,

             v.error_message

        FROM ajcl_bc_trv_vendors v

       WHERE v.request_id = gv_request_id

         AND bc_environment = gv_bc_environment

    ORDER BY v.no;



  BEGIN



    print_log( 'ajcl_bc_trv_carriers_pkg.final_report_csv_p (+)' ); 



    -- Insert Report Title

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => gv_bc_ifc || ' Report',

                                        p_request_id => gv_request_id );

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'Request ID|' || gv_request_id,

                                        p_request_id => gv_request_id );         



    -- Fila vacia

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc, p_text => ' ', p_request_id => gv_request_id );



    -- Tabla 1 -----------------------------------------------------------------------------------------------------------------                                    

    -- Insert Table Column Names                            

    ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                        p_text => 'No' || '|' ||

                                                  'Name' || '|' ||

                                                  'Address' || '|' ||

                                                  'Address 2' || '|' ||

                                                  'Oracle Status' || '|' ||

                                                  'BC Status' || '|' ||

                                                  'Message',

                                        p_request_id => gv_request_id );                                        



    -- Se insertan los registros

    FOR cv IN c_vendors LOOP



      ajcl_bc_utils_pkg.insert_report_p ( p_ifc => gv_bc_ifc,

                                          p_text => cv.no || '|' || 

                                                    cv.name || '|' || 

                                                    cv.address || '|' || 

                                                    cv.address2 || '|' || 

                                                    cv.oracle_status || '|' || 

                                                    cv.bc_status || '|' || 

                                                    cv.error_message,

                                          p_request_id => gv_request_id );  



    END LOOP;



    p_status := 'S';



    print_log( 'ajcl_bc_trv_carriers_pkg.final_report_csv_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_trv_carriers_pkg.final_report_csv_p (!). Error: ' || SQLERRM );



  END final_report_csv_p;



  PROCEDURE final_report_xlsx_p ( p_status   OUT   VARCHAR2 ) IS



    c_cursor   SYS_REFCURSOR;



  BEGIN



    print_log( 'ajcl_bc_trv_carriers_pkg.final_report_xlsx_p (+)' );



    gv_directory_report := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_REPORT' );



    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc || ' Report',

                                                p_request_id => gv_request_id,

                                                p_bc_environment => gv_bc_environment,

                                                p_jenkins_build_number => gv_jenkins_build_number );



      OPEN c_cursor FOR

      SELECT v.no,

             v.name,

             UPPER(v.oracle_status) oracle_status,

             UPPER(v.bc_status) bc_status,

             v.error_message,

             v.federalTaxClassification federal_tax_classif,

             v.federalIDNo federal_id_no,

             -- 20240925

             v.vendorcategory vendor_category,

             v.sad,

             v.legacyvendorsitename legacy_vendor_site_name,

             v.address,

             v.address2,

             v.territorycode territory_code,

             v.city,

             v.state,

             v.zipcode zip_code,

             v.paymenttermscode payment_terms_code,

             v.paymentmethodcode payment_method_code

             -- 20240925             

        FROM ajcl_bc_trv_vendors v

       WHERE v.request_id = gv_request_id

         AND bc_environment = gv_bc_environment

    ORDER BY v.no;



    ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => 'Carriers',

                                       p_sheet => 2,

                                       p_cursor => c_cursor );



    as_xlsx.save ( gv_directory_report, gv_report_filename || '.' || LOWER(gv_file_format) );



    p_status := 'S';



    print_log( 'ajcl_bc_trv_carriers_pkg.final_report_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_trv_carriers_pkg.final_report_xlsx_p (!). Error: ' || SQLERRM );



  END final_report_xlsx_p;



  PROCEDURE main_bc_p ( p_status   IN OUT   VARCHAR2 ) IS



    v_phase           VARCHAR2(200);



    v_status          VARCHAR2(1);

    v_error_message   VARCHAR2(2000);



    -- VENDORS

    v_count_ins       NUMBER;

    v_count_ws        NUMBER;



    e_error           EXCEPTION;

    e_exception       EXCEPTION;



  BEGIN



    print_log('ajcl_bc_trv_carriers_pkg.main_bc_p (+)');



    -- AJCL TRV Carrier Interface

    vendor_insert_p ( p_status => v_status,

                      p_count => v_count_ins );



    print_log ( 'v_count_ins: ' || v_count_ins );



    IF ( v_status != 'S' ) THEN



      v_phase := 'vendor_insert_p';

      RAISE e_exception;



    END IF;



    oracle_creation_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'v_oracle_creation_p';

      RAISE e_exception;



    END IF;



    BEGIN



      -- Lock & Release

      ajc_bc_dbms_lock_pkg.lock_p ( p_process_name => gv_process_name,

                                    p_id_lock => gv_id_lock,

                                    p_request_status => gv_request_status ); 



      IF ( gv_request_status != 'success' ) THEN



        RAISE ge_lock;



      END IF;

      -- Lock & Release



      call_ws ( p_status => v_status,

                p_count => v_count_ws );



      print_log ( 'v_count_ws: ' || v_count_ws );



      IF ( v_status != 'S' ) THEN



        v_phase := 'call_ws';

        RAISE e_error;



      END IF;



      -- Si se envió al menos un vendor, se ejecuta el job

      IF ( v_count_ws > 0 ) THEN



        -- Se ejecuta el JOB -----------------------------------------------------------------------------------------------------

        call_job ( p_status => v_status );



        IF v_status != 'S' THEN



          v_phase := 'call_job';

          RAISE e_error;



        END IF;



        -- Verifico el status de los vendors procesados por el job -------------------------------------------------------------

        call_status ( p_status => v_status );



        IF v_status != 'S' THEN



          v_phase := 'call_status';

          RAISE e_error;



        END IF;



      END IF;



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );



      IF ( gv_release_status != 'success' ) THEN



        RAISE ge_release;



      END IF;                                     

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------



      -- 20250222 

      -- IF ( v_count_ins > 0 ) THEN

      -- Permite atajar los reprocesados

      IF ( v_count_ins > 0 OR v_count_ws > 0 ) THEN

      -- 



        -- INSERT VENDORS REPORT IN TABLE AJCL_BC_REPORTS ----------------------------------------------------------------------

        IF ( gv_file_format = 'CSV' ) THEN



          final_report_csv_p ( p_status => v_status );     



          IF ( v_status != 'S' ) THEN



            v_phase := 'final_report_csv_p';

            RAISE e_exception;



          END IF;  



          -- CREATE CSV FROM TABLE AJCL_BC_REPORTS --------------------------------------------------------------------------------

          ajcl_bc_utils_pkg.create_csv_p ( p_ifc => gv_bc_ifc,

                                           p_request_id => gv_request_id,

                                           p_log_seq => gv_log_seq,

                                           p_type => 'REPORT',

                                           p_filename => gv_report_filename,

                                           p_status => v_status );



          IF ( v_status != 'S' ) THEN



            v_phase := 'create_csv_p | REPORT';

            RAISE e_exception;



          END IF;



        ELSIF ( gv_file_format = 'XLSX' ) THEN 



          -- No inserta en tabla, genera el xlsx directamente en el filesystem

          final_report_xlsx_p ( p_status => v_status );     



          IF ( v_status != 'S' ) THEN



            v_phase := 'final_report_xlsx_p';

            RAISE e_exception;



          END IF;  



        END IF;



        -- MAIL REPORT -----------------------------------------------------------------------------------------------------------

        BEGIN



          ajcl_bc_utils_pkg.send_mail_with_attach ( p_to_mail => gv_email,

                                                    p_subject => gv_bc_ifc || ' Report - ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                                    p_body => gv_bc_ifc || ' Report.',

                                                    p_type => 'REPORT',

                                                    p_filename => gv_report_filename,    

                                                    p_file_format => gv_file_format,

                                                    p_attach_filename => gv_bc_ifc || ' Report ' || TO_CHAR(SYSDATE,'MMDDYYYY HH24MISS') || ' ' || gv_bc_environment || '.' || LOWER(gv_file_format) );



        EXCEPTION

          WHEN OTHERS THEN

            print_log ( 'SMTP NOT WORKING.' );



        END;                                                      



      ELSE



        print_log ('No carriers to process.');



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                         p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => 'No carriers to process.' || CHR(10) || 'Request ID: ' || gv_request_id );



      END IF;



    EXCEPTION

      WHEN e_error THEN

        print_log ( 'e_error' );

        RAISE e_exception;



      WHEN OTHERS THEN

        print_log ( 'General error Vendors.' );

        RAISE e_exception;



    END;



    print_log('ajcl_bc_trv_carriers_pkg.main_bc_p (-)');



  EXCEPTION

    -- dbms_lock ---------------------------------------------------------------------------------------------------------------

    WHEN ge_lock THEN 

      p_status := 'E';

      print_log ('ajcl_bc_trv_carriers_pkg.main_bc_p. Error when trying to lock the process ' || gv_process_name || 

              ' | request_status: ' || gv_request_status);

    -- dbms_lock ---------------------------------------------------------------------------------------------------------------



    WHEN e_exception THEN

      p_status := 'E';

      print_log (v_error_message);



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------



      print_log( 'ajcl_bc_trv_carriers_pkg.main_bc_p (!)' );



    WHEN OTHERS THEN

      p_status := 'E';

      print_log ( 'Phase: ' || v_phase );



      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------

      ajc_bc_dbms_lock_pkg.release_p ( p_id_lock => gv_id_lock,

                                       p_release_status => gv_release_status );  

      -- dbms_lock - Release ---------------------------------------------------------------------------------------------------



      print_log( 'ajcl_bc_trv_carriers_pkg.bc_p (!). Error: ' || SQLERRM );



  END main_bc_p;   



  PROCEDURE main_p ( p_bc_environment         IN   VARCHAR2,

                     p_jenkins_build_number   IN   VARCHAR2 ) IS



    v_run_id            NUMBER;



    v_status            VARCHAR(1);

    v_phase             VARCHAR2(200);

    e_error             EXCEPTION;



    v_error_msg         VARCHAR2(4000);

    e_parameter_value   EXCEPTION;



  BEGIN



    gv_request_id := ajcl_bc_utils_pkg.get_request_id_f;

    gv_jenkins_build_number := p_jenkins_build_number;



    -- Se inserta el concurrent_job

    ajcl_bc_utils_pkg.ins_jenkins_concurrent_job_p ( p_request_id => gv_request_id,

                                                     p_job_name => gv_bc_ifc,

                                                     p_jenkins_build_number => p_jenkins_build_number,

                                                     p_argument1 => p_bc_environment );



    print_log ( 'ajcl_bc_trv_carriers_pkg.main_p (+)');

    print_log ( 'gv_request_id: ' || gv_request_id );



    gv_file_format := ajcl_bc_ws_utils_pkg.get_parameter_f ( 'FILE_FORMAT' );

    print_log( 'FILE_FORMAT: ' || gv_file_format ); 



    gv_email := ajcl_bc_utils_pkg.get_emails_f ( 'TRV CARRIERS' );

    print_log( 'gv_email: ' || gv_email );



    gv_process_name := ajcl_bc_ws_utils_pkg.get_lock_process_name_f ( p_integration => 'VENDORS' );

    print_log ( 'gv_process_name: ' || gv_process_name );



    -- Validacion parametro p_bc_environment -----------------------------------------------------------------------------------

    IF ( ajcl_bc_utils_pkg.is_bc_environment_valid_f ( p_bc_environment ) = 'N' ) THEN



      v_error_msg := 'Invalid value (' || p_bc_environment || ') for parameter BC_ENVIRONMENT.';

      RAISE e_parameter_value;



    END IF;



    gv_bc_environment := p_bc_environment;

    print_log ( 'gv_bc_environment: ' || gv_bc_environment );



    -- Se obtienen los parametros de la company 

    print_log ( 'gv_bc_company_name: ' || gv_bc_company_name ); 



    gv_org_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                              p_column => 'ORG_ID' );



    print_log ( 'gv_org_id: ' || gv_org_id );



    gv_bc_company_id := ajcl_bc_utils_pkg.get_company_parameters_p ( p_bc_company_name => gv_bc_company_name,

                                                                     p_column => 'BC_COMPANY_ID' );



    print_log ( 'gv_bc_company_id: ' || gv_bc_company_id );



    main_bc_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      v_phase := 'main_bc_p';

      RAISE e_error;



    END IF;



    -- Se actualiza el concurrent_job

    ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'S' );



    print_log('ajcl_bc_trv_carriers_pkg.main_p (-)');



  EXCEPTION 

    WHEN e_parameter_value THEN

      print_log('ajcl_bc_trv_carriers_pkg.main_p (!)');

      print_log(v_error_msg);



      BEGIN



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                         p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => v_error_msg );



      EXCEPTION

        WHEN OTHERS THEN

          print_log ( 'SMTP NOT WORKING.' );



      END;  



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );   



      RAISE_APPLICATION_ERROR(-20000,'Error: ' || v_error_msg );



    WHEN e_error THEN

      print_log('ajcl_bc_trv_carriers_pkg.main_p (!)');

      print_log(v_phase);



      BEGIN



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                         p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => 'Error at phase ' || v_phase );



      EXCEPTION

        WHEN OTHERS THEN

          print_log ( 'SMTP NOT WORKING.' );



      END;  



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );         



      RAISE_APPLICATION_ERROR(-20000,'Error at phase: ' || v_phase );



    WHEN OTHERS THEN

      print_log('ajcl_bc_trv_carriers_pkg.main_p (!). General Error: ' || SQLERRM);     



      BEGIN



        ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                         p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_bc_environment || ' (' || gv_jenkins_build_number || ')',

                                         p_message => 'General Error: ' || SQLERRM );



      EXCEPTION

        WHEN OTHERS THEN

          print_log ( 'SMTP NOT WORKING.' );



      END;                                           



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );         



      RAISE_APPLICATION_ERROR(-20000,'General Error: ' || SQLERRM ); 



  END main_p;



END ajcl_bc_trv_carriers_pkg;
