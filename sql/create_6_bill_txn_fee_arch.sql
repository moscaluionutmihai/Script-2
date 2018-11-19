Prompt drop TABLE BILL_TXN_FEE;
ALTER TABLE BILL_TXN_FEE
 DROP PRIMARY KEY CASCADE
/

DROP TABLE BILL_TXN_FEE CASCADE CONSTRAINTS
/

Prompt Table BILL_TXN_FEE;
--
-- BILL_TXN_FEE  (Table) 
--
CREATE TABLE BILL_TXN_FEE
(
  TXN_ID                     INTEGER            NOT NULL,
  SEQ_ID                     NUMBER(3)          NOT NULL,
  MNO_FEE                    NUMBER,
  MNO_TAXABLE_FEE            NUMBER,
  MNO_TAX                    NUMBER,
  BANK_FEE                   NUMBER,
  BANK_TAXABLE_FEE           NUMBER,
  BANK_TAX                   NUMBER,
  VALUE0                     NUMBER,
  VALUE1                     NUMBER,
  VALUE2                     NUMBER,
  VALUE3                     NUMBER,
  VERSION                    NUMBER(18),
  FEE_TYPE                   VARCHAR2(64 BYTE),
  FEE_TYPE_SRC               VARCHAR2(128 BYTE),
  FEE_TYPE_DEST              VARCHAR2(128 BYTE),
  SRC_FEE_NOT_CHARGED        NUMBER,
  DEST_FEE_NOT_CHARGED       NUMBER,
  FEE_TYPE_NOT_CHARGED       VARCHAR2(64 BYTE),
  FEE_TYPE_SRC_NOT_CHARGED   VARCHAR2(128 BYTE),
  FEE_TYPE_DEST_NOT_CHARGED  VARCHAR2(128 BYTE),
  SPLIT_INDIRECT_SUMMARY     VARCHAR2(128 CHAR)
) TABLESPACE tables_arch
LOGGING 
NOCOMPRESS 
NOCACHE
NOPARALLEL
MONITORING
/


Prompt Index IDX_BILL_TXN_FEE_PK;
--
-- IDX_BILL_TXN_FEE_PK  (Index) 
--
CREATE UNIQUE INDEX IDX_BILL_TXN_FEE_PK ON BILL_TXN_FEE
(TXN_ID)
LOGGING
NOPARALLEL
/


-- 
-- Non Foreign Key Constraints for Table BILL_TXN_FEE 
-- 
Prompt Non-Foreign Key Constraints on Table BILL_TXN_FEE;
ALTER TABLE BILL_TXN_FEE ADD (
  CONSTRAINT IDX_BILL_TXN_FEE_PK
  PRIMARY KEY
  (TXN_ID)
  USING INDEX IDX_BILL_TXN_FEE_PK
  ENABLE VALIDATE)
/

-- 
-- Foreign Key Constraints for Table BILL_TXN_FEE 
-- 
Prompt Foreign Key Constraints on Table BILL_TXN_FEE;
ALTER TABLE BILL_TXN_FEE ADD (
  CONSTRAINT IDX_BILL_TXN_FEE_FK 
  FOREIGN KEY (TXN_ID, SEQ_ID) 
  REFERENCES BILL_TXN (TXN_ID,SEQ_ID)
  ENABLE NOVALIDATE)
/
