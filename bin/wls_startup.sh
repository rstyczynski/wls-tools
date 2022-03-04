#!/bin/bash

function usage() {
    cat <<EOF
Usage: $script_name svc_def [start|stop|status|restart|register|unregister] 
EOF
}

#
# custom
#

function start() {
    case $WLS_INSTANCE in
    nodemanager)
        if [ $(whoami) != $DOMAIN_OWNER ]; then
            echo "Executing: sudo su - $DOMAIN_OWNER -c \"$start_service &\""
            sudo su - $DOMAIN_OWNER -c "$start_service &"
        else
            echo "Executing: \"$start_service &\""
            $start_service &
        fi
        echo "Started in background."   
        ;;
    *)
        if [ $(whoami) != $DOMAIN_OWNER ]; then
            echo "Executing: sudo su - $DOMAIN_OWNER -c \"$start_service\""
            sudo su - $DOMAIN_OWNER -c "$start_service"
        else
            echo "Executing: $start_service"
            $start_service
        fi
        echo "Start requested."  
        ;;
    esac
}

function stop() {
    if [ $(whoami) != $DOMAIN_OWNER ]; then
        echo "Executing: sudo su - $DOMAIN_OWNER -c \"$stop_service\""
        sudo su - $DOMAIN_OWNER -c "$stop_service"
    else
        echo "Executing: $stop_service"
        $stop_service
    fi
    echo "Stop requested."
}

function status() {
    case $WLS_INSTANCE in
    nodemanager)
        status=$(ps aux | grep "^$DOMAIN_OWNER" | grep -v grep | grep java | grep weblogic.NodeManager)
        if [ -z "$status" ]; then
            echo "Node manager not running."
            echo
        else
            echo "Node manager process:"
            ps aux  | grep "^$DOMAIN_OWNER" | grep -v grep | grep java | grep weblogic.NodeManager
            echo
        fi
        echo "Node manager properties:"
        if [ $(whoami) != $DOMAIN_OWNER ]; then
            sudo su - $DOMAIN_OWNER -c "cat $DOMAIN_HOME/nodemanager/nodemanager.properties"
        else
            cat $DOMAIN_HOME/nodemanager/nodemanager.properties
        fi

        ;;
    *)
        case $DOMAIN_TYPE in
        wls)
            status=$(ps aux | grep "^$DOMAIN_OWNER" | grep -v grep | grep java | grep -v  weblogic.NodeManager | grep weblogic)
            if [ -z "$status" ]; then
            echo "Weblogic not running."
            echo 
            else
                echo "Weblogic process:"
                ps aux | grep "^$DOMAIN_OWNER"  | grep -v grep | grep java | grep -v  weblogic.NodeManager | grep weblogic
                echo 
            fi
            ;;
        ohs)
            status=$(ps aux | grep "^$DOMAIN_OWNER" | grep -v grep | grep httpd)
            if [ -z "$status" ]; then
            echo "OHS not running."
            echo 
            else
                echo "OHS process:"
                ps aux | grep "^$DOMAIN_OWNER" | grep -v grep | grep httpd
                echo
            fi
            ;;
        esac
        ;;
    esac
}

#
# init.d functions
#

function register_initd() {

    cat >/tmp/$wls_component <<EOF
#!/bin/bash
#
# chkconfig:   2345 $start_priority $stop_priority
# description: WebLogic startup service for $wls_component
#

$script_dir/$script_name \$1 $wls_component 
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

#
# systemd functions
# 

function register_systemd() {

    if [ $WLS_INSTANCE == 'nodemanager' ]; then
    cat >/tmp/$wls_component <<EOF
[Unit]
Description=WebLogic start script - $wls_component

[Service]
Type=simple

User=$DOMAIN_OWNER
TimeoutStartSec=600

ExecStart=$script_dir/$script_name start $wls_component 
ExecStop=$script_dir/$script_name stop $wls_component 

LimitNOFILE=65535
RemainAfterExit=no
KillMode=process
Restart=always
  
[Install]
WantedBy=multi-user.target
EOF
else
    cat >/tmp/$wls_component <<EOF
[Unit]
Description=WebLogic start script - $wls_component

[Service]
Type=simple

User=$DOMAIN_OWNER
TimeoutStartSec=600

ExecStart=$script_dir/$script_name start $wls_component 
ExecStop=$script_dir/$script_name stop $wls_component 

LimitNOFILE=65535
RemainAfterExit=no
KillMode=process
Restart=always
  
[Install]
WantedBy=multi-user.target
EOF
fi

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
# main logic
#

# use cd to eliminate potentially relative path. we need the absolute one.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
script_name=$(basename "${BASH_SOURCE[0]}")

operation=$1
shift

case $operation in
start | stop | status | restart | register | unregister)
    ;;
*)
    usage
    exit 1
    ;;
esac

# wls_nodemanager
# wls_adminserver
# wls_soa_server1
# ohs_nodemanager
# ohs_ohs1
wls_component=$1
shift

DOMAIN_TYPE=$(echo $wls_component | cut -d_ -f1 | tr [A-Z] [a-z])
WLS_INSTANCE=$(echo $wls_component | cut -d_ -f2-999 | tr [A-Z] [a-z])

config_id=$1
shift
config_id=${config_id:=wls1}

os_release=$(cat /etc/os-release | grep '^VERSION=' | cut -d= -f2 | tr -d '"' | cut -d. -f1)
if [ $os_release -eq 6 ]; then
    source /etc/init.d/functions
fi

#
# get / set domain home
#
source $script_dir/config.sh 
if [ -z "$DOMAIN_HOME" ]; then
    DOMAIN_HOME=$(getcfg $config_id DOMAIN_HOME 2>/dev/null)
fi

if [ -z "$DOMAIN_OWNER" ]; then
    DOMAIN_OWNER=$(getcfg $config_id DOMAIN_OWNER 2>/dev/null)
fi

if [ -z "$ADMIN_T3" ]; then
    ADMIN_T3=$(getcfg $config_id ADMIN_T3 2>/dev/null)
fi

case $DOMAIN_TYPE in
wls)
    if [ -z "$DOMAIN_HOME" ] || [ -z "$DOMAIN_OWNER" ] || [ -z "$ADMIN_T3" ] ; then

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

        ADMIN_URL=$(getWLSjvmAttr ${wls_managed[0]} -Dweblogic.management.server)
        ADMIN_T3=$(echo $ADMIN_URL | tr [A-Z] [a-z] | sed s/http/t3/)

    fi
    if [ -z "$DOMAIN_HOME" ] || [ -z "$DOMAIN_OWNER" ] || [ -z "$ADMIN_T3" ]  ; then
        echo "WebLogic processes not found. Make sure all process are up during install to enable auto discovery."
        echo "When not possible, prepare configuration using $script_dir/config.sh with proper config_id."
    fi
    ;;
ohs)
    # Weblogic not found try OHS
    if [ -z "$DOMAIN_HOME" ] || [ -z "$DOMAIN_OWNER" ]  ; then
        echo -n "OHS discovery..."

        NM_OHS=$(ps aux | grep -v grep | grep java | grep weblogic.NodeManager | tr -s ' ' | tr ' ' '\n' | grep ohs.product.home | cut -d= -f2 | head -1)
        test ! -z "$NM_OHS" && DOMAIN_TYPE=ohs

        DOMAIN_OWNER=$(ps aux | grep -v grep | grep java | grep weblogic.NodeManager | tr -s ' ' | cut -d' ' -f1 | head -1)
        DOMAIN_HOME=$(ps aux | grep -v grep | grep java | grep weblogic.NodeManager | tr -s ' ' | tr ' ' '\n' | grep weblogic.RootDirectory | cut -d= -f2 | head -1)
        NM_PID=$(ps aux | grep -v grep | grep java | grep weblogic.NodeManager | tr -s ' ' | cut -d' ' -f2 | head -1)
    fi
    if [ -z "$DOMAIN_HOME" ] || [ -z "$DOMAIN_OWNER" ]  ; then
        echo "OHS processes not found."
    fi
    ;;
esac

# Weblogic nor OHS not found. Ask operator for domain parameters.
if [ -z "$DOMAIN_HOME" ] || [ -z "$DOMAIN_OWNER" ] || [ -z "$ADMIN_T3" ]  ; then
    echo "Running processes processes not found. Manual configuration required."
    #
    # Weblogic manual parametrisation
    #

    # ask for username and test
    test -z "$DOMAIN_OWNER" && read -p "Enter Weblogic domain owner name:" DOMAIN_OWNER

    if [ $(whoami) != $DOMAIN_OWNER ]; then
        DOMAIN_OWNER_TEST=$(sudo su - $DOMAIN_OWNER -c 'echo $(whoami) | tail -1')
        test -z "$DOMAIN_OWNER_TEST" && unset DOMAIN_OWNER
    fi

    # get domain home from users's env, ask for, and test
    if [ $(whoami) != $DOMAIN_OWNER ]; then
        test -z "$DOMAIN_HOME" && DOMAIN_HOME=$(sudo su - $DOMAIN_OWNER -c "ls $DOMAIN_HOME | tail -1")
    else
        test -z "$DOMAIN_HOME" && DOMAIN_HOME=$(ls $DOMAIN_HOME | tail -1)
    fi

    test -z "$DOMAIN_HOME" && read -p "Enter Weblogic domain home directory:" DOMAIN_HOME

    if [ $(whoami) != $DOMAIN_OWNER ]; then
        DOMAIN_HOME_TEST=$(sudo su - $DOMAIN_OWNER -c "ls $DOMAIN_HOME/bin/startNodeManager.sh")
        test -z "$DOMAIN_HOME_TEST" && unset DOMAIN_HOME
    else
        DOMAIN_HOME_TEST=$(ls $DOMAIN_HOME/bin/startNodeManager.sh)
        test -z "$DOMAIN_HOME_TEST" && unset DOMAIN_HOME
    fi

    # ask for adin url
    test -z "$ADMIN_T3" && read -p "Enter Weblogic AdminServer URL. Skip for OHS only domain:" ADMIN_T3

fi

# save provided data to configuration
test ! -z "$DOMAIN_OWNER" && setcfg $config_id DOMAIN_OWNER $DOMAIN_OWNER force 2>/dev/null
test ! -z "$DOMAIN_HOME" && setcfg $config_id DOMAIN_HOME $DOMAIN_HOME force 2>/dev/null
test ! -z "$ADMIN_T3" && setcfg $config_id ADMIN_T3 $ADMIN_T3 force 2>/dev/null

export DOMAIN_OWNER
export DOMAIN_TYPE
export DOMAIN_HOME
export ADMIN_T3

# final test of DOMAIN_HOME 
if [ $(whoami) != $DOMAIN_OWNER ]; then
    DOMAIN_HOME_TEST=$(sudo su - $DOMAIN_OWNER -c "ls $DOMAIN_HOME/bin/startNodeManager.sh")
    test -z "$DOMAIN_HOME_TEST" && unset DOMAIN_HOME
else
    DOMAIN_HOME_TEST=$(ls $DOMAIN_HOME/bin/startNodeManager.sh)
    test -z "$DOMAIN_HOME_TEST" && unset DOMAIN_HOME
fi

if [ -z "$DOMAIN_HOME" ]; then
    echo "DOMAIN_HOME not set or wrong. Exiting."
    exit 1
fi

if [ -z "$DOMAIN_OWNER" ]; then
    echo "DOMAIN_OWNER not set or wrong. Exiting."
    exit 1
fi

DOMAIN_TYPE=$(echo $DOMAIN_TYPE | tr [A-Z] [a-z])
case $DOMAIN_TYPE in 
ohs | wls)
    ;;
*)
    echo "DOMAIN_TYPE not set or wrong. Exiting."
    exit 1
    ;;
esac

if [ -z "$ADMIN_T3" ]; then
    echo "ADMIN_T3 not set or wrong. Exiting."
    exit 1
fi

#
# run
#

case $WLS_INSTANCE in
nodemanager)
    start_service="$DOMAIN_HOME/bin/startNodeManager.sh"
    stop_service="$DOMAIN_HOME/bin/stopNodeManager.sh"

    start_priority=60
    stop_priority=90
    ;;
*)
    case $DOMAIN_TYPE in
    wls)
        cat <<EOF
    Running for WebLogic:
    1. DOMAIN_HOME:  $DOMAIN_HOME
    2. DOMAIN_OWNER: $DOMAIN_OWNER
    3. INSTANCE:     $WLS_INSTANCE
    3. ADMIN URL:    $ADMIN_T3

EOF
        case $WLS_INSTANCE in
        adminserver)
            start_service="$DOMAIN_HOME/bin/startWebLogic.sh"
            stop_service="$DOMAIN_HOME/bin/stopWebLogic.sh"

            start_priority=90
            stop_priority=60
            ;;
        *)
            start_service="$script_dir/wls_startServer.sh $DOMAIN_HOME $ADMIN_T3 $WLS_INSTANCE"
            stop_service="$script_dir/wls_shutdownServer.sh $DOMAIN_HOME $ADMIN_T3 $WLS_INSTANCE"

            start_priority=95
            stop_priority=55
            ;;
        esac
        ;;
    ohs)
        cat <<EOF
    Running for OHS:
    1. DOMAIN_HOME:  $DOMAIN_HOME
    2. DOMAIN_OWNER: $DOMAIN_OWNER
    3. INSTANCE:     $WLS_INSTANCE

EOF
    start_service="$DOMAIN_HOME/bin/startComponent.sh $WLS_INSTANCE"
    stop_service="$DOMAIN_HOME/bin/stopComponent.sh $WLS_INSTANCE"

    start_priority=90
    stop_priority=60
    ;;
    esac
esac


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
