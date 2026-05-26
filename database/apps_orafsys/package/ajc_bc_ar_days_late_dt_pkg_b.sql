CREATE OR REPLACE PACKAGE BODY AJC_BC_AR_DAYS_LATE_DT_PKG IS

 

  PROCEDURE FILL_TITLES_TABLE_P ( p_org_id          IN   NUMBER,

                                  p_trx_date_from   IN   VARCHAR2,

                                  p_trx_date_to     IN   VARCHAR2 ) IS



    CURSOR c_periods ( pc_row_num   IN   NUMBER ) IS

    SELECT period

      FROM ( SELECT period, 

                    rownum row_num

               FROM ( SELECT TO_CHAR(gp.start_date,'YYYY') || '/' || gp.period_num period

                        FROM hr_operating_units ou,

                             gl_sets_of_books gsob,

                             gl_periods gp

                       WHERE ou.organization_id = p_org_id

                         AND ou.set_of_books_id = gsob.set_of_books_id

                         AND gsob.period_set_name = gp.period_set_name

                         AND gp.adjustment_period_flag = 'N'

                         AND gp.start_date >= TO_DATE(p_trx_date_from,'YYYY/MM/DD HH24:MI:SS')

                         AND gp.start_date < TO_DATE(p_trx_date_to,'YYYY/MM/DD HH24:MI:SS')

                    GROUP BY TO_CHAR(gp.start_date,'YYYY'),

                             gp.period_num

                    ORDER BY TO_CHAR(gp.start_date,'YYYY'), 

                             gp.period_num ) )

     WHERE row_num = pc_row_num;



    v_plsql   VARCHAR2(1000);



    CURSOR c_seq IS

    SELECT 1 a FROM DUAL UNION ALL

    SELECT 2 a FROM DUAL UNION ALL

    SELECT 3 a FROM DUAL UNION ALL

    SELECT 4 a FROM DUAL UNION ALL

    SELECT 5 a FROM DUAL UNION ALL

    SELECT 6 a FROM DUAL UNION ALL

    SELECT 7 a FROM DUAL UNION ALL

    SELECT 8 a FROM DUAL UNION ALL

    SELECT 9 a FROM DUAL UNION ALL

    SELECT 10 a FROM DUAL UNION ALL

    SELECT 11 a FROM DUAL UNION ALL

    SELECT 12 a FROM DUAL;



    v_column_name   VARCHAR2(100);

    v_column_num    NUMBER;



  BEGIN



    DELETE ajc.ajc_bc_ar_days_late_dt_titles;



    INSERT 

      INTO ajc.ajc_bc_ar_days_late_dt_titles

           ( column1, 

             column2,

             column3,

             column4,

             column17 )

    VALUES ( 'Region',

             'Country',

             'Customer Name',

             'Customer No',

             'Total Average' );



    FOR cs IN c_seq LOOP



      fnd_file.put_line ( fnd_file.log, 'cs.a: ' || cs.a );



      FOR cp IN c_periods ( cs.a ) LOOP



        fnd_file.put_line ( fnd_file.log, 'period: ' || cp.period );

        v_column_name := cp.period;



      END LOOP;



      v_column_num := cs.a + 4;



      fnd_file.put_line ( fnd_file.log, 'v_column_num: ' || v_column_num );



      v_plsql := 'UPDATE ajc.ajc_bc_ar_days_late_dt_titles SET column' || v_column_num || ' = ''' || v_column_name || '''';



      fnd_file.put_line ( fnd_file.log, 'v_plsql: ' || v_plsql );



      EXECUTE IMMEDIATE v_plsql;



    END LOOP;



    COMMIT;



  END FILL_TITLES_TABLE_P;



  ------------------------------------------------------------------------------------------------------------------------------



  PROCEDURE FILL_ROWS_TABLE_P ( p_org_id                 IN   NUMBER,

                                p_customer_name_low      IN   VARCHAR2,

                                p_customer_name_high     IN   VARCHAR2,

                                p_customer_number_low    IN   VARCHAR2,

                                p_customer_number_high   IN   VARCHAR2,

                                p_trx_date_from          IN   VARCHAR2,

                                p_trx_date_to            IN   VARCHAR2 ) IS



    CURSOR c_region_customer IS

    SELECT rgn.rgn_name region,

           rc.attribute3 country,

           aadl.customer_name,

           aadl.customer_number

      FROM ajc_bc_ar_days_late_v aadl,

           ra_customers rc,

           ( SELECT gp.period_num

               FROM hr_operating_units ou,

                    gl_sets_of_books gsob,

                    gl_periods gp

              WHERE ou.organization_id = p_org_id

                AND ou.set_of_books_id = gsob.set_of_books_id

                AND gsob.period_set_name = gp.period_set_name

                AND gp.adjustment_period_flag = 'N'

           GROUP BY gp.period_num ) m

           --

           ,( SELECT rgn_name, ajc_cntry_code, cntry_name

                FROM ATISPROD.rgn_cntry rgnc, ATISPROD.country cntry, ATISPROD.region rgn

               WHERE rgnc.tk_rgn = rgn.tk_rgn

                 AND rgnc.tk_cntry = cntry.tk_cntry

                 AND rgn.rgn_status = 'A'

                 AND rgnc.active_closed = 'A' ) rgn

           --

     WHERE 1 = 1

       AND aadl.org_id = p_org_id

       AND aadl.customer_name >= NVL(p_customer_name_low,aadl.customer_name)

       AND aadl.customer_name <= NVL(p_customer_name_high,aadl.customer_name)

       AND aadl.customer_number >= NVL(p_customer_number_low,aadl.customer_number)

       AND aadl.customer_number <= NVL(p_customer_number_high,aadl.customer_number)

       AND aadl.actual_date_closed >= TO_DATE(p_trx_date_from,'YYYY/MM/DD HH24:MI:SS')

       AND aadl.actual_date_closed <= TO_DATE(p_trx_date_to,'YYYY/MM/DD HH24:MI:SS')

       AND aadl.customer_name = rc.customer_name

       AND aadl.customer_number = rc.customer_number

       AND TO_CHAR(aadl.actual_date_closed,'MM') = m.period_num

       --

       AND rc.attribute3 = rgn.ajc_cntry_code

       --

       -- 20230516

       AND NOT EXISTS ( SELECT 1

                          FROM atisprod.ar_receivable_applications_all ara,

                               atisprod.ar_payment_schedules_all aps

                         WHERE ara.applied_customer_trx_id = aadl.customer_trx_id

                           AND ara.display = 'Y'

                           AND ara.application_type = 'CM'

                           AND ara.status = 'APP'

                           AND ara.payment_schedule_id = aps.payment_schedule_id

                           AND aps.status = 'CL' )

       -- 20230516

       -- 20230506

       -- No se tienen en cuenta los comprobantes que tienen el override flag en Y

       AND NOT EXISTS ( SELECT 1

                          FROM atisprod.ra_customer_trx_all rct

                         WHERE rct.customer_trx_id = aadl.customer_trx_id 

                           AND NVL(rct.attribute2,'N') = 'Y' )

       -- 20230506 

  GROUP BY rgn.rgn_name,

           rc.attribute3,

           aadl.customer_name,

           aadl.customer_number

  ORDER BY rgn.rgn_name,

           rc.attribute3,

           aadl.customer_name;



    CURSOR c_rows ( pc_country         IN   VARCHAR2,

                    pc_customer_name   IN   VARCHAR2 ) IS 

    SELECT rc.attribute3 country,

           aadl.customer_name,

           aadl.customer_number,

           -- Inicio Modificado SBanchieri 20220202

           -- aadl.period_year || '/' || m.period_num period,

           -- TO_CHAR(aadl.actual_date_closed,'YYYY') || '/' || m.period_num period,

           -- Inicio Modificado SBanchieri 20220316

           aadl.period_year 

           -- 20230314

           - DECODE(p_org_id,5244,1,0) -- en AJC OU se resta un año

           -- 20230314

           || '/' || m.period_num period,

           -- Fin Modificado SBanchieri 20220316

           -- Fin Modificado SBanchieri 20220202

           AJCBCARDLC_WAVG_DAYS_LATE ( aadl.customer_number,

                                       aadl.customer_name,

                                       -- Inicio Modificado SBanchieri 20220316

                                       -- aadl.period_year

                                       aadl.period_year 

                                       -- 20230314

                                       -- 20230424 - DECODE(p_org_id,5244,1,0) -- en AJC OU se resta un año

                                       -- 20230314

                                       ,

                                       -- Fin Modificado SBanchieri 20220316

                                       m.period_num ) weighted_average_days_late

      FROM ajc_bc_ar_days_late_v aadl,

           ra_customers rc,

           ( SELECT -- 20230606

                    gp.period_year, 

                    -- 20230606

                    gp.period_num

               FROM hr_operating_units ou,

                    gl_sets_of_books gsob,

                    gl_periods gp

              WHERE ou.organization_id = p_org_id

                AND ou.set_of_books_id = gsob.set_of_books_id

                AND gsob.period_set_name = gp.period_set_name

                AND gp.adjustment_period_flag = 'N'

                -- 20230606

                AND gp.start_date >= TO_DATE(p_trx_date_from,'YYYY/MM/DD HH24:MI:SS')

                AND gp.end_date <= TO_DATE(p_trx_date_to,'YYYY/MM/DD HH24:MI:SS')

                -- 20230606

           GROUP BY -- 20230606

                    gp.period_year, 

                    -- 20230606

                    gp.period_num ) m

     WHERE 1 = 1

       AND aadl.org_id = p_org_id

       AND rc.attribute3 = pc_country

       AND aadl.customer_name = pc_customer_name

       AND aadl.actual_date_closed >= TO_DATE(p_trx_date_from,'YYYY/MM/DD HH24:MI:SS')

       AND aadl.actual_date_closed <= TO_DATE(p_trx_date_to,'YYYY/MM/DD HH24:MI:SS')

       AND aadl.customer_name = rc.customer_name

       AND aadl.customer_number = rc.customer_number

       -- 20230606

       AND aadl.period_year = m.period_year

       -- 20230606

       -- Inicio Modificado SBanchieri 20220316

       -- AND TO_CHAR(aadl.actual_date_closed,'MM') = m.period_num

       -- Fin Modificado SBanchieri 20220316

       -- 20230516

       AND NOT EXISTS ( SELECT 1

                          FROM atisprod.ar_receivable_applications_all ara,

                               atisprod.ar_payment_schedules_all aps

                         WHERE ara.applied_customer_trx_id = aadl.customer_trx_id

                           AND ara.display = 'Y'

                           AND ara.application_type = 'CM'

                           AND ara.status = 'APP'

                           AND ara.payment_schedule_id = aps.payment_schedule_id

                           AND aps.status = 'CL' )

       -- 20230516

       -- 20230506

       -- No se tienen en cuenta los comprobantes que tienen el override flag en Y

       AND NOT EXISTS ( SELECT 1

                          FROM atisprod.ra_customer_trx_all rct

                         WHERE rct.customer_trx_id = aadl.customer_trx_id 

                           AND NVL(rct.attribute2,'N') = 'Y' )

       -- 20230506

  GROUP BY rc.attribute3,

           aadl.customer_name,

           aadl.customer_number,

           aadl.period_year,

           -- Inicio Agregado SBanchieri 20220202

           TO_CHAR(aadl.actual_date_closed,'YYYY'),

           -- Fin Agregado SBanchieri 20220202

           m.period_num

  ORDER BY rc.attribute3,

           aadl.customer_name,

           aadl.period_year,

           -- Inicio Agregado SBanchieri 20220202

           TO_CHAR(aadl.actual_date_closed,'YYYY'),

           -- Fin Agregado SBanchieri 20220202

           m.period_num;



    CURSOR c_titles IS

    SELECT *

      FROM ajc.ajc_bc_ar_days_late_dt_titles;



    v_column1    VARCHAR2(100);

    v_column2    VARCHAR2(100);

    v_column3    VARCHAR2(100);

    v_column4    NUMBER;

    v_column5    NUMBER;

    v_column6    NUMBER;

    v_column7    NUMBER;

    v_column8    NUMBER;

    v_column9    NUMBER;

    v_column10   NUMBER;

    v_column11   NUMBER;

    v_column12   NUMBER;

    v_column13   NUMBER;

    v_column14   NUMBER;

    v_column15   NUMBER;

    v_column16   NUMBER;

    v_column17   NUMBER;



    -- 20230606

    v_column5_flag    VARCHAR2(1);

    v_column6_flag    VARCHAR2(1);

    v_column7_flag    VARCHAR2(1);

    v_column8_flag    VARCHAR2(1);

    v_column9_flag    VARCHAR2(1);

    v_column10_flag   VARCHAR2(1);

    v_column11_flag   VARCHAR2(1);

    v_column12_flag   VARCHAR2(1);

    v_column13_flag   VARCHAR2(1);

    v_column14_flag   VARCHAR2(1);

    v_column15_flag   VARCHAR2(1);

    v_column16_flag   VARCHAR2(1);

    -- 20230606



    -- Inicio Agregado SBanchieri 20220221

    v_total_months   NUMBER;

    -- Fin Agregado SBanchieri 20220221



  BEGIN



    DELETE ajc.ajc_bc_ar_days_late_dt_rows;



    fnd_file.put_line(fnd_file.log,'p_org_id: ' || p_org_id);

    fnd_file.put_line(fnd_file.log,'p_customer_name_low: ' || p_customer_name_low);

    fnd_file.put_line(fnd_file.log,'p_customer_name_high: ' || p_customer_name_high);

    fnd_file.put_line(fnd_file.log,'p_customer_number_low: ' || p_customer_number_low);

    fnd_file.put_line(fnd_file.log,'p_customer_number_high: ' || p_customer_number_high);

    fnd_file.put_line(fnd_file.log,'p_trx_date_from: ' || p_trx_date_from);

    fnd_file.put_line(fnd_file.log,'p_trx_date_to: ' || p_trx_date_to);



    FOR crc IN c_region_customer LOOP



      fnd_file.put_line(fnd_file.log,'crc.country: ' || crc.country);

      fnd_file.put_line(fnd_file.log,'crc.customer_name: ' || crc.customer_name);

      fnd_file.put_line(fnd_file.log,'crc.customer_number: ' || crc.customer_number);



      v_column1 := crc.region;

      v_column2 := crc.country;

      v_column3 := crc.customer_name;

      v_column4 := crc.customer_number;



      -- Inicio Agregado SBanchieri 20220203

      v_column5 := 0;

      v_column6 := 0;

      v_column7 := 0;

      v_column8 := 0;

      v_column9 := 0;

      v_column10 := 0;

      v_column11 := 0;

      v_column12 := 0;

      v_column13 := 0;

      v_column14 := 0;

      v_column15 := 0;

      v_column16 := 0;

      v_column17 := 0;

      -- Fin Agregado SBanchieri 20220203



      FOR cr IN c_rows ( crc.country,

                         crc.customer_name ) LOOP



        fnd_file.put_line(fnd_file.log,'cr.period: ' || cr.period);

        fnd_file.put_line(fnd_file.log,'cr.weighted_average_days_late: ' || cr.weighted_average_days_late);



        FOR ct IN c_titles LOOP



          IF ( cr.period = ct.column5 ) THEN

            fnd_file.put_line(fnd_file.log,'ct.column5: ' || ct.column5);

            v_column5 := cr.weighted_average_days_late;

          ELSIF ( cr.period = ct.column6 ) THEN

            fnd_file.put_line(fnd_file.log,'ct.column6: ' || ct.column6);

            v_column6 := cr.weighted_average_days_late;

          ELSIF ( cr.period = ct.column7 ) THEN

            fnd_file.put_line(fnd_file.log,'ct.column7: ' || ct.column7);

            v_column7 := cr.weighted_average_days_late;

          ELSIF ( cr.period = ct.column8 ) THEN

            fnd_file.put_line(fnd_file.log,'ct.column8: ' || ct.column8);

            v_column8 := cr.weighted_average_days_late;

          ELSIF ( cr.period = ct.column9 ) THEN

            fnd_file.put_line(fnd_file.log,'ct.column9: ' || ct.column9);

            v_column9 := cr.weighted_average_days_late;

          ELSIF ( cr.period = ct.column10 ) THEN

            fnd_file.put_line(fnd_file.log,'ct.column10: ' || ct.column10);

            v_column10 := cr.weighted_average_days_late;

          ELSIF ( cr.period = ct.column11 ) THEN

            fnd_file.put_line(fnd_file.log,'ct.column11: ' || ct.column11);

            v_column11 := cr.weighted_average_days_late;

          ELSIF ( cr.period = ct.column12 ) THEN

            fnd_file.put_line(fnd_file.log,'ct.column12: ' || ct.column12);

            v_column12 := cr.weighted_average_days_late;

          ELSIF ( cr.period = ct.column13 ) THEN

            fnd_file.put_line(fnd_file.log,'ct.column13: ' || ct.column13);

            v_column13 := cr.weighted_average_days_late;

          ELSIF ( cr.period = ct.column14 ) THEN

            fnd_file.put_line(fnd_file.log,'ct.column14: ' || ct.column14);

            v_column14 := cr.weighted_average_days_late;

          ELSIF ( cr.period = ct.column15 ) THEN

            fnd_file.put_line(fnd_file.log,'ct.column15: ' || ct.column15);

            v_column15 := cr.weighted_average_days_late;

          ELSIF ( cr.period = ct.column16 ) THEN

            fnd_file.put_line(fnd_file.log,'ct.column16: ' || ct.column16);

            v_column16 := cr.weighted_average_days_late;

          END IF;         



        END LOOP;



      END LOOP; 



      -- Pone 0.01 los meses que no tuvieron movimiento

      -- 20230606

      v_column5_flag := 'N';

      v_column6_flag := 'N';

      v_column7_flag := 'N';

      v_column8_flag := 'N';

      v_column9_flag := 'N';

      v_column10_flag := 'N';

      v_column11_flag := 'N';

      v_column12_flag := 'N';

      v_column13_flag := 'N';

      v_column14_flag := 'N';

      v_column15_flag := 'N';

      v_column16_flag := 'N';



      FOR ct IN c_titles LOOP



        FOR cr IN c_rows ( crc.country,

                           crc.customer_name ) LOOP



          IF ( ct.column5 = cr.period ) THEN v_column5_flag := 'Y'; END IF;

          IF ( ct.column6 = cr.period ) THEN v_column6_flag := 'Y'; END IF;

          IF ( ct.column7 = cr.period ) THEN v_column7_flag := 'Y'; END IF;

          IF ( ct.column8 = cr.period ) THEN v_column8_flag := 'Y'; END IF;

          IF ( ct.column9 = cr.period ) THEN v_column9_flag := 'Y'; END IF;

          IF ( ct.column10 = cr.period ) THEN v_column10_flag := 'Y'; END IF;

          IF ( ct.column11 = cr.period ) THEN v_column11_flag := 'Y'; END IF;

          IF ( ct.column12 = cr.period ) THEN v_column12_flag := 'Y'; END IF;

          IF ( ct.column13 = cr.period ) THEN v_column13_flag := 'Y'; END IF;

          IF ( ct.column14 = cr.period ) THEN v_column14_flag := 'Y'; END IF;

          IF ( ct.column15 = cr.period ) THEN v_column15_flag := 'Y'; END IF;

          IF ( ct.column16 = cr.period ) THEN v_column16_flag := 'Y'; END IF;



        END LOOP;



      END LOOP;



      /*

      fnd_file.put_line(fnd_file.log,'v_column5_flag: ' || v_column5_flag);

      fnd_file.put_line(fnd_file.log,'v_column6_flag: ' || v_column6_flag);

      fnd_file.put_line(fnd_file.log,'v_column7_flag: ' || v_column7_flag);

      fnd_file.put_line(fnd_file.log,'v_column8_flag: ' || v_column8_flag);

      fnd_file.put_line(fnd_file.log,'v_column9_flag: ' || v_column9_flag);

      fnd_file.put_line(fnd_file.log,'v_column10_flag: ' || v_column10_flag);

      fnd_file.put_line(fnd_file.log,'v_column11_flag: ' || v_column11_flag);

      fnd_file.put_line(fnd_file.log,'v_column12_flag: ' || v_column12_flag);

      fnd_file.put_line(fnd_file.log,'v_column13_flag: ' || v_column13_flag);

      fnd_file.put_line(fnd_file.log,'v_column14_flag: ' || v_column14_flag);

      fnd_file.put_line(fnd_file.log,'v_column15_flag: ' || v_column15_flag);

      fnd_file.put_line(fnd_file.log,'v_column16_flag: ' || v_column16_flag);

      */



      -- Se setean en 0.01 si el mes no tuvo pagos

      IF ( v_column5_flag = 'N' ) THEN v_column5 := 0.01; END IF;

      IF ( v_column6_flag = 'N' ) THEN v_column6 := 0.01; END IF;

      IF ( v_column7_flag = 'N' ) THEN v_column7 := 0.01; END IF;

      IF ( v_column8_flag = 'N' ) THEN v_column8 := 0.01; END IF;

      IF ( v_column9_flag = 'N' ) THEN v_column9 := 0.01; END IF;

      IF ( v_column10_flag = 'N' ) THEN v_column10 := 0.01; END IF;

      IF ( v_column11_flag = 'N' ) THEN v_column11 := 0.01; END IF;

      IF ( v_column12_flag = 'N' ) THEN v_column12 := 0.01; END IF;

      IF ( v_column13_flag = 'N' ) THEN v_column13 := 0.01; END IF;

      IF ( v_column14_flag = 'N' ) THEN v_column14 := 0.01; END IF;

      IF ( v_column15_flag = 'N' ) THEN v_column15 := 0.01; END IF;

      IF ( v_column16_flag = 'N' ) THEN v_column16 := 0.01; END IF;      

      -- 20230606     



      -- Inicio Agregado SBanchieri 20220221

      v_total_months := 0;



      IF ( v_column5 != 0.01 ) THEN v_total_months := v_total_months + 1; END IF;

      IF ( v_column6 != 0.01 ) THEN v_total_months := v_total_months + 1; END IF;

      IF ( v_column7 != 0.01 ) THEN v_total_months := v_total_months + 1; END IF;

      IF ( v_column8 != 0.01 ) THEN v_total_months := v_total_months + 1; END IF;

      IF ( v_column9 != 0.01 ) THEN v_total_months := v_total_months + 1; END IF;

      IF ( v_column10 != 0.01 ) THEN v_total_months := v_total_months + 1; END IF;

      IF ( v_column11 != 0.01 ) THEN v_total_months := v_total_months + 1; END IF;

      IF ( v_column12 != 0.01 ) THEN v_total_months := v_total_months + 1; END IF;

      IF ( v_column13 != 0.01 ) THEN v_total_months := v_total_months + 1; END IF;

      IF ( v_column14 != 0.01 ) THEN v_total_months := v_total_months + 1; END IF;

      IF ( v_column15 != 0.01 ) THEN v_total_months := v_total_months + 1; END IF;

      IF ( v_column16 != 0.01 ) THEN v_total_months := v_total_months + 1; END IF;

      IF ( v_total_months = 0 ) THEN v_total_months := 1; END IF;

      -- Fin Agregado SBanchieri 20220221



      /* 

      -- 20230104

      SELECT ROUND(( v_column5 + v_column6 + v_column7 + v_column8 + v_column9 + 

                     -- Inicio Modificado SBanchieri 20220221

                     -- v_column10 + v_column11 + v_column12 + v_column13 + v_column14 + v_column15 ) / 12,2)

                     v_column10 + v_column11 + v_column12 + v_column13 + v_column14 + v_column15 + v_column16 ) / v_total_months,2)

                     -- Fin Modificado SBanchieri 20220221

        INTO v_column17

        FROM DUAL;

      */

      SELECT ROUND(( DECODE(v_column5,0.01,0,v_column5) + 

                     DECODE(v_column6,0.01,0,v_column6) + 

                     DECODE(v_column7,0.01,0,v_column7) + 

                     DECODE(v_column8,0.01,0,v_column8) + 

                     DECODE(v_column9,0.01,0,v_column9) + 

                     DECODE(v_column10,0.01,0,v_column10) + 

                     DECODE(v_column11,0.01,0,v_column11) + 

                     DECODE(v_column12,0.01,0,v_column12) + 

                     DECODE(v_column13,0.01,0,v_column13) + 

                     DECODE(v_column14,0.01,0,v_column14) + 

                     DECODE(v_column15,0.01,0,v_column15) + 

                     DECODE(v_column16,0.01,0,v_column16) ) / v_total_months,2)

        INTO v_column17

        FROM DUAL;

      -- 20230104



      INSERT 

        INTO ajc.ajc_bc_ar_days_late_dt_rows 

             ( COLUMN1,

               COLUMN2,  

               COLUMN3,  

               COLUMN4,  

               COLUMN5,  

               COLUMN6,  

               COLUMN7,

               COLUMN8,

               COLUMN9,

               COLUMN10,

               COLUMN11,

               COLUMN12,

               COLUMN13,

               COLUMN14,

               COLUMN15,

               COLUMN16,

               COLUMN17 )  

      VALUES ( v_column1,

               v_column2,

               v_column3,

               v_column4,

               v_column5,

               v_column6,

               v_column7,

               v_column8,

               v_column9,

               v_column10,

               v_column11,

               v_column12,

               v_column13,

               v_column14,

               v_column15,

               v_column16,

               v_column17 );



    END LOOP;



    COMMIT;



  END FILL_ROWS_TABLE_P;



  -- Inicio Agregado SBanchieri 20220221

  PROCEDURE FILL_TOTAL_ZONE_P IS



      -- Zonas

      CURSOR c_zonas IS

      SELECT column1,

             column2

        FROM ajc.ajc_bc_ar_days_late_dt_rows

       -- WHERE column1 = 'AFGH'

    GROUP BY column1,

             column2

    ORDER BY column1,

             column2;



    -- Registros por Zona

    CURSOR c_zonas_rows ( pc_zona   IN   VARCHAR2 ) IS

    SELECT *

      FROM ajc.ajc_bc_ar_days_late_dt_rows

     WHERE column2 = pc_zona;



    v_divisor5    NUMBER := 0;

    v_divisor6    NUMBER := 0;

    v_divisor7    NUMBER := 0;

    v_divisor8    NUMBER := 0;

    v_divisor9    NUMBER := 0;

    v_divisor10   NUMBER := 0;

    v_divisor11   NUMBER := 0;

    v_divisor12   NUMBER := 0;

    v_divisor13   NUMBER := 0;

    v_divisor14   NUMBER := 0;

    v_divisor15   NUMBER := 0;

    v_divisor16   NUMBER := 0;

    v_divisor17    NUMBER := 0;



    v_total5      NUMBER;

    v_total6      NUMBER;

    v_total7      NUMBER;

    v_total8      NUMBER;

    v_total9      NUMBER;

    v_total10     NUMBER;

    v_total11     NUMBER;

    v_total12     NUMBER;

    v_total13     NUMBER;

    v_total14     NUMBER;

    v_total15     NUMBER;

    v_total16     NUMBER;

    v_total17     NUMBER;



  BEGIN



    DELETE ajc.ajc_bc_ar_days_late_dt_zone_r;



    FOR cz IN c_zonas LOOP



      v_divisor5 := 0;

      v_divisor6 := 0;

      v_divisor7 := 0;

      v_divisor8 := 0;

      v_divisor9 := 0;

      v_divisor10 := 0;

      v_divisor11 := 0;

      v_divisor12 := 0;

      v_divisor13 := 0;

      v_divisor14 := 0;

      v_divisor15 := 0;

      v_divisor16 := 0;

      v_divisor17 := 0;



      v_total5 := 0;

      v_total6 := 0;

      v_total7 := 0;

      v_total8 := 0;

      v_total9 := 0;

      v_total10 := 0;

      v_total11 := 0;

      v_total12 := 0;

      v_total13 := 0;

      v_total14 := 0;

      v_total15 := 0;

      v_total16 := 0;

      v_total17 := 0;



      FOR czr IN c_zonas_rows ( cz.column2 ) LOOP



        -- Totales

        IF ( czr.column5 != 0.01 ) THEN v_total5 := v_total5 + czr.column5; END IF;

        IF ( czr.column6 != 0.01 ) THEN v_total6 := v_total6 + czr.column6; END IF;

        IF ( czr.column7 != 0.01 ) THEN v_total7 := v_total7 + czr.column7; END IF;

        IF ( czr.column8 != 0.01 ) THEN v_total8 := v_total8 + czr.column8; END IF;

        IF ( czr.column9 != 0.01 ) THEN v_total9 := v_total9 + czr.column9; END IF;

        IF ( czr.column10 != 0.01 ) THEN v_total10 := v_total10 + czr.column10; END IF;

        IF ( czr.column11 != 0.01 ) THEN v_total11 := v_total11 + czr.column11; END IF;

        IF ( czr.column12 != 0.01 ) THEN v_total12 := v_total12 + czr.column12; END IF;

        IF ( czr.column13 != 0.01 ) THEN v_total13 := v_total13 + czr.column13; END IF;

        IF ( czr.column14 != 0.01 ) THEN v_total14 := v_total14 + czr.column14; END IF;

        IF ( czr.column15 != 0.01 ) THEN v_total15 := v_total15 + czr.column15; END IF;

        IF ( czr.column16 != 0.01 ) THEN v_total16 := v_total16 + czr.column16; END IF;

        IF ( czr.column17 != 0.01 ) THEN v_total17 := v_total17 + czr.column17; END IF;



        -- Divisores

        IF ( czr.column5 != 0.01 ) THEN v_divisor5 := v_divisor5 + 1; END IF;

        IF ( czr.column6 != 0.01 ) THEN v_divisor6 := v_divisor6 + 1; END IF;

        IF ( czr.column7 != 0.01 ) THEN v_divisor7 := v_divisor7 + 1; END IF;

        IF ( czr.column8 != 0.01 ) THEN v_divisor8 := v_divisor8 + 1; END IF;

        IF ( czr.column9 != 0.01 ) THEN v_divisor9 := v_divisor9 + 1; END IF;

        IF ( czr.column10 != 0.01 ) THEN v_divisor10 := v_divisor10 + 1; END IF;

        IF ( czr.column11 != 0.01 ) THEN v_divisor11 := v_divisor11 + 1; END IF;

        IF ( czr.column12 != 0.01 ) THEN v_divisor12 := v_divisor12 + 1; END IF;

        IF ( czr.column13 != 0.01 ) THEN v_divisor13 := v_divisor13 + 1; END IF;

        IF ( czr.column14 != 0.01 ) THEN v_divisor14 := v_divisor14 + 1; END IF;

        IF ( czr.column15 != 0.01 ) THEN v_divisor15 := v_divisor15 + 1; END IF;

        IF ( czr.column16 != 0.01 ) THEN v_divisor16 := v_divisor16 + 1; END IF;

        IF ( czr.column17 != 0.01 ) THEN v_divisor17 := v_divisor17 + 1; END IF;



      END LOOP;



      -- Se salva el divisor 0

      IF ( v_divisor5 = 0 ) THEN v_divisor5 := 1; END IF;

      IF ( v_divisor6 = 0 ) THEN v_divisor6 := 1; END IF;

      IF ( v_divisor7 = 0 ) THEN v_divisor7 := 1; END IF;

      IF ( v_divisor8 = 0 ) THEN v_divisor8 := 1; END IF;

      IF ( v_divisor9 = 0 ) THEN v_divisor9 := 1; END IF;

      IF ( v_divisor10 = 0 ) THEN v_divisor10 := 1; END IF;

      IF ( v_divisor11 = 0 ) THEN v_divisor11 := 1; END IF;

      IF ( v_divisor12 = 0 ) THEN v_divisor12 := 1; END IF;

      IF ( v_divisor13 = 0 ) THEN v_divisor13 := 1; END IF;

      IF ( v_divisor14 = 0 ) THEN v_divisor14 := 1; END IF;

      IF ( v_divisor15 = 0 ) THEN v_divisor15 := 1; END IF;

      IF ( v_divisor16 = 0 ) THEN v_divisor16 := 1; END IF;

      IF ( v_divisor17 = 0 ) THEN v_divisor17 := 1; END IF;



      INSERT 

        INTO ajc.ajc_bc_ar_days_late_dt_zone_r

           ( column1,

             column2,

             column5,

             column6,

             column7,

             column8,

             column9,

             column10,

             column11,

             column12,

             column13,

             column14,

             column15,

             column16,

             column17 )

    VALUES ( cz.column1,

             cz.column2,

             ROUND(v_total5 / v_divisor5,2),      

             ROUND(v_total6 / v_divisor6,2),      

             ROUND(v_total7 / v_divisor7,2),      

             ROUND(v_total8 / v_divisor8,2),      

             ROUND(v_total9 / v_divisor9,2),      

             ROUND(v_total10 / v_divisor10,2),      

             ROUND(v_total11 / v_divisor11,2),      

             ROUND(v_total12 / v_divisor12,2),      

             ROUND(v_total13 / v_divisor13,2),      

             ROUND(v_total14 / v_divisor14,2),      

             ROUND(v_total15 / v_divisor15,2),      

             ROUND(v_total16 / v_divisor16,2),

             ROUND(v_total17 / v_divisor17,2) );



    END LOOP;



    COMMIT;



  END FILL_TOTAL_ZONE_P;



  PROCEDURE FILL_TOTAL_P IS



      -- Total Promedio de Zonas

      CURSOR c_zonas IS

      SELECT *

        FROM ajc.ajc_bc_ar_days_late_dt_zone_r;



    v_divisor5    NUMBER := 0;

    v_divisor6    NUMBER := 0;

    v_divisor7    NUMBER := 0;

    v_divisor8    NUMBER := 0;

    v_divisor9    NUMBER := 0;

    v_divisor10   NUMBER := 0;

    v_divisor11   NUMBER := 0;

    v_divisor12   NUMBER := 0;

    v_divisor13   NUMBER := 0;

    v_divisor14   NUMBER := 0;

    v_divisor15   NUMBER := 0;

    v_divisor16   NUMBER := 0;

    v_divisor17    NUMBER := 0;



    v_total5      NUMBER;

    v_total6      NUMBER;

    v_total7      NUMBER;

    v_total8      NUMBER;

    v_total9      NUMBER;

    v_total10     NUMBER;

    v_total11     NUMBER;

    v_total12     NUMBER;

    v_total13     NUMBER;

    v_total14     NUMBER;

    v_total15     NUMBER;

    v_total16     NUMBER;

    v_total17      NUMBER;



  BEGIN



    DELETE ajc.ajc_bc_ar_days_late_dt_total_r;



    v_divisor5 := 0;

    v_divisor6 := 0;

    v_divisor7 := 0;

    v_divisor8 := 0;

    v_divisor9 := 0;

    v_divisor10 := 0;

    v_divisor11 := 0;

    v_divisor12 := 0;

    v_divisor13 := 0;

    v_divisor14 := 0;

    v_divisor15 := 0;

    v_divisor16 := 0;

    v_divisor17 := 0;



    v_total5 := 0;

    v_total6 := 0;

    v_total7 := 0;

    v_total8 := 0;

    v_total9 := 0;

    v_total10 := 0;

    v_total11 := 0;

    v_total12 := 0;

    v_total13 := 0;

    v_total14 := 0;

    v_total15 := 0;

    v_total16 := 0;

    v_total17 := 0;



    FOR cz IN c_zonas LOOP



      IF ( cz.column5 != 0.01 ) THEN v_total5 := v_total5 + cz.column5; END IF;

      IF ( cz.column6 != 0.01 ) THEN v_total6 := v_total6 + cz.column6; END IF;

      IF ( cz.column7 != 0.01 ) THEN v_total7 := v_total7 + cz.column7; END IF;

      IF ( cz.column8 != 0.01 ) THEN v_total8 := v_total8 + cz.column8; END IF;

      IF ( cz.column9 != 0.01 ) THEN v_total9 := v_total9 + cz.column9; END IF;

      IF ( cz.column10 != 0.01 ) THEN v_total10 := v_total10 + cz.column10; END IF;

      IF ( cz.column11 != 0.01 ) THEN v_total11 := v_total11 + cz.column11; END IF;

      IF ( cz.column12 != 0.01 ) THEN v_total12 := v_total12 + cz.column12; END IF;

      IF ( cz.column13 != 0.01 ) THEN v_total13 := v_total13 + cz.column13; END IF;

      IF ( cz.column14 != 0.01 ) THEN v_total14 := v_total14 + cz.column14; END IF;

      IF ( cz.column15 != 0.01 ) THEN v_total15 := v_total15 + cz.column15; END IF;

      IF ( cz.column16 != 0.01 ) THEN v_total16 := v_total16 + cz.column16; END IF;

      IF ( cz.column17 != 0.01 ) THEN v_total17 := v_total17 + cz.column17; END IF;



      -- Divisores

      IF ( cz.column5 != 0.01 ) THEN v_divisor5 := v_divisor5 + 1; END IF; 

      IF ( cz.column6 != 0.01 ) THEN v_divisor6 := v_divisor6 + 1; END IF; 

      IF ( cz.column7 != 0.01 ) THEN v_divisor7 := v_divisor7 + 1; END IF;

      IF ( cz.column8 != 0.01 ) THEN v_divisor8 := v_divisor8 + 1; END IF;

      IF ( cz.column9 != 0.01 ) THEN v_divisor9 := v_divisor9 + 1; END IF;

      IF ( cz.column10 != 0.01 ) THEN v_divisor10 := v_divisor10 + 1; END IF;

      IF ( cz.column11 != 0.01 ) THEN v_divisor11 := v_divisor11 + 1; END IF;

      IF ( cz.column12 != 0.01 ) THEN v_divisor12 := v_divisor12 + 1; END IF;

      IF ( cz.column13 != 0.01 ) THEN v_divisor13 := v_divisor13 + 1; END IF;

      IF ( cz.column14 != 0.01 ) THEN v_divisor14 := v_divisor14 + 1; END IF;

      IF ( cz.column15 != 0.01 ) THEN v_divisor15 := v_divisor15 + 1; END IF;

      IF ( cz.column16 != 0.01 ) THEN v_divisor16 := v_divisor16 + 1; END IF;

      IF ( cz.column17 != 0.01 ) THEN v_divisor17 := v_divisor17 + 1; END IF;



    END LOOP;



    -- Se salva el divisor 0

    IF ( v_divisor5 = 0 ) THEN v_divisor5 := 1; END IF;

    IF ( v_divisor6 = 0 ) THEN v_divisor6 := 1; END IF;

    IF ( v_divisor7 = 0 ) THEN v_divisor7 := 1; END IF;

    IF ( v_divisor8 = 0 ) THEN v_divisor8 := 1; END IF;

    IF ( v_divisor9 = 0 ) THEN v_divisor9 := 1; END IF;

    IF ( v_divisor10 = 0 ) THEN v_divisor10 := 1; END IF;

    IF ( v_divisor11 = 0 ) THEN v_divisor11 := 1; END IF;

    IF ( v_divisor12 = 0 ) THEN v_divisor12 := 1; END IF;

    IF ( v_divisor13 = 0 ) THEN v_divisor13 := 1; END IF;

    IF ( v_divisor14 = 0 ) THEN v_divisor14 := 1; END IF;

    IF ( v_divisor15 = 0 ) THEN v_divisor15 := 1; END IF;

    IF ( v_divisor16 = 0 ) THEN v_divisor16 := 1; END IF;

    IF ( v_divisor17 = 0 ) THEN v_divisor17 := 1; END IF;



      INSERT 

        INTO ajc.ajc_bc_ar_days_late_dt_total_r

           ( column5,

             column6,

             column7,

             column8,

             column9,

             column10,

             column11,

             column12,

             column13,

             column14,

             column15,

             column16,

             column17 )

    VALUES ( ROUND(v_total5 / v_divisor5,2),      

             ROUND(v_total6 / v_divisor6,2),      

             ROUND(v_total7 / v_divisor7,2),      

             ROUND(v_total8 / v_divisor8,2),      

             ROUND(v_total9 / v_divisor9,2),      

             ROUND(v_total10 / v_divisor10,2),      

             ROUND(v_total11 / v_divisor11,2),      

             ROUND(v_total12 / v_divisor12,2),      

             ROUND(v_total13 / v_divisor13,2),      

             ROUND(v_total14 / v_divisor14,2),      

             ROUND(v_total15 / v_divisor15,2),      

             ROUND(v_total16 / v_divisor16,2),

             ROUND(v_total17 / v_divisor17,2) );



    COMMIT;



  END FILL_TOTAL_P;

  -- Fin Agregado SBanchieri 20220221



END AJC_BC_AR_DAYS_LATE_DT_PKG;
