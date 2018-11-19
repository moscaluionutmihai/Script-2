CREATE OR REPLACE PACKAGE CANAL_PLUS.archive_pkg
   AUTHID DEFINER
AS
   V_db_name          CONSTANT VARCHAR2 (50) := SYS_CONTEXT ('USERENV', 'DB_NAME');
   g_msg_type_info    CONSTANT VARCHAR2 (5) := 'info';
   g_msg_type_warn    CONSTANT VARCHAR2 (5) := 'warn';
   g_msg_type_error   CONSTANT VARCHAR2 (5) := 'error';
   g_archive_id                NUMBER;
   g_log_msg                   VARCHAR2 (4000);
   v_cons_result               NUMBER;
   g_sql_row_count             NUMBER;
   g_sqlerrm                   VARCHAR2 (2000);

   ----
   PROCEDURE archive_data ( -- pass the policy name in archive_policy.policy_name
                           -- pass null to process all archive policies.
                           -- passing true or false to  rebuild indexes ,  gather stats params as needed.
                           --   This will handle index rebuild, gather stats  on tables specified
                           --   for policy in archive_policy_tables.table_name
                           --   Index rebuild will slow down the archive process.
                           in_policy_name       IN VARCHAR2 DEFAULT NULL,
                           in_gather_stats      IN BOOLEAN DEFAULT TRUE,
                           in_rebuild_indexes   IN BOOLEAN DEFAULT FALSE);

   ----
   PROCEDURE gather_table_stats (in_policy_name IN VARCHAR2 DEFAULT NULL);

   ----
   PROCEDURE rebuild_indexes (in_policy_name IN VARCHAR2 DEFAULT NULL);

   ----
   PROCEDURE archive_catchup (
      in_stop_date             IN DATE,
      in_retention_decrement   IN NUMBER DEFAULT 7,
      in_gather_stats          IN BOOLEAN DEFAULT TRUE,
      in_rebuild_indexes       IN BOOLEAN DEFAULT FALSE);
END archive_pkg;
/

CREATE OR REPLACE PACKAGE BODY CANAL_PLUS.archive_pkg
AS
   g_stop_date   DATE;

   ----
   PROCEDURE commit_transaction
   IS
   BEGIN
      --ROLLBACK;
      COMMIT;
   END commit_transaction;

   -----
   FUNCTION stop_archiving
      RETURN BOOLEAN
   IS
      v_arch_stop   archive_control.stop_archive_process%TYPE;
   BEGIN
      SELECT stop_archive_process INTO v_arch_stop FROM archive_control;

      IF v_arch_stop = 'F' AND SYSDATE <= NVL (g_stop_date, SYSDATE)
      THEN
         RETURN FALSE;
      ELSE
         RETURN TRUE;
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN TRUE;
   END;

   ----
   PROCEDURE log_activity (p_message IN VARCHAR2, p_msg_type IN VARCHAR2)
   IS
      PRAGMA AUTONOMOUS_TRANSACTION;
   -- p_msg_type can only be ('info', 'warn', 'error')
   BEGIN
      INSERT INTO archive_log (archive_id,
                               archive_log_id,
                               MESSAGE_TYPE,
                               log_message,
                               created_by,
                               created_ts)
           VALUES (g_archive_id,
                   seq_archive_log_id.NEXTVAL,
                   p_msg_type,
                   p_message,
                   USER,
                   SYSTIMESTAMP);

      COMMIT;
   END log_activity;

   ----
   PROCEDURE handle_constraint (in_table_name        IN     VARCHAR2,
                                in_constraint_name   IN     VARCHAR2,
                                in_action            IN     VARCHAR2,
                                out_result              OUT NUMBER)
   AS
   BEGIN
      IF in_action = 'ENABLE'
      THEN
         EXECUTE IMMEDIATE
               'alter table '
            || in_table_name
            || ' '
            || in_action
            || ' novalidate constraint '
            || in_constraint_name;
      ELSIF in_action = 'DISABLE'
      THEN
         EXECUTE IMMEDIATE
               'alter table '
            || in_table_name
            || ' '
            || in_action
            || ' constraint '
            || in_constraint_name;
      END IF;

      out_result := 0;
   EXCEPTION
      WHEN OTHERS
      THEN
         out_result := 1;
   END;

   ----
   FUNCTION get_last_commit (in_retention_period IN NUMBER)
      RETURN DATE
   IS
   BEGIN
      --in_last_commit := TRUNC (ADD_MONTHS (SYSDATE, -in_retention_period));
      RETURN TRUNC (SYSDATE) - in_retention_period;
   END get_last_commit;

   ----
   PROCEDURE archive_txn_data (in_last_commit        IN     DATE,
                               in_commit_frequency   IN     NUMBER,
                               o_count                  OUT NUMBER,
                               o_errcode                OUT VARCHAR2)
   AS
      number_list1   SYS.odcinumberlist := sys.odcinumberlist ();
      v_count        NUMBER := 0;
      v_iteration    NUMBER := 0;
      v_min_ts       TIMESTAMP (6);
      v_max_ts       TIMESTAMP (6);
      v_stage        VARCHAR2 (15) := '0';

      CURSOR c1
      IS
         SELECT unique  ( a.TXN_ID )
           FROM bill_txn a
          WHERE a.TIMESTAMP < TRUNC (in_last_commit);
   BEGIN
      /*
      BILL_TXN
      BILL_TXN_AML
      BILL_TXM_COMMISSION
      BILL_TXN_DETAIL
      BILL_TXN_FAILURE
      BILL_TXN_FEE
      BILL_TXN_PROP
      BILL_TXN_TAX
      SVA_SUBTXN
      EXTERNAL_SYSTEM_BI
      EVOUCHER_INFO
      CREDIT_APPROVAL_HISTORY
      -- erp tables : erp_order, erp_order_audit, erp_order_invoice, erp_order_invoice_audit
      -- audit_trail
      */
      ----
      o_errcode := 'FAIL';
      o_count := 0;
      v_stage := 1;

      SELECT MIN (a.TIMESTAMP), MAX (a.TIMESTAMP)
        INTO v_min_ts, v_max_ts
        FROM bill_txn a;

      v_stage := 2;

      SELECT COUNT (UNIQUE txn_id)
        INTO v_count
        FROM bill_txn a
       WHERE a.TIMESTAMP < TRUNC (in_last_commit);

      log_activity (
            'Before archive. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss')
         || '. Archiving data older than '
         || TO_CHAR (in_last_commit, 'mm/dd/yyyy')
         || '. Num txn_ids to be deleted: '
         || v_count,
         g_msg_type_info);
      ----
      v_stage := 3;
      v_count := 0;
      v_iteration := 0;

      OPEN c1;

      LOOP
         -- process txns in one bulk. num controlled by commit frequency in archive_policy_table for this policy.
         FETCH c1 BULK COLLECT INTO number_list1 LIMIT in_commit_frequency;

         IF stop_archiving
         THEN
            log_activity ('Stop archive requested. Stopping the process. ',
                          g_msg_type_warn);
            EXIT;
         END IF;

         v_iteration := v_iteration + 1;
         v_count := v_count + number_list1.COUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Processing '
            || number_list1.COUNT
            || ' txn_ids.',
            g_msg_type_info);
         --- bill_txn
         v_stage := '4i -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            INSERT INTO canal_plus_arch.bill_txn
               SELECT *
                 FROM bill_txn x
                WHERE X.TXN_ID = number_list1 (i);

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Inserted '
            || g_sql_row_count
            || ', txn_ids to canal_plus_arch.bill_txn.',
            g_msg_type_info);
         --- bill_txn_detail
         v_stage := '5i -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            INSERT INTO canal_plus_arch.bill_txn_detail
               SELECT *
                 FROM bill_txn_detail x
                WHERE X.TXN_ID = number_list1 (i);

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Inserted '
            || g_sql_row_count
            || ', txn_ids to canal_plus_arch.bill_txn_detail.',
            g_msg_type_info);
         --
         v_stage := '5d -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            DELETE FROM bill_txn_detail x
                  WHERE X.TXN_ID = number_list1 (i);

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Deleted '
            || g_sql_row_count
            || ', txn_ids from  bill_txn_detail.',
            g_msg_type_info);
         --- bill_txn_aml
         v_stage := '6i -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            INSERT INTO canal_plus_arch.bill_txn_aml
               SELECT *
                 FROM bill_txn_aml x
                WHERE X.TXN_ID = number_list1 (i) ;

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Inserted '
            || g_sql_row_count
            || ', txn_ids to canal_plus_arch.bill_txn_aml.',
            g_msg_type_info);
         --
         v_stage := '6d -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            DELETE FROM bill_txn_aml x
                  WHERE X.TXN_ID = number_list1 (i) ;

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Deleted '
            || g_sql_row_count
            || ', txn_ids from  bill_txn_aml.',
            g_msg_type_info);
         --- bill_txn_failure
         v_stage := '7i -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            INSERT INTO canal_plus_arch.bill_txn_failure
               SELECT *
                 FROM bill_txn_failure x
                WHERE X.TXN_ID = number_list1 (i) ;

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Inserted '
            || g_sql_row_count
            || ', txn_ids into canal_plus_arch.bill_txn_failure.',
            g_msg_type_info);
         --
         v_stage := '7d -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            DELETE FROM bill_txn_failure x
                  WHERE X.TXN_ID = number_list1 (i) ;

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Deleted '
            || g_sql_row_count
            || ', txn_ids from  bill_txn_failure.',
            g_msg_type_info);
         --- bill_txn_fee
         v_stage := '8i -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            INSERT INTO canal_plus_arch.bill_txn_fee
               SELECT *
                 FROM bill_txn_fee x
                WHERE X.TXN_ID = number_list1 (i) ;

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Inserted '
            || g_sql_row_count
            || ', txn_ids into canal_plus_arch.bill_txn_fee.',
            g_msg_type_info);
         --
         v_stage := '8d -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            DELETE FROM bill_txn_fee x
                  WHERE X.TXN_ID = number_list1 (i) ;

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Deleted '
            || g_sql_row_count
            || ', txn_ids from  bill_txn_fee.',
            g_msg_type_info);

         --- credit_approval_history
         v_stage := '9i -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            INSERT INTO canal_plus_arch.credit_approval_history
               SELECT *
                 FROM credit_approval_history x
                WHERE X.TXN_ID = number_list1 (i);

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Inserted '
            || g_sql_row_count
            || ', txn_ids into canal_plus_arch.credit_approval_history.',
            g_msg_type_info);
         --
         v_stage := '9d -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            DELETE FROM credit_approval_history x
                  WHERE X.TXN_ID = number_list1 (i);

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Deleted '
            || g_sql_row_count
            || ', txn_ids from  credit_approval_history.',
            g_msg_type_info);
         --- bill_txn_prop
         v_stage := '10i -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            INSERT INTO canal_plus_arch.bill_txn_prop
               SELECT *
                 FROM bill_txn_prop x
                WHERE X.TXN_ID = number_list1 (i);

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Inserted '
            || g_sql_row_count
            || ', txn_ids into canal_plus_arch.bill_txn_prop.',
            g_msg_type_info);
         --
         v_stage := '10d -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            DELETE FROM bill_txn_prop x
                  WHERE X.TXN_ID = number_list1 (i);

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Deleted '
            || g_sql_row_count
            || ', txn_ids from  bill_txn_prop.',
            g_msg_type_info);
         --- bill_txn_tax
         v_stage := '11i -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            INSERT INTO canal_plus_arch.bill_txn_tax
               SELECT *
                 FROM bill_txn_tax x
                WHERE X.TXN_ID = number_list1 (i) ;

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Inserted '
            || g_sql_row_count
            || ', txn_ids into canal_plus_arch.bill_txn_tax.',
            g_msg_type_info);
         --
         v_stage := '11d -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            DELETE FROM bill_txn_tax x
                  WHERE X.TXN_ID = number_list1 (i) ;

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Deleted '
            || g_sql_row_count
            || ', txn_ids from  bill_txn_tax.',
            g_msg_type_info);

         --- bill_txn_commission
         v_stage := '12i -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            INSERT INTO canal_plus_arch.bill_txn_commission
               SELECT *
                 FROM bill_txn_commission x
                WHERE X.TXN_ID = number_list1 (i) ;

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Inserted '
            || g_sql_row_count
            || ', txn_ids into canal_plus_arch.bill_txn_commission.',
            g_msg_type_info);
         --
         v_stage := '12d -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            DELETE FROM bill_txn_commission x
                  WHERE X.TXN_ID = number_list1 (i) ;

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Deleted '
            || g_sql_row_count
            || ', txn_ids from  bill_txn_commission.',
            g_msg_type_info);

         --- external_system_bi
         v_stage := '13i -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            INSERT INTO canal_plus_arch.external_system_bi
               SELECT *
                 FROM external_system_bi x
                WHERE X.TXN_ID = number_list1 (i);

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Inserted '
            || g_sql_row_count
            || ', txn_ids into canal_plus_arch.external_system_bi.',
            g_msg_type_info);
         --
         v_stage := '13d -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            DELETE FROM external_system_bi x
                  WHERE X.TXN_ID = number_list1 (i);

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Deleted '
            || g_sql_row_count
            || ', txn_ids from  external_system_bi.',
            g_msg_type_info);

         --

         --- sva_subtxn
         v_stage := '15i -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            INSERT INTO canal_plus_arch.sva_subtxn
               SELECT *
                 FROM sva_subtxn x
                WHERE X.TXN_ID = number_list1 (i) ;

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Inserted '
            || g_sql_row_count
            || ', txn_ids into canal_plus_arch.sva_subtxn.',
            g_msg_type_info);
         --
         v_stage := '15d -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            DELETE FROM sva_subtxn x
                  WHERE X.TXN_ID = number_list1 (i) ;

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Deleted '
            || g_sql_row_count
            || ', txn_ids from  sva_subtxn.',
            g_msg_type_info);

         --- bill_txn
         v_stage := '4d -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            DELETE FROM bill_txn x
                  WHERE X.TXN_ID = number_list1 (i) ;

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Deleted '
            || g_sql_row_count
            || ', txn_ids from  bill_txn.',
            g_msg_type_info);
         ---
         commit_transaction;
         EXIT WHEN c1%NOTFOUND;
      END LOOP;

      o_count := v_count;
      v_stage := '16';

      CLOSE c1;

      ----
      v_stage := '17';

      SELECT MIN (a.TIMESTAMP), MAX (a.TIMESTAMP)
        INTO v_min_ts, v_max_ts
        FROM bill_txn a;

      log_activity (
            'After archive. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss'),
         g_msg_type_info);
      commit_transaction;
      o_errcode := '000';
   EXCEPTION
      WHEN OTHERS
      THEN
         g_sqlerrm := SUBSTR (SQLERRM, 1, 2000);
         o_errcode := SQLCODE;
         o_count := -1;
         ROLLBACK;
         log_activity (
               'Exception Occurred in archive_txn_data at stage: '
            || v_stage
            || '. Error Msg: '
            || g_sqlerrm,
            g_msg_type_error);
   END archive_txn_data;

   ----
   PROCEDURE archive_message_data (in_last_commit        IN     DATE,
                                   in_commit_frequency   IN     NUMBER,
                                   o_count                  OUT NUMBER,
                                   o_errcode                OUT VARCHAR2)
   AS
      number_list1   SYS.odcinumberlist := sys.odcinumberlist ();
      v_count        NUMBER := 0;
      v_iteration    NUMBER := 0;
      v_min_ts       TIMESTAMP (6);
      v_max_ts       TIMESTAMP (6);
      v_stage        VARCHAR2 (15) := '0';
   BEGIN
      /*
      email_message
      sms_message
      sms_log
      merchant_msg
      audit_trial
      */
      o_errcode := 'FAIL';
      O_count := 0;
      ---- SMS_MESSAGE
      v_count := 0;
      v_iteration := 0;
      v_stage := 1;

      SELECT MIN (TRUNC (TIMESTAMP)), MAX (TRUNC (TIMESTAMP))
        INTO v_min_ts, v_max_ts
        FROM sms_message a;

      v_stage := 2;

      SELECT COUNT (id)
        INTO v_count
        FROM sms_message a
       WHERE TRUNC (a.TIMESTAMP) < TRUNC (in_last_commit);

      log_activity (
            'Before archive sms_message. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss')
         || '. Archiving data older than '
         || TO_CHAR (in_last_commit, 'mm/dd/yyyy')
         || '. Num records to be deleted: '
         || v_count,
         g_msg_type_info);
      v_stage := '3i -' || v_iteration;
      v_count := 0;

      INSERT INTO canal_plus_arch.sms_message
         SELECT *
           FROM sms_message x
          WHERE TRUNC (X.TIMESTAMP) < TRUNC (in_last_commit);

      g_sql_row_count := SQL%ROWCOUNT;
      log_activity (
            'Inserted '
         || g_sql_row_count
         || ', records into canal_plus_arch.sms_message.',
         g_msg_type_info);
      --
      v_stage := '3d -' || v_iteration;

      DELETE FROM sms_message x
            WHERE TRUNC (X.TIMESTAMP) < TRUNC (in_last_commit);

      g_sql_row_count := SQL%ROWCOUNT;
      log_activity (
         'Deleted ' || g_sql_row_count || ', records from sms_message.',
         g_msg_type_info);
      ----
      v_stage := '4';

      SELECT MIN (TRUNC (TIMESTAMP)), MAX (TRUNC (TIMESTAMP))
        INTO v_min_ts, v_max_ts
        FROM sms_message a;

      log_activity (
            'After archive sms_message. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss'),
         g_msg_type_info);

      ---- sms_log
      v_count := 0;
      v_iteration := 0;
      v_stage := 5;

      SELECT MIN (TRUNC (TIMESTAMP)), MAX (TRUNC (TIMESTAMP))
        INTO v_min_ts, v_max_ts
        FROM sms_log a;

      v_stage := 6;

      SELECT COUNT (id)
        INTO v_count
        FROM sms_log a
       WHERE TRUNC (a.TIMESTAMP) < TRUNC (in_last_commit);

      log_activity (
            'Before archive sms_log. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss')
         || '. Archiving data older than '
         || TO_CHAR (in_last_commit, 'mm/dd/yyyy')
         || '. Num records to be deleted: '
         || v_count,
         g_msg_type_info);
      v_stage := '7i -' || v_iteration;
      v_count := 0;

      INSERT INTO canal_plus_arch.sms_log
         SELECT *
           FROM sms_log x
          WHERE TRUNC (X.TIMESTAMP) < TRUNC (in_last_commit);

      g_sql_row_count := SQL%ROWCOUNT;
      log_activity (
            'Inserted '
         || g_sql_row_count
         || ', records into canal_plus_arch.sms_log.',
         g_msg_type_info);
      --
      v_stage := '7d -' || v_iteration;

      DELETE FROM sms_log x
            WHERE TRUNC (X.TIMESTAMP) < TRUNC (in_last_commit);

      g_sql_row_count := SQL%ROWCOUNT;
      log_activity (
         'Deleted ' || g_sql_row_count || ', records from sms_log.',
         g_msg_type_info);
      ----
      v_stage := '8';

      SELECT MIN (TRUNC (TIMESTAMP)), MAX (TRUNC (TIMESTAMP))
        INTO v_min_ts, v_max_ts
        FROM sms_log a;

      log_activity (
            'After archive sms_log. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss'),
         g_msg_type_info);

      ---- merchant_msg
      v_count := 0;
      v_iteration := 0;
      v_stage := 9;

      SELECT MIN (TRUNC (TIMESTAMP)), MAX (TRUNC (TIMESTAMP))
        INTO v_min_ts, v_max_ts
        FROM merchant_msg a;

      v_stage := 10;

      SELECT COUNT (id)
        INTO v_count
        FROM merchant_msg a
       WHERE TRUNC (a.TIMESTAMP) < TRUNC (in_last_commit);

      log_activity (
            'Before archive merchant_msg. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss')
         || '. Archiving data older than '
         || TO_CHAR (in_last_commit, 'mm/dd/yyyy')
         || '. Num records to be deleted: '
         || v_count,
         g_msg_type_info);
      v_stage := '11i -' || v_iteration;
      v_count := 0;

      INSERT INTO canal_plus_arch.merchant_msg
         SELECT *
           FROM merchant_msg x
          WHERE TRUNC (X.TIMESTAMP) < TRUNC (in_last_commit);

      g_sql_row_count := SQL%ROWCOUNT;
      log_activity (
            'Inserted '
         || g_sql_row_count
         || ', records into canal_plus_arch.merchant_msg.',
         g_msg_type_info);
      --
      v_stage := '11d -' || v_iteration;

      DELETE FROM merchant_msg x
            WHERE TRUNC (X.TIMESTAMP) < TRUNC (in_last_commit);

      g_sql_row_count := SQL%ROWCOUNT;
      log_activity (
         'Deleted ' || g_sql_row_count || ', records from merchant_msg.',
         g_msg_type_info);
      ----
      v_stage := '12';

      SELECT MIN (TRUNC (TIMESTAMP)), MAX (TRUNC (TIMESTAMP))
        INTO v_min_ts, v_max_ts
        FROM merchant_msg a;

      log_activity (
            'After archive merchant_msg. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss'),
         g_msg_type_info);

      ---- audit_trail
      v_count := 0;
      v_iteration := 0;
      v_stage := 13;

      SELECT MIN (TRUNC (TIMESTAMP)), MAX (TRUNC (TIMESTAMP))
        INTO v_min_ts, v_max_ts
        FROM audit_trail a;

      v_stage := 14;

      SELECT COUNT (id)
        INTO v_count
        FROM audit_trail a
       WHERE TRUNC (a.TIMESTAMP) < TRUNC (in_last_commit);

      log_activity (
            'Before archive audit_trail. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss')
         || '. Archiving data older than '
         || TO_CHAR (in_last_commit, 'mm/dd/yyyy')
         || '. Num records to be deleted: '
         || v_count,
         g_msg_type_info);
      v_stage := '15i -' || v_iteration;
      v_count := 0;

      INSERT INTO canal_plus_arch.audit_trail
         SELECT *
           FROM audit_trail x
          WHERE TRUNC (X.TIMESTAMP) < TRUNC (in_last_commit);

      g_sql_row_count := SQL%ROWCOUNT;
      log_activity (
            'Inserted '
         || g_sql_row_count
         || ', records into canal_plus_arch.audit_trail.',
         g_msg_type_info);
      --
      v_stage := '15d -' || v_iteration;

      DELETE FROM audit_trail x
            WHERE TRUNC (X.TIMESTAMP) < TRUNC (in_last_commit);

      g_sql_row_count := SQL%ROWCOUNT;
      log_activity (
         'Deleted ' || g_sql_row_count || ', records from audit_trail.',
         g_msg_type_info);
      ----
      v_stage := '16';

      SELECT MIN (TRUNC (TIMESTAMP)), MAX (TRUNC (TIMESTAMP))
        INTO v_min_ts, v_max_ts
        FROM audit_trail a;

      log_activity (
            'After archive audit_trail. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss'),
         g_msg_type_info);


      ---- EMAIL Message
      v_stage := '17';
      v_iteration := 0;
      v_count := 0;

      SELECT MIN (a.TIMESTAMP), MAX (a.TIMESTAMP)
        INTO v_min_ts, v_max_ts
        FROM email_message a;

      v_stage := '18';

      SELECT COUNT (id)
        INTO v_count
        FROM email_message a
       WHERE a.TIMESTAMP < TRUNC (in_last_commit);

      log_activity (
            'Before archive email_message. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss')
         || '. Archiving data older than '
         || TO_CHAR (in_last_commit, 'mm/dd/yyyy')
         || '. Num records to be deleted: '
         || v_count,
         g_msg_type_info);
      v_stage := '19i -' || v_iteration;

      INSERT INTO canal_plus_arch.email_message
         SELECT *
           FROM email_message x
          WHERE X.TIMESTAMP < TRUNC (in_last_commit);

      g_sql_row_count := SQL%ROWCOUNT;
      log_activity (
            'Inserted '
         || g_sql_row_count
         || ', records into canal_plus_arch.email_message.',
         g_msg_type_info);
      --
      v_stage := '19d -' || v_iteration;

      DELETE FROM email_message x
            WHERE X.TIMESTAMP < TRUNC (in_last_commit);

      g_sql_row_count := SQL%ROWCOUNT;
      o_count := g_sql_row_count;
      log_activity (
         'Deleted ' || g_sql_row_count || ', records from email_message.',
         g_msg_type_info);
      ----
      v_stage := '20';

      SELECT MIN (a.TIMESTAMP), MAX (a.TIMESTAMP)
        INTO v_min_ts, v_max_ts
        FROM email_message a;

      log_activity (
            'After archive email_message. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss'),
         g_msg_type_info);
      o_errcode := '000';
      commit_transaction;
   EXCEPTION
      WHEN OTHERS
      THEN
         g_sqlerrm := SUBSTR (SQLERRM, 1, 2000);
         o_errcode := SQLCODE;
         o_count := -1;
         ROLLBACK;
         log_activity (
               'Exception Occurred in archive_message_data at stage: '
            || v_stage
            || '. Error Msg: '
            || g_sqlerrm,
            g_msg_type_error);
   END archive_message_data;

   ----
   PROCEDURE archive_topup_data (in_last_commit        IN     DATE,
                                 in_commit_frequency   IN     NUMBER,
                                 o_count                  OUT NUMBER,
                                 o_errcode                OUT VARCHAR2)
   AS
      number_list1   SYS.odcinumberlist := sys.odcinumberlist ();
      number_list2   SYS.odcinumberlist := sys.odcinumberlist ();
      v_count        NUMBER := 0;
      v_iteration    NUMBER := 0;
      v_min_ts       TIMESTAMP (6);
      v_max_ts       TIMESTAMP (6);
      v_stage        VARCHAR2 (15) := '0';

      CURSOR c1
      IS
          SELECT a.TXN_ID, a.seq_id
           FROM auth_txn a
          WHERE a.TIMESTAMP < TRUNC (in_last_commit);
   BEGIN
      /*
      auth_txn
      auth_txn_failure
      */
      ----
      o_errcode := 'FAIL';
      o_count := 0;
      v_stage := 1;

      SELECT MIN (a.TIMESTAMP), MAX (a.TIMESTAMP)
        INTO v_min_ts, v_max_ts
        FROM auth_txn a;

      v_stage := 2;

      SELECT COUNT (txn_id)
        INTO v_count
        FROM auth_txn a
       WHERE a.TIMESTAMP < TRUNC (in_last_commit);

      log_activity (
            'Before archive. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss')
         || '. Archiving data older than '
         || TO_CHAR (in_last_commit, 'mm/dd/yyyy')
         || '. Num txn_ids to be deleted: '
         || v_count,
         g_msg_type_info);
      ----
      v_stage := 3;
      v_count := 0;
      v_iteration := 0;

      OPEN c1;

      LOOP
         -- process txns in one bulk. num controlled by commit frequency in archive_policy_table for this policy.
         FETCH c1 BULK COLLECT INTO number_list1, number_list2 LIMIT in_commit_frequency;
         -- FETCH c1 BULK COLLECT INTO number_list1 LIMIT in_commit_frequency;

         IF stop_archiving
         THEN
            log_activity ('Stop archive requested. Stopping the process. ',
                          g_msg_type_warn);
            EXIT;
         END IF;

         v_iteration := v_iteration + 1;
         v_count := v_count + number_list1.COUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Processing '
            || number_list1.COUNT
            || ' txn_ids.',
            g_msg_type_info);
         --- bill_txn
         v_stage := '4i -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            INSERT INTO canal_plus_arch.auth_txn
               SELECT *
                 FROM auth_txn x
                WHERE X.TXN_ID = number_list1 (i) and x.seq_id = number_list2(i);

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Inserted '
            || g_sql_row_count
            || ', txn_ids to canal_plus_arch.auth_txn.',
            g_msg_type_info);
         --- auth_txn_failure
         v_stage := '5i -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            INSERT INTO canal_plus_arch.auth_txn_failure
               SELECT *
                 FROM auth_txn_failure x
                WHERE X.TXN_ID = number_list1 (i) and x.seq_id = number_list2(i);

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Inserted '
            || g_sql_row_count
            || ', txn_ids to canal_plus_arch.auth_txn_failure.',
            g_msg_type_info);
         --
         v_stage := '5d -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            DELETE FROM auth_txn_failure x
                  WHERE X.TXN_ID = number_list1 (i) and x.seq_id = number_list2(i);

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Deleted '
            || g_sql_row_count
            || ', txn_ids from  auth_txn_failure.',
            g_msg_type_info);

         --- auth_txn
         v_stage := '4d -' || v_iteration;

         FORALL i IN 1 .. number_list1.COUNT
            DELETE FROM auth_txn x
                  WHERE X.TXN_ID = number_list1 (i) and x.seq_id = number_list2(i);

         g_sql_row_count := SQL%ROWCOUNT;
         log_activity (
               'Iteration: '
            || v_iteration
            || ', Deleted '
            || g_sql_row_count
            || ', txn_ids from  auth_txn.',
            g_msg_type_info);
         ---
         commit_transaction;
         EXIT WHEN c1%NOTFOUND;
      END LOOP;

      o_count := v_count;
      v_stage := '6';

      CLOSE c1;

      ----
      v_stage := '7';

      SELECT MIN (a.TIMESTAMP), MAX (a.TIMESTAMP)
        INTO v_min_ts, v_max_ts
        FROM auth_txn a;

      log_activity (
            'After archive. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss'),
         g_msg_type_info);
      commit_transaction;
      o_errcode := '000';
   EXCEPTION
      WHEN OTHERS
      THEN
         g_sqlerrm := SUBSTR (SQLERRM, 1, 2000);
         o_errcode := SQLCODE;
         o_count := -1;
         ROLLBACK;
         log_activity (
               'Exception Occurred in archive_topup_data at stage: '
            || v_stage
            || '. Error Msg: '
            || g_sqlerrm,
            g_msg_type_error);
   END archive_topup_data;

   ----
   PROCEDURE archive_merchant_data (in_last_commit        IN     DATE,
                                    in_commit_frequency   IN     NUMBER,
                                    o_count                  OUT NUMBER,
                                    o_errcode                OUT VARCHAR2)
   AS
      number_list1   SYS.odcinumberlist := sys.odcinumberlist ();
      v_count        NUMBER := 0;
      v_iteration    NUMBER := 0;
      v_min_ts       TIMESTAMP (6);
      v_max_ts       TIMESTAMP (6);
      v_stage        VARCHAR2 (15) := '0';
   BEGIN
      /*
      merch_bal
      merch_bal_wallet
      */
      o_errcode := 'FAIL';
      o_count := 0;
      ---- merch_bal
      v_count := 0;
      v_iteration := 0;
      v_stage := 1;

      SELECT MIN (TIMESTAMP), MAX (TIMESTAMP)
        INTO v_min_ts, v_max_ts
        FROM merch_bal a;

      v_stage := 2;

      SELECT COUNT (1)
        INTO v_count
        FROM merch_bal a
       WHERE TRUNC (a.timestamp) < TRUNC (in_last_commit);

      log_activity (
            'Before archive merch_bal. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss')
         || '. Archiving data older than '
         || TO_CHAR (in_last_commit, 'mm/dd/yyyy')
         || '. Num records to be deleted: '
         || v_count,
         g_msg_type_info);
      v_stage := '3i -' || v_iteration;
      v_count := 0;

      INSERT INTO canal_plus_arch.merch_bal
         SELECT *
           FROM merch_bal x
          WHERE X.timestamp < TRUNC (in_last_commit);

      g_sql_row_count := SQL%ROWCOUNT;
      log_activity (
            'Inserted '
         || g_sql_row_count
         || ', records into canal_plus_arch.merch_bal.',
         g_msg_type_info);
      --
      v_stage := '3d -' || v_iteration;

      DELETE FROM merch_bal x
            WHERE X.timestamp < TRUNC (in_last_commit);

      g_sql_row_count := SQL%ROWCOUNT;
      o_count := g_sql_row_count;
      log_activity (
         'Deleted ' || g_sql_row_count || ', records from merch_bal.',
         g_msg_type_info);
      ----
      v_stage := '4';

      SELECT MIN (TIMESTAMP), MAX (TIMESTAMP)
        INTO v_min_ts, v_max_ts
        FROM merch_bal a;

      log_activity (
            'After archive merch_bal. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss'),
         g_msg_type_info);
      ----
      ---- merch_bal_wallet
      v_count := 0;
      v_iteration := 0;
      v_stage := 5;

      SELECT MIN (TIMESTAMP), MAX (TIMESTAMP)
        INTO v_min_ts, v_max_ts
        FROM merch_bal_wallet a;

      v_stage := 6;

      SELECT COUNT (1)
        INTO v_count
        FROM merch_bal_wallet a
       WHERE TRUNC (a.timestamp) < TRUNC (in_last_commit);

      log_activity (
            'Before archive merch_bal_wallet. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss')
         || '. Archiving data older than '
         || TO_CHAR (in_last_commit, 'mm/dd/yyyy')
         || '. Num records to be deleted: '
         || v_count,
         g_msg_type_info);
      v_stage := '7i -' || v_iteration;
      v_count := 0;

      INSERT INTO canal_plus_arch.merch_bal_wallet
         SELECT *
           FROM merch_bal_wallet x
          WHERE X.timestamp < TRUNC (in_last_commit);

      g_sql_row_count := SQL%ROWCOUNT;
      log_activity (
            'Inserted '
         || g_sql_row_count
         || ', records into canal_plus_arch.merch_bal_wallet.',
         g_msg_type_info);
      --
      v_stage := '7d -' || v_iteration;

      DELETE FROM merch_bal_wallet x
            WHERE X.timestamp < TRUNC (in_last_commit);

      g_sql_row_count := SQL%ROWCOUNT;
      o_count := g_sql_row_count;
      log_activity (
         'Deleted ' || g_sql_row_count || ', records from merch_bal_wallet.',
         g_msg_type_info);
      ----
      v_stage := '8';

      SELECT MIN (TIMESTAMP), MAX (TIMESTAMP)
        INTO v_min_ts, v_max_ts
        FROM merch_bal_wallet a;

      log_activity (
            'After archive merch_bal_wallet. Min_ts: '
         || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
         || ', Max_ts '
         || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss'),
         g_msg_type_info);
      ----
      o_errcode := '000';
      commit_transaction;
   EXCEPTION
      WHEN OTHERS
      THEN
         g_sqlerrm := SUBSTR (SQLERRM, 1, 2000);
         o_errcode := SQLCODE;
         o_count := -1;
         ROLLBACK;
         log_activity (
               'Exception Occurred in archive_merchant_data at stage: '
            || v_stage
            || '. Error Msg: '
            || g_sqlerrm,
            g_msg_type_error);
   END archive_merchant_data;

   ----
   PROCEDURE rebuild_indexes (in_policy_name IN VARCHAR2 DEFAULT NULL)
   AS
      v_error        VARCHAR2 (4000);
      v_stage        VARCHAR2 (20);
      v_iteration1   NUMBER := 0;
      v_iteration2   NUMBER := 0;
      v_sql          VARCHAR2 (3000);
   BEGIN
      v_stage := '1';
      g_log_msg :=
            'STARTED Index Rebuild for tables part of policy: '
         || NVL (in_policy_name, 'All Policies')
         || ' at '
         || TO_CHAR (SYSDATE, 'mm/dd/yyyy hh24:mi:ss');
      log_activity (g_log_msg, g_msg_type_info);
      v_iteration1 := 0;

      FOR c1
         IN (  SELECT a.*,
                      b.owner t_owner,
                      b.table_name t_table,
                      c.PARALLELISM
                 FROM archive_policy_tables a
                      JOIN archive_policy c ON (a.policy_name = c.policy_name)
                      LEFT JOIN sys.dba_tables b
                         ON (    a.table_owner = b.owner
                             AND a.table_name = b.table_name)
                WHERE a.policy_name = NVL (in_policy_name, a.policy_name)
             ORDER BY 1, 2)
      LOOP
         v_iteration1 := v_iteration1 + 1;
         g_log_msg :=
               'Started processing index rebuild for policy: '
            || c1.policy_name
            || ', table: '
            || c1.table_owner
            || '.'
            || c1.table_name;
         log_activity (g_log_msg, g_msg_type_info);
         v_stage := '2 -' || v_iteration1;

         IF c1.t_owner IS NULL
         THEN
            g_log_msg :=
                  'Table mentioned for policy: '
               || c1.policy_name
               || ', table: '
               || c1.table_owner
               || '.'
               || c1.table_name
               || ' is not a valid database table. Not Processing. VALIDATE THE SETUP';
            CONTINUE;
            log_activity (g_log_msg, g_msg_type_info);
         END IF;

         v_iteration2 := 0;

         -- Rebuild indexes
         FOR c2
            IN (  SELECT a.table_name,
                         a.index_name,
                         a.owner index_owner,
                         NVL2 (c.partition_name,
                               'partition ' || c.partition_name,
                               c.partition_name)
                            partition_name
                    FROM dba_indexes a
                         LEFT JOIN dba_ind_partitions c
                            ON (    a.owner = c.index_owner
                                AND a.index_name = c.index_name)
                   WHERE     a.table_name = c1.table_name
                         AND a.table_owner = c1.table_owner
                         AND index_type != 'LOB'
                ORDER BY 1, 2, 3)
         LOOP
            v_iteration2 := v_iteration2 + 1;
            v_stage := '2 -' || v_iteration1 || '-' || v_iteration2;
            v_sql :=
                  'alter index '
               || c2.index_owner
               || '.'
               || c2.index_name
               || ' rebuild '
               || c2.partition_name
               || ' online nologging parallel (degree '
               || c1.parallelism
               || ')';
            g_log_msg := 'Rebuilding index: ' || v_sql;
            log_activity (g_log_msg, g_msg_type_info);

            EXECUTE IMMEDIATE v_sql;

            --
            v_stage := '3 -' || v_iteration1 || '-' || v_iteration2;
            v_sql :=
                  'alter index '
               || c2.index_owner
               || '.'
               || c2.index_name
               || ' logging noparallel';
            g_log_msg := 'Altering index: ' || v_sql;
            log_activity (g_log_msg, g_msg_type_info);

            EXECUTE IMMEDIATE v_sql;
         END LOOP c2;
      END LOOP c1;

      v_stage := '4';
      g_log_msg :=
            'ENDED Index Rebuild for tables part of policy: '
         || NVL (in_policy_name, 'All Policies')
         || ' at '
         || TO_CHAR (SYSDATE, 'mm/dd/yyyy hh24:mi:ss');
      log_activity (g_log_msg, g_msg_type_info);
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error := SUBSTR (SQLERRM, 1, 3000);
         g_log_msg := 'Index Rebuild error at : ' || v_stage || '-' || v_error;
         v_stage := '5';
         ROLLBACK;
         log_activity (g_log_msg, g_msg_type_error);
   END rebuild_indexes;

   ----
   ----
   PROCEDURE gather_table_stats (in_policy_name IN VARCHAR2 DEFAULT NULL)
   AS
      v_error        VARCHAR2 (4000);
      v_stage        VARCHAR2 (20);
      v_iteration1   NUMBER := 0;
      v_iteration2   NUMBER := 0;
      v_sql          VARCHAR2 (3000);
   BEGIN
      v_stage := '1';
      g_log_msg :=
            'STARTED gather_table_stats for tables part of policy: '
         || NVL (in_policy_name, 'All Policies')
         || ' at '
         || TO_CHAR (SYSDATE, 'mm/dd/yyyy hh24:mi:ss');
      log_activity (g_log_msg, g_msg_type_info);
      v_iteration1 := 0;

      FOR c1
         IN (  SELECT a.*,
                      b.owner t_owner,
                      b.table_name t_table,
                      c.PARALLELISM
                 FROM archive_policy_tables a
                      JOIN archive_policy c ON (a.policy_name = c.policy_name)
                      LEFT JOIN dba_tables b
                         ON (    a.table_owner = b.owner
                             AND a.table_name = b.table_name)
                WHERE a.policy_name = NVL (in_policy_name, a.policy_name)
             ORDER BY 1, 2)
      LOOP
         v_iteration1 := v_iteration1 + 1;
         g_log_msg :=
               'Started processing gather stats for policy: '
            || c1.policy_name
            || ', table: '
            || c1.table_owner
            || '.'
            || c1.table_name;
         log_activity (g_log_msg, g_msg_type_info);
         v_stage := '2 -' || v_iteration1;

         IF c1.t_owner IS NULL
         THEN
            g_log_msg :=
                  'Table mentioned for policy: '
               || c1.policy_name
               || ', table: '
               || c1.table_owner
               || '.'
               || c1.table_name
               || ' is not a valid database table. Not Processing. VALIDATE THE SETUP';
            CONTINUE;
            log_activity (g_log_msg, g_msg_type_info);
         END IF;

         g_log_msg :=
               'Started gathering stats on table : '
            || c1.table_owner
            || '.'
            || c1.table_name;
         log_activity (g_log_msg, g_msg_type_info);
         v_stage := '4';
         DBMS_STATS.gather_table_stats (
            c1.table_owner,
            c1.table_name,
            method_opt         => 'FOR ALL COLUMNS SIZE AUTO',
            CASCADE            => TRUE,
            estimate_percent   => DBMS_STATS.auto_sample_size,
            degree             => c1.parallelism);
         g_log_msg :=
               'Ended gathering stats on table : '
            || c1.table_owner
            || '.'
            || c1.table_name;
         log_activity (g_log_msg, g_msg_type_info);
         --
         g_log_msg :=
               'Ended processing policy: '
            || c1.policy_name
            || ', table: '
            || c1.table_name;
         log_activity (g_log_msg, g_msg_type_info);
      END LOOP c1;

      v_stage := '4';
      g_log_msg :=
            'ENDED gather_table_stats for tables part of policy: '
         || NVL (in_policy_name, 'All Policies')
         || ' at '
         || TO_CHAR (SYSDATE, 'mm/dd/yyyy hh24:mi:ss');
      log_activity (g_log_msg, g_msg_type_info);
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error := SUBSTR (SQLERRM, 1, 3000);
         g_log_msg :=
            'Gather Table Stats error at : ' || v_stage || '-' || v_error;
         v_stage := '5';
         ROLLBACK;
         log_activity (g_log_msg, g_msg_type_error);
   END gather_table_stats;

   ----
   PROCEDURE archive_data (in_policy_name       IN VARCHAR2 DEFAULT NULL,
                           in_gather_stats      IN BOOLEAN DEFAULT TRUE,
                           in_rebuild_indexes   IN BOOLEAN DEFAULT FALSE)
   IS
      v_error         VARCHAR2 (4000);
      v_last_commit   DATE;
      v_starttime     DATE;
      v_stoptime      DATE;
      v_count         NUMBER;
   --
   -- mylist               SYS.ODCIVARCHAR2LIST;
   BEGIN
      --DBMS_OUTPUT.enable;
      g_archive_id :=
         NVL (g_archive_id,
              TO_NUMBER (TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')));
      g_log_msg :=
            'Archive data initiated for policy: '
         || NVL (in_policy_name, 'All Policies')
         || ' started at '
         || TO_CHAR (SYSDATE, 'mm/dd/yyyy hh24:mi:ss');
      log_activity (g_log_msg, g_msg_type_info);
      v_error := '000';
      g_log_msg := 'Retreiving the list of policies to process.';
      log_activity (g_log_msg, g_msg_type_info);

      FOR c1 IN (  SELECT *
                     FROM archive_policy
                    WHERE policy_name = NVL (in_policy_name, policy_name)
                 ORDER BY 1)
      LOOP
         v_starttime := SYSDATE;
         v_last_commit := get_last_commit (c1.retention_period);
         g_log_msg :=
               'Policy Name: '
            || c1.policy_name
            || ', Retention Period: '
            || c1.retention_period
            || ', Commit Frequency: '
            || c1.commit_frequency
            || ', Archiving data older than '
            || TO_CHAR (v_last_commit, 'mm/dd/yyyy');
         log_activity (g_log_msg, g_msg_type_info);
         v_error := 'Begin';
         v_count := -1;

         IF stop_archiving
         THEN
            log_activity ('Stop archive requested. Stopping the process. ',
                          g_msg_type_warn);
            EXIT;
         END IF;

         IF c1.policy_name = 'TXN_DATA'
         THEN
            archive_txn_data (v_last_commit,
                              c1.commit_frequency,
                              v_count,
                              v_error);
         ELSIF c1.policy_name = 'MESSAGE_DATA'
         THEN
            archive_message_data (v_last_commit,
                                  c1.commit_frequency,
                                  v_count,
                                  v_error);
         ELSIF c1.policy_name = 'TOPUP_DATA'
         THEN
            archive_topup_data (v_last_commit,
                                c1.commit_frequency,
                                v_count,
                                v_error);
         ELSIF c1.policy_name = 'MERCHANT_DATA'
         THEN
            archive_merchant_data (v_last_commit,
                                   c1.commit_frequency,
                                   v_count,
                                   v_error);
         ELSE
            v_error := 'Unhandled archive job :' || c1.policy_name;
         -- RAISE batch_job_unknown;
         END IF;

         log_activity (
               'Done purging for policy: '
            || c1.policy_name
            || '. #records processed: '
            || v_count
            || ', Return Code: '
            || v_error,
            g_msg_type_info);

         --
         IF in_gather_stats
         THEN
            gather_table_stats (c1.policy_name);
         END IF;

         IF in_rebuild_indexes
         THEN
            rebuild_indexes (c1.policy_name);
         END IF;
      --
      END LOOP;

      g_log_msg :=
            'Archive data ended at '
         || TO_CHAR (SYSDATE, 'mm/dd/yyyy hh24:mi:ss');
      log_activity (g_log_msg, g_msg_type_info);
      commit_transaction;
   EXCEPTION
      WHEN OTHERS
      THEN
         v_error := 'archive_data error: ' || SQLERRM;
         ROLLBACK;
         log_activity (g_log_msg, g_msg_type_error);
   END archive_data;

   ----
   PROCEDURE archive_catchup (
      in_stop_date             IN DATE,
      in_retention_decrement   IN NUMBER DEFAULT 7,
      in_gather_stats          IN BOOLEAN DEFAULT TRUE,
      in_rebuild_indexes       IN BOOLEAN DEFAULT FALSE)
   AS
      v_iteration              NUMBER := 0;
      v_sysdate                DATE := SYSDATE;
      -- g_stop_date              DATE;
      v_mins_to_rebuild_ind    NUMBER := 60;
      v_mins_to_gather_stats   NUMBER := 30;
      v_count                  NUMBER;
   BEGIN
      g_archive_id := TO_NUMBER (TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS'));

      IF in_stop_date IS NULL OR in_stop_date <= SYSDATE
      THEN
         log_activity (
               'archive_catchup: Invalid stop date provided: '
            || TO_CHAR (in_stop_date, 'mm/dd/yyyy hh24:mi'),
            g_msg_type_error);
         RETURN;
      END IF;

      -- adjust the stop date assuming finalizing tables takes about 1.5 hrs.
      g_stop_date := in_stop_date;

      IF in_gather_stats
      THEN
         g_stop_date := g_stop_date - (v_mins_to_gather_stats / (24 * 60));
      END IF;

      --
      IF in_rebuild_indexes
      THEN
         g_stop_date := g_stop_date - (v_mins_to_rebuild_ind / (24 * 60));
      END IF;

      --
      log_activity (
            'archive_catchup: SYSDATE: '
         || TO_CHAR (SYSDATE, 'mm/dd/yyyy hh24:mi')
         || ', stop date provided: '
         || TO_CHAR (in_stop_date, 'mm/dd/yyyy hh24:mi')
         || ', stop date computed: '
         || TO_CHAR (g_stop_date, 'mm/dd/yyyy hh24:mi'),
         g_msg_type_info);

      WHILE v_sysdate < g_stop_date
      LOOP
         v_iteration := v_iteration + 1;
         log_activity (
               'archive_catchup: Iteration '
            || v_iteration
            || '. SYSDATE: '
            || TO_CHAR (SYSDATE, 'mm/dd/yyyy hh24:mi')
            || ', stop date provided: '
            || TO_CHAR (in_stop_date, 'mm/dd/yyyy hh24:mi'),
            g_msg_type_info);
         -- Archive data,Archive data for all policies, donot finalize tables now.

         archive_data (NULL, FALSE, FALSE);

         -- update retention to continue purging.
         UPDATE archive_policy
            SET RETENTION_PERIOD =
                   GREATEST (MIN_RETENTION_PERIOD,
                             RETENTION_PERIOD - in_retention_decrement),
                created_date = SYSDATE
          WHERE MIN_RETENTION_PERIOD < RETENTION_PERIOD;

         v_count := SQL%ROWCOUNT;
         log_activity (
            'Updated retention period for ' || v_count || ' policies.',
            g_msg_type_info);
         COMMIT;

         IF v_count > 0
         THEN
            -- Some more catchup needs to happen, so let it continue.
            v_sysdate := SYSDATE;
         ELSE
            -- No More catchup needed. Stop looping.
            v_sysdate := g_stop_date;
         END IF;
      END LOOP;

      log_activity (
            'archive_catchup: Completed purging. Total iterations: '
         || v_iteration
         || '. Stopped at SYSDATE: '
         || TO_CHAR (SYSDATE, 'mm/dd/yyyy hh24:mi')
         || ', stop date provided: '
         || TO_CHAR (in_stop_date, 'mm/dd/yyyy hh24:mi'),
         g_msg_type_info);

      IF v_iteration > 0
      THEN
         --
         IF in_gather_stats
         THEN
            log_activity ('Start Gather Stats on archived tables.',
                          g_msg_type_info);
            gather_table_stats (NULL);
            log_activity ('End Gather Stats on archived tables.',
                          g_msg_type_info);
         END IF;

         IF in_rebuild_indexes
         THEN
            log_activity ('Start Index Rebuild on archived tables.',
                          g_msg_type_info);
            rebuild_indexes (NULL);
            log_activity ('End Index Rebuild on archived tables.',
                          g_msg_type_info);
         END IF;
      --
      ELSE
         log_activity ('NOT Finalizing archived tables.', g_msg_type_info);
      END IF;
   END archive_catchup;
----
END archive_pkg;
/
