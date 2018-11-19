#!/usr/bin/ksh

#set -x

# unload of a table;

LOG_FILE=unload.log
user_name="voms/voms"



# set pages 0 linesize 10000 head off trimspool on colsep '|' echo off termout off

function display_help {
        echo "\tunload.ksh usage:"
        echo "Unloads data in <file_name>"
        echo "\tunload.ksh -t <table_name> -f <file_name> [-u <user\/password>]"
        echo "\tor"
        echo "\tunload.ksh -s <select_statement> -f <file_name> [-u <user\/password>]"
        echo "HELP - display this message"
        echo "\tunload.ksh -h"
}

function get_fields {

sel_fld_stmt="set feedback off head off pages 0
                select COLUMN_NAME from user_tab_columns where table_name=upper('$table_name');"

echo "$sel_fld_stmt" | sqlplus -S -R 1 -L $user_name 2> $LOG_FILE |grep -v '^$' |  while read column_name
        do
                if [[ "x$select_list" = "x" ]]; then
                        select_list=$column_name
                else
                        select_list="$select_list || '|' || $column_name"
                fi
        done

}

function get_data {

stmt=$1

echo "set num 20 pages 0 feedback off  linesize 10000 head off trimspool on echo off termout off colsep '|'" > select_stmt.sql.tmp
echo "spool $file_name" >> select_stmt.sql.tmp
echo "$select_stmt" >> select_stmt.sql.tmp
echo "$stmt" >> select_stmt.sql.tmp
echo "spool off" >> select_stmt.sql.tmp
echo "exit" >> select_stmt.sql.tmp
echo "@select_stmt.sql.tmp" | sqlplus -S $user_name
}


######## MAIN ########

while getopts t:s:f:u:h arg
do
        case $arg in
        t)
                table_name=$OPTARG
                ;;
        s)              
                        select_stmt=$OPTARG
                        ;;
        f)
                file_name=$OPTARG
                ;;
        u)
                user_name=$OPTARG
                ;;
        h)
                display_help
                ;;
        \?)
                echo "Invalid option." >&2
                display_help
                exit
                ;;
        esac
done

if [[ "x$table_name" = "x" ]]; then
        get_data "$select_stmt"
        rm select_stmt.sql.tmp
else
        get_fields
        select_stmt="select $select_list from $table_name;"
        get_data "$select_stmt"
        rm select_stmt.sql.tmp
fi