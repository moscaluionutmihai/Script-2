simphobe@SC01SERV03535:~/sscripts/sh$ cat Insert_SCENARIODEVCOMP.sh
#!/bin/bash
#
#####################################################################
#  Script:              Insert_SCENARIODEVCOMP.sh
#  Description:
#  %created_by:         Mohammed LASSACI %
#  %date_created:       28/05/2014 %



Date=`date +"%Y""%m""%d""%H""%M""%S"`

export NOM_TABLE='Insert_SCENARIODEVCOMP'

export FICHIER_LOG=$HOME/sscripts/log/${NOM_TABLE}.`date +"%Y""%m""%d""%H""%M""%S"`.log
rm -f ${FICHIER_LOG} >/dev/null 2>&1


# CFG file
CFG_FILE=$HOME/sscripts/cfg/Insert_SCENARIODEVCOMP.cfg

if [ -f $CFG_FILE ]
        then
#-------- Variables d'environnement ---------------------------
                . ${CFG_FILE}
#               echo "$FILE_PATH $LOG_PATH $SAS_CONF_DIR $USER_SAS_ORACLE $PASSWORD_SAS_ORACLE $SID_SAS_ORACLE " |tee -a  $FICHIER_LOG
        else
                echo " Conf file $CFG_FILE doesn't exists"  | tee -a ${FICHIER_LOG}
                exit 1
fi


# Check ORACLE error
VerifErrORA()
{

        if [ `grep "ORA-" $1 | grep -v "ORA-02289" | wc -l` -ne 0 ]
        then
                echo "\t - ORACLE ERROR "
                exit 1
        fi
}


echo "Start processing : `date`" | tee -a ${FICHIER_LOG}

#######################################################################
# extraction of TAC/Model/Brand from DCE file
#MARKETING_NAME;PRF:SCREENSIZE;PRF:OSNAME;PRF:OSVENDOR;PRF:OSVERSION;WIFI_SUPPORT;NFC_VALIDATED;Brand;Model;Tac Code;User Agent;PRF:SCREENDENSITY

db_connection_url=${USER_SAS_ORACLE:?}/${PASSWORD_SAS_ORACLE:?}@${SID_SAS_ORACLE:?}

#----- sqlplus --------------------------------------------------

    sqlplus -s $db_connection_url @${REP_SQL}/param_Insert_SCENARIODEVCOMP.sql >> $FICHIER_LOG

    VerifErrORA "$FICHIER_LOG"
#-------------------------------------------------------------------------------

echo "Start Insert : $Date" | tee -a ${FICHIER_LOG}
OldTac=0
nbLigne=0
while read ligne
do
   sline=`echo "$ligne" | sed 's/;/#/g' | sed 's/"//g'`
   Brand=`echo "$sline" | awk -F"#" '{print $8}'`
   Model=`echo "$sline" | awk -F"#" '{print $9}'`
   Tac1=`echo "$sline" | awk -F"#" '{print $10}'`
   Tac=`echo "$Tac1" | sed 's/^0*//'`
   TacLength=`printf $Tac | wc -c`

   if [ $nbLigne = 0 ]
   then
                nbLigne=$nbLigne++
                echo "Ignoring first line"

        else
                if [ $Tac != $OldTac  ]
                then
                        if [ $TacLength == 8 ]
                        then
                                echo "Insert line: "  $Brand";"$Model";"$Tac | tee -a ${FICHIER_LOG}

#-------------------------------------------------------------------------------


#----- sqlplus --------------------------------------------------

                                sqlplus -s $db_connection_url @${REP_SQL}/Insert_SCENARIODEVCOMP.sql $Tac $Model $Brand >> $FICHIER_LOG

                                VerifErrORA "$FICHIER_LOG"
#-------------------------------------------------------------------------------
                                OldTac=$Tac
                                nbLigne=$nbLigne++
                        else
                                nbLigne=$nbLigne++
                                echo "TAC $Tac Invalide : $TacLength caract¦res !"
                        fi
                else
                        nbLigne=$nbLigne++
                        echo "Tac "$Tac "already declared"
                fi
        fi
done < $DATA_PATH/MY_DDCCSVDATABASEFILENAME.csv

Date=`date`
#######
#######
echo "Start Insert Add OLD tac : $Date" | tee -a ${FICHIER_LOG}
OldTac=0
nbLigne=0
while read ligne
do
   sline=`echo "$ligne" | sed 's/;/#/g' | sed 's/"//g'`
   Brand=`echo "$sline" | awk -F"#" '{print $8}'`
   Model=`echo "$sline" | awk -F"#" '{print $9}'`
   Tac1=`echo "$sline" | awk -F"#" '{print $10}'`
   Tac=`echo "$Tac1" | sed 's/^0*//'`
   TacLength=`printf $Tac | wc -c`

   if [ $nbLigne = 0 ]
   then
                nbLigne=$nbLigne++
                echo "Ignoring first line"

        else
                if [ $Tac != $OldTac  ]
                then
                        if [ $TacLength == 8 ]
                        then
                                echo "Insert line: "  $Brand";"$Model";"$Tac | tee -a ${FICHIER_LOG}

#-------------------------------------------------------------------------------


#----- sqlplus --------------------------------------------------

                                sqlplus -s $db_connection_url @${REP_SQL}/Insert_SCENARIODEVCOMP.sql $Tac $Model $Brand >> $FICHIER_LOG

                                VerifErrORA "$FICHIER_LOG"
#-------------------------------------------------------------------------------
                                OldTac=$Tac
                                nbLigne=$nbLigne++
                        else
                                nbLigne=$nbLigne++
                                echo "TAC $Tac Invalide : $TacLength caract\350res !"
                        fi
                else
                        nbLigne=$nbLigne++
                        echo "Tac "$Tac "already declared"
                fi
        fi
done < $DATA_PATH/old_tac.csv

#####
#####
echo "End Insert : $Date." | tee -a ${FICHIER_LOG}



#----------------Delete from BlackList-----------------------------------------
echo "Start delete : $Date" | tee -a ${FICHIER_LOG}
while read backlist
do
   service_id=`echo "$backlist" | awk -F";" '{print $1}'`
   Tac=`echo "$backlist" | awk -F";" '{print $2}'`

   echo "Delete line :"  $service_id";"$Tac | tee -a ${FICHIER_LOG}

#----- sqlplus --------------------------------------------------

    sqlplus -s $db_connection_url @${REP_SQL}/Delete_SCENARIODEVCOMP.sql $Tac $service_id >> $FICHIER_LOG

    VerifErrORA "$FICHIER_LOG"
#-------------------------------------------------------------------------------

done < $DATA_PATH/BlackList.csv

Date=`date`
echo "End Delete : $Date" | tee -a ${FICHIER_LOG}

Date=`date`
echo "End processing : $Date" | tee -a ${FICHIER_LOG}
exit 0

simphobe@SC01SERV03535:~/sscripts/sh$
