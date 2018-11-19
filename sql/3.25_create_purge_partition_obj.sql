DROP TYPE purge_partition_tab;
DROP TYPE purge_partition_obj;

CREATE TYPE purge_partition_obj AS OBJECT
(
   partition_name VARCHAR2 (100),
   partition_high_value_date DATE
)
/


CREATE TYPE purge_partition_tab AS TABLE OF purge_partition_obj
/
