#!/usr/bin/bash
#
#(#)--  =====================================================================================================
#(#)--  Script name       :  select_DB_TabCol_POS_VOMS.sh
#(#)--  Database          :  ORACLE
#(#)--  Description       :  Script to select columns from database tables 
#(#)--  =====================================================================================================
#
#
#--------------------------------------------------------
# Test the input parameters
#--------------------------------------------------------
if [ $# -ne 3 ]
then
    echo "Usage: "
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
      echo "Unload aborted"
      exit 1
fi
  
   
#---------------------------------------------------
# Unload the data
#---------------------------------------------------
echo "conn ${1}/${2}@${3}


SET ECHO OFF TERMOUT OFF HEADING OFF FEED OFF FEEDBACK OFF TRIMSPOOL ON
set pagesize 0
set linesize 600



SET SERVEROUTPUT ON;

set linesize 2500;

DECLARE
out_stg varchar2(2000);
out_tmp varchar2(50);
stg varchar2(2000);
tmp varchar2(50);
aux varchar2(10);
i number;
n number;

CURSOR c1 
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
   
CURSOR c2
IS
SELECT column_name 
INTO out_tmp
FROM user_tab_columns
WHERE table_name=stg;
   
BEGIN

dbms_output.put_line('echo \"conn ${1}/${2}@${3}');

dbms_output.put_line('SET ECHO OFF TERMOUT OFF HEADING OFF FEED OFF FEEDBACK OFF TRIMSPOOL ON');
dbms_output.put_line('set pagesize 0');
dbms_output.put_line('set linesize 600');
dbms_output.put_line('spool on');

OPEN c1;
 
LOOP 

FETCH c1 INTO stg;
EXIT WHEN c1%NOTFOUND;

n:=0;

OPEN c2;

LOOP

FETCH c2 INTO tmp;
EXIT WHEN c2%NOTFOUND;
n:=c2%ROWCOUNT;

END LOOP;

CLOSE c2;

i:=1;
out_stg:=NULL;
 
WHILE i<=n
LOOP

   SELECT column_name 
   INTO out_tmp
   FROM user_tab_columns WHERE table_name=stg AND column_id=i;
   IF i=1 THEN
   -- if the first column, we use the format: select <first column name>
   out_stg:='select '||trim(out_tmp);
   ELSE
   -- if not the first column, we use the format: <previous string> ^ <curent column name>
   out_stg:=trim(out_stg)|| '||' || '''^''' || '||' ||trim(out_tmp);
   END IF;
   i:=i+1;
   
END LOOP;

out_stg:=trim(out_stg)||' from '||trim(stg)||' where rownum<=1000000'||';';

dbms_output.put_line('spool ${PWD}/'||trim(lower(stg))||'.unl');
dbms_output.put_line(out_stg);

END LOOP;

CLOSE c1;

dbms_output.put_line('spool ${PWD}/user_sequences.unl');
dbms_output.put_line('select sequence_name||' || '''^''' || '||last_number from user_sequences;');

dbms_output.put_line('spool off');
dbms_output.put_line('\" | sqlplus -SILENT /nolog 1>/dev/null 2>/dev/null');

dbms_output.put_line('#-------------------------------------------------------------------');
dbms_output.put_line('# CleanUp');
dbms_output.put_line('#-------------------------------------------------------------------'); 

dbms_output.put_line('mkdir archive_${1}');
dbms_output.put_line('mv *.unl archive_${1}/');
dbms_output.put_line('mv output.* archive_${1}/');
dbms_output.put_line('sleep 5');
dbms_output.put_line('tar cvf archive_${1}.tar archive_${1}/');
dbms_output.put_line('sleep 5');
dbms_output.put_line('gzip archive_${1}.tar');
dbms_output.put_line('rm -Rf archive_${1}/');
dbms_output.put_line('date');
dbms_output.put_line('echo \"Unload finished.\"');

END;
/


" | sqlplus -SILENT /nolog 1>file.sh 2>&1

chmod +x file.sh
echo "Starting unload..."
./file.sh
