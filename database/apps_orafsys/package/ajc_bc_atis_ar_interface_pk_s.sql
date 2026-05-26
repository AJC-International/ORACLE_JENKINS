CREATE OR REPLACE PACKAGE ajc_bc_atis_ar_interface_pk IS

/*------------------------------------------------------------------------------------------------|

| Historial                                                                                       |

|   Date      Version  Modified    Detail                                                         |

|   --------- -------  ----------  -------------------------------------------------------------- |

|   02-MAR-22       1  SBanchieri  Creation                                                       |

|-------------------------------------------------------------------------------------------------*/



  gv_seconds_to_wait   NUMBER := 20;



  gv_user_id           NUMBER := fnd_global.user_id;

  gv_login_id          NUMBER := fnd_global.login_id;

  gv_request_id        NUMBER := fnd_global.conc_request_id;



/*=========================================================================+

|                                                                          |

| Public Function                                                          |

|    main_process                                                          |

|                                                                          |

| Description                                                              |

|    ATIS BC AR Transactions Interface Main Process                        |

|    Concurrent Program Executable                                         |

|                                                                          |

| Parameters                                                               |

|    retcode                   OUT     NUMBER    Codigo Estado.            |

|    errbuf                    OUT     VARCHAR2  Mensaje de Finalizacion.  |

|                                                                          |

+=========================================================================*/

  PROCEDURE main_process ( retcode           OUT   NUMBER,

                           errbuf            OUT   VARCHAR2,

                           p_date_from        IN   VARCHAR2,

                           p_bc_environment   IN   VARCHAR2 );



END AJC_BC_ATIS_AR_INTERFACE_PK;
