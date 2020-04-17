#!/bin/bash

function makePublicRead() {
    file_fullpath=$1

    while [ ! -f $file_fullpath ]; do
        echo "waiting for file..."
        sleep 1
    done

    chmod o+r $file_fullpath
    chmod g+r $file_fullpath
}

unset wls_jfr
function wls_jfr() {
    wls_server=$1
    shift
    operation=$1
    shift
    duration=$1
    shift
    opt=$1

    if [ -z "$wls_server" ]; then
        wls_server=soa_server1
    fi

    if [ -z "$operation" ]; then
        operation=start
    fi

    if [ -z "$duration" ]; then
        duration=1m
    fi

    echo "======================================="
    echo "============ WebLogic JFR  ============"
    echo "========== lazy admin tool ============"
    echo "======================================="
    echo "== host: $(hostname)"
    echo "== user: $(whoami)"
    echo "== date: $(date)"
    echo "======================================="
    echo "======================================="
    echo "======================================="

    mkdir -p /tmp/$$
    tmp=/tmp/$$

    mkdir -p ~/outbox/public
    chmod 755 ~/outbox/public

    export wls_server
    os_pid=$(ps aux | grep java | perl -ne 'BEGIN{$wls_server=$ENV{'wls_server'};} m{\w+\s+(\d+).+java -server.+-Dweblogic.Name=$wls_server} && print "$1 "')
    if [ -z "$os_pid" ]; then
        echo "No such server."
        return 1
    fi

    java_bin=$(dirname $(ps -o command ax -q $os_pid | grep -v 'COMMAND' | cut -f1 -d' '))
    $java_bin/jcmd $os_pid VM.unlock_commercial_features >/dev/null

    case $operation in
    start)
        $java_bin/jcmd $os_pid JFR.check >$tmp/jfr_check
        recNo=$(grep Recording: $tmp/jfr_check | cut -d: -f2 | cut -d= -f2 | cut -d' ' -f1 | head -1)
        if [ -z "$recNo" ]; then

            file_name=$(hostname)_$wls_server\_$(date -u +"%Y-%m-%dT%H%M%S.000Z").jfr
            $java_bin/jcmd $os_pid JFR.start duration=$duration filename=$HOME/outbox/public/$file_name compress=true
            if [ $? -eq 0 ]; then
                echo "Started $duration long recording. Output file will be written to $HOME/outbox/public/$file_name"

                echo

                host_ip=$(ip route get 8.8.8.8 | cut -d' ' -f7 | head -1)
                echo "Use scp to get recording: "
                echo 
                echo "scp -o \"ProxyJump \$user@\$jumpserver\" \$user@$host_ip:$HOME/outbox/public/$file_name ."
                echo 
                echo "Once collected open with Java Mission Control - jmc / jmc.exe"
                makePublicRead $HOME/outbox/public/$file_name

            else
                echo "Error starting recording."
            fi
        else
            echo "Recording already started: $(grep Recording: $tmp/jfr_check)"
        fi
        ;;
    stop)
        $java_bin/jcmd $os_pid JFR.check >$tmp/jfr_check
        recNo=$(grep Recording: $tmp/jfr_check | cut -d: -f2 | cut -d= -f2 | cut -d' ' -f1 | head -1)
        if [ ! -z "$recNo" ]; then
            file_name=$(hostname)_$wls_server\_$(date -u +"%Y-%m-%dT%H:%M:%S.000Z").jfr
            $java_bin/jcmd $os_pid JFR.stop recording=$recNo
            if [ $? -eq 0 ]; then
                echo "Recording stopped."
            else
                echo "Error stopping recording."
            fi
        else
            echo "No active recording."
        fi
        ;;
    check)
        $java_bin/jcmd $os_pid JFR.check
        ;;

    esac

    if [ ! "$opt" == debug ]; then
        rm -rf /tmp/$$
    fi
}

wls_jfr $@
