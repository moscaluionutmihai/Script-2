Prompt drop TABLE MERCHANT_TOKEN;
ALTER TABLE MERCHANT_TOKEN
 DROP PRIMARY KEY CASCADE
/

DROP TABLE MERCHANT_TOKEN CASCADE CONSTRAINTS
/

Prompt Table MERCHANT_TOKEN;
--
-- MERCHANT_TOKEN  (Table) 
--
CREATE TABLE MERCHANT_TOKEN
(
  ID          VARCHAR2(64 BYTE)                 NOT NULL,
  TYPE        VARCHAR2(32 BYTE)                 NOT NULL,
  VALUE       VARCHAR2(128 BYTE)                NOT NULL,
  EXPIRATION  DATE                              NOT NULL,
  VERSION     NUMBER(18)                        NOT NULL
) TABLESPACE tables_arch
LOGGING 
NOCOMPRESS 
NOCACHE
NOPARALLEL
MONITORING
/


Prompt Index IDX_MERCHANT_TOKEN_PK;
--
-- IDX_MERCHANT_TOKEN_PK  (Index) 
--
CREATE UNIQUE INDEX IDX_MERCHANT_TOKEN_PK ON MERCHANT_TOKEN
(ID, TYPE)
LOGGING
NOPARALLEL
/


-- 
-- Non Foreign Key Constraints for Table MERCHANT_TOKEN 
-- 
Prompt Non-Foreign Key Constraints on Table MERCHANT_TOKEN;
ALTER TABLE MERCHANT_TOKEN ADD (
  CONSTRAINT IDX_MERCHANT_TOKEN_PK
  PRIMARY KEY
  (ID, TYPE)
  USING INDEX IDX_MERCHANT_TOKEN_PK
  ENABLE VALIDATE)
/

-- 
-- Foreign Key Constraints for Table MERCHANT_TOKEN 
-- 
Prompt Foreign Key Constraints on Table MERCHANT_TOKEN;
ALTER TABLE MERCHANT_TOKEN ADD (
  CONSTRAINT IDX_MERCHANT_TOKEN_FK 
  FOREIGN KEY (ID) 
  REFERENCES MERCHANT (ID)
  ENABLE NOVALIDATE)
/
