PACKAGE ajc_bc_exchange_rates_pkg IS

  gv_user_id        NUMBER := fnd_global.user_id;
  gv_org_id         NUMBER := fnd_global.org_id;
  gv_request_id     NUMBER := fnd_global.conc_request_id;

  PROCEDURE main_p ( retcode           OUT   NUMBER,
                     errbuf            OUT   VARCHAR2,
                     p_bc_environment   IN   VARCHAR2,
                     p_date             IN   VARCHAR2 );

END ajc_bc_exchange_rates_pkg;
