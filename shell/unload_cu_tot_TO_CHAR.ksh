#!/bin/ksh

if [ "$#" -ne 5 ]
then 
echo "This is the help"
echo
echo
echo "You need to provide the following arguments"
echo
echo
echo "1. -f for a file OR -s for a select"
echo
echo
echo "2.The path for FILE OR the select for SELECT"
echo
echo
echo "3.The output file, the one which will contain the unload "
echo
echo
echo "4.Username of database"
echo
echo
echo "5.Password for database"
echo
echo

else

##### UNLOAD TOOL FOR ORACLE DATABASE#####
#####                                #####
#####  CREATED BY: IONUT MOSCALU     #####
#####                                #####
#####                                #####
##########################################


##### Definire Variabile ######
INPUT_FILE=$2            ######
OUTPUT_FILE=$3           ######
ORAUSER=$4               ######
ORAPASSWORD=$5           ######
###############################

## Sectiunea pentru fisiere ce contin selecturi

case $1 in

-f)echo "set heading off;" >> temp2.sql ;
echo "set linesize 500 ;"  >> temp2.sql ;
echo "set pagesize 0;" >> temp2.sql ;
echo "set head off;" >> temp2.sql ;
echo "set trimspool on;" >> temp2.sql ;
echo "set trim on;" >> temp2.sql ;
echo "set termout off;" >> temp2.sql ;
echo "set feedback off;" >> temp2.sql ;
#echo "set colsep "|";" >> temp2.sql ;
echo "spool $OUTPUT_FILE" >>temp2.sql;

### Daca nu este gasita o steluta in campul selectului atunci va modifica virgula cu "||'|'||"

if [ `egrep -c [\*] ${INPUT_FILE}` -lt 1 ]
then 
	if [ `grep -ci "tools_pkg" ${INPUT_FILE}` -lt 1 ]
		then sed 's/,/||'\''|'\''||/g' $INPUT_FILE >>temp2.sql
		else cat $INPUT_FILE |while read line ;do sed "s/,'/#'/g"|sed 's/,/||'\''|'\''||/g'|sed "s/#'/,'/g" >>temp2.sql
	fi

else

### Modifica steluta cu coloanele necesare. Acestea sunt extrase din baza de date inainte de a face unloadul propriu zis.
                
COLUMNS=`awk '{ print $4}' $INPUT_FILE|head -1 |while read line 
do (echo "set heading off";echo "set pagesize 0";echo "set feedback off";echo "select COLUMN_NAME from USER_TAB_COLUMNS where lower(table_name)='$line';")|sqlplus -S $ORAUSER/$ORAPASSWORD |awk 'BEGIN {ORS=","} {print} END{print "\n" }' |sed '$d'|sed 's/\,$/\ /'
done`
         sed "s/[\*]/$COLUMNS/g" $INPUT_FILE >> temp.sql
         sed 's/,/||'\''|'\''||/g' temp.sql >>temp2.sql && rm temp.sql
fi
echo "spool off" >>temp2.sql;
echo "@temp2.sql" |sqlplus -S $ORAUSER/$ORAPASSWORD && rm temp2.sql 
;;

## Sectiune pentru select, Daca nu exista nici o steluta in campul selectului atunci modifica virgula cu "||'|'||"

-s)  if [ `echo "$2" |egrep -c [\*]` -lt 1 ]
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
echo $2|sed "s/,'/#'/g"|sed 's/,/||'\''|'\''||/g'|sed "s/#'/,'/g" >>tmp1.txt ;
#echo $2 |sed 's/,/||'\''|'\''||/g' >>tmp1.txt ;
echo "spool off;" >>tmp1.txt 
echo "@tmp1.txt" |sqlplus -S $ORAUSER/$ORAPASSWORD && rm tmp1.txt

## Daca este descoperita o steluta atunci va extrage coloanele din baza inainde de a face unloadul.

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
echo "spool $OUTPUT_FILE" >>tmp1.txt  ;
COLUMNS=`echo "${INPUT_FILE}" |awk '{ print $4}' |head -1 |while read line 
do (echo "set heading off";echo "set pagesize 0";echo "set feedback off";echo "select COLUMN_NAME from USER_TAB_COLUMNS where lower(table_name)='$line';")|sqlplus -S $ORAUSER/$ORAPASSWORD |awk 'BEGIN {ORS=","} {print} END{print "\n" }' |sed '$d'|sed 's/\,$/\ /'
done`
echo "${INPUT_FILE}" |sed "s/[\*]/$COLUMNS/" >> tmp1.txt
 sed 's/,/||'\''|'\''||/g' tmp1.txt >>tmp2.txt
echo "spool off;" >>tmp2.txt 
echo "@tmp2.txt" |sqlplus -S $ORAUSER/$ORAPASSWORD  && rm tmp1.txt tmp2.txt
  
fi
;;
esac

fi
