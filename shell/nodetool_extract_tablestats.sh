#!/bin/bash



for i in subscription_history_log_by_log_timestamp_hour subscription_by_last_update_hour rsp_session_by_last_update_hour
do 
    for x in `cat 0.txt`
    do 
    echo './nodetool tablestats -H '$x.$i' -p 7199' >> command_to_execute.sh
    done
done


for i in subscription_history_log_by_log_timestamp_hour subscription_by_last_update_hour rsp_session_by_last_update_hour
do 
    for x in `cat 1.txt`
        do 
    echo './nodetool tablestats -H '$x.$i' -p 7198' >> command_to_execute.sh
    done
    
done
