Prompt drop TABLE AUDIT_TRAIL;
ALTER TABLE AUDIT_TRAIL
 DROP PRIMARY KEY CASCADE
/

DROP TABLE AUDIT_TRAIL CASCADE CONSTRAINTS
/

Prompt Table AUDIT_TRAIL;
--
-- AUDIT_TRAIL  (Table) 
--
CREATE TABLE AUDIT_TRAIL
(
  ID           NUMBER(18)                       NOT NULL,
  TXN_ID       NUMBER(18),
  CAT          VARCHAR2(64 BYTE)                NOT NULL,
  SUBCAT       VARCHAR2(64 BYTE),
  STATUS       VARCHAR2(16 BYTE)                NOT NULL,
  TIMESTAMP    DATE                             NOT NULL,
  CHANNEL      VARCHAR2(16 BYTE)                NOT NULL,
  TARGET       VARCHAR2(64 BYTE),
  TARGET_TYPE  NUMBER(3),
  SUBTARGET    VARCHAR2(64 BYTE),
  SRC          VARCHAR2(64 BYTE)                NOT NULL,
  SRC_TYPE     NUMBER(3)                        NOT NULL,
  IP_ADDR      VARCHAR2(15 BYTE),
  FLAGS        NUMBER(18)                       NOT NULL,
  VERSION      NUMBER(4)                        NOT NULL
) TABLESPACE tables_arch
LOGGING 
NOCOMPRESS 
NOCACHE
NOPARALLEL
MONITORING
/


Prompt Index IDX_AUDIT_TRAIL_PK;
--
-- IDX_AUDIT_TRAIL_PK  (Index) 
--
CREATE UNIQUE INDEX IDX_AUDIT_TRAIL_PK ON AUDIT_TRAIL
(ID)
LOGGING
NOPARALLEL
/


-- 
-- Non Foreign Key Constraints for Table AUDIT_TRAIL 
-- 
Prompt Non-Foreign Key Constraints on Table AUDIT_TRAIL;
ALTER TABLE AUDIT_TRAIL ADD (
  CONSTRAINT IDX_AUDIT_TRAIL_PK
  PRIMARY KEY
  (ID)
  USING INDEX IDX_AUDIT_TRAIL_PK
  ENABLE VALIDATE)
/
