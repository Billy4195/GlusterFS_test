#!bin/bash

bricks=()
nodes=()

function parse_volume {
local tmp
local index
local node_t
local brick_t
    volume_name=$1
    read -p "Enter number of reboot test: " reboot_num
    read -p "Enter number of replace-brick test: " replace_num
    read -p "Enter number of disconnect test: " disconnect_num
    read -p "Enter number of RW test: " rw_count
    read -p "Enter RW test file size: " rw_size
    echo ""
    tmp=($(gluster v info $1 | grep '^Brick[0-9]*:' | sed 's/^.* \(.*\S*\)/\1/'))
    for ((index=0;index<${#tmp[@]};index++))
    do
        nodes=(${nodes[@]} $(echo ${tmp[$index]} |sed 's/\(.*\):.*/\1/'))
    done
    bricks=(${bricks[@]} ${tmp[@]})

    [ -d /export/blk/fs ]
    tmp=$(tail -n 1 /etc/hosts | awk {' print $2'})
    bricks=($tmp:/export/blk/fs ${bricks[@]})
    if [ $? -eq 1 ]
    then 
        create_brick
    else
        check_mount 
    fi
    if [ -z $reboot_num ]
    then
        reboot_num=1
    fi
    if [ -z $replace_num ]
    then
        replace_num=1
    fi
    if [ -z $disconnect_num ]
    then
        disconnect_num=1
    fi
    if [ -z $rw_count ]
    then
        rw_count=3
    fi
    if [ -z $rw_size ]
    then
        rw_size=10
    fi
    close_monitor
    show_parse_result
}

function close_monitor {
local index
    monitor stop
    for ((index=0;index<${#nodes[@]};index++))
    do
        ssh root@${nodes[$index]} "monitor stop"
    done
}

function create_brick {
local device
local tmp
local pe
local vg
    tmp=$(echo ${bricks[1]} | sed 's/.*\(lvol.*\)\/.*/\1/' )
    pe=$(ssh root@${nodes[0]} "vgs -o lv_name,vg_name,seg_size_pe |grep $tmp | awk {'print \$3'} ")
    vg=$( vgs | sed -n '2,2p' | awk {'print $1'} )
    lvcreate -l $pe -i 2 -I 128k -W n -Z y -n test $vg
    mkfs.xfs -m crc=1 -d su=128k,sw=2 -f -K /dev/$vg/test > /dev/null 2>/dev/null
    echo "/dev/$vg/test /export/blk/fs  xfs inode64,noatime,nofail 0 0" >> /etc/fstab 
    mkdir -p /export/blk/fs
    mount -a

    [ -d /export/blk/fs ]
    if [ $? -ne 0 ]
    then 
        echo "Create Brick Failed"
        return 1
    fi
    echo "Create a new Brick from /dev/$vg/test "
    echo ""
    return 0
}

function check_mount {
    mount | grep /export/blk/fs >/dev/null
    if [ $? -ne 0 ]
    then 
        create_brick
    fi
    if [ $? -eq 0 ]
    then 
        echo "Brick has been Mounted on"
        echo ""
    fi
}

function show_parse_result {
local index
    echo "Volume name : $volume_name"
    echo ""
    echo "Volume nodes :"
    for ((index=0;index<${#nodes[@]};index++))
    do
        echo "    ${nodes[$index]}"
    done
    echo ""
    echo "Availiable Bricks:"
    for ((index=0;index<${#bricks[@]};index++))
    do
        echo "    ${bricks[$index]}"
    done
    echo ""
    echo "###Reboot $reboot_num times"
    echo "###Replace brick $replace_num times"
    echo "###Network disconnect $disconnect_num times"
    echo ""
    echo "###Num of RW_test : $rw_count"
    echo "###Num of RW_size : $rw_size"
    echo ""
}

function start_rw_test {
local index
    echo "~~~~Start RW test~~~~"
    tmux new-session -s test -d "./rwtest_Linux /log=6 /iosize=2048 /path=/volume/$volume_name x: $rw_size"
    for ((index=1;index<rw_count;index++))
    do 
        tmux new-window -t test "./rwtest_Linux /log=6 /iosize=2048 /path=/volume/$volume_name x: $rw_size"
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
    else 
        check_times=$1
    fi
    while [ $count -lt $check_times ]
    do 
        #echo Count --- $count
        sleep 2
        check_rw_test
        if [ $? != 0 ]
        then 
            return 1
        fi
        if [ $# -ge 2 ]
        then
            ping -c 1 $2 > /dev/null
            if [ $? != 0 ]
            then 
                continue
            fi
            #echo "$2 UP"
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
local bricks
local nodes
local tmp
local index
local dirty_a
local dirty
    tmp=($(gluster v info $volume_name | grep '^Brick[0-9]*:' | sed 's/^.* \(.*\S*\)/\1/'))
    for ((index=0;index<${#tmp[@]};index++))
    do
        nodes=(${nodes[@]} $(echo ${tmp[$index]} |sed 's/\(.*\):.*/\1/'))
    done
    for ((index=0;index<${#tmp[@]};index++))
    do
        bricks=(${bricks[@]} $(echo ${tmp[$index]} |sed 's/^.*:\(\S*\)/\1/'))
    done
    index=0
    while [ $index -lt ${#nodes[@]} ]
    do 
        dirty=0
        dirty_a=($(ssh root@${nodes[$index]} "for i in ${bricks[$index]}/*;do getfattr -d -m. -e hex --absolute-names \$i |grep dirty ;done"))
        #echo ${dirty[@]}
        for ((tmp=0;tmp<${#dirty_a[@]};tmp++))
        do
            if [ ${dirty_a[$tmp]} != "trusted.ec.dirty=0x00000000000000000000000000000000" ]
            then 
                dirty=1
                break
            fi
        done
        if [ $dirty -eq 1 ]
        then 
            continue
        fi
        index=$((index+1))
    done
    return 0
}

function reboot_test {
local index
    echo "==========REBOOT TEST START=========="
    for ((index=0;index<${#nodes[@]};index++))
    do
        check_status
        reboot_fn ${nodes[$index]}
        check_status 10 ${nodes[$index]}

        case "$?" in
        1)
            echo "RW test ERROR"
            echo "==========REBOOT TEST END=========="
            return 1
            ;;
        esac

    done
    echo "==========REBOOT TEST END=========="
    return 0
}

function reboot_fn {
    ssh $1 reboot
    sleep 5
    return 0
}

function replace_brick_test {
local index
local next
    echo "==========REPLACE BRICK TEST START=========="
    for ((index=0;index<$((${#nodes[@]}+1));index++))
    do
        if [ $index -eq ${#nodes[@]} ]
        then
            next=0
        else
            next=$((index+1))
        fi
        check_status
        replace_brick_fn ${bricks[$next]} ${bricks[$index]}
        check_status 10

        case "$?" in
        1)
            echo "RW test ERROR"
            echo "==========REPLACE BRICK TEST END=========="
            return 1
            ;;
        esac

    done
    echo "==========REPLACE BRICK TEST END=========="
    return 0
}

function replace_brick_fn {
    gluster v replace-brick $volume_name $1 $2 commit force
}

function disconnect_test {
local index
    echo "==========NETWORK DISCONNECT TEST START=========="
    for ((index=0;index<${#nodes[@]};index++))
    do
        check_status
        disconnect_fn ${nodes[$index]}
        check_status 10 ${nodes[$index]}

        case "$?" in
        1)
            echo "RW test ERROR"
            echo "==========NETWORK DISCONNECT TEST END=========="
            return 1
            ;;
        esac

    done
    echo "==========NETWORK DISCONNECT TEST END=========="
    return 0
}

function disconnect_fn {
    ssh root@$1-backup ifdown bond-slave-eth1 > /dev/null
    ssh root@$1-backup ifdown bond-slave-eth2 > /dev/null
    echo "DISCONNECT $1"
    sleep 20
    ssh root@$1-backup ifup bond-slave-eth1   > /dev/null
    ssh root@$1-backup ifup bond-slave-eth2   > /dev/null
    echo "RECONNECT $1"
    sleep 20
    return 0
}

function Main_test {
local index
    for ((index=0;index<$reboot_num;index++))
    do
        reboot_test
        if [ $? -ne 0 ]
        then 
            return 1
        fi
    done
    for ((index=0;index<$replace_num;index++))
    do
        replace_brick_test
        if [ $? -ne 0 ]
        then 
            return 1
        fi
    done
    for ((index=0;index<$disconnect_num;index++))
    do
        disconnect_test
        if [ $? -ne 0 ]
        then
            return 1
        fi
    done
}

parse_volume $1
start_rw_test
Main_test
close_rw_test
