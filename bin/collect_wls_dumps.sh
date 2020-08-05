#!/bin/bash


function usage() {
    echo "Usage: collect_wls_dump.sh [init] server_name [threaddump count interval] [heapdump] [lsof] [top] [debug_root dir]"
}

if [[ $1 == 'init' ]] ; then
    init=yes; shift
fi

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

if [[ $1 == 'lsof' ]] ; then
    lsof=yes; shift
fi

if [[ $1 == 'top' ]] ; then
    top=yes; shift
fi

if [[ $1 == 'debug_root' ]] ; then
    debug_root=$2; shift; shift
fi

: ${threaddump:=no}
: ${count:=10}
: ${interval:=6}
: ${heapdump:=no}
: ${lsof:=no}
: ${top:=no}
: ${debug_root:=~/trace}
: ${init:=no}


echo "==================================="
echo "======= WebLogic data dump ========"
echo "==================================="
echo "=== Host:       $(hostname)"
echo "=== Reporter:   $(whoami)"
echo "=== Date:       $(date)"
echo "==="
echo "=== Server:     $server_name"
echo "==================================="

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

#
# init
#
function init() {

    # echo ">> installing oswatcher"

    # timeout 1 sudo ls >/dev/null 2>&1
    # if [ $? -eq 124 ]; then
    #     echo "Error: must have rights to do sudo, but $(whoami) has no rights. Switch sodo user and repeat."
    #     quit 1
    # else
    #     sudo yum install -y oswatcher

    #     os_release=$(cat /etc/os-release | grep '^VERSION=' | cut -d= -f2 | tr -d '"' | cut -d. -f1)
    #     case $os_release in
    #     6)
    #         sudo chkconfig oswatcher on; echo "oswatcher service enabled on boot."
    #         sudo service oswatcher start; echo "oswatcher service started."
    #         ;;
    #     7)
    #         sudo systemctl enable oswatcher; echo "oswatcher service enabled on boot."
    #         sudo systemctl start oswatcher; echo "oswatcher service started."
    #         ;;
    #     *)
    #         echo Error. Unsupported OS release.
    #         quit 1
    #         ;;
    #     esac
    #     echo "Done."
    # fi

    echo ">> preparing inbox directory for oracle user."
    sudo mkdir /var/outbox
    sudo chmod o+x /var/outbox
    sudo chmod o+r /var/outbox
    sudo chmod o+w /var/outbox
    echo "Done."
}


#
# init
#
if [ $init == "yes" ]; then
    init
    quit 0
fi

#
# do work
#

collection_timestamp=$(date::now)_$(time::now)
log_dir=$debug_root/$(hostname)_$collection_timestamp; mkdir -p $log_dir
mkdir -p $log_dir

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
if [ $threaddump == "yes" ] && [ $lsof == "yes" ] && [ $top == "yes" ]; then
    echo ">> taking thread dumps, lsof and processes"
    echo -n "Collecting thread dump with list of open files and processes"
    for cnt in $(seq 1 $count); do
        timeout 5 lsof -p $java_pid > $log_dir/$server_name\_lsof_$(time::now).lsof
        timeout 5 top -b -n 1 > $log_dir/$server_name\_lsof_$(time::now).top
        timeout 5 kill -3 $java_pid
        timeout 5 $java_bin/jstack $java_pid > $log_dir/$server_name\_threaddump.$(time::now).jstack
        if [ $? -eq 0 ]; then
            echo -n "| $cnt of $count OK "
        else
            echo -n "| $cnt of $count Error (hope kill -3 producted dump in out file)"
        fi
        
        if [ $cnt -ne $count ]; then
            sleep $interval
        fi
    done
    echo "| Done."
elif [ $threaddump == "yes" ] && [ $lsof == "yes" ]; then
    echo ">> taking thread dumps and lsof"
    echo -n "Collecting thread dump and list of open files"
    for cnt in $(seq 1 $count); do
        timeout 5 lsof -p $java_pid > $log_dir/$server_name\_lsof_$(time::now).lsof
        timeout 5 kill -3 $java_pid
        timeout 5 $java_bin/jstack $java_pid > $log_dir/$server_name\_threaddump.$(time::now).jstack
        if [ $? -eq 0 ]; then
            echo -n "| $cnt of $count OK "
        else
            echo -n "| $cnt of $count Error (hope kill -3 producted dump in out file)"
        fi
        
        if [ $cnt -ne $count ]; then
            sleep $interval
        fi
    done
    echo "| Done."
elif [ $threaddump == "yes" ]; then
    echo ">> taking thread dumps"
    echo -n "Collecting thread dump "
    for cnt in $(seq 1 $count); do
        timeout 5 kill -3 $java_pid
        timeout 5 $java_bin/jstack $java_pid > $log_dir/$server_name\_threaddump.$(time::now).jstack
        if [ $? -eq 0 ]; then
            echo -n "| $cnt of $count OK "
        else
            echo -n "| $cnt of $count Error (hope kill -3 producted dump in out file)"
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
    echo ">> taking heap dump "
    echo -n "Collecting heap dump "
    timeout 600 $java_bin/jcmd $java_pid GC.heap_dump $log_dir/$server_name\_heapdump_$(time::now).hprof >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -n "| OK "
    else
        echo -n "| Error "
    fi
    echo "| Done."
fi

#
# lsof
#
if [ $threaddump == "no" ] && [ $lsof == "yes" ]; then
    echo ">> taking list of open files "
    echo -n "Collecting lsof "
    timeout 5 lsof -p $java_pid > $log_dir/$server_name\_lsof_$(time::now).lsof
    if [ $? -eq 0 ]; then
        echo -n "| OK "
    else
        echo -n "| Error "
    fi
    echo "| Done."
fi

#
# top
#
if [ $threaddump == "no" ] && [ $top == "yes" ]; then
    echo ">> taking list of processes "
    echo -n "Collecting top "
    timeout 5 top -b -n 1 > $log_dir/$server_name\_lsof_$(time::now).top
    if [ $? -eq 0 ]; then
        echo -n "| OK "
    else
        echo -n "| Error "
    fi
    echo "| Done."
fi

echo "Dumps saved to $log_dir"

#
# tar
#

mkdir -p $debug_root/outbox

echo ">> removing old wls_dumps..."
rm -rf $debug_root/outbox/wls_dumps_*

cd $log_dir
if [ $threaddump == "yes" ]; then
    echo ">> compressing thread dumps..."
    tar -zcvf $debug_root/outbox/wls_dumps_$collection_timestamp\_jvm-$server_name\-threaddump.tar.gz *.jstack >/dev/null
fi

if [ $heapdump == "yes" ]; then
    echo ">> compressing heap dumps..."
    tar -zcvf $debug_root/outbox/wls_dumps_$collection_timestamp\_jvm-$server_name\-heapdump.tar.gz *.hprof >/dev/null
fi

if [ $lsof == "yes" ]; then
    echo ">> compressing lsof dumps..."
    tar -zcvf $debug_root/outbox/wls_dumps_$collection_timestamp\_jvm-$server_name\-lsof.tar.gz *.lsof >/dev/null
fi

if [ $top == "yes" ]; then
    echo ">> compressing top dumps..."
    tar -zcvf $debug_root/outbox/wls_dumps_$collection_timestamp\_jvm-$server_name\-top.tar.gz *.top >/dev/null
fi

cd -

echo ">> making everyone able to read dump files..."
chmod o+r $debug_root/outbox/wls_dumps_$collection_timestamp*

echo "Transportable tar files saved to $debug_root/outbox:"
ls -l -h $debug_root/outbox/wls_dumps_$collection_timestamp* | cut -d' ' -f5-999

echo

echo "Data collection timestamp: $collection_timestamp"