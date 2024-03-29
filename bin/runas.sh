#!/bin/bash

runas_os_user=$1; shift
script_to_run_path=$1

if [ -f "$script_to_run_path" ]; then

    script_to_run=/tmp/$$.$(basename $script_to_run_path)
    shift

    cp $script_to_run_path $script_to_run

    echo "Running as $runas_os_user: $script_to_run $@"
    sudo su - $runas_os_user $script_to_run "$@"
    result=$?
    rm $script_to_run
    exit $result
else
    invoke_cmd="$@"
    echo "Running as $runas_os_user: $invoke_cmd"
    echo "sudo su - $runas_os_user -c $invoke_cmd"
    sudo su - $runas_os_user -c "$invoke_cmd"
    result=$?
    exit $result
fi

