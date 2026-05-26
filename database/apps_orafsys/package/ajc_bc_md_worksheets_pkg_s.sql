PACKAGE ajc_bc_md_worksheets_pkg IS
  
  gv_seconds_to_wait   NUMBER := 30;
  gv_request_id        NUMBER := fnd_global.conc_request_id;

  PROCEDURE main_p ( retcode             OUT   NUMBER,
                     errbuf              OUT   VARCHAR2,
                     p_bc_environment     IN   VARCHAR2 );

END ajc_bc_md_worksheets_pkg;
