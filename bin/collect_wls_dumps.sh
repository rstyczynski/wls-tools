#!/bin/bash


function usage() {
    echo "Usage: collect_wls_dump.sh server_name [threaddump count interval] [heapdump] [log_root dir]"
}

server_name=$1; shift

reg_int='^[0-9]+$'
if [[ $1 == 'threaddump' ]] ; then
    threaddump=yes; shift
    if [[ $1 =~ $reg_int ]] ; then
        count=$1; shift
    fi
    if [[ $1 =~ $reg_int ]] ; then
        interval=$1; shift
    fi
fi

if [[ $1 == 'heapdump' ]] ; then
    heapdump=yes; shift
fi

if [[ $1 == 'log_root' ]] ; then
    log_root=$2; shift; shift
fi

: ${threaddump:yes}
: ${count:=5}
: ${interval:=5}
: ${heapdump:=yes}
: ${log_root:=~/debug_data}

##
## shared functions
##
function utc::now() {
    date -u +"%Y-%m-%dT%H:%M:%S.000Z"
}
function date::now() {
    date -u +"%Y-%m-%d"
}
function time::now() {
    date -u +"%H:%M:%S.000Z"
}

function quit(){
    if [ "$0" == '-bash' ]; then
        return $1
    else
        exit $1
    fi
}


log_dir=$log_root/$(hostname)/$(date::now); mkdir -p $log_dir

java_pid=$(ps -ef | grep java | grep $server_name | grep -v grep | awk '{print $2}')
if [ -z $java_pid ]; then
    echo "Error: no such server: $server_name"
    usage
    quit 1
fi

java_user=$(ps -ef | grep java | grep $server_name | grep -v grep | awk '{print $1}')
if [ $java_user != $(whoami) ]; then
    echo "Error: must be java process owner i.e. $java_user, but you are $(whoami). Switch user and repeat."
    usage
    quit 1
fi

java_bin=$(dirname $(ps -ef | grep java | grep $server_name | grep -v grep | awk '{print $8}'))
$java_bin/jstack >/dev/null 2>&1
if [ $? -eq 127 ]; then 
  echo Error: jstack not found.
  quit 1 
fi

$java_bin/jcmd >/dev/null 2>&1
if [ $? -eq 127 ]; then 
  echo Error: jcmd not found.
  quit 1 
fi

#
# thread dumps
#
if [ $threaddump == "yes" ]; then
    echo ">> taking thread dumps"
    echo -n "Collecting thread dump "
    for cnt in $(seq 1 $count); do
        $java_bin/jstack $java_pid > $log_dir/threaddump.$(time::now).jstack
        if [ $? -eq 0 ]; then
            echo -n "| $cnt of $count Done."
        else
            echo -n "| $cnt of $count Error."
        fi
        
        if [ $cnt -ne $count ]; then
            sleep $interval
        fi
    done
    echo "| Done."
fi

#
# heap dump
#
if [ $heapdump == "yes" ]; then
    echo ">> taking heap dump"
    $java_bin/jcmd $java_pid GC.heap_dump $log_dir/heapdump_$(time::now).hprof >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "| Done."
    else
        echo "| Error."
    fi
fi

echo "Dumps saved to $log_dir"

