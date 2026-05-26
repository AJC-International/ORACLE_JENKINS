PACKAGE BODY ajc_bc_scheduler_pkg IS
-- Creation: SBANCHIERI 23-AUG-2023

  PROCEDURE print_log ( p_message   IN   VARCHAR2 ) IS
  BEGIN

    gv_log_seq := gv_log_seq + 1;
    ajcl_bc_utils_pkg.insert_log_p ( gv_bc_ifc, p_message, gv_request_id, gv_log_seq );

  END print_log;

  PROCEDURE create_and_run_job_p ( p_job_name              IN   VARCHAR2,
                                   p_comments              IN   VARCHAR2,
                                   p_number_of_arguments   IN   NUMBER,
                                   --
                                   p_argument1             IN   VARCHAR2 DEFAULT NULL, -- Reservado para poner path y nombre del sh del app 
                                                                                       -- si es loader siempre usar 
                                                                                       -- ajcl_bc_utils_pkg.get_env_variable_value_f ( 'XXAJC_TOP' ) || 'bin/AJCL_EXECUTE_CTL.sh';
                                                                                       -- que arma y ejecuta el comando sqlldr
                                   p_argument2             IN   VARCHAR2 DEFAULT NULL, -- Reservado para poner nombre del .ctl en los casos que sea loader (control file)
                                   p_argument3             IN   VARCHAR2 DEFAULT NULL, -- Reservado para poner nombre del archivo de datos a cargar por el loader (data file)
                                   p_argument4             IN   VARCHAR2 DEFAULT NULL,
                                   p_argument5             IN   VARCHAR2 DEFAULT NULL,
                                   p_argument6             IN   VARCHAR2 DEFAULT NULL,
                                   p_argument7             IN   VARCHAR2 DEFAULT NULL,
                                   p_argument8             IN   VARCHAR2 DEFAULT NULL,
                                   p_argument9             IN   VARCHAR2 DEFAULT NULL,
                                   p_argument10            IN   VARCHAR2 DEFAULT NULL,
                                   p_argument11            IN   VARCHAR2 DEFAULT NULL,
                                   p_argument12            IN   VARCHAR2 DEFAULT NULL,
                                   p_argument13            IN   VARCHAR2 DEFAULT NULL,
                                   p_argument14            IN   VARCHAR2 DEFAULT NULL,
                                   p_argument15            IN   VARCHAR2 DEFAULT NULL,
                                   p_argument16            IN   VARCHAR2 DEFAULT NULL,
                                   p_argument17            IN   VARCHAR2 DEFAULT NULL,
                                   p_argument18            IN   VARCHAR2 DEFAULT NULL,
                                   p_argument19            IN   VARCHAR2 DEFAULT NULL,
                                   p_argument20            IN   VARCHAR2 DEFAULT NULL,
                                   --
                                   p_bc_ifc                IN   VARCHAR2,
                                   p_request_id            IN   NUMBER,
                                   --
                                   p_status               OUT   VARCHAR2,
                                   p_error_msg            OUT   VARCHAR2 ) IS

    TYPE r_arguments IS RECORD ( argument VARCHAR2(1000) );
    TYPE t_arguments IS TABLE OF r_arguments INDEX BY BINARY_INTEGER;
    v_arguments    t_arguments;

    v_credential_exists   VARCHAR2(1);

  BEGIN

    gv_bc_ifc := p_bc_ifc;
    gv_request_id := p_request_id;

    -- Se elimina el job y se vuelve a crear
    BEGIN

      dbms_scheduler.drop_job ( job_name => p_job_name,
                                force => true );

    EXCEPTION
      WHEN OTHERS THEN
        NULL; -- El job no existe

    END;

    -- Crea el job
    BEGIN

      -- 20240906
      gv_job_action := ajcl_bc_utils_pkg.get_env_variable_value_f ( p_variable => 'DB_BC_FOLDER' ) || gv_job;
      -- 20240906

      dbms_scheduler.create_job ( job_name => p_job_name,
                                  job_type => gv_job_type,
                                  job_action => gv_job_action,
                                  number_of_arguments => p_number_of_arguments,
                                  start_date => SYSDATE,
                                  enabled => FALSE,
                                  auto_drop => FALSE,
                                  comments => p_comments );

      -- Asigna la credencial al job para poder ejecutar .sh
      dbms_scheduler.set_attribute ( name => p_job_name,
                                     attribute => 'credential_name',
                                     value => gv_os_credential_name );

      -- Asigna la credencial al job para poder usar las vistas USER_SCHEDULER_JOB_RUN_DETAILS y USER_SCHEDULER_JOB_LOG               
      dbms_scheduler.set_attribute ( name => p_job_name,
                                     attribute => 'connect_credential_name',
                                     value => gv_connect_credential_name );

    EXCEPTION
      WHEN OTHERS THEN
        NULL;

    END;

    -- Copia los parametros a la tabla pl
    v_arguments(1).argument := p_argument1;
    v_arguments(2).argument := p_argument2;
    v_arguments(3).argument := p_argument3;
    v_arguments(4).argument := p_argument4;
    v_arguments(5).argument := p_argument5;
    v_arguments(6).argument := p_argument6;
    v_arguments(7).argument := p_argument7;
    v_arguments(8).argument := p_argument8;
    v_arguments(9).argument := p_argument9;
    v_arguments(10).argument := p_argument10;
    v_arguments(11).argument := p_argument11;
    v_arguments(12).argument := p_argument12;
    v_arguments(13).argument := p_argument13;
    v_arguments(14).argument := p_argument14;
    v_arguments(15).argument := p_argument15;
    v_arguments(16).argument := p_argument16;
    v_arguments(17).argument := p_argument17;
    v_arguments(18).argument := p_argument18;
    v_arguments(19).argument := p_argument19;
    v_arguments(20).argument := p_argument20;

    -- dbms_output.put_line ( 'p_number_of_arguments: ' || p_number_of_arguments );

    -- Se definen los parametros del job
    FOR i IN 1 .. p_number_of_arguments LOOP

      dbms_scheduler.set_job_argument_value(p_job_name,i,v_arguments(i).argument);
      -- dbms_output.put_line ('v_arguments(' || i || '): ' || v_arguments(i).argument);
      -- dbms_output.put_line ( 'i: ' || i );

    END LOOP;

    -- Ejecuta el job creado
    -- dbms_scheduler.enable( name => p_job_name );
    dbms_scheduler.run_job ( job_name => p_job_name, 
                             use_current_session => FALSE );

    COMMIT;

    p_status := 'S';

  EXCEPTION
    WHEN OTHERS THEN
      p_status := 'E';
      p_error_msg := SQLERRM;
      print_log ( 'Error create_and_run_job_p. Error: ' || SQLERRM );

  END create_and_run_job_p;

  PROCEDURE wait_for_job_p ( p_job_name                IN   VARCHAR2,
                             -- p_check_every_x_seconds   IN   NUMBER,
                             -- p_max_seconds_to_wait     IN   NUMBER,
                             --
                             -- 20240902
                             p_loader                  IN   VARCHAR2,
                             -- 20240902                             
                             p_bc_ifc                  IN   VARCHAR2,
                             p_request_id              IN   NUMBER,
                             --
                             p_status                 OUT   VARCHAR2,
                             p_error_msg              OUT   VARCHAR2 ) IS

    v_actual_date     DATE;
    v_log_id          NUMBER;
    v_status          USER_SCHEDULER_JOB_LOG.status%TYPE;
    v_additional_info USER_SCHEDULER_JOB_LOG.additional_info%TYPE;
    v_error_msg       USER_SCHEDULER_JOB_RUN_DETAILS.additional_info%TYPE;
    v_running         VARCHAR2(1);

  BEGIN                            

    gv_bc_ifc := p_bc_ifc;
    gv_request_id := p_request_id;

    v_actual_date := SYSDATE;

    -- Mientras no se superen los segundos maximos, se controla
    WHILE ( ( SYSDATE - v_actual_date ) * 24 * 60 * 60 <= gv_max_seconds_to_wait ) LOOP

      -- Se verifica si el job se esta ejecutando
      SELECT DECODE(COUNT(1),0,'N','Y')
        INTO v_running
        FROM USER_SCHEDULER_RUNNING_JOBS
       WHERE job_name = p_job_name;

      print_log ( 'v_running: ' || v_running );

      IF ( v_running = 'N' ) THEN

        EXIT;

      END IF;

      DBMS_LOCK.SLEEP(gv_check_every_x_seconds);

    END LOOP;

    -- Se verifica si aun se sigue ejecutando
    /*
    SELECT DECODE(COUNT(1),0,'N','Y')
      INTO v_running
      FROM USER_SCHEDULER_RUNNING_JOBS
     WHERE job_name = p_job_name;

    print_log ( 'v_running: ' || v_running );
    */

    -- Si se sigue ejecutando, se cancela
    IF ( v_running = 'Y' ) THEN

      dbms_scheduler.stop_job ( job_name => p_job_name );
      p_status := 'E';
      p_error_msg := 'The job timed out and was terminated by the administrator.';
      print_log ( 'The job timed out and was terminated by the administrator.' );

    ELSE 

      -- Termino la ejecucion, se obtiene el log_id de la ultima ejecucion
      SELECT MAX(log_id)
        INTO v_log_id
        FROM USER_SCHEDULER_JOB_LOG
       WHERE job_name = p_job_name;

      print_log ( 'v_log_id: ' || v_log_id );

      -- Se consulta su status
      SELECT status,
             additional_info
        INTO v_status,
             v_additional_info
        FROM USER_SCHEDULER_JOB_LOG
       WHERE log_id = v_log_id;

      print_log ( 'Original v_status: ' || v_status );
      print_log ( 'v_additional_info: ' || v_additional_info );

      -- Se consultan los posibles errores
      SELECT errors
        INTO v_error_msg
        FROM USER_SCHEDULER_JOB_RUN_DETAILS
       WHERE log_id = v_log_id;

      print_log ( 'v_error_msg: ' || v_error_msg );

      IF ( v_status IN ('SUCCEEDED','STOPPED') OR
           ( v_status = 'FAILED' AND v_additional_info LIKE '%manual slave run%' 
             -- 20240902
             AND p_loader = 'Y' 
             -- 20240902
           ) -- No es un error, es que se ejecuto en otra sesion diferente
         ) THEN

        p_status := 'S';
        p_error_msg := v_error_msg;

        -- Si entra por esta condicion, se considera SUCCESS
        IF ( v_status = 'FAILED' AND v_additional_info LIKE '%manual slave run%' 
             -- 20240902
             AND p_loader = 'Y' 
             -- 20240902
           ) THEN

          v_status := 'SUCCEEDED';

        END IF;

      ELSIF ( -- ( v_status IN ('SUCCEEDED','STOPPED') AND v_error_msg IS NOT NULL ) OR 
              ( v_status IN ('FAILED') ) ) THEN

        p_status := 'E';
        p_error_msg := v_error_msg;

      END IF;

      print_log ( 'Final v_status: ' || v_status );

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_status := 'E';
      p_error_msg := SQLERRM;
      print_log ( 'Error ajc_bc_scheduler_pkg.wait_for_job_p. Error: ' || SQLERRM );

  END wait_for_job_p;         

  PROCEDURE create_run_wait_job_p ( p_job_name              IN       VARCHAR2,
                                    -- Job Creation
                                    p_comments              IN       VARCHAR2,
                                    p_number_of_arguments   IN       NUMBER DEFAULT 2,
                                    p_argument1             IN       VARCHAR2 DEFAULT NULL, -- Reservado para poner path y nombre del sh del app 
                                                                                            -- si es loader siempre usar /u01/oracle/finupg5appl/xxajc/bin/AJCL_EXECUTE_CTL.sh
                                                                                            -- que arma y ejecuta el comando sqlldr
                                    p_argument2             IN       VARCHAR2 DEFAULT NULL, -- Reservado para poner nombre del .ctl en los casos que sea loader (control file)
                                    p_argument3             IN       VARCHAR2 DEFAULT NULL, -- Reservado para poner nombre del archivo de datos a cargar por el loader (data file)
                                    p_argument4             IN       VARCHAR2 DEFAULT NULL,
                                    p_argument5             IN       VARCHAR2 DEFAULT NULL,
                                    p_argument6             IN       VARCHAR2 DEFAULT NULL,
                                    p_argument7             IN       VARCHAR2 DEFAULT NULL,
                                    p_argument8             IN       VARCHAR2 DEFAULT NULL,
                                    p_argument9             IN       VARCHAR2 DEFAULT NULL,
                                    p_argument10            IN       VARCHAR2 DEFAULT NULL,
                                    p_argument11            IN       VARCHAR2 DEFAULT NULL,
                                    p_argument12            IN       VARCHAR2 DEFAULT NULL,
                                    p_argument13            IN       VARCHAR2 DEFAULT NULL,
                                    p_argument14            IN       VARCHAR2 DEFAULT NULL,
                                    p_argument15            IN       VARCHAR2 DEFAULT NULL,
                                    p_argument16            IN       VARCHAR2 DEFAULT NULL,
                                    p_argument17            IN       VARCHAR2 DEFAULT NULL,
                                    p_argument18            IN       VARCHAR2 DEFAULT NULL,
                                    p_argument19            IN       VARCHAR2 DEFAULT NULL,
                                    p_argument20            IN       VARCHAR2 DEFAULT NULL,
                                    -- Job Wait
                                    -- p_check_every_x_seconds   IN   NUMBER,
                                    -- p_max_seconds_to_wait     IN   NUMBER,
                                    --
                                    p_bc_ifc                IN       VARCHAR2,
                                    p_request_id            IN       NUMBER,
                                    p_log_seq               IN OUT   NUMBER,
                                    --
                                    p_status               OUT       VARCHAR2,
                                    p_error_msg            OUT       VARCHAR2 ) IS

    -- 20240902
    v_loader           VARCHAR2(1);
    -- 20240902

    e_create_and_run   EXCEPTION;
    e_wait_for_job     EXCEPTION;

  BEGIN

    gv_bc_ifc := p_bc_ifc;
    gv_request_id := p_request_id;
    gv_log_seq := p_log_seq;

    create_and_run_job_p ( p_job_name => p_job_name,
                           p_comments => p_comments,
                           p_number_of_arguments => p_number_of_arguments,
                           p_argument1 => p_argument1,
                           p_argument2 => p_argument2,
                           p_argument3 => p_argument3,
                           p_argument4 => p_argument4,
                           p_argument5 => p_argument5,
                           p_argument6 => p_argument6,
                           p_argument7 => p_argument7,
                           p_argument8 => p_argument8,
                           p_argument9 => p_argument9,
                           p_argument10 => p_argument10,
                           p_argument11 => p_argument11,
                           p_argument12 => p_argument12,
                           p_argument13 => p_argument13,
                           p_argument14 => p_argument14,
                           p_argument15 => p_argument15,
                           p_argument16 => p_argument16,
                           p_argument17 => p_argument17,
                           p_argument18 => p_argument18,
                           p_argument19 => p_argument19,
                           p_argument20 => p_argument20,
                           --
                           p_bc_ifc => p_bc_ifc,
                           p_request_id => p_request_id,
                           --
                           p_status => p_status,
                           p_error_msg => p_error_msg );

    IF ( p_status != 'S' ) THEN

      RAISE e_create_and_run;

    END IF;

    DBMS_LOCK.SLEEP(10);

    -- 20240902
    -- Se determina si es un loader o no
    SELECT DECODE(COUNT(1),0,'N','Y')
      INTO v_loader
      FROM dual
     WHERE p_argument1 LIKE '%AJCL_EXECUTE_CTL.sh';
    -- 20240902

    wait_for_job_p ( p_job_name => p_job_name,
                     -- p_check_every_x_seconds => gv_check_every_x_seconds,
                     -- p_max_seconds_to_wait => gv_max_seconds_to_wait,
                     --
                     -- 20240902
                     p_loader => v_loader,
                     -- 20240902
                     p_bc_ifc => p_bc_ifc,
                     p_request_id => p_request_id,
                     --
                     p_status => p_status,
                     p_error_msg => p_error_msg );

    IF ( p_status != 'S' ) THEN

      RAISE e_wait_for_job;

    END IF;

    p_log_seq := gv_log_seq;

  EXCEPTION
    WHEN e_create_and_run THEN
      print_log ( 'Error calling ajc_bc_scheduler_pkg.create_and_run_job_p. Error: ' || SQLERRM ); 
      print_log ( 'p_error_msg: ' || p_error_msg ); 
      p_log_seq := gv_log_seq;
    WHEN e_wait_for_job THEN
      print_log ( 'Error calling ajc_bc_scheduler_pkg.wait_for_job_p. Error: ' || SQLERRM );   
      print_log ( 'p_error_msg: ' || p_error_msg ); 
      p_log_seq := gv_log_seq;
    WHEN OTHERS THEN
      print_log ( 'Error general ajc_bc_scheduler_pkg.create_run_wait_job_p. Error: ' || SQLERRM );   
      p_log_seq := gv_log_seq;

  END create_run_wait_job_p;

END ajc_bc_scheduler_pkg;
