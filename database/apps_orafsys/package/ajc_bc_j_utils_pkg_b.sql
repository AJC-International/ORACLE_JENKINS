PACKAGE BODY AJC_BC_J_UTILS_PKG IS
-- Creation: SBANCHIERI 23-AUG-2023 
  
  PROCEDURE print_log ( p_bc_ifc       IN   VARCHAR2,
                        p_message      IN   VARCHAR2,
                        p_request_id   IN   NUMBER ) IS
  BEGIN

    gv_log_seq := gv_log_seq + 1;
    AJC_BC_J_UTILS_PKG.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );

  END print_log;

  FUNCTION get_dimension_value ( p_oracle_segment   IN   VARCHAR2,
                                 p_oracle_value     IN   VARCHAR2,
                                 p_bc_dimension     IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_bc_value  VARCHAR2(20);

  BEGIN

    SELECT bc_value
      INTO v_bc_value
      FROM ajc_bc_gl_mapping
     WHERE oracle_segment = p_oracle_segment
       AND oracle_value = p_oracle_value
       AND bc_dimension = p_bc_dimension
       AND NVL(active,'N') = 'Y';

    RETURN v_bc_value;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RETURN NULL;
    WHEN OTHERS THEN
      RETURN NULL;

  END get_dimension_value;

  FUNCTION get_db_name_f RETURN VARCHAR2 IS

    v_db_name   V$DATABASE.name%TYPE;

  BEGIN

    SELECT name
      INTO v_db_name
      FROM V$DATABASE;

    RETURN v_db_name;

  END get_db_name_f; 

  FUNCTION get_company_parameters_p ( p_bc_company_name   IN   VARCHAR2,
                                      p_column            IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_query     VARCHAR2(2000);
    v_value     VARCHAR2(200);

  BEGIN

    v_query := 'SELECT ' || p_column || ' FROM AJC_BC_COMPANIES WHERE bc_company_name = ''' || p_bc_company_name || ''' GROUP BY ' || p_column;
    EXECUTE IMMEDIATE v_query INTO v_value;

    RETURN v_value;

  EXCEPTION
    WHEN OTHERS THEN
      RETURN NULL;

  END get_company_parameters_p;

  --
  -- Funciones para formatear reports / outputs en formato xlsx
  --
  FUNCTION get_alignment_f RETURN as_xlsx.tp_alignment IS

    v_alignment   as_xlsx.tp_alignment;

  BEGIN

    v_alignment.vertical := AJC_BC_J_WS_UTILS_PKG.get_parameter_f ( p_parameter_code => 'XLSX_FORMAT_TEXT_VERTICAL_ALIGN' );
    v_alignment.horizontal := AJC_BC_J_WS_UTILS_PKG.get_parameter_f ( p_parameter_code => 'XLSX_FORMAT_TEXT_HORIZONTAL_ALIGN' );
    v_alignment.wrapText := true;

    RETURN v_alignment;

  END get_alignment_f;

  FUNCTION get_fill_id_f RETURN PLS_INTEGER IS  
  BEGIN

    RETURN as_xlsx.get_fill ( p_patternType => AJC_BC_J_WS_UTILS_PKG.get_parameter_f ( p_parameter_code => 'XLSX_FORMAT_CELL_FILL_PATTERN_TYPE' ),
                              p_fgRGB => AJC_BC_J_WS_UTILS_PKG.get_parameter_f ( p_parameter_code => 'XLSX_FORMAT_CELL_FILL_COLOUR_FOODS' ) );

  END get_fill_id_f;

  FUNCTION get_font_f ( p_bold   IN   BOOLEAN ) RETURN PLS_INTEGER IS  
  BEGIN

    RETURN as_xlsx.get_font ( p_name => AJC_BC_J_WS_UTILS_PKG.get_parameter_f ( p_parameter_code => 'XLSX_FORMAT_FONT_NAME' ), 
                              p_bold => p_bold );

  END get_font_f;

  FUNCTION get_default_column_width_f RETURN NUMBER IS
  BEGIN

    RETURN TO_NUMBER(AJC_BC_J_WS_UTILS_PKG.get_parameter_f ( p_parameter_code => 'XLSX_FORMAT_DEFAULT_COLUMN_WIDTH' ));

  END get_default_column_width_f;

  PROCEDURE create_rep_info_sheet_p ( p_report_title           IN   VARCHAR2,
                                      p_request_id             IN   NUMBER,
                                      p_bc_environment         IN   VARCHAR2,
                                      p_jenkins_build_number   IN   VARCHAR2,
                                      -- 
                                      p_param_1_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_1_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_2_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_2_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_3_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_3_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_4_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_4_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_5_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_5_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_6_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_6_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_7_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_7_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_8_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_8_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_9_title          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_9_value          IN   VARCHAR2 DEFAULT NULL,
                                      p_param_10_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_10_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_11_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_11_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_12_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_12_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_13_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_13_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_14_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_14_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_15_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_15_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_16_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_16_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_17_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_17_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_18_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_18_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_19_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_19_value         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_20_title         IN   VARCHAR2 DEFAULT NULL,
                                      p_param_20_value         IN   VARCHAR2 DEFAULT NULL ) IS

    v_sheet       NUMBER := 1;
    v_alignment   as_xlsx.tp_alignment := get_alignment_f;
    v_row         NUMBER := 4;
    v_query       VARCHAR2(200);
    v_print       VARCHAR2(122);

  BEGIN

    as_xlsx.clear_workbook;
    as_xlsx.new_sheet('Report Info');

    -- Se setea el ancho de la columna 1
    as_xlsx.set_column_width ( p_col => 1,
                               p_width => 45,
                               p_sheet => v_sheet );

    -- Se setea el ancho de la columna 2                          
    as_xlsx.set_column_width ( p_col => 2,
                               p_width => 15,
                               p_sheet => v_sheet );                                

    -- Se imprime el Titulo del reporte 
    as_xlsx.cell ( p_col => 1,
                   p_row => 1,
                   p_sheet => v_sheet,
                   p_value => p_report_title, 
                   p_fontid => get_font_f ( p_bold => true ),
                   p_fillId => get_fill_id_f,
                   p_numFmtId => 0 );

    -- Se hace merge de la columna 1 y 2 de la fila 1 - Titulo del reporte
    as_xlsx.mergecells ( p_tl_col => 1,
                         p_tl_row => 1,
                         p_br_col => 2,
                         p_br_row => 1,
                         p_sheet => v_sheet );

    -- Se imprime la fecha y hora de generacion
    as_xlsx.cell ( p_col => 1,
                   p_row => 2,
                   p_sheet => v_sheet,
                   p_value => TO_CHAR(SYSDATE,'MM/DD/YYYY HH24:MI:SS'), 
                   p_fontid => get_font_f ( p_bold => true ),
                   p_numFmtId => 0 );

    -- Se imprime el título Parameters
    as_xlsx.cell ( p_col => 1,
                   p_row => v_row,
                   p_sheet => v_sheet,
                   p_value => 'Parameters', 
                   p_fontid => get_font_f ( p_bold => true ),
                   p_numFmtId => 0 );

    v_row := v_row + 1;

    -- Se imprime parámetro Request ID 
    as_xlsx.cell ( p_col => 1,
                   p_row => v_row,
                   p_sheet => v_sheet,
                   p_value => 'Request ID', 
                   p_fontid => get_font_f ( p_bold => false ),
                   p_numFmtId => 0 );

    as_xlsx.cell ( p_col => 2,
                   p_row => v_row,
                   p_sheet => v_sheet,
                   p_value => p_request_id, 
                   p_fontid => get_font_f ( p_bold => false ),
                   p_alignment => v_alignment,
                   p_numFmtId => 0 );                   

    v_row := v_row + 1;

    as_xlsx.cell ( p_col => 1,
                   p_row => v_row,
                   p_sheet => v_sheet,
                   p_value => 'BC Environment', 
                   p_fontid => get_font_f ( p_bold => false ),
                   p_numFmtId => 0 );    

    as_xlsx.cell ( p_col => 2,
                   p_row => v_row,
                   p_sheet => v_sheet,
                   p_value => p_bc_environment, 
                   p_fontid => get_font_f ( p_bold => false ),
                   p_alignment => v_alignment,
                   p_numFmtId => 0 );

    v_row := v_row + 1;

    as_xlsx.cell ( p_col => 1,
                   p_row => v_row,
                   p_sheet => v_sheet,
                   p_value => 'Jenkins Build Number', 
                   p_fontid => get_font_f ( p_bold => false ),
                   p_numFmtId => 0 );    

    as_xlsx.cell ( p_col => 2,
                   p_row => v_row,
                   p_sheet => v_sheet,
                   p_value => p_jenkins_build_number, 
                   p_fontid => get_font_f ( p_bold => false ),
                   p_alignment => v_alignment,
                   p_numFmtId => 0 );    

    IF ( p_param_1_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_1_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_1_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_2_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_2_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_2_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_3_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_3_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_3_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_4_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_4_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_4_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_5_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_5_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_5_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_6_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_6_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_6_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_7_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_7_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_7_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_8_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_8_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_8_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_9_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_9_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_9_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_10_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_10_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_10_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_11_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_11_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_11_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_12_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_12_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_12_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_13_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_13_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_13_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_14_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_14_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_14_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_15_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_15_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_15_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_16_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_16_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_16_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_17_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_17_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_17_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_18_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_18_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_18_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_19_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_19_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_19_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

    IF ( p_param_20_title IS NOT NULL ) THEN

      v_row := v_row + 1;

      as_xlsx.cell ( p_col => 1,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_20_title, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_numFmtId => 0 );    

      as_xlsx.cell ( p_col => 2,
                     p_row => v_row,
                     p_sheet => v_sheet,
                     p_value => p_param_20_value, 
                     p_fontid => get_font_f ( p_bold => false ),
                     p_alignment => v_alignment,
                     p_numFmtId => 0 );    

    END IF;

  END create_rep_info_sheet_p;

  PROCEDURE create_sheet_p ( p_sheet_title   IN       VARCHAR2,
                             p_sheet         IN       NUMBER,
                             p_cursor        IN OUT   SYS_REFCURSOR ) IS
  BEGIN

    as_xlsx.new_sheet(p_sheet_title);

    -- Se setea el ancho de las primeras 40 columnas de la hoja
    FOR column IN 1..40 LOOP

      as_xlsx.set_column_width ( p_col => column,
                                 p_width => get_default_column_width_f,
                                 p_sheet => p_sheet );

    END LOOP;

    -- Se setea el formato de la 1era fila de la solapa de datos
    as_xlsx.set_row ( p_row => 1,
                      p_numFmtId => 0,
                      p_fontId => get_font_f ( p_bold => true ),
                      p_borderId => as_xlsx.get_border ( p_top => null,
                                                         p_bottom => 'thin',
                                                         p_left => null,
                                                         p_right => null ),
                      p_fillId => get_fill_id_f,
                      p_sheet => p_sheet );  

    -- Se inmobiliza la fila de los titulos
    as_xlsx.freeze_rows ( p_nr_rows => 1,
                          p_sheet => p_sheet );

    as_xlsx.query2sheet ( p_cursor, 
                          p_sheet => p_sheet );                         

  END create_sheet_p;
  --
  -- Funciones para formatear reports / outputs en formato xlsx
  --

  FUNCTION get_emails_f ( p_integration   IN   VARCHAR2 ) RETURN VARCHAR2 IS

    v_emails   AJC_BC_INTEGRATION_EMAILS.emails%TYPE;

  BEGIN

    SELECT emails
      INTO v_emails
      FROM AJC_BC_INTEGRATION_EMAILS
     WHERE integration = p_integration;

    RETURN v_emails;

  END get_emails_f;

  PROCEDURE send_email_p ( p_to        IN   VARCHAR2,
                           p_subject   IN   VARCHAR2,
                           p_message   IN   VARCHAR2 ) IS
  BEGIN

    EXECUTE IMMEDIATE 'ALTER SESSION SET smtp_out_server = ''smtp.ajc.bz''';

    gv_from_mail := AJC_BC_J_WS_UTILS_PKG.get_parameter_f ( 'INTEGRATIONS_FROM_MAIL' );

    utl_mail.send( SENDER     => 'AJC BC <' || gv_from_mail || '>',
                   RECIPIENTS => p_to,
                   SUBJECT    => p_subject,
                   MESSAGE    => p_message,
                   mime_type  => 'text; charset=us-ascii' );

  END send_email_p;

  -- Levanta los registros de la tabla AJC_BC_OUTPUTS o AJC_BC_REPORTS y crea un .csv 
  PROCEDURE create_csv_p ( p_ifc            IN       VARCHAR2,
                           p_request_id     IN       NUMBER,
                           p_log_seq        IN OUT   NUMBER,
                           p_type           IN       VARCHAR2, -- 'OUTPUT' o 'REPORT'
                           p_filename       IN       VARCHAR2,
                           p_status        OUT       VARCHAR2 ) IS

    file             UTL_FILE.FILE_TYPE;
    v_directory      all_directories.directory_name%TYPE;
    v_table          all_tables.table_name%TYPE;
    v_text           ajc_bc_outputs.text%TYPE;

    TYPE t_cursor IS REF CURSOR;
    c_cursor          t_cursor;
    v_cursor_string   VARCHAR2(4000);

  BEGIN 

    gv_bc_ifc := p_ifc;
    gv_request_id := p_request_id;
    gv_log_seq := p_log_seq;

    gv_directory_output := AJC_BC_J_WS_UTILS_PKG.get_parameter_f ( p_parameter_code => 'AJC_DIRECTORY_OUTPUT' );
    gv_directory_report := AJC_BC_J_WS_UTILS_PKG.get_parameter_f ( p_parameter_code => 'AJC_DIRECTORY_REPORT' );

    IF ( p_type = 'LOG' ) THEN

      v_directory := gv_directory_output;
      v_table := 'AJC_BC_LOGS';

    ELSIF ( p_type = 'OUTPUT' ) THEN

      v_directory := gv_directory_output;
      v_table := 'AJC_BC_OUTPUTS';

    ELSIF ( p_type = 'REPORT' ) THEN

      v_directory := gv_directory_report;
      v_table := 'AJC_BC_REPORTS';

    END IF;

    -- print_log ( p_ifc, 'v_directory: ' || v_directory, p_request_id ); 
    -- print_log ( p_ifc, 'v_table: ' || v_table, p_request_id ); 

    -- Se abre el archivo
    file := UTL_FILE.FOPEN(v_directory,p_filename || '.csv','W',32767); 

    -- Se arma el cursor
    v_cursor_string :=  'SELECT text FROM ' || v_table || ' WHERE request_id = ' || p_request_id || ' AND ifc = ''' || p_ifc || ''' ORDER BY seq';
    -- print_log ( p_ifc, 'v_cursor_string: ' || v_cursor_string, p_request_id ); 

    -- Se imprimen las lineas al archivo
    OPEN c_cursor FOR v_cursor_string;
    LOOP

      FETCH c_cursor INTO v_text;
      EXIT WHEN c_cursor%NOTFOUND;
      UTL_FILE.PUT_LINE(file,v_text,TRUE);

    END LOOP;

    CLOSE c_cursor;

    -- Se cierra el archivo
    UTL_FILE.FCLOSE(file);

    p_status := 'S';

    p_log_seq := gv_log_seq;

  EXCEPTION 
    WHEN OTHERS THEN 
      -- Se cierra el archivo
      UTL_FILE.FCLOSE(file);
      p_status := 'E';

  END create_csv_p;  

  -- Genera y envia tantos mails como destinatarios haya, solo usa TO y no usa CC
  PROCEDURE send_mail_with_attach ( p_to_mail            VARCHAR2,
                                    p_subject            VARCHAR2,
                                    p_body               VARCHAR2,
                                    p_type               VARCHAR2,
                                    p_filename           VARCHAR2, 
                                    p_file_format        VARCHAR2 DEFAULT 'CSV',
                                    p_attach_filename    VARCHAR2 ) IS

    v_smtp_server         VARCHAR2(100) := 'smtp.ajc.bz';
    v_smtp_server_port    NUMBER := 25;
    v_directory_name      VARCHAR2(100);
    v_file_name           VARCHAR2(100);
    -- v_mesg                VARCHAR2(32767);
    v_conn                UTL_SMTP.CONNECTION;
    CRLF                  CONSTANT VARCHAR2(10) := utl_tcp.CRLF;
    BOUNDARY              CONSTANT VARCHAR2(256) := '-----7D81B75CCC90D2974F7A1CBD';
    FIRST_BOUNDARY        CONSTANT VARCHAR2(256) := '--'||BOUNDARY||CRLF;
    MULTIPART_MIME_TYPE   CONSTANT VARCHAR2(256) := 'multipart/mixed; boundary="'||BOUNDARY||'"';

    -- MIME_TYPE             CONSTANT varchar2(255) := 'text/csv';
    MIME_TYPE             VARCHAR2(255);

    -- 20240607 - Agregado para poder enviar mail a multiples direcciones
    v_mail_count          NUMBER;
    v_to_mail             VARCHAR2(2000);
    v_mail                VARCHAR2(2000);
    -- 20240607 - Agregado para poder enviar mail a multiples direcciones

    ---------------------------------------------------------------------------------------------------------------------------

    -- 20240607 - Agregado para poder enviar mail a multiples direcciones
    PROCEDURE parse_mail_p ( p_to_mail   IN OUT VARCHAR2,
                             p_mail         OUT VARCHAR2 ) IS
    BEGIN

      IF ( INSTR(p_to_mail,',') = 0 ) THEN

        p_mail := p_to_mail;

      ELSE

        SELECT SUBSTR(p_to_mail,1,INSTR(p_to_mail,',') - 1), -- Se obtiene el texto hasta la primera coma
               SUBSTR(p_to_mail,INSTR(p_to_mail,',') + 1) -- Se guarda todo el resto, sin el texto hasta la primera coma
          INTO p_mail,
               p_to_mail
          FROM DUAL;

      END IF;

    END parse_mail_p;
    -- 20240607 - Agregado para poder enviar mail a multiples direcciones

    PROCEDURE write_mime_header ( p_conn  in out nocopy utl_smtp.connection,
                                  p_name  in varchar2,
                                  p_value in varchar2 ) IS
    BEGIN

      UTL_SMTP.WRITE_RAW_DATA( p_conn, UTL_RAW.CAST_TO_RAW( p_name || ': ' || p_value || UTL_TCP.CRLF) );

    END write_mime_header;

    ---------------------------------------------------------------------------------------------------------------------------

    PROCEDURE write_boundary ( p_conn IN OUT NOCOPY UTL_SMTP.CONNECTION,
                               p_last IN BOOLEAN DEFAULT false ) IS
    BEGIN

      IF (p_last) THEN

        UTL_SMTP.WRITE_DATA(p_conn, '--DMW.Boundary.605592468--'||UTL_TCP.CRLF);

      ELSE

        UTL_SMTP.WRITE_DATA(p_conn, '--DMW.Boundary.605592468'||UTL_TCP.CRLF);

      END IF;

    END write_boundary;

    ---------------------------------------------------------------------------------------------------------------------------

    PROCEDURE end_attachment ( p_conn   IN OUT NOCOPY UTL_SMTP.C
