#!/bin/bash

scan_type=$1
cfgmon_root=$2
nfs_root=$3

function usage() {
    echo "Usage: cfgmon_scan_host.sh [init|scan_type] [cfgmon_root] [nfs_root]"
}

[ -z "$scan_type" ] && echo "Error. $(usage)" && exit 1

: ${cfgmon_root:=/home/pmaker}

if [ $scan_type == init ]; then

    echo "======================================="
    echo "============ Config Monitor ==========="
    echo "============== host scan =============="
    echo "======================================="
    echo "== host: $(hostname)"
    echo "== user: $(whoami)"
    echo "== date: $(date)"
    echo "======================================="
    echo "== cfgmon_root: $cfgmon_root/cfgmon"
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
    mkdir -p $cfgmon_root/cfgmon
    git init $cfgmon_root/cfgmon

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
echo "== cfgmon_root: $cfgmon_root/cfgmon"
echo "== mode: scan"
echo "== scan_type: $scan_type"
echo "======================================="
echo "======================================="

if [ ! -d $cfgmon_root/cfgmon ]; then
        echo 'Scan env not initialized. Run the script with init argument first.'
        exit 1
fi

# prepare cfg mon for today
today=$(date -u +"%Y-%m-%d")
cfgmon_now=$cfgmon_root/cfgmon/$today

# remove today (if exists) to avoind file mixing between multiple runs on the sme day
rm -rf $cfgmon_now
mkdir -p $cfgmon_now

# lock cfg mon directory
touch $cfgmon_root/cfgmon/lock

# sysctl
mkdir -p $cfgmon_now/os/sysctl
sudo sysctl -a >$cfgmon_now/os/sysctl/sysctl.log

# weblogic
source ~/wls-tools/bin/discover_processes.sh
discoverWLS
wls_user=$(getWLSjvmAttr ${wls_managed[0]} os_user)
# take wls owner home dir
wls_user_home=$(cat /etc/passwd | grep "^$wls_user:" | cut -d: -f6)

chmod o+x ~/
chmod -R o+x ~/wls-tools
chmod -R o+x ~/wls-tools/*
wlstools_bin=$(cd ~/wls-tools/bin; pwd)

# prepare inbox to get data from wls user
pmaker_home=$HOME
mkdir -p $pmaker_home/cfgmon/inbox
chmod o+x $pmaker_home/cfgmon
chmod o+x $pmaker_home/cfgmon/inbox
chmod o+w $pmaker_home/cfgmon/inbox

# perform document_host
sudo su - $wls_user <<EOF
$wlstools_bin/document_host.sh document
if [ \$? -eq 0 ]; then 

    touch /tmp/document_host.ok
    chmod -R o+r /tmp/document_host.ok
    rm -rf /tmp/document_host.error

    #chmod o+x \$HOME
    #chmod -R o+x \$HOME/oracle
    #chmod -R o+r \$HOME/oracle/weblogic/current

    cp -R ~/oracle/weblogic/current/* $pmaker_home/cfgmon/inbox

    for file_name in \$(ls $pmaker_home/cfgmon/inbox); do
        chmod -R o+r $pmaker_home/cfgmon/inbox/\$file_name
        chmod -R o+w $pmaker_home/cfgmon/inbox/\$file_name
        [ -d $file_name ] && chmod -R o+x $pmaker_home/cfgmon/inbox/\$file_name
    done
else
    touch /tmp/document_host.error
    chmod -R o+r /tmp/document_host.error
    rm -rf /tmp/document_host.ok
fi
EOF

if [ -f /tmp/document_host.ok ]; then
    mkdir -p $cfgmon_now/wls
    cp -R $pmaker_home/cfgmon/inbox/* $cfgmon_now/wls/
    rm -rf $pmaker_home/cfgmon/inbox
fi

# make archive
echo ">> preparing tar files..."
cd $cfgmon_now
mkdir -p $cfgmon_root/cfgmon/outbox
tar -zcvf $cfgmon_root/cfgmon/outbox/$(hostname).$today.scan_host.tar.gz . >/dev/null

# copy to shared location
if [ ! -z "$nfs_root" ]; then
    echo ">> copying tar file to shared location..."
    mkdir -p $nfs_root/inbox
    cp $cfgmon_root/cfgmon/outbox/$(hostname).$today.scan_host.tar.gz $nfs_root/inbox

    echo ">> copying files to shared location..."
    mkdir -p $nfs_root/$(hostname)/$today
    cp -R $cfgmon_now/*  $nfs_root/$(hostname)/$today

    mv $nfs_root/$(hostname)/current $nfs_root/$(hostname)/current.prv
    mkdir -p $nfs_root/$(hostname)/current
    cp -R  $cfgmon_now/* $nfs_root/$(hostname)/current
    rm -rf $nfs_root/$(hostname)/current.prv
fi

#
# finalize
#

echo ">> linking current to actual data: $cfgmon_root/cfgmon/current -> $cfgmon_now"
mv $cfgmon_root/cfgmon/current $cfgmon_root/cfgmon/current.prv
ln -s $(basename $cfgmon_now) $cfgmon_root/cfgmon/current 
rm -rf $cfgmon_root/cfgmon/current.prv

# remove lock
rm -rf $cfgmon_root/cfgmon/lock

# remove old data
find $cfgmon_root/cfgmon -maxdepth 1 -type d -mtime +7 | xargs rm -rf 

# add to version control
echo ">> keeping history in git"
cd $cfgmon_root/cfgmon
git add --all >/dev/null 2>&1
git commit -am "config fetch" >/dev/null 2>&1
cd - >/dev/null

echo "Done."
