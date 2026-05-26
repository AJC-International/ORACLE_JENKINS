CREATE OR REPLACE PACKAGE              AJC_BC_AR_CLE_PKG 

AS

    /*******************************************************************************

    NAME     : AJC_BC_AR_CLE_PKG

    PURPOSE  : Package to download the AR information from Customer Ledger Entry from BC into a internal tables

    TEAM OWNER:  Apps Support

    ********************************************************************************/



    PROCEDURE MAIN_P(P_FULL_REFRESH IN CHAR DEFAULT 'N');  



END AJC_BC_AR_CLE_PKG;
