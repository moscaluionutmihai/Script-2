DROP TABLE CANAL_PLUS_ARCH.PURGE_POLICY CASCADE CONSTRAINTS;

CREATE TABLE CANAL_PLUS_ARCH.PURGE_POLICY
(
   POLICY_NAME        VARCHAR2 (50 BYTE) NOT NULL,
   RETENTION_MONTHS   NUMBER NOT NULL,
   CREATED_BY         VARCHAR2 (30 BYTE) NOT NULL,
   CREATED_DATE       DATE NOT NULL
)
TABLESPACE tables_arch;

ALTER TABLE PURGE_POLICY
   ADD CONSTRAINT PURGE_POLICY_PK PRIMARY KEY (policy_name)
       USING INDEX TABLESPACE indexes_arch;

ALTER TABLE PURGE_POLICY ADD (
  CONSTRAINT PURGE_POLICY_CHECK2
  CHECK (UPPER(policy_name) = policy_name)
  );

TRUNCATE TABLE purge_policy;

INSERT INTO purge_policy
     VALUES ('TXN_DATA',
             36,
             USER,
             SYSDATE);

INSERT INTO purge_policy
     VALUES ('MESSAGE_DATA',
             36,
             USER,
             SYSDATE);

INSERT INTO purge_policy
     VALUES ('TOPUP_DATA',
             36,
             USER,
             SYSDATE);

INSERT INTO purge_policy
     VALUES ('REPORT_DATA',
             36,
             USER,
             SYSDATE);

INSERT INTO purge_policy
     VALUES ('MERCHANT_DATA',
             36,
             USER,
             SYSDATE);

COMMIT;
