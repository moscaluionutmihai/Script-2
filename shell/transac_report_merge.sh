#!/bin/sh


## Variable
ACTUALDATE=`date +"%Y%m%d%k%M%S"`
REP_DIR=/var/opt/FERMA/reports
REP_FILE_INT=$REP_DIR/TIMESTAMP
BKP_DIR=/var/opt/FERMA/reports/MPOS_REP_bkp
touch -t `TZ=GMT+8 date '+%y%m%d%H%M'` ${REP_DIR}/TIMESTAMP  ## create a file 12H older
#touch -t `TZ=GMT+9 date '+%y%m%d%H%M'` ${REP_DIR}/TIMESTAMP ## create a file 13H older


##Main script

for i in `find ${REP_DIR} -name "MPOS_REP*" -f -newer ${REP_FILE_INT} -print`
do  cat $i >> transacreport_$ACTUALDATE.out 
	echo $i >> transacreport_result_$ACTUALDATE.log
	mv $i $BKP_DIR/
done


