#!/bin/bash
clear
cat intro.txt
read -n 1 -p "				   . . . Press any key to continue . . . "

avg_call()
{
echo -e "Average call duration for $report_date was \c" >> "reports/report_avg.log"

	nawk -F"|" 'BEGIN {total=0;}
			  {total+=$6;}
                    END   {printf "%.2f seconds from a total of %d calls.\n",total/NR,NR}' < intermediate2.txt >> "reports/report_avg.log"

	#removes the duplicate lines from report_avg.log
	nawk '!x[$0]++' "reports/report_avg.log" > tmp && mv tmp "reports/report_avg.log"
}

cps_calc()
{
#copy the initial_report.txt to our reports folder so we can further calculate cps
cat initial_report.txt > "reports/initial_report.txt"
i=0
nrlines=$(wc -l < intermediate1.txt)

#checking if the file has data (cdrs)
if [[ -s intermediate1.txt ]] ; then
#calculating cps
IFS="|"
while read -r nrstart nrend durata      
do      
	((durata++))
	#using the already made initial_report.txt (HHMMSS|0) cuts only the part of the file where the call took place and adds 1 to cps column
	head -$nrend "reports/initial_report.txt" | tail -$durata > intermediate3.txt
	head -$nrstart "reports/initial_report.txt" > "reports/report$reportdate.txt"

	#adding +1
	nawk -F'|' '{$2+=1;}1' OFS='|' intermediate3.txt > tmp && mv tmp intermediate3.txt

	#building the final report
	cat intermediate3.txt >> "reports/report$reportdate.txt"
	nrend=$((86400-nrend))
	tail -$nrend "reports/initial_report.txt" >> "reports/report$reportdate.txt"

	#the initial report will now be the final report and the cycle goes on untill the end of the cdr file.
	cat "reports/report$reportdate.txt" > "reports/initial_report.txt"

	#calculate the progress
	timer=$(( i*100/nrlines))
	echo -ne "	Calculating CPS ---> $timer% \r"
	((i++))

done < intermediate1.txt

echo -ne "	Calculating CPS ---> 100% \r"
echo -e "\n "

#waits for an any input key
read -n 1 -p "				   . . . Press any key to continue . . . "
else
echo -e "        There are no cdr's available for the input date."
reportdate=""
echo -e "\n "
read -n 1 -p "				   . . . Press any key to continue . . . "
fi ;
}

sort_cdrs()
{
#clears all the intermediate files.
cat /dev/null > intermediate1.txt
cat /dev/null > intermediate2.txt
cat /dev/null > intermediate3.txt

#cuts from the raw cdr_files.txt the lines with date | call_start_date | call_end_date into intermediate1.txt
cut -f 5,6,7 -d '|' cdr_files.txt > intermediate1.txt 

#we now separate this file by the desired day and the day before (dayminusone variable was calculated in verify_date)
grep -w "$reportdate" intermediate1.txt > intermediate2.txt
grep -w "$dayminusone" intermediate1.txt > intermediate3.txt

#just some info for the user 
echo -e "\n        Sorting CDR's by $report_date ... \c"
sleep 2
echo "Done."
sleep 1
echo -e "\n        Processing CDR's from the day before to check if any calls took place on $report_date ... \c"
sleep 2
echo "Done."
sleep 1

#checks if any calls started on the day before and ended in the day of interest and changes the call_start_date with 000000
cat /dev/null > intermediate1.txt
nawk -F"|" '{
		if ($2>=$3) 
		{$2="000000"
                 print $1"|"$2"|"$3;}
             }' < intermediate3.txt >> intermediate1.txt

#checks if any calls started on the day of interest end ends on the next day and changes the call_end_date with 235959
nawk -F"|" '{
		if ($2<=$3) 
		  print $1"|"$2"|"$3;
		else 
		   {$3="235959"
                    print $1"|"$2"|"$3;}
             }' < intermediate2.txt >> intermediate1.txt

#info to user
echo -e "\n        Calculating the duration of every call that took place on $report_date ... \c"
sleep 2
echo "Done."
sleep 1
#function to calculate the duration (in seconds) for the correct calls that took place in the specified day
cat /dev/null > intermediate3.txt
nawk -F "|"  '{ 	       
	             hh = substr($2,1,2)
		     mm = substr($2,3,2)
		     ss = substr($2,5,2)
		     sec1 = (hh*3600+mm*60+ss)
		     hh = substr($3,1,2)
		     mm = substr($3,3,2)
		     ss = substr($3,5,2)
                     sec2 = (hh*3600+mm*60+ss)
		     sec = sec2-sec1
		     print sec1,sec2+1,sec > "intermediate3.txt"
                    }' OFS='|' < intermediate1.txt 

#intermediate2.txt will now have 6 columns - date | call_start_date | call_end_date | index_start | index_end | duration_of_call
cat /dev/null > intermediate2.txt
paste -d "|" intermediate1.txt intermediate3.txt > intermediate2.txt

#intermediate1.txt will now have 2 columns - call_start_date | duration_of_call for the requested day.
cat /dev/null > intermediate1.txt
cut -f 4,5,6 -d '|' intermediate2.txt > intermediate1.txt
echo -e "\n "
cps_calc
}

verify_date ()
{
#stores the input date in a vector to verify if the format is correct and if that date exists
local -a vector
IFS='-' read -a vector <<< "$1"

if [ ${#vector[0]} -eq 4 ] && [ ${#vector[1]} -eq 2 ] && [ ${#vector[2]} -eq 2 ]
	then echo -e "\n	The date format is correct !"
	     sleep 1
	     echo -e "\n	Verifying date ... \c"
	     sleep 1
	     echo "Done."
	     sleep 1
if [ ${vector[1]} -gt 12 ] || [ ${vector[1]} -eq 00 ] || [ ${vector[2]} -eq 00 ] 
	then echo -e "\n    	This date doesn't exist ... day or/and month incorrect"
	     sleep 2
	     break
elif [ ${vector[1]} -eq 01 ] && [ ${vector[2]} -gt 31 ] 
	then echo -e "\n    	This date doesn't exist ... day or/and month incorrect"
	     sleep 2
	     break
elif [ ${vector[1]} -eq 03 ] && [ ${vector[2]} -gt 31 ] 
	then echo -e "\n    	This date doesn't exist ... day or/and month incorrect"
             sleep 2
	     break
elif [ ${vector[1]} -eq 05 ] && [ ${vector[2]} -gt 31 ] 
	then echo -e "\n    	This date doesn't exist ... day or/and month incorrect"
             sleep 2
	     break
elif [ ${vector[1]} -eq 07 ] && [ ${vector[2]} -gt 31 ] 
	then echo -e "\n    	This date doesn't exist ... day or/and month incorrect"
	     sleep 2
	     break
elif [ ${vector[1]} -eq 08 ] && [ ${vector[2]} -gt 31 ] 
	then echo -e "\n    	This date doesn't exist ... day or/and month incorrect"
             sleep 2
	     break
elif [ ${vector[1]} -eq 10 ] && [ ${vector[2]} -gt 31 ] 
	then echo -e "\n    	This date doesn't exist ... day or/and month incorrect"
	     sleep 2
	     break
elif [ ${vector[1]} -eq 12 ] && [ ${vector[2]} -gt 31 ] 
	then echo -e "\n    	This date doesn't exist ... day or/and month incorrect"
             sleep 2
             break
elif [ ${vector[1]} -eq 02 ] && [ ${vector[2]} -gt 29 ] 
	then echo -e "\n    	This date doesn't exist ... day or/and month incorrect"
	     sleep 2
	     break
elif [ ${vector[1]} -eq 04 ] && [ ${vector[2]} -gt 30 ] 
	then echo -e "\n    	This date doesn't exist ... day or/and month incorrect"
             sleep 2
	     break
elif [ ${vector[1]} -eq 06 ] && [ ${vector[2]} -gt 30 ] 
	then echo -e "\n    	This date doesn't exist ... day or/and month incorrect"
	     sleep 2
	     break
elif [ ${vector[1]} -eq 09 ] && [ ${vector[2]} -gt 30 ] 
	then echo -e "\n    	This date doesn't exist ... day or/and month incorrect"
	     sleep 2
	     break
elif [ ${vector[1]} -eq 11 ] && [ ${vector[2]} -gt 30 ] 
	then echo -e "\n        This date doesn't exist ... day or/and month incorrect" 
	     sleep 2
	     break
fi

else 
	echo -e "\n        The date format is not correct ! It should be YYYY-MM-DD ! "
	sleep 2
        break
	
fi

#stores the selected day in reportdate variable in form of YYYYMMDD 
for element in "${vector[@]}"
do
    reportdate="$reportdate$element"
done

#calculates the day before and stores it in dayminusone variable
day=$(echo "${vector[2]}")
month=$(echo "${vector[1]}")
year=$(echo "${vector[0]}")
#eliminating "0" in front of the digits so the 08 and 09 won't get confused with octals during the if clause
day=`echo $day|sed 's/^0*//'`
month=`echo $month|sed 's/^0*//'`
((day--))
if [ $day -eq 0 ] 
	then
	if [ $month -eq 12 ]   
then 
day="30" 
((month--))
              elif [ $month -eq 11 ]
then 
day="31"
((month--))
	      elif [ $month -eq 10 ] 
then 
day="30" 
((month--))
              elif [ $month -eq 9 ] 
then 
day="31" 
((month--))
	      elif [ $month -eq 8 ] 
then 
day="31" 
((month--))
	      elif [ $month -eq 7 ] 
then 
day="30" 
((month--))
	      elif [ $month -eq 6 ] 
then 
day="31" 
((month--))
	      elif [ $month -eq 5 ] 
then 
day="30" 
((month--))
	      elif [ $month -eq 4 ] 
then 
day="31" 
((month--))
	      elif [ $month -eq 3 ] 
then 
day="29" 
((month--))
	      elif [ $month -eq 2 ] 
then 
day="31" 
((month--))
	      elif [ $month -eq 1 ] 
then 
day="31" 
((month--))
              fi               
fi

if [ $day -le 9 ] 
then
day=$(echo "0$day")
fi
if [ $month -eq 0 ] 
then
	month="12"
	((year--))	
fi
if [ $month -le 9 ] 
then
month=$(echo "0$month")
fi
dayminusone=$year$month$day

sort_cdrs
break
}

#main program
while true
do
clear
cat menu.txt
echo -e "\n				    	Please select an option: \c"
read optiune
case "$optiune" in

1) while true
   do
   clear
   echo -e "

	Please enter the date for which you wish to create the report 
	The format must be YYYY-MM-DD: \c"
   
   read report_date
   verify_date $report_date
   
   done  
   ;;

2) while true
   do
clear
echo -e "\n \n \n 	     This is an option to create a new clean initial_report.txt  \n"
echo -e "\n 	     Use this option if initial_report.txt was altered in any way as it's used by this tool to create the daily reports.  \n"
echo -e "\n 	     DO NOT in any way interrupt this script while running !!! \n"
echo -e "\n 	     Do you wish to continue (y/n) \c"

#function to create the initial_report.txt that stores all the seconds in a day with 0 calls per seconds and it is used to calculate the cps using the calls duration
read optiune
case "$optiune" in
	y) cat /dev/null > initial_report.txt
echo -e "\n "
i=0
s="00"
m="00"
h="00"
echo "000000|0" > initial_report.txt
for (( i=0; i<=86398; i++ ))
do
s=`echo $s|sed 's/^0*//'`
s=$((s+1))
if [[ $s -le 9 ]]
then
s="0$s"
elif [[ $s -eq 60 ]]
	then	
	s="00"   
	m=`echo $m|sed 's/^0*//'`
        m=$((m+1))
                if [[ $m -le 9 ]]
			then 
			m="0$m"
		elif [[ $m -eq 60 ]]
				then
				m="00"
				h=`echo $h|sed 's/^0*//'`
			        h=$((h+1))
					if [[ $h -le 9 ]]
						then 
						h="0$h"
					fi
		fi
	
fi
let "i+=2"
echo "$h$m$s|0" >> "initial_report.txt"
let "i-=2"
timer=$(( i*100/86398))
echo -ne "	     Writing the report ---> $timer% \r"
done 
echo -e "\n "
read -n 1 -p "				   . . . Press any key to continue . . . "
break
;;
	n) clear
	   break
   	   ;;
esac
done
;;

3) clear 
   #calculates the total nr of calls and average call duration for the desired day and stores it in report_avg.log
   if [ "$report_date" == "" ]
   #if the user didn't entered a day at option 1 we will have no intermediate.txt files from which to calculate the average call duration
   then   
   	echo -e "\n \n 	     First you must create a report ( choose option 1 from the main menu )"
	sleep 3
   else
	echo -e "\n		\c"

	avg_call
 	#stdout the last line
	cat "reports/report_avg.log" | tail -1
   	echo -e "\n"
	read -n 1 -p "				  	 . . . Press any key to continue . . . "  
   fi	
   ;;

4) clear
   #help menu
   cat help.txt
	echo -e "\n"
   read -n 1 -p "				     . . . Press any key to continue . . . "
   ;;

5) clear
   #exits the tool
   exit ;;
esac
done
