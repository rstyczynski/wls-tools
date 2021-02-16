#!/bin/bash

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

wls_component=$(basename "$0" | cut -d. -f1)

max_int=2147483647

function usage() {
    cat <<EOF
Usage: $script_name svc_def [start|stop|status|restart|register|unregister] 
EOF
}

case $1 in
start | stop | status | restart | register | unregister)
    operation=$1
    shift
    
    wls_component=$1
    shift

    domain_code=$1
    shift
    domain_code=${domain_code:-wls1}
    ;;
*)
    usage
    exit 1
    ;;
esac

os_release=$(cat /etc/os-release | grep '^VERSION=' | cut -d= -f2 | tr -d '"' | cut -d. -f1)
if [ $os_release -eq 6 ]; then
    source /etc/init.d/functions
fi


function y2j() {
    python -c "import json, sys, yaml ; y=yaml.safe_load(sys.stdin.read()) ; print(json.dumps(y))"
}

#
# custom
#



function start() {
    #TODO

    case $wls_component in
    wls_nodemanager)
        $DOMAIN_HOME/bin/startNodeManager.sh >> $DOMAIN_HOME/servers/$wls_component.out
        ;;
    wls_adminserver)
        $DOMAIN_HOME/bin/startWebLogic.sh >> $DOMAIN_HOME/servers/$wls_component.out
        ;;
    esac

}

function stop() {

    case $wls_component in
    wls_nodemanager)
        $DOMAIN_HOME/bin/stopNodeManager.sh >> $DOMAIN_HOME/servers/$wls_component.out
        ;;
    wls_adminserver)
        $DOMAIN_HOME/bin/stopWebLogic.sh >> $DOMAIN_HOME/servers/$wls_component.out
        ;;
    esac
}

function status() {
    echo "not implemented"
}


function register_initd() {
    cat >/tmp/$wls_component <<EOF
#!/bin/bash
#
# chkconfig:   12345 01 99
# description: WebLogic startup service for $wls_component
#

sudo su - $DOMAIN_OWNER /etc/init.d/$wls_component \$1
EOF

    chmod +x /tmp/$wls_component
    sudo mv /tmp/$wls_component /etc/init.d/$wls_component

    sudo chkconfig --add $wls_component

    echo echo "Service registered. Start the service:"
    cat <<EOF
sudo service $wls_component start
sudo service $wls_component status
sudo service $wls_component stop
EOF
}

function unregister_initd() {

    stop
    sudo chkconfig --del $wls_component
    sudo rm -f /etc/init.d/$wls_component

    echo "Service unregistered."
}

function register_systemd() {

    cat >/tmp/$wls_component <<EOF
[Unit]
Description=WebLogic start script - $wls_component

[Service]
Type=simple

User=$DOMAIN_OWNER
TimeoutStartSec=600

ExecStart=$start_service
ExecStop=$stop_service

LimitNOFILE=65535
RemainAfterExit=no
KillMode=process
Restart=always
  
[Install]
WantedBy=multi-user.target
EOF

    sudo mv /tmp/$wls_component /etc/systemd/system/$wls_component.service
    sudo systemctl daemon-reload
    sudo systemctl enable $wls_component.service

    echo "Service registered. Start and manage the service:"
    cat <<EOF
sudo systemctl start $wls_component
sudo systemctl status $wls_component
sudo systemctl restart $wls_component
sudo systemctl stop $wls_component

sudo journalctl -u $wls_component
sudo journalctl -u $wls_component -f
EOF

}

function unregister_systemd() {

    stop
    sudo systemctl disable $wls_component.service
    sudo rm -f /etc/systemd/system/$wls_component.service

    sudo systemctl daemon-reload

    echo "Service unregistered."
}

#
# get / set domain home
#
source $script_dir/config.sh 
if [ -z "$DOMAIN_HOME" ]; then
    DOMAIN_HOME=$(getcfg $domain_code DOMAIN_HOME 2>/dev/null)
fi

if [ -z "$DOMAIN_OWNER" ]; then
    DOMAIN_OWNER=$(getcfg $domain_code DOMAIN_OWNER 2>/dev/null)
fi

if [ -z "$DOMAIN_HOME" ] || [ -z "$DOMAIN_OWNER" ]  ; then
    #
    # WebLogic discovery
    #
    echo -n "WLS discovery..."
    source $script_dir/discover_processes.sh 
    discoverWLS
    DOMAIN_OWNER=$(getWLSjvmAttr ${wls_managed[0]} os_user)
    : ${DOMAIN_OWNER:=$(getWLSjvmAttr ${wls_admin[0]} os_user)}
    DOMAIN_HOME=$(getWLSjvmAttr ${wls_managed[0]} domain_home)
    : ${DOMAIN_HOME:=$(getWLSjvmAttr ${wls_admin[0]} domain_home)}
    if [ -z "$DOMAIN_HOME" ] || [ -z "$DOMAIN_OWNER" ]  ; then
        echo "Running WebLogic processes not found."

        #
        # Weblogic manual parametrisation
        #
        test -z "$DOMAIN_OWNER" && read -p "Enter WebLogic domain owner name:" DOMAIN_OWNER

        # test user
        DOMAIN_OWNER_TEST=$(sudo su - $DOMAIN_OWNER -c 'echo $(whoami)' | tail -1)
        test -z "$DOMAIN_OWNER_TEST" && unset DOMAIN_OWNER

        # get domain home
        test -z "$DOMAIN_HOME" && DOMAIN_HOME=$(sudo su - $DOMAIN_OWNER -c 'echo $DOMAIN_HOME' | tail -1)

        test -z "$DOMAIN_HOME" && read -p "Enter WebLogic domain home directory:" DOMAIN_HOME

        DOMAIN_HOME_TEST=$(sudo su - $DOMAIN_OWNER -c "echo $(ls $DOMAIN_HOME)")
        test -z "$DOMAIN_HOME_TEST" && unset DOMAIN_HOME

    fi

    if [ ! -z "$DOMAIN_OWNER" ] && [ ! -z "$DOMAIN_HOME" ]; then
        setcfg $domain_code DOMAIN_OWNER $DOMAIN_OWNER force 2>/dev/null
        setcfg $domain_code DOMAIN_HOME $DOMAIN_HOME force 2>/dev/null
    fi
fi

export DOMAIN_OWNER
export DOMAIN_HOME

if [ -z "$DOMAIN_HOME" ]; then
    echo "DOMAIN_HOME not set. Exiting."
    exit 1
fi

if [ -z "$DOMAIN_OWNER" ]; then
    echo "DOMAIN_OWNER not set. Exiting."
    exit 1
fi

#
# run
#

cat <<EOF
Running for WebLogic:
1. DOMAIN_HOME: $DOMAIN_HOME
2. DOMAIN_OWNER: $DOMAIN_OWNER

EOF

case $operation in
start)
    start
    ;;
stop)
    stop
    ;;
status)
    status
    ;;
restart)
    stop
    sleep 1
    start
    ;;
register)

    case $wls_component in
    wls_nodemanager)
        start_service="$DOMAIN_HOME/bin/startNodeManager.sh"
        stop_service="$DOMAIN_HOME/bin/stopNodeManager.sh"
        ;;
    wls_adminserver)
        start_service="$DOMAIN_HOME/bin/startWebLogic.sh"
        stop_service="$DOMAIN_HOME/bin/stopWebLogic.sh"
        ;;
    esac

    case $os_release in
    6)
        register_initd
        ;;
    7)
        register_systemd
        ;;
    esac
    ;;
unregister)
    case $os_release in
    6)
        unregister_initd
        ;;
    7)
        unregister_systemd
        ;;
    *)
        echo Error. Unsupported OS release.
        exit 1
        ;;
    esac
    ;;
*)
    exit 1
    ;;
esac
