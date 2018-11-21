#!/usr/bin/python


import csv
import sys
import os
import cx_Oracle
from colorama import Fore, Back, Style


## Show info
## Global Setings

print('\n\nThis script was build in order to help you to make a network change for Canal+ customer')
print('\nYou will be asked for several parameter . Please pay attention to index counting. You must start from 0 (zero) not from 1')
print('\nEngineer that made this script is Moscalu Ionut.If any issue with this script please contact him.')

GLOBAL_CSV_FILE=input("\nPlease provide excel file received from the customer (it must be into single quotes, and CSV format): ")
MERCHANT_ID_INDEX=input("\nPlease input the column number of the merchant_id that will be changed :")
NEW_CGA_WEB_ID_INDEX=input("\nPlease input the column number of the NEW CGAWEB_ID:")
OLD_CGA_WEB_ID_INDEX=input("\nPlease input the column number of the OLD CGAWEB_ID:")
NEW_PARENT_ID_INDEX=input("\nPlease input the column number of the NEW PARENT MERCHANT_ID:")

CGAWEB_ID_SQL_FILE='Update_CGAWEB_ID.sql'
PARENT_ID_SQL_FILE='Update_PARENT_ID.sql'
ROOT_ID_SQL_FILE='Update_ROOT_ID.sql'
num_lines = len(list(open(GLOBAL_CSV_FILE)))




## Check if we have duplicate users and if they exist into DB
def check_merchant_id():

    coloumn2 = []
    
    with open(GLOBAL_CSV_FILE, "r+") as f:
        data = csv.reader(f, delimiter=',')
        for line in data:
            coloumn2.append(line[0])

        coloumn2.pop(0)
        dupes = [x for n, x in enumerate(coloumn2) if x in coloumn2[:n]]
        size = len(dupes)
        if size > 0 :
            print(Fore.RED + '\nYou have a duplicate merchant_id. Please check merchant with id: {}'.format(dupes)) 
            sys.exit()
        else:
            err_nb = 0
            for xx in coloumn2:
                
                dict_of_selected_nb = {}
                Connection_String ='canal_plus/wsx3edc@(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=10.120.25.54)(PORT=1521)))(CONNECT_DATA=(SID=mmso)))'
                connection = cx_Oracle.connect(Connection_String)
                merchantid = xx
                cursor = connection.cursor()
                select_stmt= "Select :blabla,(case when COALESCE(MAX(ms.FK_MERCHANT_ID), '0') = 0 THEN 0 WHEN COALESCE(MAX(ms.FK_MERCHANT_ID), '0') != 0 THEN 1 END) state FROM merchant m inner join merchant_association ms on m.id = ms.FK_MERCHANT_ID WHERE m.merchant_id = :blabla "
                cursor.execute(select_stmt,{'blabla' : merchantid })
                result_of_select = [{row[0] : row[1]} for row in cursor.fetchall()]
                for i in result_of_select:
                    fields = i
                    for mrc_id,value in fields.items():
                        if value != 1:
                            print(Fore.RED + '\nMerchant not found. Please check merchant with id: {}'.format(mrc_id))
                            err_nb += 1
            if err_nb != 0 :
                sys.exit()


## Backup DB users data 
def backup_users(output_file):
    with open(GLOBAL_CSV_FILE,mode = 'r') as csv_file:
        csv_reader = csv.reader(csv_file, delimiter=',')
        line_count = 0
        for row in csv_reader:
            if line_count == 0:
                line_count += 1
            else:
                if num_lines != line_count:
                    filename=output_file
                    FILE=open(filename,"a");
                    output=csv.writer(FILE, dialect='excel')
                    Connection_String ='canal_plus/wsx3edc@(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=10.120.25.54)(PORT=1521)))(CONNECT_DATA=(SID=mmso)))'
        
                    connection = cx_Oracle.connect(Connection_String)
                    #merchantid = row[1]
                    merchantid = row[MERCHANT_ID_INDEX]
                    cursor = connection.cursor()
                    select_stmt= "Select m.*,ms.* FROM merchant m inner join merchant_association ms on m.id = ms.FK_MERCHANT_ID WHERE m.merchant_id = :blabla "
                    cursor.execute(select_stmt,{'blabla' : merchantid })
                    for rows in cursor:
                        output.writerow(rows)
                    cursor.close()
                    connection.close()
                    line_count += 1
                    FILE.close()
    csv_file.close()

## Prepare SQL file for  CGAWEB ID change

def cgaweb_prepare_file():
    with open(CGAWEB_ID_SQL_FILE,mode = 'w') as f:
        with open(GLOBAL_CSV_FILE,mode = 'r') as csv_file:
            csv_reader = csv.reader(csv_file, delimiter=',')
            line_count = 0
            for row in csv_reader:
                if line_count == 0:
                    line_count += 1
                else:
                    print >> f, ("update merchant_association ma set ma.EXTERNAL_REFERENCE_ID='{}' where exists (select * from merchant m where m.id=ma.fk_merchant_id and m.merchant_id='{}') and ma.EXTERNAL_REFERENCE_ID='{}';". format (row[NEW_CGA_WEB_ID_INDEX],row[MERCHANT_ID_INDEX],row[OLD_CGA_WEB_ID_INDEX]))
                    line_count += 1
                
                
##Prepare SQL file for Parent ID change 
def parent_prepare_file():
    with open(PARENT_ID_SQL_FILE,mode = 'w') as f:
        with open(GLOBAL_CSV_FILE,mode = 'r') as csv_file:
            csv_reader = csv.reader(csv_file, delimiter=',')
            line_count = 0
            for row in csv_reader:
                if line_count == 0:
                    line_count += 1
                else:
                    print >> f, ("update merchant set PARENT_ID=(select id from merchant where merchant_id='{}'),ROOT_ID=(select id from merchant where merchant_id='{}') WHERE MERCHANT_ID='{}';".format(row[NEW_PARENT_ID_INDEX],row[NEW_PARENT_ID_INDEX],row[MERCHANT_ID_INDEX]))
                    line_count += 1


## Prepare SQL file for ROOT ID change 
def root_prepare_file():
    with open(ROOT_ID_SQL_FILE,mode = 'w') as f:
        with open(GLOBAL_CSV_FILE,mode = 'r') as csv_file:
            csv_reader = csv.reader(csv_file, delimiter=',')
            line_count = 0
            for row in csv_reader:
                if line_count == 0:
                    line_count += 1
                else:
                    print >> f, ("update merchant set ROOT_ID=(select id from merchant where merchant_id='{}') where parent_ID=(select id from merchant where MERCHANT_ID='{}');".format(row[NEW_PARENT_ID_INDEX],row[MERCHANT_ID_INDEX]))
                    line_count += 1

## Running all function defined abowe                
if __name__ == '__main__':
    intro()
    check_merchant_id()
    backup_users(input("\nPlease provide a file name for backup current configuration of the users(it must be into single quotes) : "))
    cgaweb_prepare_file()
    parent_prepare_file()
    root_prepare_file()
