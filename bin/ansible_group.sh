#!/bin/bash

inventory=$1; shift
cmd=$1; shift
host=$1; shift

: ${host:=$(hostname -i)}

#
#
#
function usage() {
    echo "Usage: ansible_groups inventory [count|name|names] [host]"
}

#
#
# 

group_names_raw=$(ansible -i $inventory $host -m debug -a 'var=group_names' -o)
group_names_json=${group_names_raw#*=>}

case $cmd in
count)
    group_cnt=$(echo $group_names_json | jq -r '.group_names' | tr -d '[\n] "' | tr , '\n' | wc -l)
    echo $group_cnt
    ;;
name)
    group_cnt=$(echo $group_names_json | jq -r '.group_names' | tr -d ' "' | sed '/^\[$/d;/^\]$/d' | tr , '\n'  | wc -l)
    if [ $group_cnt -eq 1 ]; then
        group_name=$(echo $group_names_json | jq -r '.group_names[0]')
        echo $group_name
    else
        >&2 echo "Error. More than one group assigned."
        exit 2
    fi
    ;;
names)
    group_names=$(echo $group_names_json | jq -r '.group_names' | tr -d '[\n] "' | tr , ' ')
    echo $group_names
    ;;
*)
    >&2 echo "Error. Unknown command"
    usage
    exit 1
    ;;
esac

