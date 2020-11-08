#!/bin/bash

source wls-tools/bin/discover_processes.sh 
discoverWLS
os_user=$(getWLSjvmAttr ${wls_managed[0]} os_user) 
: ${os_user:=$(getWLSjvmAttr ${wls_admin[0]} os_user)}

if [ -z "$os_user" ]; then
    echo "Error. Oracle middleware not detected."
    exit 1
else    
    sudo su - $os_user $@
    exit 0
fi
