#!/bin/bash

tool_name="x-ray_access_log"
tool_author=ryszard.styczynski@oracle.com
tool_version=0.1



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

    what="$1"; shift
    size=$1; shift

    back='____________________________________________________________________________________________________________'
    back='                                                                                                            '
    dots='............................................................................................................'

    what_lth=$(echo -n "$what" | wc -c)

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


function check_work_distribution() {
env=$1
date_txt=$2

if [ -z "$env" ]; then
  echo "Usage: check_work_distribution env [date]"
  return 1
fi

: ${date_txt:=$(date +"%Y-%m-%d")}

months=(none Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

cd /mwlogs/x-ray/$(echo $env | tr [A-Z] [a-z])/soa/diag/wls/log/soa_domain

date_y=$(echo $date_txt | cut -b1-4)
date_m=$(echo $date_txt | cut -b6-7)
date_m_int=$(echo $date_m | tr -d 0)
date_d=$(echo $date_txt | cut -b9-10)

date_txt_ohs=$date_d/${months[$date_m_int]}/$date_y


cat <<EOF
### 
### Work distribution at $env 
###
EOF

sayatcell -n date 10
sayatcell -n hour 10
sayatcell -n OHS 10
sayatcell -n SOA 10
sayatcell  OSB 10

    #ohs_tz=$(grep -P "$date_txt_ohs:$hour:" ./ohs*/$date_txt/access*  | cut -f5 -d" " | tr -d '[+\]]' | cut -b1-2 | uniq | tr -d '0')
      ohs_tz=0

  for hour in {0..23}; do
    ohs_hour=$(( $hour - $ohs_tz ))

    if [ $hour -lt 10 ]; then
       hour=0$hour
    fi

    if [ $ohs_hour -lt 10 ]; then
       ohs_hour=0$ohs_hour
    fi
    

    sayatcell -n "$date_txt" 10
    sayatcell -n "$hour" 6
    sayatcell -n "$(grep -P "$date_txt_ohs:$ohs_hour:" ./ohs*/$date_txt/access* | wc -l)" 10
    sayatcell -n "$(grep -P "$date_txt\s+$hour:" ./soa*/$date_txt/access* | wc -l)" 10
    sayatcell "$(grep -P "$date_txt\s+$hour:" ./osb*/$date_txt/access*  | wc -l)" 10
   

done

}


function check_call_distribution() {
env=$1
service=$2
date_txt=$3

if [ -z "$env" ] || [ -z "$service" ]; then
  echo "Usage: check_call_distribution env service [date]"
  return 1
fi

: ${date_txt:=$(date +"%Y-%m-%d")}

months=(none Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

cd /mwlogs/x-ray/$(echo $env | tr [A-Z] [a-z])/soa/diag/wls/log/soa_domain

date_y=$(echo $date_txt | cut -b1-4)
date_m=$(echo $date_txt | cut -b6-7)
date_m_int=$(echo $date_m | tr -d 0)
date_d=$(echo $date_txt | cut -b9-10)

date_txt_ohs=$date_d/${months[$date_m_int]}/$date_y


cat <<EOF
### 
### Work distribution
### $service at $env 
###
EOF

sayatcell -n date 10
sayatcell -n hour 10
sayatcell -n OHS 10
sayatcell -n SOA 10
sayatcell  OSB 10

  #ohs_tz=$(grep -P "$date_txt_ohs:$hour:" ./ohs*/$date_txt/access*  | cut -f5 -d" " | tr -d '[+\]]' | cut -b1-2 | uniq | tr -d '0')
  ohs_tz=0

  for hour in {0..23}; do
        ohs_hour=$(( $hour - $ohs_tz ))

    if [ $hour -lt 10 ]; then
       hour=0$hour
    fi

    if [ $ohs_hour -lt 10 ]; then
       ohs_hour=0$ohs_hour
    fi

    sayatcell -n "$date_txt" 10
    sayatcell -n "$hour" 6
    sayatcell -n "$(grep -P "$date_txt_ohs:$ohs_hour:" ./ohs*/$date_txt/access*  | grep $service | wc -l)" 10
    sayatcell -n "$(grep -P "$date_txt\s+$hour:" ./soa*/$date_txt/access* | grep $service | wc -l)" 10
    sayatcell "$(grep -P "$date_txt\s+$hour:" ./osb*/$date_txt/access* | grep $service | wc -l) " 10 
   
done

}

function get_top_services() {
env=$1
date_txt=$2
hour=$3
topn=$4

if [ -z "$env" ] || [ -z "$date_txt" ]; then
  echo "Usage: get_top_services env date [hour] [top N]"
  return 1
fi

: ${topn:=5}

cat <<EOF
### 
### top used serices
### $service at $env 
###
EOF

months=(none Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

cd /mwlogs/x-ray/$(echo $env | tr [A-Z] [a-z])/soa/diag/wls/log/soa_domain

date_y=$(echo $date_txt | cut -b1-4)
date_m=$(echo $date_txt | cut -b6-7)
date_m_int=$(echo $date_m | tr -d 0)
date_d=$(echo $date_txt | cut -b9-10)

date_txt_ohs=$date_d/${months[$date_m_int]}/$date_y



  #ohs_tz=$(grep -P "$date_txt_ohs:$hour:" ./ohs*/$date_txt/access*  | cut -f5 -d" " | tr -d '[+\]]' | cut -b1-2 | uniq | tr -d '0')
  ohs_tz=0

  if [ -z "$hour" ]; then

    sayatcell -n date 10
    sayatcell -n hour 10
    sayatcell -n OHS 10
    sayatcell -n SOA 10
    sayatcell  OSB 10

    for hour in {0..23}; do
      ohs_hour=$(( $hour - $ohs_tz ))
      
      if [ $hour -lt 10 ]; then
        hour=0$hour
      fi

      if [ $ohs_hour -lt 10 ]; then
        ohs_hour=0$ohs_hour
      fi

      # sayatcell -n "$date_txt" 10
      # sayatcell -n "$hour" 6
      # sayatcell -n "$(grep -P "$date_txt_ohs:$ohs_hour:" ./ohs*/$date_txt/access* | tr '?' '\t' | cut -f8 -d' '  | sort | uniq -c | sort -nr | head -$topn | tr ' ' '_'| tr '\n' '_')" 50
      # sayatcell -n "$(grep -P "$date_txt\s+$hour:" ./soa*/$date_txt/access* | tr '?' '\t' | cut -f6 | sort | uniq -c | sort -nr | head -$topn  | tr ' ' '_'| tr '\n' '_')" 50
      # sayatcell "$(grep -P "$date_txt\s+$hour:" ./osb*/$date_txt/access* | tr '?' '\t' | cut -f11 | sort | uniq -c | sort -nr | head -$topn | tr ' ' '_'| tr '\n' '_')" 50

      echo "$date_txt $hour:00:00 - $hour:59:59"
      echo OHS:
      grep -P "$date_txt_ohs:$ohs_hour:" ./ohs*/$date_txt/access* | tr '?' '\t' | cut -f8 -d' '  | sort | uniq -c | sort -nr | head -$topn
      echo SOA:
      grep -P "$date_txt\s+$hour:" ./soa*/$date_txt/access* | tr '?' '\t' | cut -f6 | sort | uniq -c | sort -nr | head -$topn
      echo OSB:
      grep -P "$date_txt\s+$hour:" ./osb*/$date_txt/access* | tr '?' '\t' | cut -f11 | sort | uniq -c | sort -nr | head -$topn

    done
  else
      ohs_hour=$(( $hour - $ohs_tz ))
      
      if [ $hour -lt 10 ]; then
        hour=0$hour
      fi

      if [ $ohs_hour -lt 10 ]; then
        ohs_hour=0$ohs_hour
      fi
      echo "$date_txt $hour:00:00 - $hour:59:59"
      echo OHS:
      grep -P "$date_txt_ohs:$ohs_hour:" ./ohs*/$date_txt/access* | tr '?' '\t' | cut -f8 -d' '  | sort | uniq -c | sort -nr | head -$topn
      echo SOA:
      grep -P "$date_txt\s+$hour:" ./soa*/$date_txt/access* | tr '?' '\t' | cut -f6 | sort | uniq -c | sort -nr | head -$topn
      echo OSB:
      grep -P "$date_txt\s+$hour:" ./osb*/$date_txt/access* | tr '?' '\t' | cut -f11 | sort | uniq -c | sort -nr | head -$topn

  fi

}


function get_response_time() {
env=$1
date=$2
time=$3
date_time="$date $time"

if [ -z "$env" ]; then
  echo "Usage: get_response_time env [date] [time]"
  return 1
fi

if [ -z "$date_time" ]; then
  time_epoch=$(date +%s)
else
  time_epoch=$(date -d "$date_time" +"%s")
fi

date_slot=$(date -d@$time_epoch +"%Y-%m-%d")
time_slot=$(date -d@$time_epoch  +"%H:%M" | cut -b1-4) 
time_slot="$time_slot\d"

cat <<EOF
### 
### time used by serices
### $date_slot $time_slot
###
EOF

months=(none Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

cd /mwlogs/x-ray/$(echo $env | tr [A-Z] [a-z])/soa/diag/wls/log/soa_domain


date_txt=$date_slot

months=(none Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

cd /mwlogs/x-ray/$(echo $env | tr [A-Z] [a-z])/soa/diag/wls/log/soa_domain

date_y=$(echo $date_txt | cut -b1-4)
date_m=$(echo $date_txt | cut -b6-7)
date_m_int=$(echo $date_m | tr -d 0)
date_d=$(echo $date_txt | cut -b9-10)

date_txt_ohs=$date_d/${months[$date_m_int]}/$date_y

# no xecution time in ohs log!
#grep -P "$date_txt_ohs:$time_slot:" ./ohs*/$date_txt/access*

echo OHS
echo "(no data in access log)"

echo SOA
echo "(no data in access log)"

echo OSB

services=$(grep -P "$date_txt\s+$time_slot:" ./osb*/$date_txt/access* | tr '?' '\t' | cut -f11 | sort | uniq )

  sayatcell -n -f service 60
  sayatcell -n -f "min" 10
  sayatcell -n -f "max" 10
  sayatcell -n -f "avg" 10
  sayatcell -n -f "stdev" 10
  sayatcell -n -f warning 30
  sayatcell -f alert  30

  sayatcell -n -f " " 60
  sayatcell -n -f "[ms]" 10
  sayatcell -n -f "[ms]" 10
  sayatcell -n -f "[ms]" 10
  sayatcell -n -f "[ms]" 10
  sayatcell -n -f " " 30
  sayatcell -f " "  30

  sayatcell -n -f '-----------' 60
  sayatcell -n -f '------' 10
  sayatcell -n -f '------' 10
  sayatcell -n -f '------' 10
  sayatcell -n -f '------' 10
  sayatcell -n -f '-----------' 30
  sayatcell -f '-----------' 30

for service in $services; do
  invocations=$(grep -P "$date_txt\s+$time_slot:" ./osb*/$date_txt/access* | grep "$service" | tr '?' '\t' | cut -f11 | uniq -c)
  timings=$(grep -P "$date_txt\s+$time_slot:" ./osb*/$date_txt/access* | grep "$service" | tr '?' '\t' | cut -f7)
  avg=$(echo $timings | tr ' ' '\n' | awk '{ total += $1 } END { printf "%d", total/NR*1000 }')
  stdev=$(echo $timings | tr ' ' '\n'  | awk '{for(i=1;i<=NF;i++) {sum[i] += $i; sumsq[i] += ($i)^2}} 
          END {for (i=1;i<=NF;i++) { printf "%d", sqrt((sumsq[i]-sum[i]^2/NR)/NR)*1000} }')
  min=$(echo $timings | tr ' ' '\n' | awk 'BEGIN {min=1000} {if ($1<0+min) min=$1} END {printf "%d", min *1000}')
  max=$(echo $timings | tr ' ' '\n' | awk 'BEGIN {max=0} {if ($1>0+max) max=$1} END {printf "%d", max*1000}')



  sayatcell -n -f "$service                                               " 60
  sayatcell -n -f $min 10
  sayatcell -n -f $max 10
  sayatcell -n -f $avg 10
  sayatcell -n -f $stdev 10

  warning=''
  alert=''
  if [ $max -gt 30000 ]; then
      warning="max > 30 seconds"
  fi
  
  if [ $stdev -gt $avg ]; then
      alert="stdev > avg"
  fi

  if [ $avg -gt 30000 ]; then
      alert="avg > 30 seconds"
  fi

  sayatcell -n -f "$warning" 30
  sayatcell -f "$alert" 30

done

}

