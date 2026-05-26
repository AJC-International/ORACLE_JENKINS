PACKAGE AJC_BC_ATIS_BATCH_INTERFACE_PK IS
/* -----------------------------------------------------------------------------------------------|
| Historial                                                                                       |
|   Date      Version  Modified      Detail                                                       |
|   --------- -------  ----------    -------------------------------------------------------------|
|   14-ENE-22       1  MNazarre      Creation                                                     |
|   19-DEC-22       2  SBanchieri    Update                                                       |  
|------------------------------------------------------------------------------------------------*/

  gv_request_id        NUMBER := fnd_global.conc_request_id;   

  function get_dimension_value ( p_oracle_segment   IN   VARCHAR2
                                ,p_oracle_value     IN   VARCHAR2
                                ,p_bc_dimension     IN   VARCHAR2 ) RETURN VARCHAR2;

/*=========================================================================+
|                                                                          |
| Public Function                                                          |
|    main_process                                                          |
|                                                                          |
| Description                                                              |
|    ATIS BC GL/AR Batches Interface Main Process                          |
|    Concurrent Program Executable                                         |
|                                                                          |
|                                                                          |
| Parameters                                                               |
|    retcode                   OUT     NUMBER    Codigo Estado.            |
|    errbuf                    OUT     VARCHAR2  Mensaje de Finalizacion.  |
|                                                                          |
+=========================================================================*/
  PROCEDURE main_process   (retcode                   OUT NUMBER
                          , errbuf                    OUT VARCHAR2
--                          , p_je_source_name           IN VARCHAR2
--                          , p_je_category_name         IN VARCHAR2
                          , p_date_from                IN VARCHAR2
                          , p_date_to                  IN VARCHAR2
                          , p_journalbatchname         IN VARCHAR2 --DAILYINT
                          , p_bc_company_name          IN VARCHAR2
                          , p_environment              IN VARCHAR2
                          , p_mail_list                IN VARCHAR2
                          );

  -- 20221219 SBanchieri
  PROCEDURE pending_caller ( retcode             OUT   NUMBER,
                             errbuf              OUT   VARCHAR2,
                             p_date_from          IN   VARCHAR2,
                             p_journalbatchname   IN   VARCHAR2,
                             p_bc_environment     IN   VARCHAR2 );
  -- 20221219 SBanchieri

END AJC_BC_ATIS_BATCH_INTERFACE_PK;
