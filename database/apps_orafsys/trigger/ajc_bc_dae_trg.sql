TRIGGER AJC_BC_DAE_TRG

AFTER INSERT OR UPDATE ON "AR"."CUSTOMER_DAE_ADOP_HIST"

REFERENCING 

  NEW AS NEW

  OLD AS OLD

FOR EACH ROW

DECLARE



  v_exists   NUMBER;



BEGIN



  SELECT COUNT(1)

    INTO v_exists

    FROM AJC_BC_CUSTOMERS_DAE

   WHERE status = 'NEW'

     AND customer_id = :NEW.customer_id

     AND request_id IS NULL;



  -- No existe, se inserta

  IF ( v_exists = 0 ) THEN



    INSERT 

      INTO AJC_BC_CUSTOMERS_DAE 

           ( CUSTOMER_ID,

             DAE,

             CREATION_DATE,

             STATUS ) 

    VALUES ( :NEW.customer_id,

             :NEW.dae,

             SYSDATE,

             'NEW' );



  -- Existe y aun no fue procesado, se actualiza

  ELSE



    UPDATE AJC_BC_CUSTOMERS_DAE

       SET DAE = :NEW.dae,

           creation_date = SYSDATE

     WHERE customer_id = :NEW.customer_id

       AND status = 'NEW'

       AND request_id IS NULL;



  END IF;



EXCEPTION

  WHEN OTHERS THEN

    ajc_bc_ws_utils_pkg.send_email ( p_to => 'sbanchieri@gmail.com,lkusnier@ajcgroup.com',

                                     p_subject => 'AJC BC AR Customers DAE Interface - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'),

                                     p_message => 'TRIGGER BC DAE: AJC_BC_DAE_TRG | Error: ' || SQLERRM );



END AJC_BC_DAE_TRG;

