#!/bin/bash


function usage() {
    echo "Usage: collect_wls_dump.sh [init | server_name] [threaddump count interval] [heapdump] [lsof] [top] [trace_root dir]"
}

source /etc/collect_wls_dumps.conf
source ~/etc/collect_wls_dumps.conf

if [[ $1 == 'init' ]] ; then
    init=yes; shift
else
    server_name=$1; shift
fi

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

if [[ $1 == 'trace_root' ]] ; then
    trace_root=$2; shift; shift
fi

: ${threaddump:=no}
: ${count:=10}
: ${interval:=6}
: ${heapdump:=no}
: ${lsof:=no}
: ${top:=no}
: ${trace_root:=~/trace}
: ${init:=no}


echo "==================================="
echo "======= WebLogic data dump ========"
echo "==================================="
echo "=== Host:       $(hostname)"
echo "=== Reporter:   $(whoami)"
echo "=== Date:       $(date)"
echo "==="
echo "=== threaddump: $threaddump"
echo "=== count:      $count"
echo "=== interval:   $interval"
echo "=== lsof:       $lsof"
echo "=== top:        $top"
echo "=== heapdump:   $heapdump"
echo "=== trace_root: $trace_root"
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

function check_sudo() {

    echo -n ">> checking sudo rights..."    
    sudo=sudo
    has_sudo=yes
    sudo -A /bin/ls ls >/dev/null 2>&1
    if [ $? -eq 1 ]; then
        sudo=
        has_sudo=no
        echo "No sudo rights."
    else
        echo "Has sudo rights."
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

    # check sudo rights
    check_sudo

    echo ">> installing gcore..."
    if [ $has_sudo == 'yes' ]; then    
        sudo yum install -y gdb crash-gcore-command
    else
        echo "Skipped. gcore may be not available on RH6. It's at RH7"
    fi

    echo ">> preparing inbox directory for users."
    # may be done with sudo or w/o sudo if user is owner of all path | check_sude sets sudo variable
    path=$trace_root/outbox

    if [ $has_sudo == 'no' ]; then
        mkdir -p $trace_root/outbox
    fi

    $sudo chmod o+r $path
    $sudo chmod o+w $path
    $sudo chmod g+r $path
    $sudo chmod g+w $path

    x_on_path=yes
    while [ ! $path == '/' ]; do
        $sudo chmod o+x $path
        $sudo chmod g+x $path
        if [ $? -ne 0 ]; then
            x_on_path=no
        fi
        path=$(dirname $path)
    done

    if [ $x_on_path = "yes" ]; then
        trace_outbox=$trace_root/outbox
    else
        echo -n ">> setting /var/outbox..."
        if [ $has_sudo == 'yes' ]; then    
            trace_outbox=/var/outbox
            sudo mkdir $trace_outbox
            sudo chmod o+x $trace_outbox
            sudo chmod o+r $trace_outbox
            sudo chmod o+w $trace_outbox
            echo "Done."
        else
            echo "Skipped."
        fi
    fi

    # echo ">> subdirectories osw, jfr, oom"
    # mkdir $trace_root/osw
    # mkdir $trace_root/jfr
    # mkdir $trace_root/oom
    if [ $has_sudo == 'yes' ]; then    
        echo ">> saving configuration to /etc/collect_wls_dumps.conf"
        echo "trace_root=$trace_root" | sudo tee -a /etc/collect_wls_dumps.conf
        echo "trace_outbox=$trace_root/outbox" | sudo tee -a /etc/collect_wls_dumps.conf
    else
        echo ">> saving configuration to ~/etc/collect_wls_dumps.conf"
        echo "trace_root=$trace_root" >> ~/etc/collect_wls_dumps.conf
        echo "trace_outbox=$trace_root/outbox" >> ~/etc/collect_wls_dumps.conf
    fi

    echo "Directory to expose files, reachable by any user, set to: $trace_outbox"
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


# reuse collection timestamp if already set | if -z $collection_timestamp then set
: ${collection_timestamp:=$(date::now)_$(time::now)}

log_dir=$trace_root/wls_dumps/$(hostname)_$collection_timestamp
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
        timeout 5 top -b -n 1 > $log_dir/$server_name\_top_$(time::now).top
        timeout 5 kill -3 $java_pid
        timeout 5 $java_bin/jstack $java_pid > $log_dir/$server_name\_threaddump_$(time::now).jstack
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
        timeout 5 $java_bin/jstack $java_pid > $log_dir/$server_name\_threaddump_$(time::now).jstack
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
        timeout 5 $java_bin/jstack $java_pid > $log_dir/$server_name\_threaddump_$(time::now).jstack
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
    timeout 5 top -b -n 1 > $log_dir/$server_name\_top_$(time::now).top
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

mkdir -p $trace_root/outbox

echo ">> removing old wls_dumps..."
rm -rf $trace_root/outbox/wls_dumps_*

cd $log_dir
if [ $threaddump == "yes" ]; then
    echo ">> compressing thread dumps..."
    tar -zcvf $trace_root/outbox/wls_dumps_$collection_timestamp\_jvm-$server_name\-threaddump.tar.gz *.jstack >/dev/null
fi

if [ $heapdump == "yes" ]; then
    echo ">> compressing heap dumps..."
    tar -zcvf $trace_root/outbox/wls_dumps_$collection_timestamp\_jvm-$server_name\-heapdump.tar.gz *.hprof >/dev/null
fi

if [ $lsof == "yes" ]; then
    echo ">> compressing lsof dumps..."
    tar -zcvf $trace_root/outbox/wls_dumps_$collection_timestamp\_jvm-$server_name\-lsof.tar.gz *.lsof >/dev/null
fi

if [ $top == "yes" ]; then
    echo ">> compressing top dumps..."
    tar -zcvf $trace_root/outbox/wls_dumps_$collection_timestamp\_jvm-$server_name\-top.tar.gz *.top >/dev/null
fi

cd -

echo ">> making everyone able to read dump files..."
chmod o+r $trace_root/outbox/wls_dumps_$collection_timestamp*

echo "Transportable tar files saved to $trace_root/outbox:"
ls -l -h $trace_root/outbox/wls_dumps_$collection_timestamp* | cut -d' ' -f5-999

echo

echo "Data collection timestamp: $collection_timestamp"