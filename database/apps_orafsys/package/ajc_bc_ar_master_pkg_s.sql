CREATE OR REPLACE PACKAGE ajc_bc_ar_master_pkg AS

  

  gv_user_id      NUMBER := fnd_global.user_id;

  gv_request_id   NUMBER := fnd_global.conc_request_id;

  gv_ifc          VARCHAR2(100) := 'AR MASTER CONTROL';



  FUNCTION get_closed_at_date ( p_entryNo           IN   NUMBER, 

                                p_remainingAmount   IN   NUMBER,

                                p_closedAtDate      IN   VARCHAR2

                                -- 20241212

                                ,p_globaldimension1code   IN   VARCHAR2

                                -- 20241212

                                ) RETURN DATE;



  PROCEDURE main_p ( retcode            OUT   NUMBER,

                     errbuf             OUT   VARCHAR2,

                     p_bc_environment   IN   VARCHAR2 );  



END ajc_bc_ar_master_pkg;
