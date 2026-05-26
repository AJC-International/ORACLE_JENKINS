CREATE OR REPLACE PACKAGE BODY ajc_bc_atis_ar_interface_pk IS

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

    print_log ( 'Inicio borrado - Se borran de la tabla inbound los registros (cabeceras y lineas) a procesar.' );



    FOR ctd IN c_customer_trx_del LOOP



      print_log ( '- customer_trx_id: ' || ctd.customer_trx_id );      



      ajc_bc_ws_utils_pkg.get_bc_company_id_f ( p_org_id => NULL,

                                                p_company_number => ctd.bc_company_number,

                                                p_set_of_books_id => NULL,

                                                p_bc_company_id => v_bc_company_id,

                                                p_status => v_get_company_status );



      print_log ( 'v_bc_company_id: ' || v_bc_company_id );      



      -- Se borra cabecera y lineas de las tablas inbound

      delete_inbound_records ( p_bc_environment => p_bc_environment,

                               p_company_id => v_bc_company_id,

                               p_customer_trx_id => ctd.customer_trx_id );



    END LOOP;



    print_log ( 'Fin borrado - Se borran de la tabla inbound los registros (cabeceras y lineas) a procesar.' );

    print_log ( ' ' );



    -- Se procesa lo marcado por el update

    FOR ccab IN c_cabeceras LOOP



      print_log ('Se procesa la transactionNo: ' || ccab.transactionNo);

      v_customer_trx_id := ccab.customer_trx_id;



      -- 20231211

      -- Se renumeran las lineas de las facturas que tienen alguna linea con mas de una distribucion

      IF ( ccab.several_distributions = 'Y' ) THEN



        v_lineNo := 0;



      END IF;

      -- 20231211



      FOR clin IN c_lineas ( ccab.customer_trx_id, ccab.class ) LOOP



        print_log ('Se procesa la linea: ' || clin.lineNo);



        IF clin.account IS NULL THEN



          v_error_message := 'No existe Cuenta BC para la Cuenta ' || clin.segment2;



        END IF;



        -- Se arma la linea

        APEX_JSON.initialize_clob_output;

        APEX_JSON.open_object;

        APEX_JSON.write('customerTrxID',clin.customer_trx_id,true);

        APEX_JSON.write('requestID',gv_request_id);



        -- 20221205 APEX_JSON.write('company',ccab.company);

        /*

        IF ( ajc_bc_account_dim_pkg.account_dim_required(clin.account,'COMPANY') = 'Y' ) THEN

          APEX_JSON.write('company',ccab.company,true);

        ELSE

          APEX_JSON.write('company','',TRUE);

        END IF;

        */

        APEX_JSON.write('company',ajc_bc_account_dim_pkg.account_dim_required(clin.account,'COMPANY',ccab.company),TRUE);

        --



        APEX_JSON.write('transactionNo',ccab.transactionNo);



        -- 20231211

        -- Si es una factura con una distribucion por linea, se deja la numeracion original de las lineas

        IF ( ccab.several_distributions = 'N' ) THEN

        -- 20231211

          v_lineNo := clin.lineNo;

        -- 20231211

        ELSE

        -- Si es una factura que tiene alguna linea con mas de una distribucion, se renumeran todas las lineas desde 1 en adelante



          v_lineNo := v_lineNo + 1;



        END IF;



        -- APEX_JSON.write('lineNo',clin.lineNo);

        APEX_JSON.write('lineNo',v_lineNo);

        -- 20231211



        APEX_JSON.write('description',clin.description);

        APEX_JSON.write('quantity',clin.quantity);

        APEX_JSON.write('unitSellingPrice',clin.unitSellingPrice);

        APEX_JSON.write('extendedAmount',clin.extendedAmount);

        APEX_JSON.write('accountedAmount',clin.accountedAmount,true);

        APEX_JSON.write('account',clin.account);



        print_log('account: ' || clin.account);



        -- 20221205 APEX_JSON.write('department',clin.department);

        /*

        IF ( ajc_bc_account_dim_pkg.account_dim_required(clin.account,'DEPARTMENT') = 'Y' ) THEN

          APEX_JSON.write('department',clin.department,true);

        ELSE

          APEX_JSON.write('department','',TRUE);

        END IF;

        */

        APEX_JSON.write('department',ajc_bc_account_dim_pkg.account_dim_required(clin.account,'DEPARTMENT',clin.department),TRUE);

        --



        -- 20221205 APEX_JSON.write('product',clin.product);

        /*

        IF ( ajc_bc_account_dim_pkg.account_dim_required(clin.account,'PRODUCT') = 'Y' ) THEN

          APEX_JSON.write('product',clin.product,true);

        ELSE

          APEX_JSON.write('product','',TRUE);

        END IF;

        */

        APEX_JSON.write('product',ajc_bc_account_dim_pkg.account_dim_required(clin.account,'PRODUCT',clin.product),TRUE);



        -- 20221205 APEX_JSON.write('destination',clin.destination);

        /*

        IF ( ajc_bc_account_dim_pkg.account_dim_required(clin.account,'DESTINATION') = 'Y' ) THEN

          APEX_JSON.write('destination',clin.destination,true);

        ELSE

          APEX_JSON.write('destination','',TRUE);

        END IF;

        */

        APEX_JSON.write('destination',ajc_bc_account_dim_pkg.account_dim_required(clin.account,'DESTINATION',clin.destination),TRUE);



        -- 20221205 APEX_JSON.write('origin',clin.origin);

        /*

        IF ( ajc_bc_account_dim_pkg.account_dim_required(clin.account,'ORIGIN') = 'Y' ) THEN

          APEX_JSON.write('origin',clin.origin,true);

        ELSE

          APEX_JSON.write('origin','',TRUE);

        END IF;

        */

        APEX_JSON.write('origin',ajc_bc_account_dim_pkg.account_dim_required(clin.account,'ORIGIN',clin.origin),TRUE);



        -- 20221205 APEX_JSON.write('office',clin.office);

        /*

        IF ( ajc_bc_account_dim_pkg.account_dim_required(clin.account,'OFFICE') = 'Y' ) THEN

          APEX_JSON.write('office',clin.office,true);

        ELSE

          APEX_JSON.write('office','',TRUE);

        END IF;

        */

        APEX_JSON.write('office',ajc_bc_account_dim_pkg.account_dim_required(clin.account,'OFFICE',clin.office),TRUE);

        --



        -- 20221205 NO SE DEBE ENVIAR MAS APEX_JSON.write('intercompany',clin.intercompany);

        APEX_JSON.write('salesOrderSource',clin.salesOrderSource,true);

        APEX_JSON.write('salesOrder',clin.salesOrder,true);

        APEX_JSON.write('salesOrderRevision',clin.salesOrderRevision,true);

        APEX_JSON.write('salesOrderLine',clin.salesOrderLine,true);

        APEX_JSON.write('salesOrderDate',clin.salesOrderDate,true);

        APEX_JSON.write('alReasonMeaning',clin.alReasonMeaning,true);



        -- 20221205 APEX_JSON.write('WorksheetNo',clin.worksheet,true);

        /*

        IF ( ajc_bc_account_dim_pkg.account_dim_required(clin.account,'WORKSHEET') = 'Y' ) THEN

          APEX_JSON.write('WorksheetNo',clin.worksheet,true);

        ELSE

          APEX_JSON.write('WorksheetNo','',TRUE);

        END IF;

        */

        APEX_JSON.write('WorksheetNo',ajc_bc_account_dim_pkg.account_dim_required(clin.account,'WORKSHEET',clin.worksheet),TRUE);

        --



        APEX_JSON.close_object;



        v_body_line := APEX_JSON.get_clob_output;



        insert_lines_table ( p_status_code => v_status

                            ,p_error_message => v_error_message

                            ,p_customer_trx_id => ccab.customer_trx_id

                            ,p_customer_trx_line_id => clin.customer_trx_line_id

                            ,p_json_data => v_body_line

                            -- 20231211 ,p_line_number => clin.lineNo

                            ,p_line_number => v_lineNo

                            -- 20231211

                            ,p_description => clin.description

                            ,p_quantity => clin.quantity

                            ,p_unit_selling_price => clin.unitSellingPrice

                            ,p_extended_amount => clin.extendedAmount );



        print_log('v_body_line: ' || v_body_line);



        apex_json.free_output;



        IF v_status != 'S' THEN



          IF v_status = 'W' THEN



            RAISE e_cust_exception;



          ELSE



            RAISE e_cust_exception;



          END IF;



        END IF;



      END LOOP;



      -- Si es CM, debo verificar si vinieron datos de la aplicacion contra la factura en la interface

      IF ( ccab.class = 'CM' ) THEN



        v_applies_to_doc_no := NULL;

        v_applies_to_doc_type := NULL;



        BEGIN



          print_log('Es CM, se obtienen los datos del comprobante al que aplica.');



          SELECT inv.trx_number, 

                 DECODE(ctt.type,'INV','Invoice',ctt.type)

            INTO v_applies_to_doc_no,

                 v_applies_to_doc_type

            FROM ra_customer_trx_all cm,

                 ar_receivable_applications_all ara,

                 ra_customer_trx_all inv,

                 ra_cust_trx_types_all ctt

           WHERE ara.customer_trx_id = ccab.customer_trx_id

             AND ara.customer_trx_id = cm.customer_trx_id

             AND ara.applied_customer_trx_id = inv.customer_trx_id

             AND ara.display = 'Y'

             AND inv.cust_trx_type_id = ctt.cust_trx_type_id

             AND EXISTS ( SELECT 1 

                            FROM ajc_ra_interface_lines_all

                           WHERE interface_line_attribute2 = cm.trx_number -- CM

                             AND reference_line_attribute2 = inv.trx_number ); -- INV a la que aplica



          print_log('v_applies_to_doc_type: ' || v_applies_to_doc_type);

          print_log('v_applies_to_doc_no: ' || v_applies_to_doc_no);



        EXCEPTION

          WHEN OTHERS THEN

            v_applies_to_doc_no := NULL;

            v_applies_to_doc_type := NULL;



        END;



      END IF;



      APEX_JSON.initialize_clob_output;

      APEX_JSON.open_object;



      -- Se arma la cabecera

      APEX_JSON.write('customerTrxID',ccab.customer_trx_id,true);



      -- 20221209 APEX_JSON.write('company',ccab.company);

      APEX_JSON.write('company',ajc_bc_account_dim_pkg.account_dim_required(ccab.account,'COMPANY',ccab.company),TRUE);



      APEX_JSON.write('transactionNo',ccab.transactionNo);

      APEX_JSON.write('transactionDate',ccab.transactionDate);

      APEX_JSON.write('class',ccab.class);

      APEX_JSON.write('termName',ccab.termName,true);

      APEX_JSON.write('termDueDate',ccab.termDueDate);

      APEX_JSON.write('glDate',ccab.glDate);

      APEX_JSON.write('invoiceCurrencyCode',ccab.invoiceCurrencyCode);

      APEX_JSON.write('exchangeDate',ccab.exchangeDate,true);

      APEX_JSON.write('exchangeRate',ccab.exchangeRate,true);

      APEX_JSON.write('exchangeRateType',ccab.exchangeRateType,true);

      APEX_JSON.write('purchaseOrder',ccab.purchaseOrder,true);

      APEX_JSON.write('amount',ccab.amount);

      APEX_JSON.write('accountedAmount',ccab.accountedAmount,true);

      -- 20220712

      APEX_JSON.write('account',ccab.account,true);



      -- APEX_JSON.write('department',ccab.department,true);

      APEX_JSON.write('department',ajc_bc_account_dim_pkg.account_dim_required(ccab.account,'DEPARTMENT',ccab.department),TRUE);



      -- APEX_JSON.write('product',ccab.product,true);

      APEX_JSON.write('product',ajc_bc_account_dim_pkg.account_dim_required(ccab.account,'PRODUCT',ccab.product),TRUE);



      -- APEX_JSON.write('destination',ccab.destination,true);

      APEX_JSON.write('destination',ajc_bc_account_dim_pkg.account_dim_required(ccab.account,'DESTINATION',ccab.destination),TRUE);



      -- APEX_JSON.write('origin',ccab.origin,true);

      APEX_JSON.write('origin',ajc_bc_account_dim_pkg.account_dim_required(ccab.account,'ORIGIN',ccab.origin),TRUE);



      -- APEX_JSON.write('office',ccab.office,true);

      APEX_JSON.write('office',ajc_bc_account_dim_pkg.account_dim_required(ccab.account,'OFFICE',ccab.office),TRUE);



      -- 20221205 NO SE DEBE ENVIAR MAS APEX_JSON.write('intercompany',ccab.intercompany,true);

      -- 20220712

      APEX_JSON.write('billToCustomerName',ccab.billToCustomerName);

      APEX_JSON.write('billToCustomerNo',ccab.billToCustomerNo);

      APEX_JSON.write('billToAddress1',ccab.billToAddress1,true);

      APEX_JSON.write('billToAddress2',ccab.billToAddress2,true);

      APEX_JSON.write('billToAddress3',ccab.billToAddress3,true);

      APEX_JSON.write('requestID',gv_request_id);

      APEX_JSON.write('WorksheetNo',ccab.worksheet,true);

      APEX_JSON.write('AppliestoDocType',v_applies_to_doc_type,true);

      APEX_JSON.write('AppliestoDocNo',v_applies_to_doc_no,true);

      APEX_JSON.write('overrideFlag',ccab.override_flag,true); -- Agregado 20220622

      APEX_JSON.write('commentsAJC_INE',ccab.comments,true); -- 20220809



      APEX_JSON.close_object;



      v_body_header := APEX_JSON.get_clob_output;



      insert_headers_table ( p_status_code     => v_status

                            ,p_error_message   => v_error_message

                            ,p_customer_trx_id => ccab.customer_trx_id

                            ,p_json_data       => v_body_header

                            ,p_trx_number      => ccab.transactionNo

                            ,p_trx_date        => ccab.transactionDate

                            ,p_class           => ccab.class

                            ,p_currency_code   => ccab.invoiceCurrencyCode

                            ,p_amount          => ccab.amount

                            ,p_customer_name   => ccab.billToCustomerName

                            ,p_customer_number => ccab.billToCustomerNo

                            ,p_org_id          => ccab.org_id

                            ,p_company         => ccab.company );



      print_log('v_body_header: ' || v_body_header);



      APEX_JSON.free_output;



      IF v_status != 'S' THEN



        IF v_status = 'W' THEN



          RAISE e_cust_exception;



        ELSE



          RAISE e_cust_exception;



        END IF;



      END IF;



    END LOOP;



    print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.insert_trx (-)');



  EXCEPTION

    WHEN e_cust_exception THEN

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.insert_trx (!)');

    WHEN others THEN

        print_log ('v_customer_trx_id: ' || v_customer_trx_id);

        v_error_message := 'Error no atrapado al crear listado JSON, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.insert_trx (!)');



  END insert_trx;



  /*=========================================================================+

  |                                                                          |

  | Private Procedure                                                        |

  |    call_ws                                                               |

  |                                                                          |

  | Description                                                              |

  |    Llamo al Web Service que inserta en tablas de staging de              |

  |    Sales Invoices en BC                                                  |

  |                                                                          |

  | Parameters                                                               |

  |    p_message                   IN     NUMBER    Mensaje.                 |

  |                                                                          |

  +=========================================================================*/

  PROCEDURE call_ws ( p_bc_environment   IN       VARCHAR2 

                     ,p_status           OUT      VARCHAR2

                     ,p_error_message    OUT      VARCHAR2

                     ,p_trx_count        IN OUT   NUMBER

                     ,p_lines_count      IN OUT   NUMBER ) IS



    v_company_id           VARCHAR2(100);

    v_status               VARCHAR2(1);

    v_error_message        VARCHAR2(2000);

    e_cust_exception       EXCEPTION;



    v_url_header           VARCHAR2(2000);      

    -- 20230414 v_api_header           VARCHAR2(200) := 'inboundSalesHeaderINE';

    v_api_header           VARCHAR2(200);



    v_body_header          VARCHAR2(2000);

    v_clob_result_header   CLOB;



    v_url_line             VARCHAR2(2000);

    -- 20230414 v_api_line             VARCHAR2(200) := 'inboundSalesLineINE';

    v_api_line             VARCHAR2(200);

    v_body_line            VARCHAR2(2000);

    v_clob_result_line     CLOB;



    v_linea_con_error      VARCHAR2(1);



    CURSOR c_cabeceras IS

    SELECT *

      FROM AJC_BC_ATIS_AR_HEADERS

     WHERE request_id = gv_request_id

       AND status = 'NEW';



    CURSOR c_lineas ( p_customer_trx_id   IN   NUMBER ) IS

    SELECT *

      FROM AJC_BC_ATIS_AR_LINES

     WHERE request_id = gv_request_id

       AND customer_trx_id = p_customer_trx_id

       AND status = 'NEW';



  BEGIN



    print_log (' ');

    print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.call_ws (+)');



    v_api_header := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'SALES INVOICES',

                                                    p_subentity => 'HEADERS',

                                                    p_method => 'GET' );

    print_log ('v_api_header: ' || v_api_header);



    v_api_line := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'SALES INVOICES',

                                                    p_subentity => 'LINES',

                                                    p_method => 'GET' );

    print_log ('v_api_line: ' || v_api_line);



    FOR ccab IN c_cabeceras LOOP



      print_log ('customer_trx_id: ' || ccab.customer_trx_id);

      print_log ('trx_number: ' || ccab.trx_number);



      v_linea_con_error := 'N';



      -- Se obtiene el v_company_id

      ajc_bc_ws_utils_pkg.get_bc_company_id_f ( p_org_id => NULL,

                                                p_company_number => ccab.company,

                                                p_set_of_books_id  => NULL,

                                                p_bc_company_id => v_company_id,

                                                p_status => v_status );



      print_log('v_company_id: ' || v_company_id);



      v_url_header := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, v_company_id ) || v_api_header;

      print_log('v_url_header: ' || v_url_header);



      v_url_line := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, v_company_id ) || v_api_line;

      print_log('v_url_line: ' || v_url_line);



      FOR clin IN c_lineas ( ccab.customer_trx_id ) LOOP



        print_log ('customer_trx_line_id: ' || clin.customer_trx_line_id);



        IF ( v_linea_con_error = 'N' ) THEN



          -- 20251204 REINTENTO

          gv_retry := 'N';



          BEGIN

          -- 20251204 REINTENTO



            v_clob_result_line := ajc_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url_line,

                                                                            p_request_header_name1 => 'Content-Type',

                                                                            p_request_header_value1 => 'application/json',

                                                                            p_request_header_name2 => NULL,

                                                                            p_request_header_value2 => NULL, 

                                                                            p_http_method => 'POST',

                                                                            p_body => clin.json_data );  



            -- 20251204 REINTENTO

            IF ( UPPER(v_clob_result_line) LIKE UPPER('%502 Bad Gateway%') ) THEN



              print_log('502 Bad Gateway'); 

              gv_retry := 'Y';



            END IF;



          EXCEPTION

            WHEN OTHERS THEN

              print_log('Error calling ajc_bc_ws_utils_pkg.patch_post_bc_row_f: ' || SQLCODE || '|' || SQLERRM ); 

              gv_retry := 'Y';



          END;



          IF ( gv_retry = 'Y' ) THEN



            print_log( 'Connection error detected. Retrying in ' || gv_retry_in_seconds || ' seconds.' );

            DBMS_LOCK.sleep(gv_retry_in_seconds);



            v_clob_result_line := ajc_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url_line,

                                                                            p_request_header_name1 => 'Content-Type',

                                                                            p_request_header_value1 => 'application/json',

                                                                            p_request_header_name2 => NULL,

                                                                            p_request_header_value2 => NULL, 

                                                                            p_http_method => 'POST',

                                                                            p_body => clin.json_data );



          END IF;

          -- 20251204 REINTENTO



          print_log('v_clob_result_line: ' || v_clob_result_line);



          IF ( INSTR(v_clob_result_line,'error') != 0 ) THEN



            print_log('Error al enviar la línea del comprobante.');



            v_error_message := 'Se produjo un error al enviar la línea: ' ||

                                SUBSTR(v_clob_result_line,INSTR(v_clob_result_line,'message') + 10);



            print_log(v_error_message);



            UPDATE AJC_BC_ATIS_AR_LINES

               SET status = 'ERROR',

                   error_message = v_error_message,

                   json_data_response = v_clob_result_line

             WHERE customer_trx_id = ccab.customer_trx_id

               AND request_id = gv_request_id

               AND customer_trx_line_id = clin.customer_trx_line_id;



            v_linea_con_error := 'Y';



          ELSE



            UPDATE AJC_BC_ATIS_AR_LINES

               SET status = 'SENT',

                   json_data_response = v_clob_result_line

             WHERE customer_trx_id = ccab.customer_trx_id

               AND request_id = gv_request_id

               AND customer_trx_line_id = clin.customer_trx_line_id;



            p_lines_count := NVL(p_lines_count,1) + 1;



            print_log('La línea se envió correctamente.');



          END IF;



        END IF;



      END LOOP;



      -- Si ninguna linea del comprobante falló, se envía la cabecera

      IF ( v_linea_con_error = 'N' ) THEN



        -- 20251204 REINTENTO

        gv_retry := 'N';



        BEGIN

        -- 20251204 REINTENTO



          v_clob_result_header := ajc_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url_header,

                                                                            p_request_header_name1 => 'Content-Type',

                                                                            p_request_header_value1 => 'application/json',

                                                                            p_request_header_name2 => NULL,

                                                                            p_request_header_value2 => NULL, 

                                                                            p_http_method => 'POST',

                                                                            p_body => ccab.json_data );  



          -- 20251204 REINTENTO

          IF ( UPPER(v_clob_result_header) LIKE UPPER('%502 Bad Gateway%') ) THEN



            print_log('502 Bad Gateway'); 

            gv_retry := 'Y';



          END IF;



        EXCEPTION

          WHEN OTHERS THEN

            print_log('Error calling ajc_bc_ws_utils_pkg.patch_post_bc_row_f: ' || SQLCODE || '|' || SQLERRM ); 

            gv_retry := 'Y';



        END;



        IF ( gv_retry = 'Y' ) THEN



          print_log( 'Connection error detected. Retrying in ' || gv_retry_in_seconds || ' seconds.' );

          DBMS_LOCK.sleep(gv_retry_in_seconds);



          v_clob_result_header := ajc_bc_ws_utils_pkg.patch_post_bc_row_f ( p_url => v_url_header,

                                                                            p_request_header_name1 => 'Content-Type',

                                                                            p_request_header_value1 => 'application/json',

                                                                            p_request_header_name2 => NULL,

                                                                            p_request_header_value2 => NULL, 

                                                                            p_http_method => 'POST',

                                                                            p_body => ccab.json_data );  



        END IF;

        -- 20251204 REINTENTO



        print_log('v_clob_result_header: ' || v_clob_result_header);



        IF ( INSTR(v_clob_result_header,'error') != 0 ) THEN



          print_log('Error al enviar la cabecera del comprobante.');



          v_error_message := 'Se produjo un error al enviar la cabecera: ' ||

                              SUBSTR(v_clob_result_header,INSTR(v_clob_result_header,'message') + 10);



          print_log(v_error_message);



          UPDATE AJC_BC_ATIS_AR_HEADERS

             SET status = 'ERROR',

                 error_message = v_error_message,

                 json_data_response = v_clob_result_header

           WHERE request_id = gv_request_id

             AND customer_trx_id = ccab.customer_trx_id;



        ELSE



          UPDATE AJC_BC_ATIS_AR_HEADERS

             SET status = 'SENT',

                 json_data_response = v_clob_result_header

           WHERE request_id = gv_request_id

             AND customer_trx_id = ccab.customer_trx_id;



          print_log('El comprobante se envió correctamente.');



        END IF;



        p_trx_count := NVL(p_trx_count,0) + 1;



      ELSE



        UPDATE AJC_BC_ATIS_AR_HEADERS

           SET status = 'ERROR',

               error_message = 'Se produjo un error en alguna línea del comprobante.'

         WHERE request_id = gv_request_id

           AND customer_trx_id = ccab.customer_trx_id;



        -- Se desmarca el comprobante para que pueda volver a ser procesado

        UPDATE ra_customer_trx_all

           SET attribute7 = NULL -- AJC_BC_REQUEST_ID | Se utiliza para marcar los comprobantes enviados.

         WHERE customer_trx_id = ccab.customer_trx_id;



      END IF;



    END LOOP;



    print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.call_ws (-)');   



  EXCEPTION

    WHEN e_cust_exception THEN

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.call_ws (!)');



    WHEN others THEN

        v_error_message := 'Error no atrapado al Web Service General Journal Inbounds, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.call_ws (!)');



  END call_ws;



  /*=========================================================================+

  |                                                                          |

  | Private Procedure                                                        |

  |    call_job                                                              |

  |                                                                          |

  | Description                                                              |

  |    Llamo al Web Service que ejecuta Job que procesa tablas de            |

  |    Sales Invoices                                                        |

  |                                                                          |

  | Parameters                                                               |

  |    p_message                   IN     NUMBER    Mensaje.                 |

  |                                                                          |

  +=========================================================================*/

  PROCEDURE call_job ( p_bc_environment   IN   VARCHAR2

                      ,p_status          OUT   VARCHAR2

                      ,p_error_message   OUT   VARCHAR2 ) IS



    CURSOR c_companies IS

    SELECT DISTINCT abcc.bc_company_id company_id,

           abch.org_id

      FROM ajc_bc_atis_ar_headers abch,

           AJC_BC_COMPANIES abcc

     WHERE abch.status = 'SENT'

       AND abch.request_id = gv_request_id

       AND abch.company = abcc.oracle_company_number;



    v_job_object_id     NUMBER;

    v_status            VARCHAR2(20);

    v_error_message     VARCHAR2(2000);

    v_clob_result_job   CLOB;



  BEGIN



    print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.call_job (+)');



    FOR cc IN c_companies LOOP



      print_log ( 'company_id: ' || cc.company_id );



      v_job_object_id := ajc_bc_ws_utils_pkg.get_object_id_f ( 'SALES INVOICES' );



      /* 20230908

      v_clob_result_job := ajc_bc_ws_utils_pkg.run_job_queue_token_v2_f ( p_environment => p_bc_environment

                                                                         ,p_company_id => cc.company_id

                                                                         ,p_object_id => v_job_object_id

                                                                         ,p_seconds_to_wait => gv_seconds_to_wait );

      */

      v_clob_result_job := ajc_bc_ws_utils_pkg.run_job_queue_f ( p_environment => p_bc_environment

                                                                ,p_company_id => cc.company_id

                                                                ,p_object_id => v_job_object_id

                                                                ,p_seconds_to_wait => gv_seconds_to_wait );

      -- 20230908



      IF ( INSTR(UPPER(v_clob_result_job),'ERROR') = 0 ) THEN



        print_log('Se ejecutó el job Sales Invoices con éxito.');

        v_status := 'SUCCESS';



      ELSE



        print_log('Se produjo un error al ejecutar el job Sales Invoices.');

        v_status := 'ERROR';



      END IF;



      -- Se inserta registro de control

      INSERT

        INTO AJC_BC_ATIS_AR_CONTROL

             ( request_id,

               org_id,

               status,

               job_response,

               creation_date )

      VALUES ( gv_request_id, 

               cc.org_id,

               v_status,

               v_clob_result_job,

               SYSDATE );



    END LOOP;



    p_status := 'S';



    print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.call_ws_job (-)');   



  EXCEPTION    

    WHEN others THEN

        v_error_message := 'Error no atrapado al llamar Web Service de Job, Error: '||sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.call_job (!)');



  END call_job;



  -- Inicio Agregado SBanchieri 20220317

  /*=========================================================================+

  |                                                                          |

  | Private Procedure                                                        |

  |    call_status                                                           |

  |                                                                          |

  | Description                                                              |

  |    Llamo al Web Service que retorna el status de los registros enviados  |

  |    y procesados por el job.                                              |

  |                                                                          |

  | Parameters                                                               |

  |    p_message                   IN     NUMBER    Mensaje.                 |

  |                                                                          |

  +=========================================================================*/

  PROCEDURE call_status ( p_bc_environment   IN   VARCHAR2

                         ,p_status          OUT   VARCHAR2

                         ,p_error_message   OUT   VARCHAR2 ) IS



    CURSOR c_companies IS

    SELECT DISTINCT abcc.bc_company_id company_id,

           abch.org_id

      FROM ajc_bc_atis_ar_headers abch,

           AJC_BC_COMPANIES abcc

     WHERE abch.status = 'SENT'

       AND abch.request_id = gv_request_id

       AND abch.company = abcc.oracle_company_number;



    v_status               VARCHAR2(1);

    v_error_message        VARCHAR2(2000);

    e_cust_exception       EXCEPTION;



    -- 20230414 v_api_status           VARCHAR2(200) := 'salesIntegrationStatus';

    v_api_status           VARCHAR2(200);

    v_get_url              VARCHAR2(2000);

    v_clob_result_status   CLOB;



    -- 20230414 v_api_delete_header    VARCHAR2(200) := 'inboundSalesHeaderINE';

    -- 20230511 v_api_delete_header    VARCHAR2(200);

    -- 20230414 v_api_delete_lines     VARCHAR2(200) := 'inboundSalesLineINE';

    -- 20230511 v_api_delete_lines     VARCHAR2(200);

    -- 20230511 v_header_delete_url    VARCHAR2(2000);

    -- 20230511 v_lines_delete_url     VARCHAR2(2000);

    v_header_delete_clob   CLOB;

    v_lines_delete_clob    CLOB;



    CURSOR c_status ( p_clob_result_status   IN   CLOB ) IS

    SELECT customerTrxID,

           company,

           transactionNo,

           transactionDate,

           glDate,

           purchaseOrder,

           amount,

           status,

           statusRemarks,

           requestID

    FROM json_table( p_clob_result_status,

                     '$.value[*]' COLUMNS ( customerTrxID     VARCHAR2(4000)  path '$.customerTrxID',

                                            company           VARCHAR2(4000)  path '$.company',

                                            transactionNo     VARCHAR2(4000)  path '$.transactionNo',

                                            transactionDate   VARCHAR2(4000)  path '$.transactionDate',

                                            glDate            VARCHAR2(4000)  path '$.glDate',

                                            purchaseOrder     VARCHAR2(4000)  path '$.purchaseOrder', 

                                            amount            VARCHAR2(4000)  path '$.amount',

                                            status            VARCHAR2(4000)  path '$.status',

                                            statusRemarks     VARCHAR2(4000)  path '$.statusRemarks',

                                            requestID         VARCHAR2(4000)  path '$.requestID' ) );



    v_cant_sin_procesar   NUMBER;

    v_stime               NUMBER;

    v_etime               NUMBER;



  BEGIN



    print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.call_status (+)');



    v_api_status := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'SALES INVOICES',

                                                    p_subentity => 'STATUS',

                                                    p_method => 'GET' );

    print_log ( 'v_api_status: ' || v_api_status );



    /* 20230511 

    v_api_delete_header := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'SALES INVOICES',

                                                           p_subentity => 'HEADERS',

                                                           p_method => 'DELETE' );

    print_log ( 'v_api_delete_header: ' || v_api_delete_header );



    v_api_delete_lines := ajc_bc_ws_utils_pkg.get_api_f ( p_entity => 'SALES INVOICES',

                                                           p_subentity => 'LINES',

                                                           p_method => 'DELETE' );

    print_log ( 'v_api_delete_lines: ' || v_api_delete_lines ); 

    */



    FOR cc IN c_companies LOOP



      v_get_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, cc.company_id ) || v_api_status

                   || '?$filter=requestID eq ' || TO_CHAR(gv_request_id)

                   ; 



      print_log ( 'v_get_url: ' || v_get_url );



      v_cant_sin_procesar := -1;



      -- seteo tiempo de inicio

      SELECT TO_NUMBER(((TO_CHAR(SYSDATE, 'J') - 1 ) * 86400) + TO_CHAR(SYSDATE, 'SSSSS'))

        INTO v_stime

        FROM DUAL;



      WHILE v_cant_sin_procesar <> 0 LOOP



        BEGIN



          v_clob_result_status := ajc_bc_ws_utils_pkg.get_bc_clob_result_f ( p_url => v_get_url );



        EXCEPTION

          WHEN OTHERS THEN

            NULL;



        END;



        SELECT COUNT(*)

          INTO v_cant_sin_procesar

          FROM json_table( v_clob_result_status,

                           '$.value[*]' COLUMNS ( status VARCHAR2(4000) path '$.status',

                                                  requestID VARCHAR2(4000) path '$.requestID'))

         WHERE requestID = gv_request_id

           AND status NOT IN ('Error','Success');



        print_log ( 'Cantidad de registros sin procesar: ' || v_cant_sin_procesar );



        IF v_cant_sin_procesar <> 0 THEN



          SELECT TO_NUMBER(((TO_CHAR(SYSDATE, 'J') - 1 ) * 86400) + TO_CHAR(SYSDATE, 'SSSSS'))

            INTO v_etime

            FROM DUAL;



          print_log ( 'v_etime: ' || v_etime );



          IF ( (v_etime - v_stime ) >= 600 ) THEN



            print_log ( 'La espera del job demoró mas de 600 segundos. Se marcarán todos los registros como REJECTED.' );

            EXIT;



          END IF;



          print_log ( 'Espero 15 segundos' );  

          DBMS_LOCK.sleep(15);



        END IF;



      END LOOP;



      print_log ( 'Status: ' );

      print_log ( ' ' );



      FOR cs IN c_status ( v_clob_result_status ) LOOP



        IF ( cs.status != 'Success' ) THEN



          print_log ( 'customerTrxID: ' || cs.customerTrxID || 

                   ' | company: ' || cs.company || 

                   ' | transactionNo: ' || cs.transactionNo || 

                   ' | transactionDate: ' || cs.transactionDate || 

                   ' | glDate: ' || cs.glDate || 

                   ' | purchaseOrder: ' || cs.purchaseOrder || 

                   ' | amount: ' || cs.amount || 

                   ' | status: ' || cs.status || 

                   ' | statusRemarks: ' || cs.statusRemarks

                 );



          print_log ( ' ' );



          -- Se actualiza la tabla custom con el status REJECTED

          UPDATE AJC_BC_ATIS_AR_HEADERS

             SET status = 'REJECTED',

                 error_message = cs.statusRemarks

           WHERE request_id = gv_request_id

             AND customer_trx_id = cs.customerTrxID;



          -- Se actualiza el status de sus lineas   

          UPDATE AJC_BC_ATIS_AR_LINES

             SET status = 'REJECTED'

           WHERE request_id = gv_request_id

             AND customer_trx_id = cs.customerTrxID;



          -- Se desmarca el comprobante para que pueda volver a ser procesado

          UPDATE ra_customer_trx_all

             SET attribute7 = NULL -- AJC_BC_REQUEST_ID | Se utiliza para marcar los comprobantes enviados.

           WHERE customer_trx_id = cs.customerTrxID;



          -- Se borra cabecera y lineas de las tablas inbound

          delete_inbound_records ( p_bc_environment => p_bc_environment,

                                   p_company_id => cc.company_id,

                                   p_customer_trx_id => cs.customerTrxID );



          -- Se arma la URL para borrar lineas de la tabla staging

          /*

          v_lines_delete_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, cc.company_id ) || v_api_delete_lines

                                -- || '?$filter=requestID eq ' || gv_request_id

                                || '(' || cs.customerTrxID || ',0,0)' -- customerTrxID, requestID, lineNo

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

          v_header_delete_url := ajc_bc_ws_utils_pkg.get_base_inecta_url_f ( p_bc_environment, cc.company_id ) || v_api_delete_header

                                 -- || '?$filter=requestID eq ' || gv_request_id

                                 || '(' || cs.customerTrxID || ',0)' -- customerTrxID, requestID

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

          */



        ELSE



          -- Se actualiza la tabla custom con el status IMPORTED

          UPDATE AJC_BC_ATIS_AR_HEADERS

             SET status = 'SUCCESS'

           WHERE request_id = gv_request_id

             AND customer_trx_id = cs.customerTrxID;



          -- Se actualizan sus lineas   

          UPDATE AJC_BC_ATIS_AR_LINES

             SET status = 'SUCCESS'

           WHERE request_id = gv_request_id

             AND customer_trx_id = cs.customerTrxID;



          -- Se marca el comprobante como procesado ok

          UPDATE ra_customer_trx_all

             SET attribute7 = attribute7 || ' | PROCESSED' -- AJC_BC_REQUEST_ID | Se utiliza para marcar los comprobantes enviados.

           WHERE customer_trx_id = cs.customerTrxID;



        END IF;



      END LOOP;    



    END LOOP;



    p_status := 'S';



    print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.call_status (-)');   



  EXCEPTION

    WHEN e_cust_exception THEN

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.call_status (!)');



    WHEN others THEN

        v_error_message := 'Error no atrapado al llamar Web Service de Status, Error: ' || sqlerrm;

        p_status := 'E';

        p_error_message := v_error_message;

        print_log (p_error_message);

        print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.call_status (!)');



  END call_status;

  -- Fin Agregado SBanchieri 20220317



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

                           p_bc_environment   IN   VARCHAR2 ) IS



    v_email             VARCHAR2(2000);



    v_status          VARCHAR2(1);

    v_error_message   VARCHAR2(2000);

    e_cust_exception  EXCEPTION;

    v_trx_count       NUMBER := 0;

    v_lines_count     NUMBER := 0;



    v_request_id_excel   NUMBER;



  BEGIN 



    print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.main_process (+)');



    -- v_email := 'sbanchieri@gmail.com'; 

    v_email := ajc_bc_ws_utils_pkg.get_emails_f ( 'SALES INVOICES' );



    -- 20251204 REINTENTO

    gv_retry_in_seconds := ajc_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'POST_RETRY_IN_SECONDS' );

    print_log ( 'POST_RETRY_IN_SECONDS: ' || gv_retry_in_seconds );    

    -- 20251204 REINTENTO



    -- 20230228

    -- Se ejecuta el concurrente AJC BC Worksheets Interface

    ajc_bc_worksheets_pkg.caller_p ( p_bc_environment => p_bc_environment );

    -- 20230228



    print_log ('Date From: ' || p_date_from);



    -- Genero registros que seran enviados a BC, insertando en tabla del proceso y json por linea de asiento

    insert_trx ( p_status         => v_status,

                 p_error_message  => v_error_message,

                 p_date_from      => p_date_from,

                 p_bc_environment => p_bc_environment );



    IF v_status != 'S' THEN



      IF v_status = 'W' THEN



        retcode := 1;

        errbuf  := v_error_message;

        NULL;



      ELSE



        RAISE e_cust_exception;



      END IF;



    END IF;



    -- WS para enviar la info a BC ---------------------------------------------------------------------------------------------

    call_ws ( p_bc_environment => p_bc_environment

             ,p_status => v_status

             ,p_error_message => v_error_message

             ,p_trx_count => v_trx_count

             ,p_lines_count => v_lines_count );



    print_log ( 'v_trx_count: ' || v_trx_count );

    print_log ( 'v_lines_count: ' || v_lines_count );



    IF v_status != 'S' THEN



      IF v_status = 'W' THEN



        retcode := 1;

        errbuf  := v_error_message;



      ELSE



        RAISE e_cust_exception;



      END IF;



    END IF;



    -- Si se envió al menos un comprobante, se ejecuta el job

    IF ( v_trx_count > 0 ) THEN



      -- Se ejecuta el JOB -----------------------------------------------------------------------------------------------------

      call_job ( p_bc_environment => p_bc_environment

                ,p_status => v_status

                ,p_error_message => v_error_message );



      IF v_status != 'S' THEN



        IF v_status = 'W' THEN



          retcode := 1;

          errbuf  := v_error_message;



        ELSE



          RAISE e_cust_exception;



        END IF;



      END IF;



      -- Verifico el status de las lineas procesadas por el job ----------------------------------------------------------------

      call_status ( p_bc_environment => p_bc_environment

                   ,p_status => v_status

                   ,p_error_message => v_error_message );



      IF v_status != 'S' THEN



        IF v_status = 'W' THEN



          retcode := 1;

          errbuf  := v_error_message;



        ELSE



          RAISE e_cust_exception;



        END IF;



      END IF;



      -- EXCEL REPORT ------------------------------------------------------------------------------------------------------------

      v_request_id_excel := ajc_bc_ws_utils_pkg.print_excel_report ( p_request_id => gv_request_id,

                                                                     p_program => 'AJCBCSIIR', -- AJC BC Sales Invoices Interface Report

                                                                     p_template => 'AJCBCSIIR' );



      -- MAIL --------------------------------------------------------------------------------------------------------------------

      ajc_bc_ws_utils_pkg.send_unix_mail_attach ( p_mail => v_email,

                                                  p_report_request_id => v_request_id_excel ); 



    END IF;



    print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.main_process (-)');



    IF retcode IS NULL THEN



      retcode := 0;



    ELSE



      print_log (errbuf);



      IF NOT fnd_concurrent.set_completion_status('WARNING',errbuf) THEN



        print_log ('Error seteando estado de finalizacion');



      ELSE



        print_log ('Estado de finalizacion seteado');



      END IF; 



    END IF;



  EXCEPTION

    WHEN e_cust_exception THEN



      retcode := 2;

      errbuf  := v_error_message;

      print_log (v_error_message);

      RAISE_APPLICATION_ERROR(-20000,v_error_message);     

      print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.main_process (!)');

    WHEN others THEN



      errbuf  := 'Error al Ejecutar el Proceso: '||SQLERRM;

      retcode := 2;

      print_log (errbuf);

      RAISE_APPLICATION_ERROR(-20000,v_error_message);

      print_log ('AJC_BC_ATIS_AR_INTERFACE_PK.main_process (!)');



  END main_process;



END AJC_BC_ATIS_AR_INTERFACE_PK;
