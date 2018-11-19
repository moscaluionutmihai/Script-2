#!/usr/bin/ksh

## Script for statistics
## Made by Ionut Moscalu
## Date : 07.01.2015
## Version 1.01
## Description : This tool will generate a report file from maximum 24 H interval , with each second,hour or minute, even if in that interval no transaction were found into database.


## Help to run the script:
if [ "$#" -ne 6 ]
then 
echo "This is the help"
echo " If there is the first run of the script on this site please be sure you have insert_in_tab_time.sql file in the same location"
echo
echo "This tool can extract data from one single day "
echo
echo "You need to provide the following arguments"
echo
echo 
echo "1.-s second  -m minute  -h hour"
echo
echo  
echo "2.Time start in the following order dd-mm-yyyy HH24:MI:SS"
echo
echo
echo "3.Time stop in the following order dd-mm-yyyy HH24:MI:SS"
echo
echo
echo "4.The output file name , the one which will contain the unload "
echo
echo
echo "5.Username of database"
echo
echo
echo "6. Password for database"
echo
echo
echo " Example :"
echo " Using a file: "
echo " ./stats_int.ksh -s \"21-01-2015 01:00:00\" \"21-01-2015 13:00:00\" unload_actors.unl pos pos "
echo 
echo
echo 
echo
exit 0
fi

###############################################################################
#
# Check another instance of stats_int is not running
#
###############################################################################

function do_check_running
{
        COUNT=`ps -ef | grep $0 |grep -v grep| wc -l| awk '{print $1}'`
        #Deduce self and grep from count
        let COUNT=$COUNT-1
        if [ "$COUNT" -gt 0 ]
        then
                echo "$COUNT instance(s) of stats_int already running! Please try again later."
                exit 1
        fi
        echo "No other instance of stats_int running."
        return 0
}

do_check_running

# SETTING VARIABLES

ORAUSER=$5
ORAPASSWORD=$6
TIME_START=$2
TIME_STOP=$3
ERRORLOGFILE=`date +%H_%M_%S`_error.err
OUTPUT_FILE=$4

DATE1=`date +"%k"`
DATE2=`date -u +"%k"`
DIFFDATE=$(($DATE1-$DATE2))



# Retrive some information from database
UNIX_DATE_START=`echo "set num 20;
set head off;
select round(((( to_date('${TIME_START}','DD-MM-YYYY hh24:mi:ss') - date '1970-01-01' )-${DIFFDATE}/24) * 60 * 60 * 24))*1000 from dual;" |sqlplus -S ${ORAUSER}/${ORAPASSWORD}|sed "/^$/d" |nawk -FS="|" '{ gsub(/\t/,""); gsub(/ +\|/,"|"); gsub(/\| +/,"|"); gsub(/^ */,""); gsub(/ *$/,""); print }'`


UNIX_DATE_STOP=`echo "set num 20;
set head off;
select round(((( to_date('${TIME_STOP}','DD-MM-YYYY hh24:mi:ss') - date '1970-01-01' )-${DIFFDATE}/24) * 60 * 60 * 24))*1000 from dual;" |sqlplus -S ${ORAUSER}/${ORAPASSWORD}|sed "/^$/d" |nawk -FS="|" '{ gsub(/\t/,""); gsub(/ +\|/,"|"); gsub(/\| +/,"|"); gsub(/^ */,""); gsub(/ *$/,""); print }'`


TIME_INTERVAL_START=`echo "${TIME_START}" |awk '{print $2}' `
TIME_INTERVAL_STOP=`echo "${TIME_STOP}" |awk '{print $2}' `


# CREATING TABLES

CHECK_TIME=`echo "set num 20;
set head off;
select table_name from user_tables where lower(table_name)='time';" |sqlplus -S ${ORAUSER}/${ORAPASSWORD}|sed "/^$/d" |nawk -FS="|" '{ gsub(/\t/,""); gsub(/ +\|/,"|"); gsub(/\| +/,"|"); gsub(/^ */,""); gsub(/ *$/,""); print }'`



	if [[ ${CHECK_TIME} == "no rows selected" ]] 
	then
echo "Creating table TIME: ....... "
echo "CREATE TABLE TIME(	ORA VARCHAR2(8), SUC NUMBER,FAILED NUMBER,OTHER NUMBER);" |sqlplus -S $ORAUSER/$ORAPASSWORD ;
echo " Table TIME created ! "
# Update Time table with values
echo " Updating table TIME :...... "


		if [[ -f "insert_in_tab_time.sql" ]]
		then
		echo "@insert_in_tab_time.sql" |sqlplus -S $ORAUSER/$ORAPASSWORD 2> $ERRORLOGFILE 1>&2 
		echo " Table TIME updated ! "
		else echo "the  insert_in_tab_time.sql file is missing"
		exit 1
		fi
	else
echo "The TIME table already exist"
	fi
  

	
## creating stored procedure

sqlplus -S ${ORAUSER}/${ORAPASSWORD} << EOF

CREATE OR REPLACE PROCEDURE transaction ( v_unix_date_start number,
										  v_unix_date_stop number)
  AS
      v_ora       	varchar2(50);
      v_count       number;
      v_suc    	    number;
      v_failed    	number;
      v_other     	number;
      v_state       number;


   CURSOR c_transaction IS
        SELECT substr(TO_CHAR(tools_pkg.TimeInt8ToDateLCL(lastupdate),'dd-MM-YYYY HH24:MI:SS'),12,8) ,count(*),operstate
        FROM transacglobal
		where lastupdate between v_unix_date_start and v_unix_date_stop
        group by substr(TO_CHAR(tools_pkg.TimeInt8ToDateLCL(lastupdate),'dd-MM-YYYY HH24:MI:SS'),12,8) ,operstate
        ORDER BY substr(TO_CHAR(tools_pkg.TimeInt8ToDateLCL(lastupdate),'dd-MM-YYYY HH24:MI:SS'),12,8);

  BEGIN

    OPEN c_transaction;
    LOOP
       FETCH c_transaction
       INTO  v_ora, v_count, v_state;
       EXIT WHEN c_transaction%NOTFOUND;
	   

       

UPDATE time
set suc = case
WHEN v_state = 61 THEN v_count 
else suc
END
, failed = case
WHEN v_state = 103 THEN v_count
else failed
END
, other = case
WHEN v_state not in (61,103) THEN v_count
else other
END
where ora = v_ora;
                         

    END LOOP;
    CLOSE c_transaction;
    RETURN;
  END;
  /
EOF

## Update counters to zero in order to be sure there aren't any old values there
echo "update time set suc=0,failed=0,other=0;" |sqlplus -S $ORAUSER/$ORAPASSWORD 2> $ERRORLOGFILE 1>&2 
 
## Updating the time table with count from transacglobal table 
echo "execute transaction(${UNIX_DATE_START},${UNIX_DATE_STOP});" |sqlplus -S $ORAUSER/$ORAPASSWORD 2> $ERRORLOGFILE 1>&2 

#####

# Provide the statistics

## Delete temp2.sql file in case it exist
if [[ -f "temp2.sql" ]]
then 
rm temp2.sql
fi

## Prepare the unload file 
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


# Provide statistics

echo " Providing statistics :...... "


case $1 in

-s)
echo "select ora|| '|' || sum(suc)|| '|' || sum(failed)|| '|' ||sum(other)
 from time
 where ora between '${TIME_INTERVAL_START}' and '${TIME_INTERVAL_STOP}'
group by ora order by ora ; " >>temp2.sql
;;
-m)
echo "select substr(ora,1,5)|| '|' || sum(suc)|| '|' || sum(failed)|| '|' ||sum(other)
 from time 
 where ora between '${TIME_INTERVAL_START}' and '${TIME_INTERVAL_STOP}'
 group by substr(ora,1,5) order by substr(ora,1,5); " >>temp2.sql
;;
-h)
echo "select substr(ora,1,2)|| '|' || sum(suc)|| '|' || sum(failed)|| '|' ||sum(other) 
from time 
where ora between '${TIME_INTERVAL_START}' and '${TIME_INTERVAL_STOP}'
group by substr(ora,1,2) order by substr(ora,1,2); " >>temp2.sql
;;
esac

echo "spool off" >>temp2.sql

echo " Start to generate the unload on ${OUTPUT_FILE} "

echo "@temp2.sql" |sqlplus -S $ORAUSER/$ORAPASSWORD && rm temp2.sql 

TM_LCL_START=`echo "set num 20;
set head off;
select TO_CHAR(tools_pkg.TimeInt8ToDateLCL(${UNIX_DATE_START}),'dd-MM-YYYY HH24:MI:SS') from dual; "|sqlplus -S $ORAUSER/$ORAPASSWORD`

TM_LCL_STOP=`echo "set num 20;
set head off;
select TO_CHAR(tools_pkg.TimeInt8ToDateLCL(${UNIX_DATE_STOP}),'dd-MM-YYYY HH24:MI:SS') from dual;" |sqlplus -S $ORAUSER/$ORAPASSWORD`

echo " 
####### The header for this unload file is:
 Hour | Successful transactions | Failed Transactions | Other Transactions (all other transactions which are not in 61 or 103 operstate) " |cat - ${OUTPUT_FILE} > temp && mv temp ${OUTPUT_FILE}

echo " Unload done in  ${OUTPUT_FILE} for timestamp between ${TM_LCL_START} and ${TM_LCL_STOP} "







