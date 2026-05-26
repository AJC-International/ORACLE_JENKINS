PACKAGE ajcl_bc_accounts_pkg AS
-- Creation: SBANCHIERI 23-AUG-2023
  
  gv_bc_company_name   VARCHAR2(200) := 'LOGIS-USA-USD';
  gv_bc_company_id     VARCHAR2(200);

  -- Trae de BC la obligatoriedad de las dimensiones para cada cuenta y lo guarda en la tabla ajcl_bc_account_dimensions
  PROCEDURE main_p ( p_bc_environment   IN   VARCHAR2 );

  -- Determina si la dimension es obligatoria en BC                   
  FUNCTION account_dim_required ( p_bc_environment   IN   VARCHAR2,
                                  p_account          IN   VARCHAR2,
                                  p_dimension        IN   VARCHAR2,
                                  p_value            IN   VARCHAR2 ) RETURN VARCHAR2;

  FUNCTION get_dimension_value ( p_oracle_segment   IN   VARCHAR2,
                                 p_oracle_value     IN   VARCHAR2,
                                 p_bc_dimension     IN   VARCHAR2 ) RETURN VARCHAR2;

END ajcl_bc_accounts_pkg;
