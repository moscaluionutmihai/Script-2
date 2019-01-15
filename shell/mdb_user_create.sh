#!/bin/bash
#Version 2.6
#last update 06.12.2018 (day after Expo :))
#Created by O.Savchuk

#Should be changed on new server
#default IP of DB users is:
ip_def='10.120.%'

#Default charset\collation for database
def_char=utf8
def_coll=utf8_unicode_ci

#credentials
mysql_user=`grep ^wsrep_sst_auth /etc/mysql/conf.d/cluster.cnf | awk -F"\"" '{print $2}' | sed 's/ *:.*//'`
mysql_pass=`grep ^wsrep_sst_auth /etc/mysql/conf.d/cluster.cnf | awk -F""\:"" '{print $2}' | sed 's/ *".*//'`

#rights that will be granted
USER="delete,insert,select,update"
ADMIN="create,create view,drop,delete,insert,select,update,index,alter,CREATE ROUTINE,ALTER ROUTINE,EXECUTE,TRIGGER"
REPORT="select"
ALL="all"

#show all databases
mysql -u$mysql_user -p$mysql_pass -e "SHOW DATABASES;"

#dbnames
echo " "
echo "----------------------"
echo " you can enter DB names separated by space"
echo " for example: DB1 DB2 DB3"
echo "----------------------"
echo " "
echo "dbname: "
read dblist
if [ -z "$dblist" ]
        then
        echo " "
        echo "----------------------"
        echo "Database name cannot be empty"
        echo "----------------------"
        echo " "
        exit
fi

#charsets and collation
#user IP
echo "default charset / collation are: "
echo "$def_char / $def_coll"
echo ""
echo "----------------------"
echo "If you wish proceed with default values - press ENTER"
echo "else"
echo "set new values"
echo ""
echo "----------------------"
echo "CHARSET:"
read def_char_set
if [ -z "$def_char_set" ]
        then
        def_char=$def_char
        echo $def_char
        else
        def_char=$def_char_set
        echo ""

fi

echo "Possible COLLATIONs for charset $def_char :"
mysql -u$mysql_user -p$mysql_pass -e "SHOW COLLATION WHERE Charset = '$def_char'"
echo "Please chose one from list above or just press ENTER to set defaul value ($def_coll)"
echo ""
echo "COLLATION:"
read def_coll_set
if [ -z "$def_coll_set" ]
        then
        def_coll=$def_coll
        echo $def_coll
        else
        def_coll=$def_coll_set
fi

#username
user_from_db=`echo $dblist | cut -c1-5`

echo " "
echo "----------------------"
echo "Possible users for your DB are: "
echo ""
mysql -u$mysql_user -p$mysql_pass -N -s -e "select distinct user from mysql.user where user like '$user_from_db%'"
echo ""
echo "----------------------"
echo "Chose user from list above or provide new one: "
echo "username: "
read user
if [ -z "$user" ]
        then
        echo " "
        echo "----------------------"
        echo "Username cannot be empty"
        echo "----------------------"
        echo " "
        exit
fi
echo "----------------------"
echo ""
#user IP
echo "Allowed IP range (default '$ip_def'): "
read ip
if [ -z "$ip" ]
        then
        ip=$ip_def
fi

#user password
user_exist=`mysql -u$mysql_user -p$mysql_pass -N -s -e "select distinct CONCAT(user, '@', host) from mysql.user where user='$user' and host='$ip';"`
userpass=`mysql  -u$mysql_user -p$mysql_pass platform_engin -B -N -e "select distinct pass from platform_engin.db_plan_capacity where username = '$user';"`
if ([ -n "$userpass" ] && [ -n "$user_exist" ])
        then
        echo ""
        echo "----------------------"
        echo "user $user already exist"
        echo "we will use current password"
        echo "----------------------"
        echo ""
        #set password
        pw=$userpass
        #set role
        db_role=`mysql  -u$mysql_user -p$mysql_pass platform_engin -B -N -e "select distinct priv from platform_engin.db_plan_capacity where username = '$user';"`

        else

        echo "User password: "
        read pw
        if [ -z "$pw" ]
                then
                echo " "
                echo "----------------------"
                echo "Password cannot be empty"
                echo "----------------------"
                echo " "
                exit
        fi
fi

#Grants

if [ -n "$db_role" ]
        then
        read role <<< $db_role
        echo "role was read"
        echo "role will be $db_role"
else

echo " "
echo "----------------------"
echo "DB role (ADMIN,USER,REPORT,ALL)"
echo "USER      - $USER"
echo "ADMIN     - $ADMIN"
echo "REPORT    - $REPORT"
echo "ALL       - $ALL grants to *.* "
echo " "
echo "to grant permissions manually, leave this field blanked (PRESS ENTER)."
echo " "

        echo "DB Role: "
        read role
fi

if [ "$role" = 'ADMIN' ]
        then
        role=$ADMIN;
        db_role='ADMIN'
        elif [ "$role" = 'USER' ]
        then
        role=$USER
        db_role='USER'
        elif [ "$role" = 'ALL' ]
        then
        role=$ALL
        db_role='ALL'
        elif [ "$role" = 'REPORT' ]
        then
        role=$REPORT
        db_role='REPORT'
        else
        echo 'type grants manually with coma: '
        read role
        db_role='MANUAL'
fi

#ticket name
echo "----------------------"
echo " "
echo "ticket name"
read tick
        if [ -z "$tick" ]
        then
        echo " "
        echo "----------------------"
        echo "ticket name cannot be empty"
        echo "----------------------"
        echo " "
        exit
        fi

#db size forecast
echo "----------------------"
echo " "

for db in $dblist
do
echo ""
echo "If DB already exist left the field empty"
echo "$db size GB in 1 year (default 0): "
read size
        if [ -z "$size" ]
        then
        size=0
        fi
echo ""
echo "----------------------"
echo "$db size is $size Gb"
echo "----------------------"
echo ""

#mysql scripts
cr_db="create database $db CHARACTER set $def_char collate $def_coll;"
cr_user="create user '$user'@'$ip' identified by '$pw';"
db_colls="use $db ; select @@character_set_database, @@collation_database;"
grant_role="grant $role on $db.* to '$user'@'$ip'; flush privileges; SHOW GRANTS FOR '$user'@'$ip';"
capacity="insert into platform_engin.db_plan_capacity (dbname, cr_date,ticket,username,pass,grows_per_year,\`2016\`,\`2017\`,\`2018\`,\`2019\`,\`2020\`,priv,status) values ('$db', now(), '$tick','$user','$pw',$size,GREATEST($size/365*datediff('2016-12-31',now()),0),GREATEST($size/365*datediff('2017-12-31',now()),0),GREATEST($size/365*datediff('2018-12-31',now()),0),GREATEST($size/365*datediff('2019-12-31',now()),0),GREATEST($size/365*datediff('2020-12-31',now()),0),'$db_role','ACTIVE');"
check="select * from platform_engin.db_plan_capacity where username='$user';"

#check if db or user already exists
db_exist=`mysql -u$mysql_user -p$mysql_pass -e "SHOW DATABASES;"`
user_exist=`mysql -u$mysql_user -p$mysql_pass -N -s -e "select CONCAT(user, '@', host) from mysql.user where user='$user' and host='$ip';"`
capac_plan="select sum(\`2016\`) as '2016',sum(\`2017\`) as '2017',sum(\`2018\`) as '2018',sum(\`2019\`) as '2019',sum(\`2020\`) as '2020' from platform_engin.db_plan_capacity;"

for u in $db_exist
do

        if ([ "$u" = "$db" ] && [ "$user_exist" = "$user@$ip" ])
        then
        db_ex=1
        us_ex=1
        break
        elif [ "$u" = "$db" ]
        then
        db_ex=1
        us_ex=0
        break
        elif [ "$user_exist" = "$user@$ip" ]
        then
        db_ex=0
        us_ex=1
        else
        db_ex=0
        us_ex=0
        fi
done
if [ "$db_ex$us_ex" = "11" ]
then
                echo "DB $db and USER '$user'@'$ip' already exist"
                echo "Only rights $db_role will be granted"
                echo ""
                mysql -upengine -p platform_engin -e "
                $grant_role
                $capacity
                $check
                "
elif [ "$db_ex$us_ex" = "10" ]
then
                echo "DB $db exist, USER '$user'@'$ip' no"
                echo "Only user '$user'@'$ip' with rights $db_role will be created"
                echo ""
                mysql -upengine -p platform_engin -e "
                $cr_user
                $grant_role
                $capacity
                $check
                "
elif [ "$db_ex$us_ex" = "01" ]
then
                echo "USER '$user'@'$ip' exists, DB $db no"
                echo "Only DB $db will be created"
                echo ""
                mysql -upengine -p platform_engin -e "
                $cr_db
                $grant_role
                $capacity
                $db_colls
                $check
                "
elif [ "$db_ex$us_ex" = "00" ]
then
                echo "Neither USER nor DB exist"
                echo "User '$user'@'$ip' with rights $db_role and DB $db will be created"
                echo ""
                mysql -upengine -p platform_engin -e "
                $cr_db
                $cr_user
                $grant_role
                $capacity
                $db_colls
                $check
                "
fi
done
datadir=`mysql -u$mysql_user -p$mysql_pass -N -s -e "show variables like 'datadir';" | awk '{print $2}'`
disk_size=`df -h $datadir | awk '{print $2, $3, $4, $5}'`
echo ""
echo "Current disk size is:"
echo "-----------------------------"
echo "$disk_size"
echo "-----------------------------"
echo ""
echo "Planned capacity per years:"
mysql -u$mysql_user -p$mysql_pass -e "$capac_plan"
