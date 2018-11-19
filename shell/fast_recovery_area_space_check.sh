#!/bin/bash
#set -x
. /home/oracle/.bashrc
. define mmso
TABLE_FOR_SELECT='V$RECOVERY_FILE_DEST'
DISTRIBUTION_LIST="i.moscalu@oberthur.com solution.hotline@oberthur.com"



SQLDATA=`echo "select name ||'|'|| round(space_limit/1000000)||'|'||round(space_used/1000000) ||'|'|| round((space_used*100)/space_limit) PCT from $TABLE_FOR_SELECT;" | /home/app/orahome/product/11.2.0.4/bin/sqlplus -S / as sysdba |grep "fast_recovery_area"`
 
NAME_OS_SPACE=`echo $SQLDATA |awk -F'|' '{print $1}'`
SAPACE_LIMIT=`echo $SQLDATA |awk -F'|' '{print $2}'`
SPACE_USED=`echo $SQLDATA |awk -F'|' '{print $3}'`
USE_SPACE_PERCENTAGE=`echo $SQLDATA |awk -F'|' '{print $4}'`


if [ $USE_SPACE_PERCENTAGE -gt 10 ] 
then
echo  " Please check urgently the free space from Fast Recovery Area.
 The Limit is set to be $SAPACE_LIMIT MB and we have used $SPACE_USED MB. The used space percentage is $USE_SPACE_PERCENTAGE %.
"|mailx -s "Canal+ Space inside Fast Recovery Area is small.DB side" -r "DoNotReply@OT.com" $DISTRIBUTION_LIST
fi
