#!/bin/bash

#
# 
#

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

months=(none Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

tech_ULR="/console|/em|/servicebus|/OracleHTTPServer12c_files|/favicon.ico|/soa/composer"

#
#
#

function accesslog_report() {

    log_dir=$1

    dates=$(cd $log_dir; ls)

    say '================================================================'
    say '================================================================'
    say "                      Calls per day"
    say '================================================================'
    say " log directory: $log_dir"
    say '================================================================'
    say '================================================================'

    sayatcell -n -f "date" 15
    sayatcell -n -f "tech calls" 15
    sayatcell -n -f "security scans" 15
    sayatcell -n -f "service calls" 15

    for date in $dates; do
        
        day=$(echo $date | cut -d'-' -f3)
        month_no=$(echo $date | cut -d'-' -f2)
        month=${months[month_no]}
        year=$(echo $date | cut -d'-' -f1)

        #echo '================================================================'
        #echo "$date, $day/$month/$year: "
        #echo '================================================================' 
        say
        sayatcell -n -f $date 15

        tech_calls=$(cat $log_dir/$date/access_log* 2>/dev/null | grep "$day/$month/$year" | egrep "$tech_ULR" | cut -d' ' -f7-8  | wc -l)
        sayatcell -n -f $tech_calls 15

        scan_calls=$(cat $log_dir/$date/access_log* 2>/dev/null | grep "$day/$month/$year"| egrep -v "$tech_ULR" | egrep 404 | cut -d' ' -f7-8  | wc -l)
        sayatcell -n -f $scan_calls 15

        service_calls=$(cat $log_dir/$date/access_log* 2>/dev/null  | grep "$day/$month/$year" | egrep -v "$tech_ULR" | egrep -v 404 | cut -d' ' -f7-8  | wc -l)
        sayatcell -n -f $service_calls 15
    done

    say

    say Legend
    say " - tech calls     - all calls prefixed with any of: $tech_ULR"
    say " - security scans - all non tech calls ended with http 404 error code"
    say " - service calls  - all non tech calls, and non http 404 calls"

    say Done.
}

function servicecalls_report() {

    log_dir=$1

    dates=$(cd $log_dir; ls)

    say '================================================================'
    say '================================================================'
    say "                   Unique service calls per day"
    say '================================================================'
    say " log directory: $log_dir"
    say '================================================================'
    say '================================================================'

    for date in $dates; do
        
        day=$(echo $date | cut -d'-' -f3)
        month_no=$(echo $date | cut -d'-' -f2)
        month=${months[month_no]}
        year=$(echo $date | cut -d'-' -f1)

        say '================================================================'
        say "$date, $day/$month/$year: "
        say '================================================================' 


        uniqiue_svc_calls=$(cat $log_dir/$date/access_log* 2>/dev/null | grep "$day/$month/$year" | grep '/soa-infra/services' | cut -d' ' -f7-8  | cut -d' ' -f2 | cut -d'/' -f4-5 | sort -u)
        if [ -z "$uniqiue_svc_calls" ]; then
            say "(none)"
        else
            for service_call in $uniqiue_svc_calls; do
                cnt=$(cat $log_dir/$date/access_log* 2>/dev/null | grep "$day/$month/$year" | grep "/soa-infra/services/$service_call" | wc -l)
                say "$service_call: $cnt"
            done
        fi

    done

    say
    say Done.
}

cmd=$1; shift

case $cmd in
access)
    accesslog_report $1
    ;;
service)
    servicecalls_report $1
    ;;
both)
    accesslog_report $1
    servicecalls_report $1
    ;;
*)
    say "Usage: ohs_access_log_report.sh acess|servicce|both path"
    ;;
esac