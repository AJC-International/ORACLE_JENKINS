CREATE OR REPLACE PACKAGE AJC_BC_ABBYY_INTERFACE_PK AS



/* ----------------------------------------------------------------------------------------------|

| Historial                                                                                      |

|   Date      Version  Modified    Detail                                                        |

|   --------- -------  ----------  --------------------------------------------------------------|

|   14-APR-19    1     PBONADEO    Creation                                                      |

|   04-DEC-20    2     SBANCHIERI  Creation                                                      |

|------------------------------------------------------------------------------------------------*/



g_source ap_invoices_interface.source%type;

g_dft_account VARCHAR2(10);

g_usd_tolerance_amount NUMBER;

gv_environment    VARCHAR2(100);

gv_request_id      NUMBER := fnd_global.conc_request_id;

gv_md_company_id VARCHAR2(200):= '26fb86f1-2b58-ec11-9f08-002248210987'; --Master Data company ID 



TYPE t_invoice_bc IS RECORD

(

invoiceID   VARCHAR2(30),

requestID  VARCHAR2(30),

invoiceNo VARCHAR2(30),

invoiceType VARCHAR2(30),

invoiceDate VARCHAR2(30),

vendorNo VARCHAR2(30),

vendorSiteCode VARCHAR2(30),

invoiceAmount VARCHAR2(50),

invoiceCurrencyCode VARCHAR2(10),

exchangeRate VARCHAR2(30),

exchangeRateType VARCHAR2(30),

exchangeDate VARCHAR2(30),

baseAmount VARCHAR2(50),

gLDate VARCHAR2(30),

organisationID VARCHAR2(10),

description VARCHAR2(240),

termName VARCHAR2(30),

termsDate VARCHAR2(30),

dueDate VARCHAR2(30),

paymentMethodCode VARCHAR2(30),

payGroupCode VARCHAR2(50),

setofBooksID VARCHAR2(20),

setofBooksName VARCHAR2(100),

accountsPayCode VARCHAR2(240),

company VARCHAR2(20),

account VARCHAR2(20),

accountDescription VARCHAR2(240),

department VARCHAR2(20),

product VARCHAR2(20),

destination VARCHAR2(20),

origin VARCHAR2(20),

intercompany VARCHAR2(20),

pdfFileUrl VARCHAR2(500),

source VARCHAR2(20),

office VARCHAR2(20)

);



TYPE t_inv_line_bc IS RECORD

(

requestID  VARCHAR2(30),

invoiceID   VARCHAR2(30),

invoiceNo VARCHAR2(30),

lineNo VARCHAR2(10),

amount VARCHAR2(50),

description VARCHAR2(240),

accountingDate VARCHAR2(30),

periodName VARCHAR2(20),

worksheetNo VARCHAR2(240),

baseAmount VARCHAR2(50),

exchangeRate VARCHAR2(30),

exchangeRateType VARCHAR2(30),

exchangeDate VARCHAR2(30),

organisationID VARCHAR2(10),

setofBooksID VARCHAR2(20),

setofBooksName VARCHAR2(100),

distCodeCombination VARCHAR2(30),

company VARCHAR2(20),

account VARCHAR2(20),

accountDescription VARCHAR2(240),

department VARCHAR2(20),

product VARCHAR2(20),

destination VARCHAR2(20),

origin VARCHAR2(20),

intercompany VARCHAR2(20),

office VARCHAR2(20)

);



FUNCTION get_text (p_text  IN VARCHAR2

                  ,p_index IN NUMBER) RETURN VARCHAR2;



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

PROCEDURE main_inv_process ( retcode             OUT NUMBER

                            ,errbuf              OUT VARCHAR2

                            ,p_source             IN VARCHAR2

                            ,p_dft_account        IN VARCHAR2

                            ,p_environment      IN VARCHAR2

                            ,p_delete_flag      IN VARCHAR2 );



PROCEDURE process_invoices (p_status            OUT VARCHAR2

                           ,p_error_message     OUT VARCHAR2);                              

--

PROCEDURE remove_inv ( retcode             OUT NUMBER,

                       errbuf              OUT VARCHAR2,

                       p_invoice_num       IN  VARCHAR2,

                       p_status            IN  VARCHAR2 );



END;
