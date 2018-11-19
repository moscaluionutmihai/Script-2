DROP TABLE CANAL_PLUS_ARCH.purge_policy_tables;

CREATE TABLE CANAL_PLUS_ARCH.purge_policy_tables
(
   policy_name    VARCHAR2 (50 BYTE) NOT NULL,
   table_owner    VARCHAR2 (30) NOT NULL,
   table_name     VARCHAR2 (30) NOT NULL,
   purge_method   VARCHAR2 (15) NOT NULL,
   purge_order    NUMBER NOT NULL,
   CONSTRAINT ppt_policy_fk FOREIGN KEY (policy_name)
   REFERENCES purge_policy (policy_name)
)
TABLESPACE tables_arch;

ALTER TABLE purge_policy_tables
   ADD CONSTRAINT purge_method_chk CHECK
          (purge_method IN ('IND', 'PARENT_PTN', 'CHILD_PTN'));

INSERT INTO purge_policy_tables
     VALUES ('MERCHANT_DATA',
             'CANAL_PLUS_ARCH',
             'MERCH_BAL',
             'IND',
             1);

--INSERT INTO purge_policy_tables
--     VALUES ('REPORT_DATA', 'CANAL_PLUS_ARCH', 'REPORT_REQUEST');
--
--INSERT INTO purge_policy_tables
--     VALUES ('REPORT_DATA', 'CANAL_PLUS_ARCH', 'REPORT_BLOB');

INSERT INTO purge_policy_tables
     VALUES ('TOPUP_DATA',
             'CANAL_PLUS_ARCH',
             'TOPUP_INFO',
             'IND',
             1);

INSERT INTO purge_policy_tables
     VALUES ('MESSAGE_DATA',
             'CANAL_PLUS_ARCH',
             'EMAIL_MESSAGE',
             'IND',
             1);

INSERT INTO purge_policy_tables
     VALUES ('MESSAGE_DATA',
             'CANAL_PLUS_ARCH',
             'SMS_MESSAGE',
             'IND',
             2);

INSERT INTO purge_policy_tables
     VALUES ('TXN_DATA',
             'CANAL_PLUS_ARCH',
             'BILL_TXN',
             'PARENT_PTN',
             1);

INSERT INTO purge_policy_tables
     VALUES ('TXN_DATA',
             'CANAL_PLUS_ARCH',
             'BILL_TXN_DETAIL',
             'CHILD_PTN',
             0);

INSERT INTO purge_policy_tables
     VALUES ('TXN_DATA',
             'CANAL_PLUS_ARCH',
             'BILL_TXN_STATE',
             'IND',
             2);

INSERT INTO purge_policy_tables
     VALUES ('TXN_DATA',
             'CANAL_PLUS_ARCH',
             'BILL_TXN_FAILURE',
             'CHILD_PTN',
             0);

INSERT INTO purge_policy_tables
     VALUES ('TXN_DATA',
             'CANAL_PLUS_ARCH',
             'BILL_TXN_FEE',
             'CHILD_PTN',
             0);

INSERT INTO purge_policy_tables
     VALUES ('TXN_DATA',
             'CANAL_PLUS_ARCH',
             'BILL_TXN_PROP',
             'CHILD_PTN',
             0);

INSERT INTO purge_policy_tables
     VALUES ('TXN_DATA',
             'CANAL_PLUS_ARCH',
             'BILL_TXN_LOCK',
             'CHILD_PTN',
             0);

INSERT INTO purge_policy_tables
     VALUES ('TXN_DATA',
             'CANAL_PLUS_ARCH',
             'SVA_SUBTXN',
             'IND',
             3);

INSERT INTO purge_policy_tables
     VALUES ('TXN_DATA',
             'CANAL_PLUS_ARCH',
             'ERP_ORDER',
             'IND',
             4);

INSERT INTO purge_policy_tables
     VALUES ('TXN_DATA',
             'CANAL_PLUS_ARCH',
             'ERP_ORDER_AUDIT',
             'IND',
             5);

INSERT INTO purge_policy_tables
     VALUES ('TXN_DATA',
             'CANAL_PLUS_ARCH',
             'ERP_ORDER_INVOICE',
             'IND',
             6);

INSERT INTO purge_policy_tables
     VALUES ('TXN_DATA',
             'CANAL_PLUS_ARCH',
             'ERP_ORDER_INVOICE_AUDIT',
             'IND',
             7);

INSERT INTO purge_policy_tables
     VALUES ('TXN_DATA',
             'CANAL_PLUS_ARCH',
             'AUDIT_TRAIL',
             'IND',
             8);


COMMIT;