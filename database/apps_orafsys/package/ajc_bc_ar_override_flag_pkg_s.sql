CREATE OR REPLACE PACKAGE ajc_bc_ar_override_flag_pkg AS

  

  gv_user_id        NUMBER := fnd_global.user_id;

  gv_request_id     NUMBER := fnd_global.conc_request_id;



  gv_ifc            VARCHAR2(100) := 'AR OVERRIDE FLAG';



  PROCEDURE main_p ( retcode            OUT   NUMBER,

                     errbuf             OUT   VARCHAR2,

                     p_bc_environment   IN    VARCHAR2 );



END ajc_bc_ar_override_flag_pkg;
