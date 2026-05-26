CREATE OR REPLACE PACKAGE ajcl_bc_csa_pkg IS

-- Creation: SBANCHIERI 23-AUG-2023 

  

  gv_bc_company_name             ajc_bc_companies.bc_company_name%TYPE := 'LOGIS-USA-USD';

  gv_bc_company_id               ajc_bc_companies.bc_company_id%TYPE;  

  gv_set_of_books_id             ajc_bc_companies.set_of_books_id%TYPE;  

  gv_org_id                      ajc_bc_companies.org_id%TYPE;



  gv_bc_environment              VARCHAR2(100);

  gv_if_errors_stop              VARCHAR2(1);

  gv_log_seq                     NUMBER := 0;



  gv_lines_per_json              NUMBER := 100;

  gv_user_id                     NUMBER := 0;



  gv_bc_ifc                      VARCHAR2(200) := 'AJCL BC CSA Interface';

  gv_output_filename             VARCHAR2(100) := 'AJCLBCCSAIO';



  gv_bc_gl_ifc                   VARCHAR2(200) := 'AJCL BC CSA GL Interface';

  gv_gl_report_filename          VARCHAR2(100) := 'AJCLBCCSAGLIR';

  gv_gl_email                    ajcl_bc_integration_emails.emails%TYPE;



  gv_bc_ar_ifc                   VARCHAR2(200) := 'AJCL BC CSA AR Interface';

  gv_ar_report_filename          VARCHAR2(100) := 'AJCLBCCSAARIR';

  gv_ar_email                    ajcl_bc_integration_emails.emails%TYPE;



  gv_request_id                  NUMBER;



  gv_journal_template_name       VARCHAR2(30) := 'GENERAL';

  gv_journal_batch_name          VARCHAR2(30) := 'DAILYINT';



  gv_valid                       VARCHAR2(1);

  gv_fin_chrg_exists             VARCHAR2(1);

  gv_err_msg                     VARCHAR2(200);

  gv_val_status                  VARCHAR2(1);

  gv_ar_status                   ajc_csa_interfaceapar.ar_status%TYPE;

  gv_gl_status                   ajc_csa_interfaceapar.gl_status%TYPE;

  gv_destination                 VARCHAR2(3);

  gv_trx_date                    DATE;

  gv_gl_date                     DATE;

  gv_out_date                    DATE;

  gv_in_date                     DATE;

  gv_reversal_source             VARCHAR2(3);

  gv_ar_reversal_ref_name        VARCHAR2(20);

  gv_gl_reversal_ref_name        VARCHAR2(100);

  gv_je_category                 gl_je_categories_tl.user_je_category_name%TYPE;

  gv_worksheet                   VARCHAR2(100);



  gv_ar_rev_ref_entryno          INTEGER; -- Se usa el entryno de BC que es numerico

  gv_ar_reversal_ref_id          INTEGER; -- Se usa el customer_trx_id de Oracle



  gv_gl_rev_ref_entryno          INTEGER; -- Se usa el entryno de BC que es numerico

  gv_gl_reversal_ref_id          INTEGER; -- Se usa el je_header_id de Oracle



  gv_count                       INTEGER := 0;

  gv_start_seq                   INTEGER := 0;

  gv_last_seq                    INTEGER := 0;

  gv_ar_invoice_amt              NUMBER;

  gv_ar_app_cm_amt               NUMBER;

  gv_ar_manual_cm_amt            NUMBER;

  gv_gl_rvrs_amt                 NUMBER;

  gv_assoc_rev_pod_null	         VARCHAR2(1); 

  gv_prev_ar_housebill           NUMBER := -1;

  gv_prev_gl_housebill           NUMBER := -1;



  conversion_type_c              VARCHAR2(10) := 'User';

  conversion_rate_c		            NUMBER := 1;

  dff_context_c         			      ra_interface_lines.interface_line_context%TYPE := 'CSA';

  line_type_c	           		      ra_interface_lines.line_type%TYPE := 'LINE';

  currency_code_c		       	      ra_interface_lines.currency_code%TYPE := 'USD';

  uom_c				                      VARCHAR2(10) := 'Each';

  qty_c			                	      NUMBER := 1;



  gv_ar_match                    VARCHAR2(20);

  gv_gl_match                    VARCHAR2(20);



  gv_file_format                 VARCHAR2(4);

  gv_directory_report            all_directories.directory_name%TYPE; 

  gv_directory_output            all_directories.directory_name%TYPE; 



  gv_bc_start_date               DATE;

  gv_bc_end_date                 DATE;

  gv_only_reprocess              VARCHAR2(1) := 'N';

  -- -- 20240905 gv_check_integrations_source   VARCHAR2(1);

  gv_jenkins_build_number        VARCHAR2(100);



  -- dbms_lock -----------------------------------------------------------------------------------------------------------------

  gv_gl_process_name             VARCHAR2(200);

  gv_gl_request_status           VARCHAR2(200);

  gv_gl_id_lock                  VARCHAR2(200);

  ge_gl_lock                     EXCEPTION;

  gv_gl_release_status           VARCHAR2(200);

  ge_gl_release                  EXCEPTION;  



  gv_ar_process_name             VARCHAR2(200);

  gv_ar_request_status           VARCHAR2(200);

  gv_ar_id_lock                  VARCHAR2(200);

  ge_ar_lock                     EXCEPTION;

  gv_ar_release_status           VARCHAR2(200);

  ge_ar_release                  EXCEPTION; 

  -- dbms_lock -----------------------------------------------------------------------------------------------------------------



  PROCEDURE main_p ( p_bc_environment              IN   VARCHAR2,

                     p_if_errors_stop              IN   VARCHAR2,

                     p_starting_pk_seqno           IN   VARCHAR2, -- Prompt Starting PK Seqno

                     -- 20240905 p_check_integrations_source   IN   VARCHAR2,

                     p_jenkins_build_number        IN   VARCHAR2 ); 



END ajcl_bc_csa_pkg;
