TRIGGER APPS_ORAFSYS.ajcl_bc_trv_tpay_int_trg 

AFTER INSERT ON AJC.AJCL_TRV_TPAY_INV_INT

REFERENCING 

  NEW AS NEW

  OLD AS OLD

FOR EACH ROW

DECLARE

BEGIN



    INSERT 

      INTO AJCL_BC_TRV_TPAY_INV_INT

         (   RECORD_ID,

              PAYMENT_KEY,

              VENDOR_KEY,

              BROKER_REFERENCE_NUM,

              CARRIER_INVOICE_NUM,

              NET_AMOUNT,

              PAYMENT_DATE,

              TPAY_PAYMENT_ID,

              MGATE_SO,

              INVOICE_IMAGE_URL,

              CREATION_DATE,

              CREATED_BY,

              LAST_UPDATE_DATE,

              LAST_UPDATED_BY,

              STATUS,

              ORACLE_VENDOR_ID,

              ORACLE_VENDOR_SITE_ID)

  VALUES 

         (   :NEW.RECORD_ID,

              :NEW.PAYMENT_KEY,

              :NEW.VENDOR_KEY,

              :NEW.BROKER_REFERENCE_NUM,

              :NEW.CARRIER_INVOICE_NUM,

              :NEW.NET_AMOUNT,

              :NEW.PAYMENT_DATE,

              :NEW.TPAY_PAYMENT_ID,

              :NEW.MGATE_SO,

              :NEW.INVOICE_IMAGE_URL,

              :NEW.CREATION_DATE,

              :NEW.CREATED_BY,

              :NEW.LAST_UPDATE_DATE,

              :NEW.LAST_UPDATED_BY,

              :NEW.STATUS,

              :NEW.ORACLE_VENDOR_ID,

              :NEW.ORACLE_VENDOR_SITE_ID);





EXCEPTION

  WHEN OTHERS THEN

    NULL;



END;

