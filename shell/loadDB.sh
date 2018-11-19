#!/usr/bin/bash
#
#(#)--  =====================================================================================================
#(#)--  Script name       :  load_data_POS_VOMS.sh
#(#)--  Database          :  ORACLE
#(#)--  Description       :  Script to load data in a database
#(#)--  =====================================================================================================
#
#
#--------------------------------------------------------
# Input the local variables and test the input parameters
#--------------------------------------------------------

if [ $# -ne 4 ]
then
          echo "Usage:"
          echo "$0 <DB_user> <DB_password> <ORACLE_SID> <files location>"
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
      exit 1
   fi


cd $4

mkdir log_files
mkdir control_files

for file in `ls *.unl`
        do
            filename=`echo $file | cut -f1 -d.`
            
            if [ $filename != "user_sequences" ]
            then

                echo "Loading data into table $filename..."
                echo "conn ${1}/${2}@${3}

                SET ECHO OFF TERMOUT OFF HEADING OFF FEED OFF FEEDBACK OFF TRIMSPOOL ON
                set pagesize 0
                set linesize 600

                SET SERVEROUTPUT ON;

                DECLARE
                tab varchar2(1000):='${filename}';
                col varchar2(1000);
                aux varchar2(5000);
                i number;
                n number;

                BEGIN

                dbms_output.put_line('load data');
                dbms_output.put_line('infile '||''''||tab||'.unl'||'''');
                dbms_output.put_line('append into table '||tab);
                dbms_output.put_line('fields terminated by '||''''||'^'||'''');
                dbms_output.put_line('trailing nullcols');
                dbms_output.put_line('(');

                n:=0;

                SELECT max(column_id)
                INTO n
                FROM user_tab_columns WHERE table_name=upper(tab);

                i:=1;
                aux:=NULL;

                WHILE i<=n
                LOOP

                        SELECT column_name
                        INTO col
                        FROM user_tab_columns WHERE table_name=upper(tab) AND column_id=i;
                        IF i=n THEN
                                aux:=trim(aux)||trim(col);
                        ELSE
                                aux:=trim(aux)||trim(col)||',';
                        END IF;
                        i:=i+1;

                END LOOP;

                dbms_output.put_line(aux);
                dbms_output.put_line(')');

                END;
                /

                " | sqlplus -SILENT /nolog 1>control_files/$filename.ctl 2>&1

                sqlldr userid=$1/$2 control=control_files/$filename.ctl log=log_files/$filename.log bad=log_files/$filename.bad data=$file
                echo "Finished loading data into table $filename - for more information, check the file $4/log_files/$filename.*"
            else
                # Update sequences with the values from user_sequences.unl 
                echo "Updating sequences..."
                >log_files/user_sequences.log
                cat user_sequences.unl | while read line
                do
                    sequence_name=`echo $line | cut -f1 -d^`
                    sequence_live_value=`echo $line | cut -f2 -d^`
                
                    echo "conn ${1}/${2}@${3}
                         SET SERVEROUTPUT ON
                
                         DECLARE
                            increment_value NUMBER(20);
                            sequence_testbed_value NUMBER(20);
                            next_value NUMBER;
                            sequence_found NUMBER(1);
                         BEGIN

                            sequence_found := 1;
                            BEGIN
                                SELECT last_number 
                                  INTO sequence_testbed_value 
                                  FROM user_sequences 
                                 WHERE sequence_name='$sequence_name';
                            EXCEPTION
                                WHEN NO_DATA_FOUND THEN
                                sequence_found := 0;
                            END;
                        
                            IF sequence_found = 1
                            THEN
                                dbms_output.put_line('Sequence ' || '$sequence_name');
                                dbms_output.put_line(' - current value: ' || sequence_testbed_value);
                                dbms_output.put_line(' - live system value: ' || '$sequence_live_value');
                                                            
                                increment_value:=$sequence_live_value-sequence_testbed_value+20;
                    
                                IF increment_value > 0
                                THEN
                                    dbms_output.put_line(' - increment value: ' || increment_value);
                                    
                                    EXECUTE IMMEDIATE ('ALTER SEQUENCE ' || '$sequence_name' || ' INCREMENT BY ' || increment_value);
                                    EXECUTE IMMEDIATE ('SELECT '|| '$sequence_name' ||'.NEXTVAL FROM DUAL') INTO next_value;
                    
                                    EXECUTE IMMEDIATE ('ALTER SEQUENCE ' || '$sequence_name' || ' INCREMENT BY ' || '1');
                                    EXECUTE IMMEDIATE ('SELECT '|| '$sequence_name' ||'.NEXTVAL FROM DUAL') INTO next_value;
                                    
                                    dbms_output.put_line(' - value after change: ' || next_value);
                                END IF;
                            END IF;    
                        END;
                        /
                    " | sqlplus -SILENT /nolog 1>>log_files/user_sequences.log 2>&1
                done
                echo "Sequences updated - for more information, check the file $4/log_files/user_sequences.log"
            fi    
done
