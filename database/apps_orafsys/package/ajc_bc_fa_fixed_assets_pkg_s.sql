PACKAGE AJC_BC_FA_FIXED_ASSETS_PKG AS
  
  gv_request_id   NUMBER := fnd_global.conc_request_id;

  FUNCTION get_deprn_reserve ( p_asset_id         IN   NUMBER,
                               p_book_type_code   IN   VARCHAR2,
                               p_period_name      IN   VARCHAR2,
                               p_cost             IN   NUMBER ) RETURN NUMBER;

  PROCEDURE main_p ( retcode               OUT   NUMBER,
                     errbuf                OUT   VARCHAR2,
                     p_book_type_code       IN   VARCHAR2,
                     p_delete_final_table   IN   VARCHAR2,
                     p_period_name          IN   VARCHAR2 );

END AJC_BC_FA_FIXED_ASSETS_PKG;
