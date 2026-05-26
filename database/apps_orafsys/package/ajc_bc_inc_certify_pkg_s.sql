CREATE OR REPLACE PACKAGE ajc_bc_inc_certify_pkg AS

  

  gv_seconds_to_wait   NUMBER := 20;



  gv_request_id        NUMBER := fnd_global.conc_request_id;

  -- 20230414 gv_job_object_id     NUMBER := 70004; -- Purchase Document



  PROCEDURE ajc_inc_ftp_expense_rpt ( p_file_prefix   IN   VARCHAR2,

                                      p_status       OUT   VARCHAR2 ); 



  PROCEDURE ajc_inc_load_expense_rpt_int ( p_file_name   IN   VARCHAR2,

                                           p_status       OUT   VARCHAR2 ); 



  PROCEDURE expense_report_interface_p ( p_gl_date                       IN   DATE,

                                         p_american_express_supplier     IN   VARCHAR2,

                                         p_travel_advance_account_num    IN   VARCHAR2,

                                         p_status                       OUT   VARCHAR2 );



  PROCEDURE ajc_inc_del_expense_rpt_files ( p_status   OUT   VARCHAR2 );



  PROCEDURE main_p ( retcode                       OUT   NUMBER,

                     errbuf                        OUT   VARCHAR2,

                     -- p_file_prefix                  IN   VARCHAR2,

                     p_file_name                    IN   VARCHAR2,

                     p_gl_date                      IN   VARCHAR2,

                     -- p_company_id                   IN   VARCHAR2,

                     p_american_express_supplier    IN   VARCHAR2,

                     p_travel_advance_account_num   IN   VARCHAR2,

                     p_bc_environment               IN   VARCHAR2 );



END ajc_bc_inc_certify_pkg;
