Prompt drop TABLE ADMIN_MSG;
ALTER TABLE ADMIN_MSG
 DROP PRIMARY KEY CASCADE
/

DROP TABLE ADMIN_MSG CASCADE CONSTRAINTS
/

Prompt Table ADMIN_MSG;
--
-- ADMIN_MSG  (Table) 
--
CREATE TABLE ADMIN_MSG
(
  ID         NUMBER(12)                         NOT NULL,
  THREAD_ID  NUMBER(12)                         NOT NULL,
  SRC_ID     VARCHAR2(64 BYTE)                  NOT NULL,
  SRC_TYPE   NUMBER(3)                          NOT NULL,
  DEST_ID    VARCHAR2(64 BYTE)                  NOT NULL,
  SUBJECT    VARCHAR2(200 BYTE)                 NOT NULL,
  BODY       VARCHAR2(2000 BYTE),
  STATUS     VARCHAR2(2 BYTE)                   NOT NULL,
  TIMESTAMP  DATE                               NOT NULL,
  FLAGS      NUMBER(18)                         NOT NULL,
  VERSION    NUMBER(5)                          NOT NULL,
  PEREX      VARCHAR2(1024 CHAR)
) TABLESPACE tables_arch
LOGGING 
NOCOMPRESS 
NOCACHE
NOPARALLEL
MONITORING
/


Prompt Index IDX_ADMIN_MSG_PK;
--
-- IDX_ADMIN_MSG_PK  (Index) 
--
CREATE UNIQUE INDEX IDX_ADMIN_MSG_PK ON ADMIN_MSG
(ID)
LOGGING
NOPARALLEL
/


Prompt Index IDX_ADMIN_MSG_SRC;
--
-- IDX_ADMIN_MSG_SRC  (Index) 
--
CREATE INDEX IDX_ADMIN_MSG_SRC ON ADMIN_MSG
(SRC_ID)
LOGGING
NOPARALLEL
/


Prompt Index IDX_ADMIN_MSG_DEST;
--
-- IDX_ADMIN_MSG_DEST  (Index) 
--
CREATE INDEX IDX_ADMIN_MSG_DEST ON ADMIN_MSG
(DEST_ID)
LOGGING
NOPARALLEL
/


-- 
-- Non Foreign Key Constraints for Table ADMIN_MSG 
-- 
Prompt Non-Foreign Key Constraints on Table ADMIN_MSG;
ALTER TABLE ADMIN_MSG ADD (
  CONSTRAINT IDX_ADMIN_MSG_PK
  PRIMARY KEY
  (ID)
  USING INDEX IDX_ADMIN_MSG_PK
  ENABLE VALIDATE)
/
