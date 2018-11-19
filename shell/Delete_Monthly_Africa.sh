#!/bin/bash


# Seting variables
set -x
echo "mmso" |/usr/local/bin/oraenv
export ORACLE_SID=mmso
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/11.2/dbhome_1
export PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/home/oracle/.loc

SQL_FILE=/home/oracle/scripts/cfg/TransactionDelete_Africa.sql

DATE_TO_DELETE=`date +"%Y-%m" -d "13 month ago"`
OLD_DATE_TO_DELETE=`awk -F"'" ' /execute TransactionDelete/ {print $2}' $SQL_FILE`
START_DATE=`date`

ERROR_LOG=/home/oracle/scripts/log/error_cron.log
ZABBIX_FILE=/home/oracle/scripts/cfg/zabbix_state_AFRICA.txt
STATE_OF_PROCESS=/home/oracle/scripts/cfg/state_of_running_Africa.txt


#VALUE_OF_DB=`echo 'set num 20;
#set head off;
#select case when OPEN_MODE='\''READ WRITE'\''  then '\''ACTIVE'\'' ELSE '\''STDBY'\'' END from v$database;' |/u01/app/oracle/product/11.2/dbhome_1/bin/sqlplus -S / as sysdba|sed "/^$/d"  `

VALUE_OF_DB=`echo 'set num 20;
set head off;
select OPEN_MODE from v$database;' |/u01/app/oracle/product/11.2/dbhome_1/bin/sqlplus -S / as sysdba|sed "/^$/d"  `

if [[ "$VALUE_OF_DB" == 'READ WRITE' ]]
then

            #Check state (if 1= still running, if 0=not running)
STATE=$( cat ${STATE_OF_PROCESS})


        if [[ $STATE -eq 0 ]]
        then
        echo "PL/SQL procedure PENDING from $START_DATE" > $ZABBIX_FILE
        echo 1 > ${STATE_OF_PROCESS}
        mv /home/oracle/scripts/TransactionDelete_sql_AFRICA_result.txt /home/oracle/scripts/TransactionDelete_sql_AFRICA_result.txt_$OLD_DATE_TO_DELETE.txt
        sed -i -e "s/$OLD_DATE_TO_DELETE/$DATE_TO_DELETE/g" /home/oracle/scripts/$SQL_FILE
        mv $ERROR_LOG ${ERROR_LOG}_${OLD_DATE_TO_DELETE}
        echo "@${SQL_FILE}" | /u01/app/oracle/product/11.2/dbhome_1/bin/sqlplus canal_plus/wsx3edc > $ERROR_LOG 2>&1
        echo 0 > ${STATE_OF_PROCESS}
        else
        echo " There is an instance running.. skipping "
        fi
#fi


RUN_DATE=`awk -F':' '/TransactionDelete procedure has ended at/  {print $2}' $ERROR_LOG`
RUN_RESULT=`awk '/SQL procedure successfully completed/  {print $0}' $ERROR_LOG `
NB_OF_ROWS=`awk -F':' '/Nb of rows into bill_txn_detail table/  {print $2}' $ERROR_LOG `

    if [[ $RUN_RESULT == 'PL/SQL procedure successfully completed.' ]]
    then
        if [[ $NB_OF_ROWS -gt 0  ]]
        then
        echo " The procedure run with SUCCESS on $RUN_DATE " > $ZABBIX_FILE
        else
        echo " The procedure run but it didn't delete any ROWS. Please CHECK $ERROR_LOG " > $ZABBIX_FILE
        fi
    else
    echo " PL/SQL procedure FAILED to complete. Check $ERROR_LOG " > $ZABBIX_FILE
    fi
else
echo " This is Standby server, so the state should be ignored" > $ZABBIX_FILE
fi
