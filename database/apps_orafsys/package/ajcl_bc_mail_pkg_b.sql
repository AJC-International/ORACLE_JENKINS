PACKAGE BODY ajcl_bc_mail_pkg IS
  
  PROCEDURE mail_files ( p_from_mail          VARCHAR2,
                         p_to_mail            VARCHAR2,
                         p_cc_mail            VARCHAR2,
                         p_subject            VARCHAR2,
                         p_message            VARCHAR2,
                         p_oracle_directory   VARCHAR2,
                         p_filename           VARCHAR2, 
                         p_attach_filename    VARCHAR2 ) IS
    
    v_smtp_server         VARCHAR2(100) := 'smtp.ajc.bz';
    v_smtp_server_port    NUMBER := 25;
    v_directory_name      VARCHAR2(100);
    v_file_name           VARCHAR2(100);
    v_mesg                VARCHAR2(32767);
    v_conn                UTL_SMTP.CONNECTION;
    CRLF                  CONSTANT varchar2(10) := utl_tcp.CRLF;
    BOUNDARY              CONSTANT varchar2(256) := '-----7D81B75CCC90D2974F7A1CBD';
    FIRST_BOUNDARY        CONSTANT varchar2(256) := '--'||BOUNDARY||CRLF;
    MULTIPART_MIME_TYPE   CONSTANT varchar2(256) := 'multipart/mixed; boundary="'||BOUNDARY||'"';
    MIME_TYPE             CONSTANT varchar2(255) := 'text/html';

    ---------------------------------------------------------------------------------------------------------------------------

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
                                 p_mime_type    IN VARCHAR2 DEFAULT 'text/plain',
                                 p_inline       IN BOOLEAN DEFAULT false,
                                 p_filename     IN VARCHAR2 DEFAULT null,
                                 p_transfer_enc IN VARCHAR2 DEFAULT null ) IS
    BEGIN

      utl_smtp.write_data(p_conn, FIRST_BOUNDARY); 
      write_mime_header(p_conn,'Content-Type', p_mime_type);
      write_mime_header(p_conn,'Content-Transfer-Encoding','base64');

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

    BEGIN

      begin_attachment ( p_conn => p_conn,
                         p_mime_type => p_mime_type,
                         p_inline => FALSE,
                         p_filename => p_attach_filename,
                         p_transfer_enc => 'base64' );
      BEGIN

        v_bfile := BFILENAME(p_oracle_directory, p_file_name);
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
      end_attachment(p_conn => p_conn);

    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        end_attachment(p_conn => p_conn);
        DBMS_LOB.FILECLOSE(v_bfile);

    END binary_attachment;

  -- Main
  BEGIN

     v_conn:= utl_smtp.OPEN_CONNECTION( v_smtp_server, v_smtp_server_port );

     utl_smtp.HELO( v_conn, v_smtp_server );
     utl_smtp.MAIL( v_conn, p_from_mail );
     utl_smtp.RCPT( v_conn, p_to_mail );
     utl_smtp.RCPT( v_conn, p_cc_mail );
     utl_smtp.OPEN_DATA ( v_conn );

     utl_smtp.write_data(v_conn,'Subject: ' || p_subject || utl_tcp.crlf);    
     utl_smtp.write_data(v_conn,'Date: ' || TO_CHAR(SYSDATE,'dd mon yy hh24:mi:ss') || utl_tcp.crlf);
     utl_smtp.write_data(v_conn,'From: ' || p_from_mail || utl_tcp.crlf);    
     utl_smtp.write_data(v_conn,'To: "' || p_to_mail || '" <' || p_to_mail || '>' || utl_tcp.crlf);
     utl_smtp.write_data(v_conn,'CC: "' || p_cc_mail || '" <' || p_cc_mail || '>' || utl_tcp.crlf);

     utl_smtp.write_data(v_conn, 'Content-Type' || ': ' || MULTIPART_MIME_TYPE || utl_tcp.CRLF );
     utl_smtp.write_data(v_conn,CRLF);

     -- Body
     utl_smtp.write_data(v_conn, FIRST_BOUNDARY);
     utl_smtp.write_data(v_conn, 'Content-Type' || ': ' || MIME_TYPE || utl_tcp.CRLF );

     utl_smtp.write_data(v_conn, UTL_TCP.CRLF );
     utl_smtp.write_data(v_conn, p_message ); 
     utl_smtp.write_data(v_conn, UTL_TCP.CRLF );
     -- Body

     -- Add Attach
     binary_attachment ( p_conn => v_conn,
                         p_file_name => p_filename || '.csv',
                         p_mime_type => 'application/excel',
                         p_attach_filename => p_attach_filename );

     -- Send email
     UTL_SMTP.CLOSE_DATA( v_conn );
     UTL_SMTP.QUIT( v_conn );

  END mail_files;

END ajcl_bc_mail_pkg;
