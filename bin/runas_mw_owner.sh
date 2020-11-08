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
        cp $1 /tmp/$$.$1
        sudo su - $os_user $@
        rm /tmp/$$.$1
        exit 0
    else
        echo "Error. Script not found."
        exit 2
    fi
fi
