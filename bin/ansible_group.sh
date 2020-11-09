#!/bin/bash

inventory=$1; shift
cmd=$1; shift
host=$1; shift

: ${host:=$(hostname -i)}

#
#
#
function usage() {
    echo "Usage: ansible_groups inventory [count|names] [host]"
}

#
#
# 

group_names_raw=$(ansible -i $inventory $host -m debug -a 'var=group_names' -o)
group_names_json=${group_names_raw#*=>}

case $cmd in:
count)
    group_cnt=$(echo $group_names_json | jq -r '.group_names' | tr -d '[\n] "' | tr , '\n' | wc -l)
    echo $group_cnt
    ;;
names)
    group_names=$(echo $group_names_json | jq -r '.group_names' | tr -d '[\n] "' | tr , ' ')
    echo $group_names
    ;;
*)
    echo "Error. Unknown command"
    usage
    exit 1
    ;;
esac

