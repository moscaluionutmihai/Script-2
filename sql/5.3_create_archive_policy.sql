DROP TABLE CANAL_PLUS.ARCHIVE_POLICY CASCADE CONSTRAINTS;

CREATE TABLE CANAL_PLUS.ARCHIVE_POLICY
(
   POLICY_NAME            VARCHAR2 (50 BYTE) NOT NULL,
   MIN_RETENTION_PERIOD   NUMBER NOT NULL,
   RETENTION_PERIOD       NUMBER NOT NULL,
   COMMIT_FREQUENCY       NUMBER NOT NULL,
   PARALLELISM            NUMBER NOT NULL,
   CREATED_BY             VARCHAR2 (30 BYTE) NOT NULL,
   CREATED_DATE           DATE NOT NULL
)
TABLESPACE TABLES1;

ALTER TABLE ARCHIVE_POLICY
   ADD CONSTRAINT ARCHIVE_POLICY_PK PRIMARY KEY (POLICY_NAME)
       USING INDEX TABLESPACE INDEX1;

ALTER TABLE ARCHIVE_POLICY ADD (
  CONSTRAINT ARCHIVE_POLICY_CHECK1
  CHECK (RETENTION_PERIOD >= MIN_RETENTION_PERIOD)
  );

ALTER TABLE ARCHIVE_POLICY ADD (
  CONSTRAINT ARCHIVE_POLICY_CHECK2
  CHECK (UPPER(POLICY_NAME) = POLICY_NAME)
  );

--ALTER TABLE ARCHIVE_policy_tables   DROP CONSTRAINT ppt_policy_fk;

TRUNCATE TABLE ARCHIVE_POLICY;

INSERT INTO ARCHIVE_POLICY
     select 'MERCHANT_DATA',
             400,
             trunc(sysdate) - 10 - trunc(min(timestamp)),
             10000,
             8,
             USER,
             SYSDATE from merch_bal;

INSERT INTO ARCHIVE_POLICY
     select  'TXN_DATA',
             400,
             trunc(sysdate) - 10 - trunc(min(timestamp)),
             10000,
             8,
             USER,
             SYSDATE from bill_txn;

INSERT INTO ARCHIVE_POLICY
     select /*+ parallel (6) */ 'MESSAGE_DATA',
             400,
             trunc(sysdate) - 10 - trunc(min(timestamp)),
             10000,
             8,
             USER,
             SYSDATE from sms_message;

INSERT INTO ARCHIVE_POLICY
select 'REPORT_DATA',
             400,
             trunc(sysdate) - 10 - trunc(min(requestdate)),
             10000,
             8,
             USER,
             SYSDATE from report_request;



INSERT INTO ARCHIVE_POLICY
     select 'TOPUP_DATA',
             400,
              trunc(sysdate) - 10 - MIN (TRUNC (TIMESTAMP)),
             10000,
             8,
             USER,
             SYSDATE from auth_txn;

INSERT INTO ARCHIVE_POLICY
     select 'MISC_DATA',
             400,
              trunc(sysdate) - 10 - MIN (TRUNC (TIMESTAMP)),
             10000,
             8,
             USER,
             SYSDATE from sva_subtxn;


COMMIT;
