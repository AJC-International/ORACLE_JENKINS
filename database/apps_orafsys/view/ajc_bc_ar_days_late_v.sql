
  CREATE OR REPLACE FORCE EDITIONABLE VIEW "APPS_ORAFSYS"."AJC_BC_AR_DAYS_LATE_V" ("ORGANIZATION_NAME", "CUSTOMER_NAME", "CUSTOMER_NUMBER", "TRX_NUMBER", "TRX_DATE", "DUE_DATE", "TERM_NAME", "ACTUAL_DATE_CLOSED", "DAYS_LATE", "INVOICE_CURRENCY_CODE", "AMOUNT_DUE_ORIGINAL", "COMMENTS", "PURCHASE_ORDER", "TYPE_NAME", "BATCH_SOURCE_NAME", "PERIOD_YEAR", "PERIOD_NUM", "PERIOD_NAME", "GL_DATE", "GL_DATE_CLOSED", "CUSTOMER_TRX_ID", "ORG_ID", "AMOUNT_X_DAYS_LATE") AS 
  SELECT haou.name organization_name,
         hp.party_name customer_name,
         hca.account_number customer_number,
         aps.trx_number,
         aps.trx_date,
         aps.due_date,
         arpt_sql_func_util.get_term_details (aps.term_id, 'NAME')
            term_name,
         aps.actual_date_closed,
         NVL (aps.actual_date_closed, TRUNC (SYSDATE)) - aps.due_date
            days_late,
         aps.invoice_currency_code,
         aps.amount_due_original,
         rct.comments,
         rct.purchase_order,
         rctt.name type_name,
         rbs.name batch_source_name,
         gp.period_year,
         --decode(gp.period_set_name, 'AJC CALENDAR', gp.period_year - 1, gp.period_year) period_year,
         gp.period_num,
         gp.period_name,
         aps.gl_date,
         aps.gl_date_closed                  --       ,aps.amount_applied
                                 --       ,aps.amount_line_items_original
                                              --       ,aps.days_past_due
                                       --       ,aps.amount_due_remaining
                                                     --       ,aps.status
                                                      --       ,aps.class
                                                   --       ,aps.due_days
                                              --       ,aps.rat_term_name
         ,
         aps.customer_trx_id,
         aps.org_id,
         (NVL (aps.actual_date_closed, TRUNC (SYSDATE)) - aps.due_date)
         * aps.amount_due_original
            amount_x_days_late
    FROM atisprod.ar_payment_schedules_all aps,
         gl_periods gp,
         financials_system_params_all fps,
         gl_sets_of_books gsob,
         hr_all_organization_units haou,
         hz_cust_accounts hca,
         hz_parties hp,
         ra_customer_trx_all rct,
         ra_batch_sources_all rbs,
         ra_cust_trx_types_all rctt
   WHERE aps.class = 'INV'
     AND aps.status = 'CL'
     AND gsob.set_of_books_id = fps.set_of_books_id
     AND gp.period_set_name = gsob.period_set_name
     -- Inicio Modificacion SBanchieri 20210202
     -- and   aps.gl_date between gp.start_date and gp.end_date
     AND aps.actual_date_closed BETWEEN gp.start_date AND gp.end_date
     --
     AND aps.org_id = haou.organization_id
     AND aps.org_id = fps.org_id
     AND aps.customer_id = hca.cust_account_id
     AND hca.party_id = hp.party_id
     AND aps.customer_trx_id = rct.customer_trx_id
     AND rct.batch_source_id = rbs.batch_source_id
     AND rct.org_id = rbs.org_id
     AND rct.cust_trx_type_id = rctt.cust_trx_type_id
     AND rct.org_id = rctt.org_id
     AND rctt.name != 'ZMG INV ACCR'
     -- and aps.customer_id = 87715
     -- and aps.trx_date > to_date('20200101','yyyymmdd')
     -- and aps.org_id = 5387
ORDER BY gp.period_year, gp.period_num
