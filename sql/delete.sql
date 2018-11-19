set timing on;
spool /home/app/orahome/product/11.2.0.4/sql_result.txt
execute TransactionDelete('2016-09');
spool off;
