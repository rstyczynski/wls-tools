#!/bin/bash

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
      rm -f /tmp/ps.$$
      rm -f /tmp/jstack.$$
    else
      echo "Temp files left for analysis: /tmp/ps.$$, /tmp/jstack.$$"
    fi

    cat <<EOF_quit
$exit_msg
######################################
EOF_quit

    exit $1
}

trap quit SIGINT EXIT

function java_top() {

process_identifier=$1 
top_threads=$2
thread_lines=$3

: ${process_identifier:=java}
: ${top_threads:=5}
: ${thread_lines:=0}

cat <<EOF_intro
######################################
Java top v0.1 by Ryszard Styczynski
EOF_intro


java_pid=$(ps aux | grep $process_identifier | grep -v grep | grep -v java_top.sh | tr -s ' ' | cut -f2 -d' ')
if [ -z "$java_pid" ]; then
    quit 1 "Java process not found."
fi

if [ $(echo $java_pid | tr ' ' '\n' | wc -l) -gt 1 ]; then
    quit 2 "Multiple java processes found. Make identifier more precise"
fi

java_owner=$(ps aux | grep $process_identifier | grep -v grep | tr -s ' ' | cut -f1 -d' ')
java_home=$(dirname $(ps aux | grep $process_identifier | grep -v grep | tr -s ' ' | cut -f11 -d' '))

rm -f /tmp/jstack.$$
jstack_mode=regular
jstack_run=regular
timeout 1 sleep 5 #5 $java_home/jstack $java_pid > /tmp/jstack.$$ 2>/dev/null
result=$?
case $result in
126)
  jstack_run="sudo regular"
  sudo su - $java_owner -c "timeout 5 $java_home/jstack $java_pid" > /tmp/jstack.$$ 2>/dev/null
  if [ $? -ne 0 ]; then
    quit 3 "Not able to connect to JVM (sudo)."
  fi
  ;;
124)
  jstack_mode=forced
  jstack_run=forced
  timeout 15 $java_home/jstack -F $java_pid > /tmp/jstack.$$ 2>/dev/null
  resultF=$?
  case $resultF in
  126)
    jstack_run="sudo forced"
    sudo su - $java_owner -c "timeout 5 $java_home/jstack $java_pid" > /tmp/jstack.$$ 2>/dev/null
    if [ $? -ne 0 ]; then
      quit 3 "Not able to connect to JVM (sudo forced)."
    fi
    ;;
  124)
    quit 3 "Not able to connect to JVM (forced timeout)."
    ;;
  *)
    echo "Not handled jstack exit code: $result"
    ;;
  esac
  ;;
*)
  echo jstack exit code: $result
  ;;
esac

if [ $(cat /tmp/jstack.$$ | wc -l) -eq 0 ]; then
   rm -f /tmp/jstack.$$
fi

if [ ! -f /tmp/jstack.$$ ]; then
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
##### thread stack lines..:$thread_lines
EOF1a

cat <<EOF1b
###################
##### java_pid............:$java_pid
##### java_owner..........:$java_owner
##### java_home...........:$java_home
##### thread dump mode....:$jstack_mode
######################################

EOF1b

ps aux -L | grep -P  "$java_owner\s+$java_pid" | grep -v grep | sort -rnk4,4  > /tmp/ps.$$

#
# ps headers discovery
pid_col=$(ps aux -L | head -1 | tr -s ' ' | tr ' ' '\n' | nl | tr -s ' ' | tr '\t' ' ' | cut -d' ' -f2,3 | grep " PID$" | cut -f1 -d' ')
lwp_col=$(ps aux -L | head -1 | tr -s ' ' | tr ' ' '\n' | nl | tr -s ' ' | tr '\t' ' ' | cut -d' ' -f2,3 | grep " LWP$" | cut -f1 -d' ')
cpu_col=$(ps aux -L | head -1 | tr -s ' ' | tr ' ' '\n' | nl | tr -s ' ' | tr '\t' ' ' | cut -d' ' -f2,3 | grep " %CPU$" | cut -f1 -d' ')
mem_col=$(ps aux -L | head -1 | tr -s ' ' | tr ' ' '\n' | nl | tr -s ' ' | tr '\t' ' ' | cut -d' ' -f2,3 | grep " %MEM$" | cut -f1 -d' ')
pscols=$((echo $pid_col; echo $lwp_col; echo $cpu_col; echo $mem_col) | sort -n | tr '\n' ',' | sed 's/,$//')

# 
#
# look by ps
#

  for header in $(ps aux -L | head -1 | tr -s ' ' | cut -d' ' -f$pscols); do
    sayatcell -n $header 5
  done
  sayatcell thread 10


  for pid in $(cat /tmp/ps.$$ | head -$top_threads | tr -s ' ' | cut -f$lwp_col -d' ' ); do
    hexpid=$(printf '%x\n' $pid)

    # linux part
    for ps_data in $(echo $(cat /tmp/ps.$$ | grep -P "$java_owner\s+$java_pid\s+$pid") | cut -d' ' -f$pscols| tr '\n' ' '); do
        sayatcell -n $ps_data 5
    done

    # java part
    if [ $jstack_mode = regular ]; then
        java_thread=$(cat /tmp/jstack.$$ | grep "nid=0x$hexpid")
    else
        java_thread=$(cat /tmp/jstack.$$ | grep "Thread $pid")
    fi
    if [ $? -ne 0 ]; then
      quit 4 "Thread $pid / 0x$hexpid NOT FOUND in Java thread dump."
      
    else
      if [ $jstack_mode = regular ]; then
          cat /tmp/jstack.$$ | grep -A$thread_lines "nid=0x$hexpid" | sed -n '1, /^$/p'
      else
          cat /tmp/jstack.$$ | grep -A$thread_lines "Thread $pid" | sed -n '1, /^$/p'
      fi
    fi
  done

}

java_top $@
quit 0
