PACKAGE BODY ajc_bc_dbms_lock_pkg is
-- Creation: SBANCHIERI 23-AUG-2023
  
  PROCEDURE lock_p ( p_process_name      IN   VARCHAR2,
                     p_id_lock          OUT   VARCHAR2,
                     p_request_status   OUT   VARCHAR2 ) IS
  
    v_status   INTEGER;

  BEGIN

    gv_timeout := TO_NUMBER(ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'LOCK_TIMEOUT_IN_SECONDS' ));

    DBMS_LOCK.allocate_unique( lockname => p_process_name,
                               lockhandle => p_id_lock );

    -- dbms_output.put_line ('lock_p p_id_lock: ' || p_id_lock);

    v_status := DBMS_LOCK.request ( lockhandle => p_id_lock,
                                    lockmode => 6, -- Exclusive
                                    timeout => gv_timeout );

    -- dbms_output.put_line ('lock_p v_status: ' || v_status);

    SELECT DECODE(v_status,0,'success',
                           1,'timeout',
                           2,'deadlock',
                           3,'parameter error',
                           4,'already own lock specified by id or lockhandle',
                           5,'illegal lockhandle')
      INTO p_request_status
      FROM DUAL;

    IF ( p_request_status = 'success' ) THEN

        INSERT 
          INTO ajc_bc_locks
             ( process_name,
               lock_id )
      VALUES ( p_process_name,
               p_id_lock );

      COMMIT;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_request_status := 'error general';
      -- RAISE_APPLICATION_ERROR(-20343, 'General Error: ' || SQLERRM);

  END lock_p;

  PROCEDURE release_p ( p_id_lock           IN   VARCHAR2,
                        p_release_status   OUT   VARCHAR2 ) IS

    v_status   INTEGER;

  BEGIN

    IF ( p_id_lock IS NOT NULL ) THEN

      v_status := DBMS_LOCK.release(p_id_lock);

      -- dbms_output.put_line ('release_p v_status: ' || v_status);

      SELECT DECODE(v_status,0,'success',
                             3,'parameter error',
                             4,'dont own lock specified by id or lockhandle',
                             5,'illegal lockhandle')
        INTO p_release_status
        FROM DUAL;

      IF ( p_release_status = 'success' ) THEN

        DELETE ajc_bc_locks
         WHERE lock_id = p_id_lock;

        COMMIT;

      END IF;

    END IF;

  EXCEPTION
    WHEN OTHERS THEN
      p_release_status := 'error general';
      -- RAISE_APPLICATION_ERROR(-20343, 'General Error: ' || SQLERRM);

  END release_p;

  PROCEDURE kill_session_p ( p_process_name   IN   VARCHAR2 ) IS

    v_sid               NUMBER;
    v_serial            NUMBER;
    v_lock_id           VARCHAR2(200);
    v_elapsed_seconds   NUMBER;
    v_dynamic_sql       VARCHAR2(2000);

    e_waiting           EXCEPTION;

  BEGIN

    gv_timeout := TO_NUMBER(ajcl_bc_ws_utils_pkg.get_parameter_f ( p_parameter_code => 'LOCK_TIMEOUT_IN_SECONDS' ));

    SELECT d.sid,
           d.serial#, 
           bcl.lock_id,
           l.ctime
      INTO v_sid,
           v_serial,
           v_lock_id,
           v_elapsed_seconds
      FROM v$session d,
           ajc_bc_locks bcl,
           V$LOCK l
     WHERE d.sid = l.sid
       AND l.id1 = SUBSTR(bcl.lock_id,1,10)
       AND bcl.process_name = TRIM(p_process_name);

    -- dbms_output.put_line ('v_sid: ' || v_sid);
    -- dbms_output.put_line ('v_serial: ' || v_serial);
    -- dbms_output.put_line ('v_lock_id: ' || v_lock_id);

    IF ( v_elapsed_seconds < gv_timeout ) THEN

      RAISE e_waiting;

    END IF;

    v_dynamic_sql := 'ALTER SYSTEM KILL SESSION ''' || v_sid || ',' || v_serial || ''' IMMEDIATE';
    -- dbms_output.put_line ('v_dynamic_sql: ' || v_dynamic_sql);

    EXECUTE IMMEDIATE v_dynamic_sql;

    DELETE ajc_bc_locks
     WHERE lock_id = v_lock_id;

    COMMIT;

  EXCEPTION
    WHEN e_waiting THEN
      RAISE_APPLICATION_ERROR(-20343, 'Process ' || p_process_name || ' (elapsed seconds: ' || v_elapsed_seconds || ') cannot be canceled because it has not yet exceeded the defined max waiting seconds (' || gv_timeout || ').');
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20343, 'Process ' || p_process_name || ' not found.');
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(-20343, SQLERRM);

  END kill_session_p;

END ajc_bc_dbms_lock_pkg;
