PACKAGE ajc_bc_scheduler_pkg IS
-- Creation: SBANCHIERI 23-AUG-2023
  
  gv_bc_ifc                    VARCHAR2(200);
  gv_request_id                NUMBER := 0;
  gv_log_seq                   NUMBER;

  gv_job_type                  VARCHAR2(100) := 'EXECUTABLE';

  -- .sh que esta en el db server, se conecta al app y ejecuta .sh (FTP, archive, rename) o el .sh que arma la sentencia del loader
  gv_job                       VARCHAR2(100) := 'app_job_manager.sh';
  -- Se obtiene la carpeta segun la db en tiempo de ejecucion y se concatena el valor de gv_job
  gv_job_action                VARCHAR2(100);

  gv_check_every_x_seconds     NUMBER := 10;
  gv_max_seconds_to_wait       NUMBER := 1800; -- 30 minutos

  gv_os_credential_name        VARCHAR2(100) := 'oracle_os_user';
  gv_connect_credential_name   VARCHAR2(100) := 'oracle_apps_orafsys';

  PROCEDURE create_and_run_job_p ( p_job_name              IN   VARCHAR2,
                                   p_comments              IN   VARCHAR2,
                                   p_number_of_arguments   IN   NUMBER,
                                   --
                                   p_argument1             IN   VARCHAR2 DEFAULT NULL, -- Reservado para poner path y nombre del sh del app 
                                                                                       -- si es loader siempre usar /u01/oracle/finupg5appl/xxajc/bin/AJCL_EXECUTE_CTL.sh
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
                                   p_error_msg            OUT   VARCHAR2 );

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
                             p_error_msg              OUT   VARCHAR2 );

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
                                    p_error_msg            OUT       VARCHAR2 );                             

END ajc_bc_scheduler_pkg;
