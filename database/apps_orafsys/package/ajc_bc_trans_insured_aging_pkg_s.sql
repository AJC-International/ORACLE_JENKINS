CREATE OR REPLACE PACKAGE AJC_BC_TRANS_INSURED_AGING_PKG IS



  PROCEDURE main_p ( retcode                          OUT   NUMBER,

                     errbuf                           OUT   VARCHAR2,

                     p_org_id                         IN    NUMBER,

                     p_as_of_date                     IN    VARCHAR2,         

                     p_set_of_books_id                IN    NUMBER,

                     p_translation_currency           IN    VARCHAR2,         

                     p_translation_rate               IN    NUMBER,

                     p_aig_translation_rate           IN    NUMBER,

                     p_open_acct_cus_lim_curr         IN    VARCHAR2,

                     p_open_acct_cus_lim_trans_rate   IN    NUMBER,

                     p_transaction_type_low           IN    VARCHAR2,

                     p_transaction_type_high          IN    VARCHAR2 );



END AJC_BC_TRANS_INSURED_AGING_PKG;
