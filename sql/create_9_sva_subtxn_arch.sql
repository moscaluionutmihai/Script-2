Prompt drop TABLE SVA_SUBTXN;
ALTER TABLE SVA_SUBTXN
 DROP PRIMARY KEY CASCADE
/

DROP TABLE SVA_SUBTXN CASCADE CONSTRAINTS
/

Prompt Table SVA_SUBTXN;
--
-- SVA_SUBTXN  (Table) 
--
CREATE TABLE SVA_SUBTXN
(
  TXN_ID            NUMBER                      NOT NULL,
  SEQ_ID            NUMBER(3)                   NOT NULL,
  TIMESTAMP         TIMESTAMP(6)                NOT NULL,
  STATUS            VARCHAR2(10 BYTE)           NOT NULL,
  TYPE              VARCHAR2(20 BYTE)           NOT NULL,
  ACCOUNT_ID        VARCHAR2(64 BYTE)           NOT NULL,
  PRICE             NUMBER(18,6)                NOT NULL,
  PRICE_CRNCY       VARCHAR2(3 BYTE)            NOT NULL,
  PREVIOUS_BALANCE  NUMBER(18,6),
  FREETEXT          VARCHAR2(128 BYTE),
  VERSION           NUMBER(18),
  BANK_ID           NUMBER                      NOT NULL,
  RING_FENCE        NUMBER                      NOT NULL,
  WALLET_TYPE       NUMBER(5)                   NOT NULL
) TABLESPACE tables_arch
LOGGING 
NOCOMPRESS 
NOCACHE
NOPARALLEL
MONITORING
/


Prompt Index IDX_SVA_SUBTXN_PK;
--
-- IDX_SVA_SUBTXN_PK  (Index) 
--
CREATE UNIQUE INDEX IDX_SVA_SUBTXN_PK ON SVA_SUBTXN
(TXN_ID, SEQ_ID, STATUS)
LOGGING
NOPARALLEL
/


-- 
-- Non Foreign Key Constraints for Table SVA_SUBTXN 
-- 
Prompt Non-Foreign Key Constraints on Table SVA_SUBTXN;
ALTER TABLE SVA_SUBTXN ADD (
  CONSTRAINT IDX_SVA_SUBTXN_PK
  PRIMARY KEY
  (TXN_ID, SEQ_ID, STATUS)
  USING INDEX IDX_SVA_SUBTXN_PK
  ENABLE VALIDATE)
/
