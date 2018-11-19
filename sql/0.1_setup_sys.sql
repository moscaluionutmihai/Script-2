SET FEEDBACK ON TRIMS ON LINES 200 PAGES 20000 TIME ON TIMING ON

SPOOL setup_sys.log

-- Run as SYS
@@1.1_create_arch_user_ts.sql
@@1.2_grants_to_prod_user.sql

SPOOL OFF
