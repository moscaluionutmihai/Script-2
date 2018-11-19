#!/usr/bin/bash
#
#(#)--  =====================================================================================================
#(#)--  Script name       :  delete_data_POS_VOMS.sh
#(#)--  Database          :  ORACLE
#(#)--  Description       :  Script for delete data from Oracle database
#(#)--  =====================================================================================================
#
#
#--------------------------------------------------------
# Input the local variables and test the input parameters
#--------------------------------------------------------
if [ $# -ne 3 ]
then
          echo "Usage:"
          echo "$0 <DB_user> <DB_password> <ORACLE_SID>"
          exit 1
fi

#---------------------------------------------------
# Check the database existence
#---------------------------------------------------
D_B_E_X_I_S_T_S=`echo "SELECT username FROM sys.all_users where username = upper('$1'); " | sqlplus / as sysdba  | grep -ci "$1"`
if [ $D_B_E_X_I_S_T_S -eq 0 ]
then
      echo ""
      echo "ERROR: The schema [ ${1}/${2} ] doesn't exist..."
      echo "Cleanup aborted"
      exit 1
   fi


#---------------------------------------------------
# Prepare the deletion
#---------------------------------------------------
echo "conn ${1}/${2}@${3}


SET ECHO OFF TERMOUT OFF HEADING OFF FEED OFF FEEDBACK OFF TRIMSPOOL ON
set pagesize 0
set linesize 600



SET SERVEROUTPUT ON;

set linesize 2500;

DECLARE
tab varchar2(2000);


CURSOR c
IS
SELECT table_name FROM user_tables
WHERE table_name not like '%REPORT1'
   and table_name not like '%REPORT2'
   and table_name not like '%REPORT3'
   and table_name not like '%REPORT4'
   and table_name not like '%REPORT5'
   and table_name not like '%REPORT6'
   and table_name not like '%REPORT7'
   and table_name not like '%REPORT8'
   and table_name not like 'DEBUG_OBJECT';

BEGIN

dbms_output.put_line('echo \"conn ${1}/${2}@${3}');



OPEN c;

LOOP

FETCH c INTO tab;
EXIT WHEN c%NOTFOUND;

dbms_output.put_line('truncate table '||upper(tab)||';');

END LOOP;

CLOSE c;



dbms_output.put_line('\" | sqlplus -SILENT /nolog');

END;
/


" | sqlplus -SILENT /nolog 1>file_delete.sh 2>&1

chmod +x file_delete.sh
./file_delete.sh

