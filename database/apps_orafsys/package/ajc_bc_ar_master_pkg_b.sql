CREATE OR REPLACE PACKAGE BODY ajc_bc_ar_master_pkg AS

  

  -- ---------------------------------------------------------------------------------------------------------------------------

  -- Print Log

  -- ---------------------------------------------------------------------------------------------------------------------------

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    fnd_file.put_line(fnd_file.log, p_message);



  END print_log;



  -- ---------------------------------------------------------------------------------------------------------------------------

  -- Print Output

  -- ---------------------------------------------------------------------------------------------------------------------------

  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS

  BEGIN



    fnd_file.put_line(fnd_file.output,p_message);



  END print_output;



  PROCEDURE get_cust_ledger_entries_p ( p_company_id               IN       VARCHAR2,

                                        p_last_bc_processed_date   IN       TIMESTAMP,

                                        p_bc_environment           IN       VARCHAR2,

                                        p_return                   IN OUT   VARCHAR2,

                                        p_error_msg                IN OUT   VARCHAR2,

                                        p_cle_total_control        IN OUT   NUMBER ) IS



    v_get_url        VARCHAR2(2000);

    v_get_api        VARCHAR2(100);



    v_insert_count   NUMBER;



    CURSOR c_cle_control ( p_get_url   IN   VARCHAR2 ) IS

    SELECT systemId,

           adjustedCurrencyFactor,

           amount,

           amountLCY,

           appliesToDocNo,

           -- 20240617 appliesToDocType,

           REPLACE(REPLACE(appliesToDocType,'_x0020_',' '),'_x002F_','/') appliesToDocType,

           -- 20240617

           appliesToExtDocNo,

           balAccountNo,

           -- 20240617 balAccountType,

           REPLACE(REPLACE(balAccountType,'_x0020_',' '),'_x002F_','/') balAccountType,

           -- 20240617

           closedAtDate,

           closedByAmount,

           closedByAmountLCY,

           closedByCurrencyAmount,

           closedByEntryNo,

           creditAmount,

           creditAmountLCY,

           currencyCode,

           customerName,

           customerNo,

           debitAmount,

           debitAmountLCY,

           description,

           documentDate,

           documentNo,

           -- 20240617 documentType,

           REPLACE(REPLACE(documentType,'_x0020_',' '),'_x002F_','/') documentType,

           -- 20240617

           dueDate,

           comments,

           entryNo,

           globalDimension1Code,

           globalDimension2Code,

           journalBatchName,

           originalAmount,

           originalAmtLCY,

           originalCurrencyFactor,

           postingDate,

           prepayment,

           remainingAmount,

           remainingAmtLCY,

           reversed,

           salesLCY,

           sellToCustomerNo,

           shortcutDimension3Code,

           shortcutDimension4Code,

           shortcutDimension5Code,

           shortcutDimension6Code,

           shortcutDimension7Code,

           shortcutDimension8Code,

           sourceCode,

           creditMemoAdjustment,

           paymentTermsCode,

           systemCreatedAt,

           systemCreatedBy,

           systemModifiedAt,

           systemModifiedBy,

           transactionNo,

           userID,

           createdDate,

           createdTime,

           modifiedDate,

           modifiedTime,

           'NEW' status, 

           TRUNC(SYSDATE) creation_date,

           gv_request_id request_id

      FROM json_table( ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => p_get_url ),

                       '$.value[*]' COLUMNS ( systemId                 VARCHAR2(4000) path '$.systemId',

                                              adjustedCurrencyFactor   VARCHAR2(4000) path '$.adjustedCurrencyFactor',

                                              amount                   VARCHAR2(4000) path '$.amount',

                                              amountLCY                VARCHAR2(4000) path '$.amountLCY',

                                              appliesToDocNo           VARCHAR2(4000) path '$.appliesToDocNo',

                                              appliesToDocType         VARCHAR2(4000) path '$.appliesToDocType',

                                              appliesToExtDocNo        VARCHAR2(4000) path '$.appliesToExtDocNo',

                                              balAccountNo             VARCHAR2(4000) path '$.balAccountNo',

                                              balAccountType           VARCHAR2(4000) path '$.balAccountType',

                                              closedAtDate             VARCHAR2(4000) path '$.closedAtDate',

                                              closedByAmount           VARCHAR2(4000) path '$.closedByAmount',

                                              closedByAmountLCY        VARCHAR2(4000) path '$.closedByAmountLCY',

                                              closedByCurrencyAmount   VARCHAR2(4000) path '$.closedByCurrencyAmount',

                                              closedByEntryNo          VARCHAR2(4000) path '$.closedByEntryNo',

                                              creditAmount             VARCHAR2(4000) path '$.creditAmount',

                                              creditAmountLCY          VARCHAR2(4000) path '$.creditAmountLCY',

                                              currencyCode             VARCHAR2(4000) path '$.currencyCode',

                                              customerName             VARCHAR2(4000) path '$.customerName',

                                              customerNo               VARCHAR2(4000) path '$.customerNo',

                                              debitAmount              VARCHAR2(4000) path '$.debitAmount',

                                              debitAmountLCY           VARCHAR2(4000) path '$.debitAmountLCY',

                                              description              VARCHAR2(4000) path '$.description',

                                              documentDate             VARCHAR2(4000) path '$.documentDate',

                                              documentNo               VARCHAR2(4000) path '$.documentNo',

                                              documentType             VARCHAR2(4000) path '$.documentType',

                                              dueDate                  VARCHAR2(4000) path '$.dueDate',

                                              comments                 VARCHAR2(4000) path '$.comment',

                                              entryNo                  VARCHAR2(4000) path '$.entryNo',

                                              globalDimension1Code     VARCHAR2(4000) path '$.globalDimension1Code',

                                              globalDimension2Code     VARCHAR2(4000) path '$.globalDimension2Code',

                                              journalBatchName         VARCHAR2(4000) path '$.journalBatchName',

                                              originalAmount           VARCHAR2(4000) path '$.originalAmount',

                                              originalAmtLCY           VARCHAR2(4000) path '$.originalAmtLCY',

                                              originalCurrencyFactor   VARCHAR2(4000) path '$.originalCurrencyFactor',

                                              postingDate              VARCHAR2(4000) path '$.postingDate',

                                              prepayment               VARCHAR2(4000) path '$.prepayment',

                                              remainingAmount          VARCHAR2(4000) path '$.remainingAmount',

                                              remainingAmtLCY          VARCHAR2(4000) path '$.remainingAmtLCY',

                                              reversed                 VARCHAR2(4000) path '$.reversed',

                                              salesLCY                 VARCHAR2(4000) path '$.salesLCY',

                                              sellToCustomerNo         VARCHAR2(4000) path '$.sellToCustomerNo',

                                              shortcutDimension3Code   VARCHAR2(4000) path '$.shortcutDimension3Code',

                                              shortcutDimension4Code   VARCHAR2(4000) path '$.shortcutDimension4Code',

                                              shortcutDimension5Code   VARCHAR2(4000) path '$.shortcutDimension5Code',

                                              shortcutDimension6Code   VARCHAR2(4000) path '$.shortcutDimension6Code',

                                              shortcutDimension7Code   VARCHAR2(4000) path '$.shortcutDimension7Code',

                                              shortcutDimension8Code   VARCHAR2(4000) path '$.shortcutDimension8Code',

                                              sourceCode               VARCHAR2(4000) path '$.sourceCode',

                                              creditMemoAdjustment     VARCHAR2(4000) path '$.creditMemoAdjustment',

                                              paymentTermsCode         VARCHAR2(4000) path '$.paymentTermsCode',

                                              systemCreatedAt          VARCHAR2(4000) path '$.systemCreatedAt',

                                              systemCreatedBy          VARCHAR2(4000) path '$.systemCreatedBy',

                                              systemModifiedAt         VARCHAR2(4000) path '$.systemModifiedAt',

                                              systemModifiedBy         VARCHAR2(4000) path '$.systemModifiedBy',

                                              transactionNo            VARCHAR2(4000) path '$.transactionNo',

                                              userID                   VARCHAR2(4000) path '$.userID',

                                              createdDate              VARCHAR2(4000) path '$.createdDate',

                                              createdTime              VARCHAR2(4000) path '$.createdTime',

                                              modifiedDate             VARCHAR2(4000) path '$.modifiedDate',

                                              modifiedTime             VARCHAR2(4000) path '$.modifiedTime' )) cle;



    -- 20240819

    v_amount              NUMBER;

    v_amountLCY           NUMBER;

    v_balAccountNo        VARCHAR2(100);

    v_balAccountType      VARCHAR2(100);

    v_closedByAmount      NUMBER;

    v_closedByAmountLCY   NUMBER; 

    v_customerName        VARCHAR2(300);

    v_customerNo          VARCHAR2(100);

    v_description         VARCHAR2(300);

    v_documentDate        VARCHAR2(100);

    v_documentNo          VARCHAR2(100);

    v_documentType        VARCHAR2(100);

    v_entryNo             NUMBER;  

    v_postingDate         VARCHAR2(100);

    v_sourceCode          VARCHAR2(100);

    -- 20240819



  BEGIN



    print_log ('ajc_bc_ar_master_pkg.get_cust_ledger_entries_p (+)');



    v_get_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'CUSTOMER LEDGER ENTRIES',

                                                 p_subentity => NULL,

                                                 p_method => 'GET' );



    v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, p_company_id ) || v_get_api

                 || '?$filter=systemModifiedAt gt ' || TO_CHAR(p_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z');



    v_insert_count := 0;



    FOR cclec IN c_cle_control ( v_get_url ) LOOP



      -- 20240819

      v_amount := cclec.amount;

      v_amountLCY := cclec.amountLCY;

      v_balAccountNo := cclec.balAccountNo;

      v_balAccountType := cclec.balAccountType;

      v_closedByAmount := cclec.closedByAmount;

      v_closedByAmountLCY := cclec.closedByAmountLCY;

      v_customerName := cclec.customerName;

      v_customerNo := cclec.customerNo;

      v_description := cclec.description;

      v_documentDate := cclec.documentDate;

      v_documentNo := cclec.documentNo;

      v_documentType := cclec.documentType;

      v_entryNo := cclec.entryNo;

      v_postingDate := cclec.postingDate;

      v_sourceCode := cclec.sourceCode;

      -- 20240819



      DELETE ajc_bc_cle_control

       WHERE systemId = cclec.systemId

         AND bc_environment = p_bc_environment;



      INSERT

        INTO ajc_bc_cle_control

           ( systemId,

             adjustedCurrencyFactor,

             amount,

             amountLCY,

             appliesToDocNo,

             appliesToDocType,

             appliesToExtDocNo,

             balAccountNo,

             balAccountType,

             closedAtDate,

             closedByAmount,

             closedByAmountLCY,

             closedByCurrencyAmount,

             closedByEntryNo,

             creditAmount,

             creditAmountLCY,

             currencyCode,

             customerName,

             customerNo,

             debitAmount,

             debitAmountLCY,

             description,

             documentDate,

             documentNo,

             documentType,

             dueDate,

             comments,

             entryNo,

             globalDimension1Code,

             globalDimension2Code,

             journalBatchName,

             originalAmount,

             originalAmtLCY,

             originalCurrencyFactor,

             postingDate,

             prepayment,

             remainingAmount,

             remainingAmtLCY,

             reversed,

             salesLCY,

             sellToCustomerNo,

             shortcutDimension3Code,

             shortcutDimension4Code,

             shortcutDimension5Code,

             shortcutDimension6Code,

             shortcutDimension7Code,

             shortcutDimension8Code,

             sourceCode,

             creditMemoAdjustment,

             paymentTermsCode,

             systemCreatedAt,

             systemCreatedBy,

             systemModifiedAt,

             systemModifiedBy,

             transactionNo,

             userID,

             createdDate,

             createdTime,

             modifiedDate,

             modifiedTime,

             status,

             creation_date,

             request_id,

             bc_environment,

             trx_number )

    VALUES ( cclec.systemId,

             cclec.adjustedCurrencyFactor,

             cclec.amount,

             cclec.amountLCY,

             cclec.appliesToDocNo,

             cclec.appliesToDocType,

             cclec.appliesToExtDocNo,

             cclec.balAccountNo,

             cclec.balAccountType,

             cclec.closedAtDate,

             cclec.closedByAmount,

             cclec.closedByAmountLCY,

             cclec.closedByCurrencyAmount,

             cclec.closedByEntryNo,

             cclec.creditAmount,

             cclec.creditAmountLCY,

             cclec.currencyCode,

             cclec.customerName,

             cclec.customerNo,

             cclec.debitAmount,

             cclec.debitAmountLCY,

             cclec.description,

             cclec.documentDate,

             cclec.documentNo,

             cclec.documentType,

             cclec.dueDate,

             cclec.comments,

             cclec.entryNo,

             cclec.globalDimension1Code,

             cclec.globalDimension2Code,

             cclec.journalBatchName,

             cclec.originalAmount,

             cclec.originalAmtLCY,

             cclec.originalCurrencyFactor,

             cclec.postingDate,

             cclec.prepayment,

             cclec.remainingAmount,

             cclec.remainingAmtLCY,

             cclec.reversed,

             cclec.salesLCY,

             cclec.sellToCustomerNo,

             cclec.shortcutDimension3Code,

             cclec.shortcutDimension4Code,

             cclec.shortcutDimension5Code,

             cclec.shortcutDimension6Code,

             cclec.shortcutDimension7Code,

             cclec.shortcutDimension8Code,

             cclec.sourceCode,

             cclec.creditMemoAdjustment,

             cclec.paymentTermsCode,

             cclec.systemCreatedAt,

             cclec.systemCreatedBy,

             cclec.systemModifiedAt,

             cclec.systemModifiedBy,

             cclec.transactionNo,

             cclec.userID,

             cclec.createdDate,

             cclec.createdTime,

             cclec.modifiedDate,

             cclec.modifiedTime,

             cclec.status, 

             cclec.creation_date,

             cclec.request_id,

             p_bc_environment,

             DECODE(SUBSTR(cclec.documentNo,1,3),'AR-',SUBSTR(cclec.documentNo,4),cclec.documentNo) 

        );



        v_insert_count := v_insert_count + 1;

        p_cle_total_control := p_cle_total_control + 1;



    END LOOP;



    print_log ('Rows inserted: ' || v_insert_count );

    print_log (' ');



    p_return := 'S';

    print_log ('ajc_bc_ar_master_pkg.get_cust_ledger_entries_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      print_log ('ajc_bc_ar_master_pkg.get_cust_ledger_entries_p (!). ' || SQLERRM);



      -- 20240819

      print_log ( 'Customer Ledger Entry with error' );

      print_log ( '---------------------------------------------------------------------------------------------------------' );



      print_log ( 'amount: ' || v_amount );

      print_log ( 'amountLCY: ' || v_amountLCY );

      print_log ( 'balAccountNo: ' || v_balAccountNo );

      print_log ( 'balAccountType: ' || v_balAccountType );

      print_log ( 'closedByAmount: ' || v_closedByAmount );

      print_log ( 'closedByAmountLCY: ' || v_closedByAmountLCY );

      print_log ( 'customerName: ' || v_customerName );

      print_log ( 'customerNo: ' || v_customerNo );

      print_log ( 'description: ' || v_description );

      print_log ( 'documentDate: ' || v_documentDate );

      print_log ( 'documentNo: ' || v_documentNo );

      print_log ( 'documentType: ' || v_documentType );

      print_log ( 'entryNo: ' || v_entryNo );

      print_log ( 'postingDate: ' || v_postingDate );

      print_log ( 'sourceCode: ' || v_sourceCode );      

      -- 20240819



      p_return := 'E';

      p_error_msg := 'get_cust_ledger_entries_p. Error: ' || SQLERRM;



  END get_cust_ledger_entries_p;



  PROCEDURE get_det_cust_ledger_entries_p ( p_company_id               IN       VARCHAR2,

                                            p_last_bc_processed_date   IN       TIMESTAMP,

                                            p_bc_environment           IN       VARCHAR2,

                                            p_return                   IN OUT   VARCHAR2,

                                            p_error_msg                IN OUT   VARCHAR2,

                                            p_dcle_total_control       IN OUT   NUMBER ) IS



    v_get_url        VARCHAR2(2000);

    v_get_api        VARCHAR2(100);



    v_insert_count   NUMBER;



    CURSOR c_dcle_control ( p_get_url   IN   VARCHAR2 ) IS 

    SELECT systemId,

           amount,

           amountLCY,

           amountInCompanyCurrencyINE,

           applicationNo,

           appliedCustLedgerEntryNo,

           companyCurrencyCodeINE,

           creditAmount,

           creditAmountLCY,

           currencyCode,

           custLedgerEntryNo,

           customerNo,

           debitAmount,

           debitAmountLCY,

           documentNo,

           -- 20240617 documentType,

           REPLACE(REPLACE(documentType,'_x0020_',' '),'_x002F_','/') documentType,

           -- 20240617

           entryNo,

           -- 20240617 entryType,

           REPLACE(REPLACE(entryType,'_x0020_',' '),'_x002F_','/') entryType,

           -- 20240617

           -- 20240617 initialDocumentType,

           REPLACE(REPLACE(initialDocumentType,'_x0020_',' '),'_x002F_','/') initialDocumentType,

           -- 20240617

           initialEntryDueDate,

           initialEntryGlobalDim1,

           initialEntryGlobalDim2,

           journalBatchName,

           ledgerEntryAmount,

           maxPaymentTolerance,

           postingDate,

           reasonCode,

           remainingPmtDiscPossible,

           sourceCode,

           systemCreatedAt,

           systemCreatedBy,

           systemModifiedAt,

           systemModifiedBy,

           taxJurisdictionCode,

           transactionNo,

           unapplied,

           unappliedByEntryNo,

           useTax,

           userID,

           createdDate,

           createdTime,

           modifiedDate,

           modifiedTime,

           'NEW' status, 

           TRUNC(SYSDATE) creation_date,

           gv_request_id request_id

      FROM json_table( ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => p_get_url ),

                       '$.value[*]' COLUMNS ( systemId                     VARCHAR2(4000) path '$.systemId',

                                              amount                       VARCHAR2(4000) path '$.amount',

                                              amountLCY                    VARCHAR2(4000) path '$.amountLCY',

                                              amountInCompanyCurrencyINE   VARCHAR2(4000) path '$.amountInCompanyCurrencyINE',

                                              applicationNo                VARCHAR2(4000) path '$.applicationNo',

                                              appliedCustLedgerEntryNo     VARCHAR2(4000) path '$.appliedCustLedgerEntryNo',

                                              companyCurrencyCodeINE       VARCHAR2(4000) path '$.companyCurrencyCodeINE',

                                              creditAmount                 VARCHAR2(4000) path '$.creditAmount',

                                              creditAmountLCY              VARCHAR2(4000) path '$.creditAmountLCY',

                                              currencyCode                 VARCHAR2(4000) path '$.currencyCode',

                                              custLedgerEntryNo            VARCHAR2(4000) path '$.custLedgerEntryNo',

                                              customerNo                   VARCHAR2(4000) path '$.customerNo',

                                              debitAmount                  VARCHAR2(4000) path '$.debitAmount',

                                              debitAmountLCY               VARCHAR2(4000) path '$.debitAmountLCY',

                                              documentNo                   VARCHAR2(4000) path '$.documentNo',

                                              documentType                 VARCHAR2(4000) path '$.documentType',

                                              entryNo                      VARCHAR2(4000) path '$.entryNo',

                                              entryType                    VARCHAR2(4000) path '$.entryType',

                                              initialDocumentType          VARCHAR2(4000) path '$.initialDocumentType',

                                              initialEntryDueDate          VARCHAR2(4000) path '$.initialEntryDueDate',

                                              initialEntryGlobalDim1       VARCHAR2(4000) path '$.initialEntryGlobalDim1',

                                              initialEntryGlobalDim2       VARCHAR2(4000) path '$.initialEntryGlobalDim2',

                                              journalBatchName             VARCHAR2(4000) path '$.journalBatchName',

                                              ledgerEntryAmount            VARCHAR2(4000) path '$.ledgerEntryAmount',

                                              maxPaymentTolerance          VARCHAR2(4000) path '$.maxPaymentTolerance',

                                              postingDate                  VARCHAR2(4000) path '$.postingDate',

                                              reasonCode                   VARCHAR2(4000) path '$.reasonCode',

                                              remainingPmtDiscPossible     VARCHAR2(4000) path '$.remainingPmtDiscPossible',

                                              sourceCode                   VARCHAR2(4000) path '$.sourceCode',

                                              systemCreatedAt              VARCHAR2(4000) path '$.systemCreatedAt',

                                              systemCreatedBy              VARCHAR2(4000) path '$.systemCreatedBy',

                                              systemModifiedAt             VARCHAR2(4000) path '$.systemModifiedAt',

                                              systemModifiedBy             VARCHAR2(4000) path '$.systemModifiedBy',

                                              taxJurisdictionCode          VARCHAR2(4000) path '$.taxJurisdictionCode',

                                              transactionNo                VARCHAR2(4000) path '$.transactionNo',

                                              unapplied                    VARCHAR2(4000) path '$.unapplied',

                                              unappliedByEntryNo           VARCHAR2(4000) path '$.unappliedByEntryNo',

                                              useTax                       VARCHAR2(4000) path '$.useTax',

                                              userID                       VARCHAR2(4000) path '$.userID',

                                              createdDate                  VARCHAR2(4000) path '$.createdDate',

                                              createdTime                  VARCHAR2(4000) path '$.createdTime',

                                              modifiedDate                 VARCHAR2(4000) path '$.modifiedDate',

                                              modifiedTime                 VARCHAR2(4000) path '$.modifiedTime' )) dcle;



    -- 20240819

    v_amount                     NUMBER;

    v_amountLCY                  NUMBER;

    v_appliedCustLedgerEntryNo   NUMBER;

    v_custLedgerEntryNo          NUMBER;

    v_customerNo                 VARCHAR2(100);

    v_documentNo                 VARCHAR2(100);

    v_documentType               VARCHAR2(100);

    v_entryNo                    NUMBER;  

    v_entryType                  VARCHAR2(100);

    v_initialDocumentType        VARCHAR2(100);

    v_postingDate                VARCHAR2(100);

    v_sourceCode                 VARCHAR2(100);

    -- 20240819



  BEGIN



    print_log (' ');

    print_log ('ajc_bc_ar_master_pkg.get_det_cust_ledger_entries_p (+)');



    v_get_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'DETAILED CUSTOMER LEDGER ENTRIES',

                                                 p_subentity => NULL,

                                                 p_method => 'GET' );                                         



    v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, p_company_id ) || v_get_api

                 || '?$filter=systemModifiedAt gt ' || TO_CHAR(p_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z'); 



    v_insert_count := 0;



    FOR cdclec IN c_dcle_control ( v_get_url ) LOOP



      -- 20240819

      v_amount := cdclec.amount;

      v_amountLCY := cdclec.amountLCY;

      v_appliedCustLedgerEntryNo := cdclec.appliedCustLedgerEntryNo;

      v_custLedgerEntryNo := cdclec.custLedgerEntryNo;

      v_customerNo := cdclec.customerNo;

      v_documentNo := cdclec.documentNo;

      v_documentType := cdclec.documentType;

      v_entryNo := cdclec.entryNo;

      v_entryType := cdclec.entryType;

      v_initialDocumentType := cdclec.initialDocumentType;

      v_postingDate := cdclec.postingDate;

      v_sourceCode := cdclec.sourceCode;

      -- 20240819



      DELETE ajc_bc_dcle_control

       WHERE systemId = cdclec.systemId

         AND bc_environment = p_bc_environment;



      INSERT

        INTO ajc_bc_dcle_control

           ( systemId,

             amount,

             amountLCY,

             amountInCompanyCurrencyINE,

             applicationNo,

             appliedCustLedgerEntryNo,

             companyCurrencyCodeINE,

             creditAmount,

             creditAmountLCY,

             currencyCode,

             custLedgerEntryNo,

             customerNo,

             debitAmount,

             debitAmountLCY,

             documentNo,

             documentType,

             entryNo,

             entryType,

             initialDocumentType,

             initialEntryDueDate,

             initialEntryGlobalDim1,

             initialEntryGlobalDim2,

             journalBatchName,

             ledgerEntryAmount,

             maxPaymentTolerance,

             postingDate,

             reasonCode,

             remainingPmtDiscPossible,

             sourceCode,

             systemCreatedAt,

             systemCreatedBy,

             systemModifiedAt,

             systemModifiedBy,

             taxJurisdictionCode,

             transactionNo,

             unapplied,

             unappliedByEntryNo,

             useTax,

             userID,

             createdDate,

             createdTime,

             modifiedDate,

             modifiedTime,

             status, 

             creation_date,

             request_id,

             bc_environment,

             trx_number )

    VALUES ( cdclec.systemId,

             cdclec.amount,

             cdclec.amountLCY,

             cdclec.amountInCompanyCurrencyINE,

             cdclec.applicationNo,

             cdclec.appliedCustLedgerEntryNo,

             cdclec.companyCurrencyCodeINE,

             cdclec.creditAmount,

             cdclec.creditAmountLCY,

             cdclec.currencyCode,

             cdclec.custLedgerEntryNo,

             cdclec.customerNo,

             cdclec.debitAmount,

             cdclec.debitAmountLCY,

             cdclec.documentNo,

             cdclec.documentType,

             cdclec.entryNo,

             cdclec.entryType,

             cdclec.initialDocumentType,

             cdclec.initialEntryDueDate,

             cdclec.initialEntryGlobalDim1,

             cdclec.initialEntryGlobalDim2,

             cdclec.journalBatchName,

             cdclec.ledgerEntryAmount,

             cdclec.maxPaymentTolerance,

             cdclec.postingDate,

             cdclec.reasonCode,

             cdclec.remainingPmtDiscPossible,

             cdclec.sourceCode,

             cdclec.systemCreatedAt,

             cdclec.systemCreatedBy,

             cdclec.systemModifiedAt,

             cdclec.systemModifiedBy,

             cdclec.taxJurisdictionCode,

             cdclec.transactionNo,

             cdclec.unapplied,

             cdclec.unappliedByEntryNo,

             cdclec.useTax,

             cdclec.userID,

             cdclec.createdDate,

             cdclec.createdTime,

             cdclec.modifiedDate,

             cdclec.modifiedTime,

             cdclec.status, 

             cdclec.creation_date,

             cdclec.request_id,

             p_bc_environment,

             DECODE(SUBSTR(cdclec.documentNo,1,3),'AR-',SUBSTR(cdclec.documentNo,4),cdclec.documentNo) );



        v_insert_count := v_insert_count + 1;

        p_dcle_total_control := p_dcle_total_control + 1;



    END LOOP;



    print_log ('Rows inserted: ' || v_insert_count );

    print_log (' ');



    p_return := 'S';

    print_log ('ajc_bc_ar_master_pkg.get_det_cust_ledger_entries_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      print_log ('ajc_bc_ar_master_pkg.get_det_cust_ledger_entries_p (!). ' || SQLERRM);



      -- 20240819

      print_log ( 'Detailed Customer Ledger Entry with error' );

      print_log ( '---------------------------------------------------------------------------------------------------------' );



      print_log ('amount: ' || v_amount );

      print_log ('amountLCY: ' || v_amountLCY );

      print_log ('appliedCustLedgerEntryNo: ' || v_appliedCustLedgerEntryNo );

      print_log ('custLedgerEntryNo: ' || v_custLedgerEntryNo );

      print_log ('customerNo: ' || v_customerNo );

      print_log ('documentNo: ' || v_documentNo );

      print_log ('documentType: ' || v_documentType );

      print_log ('entryNo: ' || v_entryNo );

      print_log ('entryType: ' || v_entryType );

      print_log ('initialDocumentType: ' || v_initialDocumentType );

      print_log ('postingDate: ' || v_postingDate );

      print_log ('sourceCode: ' || v_sourceCode );

      -- 20240819



      p_return := 'E';

      p_error_msg := 'get_det_cust_ledger_entries_p. Error: ' || SQLERRM;



  END get_det_cust_ledger_entries_p;



  /* -- 20240819

  PROCEDURE get_gl_entries_p ( p_company_id               IN       VARCHAR2,

                               p_last_bc_processed_date   IN       TIMESTAMP,

                               p_bc_environment           IN       VARCHAR2,

                               p_return                   IN OUT   VARCHAR2,

                               p_error_msg                IN OUT   VARCHAR2,

                               p_gle_total_control        IN OUT   NUMBER ) IS



    v_get_url        VARCHAR2(2000);

    v_get_api        VARCHAR2(100);



    v_insert_count   NUMBER;



    CURSOR c_source_code IS

    SELECT 'CASHRECJNL' sourceCode

      FROM dual

     UNION ALL

    SELECT 'SALES' sourceCode

      FROM dual

     UNION ALL

    SELECT 'REVERSAL' sourceCode

      FROM dual;



    CURSOR c_gle_control ( p_get_url   IN   VARCHAR2 ) IS

    SELECT systemId,

           accountId,

           addCurrencyCreditAmount,

           addCurrencyDebitAmount,

           additionalCurrencyAmount,

           amount,

           balAccountNo,

           balAccountType,

           businessUnitCode,

           comments,

           costAllocationStatusINE,

           costTypeDimensionCodeINE,

           creditAmount,

           debitAmount,

           description,

           dimensionSetID,

           documentDate,

           documentNo,

           documentType,

           entryNo,

           expenseTypeINE,

           externalDocumentNo,

           faEntryNo,

           faEntryType,

           gLAccountName,

           gLAccountNo,

           globalDimension1Code,

           globalDimension2Code,

           incomeBalanceINE,

           postingDate,

           priorYearEntry,

           quantity,

           reasonCode,

           reversed,

           reversedEntryNo,

           reversedByEntryNo,

           shortcutDimension3Code,

           shortcutDimension4Code,

           shortcutDimension5Code,

           shortcutDimension6Code,

           shortcutDimension7Code,

           shortcutDimension8Code,

           sourceCode,

           sourceNo,

           sourceType,

           systemCreatedEntry,

           systemCreatedAt,

           systemCreatedBy,

           systemModifiedAt,

           systemModifiedBy,

           transactionNo,

           useTax,

           userID,

           vatAmount,

           createdDate,

           createdTime,

           modifiedDate,

           modifiedTime,

           'NEW' status, 

           TRUNC(SYSDATE) creation_date,

           gv_request_id request_id

      FROM json_table( ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => p_get_url ),

                       '$.value[*]' COLUMNS ( systemId                    VARCHAR2(4000) path '$.systemId',

                                              accountId                   VARCHAR2(4000) path '$.accountId',

                                              addCurrencyCreditAmount     VARCHAR2(4000) path '$.addCurrencyCreditAmount',

                                              addCurrencyDebitAmount      VARCHAR2(4000) path '$.addCurrencyDebitAmount',

                                              additionalCurrencyAmount    VARCHAR2(4000) path '$.additionalCurrencyAmount',

                                              amount                      VARCHAR2(4000) path '$.amount',

                                              balAccountNo                VARCHAR2(4000) path '$.balAccountNo',

                                              balAccountType              VARCHAR2(4000) path '$.balAccountType',

                                              businessUnitCode            VARCHAR2(4000) path '$.businessUnitCode',

                                              comments                    VARCHAR2(4000) path '$.comment ',

                                              costAllocationStatusINE     VARCHAR2(4000) path '$.costAllocationStatusINE ',

                                              costTypeDimensionCodeINE    VARCHAR2(4000) path '$.costTypeDimensionCodeINE ',

                                              creditAmount                VARCHAR2(4000) path '$.creditAmount ',

                                              debitAmount                 VARCHAR2(4000) path '$.debitAmount ',

                                              description                 VARCHAR2(4000) path '$.description ',

                                              dimensionSetID              VARCHAR2(4000) path '$.dimensionSetID ',

                                              documentDate                VARCHAR2(4000) path '$.documentDate ',

                                              documentNo                  VARCHAR2(4000) path '$.documentNo ',

                                              documentType                VARCHAR2(4000) path '$.documentType ',

                                              entryNo                     VARCHAR2(4000) path '$.entryNo ',

                                              expenseTypeINE              VARCHAR2(4000) path '$.expenseTypeINE ',

                                              externalDocumentNo          VARCHAR2(4000) path '$.externalDocumentNo ',

                                              faEntryNo                   VARCHAR2(4000) path '$.faEntryNo ',

                                              faEntryType                 VARCHAR2(4000) path '$.faEntryType ',

                                              gLAccountName               VARCHAR2(4000) path '$.gLAccountName ',

                                              gLAccountNo                 VARCHAR2(4000) path '$.gLAccountNo ',

                                              globalDimension1Code        VARCHAR2(4000) path '$.globalDimension1Code ',

                                              globalDimension2Code        VARCHAR2(4000) path '$.globalDimension2Code ',

                                              incomeBalanceINE            VARCHAR2(4000) path '$.incomeBalanceINE ',

                                              postingDate                 VARCHAR2(4000) path '$.postingDate ',

                                              priorYearEntry              VARCHAR2(4000) path '$.priorYearEntry ',

                                              quantity                    VARCHAR2(4000) path '$.quantity ',

                                              reasonCode                  VARCHAR2(4000) path '$.reasonCode ',

                                              reversed                    VARCHAR2(4000) path '$.reversed ',

                                              reversedEntryNo             VARCHAR2(4000) path '$.reversedEntryNo ',

                                              reversedByEntryNo           VARCHAR2(4000) path '$.reversedByEntryNo ',

                                              shortcutDimension3Code      VARCHAR2(4000) path '$.shortcutDimension3Code ',

                                              shortcutDimension4Code      VARCHAR2(4000) path '$.shortcutDimension4Code ',

                                              shortcutDimension5Code      VARCHAR2(4000) path '$.shortcutDimension5Code ',

                                              shortcutDimension6Code      VARCHAR2(4000) path '$.shortcutDimension6Code ',

                                              shortcutDimension7Code      VARCHAR2(4000) path '$.shortcutDimension7Code ',

                                              shortcutDimension8Code      VARCHAR2(4000) path '$.shortcutDimension8Code ',

                                              sourceCode                  VARCHAR2(4000) path '$.sourceCode ',

                                              sourceNo                    VARCHAR2(4000) path '$.sourceNo ',

                                              sourceType                  VARCHAR2(4000) path '$.sourceType ',

                                              systemCreatedEntry          VARCHAR2(4000) path '$.systemCreatedEntry ',

                                              systemCreatedAt             VARCHAR2(4000) path '$.systemCreatedAt ',

                                              systemCreatedBy             VARCHAR2(4000) path '$.systemCreatedBy ',

                                              systemModifiedAt            VARCHAR2(4000) path '$.systemModifiedAt ',

                                              systemModifiedBy            VARCHAR2(4000) path '$.systemModifiedBy ',

                                              transactionNo               VARCHAR2(4000) path '$.transactionNo ',

                                              useTax                      VARCHAR2(4000) path '$.useTax ',

                                              userID                      VARCHAR2(4000) path '$.userID ',

                                              vatAmount                   VARCHAR2(4000) path '$.vatAmount ',

                                              createdDate                 VARCHAR2(4000) path '$.createdDate ',

                                              createdTime                 VARCHAR2(4000) path '$.createdTime ',

                                              modifiedDate                VARCHAR2(4000) path '$.modifiedDate ',

                                              modifiedTime                VARCHAR2(4000) path '$.modifiedTime' )) gle;



  BEGIN



    print_log (' ');

    print_log ('ajc_bc_ar_master_pkg.get_gl_entries_p (+)');



    v_get_api := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'GL ENTRIES',

                                                 p_subentity => NULL,

                                                 p_method => 'GET' );



    v_insert_count := 0;



    FOR csc IN c_source_code LOOP



      print_log ( 'sourceCode: ' || csc.sourceCode );



      v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, p_company_id ) || v_get_api

                   || '?$filter=systemModifiedAt gt ' || TO_CHAR(p_last_bc_processed_date,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z')

                   || ' and sourceCode eq ''' || csc.sourceCode || '''';



      FOR cglec IN c_gle_control ( v_get_url ) LOOP



        DELETE ajc_bc_gle_control

         WHERE systemId = cglec.systemId

           AND bc_environment = p_bc_environment;



        INSERT

          INTO ajc_bc_gle_control

             ( systemId,

               accountId,

               addCurrencyCreditAmount,

               addCurrencyDebitAmount,

               additionalCurrencyAmount,

               amount,

               balAccountNo,

               balAccountType,

               businessUnitCode,

               comments,

               costAllocationStatusINE,

               costTypeDimensionCodeINE,

               creditAmount,

               debitAmount,

               description,

               dimensionSetID,

               documentDate,

               documentNo,

               documentType,

               entryNo,

               expenseTypeINE,

               externalDocumentNo,

               faEntryNo,

               faEntryType,

               gLAccountName,

               gLAccountNo,

               globalDimension1Code,

               globalDimension2Code,

               incomeBalanceINE,

               postingDate,

               priorYearEntry,

               quantity,

               reasonCode,

               reversed,

               reversedEntryNo,

               reversedByEntryNo,

               shortcutDimension3Code,

               shortcutDimension4Code,

               shortcutDimension5Code,

               shortcutDimension6Code,

               shortcutDimension7Code,

               shortcutDimension8Code,

               sourceCode,

               sourceNo,

               sourceType,

               systemCreatedEntry,

               systemCreatedAt,

               systemCreatedBy,

               systemModifiedAt,

               systemModifiedBy,

               transactionNo,

               useTax,

               userID,

               vatAmount,

               createdDate,

               createdTime,

               modifiedDate,

               modifiedTime,

               status,

               creation_date,

               request_id,

               bc_environment,

               trx_number )

      VALUES ( cglec.systemId,

               cglec.accountId,

               cglec.addCurrencyCreditAmount,

               cglec.addCurrencyDebitAmount,

               cglec.additionalCurrencyAmount,

               cglec.amount,

               cglec.balAccountNo,

               cglec.balAccountType,

               cglec.businessUnitCode,

               cglec.comments,

               cglec.costAllocationStatusINE,

               cglec.costTypeDimensionCodeINE,

               cglec.creditAmount,

               cglec.debitAmount,

               cglec.description,

               cglec.dimensionSetID,

               cglec.documentDate,

               cglec.documentNo,

               cglec.documentType,

               cglec.entryNo,

               cglec.expenseTypeINE,

               cglec.externalDocumentNo,

               cglec.faEntryNo,

               cglec.faEntryType,

               cglec.gLAccountName,

               cglec.gLAccountNo,

               cglec.globalDimension1Code,

               cglec.globalDimension2Code,

               cglec.incomeBalanceINE,

               cglec.postingDate,

               cglec.priorYearEntry,

               cglec.quantity,

               cglec.reasonCode,

               cglec.reversed,

               cglec.reversedEntryNo,

               cglec.reversedByEntryNo,

               cglec.shortcutDimension3Code,

               cglec.shortcutDimension4Code,

               cglec.shortcutDimension5Code,

               cglec.shortcutDimension6Code,

               cglec.shortcutDimension7Code,

               cglec.shortcutDimension8Code,

               cglec.sourceCode,

               cglec.sourceNo,

               cglec.sourceType,

               cglec.systemCreatedEntry,

               cglec.systemCreatedAt,

               cglec.systemCreatedBy,

               cglec.systemModifiedAt,

               cglec.systemModifiedBy,

               cglec.transactionNo,

               cglec.useTax,

               cglec.userID,

               cglec.vatAmount,

               cglec.createdDate,

               cglec.createdTime,

               cglec.modifiedDate,

               cglec.modifiedTime,

               cglec.status,

               cglec.creation_date,

               cglec.request_id,

               p_bc_environment,

               DECODE(SUBSTR(cglec.documentNo,1,3),'AR-',SUBSTR(cglec.documentNo,4),cglec.documentNo) );



          v_insert_count := v_insert_count + 1;

          p_gle_total_control := p_gle_total_control + 1;



      END LOOP;



    END LOOP;



    print_log ('Rows inserted: ' || v_insert_count );

    print_log (' ');



    p_return := 'S';  

    print_log ('ajc_bc_ar_master_pkg.get_gl_entries_p (-)');



  EXCEPTION

    WHEN OTHERS THEN

      print_log ('ajc_bc_ar_master_pkg.get_gl_entries_p (!). ' || SQLERRM);

      p_return := 'E';

      p_error_msg := 'get_gl_entries_p. Error: ' || SQLERRM;



  END get_gl_entries_p;

  -- 20240819

  */



  -- 20231026

  FUNCTION get_closed_at_date ( p_entryNo           IN   NUMBER, 

                                p_remainingAmount   IN   NUMBER,

                                p_closedAtDate      IN   VARCHAR2

                                -- 20241212

                                ,p_globaldimension1code   IN   VARCHAR2

                                -- 20241212

                                ) RETURN DATE IS



    v_closedAtDate   ajc_bc_cle_control.closedAtDate%TYPE;



  BEGIN



    -- Si no esta cerrada, no se muestra closedAtDate

    IF ( p_remainingAmount != 0 ) THEN



      RETURN NULL;



    END IF;  



    -- Se verifica si la que tiene el registro es distinta de 0001-01-01

    IF ( p_closedAtDate != '0001-01-01' ) THEN



      v_closedAtDate := p_closedAtDate;



    ELSE



      v_closedAtDate := NULL;



    END IF;



    -- Si no se obtuvo valor, se obtiene de las aplicaciones

    IF ( v_closedAtDate IS NULL ) THEN



      SELECT MAX(closedAtDate)

        INTO v_closedAtDate

        FROM ajc_bc_cle_control

       WHERE closedbyentryno = p_entryNo

         -- 20241212

         AND NVL(globaldimension1code,'-1') = NVL(p_globaldimension1code,'-1')

         ;

         -- 20241212



      IF ( v_closedAtDate = '0001-01-01' ) THEN



        v_closedAtDate := NULL;



      END IF;



    END IF;



    RETURN TO_DATE(v_closedAtDate,'YYYY-MM-DD');



  EXCEPTION

    WHEN OTHERS THEN

      RETURN NULL;



  END get_closed_at_date;



  -- 20231026



  PROCEDURE populate_tables_p -- 20240819

                              ( p_return      IN OUT   VARCHAR2,

                                p_error_msg   IN OUT   VARCHAR2 )

                              -- 20240819                                

                              IS

  BEGIN



    print_log (' ');

    print_log ('ajc_bc_ar_master_pkg.populate_tables_p (+)');



    print_log ('Se borra la tabla atisprod.ra_customer_trx_all');

    DELETE atisprod.ra_customer_trx_all;



    print_log ('Se borra la tabla atisprod.ar_payment_schedules_all');

    DELETE atisprod.ar_payment_schedules_all;



    print_log ('Se borra la tabla atisprod.ar_receivable_applications_all');

    DELETE atisprod.ar_receivable_applications_all;



    print_log ('Se borra la tabla atisprod.ar_cash_receipts_all');

    DELETE atisprod.ar_cash_receipts_all;



    -- print_log ('Se borra la tabla atisprod.ar_adjustments_all');

    -- DELETE atisprod.ar_adjustments_all;

    -- No se borra ni se popula porque no se usa



    -- Populate atisprod.ra_customer_trx_all

    print_log ('Populate atisprod.ra_customer_trx_all');



    INSERT 

      INTO atisprod.ra_customer_trx_all

    SELECT bc.org_id, 

           rct.attribute1,

           rct.attribute2,

           rct.attribute10,

           cle.trx_number, 

           cle.amount,

           rct.customer_trx_id,

           rct.interface_header_attribute4,

           rct.interface_header_context,

           rct.set_of_books_id,

           NVL(rct.sold_to_customer_id,c.customer_id) sold_to_customer_id,

           NVL(rct.trx_date,TO_DATE(cle.documentDate,'YYYY-MM-DD')) trx_date,

           CASE

             WHEN ( cle.remainingAmount != 0 ) THEN

               'OP'

             ELSE

               'CL'

           END status_trx

      FROM ajc.ajc_bc_cle_control cle,

           apps_orafsys.ra_customers c,

           ajc.ajc_bc_companies bc,

           ar.ra_customer_trx_all rct,

           ar.ra_cust_trx_types_all rctt

     WHERE cle.sourceCode = 'SALES'

       AND cle.customerNo = c.customer_number   

       AND cle.globalDimension1Code = bc.oracle_company_number

       AND bc.org_id = rct.org_id

       AND c.customer_id = rct.bill_to_customer_id

       AND cle.trx_number = rct.trx_number

       AND rct.cust_trx_type_id = rctt.cust_trx_type_id

       AND rctt.type = DECODE(cle.documentType,'Invoice','INV','Credit Memo','CM')

       AND rct.creation_date >= TO_DATE('13/10/2017 00:00:00','DD/MM/YYYY HH24:MI:SS')            

       AND rct.interface_header_context IN ('ATIS','NOT ATIS')

       -- 20230807

       -- Se excluyen los intercompany

       AND NOT EXISTS ( SELECT 1

                          FROM ajc_bc_ic_customers

                         WHERE customer_number = cle.customerNo )

       -- 20230807

       -- 20241014

       -- Solo para compañias que no son de LOGISTICS

       AND bc.org_id != 5387

       -- 20241014

       ;       



    -- Populate atisprod.ar_payment_schedules_all

    print_log ('Populate atisprod.ar_payment_schedules_all');



    INSERT 

      INTO atisprod.ar_payment_schedules_all

    SELECT trx.entryNo payment_schedule_id, 

           trx.trx_number,

           -- 

           TO_DATE(trx.documentDate,'YYYY-MM-DD') trx_date,

           TO_DATE(trx.dueDate,'YYYY-MM-DD') due_date,

           TO_DATE(trx.postingDate,'YYYY-MM-DD') gl_date,

           trx.amount amount_due_original, 

           trx.remainingAmount amount_due_remaining,

           CASE

             WHEN ( trx.remainingAmount = 0 ) THEN

               'CL'

             ELSE

               'OP'

           END status,

           CASE 

             WHEN rct.customer_trx_id IS NOT NULL THEN

               DECODE(trx.documentType,'Invoice','INV','Credit Memo','CM')

             ELSE

               'PMT'

           END class,

           TO_NUMBER(NULL) cash_receipt_id,

           CASE

             WHEN trx.currencyCode IS NULL THEN

               -- Se muestra la moneda funcional de la org

               bc.currency

             ELSE

               DECODE(trx.currencyCode,'MXN','MEX',trx.currencyCode)

           END invoice_currency_code,

           CASE

             WHEN trx.currencyCode IS NULL THEN 

               1

             ELSE 

               -- Se usa el que viene de ATIS, si no es de ATIS, se usa el de BC

               NVL(rct.exchange_rate,1 / trx.originalCurrencyFactor)

           END exchange_rate,

           c.customer_id customer_id,

           CASE 

             WHEN rct.customer_trx_id IS NOT NULL THEN

               rct.bill_to_site_use_id

             ELSE

               ( SELECT hcsu.site_use_id

                   FROM hz_cust_acct_sites_all hcas,

                        hz_party_sites hps,

                        hz_cust_site_uses_all hcsu 

                  WHERE hcas.cust_account_id = c.customer_id

                    AND NVL(hcas.status, 'I') = 'A' 

                    AND hcas.party_site_id = hps.party_site_id 

                    AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id 

                    AND hcsu.primary_flag = 'Y' 

                    AND hcsu.org_id = bc.org_id 

                    AND hcsu.site_use_code = 'BILL_TO' ) 

           END customer_site_use_id,       

           rct.customer_trx_id customer_trx_id,

           rct.cust_trx_type_id,

           rct.term_id,

           rct.org_id

           -- 20230731

           ,trx.amount - trx.remainingAmount amount_applied

           -- 20230803 ,TO_DATE(trx.postingDate,'YYYY-MM-DD') actual_date_closed

           -- 20231026 ,TO_DATE(trx.closedAtDate,'YYYY-MM-DD') actual_date_closed

           -- 20241212 ,ajc_bc_ar_master_pkg.get_closed_at_date ( trx.entryNo, trx.remainingAmount, trx.closedAtDate ) actual_date_closed

           ,ajc_bc_ar_master_pkg.get_closed_at_date ( trx.entryNo, trx.remainingAmount, trx.closedAtDate, trx.globaldimension1code ) actual_date_closed

           -- 20231026

           -- 20230803 ,TO_DATE(trx.postingDate,'YYYY-MM-DD') gl_date_closed

           -- 20231026 ,TO_DATE(trx.closedAtDate,'YYYY-MM-DD') gl_date_closed

           -- 20241212 ,ajc_bc_ar_master_pkg.get_closed_at_date ( trx.entryNo, trx.remainingAmount, trx.closedAtDate ) gl_date_closed

           ,ajc_bc_ar_master_pkg.get_closed_at_date ( trx.entryNo, trx.remainingAmount, trx.closedAtDate, trx.globaldimension1code ) gl_date_closed

           -- 20231026 

           ,NULL attribute10

           -- 20230731

      FROM ajc.ajc_bc_cle_control trx, 

           ( SELECT rcta.customer_trx_id,

                    rcta.bill_to_customer_id,

                    rcta.trx_number,

                    rcta.org_id,

                    rcta.term_id,

                    rcta.cust_trx_type_id,

                    rcta.bill_to_site_use_id,

                    rcta.exchange_rate,

                    DECODE(rctt.type,'INV','Invoice','CM','Credit Memo') type

               FROM ar.ra_customer_trx_all rcta,

                    ar.ra_cust_trx_types_all rctt

              WHERE rcta.cust_trx_type_id = rctt.cust_trx_type_id

                AND rcta.creation_date >= TO_DATE('13/10/2017 00:00:00','DD/MM/YYYY HH24:MI:SS')            

                AND rcta.interface_header_context IN ('ATIS','NOT ATIS')

                ) rct,

           apps_orafsys.ra_customers c,

           ajc.ajc_bc_companies bc

     WHERE trx.sourceCode = 'SALES'

       AND trx.customerNo = c.customer_number   

       AND c.customer_id = rct.bill_to_customer_id (+)

       AND trx.trx_number = rct.trx_number (+)

       AND trx.globalDimension1Code = bc.oracle_company_number

       AND bc.org_id = rct.org_id (+)  

       AND trx.documentType = rct.type (+)

       -- 20230807

       -- Se excluyen los intercompany

       AND NOT EXISTS ( SELECT 1

                          FROM ajc_bc_ic_customers

                         WHERE customer_number = trx.customerNo )

       -- 20230807

       -- 20241014

       -- Solo para compañias que no son de LOGISTICS

       AND bc.org_id != 5387

       -- 20241014

     UNION ALL

    -- Payments

    SELECT pay.entryNo payment_schedule_id, 

           pay.trx_number,

           TO_DATE(pay.documentDate,'YYYY-MM-DD') trx_date,

           TO_DATE(pay.dueDate,'YYYY-MM-DD') due_date,

           TO_DATE(pay.postingDate,'YYYY-MM-DD') gl_date,

           pay.amount amount_due_original,

           pay.remainingAmount amount_due_remaining,       

           CASE

             WHEN ( pay.remainingAmount = 0 ) THEN

               'CL'

             ELSE

               'OP'

           END status,

           'PMT' class,

           pay.entryNo cash_receipt_id,

           CASE

             WHEN pay.currencyCode IS NULL THEN

               -- Se muestra la moneda funcional de la org

               bc.currency

             ELSE

               DECODE(pay.currencyCode,'MXN','MEX',pay.currencyCode)

           END invoice_currency_code,

           CASE

             WHEN pay.currencyCode IS NULL THEN 

               1

             ELSE 

               1 / pay.originalCurrencyFactor

           END exchange_rate,

           c.customer_id customer_id,

           ( SELECT hcsu.site_use_id

               FROM hz_cust_acct_sites_all hcas,

                    hz_party_sites hps,

                    hz_cust_site_uses_all hcsu 

              WHERE hcas.cust_account_id = c.customer_id

                AND NVL(hcas.status, 'I') = 'A' 

                AND hcas.party_site_id = hps.party_site_id 

                AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id 

                AND hcsu.primary_flag = 'Y' 

                AND hcsu.org_id = bc.org_id 

                AND hcsu.site_use_code = 'BILL_TO' ) customer_site_use_id,

           NULL customer_trx_id,

           NULL cust_trx_type_id,

           NULL term_id,

           bc.org_id

           -- 20230731

           ,pay.amount - pay.remainingAmount amount_applied

           -- 20230803 ,TO_DATE(pay.postingDate,'YYYY-MM-DD') actual_date_closed

           -- 20231026 ,TO_DATE(pay.closedAtDate,'YYYY-MM-DD') actual_date_closed

           -- 20241212 ,ajc_bc_ar_master_pkg.get_closed_at_date ( pay.entryNo, pay.remainingAmount, pay.closedAtDate ) actual_date_closed

           ,ajc_bc_ar_master_pkg.get_closed_at_date ( pay.entryNo, pay.remainingAmount, pay.closedAtDate, pay.globaldimension1code ) actual_date_closed

           -- 20231026

           -- 20230803 ,TO_DATE(pay.postingDate,'YYYY-MM-DD') gl_date_closed

           -- 20231026 ,TO_DATE(pay.closedAtDate,'YYYY-MM-DD') gl_date_closed

           -- 20241212 ,ajc_bc_ar_master_pkg.get_closed_at_date ( pay.entryNo, pay.remainingAmount, pay.closedAtDate ) gl_date_closed

           ,ajc_bc_ar_master_pkg.get_closed_at_date ( pay.entryNo, pay.remainingAmount, pay.closedAtDate, pay.globaldimension1code ) gl_date_closed

           -- 20231026

           ,NULL attribute10

           -- 20230731

      FROM ajc.ajc_bc_cle_control pay, 

           apps_orafsys.ra_customers c,

           ajc.ajc_bc_companies bc

     WHERE NVL(pay.sourceCode,'X') != 'SALES'

       AND pay.customerNo = c.customer_number   

       AND pay.globalDimension1Code = bc.oracle_company_number

       -- 20230807

       -- Se excluyen los intercompany

       AND NOT EXISTS ( SELECT 1

                          FROM ajc_bc_ic_customers

                         WHERE customer_number = pay.customerNo )

       -- 20230807

       -- 20241014

       -- Solo para compañias que no son de LOGISTICS

       AND bc.org_id != 5387

       -- 20241014

       ;



    -- Populate atisprod.ar_receivable_applications_all

    print_log ('Populate atisprod.ar_receivable_applications_all');



    INSERT 

      INTO atisprod.ar_receivable_applications_all

    -- Invoices | Credit Memos

    SELECT TO_DATE(SUBSTR(app.systemCreatedAt,1,10),'YYYY-MM-DD') apply_date,

           doc.entryNo payment_schedule_id,

           TO_DATE(app.postingDate,'YYYY-MM-DD') gl_date,

           NULL reversal_gl_date,

           NULL confirmed_flag,

           0 acctd_unearned_discount_taken,

           0 acctd_earned_discount_taken,

           -- Se usa el que viene de ATIS

           ROUND(-1 * app.amount * rct.exchange_rate,2) acctd_amount_applied_to,

           -- Se usa el que viene de ATIS, si no es de ATIS, se usa el de BC

           ROUND(-1 * app.amount * NVL(rct_app.exchange_rate,( 1 / doc.originalCurrencyFactor) ) ,2) acctd_amount_applied_from,

           rct_app.customer_trx_id,

           app.entryNo receivable_application_id,

           -1 * app.amount amount_applied,

           c.customer_id on_account_customer,

           inv.entryNo applied_payment_schedule_id,

           rct.customer_trx_id applied_customer_trx_id,

           DECODE(app.unapplied,'false','Y','N') display,

           CASE

             WHEN ( ( doc.documentNo LIKE 'CRJ%' OR doc.documentNo LIKE 'AR-%' ) AND doc.documentType NOT IN ('Invoice','Credit Memo') ) THEN

               doc.entryNo

             ELSE

               TO_NUMBER(NULL)

           END cash_receipt_id,

           CASE

             WHEN ( doc.documentNo LIKE 'CRJ%' OR doc.documentNo LIKE 'AR-%' ) THEN

               'CASH'

             WHEN ( app.DocumentType = 'Credit Memo' ) THEN

               'CM' 

             ELSE

               'CASH'

           END application_type,

           DECODE(app.sourceCode,'SALESAPPL','APP',

                                 'CASHRECJNL','APP',

                                 'SALES','APP',

                                 'UNAPPSALES','UNAPP',

                                  NULL,'APP') status,

           rct.org_id,

           bc.set_of_books_id

      FROM ajc.ajc_bc_cle_control inv,

           ( SELECT rcta.customer_trx_id,

                    rcta.bill_to_customer_id,

                    rcta.trx_number,

                    rcta.org_id,

                    rcta.term_id,

                    rcta.cust_trx_type_id,

                    rcta.bill_to_site_use_id,

                    rcta.exchange_rate,

                    DECODE(rctt.type,'INV','Invoice','CM','Credit Memo') type

               FROM ar.ra_customer_trx_all rcta,

                    ar.ra_cust_trx_types_all rctt

              WHERE rcta.cust_trx_type_id = rctt.cust_trx_type_id

                AND rcta.creation_date >= TO_DATE('13/10/2017 00:00:00','DD/MM/YYYY HH24:MI:SS')            

                AND rcta.interface_header_context IN ('ATIS','NOT ATIS') ) rct,

           apps_orafsys.ra_customers c,

           ajc.ajc_bc_companies bc,

           ajc.ajc_bc_dcle_control app,

           ajc.ajc_bc_cle_control doc,

           ( SELECT rctb.customer_trx_id,

                    rctb.bill_to_customer_id,

                    rctb.trx_number,

                    rctb.org_id,

                    rctb.term_id,

                    rctb.cust_trx_type_id,

                    rctb.bill_to_site_use_id,

                    rctb.exchange_rate,

                    DECODE(rctt.type,'INV','Invoice','CM','Credit Memo') type

               FROM ar.ra_customer_trx_all rctb,

                    ar.ra_cust_trx_types_all rctt

              WHERE rctb.cust_trx_type_id = rctt.cust_trx_type_id

                AND rctb.creation_date >= TO_DATE('13/10/2017 00:00:00','DD/MM/YYYY HH24:MI:SS')            

                AND rctb.interface_header_context IN ('ATIS','NOT ATIS') ) rct_app

     WHERE ( ( inv.documentType = 'Invoice' AND doc.documentType != 'Invoice' ) OR

             ( inv.documentType = 'Credit Memo' AND doc.documentType != 'Credit Memo' ) )

       AND inv.sourceCode = 'SALES'

       AND inv.customerNo = c.customer_number   

       AND c.customer_id = rct.bill_to_customer_id

       AND inv.trx_number = rct.trx_number

       AND inv.documentType = rct.type

       AND inv.globalDimension1Code = bc.oracle_company_number

       AND bc.org_id = rct.org_id

       AND inv.entryNo = app.custLedgerEntryNo

       AND inv.globalDimension1Code = app.initialEntryGlobalDim1

       AND app.entryType = 'Application'

       AND app.appliedCustLedgerEntryNo = doc.entryNo

       AND app.initialEntryGlobalDim1 = doc.globalDimension1Code

       AND c.customer_id = rct_app.bill_to_customer_id (+)

       AND doc.trx_number = rct_app.trx_number (+)

       AND doc.documentType = rct_app.type (+)

       -- 20230807

       -- Se excluyen los intercompany

       AND NOT EXISTS ( SELECT 1

                          FROM ajc_bc_ic_customers

                         WHERE customer_number = inv.customerNo )

       -- 20230807

       -- 20241014

       -- Solo para compañias que no son de LOGISTICS

       AND bc.org_id != 5387

       -- 20241014

     UNION ALL

    -- OP no aplicado (remaining) va On Account

    SELECT TO_DATE(SUBSTR(doc.systemCreatedAt,1,10),'YYYY-MM-DD') apply_date,

           doc.entryNo payment_schedule_id,

           TO_DATE(doc.postingDate,'YYYY-MM-DD') gl_date,

           NULL reversal_gl_date,

           NULL confirmed_flag,

           0 acctd_unearned_discount_taken,

           0 acctd_earned_discount_taken,

           NULL acctd_amount_applied_to,

           ROUND(doc.remainingAmount * ( 1 / doc.originalCurrencyFactor ),2) acctd_amount_applied_from,

           NULL customer_trx_id,

           doc.entryNo receivable_application_id,

           doc.remainingAmount amount_applied,

           c.customer_id on_account_customer,

           -1 applied_payment_schedule_id,

           NULL applied_customer_trx_id, 

           'Y' display,

           doc.entryNo cash_receipt_id,

           'CASH' application_type,

           'ACC' status,

           bc.org_id,

           bc.set_of_books_id

      FROM ajc.ajc_bc_cle_control doc,

           apps_orafsys.ra_customers c,

           ajc.ajc_bc_companies bc

     WHERE doc.globalDimension1Code = bc.oracle_company_number

       AND doc.remainingAmount != 0

       AND doc.customerNo = c.customer_number

       AND NVL(doc.sourceCode,'X') != 'SALES'

       -- 20230807

       -- Se excluyen los intercompany

       AND NOT EXISTS ( SELECT 1

                          FROM ajc_bc_ic_customers

                         WHERE customer_number = doc.customerNo )

       -- 20230807

       -- 20241014

       -- Solo para compañias que no son de LOGISTICS

       AND bc.org_id != 5387

       -- 20241014

       ;



    -- Populate atisprod.ar_cash_receipts_all

    print_log ('Populate atisprod.ar_cash_receipts_all');



    INSERT 

      INTO atisprod.ar_cash_receipts_all

    SELECT rcp.entryNo cash_receipt_id,

           rcp.trx_number receipt_number,

           bc.set_of_books_id,

           bc.org_id,

           TO_DATE(rcp.documentDate,'YYYY-MM-DD') receipt_date,

           CASE

             WHEN rcp.currencyCode IS NULL THEN 

               1

             ELSE 

               1 / rcp.originalCurrencyFactor

           END exchange_rate,

           CASE

             WHEN rcp.currencyCode IS NULL THEN

               -- Se muestra la moneda funcional de la org

               bc.currency

             ELSE

               DECODE(rcp.currencyCode,'MXN','MEX',rcp.currencyCode) 

           END currency_code,

           rcp.shortcutdimension8code attribute2, -- worksheet

           rcp.comments,

           NULL application_notes

      FROM ajc.ajc_bc_cle_control rcp,

           ajc.ajc_bc_companies bc 

     WHERE rcp.globalDimension1Code = bc.oracle_company_number 

       AND NVL(rcp.sourceCode,'X') != 'SALES'

       -- 20230807

       -- Se excluyen los intercompany

       AND NOT EXISTS ( SELECT 1

                          FROM ajc_bc_ic_customers

                         WHERE customer_number = rcp.customerNo )

       -- 20230807

       -- 20241014

       -- Solo para compañias que no son de LOGISTICS

       AND bc.org_id != 5387

       -- 20241014

       ;



    p_return := 'S';



    print_log ('ajc_bc_ar_master_pkg.populate_tables_p (-)');

    print_log (' ');



  -- 20240819

  EXCEPTION

    WHEN OTHERS THEN

      print_log ('ajc_bc_ar_master_pkg.populate_tables_p (!). ' || SQLERRM);

      p_return := 'E';

      p_error_msg := 'populate_tables_p. Error: ' || SQLERRM;

  -- 20240819



  END populate_tables_p;



  PROCEDURE main_p ( retcode            OUT   NUMBER,

                     errbuf             OUT   VARCHAR2,

                     p_bc_environment   IN   VARCHAR2 ) IS



    v_run_date                 TIMESTAMP;

    v_last_processed_date      TIMESTAMP;

    v_last_bc_processed_date   TIMESTAMP;

    v_email                    VARCHAR2(2000);



    v_return                   VARCHAR2(1);

    v_error_msg                VARCHAR2(1);



    -- Control

    v_cle_total_control        NUMBER;

    v_dcle_total_control       NUMBER;

    -- 20240819 v_gle_total_control        NUMBER;



      CURSOR c_bc_companies IS

      SELECT bc_company_name,

             bc_company_id

        FROM ajc_bc_companies

    GROUP BY bc_company_name,

             bc_company_id

    ORDER BY bc_company_name;



    e_get_master_tables        EXCEPTION;

    e_populate_tables          EXCEPTION;



  BEGIN



    print_log ('ajc_bc_ar_master_pkg.main_p (+)');

    print_log (' ');



    v_email := ajc_bc_ws_utils_pkg.get_emails_f ( 'AR' );



    print_log ('BC Environment: ' || p_bc_environment);

    print_log ('Mail: ' || v_email);

    print_log (' ');



    print_log ('Se obtienen los customers intercompany y el customer UNIDENTIFIED.');



    ajc_bc_ic_customers_pkg.main_p ( p_bc_environment => p_bc_environment );



    print_log ('Inicio Sincronización de datos de AR.');



    -- Se guarda la fecha y hora actual

    v_run_date := systimestamp;

    print_log ( 'v_run_date: ' || v_run_date );



    -- Se obtiene la fecha y hora de Oracle de la ultima ejecucion de la interface

    v_last_processed_date := ajc_bc_ws_utils_pkg.get_ifc_last_processed_date_f ( gv_ifc );

    print_log ( 'Oracle last processed date: ' || v_last_processed_date );    



    -- Se obtiene la fecha y hora de BC de la ultima ejecucion de la interface

    v_last_bc_processed_date := ajc_bc_ws_utils_pkg.get_bc_last_processed_date_f ( v_last_processed_date );

    print_log ( 'BC last processed date: ' || v_last_bc_processed_date );



    -- Tablas de control

    v_cle_total_control := 0;

    v_dcle_total_control := 0;

    -- 20240819 v_gle_total_control := 0;



    FOR bcc IN c_bc_companies LOOP



      print_log (' ');

      print_log ('- BC Company Name: ' || bcc.bc_company_name || '------------------------------------------------------------------------------------------ ');



      get_cust_ledger_entries_p ( p_company_id => bcc.bc_company_id,

                                  p_last_bc_processed_date => v_last_bc_processed_date,

                                  p_bc_environment => p_bc_environment,

                                  p_return => v_return,

                                  p_error_msg => v_error_msg,

                                  p_cle_total_control => v_cle_total_control );



      IF ( v_return != 'S' ) THEN



        RAISE e_get_master_tables;



      END IF;



      get_det_cust_ledger_entries_p ( p_company_id => bcc.bc_company_id,

                                      p_last_bc_processed_date => v_last_bc_processed_date,

                                      p_bc_environment => p_bc_environment,

                                      p_return => v_return,

                                      p_error_msg => v_error_msg,

                                      p_dcle_total_control => v_dcle_total_control );



      IF ( v_return != 'S' ) THEN



        RAISE e_get_master_tables;



      END IF;



      /* -- 20240819

      get_gl_entries_p ( bcc.bc_company_id, v_last_bc_processed_date, p_bc_environment, v_return, v_error_msg, v_gle_total_control );



      IF ( v_return != 'S' ) THEN



        RAISE e_get_master_tables;



      END IF;

      -- 20240819

      */



    END LOOP;



    -- Se llenan las tablas atisprod

    populate_tables_p -- 20240819

                      ( p_return => v_return,

                        p_error_msg => v_error_msg )

                      -- 20240819

                      ;



    -- 20240819

    IF ( v_return != 'S' ) THEN



      RAISE e_populate_tables;



    END IF;

    -- 20240819



    COMMIT;



    -- Se actualiza la tabla de control

    ajc_bc_ws_utils_pkg.upd_ifc_last_processed_date_p ( gv_ifc,

                                                        gv_request_id,

                                                        v_run_date );



    print_log ('Registros Customer Ledger Entries totales: ' || v_cle_total_control );

    print_log ('Registros Detailed Customer Ledger Entries totales: ' || v_dcle_total_control );

    -- 20240819 print_log ('Registros General Ledger Entries totales: ' || v_gle_total_control );

    print_log (' ');



    print_log ('Fin Sincronización de datos de AR.');

    print_log (' ');                                                        



  EXCEPTION 

    WHEN e_get_master_tables THEN

      ROLLBACK;



      print_log ( 'ajc_bc_ar_master_pkg.main_p (!) - e_get_master_tables. Error: ' || SQLERRM );

      ajc_bc_ws_utils_pkg.send_email ( p_to => v_email,

                                       p_subject => 'AJC BC AR Master - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'),

                                       p_message => 'Request ID: ' || gv_request_id || CHR(10) || CHR(10) ||

                                                    'Data Sync error: ' || SQLERRM );



    -- 20240819

    WHEN e_populate_tables THEN

      ROLLBACK;



      print_log ( 'ajc_bc_ar_master_pkg.main_p (!) - e_populate_tables. Error: ' || SQLERRM );

      ajc_bc_ws_utils_pkg.send_email ( p_to => v_email,

                                       p_subject => 'AJC BC AR Master - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'),

                                       p_message => 'Request ID: ' || gv_request_id || CHR(10) || CHR(10) ||

                                                    'Populate tables error: ' || SQLERRM );

    -- 20240819



    WHEN OTHERS THEN

      ROLLBACK;



      print_log ( 'ajc_bc_ar_master_pkg.main_p (!) - OTHERS. Error: ' || SQLERRM );



      -- 20251210

      /*

      ajc_bc_ws_utils_pkg.send_email ( p_to => v_email,

                                       p_subject => 'AJC BC AR Master - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS'),

                                       p_message => 'Request ID: ' || gv_request_id || CHR(10) || CHR(10) ||

                                                    'Sync error: ' || SQLERRM );

      */

      -- 20251210



  END main_p;



END ajc_bc_ar_master_pkg;
