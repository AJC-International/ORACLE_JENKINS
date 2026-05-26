PACKAGE BODY AJC_BC_FA_FIXED_ASSETS_PKG AS
  
  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line (fnd_file.log, p_message);

  END print_log;

  PROCEDURE print_output ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    fnd_file.put_line(fnd_file.output,p_message);

  END print_output;

  FUNCTION print_excel_report ( p_argument1            IN   VARCHAR2,
                                p_program_short_code   IN   VARCHAR2 ) RETURN NUMBER IS

    v_request_id        NUMBER;
    v_message           VARCHAR2(2000);
    v_error_message     VARCHAR2(2000);
    e_cust_exception    EXCEPTION;
    v_conc_phase        VARCHAR2 (50);
    v_conc_status       VARCHAR2 (50);
    v_conc_dev_phase    VARCHAR2 (50);
    v_conc_dev_status   VARCHAR2 (50);
    v_conc_message      VARCHAR2 (250);

    v_template_appl_name   xdo_templates_b.application_short_name%TYPE;
    v_template_code        xdo_templates_b.template_code%TYPE;
    v_template_language    xdo_templates_b.default_language%TYPE;
    v_template_territory   xdo_templates_b.default_territory%TYPE;
    v_output_format        VARCHAR2(10);
    v_status_code          VARCHAR2(1);

  BEGIN

     BEGIN

       SELECT application_short_name, 
              template_code, 
              default_language, 
              default_territory, 
              'EXCEL'
         INTO v_template_appl_name,
              v_template_code,
              v_template_language,
              v_template_territory,
              v_output_format
         FROM xdo_templates_b
        WHERE template_code = p_program_short_code;

    EXCEPTION
      WHEN OTHERS THEN
        v_error_message := 'Error al buscar los datos del template correspondiente al código: ' || p_program_short_code || ': '||sqlerrm;
        v_status_code := 'W';
        RAISE e_cust_exception;

    END;  

    IF NOT fnd_request.add_layout ( template_appl_name  => v_template_appl_name,
                                    template_code       => v_template_code,
                                    template_language   => v_template_language,
                                    template_territory  => v_template_territory,
                                    output_format       => v_output_format ) THEN

      v_error_message := 'Error al setear el Template Publisher';
      v_status_code := 'E';
      raise e_cust_exception;

    END IF; 

    IF NOT fnd_request.set_options('NO','YES',NULL,NULL) THEN

      v_message := fnd_message.get;
      v_error_message := 'Error ejecutando FND_REQUEST.SET_OPTIONS. ' || v_message || ' ' || sqlerrm;
      v_status_code := 'W';
      raise e_cust_exception;

    END IF;

    -- Submit Report
    v_request_id := fnd_request.submit_request ( 'XXAJC',
                                                 p_program_short_code,
                                                 argument1 => p_argument1 ) ;

    IF v_request_id = 0 THEN

      v_message := fnd_message.get;
      print_log('Error Ejecutando FND_REQUEST.SUBMIT_REQUEST. ' || p_program_short_code || '. Error: ' || v_message || ', ' || SQLERRM);
      RAISE e_cust_exception;

    END IF ;

    COMMIT;

    IF NOT fnd_concurrent.wait_for_request ( v_request_id,
                                             10,
                                             18000,
                                             v_conc_phase,
                                             v_conc_status,
                                             v_conc_dev_phase,
                                             v_conc_dev_status,
                                             v_conc_message) THEN

      v_message := fnd_message.get;
      print_log('Error Ejecutando FND_REQUEST.WAIT_FOR_REQUEST. ' || p_program_short_code || ' con nro. solicitud ' || 
                TO_CHAR (v_request_id) || '. Error: ' || v_message || ' ' || SQLERRM);
      RAISE e_cust_exception;

    END IF ;

    IF v_conc_dev_phase != 'COMPLETE' OR v_conc_dev_status != 'NORMAL' THEN

      v_error_message := fnd_message.get;
      print_log('Error en la ejecucion del concurrente ' || p_program_short_code || ' con nro. solicitud ' || 
                TO_CHAR (v_request_id) || '. Error: ' || v_error_message || ' ' || SQLERRM);
      RAISE e_cust_exception;

    END IF ; 

    RETURN v_request_id;

  END print_excel_report;

  FUNCTION get_deprn_reserve ( p_asset_id         IN   NUMBER,
                               p_book_type_code   IN   VARCHAR2,
                               p_period_name      IN   VARCHAR2,
                               p_cost             IN   NUMBER ) RETURN NUMBER IS

    v_period_counter       NUMBER;
    v_period_counter_lc    NUMBER;
    v_mig_anterior         NUMBER;
    v_fr_period_counter    NUMBER;
    v_calc_deprn_reserve   VARCHAR2(1) := 'N';
    v_deprn_reserve        NUMBER;

  BEGIN

    -- Se obtiene el period_counter del period_name
    SELECT period_counter
      INTO v_period_counter
      FROM fa_deprn_periods fdp
     WHERE fdp.book_type_code = p_book_type_code
       AND fdp.period_name = p_period_name;

    -- Se obtiene el periodo en el que se completo la vida del activo
    -- 20230703
    SELECT period_counter_life_complete
      INTO v_period_counter_lc
      FROM fa_books
     WHERE asset_id = p_asset_id
       AND book_type_code = p_book_type_code;

    -- Si se deprecio completamente antes del periodo del parametro, se devuelve el costo
    IF ( v_period_counter_lc IS NOT NULL AND
         v_period_counter_lc <= v_period_counter ) THEN

      RETURN p_cost;

    END IF;  
    -- 20230703

    -- Se obtiene el period_counter si el activo fue retirado
    BEGIN

      SELECT fdp.period_counter
        INTO v_fr_period_counter
        FROM fa_financial_inquiry_cost_v fic,
             fa_deprn_periods fdp
       WHERE fic.asset_id = p_asset_id
         AND fic.transaction_type = 'Full Retirement'
         AND fic.period_effective = fdp.period_name
         AND fdp.book_type_code = p_book_type_code;

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        -- No fue retirado
        v_fr_period_counter := 0;

    END;

    -- Si fue retirado y se retiro antes del periodo de corte, se retorna 0
    IF ( v_fr_period_counter != 0 AND
         v_fr_period_counter <= v_period_counter ) THEN

      v_deprn_reserve := 0;
      RETURN v_deprn_reserve;

    END IF;

    -- Se calcula el deprn reserve para los casos
    -- No fue retirado
    -- Fue retirado pero luego de la fecha de corte
    SELECT NVL(SUM(fid.deprn_amount),0)
      INTO v_deprn_reserve
      FROM fa_financial_inquiry_deprn_v fid,
           fa_deprn_periods fdp
     WHERE fid.asset_id = p_asset_id
       AND fid.book_type_code = p_book_type_code
       AND fid.period_entered = fdp.period_name
       AND fid.book_type_code = fdp.book_type_code
       AND fdp.period_counter <= ( SELECT fdp2.period_counter 
                                     FROM fa_deprn_periods fdp2 
                                    WHERE fdp2.period_name = p_period_name
                                      AND fdp2.book_type_code = fdp.book_type_code );

    -- 20230703
    -- Se agrega el calculo de la depreciación inicial migracion anterior
    SELECT NVL(SUM(ytd_deprn) ,0)
      INTO v_mig_anterior
      FROM fa_deprn_summary a
     WHERE asset_id = p_asset_id
       AND period_counter <= v_period_counter
       AND period_counter = ( SELECT MIN(period_counter) 
                                FROM fa_deprn_summary b 
                               WHERE b.asset_id = a.asset_id 
                                 AND deprn_amount = 0 );

    v_deprn_reserve := v_deprn_reserve + v_mig_anterior;
    -- 20230703

    RETURN v_deprn_reserve;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN -999999999999;

  END get_deprn_reserve;

  PROCEDURE main_p ( retcode               OUT   NUMBER,
                     errbuf                OUT   VARCHAR2,
                     p_book_type_code       IN   VARCHAR2,
                     p_delete_final_table   IN   VARCHAR2,
                     p_period_name          IN   VARCHAR2 ) IS

    CURSOR c_fa IS 
    SELECT fa.asset_id,
           fb.book_type_code,
           --
           fa.asset_number no,
           -- SUBSTR(fa.asset_number || '-' || fat.description,1,17) description,
           SUBSTR(fat.description,1,100) description,
           -- SUBSTR(fa.asset_number || '-' || UPPER(fat.description),1,17) search_description,
           SUBSTR(UPPER(fat.description),1,100) search_description,
           NULL description_2,
           'TANGIBLE' fa_class_code,
           fc.segment1 fa_subclass_code,
           NULL location_code,
           NULL fa_location_code,
           NULL global_dimension_1_code,
           NULL global_dimension_2_code,
           -- v.segment1 vendor_no,
           NULL vendor_no,          
           NULL main_asset_component,
           NULL component_of_main_asset,
           'false' budgeted_asset,
           NULL warranty_date,
           NULL responsible_employee,
           NULL serial_no,
           TO_CHAR(SYSDATE,'YYYY-MM-DD') last_date_modified,
           'false' blocked,
           NULL maintenance_vendor_no,
           'false' under_maintenance,
           NULL next_service_date,
           'false' inactive,
           NULL no_series,
           NULL fa_posting_group, -- POR EL MOMENTO SE DEJA VACIO Y SE VERA SI ES NECESARIO
           '{00000000-0000-0000-0000-000000000000}' image,
           NULL vehicle_license_plate,
           0 vehicle_year,
           NULL sat_federal_autotransport,
           NULL sat_trailer_type,
           NULL sct_permission_type,
           NULL sct_permission_number,
           NULL sat_classification_code,
           NULL uscg_no,
           NULL asset_tag,
           NULL year_of_manufacture,
           NULL vin_no,
           NULL engine_no
      FROM fa_additions_b fa, 
           fa_additions_tl fat,
           fa_books fb, 
           fa_categories_b fc
           -- ,fa_asset_invoices fai
           -- ,po_vendors v
           -- ,fa_asset_keywords ak
     WHERE fa.asset_id = fb.asset_id
       AND fb.date_ineffective IS NULL
       AND fa.asset_id = fat.asset_id
       AND fat.language = 'US'
       AND fa.asset_category_id = fc.category_id
       -- AND fa.asset_id = fai.asset_id (+)
       -- AND fai.date_ineffective IS NULL
       -- AND fai.po_vendor_id = v.vendor_id (+)
       -- AND fa.asset_key_ccid = ak.code_combination_id (+)
       -- AND fai.deleted_flag = 'NO'
       -- AND fa.asset_id IN (1641)
       AND fb.book_type_code = p_book_type_code;

    CURSOR c_fa_deprn ( p_asset_id   IN   NUMBER ) IS
    SELECT fa.asset_id asset_id,
           fb.book_type_code,
           --
           fa.asset_number no,
           'COMPANY' depreciation_book_code, 
           -- fb.book_type_code depreciation_book_code,
           --
           'Straight-Line' depreciation_method,
           TO_CHAR(fb.date_placed_in_service,'YYYY-MM-DD') depreciation_starting_date,
           0 straight_line_perc,
           life_in_months / 12 no_of_depreciation_years,
           life_in_months no_of_depreciation_months,
           0 fixed_depr_amount,
           0 declining_balance_perc,
           NULL depreciation_table_code,
           0 final_rounding_amount,
           0 ending_book_value,
           NULL fa_posting_group, -- ?
           -- TO_CHAR(fb.date_placed_in_service + ( ( life_in_months / 12 ) * 365 ) - 1,'YYYY-MM-DD') depreciation_ending_date, -- ?
           NULL  depreciation_ending_date,
           -- TO_CHAR(fb.date_placed_in_service,'YYYY-MM-DD') acquisition_date, -- ?
           NULL acquisition_date,
           --
           -- TO_CHAR(fb.date_placed_in_service,'YYYY-MM-DD') gl_acquisition_date, -- ?
           NULL gl_acquisition_date,
           --
           NULL disposal_date,
           -- TO_CHAR(fb.date_placed_in_service,'YYYY-MM-DD') last_acquisition_cost_date, -- ?
           NULL last_acquisition_cost_date,
           --
           -- TO_CHAR(fb.date_placed_in_service,'YYYY-MM-DD') last_depreciation_date, -- ?
           NULL last_depreciation_date,
           --
           NULL last_write_down_date,
           NULL last_appreciation_date,
           NULL last_custom_1_date,
           NULL last_custom_2_date,
           NULL last_salvage_value_date,
           0 fa_exchange_rate,
           0 fixed_depr_amount_below_zero,
           TO_CHAR(SYSDATE,'YYYY-MM-DD') last_date_modified,
           NULL first_user_defined_depr_date,
           'true' use_fa_ledger_check,
           NULL last_maintenance_date,
           0 depr_below_zero_perc,
           NULL projected_disposal_date,
           0 projected_proceeds_on_disposal,
           NULL depr_starting_date_custom_1,
           NULL depr_ending_date_custom_1,
           0 accum_depr_perc_custom_1,
           0 depr_this_year_perc_custom_1,
           NULL property_class_custom_1,
           -- SUBSTR(fat.description,1,100) description,
           NULL description,
           --
           NULL main_asset_component,
           NULL component_of_main_asset,
           0 fa_add_currency_factor,
           'false' use_half_year_convention,
           'false' use_db_perc_first_fiscal_year,
           NULL temp_ending_date,
           0 temp_fixed_depr_amount,
           'false' ignore_def_ending_book_value,
           'false' default_fa_depreciation_book
      FROM fa_additions_b fa,
           fa_additions_tl fat,
           fa_books fb
     WHERE fa.asset_id = p_asset_id
       AND fa.asset_id = fb.asset_id
       AND fb.date_ineffective IS NULL
       AND fb.book_type_code = p_book_type_code
       AND fa.asset_id = fat.asset_id
       AND fat.language = 'US';

    CURSOR c_fa_journal ( p_asset_id   IN   NUMBER ) IS
    SELECT fa.asset_id asset_id,
           fb.book_type_code,
           --
           'ASSETS' journal_template_name,
           'DEFAULT' journal_batch_name,
           10000 line_no,
           'COMPANY' depreciation_book_code,
           'Acquisition Cost' fa_posting_type,
           fa.asset_number fa_no,
           TO_CHAR(SYSDATE,'YYYY-MM-DD') fa_posting_date,
           NULL posting_date,
           NULL document_type,
           NULL document_date,
           NULL document_no,
           NULL external_document_no,
           SUBSTR(fat.description,1,100) description,
           fb.cost amount,
           fb.cost debit_amount,
           0 credit_amount,
           0 salvage_value,
           0 quantity,
           'false' correction,
           0 no_of_depreciation_days,
           'false' depr_until_fa_posting_date,
           'false' depr_acquisition_cost,
           NULL fa_posting_group,
           NULL maintenance_code,
           ( SELECT gcc.segment1
               FROM fa_distribution_history fadh,
                    gl_code_combinations gcc
              WHERE fadh.asset_id = fa.asset_id
                AND fadh.book_type_code = fb.book_type_code
                AND fadh.code_combination_id = gcc.code_combination_id
                AND date_ineffective IS NULL ) shortcut_dimension_1_code,
           ( SELECT gcc.segment3
               FROM fa_distribution_history fadh,
                    gl_code_combinations gcc
              WHERE fadh.asset_id = fa.asset_id
                AND fadh.book_type_code = fb.book_type_code
                AND fadh.code_combination_id = gcc.code_combination_id
                AND date_ineffective IS NULL ) shortcut_dimension_2_code,
           NULL insurance_no,
           NULL budgeted_fa_no,
           'false' use_duplication_list,
           NULL duplicate_in_depreciation_book,
           'false' fa_reclassification_entry,
           NULL fa_error_entry_no,
           NULL reason_code,
           'FAJNL' source_code,
           NULL recurring_method,
           NULL recurring_frequency,
           NULL expiration_date,
           'false' index_entry,
           NULL posting_no_series,
           516 dimension_set_id
      FROM fa_additions_b fa,
           fa_additions_tl fat,
           fa_books fb
     WHERE fa.asset_id = p_asset_id
       AND fa.asset_id = fb.asset_id
       AND fb.date_ineffective IS NULL
       AND fb.book_type_code = p_book_type_code
       AND fa.asset_id = fat.asset_id
       AND fat.language = 'US'
     UNION ALL
    SELECT fa.asset_id asset_id,
           fb.book_type_code,
           --
           'ASSETS' journal_template_name,
           'DEFAULT' journal_batch_name,
           20000 line_no,
           'COMPANY' depreciation_book_code,
           'Depreciation' fa_posting_type,
           fa.asset_number fa_no,
           TO_CHAR(SYSDATE,'YYYY-MM-DD') fa_posting_date,
           NULL posting_date,
           NULL document_type,
           NULL document_date,
           NULL document_no,
           NULL external_document_no,
           SUBSTR(fat.description,1,100) description,
           -1 * get_deprn_reserve ( p_asset_id => fa.asset_id,
                                    p_book_type_code => fb.book_type_code,
                                    p_period_name => p_period_name,
                                    p_cost => fb.cost ) amount,
           0 debit_amount,
           get_deprn_reserve ( p_asset_id => fa.asset_id,
                               p_book_type_code => fb.book_type_code,
                               p_period_name => p_period_name,
                               p_cost => fb.cost ) credit_amount,         
           0 salvage_value,
           0 quantity,
           'false' correction,
           0 no_of_depreciation_days,
           'false' depr_until_fa_posting_date,
           'false' depr_acquisition_cost,
           NULL fa_posting_group,
           NULL maintenance_code,
           ( SELECT gcc.segment1
               FROM fa_distribution_history fadh,
                    gl_code_combinations gcc
              WHERE fadh.asset_id = fa.asset_id
                AND fadh.book_type_code = fb.book_type_code
                AND fadh.code_combination_id = gcc.code_combination_id
                AND date_ineffective IS NULL ) shortcut_dimension_1_code,
           ( SELECT gcc.segment3
               FROM fa_distribution_history fadh,
                    gl_code_combinations gcc
              WHERE fadh.asset_id = fa.asset_id
                AND fadh.book_type_code = fb.book_type_code
                AND fadh.code_combination_id = gcc.code_combination_id
                AND date_ineffective IS NULL ) shortcut_dimension_2_code,
           NULL insurance_no,
           NULL budgeted_fa_no,
           'false' use_duplication_list,
           NULL duplicate_in_depreciation_book,
           'false' fa_reclassification_entry,
           NULL fa_error_entry_no,
           NULL reason_code,
           'FAJNL' source_code,
           NULL recurring_method,
           NULL recurring_frequency,
           NULL expiration_date,
           'false' index_entry,
           NULL posting_no_series,
           516 dimension_set_id
      FROM fa_additions_b fa,
           fa_additions_tl fat,
           fa_books fb
     WHERE fa.asset_id = p_asset_id
       AND fa.asset_id = fb.asset_id
       AND fb.date_ineffective IS NULL
       AND fb.book_type_code = p_book_type_code
       AND fa.asset_id = fat.asset_id
       AND fat.language = 'US';

    v_request_id_excel   NUMBER;

  BEGIN

    print_log ( 'AJC_BC_FA_FIXED_ASSETS_PKG.main_p (+)' );
    print_log ( 'Book Type Code: ' || p_book_type_code );

    IF ( p_delete_final_table = 'Y' ) THEN

      DELETE AJC_BC_FA_FIXED_ASSETS
       WHERE book_type_code = p_book_type_code;

      print_log ('Se borra de la tabla AJC_BC_FA_FIXED_ASSETS..');
      print_log (' '); 

      print_log ('Cantidad registros borrados: ' || SQL%ROWCOUNT );

      DELETE AJC_BC_FA_FIXED_ASSETS_DEPRN
       WHERE book_type_code = p_book_type_code;

      print_log ('Se borra de la tabla AJC_BC_FA_FIXED_ASSETS_DEPRN..');
      print_log (' '); 

      print_log ('Cantidad registros borrados: ' || SQL%ROWCOUNT );

      DELETE AJC_BC_FA_FIXED_ASSETS_JOURNAL
       WHERE book_type_code = p_book_type_code;

      print_log ('Se borra de la tabla AJC_BC_FA_FIXED_ASSETS_JOURNAL..');
      print_log (' '); 

      print_log ('Cantidad registros borrados: ' || SQL%ROWCOUNT );

      COMMIT;

    END IF;

    FOR cfa IN c_fa LOOP

        INSERT 
          INTO AJC_BC_FA_FIXED_ASSETS
             ( asset_id,
               book_type_code,
               request_id,
               creation_date,
               --
               no,
               description,
               search_description,
               description_2,
               fa_class_code,
               fa_subclass_code,
               location_code,
               fa_location_code,
               global_dimension_1_code,
               global_dimension_2_code,
               vendor_no,          
               main_asset_component,
               component_of_main_asset,
               budgeted_asset,
               warranty_date,
               responsible_employee,
               serial_no,
               last_date_modified,
               blocked,
               maintenance_vendor_no,
               under_maintenance,
               next_service_date,
               inactive,
               no_series,
               fa_posting_group,
               image,
               vehicle_license_plate,
               vehicle_year,
               sat_federal_autotransport,
               sat_trailer_type,
               sct_permission_type,
               sct_permission_number,
               sat_classification_code,
               uscg_no,
               asset_tag,
               year_of_manufacture,
               vin_no,
               engine_no )
      VALUES ( cfa.asset_id,
               cfa.book_type_code,
               gv_request_id,
               SYSDATE,
               --
               cfa.no,
               cfa.description,
               cfa.search_description,
               cfa.description_2,
               cfa.fa_class_code,
               cfa.fa_subclass_code,
               cfa.location_code,
               cfa.fa_location_code,
               cfa.global_dimension_1_code,
               cfa.global_dimension_2_code,
               cfa.vendor_no,          
               cfa.main_asset_component,
               cfa.component_of_main_asset,
               cfa.budgeted_asset,
               cfa.warranty_date,
               cfa.responsible_employee,
               cfa.serial_no,
               cfa.last_date_modified,
               cfa.blocked,
               cfa.maintenance_vendor_no,
               cfa.under_maintenance,
               cfa.next_service_date,
               cfa.inactive,
               cfa.no_series,
               cfa.fa_posting_group,
               cfa.image,
               cfa.vehicle_license_plate,
               cfa.vehicle_year,
               cfa.sat_federal_autotransport,
               cfa.sat_trailer_type,
               cfa.sct_permission_type,
               cfa.sct_permission_number,
               cfa.sat_classification_code,
               cfa.uscg_no,
               cfa.asset_tag,
               cfa.year_of_manufacture,
               cfa.vin_no,
               cfa.engine_no );

      FOR cfad IN c_fa_deprn ( cfa.asset_id ) LOOP

          INSERT 
            INTO AJC_BC_FA_FIXED_ASSETS_DEPRN
               ( asset_id,
                 book_type_code,
                 request_id,
                 creation_date,
                 --
                 no,
                 depreciation_book_code,
                 depreciation_method,
                 depreciation_starting_date,
                 straight_line_perc,
                 no_of_depreciation_years,
                 no_of_depreciation_months,
                 fixed_depr_amount,
                 declining_balance_perc,
                 depreciation_table_code,
                 final_rounding_amount,
                 ending_book_value,
                 fa_posting_group,
                 depreciation_ending_date,
                 acquisition_date,
                 gl_acquisition_date,
                 disposal_date,
                 last_acquisition_cost_date,
                 last_depreciation_date,
                 last_write_down_date,
                 last_appreciation_date,
                 last_custom_1_date,
                 last_custom_2_date,
                 last_salvage_value_date,
                 fa_exchange_rate,
                 fixed_depr_amount_below_zero,
                 last_date_modified,
                 first_user_defined_depr_date,
                 use_fa_ledger_check,
                 last_maintenance_date,
                 depr_below_zero_perc,
                 projected_disposal_date,
                 projected_proceeds_on_disposal,
                 depr_starting_date_custom_1,
                 depr_ending_date_custom_1,
                 accum_depr_perc_custom_1,
                 depr_this_year_perc_custom_1,
                 property_class_custom_1,
                 description,
                 main_asset_component,
                 component_of_main_asset,
                 fa_add_currency_factor,
                 use_half_year_convention,
                 use_db_perc_first_fiscal_year,
                 temp_ending_date,
                 temp_fixed_depr_amount,
                 ignore_def_ending_book_value,
                 default_fa_depreciation_book )
        VALUES ( cfad.asset_id,
                 cfad.book_type_code,
                 gv_request_id,
                 SYSDATE,
                 --
                 cfad.no,
                 cfad.depreciation_book_code,
                 cfad.depreciation_method,
                 cfad.depreciation_starting_date,
                 cfad.straight_line_perc,
                 cfad.no_of_depreciation_years,
                 cfad.no_of_depreciation_months,
                 cfad.fixed_depr_amount,
                 cfad.declining_balance_perc,
                 cfad.depreciation_table_code,
                 cfad.final_rounding_amount,
                 cfad.ending_book_value,
                 cfad.fa_posting_group,
                 cfad.depreciation_ending_date,
                 cfad.acquisition_date,
                 cfad.gl_acquisition_date,
                 cfad.disposal_date,
                 cfad.last_acquisition_cost_date,
                 cfad.last_depreciation_date,
                 cfad.last_write_down_date,
                 cfad.last_appreciation_date,
                 cfad.last_custom_1_date,
                 cfad.last_custom_2_date,
                 cfad.last_salvage_value_date,
                 cfad.fa_exchange_rate,
                 cfad.fixed_depr_amount_below_zero,
                 cfad.last_date_modified,
                 cfad.first_user_defined_depr_date,
                 cfad.use_fa_ledger_check,
                 cfad.last_maintenance_date,
                 cfad.depr_below_zero_perc,
                 cfad.projected_disposal_date,
                 cfad.projected_proceeds_on_disposal,
                 cfad.depr_starting_date_custom_1,
                 cfad.depr_ending_date_custom_1,
                 cfad.accum_depr_perc_custom_1,
                 cfad.depr_this_year_perc_custom_1,
                 cfad.property_class_custom_1,
                 cfad.description,
                 cfad.main_asset_component,
                 cfad.component_of_main_asset,
                 cfad.fa_add_currency_factor,
                 cfad.use_half_year_convention,
                 cfad.use_db_perc_first_fiscal_year,
                 cfad.temp_ending_date,
                 cfad.temp_fixed_depr_amount,
                 cfad.ignore_def_ending_book_value,
                 cfad.default_fa_depreciation_book );

      END LOOP;

      FOR cfaj IN c_fa_journal ( cfa.asset_id ) LOOP

          INSERT 
            INTO AJC_BC_FA_FIXED_ASSETS_JOURNAL
               ( asset_id,
                 book_type_code,
                 request_id,
                 creation_date,
                 -- 
                 journal_template_name,
                 journal_batch_name,
                 line_no,
                 depreciation_book_code,
                 fa_posting_type,
                 fa_no,
                 fa_posting_date,
                 posting_date,
                 document_type,
                 document_date,
                 document_no,
                 external_document_no,
                 description,
                 amount,
                 debit_amount,
                 credit_amount,
                 salvage_value,
                 quantity,
                 correction,
                 no_of_depreciation_days,
                 depr_until_fa_posting_date,
                 depr_acquisition_cost,
                 fa_posting_group,
                 maintenance_code,
                 shortcut_dimension_1_code,
                 shortcut_dimension_2_code,
                 insurance_no,
                 budgeted_fa_no,
                 use_duplication_list,
                 duplicate_in_depreciation_book,
                 fa_reclassification_entry,
                 fa_error_entry_no,
                 reason_code,
                 source_code,
                 recurring_method,
                 recurring_frequency,
                 expiration_date,
                 index_entry,
                 posting_no_series,
                 dimension_set_id )
        VALUES ( cfaj.asset_id,
                 cfaj.book_type_code,
                 gv_request_id,
                 SYSDATE,
                 -- 
                 cfaj.journal_template_name,
                 cfaj.journal_batch_name,
                 cfaj.line_no,
                 cfaj.depreciation_book_code,
                 cfaj.fa_posting_type,
                 cfaj.fa_no,
                 cfaj.fa_posting_date,
                 cfaj.posting_date,
                 cfaj.document_type,
                 cfaj.document_date,
                 cfaj.document_no,
                 cfaj.external_document_no,
                 cfaj.description,
                 cfaj.amount,
                 cfaj.debit_amount,
                 cfaj.credit_amount,
                 cfaj.salvage_value,
                 cfaj.quantity,
                 cfaj.correction,
                 cfaj.no_of_depreciation_days,
                 cfaj.depr_until_fa_posting_date,
                 cfaj.depr_acquisition_cost,
                 cfaj.fa_posting_group,
                 cfaj.maintenance_code,
                 cfaj.shortcut_dimension_1_code,
                 cfaj.shortcut_dimension_2_code,
                 cfaj.insurance_no,
                 cfaj.budgeted_fa_no,
                 cfaj.use_duplication_list,
                 cfaj.duplicate_in_depreciation_book,
                 cfaj.fa_reclassification_entry,
                 cfaj.fa_error_entry_no,
                 cfaj.reason_code,
                 cfaj.source_code,
                 cfaj.recurring_method,
                 cfaj.recurring_frequency,
                 cfaj.expiration_date,
                 cfaj.index_entry,
                 cfaj.posting_no_series,
                 cfaj.dimension_set_id );

      END LOOP;

    END LOOP;

    v_request_id_excel := ajc_bc_ws_utils_pkg.print_excel_report ( p_request_id => gv_request_id,
                                                                   p_program => 'AJCBCFAR', -- AJC BC Master Data - FA - Fixed Assets - Report
                                                                   p_template => 'AJCBCFAR' );                                               

    print_log ('General Report request id: ' || v_request_id_excel );

    v_request_id_excel := ajc_bc_ws_utils_pkg.print_excel_report ( p_request_id => gv_request_id,
                                                                   p_program => 'AJCBCFADR', -- AJC BC Master Data - FA - Fixed Assets - Depreciation Report
                                                                   p_template => 'AJCBCFADR' );                                               

    print_log ('Depreciation Report request id: ' || v_request_id_excel );

    v_request_id_excel := ajc_bc_ws_utils_pkg.print_excel_report ( p_request_id => gv_request_id,
                                                                   p_program => 'AJCBCFAJLR', -- AJC BC Master Data - FA - Fixed Assets - Journal Line Report
                                                                   p_template => 'AJCBCFAJLR' );                                               

    print_log ('Journal Line Report request id: ' || v_request_id_excel );

    print_log ( 'AJC_BC_FA_FIXED_ASSETS_PKG.main_p (-)' );

  EXCEPTION
    WHEN OTHERS THEN
      print_log ( 'AJC_BC_FA_FIXED_ASSETS_PKG.main_p (!). Error: '
