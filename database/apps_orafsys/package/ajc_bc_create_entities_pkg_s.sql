CREATE OR REPLACE PACKAGE ajc_bc_create_entities_pkg IS

  

  gv_user_id      NUMBER := fnd_global.user_id;

  gv_request_id   NUMBER := fnd_global.conc_request_id;



  FUNCTION payment_terms_f ( p_name             IN   VARCHAR2,

                             p_application      IN   VARCHAR2,

                             p_company_id       IN   VARCHAR2,

                             p_bc_environment   IN   VARCHAR2 ) RETURN NUMBER;



  -- AP

  FUNCTION payment_method_f ( p_name   IN   VARCHAR2 ) RETURN VARCHAR;



  -- AP

  FUNCTION pay_group_f ( p_name   IN   VARCHAR2 ) RETURN VARCHAR;



  -- AR

  FUNCTION collector_f ( p_name   IN   VARCHAR ) RETURN NUMBER;



  -- AR

  FUNCTION statement_cycle_f ( p_name   IN   VARCHAR ) RETURN NUMBER;



END ajc_bc_create_entities_pkg;
