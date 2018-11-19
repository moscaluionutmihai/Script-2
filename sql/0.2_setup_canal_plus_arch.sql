SET FEEDBACK ON TRIMS ON LINES 200 PAGES 20000 TIME ON TIMING ON

SPOOL setup_canal_plus_arch.log

-- Run as canal_plus_arch.
@@create_1_bill_txn_arch.sql
@@create_2_bill_txn_aml_arch.sql
@@create_3_bill_txn_commission_arch.sql
@@create_4_bill_txn_detail_arch.sql
@@create_6_bill_txn_fee_arch.sql
@@create_5_bill_txn_failure_arch.sql
@@create_7_bill_txn_prop_arch.sql
@@create_8_bill_txn_tax_arch.sql
@@create_9_sva_subtxn_arch.sql
@@create_10_external_system_bi_arch.sql
@@create_11_evoucher_info_arch.sql
@@create_12_credit_approval_history_arch.sql
@@create_13_auth_txn_arch.sql
@@create_14_auth_txn_failure_arch.sql
@@create_15_sms_log_arch.sql
@@create_16_sms_message_arch.sql
@@create_18_audit_trail_arch.sql
@@create_22_merchant_token_audit_arch.sql
@@create_23_merch_bal_arch.sql
@@create_24_merch_bal_wallet_arch.sql
@@create_26_merchant_msg_arch.sql
@@create_27_email_message_arch.sql
@@create_grant_to_canal_plus.sql

SPOOL OFF


