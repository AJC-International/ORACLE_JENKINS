PACKAGE BODY ajc_bc_ar_master_pkg AS
  
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

    v_get_url     
