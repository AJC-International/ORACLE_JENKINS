PACKAGE AJC_BC_AR_DAYS_LATE_DT_PKG IS
 
  PROCEDURE FILL_TITLES_TABLE_P ( p_org_id          IN   NUMBER,
                                  p_trx_date_from   IN   VARCHAR2,
                                  p_trx_date_to     IN   VARCHAR2 );

  PROCEDURE FILL_ROWS_TABLE_P ( p_org_id                 IN   NUMBER,
                                p_customer_name_low      IN   VARCHAR2,
                                p_customer_name_high     IN   VARCHAR2,
                                p_customer_number_low    IN   VARCHAR2,
                                p_customer_number_high   IN   VARCHAR2,
                                p_trx_date_from          IN   VARCHAR2,
                                p_trx_date_to            IN   VARCHAR2 );

  -- Inicio Agregado SBanchieri 20220221
  PROCEDURE FILL_TOTAL_ZONE_P;

  PROCEDURE FILL_TOTAL_P;
  -- Fin Agregado SBanchieri 20220221

END AJC_BC_AR_DAYS_LATE_DT_PKG;
