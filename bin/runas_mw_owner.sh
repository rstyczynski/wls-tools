#!/bin/bash

source ~/oci-tools/bin/config.sh
export mw_os_user=$(getcfg x-ray mw_os_user)
if [ -z "$mw_os_user" ]; then
    # to stop per from complains about locale
    export LC_CTYPE=en_US.UTF-8
    export LC_ALL=en_US.UTF-8

    source ~/wls-tools/bin/discover_processes.sh
    discoverWLS
    mw_os_user=$(getWLSjvmAttr ${wls_managed[0]} os_user)
    # admin only?
    : ${mw_os_user:=$(getWLSjvmAttr ${wls_admin[0]} os_user)}
    # ohs only?
    : ${mw_os_user:=$(ps aux | grep weblogic.nodemanager | grep -v grep | cut -f1 -d' ' | sort -u)}

    setcfg x-ray mw_os_user $mw_os_user force
fi

export mw_os_user=$(getcfg x-ray mw_os_user)
if [ -z "$mw_os_user" ]; then
    echo "Error. Oracle middleware not detected."
    exit 1
else
    if [ -f "$1" ]; then

        script_to_run_path=$1
        script_to_run=/tmp/$$.$(basename $1)
        shift

        cp $script_to_run_path $script_to_run

        echo "Running as $mw_os_user: $script_to_run $@"
        sudo su - $mw_os_user $script_to_run $@
        rm $script_to_run
        exit 0
    else
        echo "Running as $mw_os_user: $@"
        echo "sudo su - $mw_os_user -c $@"
        sudo su - $mw_os_user -c "$@"
        exit 0
    fi
fi
