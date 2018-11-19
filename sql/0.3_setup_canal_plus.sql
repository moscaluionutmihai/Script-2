SET FEEDBACK ON TRIMS ON LINES 200 PAGES 20000 TIME ON TIMING ON

SPOOL setup_canal_plus.log

-- Run as CANAL_PLUS.

@@5.1_create_gtt_archive_temp.sql
@@5.2_create_archive_log.sql
@@5.3_create_archive_policy.sql
@@5.4_create_archive_policy_tables.sql
@@5.5_create_seq_archive_log_id.sql
@@5.7_create_archive_control.sql

@@5.99_create_archive_pkg.sql

SPOOL OFF
