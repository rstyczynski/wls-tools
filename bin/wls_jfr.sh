#!/bin/bash

function usage() {
    echo "Usage: wls_jfr.sh server_name operation [duration] [dump_location dir]
    
, where:
- operation: start, stop, check; default start
- duration: time given as e.g. 30s, 1m, 1h; default 5m
- dump_location: directoruy to store jfr files. 15 minutes takes approx. 3MB; default ~/outbox/public
"
}

unset jcmd_error_handler
function jcmd_error_handler() {

        echo "Error conecting to JVM. JFR interaction not possible. Writing thread dump instead."

        file_name=$(hostname)_$wls_server\_$(date -u +"%Y-%m-%dT%H%M%S.000Z").jtop
        $wls_tools_bin/java_top.sh $wls_server > $dump_location/$file_name

        echo "JVM thread dump written to $dump_location/$file_name."
}

unset wls_jfr
function wls_jfr() {
    wls_server=$1; shift
    if [ -z "$wls_server" ]; then
        usage
        exit 1
    fi

    case $1 in
    start|stop|check) 
        operation=$1; shift
        ;;
    *)
        usage
        exit 1
        ;;
    esac

    reg_int='^[0-9]+[smh]*$'
    if [[ $1 =~ $reg_int ]] ; then
        duration=$1; shift
    fi

    if [[ $1 == 'dump_location' ]] ; then
        dump_location=$2; shift; shift
    fi

    if [[ $1 == 'debug' ]] ; then
        debug=yes; shift
    fi

    : ${wls_server:=soa_server1}
    : ${operation:=start}
    : ${duration:=5m}
    : ${dump_location:="$HOME/outbox/public"}
    : ${debug:=no}

    echo "======================================="
    echo "============ WebLogic JFR  ============"
    echo "========== lazy admin tool ============"
    echo "======================================="
    echo "== host: $(hostname)"
    echo "== user: $(whoami)"
    echo "== date: $(date)"
    echo "======================================="
    echo "== wls_server:    $wls_server"
    echo "== operation:     $operation"
    echo "== duration:      $duration"
    echo "== dump_location: $dump_location"
    echo "======================================="
    echo "======================================="
    echo "======================================="

    mkdir -p /tmp/$$
    tmp=/tmp/$$

    wls_tools_bin=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

    mkdir -p $dump_location 
    if [ $dump_location == "$HOME/outbox/public" ]; then
        chmod 755 $HOME/outbox/public
    fi

    export wls_server
    os_pid=$(ps aux | grep java | perl -ne 'BEGIN{$wls_server=$ENV{'wls_server'};} m{\w+\s+(\d+).+java -server.+-Dweblogic.Name=$wls_server} && print "$1 "')
    if [ -z "$os_pid" ]; then
        echo "No such server."
        return 1
    fi

    java_bin=$(dirname $(ps -o command ax -q $os_pid | grep -v 'COMMAND' | cut -f1 -d' '))
    timeout 10 $java_bin/jcmd $os_pid VM.unlock_commercial_features >/dev/null
    if [ $? -ne 0 ]; then
        jcmd_error_handler
    else

        case $operation in
        start)
            timeout 10 $java_bin/jcmd $os_pid JFR.check >$tmp/jfr_check
            if [ $? -ne 0 ]; then
                jcmd_error_handler
            else
                recNo=$(grep Recording: $tmp/jfr_check | grep wls-tools_JFR | cut -d: -f2 | cut -d= -f2 | cut -d' ' -f1 | head -1)
                if [ -z "$recNo" ]; then

                    file_name=$(hostname)_$wls_server\_$(date -u +"%Y-%m-%dT%H%M%S.000Z").jfr
                    timeout 10 $java_bin/jcmd $os_pid JFR.start name=wls-tools_JFR duration=$duration filename=$dump_location/$file_name compress=true
                    if [ $? -eq 0 ]; then
                        echo "Started $duration long recording. Output file will be written to $dump_location/$file_name"

                        echo

                        host_ip=$(hostname -i)
                        echo "Use scp to get recording: "
                        echo 
                        echo "scp -o \"ProxyJump \$user@\$jumpserver\" \$user@$host_ip:$dump_location/$file_name ."
                        echo 
                        echo "Once collected open with Java Mission Control - jmc / jmc.exe"
                        
                        # wait for file and make readable for all
                        while [ ! -f $dump_location/$file_name ]; do
                            echo "waiting for file..."
                            sleep 1
                        done

                        chmod o+r $dump_location/$file_name 
                        chmod g+r $dump_location/$file_name 
                    else
                        echo "Error starting recording. Writing thread dump instead."
                        jcmd_error_handler
                    fi
                else
                    echo "Recording already started: $(grep Recording: $tmp/jfr_check)"
                fi
            fi
            ;;
        stop)
            timeout 10 $java_bin/jcmd $os_pid JFR.check >$tmp/jfr_check
            if [ $? -ne 0 ]; then
                jcmd_error_handler
            else
                recNo=$(grep Recording: $tmp/jfr_check | cut -d: -f2 | cut -d= -f2 | cut -d' ' -f1 | head -1)
                if [ ! -z "$recNo" ]; then
                    file_name=$(hostname)_$wls_server\_$(date -u +"%Y-%m-%dT%H:%M:%S.000Z").jfr
                    timeout 10 $java_bin/jcmd $os_pid JFR.stop recording=$recNo
                    if [ $? -eq 0 ]; then
                        echo "Recording stopped."
                    else
                        echo "Error stopping recording. Writing thread dump instead."
                        jcmd_error_handler
                    fi
                else
                    echo "No active recording."
                fi
            fi
            ;;
        check)
            timeout 10 $java_bin/jcmd $os_pid JFR.check
            if [ $? -ne 0 ]; then
                jcmd_error_handler
            fi
            ;;
        esac
    fi

    # todo
    if [ ! "$opt" == debug ]; then
        rm -rf /tmp/$$
    fi
}

wls_jfr $@
