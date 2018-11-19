#!/bin/ksh

INPUT_FILE=$1
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
COLUMNS=`echo "${INPUT_FILE}" |awk '{ print $4}' ` #|head -1 |while read line 
#do (echo "set heading off";echo "set pagesize 0";echo "set feedback off";echo "select COLUMN_NAME from USER_TAB_COLUMNS where lower(table_name)='$line';")|sqlplus -S $ORAUSER/$ORAPASSWORD |awk 'BEGIN {ORS=","} {print} END{print "\n" }' |sed '$d'|sed 's/\,$/\ /'
#done`
echo $COLUMNS


awk '$2 ~/,[ a-z A-Z ]/ {gsub(/,/, "\|"); print;}' ~/temp.txt

echo "select TO_CHAR(tools_pkg.TimeInt8ToDateLCL(creationdate),'dd-MM-YYYY HH:MI:SS'),TO_CHAR(tools_pkg.TimeInt8ToDateLCL(lastupdate),'dd-MM-YYYY HH:MI:SS') from transacglobal where rownum<2;" |awk '$2 ~/,[ a-z A-Z ]/ {gsub(/,/, "\|"); print;}'
select TO_CHAR(tools_pkg.TimeInt8ToDateLCL(creationdate),'dd-MM-YYYY HH:MI:SS')|O_CHAR(tools_pkg.TimeInt8ToDateLCL(lastupdate),'dd-MM-YYYY HH:MI:SS') from transacglobal where rownum<2;
lsav@cumulus-z1:(ReSP+DB)> 




echo "select state,TO_CHAR(tools_pkg.TimeInt8ToDateLCL(creationdate),'dd-MM-YYYY HH:MI:SS'),TO_CHAR(tools_pkg.TimeInt8ToDateLCL(creationdate),'dd-MM-YYYY HH:MI:SS') from actor ;"
 |sed "s/,'/#'/g"|sed 's/,/||'\''|'\''||/g'|sed "s/#'/,'/g"
 
 select LASTUPDATE||'|'||
 CREATIONDATE||'|'||
OPERERROR||'|'||
IERRORINFO||'|'||
IERROR||'|'||
OPERSTATE||'|'||
THIRDNOTIF_Q||'|'||
THIRDALIASNAME||'|'||
THIRDACTORID||'|'||
RECIPIENTNOTIF_Q||'|'||
RECIPIENTALIASNAME||'|'||
RECIPIENTACTORID||'|'||
SENDERNOTIF_Q||'|'||
SENDERALIASNAME||'|'||
SENDERACTORID||'|'||
STATE||'|'||
TAX||'|'||
CREDIT||'|'||
SESSIONSID||'|'||
PAYMENTMODE||'|'||
UNITVALUEID||'|'||
ACTORID||'|'||
ALIASNAME||'|'||
OPERATION||'|'||
SERVICE||'|'||
ALIASCATEGORY||'|'||
MEDIUM||'|'||
EXTERNALTRANSAC||'|'||
TRANSACID LASTUPDATE||'|'||CREATIONDATE||'|'||
OPERERROR||'|'||IERRORINFO||'|'||IERROR||'|'||OPERSTATE||'|'||THIRDNOTIF_Q||'|'||THIRDALIASNAME||'|'||
THIRDACTORID||'|'||RECIPIENTNOTIF_Q||'|'||RECIPIENTALIASNAME
||'|'||RECIPIENTACTORID||'|'||
SENDERNOTIF_Q||'|'||SENDERALIASNAME||'|'||SENDERACTORID||'|'||STATE||'|'||TAX||'|'||CREDIT||'|'||SESSIONSID
||'|'||PAYMENTMODE||'|'||UNITVALUEID||'|'||
ACTORID||'|'||ALIASNAME||'|'||OPERATION||'|'||SERVICE||'|'||ALIASCATEGORY||'|'||MEDIUM||'|'||EXTERNALTRANSAC||'|'||TRANSACID from transacglobal where rownum<2;
