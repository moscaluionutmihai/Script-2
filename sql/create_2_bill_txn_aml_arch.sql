Prompt drop TABLE BILL_TXN_AML;
ALTER TABLE BILL_TXN_AML
 DROP PRIMARY KEY CASCADE
/

DROP TABLE BILL_TXN_AML CASCADE CONSTRAINTS
/

Prompt Table BILL_TXN_AML;
--
-- BILL_TXN_AML  (Table) 
--
CREATE TABLE BILL_TXN_AML
(
  TXN_ID               INTEGER                  NOT NULL,
  SEQ_ID               NUMBER(3)                NOT NULL,
  TIMESTAMP            DATE                     NOT NULL,
  TYPE                 VARCHAR2(20 BYTE)        NOT NULL,
  PRICE                NUMBER(18,6)             NOT NULL,
  PRICE_AML            NUMBER(18,6)             NOT NULL,
  SRC_SUR_ID           VARCHAR2(64 BYTE)        NOT NULL,
  SRC_TYPE             NUMBER(3)                NOT NULL,
  SRC_MSISDN           VARCHAR2(16 BYTE),
  SRC_MNO              NUMBER(3),
  SRC_BANK             NUMBER                   NOT NULL,
  SRC_KYC_CAT          NUMBER,
  DEST_SUR_ID          VARCHAR2(64 BYTE)        NOT NULL,
  DEST_TYPE            NUMBER(3)                NOT NULL,
  DEST_MSISDN          VARCHAR2(16 BYTE),
  DEST_MNO             NUMBER(3),
  DEST_BANK            NUMBER,
  DEST_KYC_CAT         NUMBER,
  CHANNEL              VARCHAR2(16 BYTE)        NOT NULL,
  FLAGS                NUMBER(18),
  VERSION              NUMBER(18)               NOT NULL,
  BILL_SRVC_ID         VARCHAR2(64 BYTE)        NOT NULL,
  FEE_REVERSAL_TXN_ID  INTEGER
) TABLESPACE tables_arch
LOGGING 
NOCOMPRESS 
NOCACHE
NOPARALLEL
MONITORING
/


Prompt Index IDX_BILL_TXN_AML_PK;
--
-- IDX_BILL_TXN_AML_PK  (Index) 
--
CREATE UNIQUE INDEX IDX_BILL_TXN_AML_PK ON BILL_TXN_AML
(TXN_ID)
LOGGING
NOPARALLEL
/


-- 
-- Non Foreign Key Constraints for Table BILL_TXN_AML 
-- 
Prompt Non-Foreign Key Constraints on Table BILL_TXN_AML;
ALTER TABLE BILL_TXN_AML ADD (
  CONSTRAINT IDX_BILL_TXN_AML_PK
  PRIMARY KEY
  (TXN_ID)
  USING INDEX IDX_BILL_TXN_AML_PK
  ENABLE VALIDATE)
/

-- 
-- Foreign Key Constraints for Table BILL_TXN_AML 
-- 
Prompt Foreign Key Constraints on Table BILL_TXN_AML;
ALTER TABLE BILL_TXN_AML ADD (
  CONSTRAINT IDX_BILL_TXN_AML_FK 
  FOREIGN KEY (TXN_ID, SEQ_ID) 
  REFERENCES BILL_TXN (TXN_ID,SEQ_ID)
  ENABLE NOVALIDATE)
/
