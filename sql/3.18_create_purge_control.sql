PROMPT DROP TABLE purge_CONTROL;
DROP TABLE canal_plus_arch.purge_CONTROL CASCADE CONSTRAINTS;

PROMPT TABLE purge_CONTROL;
--
-- purge_CONTROL  (Table)
--

CREATE TABLE canal_plus_arch.purge_CONTROL
(
   stop_purge_process   CHAR (1) NOT NULL,
   CREATED_BY           VARCHAR2 (30 BYTE) NOT NULL,
   CREATED_TS           TIMESTAMP (6) DEFAULT SYSTIMESTAMP NOT NULL
)
TABLESPACE tables_arch;

INSERT INTO purge_control
     VALUES ('F', USER, SYSDATE);

COMMIT;
