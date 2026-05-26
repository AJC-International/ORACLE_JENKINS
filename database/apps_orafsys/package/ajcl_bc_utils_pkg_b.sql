CREATE OR REPLACE PACKAGE BODY ajcl_bc_utils_pkg IS

-- Creation: SBANCHIERI 23-AUG-2023 

  

  PROCEDURE print_log ( p_bc_ifc       IN   VARCHAR2,

                        p_message      IN   VARCHAR2,

                        p_request_id   IN   NUMBER ) IS

  BEGIN



    gv_log_seq := gv_log_seq + 1;

    ajcl_bc_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );



  END print_log;



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



    v_alignment.vertical := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'XLSX_FORMAT_TEXT_VERTICAL_ALIGN' );

    v_alignment.horizontal := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'XLSX_FORMAT_TEXT_HORIZONTAL_ALIGN' );

    v_alignment.wrapText := true;



    RETURN v_alignment;



  END get_alignment_f;



  FUNCTION get_fill_id_f RETURN PLS_INTEGER IS  

  BEGIN



    RETURN as_xlsx.get_fill ( p_patternType => ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'XLSX_FORMAT_CELL_FILL_PATTERN_TYPE' ),

                              p_fgRGB => ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'XLSX_FORMAT_CELL_FILL_COLOUR' ) );



  END get_fill_id_f;



  FUNCTION get_font_f ( p_bold   IN   BOOLEAN ) RETURN PLS_INTEGER IS  

  BEGIN



    RETURN as_xlsx.get_font ( p_name => ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'XLSX_FORMAT_FONT_NAME' ), 

                              p_bold => p_bold );



  END get_font_f;



  FUNCTION get_default_column_width_f RETURN NUMBER IS

  BEGIN



    RETURN TO_NUMBER(ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'XLSX_FORMAT_DEFAULT_COLUMN_WIDTH' ));



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



    v_emails   AJCL_BC_INTEGRATION_EMAILS.emails%TYPE;



  BEGIN



    SELECT emails

      INTO v_emails

      FROM AJCL_BC_INTEGRATION_EMAILS

     WHERE integration = p_integration;



    RETURN v_emails;



  END get_emails_f;



  PROCEDURE send_email_p ( p_to        IN   VARCHAR2,

                           p_subject   IN   VARCHAR2,

                           p_message   IN   VARCHAR2 ) IS

  BEGIN



    EXECUTE IMMEDIATE 'ALTER SESSION SET smtp_out_server = ''smtp.ajc.bz''';



    gv_from_mail := ajcl_bc_ws_utils_pkg.get_parameter_f ( 'INTEGRATIONS_FROM_MAIL' );



    utl_mail.send( SENDER     => 'AJCL BC <' || gv_from_mail || '>',

                   RECIPIENTS => p_to,

                   SUBJECT    => p_subject,

                   MESSAGE    => p_message,

                   mime_type  => 'text; charset=us-ascii' );



  END send_email_p;



  -- Levanta los registros de la tabla AJCL_BC_OUTPUTS o AJCL_BC_REPORTS y crea un .csv 

  PROCEDURE create_csv_p ( p_ifc            IN       VARCHAR2,

                           p_request_id     IN       NUMBER,

                           p_log_seq        IN OUT   NUMBER,

                           p_type           IN       VARCHAR2, -- 'OUTPUT' o 'REPORT'

                           p_filename       IN       VARCHAR2,

                           p_status        OUT       VARCHAR2 ) IS



    file             UTL_FILE.FILE_TYPE;

    v_directory      all_directories.directory_name%TYPE;

    v_table          all_tables.table_name%TYPE;

    v_text           ajcl_bc_outputs.text%TYPE;



    TYPE t_cursor IS REF CURSOR;

    c_cursor          t_cursor;

    v_cursor_string   VARCHAR2(4000);



  BEGIN 



    gv_bc_ifc := p_ifc;

    gv_request_id := p_request_id;

    gv_log_seq := p_log_seq;



    gv_directory_output := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_OUTPUT' );

    gv_directory_report := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_REPORT' );



    -- print_log ( p_ifc, 'ajcl_bc_utils_pkg.create_csv_p (+)', p_request_id );   



    IF ( p_type = 'LOG' ) THEN



      v_directory := gv_directory_output;

      v_table := 'AJCL_BC_LOGS';



    ELSIF ( p_type = 'OUTPUT' ) THEN



      v_directory := gv_directory_output;

      v_table := 'AJCL_BC_OUTPUTS';



    ELSIF ( p_type = 'REPORT' ) THEN



      v_directory := gv_directory_report;

      v_table := 'AJCL_BC_REPORTS';



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

      -- UTL_FILE.PUT(file,v_text || CHR(13) || CHR(10)); -- Se cambia por limitacion de 32kb en el archivo, se usa PUT LINE con true en autoflush

      UTL_FILE.PUT_LINE(file,v_text,TRUE);



    END LOOP;



    CLOSE c_cursor;



    -- Se cierra el archivo

    UTL_FILE.FCLOSE(file);



    p_status := 'S';



    -- print_log ( p_ifc, 'ajcl_bc_utils_pkg.create_csv_p (-)', p_request_id );  

    p_log_seq := gv_log_seq;



  EXCEPTION 

    WHEN OTHERS THEN 

      -- Se cierra el archivo

      UTL_FILE.FCLOSE(file);

      p_status := 'E';



  END create_csv_p;  



  -- 20240619 - Genera y envia tantos mails como destinatarios haya, solo usa TO y no usa CC

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



    PROCEDURE end_attachment ( p_conn   IN OUT NOCOPY UTL_SMTP.CONNECTION,

                               p_last   IN     BOOLEAN DEFAULT TRUE ) IS

    BEGIN



      UTL_SMTP.WRITE_DATA(p_conn, UTL_TCP.CRLF);



      IF ( p_last ) THEN



        write_boundary(p_conn, p_last);



      END IF;



    END end_attachment;



    ---------------------------------------------------------------------------------------------------------------------------



    PROCEDURE begin_attachment ( p_conn         IN OUT NOCOPY UTL_SMTP.CONNECTION,

                                 p_mime_type    IN VARCHAR2 DEFAULT 'text/csv',

                                 p_inline       IN BOOLEAN DEFAULT false,

                                 p_filename     IN VARCHAR2 DEFAULT null,

                                 p_transfer_enc IN VARCHAR2 DEFAULT null ) IS

    BEGIN



      utl_smtp.write_data(p_conn, FIRST_BOUNDARY); 

      write_mime_header(p_conn,'Content-Type', p_mime_type);

      write_mime_header(p_conn,'Content-Transfer-Encoding',p_transfer_enc); -- 'base64');



      IF (p_filename IS NOT NULL) THEN



        IF (p_inline) THEN

          write_mime_header(p_conn,'Content-Disposition', 'inline; filename= ' || p_attach_filename);          

        ELSE 

          write_mime_header(p_conn,'Content-Disposition','attachment; filename= '||p_attach_filename);

        END IF;



      END IF;



      UTL_SMTP.WRITE_DATA(p_conn, UTL_TCP.CRLF);



    END begin_attachment;



    PROCEDURE binary_attachment ( p_conn              IN OUT UTL_SMTP.CONNECTION,

                                  p_type              IN     VARCHAR2,

                                  p_file_name         IN     VARCHAR2,

                                  p_mime_type         IN     VARCHAR2,

                                  p_attach_filename   IN     VARCHAR2 ) IS



      c_max_line_width CONSTANT PLS_INTEGER DEFAULT 54;

      v_amt            BINARY_INTEGER := 672 * 3; /* ensures proper format; 2016 */

      v_bfile          BFILE;

      v_file_length    PLS_INTEGER;

      v_buf            RAW(2100);

      v_modulo         PLS_INTEGER;

      v_pieces         PLS_INTEGER;

      v_file_pos       pls_integer := 1;



      v_directory      all_directories.directory_name%TYPE;



    BEGIN



      begin_attachment ( p_conn => p_conn,

                         p_mime_type => p_mime_type,

                         p_inline => FALSE,

                         p_filename => p_attach_filename,

                         p_transfer_enc => 'base64' );

      BEGIN



        gv_directory_output := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_OUTPUT' );

        gv_directory_report := ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'AJCL_DIRECTORY_REPORT' );



        IF ( p_type = 'LOG' ) THEN



          v_directory := gv_directory_output;



        ELSIF ( p_type = 'OUTPUT' ) THEN



          v_directory := gv_directory_output;



        ELSIF ( p_type = 'REPORT' ) THEN



          v_directory := gv_directory_report;



        END IF;



        v_bfile := BFILENAME(v_directory, p_file_name);

        -- Get the size of the file to be attached

        v_file_length := DBMS_LOB.GETLENGTH(v_bfile);

        -- Calculate the number of pieces the file will be split up into

        v_pieces := TRUNC(v_file_length / v_amt);



        -- Calculate the remainder after dividing the file into v_amt chunks

        v_modulo := MOD(v_file_length, v_amt);



        IF (v_modulo <> 0) THEN



          -- Since the file does not divide equally

          -- we need to go round the loop an extra time to write the last

          -- few bytes - so add one to the loop counter.

          v_pieces := v_pieces + 1;



        END IF;



        DBMS_LOB.FILEOPEN(v_bfile, DBMS_LOB.FILE_READONLY);



        FOR i IN 1 .. v_pieces LOOP



          -- we can read at the beginning of the loop as we have already calculated

          -- how many iterations we will take and so do not need to check

          -- end of file inside the loop.

          v_buf := NULL;

          DBMS_LOB.READ(v_bfile, v_amt, v_file_pos, v_buf);

          v_file_pos := I * v_amt + 1;

          UTL_SMTP.WRITE_RAW_DATA(p_conn, UTL_ENCODE.BASE64_ENCODE(v_buf));



        END LOOP;



      END;



      DBMS_LOB.FILECLOSE(v_bfile);

      -- Se comenta para que no genere caracteres raros en la ultima linea 

      -- end_attachment(p_conn => p_conn);



    EXCEPTION

      WHEN NO_DATA_FOUND THEN

        -- Se comenta para que no genere caracteres raros en la ultima linea 

        -- end_attachment(p_conn => p_conn);

        DBMS_LOB.FILECLOSE(v_bfile);



    END binary_attachment;



  -- Main

  BEGIN



    IF ( p_file_format = 'CSV' ) THEN



      MIME_TYPE := 'text/csv';



    ELSIF ( p_file_format = 'XLSX' ) THEN



      -- 20240816 

      -- MIME_TYPE := 'application/vnd.ms-excel';

      MIME_TYPE := 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';



    END IF;    



    gv_from_mail := ajcl_bc_ws_utils_pkg.get_parameter_f ( 'INTEGRATIONS_FROM_MAIL' );



    v_to_mail := REPLACE(p_to_mail,';',',');



    -- Se resta al largo total el largo sin el separador y se suma 1 si el ultimo caracter no es el separador

    SELECT LENGTH(v_to_mail) - LENGTH(REPLACE(v_to_mail,',')) + DECODE(SUBSTR(v_to_mail,-1,1),',',0,1)

      INTO v_mail_count

      FROM DUAL;



    -- Se envia un mail por cada destinatario  

    FOR i IN 1 .. v_mail_count LOOP



      parse_mail_p ( p_to_mail => v_to_mail,

                     p_mail => v_mail );



      v_conn := utl_smtp.OPEN_CONNECTION( v_smtp_server, v_smtp_server_port );



      utl_smtp.HELO( v_conn, v_smtp_server );

      utl_smtp.MAIL( v_conn, gv_from_mail );

      utl_smtp.RCPT( v_conn, v_mail );



      utl_smtp.OPEN_DATA ( v_conn );



      utl_smtp.write_data(v_conn,'Subject: ' || p_subject || utl_tcp.crlf);    

      utl_smtp.write_data(v_conn,'Date: ' || TO_CHAR(SYSDATE,'dd mon yy hh24:mi:ss') || utl_tcp.crlf);



      utl_smtp.write_data(v_conn,'From: "AJCL BC" <' || gv_from_mail || '>' || utl_tcp.crlf);



      utl_smtp.write_data(v_conn,'To: "' || v_mail || '" <' || v_mail || '>' || utl_tcp.crlf);



      utl_smtp.write_data(v_conn, 'Content-Type' || ': ' || MULTIPART_MIME_TYPE || utl_tcp.CRLF );

      utl_smtp.write_data(v_conn,CRLF);



      -- Body

      utl_smtp.write_data(v_conn, FIRST_BOUNDARY);

      -- utl_smtp.write_data(v_conn, 'Content-Type' || ': ' || MIME_TYPE || utl_tcp.CRLF );

      utl_smtp.write_data(v_conn, 'Content-Type' || ': ' || 'text/plain' || utl_tcp.CRLF );



      utl_smtp.write_data(v_conn, UTL_TCP.CRLF );

      utl_smtp.write_data(v_conn, p_body ); 

      utl_smtp.write_data(v_conn, UTL_TCP.CRLF );

      -- Body



      -- Add Attach

      binary_attachment ( p_conn => v_conn,

                          p_type => p_type,

                          p_file_name => p_filename || '.' || LOWER(p_file_format),

                          p_mime_type => MIME_TYPE, 

                          p_attach_filename => p_attach_filename );



      -- Send email

      UTL_SMTP.CLOSE_DATA( v_conn );

      UTL_SMTP.QUIT( v_conn );



    END LOOP;



  END send_mail_with_attach;



  PROCEDURE insert_log_p ( p_ifc          VARCHAR2,

                           p_text         VARCHAR2,

                           p_request_id   NUMBER,

                           p_seq          NUMBER ) IS



    PRAGMA AUTONOMOUS_TRANSACTION;



  BEGIN



      INSERT

        INTO ajcl_bc_logs

           ( ifc,

             seq,

             text,

             request_id,

             creation_date )

    VALUES ( p_ifc,

             p_seq,

             p_text,

             p_request_id,

             SYSDATE );



    COMMIT;



  END insert_log_p;



  -- Se llama desde Jenkins - AJCL BC Purge Log

  PROCEDURE purge_log_p ( p_keep_x_days   IN   VARCHAR2 ) IS



    e_parameter_value   EXCEPTION;



  BEGIN



    -- Validacion parametro p_keep_x_days -----------------------------------------------------------------------------------    

    IF ( LENGTH(regexp_replace(p_keep_x_days, '[0-9]', '')) IS NOT NULL ) THEN



      RAISE e_parameter_value;



    END IF;



    DELETE ajcl_bc_logs

     WHERE TRUNC(SYSDATE) - TRUNC(creation_date) > TO_NUMBER(p_keep_x_days);



    COMMIT;



  EXCEPTION

    WHEN e_parameter_value THEN

      RAISE_APPLICATION_ERROR(-20000,'ajcl_bc_utils_pkg.purge_log_p - KEEP_X_DAYS only allow numbers.');

    WHEN OTHERS THEN

      RAISE_APPLICATION_ERROR(-20000,'ajcl_bc_utils_pkg.purge_log_p - General Error.');



  END purge_log_p;



  -- Se llama desde Jenkins - AJCL BC Send Log by Mail

  PROCEDURE send_log_by_mail_p ( p_request_id             IN   VARCHAR2,

                                 p_mail                   IN   VARCHAR2,

                                 p_jenkins_build_number   IN   VARCHAR2 DEFAULT NULL ) IS



    v_request_id             NUMBER;

    v_valid                  VARCHAR2(1);



    v_ifc                    AJC_BC_JENKINS_CONCURRENT_JOBS.job_name%TYPE;

    v_log_seq                NUMBER := 0;

    v_status                 VARCHAR2(1);

    v_lines_count            NUMBER;



    e_request_id_invalid     EXCEPTION;

    e_request_id_not_found   EXCEPTION;

    e_mail_empty             EXCEPTION;

    e_mail_invalid           EXCEPTION;

    e_log_empty              EXCEPTION;



  BEGIN 



    -- Validacion parametro p_request_id ---------------------------------------------------------------------------------------    

    IF ( LENGTH(regexp_replace(p_request_id, '[0-9]', '')) IS NOT NULL ) THEN



      RAISE e_request_id_invalid;



    ELSE



      v_request_id := TO_NUMBER(p_request_id);



    END IF;



    IF ( p_mail IS NULL ) THEN



      RAISE e_mail_empty;



    ELSE



      IF ( p_jenkins_build_number IS NOT NULL ) THEN



        BEGIN



          SELECT 'Y'

            INTO v_valid

            FROM dual

           WHERE REGEXP_LIKE(p_mail,'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$');



        EXCEPTION

          WHEN NO_DATA_FOUND THEN

            RAISE e_mail_invalid;



        END;      



      END IF;



    END IF; 



    -- Se obtiene el nombre de la ifc

    BEGIN



      SELECT job_name

        INTO v_ifc

        FROM AJC_BC_JENKINS_CONCURRENT_JOBS 

       WHERE request_id = v_request_id;



    EXCEPTION

      WHEN NO_DATA_FOUND THEN

        RAISE e_request_id_not_found;



    END;



    -- Se verifica si hay lineas generadas en el log para el request_id

    SELECT COUNT(1)

      INTO v_lines_count

      FROM ajcl_bc_logs

     WHERE request_id = v_request_id;



    IF ( v_lines_count > 0 ) THEN



      -- CREATE CSV FROM TABLE AJCL_BC_LOGS --------------------------------------------------------------------------------------

      create_csv_p ( p_ifc => v_ifc,

                     p_request_id => v_request_id,

                     p_log_seq => v_log_seq,

                     p_type => 'LOG',

                     p_filename => 'log',

                     p_status => v_status );



      -- MAIL LOG -----------------------------------------------------------------------------------------------------------

      send_mail_with_attach ( p_to_mail => p_mail,

                              p_subject => v_ifc || ' Log - ' || TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS') || ' - (' || v_request_id || ')',

                              p_body => v_ifc || ' Log.',

                              p_type => 'LOG',

                              p_filename => 'log', 

                              p_attach_filename => v_ifc || ' Log ' || v_request_id || '.csv' );  



    ELSE



      RAISE e_log_empty;



    END IF;                              



  EXCEPTION

    WHEN e_request_id_invalid THEN

      RAISE_APPLICATION_ERROR(-20000,'Parameter REQUEST_ID only allow numbers.');

    WHEN e_request_id_not_found THEN

      RAISE_APPLICATION_ERROR(-20000,'Parameter REQUEST_ID not found.');

    WHEN e_mail_empty THEN

      RAISE_APPLICATION_ERROR(-20000,'Parameter MAIL cannot be empty.');

    WHEN e_mail_invalid THEN

      RAISE_APPLICATION_ERROR(-20000,'Invalid value for parameter MAIL.');      

    WHEN e_log_empty THEN

      RAISE_APPLICATION_ERROR(-20000,'The REQUEST_ID log is empty.');      



  END send_log_by_mail_p;



  -- Inserta en la tabla AJCL_BC_OUTPUTS

  PROCEDURE insert_output_p ( p_ifc          VARCHAR2,

                              p_text         VARCHAR2,

                              p_request_id   NUMBER ) IS



    PRAGMA AUTONOMOUS_TRANSACTION;

    v_exists   VARCHAR2(1);

    v_seq      NUMBER;



  BEGIN



    -- Se verifica si existe algun registro para la ifc y request id

    -- Para que el delete de abajo se ejecute solo la primera vez que se inserta un registro para la ifc y request_id

    SELECT DECODE(COUNT(1),0,'N','Y')

      INTO v_exists

      FROM ajcl_bc_outputs

     WHERE ifc = p_ifc

       AND request_id = p_request_id;



    -- Si no existe, se borra todo lo que haya para la ifc y distinto request_id, para eliminar el output anterior   

    IF ( v_exists = 'N' ) THEN



      DELETE ajcl_bc_outputs

       WHERE ifc = p_ifc

         AND request_id != p_request_id;



      COMMIT;



    END IF;



    SELECT NVL(MAX(seq),0) + 1

      INTO v_seq

      FROM ajcl_bc_outputs

     WHERE ifc = p_ifc

       AND request_id = p_request_id;



      INSERT

        INTO ajcl_bc_outputs

           ( ifc,

             seq,

             text,

             request_id,

             creation_date )

    VALUES ( p_ifc,

             v_seq,

             p_text,

             p_request_id,

             SYSDATE );



    COMMIT;



  END insert_output_p;    



  -- Inserta en la tabla AJCL_BC_OUTPUTS_XLSX

  PROCEDURE insert_output_xlsx_p ( p_ifc          VARCHAR2,

                                   p_section      VARCHAR2,

                                   p_column1      VARCHAR2,

                                   p_column2      VARCHAR2 DEFAULT NULL,

                                   p_column3      VARCHAR2 DEFAULT NULL,

                                   p_column4      VARCHAR2 DEFAULT NULL,

                                   p_column5      VARCHAR2 DEFAULT NULL,

                                   p_column6      VARCHAR2 DEFAULT NULL,

                                   p_column7      VARCHAR2 DEFAULT NULL,

                                   p_column8      VARCHAR2 DEFAULT NULL,

                                   p_column9      VARCHAR2 DEFAULT NULL,

                                   p_column10     VARCHAR2 DEFAULT NULL,

                                   p_column11     VARCHAR2 DEFAULT NULL,

                                   p_column12     VARCHAR2 DEFAULT NULL,

                                   p_column13     VARCHAR2 DEFAULT NULL,

                                   p_column14     VARCHAR2 DEFAULT NULL,

                                   p_column15     VARCHAR2 DEFAULT NULL,

                                   p_column16     VARCHAR2 DEFAULT NULL,

                                   p_column17     VARCHAR2 DEFAULT NULL,

                                   p_column18     VARCHAR2 DEFAULT NULL,

                                   p_column19     VARCHAR2 DEFAULT NULL,

                                   p_column20     VARCHAR2 DEFAULT NULL,

                                   p_request_id   NUMBER ) IS



    PRAGMA AUTONOMOUS_TRANSACTION;

    v_exists   VARCHAR2(1);

    v_seq      NUMBER;



  BEGIN



    -- Se verifica si existe algun registro para la ifc y request id

    -- Para que el delete de abajo se ejecute solo la primera vez que se inserta un registro para la ifc y request_id

    SELECT DECODE(COUNT(1),0,'N','Y')

      INTO v_exists

      FROM AJCL_BC_OUTPUTS_XLSX

     WHERE ifc = p_ifc

       AND request_id = p_request_id;



    -- Si no existe, se borra todo lo que haya para la ifc y distinto request_id, para eliminar el output anterior   

    IF ( v_exists = 'N' ) THEN



      DELETE AJCL_BC_OUTPUTS_XLSX

       WHERE ifc = p_ifc

         AND request_id != p_request_id;



      COMMIT;



    END IF;



    SELECT NVL(MAX(seq),0) + 1

      INTO v_seq

      FROM AJCL_BC_OUTPUTS_XLSX

     WHERE ifc = p_ifc

       AND request_id = p_request_id;



      INSERT

        INTO AJCL_BC_OUTPUTS_XLSX

           ( ifc,

             seq,

             section,

             column1,

             column2,

             column3,

             column4,

             column5,

             column6,

             column7,

             column8,

             column9,

             column10,

             column11,

             column12,

             column13,

             column14,

             column15,

             column16,

             column17,

             column18,

             column19,

             column20,

             request_id,

             creation_date )

    VALUES ( p_ifc,

             v_seq,

             p_section,

             p_column1,

             p_column2,

             p_column3,

             p_column4,

             p_column5,

             p_column6,

             p_column7,

             p_column8,

             p_column9,

             p_column10,

             p_column11,

             p_column12,

             p_column13,

             p_column14,

             p_column15,

             p_column16,

             p_column17,

             p_column18,

             p_column19,

             p_column20,

             p_request_id,

             SYSDATE );



    COMMIT;



  END insert_output_xlsx_p;



  -- Inserta en la tabla AJCL_BC_REPORTS

  PROCEDURE insert_report_p ( p_ifc          VARCHAR2,

                              p_text         VARCHAR2,

                              p_request_id   NUMBER ) IS



    PRAGMA AUTONOMOUS_TRANSACTION;

    v_exists   VARCHAR2(1);

    v_seq      NUMBER;



  BEGIN



    -- Se verifica si existe algun registro para la ifc y request id

    -- Para que el delete de abajo se ejecute solo la primera vez que se inserta un registro para la ifc y request_id

    SELECT DECODE(COUNT(1),0,'N','Y')

      INTO v_exists

      FROM ajcl_bc_reports

     WHERE ifc = p_ifc

       AND request_id = p_request_id;



    -- Si no existe, se borra todo lo que haya para la ifc y distinto request_id, para eliminar el report anterior   

    IF ( v_exists = 'N' ) THEN



      DELETE ajcl_bc_reports

       WHERE ifc = p_ifc

         AND request_id != p_request_id;



      COMMIT;



    END IF;



    SELECT NVL(MAX(seq),0) + 1

      INTO v_seq

      FROM ajcl_bc_reports

     WHERE ifc = p_ifc

       AND request_id = p_request_id;



      INSERT

        INTO ajcl_bc_reports

           ( ifc,

             seq,

             text,

             request_id,

             creation_date )

    VALUES ( p_ifc,

             v_seq,

             p_text,

             p_request_id,

             SYSDATE );



    COMMIT;



  END insert_report_p;



  FUNCTION get_request_id_f RETURN NUMBER IS



    v_request_id   NUMBER;



  BEGIN



    SELECT AJC_BC_REQUEST_ID_SEQ.nextval

      INTO v_request_id

      FROM DUAL;



    RETURN v_request_id;



  END get_request_id_f;



  FUNCTION get_env_variable_value_f ( p_variable   IN   VARCHAR2 ) RETURN VARCHAR2 IS



    v_value     VARCHAR2(100);



  BEGIN



    SELECT value

      INTO v_value

      FROM AJC_BC_ENVIRONMENT_VARIABLES

     WHERE variable = p_variable

       AND db_name = ajcl_bc_utils_pkg.get_db_name_f;



    RETURN v_value;



  EXCEPTION

    WHEN OTHERS THEN

      RETURN 'Environment variable ' || p_variable || ' not defined in table AJCL_BC_ENVIRONMENT_VARIABLES';



  END get_env_variable_value_f;



  FUNCTION get_executable_file_name_f ( p_code   IN   VARCHAR2 ) RETURN VARCHAR2 IS



    v_execution_file_name     VARCHAR2(100);



  BEGIN



    SELECT execution_file_name

      INTO v_execution_file_name

      FROM AJC_BC_EXECUTABLES

     WHERE code = p_code;



    RETURN v_execution_file_name;



  EXCEPTION

    WHEN OTHERS THEN

      RETURN 'Executable ' || p_code || ' not defined in table AJC_BC_EXECUTABLES';



  END get_executable_file_name_f;



  FUNCTION is_bc_environment_valid_f ( p_bc_environment   IN   VARCHAR2 ) RETURN VARCHAR2 IS



    v_is_bc_environment_valid   VARCHAR2(1);



  BEGIN



    SELECT DECODE(COUNT(1),0,'N','Y')

      INTO v_is_bc_environment_valid

      FROM AJC_BC_ENVIRONMENTS

     WHERE db_name = ajcl_bc_utils_pkg.get_db_name_f

       AND UPPER(bc_environment) = UPPER(p_bc_environment)

       AND enabled = 'Y';



    RETURN v_is_bc_environment_valid;



  EXCEPTION

    WHEN OTHERS THEN

      RETURN 'N';



  END is_bc_environment_valid_f;



  PROCEDURE initialize_p ( p_org_id   IN   NUMBER ) IS

  BEGIN



    EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_LANGUAGE=AMERICAN';



    dbms_application_info.set_client_info(p_org_id); 



  END initialize_p;



  PROCEDURE ins_jenkins_concurrent_job_p ( p_request_id             IN   NUMBER,

                                           p_job_name               IN   VARCHAR2,

                                           p_jenkins_build_number   IN   VARCHAR2 DEFAULT NULL,

                                           p_argument1              IN   VARCHAR2 DEFAULT NULL,

                                           p_argument2              IN   VARCHAR2 DEFAULT NULL,

                                           p_argument3              IN   VARCHAR2 DEFAULT NULL,

                                           p_argument4              IN   VARCHAR2 DEFAULT NULL,

                                           p_argument5              IN   VARCHAR2 DEFAULT NULL,

                                           p_argument6              IN   VARCHAR2 DEFAULT NULL,

                                           p_argument7              IN   VARCHAR2 DEFAULT NULL,

                                           p_argument8              IN   VARCHAR2 DEFAULT NULL,

                                           p_argument9              IN   VARCHAR2 DEFAULT NULL,

                                           p_argument10             IN   VARCHAR2 DEFAULT NULL,

                                           p_argument11             IN   VARCHAR2 DEFAULT NULL,

                                           p_argument12             IN   VARCHAR2 DEFAULT NULL,

                                           p_argument13             IN   VARCHAR2 DEFAULT NULL,

                                           p_argument14             IN   VARCHAR2 DEFAULT NULL,

                                           p_argument15             IN   VARCHAR2 DEFAULT NULL,

                                           p_argument16             IN   VARCHAR2 DEFAULT NULL,

                                           p_argument17             IN   VARCHAR2 DEFAULT NULL,

                                           p_argument18             IN   VARCHAR2 DEFAULT NULL,

                                           p_argument19             IN   VARCHAR2 DEFAULT NULL,

                                           p_argument20             IN   VARCHAR2 DEFAULT NULL ) IS



    PRAGMA AUTONOMOUS_TRANSACTION;



  BEGIN



    INSERT

      INTO ajc_bc_jenkins_concurrent_jobs

           ( request_id,

             job_name,

             jenkins_build_number,

             start_date,

             argument1,

             argument2,

             argument3,

             argument4,

             argument5,

             argument6,

             argument7,

             argument8,

             argument9,

             argument10,

             argument11,

             argument12,

             argument13,

             argument14,

             argument15,

             argument16,

             argument17,

             argument18,

             argument19,

             argument20,

             status,

             creation_date )

    VALUES ( p_request_id,

             p_job_name,

             p_jenkins_build_number,

             SYSDATE, -- start_date

             p_argument1,

             p_argument2,

             p_argument3,

             p_argument4,

             p_argument5,

             p_argument6,

             p_argument7,

             p_argument8,

             p_argument9,

             p_argument10,

             p_argument11,

             p_argument12,

             p_argument13,

             p_argument14,

             p_argument15,

             p_argument16,

             p_argument17,

             p_argument18,

             p_argument19,

             p_argument20,

             'R', -- status

             SYSDATE ); -- creation_date



    COMMIT;



  END ins_jenkins_concurrent_job_p;



  PROCEDURE upd_jenkins_concurrent_job_p ( p_request_id   IN   NUMBER,

                                           p_status       IN   VARCHAR2 ) IS



    PRAGMA AUTONOMOUS_TRANSACTION;



  BEGIN



    UPDATE ajc_bc_jenkins_concurrent_jobs

       SET end_date = SYSDATE,

           status = p_status

     WHERE request_id = p_request_id;



    COMMIT;



  END upd_jenkins_concurrent_job_p;



END ajcl_bc_utils_pkg;
