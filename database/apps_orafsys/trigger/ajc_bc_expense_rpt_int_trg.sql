TRIGGER APPS_ORAFSYS.ajc_bc_expense_rpt_int_trg 

AFTER INSERT ON AJC.AJC_EXPENSE_RPT_INT

REFERENCING 

  NEW AS NEW

  OLD AS OLD

FOR EACH ROW

DECLARE

BEGIN



    INSERT 

      INTO AJCL_BC_EXPENSE_RPT_INT

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

           CREATION_DATE,

           CREATED_BY,

           LAST_UPDATE_DATE,

           LAST_UPDATED_BY,

           STATUS )

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

           :NEW.CREATION_DATE,

           :NEW.CREATED_BY,

           :NEW.LAST_UPDATE_DATE,

           :NEW.LAST_UPDATED_BY,

           :NEW.STATUS);



EXCEPTION

  WHEN OTHERS THEN

    NULL;



END;

