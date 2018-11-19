lsav@DU_L3>cat build_base.sh
#!/usr/bin/ksh
#
# ---------------------------------------------------
# $Source: /cvs/cvsvoms_ng/ORA_PayM_DATABASE/scripts/build_base.sh,v $
# $Revision: 1.3 $
# $Date: 2012-02-16 13:45:31 $
# $Author: scirstoiu $
# ---------------------------------------------------
#
#(#)--  ============================================================
#(#)--  Script name       :  build_base.sh
#(#)--  Database          :  ORACLE
#(#)--  Author            :  AJA
#(#)--  Creation date     :  29/09/2009
#(#)--  Description       :  Script that creates the common part of the
#(#)--                    :  Oracle schema for Paymobile
#(#)--  Code review date  :
#(#)--                by  :
#(#)--  Modification date :
#(#)--                by  :
#(#)--  Description       :
#(#)--  ============================================================
#
# Options
#      -b : "batch mode". No question is asked. If some parameters are missing (ORACLE_SID,...), it returns an error
#      -u USERNAME : user name corresponding to the schema on which tables are created
#      -p PASSWORD : The user's password 
#

#---------------------------
# Define the local variables
#---------------------------
# script is always run in batch mode
BATCH="Y"

typeset user=""
typeset password=""
typeset _Log_File=""


TABLE_FILE="cre_all_table.sql"
INDEX_FILE="cre_all_idx.sql"
PK_FILE="cre_all_pk.sql"
SEQ_FILE="cre_all_seq.sql"
TAG_FILE="cre_tag_ins.sql"


clear

#----------------------------
# Check the input parameters
#----------------------------
test_param()
{
   cpt=1
   nbparam=$#
   while [ $cpt -le $nbparam ]
   do
      case "$1" in
         '-u') if [ "$2" = "" ]
               then
                  echo ""
                  echo "                  **** The user name is mandatory ****"
                  exit 1
               else
                  user=$2
               fi
               let cpt=cpt+1
               shift ;;
         '-p') password="$2"
               if [ "`echo ${password} | cut -c0-1`" = "-" -o "x${password}" = "x" ]
               then
                  echo ""
                  echo "                  **** The user's password is mandatory ****"
                  exit 2
               fi
               let cpt=cpt+1
               shift ;;
         '-l') _Log_File="$2"
               if [ "$2" = "" ]
               then
                  echo ""
                  echo "                  **** The log file is mandatory ****"
                  exit 3
               fi
               let cpt=cpt+1
               shift ;;     
            *) echo ""
               echo "                          **** Invalid option ****"
               exit 4 ;;
      esac
      shift
      let cpt=cpt+1
   done
   echo ""
}

#----------------------------------------------------------------------------
# Function echo2 : a function for adding the text messages in the log files
#----------------------------------------------------------------------------
echo2() {
   if [ -f $_Log_File ]
   then
      echo $1 >> $_Log_File 2>&1
   fi
   printf "$1"
}


#----------------------------------------------------------------------------
# Function execSQL : a function that executes sql files
#----------------------------------------------------------------------------
execSQL() {

   echo "conn ${user}/${password}
         @${1}
        " | sqlplus /nolog >> $_Log_File 2>&1

}

#----------------------------------------------------------------------------
# main
#----------------------------------------------------------------------------
if [ "$#" -ge 1 ]
then
   test_param $*
fi

if [ "x$user" = "x" ]
then
   clear
   echo ""
   echo "ERROR: The username is missing."
   echo ""
   exit 12
fi

if [ "${password}" = "" ]
then
   password="${user}"
fi


#-------------------------------------------
# Check the SQL files
#-------------------------------------------
if [ ! -f ${TABLE_FILE} -o ! -f ${INDEX_FILE} -o ! -f ${PK_FILE} -o ! -f ${SEQ_FILE} -o ! -f ${TAG_FILE} ]
then
   echo "ERROR: Missing SQL file(s)!!! \n"
   exit 5
fi


#----------------------------------
# Creating the Oracle objects
#----------------------------------
echo "Creating tables ... \n"
execSQL ${TABLE_FILE}

echo "Creating indexes ... \n"
execSQL ${INDEX_FILE}

echo "Creating primary keys ... \n"
execSQL ${PK_FILE}

echo "Creating sequences ... \n"
execSQL ${SEQ_FILE}

echo "Inserting data in the [ tagBase ] table for paymobile common ... \n"
cat ${TAG_FILE} | sed 's/\$Name//g' | sed 's/: //g' | sed 's/\$/ /g' > cre_ins_tag_tmp.sql

execSQL cre_ins_tag_tmp.sql
rm cre_ins_tag_tmp.sql




lsav@DU_L3> 
