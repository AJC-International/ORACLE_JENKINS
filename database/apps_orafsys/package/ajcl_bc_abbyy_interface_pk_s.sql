CREATE OR REPLACE PACKAGE              AJCL_BC_ABBYY_INTERFACE_PK AS



/* ----------------------------------------------------------------------------------------------|

| Historial                                                                                      |

|   Date      Version  Modified    Detail                                                        |

|   --------- -------  ----------  --------------------------------------------------------------|

|   10-JAN-24    1     MBETTI    Creation                                                      |

|------------------------------------------------------------------------------------------------*/



gv_bc_environment    VARCHAR2(100);

gv_jenkins_build_number NUMBER;

gv_set_of_books_id         hr_operating_units.set_of_books_id%TYPE;

gv_set_of_books_name      gl_sets_of_books.name%TYPE;

gv_org_id                  hr_operating_units.organization_id%TYPE;

gv_bc_company_name        ajc_bc_companies.bc_company_name%TYPE := 'LOGIS-USA-USD';

gv_request_id   fnd_concurrent_requests.request_id%TYPE;

gv_md_company_id VARCHAR2(200):= '26fb86f1-2b58-ec11-9f08-002248210987'; --Master Data company ID 

gv_bc_company_id           ajc_bc_companies.bc_company_id%TYPE;

gv_bc_ifc                  VARCHAR2(200) := 'AJCL BC ABBYY Invoice Interface';

gv_report_filename         VARCHAR2(100) := 'AJCLBCAII';

gv_output_filename         VARCHAR2(100) := 'AJCLBCAII_output';

gv_log_seq                 NUMBER := 0;

gv_email                   ajcl_bc_integration_emails.emails%TYPE;  

gv_user_id                 fnd_user.user_id%TYPE := 0;

gv_directory_report        all_directories.directory_name%TYPE;



-- dbms_lock -----------------------------------------------------------------------------------------------------------------

gv_process_name         VARCHAR2(200);

gv_request_status       VARCHAR2(200);

gv_id_lock              VARCHAR2(200);

ge_lock                 EXCEPTION;

gv_release_status       VARCHAR2(200);

ge_release              EXCEPTION;  

-- dbms_lock -----------------------------------------------------------------------------------------------------------------



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

division VARCHAR2(20),

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

division VARCHAR2(20),

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

PROCEDURE main_p (p_bc_environment       IN VARCHAR2,

                                p_jenkins_build_number   IN   VARCHAR2 );





-- Inicio Agregado SBanchieri 20210812

PROCEDURE delete_error_records ( retcode   OUT NUMBER

                                ,errbuf    OUT VARCHAR2

                                ,p_draft   IN  VARCHAR2 );

-- Fin Agregado SBanchieri 20210812



END AJCL_BC_ABBYY_INTERFACE_PK;
