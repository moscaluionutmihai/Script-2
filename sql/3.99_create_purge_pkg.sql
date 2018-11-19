CREATE OR REPLACE PACKAGE otar_ot_arch.purge_pkg
   AUTHID DEFINER
AS
   V_db_name          CONSTANT VARCHAR2 (50) := SYS_CONTEXT ('USERENV', 'DB_NAME');
   g_msg_type_info    CONSTANT VARCHAR2 (5) := 'info';
   g_msg_type_warn    CONSTANT VARCHAR2 (5) := 'warn';
   g_msg_type_error   CONSTANT VARCHAR2 (5) := 'error';
   g_purge_id                  NUMBER;
   g_log_msg                   VARCHAR2 (4000);
   v_cons_result               NUMBER;
   g_sql_row_count             NUMBER;
   g_sqlerrm                   VARCHAR2 (3000);

   ----
   PROCEDURE purge_data (  -- pass the policy name in purge_policy.policy_name
                         -- pass null to process all archive policies.
                         -- passing true or false to gather stats params as needed.
                         --   This will handle gather stats  on tables specified
                         --   for policy in purge_policy_tables.table_name

                         in_policy_name    IN VARCHAR2 DEFAULT NULL,
                         in_gather_stats   IN BOOLEAN DEFAULT FALSE);

   ----
   PROCEDURE gather_table_stats (in_policy_name IN VARCHAR2 DEFAULT NULL);

   ----
   --PROCEDURE rebuild_indexes (in_policy_name IN VARCHAR2 DEFAULT NULL);

   ---
   FUNCTION get_partitions_for_purge (in_table_owner       IN VARCHAR2,
                                      in_table_name        IN VARCHAR2,
                                      in_purge_high_date   IN DATE)
      RETURN purge_partition_tab
      PIPELINED;
END purge_pkg;
/

CREATE OR REPLACE PACKAGE BODY otar_ot_arch.purge_pkg
AS
   ----
   PROCEDURE commit_transaction
   IS
   BEGIN
      --ROLLBACK;
      COMMIT;
   END commit_transaction;

   -----
   FUNCTION stop_purging
      RETURN BOOLEAN
   IS
      v_arch_stop   purge_control.stop_purge_process%TYPE;
   BEGIN
      SELECT stop_purge_process INTO v_arch_stop FROM purge_control;

      IF v_arch_stop = 'F'
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
      INSERT INTO purge_log (purge_id,
                             purge_log_id,
                             MESSAGE_TYPE,
                             log_message,
                             created_by,
                             created_ts)
           VALUES (g_purge_id,
                   seq_purge_log_id.NEXTVAL,
                   p_msg_type,
                   p_message,
                   USER,
                   SYSTIMESTAMP);

      COMMIT;
   END log_activity;

   ----
   PROCEDURE handle_constraints (in_table_name   IN     VARCHAR2,
                                 in_action       IN     VARCHAR2,
                                 out_result         OUT NUMBER)
   AS
      v_sql      VARCHAR2 (2000);
      v_result   NUMBER := 0;
      v_error    VARCHAR2 (4000);
   BEGIN
      FOR c1
         IN (SELECT chi.owner chi_owner,
                    chi.table_name chi_table_name,
                    chi.constraint_name chi_constraint_name,
                    chi.status chi_constraint_status,
                    par.constraint_type par_constraint_type,
                    par.owner par_owner,
                    par.table_name par_table_name,
                    par.constraint_name par_constraint_name
               FROM dba_constraints chi
                    JOIN dba_constraints par
                       ON (    chi.r_owner = par.owner
                           AND chi.r_constraint_name = par.constraint_name)
              WHERE     chi.constraint_type = 'R'
                    AND par.owner = 'OTAR_OT_ARCH'
                    AND par.table_name = in_table_name
                    AND NOT EXISTS
                           (SELECT 1
                              FROM purge_policy_tables c
                             WHERE     purge_method = 'CHILD_PTN'
                                   AND chi.table_name = c.table_name))
      LOOP
         IF in_action = 'ENABLE'
         THEN
            v_sql :=
                  'alter table '
               || c1.chi_table_name
               || ' '
               || in_action
               || ' novalidate constraint '
               || c1.chi_constraint_name;
         ELSIF in_action = 'DISABLE'
         THEN
            v_sql :=
                  'alter table '
               || c1.chi_table_name
               || ' '
               || in_action
               || ' constraint '
               || c1.chi_constraint_name;
         END IF;

         BEGIN
            g_log_msg := 'Executing SQL: ' || v_sql;
            log_activity (g_log_msg, g_msg_type_info);

            EXECUTE IMMEDIATE v_sql;
         EXCEPTION
            WHEN OTHERS
            THEN
               v_error := SUBSTR (SQLERRM, 1, 3000);
               g_log_msg :=
                     'Failed to '
                  || in_action
                  || ' constraint '
                  || c1.chi_table_name
                  || '.'
                  || c1.chi_constraint_name
                  || ' with error: '
                  || v_error;
               log_activity (g_log_msg, g_msg_type_info);
               v_result := 1;
         END;
      END LOOP;

      out_result := v_result;
   END handle_constraints;

   ----

   FUNCTION get_last_commit (in_retention_months IN NUMBER)
      RETURN DATE
   IS
   BEGIN
      --in_last_commit := TRUNC (ADD_MONTHS (SYSDATE, -in_retention_months));
      RETURN TRUNC (ADD_MONTHS (TRUNC (SYSDATE), -1 * in_retention_months),
                    'MON');
   END get_last_commit;

   ----

   FUNCTION get_partitions_for_purge (in_table_owner       IN VARCHAR2,
                                      in_table_name        IN VARCHAR2,
                                      in_purge_high_date   IN DATE)
      RETURN purge_partition_tab
      PIPELINED
   AS
      v_hival                 VARCHAR2 (4000);
      v_sql                   VARCHAR2 (4000);
      v_partition_high_date   DATE;
      v_cursor                INTEGER DEFAULT DBMS_SQL.open_cursor;
      v_rows_back             NUMBER;
      v_table_name            VARCHAR2 (30);
      v_counter               NUMBER;
   BEGIN
      -- partition position = 1 always grabs the "oldest" partition
      v_table_name := in_table_name;

      FOR c1
         IN (  SELECT *
                 FROM dba_tab_partitions
                WHERE     table_name = v_table_name
                      AND table_owner = in_table_owner
             ORDER BY partition_position)
      LOOP
         v_hival := c1.high_value;

         IF v_hival = 'MAXVALUE'
         THEN
            DBMS_OUTPUT.put_line (
                  'Skipping MAXVALUE partition '
               || c1.partition_name
               || ', position '
               || c1.partition_position);
         ELSE
            DBMS_SQL.parse (v_cursor,
                            'begin :retval := ' || v_hival || '; end;',
                            DBMS_SQL.native);
            DBMS_SQL.bind_variable (v_cursor,
                                    ':retval',
                                    v_partition_high_date);
            v_rows_back := DBMS_SQL.execute (v_cursor);
            DBMS_SQL.variable_value (v_cursor,
                                     ':retval',
                                     v_partition_high_date);
            DBMS_OUTPUT.put_line (
                  c1.partition_name
               || '-'
               || c1.partition_position
               || '-'
               || TO_CHAR (v_partition_high_date, 'yyyy-mm-dd-hh24.mi.ss'));

            IF in_purge_high_date >= v_partition_high_date
            THEN
               DBMS_OUTPUT.put_line ('Including for purge');
               PIPE ROW (purge_partition_obj (c1.partition_name,
                                              v_partition_high_date));
            END IF;
         END IF;
      END LOOP;
   END get_partitions_for_purge;

   ----

   PROCEDURE rebuild_indexes (in_policy_name IN VARCHAR2 DEFAULT NULL)
   AS
      v_error        VARCHAR2 (4000);
      v_stage        VARCHAR2 (40);
      v_iteration1   NUMBER := 0;
      v_iteration2   NUMBER := 0;
      v_sql          VARCHAR2 (3000);
   BEGIN
      v_stage := '1';
      g_log_msg :=
            'STARTED Index Rebuild for tables part of policy: '
         || NVL (in_policy_name, 'All Policies')
         || 'at '
         || TO_CHAR (SYSDATE, 'mm/dd/yyyy hh24:mi:ss');
      log_activity (g_log_msg, g_msg_type_info);
      v_iteration1 := 0;

      FOR c1
         IN (  SELECT a.*,
                      b.owner t_owner,
                      b.table_name t_table,
                      4 PARALLELISM
                 FROM purge_policy_tables a
                      JOIN purge_policy c ON (a.policy_name = c.policy_name)
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
               || 'is not a valid database table. Not Processing. VALIDATE THE SETUP';
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
               || 'rebuild '
               || c2.partition_name
               || 'online nologging parallel (degree '
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
               || 'logging noparallel';
            g_log_msg := 'Altering index: ' || v_sql;
            log_activity (g_log_msg, g_msg_type_info);

            EXECUTE IMMEDIATE v_sql;
         END LOOP c2;
      END LOOP c1;

      v_stage := '4';
      g_log_msg :=
            'ENDED Index Rebuild for tables part of policy: '
         || NVL (in_policy_name, 'All Policies')
         || 'at '
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
         || 'at '
         || TO_CHAR (SYSDATE, 'mm/dd/yyyy hh24:mi:ss');
      log_activity (g_log_msg, g_msg_type_info);
      v_iteration1 := 0;

      FOR c1
         IN (  SELECT a.*,
                      b.owner t_owner,
                      b.table_name t_table,
                      4 PARALLELISM
                 FROM purge_policy_tables a
                      JOIN purge_policy c ON (a.policy_name = c.policy_name)
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
               || 'is not a valid database table. Not Processing. VALIDATE THE SETUP';
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
         || 'at '
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

   PROCEDURE purge_data (in_policy_name    IN VARCHAR2 DEFAULT NULL,
                         in_gather_stats   IN BOOLEAN DEFAULT FALSE)
   IS
      v_error              VARCHAR2 (4000);
      v_last_commit        DATE;
      v_starttime          DATE;
      v_stoptime           DATE;
      v_count              NUMBER;
      v_stage              VARCHAR2 (20);
      v_partition_column   VARCHAR2 (40);
      v_min_ts             TIMESTAMP (6);
      v_max_ts             TIMESTAMP (6);
      v_sql                VARCHAR2 (3000);
      v_return             NUMBER;
      v_counter            NUMBER;
   BEGIN
      --DBMS_OUTPUT.enable;
      g_purge_id := TO_NUMBER (TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS'));
      g_log_msg :=
            'Archive data initiated for policy: '
         || NVL (in_policy_name, 'All Policies')
         || ' started at '
         || TO_CHAR (SYSDATE, 'mm/dd/yyyy hh24:mi:ss');
      log_activity (g_log_msg, g_msg_type_info);
      v_error := '000';

      --g_log_msg := 'Retreiving the list of policies to process.';
      --log_activity (g_log_msg, g_msg_type_info);

      FOR c1 IN (  SELECT *
                     FROM purge_policy
                    WHERE policy_name = NVL (in_policy_name, policy_name)
                 ORDER BY 1)
      LOOP
         v_starttime := SYSDATE;
         v_last_commit := get_last_commit (c1.retention_months);
         g_log_msg :=
               'Policy Name: '
            || c1.policy_name
            || ', Retention Period: '
            || c1.retention_months
            || ', Purging data older than '
            || TO_CHAR (v_last_commit, 'mm/dd/yyyy');
         log_activity (g_log_msg, g_msg_type_info);
         v_error := 'Begin';
         v_count := -1;

         IF stop_purging
         THEN
            log_activity ('Stop archive requested. Stopping the process. ',
                          g_msg_type_warn);
            EXIT;
         END IF;

         --==--==--==
         v_stage := 1;

         FOR c2 IN (  SELECT *
                        FROM purge_policy_tables
                       WHERE policy_name = c1.policy_name
                    ORDER BY purge_order DESC)
         LOOP
            BEGIN
               v_stage := '2';
               log_activity (
                     'Begin - Policy: '
                  || c2.policy_name
                  || ', Table: '
                  || c2.table_name
                  || ',Purge Order: '
                  || c2.purge_order
                  || ', Purge Method: '
                  || c2.purge_method
                  || ', Purge data older than '
                  || TO_CHAR (v_last_commit, 'mm/dd/yyyy'),
                  g_msg_type_info);

               IF c2.PURGE_ORDER = 0
               THEN
                  log_activity (
                     'Skipping table/partition since it is a ref partitioned child.',
                     g_msg_type_info);
                  CONTINUE;
               END IF;

               v_stage := '3';

               SELECT COUNT (1),
                      COUNT (CASE WHEN interval = 'YES' THEN 1 END)
                 INTO v_count, v_counter
                 FROM user_tab_partitions
                WHERE table_name = c2.table_name;

               IF v_count = 1
               THEN
                  log_activity (
                     'Skipping table/partition since it has only 1 partition.',
                     g_msg_type_info);
                  CONTINUE;
               END IF;

               IF v_counter > 0
               THEN
                  log_activity (
                     'Fixing table partitioning to handle possible ORA-14758',
                     g_msg_type_info);

                  v_sql :=
                        'alter table '
                     || c2.table_name
                     || ' set interval ( numtoyminterval (1,''MONTH'') )';
                  g_log_msg := 'Executing SQL: ' || v_sql;
                  log_activity (g_log_msg, g_msg_type_info);

                  EXECUTE IMMEDIATE v_sql;
               END IF;

               v_stage := 3.1;
               log_activity ('Disabling Constraints', g_msg_type_info);

               handle_constraints (c2.table_name, 'DISABLE', v_return);

               v_stage := '4';
               log_activity (
                  'Getting partitioned column for table ' || c2.table_name,
                  g_msg_type_info);

               SELECT column_name
                 INTO v_partition_column
                 FROM dba_part_key_columns
                WHERE     owner = 'OTAR_OT_ARCH'
                      AND object_type = 'TABLE'
                      AND name = c2.table_name;

               v_sql :=
                     'SELECT MIN ('
                  || v_partition_column
                  || '), MAX ('
                  || v_partition_column
                  || ') FROM '
                  || c2.table_name
                  || ' a';
               v_stage := 5;
               log_activity ('Executing SQL: ' || v_sql, g_msg_type_info);

               EXECUTE IMMEDIATE v_sql INTO v_min_ts, v_max_ts;

               log_activity (
                     'Before archive '
                  || c2.table_name
                  || '. Min_ts: '
                  || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
                  || ', Max_ts '
                  || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss')
                  || '. Purging data older than '
                  || TO_CHAR (v_last_commit, 'mm/dd/yyyy'),
                  g_msg_type_info);

               v_stage := 6;
               v_count := 0;

               FOR c3
                  IN (SELECT partition_name, partition_high_value_date
                        FROM TABLE (
                                get_partitions_for_purge ('OTAR_OT_ARCH',
                                                          c2.table_name,
                                                          v_last_commit)))
               LOOP
                  SELECT COUNT (1)
                    INTO v_counter
                    FROM user_tab_partitions
                   WHERE table_name = c2.table_name;

                  IF v_counter = 1
                  THEN
                     log_activity (
                           'Skipping table/partition since it has only 1 partition: '
                        || c3.partition_name
                        || ', high value '
                        || TO_CHAR (c3.partition_high_value_date,
                                    'yyyy-mm-dd'),
                        g_msg_type_info);
                     EXIT;
                  END IF;

                  v_count := v_count + 1;

                  BEGIN
                     v_stage := '6 ';
                     -- ALTER TABLE sales DROP PARTITION FOR(TO_DATE('01-SEP-2007','dd-MON-yyyy'));
                     v_sql :=
                           'alter table otar_ot_arch.'
                        || c2.table_name
                        || ' drop partition '
                        || c3.partition_name
                        || ' update global indexes';

                     log_activity (
                           'Partition '
                        || c3.partition_name
                        || ', high value '
                        || TO_CHAR (c3.partition_high_value_date,
                                    'yyyy-mm-dd')
                        || '. Executing SQL: '
                        || v_sql,
                        g_msg_type_info);

                     EXECUTE IMMEDIATE v_sql;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        log_activity (
                              'Unable to drop partition '
                           || c3.partition_name
                           || ' due to: '
                           || SUBSTR (SQLERRM, 1, 2500),
                           g_msg_type_error);
                  END;
               END LOOP c3;

               IF v_count = 0
               THEN
                  log_activity (
                     'No Partitions to be dropped for ' || c2.table_name,
                     g_msg_type_info);
               END IF;

               ----
               v_stage := '9';
               log_activity ('Enabling Constraints', g_msg_type_info);

               handle_constraints (c2.table_name, 'ENABLE', v_return);

               ----
               v_stage := '7';
               v_sql :=
                     'SELECT MIN ('
                  || v_partition_column
                  || '), MAX ('
                  || v_partition_column
                  || ') FROM '
                  || c2.table_name
                  || ' a';
               log_activity ('Executing SQL: ' || v_sql, g_msg_type_info);
               v_stage := '8';

               EXECUTE IMMEDIATE v_sql INTO v_min_ts, v_max_ts;

               log_activity (
                     'After archive '
                  || c2.table_name
                  || '. Min_ts: '
                  || TO_CHAR (v_min_ts, 'mm/dd/yyyy hh24:mi:ss')
                  || ', Max_ts '
                  || TO_CHAR (v_max_ts, 'mm/dd/yyyy hh24:mi:ss')
                  || '. Purging data older than '
                  || TO_CHAR (v_last_commit, 'mm/dd/yyyy')
                  || '. #partitions dropped: '
                  || v_count,
                  g_msg_type_info);

               ----
               log_activity (
                     'End - Policy: '
                  || c2.policy_name
                  || ', Table: '
                  || c2.table_name
                  || ',Purge Order: '
                  || c2.purge_order
                  || ', Purge Method: '
                  || c2.purge_method
                  || ', Purge data older than '
                  || TO_CHAR (v_last_commit, 'mm/dd/yyyy'),
                  g_msg_type_info);
            ----
            EXCEPTION
               WHEN OTHERS
               THEN
                  log_activity (
                        'Purge error in C2 at '
                     || v_stage
                     || ' due to '
                     || SUBSTR (SQLERRM, 1, 2500),
                     g_msg_type_error);
            END;
         END LOOP c2;

         v_error := '000';
         --==--==--==
         log_activity (
               'Done purging for policy: '
            || c1.policy_name
            || ', Return Code: '
            || v_error,
            g_msg_type_info);
         --
         v_stage := '9';

         IF in_gather_stats
         THEN
            gather_table_stats (c1.policy_name);
         END IF;
      --         IF in_rebuild_indexes
      --         THEN
      --            rebuild_indexes (c1.policy_name);
      --         END IF;
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
         v_error := 'purge_data error at ' || v_stage || ' : ' || SQLERRM;
         ROLLBACK;
         log_activity (v_error, g_msg_type_error);
   END purge_data;
----

END purge_pkg;
/