PACKAGE AJC_BC_J_ACCOUNT_DIM_PKG AS

  gv_bc_environment         VARCHAR2(100);

  gv_company_id             VARCHAR2(200) := '26fb86f1-2b58-ec11-9f08-002248210987'; 
  gv_company_name           VARCHAR2(200) := 'Master Data';

  PROCEDURE main_p ( p_bc_environment   IN   VARCHAR2,
                     p_request_id       IN   NUMBER );

  FUNCTION account_dim_required ( p_account     IN   VARCHAR2,
                                  p_dimension   IN   VARCHAR2,
                                  p_value       IN   VARCHAR2 ) RETURN VARCHAR2;

END AJC_BC_J_ACCOUNT_DIM_PKG;
