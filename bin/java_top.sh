#!/bin/bash

tool_name="java top"
tool_author=ryszard.styczynski@oracle.com
tool_version=0.1


function say() {
    nl=yes
    if [ "$1" == '-n' ]; then
        nl=no
        shift
    fi

    if [ $nl == yes ]; then
        echo "$@" | tee -a $report
    else
        echo -n "$@" | tee -a $report
    fi
}

function sayatcell() {

    nl=yes
    if [ $1 == '-n' ]; then
        nl=no
        shift
    fi

    fr=no
    if [ $1 == '-f' ]; then
        fr=yes
        shift
    fi

    what=$1; shift
    size=$1; shift

    back='____________________________________________________________________________________________________________'
    back='                                                                                                            '
    dots='............................................................................................................'

    what_lth=$(echo -n $what | wc -c)

    if [ $what_lth -lt $size ]; then
        pre=$(echo "($size - $what_lth)/2" | bc)
        post=$(echo "$size - $what_lth - $pre" | bc)
        
        if [ $pre -gt 0 ]; then 
            echo -n "$back" | cut -b1-$pre | tr -d '\n'
        fi

        echo -n "$what"
        
        if [ $post -gt 0 ]; then
            echo -n "$back" | cut -b1-$post | tr -d '\n'
        fi

    elif [ $what_lth -gt $size ]; then
        echo -n "$what" | cut -b1-$(( $size - 2 )) | tr -d '\n'
        echo -n "$dots" | cut -b1-2 | tr -d '\n'
    elif [ $what_lth -eq $size ]; then
        echo -n "$what" 
    fi

    if [ $nl == yes ]; then
        if [ $fr == yes ]; then
            echo '|'
        else
            echo
        fi
    elif [ $fr == yes ]; then
            echo -n '|'
    fi
}



#
# 
#

function quit() {
    exit_code=$1
    exit_msg=$2
    : ${exit_code:=0}

    if [ $exit_code -eq 0 ]; then
      rm -f ~/tmp/java_top*.$$
    else
      if [ $(ls ~/tmp/java_top_*.$$ 2>/dev/null | wc -l) -gt 0 ]; then
        echo "Temp files left for analysis: $(ls ~/tmp/java_top_*.$$)."
      fi
    fi

    cat <<EOF_quit
$exit_msg
######################################
EOF_quit

    exit $1
}

function quit_int() {
  quit 101 "Operation interrupted by operator."
}

trap quit_int SIGINT

function usage() {

cat <<EOF_usage
Usage: java_top.sh process_identifier top_threads stack_lines

, where:
- process_identifier - unique text to selet exactly one line from list of all processes
- top_threads - shows top CPU consumigm threds. Defaults to 5
- stack_lines - shows requsted number f stack trace for each displayed thread. Defults to 0

Utility uses jstack to connect to pointed JVM in both reglar and forced mode. Should be used by owner of JVM or user with sude rights. OS level information is taken from ps and top tools. CPU utilisation is as for now - repoted by top.

######################################
$tool_name v$tool_version by $tool_author
EOF_usage

}

function java_top() {

process_identifier=$1 
top_threads=$2
stack_lines=$3

if [ -z "$process_identifier" ]; then
  usage()
  quit 100
fi


: ${top_threads:=5}
: ${stack_lines:=0}

mkdir -p ~/tmp/java_top

cat <<EOF_intro
######################################
$tool_name v$tool_version by $tool_author

EOF_intro


java_pid=$(ps aux | grep $process_identifier | grep -v grep | grep -v java_top.sh | tr -s ' ' | cut -f2 -d' ')
if [ -z "$java_pid" ]; then
    quit 1 "Java process not found."
fi

if [ $(echo $java_pid | tr ' ' '\n' | wc -l) -gt 1 ]; then
    ps aux | grep $process_identifier | grep -v grep | grep -v java_top.sh

    quit 2 "Multiple java processes found. Make identifier more precise"
fi

java_owner=$(ps aux | grep $process_identifier | grep -v grep | grep -v java_top.sh | tr -s ' ' | cut -f1 -d' ')
java_bin=$(dirname $(ps aux | grep $process_identifier | grep -v grep | grep -v java_top.sh| tr -s ' '  | cut -f11 -d' '))

rm -f ~/tmp/java_top_jstack.$$

jstack_mode=regular
jstack_run=regular
echo "Trying to start jstack as $jstack_run in $jstack_mode mode."
timeout 30 $java_bin/jstack $java_pid > ~/tmp/java_top_jstack.$$ 2>~/tmp/java_top_jstack_err.$$
if [ $? -ne 0 ]; then
  jstack_run="sudo"
  echo "Trying to start jstack as $jstack_run in $jstack_mode mode."
  sudo su - $java_owner -c "timeout 30 $java_bin/jstack $java_pid" > ~/tmp/java_top_jstack.$$ 2>~/tmp/java_top_jstack_err.$$
  if [ $? -ne 0 ]; then
    jstack_mode=forced
    jstack_run="regular"
    echo "Trying to start jstack as $jstack_run in $jstack_mode mode."
    timeout 60 $java_bin/jstack -F $java_pid > ~/tmp/java_top_jstack.$$ 2>~/tmp/java_top_jstack_err.$$
    if [ $? -ne 0 ]; then
      jstack_run="sudo"
      echo "Trying to start jstack as $jstack_run in $jstack_mode mode."
      sudo su - $java_owner -c "timeout 60 $java_bin/jstack -F $java_pid" > ~/tmp/java_top_jstack.$$  2>~/tmp/java_top_jstack_err.$$
    fi
  fi
fi

if [ $(cat ~/tmp/java_top_jstack.$$ | wc -l) -eq 0 ]; then
   rm -f ~/tmp/java_top_jstack.$$
fi

if [ ! -f ~/tmp/java_top_jstack.$$ ]; then
    quit 3 "Not able to connect to JVM."
fi


cat <<EOF1a
######################################
##### host................:$(hostname)
##### operator............:$(logname)
##### date................:$(date)
###################
##### jstack run mode.....:$jstack_run
###################
##### process_identifier..:$process_identifier
##### top threads.........:$top_threads
##### thread stack lines..:$stack_lines
EOF1a

cat <<EOF1b
###################
##### java_pid............:$java_pid
##### java_owner..........:$java_owner
##### java_bin...........:$java_bin
##### thread dump mode....:$jstack_mode
######################################

EOF1b

#
# ps headers discovery
ps aux -L | grep -P  "$java_owner\s+$java_pid" | grep -v grep | sort -rnk4,4  > ~/tmp/java_top_ps.$$

pid_col=$(ps aux -L | head -1 | tr -s ' ' | tr ' ' '\n' | nl | tr -s ' ' | tr '\t' ' ' | cut -d' ' -f2,3 | grep " PID$" | cut -f1 -d' ')
lwp_col=$(ps aux -L | head -1 | tr -s ' ' | tr ' ' '\n' | nl | tr -s ' ' | tr '\t' ' ' | cut -d' ' -f2,3 | grep " LWP$" | cut -f1 -d' ')
#cpu_col=$(ps aux -L | head -1 | tr -s ' ' | tr ' ' '\n' | nl | tr -s ' ' | tr '\t' ' ' | cut -d' ' -f2,3 | grep " %CPU$" | cut -f1 -d' ')
mem_col=$(ps aux -L | head -1 | tr -s ' ' | tr ' ' '\n' | nl | tr -s ' ' | tr '\t' ' ' | cut -d' ' -f2,3 | grep " %MEM$" | cut -f1 -d' ')
start_col=$(ps aux -L | head -1 | tr -s ' ' | tr ' ' '\n' | nl | tr -s ' ' | tr '\t' ' ' | cut -d' ' -f2,3 | grep " START$" | cut -f1 -d' ')
time_col=$(ps aux -L | head -1 | tr -s ' ' | tr ' ' '\n' | nl | tr -s ' ' | tr '\t' ' ' | cut -d' ' -f2,3 | grep " TIME$" | cut -f1 -d' ')

pscols=$((echo $pid_col; echo $lwp_col; echo $mem_col; echo $start_col; echo $time_col) | sort -n | tr '\n' ',' | sed 's/,$//' | sed 's/^,//')

#
# top header discovery
cat ~/tmp/java_top_ps.$$  | tr -s ' ' | cut -f$lwp_col -d' ' | sed 's/^/^/g' | sed 's/$/ /' >~/tmp/java_top_ps_lwp.$$

top -H -b -n 1  | sed 's/^\s*//' > ~/tmp/java_top_top.$$
cat ~/tmp/java_top_top.$$ | grep -f ~/tmp/java_top_ps_lwp.$$  | sort -rnk9,9  > ~/tmp/java_top_top_sorted.$$

top_pid_col=$(cat ~/tmp/java_top_top.$$ | grep PID | grep USER | grep '%CPU' | tr -s ' ' | tr ' ' '\n' | nl | tr -s ' ' | tr '\t' ' ' | cut -d' ' -f2,3 | grep -P "\s*PID$" | cut -f1 -d' ')
top_cpu_col=$(cat ~/tmp/java_top_top.$$ | grep PID | grep USER | grep '%CPU' | tr -s ' ' | tr ' ' '\n' | nl | tr -s ' ' | tr '\t' ' ' | cut -d' ' -f2,3 | grep " %CPU$" | cut -f1 -d' ')

topcols=$((echo $top_cpu_col) | sort -n | tr '\n' ',' | sed 's/,$//' | sed 's/^,//')

# 
#
# look by ps
#

  #
  # header
  #

  # linux ps part
  for header in $(ps aux -L | head -1 | tr -s ' ' | cut -d' ' -f$pscols); do
    sayatcell -n $header 7
  done
  
  # linux top part
  for header in $(cat ~/tmp/java_top_top.$$ | grep PID | grep USER | grep '%CPU' | head -1 | tr -s ' ' | cut -d' ' -f$topcols); do
    sayatcell -n $header 7
  done

  # jstack part
  sayatcell thread 10


  # data
  error=0
  for pid in $(cat ~/tmp/java_top_top_sorted.$$ | head -$top_threads | tr -s ' ' | cut -f$top_pid_col -d' ' ); do
    hexpid=$(printf '%x\n' $pid)

    # linux ps part
    for ps_data in $(echo $(cat ~/tmp/java_top_ps.$$ | grep -P "$java_owner\s+$java_pid\s+$pid") | cut -d' ' -f$pscols| tr '\n' ' '); do
        sayatcell -n $ps_data 7
    done

    # linux top part
    for top_data in $(echo $(cat ~/tmp/java_top_top.$$ | grep -P "^\s*$pid\s+") | cut -d' ' -f$topcols | tr '\n' ' '); do
        sayatcell -n $top_data 7
    done

    # java part
    if [ $jstack_mode = regular ]; then
        java_thread=$(cat ~/tmp/java_top_jstack.$$ | grep "nid=0x$hexpid")
    else
        java_thread=$(cat ~/tmp/java_top_jstack.$$ | grep "Thread $pid")
    fi
    if [ $? -ne 0 ]; then
      echo "Warning: thread $pid / 0x$hexpid NOT FOUND in Java thread dump. Possible in forced mode for JVM internal threads."
      error=101
    else
      if [ $jstack_mode = regular ]; then
          cat ~/tmp/java_top_jstack.$$ | grep -A$stack_lines "nid=0x$hexpid" | sed -n '1, /^$/p'
      else
          cat ~/tmp/java_top_jstack.$$ | grep -A$stack_lines "Thread $pid" | sed -n '1, /^$/p'
      fi
    fi
  done

}

#set -x
java_top $@
quit $error
