DROP TABLE gtt_archive_temp;

CREATE GLOBAL TEMPORARY TABLE gtt_archive_temp
(
   num_col1    NUMBER,
   char_col1   VARCHAR2 (100)
) ON COMMIT DELETE ROWS;