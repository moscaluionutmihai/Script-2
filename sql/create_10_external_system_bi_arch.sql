Prompt drop TABLE EXTERNAL_SYSTEM_BI;
ALTER TABLE EXTERNAL_SYSTEM_BI
 DROP PRIMARY KEY CASCADE
/

DROP TABLE EXTERNAL_SYSTEM_BI CASCADE CONSTRAINTS
/

Prompt Table EXTERNAL_SYSTEM_BI;
--
-- EXTERNAL_SYSTEM_BI  (Table) 
--
CREATE TABLE EXTERNAL_SYSTEM_BI
(
  ID                      NUMBER(18)            NOT NULL,
  TXN_TYPE                VARCHAR2(10 BYTE)     NOT NULL,
  TXN_OPERATION_TYPE      VARCHAR2(20 BYTE)     NOT NULL,
  TXN_ID                  NUMBER                NOT NULL,
  EXT_REF_STATUS          VARCHAR2(20 BYTE)     DEFAULT 'SUCCESS'             NOT NULL,
  EXT_REF_RESULT_IS_SEND  CHAR(1 BYTE)          DEFAULT 'N'                   NOT NULL,
  EXT_REF_RESULT_CODE     VARCHAR2(50 BYTE),
  EXT_REF_RESULT_COMMENT  VARCHAR2(500 BYTE),
  EXT_REF_SENT_PARAM      VARCHAR2(1500 BYTE),
  EXT_REF_RECEIVED_PARAM  VARCHAR2(2500 BYTE)
) TABLESPACE tables_arch
LOGGING 
NOCOMPRESS 
NOCACHE
NOPARALLEL
MONITORING
/

COMMENT ON COLUMN EXTERNAL_SYSTEM_BI.TXN_TYPE IS 'possible values are billing , auth'
/

COMMENT ON COLUMN EXTERNAL_SYSTEM_BI.TXN_OPERATION_TYPE IS 'possible values are authverifysubscriber, authgetrenewaloffor, authverifyoffer,BILLREGISTERSTANDARTRENEWAL, BILLREGISTERAUTOMATICRENEWAL'
/

COMMENT ON COLUMN EXTERNAL_SYSTEM_BI.EXT_REF_STATUS IS 'possible values are SUCCUSS , FAIL'
/



Prompt Index PK_EXT_SYS_BI_ID;
--
-- PK_EXT_SYS_BI_ID  (Index) 
--
CREATE UNIQUE INDEX PK_EXT_SYS_BI_ID ON EXTERNAL_SYSTEM_BI
(ID)
LOGGING
NOPARALLEL
/


Prompt Index IDX_EXT_SYS_BI_PARAM;
--
-- IDX_EXT_SYS_BI_PARAM  (Index) 
--
CREATE INDEX IDX_EXT_SYS_BI_PARAM ON EXTERNAL_SYSTEM_BI
(TXN_ID, EXT_REF_SENT_PARAM, EXT_REF_RECEIVED_PARAM)
LOGGING
NOPARALLEL
/


-- 
-- Non Foreign Key Constraints for Table EXTERNAL_SYSTEM_BI 
-- 
Prompt Non-Foreign Key Constraints on Table EXTERNAL_SYSTEM_BI;
ALTER TABLE EXTERNAL_SYSTEM_BI ADD (
  CONSTRAINT PK_EXT_SYS_BI_ID
  PRIMARY KEY
  (ID)
  USING INDEX PK_EXT_SYS_BI_ID
  ENABLE VALIDATE)
/
