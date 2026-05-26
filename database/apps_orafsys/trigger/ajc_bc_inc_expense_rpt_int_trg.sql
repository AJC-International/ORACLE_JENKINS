TRIGGER APPS_ORAFSYS.ajc_bc_inc_expense_rpt_int_trg 
AFTER INSERT ON AJC.AJC_INC_EXPENSE_RPT_INT
REFERENCING 
  NEW AS NEW
  OLD AS OLD
FOR EACH ROW
DECLARE
BEGIN

    INSERT 
      INTO AJC_BC_INC_EXPENSE_RPT_INT
         ( RECORD_ID,
           INVOICE_TYPE,
           SUPPLIER_NAME,
           SUPPLIER_NUMBER,
           SUPPLIER_SITE_CODE,
           INVOICE_DATE,
           INVOICE_NUMBER,
           CURRENCY_CODE,
           INVOICE_AMOUNT,
           DESCRIPTION,
           GL_DATE,
           LINE_NUM,
           LINE_TYPE,
           LINE_AMOUNT,
           DISTR_ACCOUNT,
           WORKSHEET_NUMBER,
           INVOICE_IMAGE_URL,
           REIMBURSE_FLAG,
           CREATION_DATE,
           CREATED_BY,
           LAST_UPDATE_DATE,
           LAST_UPDATED_BY,
           STATUS,
           ORG_ID,
           RESP_ID,
           ORACLE_SUPPLIER_NUM,
           ORACLE_SUPPLIER_SITE_CODE,
           ORACLE_INVOICE_NUM )
  VALUES ( :NEW.RECORD_ID,
           :NEW.INVOICE_TYPE,
           :NEW.SUPPLIER_NAME,
           :NEW.SUPPLIER_NUMBER,
           :NEW.SUPPLIER_SITE_CODE,
           :NEW.INVOICE_DATE,
           :NEW.INVOICE_NUMBER,
           :NEW.CURRENCY_CODE,
           :NEW.INVOICE_AMOUNT,
           :NEW.DESCRIPTION,
           :NEW.GL_DATE,
           :NEW.LINE_NUM,
           :NEW.LINE_TYPE,
           :NEW.LINE_AMOUNT,
           :NEW.DISTR_ACCOUNT,
           :NEW.WORKSHEET_NUMBER,
           :NEW.INVOICE_IMAGE_URL,
           :NEW.REIMBURSE_FLAG,
           :NEW.CREATION_DATE,
           :NEW.CREATED_BY,
           :NEW.LAST_UPDATE_DATE,
           :NEW.LAST_UPDATED_BY,
           :NEW.STATUS,
           :NEW.ORG_ID,
           :NEW.RESP_ID,
           :NEW.ORACLE_SUPPLIER_NUM,
           :NEW.ORACLE_SUPPLIER_SITE_CODE,
           :NEW.ORACLE_INVOICE_NUM );

EXCEPTION
  WHEN OTHERS THEN
    NULL;

END;           
