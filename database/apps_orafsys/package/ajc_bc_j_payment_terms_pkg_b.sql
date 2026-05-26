CREATE OR REPLACE PACKAGE BODY AJC_BC_J_PAYMENT_TERMS_PKG IS



  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    gv_log_seq := gv_log_seq + 1;

    AJC_BC_J_UTILS_PKG.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );



  END print_log;



  PROCEDURE get_payment_terms_p ( p_last_bc_processed_date   IN    TIMESTAMP,

                                  p_return                   OUT   VARCHAR2, 

                                  p_message                  OUT   VARCHAR2 ) IS



    v_get_url       VARCHAR2(2000);

    v_get_api       VARCHAR2(100);

    v_clob_result   CLOB;



  BEGIN



    print_log ('AJC_BC_J_PAYMENT_TERMS_PKG.get_payment_terms_p (+)');



    v_get_api := AJC_BC_J_WS_UTILS_PKG.get_api_f ( p_entity => 'PAYMENT TERMS',

                                                   p_subentity => NULL,

                                                   p_method => 'GET' );

    print_log ( 'v_get_api: ' || v_get_api );



    v_get_url := AJC_BC_J_WS_UTILS_PKG.get_base_inecta_url_f ( gv_bc_environment, gv_company_id ) || v_get_api 

                 || '?$filter=lastModifiedDateTime gt ' || TO_CHAR(p_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');



    print_log ( 'v_get_url: ' || v_get_url );



    v_clob_result := AJC_BC_J_WS_UTILS_PKG.get_bc_clob_result_f ( p_url => v_get_url );



    INSERT

      INTO ajc_bc_payment_terms

         ( code,

           description,

           calcPmtDiscOnCrMemos,

           coupledToCRM,

           discount,

           discountDateCalculation,

           dueDateCalculation,

           satPaymentTerm,

           id,

           lastModifiedDateTime,

           accountStatementDueDays,

           type,

           inactive,

           systemModifiedBy,

           --

           creation_date,

           request_id,

           status )

    SELECT code,

           description,

           calcPmtDiscOnCrMemos,

           coupledToCRM,

           discount,

           discountDateCalculation,

           NVL(regexp_replace(dueDateCalculation,'[^0-9]', ''),0), -- dueDateCalculation

           satPaymentTerm,

           id,

           lastModifiedDateTime,

           accountStatementDueDays,

           type,

           DECODE(inactive,'true','Y','N'),

           systemModifiedBy,

           --

           SYSDATE,

           gv_request_id,

           'NEW'           

      FROM json_table( v_clob_result,

                       '$.value[*]' COLUMNS ( code                      VARCHAR2(4000)  path '$.code',

                                              description               VARCHAR2(4000)  path '$.description',

                                              calcPmtDiscOnCrMemos      VARCHAR2(4000)  path '$.calcPmtDiscOnCrMemos',

                                              coupledToCRM              VARCHAR2(4000)  path '$.coupledToCRM',

                                              discount                  VARCHAR2(4000)  path '$.discount',

                                              discountDateCalculation   VARCHAR2(4000)  path '$.discountDateCalculation',

                                              dueDateCalculation        VARCHAR2(4000)  path '$.dueDateCalculation',

                                              satPaymentTerm            VARCHAR2(4000)  path '$.satPaymentTerm',

                                              id                        VARCHAR2(4000)  path '$.id',

                                              lastModifiedDateTime      VARCHAR2(4000)  path '$.lastModifiedDateTime',

                                              accountStatementDueDays   VARCHAR2(4000)  path '$.accStatemntDueDays',

                                              type                      VARCHAR2(4000)  path '$.type',

                                              inactive                  VARCHAR2(4000)  path '$.inactive',

                                              systemModifiedBy          VARCHAR2(4000)  path '$.systemModifiedBy' ) );



    p_return := 'S';



    print_log ('AJC_BC_J_PAYMENT_TERMS_PKG.get_payment_terms_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_return := 'E';

      p_message := 'Error general get_payment_terms_p: ' || SQLERRM;



  END get_payment_terms_p;



  PROCEDURE process_payment_terms_p ( p_count     IN OUT   NUMBER,

                                      p_return    OUT      VARCHAR2, 

                                      p_message   OUT      VARCHAR2 ) IS



    CURSOR c_payment_terms IS

    SELECT *

      FROM ajc_bc_payment_terms

     WHERE request_id = gv_request_id

       AND status = 'NEW';



    v_term_id_ap                    ap_terms.term_id%TYPE;

    v_term_id_ar                    ra_terms.term_id%TYPE;

    v_attribute1                    ra_terms.attribute1%TYPE;

    v_attribute2                    ra_terms.attribute2%TYPE;

    v_attribute3                    ra_terms.attribute3%TYPE;

    v_attribute4                    ra_terms.attribute4%TYPE;

    v_attribute5                    ra_terms.attribute5%TYPE;

    v_attribute6                    ra_terms.attribute6%TYPE;

    v_attribute7                    ra_terms.attribute7%TYPE;

    v_attribute8                    ra_terms.attribute8%TYPE;

    v_attribute9                    ra_terms.attribute9%TYPE;

    v_attribute10                   ra_terms.attribute10%TYPE;

    v_attribute11                   ra_terms.attribute11%TYPE;

    v_attribute12                   ra_terms.attribute12%TYPE;

    v_attribute13                   ra_terms.attribute13%TYPE;

    v_attribute14                   ra_terms.attribute14%TYPE;

    v_attribute15                   ra_terms.attribute15%TYPE;    



    v_name                          ap_terms.name%TYPE;

    v_start_date_active             ra_terms_b.start_date_active%TYPE;    

    v_end_date_active               ra_terms_b.end_date_active%TYPE;    



    v_type                          ap_terms.type%TYPE;

    v_rank                          ap_terms.rank%TYPE;



    v_credit_check_flag             ra_terms_b.credit_check_flag%TYPE;

    v_prepayment_flag               ra_terms_b.prepayment_flag%TYPE;    

    v_due_cutoff_day                ra_terms_b.due_cutoff_day%TYPE;    

    v_printing_lead_days            ra_terms_b.printing_lead_days%TYPE;    

    v_calc_discount_on_lines_flag   ra_terms_b.calc_discount_on_lines_flag%TYPE;    

    v_first_installment_code        ra_terms_b.first_installment_code%TYPE;    

    v_partial_discount_flag         ra_terms_b.partial_discount_flag%TYPE;  

    v_base_amount                   ra_terms_b.base_amount%TYPE;

    v_in_use                        ra_terms_b.in_use%TYPE;



    v_sequence_num                  ra_terms_lines.sequence_num%TYPE;

    v_account_statement_due_days    ra_terms_lines.attribute1%TYPE;



    v_error_message                 VARCHAR2(400);



    -- 20240202

    v_updated_in_ap                 VARCHAR2(1);

    v_updated_in_ar                 VARCHAR2(1);

    -- 20240202



    v_module                        VARCHAR2(2);

    v_tbl_status                    VARCHAR2(20);



    e_api                           EXCEPTION;



  BEGIN



    print_log ('AJC_BC_J_PAYMENT_TERMS_PKG.process_payment_terms_p (+)');



    UPDATE ajc_bc_payment_terms

       SET status = 'SKIPPED'

     WHERE request_id = gv_request_id

       AND status = 'NEW'

       AND systemModifiedBy NOT IN ( SELECT user_security_id

                                       FROM ajc_bc_vend_cust_ifc_users

                                      WHERE bc_environment = gv_bc_environment

                                        AND company = 'INC'

                                        AND enabled = 'Y' );



    p_count := SQL%ROWCOUNT;



    COMMIT;



    FOR cpt IN c_payment_terms LOOP



      p_count := p_count + 1;



      print_log ('Payment Term: ' || cpt.code );

      print_log ('Description: ' || cpt.description );



      v_updated_in_ap := 'N';

      v_updated_in_ar := 'N';



      v_name := NULL;



      -- AP

      v_term_id_ap := NULL;

      v_type := NULL;

      v_rank := NULL;



      -- AR

      v_term_id_ar := NULL;

      v_credit_check_flag := NULL;

      v_prepayment_flag := NULL;

      v_printing_lead_days := NULL;

      v_calc_discount_on_lines_flag := NULL;

      v_first_installment_code := NULL;

      v_partial_discount_flag := NULL;

      v_base_amount := NULL;

      v_in_use := NULL;



      v_sequence_num := NULL;



      -- AP / AR

      v_start_date_active := NULL;

      v_end_date_active := NULL;

      v_due_cutoff_day := NULL;

      v_attribute1 := NULL;

      v_attribute2 := NULL;

      v_attribute3 := NULL;

      v_attribute4 := NULL;

      v_attribute5 := NULL;

      v_attribute6 := NULL;

      v_attribute7 := NULL;

      v_attribute8 := NULL;

      v_attribute9 := NULL;

      v_attribute10 := NULL;

      v_attribute11 := NULL;

      v_attribute12 := NULL;

      v_attribute13 := NULL;

      v_attribute14 := NULL;

      v_attribute15 := NULL;  



      v_error_message := NULL;

      v_module := NULL;

      v_tbl_status := NULL;



      BEGIN



        -- AP ------------------------------------------------------------------------------------------------------------------

        BEGIN



          SELECT pt.term_id,

                 pt.name,

                 pt.start_date_active,

                 pt.end_date_active,

                 pt.due_cutoff_day,

                 pt.type,

                 pt.rank,

                 pt.attribute1,

                 pt.attribute2,

                 pt.attribute3,

                 pt.attribute4,

                 pt.attribute5,

                 pt.attribute6,

                 pt.attribute7,

                 pt.attribute8,

                 pt.attribute9,

                 pt.attribute10,

                 pt.attribute11,

                 pt.attribute12,

                 pt.attribute13,

                 pt.attribute14,

                 pt.attribute15

            INTO v_term_id_ap,

                 v_name,

                 v_start_date_active,

                 v_end_date_active,

                 v_due_cutoff_day,

                 v_type,

                 v_rank,

                 v_attribute1,

                 v_attribute2,

                 v_attribute3,

                 v_attribute4,

                 v_attribute5,

                 v_attribute6,

                 v_attribute7,

                 v_attribute8,

                 v_attribute9,

                 v_attribute10,

                 v_attribute11,

                 v_attribute12,

                 v_attribute13,

                 v_attribute14,

                 v_attribute15

            FROM AJC_BC_PAYMENT_TERMS_MAPPING m,

                 ap_terms pt

           WHERE m.bc_code = cpt.code

             AND m.module = 'AP'

             AND m.term_id = pt.term_id;



        EXCEPTION 

          WHEN OTHERS THEN

            v_term_id_ap := NULL;



        END;



        IF ( v_term_id_ap IS NOT NULL ) THEN 



          print_log ('Payment Term exists in AP.');



          IF ( cpt.inactive = 'Y' ) THEN



            v_end_date_active := SYSDATE;



          ELSE



            v_end_date_active := NULL;



          END IF;



          BEGIN



            ap_terms_pkg.update_row ( x_term_id => v_term_id_ap,

                                      x_enabled_flag => 'Y',

                                      x_due_cutoff_day	=> v_due_cutoff_day,

                                      x_type => v_type,

                                      x_start_date_active => v_start_date_active,

                                      x_end_date_active	=> v_end_date_active,

                                      x_rank	=> v_rank,

                                      x_attribute_category	=> NULL,

                                      x_attribute1	=> v_attribute1,

                                      x_attribute2	=> v_attribute2,

                                      x_attribute3	=> v_attribute3,

                                      x_attribute4	=> v_attribute4,

                                      x_attribute5	=> v_attribute5,

                                      x_attribute6	=> v_attribute6,

                                      x_attribute7	=> v_attribute7,

                                      x_attribute8	=> v_attribute8,

                                      x_attribute9	=> v_attribute9,

                                      x_attribute10	=> v_attribute10,

                                      x_attribute11	=> v_attribute11,

                                      x_attribute12	=> v_attribute12,

                                      x_attribute13	=> v_attribute13,

                                      x_attribute14	=> v_attribute14,

                                      x_attribute15	=> v_attribute15,

                                      x_name => v_name,

                                      x_description => cpt.description,

                                      x_last_update_date => SYSDATE,

                                      x_last_updated_by => gv_user_id,

                                      x_last_update_login => gv_user_id );



          EXCEPTION

            WHEN OTHERS THEN

              RAISE e_api;



          END;



          -- Se obtiene la línea a actualizar

          BEGIN



              SELECT sequence_num

                INTO v_sequence_num

                FROM ap_terms_lines

               WHERE term_id = v_term_id_ap

                 AND rownum = 1

            ORDER BY sequence_num;



            print_log ('Line Sequence Num: ' || v_sequence_num);



            UPDATE ap_terms_lines

               SET due_days = cpt.dueDateCalculation,

                   last_update_date = SYSDATE

             WHERE term_id = v_term_id_ar

               AND sequence_num = v_sequence_num;



            print_log ('Payment Term line Due Days updated.');



          EXCEPTION

            WHEN OTHERS THEN

              v_error_message := 'Payment Term line not found.';

              print_log (v_error_message);



          END;          



          print_log ('Payment Term updated.');



          v_updated_in_ap := 'Y';



        ELSE



          print_log ('Payment Term does not exist in AP');



        END IF;



        -- AR ------------------------------------------------------------------------------------------------------------------

        BEGIN



          SELECT pt.term_id,

                 pt.name,

                 pt.start_date_active,

                 pt.end_date_active,

                 pt.credit_check_flag,

                 pt.prepayment_flag,

                 pt.due_cutoff_day,

                 pt.printing_lead_days,

                 pt.calc_discount_on_lines_flag,

                 pt.first_installment_code,

                 pt.partial_discount_flag,

                 pt.base_amount,

                 pt.in_use,

                 NVL(cpt.type,pt.attribute1), -- Si de BC trae valor, se usa ese valor, sino se deja el que tiene

                 pt.attribute2,

                 pt.attribute3,

                 pt.attribute4,

                 pt.attribute5,

                 pt.attribute6,

                 pt.attribute7,

                 pt.attribute8,

                 pt.attribute9,

                 pt.attribute10,

                 pt.attribute11,

                 pt.attribute12,

                 pt.attribute13,

                 pt.attribute14,

                 pt.attribute15

            INTO v_term_id_ar,

                 v_name,

                 v_start_date_active,

                 v_end_date_active,

                 v_credit_check_flag,

                 v_prepayment_flag,

                 v_due_cutoff_day,

                 v_printing_lead_days,

                 v_calc_discount_on_lines_flag,

                 v_first_installment_code,

                 v_partial_discount_flag,

                 v_base_amount,

                 v_in_use,

                 v_attribute1,

                 v_attribute2,

                 v_attribute3,

                 v_attribute4,

                 v_attribute5,

                 v_attribute6,

                 v_attribute7,

                 v_attribute8,

                 v_attribute9,

                 v_attribute10,

                 v_attribute11,

                 v_attribute12,

                 v_attribute13,

                 v_attribute14,

                 v_attribute15

            FROM AJC_BC_PAYMENT_TERMS_MAPPING m,

                 ra_terms pt

           WHERE m.bc_code = cpt.code

             AND m.module = 'AR'

             AND m.term_id = pt.term_id;



        EXCEPTION 

          WHEN OTHERS THEN

            v_term_id_ar := NULL;



        END;



        IF ( v_term_id_ar IS NOT NULL ) THEN



          print_log ('Payment Term exists in AR');



          IF ( cpt.inactive = 'Y' ) THEN



            v_end_date_active := SYSDATE;



          ELSE



            v_end_date_active := NULL;



          END IF;



          BEGIN



            ra_terms_table_handler.update_row ( x_term_id => v_term_id_ar,

                                                x_credit_check_flag => v_credit_check_flag,

                                                x_prepayment_flag => v_prepayment_flag,

                                                x_due_cutoff_day => v_due_cutoff_day,

                                                x_printing_lead_days => v_printing_lead_days,

                                                x_start_date_active => v_start_date_active,

                                                x_end_date_active => v_end_date_active,

                                                x_attribute_category => NULL,

                                                x_attribute1 => v_attribute1, -- Type

                                                x_attribute2 => v_attribute2,

                                                x_attribute3 => v_attribute3,

                                                x_attribute4 => v_attribute4,

                                                x_attribute5 => v_attribute5,

                                                x_attribute6 => v_attribute6,

                                                x_attribute7 => v_attribute7,

                                                x_attribute8 => v_attribute8,

                                                x_attribute9 => v_attribute9,

                                                x_attribute10 => v_attribute10,

                                                x_base_amount => v_base_amount,

                                                x_calc_discount_on_lines_flag => v_calc_discount_on_lines_flag,

                                                x_first_installment_code => v_first_installment_code,

                                                x_in_use => v_in_use,

                                                x_partial_discount_flag => v_partial_discount_flag,

                                                x_attribute11 => v_attribute11,

                                                x_attribute12 => v_attribute12,

                                                x_attribute13 => v_attribute13,

                                                x_attribute14 => v_attribute14,

                                                x_attribute15 => v_attribute15,

                                                x_name => v_name,

                                                x_description => cpt.description,

                                                x_last_update_date => SYSDATE,

                                                x_last_updated_by => gv_user_id,

                                                x_last_update_login => gv_user_id );



          EXCEPTION

            WHEN OTHERS THEN

              RAISE e_api;



          END;



          -- Se obtiene la línea a actualizar

          BEGIN



              SELECT sequence_num,

                     attribute1

                INTO v_sequence_num,

                     v_account_statement_due_days

                FROM ra_terms_lines

               WHERE term_id = v_term_id_ar

                 AND rownum = 1

            ORDER BY sequence_num;



            print_log ('Line Sequence Num: ' || v_sequence_num);



            UPDATE ra_terms_lines

               SET due_days = cpt.dueDateCalculation,

                   attribute1 = NVL(cpt.accountStatementDueDays,v_account_statement_due_days),

                   last_update_date = SYSDATE

             WHERE term_id = v_term_id_ar

               AND sequence_num = v_sequence_num;



            print_log ('Payment Term line: Due Days and Account Statement Due Days flexfield segment updated.');



          EXCEPTION

            WHEN OTHERS THEN

              print_log ('Payment Term line not found.');



          END;



          print_log ('Payment Term updated.');



          v_updated_in_ar := 'Y';



        ELSE



          print_log ('Payment Term does not exist in AR');



        END IF;



      EXCEPTION

        WHEN e_api THEN

          v_error_message := 'API error.';

        WHEN OTHERS THEN

          ROLLBACK;

          v_error_message := 'Error general. ' || SQLERRM;

          v_tbl_status := 'ERROR';



      END;



      COMMIT;



      IF ( v_updated_in_ap = 'Y' OR v_updated_in_ar = 'Y' ) THEN



        v_tbl_status := 'UPDATED';



        IF ( v_updated_in_ap = 'Y' AND v_updated_in_ar = 'N' ) THEN



          v_module := 'AP';



        ELSIF ( v_updated_in_ap = 'N' AND v_updated_in_ar = 'Y' ) THEN



          v_module := 'AR';



        ELSIF ( v_updated_in_ap = 'Y' AND v_updated_in_ar = 'Y' ) THEN



          v_module := 'RP';



        END IF;



      ELSE 



        v_tbl_status := 'NOT EXIST';



      END IF;



      UPDATE ajc_bc_payment_terms

         SET name = v_name,

             status = v_tbl_status, 

             processed_date = SYSDATE,

             module = v_module,

             message = v_error_message

       WHERE code = cpt.code

         AND request_id = gv_request_id

         AND status = 'NEW';



      COMMIT;



    END LOOP;



    p_return := 'S';



    print_log ('AJC_BC_J_PAYMENT_TERMS_PKG.process_payment_terms_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      p_return := 'E';

      p_message := 'Error general process_payment_terms_p: ' || SQLERRM;      



  END process_payment_terms_p; 



  PROCEDURE main_p ( p_bc_environment   IN   VARCHAR2,

                     p_bc_ifc           IN   VARCHAR2,

                     p_request_id       IN   NUMBER,

                     p_log_seq      IN OUT   NUMBER,

                     p_status          OUT   VARCHAR2 ) IS



    v_run_date                 TIMESTAMP;

    v_last_processed_date      TIMESTAMP;

    v_last_bc_processed_date   TIMESTAMP;



    v_payment_terms_count      NUMBER;



    v_error_message            VARCHAR2(2000);

    e_parameter_value          EXCEPTION;



    v_return                   VARCHAR2(1);

    v_message                  VARCHAR2(2000);



    e_error                    EXCEPTION;



  BEGIN



    gv_request_id := p_request_id;

    gv_bc_ifc := p_bc_ifc;

    gv_log_seq := p_log_seq;



    print_log ( 'AJC_BC_J_PAYMENT_TERMS_PKG.main_p (+)' );

    print_log ( 'gv_request_id: ' || gv_request_id );



    gv_bc_environment := p_bc_environment;

    print_log ( 'gv_bc_environment: ' || gv_bc_environment );  



    -- Se guarda la fecha y hora actual

    v_run_date := systimestamp;

    print_log ( 'v_run_date: ' || v_run_date );



    -- Se obtiene la fecha y hora de Oracle de la ultima ejecucion de la interface

    v_last_processed_date := AJC_BC_J_WS_UTILS_PKG.get_ifc_last_processed_date_f ( gv_ifc );

    print_log ( 'Oracle last processed date: ' || v_last_processed_date );    



    -- Se obtiene la fecha y hora de BC de la ultima ejecucion de la interface

    v_last_bc_processed_date := AJC_BC_J_WS_UTILS_PKG.get_bc_last_processed_date_f ( v_last_processed_date );

    print_log ( 'BC last processed date: ' || v_last_bc_processed_date );



    get_payment_terms_p ( p_last_bc_processed_date => v_last_bc_processed_date,

                          p_return => v_return, 

                          p_message => v_message );



    IF ( v_return != 'S' ) THEN



      RAISE e_error;



    END IF;



    process_payment_terms_p ( p_count => v_payment_terms_count,

                              p_return => v_return, 

                              p_message => v_message );



    IF ( v_return != 'S' ) THEN



      RAISE e_error;



    END IF;



    -- Se actualiza la tabla de control

    AJC_BC_J_WS_UTILS_PKG.upd_ifc_last_processed_date_p ( gv_ifc,

                                                          gv_request_id,

                                                          v_run_date );



    COMMIT;



    p_log_seq := gv_log_seq;



    print_log ('AJC_BC_J_PAYMENT_TERMS_PKG.main_p (-)');



  EXCEPTION

    WHEN e_error THEN

      print_log ( v_message );



    WHEN OTHERS THEN

      print_log ( 'Error general: ' || SQLERRM );



  END main_p;



END AJC_BC_J_PAYMENT_TERMS_PKG;
