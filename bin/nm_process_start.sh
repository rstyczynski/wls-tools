#!/bin/bash

start_cmd=$1
DOMAIN_OWNER=$2
log_dir=$3
log_name=$4

if [ $(whoami) != $DOMAIN_OWNER ]; then
    file_no=$(sudo su $DOMAIN_OWNER -c "ls $log_dir | grep -P '$log_name\.out\.\d+' | cut -d. -f3 | sort -nr | head -1")
else
    file_no=$(ls $log_dir | grep -P "$log_dir\.out\.\d+" | cut -d. -f3 | sort -nr | head -1)
fi
: ${file_no:=0}

file_no=$(( $file_no + 1 ))
stdout_log=$log_dir/$log_name.out.$file_no
stderr_log=$log_dir/$log_name.err.$file_no

rm -f $log_dir/$log_name.out; ln -s $stdout_log $log_dir/$log_name.out
rm -f $log_dir/$log_name.err; ln -s $stderr_log $log_dir/$log_name.err
$start_cmd >$stdout_log 2>$stderr_log

