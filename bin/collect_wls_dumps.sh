#!/bin/bash


function usage() {
    echo "Usage: collect_wls_dump.sh server_name [threaddump count interval] [heapdump] [lsof] [oswatcher] [debug_root dir]"
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

if [[ $1 == 'lsof' ]] ; then
    lsof=yes; shift
fi

if [[ $1 == 'oswatcher' ]] ; then
    oswatcher=yes; shift
fi

if [[ $1 == 'debug_root' ]] ; then
    debug_root=$2; shift; shift
fi

: ${threaddump:=no}
: ${count:=5}
: ${interval:=5}
: ${heapdump:=no}
: ${lsof:=no}
: ${oswatcher:=yes}
: ${debug_root:=~/debug_data}

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
if [ $threaddump == "yes" ] && [ $lsof == "yes" ]; then
    echo ">> taking thread dumps and lsof"
    echo -n "Collecting thread dump and list of open files"
    for cnt in $(seq 1 $count); do
        lsof -p $java_pid > $log_dir/$server_name\_lsof_$(time::now).lsof
        $java_bin/jstack $java_pid > $log_dir/$server_name\_threaddump.$(time::now).jstack
        if [ $? -eq 0 ]; then
            echo -n "| $cnt of $count OK "
        else
            echo -n "| $cnt of $count Error "
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
        $java_bin/jstack $java_pid > $log_dir/$server_name\_threaddump.$(time::now).jstack
        if [ $? -eq 0 ]; then
            echo -n "| $cnt of $count OK "
        else
            echo -n "| $cnt of $count Error "
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
    $java_bin/jcmd $java_pid GC.heap_dump $log_dir/$server_name\_heapdump_$(time::now).hprof >/dev/null 2>&1
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
    lsof -p $java_pid > $log_dir/$server_name\_lsof_$(time::now).lsof
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

cd $log_dir
echo ">> compressing heap dumps..."
tar -zcvf $debug_root/outbox/$collection_timestmap\_jvm-$server_name\-heapdump.tar.gz *.hprof >/dev/null
echo ">> compressing thread dumps..."
tar -zcvf $debug_root/outbox/$collection_timestmap\_jvm-$server_name\-threaddump.tar.gz *.jstack >/dev/null
echo ">> compressing lsof dumps..."
tar -zcvf $debug_root/outbox/$collection_timestmap\_jvm-$server_name\-lsof.tar.gz *.lsof >/dev/null
cd -

if [ $oswatcher == 'yes' ]; then
    echo ">> compressing oswatcher files..."
    if [ -f /etc/sysconfig/oswatcher ]; then
        osw_dir=$(grep "^DATADIR=" /etc/sysconfig/oswatcher | cut -f2 -d=)
        cd $osw_dir
        tar -zcvf $debug_root/outbox/$collection_timestmap\_osw.tar.gz ./ >/dev/null
        cd -
    else
        echo Warning: OSWatcher not available. Skipping...
    fi
fi

echo "Transportable tar files saved to $debug_root/outbox"


