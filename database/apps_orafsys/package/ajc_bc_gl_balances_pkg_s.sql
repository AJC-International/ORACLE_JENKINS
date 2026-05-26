PACKAGE ajc_bc_gl_balances_pkg IS

  gv_request_id   NUMBER := fnd_global.conc_request_id;

  FUNCTION get_period_year ( pc_oracle_company   IN   VARCHAR2,
                             p_date              IN   DATE,
                             p_oracle_company    IN   VARCHAR2 -- Se agrega y se envia el parametro original del request
                             ) RETURN NUMBER;

  FUNCTION translated_ending_balance ( p_set_of_books_id       IN   NUMBER,
                                       p_period_set_name       IN   VARCHAR2,
                                       p_period_year           IN   NUMBER,
                                       p_code_combination_id   IN   NUMBER ) RETURN NUMBER;

  PROCEDURE year_to_date_ytd ( retcode               OUT   NUMBER,
                               errbuf                OUT   VARCHAR2,
                               p_oracle_company       IN   VARCHAR2,
                               p_oracle_account       IN   VARCHAR2,
                               p_end_date             IN   VARCHAR2,
                               p_currency_code        IN   VARCHAR2,
                               p_delete_final_table   IN   VARCHAR2,
                               p_bc_environment       IN   VARCHAR2 );

  FUNCTION translated_period_net_change ( p_set_of_books_id       IN   NUMBER,
                                          p_period_set_name       IN   VARCHAR2,
                                          p_end_date              IN   DATE,
                                          p_period_year           IN   NUMBER,
                                          p_period_num            IN   NUMBER,
                                          p_code_combination_id   IN   NUMBER ) RETURN NUMBER;

  PROCEDURE period_to_date_ptd ( retcode               OUT   NUMBER,
                                 errbuf                OUT   VARCHAR2,
                                 p_oracle_company      IN    VARCHAR2,
                                 p_oracle_account      IN    VARCHAR2,
                                 p_period_year         IN    NUMBER,
                                 p_period_year_real    IN    NUMBER,
                                 p_period_num          IN    NUMBER,
                                 p_currency_code       IN    VARCHAR2,
                                 p_delete_final_table  IN    VARCHAR2,
                                 p_execute_report      IN    VARCHAR2,
                                 p_bc_environment      IN    VARCHAR2 );    

  PROCEDURE period_to_date_ptd_caller ( retcode               OUT   NUMBER,
                                        errbuf                OUT   VARCHAR2,
                                        p_oracle_company      IN    VARCHAR2,
                                        p_oracle_account      IN    VARCHAR2,
                                        p_start_date          IN    VARCHAR2,
                                        p_end_date            IN    VARCHAR2,
                                        p_currency_code       IN    VARCHAR2,
                                        p_delete_final_table  IN    VARCHAR2,
                                        p_bc_environment      IN    VARCHAR2 );                                       

END ajc_bc_gl_balances_pkg;
