CREATE OR REPLACE PACKAGE BODY ajcl_bc_trv_data_load_pkg IS

-- Creation: SBANCHIERI 25-JUN-2024

  

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    gv_log_seq := gv_log_seq + 1;

    ajcl_bc_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );



  END print_log;



  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    ajcl_bc_utils_pkg.insert_output_p ( gv_bc_ifc, p_message, gv_request_id );



  END print_output;



  PROCEDURE print_output_xlsx ( p_section      VARCHAR2,

                                p_column1      VARCHAR2,

                                p_column2      VARCHAR2 DEFAULT NULL,

                                p_column3      VARCHAR2 DEFAULT NULL,

                                p_column4      VARCHAR2 DEFAULT NULL,

                                p_column5      VARCHAR2 DEFAULT NULL,

                                p_column6      VARCHAR2 DEFAULT NULL,

                                p_column7      VARCHAR2 DEFAULT NULL,

                                p_column8      VARCHAR2 DEFAULT NULL,

                                p_column9      VARCHAR2 DEFAULT NULL,

                                p_column10     VARCHAR2 DEFAULT NULL,

                                p_column11     VARCHAR2 DEFAULT NULL,

                                p_column12     VARCHAR2 DEFAULT NULL,

                                p_column13     VARCHAR2 DEFAULT NULL,

                                p_column14     VARCHAR2 DEFAULT NULL,

                                p_column15     VARCHAR2 DEFAULT NULL,

                                p_column16     VARCHAR2 DEFAULT NULL,

                                p_column17     VARCHAR2 DEFAULT NULL,

                                p_column18     VARCHAR2 DEFAULT NULL,

                                p_column19     VARCHAR2 DEFAULT NULL,

                                p_column20     VARCHAR2 DEFAULT NULL ) IS

  BEGIN



    ajcl_bc_utils_pkg.insert_output_xlsx_p ( p_ifc => gv_bc_ifc,

                                             p_section => p_section,

                                             p_column1 => p_column1,

                                             p_column2 => p_column2,

                                             p_column3 => p_column3,

                                             p_column4 => p_column4,

                                             p_column5 => p_column5,

                                             p_column6 => p_column6,

                                             p_column7 => p_column7,

                                             p_column8 => p_column8,

                                             p_column9 => p_column9,

                                             p_column10 => p_column10,

                                             p_column11 => p_column11,

                                             p_column12 => p_column12,

                                             p_column13 => p_column13,

                                             p_column14 => p_column14,

                                             p_column15 => p_column15,

                                             p_column16 => p_column16,

                                             p_column17 => p_column17,

                                             p_column18 => p_column18,

                                             p_column19 => p_column19,

                                             p_column20 => p_column20,

                                             p_request_id => gv_request_id );



  END print_output_xlsx;



  PROCEDURE final_output_xlsx_p ( p_status   OUT   VARCHAR2 ) IS



    v_query     VARCHAR2(2000);

    c_cursor    SYS_REFCURSOR;

    v_sheet     NUMBER := 1;



      CURSOR c_sections IS

      SELECT *

        FROM ajcl_bc_outputs_xlsx

       WHERE ifc = gv_bc_ifc

         AND request_id = gv_request_id

         AND seq IN ( SELECT MIN(seq)

                        FROM ajcl_bc_outputs_xlsx

                       WHERE ifc = gv_bc_ifc

                         AND request_id = gv_request_id

                    GROUP BY section )

    ORDER BY seq;    



  BEGIN



    print_log( 'ajcl_bc_trv_data_load_pkg.final_output_xlsx_p (+)' );



    gv_directory_output := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_OUTPUT' );



    ajcl_bc_utils_pkg.create_rep_info_sheet_p ( p_report_title => gv_bc_ifc || ' Output',

                                                p_request_id => gv_request_id,

                                                p_bc_environment => NULL,

                                                p_jenkins_build_number => gv_jenkins_build_number,

                                                --

                                                p_param_1_title => ' ',

                                                p_param_1_value => ' ',

                                                p_param_2_title => 'RUN ID',

                                                p_param_2_value => gv_run_id );



    FOR cs IN c_sections LOOP



      v_sheet := v_sheet + 1;



      v_query := 'SELECT column1 "' || cs.column1 || '"';



      IF ( cs.column2 IS NOT NULL ) THEN

        v_query := v_query || ', column2 "' || cs.column2 || '"';

      END IF;  



      IF ( cs.column3 IS NOT NULL ) THEN

        v_query := v_query || ', column3 "' || cs.column3 || '"';

      END IF;



      IF ( cs.column4 IS NOT NULL ) THEN

        v_query := v_query || ', column4 "' || cs.column4 || '"';

      END IF; 



      IF ( cs.column5 IS NOT NULL ) THEN

        v_query := v_query || ', column5 "' || cs.column5 || '"';

      END IF;



      IF ( cs.column6 IS NOT NULL ) THEN

        v_query := v_query || ', column6 "' || cs.column6 || '"';

      END IF;



      IF ( cs.column7 IS NOT NULL ) THEN

        v_query := v_query || ', column7 "' || cs.column7 || '"';

      END IF;



      IF ( cs.column8 IS NOT NULL ) THEN

        v_query := v_query || ', column8 "' || cs.column8 || '"';

      END IF;



      IF ( cs.column9 IS NOT NULL ) THEN

        v_query := v_query || ', column9 "' || cs.column9 || '"';

      END IF;



      IF ( cs.column10 IS NOT NULL ) THEN

        v_query := v_query || ', column10 "' || cs.column10 || '"';

      END IF;



      IF ( cs.column11 IS NOT NULL ) THEN

        v_query := v_query || ', column11 "' || cs.column11 || '"';

      END IF;



      IF ( cs.column12 IS NOT NULL ) THEN

        v_query := v_query || ', column12 "' || cs.column12 || '"';

      END IF;



      IF ( cs.column13 IS NOT NULL ) THEN

        v_query := v_query || ', column13 "' || cs.column13 || '"';

      END IF;



      IF ( cs.column14 IS NOT NULL ) THEN

        v_query := v_query || ', column14 "' || cs.column14 || '"';

      END IF;



      IF ( cs.column15 IS NOT NULL ) THEN

        v_query := v_query || ', column15 "' || cs.column15 || '"';

      END IF;



      IF ( cs.column16 IS NOT NULL ) THEN

        v_query := v_query || ', column16 "' || cs.column16 || '"';

      END IF;



      IF ( cs.column17 IS NOT NULL ) THEN

        v_query := v_query || ', column17 "' || cs.column17 || '"';

      END IF;



      IF ( cs.column18 IS NOT NULL ) THEN

        v_query := v_query || ', column18 "' || cs.column18 || '"';

      END IF;



      IF ( cs.column19 IS NOT NULL ) THEN

        v_query := v_query || ', column19 "' || cs.column19 || '"';

      END IF;



      IF ( cs.column20 IS NOT NULL ) THEN

        v_query := v_query || ', column20 "' || cs.column20 || '"';

      END IF;



      v_query := v_query || ' FROM AJCL_BC_OUTPUTS_XLSX' ||

                           ' WHERE ifc = ''' || gv_bc_ifc || '''' ||

                             ' AND request_id = ' || gv_request_id ||

                             ' AND section = ''' || cs.section || '''' ||

                             ' AND seq != ' || cs.seq || -- No se incluye la fila que contiene los nombres de las columnas

                             ' ORDER BY seq';



      OPEN c_cursor FOR v_query;



      ajcl_bc_utils_pkg.create_sheet_p ( p_sheet_title => cs.section,

                                         p_sheet => v_sheet,

                                         p_cursor => c_cursor );



    END LOOP;



    as_xlsx.save ( gv_directory_output, gv_output_filename || '.' || LOWER(gv_file_format) );



    p_status := 'S';



    print_log( 'ajcl_bc_trv_data_load_pkg.final_output_xlsx_p (-)' );



  EXCEPTION

    WHEN OTHERS THEN

      p_status := 'E';

      print_log( 'ajcl_bc_trv_data_load_pkg.final_output_xlsx_p (!). Error: ' || SQLERRM );



  END final_output_xlsx_p;



  PROCEDURE process_data_load_p ( p_status   IN OUT   VARCHAR2,

                                  p_error_msg   OUT   VARCHAR2 ) IS



    carrier_inv_cnt_v		         NUMBER := 0;

    customer_inv_cnt_v		        NUMBER := 0;

    route_qa_cnt_v			           NUMBER := 0;

    latest_run_id_v			          NUMBER := NULL;

    num_correctables_v		        NUMBER := 0;

    num_not_interfaced_v		      NUMBER := 0;

    num_missing_cust_vend_v	   	NUMBER := 0;



      CURSOR c_report IS

      SELECT xml_file_type, 

             TO_CHAR(COUNT(1),'999,999,999') file_type_cnt

        FROM AJC_TRV_INTERFACE

       WHERE oracle_xml_run_id = ( SELECT MAX(oracle_xml_run_id) 

                                     FROM AJC_TRV_INTERFACE )

    GROUP BY xml_file_type

    ORDER BY xml_file_type;



    v_columns                   VARCHAR2(2000);

    v_status                    VARCHAR2(1);

    e_error                     EXCEPTION;



  BEGIN



    print_log('ajcl_bc_trv_data_load_pkg.process_data_load_p (+)');



    -- Verify there is data in the staging tables

    SELECT COUNT(1) 

      INTO customer_inv_cnt_v 

      FROM TRV_CUSTOMER_INVOICE_INTERFACE; 



    print_log ( 'customer_inv_cnt_v: ' || customer_inv_cnt_v );



    SELECT COUNT(1) 

      INTO carrier_inv_cnt_v	

      FROM TRV_CARRIER_INVOICE_INTERFACE;	



    print_log ( 'carrier_inv_cnt_v: ' || carrier_inv_cnt_v );



    SELECT COUNT(1) 

      INTO route_qa_cnt_v	

      FROM TRV_ROUTE_TRANSPORT_INTERFACE;



    print_log ( 'route_qa_cnt_v: ' || route_qa_cnt_v );



    IF ( carrier_inv_cnt_v + customer_inv_cnt_v + route_qa_cnt_v = 0 ) THEN



      p_error_msg := 'No data to process.';

      RAISE e_error;



    END IF;



    -- Verify all prior records have been processed



    -- Find the most recent run id

    SELECT MAX(oracle_xml_run_id)

      INTO latest_run_id_v

      FROM AJC_TRV_INTERFACE;



    print_log ( 'latest_run_id_v: ' || latest_run_id_v );



    SELECT COUNT(1)

      INTO num_correctables_v

      FROM AJC_TRV_INTERFACE

     WHERE oracle_xml_run_id = latest_run_id_v

       AND validation_status = 'Correctable';



    print_log ( 'num_correctables_v: ' || num_correctables_v );



    IF ( num_correctables_v > 0 ) THEN



      p_error_msg := 'Correctable errors found in Run ID ' || latest_run_id_v;

      RAISE e_error;



    END IF;



    SELECT COUNT(1)

      INTO num_not_interfaced_v

      FROM AJC_TRV_INTERFACE

     WHERE oracle_xml_run_id = latest_run_id_v

       AND NVL(interface_status,'XXX') NOT IN ('Interfaced', 'NA');



    print_log ( 'num_not_interfaced_v: ' || num_not_interfaced_v );



    IF ( num_not_interfaced_v > 0 ) THEN



      p_error_msg := 'Data not interfaced for Run ID ' || latest_run_id_v;

      RAISE e_error;



    END IF;



    -- Determine if there are any records in the XML staging tables missing a customer/vendor

    SELECT ( SELECT COUNT(1) 

               FROM TRV_CUSTOMER_INVOICE_INTERFACE 

              WHERE enterpriseaccntnum IS NULL ) + 

           ( SELECT COUNT(1) 

               FROM TRV_CARRIER_INVOICE_INTERFACE 

              WHERE carrierid IS NULL ) +

           ( SELECT COUNT(1) 

               FROM TRV_ROUTE_TRANSPORT_INTERFACE 

              WHERE pricesheettype = 'Cost' 

                AND refcustomeracctnum IS NULL ) + 

           ( SELECT COUNT(1) 

               FROM TRV_ROUTE_TRANSPORT_INTERFACE  

              WHERE pricesheettype IN ('Charge','VendorRate') 

                AND carrierid IS NULL )

      INTO num_missing_cust_vend_v

      FROM DUAL;



    print_log ( 'num_missing_cust_vend_v: ' || num_missing_cust_vend_v );



    IF num_missing_cust_vend_v > 0 THEN



      p_error_msg := 'Customers / Vendors Missing in XML Staging Tables.';

      RAISE e_error;



    END IF;



    -- Get Run ID

    SELECT ajc_trv_xml_run_id_s.nextval

      INTO gv_run_id

      FROM dual;



    print_log ( 'gv_run_id: ' || gv_run_id );



    -- Lock staging tables before inserting

	   LOCK TABLE TRV_CUSTOMER_INVOICE_INTERFACE IN EXCLUSIVE MODE NOWAIT;

	   LOCK TABLE TRV_CARRIER_INVOICE_INTERFACE IN EXCLUSIVE MODE NOWAIT;

	   LOCK TABLE TRV_ROUTE_TRANSPORT_INTERFACE IN EXCLUSIVE MODE NOWAIT;



    BEGIN



      INSERT 

        INTO AJC_TRV_INTERFACE

			        ( xml_file_name,

             xml_file_date,

             xml_file_type,

             oracle_xml_run_id,

             trv_shipping_order,

             trv_load_id,

             trv_item_seq,

             trv_cust_carr_acct_Num,

             trv_cust_carr_acct_Name,

             po_num,

             Invoice_date,

             Invoice_Num,

             Charge_type,

             Charge_desc,

             edi_item_code,

             charge_amount,

             delivery_date,

             creation_date,

             created_by,

             last_update_date,

             last_updated_by,

             xml_file_id,

             trv_ship_id,

			          trv_order_id )

		    SELECT REPLACE(filename,'-ajclogistics'),

             filecreateddate,

             'Customer-Inv',

             gv_run_id,

             refshippingorder,

             refloadid,

             chargesseqnum,

             enterpriseaccntnum,

             enterprisename,

             refponum,

             TO_DATE(invdate,'DD/MM/YYYY HH24:MI') ,

             -- 20240815 

             SUBSTR(invnum,1,30),

             -- 20240815

             chargestype,

             chargesdesc,

             chargesedicode,

             chargesamount,

             TO_DATE(pricesheetdropdate,'DD/MM/YYYY HH24:MI') ,

             SYSDATE,

             gv_user_id,

             SYSDATE,

             gv_user_id,

             REPLACE(filename,'-'),

             shipid,

			          orderid

        FROM TRV_CUSTOMER_INVOICE_INTERFACE;



      print_log ( '1. INSERT ' || SQL%ROWCOUNT || ' records into AJC_TRV_INTERFACE FROM TRV_CUSTOMER_INVOICE_INTERFACE' );



    EXCEPTION

		    WHEN OTHERS THEN

        RAISE;



	   END;



    BEGIN



      INSERT 

        INTO AJC_TRV_INTERFACE

			        ( xml_file_name,

             xml_file_date,

             xml_file_type,

             oracle_xml_run_id,

             trv_shipping_order,

             trv_load_id,

             trv_item_seq,

             trv_cust_carr_acct_Num,

             trv_cust_carr_acct_Name,

             po_num,

             Invoice_date,

             Invoice_Num,

             Charge_type,

             Charge_desc,

             edi_item_code,

             charge_amount,

             delivery_date,

             creation_date,

             created_by,

             last_update_date,

             last_updated_by,

             xml_file_id,

             trv_ship_id,

		          	trv_order_id )	

      SELECT REPLACE(filename,'-ajclogistics'),

             filecreateddate,

             'Carrier-Inv',

             gv_run_id,

             refshippingorder,

             refloadid,

             chargesseqnum,

             carrierid,             

             carriername,             

             refponum,

             TO_DATE(invdate,'DD/MM/YYYY HH24:MI') ,

             -- 20240815 

             SUBSTR(invnum,1,30),

             -- 20240815

             chargestype,

             chargesdesc,

             chargesedicode,

             chargesamount,

             TO_DATE(pricesheetdropdate,'DD/MM/YYYY HH24:MI') ,

             SYSDATE,

             gv_user_id,

             SYSDATE,

             gv_user_id,

             REPLACE(filename,'-'),

             shipid,

		          	orderid

        FROM TRV_CARRIER_INVOICE_INTERFACE;



      print_log ( '2. INSERT ' || SQL%ROWCOUNT || ' records into AJC_TRV_INTERFACE FROM TRV_CARRIER_INVOICE_INTERFACE' );



    EXCEPTION

		    WHEN OTHERS THEN

        RAISE;



	   END;



    BEGIN



      INSERT 

        INTO AJC_TRV_INTERFACE

			        ( xml_file_name,

             xml_file_date,

             xml_file_type,

             oracle_xml_run_id,

             trv_shipping_order,

             trv_load_id,

             trv_item_seq,

             trv_cust_carr_acct_Num,

             trv_cust_carr_acct_Name,

             po_num,

             Charge_type,

             Charge_desc,

             edi_item_code,

             charge_amount,

             delivery_date,

             creation_date,

             created_by,

             last_update_date,

             last_updated_by,

             xml_file_id,

             trv_ship_id,

		          	trv_order_id )	

      SELECT REPLACE(filename,'-ajclogistics'),

             TO_DATE(filecreateddate,'DD/MM/YYYY'),

             'Route-QAREV',	

             gv_run_id,

             refshippingorder,

             refloadid,

             chargesseqnum,

             refcustomeracctnum,

             entcustomername,

             refponum,

             chargestype,

             chargesdesc,

             chargesedicode,

             chargesamount,

             TO_DATE(pricesheetdropdate,'DD/MM/YYYY') ,

             SYSDATE,

             gv_user_id,

             SYSDATE,

             gv_user_id,

			          REPLACE(filename,'-'),

			          shipid,

             orderid

      		FROM TRV_ROUTE_TRANSPORT_INTERFACE

		     WHERE pricesheettype = 'Cost';



      print_log ( '3. INSERT ' || SQL%ROWCOUNT || ' records into AJC_TRV_INTERFACE FROM TRV_ROUTE_TRANSPORT_INTERFACE pricesheettype = Cost' );



    EXCEPTION

		    WHEN OTHERS THEN

        RAISE;



	   END;



    BEGIN 



      INSERT 

        INTO AJC_TRV_INTERFACE

			        ( xml_file_name,

             xml_file_date,

             xml_file_type,

             oracle_xml_run_id,

             trv_shipping_order,

             trv_load_id,

             trv_item_seq,

             trv_cust_carr_acct_Num,

             trv_cust_carr_acct_Name,

             po_num,

             Charge_type,

             Charge_desc,

             edi_item_code,

             charge_amount,

             delivery_date,

             creation_date,

             created_by,

             last_update_date,

             last_updated_by,

             xml_file_id,

             trv_ship_id,

	          		trv_order_id )

      SELECT REPLACE(filename,'-ajclogistics'),

             filecreateddate,

             'Route-QACOGS',	

             gv_run_id,

             refshippingorder,

             refloadid,

             chargesseqnum,

             carrierid,             

             carriername,             

             refponum,

             chargestype,

             chargesdesc,

             chargesedicode,

             chargesamount,

             TO_DATE(pricesheetdropdate,'DD/MM/YYYY HH24:MI') ,

             SYSDATE,

             gv_user_id,

             SYSDATE,

             gv_user_id,

             REPLACE(filename,'-'),

             shipid,

			          orderid

        FROM TRV_ROUTE_TRANSPORT_INTERFACE

       WHERE pricesheettype IN ('Charge','VendorRate');



      print_log ( '4. INSERT ' || SQL%ROWCOUNT || ' records into AJC_TRV_INTERFACE FROM TRV_ROUTE_TRANSPORT_INTERFACE pricesheettype = Charge OR VendorRate' );



    EXCEPTION

		    WHEN OTHERS THEN

        RAISE;



	   END;



	   COMMIT;



    -- clear_staging_tables

    DELETE TRV_CUSTOMER_INVOICE_INTERFACE;

    DELETE TRV_CARRIER_INVOICE_INTERFACE;

    DELETE TRV_ROUTE_TRANSPORT_INTERFACE;



    COMMIT;



    IF ( gv_file_format = 'CSV' ) THEN



      print_output ( 'AJCL BC TRV Data Load' );

      print_output ( 'Request ID|' || gv_request_id );

      print_output ( ' ' ); 



      print_output ( 'AJCL TRV Data Load' );    

      print_output ( ' ' );    



      v_columns := 'File Type' || '|' ||

                   'Line Count';



      print_output ( v_columns );



      FOR crpt IN c_report LOOP



        print_output ( crpt.xml_file_type || '|' ||

                       crpt.file_type_cnt );



      END LOOP;



    ELSIF ( gv_file_format = 'XLSX' ) THEN 



      -- Column Names

      print_output_xlsx ( p_section => 'Data Load',

                          p_column1 => 'File Type',

                          p_column2 => 'Line Count',

                          p_column3 => 'Valid Run ID' );    



      FOR crpt IN c_report LOOP



        print_output_xlsx ( p_section => 'Data Load',

                            p_column1 => crpt.xml_file_type,

                            p_column2 => TRIM(crpt.file_type_cnt),

                            p_column3 => gv_run_id );



      END LOOP;  



    END IF;



    p_status := 'S';



    print_log('ajcl_bc_trv_data_load_pkg.process_data_load_p (-)');



  EXCEPTION 

    WHEN e_error THEN

      print_log('ajcl_bc_trv_data_load_pkg.process_data_load_p (!)');

      p_status := 'E';



	   WHEN OTHERS THEN

		    ROLLBACK;

      p_error_msg := 'Error: ' || SQLERRM;

      print_log('ajcl_bc_trv_data_load_pkg.process_data_load_p (!). ' || p_error_msg );

      p_status := 'E';



  END process_data_load_p;



  PROCEDURE main_p ( p_jenkins_build_number   IN   VARCHAR2 ) IS



    v_status      VARCHAR(1);

    v_error_msg   VARCHAR2(2000);

    e_error       EXCEPTION;



  BEGIN



    gv_request_id := ajcl_bc_utils_pkg.get_request_id_f;

    gv_jenkins_build_number := p_jenkins_build_number;



    -- Se inserta el concurrent_job

    ajcl_bc_utils_pkg.ins_jenkins_concurrent_job_p ( p_request_id => gv_request_id,

                                                     p_job_name => gv_bc_ifc,

                                                     p_jenkins_build_number => p_jenkins_build_number );



    print_log ( 'ajcl_bc_trv_data_load_pkg.main_p (+)');



    print_log ( 'gv_request_id: ' || gv_request_id ); 

    print_log ( 'gv_bc_ifc: ' || gv_bc_ifc ); 

    print_log ( 'gv_jenkins_build_number: ' || gv_jenkins_build_number );



    gv_oracle_db := ajcl_bc_utils_pkg.get_db_name_f;

    print_log ( 'gv_oracle_db: ' || gv_oracle_db );



    gv_file_format := ajcl_bc_ws_utils_pkg.get_parameter_f ( 'FILE_FORMAT' );

    print_log( 'FILE_FORMAT: ' || gv_file_format ); 



    gv_email := ajcl_bc_utils_pkg.get_emails_f ( 'TRV DATA LOAD' );

    print_log( 'gv_email: ' || gv_email );



    -- AJCL TRV Data Load

    process_data_load_p ( p_status => v_status,

                          p_error_msg => v_error_msg );



    IF ( v_status != 'S' ) THEN



      print_log(v_error_msg);

      RAISE e_error;



    END IF;



    -- Generate excel output

    final_output_xlsx_p ( p_status => v_status );



    IF ( v_status != 'S' ) THEN



      RAISE e_error;



    END IF;



    -- Send output by mail

    BEGIN



      ajcl_bc_utils_pkg.send_mail_with_attach ( p_to_mail => gv_email,

                                                p_subject => gv_bc_ifc || ' Output - ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ' || gv_oracle_db || ' (' || gv_jenkins_build_number || ')',

                                                p_body => gv_bc_ifc || ' Output.',

                                                p_type => 'OUTPUT',

                                                p_filename => gv_output_filename, 

                                                p_file_format => gv_file_format,

                                                p_attach_filename => gv_bc_ifc || ' Output ' || TO_CHAR(SYSDATE,'MMDDYYYY HH24MISS') || ' ' || gv_oracle_db || '.' || LOWER(gv_file_format) ); 



    EXCEPTION

      WHEN OTHERS THEN

        print_log ( 'SMTP NOT WORKING.' );



    END;  



    -- Se actualiza el concurrent_job

    ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'S' );



    print_log('ajcl_bc_trv_data_load_pkg.main_p (-)');        



  EXCEPTION

    WHEN e_error THEN

      print_log('ajcl_bc_trv_data_load_pkg.main_data_load_p (!)');



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_oracle_db || ' (' || gv_jenkins_build_number || ')',

                                       p_message => v_error_msg || '. Build Number: ' || gv_jenkins_build_number );



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );  



    WHEN OTHERS THEN

      print_log('ajcl_bc_trv_data_load_pkg.main_data_load_p (!). Error: ' || SQLERRM);



      ajcl_bc_utils_pkg.send_email_p ( p_to => gv_email,

                                       p_subject => gv_bc_ifc || ' ' || TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS') || ' - ERROR - ' || gv_oracle_db || ' (' || gv_jenkins_build_number || ')',

                                       p_message => 'Error: ' || SQLERRM || '. Build Number: ' || gv_jenkins_build_number );



      -- Se actualiza el concurrent_job

      ajcl_bc_utils_pkg.upd_jenkins_concurrent_job_p ( p_request_id => gv_request_id, p_status => 'E' );  



  END main_p;



END ajcl_bc_trv_data_load_pkg;  
