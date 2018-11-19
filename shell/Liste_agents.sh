
lsav@paymob10 > cat /var/opt/FERMA/voms/DAILY_REPORTS_POS/AGENT/Liste_Agents.sh
#!/bin/ksh
# CTR 119116 - WTA ListeAgent and ListeGroup scripts

# log file: Liste_Agents20060605.data

#- Chargement de l'env oracle


. $( echo ~oracle )/.profile

clear

# *** CAUTION : the parameters below must be set to your site values ***
dbuser=db_pos_wta
dbpasswd=db_pos_wta
dbSID=POS
WHERE=/export/home/lsav

#
cd $WHERE

_filename=Liste_Agents
_extention=data
_date=`date +%Y%m%d`
StatFileName=$_filename$_date.$_extention

for _log in `ls *.$_extention | grep -v $StatFileName` ; do rm $_log; done 1>/dev/null 2>&1

StatFileName=Liste_Agents$_date.data
echo $StatFileName
if [ -f $StatFileName ]; then
        cat $StatFileName
        echo ""
        echo "#Lists are generated in file '$WHERE/$StatFileName'."
        exit 1
fi

#-----------------------------------
# Extraction des statistiques
#-----------------------------------
sqlplus -S ${dbuser}/${dbpasswd}@${dbSID} << EOF > $$.tmp

  SET SERVEROUTPUT ON
  
  SET LINESIZE 1300

  BEGIN
   support_pos_pkg.listeAgents();
  END;
/
  EXIT;
EOF
cat $$.tmp | grep -v "procedure successfully completed" \
      | awk '{ if($1>='300') {print $0} } ' > $$.stat
rm  $$.tmp

#-----------------------------------
# Preparation de l'entete du fichier
#-----------------------------------
echo "#List of POS Agents" | tee -a $$.data
echo "#Command used: $0 " | tee -a $$.data
echo "#List generated at `date +%Y/%m/%d`" | tee -a $$.data

echo "#In following, each frame is composed with a set of fields separated per pipe '|'" | tee -a $$.data
echo "#Signification of fields:" | tee -a $$.data
echo "Actor Id
State
Suspension for MSISDN
Suspension for User
Profil
Username
MSISDN
FirstName
LastName
Supplementary information
STORM Balance Credit
STORM-SCRATCH Balance Credit" > $$.erreurs

awk '{printf("#\t%3s. %s\n",NR,$0)}' $$.erreurs | tee -a $$.data

#echo "#Number of lines generated: `wc -l $$.stat | awk '{print $1}'`" | tee -a $$.data
nb_line="#Number of lines generated: $( wc -l $$.stat | awk '{print $1}' )"
cat $$.stat | tee -a $$.data

mv $$.data $StatFileName
echo $nb_line
echo $nb_line >> $StatFileName
echo "#Lists are generated in file '$WHERE/$StatFileName'."

rm $$.erreurs $$.stat 1>/dev/null 2>&1

lsav@paymob10 > 
