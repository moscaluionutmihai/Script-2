Prompt drop TABLE BILL_TXN_TAX;
ALTER TABLE BILL_TXN_TAX
 DROP PRIMARY KEY CASCADE
/

DROP TABLE BILL_TXN_TAX CASCADE CONSTRAINTS
/

Prompt Table BILL_TXN_TAX;
--
-- BILL_TXN_TAX  (Table) 
--
CREATE TABLE BILL_TXN_TAX
(
  TXN_ID           NUMBER                       NOT NULL,
  SEQ_ID           NUMBER(3)                    NOT NULL,
  TAX_TYPE         NUMBER(3),
  TAX              NUMBER                       NOT NULL,
  VERSION          NUMBER                       DEFAULT 0,
  TAX_DESCRIPTION  VARCHAR2(20 BYTE),
  TAX_RATE         NUMBER CONSTRAINT NN_BILL_TXN_TAX_RATE NOT NULL
) TABLESPACE tables_arch
LOGGING 
NOCOMPRESS 
NOCACHE
NOPARALLEL
MONITORING
/

COMMENT ON COLUMN BILL_TXN_TAX.TAX_TYPE IS 'inclusive or exclusive'
/

COMMENT ON COLUMN BILL_TXN_TAX.TAX_RATE IS 'if tax_rate is 0 get tax rate from country_vat'
/



--  There is no statement for index CANAL_TUNE.SYS_C0014127.
--  The object is created when the parent object is created.

-- 
-- Non Foreign Key Constraints for Table BILL_TXN_TAX 
-- 
Prompt Non-Foreign Key Constraints on Table BILL_TXN_TAX;
ALTER TABLE BILL_TXN_TAX ADD (
  PRIMARY KEY
  (TXN_ID)
  ENABLE VALIDATE)
/

-- 
-- Foreign Key Constraints for Table BILL_TXN_TAX 
-- 
Prompt Foreign Key Constraints on Table BILL_TXN_TAX;
ALTER TABLE BILL_TXN_TAX ADD (
  CONSTRAINT IDX_BILL_TXN_TAX_FK 
  FOREIGN KEY (TXN_ID, SEQ_ID) 
  REFERENCES BILL_TXN (TXN_ID,SEQ_ID)
  ENABLE NOVALIDATE)
/
