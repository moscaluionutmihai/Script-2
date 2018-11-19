-- New Tablespaces for Archive User
-- Please change the directory and names as applicable to the deployment

CREATE tablespace tables_arch DATAFILE '/home/oracle/oradata/bkupdb/bkupdb/tables_arch_01.dbf' SIZE 10M AUTOEXTEND ON NEXT 10M MAXSIZE unlimited;
CREATE tablespace indexes_arch DATAFILE '/home/oracle/oradata/bkupdb/bkupdb/indexes_arch_01.dbf' SIZE 10M AUTOEXTEND ON NEXT 10M MAXSIZE unlimited;
alter tablespace tables_arch add DATAFILE '/home/oracle/oradata/bkupdb/bkupdb/tables_arch_04.dbf' SIZE 10M AUTOEXTEND ON NEXT 10M MAXSIZE unlimited;
alter  tablespace indexes_arch add DATAFILE '/home/oracle/oradata/bkupdb/bkupdb/indexes_arch_04.dbf' SIZE 10M AUTOEXTEND ON NEXT 10M MAXSIZE unlimited;

-- New Archive User

CREATE USER CANAL_PLUS_ARCH IDENTIFIED BY tgbcanal0tarch DEFAULT tablespace tables_arch;

-- Necessary grants to Archive User

GRANT CONNECT, RESOURCE TO CANAL_PLUS_ARCH;
GRANT CREATE TABLE TO CANAL_PLUS_ARCH;
GRANT EXECUTE ON DBMS_STATS TO CANAL_PLUS_ARCH;
GRANT ALTER ANY INDEX TO CANAL_PLUS_ARCH;
GRANT SELECT ON V_$SQLTEXT_WITH_NEWLINES TO CANAL_PLUS_ARCH;
GRANT SELECT ON V_$SQLTEXT TO CANAL_PLUS_ARCH;
GRANT SELECT ON DBA_IND_PARTITIONS TO CANAL_PLUS_ARCH;
GRANT SELECT ON DBA_TAB_PARTITIONS TO CANAL_PLUS_ARCH;
GRANT SELECT ON DBA_PART_KEY_COLUMNS TO CANAL_PLUS_ARCH;
GRANT SELECT ON DBA_TABLES TO CANAL_PLUS_ARCH;
GRANT SELECT ON DBA_INDEXES TO CANAL_PLUS_ARCH;
GRANT CREATE PROCEDURE TO CANAL_PLUS_ARCH;
grant execute on dbms_sql to CANAL_PLUS_ARCH;
grant select on dba_constraints to CANAL_PLUS_ARCH;






