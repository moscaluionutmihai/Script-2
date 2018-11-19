#!/usr/bin/ksh

## Script for statistics
## Made by Ionut Moscalu
## Date : 07.01.2015
## Version 1.01

## Help to run the script:
if [ "$#" -ne 6 ]
then 
echo "This is the help"
echo
echo
echo "You need to provide the following arguments"
echo
echo
echo "1. Time start in the following order dd-mm-yyyy HH:MI:SS "
echo
echo
echo "2.Time stop in the following order dd-mm-yyyy HH:MI:SS"
echo
echo
echo "3.The output file name , the one which will contain the unload "
echo
echo
echo "4.Username of database"
echo
echo
echo "5.Password for database"
echo
echo
echo "6.Error log file"
echo
echo
echo " Example :"
echo " Using a file: "
echo " ./statistics.ksh \"03-01-2015 01:00:00\" \"03-01-2015 01:00:00\" unload_actors.unl pos pos error_log.err "
echo 
echo
echo 
echo
exit 0
fi



# SETTING VARIABLES

ORAUSER=$4
ORAPASSWORD=$5
TIME_START=$1
TIME_STOP=$2
ERRORLOGFILE=$6
OUTPUT_FILE=$3

DATE1=`date +"%k"`
DATE2=`date -u +"%k"`
DIFFDATE=$(($DATE1-$DATE2))



# Retrive some information from database
UNIX_DATE_START=`echo "set num 20;
set head off;
select tools_pkg.timetoint8(TO_DATE('${TIME_START}','DD-MM-YYYY HH24:MI:SS')-${DIFFDATE}/24) from dual;" |sqlplus -S ${ORAUSER}/${ORAPASSWORD}|sed "/^$/d" |nawk -FS="|" '{ gsub(/\t/,""); gsub(/ +\|/,"|"); gsub(/\| +/,"|"); gsub(/^ */,""); gsub(/ *$/,""); print }'`


UNIX_DATE_STOP=`echo "set num 20;
set head off;
select tools_pkg.timetoint8(TO_DATE('${TIME_STOP}','DD-MM-YYYY HH24:MI:SS')-${DIFFDATE}/24) from dual;" |sqlplus -S ${ORAUSER}/${ORAPASSWORD}|sed "/^$/d" |nawk -FS="|" '{ gsub(/\t/,""); gsub(/ +\|/,"|"); gsub(/\| +/,"|"); gsub(/^ */,""); gsub(/ *$/,""); print }'`


TIME_INTERVAL_START=`echo "${TIME_START}" |awk '{print $2}' `
TIME_INTERVAL_STOP=`echo "${TIME_STOP}" |awk '{print $2}' `

#TIME_INTERVAL_START_M=`echo "${TIME_START}" |awk '{print $2}' `
#TIME_INTERVAL_STOP_M=`echo "${TIME_STOP}" |awk '{print $2}' `

#TIME_INTERVAL_START_H=`echo "${TIME_START}" |awk '{print $2}' `
#TIME_INTERVAL_STOP_H=`echo "${TIME_STOP}" |awk '{print $2}' `

# CREATING TABLES

CHECK_TIME=`echo "set num 20;
set head off;
select table_name from user_tables where lower(table_name)='time';" |sqlplus -S ${ORAUSER}/${ORAPASSWORD}|sed "/^$/d" |nawk -FS="|" '{ gsub(/\t/,""); gsub(/ +\|/,"|"); gsub(/\| +/,"|"); gsub(/^ */,""); gsub(/ *$/,""); print }'`

CHECK_TRANSACCOUNT=`echo "set num 20;
set head off;
select table_name from user_tables where lower(table_name)='transaccount';" |sqlplus -S ${ORAUSER}/${ORAPASSWORD}|sed "/^$/d" |nawk -FS="|" '{ gsub(/\t/,""); gsub(/ +\|/,"|"); gsub(/\| +/,"|"); gsub(/^ */,""); gsub(/ *$/,""); print }'`



	if [[ ${CHECK_TIME} == "no rows selected" ]] 
	then
echo "Creating table TIME: ....... "
echo "CREATE TABLE TIME ( ORA VARCHAR2(8 BYTE),COUNT NUMBER );" |sqlplus -S $ORAUSER/$ORAPASSWORD ;
echo " Table TIME created ! "
# Update Time table with values
echo " Updating table TIME :...... "
echo "@insert_in_tab_time.sql" |sqlplus -S $ORAUSER/$ORAPASSWORD 2> $ERRORLOGFILE 1>&2 
echo " Table TIME updated ! "
	else
echo "The TIME table already exist"
	fi
  
  	if [[ ${CHECK_TRANSACCOUNT} == "no rows selected" ]] 
	then
echo "Creating table TRANSACCOUNT: ....... "
echo "CREATE TABLE TRANSACCOUNT ( ORA VARCHAR2(8 BYTE), COUNT NUMBER,OPERSTATE NUMBER);" |sqlplus -S $ORAUSER/$ORAPASSWORD
echo " Table TRANSACCOUNT created ! "
	else
echo "The TRANSACCOUNT table already exist"
	fi
  

# Provide the statistics
if [[ -f "temp2.sql" ]]
then 
rm temp2.sql
fi

echo "set heading off" >> temp2.sql    
echo "set linesize 500"  >> temp2.sql  
echo "set pagesize 0" >> temp2.sql     
echo "set head off" >> temp2.sql       
echo "set trimspool on" >> temp2.sql   
echo "set trim on" >> temp2.sql       
echo "set termout off" >> temp2.sql    
echo "set feedback off" >> temp2.sql   
echo 'set colsep "|"' >> temp2.sql     
echo "spool $OUTPUT_FILE" >>temp2.sql 


# Update TransacCount table with values

echo " Updating table TRANSACCOUNT :...... "


case $7 in

-s)
echo " insert into transaccount 
select TO_CHAR(tools_pkg.TimeInt8ToDateLCL(lastupdate),'HH24:MI:SS'),count(*),operstate 
from transacglobal 
where lastupdate between ${UNIX_DATE_START} and ${UNIX_DATE_STOP}
group by TO_CHAR(tools_pkg.TimeInt8ToDateLCL(lastupdate),'HH24:MI:SS'),operstate; " | sqlplus -S $ORAUSER/$ORAPASSWORD

echo "select time.ora,time.count+nvl(transaccount.count,0),transaccount.operstate
from time
left join transaccount on time.ora=transaccount.ora
where time.ora between '${TIME_INTERVAL_START}' and '${TIME_INTERVAL_STOP}'
order by time.ora; " >>temp2.sql

;;
-m)
echo " insert into transaccount 
select TO_CHAR(tools_pkg.TimeInt8ToDateLCL(lastupdate),'HH24:MI'),count(*),operstate 
from transacglobal 
where lastupdate between ${UNIX_DATE_START} and ${UNIX_DATE_STOP}
group by TO_CHAR(tools_pkg.TimeInt8ToDateLCL(lastupdate),'HH24:MI'),operstate; " | sqlplus -S $ORAUSER/$ORAPASSWORD
;;
-h)
echo " insert into transaccount 
select TO_CHAR(tools_pkg.TimeInt8ToDateLCL(lastupdate),'HH24'),count(*),operstate 
from transacglobal 
where lastupdate between ${UNIX_DATE_START} and ${UNIX_DATE_STOP}
group by TO_CHAR(tools_pkg.TimeInt8ToDateLCL(lastupdate),'HH24'),operstate; " | sqlplus -S $ORAUSER/$ORAPASSWORD
;;
esac


 




echo "spool off" >>temp2.sql

echo " Start to generate the unload on ${OUTPUT_FILE} "

echo "@temp2.sql" |sqlplus -S $ORAUSER/$ORAPASSWORD && rm temp2.sql 

echo " Unload done in  ${OUTPUT_FILE} "

# Clean-up

echo "Start to do clean-up :...... "

echo "truncate table TRANSACCOUNT;" |sqlplus -S $ORAUSER/$ORAPASSWORD

echo " Clean-up done ! "