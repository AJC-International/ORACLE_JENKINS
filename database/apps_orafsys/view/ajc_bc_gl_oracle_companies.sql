
  CREATE OR REPLACE FORCE EDITIONABLE VIEW "APPS_ORAFSYS"."AJC_BC_GL_ORACLE_COMPANIES" ("SEGMENT1", "DESCRIPTION") AS 
  SELECT vl.flex_value segment1, 
         vl.description description
    FROM fnd_flex_value_sets vs, 
         fnd_flex_values_vl vl
   WHERE vs.flex_value_set_name = 'AJC COMPANY'
     AND vs.flex_value_set_id = vl.flex_value_set_id
ORDER BY vl.flex_value
