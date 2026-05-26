
  CREATE OR REPLACE FORCE EDITIONABLE VIEW "APPS_ORAFSYS"."AJC_BC_COMPANIES_V" ("BC_COMPANY_NAME", "BC_COMPANY_ID") AS 
  SELECT bc_company_name,
          bc_company_id
     FROM ajc_bc_companies 
    WHERE bc_company_id IS NOT NULL
 GROUP BY bc_company_name,
          bc_company_id
 ORDER BY bc_company_name
