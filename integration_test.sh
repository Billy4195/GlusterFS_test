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

parse_volume $1
