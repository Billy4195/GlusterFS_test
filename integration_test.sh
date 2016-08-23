#!bin/bash

bricks=(VM25:/export/bk1/fs)
nodes=()

function parse_volume {
local tmp
local index
    volume_name=$1
    tmp=($(gluster v info $1 | grep '^Brick[0-9]*:' | sed 's/^.* \([Vv][Mm][0-9]*\S*\)/\1/'))
    for ((index=0;index<${#tmp[@]};index++))
    do
        nodes=(${nodes[@]} $(echo ${tmp[$index]} |sed 's/\([Vv][Mm][0-9]*\).*/\1/'))
    done
    bricks=($bricks ${tmp[@]})
    show_parse_result
}

function show_parse_result {
local index
    echo "Volume name : $volume_name"
    echo "Volume nodes :"
    for ((index=0;index<${#nodes[@]};index++))
    do
        echo "    ${nodes[$index]}"
    done
    echo "Availiable Bricks:"
    for ((index=0;index<${#bricks[@]};index++))
    do
        echo "    ${bricks[$index]}"
    done
}

function start_rw_test {
local index
    if [ $# != 0 ] && [ $1 -gt 0 ]
    then 
        rw_count=$1
    else
        rw_count=3
    fi
    echo "~~~~Start RW test~~~~"
    tmux new-session -s test -d "./rwtest_Linux /log=6 /iosize=1024 /path=/volume/$volume_name x: 10"
    for ((index=1;index<rw_count;index++))
    do 
        tmux new-window -t test "./rwtest_Linux /log=6 /iosize=1024 /path=/volume/$volume_name x: 10"
    done
}

function close_rw_test {
    tmux kill-session -t test
    rm -rf /volume/$volume_name/_R\@W_*
    echo "~~~~Close RW test success!~~~~" 
}

function check_status {
local count=0
local check_times
    if [ $# == 0 ]
    then 
        check_times=5
    fi
    while [ $count -lt $check_times ]
    do 
        sleep 2
        check_rw_test
        if [ $? != 0 ]
        then 
            return 1
        fi
        check_heal_finish
        if [ $? == 0 ]
        then
            count=$((count+1))
        fi
    done
    echo "Check status Finish"
}

function check_rw_test {
    if [ $(pidof rwtest_Linux | wc -w) == $rw_count ]
    then
        return 0 
    else
        return 1
    fi
}

function check_heal_finish {
    return 0
}

parse_volume $1
start_rw_test
check_status
close_rw_test
