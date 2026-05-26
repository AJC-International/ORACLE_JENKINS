CREATE OR REPLACE PACKAGE ajc_bc_arxage_pkg IS



  PROCEDURE main_p ( retcode                  OUT   NUMBER,

                     errbuf                   OUT   VARCHAR2,

                     p_reporting_level         IN   NUMBER,

                     p_reporting_context       IN   NUMBER, -- org_id

                     p_set_of_books_currency   IN   VARCHAR2,

                     p_chart_of_accounts       IN   NUMBER,

                     p_as_of_date              IN   VARCHAR2,

                     p_order_by                IN   VARCHAR2,

                     p_report_summary          IN   VARCHAR2, -- Customer | Invoice

                     p_report_format           IN   VARCHAR2, -- Brief | Detailed

                     p_aging_bucket_name       IN   VARCHAR2,

                     p_show_open_credits       IN   VARCHAR2,

                     p_show_receipts_at_risk   IN   VARCHAR2,

                     p_customer_name_low       IN   VARCHAR2,

                     p_customer_name_high      IN   VARCHAR2,

                     p_customer_number_low     IN   VARCHAR2,

                     p_customer_number_high    IN   VARCHAR2,

                     p_balance_due_low         IN   NUMBER,

                     p_balance_due_high        IN   NUMBER,

                     p_transaction_type_low    IN   VARCHAR2,

                     p_transaction_type_high   IN   VARCHAR2 );



END ajc_bc_arxage_pkg;
