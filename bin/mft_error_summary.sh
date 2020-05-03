#!/bin/bash

#
# helper functions
#

# split log into NUL-separated chunks
alias t0="sed 's:^\\(\\[[-+:.0-9T]\\+\\]\\):\\x0\\1:'"

# remove NUL characters
alias f0='tr -d \\0'

unset mft_error_document
function mft_error_document() {
    server_name=$1
    log_date=$2

    if [ -z "$log_date" ]; then
        log_date=$(date +%Y-%m-%d)
    fi

    #
    # analytical functions
    #
    error_dir=/u01/data/domains/prodmftc_domain/servers/$server_name/analysis/$log_date
    mkdir -p $error_dir
    mkdir -p $error_dir/log

    log_date_stop=$(date -d "$log_date +1day" +%Y-%m-%d)
    touch --date $log_date /tmp/start
    touch --date $log_date_stop /tmp/end
    find /u01/data/domains/prodmftc_domain/servers/$server_name/logs -type f -newer /tmp/start -not -newer /tmp/end |
        grep $server_name-mft-diagnostic |
        xargs -I{} cp "{}" $error_dir/log

    echo "--- get errored ecid"
    find $error_dir/log -type f -mtime -1 -printf "%T+\t%p\n" |
        sort | cut -f2 |
        xargs grep '\[ERROR\]' $1 |
        sed 's/$/\n\n\n/g' |
        perl -ne ' print "$7\n" if /(\S+):\[(\S+)\] (\S+) (\S+) (\S+) (\S+).*?ecid: (\S+) [\S ]*FlowId: ([\S^]+)* /' |
        cut -f1 -d',' |
        sort -u |
        cat >$error_dir/ecid.tmp
    cat $error_dir/ecid.tmp

    echo "--- get files with ecid"
    find $error_dir/log -type f -mtime -1 -printf "%T+\t%p\n" |
        sort | cut -f2 |
        xargs grep -f $error_dir/ecid.tmp $1 |
        cut -f1 -d: | sort -u >$error_dir/files.tmp
    cat $error_dir/files.tmp

    echo "--- get errors"
    for ecid in $(cat $error_dir/ecid.tmp); do

        echo "==================="
        echo "== $ecid =="
        echo "==================="

        cat $(cat $error_dir/files.tmp) | t0 | grep -z $ecid | grep -z '\[ERROR\]' | f0 | grep -v '^$' >$error_dir/$ecid.errors
    done

    echo "---- get file names"

    for ecid in $(cat $error_dir/ecid.tmp); do

        echo "==================="
        echo "== $ecid =="
        echo "==================="

        cat $(cat $error_dir/files.tmp) |
            t0 |
            grep -z $ecid |
            f0 |
            grep '^\[' |
            perl -ne 'm{(\S+).*?payloadReference=(\S+)} && print "$1 $2\n"' |
            sort -n >$error_dir/$ecid.files

    done

    # echo "--- get flows"
    # for ecid in $(cat $error_dir/ecid.tmp); do

    #     echo "==================="
    #     echo "== $ecid =="
    #     echo "==================="

    #     cat $(cat $error_dir/files.tmp) |
    #         t0 |
    #         grep -z $ecid |
    #         perl -0ne ' printf("%32s %-50s %-20s %-20s\n", $1, $2, $3, $4) if /^(\S+).*?SRC_CLASS: ([\w\.]+)\] \[SRC_METHOD: ([\w\.]+)\] ([\w\s:\.\/_\S]+)/' |
    #         f0 |
    #         grep -v '^$' >$error_dir/$ecid.flows

    # done

    # echo "--- get operations"
    # for ecid in $(cat $error_dir/ecid.tmp); do

    #     echo "==================="
    #     echo "== $ecid =="
    #     echo "==================="

    #     cat $(cat $error_dir/files.tmp) | t0 | grep -z $ecid |
    #         perl -0ne ' print "$1\t$2\t$3\t$5\n" if /^(\S+).*?SRC_CLASS: ([\w\.]+)\] \[SRC_METHOD: ([\w\.]+)\] ([\w\s:\.\/_]+)/' | cut -f1-999 -d':' |
    #         f0 | grep -v '^$' >$error_dir/$ecid.operations
    # done

}

function mft_error_summary() {
    server_name=$1
    log_date=$2

    if [ -z "$log_date" ]; then
        log_date=$(date +%Y-%m-%d)
    fi

    echo "======================================="
    echo "========= MFT Error summary ==========="
    echo "======================================="
    echo "== host: $(hostname)"
    echo "== user: $(whoami)"
    echo "== date: $(date)"
    echo "== log_date: $log_date"
    echo "======================================="
    echo "======================================="
    echo "======================================="

    error_dir=/u01/data/domains/prodmftc_domain/servers/$server_name/analysis/$log_date

    echo "---- prepare summary"

    for ecid in $(cat $error_dir/ecid.tmp | sort); do

        echo "File: $(head -1 $error_dir/$ecid.files | cut -d' ' -f2)"
        echo "   ecid:   $ecid"
        echo "   start:  $(head -1 $error_dir/$ecid.files | cut -d' ' -f1)"
        echo "   stop:   $(tail -1 $error_dir/$ecid.files | cut -d' ' -f1)"
        if [ -f $error_dir/$ecid.errors ]; then
            echo "   errors:    $(cat $error_dir/$ecid.errors | grep '\[ERROR\]' | wc -l)"
            echo "   error msg: $(cat $error_dir/$ecid.errors | perl -ne 'm{^(\S+).*?errorDesc=(\S+.*?),} && print "$2\n"' | sort -u)"
        else
            echo "   errors: 0"
        fi
        # echo "   ops:    $(cat $error_dir/$ecid.operations | wc -l)"
        echo
    done >$error_dir/log_summary.txt

    for ecid in $(cat $error_dir/ecid.tmp | sort -u); do

        if [ -f $error_dir/$ecid.errors ]; then
            echo "File: $(head -1 $error_dir/$ecid.files | cut -d' ' -f2)"
            echo "   ecid:   $ecid"
            echo "   start:  $(head -1 $error_dir/$ecid.files | cut -d' ' -f1)"
            echo "   stop:   $(tail -1 $error_dir/$ecid.files | cut -d' ' -f1)"
            echo "   errors: $(cat $error_dir/$ecid.errors | grep '\[ERROR\]' | wc -l)"
            echo
            cat $error_dir/$ecid.errors | perl -ne 'm{^(\S+).*?errorDesc=(\S+.*?),} && print "$2\n"' |
                sed 's/-[a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9]-//g' |
                sed 's/-[a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9]-//g' |
                sed 's/[a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9]//g' |
                sed 's/[a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9]//g' |
                sort -u
            echo
            # echo "   ops:    $(cat $error_dir/$ecid.operations | wc -l)"
            echo
        fi
    done >$error_dir/log_errors.txt

    echo "=================="
    echo "==== File error summary"
    echo "=================="
    cat $error_dir/log_summary.txt

    echo "=================="
    echo -n "==== Files processed with error:"
    cat $error_dir/*.files | cut -f2 -d' ' | sort -u | wc -l >$error_dir/log_filecount.txt
    cat $error_dir/log_filecount.txt
    echo "=================="

    echo "=================="
    echo "==== Error summary"
    echo "=================="
    errors=$(cat $error_dir/*.errors | perl -ne 'm{^(\S+).*?errorDesc=(\S+.*?),} && print "$2\n"' |
        sed 's/-[a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9]-//g' |
        sed 's/-[a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9]-//g' |
        sed 's/[a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9]//g' |
        sed 's/[a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9][a-fA-F0-9]//g' |
        sort -u)
    IFS=$'\n'
    for error in $errors; do
        echo "$(cat $error_dir/*.errors | grep "$error" | wc -l): $error"
    done
    unset IFS

    # echo "=================="
    # echo "==== Errors"
    # echo "=================="
    # cat $error_dir/log_errors.txt

}

#mft_error_document server_name 2020-04-24
#mft_error_summary  2020-04-24
