#!/bin/bash

tools_src=$1; shift

: ${tools_src:=git}


# get libraries
case $tools_src in
git)
    cd ~
    test -d umc && (cd umc; git pull)
    test -d umc || git clone https://github.com/rstyczynski/umc.git
    ;;
*)
    if [ ! -d $tools_src/umc ]; then
        echo "Error. umc not available at shared location. Put it there before proceeding"
        exit 1
    fi
    cp -rf --preserve=mode,timestamps $tools_src/umc ~/
    ;;
esac

# prepare cfg directory
umc_cfg=~/.umc
mkdir -p $umc_cfg

# detect interface name (may be ens3, eth0)
primary_if=$(ip r | grep ^default | tr -s ' ' | cut -d' ' -f5)
echo "Primary if: $primary_if"

cat ~/umc/lib/os-probe.yaml | sed "s/eth0/$primary_if/" > $umc_cfg/os-probe.yaml

$HOME/umc/lib/os-service.sh os-probe.yaml restart

# init cron
cron_section_start="# START umc - os"
cron_section_stop="# STOP umc - os"

cat >umc_os.cron <<EOF
$cron_section_start
1 0 * * * $HOME/umc/lib/os-service.sh os-probe.yaml restart
$cron_section_stop
EOF

(crontab -l 2>/dev/null | 
sed "/$cron_section_start/,/$cron_section_stop/d"
cat umc_os.cron) | crontab -

rm -rf umc_os.cron
crontab -l


