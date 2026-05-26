
  CREATE OR REPLACE FORCE EDITIONABLE VIEW "APPS_ORAFSYS"."AJC_BC_GL_PTD_START_DATE" ("ORACLE_COMPANY_NUMBER", "PERIOD_NAME", "START_DATE", "PERIOD_YEAR", "PERIOD_NUM") AS 
  SELECT   bcc.oracle_company_number,
            gp.period_name,
            gp.start_date,
            gp.period_year,
            gp.period_num
     FROM   ajc_bc_companies bcc, gl_sets_of_books gsob, gl_periods gp
    WHERE       bcc.set_of_books_id = gsob.set_of_books_id
            AND gsob.period_set_name = gp.period_set_name
            AND TO_NUMBER (TO_CHAR (gp.start_date, 'YYYY')) >= 2021
            AND TO_NUMBER (TO_CHAR (gp.end_date, 'YYYY')) <= 2024 
