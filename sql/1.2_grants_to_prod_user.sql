-- GRANTS to main and archive users
grant select on dba_tables to canal_plus_arch;
grant select on dba_indexes to canal_plus_arch;
GRANT SELECT ON dba_ind_partitions TO canal_plus_arch;
grant select on dba_tables to canal_plus;
grant select on dba_indexes to canal_plus;
GRANT SELECT ON dba_ind_partitions TO canal_plus;
