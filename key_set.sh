#!/bin/bash 

hosts=($(cat /etc/hosts | grep -v local | awk {' print $2 '} | grep -v backup ))
add=$(tail -n 1 /etc/hosts)
match=$(echo $add | awk {'print $2'})
for ((index=0;index<${#hosts[@]};index++))
do
    ssh-copy-id root@${hosts[$index]]} 
    if [ $? -eq 0 ]
    then
        echo "${hosts[$index]} copy key success!!"
    fi
    tmp=$(ssh root@${hosts[$index]} "cat /etc/hosts | grep $match")
    #echo $tmp
    if [ $? -ne 0 ]
    then
        ssh root@${hosts[$index]} "echo '$add' >> /etc/hosts"
    fi
    echo ""
done

