CREATE OR REPLACE PACKAGE              AJC_BC_ADAPTIVE_INTERFACE_PK IS

/* --------------------------------------------------------------------------------------------|

| Historial                                                                                    |

|   Date      Version Modified   Detail                                                        |

|   --------- ------- ---------- --------------------------------------------------------------|

|   17-JUN-20       1 SBANCHIERI Creation                                                      |

/   03-OCT-22       1.1 MBETTI Update                                                           /

|---------------------------------------------------------------------------------------------*/



  /*=========================================================================+

  |                                                                          |

  | Public Function                                                          |

  |    main_process                                                          |

  |                                                                          |

  | Description                                                              |

  |    Expenses Cost Main Process                                            |

  |    Concurrent Program Executable                                         |

  |                                                                          |

  |                                                                          |

  | Parameters                                                               |

  |    retcode                   OUT     NUMBER    Codigo Estado.            |

  |    errbuf                    OUT     VARCHAR2  Mensaje de Finalizacion.  |

  |                                                                          |

  +=========================================================================*/

  PROCEDURE main_process (retcode    OUT NUMBER

                         ,errbuf     OUT VARCHAR2

                         ,p_environment IN VARCHAR2

                         ,p_force_closed_periods IN VARCHAR2 DEFAULT 'N' );



PROCEDURE process_accounts ( p_company_id IN VARCHAR

                            ,p_status_code   OUT VARCHAR2

                            ,p_error_message OUT VARCHAR2 );

                            

PROCEDURE process_journals ( p_company_id IN VARCHAR2

                            ,p_status_code   OUT VARCHAR2

                            ,p_error_message OUT VARCHAR2 );                            



END AJC_BC_ADAPTIVE_INTERFACE_PK;
