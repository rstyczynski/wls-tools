#!/bin/bash

src_servers=$1
cfgmon_root=$2
nfs_root=$3

function usage() {
    echo "Usage: cfgmon_fetch_scans.sh [init|none|src_servers] [cfgmon_root] [nfs_root]"
}

: ${cfgmon_root:=/home/pmaker/cfgmon}
[ -z "$src_servers" ] && echo "Error. $(usage)" && exit 1

if [ "$src_servers" == init ]; then

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

    mkdir -p $cfgmon_root/servers
    mkdir -p $cfgmon_root/reports

    git init $cfgmon_root

    # prepare http

    cat >~/cfgmon.tmp <<EOF
AllowOverride ALL

Alias /cfgmon $cfgmon_root

<Directory $cfgmon_root>
    Options +Indexes  
    #RH7 only
    Require all granted
</Directory>

<Directory $cfgmon_root/servers>
    Options +Indexes  
    #RH7 only
    Require all granted
    ForceType text/plain
</Directory>

<Directory $cfgmon_root/reports>
    Options +Indexes  
    #RH7 only
    Require all granted
</Directory>
EOF
    chmod 644 ~/cfgmon.tmp
    sudo mv ~/cfgmon.tmp /etc/httpd/conf.d/cfgmon.conf
    sudo chcon unconfined_u:object_r:httpd_config_t:s0 /etc/httpd/conf.d/cfgmon.conf

    echo 'IndexOptions NameWidth=*' > $cfgmon_root/servers/.htaccess
    sudo chcon unconfined_u:object_r:httpd_config_t:s0 $cfgmon_root/servers/.htaccess

    echo 'IndexOptions NameWidth=*' > $cfgmon_root/reports/.htaccess
    sudo chcon unconfined_u:object_r:httpd_config_t:s0 $cfgmon_root/servers/.htaccess

    permission=$(ls -la --context /var/www/html | head -1 | cut -d' ' -f4)
    chcon -R $permission $cfgmon_root/servers
    chcon -R $permission $cfgmon_root/reports
    chcon -R $permission $cfgmon_root

    chmod -R o+x $cfgmon_root/servers
    chmod -R o+x $cfgmon_root/reports
    chmod -R o+x $cfgmon_root

    sudo systemctl restart httpd
    curl http://localhost/cfgmon/
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
echo "== mode       : fetch"
echo "== src_servers: $src_servers"
echo "== nfs_root   : $nfs_root"
echo "======================================="
echo "======================================="

if [ ! -d $cfgmon_root ]; then
    echo 'Fetch scan utility not initialized. Run the script with init argument first.'
    exit 1
fi

today=$(date -u +"%Y-%m-%d")

wlsdoc_bin="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source /home/pmaker/wls-tools/bin/document_host.sh

if [ "$src_servers" != none ]; then
    # server
    for server in $src_servers; do
        cnt=0
        
        echo -n ">> Removing current folder: $cfgmon_root/servers/$server/current"
        rm -rf $cfgmon_root/servers/$server/current/*
        rm -rf $cfgmon_root/servers/$server/current

        echo -n ">> Fetching $server"
        mkdir -p $cfgmon_root/servers/$server
        echo -n '.'
        rsync -ra $server:$cfgmon_root/* $cfgmon_root/servers/$server
        # remove data if fetched during cfg dump
        while [ -f $cfgmon_root/servers/$server/lock ]; do
            echo -n '.'
            rm -rf $cfgmon_root/servers/$server/lock

            cnt=$(($cnt + 1))
            if [ $cnt -gt 10 ]; then
                break
            fi
            rsync -ra $server:$cfgmon_root/* $cfgmon_root/servers/$server
            sleep 1
        done
        
        if [ $cnt -gt 10 ]; then
            echo Timeout.
        else
            echo Done.
        fi

        if [ -f $cfgmon_root/servers/$server/current/wls/context/status/discoverDomain.error ]; then
            echo ">> Recovering domain scan." 
            recover_discoverDomain_error $server
        fi

        # fix permissions
        chmod -R o+x $cfgmon_root/servers/$server
        chmod -R o+r $cfgmon_root/servers/$server
    done
fi

if [ ! -z "$nfs_root" ]; then

    rsync -ra $nfs_root/* $cfgmon_root/servers
    
fi

#
# finalize
#

# add to version control
cd $cfgmon_root/servers
git add --all >/dev/null 2>&1
git commit -am "system fetch" >/dev/null 2>&1
cd - >/dev/null
