CREATE OR REPLACE PACKAGE ajc_bc_mail_pkg IS

  

  PROCEDURE mail_files ( p_from_mail          VARCHAR2,

                         p_to_mail            VARCHAR2,

                         p_cc_mail            VARCHAR2,

                         p_subject            VARCHAR2,

                         p_message            VARCHAR2,

                         p_oracle_directory   VARCHAR2,

                         p_request_id         NUMBER,

                         p_ifc                VARCHAR2,

                         p_attach_filename    VARCHAR2 );



END ajc_bc_mail_pkg;
