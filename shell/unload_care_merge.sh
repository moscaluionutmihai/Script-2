#!/bin/ksh


#OUTPUT_DIR=/ldata/
OUTPUT_FILE=$3
INPUT_FILE=$2



case $1 in

f)echo "set heading off;" >> temp2.sql ;
echo "set linesize 500 ;"  >> temp2.sql ;
echo "set pagesize 0;" >> temp2.sql ;
echo "set head off;" >> temp2.sql ;
echo "set trimspool on;" >> temp2.sql ;
echo "set trim on;" >> temp2.sql ;
echo "set termout off;" >> temp2.sql ;
echo "set feedback off;" >> temp2.sql ;
#echo "set colsep "|";" >> temp2.sql ;
echo "spool $OUTPUT_FILE" >>temp2.sql;

if [ -z `grep '*' ${INPUT_FILE}` ]
then sed 's/,/||'\''|'\''||/g' $INPUT_FILE >>temp2.sql
else

#Modifica steluta cu coloanele necesare		
COLUMNS=`awk '{ print $4}' $INPUT_FILE|head -1 |while read line 
do (echo "set heading off";echo "set pagesize 0";echo "set feedback off";echo "select COLUMN_NAME from USER_TAB_COLUMNS where lower(table_name)='$line';")|sqlplus -S vomssyr/voms |awk 'BEGIN {ORS=","} {print} END{print "\n" }' |sed '$d'|sed 's/\,$/\ /'
done`
	 sed "s/[\*]/$COLUMNS/g" $INPUT_FILE >> temp.sql
	 sed 's/,/||'\''|'\''||/g' temp.sql >>temp2.sql
fi
echo "spool off" >>temp2.sql;
echo "@temp2.sql" |sqlplus -S vomssyr/voms
;;
s)echo "set heading off;" >> temp2.sql ;
echo "set linesize 500 ;"  >> temp2.sql ;
echo "set pagesize 0;" >> temp2.sql ;
echo "set head off;" >> temp2.sql ;
echo "set trimspool on;" >> temp2.sql ;
echo "set trim on;" >> temp2.sql ;
echo "set termout off;" >> temp2.sql ;
echo "set feedback off;" >> temp2.sql ;
#echo "set colsep "|";" >> temp2.sql ;
echo "spool $OUTPUT_FILE" >>temp2.sql;
echo $2 
;;
esac


awk '{ print $4}' list2.txt|head -1 |while read line 
do (echo "set heading off";echo "set pagesize 0";echo "set feedback off";echo "select COLUMN_NAME from USER_TAB_COLUMNS where lower(table_name)='$line';")|sqlplus -S vomssyr/voms |awk 'BEGIN {ORS=","} {print} END{print "\n" }' |sed '$d'|sed 's/\,$/\ /'|sed 's/,/||'\''|'\''||/g';done


awk '{$0=substr($0,1,length($0)-5); print $0}'

awk '{ print $4}' list2.txt|head -1 |while read line ;do (echo "set heading off";echo "select * from USER_TAB_COLUMNS where table_name='\''$line\''';")|sqlplus -S vomssyr/voms;done

select * from USER_TAB_COLUMNS where table_name='ACTOR';

for i in `ls -ltr |grep "update_voucher_state_a*" |awk '{print $9}'`;do echo 'set lock mode to wait 5;' | cat - $i > temp.sql && mv temp.sql $i;done 

sed 's/,/||'\''|'\''||/g' 1_test.sh >1.txt
