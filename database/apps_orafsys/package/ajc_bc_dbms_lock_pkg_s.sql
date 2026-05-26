CREATE OR REPLACE PACKAGE ajc_bc_dbms_lock_pkg is

-- Creation: SBANCHIERI 23-AUG-2023

  

  gv_timeout   INTEGER;



  PROCEDURE lock_p ( p_process_name      IN   VARCHAR2,

                     p_id_lock          OUT   VARCHAR2,

                     p_request_status   OUT   VARCHAR2 );



  PROCEDURE release_p ( p_id_lock           IN   VARCHAR2,

                        p_release_status   OUT   VARCHAR2 );



  -- Se usa desde Jenkins

  PROCEDURE kill_session_p ( p_process_name   IN   VARCHAR2 );



END ajc_bc_dbms_lock_pkg;
