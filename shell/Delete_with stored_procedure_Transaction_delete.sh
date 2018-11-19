#!/bin/bash

set -x
. /home/oracle/dba/scripts/define mmso

IS_RUNNING=0
DATE=`date +"%k"`
IS_RUNNING=`grep -c "procedure successfully completed" /home/app/orahome/product/11.2.0.4/sql_result.txt`

if [ -z $IS_RUNNING ] ; then
    IS_RUNNING=0
    fi


if [ $DATE -gt 17 ] && [ $DATE -lt 22 ] ;then
    if [ $IS_RUNNING -ge 1 ] ; then

        OLD_DATE_TO_DELETE=`grep execute /home/app/orahome/product/11.2.0.4/delete.sql|awk -F"'" '{print $2}'`
        OLD_YEAR_TO_DELETE=`echo $OLD_DATE_TO_DELETE |awk -F"-" '{print $1}'`
        OLD_DAY_TO_DELETE=`echo $OLD_DATE_TO_DELETE |awk -F"-" '{print $2}'`

        if [ $OLD_DAY_TO_DELETE -gt 07 ] && [ $OLD_DAY_TO_DELETE -lt 10 ] ; then
        OLD_DAY_TO_DELETE=`echo $OLD_DAY_TO_DELETE |awk -F"0" '{print $2}'`
        fi

        NEXT_TO_DELETE=$((OLD_DAY_TO_DELETE + 1))
            if [ $NEXT_TO_DELETE -lt 10 ] ; then
            NEXT_TO_DELETE=`echo -n "0"$NEXT_TO_DELETE`
            fi

            if [ $OLD_DAY_TO_DELETE -eq 12 ] ; then
            OLD_YEAR_TO_DELETE=$((OLD_YEAR_TO_DELETE +1))
            NEXT_TO_DELETE=01
            fi

            DATE_TO_DELETE=`echo -n $OLD_YEAR_TO_DELETE"-"$NEXT_TO_DELETE`
            mv /home/app/orahome/product/11.2.0.4/sql_result.txt /home/app/orahome/product/11.2.0.4/sql_result_$DATE_TO_DELETE.txt
            sed -i -e "s/$OLD_DATE_TO_DELETE/$DATE_TO_DELETE/g" /home/app/orahome/product/11.2.0.4/delete.sql

        /home/app/orahome/product/11.2.0.4/delete.sh >/home/app/orahome/product/11.2.0.4/error_cron.log 2>&1
    fi
fi
