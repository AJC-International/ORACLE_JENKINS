TRIGGER APPS_ORAFSYS.AJC_BC_ABBYY_INVOICES_INT_TRG
AFTER INSERT ON AJC.AJC_AP_ABBYY_INVOICES_INT
REFERENCING
  NEW AS NEW
  OLD AS OLD
FOR EACH ROW
-- 20230703
 WHEN ( NEW.org_id != 5387 ) DECLARE
BEGIN

    INSERT
      INTO AJC_BC_ABBYY_INVOICES_INT
           ( ORG_ID, 
             VENDOR_ID, 
             VENDOR_SITE_CODE, 
             ADDRESS_LINE1, 
             ADDRESS_LINE2, 
             ADDRESS_LINE3, 
             CITY, 
             STATE, 
             ZIP, 
             PROVINCE, 
             COUNTRY, 
             INVOICE_NUM, 
             INVOICE_DATE, 
             INVOICE_TYPE_LOOKUP_CODE, 
             INVOICE_AMOUNT, 
             INVOICE_CURRENCY_CODE, 
             DESCRIPTION, 
             WORKSHEET_NUMBER, 
             STATUS_CODE, 
             ERROR_MESSAGE, 
             CREATED_BY, 
             CREATION_DATE, 
             LAST_UPDATED_BY, 
             LAST_UPDATE_DATE, 
             LAST_UPDATE_LOGIN, 
             REQUEST_ID, 
             ABBYY_USER_NAME, 
             FILE_PATH, 
             INVOICE_ID, 
             VENDOR_NAME, 
             VENDOR_NUM )
    VALUES ( :NEW.ORG_ID, 
             :NEW.VENDOR_ID, 
             :NEW.VENDOR_SITE_CODE, 
             :NEW.ADDRESS_LINE1, 
             :NEW.ADDRESS_LINE2, 
             :NEW.ADDRESS_LINE3, 
             :NEW.CITY, 
             :NEW.STATE, 
             :NEW.ZIP, 
             :NEW.PROVINCE, 
             :NEW.COUNTRY, 
             :NEW.INVOICE_NUM, 
             :NEW.INVOICE_DATE, 
             :NEW.INVOICE_TYPE_LOOKUP_CODE, 
             :NEW.INVOICE_AMOUNT, 
             :NEW.INVOICE_CURRENCY_CODE, 
             :NEW.DESCRIPTION, 
             :NEW.WORKSHEET_NUMBER, 
             :NEW.STATUS_CODE, 
             :NEW.ERROR_MESSAGE, 
             :NEW.CREATED_BY, 
             :NEW.CREATION_DATE, 
             :NEW.LAST_UPDATED_BY, 
             :NEW.LAST_UPDATE_DATE, 
             :NEW.LAST_UPDATE_LOGIN, 
             :NEW.REQUEST_ID, 
             :NEW.ABBYY_USER_NAME, 
             :NEW.FILE_PATH, 
             :NEW.INVOICE_ID, 
             :NEW.VENDOR_NAME, 
             :NEW.VENDOR_NUM );

EXCEPTION
  WHEN OTHERS THEN
    NULL;

END;
