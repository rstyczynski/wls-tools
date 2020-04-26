

function _threadGetOwner() {
    root_class=$1

    cat /tmp/tdump | grep -B1 "$root_class" | grep -v "$root_class" | sort -u | grep -v '\--' | tr -d '\t' | cut -f2 -d' '
}

function wls_top() {
    java_pid=$1 #13657

    java_bin=$(dirname $(ps -o command ax -q $java_pid | grep -v 'COMMAND' | cut -f1 -d' '))
    $java_bin/jstack $java_pid | grep -A30 RUNNABLE >/tmp/tdump

    rm -f /tmp/modules

    _threadGetOwner 'java.lang.Thread.run' >> /tmp/modules
    _threadGetOwner 'weblogic.kernel.ExecuteThread.execute' >> /tmp/modules
    _threadGetOwner 'weblogic.server.channels.ServerListenThread.selectFrom' >> /tmp/modules
    _threadGetOwner 'weblogic.nodemanager.NMService$[0-9]+.run' >> /tmp/modules
    _threadGetOwner 'oracle.integration.platform.blocks.executor.WorkManagerExecutor$[0-9][0-9]*.run' >> /tmp/modules

    IFS=$'\n'
    for module in $(cat /tmp/modules | sort -u); do
        echo -n "$(echo "$module" | cut -f1 -d'('): "
        cat /tmp/tdump | grep "$module" | wc -l
    done | sort -k2 -t':' -r -n
    unset IFS

}


function wlsLogSummary {
script_id=wlsLogSummary

server_name=$1

domain_dir=$DOMAIN_HOME
if [ -z "$domain_dir" ]; then
  domain_dir=$2
fi

if [ -z $server_name ] || [ -z $domain_dir ]; then
  echo "Usage: wlsLogSummary server_name domain_dir [start_date] [stop_date]"
  echo 
  echo "Dates are in format 2019-01-01. If not provided today is used."
  return 1
fi

if [ -z "$REPORT_WIDTH" ]; then
   REPORT_WIDTH=140
fi


date_start=$3
if [ -z $date_start ]; then
  date_start=$(date +%Y-%m-%d)
fi

date_stop=$4
if [ -z $date_stop ]; then
  date_stop=$(date +%Y-%m-%d)
fi

server_logs=$domain_dir/servers/$server_name/logs

if [ ! -d $server_logs ]; then
	echo Error. Directory does not exist. Info: $server_logs
	return 1
fi

echo 
echo "==================================="
echo "======= WebLogic Log summary ======"
echo "==================================="
echo "=== Host:       $(hostname)"
echo "=== Reporter:   $(whoami)"
echo "=== Date:       $(date)"
echo "==="
echo "=== Server:     $server_name"
echo "=== Domain:     $domain_dir"
echo "=== Logs:       $server_logs"
echo "==="
echo "=== Start date: $date_start"
echo "=== Stop date:  $date_stop"
echo "==================================="


tmp=/tmp/$script_id\_$$
mkdir -p $tmp

start_line=$(ls -ltr --color=auto --time-style=long-iso $server_logs/$server_name.out* | grep "$date_start" | head -1 | tr -s ' ' | cut -d' ' -f6,7)
if [ -z "$start_line" ]; then
  start_line=$(ls -ltr --color=auto --time-style=long-iso $server_logs/$server_name.out* | head -1 | tr -s ' ' | cut -d' ' -f6,7)
fi

stop_line=$(ls -ltr --color=auto --time-style=long-iso $server_logs/$server_name.out* | grep "$date_stop" | tail -1 | head -1 | tr -s ' ' | cut -d' ' -f6,7)
if [ -z "$stop_line" ]; then
  stop_line=$(ls -ltr --color=auto --time-style=long-iso $server_logs/$server_name.out* | tail -1 | head -1 | tr -s ' ' | cut -d' ' -f6,7)
fi

echo "=== Start datetimestmp: $start_line"
echo "=== Stop datetimestmp:  $stop_line"
echo "==================================="

ls -ltr --color=auto --time-style=long-iso $server_logs/$server_name.out* | \
tr -s ' ' | \
cut -d' ' -f6,7,8 | \
sed -n "/$start_line/,/$stop_line/p" | \
cut -d' ' -f3  >$tmp/files

echo 
echo "==================================="
echo "============= Files =============== "
echo "==================================="
ls -lh $(cat $tmp/files)


echo 
echo "==================================="
echo "========== Error summary ========== "
echo "==================================="

grep '<Error>' $(cat $tmp/files) | \
cut -d'<' -f4 | \
cut -d'>' -f1 | \
sort | uniq -c | \
sort -n -r  >$tmp/modules_cnt

cat $tmp/modules_cnt  | \
tr -s ' '  | \
cut -d' ' -f3 >$tmp/modules

cat $tmp/modules_cnt

echo 
echo "==================================="
echo "========== Top 10 errors ========== "
echo "==================================="

for module in $(cat $tmp/modules | head -10 ); do
   echo 
   echo "==========================================================="
   echo "==== $module - top 20 occurances"
   echo "==========================================================="
   grep '<Error>' $(cat $tmp/files) | \
   grep "<$module>" | \
   cut -d'<' -f6 | \
   cut -b1-$REPORT_WIDTH | \
   # replace identifiers to masks
   # sed 's/[0-9]\{2\}\+/99/g' | \
   sort | uniq -c | sort -nr | head -20
done

rm /tmp/$script_id\_$$/*
rmdir /tmp/$script_id\_$$
}
