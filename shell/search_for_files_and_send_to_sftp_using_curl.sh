#!/bin/bash


#set -x


## Checking if we need to prompt the Help. 
if [ $# -lt 4 ]
then
echo 'HELP : 
# $1 = luna
# $2 = anul
# $3 = alegem daca sa facem arhivele sau nu ( 1 nu se face, 2 se face)
# $4 = alegem daca trimitem fisierele catre sftp sau nu (1 nu se trimit, 2 se trimit) ' ; exit 1;
fi


## Seting variables
CREDITWITHDRAW='/opt/mms/misc/files/canal/CREDITWITHDRAW'
HIERARCHYDATA='/opt/mms/misc/files/canal/HIERARCHYDATA'
GENERATEDEVOUCHERS='/opt/mms/misc/files/canal/GENERATEDEVOUCHERS'
ETOPUPTRANSACTIONS='/opt/mms/misc/files/canal/ETOPUPTRANSACTIONS'


NBDAYINMONTH=`date -d "$1/1/$2 + 1 month - 1 day" "+%d"`

## Checking if the files exist
 for i in $(seq 1 $NBDAYINMONTH ) ;
do
CURRDATE=`date +"%d%m%Y" -d "$1/$i/$2"`
ls  $CREDITWITHDRAW'_01_'$CURRDATE.csv;
ls  $HIERARCHYDATA'_01_'$CURRDATE.csv;
ls  $GENERATEDEVOUCHERS'_01_'$CURRDATE.csv;
ls  $ETOPUPTRANSACTIONS'_01_'$CURRDATE.csv;

done 1>/dev/null 2> ~romanialtwo/BI_error_log.log


# Checking if we had a missing file
RESULT=`echo $?`



if [ $RESULT -ne 0 ]
then
echo " There is a file missing , exiting. Check the error logfile located under ~romanialtwo/BI_error_log.log" ; exit 1;
else
echo " All files are present "
fi

# Create archives (or not)
case "$3" in 

1) echo " You choused to not create the archives ,and to not send them." ; exit 0;

;;

2) echo "ok, generating archive files"
tar -czvf /opt/mms/misc/files/canal/CREDITWITHDRAW_$1_$2.tar.gz /opt/mms/misc/files/canal/$CREDITWITHDRAW'_01_*_'$1"_"$2.csv
echo "CREDITWITHDRAW_$1_$2.tar.gz has been generated"
tar -czvf /opt/mms/misc/files/canal/HIERARCHYDATA_$1_$2.tar.gz /opt/mms/misc/files/canal/$HIERARCHYDATA'_01_*_'$1"_"$2.csv
echo "HIERARCHYDATA$1_$2.tar.gz has been generated"
tar -czvf /opt/mms/misc/files/canal/GENERATEDEVOUCHERS_$1_$2.tar.gz /opt/mms/misc/files/canal/$GENERATEDEVOUCHERS'_01_*_'$1"_"$2.csv
echo "GENERATEDEVOUCHERS$1_$2.tar.gz has been generated"
tar -czvf /opt/mms/misc/files/canal/ETOPUPTRANSACTIONS_$1_$2.tar.gz /opt/mms/misc/files/canal/$ETOPUPTRANSACTIONS'_01_*_'$1"_"$2.csv
echo "ETOPUPTRANSACTIONS$1_$2.tar.gz has been generated"

        # Send the archives (or not)
        case "$4" in

        1) echo " You choused to not send the archives"

        ;;

        2) echo " We are sending the archives now ... "
        curl -u evoucher_romania:bus12@{478  -T /opt/mms/misc/files/canal/CREDITWITHDRAW_$1"_"$2.tar.gz sftp://192.168.177.101 
        curl -u evoucher_romania:bus12@{478  -T /opt/mms/misc/files/canal/HIERARCHYDATA_$1"_"$2.tar.gz sftp://192.168.177.101
        curl -u evoucher_romania:bus12@{478  -T /opt/mms/misc/files/canal/GENERATEDEVOUCHERS_$1"_"$2.tar.gz sftp://192.168.177.101 
        curl -u evoucher_romania:bus12@{478  -T /opt/mms/misc/files/canal/ETOPUPTRANSACTIONS_$1"_"$2.tar.gz sftp://192.168.177.101
        ;;
        esac




;;
esac

