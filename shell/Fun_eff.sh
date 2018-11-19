#!/bin/bash

if [ "$#" -ne 1 ]
then 
echo
echo "This is the help"
echo
echo
echo "You need to provide the following arguments"
echo
echo
echo "1. The Month and year for extracted period in format Mon/YYYY "
echo
echo " Example :"
echo 
echo " ./fun_eff.sh Apr/2015 "
echo
echo
else



MONTH=$1
ACCESS_LOG=/var/container_data/onsm_apache_proxy/log/access_log

# Functionals errors AFSCM : 
AFSCM_ERROR=`grep AFSCM $ACCESS_LOG | grep -v ' 20' | grep -i $MONTH  | grep -v '500 475' | grep -v '500 440' | grep -v '500 396' | grep -v '500 368' | grep -v '500 431' | grep -v '500 496' | grep -v '500 371' | grep -v '500 438' | grep -v '500 398' | grep -v '500 420' | wc -l`


AFSCM_TOTAL=`grep AFSCM $ACCESS_LOG | grep -i $MONTH | wc -l`


AFSCM_PERC=`awk "BEGIN {print 100-( $AFSCM_ERROR*100/$AFSCM_TOTAL )}"`

#Descriptions : Requests succesful +  Error 14 (unknown MSISD) + Error 402 (UICC Not Compliant) + Error 403 (Mobile handset not compliant with NFC Services) + Error 1 (Value Error – Incorrect data sent by SP TSM) + Error 401 (Customer Not Activated) + Error 210 (SSD already Created and Allocated for this SP)
 
 
#Functional errors EBS :
EBS_ERROR=`grep ebs $ACCESS_LOG | grep -v ' 200 ' | grep -i $MONTH | grep -v '500 498' | grep -v ' 400 ' | grep -v '500 484' | grep -v ' 500 482' | grep -v '500 478' | wc -l`

EBS_TOTAL=`grep ebs $ACCESS_LOG | grep -i $MONTH | wc -l`

EBS_PER=`awk "BEGIN {print 100-( $EBS_ERROR*100/$EBS_TOTAL )}"`

#Requests Succesful + SubscriberAlreadyDefined + ICCIDAlreadyUsed + UnknownSubscriber + UnknownProfile
 
 
#Functional errors OWM
OWM_ERROR=`grep owm $ACCESS_LOG | grep -i $MONTH | grep ' 50' | grep -v ' 200 ' | grep -v Logo | grep -v '500 7046' | grep -v '500 7068' | wc -l`

OWM_TOTAL=`grep owm $ACCESS_LOG | grep -i $MONTH | grep -v '500 7046' | grep -v '500 7068' | wc -l`

OWM_PER=`awk "BEGIN {print 100-( $OWM_ERROR*100/$OWM_TOTAL )}"`
 
#Response with http code 200 or 304. Request with missing http headers (Wassup Translator Issue) are not counted 
 

divider===============================
divider=$divider$divider

header="\n %-10s %8s %10s %11s %1s\n"
format=" %-10s %8s %10s %11.2f %%\n"

width=43

echo
echo
printf "\t\tStatistics for : $MONTH\n" "$divider" 

printf "$header" "ITEM NAME" "Failures" "Total" "Rate"

printf "%$width.${width}s\n" "$divider"

printf "$format" \
AFSCM $AFSCM_ERROR $AFSCM_TOTAL $AFSCM_PERC \
EBS $EBS_ERROR $EBS_TOTAL $EBS_PER  \
OWM $OWM_ERROR $OWM_TOTAL $OWM_PER
 
 fi
