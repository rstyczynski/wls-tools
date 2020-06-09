#!/bin/bash

src_servers=$1
cfgmon_root=$2

function usage() {
    echo "Usage: cfgmon_fetch_scans.sh [init|src_servers] [cfgmon_root ]"
}

: ${cfgmon_root:=/home/pmaker/cfgmon}
[ -z "$src_servers" ] && echo "Error. $(usage)" && exit 1

if [ $src_servers == init ]; then

    echo "======================================="
    echo "============ Config Monitor ==========="
    echo "============= fetch scans ============="
    echo "======================================="
    echo "== host: $(hostname)"
    echo "== user: $(whoami)"
    echo "== date: $(date)"
    echo "======================================="
    echo "== cfgmon_root: $cfgmon_root"
    echo "== mode: init"
    echo "======================================="
    echo "======================================="

    #
    # prepare host
    #
    [ -z "$(git --version)" ] && sudo yum install -y git
    [ -z "$(git config user.email)" ] && git config --global user.email "$(hostname)"
    [ -z "$(git config user.name)" ] && git config --global user.name "$(hostname)"

    # preare cfg dump directory
    cfgmon_root=/home/pmaker/cfgmon
    git init $cfgmon_root

    # prepare http

    cat >~/cfgmon.tmp <<EOF
Alias /rtg/cfgmon $cfgmon_root
<Directory $cfgmon_root>
    Options +Indexes  
    #RH7 only
    Require all granted
    ForceType text/plain
</Directory>
EOF
    chmod 644 ~/cfgmon.tmp
    sudo mv ~/cfgmon.tmp /etc/httpd/conf.d/cfgmon.conf
    sudo chcon unconfined_u:object_r:httpd_config_t:s0 /etc/httpd/conf.d/cfgmon.conf

    permission=$(ls -la --context /var/www/html | head -1 | cut -d' ' -f4)
    chcon -R $permission $cfgmon_root
    chmod -R o+x $cfgmon_root

    sudo systemctl restart httpd
    curl http://10.106.6.57/rtg/cfgmon/
    sudo tail /var/log/httpd/error_log

    exit 0
fi

#
# fetch configs
#

echo "======================================="
echo "============ Config Monitor ==========="
echo "============= fetch scans ============="
echo "======================================="
echo "== host: $(hostname)"
echo "== user: $(whoami)"
echo "== date: $(date)"
echo "======================================="
echo "== cfgmon_root: $cfgmon_root"
echo "== mode: fetch"
echo "== src_servers: $src_servers"
echo "======================================="
echo "======================================="

if [ ! -d $cfgmon_root ]; then
    echo 'Scan env not initialized. Run the script with init argument first.'
    exit 1
fi

today=$(date -u +"%Y-%m-%d")

# server
for server in $src_servers; do
    cnt=0
    echo -n "Fetching $server"
    mkdir -p $cfgmon_root/$server
    echo -n '.'
    rsync -r $server:$cfgmon_root/* /$cfgmon_root/$server
    # remove data if fetched during cfg dump
    while [ -f $cfgmon_root/$server/lock ]; do
        echo -n '.'
        rm -rf $cfgmon_root/$server/lock

        cnt=$(($cnt + 1))
        if [ $cnt -gt 10 ]; then
            break
        fi

        rsync -r $server:$cfgmon_root/* $cfgmon_root/$server
        sleep 1
    done
    
    if [ $cnt -gt 10 ]; then
        echo Timeout
    else
        chmod -R o+x $cfgmon_root/$server
        chmod -R o+r $cfgmon_root/$server
        echo Done
    fi
done

#
# finalize
#

# add to version control
cd $cfgmon_root
git add --all >/dev/null 2>&1
git commit -am "system fetch" >/dev/null 2>&1
cd - >/dev/null
