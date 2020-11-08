#!/bin/bash

source wls-tools/bin/discover_processes.sh 

# to stop per from complains about locale
export LC_CTYPE=en_US.UTF-8
export LC_ALL=en_US.UTF-8

discoverWLS
os_user=$(getWLSjvmAttr ${wls_managed[0]} os_user) 
: ${os_user:=$(getWLSjvmAttr ${wls_admin[0]} os_user)}

if [ -z "$os_user" ]; then
    echo "Error. Oracle middleware not detected."
    exit 1
else    
    if [ -f $1 ]; then

        script_to_run_path=$1
        script_to_run=/tmp/$$.$(basename $1)
        shift

        cp $script_to_run_path $script_to_run
        sudo su - $os_user $@
        rm $script_to_run
        exit 0
    else
        echo "Error. Script not found."
        exit 2
    fi
fi
