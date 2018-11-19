ionutmos@SC01SERV03411:/home/abderelb$ cat stats.sh
#!/bin/bash
removeZero()
{
hour=$1
 if [ ${hour:0:1} -eq 0 ]
then
hour=${hour:1}
fi
echo $hour
}
addZero()
{
hour=$1
 if [ $hour -lt 10 ] && [ ${hour:0:1} != 00 ]
then
hour=0$hour
fi
echo $hour
}
nextHour()
{
h=$1
hour=$(removeZero $h)
nextHour=`expr $hour + 1`
nextHourWithZero=$(addZero $nextHour)
echo $nextHourWithZero
}

for req in ebs AFSCMv2\.1
do echo "$req"
for hour in `seq 0 23`
do
echo -n $(addZero $hour):00-$(nextHour $hour):00:
egrep "05/May/2015:$(addZero $hour):" /var/container_data/onsm_apache_proxy/log/access_newssl_log | egrep "/$req"| wc -l
done
done
ionutmos@SC01SERV03411:/home/abderelb$
