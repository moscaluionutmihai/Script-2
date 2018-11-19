lsav@paymob10 > cat /opt/ESG/resources/ORA_POS_PROCESSING/scripts/purge_extract_fragment.sh
#!/bin/ksh
#set -x
#(#)  -------------------------- CVS -----------------------------
#(#)  $Source: /cvs/cvsvoms_ng/ORA_POS_PROCESSING/scripts/purge_extract_fragment.sh,v $
#(#)  $Revision: 1.9.6.1.4.4 $
#(#)  $Date: 2011-07-26 22:41:17 $
#(#)  $Author: xrossard $
#(#)  ------------------------------------------------------------
#(#)  ============================================================
#(#)  Script name       :  purge_extract_fragment.sh
#(#)  Database          :  ORACLE
#(#)  Author            :  KBou     / Daniel Stefaniu
#(#)  Creation date     :  08/09/05
#(#)  Description       :  Script Shell de purge des tables fragmentees
#(#)  Code review date  :
#(#)                by  :
#(#)  Modification date :  29/11/2006
#(#)                by  :  Daniel STEFANIU
#(#)  Description       :  I fixed an unexpected behavior for SautFrag
#(#)                    :  computation
#(#)  Modification date :  20/12/2006
#(#)                by  :  Marian ANDRONE
#(#)  Description       :  I fixed the script so that it won't stop its
#(#)                    :  execution if one or more fragments were not
#(#)                    :  previously detached
#(#)  Modification date :  25/1/2007
#(#)                by  :  Radu BREBEANU
#(#)  Description       :  I have created a new function ("f_execute_sql")
#(#)                    :  to execute SQL statements  and get errors; I have
#(#)                    :  modified all script functions that use SQL
#(#)                    :  statements to call this function.
#(#)  Modification date :  13/01/2007 by LFA
#(#)  Description       :  simplification - remove some non used sql
#(#)                    :                   replace some dynamic sql by non-dynamic (eg : fermaParam select)
#(#)  Modification date :  20/07/2007
#(#)                by  :  Marian ANDRONE
#(#)  Description       :  If the "f_detachadd_frag" function fails, the SQL statement within will be repeated multiple times
#(#)                    :  (depending of "NbIterations") and also, in the traces, information about running SQL processes
#(#)                    :  and about disk status will be inserted.
#(#)  Modification date :  30/07/2007
#(#)                by  :  Marian ANDRONE
#(#)  Description       :  I added two new functions ('f_parse_date' and 'f_delete_old_files') in order to remove the generated files (unload or log files)
#(#)                    :   older than "NbDays4Delete" days. I also modified the config file "purge_extract_fragment.conf", in order to set the value
#(#)                    :   of LOG directory (variable "RepLog"), value needed by the function 'f_delete_old_files'
#(#)  Modification date :  21/08/2007
#(#)                by  :  Marian ANDRONE
#(#)  Description       :  All the french displayed messages were translated into english
#(#)  Modification date :  25/09/2007
#(#)                by  :  Marian ANDRONE
#(#)  Description       :  Add more traces (using the Informix admin tool ONSTAT) if a lock is detected on the working table
#(#)  Modification date :  07/04/2008
#(#)                by  :  Marian ANDRONE
#(#)  Description       :  CFS 33897 -> Correct the function "f_control_file". Also, if the output directory doesn't exist, the output file(s) will
#(#)                    :   be stored in the "/tmp" directory
#(#)  Modification date :  05/06/2008
#(#)                by  :  Marian ANDRONE
#(#)  Description       :  For Informix 10.x, the TRUNCATE function will be used to purge the report tables
#(#)  Modification date :  15/01/2009
#(#)                by  :  Paul Lushey
#(#)  Description       :  Port to Oracle
#(#)  Modification date :  30/01/2009
#(#)                by  :  Marian ANDRONE
#(#)  Description       :  Fix the computation formula for the parameter 'NowFrag'
#(#)  Modification date :  12/02/2009
#(#)                by  :  Marian ANDRONE
#(#)  Description       :  1.Patch for CFS 39503 :
#(#)                    :   - Correct the SQL syntax for TRUNCATE (the keyword "TABLE" was missing)
#(#)                    :  2.The line "WHENEVER sqlerror exit 99;" was added in all the SQL statements.
#(#)                    :    (this helps for retrieving the exit status of each executed SQL statement).
#(#)                    :  3.In the function "f_delete_old_files" the following issues had been fixed :
#(#)                    :     - fix the dates comparison (adaptation to Oracle format)
#(#)                    :     - fix the treatment of old data files
#(#)                    :     - fix the treatment of old log files
#(#)                    :  4.No trailing blanks are allowed at the end of each spooled line (lowers the data file size)
#(#)                    :  5.Fix the function "f_truncate_frag" so that it uses the variable "PurgNumFrag" for computing the
#(#)                    :     current working table (instead of using the "NowFrag" variable).
#(#)  Modification date :  26/11/2009
#(#)                by  :  Marian ANDRONE
#(#)  Description       :  Patch for CTS 98457: - Replace fermaParam by systemParam & FERMALG by ESGLG
#(#)                    :                       - Add a new input param which specifies the output directory
#(#)  Modification date :  17/06/2010
#(#)                by  :  Christian Guinet
#(#)  Description       :  Fault 106173 - Reports maximum number of characters per line is unsufficent
#(#)                    :  - changed linesize from 200 to 2048 during report generation spool command
#(#)  Modification date :  03/01/2011
#(#)                by  :  ENE
#(#)  Description       :  For TSN reports only include the reportTXT column in the output

#(#)============================================================
#(#)

#------------------------------------------------------------------------------
# Local Variables :  Script and Titre
#------------------------------------------------------------------------------

# Parametre
typeset TableName=`echo $1 | tr "[:lower:]" "[:upper:]"`

typeset user=`echo $2 | tr "[:upper:]" "[:lower:]"`
typeset password="${user}"
typeset FileData="toto"    # this is the default value
typeset -i SQL_ERROR=0
typeset SQL_ERROR_MSG=""
typeset SQL_RET_VAL=""

#Initialisation des Variables calcul?
typeset -i NowFrag=0
typeset -i PurgNumFrag=0
typeset PrefixeTab=""
typeset FreqFrag=""
typeset ExprDate=""
typeset -i MaxFrag=0
typeset -i OffsetFrag=0
typeset -i CurrentFrag=0
typeset -i Cnt=0
typeset -i Cpt=0
typeset -i SautFrag=0
typeset -i NumFrag=0
typeset -i NextFrag=0
typeset -i PrevFrag=0
typeset -i FragBase=0
typeset -i LastFrag=0

typeset -i FrequencyInSeconds=0
typeset -i MaxFragAllowedForExtract=0
typeset -i MinFragAllowedForExtract=0

typeset -i days=0
typeset -i month=0
typeset -i year=0

typeset -i seconds=0
typeset -i minutes=0
typeset -i hours=0

typeset nbDaysDiff=""

#Initialisation des codes retours
typeset -i RET_INIT=0
typeset -i RET_COD=0
typeset -i RET_JOB=0

##############
# Parameters #
##############

#Initialisation des Variables Statiques
Etape=""
typeset CompiledString=""        # this variable will be returned by the custom configured CompileName (from configuration file)

typeset PrmTable="systemParam"

typeset DetachTable=${TableName}Tach             # the formula for the names of the tables resulted from detached fragments
typeset DbsName="datadbs"                        # the root of the dbspace name for the fragments
#typeset ExtractDate="CURRENT"                   # the default value of the date of the extraction date
typeset ExtractDate="SYSTIMESTAMP"               # the default value of the date of the extraction date
typeset DB_LOCALE="en_us.utf8"

typeset ConfFileName="purge_extract_fragment.conf"
typeset ConfDir="."

#######################
# do not modify below #
#######################

if [ $# -ne 2 -a $# -ne 3 -a $# -ne 4 ]
then
   echo " ===> Missing Argument"
   echo " Arguments : TableName user OutputPATH [FullPathOfConfigFileName]"
   echo " Command line syntax (e.g.): $0 dailyReport lsav /var/opt/ESG/reports [/tmp/purge_extract_fragment.conf]"

   RET_JOB=1
else
   #-----------------------------------------------------------------------------
   # Execute configuration script
   # -----------------------------------------------------------------------------
   if [ -z $4 ]
   then
      . ${ConfDir}/${ConfFileName} $3
   else
      if [ -f $4 ]
      then
         . $4 $3
      else
         . ${ConfDir}/${ConfFileName} $3
      fi
   fi
fi

SQL_ERR_FILE="${LOG_FILE}.$$.err"

# Liste des param?e de gestion de fragmentation en base par table
## ${TableName}_PREFIXE             : Pr?xe de la table (Unique)
## ${Prefixe}_FRAG_FREQUENCY        : p?odicit?'extraction des donn? (M (mois), D (jour), H (heure)
## ${Prefixe}_FRAG_MAX_NUMBER       : Nombre maximum de fragment de la table en base
## ${Prefixe}_FRAG_OFFSET           : P?odicit?e purge. le fragment (N - x) sera purg?pr?extraction du fragment N
## ${Prefixe}_FRAG_REFRESH          : P?ode de rafra?issement de la recherche des param?es.
## ${Prefixe}_FRAG_EXTRACT_CURRENT  : Num? de fragment en cours de traitement d'extraction.
## ${Prefixe}_FRAG_EXTRACT_LAST     : Num? de fragment extrait pr?dement.
## ${Prefixe}_FRAG_EXTRACT_DATE     : Date de la derni? extraction
## ${Prefixe}_FRAG_EXTRACT_STATE    : Etat de l'extraction True (1) or False (0).
## ${Prefixe}_FRAG_PURGE_CURRENT    : Num? de fragment en cours de traitement de purge.
## ${Prefixe}_FRAG_PURGE_LAST       : Num? de fragment purg?r?dement.
## ${Prefixe}_FRAG_PURGE_DATE       : Date de la derni? purge
## ${Prefixe}_FRAG_PURGE_STATE      : Etat des Purge True (1) or False (0).

set +A PrmTab FREQUENCY MAX_NUMBER OFFSET REFRESH EXTRACT_CURRENT EXTRACT_LAST EXTRACT_DATE EXTRACT_STATE PURGE_CURRENT PURGE_LAST PURGE_DATE PURGE_STATE
set +A VarTab Frequency MaxFrag OffsetFrag RefreshFrag CurExtract lastExtract DateExtract StateExtract CurPurge LastPurge DatePurge StatePurge
set +A PurgTab

# -----------------------------------------------------------------------------
# Function  : Parse dates [ f_parse_date ]
# -----------------------------------------------------------------------------

function f_parse_date {

   String4Parse=$1

   days=0
   month=0
   year=0

   seconds=0
   minutes=0
   hours=0

   String4Parse=`basename ${String4Parse}`
#   String4Parse=`echo ${String4Parse}| sed 's/purge_extract_fragment_//g' | cut -d'_' -f2 | cut -d'.' -f1`
   String4Parse=`echo ${String4Parse}| sed 's/purgeExtractFragment_//g' | cut -d'_' -f2 | cut -d'.' -f1`

   year=`echo | nawk -v inputString=${String4Parse} 'BEGIN{tmpYear=0;}{tmpYear=substr(inputString,1,4);print tmpYear;}'`
   month=`echo | nawk -v inputString=${String4Parse} 'BEGIN{tmpMonth=0;}{tmpMonth=substr(inputString,5,2);print tmpMonth;}'`
   days=`echo | nawk -v inputString=${String4Parse} 'BEGIN{tmpDay=0;}{tmpDay=substr(inputString,7,2);print tmpDay;}'`
}

# -----------------------------------------------------------------------------
# Function  : Removes old files [ f_delete_old_files ]
# -----------------------------------------------------------------------------
function f_delete_old_files {
#   set -x

   f_parse_date ${ZDATE}
   CurrentDate=`echo "${days} ${month} ${year}"`

   echo "#######################################"
   echo "### Begin treating old unload files ###"
   echo "#######################################"
   for unloadFileName in `ls ${RepOut}/${TableName}*.out 2>/dev/null`
   do
      echo "\n ===> Checking the file [ ${unloadFileName} ]"

      f_parse_date ${unloadFileName}
      DateOfFile4Purge=`echo "${days} ${month} ${year}"`

      nbDaysDiff=`echo "conn ${user}/${password}
                  select 'XYZ~'||to_char(to_date('${CurrentDate}','dd mm yyyy')-to_date('${DateOfFile4Purge}','dd mm yyyy')) value from dual;" |
                  sqlplus -SILENT /nolog 2>/dev/null |
                  grep -i 'XYZ~' |
                  cut -d'~' -f2 |
                  sed 's/00:00:00.00000//g' |
                  sed 's/ //g'
                 `
      if [ ${nbDaysDiff} -gt ${NbDays4Delete} ]
      then
         echo "\t ===> The file [ ${unloadFileName} ] will be deleted...\n"
         #Purge the file
         rm -f ${unloadFileName} 1>/dev/null 2>&1

         if [ -f ${unloadFileName} ]
         then
            echo "\t ===> Error deleting the file [ ${unloadFileName} ] !!!"
         else
            echo "\t ===> The file [ ${unloadFileName} ] was successfully deleted."
         fi
      fi

   done

   echo "########################################"
   echo "### Finish treating old unload files ###"
   echo "########################################"

   echo

   echo "####################################"
   echo "### Begin treating old log files ###"
   echo "####################################"
   for LogFileName in `ls ${RepLog}/purgeExtractFragment_${TableName}_*.log 2>/dev/null`
   do
      echo "\n ===> Checking the file [ ${LogFileName} ]"

      f_parse_date ${LogFileName}
      DateOfFile4Purge=`echo "${days} ${month} ${year}"`

      nbDaysDiff=`echo "conn ${user}/${password}
                        select 'XYZ~'||to_char(to_date('${CurrentDate}','dd mm yyyy')-to_date('${DateOfFile4Purge}','dd mm yyyy')) value from dual;" |
                  sqlplus -SILENT /nolog 2>/dev/null |
                  grep -i 'XYZ~' |
                  cut -d'~' -f2 |
                  sed 's/00:00:00.00000//g' |
                  sed 's/ //g'
                 `
      if [ ${nbDaysDiff} -gt ${NbDays4Delete} ]
      then
         echo "\t ===> The file [ ${LogFileName} ] will be deleted.\n"
         #Purge the file
         rm -f ${LogFileName} 1>/dev/null 2>&1

         if [ -f ${LogFileName} ]
         then
            echo "\t ===> Error deleting the file [ ${LogFileName} ] !!!"
         else
            echo "\t ===> The file [ ${LogFileName} ] was successfully deleted."
         fi
      fi

   done

   echo "#####################################"
   echo "### Finish treating old log files ###"
   echo "#####################################"

}

# --------------------------------------------------------------------------------------------------
# Function  : Get info about the opened sessions on the working schema [ f_get_sqlSessions_details ]
# --------------------------------------------------------------------------------------------------
function f_get_sqlSessions_details
{
#   set -x
   Step="Get details about all the sessions opened on the database ${DBNAME4PURGE}"
   echo "${Step}\n"

   echo "conn ${user}/${password}
         WHENEVER sqlerror exit 99;
         set heading on linesize 500 wrap on
         select sid || '|'|| serial# || '|' || username || '|' || LOCKWAIT || '|' || status || '|' || OSUSER || '|' || machine || '|' || vse.SQL_ID || '|' || LOGON_TIME || '|' || EVENT || '|' || vsq.sql_text
           from v$session vse
           left outer join v$sql vsq
             on vsq.sql_id = vse.sql_id
          where upper(SCHEMANAME) = upper('${user}');
        " | sqlplus -SILENT /nolog

}

# -----------------------------------------------------------------------------
# Function  : Execute SQL statements                            [f_execute_sql]
# -----------------------------------------------------------------------------
function f_execute_sql {

   #$1 - SQL statement to execute
   #$2 - the function name that calls the execution

   SQL_statement=$1
   function_name=$2

   SQL_ERROR=0
   SQL_ERROR_MSG=""
   SQL_RET_VAL=""

   if [ "x${SQL_statement}" == "x" ]
   then
      SQL_ERROR_MSG="Invalid SQL statement"
      SQL_ERROR=255
   fi

   if [ "x$function_name" == "x" ]
   then
      function_name="unknown function"
   fi

   if [ "x${SQL_ERROR_MSG}" == "x" ]
   then
      SQL_RET_VAL=`echo "conn ${user}/${password}
      ${SQL_statement}" | sqlplus -SILENT /nolog 2>${SQL_ERR_FILE} `
      SQL_ERROR=$?
      if [ ${SQL_ERROR} -eq 0 ]
      then
         SQL_ERROR_MSG=""
      else
         echo "====> SQL ERROR in function $function_name"
         echo "#  STATEMENT"

         echo "${SQL_statement}"| sed "s/^/#/g"

         echo "#  END STATEMENT"
         echo "#  ERROR MESSAGE"
         echo "${SQL_RET_VAL}" | grep -v "^\ *$" | sed "s/^\ */#     /g"
         cat  "${SQL_ERR_FILE}" | grep -v "^\ *$" | sed "s/^\ */#     /g"
         echo "#  END ERROR MESSAGE"
      fi
   else
      echo "====> SQL ERROR in function $function_name"
      echo "#  ${SQL_ERROR_MSG}"
   fi
   rm ${SQL_ERR_FILE} 2> /dev/null
}

# -----------------------------------------------------------------------------
# Function  : Check the status of each action.                      [ f_verif ]
# -----------------------------------------------------------------------------
function f_verif {
#    set -x
    if (( ${RET_INIT} != 0 ))
    then
        echo "==== ${Etape} : [ NOK ]"
        RET_COD=${RET_INIT}
    else
        echo "==== ${Etape} : [ OK ]"
    fi
}

# -----------------------------------------------------------------------------
# Function  : Extract the data from the fragment.            [ f_extract_data ]
# -----------------------------------------------------------------------------
function f_extract_data {
   set -x

   Etape="Extracting data from the table : [ ${TableName}${NowFrag} ]"
   echo "====> ${Etape}"

   CompileName ${FileName}   # this function will create a custom name for the output file into "CompiledString" parameter
   outputFile=${CompiledString}

   echo "==== File containing the unloaded data: ${RepOut}/${outputFile}"

   GEN_SQL_UNLOAD="gen_unload.sql.$$"
   >${GEN_SQL_UNLOAD}

#   echo "conn ${user}/${password}
#         SET ECHO OFF TERMOUT OFF HEADING OFF FEED OFF TRIMSPOOL ON
#         SET LINES 200 PAGES 5000
#         SPOOL ${GEN_SQL_UNLOAD}
#         SELECT 'SELECT' FROM DUAL;
#         SELECT 'A.' || COLUMN_NAME
#         FROM USER_TAB_COLUMNS
#         WHERE table_name = '${TableName}${NowFrag}'
#           AND column_id = 1;
#         SELECT  '||''|''||A.' || COLUMN_NAME
#         FROM USER_TAB_COLUMNS
#         WHERE table_name = '${TableName}${NowFrag}'
#           AND column_id > 1
#         ORDER BY column_id;
#         SELECT 'FROM ${TableName}${NowFrag} A;' FROM DUAL;
#         SPOOL OFF
#         exit;" | sqlplus -SILENT /nolog > /dev/null 2>&1
###--ENE----
   mytablename=`echo $TableName | tr '[A-Z]' '[a-z]'`
   if [ $mytablename = topsecretnumbercreationreport -o $mytablename = topsecretnumberusagereport ]
   then
      echo "conn ${user}/${password}
            SET ECHO OFF TERMOUT OFF HEADING OFF FEED OFF
            SET LINES 80 PAGES 5000
            SPOOL ${GEN_SQL_UNLOAD}
            SELECT decode(COLUMN_ID,1,'SELECT REPORTTXT FROM ${TableName}${NowFrag};')
            FROM USER_TAB_COLUMNS
            WHERE table_name = '${TableName}${NowFrag}'
            ORDER BY COLUMN_ID ;
            SPOOL OFF
            exit;" | sqlplus -SILENT /nolog > /dev/null 2>&1 
###--end--ENE-----
   elif [ $mytablename = transacreport ]
   then
      echo "conn ${user}/${password}
            SET ECHO OFF TERMOUT OFF HEADING OFF FEED OFF
            SET LINES 80 PAGES 5000
            SPOOL ${GEN_SQL_UNLOAD}
            SELECT decode(COLUMN_ID,1,'SELECT REPORTID ||''|''|| REPORTTEXT || REPORTTIMESTAMP ||''|'' FROM ${TableName}${NowFrag};')
            FROM USER_TAB_COLUMNS
            WHERE table_name = '${TableName}${NowFrag}'
            ORDER BY COLUMN_ID ;
            SPOOL OFF
            exit;" | sqlplus -SILENT /nolog > /dev/null 2>&1 
   else 
      echo "conn ${user}/${password}
            SET ECHO OFF TERMOUT OFF HEADING OFF FEED OFF
            SET LINES 80 PAGES 5000
            SPOOL ${GEN_SQL_UNLOAD}
            SELECT decode(COLUMN_ID,1,'SELECT ' || COLUMN_NAME,
                                (SELECT max(column_id) from user_tab_columns where table_name = '${TableName}${NowFrag}'),'||''|''||' || COLUMN_NAME ||CHR(10)||' FROM ${TableName}${NowFrag};',
           '||''|''||' || COLUMN_NAME)
            FROM USER_TAB_COLUMNS
            WHERE table_name = '${TableName}${NowFrag}'
            ORDER BY COLUMN_ID ;
            SPOOL OFF
            exit;" | sqlplus -SILENT /nolog > /dev/null 2>&1
   fi
   
   >${RepOut}/${FileName_Temp}
   echo "conn ${user}/${password}
         SET ECHO OFF TERMOUT OFF HEADING OFF FEED OFF SQLBL ON TRIMSPOOL ON
         SET LINES 2048 PAGES 5000
         SPOOL ${RepOut}/${FileName_Temp}
         @${GEN_SQL_UNLOAD}
         SPOOL OFF
         exit;" | sqlplus -SILENT /nolog > /dev/null 2>&1

   RET_INIT=$?

   #Replace '\|' by '|' in the unload file's content
   sed 's/\\|/|/g' ${RepOut}/${FileName_Temp}  | grep -v ^$ >>${RepOut}/${outputFile}    # moves data from temporary file to output file
   rm ${RepOut}/${FileName_Temp}                            # removes temporary data file

   f_verif
}

# -----------------------------------------------------------------------------
# Function  : Truncate the fragment.                        [ f_truncate_frag ]
# -----------------------------------------------------------------------------
function f_truncate_frag {
    set -x

    # On detache la partition demande de la table
    Etape="Purge the table : [ ${TableName}${PurgNumFrag} ]"

    if (( ${SautFrag} != 0 ))
    then
        echo " ==========================================================================================="
        echo "Treatment of table : [ ${TableName}${PurgNumFrag} ]"
    fi
    echo "====> ${Etape}"

    # On ajoute la partition qui a ? d?ch?r?dement de la table

    if (( ${PurgNumFrag} == ${MaxFrag} ))
    then
        ((NextPrev=${PurgNumFrag}-1))
        AfterBefor="AFTER"
    else
        ((NextPrev=${PurgNumFrag}+1))
        AfterBefor="BEFORE"
    fi

    boolInd=1
    loopInd=0

    #Repeat the SQL statement multiple times until no error is found or
    while [ ${boolInd} -eq 1 -a ${loopInd} -lt ${NbIterations} ]
    do

      boolInd=0;

      ((loopInd=${loopInd} + 1))

      echo "\n===> Begin Iteration no [ ${loopInd} ]\n"

      SQL_STATEMENT="WHENEVER sqlerror exit 99;
                     Lock table ${TableName}${PurgNumFrag} in exclusive Mode;
                     TRUNCATE table ${TableName}${PurgNumFrag};"

      f_execute_sql "${SQL_STATEMENT}" "f_truncate_frag"

      RET_INIT=${SQL_ERROR}

      if [ ${RET_INIT} -ne 0 ]
      then
         boolInd=1
#        echo "\n===> List of running SQL processes\n"


         # Get detailed information about the opened sessions on the working schema
         f_get_sqlSessions_details

#        echo "\n===> Dbspaces and chunks status\n"


         # Delay between two iterations
         if [ ${NbDelaySeconds} -gt 0 ]
         then
            echo "The delay between two iterations is [ ${NbDelaySeconds} ] seconds"
            sleep ${NbDelaySeconds}
         fi

      fi

      echo "\n===> Finish Iteration no [ ${loopInd} ]\n"

    done

    f_verif

}

# -----------------------------------------------------------------------------
# Function  : Retrieve parameters from the database.                 [ f_frag ]
# -----------------------------------------------------------------------------
function f_param {
#    set -x
    PrmName=$1
    VarValue=""

    SQL_STATEMENT="WHENEVER sqlerror exit 99;
       select 'XYZ~' || a.value value
        from systemParam a
       WHERE a.groupName = '${PrmName}'
         AND a.rank      = 1
         AND a.langue    = 'ESGLG'
         AND a.state     = 68;"

    f_execute_sql "${SQL_STATEMENT}" "f_param"

    RET_INIT=${SQL_ERROR}

    VarValue=`echo "${SQL_RET_VAL}" | grep "XYZ" | cut -d"~" -f2`
}

# -----------------------------------------------------------------------------
# Function  : Update of table systemParam                     [ f_update_frag ]
# -----------------------------------------------------------------------------
function f_update_frag {
#    set -x

    PrmName=$1
    Val=$2

    Etape="Update the parameter [ ${PrmName} ] in the table : [ ${PrmTable} ]"
    echo "====> ${Etape}"

    if [ "$Val" == "SYSTIMESTAMP" ]
    then
        Val="SYSTIMESTAMP"
    else
        if [ "x$Val" == "x" ]
        then
            Val=Null
        else
            Val="'"$Val"'"
        fi
    fi

    SQL_STATEMENT="WHENEVER sqlerror exit 99;
         update systemParam
            set value=${Val}
          where groupName = '${PrmName}'
            AND rank   = 1
            AND langue = 'ESGLG'
            AND state  = 68  ;"

    f_execute_sql "${SQL_STATEMENT}" "f_update_frag"

    RET_INIT=${SQL_ERROR}

    f_verif
}

# -----------------------------------------------------------------------------
# Function  : Check the status of the unload file            [ f_control_file ]
# -----------------------------------------------------------------------------
function f_control_file {
#    set -x
   CompileName ${FileName}   # this function will create a custom name for the output file into "CompiledString" parameter
   outputFile=${CompiledString}

   Etape="Check the extraction file : [ ${RepOut}/${outputFile} ]"
   echo "====> ${Etape}"

   if [ -f ${RepOut}/${outputFile} ]
   then
      cnt=`awk 'END {print NR}' ${RepOut}/${outputFile}`
      if [ $cnt -eq 0 ]
      then
         echo " !!! No data was extracted. The extraction file is empty"
         echo " !!! Deletion of extraction file : [ ${RepOut}/${outputFile} ]"

         rm -f ${RepOut}/${outputFile}
      else
         echo " !!!  There are ${cnt} lines in the extraction file [ ${RepOut}/${outputFile} ]" >> $logFile
      fi
   fi

   RET_INIT=$?
   f_verif
}

# -----------------------------------------------------------------------------
# Function  : Retrieve parameters from the database.          [ f_search_frag ]
# -----------------------------------------------------------------------------
function f_search_param {
#    set -x
    Etape="Retrieve the parameters from the table : [ ${PrmTable} ]"
    echo "====> ${Etape}"

    TbName=`echo ${TableName} | tr [:lower:] [:upper:]`

    # Retrieve the table's prefix
    f_param "${TbName}_PREFIXE"
    PrefixeTab=$VarValue
    if [ "x${PrefixeTab}" == "x" -o ${RET_INIT} -ne 0 ]
    then
    echo "${TbName}_PREFIXE"
        RET_INIT=1
    else
        Cpt=0
        while ((${Cpt}<${#PrmTab[*]}))
        do
           VarName=${VarTab[$Cpt]}
           eval ${VarName}=""

           # Retrieve parameters from the database
           f_param  "${PrefixeTab}_FRAG_${PrmTab[$Cpt]}"

           if (( ${RET_INIT} != 0 ))
           then
           echo  "${PrefixeTab}_FRAG_${PrmTab[$Cpt]}"
              break
           else
              eval ${VarName}=\"$VarValue\"
              echo "The value of the parameter in the database : [ ${PrefixeTab}_FRAG_${PrmTab[$Cpt]} ] is : [ $VarValue ]"

              ((Cpt=$Cpt + 1))
           fi
        done

        if [ "x${Frequency}" != "x" ]
        then
            # La date calcul?st la date courante - 1 (Month, Day, Hour selon le param?e fr?ance de fragmentation)

            #ExprDate="x"; FreqFrag="x"; (( FrequencyInSeconds=-1 ))

            case ${Frequency} in
                M)   ExprDate="month"; FreqFrag="m"; (( FrequencyInSeconds=3600*24*28 )) ;; # the minimum number of days in a month is 28
                D)   ExprDate="day"; FreqFrag="d"; (( FrequencyInSeconds=3600*24 )) ;;
                H)   ExprDate="hour"; FreqFrag="H"; (( FrequencyInSeconds=3600 )) ;;
            esac
            #echo "ExprDate : $ExprDate"

            SQL_STATEMENT="WHENEVER sqlerror exit 99;
                           set serveroutput on ECHO OFF TERMOUT OFF HEADING OFF FEED OFF
                           declare
                              r_currentFragmentId   NUMBER  ;
                              r_frag_freq           VARCHAR2(100);
                              r_frag_nbFrags        NUMBER  ;
                              r_frag_param_validity NUMBER  ;
                              r_operError           NUMBER  ;
                              r_return_code         NUMBER  ;
                           begin
                              report_pkg.getCurrentFragment('${PrefixeTab}', 1, null, null, null,
                                                             r_currentFragmentId, r_frag_freq, r_frag_nbFrags, r_frag_param_validity, r_operError, r_return_code);
                              dbms_output.put_line('X ' || r_currentFragmentId);
                           end;
                           /
                           "

            f_execute_sql "${SQL_STATEMENT}" "f_search_param"

            echo "${SQL_RET_VAL}" \
                  | grep -v ^$ \
                  | sed 's/SQL>//g' \
                  | grep -w 'X' \
                  | awk '{FS="X";print $2}' \
                  | read NowFrag           #returns FragmentId operError and return_code

            RET_INIT=${SQL_ERROR}

            NumFrag=${NowFrag}

            if [ ${NowFrag} -eq 0 ]        # this is because we do not want NowFrag = 0
            then                           # it should not come to this
               ((NowFrag=1))
               NumFrag=${NowFrag}
            fi

        fi
    fi

    if (( ${RET_INIT} != 0 ))
    then
       echo " !!! ERROR Invalid or non-existent parameters in the database"

       f_verif
    fi

    f_verif
    if (( ${RET_INIT} == 0 ))
    then
       # Control of parameters
       f_control_param
    fi
}

# -----------------------------------------------------------------------------
# Function  : Control of parameters.                        [ f_control_param ]
# -----------------------------------------------------------------------------
function f_control_param {
    set -x

    Etape="Check the parameters of table : [ ${TableName} ]"
    echo "====> ${Etape}"

    # Control the parameters. Their value must be: not NULL, !=0 and <= {MaxFrag}
    if [ "x${StateExtract}" == "x0" ]
    then
        echo " !!! The extraction was deactivated"
        echo " The treatement was cancelled"

        RET_INIT=1
    else
        if [ "x${MaxFrag}" == "x" -o "x${OffsetFrag}" == "x" -o "x${FreqFrag}" == "x" -o "x${NowFrag}" == "x" ]
        then
            echo " !!! ERROR Invalid fragmentation parameters"

            RET_INIT=2
        else
            if (( ((${MaxFrag}*${OffsetFrag})) == 0 )) || (( ${OffsetFrag} > ((${MaxFrag}-2)) ))
            then
                echo " !!! ERROR Invalid fragmentation parameters"

                RET_INIT=3
            else
                CurrentFrag=${CurExtract}
                if (( ${NowFrag} > ${MaxFrag} ))
                then
                    echo " !!! ERROR Invalid fragmentation parameters"

                    RET_INIT=4
                else
                    # Check for not extracting again the data that was already extracted
                    if (( ${NowFrag} == ${CurrentFrag} ))
                    then
                        echo " !!! WARNING The extraction of requested fragment, as well as the purge, was previously performed"
                        echo " !!! Please check the previously generated log file and extraction file"

                        RET_INIT=6
                    fi
                fi

                # Control the fragmentation sequence
                if (( ${RET_INIT} == 0 ))
                then
                  (( SautFrag = ( ${MaxFrag} + ${MaxFrag} + ${NumFrag} - ${OffsetFrag} - ${CurrentFrag} ) % ${MaxFrag} ))

                  # create an interval that can extend across MaxFrag limit, that contains the valid fragments for extract / purge
                  (( MaxFragAllowedForExtract = ${MaxFrag} + ${NumFrag} - ${OffsetFrag} + 1 ))
                  (( MinFragAllowedForExtract = ${NumFrag} + 1 ))

                  # if the SautFrag combined with OffsetFrag will get a fragment that we must not extract ... we'll skip it
                  if (( ${MaxFrag} - 1 - ${OffsetFrag} < ${SautFrag} ))
                  then
                     # we modify the CurrentFrag by the difference with maximum allowed saut
                     (( CurrentFrag = ( ${CurrentFrag} - ( ${MaxFrag} - 1 - ${OffsetFrag} - ${SautFrag} ) - 1 ) % ${MaxFrag} + 1 ))
                     # we update also the SautFrag
                     (( SautFrag    = ${MaxFrag} - 1 - ${OffsetFrag} ))
                  fi
                fi
            fi
        fi
    fi
    f_verif
}

# -----------------------------------------------------------------------------------------------
# Function  : Computation of current fragment and check of database parameters. [ f_calcul_frag ]
# -----------------------------------------------------------------------------------------------
function f_calcul_frag {
#    set -x

    Etape="Computation of current fragment and check of database parameters"
    echo "====> ${Etape}"

    if (( ${RET_INIT} == 0 ))
    then
        echo " === Details :"
        echo "The number of the previously treated fragment : [ ${CurrentFrag} ]"
        echo "The number of the current computed fragment   : [ ${NowFrag} ]"

        if (( ${SautFrag} != 0 ))
        then
            echo " !!! WARNING The data from the [ ${SautFrag} ] previous fragments was not extracted"
            echo " !!! The data from these fragments will be extracted now"

        fi
    fi
    f_verif
}
# -----------------------------------------------------------------------------
# Function  : Computation of non extracted fragments.           [ f_saut_frag ]
# -----------------------------------------------------------------------------
function f_saut_frag {
#    set -x

    Etape="Computation of non extracted fragments"

    if (( ${SautFrag} != 0 ))
    then
       echo " ==========================================================================================="
    fi
    echo "====> ${Etape}"

      # Calcul des fragments non extraits daut de fragment
      ((NowFrag = (${MaxFrag} + ${CurrentFrag} + 1 - 1 ) % ${MaxFrag} + 1))

        CurrentFrag=${NowFrag}
        echo "Treatment of fragment : [ ${NowFrag} ]"

      PurgNumFrag=${NowFrag}                 # it will purge the current fragment

      # Calcul du fragment qui suit le fragment courant r?
      ((NextFrag = (${MaxFrag} + ${NumFrag} + 1 - 1 ) % ${MaxFrag} + 1))

      # Calcul du fragment qui pr?dent le fragment courant r?
      ((PrevFrag = (${MaxFrag} + ${NumFrag} - 1 - 1 ) % ${MaxFrag} + 1))


        # Emp?ement de purger les donn? du fragment courant r? ainsi que du fragment qui le suit
        if  (( ${PurgNumFrag} == ${NumFrag} )) ||
         (( ${PurgNumFrag} == ${NextFrag} )) ||
            ( (( ${NumFrag} < ${NowFrag} )) && ( (( ${MinFragAllowedForExtract} > ${NowFrag} )) ||
                                                 (( ${MaxFragAllowedForExtract} < ${NowFrag} )) ) ) ||
            ( (( ${NumFrag} > ${NowFrag} )) && ( (( ${MinFragAllowedForExtract} > ${NowFrag} + ${MaxFrag} )) ||
                                        (( ${MaxFragAllowedForExtract} < ${NowFrag} + ${MaxFrag} )) ) )

        then
            echo "The fragment [ ${PurgNumFrag} ] will not be purged"

        else
            echo "The fragment [ ${PurgNumFrag} ] will be purged after the extraction of the data that was not unloaded the previous time"

            # On m?rise les Fragment ?urger apr?l'extraction des donn?
            ((PurgTab[${#PurgTab[*]}]=${PurgNumFrag}))        ### -> this will add new records to the "PurgTab" array starting with index=0
        fi
    f_verif
}

#=============================================================
# Function MAIN
#=============================================================
function f_main {
    set -x

    echo " ==========================================================================================="
    Titre=" ===> PURGE AND DATA EXTRACTION FOR THE TABLE [ ${TableName} ] "
    echo "${Titre}"
    echo " BEGIN   :" `date "+%d/%m/%Y %H:%M"`
    echo " ==========================================================================================="

    f_delete_old_files                        # delete the old generated unload/log files

    f_search_param                            # get default parameters and set initial data
    if (( ${RET_COD} == 0 ))
    then
        RET_INIT=0

        f_calcul_frag                         # tests some parameters

        if (( ${RET_COD} == 0 ))
        then
        # begin of extract data part
            i=${SautFrag}
            while (($i>0))
            do
                f_saut_frag                   # get the next valid fragment
                ((i=$i-1))
                f_extract_data                # make the unload
                if (( ${RET_COD} == 0 ))
                then
                    f_control_file            # check if there is any data in the output file
                    if (( ${RET_COD} == 0 ))
                    then
                        f_param "${PrefixeTab}_FRAG_EXTRACT_CURRENT"        # gets from the database the "_FRAG_EXTRACT_CURRENT" value for current table
                        lastFrag=$VarValue
                        f_update_frag "${PrefixeTab}_FRAG_EXTRACT_CURRENT" ${NowFrag}        # set in the database the new value for "_FRAG_EXTRACT_CURRENT" value
                        f_update_frag "${PrefixeTab}_FRAG_EXTRACT_LAST" ${lastFrag}          # set in the database the new value for "_FRAG_EXTRACT_LAST" value
                        f_update_frag "${PrefixeTab}_FRAG_EXTRACT_DATE" ${ExtractDate}       # set in the database the new value for "_FRAG_EXTRACT_DATE" value
                    fi
                fi
                if (( ${RET_COD} != 0 ))
                then
                    break
                fi
            done
        # end of extract data part

        # begin of purge data part
            if (( ${RET_COD} == 0 ))
            then
               Cpt=0            # because PurgTab array (created in f_saut_frag) is an array that starts from 0
               while ((${Cpt}<${#PurgTab[*]}))
               do
                  if [ "x${SautFrag}" != "x0" ]
                  then
                      PurgNumFrag=${PurgTab[$Cpt]}
                  fi
                  f_truncate_frag
                  if (( ${RET_COD} == 0 ))
                  then
                      f_param "${PrefixeTab}_FRAG_PURGE_CURRENT"
                      lastFrag=$VarValue
                      f_update_frag "${PrefixeTab}_FRAG_PURGE_CURRENT" ${PurgNumFrag}
                      f_update_frag "${PrefixeTab}_FRAG_PURGE_LAST" ${lastFrag}
                      f_update_frag "${PrefixeTab}_FRAG_PURGE_DATE" ${ExtractDate}
                      echo "====> ${Etape}"
                  fi
                  ((Cpt=$Cpt + 1))
                  if (( ${RET_COD} != 0 )) || (( ${Cpt} == 0 ))
                  then
                      break
                  fi
               done
            fi
        # end of purge data part
        fi
    fi

    echo " ==========================================================================================="

    if (( ${RET_COD} == 0 ))
    then
        echo "${Titre} : [ OK ]"
    else
        RET_JOB=${RET_COD}
        echo "${Titre} : [ NOK ]"
    fi

    echo " END   :" `date "+%d/%m/%Y %H:%M"`
}

#----------------------------------------------
#MAIN PROCEDURE
#----------------------------------------------
(

   if [ ${RET_JOB} -eq 0 ]
   then
      clear
      echo "The number of arguments is : $#"
      echo "====> The log file is : ${LOG_FILE}"

      f_main > ${LOG_FILE} 2>&1

      echo "${Titre}"
      if (( ${RET_JOB} == 0 ))
      then
      echo "      ===> : [ OK ]"
      else
      echo "      ===> : [ NOK ]"
      fi
   fi

   exit $RET_JOB
)
lsav@paymob10 > 
