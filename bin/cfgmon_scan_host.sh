#!/bin/bash

scan_type=$1
cfgmon_root=$2

function usage() {
    echo "Usage: cfgmon_scan_host.sh [init|scan_type] [cfgmon_root]"
}

[ -z "$scan_type" ] && echo "Error. $(usage)" && exit 1

: ${cfgmon_root:=/home/pmaker/cfgmon}

if [ $scan_type == init ]; then

    echo "======================================="
    echo "============ Config Monitor ==========="
    echo "============== host scan =============="
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
    mkdir -p $cfgmon_root
    git init $cfgmon_root

    exit 0
fi

#
# dump config
#
echo "======================================="
echo "============ Config Monitor ==========="
echo "============== host scan =============="
echo "======================================="
echo "== host: $(hostname)"
echo "== user: $(whoami)"
echo "== date: $(date)"
echo "======================================="
echo "== cfgmon_root: $cfgmon_root"
echo "== mode: scan"
echo "== scan_type: $scan_type"
echo "======================================="
echo "======================================="

if [ ! -d $cfgmon_root ]; then
        echo 'Scan env not initialized. Run the script with init argument first.'
        exit 1
fi

# prepare cfg mon for today
today=$(date -u +"%Y-%m-%d")
cfgmon_now=$cfgmon_root/$today
touch $cfgmon_root/lock

# sysctl
mkdir -p $cfgmon_now/os/sysctl
sudo sysctl -a >$cfgmon_now/os/sysctl/sysctl.log

# weblogic
mkdir -p $cfgmon_now/middleware/wls

source ~/wls-tools/bin/discover_processes.sh
discoverWLS
wls_user=$(getWLSjvmAttr ${wls_managed[0]} os_user)

chmod o+x ~/
chmod -R o+x ~/wls-tools
chmod -R o+x ~/wls-tools/*
wlstools_bin=$(cd ~/wls-tools/bin; pwd)

sudo su $wls_user <<EOF
source $wlstools_bin/document_host.sh document
EOF

sudo su $wls_user <<EOF
chmod -R o+r /home/applsoad/oracle/weblogic/current
EOF


cp -r /home/applsoad/oracle/weblogic/current $cfgmon_now/middleware/wls

#
# finalize
#

mv $cfgmon_root/current $wlsdoc_root/current.prv
cp -r $cfgmon_now $cfgmon_root/current
rm -rf $wlsdoc_root/current.prv

# remove lock
rm -rf $cfgmon_root/lock

# add to version control
cd $cfgmon_now
git add --all >/dev/null 2>&1
git commit -am "config fetch" >/dev/null 2>&1
cd - >/dev/null
