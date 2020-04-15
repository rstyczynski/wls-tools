#!/bin/bash

function _threadGetOwner() {
    root_class=$1

    cat $tmp/tdump | grep -B1 "$root_class" | grep -v "$root_class" | sort -u | grep -v '\--' | tr -d '\t' | cut -f2 -d' '
}


# split stack into NUL-separated chunks
function t0() {
    sed s:^$:\\x0:
}

# remove NUL characters
function f0() {
    tr -d \\0
}


function wls_top() {
    wls_server=$1; shift 
    opt=$1

    mkdir -p /tmp/$$
    tmp=/tmp/$$

    export wls_server
    os_pid=$(ps aux | grep java | perl -ne 'BEGIN{$wls_server=$ENV{'wls_server'};} m{\w+\s+(\d+).+java -server.+-Dweblogic.Name=$wls_server} && print "$1 "')

    java_bin=$(dirname $(ps -o command ax -q $os_pid | grep -v 'COMMAND' | cut -f1 -d' '))
    $java_bin/jstack $os_pid | t0 | grep -z RUNNABLE | f0 >$tmp/tdump

    rm -f $tmp/modules

    _threadGetOwner 'java.lang.Thread.run' >> $tmp/modules
    _threadGetOwner 'weblogic.kernel.ExecuteThread.execute' >> $tmp/modules
    _threadGetOwner 'weblogic.server.channels.ServerListenThread.selectFrom' >> $tmp/modules
    _threadGetOwner 'weblogic.nodemanager.NMService$[0-9]+.run' >> $tmp/modules
    _threadGetOwner 'oracle.integration.platform.blocks.executor.WorkManagerExecutor$[0-9][0-9]*.run' >> $tmp/modules

    IFS=$'\n'
    for module in $(cat $tmp/modules | sort -u); do
        echo -n "$module: "
        cat $tmp/tdump | grep "$module" | cut -f1 -d'(' | wc -l
    done | sort -k3 -t':' -r -n
    unset IFS

    if [ ! "$opt" == debug ]; then
        rm -rf /tmp/$$
    fi
}

wls_top $@

