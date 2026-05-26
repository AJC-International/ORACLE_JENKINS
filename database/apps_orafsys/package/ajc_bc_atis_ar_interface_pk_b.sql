PACKAGE BODY ajc_bc_atis_ar_interface_pk IS
/*------------------------------------------------------------------------------------------------|
| Historial                                                                                       |
|   Date      Version  Modified    Detail                                                         |
|   --------- -------  ----------  -------------------------------------------------------------- |
|   02-MAR-22       1  SBanchieri  Creation                                                       |
|-------------------------------------------------------------------------------------------------*/

  -- 20251204 REINTENTO
  gv_retry_in_seconds   NUMBER;
  gv_retry              VARCHAR2(1);
  -- 20251204 REINTENTO

  /*=========================================================================+
  |                                                                          |
  | Private Procedure                                                        |
  |    print_log                                                             |
  |                                                                          |
  | Description                                                              |
  |    Impresion de log                                                      |
  |                                                                          |
  | Parameters                                                               |
  |    p_message                   IN     NUMBER    Mensaje.                 |
  |                                                                          |
  +=========================================================================*/
  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line (fnd_file.log, p_message);

  END print_log;

  /*=========================================================================+
  |                                                                          |
  | Private Procedure                                                        |
  |    print_output                                                          |
  |                                                                          |
  | Description                                                              |
  |    Impresion de output                                                   |
  |                                                                          |
  | Parameters                                                               |
  |    p_message                   IN     NUMBER    Mensaje.                 |
  |                                                                          |
  +=========================================================================*/

  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line(fnd_file.output,p_message);

  END print_output;

  /*=========================================================================+
  |                                                                          |
  | Private Procedure                                                        |
  |    insert_lines_table                                                    |
  |                                                                          |
  | Description                                                              |
  |    Insert Lines Table                                                    |
  |                                                                          |
  | Parameters                                                               |
  |    p_message                   IN     NUMBER    Mensaje.                 |
  |                                                                          |
  +=========================================================================*/
  PROCEDURE insert_lines_table ( p_status_code               OUT   VARCHAR2,
                                 p_error_message             OUT   VARCHAR2,
                                 p_customer_trx_id            IN   NUMBER,
                                 p_customer_trx_line_id       IN   NUMBER,
                                 p_json_data                  IN   CLOB,
                                 p_line_number                IN   NUMBER,
                                 p_description                IN   VARCHAR2,
                                 p_quantity                   IN   NUMBER,
                                 p_unit_selling_price         IN   NUMBER,
                                 p_extended_amount            IN   NUMBER ) IS  
  BEGIN

    print_log('AJC_BC_ATIS_AR_INTERFACE_PK.insert_lines_table (+)');

      INSERT 
        INTO AJC_BC_ATIS_AR_LINES
           ( request_id,
             customer_trx_id,
             customer_trx_line_id,
             json_data,
             line_number,
             description,
             quantity,
             unit_selling_price,
             extended_amount,
             creation_date,
             created_by,
             last_update_date,
             last_updated_by,
             status )
    VALUES ( gv_request_id,
             p_customer_trx_id,
             p_customer_trx_line_id,
             p_json_data,
             p_line_number,
             p_description,
             p_quantity,
             p_unit_selling_price,
             p_extended_amount,
             sysdate,
             gv_user_id,
             sysdate,
             gv_user_id,
             'NEW' );

    print_log ('- Se inserta la linea en la tabla custom ---------------------------------------------------------------------');

    p_status_code := 'S';

    print_log('AJC_BC_ATIS_AR_INTERFACE_PK.insert_lines_table (-)');

  EXCEPTION
    WHEN OTHERS THEN
      p_status_code := 'E';
      p_error_message := 'Error al insertar registro insert_lines_table, Error: '||sqlerrm;
      print_log('AJC_BC_ATIS_AR_INTERFACE_PK.insert_lines_table. Error: '||sqlerrm);
      print_log('AJC_BC_ATIS_AR_INTERFACE_PK.insert_lines_table (!)');

  END insert_lines_table;  

  /*=========================================================================+
  |                                                                          |
  | Private Procedure                                                        |
  |    insert_headers_table                                                  |
  |                                                                          |
  | Description                                                              |
  |    Insert Headers Table                                                  |
  |                                                                          |
  | Parameters                                                               |
  |    p_message                   IN     NUMBER    Mensaje.                 |
  |                                                                          |
  +=========================================================================*/
  PROCEDURE insert_headers_table ( p_status_code               OUT   VARCHAR2,
                                   p_error_message             OUT   VARCHAR2,
                                   p_customer_trx_id            IN   NUMBER,
                                   p_json_data                  IN   CLOB,
                                   p_trx_number                 IN   VARCHAR2,
                                   p_trx_date                   IN   VARCHAR2, 
                                   p_class                      IN   VARCHAR2, 
                                   p_currency_code              IN   VARCHAR2,
                                   p_amount                     IN   NUMBER,
                                   p_customer_name              IN   VARCHAR2,
                                   p_customer_number            IN   VARCHAR2,
                                   p_org_id                     IN   NUMBER,
                                   p_company                    IN   VARCHAR2 ) IS  
  BEGIN

    print_log('AJC_BC_ATIS_AR_INTERFACE_PK.insert_headers_table (+)');

      INSERT 
        INTO AJC_BC_ATIS_AR_HEADERS
           ( request_id,
             customer_trx_id,
             json_data,
             trx_number,
             trx_date,
             class,
             currency_code,
             amount,
             customer_name,
             customer_number,
             org_id,
             company,
             creation_date,
             created_by,
             last_update_date,
             last_updated_by,
             status )
    VALUES ( gv_request_id,
             p_customer_trx_id,
             p_json_data,
             p_trx_number,
             p_trx_date,
             p_class,
             p_currency_code,
             p_amount,
             p_customer_name,
             p_customer_number,
             p_org_id,
             p_company,
             sysdate,
             gv_user_id,
             sysdate,
             gv_user_id,
             'NEW' );

    print_log ('- Se inserta la cabecera en la tabla custom ------------------------------------------------------------------');

    p_status_code := 'S';

    print_log('AJC_BC_ATIS_AR_INTERFACE_PK.insert_headers_table (-)');

  EXCEPTION
    WHEN OTHERS THEN
      p_status_code := 'E';
      p_error_message := 'Error al insertar registro insert_headers_table, Error: '||sqlerrm;
      print_log('AJC_BC_ATIS_AR_INTERFACE_PK.insert_headers_table. Error: '||sqlerrm);
      print_log('AJC_BC_ATIS_AR_INTERFACE_PK.insert_headers_table (!)');

  END insert_headers_table; 

  PROCEDURE delete_inbound_records ( p_bc_environment    IN   VARCHAR2,
                                     p_company_id        IN   VARCHAR2,
                                     p_customer_trx_id   IN   NUMBER ) IS

    v_api_delete_header    VARCHAR2(200);
    v_api_delete_lines     VARCHAR2(200);
    v_header_delete_url    VARCHAR2(2000);
    v_lines_delete_url     VARCHAR2(2000);
    v_header_delete_clob   CLOB;
    v_lines_delete_clob    CLOB;

  BEGIN

    print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.delete_inbound_records (+)');

    v_api_delete_header := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'SALES INVOICES',
                                                           p_subentity => 'HEADERS',
                                                           p_method => 'DELETE' );

    print_log ( 'v_api_delete_header: ' || v_api_delete_header );

    v_api_delete_lines := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'SALES INVOICES',
                                                          p_subentity => 'LINES',
                                                          p_method => 'DELETE' );

    print_log ( 'v_api_delete_lines: ' || v_api_delete_lines ); 

    -- Se arma la URL para borrar lineas de la tabla staging
    v_lines_delete_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, p_company_id ) || v_api_delete_lines
                          || '(' || p_customer_trx_id || ',0,0)' -- customerTrxID, requestID, lineNo
                          ; 

    print_log ( 'v_lines_delete_url: ' || v_lines_delete_url );

    -- Se borran las lineas de la tabla staging
    v_lines_delete_clob := ajc_bc_ws_utils_pkg.delete_bc_row_f ( p_url => v_lines_delete_url );

    IF ( INSTR(v_lines_delete_clob,'error') != 0 )  THEN

      print_log('Error al borrar lineas de la tabla stage de BC');
      print_log(v_lines_delete_clob);

    ELSE

      print_log('Lineas borradas de la tabla stage de BC');

    END IF;

    -- Se arma la URL para borrar cabecera de la tabla staging
    v_header_delete_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, p_company_id ) || v_api_delete_header
                           || '(' || p_customer_trx_id || ',0)' -- customerTrxID, requestID
                           ; 

    print_log ( 'v_header_delete_url: ' || v_header_delete_url );

    -- Se borra la cabecera de la tabla staging
    v_header_delete_clob := ajc_bc_ws_utils_pkg.delete_bc_row_f ( p_url => v_header_delete_url );

    IF ( INSTR(v_header_delete_clob,'error') != 0 )  THEN

      print_log('Error al borrar cabecera de la tabla stage de BC');
      print_log(v_header_delete_clob);

    ELSE

      print_log('Cabecera borrada de la tabla stage de BC');

    END IF;

    print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.delete_inbound_records (-)');

  END delete_inbound_records;

  /*=========================================================================+
  |                                                                          |
  | Private Procedure                                                        |
  |    insert_trx                                                            |
  |                                                                          |
  | Description                                                              |
  |    Genero registros que seran enviados a BC                              |
  |    insertando en tabla del proceso y json por linea de asiento           |
  |                                                                          |
  | Parameters                                                               |
  |    p_message                   IN     NUMBER    Mensaje.                 |
  |                                                                          |
  +=========================================================================*/
  PROCEDURE insert_trx ( p_status          OUT   VARCHAR2,
                         p_error_message   OUT   VARCHAR2,
                         p_date_from        IN   VARCHAR2,
                         p_bc_environment   IN   VARCHAR2 ) IS

    CURSOR c_customer_trx_del IS
    SELECT rct.customer_trx_id,
           ajc_bc_account_dim_pkg.account_dim_required(aba.bc_account,'COMPANY',gcc.segment1) bc_company_number
      FROM ra_customer_trx_all rct,
           ra_batch_sources_all rbs,
           ra_cust_trx_line_gl_dist_all rctd,
           gl_code_combinations gcc,
           ajc_bc_accounts aba
     WHERE rct.attribute7 = TO_CHAR(gv_request_id)
       AND rct.batch_source_id = rbs.batch_source_id
       AND rct.interface_header_context = 'ATIS'
       AND rct.complete_flag = 'Y'
       AND rct.customer_trx_id = rctd.customer_trx_id
       -- AND rct.customer_trx_id = 4981308
       AND rctd.code_combination_id = gcc.code_combination_id
       AND rctd.account_class = 'REC'
       AND gcc.segment2 = aba.oracle_account (+);

    v_bc_company_id        VARCHAR2(200);
    v_get_company_status   VARCHAR2(200);

    CURSOR c_cabeceras IS
    SELECT rct.customer_trx_id, 
           -- 20220712
           /*
           ( SELECT gcc.segment1
               FROM ra_cust_trx_line_gl_dist_all rctd,
                    gl_code_combinations gcc
              WHERE rctd.code_combination_id = gcc.code_combination_id
                AND rctd.account_class = 'REC'
                AND rctd.customer_trx_id = rct.customer_trx_id ) company,
           */
           gcc.segment1 company,
           aba.bc_account account,
           gcc.segment3 department,
           DECODE(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT4'
                                                                      ,p_oracle_value   => gcc.segment4
                                                                      ,p_bc_dimension   => 'DIVISION'), NULL,gcc.segment4,'000') product,
           DECODE(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT5'
                                                                      ,p_oracle_value   => gcc.segment5
                                                                      ,p_bc_dimension   => 'OFFICE'), NULL,gcc.segment5,'000') destination,
           gcc.segment6 origin,
           NVL(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT5'
                                                                   ,p_oracle_value   => gcc.segment5
                                                                   ,p_bc_dimension   => 'OFFICE'),'000') office,
           -- 20221205                                                                   
           gcc.segment7 intercompany,
           -- 20220712
           rct.trx_number transactionNo,
           TO_CHAR(rct.trx_date,'YYYY-MM-DD') transactionDate,
           ctt.type class,
           SUBSTR(pt.name,1,10) termName,
           TO_CHAR(NVL(rct.term_due_date,aps.due_date),'YYYY-MM-DD') termDueDate,
           TO_CHAR(
             ( SELECT MIN(rctd.gl_date)
                 FROM ra_customer_trx_lines_all rctl,
                      ra_cust_trx_line_gl_dist_all rctd
                WHERE rctl.customer_trx_id = rct.customer_trx_id
                  AND rctl.customer_trx_line_id = rctd.customer_trx_line_id ) 
           ,'YYYY-MM-DD') glDate,
           -- 20220923
           -- rct.invoice_currency_code invoiceCurrencyCode,
           NVL(fc.attribute1, rct.invoice_currency_code) invoiceCurrencyCode,
           -- 20220923
           TO_CHAR(rct.exchange_date,'YYYY-MM-DD') exchangeDate,
           rct.exchange_rate exchangeRate,
           rct.exchange_rate_type exchangeRateType,
           rct.purchase_order purchaseOrder,
           DECODE( ctt.type, 'CM', -1, 1) * ( SELECT SUM(rctl.extended_amount)
                                                FROM ra_customer_trx_lines_all rctl
                                               WHERE rctl.customer_trx_id = rct.customer_trx_id ) amount,
           NULL accountedAmount,
           rc.customer_name billToCustomerName,
           rc.customer_number billToCustomerNo,
           SUBSTR(hl.address1,1,100) billToAddress1,
           SUBSTR(hl.address2,1,50) billToAddress2,
           SUBSTR(hl.address3,1,50) billToAddress3,
           rct.interface_header_attribute4 worksheet,
           DECODE(NVL(rct.attribute2,'N'),'N','false','Y','true') override_flag,
           rct.org_id,
           -- 20220809
           rct.comments
           -- 20220809
           -- 20231211
           -- Verifica si es un comprobante que tiene alguna linea con mas de una distribucion
           ,DECODE( 
                    ( SELECT COUNT(1)
                        FROM ra_customer_trx_lines_all rctl  
                       WHERE rctl.customer_trx_id = rct.customer_trx_id
                         AND EXISTS ( SELECT rctd.customer_trx_line_id
                                        FROM ra_cust_trx_line_gl_dist_all rctd
                                       WHERE rctd.customer_trx_line_id = rctl.customer_trx_line_id
                                         AND rctd.account_class = 'REV'
                                    GROUP BY rctd.customer_trx_line_id
                                      HAVING COUNT(1) > 1 ) ),0,'N','Y') several_distributions
           -- 20231211
      FROM ra_customer_trx_all rct,
           ra_batch_sources_all rbs,
           -- hr_operating_units ou,
           ra_cust_trx_types_all ctt,
           ar_customers rc,
           hz_cust_site_uses_all site_uses,
           hz_cust_acct_sites_all acct_sites,
           hz_party_sites party_sites,
           hz_locations hl,
           ra_terms_tl pt,
           ar_payment_schedules_all aps,
           -- 20220712
           ra_cust_trx_line_gl_dist_all rctd,
           gl_code_combinations gcc,
           ajc.ajc_bc_accounts aba
           -- 20220712
           -- 20220923
           ,fnd_currencies fc
           -- 20220923
     WHERE rct.batch_source_id = rbs.batch_source_id
       -- 20230202
       -- AND rbs.name = 'ATIS-INC-IMPORT'
       AND rct.interface_header_context = 'ATIS'
       -- 20230202
       AND rct.attribute7 = TO_CHAR(gv_request_id)
       AND rct.complete_flag = 'Y'
       AND rct.cust_trx_type_id = ctt.cust_trx_type_id
       AND rct.bill_to_customer_id = rc.customer_id
       AND rct.bill_to_site_use_id = site_uses.site_use_id
       AND site_uses.cust_acct_site_id = acct_sites.cust_acct_site_id
       AND acct_sites.party_site_id = party_sites.party_site_id
       AND party_sites.location_id = hl.location_id
       AND rct.term_id = pt.term_id (+)
       AND rct.customer_trx_id = aps.customer_trx_id (+)
       -- 20220712
       AND rctd.code_combination_id = gcc.code_combination_id
       AND rctd.account_class = 'REC'
       AND rctd.customer_trx_id = rct.customer_trx_id
       AND gcc.segment2 = aba.oracle_account (+)
       -- 20220712
       -- 20220923
       AND rct.invoice_currency_code = fc.currency_code
       -- 20220923
  ORDER BY DECODE(ctt.type,'INV',1,'CM',2); -- Debe procesar primero las invoices para poder aplicar con CM

      CURSOR c_lineas ( pc_customer_trx_id   IN   NUMBER,
                        pc_class             IN   VARCHAR2 ) IS 
      -- Lineas con una distribucion
      SELECT rctl.customer_trx_id,
             rctl.customer_trx_line_id,
             rctl.line_number lineNo,
             SUBSTR(rctl.description,1,100) description,
             DECODE(pc_class,'CM',-1,1) * DECODE(pc_class,'INV',rctl.quantity_invoiced,rctl.quantity_credited) quantity,
             rctl.unit_selling_price unitSellingPrice,
             DECODE(pc_class,'CM',-1,1) * rctl.extended_amount extendedAmount,
             DECODE(pc_class,'CM',-1,1) * rctd.acctd_amount accountedAmount,
             aba.bc_account account,
             gcc.segment3 department,
             DECODE( AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT4'
                                                                         ,p_oracle_value   => gcc.segment4
                                                                         ,p_bc_dimension   => 'DIVISION'), NULL,gcc.segment4,'000') product,
             DECODE(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT5'
                                                                        ,p_oracle_value   => gcc.segment5
                                                                        ,p_bc_dimension   => 'OFFICE'), NULL,gcc.segment5,'000') destination,
             NVL(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT5'
                                                                     ,p_oracle_value   => gcc.segment5
                                                                     ,p_bc_dimension   => 'OFFICE'),'000') office,  
             gcc.segment6 origin,
             gcc.segment7 intercompany,
             rctl.sales_order_source salesOrderSource,
             rctl.sales_order salesOrder,
             rctl.sales_order_revision salesOrderRevision,
             rctl.sales_order_line salesOrderLine,
             TO_CHAR(rctl.sales_order_date,'YYYY-MM-DD') salesOrderDate,
             NULL alReasonMeaning,
             gcc.segment2,
             rctd.attribute1 worksheet
        FROM ra_customer_trx_lines_all rctl,
             ra_cust_trx_line_gl_dist_all rctd,
             gl_code_combinations gcc,
             ajc.ajc_bc_accounts aba
       WHERE rctl.customer_trx_id = pc_customer_trx_id -- 4673041
         AND rctl.customer_trx_line_id = rctd.customer_trx_line_id
         AND rctd.account_class = 'REV'
         AND rctd.code_combination_id = gcc.code_combination_id
         AND gcc.segment2 = aba.oracle_account (+)
         -- 20230103
         -- Se excluyen las líneas con unit selling price 0
         AND rctl.unit_selling_price != 0
         -- 20230103
         -- 20231211
         -- Se levantan las lineas que no tienen mas de una distribucion
         AND NOT EXISTS ( SELECT 'Y'
                            FROM ra_cust_trx_line_gl_dist_all rctd
                           WHERE rctd.customer_trx_line_id = rctl.customer_trx_line_id 
                             AND rctd.account_class = 'REV'
                        GROUP BY rctd.customer_trx_line_id
                          HAVING COUNT(1) > 1 )
       UNION 
      -- Lineas con mas de una distribucion
      SELECT rctl.customer_trx_id,
             rctl.customer_trx_line_id,
             rctl.line_number lineNo,
             SUBSTR(rctl.description,1,100) description,
             -- 20250926
             -- DECODE(pc_class,'CM',-1,1) * DECODE(pc_class,'INV',rctl.quantity_invoiced,rctl.quantity_credited) quantity,
             ABS(DECODE(pc_class,'INV',rctl.quantity_invoiced,rctl.quantity_credited)) quantity,
             -- 20250926
             -- Cambio con respecto al cursor de arriba
             -- 20250926 
             -- rctd.acctd_amount / DECODE('INV','CM',-1,1) * DECODE('INV','INV',rctl.quantity_invoiced,rctl.quantity_credited) unitSellingPrice,
             rctd.acctd_amount / DECODE(pc_class,'CM',-1,1) * DECODE(pc_class,'INV',rctl.quantity_invoiced,rctl.quantity_credited) unitSellingPrice,
             -- 20250926
             DECODE(pc_class,'CM',-1,1) * rctd.acctd_amount extendedAmount,
             DECODE(pc_class,'CM',-1,1) * rctd.acctd_amount accountedAmount,
             -- Cambio con respecto al cursor de arriba
             --
             aba.bc_account account,
             gcc.segment3 department,
             DECODE( AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT4'
                                                                         ,p_oracle_value   => gcc.segment4
                                                                         ,p_bc_dimension   => 'DIVISION'), NULL,gcc.segment4,'000') product,
             DECODE(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT5'
                                                                        ,p_oracle_value   => gcc.segment5
                                                                        ,p_bc_dimension   => 'OFFICE'), NULL,gcc.segment5,'000') destination,
             NVL(AJC_BC_ATIS_BATCH_INTERFACE_PK.get_dimension_value ( p_oracle_segment => 'SEGMENT5'
                                                                     ,p_oracle_value   => gcc.segment5
                                                                     ,p_bc_dimension   => 'OFFICE'),'000') office,  
             gcc.segment6 origin,
             gcc.segment7 intercompany,
             rctl.sales_order_source salesOrderSource,
             rctl.sales_order salesOrder,
             rctl.sales_order_revision salesOrderRevision,
             rctl.sales_order_line salesOrderLine,
             TO_CHAR(rctl.sales_order_date,'YYYY-MM-DD') salesOrderDate,
             NULL alReasonMeaning,
             gcc.segment2,
             rctd.attribute1 worksheet
        FROM ra_customer_trx_lines_all rctl,
             ra_cust_trx_line_gl_dist_all rctd,
             gl_code_combinations gcc,
             ajc.ajc_bc_accounts aba
       WHERE rctl.customer_trx_id = pc_customer_trx_id -- 4673041
         AND rctl.customer_trx_line_id = rctd.customer_trx_line_id
         AND rctd.account_class = 'REV'
         AND rctd.code_combination_id = gcc.code_combination_id
         AND gcc.segment2 = aba.oracle_account (+)
         -- 20230103
         -- Se excluyen las líneas con unit selling price 0
         AND rctl.unit_selling_price != 0
         -- 20230103
         -- 20231211
         -- Se levantan las lineas que tienen mas de una distribucion
         AND EXISTS ( SELECT 'Y'
                        FROM ra_cust_trx_line_gl_dist_all rctd
                       WHERE rctd.customer_trx_line_id = rctl.customer_trx_line_id 
                         AND rctd.account_class = 'REV'
                    GROUP BY rctd.customer_trx_line_id
                      HAVING COUNT(1) > 1 )
    ORDER BY 3; -- line_number

    v_error_message         VARCHAR2(2000);
    v_status                VARCHAR2(1);
    e_cust_exception        EXCEPTION;

    v_body_header           VARCHAR2(3000);
    v_body_line             VARCHAR2(3000);

    v_customer_trx_id       NUMBER;

    v_applies_to_doc_no     ra_customer_trx_all.trx_number%TYPE;
    v_applies_to_doc_type   ra_cust_trx_types_all.type%TYPE;

    -- 20231211
    v_lineNo                NUMBER;
    -- 20231211

  BEGIN

    print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.insert_trx (+)');

    -- Se actualizan las cabeceras a procesar con el request_id
    UPDATE ra_customer_trx_all rct
       SET attribute7 = gv_request_id
     WHERE rct.customer_trx_id IN ( SELECT rct.customer_trx_id
                                      FROM ra_customer_trx_all rct,
                                           ra_batch_sources_all rbs,
                                           ra_cust_trx_types_all ctt,
                                           ar_customers rc,
                                           hz_cust_site_uses_all site_uses,
                                           hz_cust_acct_sites_all acct_sites,
                                           hz_party_sites party_sites,
                                           hz_locations hl,
                                           ra_terms_tl pt,
                                           ar_payment_schedules_all aps
                                     WHERE rct.batch_source_id = rbs.batch_source_id
                                       -- 20230202
                                       -- AND rbs.name = 'ATIS-INC-IMPORT'
                                       AND rct.interface_header_context = 'ATIS'
                                       -- 20230202
                                       AND rct.attribute7 IS NULL
                                       AND rct.complete_flag = 'Y'
                                       --
                                       AND TRUNC(rct.creation_date) >= TO_DATE(p_date_from,'YYYY/MM/DD HH24:MI:SS')
                                       -- Agregado 20221212
                                       -- 20230703
                                       -- AND TRUNC(rct.trx_date) >= TO_DATE('2022/11/27','YYYY/MM/DD') 
                                       AND aps.gl_date >= TO_DATE('2023/07/02','YYYY/MM/DD') 
                                       -- No haria falta excluir logistics porque no trabaja con ATIS
                                       AND rct.org_id != 5387 -- Logistics
                                       -- 20230703
                                       -- Agregado 20221212
                                       -- AND rct.trx_number IN ('1514034','1516962') -- 20230116
                                       AND rct.cust_trx_type_id = ctt.cust_trx_type_id
                                       AND rct.bill_to_customer_id = rc.customer_id
                                       AND rct.bill_to_site_use_id = site_uses.site_use_id
                                       AND site_uses.cust_acct_site_id = acct_sites.cust_acct_site_id
                                       AND acct_sites.party_site_id = party_sites.party_site_id
                                       AND party_sites.location_id = hl.location_id
                                       AND rct.term_id = pt.term_id (+)
                                       AND rct.customer_trx_id = aps.customer_trx_id (+)
                                       -- 20230103
                                       -- Tiene lineas sin unit selling price en 0
                                       -- Si el comprobante solo tiene una linea y la misma tiene unit selling price 0,
                                       -- no marca la cabecera para procesar
                                       AND EXISTS ( SELECT 1
                                                      FROM ra_customer_trx_lines_all rctl, 
                                                           ra_cust_trx_line_gl_dist_all rctd 
                                                     WHERE rctl.customer_trx_id = rct.customer_trx_id
                                                       AND rctl.customer_trx_line_id = rctd.customer_trx_line_id
                                                       AND rctd.account_class = 'REV'
                                                       AND rctl.unit_selling_price != 0 ) 
                                       -- 20230103
                                       );

    print_log ('Se hace update de los registros a procesar.');
    print_log ('Registros actualizados: ' || SQL%ROWCOUNT );

    -- Se levantan todos los registros actualizados y se ejecuta sentencia de delete de inbound antes de procesarlos, por si
    -- un request anterior los envió y al fallar no pudo borrarlos, porque falla la llamada al ws de borrado
    print_log ( ' ' );
    print_log ( 'Inicio borrado - Se borran de la tabla inbound los registros (cab
