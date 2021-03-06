PROMPT drop TABLE PURGE_LOG;
DROP TABLE CANAL_PLUS_ARCH.PURGE_LOG CASCADE CONSTRAINTS;

PROMPT Table PURGE_LOG;
--
-- PURGE_LOG  (Table)
--

CREATE TABLE CANAL_PLUS_ARCH.PURGE_LOG
(
   purge_id       NUMBER NOT NULL,
   PURGE_LOG_ID   NUMBER NOT NULL,
   MESSAGE_TYPE   VARCHAR2 (30 BYTE) NOT NULL,
   LOG_MESSAGE    VARCHAR2 (4000 BYTE) NOT NULL,
   CREATED_BY     VARCHAR2 (30 BYTE) NOT NULL,
   CREATED_TS     TIMESTAMP (6) DEFAULT SYSTIMESTAMP NOT NULL
)
TABLESPACE tables_arch;

ALTER TABLE CANAL_PLUS_ARCH.purge_log
   ADD CONSTRAINT purge_log_pk PRIMARY KEY (purge_log_id)
       USING INDEX TABLESPACE indexes_arch;

ALTER TABLE CANAL_PLUS_ARCH.purge_log
   ADD CONSTRAINT purge_log_check CHECK
          (LOWER (MESSAGE_TYPE) IN ('info', 'warn', 'error'));
