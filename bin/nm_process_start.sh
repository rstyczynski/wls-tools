#!/bin/bash

strt_cmd=$1
log_dir=$2
log_name=$3
stdout_log=$4
stderr_log=$5

rm -f $log_dir/$log_name.out; ln -s $stdout_log $log_dir/$log_name.out
rm -f $log_dir/$log_name.err; ln -s $stderr_log $log_dir/$log_name.err
$start_cmd >$stdout_log 2>$stderr_log

