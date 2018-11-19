#!/bin/bash
# Shell script to monitor or watch the high cpu-load
# It will send an email to $ADMIN, if the (cpu load is in %) percentage
# of cpu-load is >= 70%
#
set -x

if ! [ -f $ALARM_FILE ] ;
then
echo UP > $ALARM_FILE
fi


HOSTNAME=`hostname`
CAT=/bin/cat
MAILFILE=/tmp/Replication_stats
MAILER=/usr/bin/mutt

ALARM_FILE=/home/OT_RUN/Replication_last_state.log
ALARM_SENT_TN=$(cat $ALARM_FILE )

USER="root"
PASSWORD="eelcdadcg"
DB_NAME="EUROVIP"
SELECT_LOG=/tmp/replication.log

DOWN_ALARM_SENT_TN=$(grep DOWN $ALARM_FILE)
NB_ALARM=$(echo $DOWN_ALARM_SENT_TN |cut -d '_' -f2)
NB_TO_ADD=1






function DB { mysql -u $USER -p$PASSWORD  -e "show slave status\G" -s -r $DB_NAME > $SELECT_LOG ; }


 
function check_Slave_IO_Running {
if [ $Slave_IO_Running != "Yes" ] ;
    then
        if [ -z $NB_ALARM ] ;
        then 
        NB_ALARM=0
        fi
            if [ `echo $NB_ALARM` -le 10 ] ;
            then
            echo "Please check Replication on ${HOSTNAME} . Slave_IO_Running is not OK.\nSlave_IO_Running = $Slave_IO_Running. The issue is not resolved until you will not receive a maill in which you will be informed that the replication is OK." > $MAILFILE
            $CAT $MAILFILE | $MAILER -e "set from='$HOSTNAME@truphone.gb' realname='$HOSTNAME@truphone.gb' " -s " $(($NB_ALARM+$NB_TO_ADD)) . Replication is not OK on ${HOSTNAME}. Check Slave_IO_Running." $mailto
            echo "DOWN_$(($NB_ALARM+$NB_TO_ADD))" > $ALARM_FILE
            fi
fi
}

function check_Slave_SQL_Running {
if [ $Slave_SQL_Running != "Yes" ] ;
    then
        if [ -z $NB_ALARM ] ;
        then 
        NB_ALARM=0
        fi
            if [ `echo $NB_ALARM` -le 10 ] ;
            then
            echo "Please check Replication on ${HOSTNAME} . Slave_SQL_Running is not OK.\nSlave_SQL_Running = $Slave_SQL_Running. The issue is not resolved until you will not receive a maill in which you will be informed that the replication is OK.  " > $MAILFILE
            $CAT $MAILFILE | $MAILER -e "set from='$HOSTNAME@truphone.gb' realname='$HOSTNAME@truphone.gb' " -s " $(($NB_ALARM+$NB_TO_ADD)) Replication is not OK on ${HOSTNAME}. Check Slave_SQL_Running ." $mailto
            echo "DOWN_$(($NB_ALARM+$NB_TO_ADD))" > $ALARM_FILE
            fi
fi
}

function check_Seconds_Behind_Master {
if [ $Seconds_Behind_Master -ne 0 ] ;
    then
        if [ -z $NB_ALARM ] ;
        then 
        NB_ALARM=0
        fi
            if [ `echo $NB_ALARM` -le 10 ] ;
            then
            echo "Please check Replication on ${HOSTNAME} . Seconds_Behind_Master is not OK .\nSeconds_Behind_Master = $Seconds_Behind_Master. The issue is not resolved until you will not receive a maill in which you will be informed that the replication is OK." > $MAILFILE
            $CAT $MAILFILE | $MAILER -e "set from='$HOSTNAME@truphone.gb' realname='$HOSTNAME@truphone.gb' " -s " $(($NB_ALARM+$NB_TO_ADD)) . Replication is not OK on ${HOSTNAME}. Check Seconds_Behind_Master ." $mailto
            echo "DOWN_$(($NB_ALARM+$NB_TO_ADD))" > $ALARM_FILE
            fi
fi
}

function check_OK {
if [ $Slave_IO_Running = Yes ] && [ $Slave_SQL_Running = Yes ] && [ $Seconds_Behind_Master -eq 0 ];


then
    if [ `echo $DOWN_ALARM_SENT_TN |grep -ic down` -eq 1 ] ;
    then
    echo "Replication on ${HOSTNAME} is working fine now." > $MAILFILE
    $CAT $MAILFILE | $MAILER -e "set from='$HOSTNAME@truphone.gb' realname='$HOSTNAME@truphone.gb' " -s "Replication is OK on ${HOSTNAME}" $mailto
    echo "UP" > $ALARM_FILE
    fi
exit 0
fi
}

mailto="i.moscalu@oberthur.com"

DB

Slave_IO_Running=$(awk -F':' '/Slave_IO_Running/ {gsub(/^ */,"");printf "%s", $2}' $SELECT_LOG|sed -e "s/ //" )
Slave_SQL_Running=$(awk -F':' '/Slave_SQL_Running:/ {print $2}' $SELECT_LOG|sed -e "s/ //" )
Last_Errno=$(awk -F':' '/Last_Errno/ {print $2}' $SELECT_LOG )
Last_Error=$(awk -F':' '/Last_Error/ {print $2}' $SELECT_LOG )
Seconds_Behind_Master=$(awk -F':' '/Seconds_Behind_Master/ {printf "%d", $2}' $SELECT_LOG )


check_OK

check_Slave_IO_Running

check_Slave_SQL_Running

check_Seconds_Behind_Master
