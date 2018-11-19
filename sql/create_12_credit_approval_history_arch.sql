Prompt drop TABLE CREDIT_APPROVAL_HISTORY;
ALTER TABLE CREDIT_APPROVAL_HISTORY
 DROP PRIMARY KEY CASCADE
/

DROP TABLE CREDIT_APPROVAL_HISTORY CASCADE CONSTRAINTS
/

Prompt Table CREDIT_APPROVAL_HISTORY;
--
-- CREDIT_APPROVAL_HISTORY  (Table) 
--
CREATE TABLE CREDIT_APPROVAL_HISTORY
(
  ID                  NUMBER                    NOT NULL,
  TXN_ID              NUMBER                    NOT NULL,
  TXN_OPERATION_TYPE  VARCHAR2(20 BYTE)         NOT NULL,
  STATUS              VARCHAR2(20 BYTE)         NOT NULL,
  CREATED_BY          VARCHAR2(64 BYTE)         NOT NULL,
  CREATE_TIME         DATE                      NOT NULL,
  CREATE_EXP          VARCHAR2(100 BYTE),
  APPROVED_BY         VARCHAR2(64 BYTE),
  APPROVE_TIME        DATE,
  APPROVE_EXP         VARCHAR2(100 CHAR),
  VERSION             NUMBER(12)                DEFAULT 0
) TABLESPACE tables_arch
LOGGING 
NOCOMPRESS 
NOCACHE
NOPARALLEL
MONITORING
/


--  There is no statement for index CANAL_TUNE.SYS_C0014238.
--  The object is created when the parent object is created.

--  There is no statement for index CANAL_TUNE.SYS_C0014237.
--  The object is created when the parent object is created.

-- 
-- Non Foreign Key Constraints for Table CREDIT_APPROVAL_HISTORY 
-- 
Prompt Non-Foreign Key Constraints on Table CREDIT_APPROVAL_HISTORY;
ALTER TABLE CREDIT_APPROVAL_HISTORY ADD (
  PRIMARY KEY
  (ID)
  ENABLE VALIDATE,
  UNIQUE (TXN_ID)
  ENABLE VALIDATE)
/
