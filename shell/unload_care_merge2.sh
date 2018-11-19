#!/bin/ksh


#OUTPUT_DIR=/ldata/

INPUT_FILE=$2
OUTPUT_FILE=$3
ORAUSER=$4
ORAPASSWORD=$5



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
do (echo "set heading off";echo "set pagesize 0";echo "set feedback off";echo "select COLUMN_NAME from USER_TAB_COLUMNS where lower(table_name)='$line';")|sqlplus -S $ORAUSER/$ORAPASSWORD |awk 'BEGIN {ORS=","} {print} END{print "\n" }' |sed '$d'|sed 's/\,$/\ /'
done`
	 sed "s/[\*]/$COLUMNS/g" $INPUT_FILE >> temp.sql
	 sed 's/,/||'\''|'\''||/g' temp.sql >>temp2.sql
fi
echo "spool off" >>temp2.sql;
echo "@temp2.sql" |sqlplus -S $ORAUSER/$ORAPASSWORD
;;
s)  if [ `echo $2 |egrep -c [\*]` -eq 1 ]
then 
echo "set heading off;" >>tmp1.txt ;
echo "set linesize 500 ;" >>tmp1.txt  ;
echo "set pagesize 0;" >>tmp1.txt  ;
echo "set head off;" >>tmp1.txt  ;
echo "set trimspool on;"  >>tmp1.txt ;
echo "set trim on;"  >>tmp1.txt ;
echo "set termout off;"  >>tmp1.txt ;
echo "set feedback off;" >>tmp1.txt  ;
#echo "set colsep "|";" >>tmp1.txt  ;
echo "spool $OUTPUT_FILE" >>tmp1.txt  ;
echo $2 |sed 's/,/||'\''|'\''||/g' >>tmp1.txt ;
echo "spool off;" >>tmp1.txt 
echo "@tmp1.txt" |sqlplus -S $ORAUSER/$ORAPASSWORD #&& rm tmp1.txt

else

echo "set heading off;" >>tmp1.txt ;
echo "set linesize 500 ;" >>tmp1.txt  ;
echo "set pagesize 0;" >>tmp1.txt  ;
echo "set head off;" >>tmp1.txt  ;
echo "set trimspool on;"  >>tmp1.txt ;
echo "set trim on;"  >>tmp1.txt ;
echo "set termout off;"  >>tmp1.txt ;
echo "set feedback off;" >>tmp1.txt  ;
#echo "set colsep "|";" >>tmp1.txt  ;
echo "spool imm.txt" >>tmp1.txt  ;
COLUMNS=`echo "${INPUT_FILE}" |awk '{ print $4}' |head -1 |while read line 
do (echo "set heading off";echo "set pagesize 0";echo "set feedback off";echo "select COLUMN_NAME from USER_TAB_COLUMNS where lower(table_name)='$line';")|sqlplus -S possyr/pos |awk 'BEGIN {ORS=","} {print} END{print "\n" }' |sed '$d'|sed 's/\,$/\ /'
done`
echo $COLUMNS
echo "${INPUT_FILE}" |sed "s/[\*]/$COLUMNS/g"  >> tmp1.txt
 sed 's/,/||'\''|'\''||/g' tmp1.txt >>tmp2.txt
echo "spool off;" >>tmp2.txt 
echo "@tmp2.txt" |sqlplus -S $ORAUSER/$ORAPASSWORD #&& rm tmp1.txt tmp2.txt
  
fi
;;
esac


