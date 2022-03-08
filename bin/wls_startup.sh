#!/bin/bash

function usage() {
    cat <<EOF
Usage: $script_name type_name [start|stop|status|restart|register|unregister] 
EOF
}

#
# custom
#

function start() {
    case $start_mode in
    blocking)

        if [ $(whoami) != $DOMAIN_OWNER ]; then
            echo "Executing: sudo su - $DOMAIN_OWNER -c \"nohup $start_service &\""
            # TODO rotate on start
            sudo su - $DOMAIN_OWNER -c "nohup $start_service > $stdout_log 2> $stderr_log  &"
        else
            echo "Executing: \"nohup $start_service &\""
            nohup $start_service > $stdout_log 2> $stderr_log &
        fi
        echo "Started in background."   
        ;;
    requesting)
        if [ $(whoami) != $DOMAIN_OWNER ]; then
            echo "Executing: sudo su - $DOMAIN_OWNER -c \"$start_service\""
            sudo su - $DOMAIN_OWNER -c "$start_service"
        else
            echo "Executing: $start_service"
            $start_service
        fi

        if [ $? -eq 0 ]; then
            echo "Start requested."
        else
            echo "Start failed."
        fi
        ;;
    *)
        echo "Error. Wrong start mode."
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
        echo
        echo "Node manager properties:"
        if [ $(whoami) != $DOMAIN_OWNER ]; then
            sudo su - $DOMAIN_OWNER -c "cat $DOMAIN_HOME/nodemanager/nodemanager.properties"
        else
            cat $DOMAIN_HOME/nodemanager/nodemanager.properties
        fi
        echo "Source: $DOMAIN_HOME/nodemanager/nodemanager.properties"

        status=$(ps aux | grep "^$DOMAIN_OWNER" | grep -v grep | grep java | grep weblogic.NodeManager)
        if [ -z "$status" ]; then
            echo "Node manager not running."
            echo
        else
            echo "Node manager process:"
            ps aux  | grep "^$DOMAIN_OWNER" | grep -v grep | grep java | grep weblogic.NodeManager
            echo
        fi
        ;;
    *)
        case $DOMAIN_TYPE in
        wls)
            status=$(ps aux | grep "^$DOMAIN_OWNER" | grep -v grep | grep java | grep -v  weblogic.NodeManager | grep weblogic.Server | grep -i "Dweblogic.Name=$WLS_INSTANCE")
            if [ -z "$status" ]; then
            echo "Weblogic not running."
            echo 
            else
                echo "Weblogic process:"
                ps aux | grep "^$DOMAIN_OWNER"  | grep -v grep | grep java | grep -v  weblogic.NodeManager | grep weblogic.Server | grep -i "Dweblogic.Name=$WLS_INSTANCE"
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

$script_dir/$script_name $wls_component \$1
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

    sudo chkconfig --del $wls_component
    sudo rm -f /etc/init.d/$wls_component

    echo "Service unregistered."
}

#
# systemd functions
# 

function register_systemd() {

case $start_mode in
blocking)
    # nodemanager and adminserver process start is blocking, so may be managed by systemd. notice RemainAfterExit=no
    cat >/tmp/$wls_component <<EOF
[Unit]
Description=WebLogic start script - $wls_component

[Service]
Type=simple

User=$DOMAIN_OWNER
TimeoutStartSec=600

ExecStart=$start_service
ExecStop=$stop_service

RemainAfterExit=no
KillMode=process
Restart=always
  
[Install]
WantedBy=multi-user.target
EOF
    ;;
requesting)
    # server process start is non blocking, so cannot be managed by systemd. notice RemainAfterExit=yes

    # Note that [Unit] Requires= After= can't be used as node mamanger service name is not static - may be prefixd with wls_ or ohs_
    # wait for nm process is implemented in wls start / stop scripts.
    cat >/tmp/$wls_component <<EOF
[Unit]
Description=WebLogic start script - $wls_component

[Service]
Type=simple

User=$DOMAIN_OWNER
TimeoutStartSec=600

ExecStart=$script_dir/$script_name $wls_component start
ExecStop=$script_dir/$script_name $wls_component stop

RemainAfterExit=yes
KillMode=process
Restart=no
  
[Install]
WantedBy=multi-user.target
EOF
    ;;
esac

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

# wls_nodemanager
# wls_adminserver
# wls_soa_server1
# ohs_nodemanager
# ohs_ohs1
wls_component=$1
shift

DOMAIN_TYPE=$(echo $wls_component | cut -d_ -f1 | tr [A-Z] [a-z])
WLS_INSTANCE=$(echo $wls_component | cut -d_ -f2-999 | tr [A-Z] [a-z])

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

config_id=$1
shift
: ${config_id:=wls1}

os_release=$(cat /etc/os-release | grep '^VERSION=' | cut -d= -f2 | tr -d '"' | cut -d. -f1)
if [ $os_release -eq 6 ]; then
    source /etc/init.d/functions
fi

#
# get / set domain home
#
source $script_dir/config.sh 
DOMAIN_HOME=$(getcfg $config_id DOMAIN_HOME 2>/dev/null)
DOMAIN_NAME=$(getcfg $config_id DOMAIN_NAME 2>/dev/null)
DOMAIN_OWNER=$(getcfg $config_id DOMAIN_OWNER 2>/dev/null)

case $DOMAIN_TYPE in
wls)
    if [ -z "$DOMAIN_HOME" ] || [ -z "$DOMAIN_NAME" ] || [ -z "$DOMAIN_OWNER" ]  ; then

        #
        # WebLogic discovery
        #
        echo -n "WLS discovery..."
        source $script_dir/discover_processes.sh 
        discoverWLS

        : ${DOMAIN_OWNER:=$(getWLSjvmAttr ${wls_managed[0]} os_user)}
        : ${DOMAIN_OWNER:=$(getWLSjvmAttr ${wls_admin[0]} os_user)}
        : ${DOMAIN_NAME:=$(getDomainName)}
        : ${DOMAIN_HOME:=$(getDomainHome)}
    fi

    if [ -z "$DOMAIN_HOME" ] || [ -z "$DOMAIN_NAME" ] || [ -z "$DOMAIN_OWNER" ]; then
        echo "WebLogic processes not found. Make sure all process are up during install to enable auto discovery."
        echo "When not possible, prepare configuration using $script_dir/config.sh with proper config_id."
    fi
    ;;
ohs)
    # Weblogic not found, try OHS
    if [ -z "$DOMAIN_HOME" ] || [ -z "$DOMAIN_NAME" ] || [ -z "$DOMAIN_OWNER" ]  ; then
        echo -n "OHS discovery..."

        : ${NM_OHS:=$(ps aux | grep -v grep | grep java | grep weblogic.NodeManager | tr -s ' ' | tr ' ' '\n' | grep ohs.product.home | cut -d= -f2 | head -1)}
        test ! -z "$NM_OHS" && DOMAIN_TYPE=ohs

        : ${DOMAIN_OWNER=:$(ps aux | grep -v grep | grep java | grep weblogic.NodeManager | tr -s ' ' | cut -d' ' -f1 | head -1)}
        : ${DOMAIN_HOME:=$(ps aux | grep -v grep | grep java | grep weblogic.NodeManager | tr -s ' ' | tr ' ' '\n' | grep weblogic.RootDirectory | cut -d= -f2 | head -1)}
        : ${DOMAIN_NAME:=$(filename $DOMAIN_HOME)}
        : ${NM_PID:=$(ps aux | grep -v grep | grep java | grep weblogic.NodeManager | tr -s ' ' | cut -d' ' -f2 | head -1)}
    fi
    if [ -z "$DOMAIN_HOME" ] || [ -z "$DOMAIN_NAME" ] || [ -z "$DOMAIN_OWNER" ]  ; then
        echo "OHS processes not found."
    fi
    ;;
esac

# Weblogic nor OHS not found. Ask operator for domain parameters.
if [ -z "$DOMAIN_HOME" ]  || [ -z "$DOMAIN_NAME" ] || [ -z "$DOMAIN_OWNER" ]; then
    echo "Running processes not found. Manual configuration required."
    #
    # Weblogic manual parametrisation
    #

    # ask for username and test
    test -z "$DOMAIN_OWNER" && read -p "Enter Weblogic domain owner name:" DOMAIN_OWNER

    if [ $(whoami) != "$DOMAIN_OWNER" ]; then
        DOMAIN_OWNER_TEST=$(sudo su  $DOMAIN_OWNER -c 'echo $(whoami) | tail -1')
        test -z "$DOMAIN_OWNER_TEST" && unset DOMAIN_OWNER
    fi

    # get domain home from users's env, ask for, and test
    if [ $(whoami) != "$DOMAIN_OWNER" ]; then
        test -z "$DOMAIN_HOME" && DOMAIN_HOME=$(sudo su  $DOMAIN_OWNER -c "ls $DOMAIN_HOME | tail -1")
    else
        test -z "$DOMAIN_HOME" && DOMAIN_HOME=$(ls $DOMAIN_HOME | tail -1)
    fi

    test -z "$DOMAIN_HOME" && read -p "Enter Weblogic domain home directory:" DOMAIN_HOME

    if [ $(whoami) != "$DOMAIN_OWNER" ]; then
        DOMAIN_HOME_TEST=$(sudo su  $DOMAIN_OWNER -c "ls $DOMAIN_HOME/bin/startNodeManager.sh")
        test -z "$DOMAIN_HOME_TEST" && unset DOMAIN_HOME
    else
        DOMAIN_HOME_TEST=$(ls $DOMAIN_HOME/bin/startNodeManager.sh)
        test -z "$DOMAIN_HOME_TEST" && unset DOMAIN_HOME
    fi

    test -z "$DOMAIN_NAME" && read -p "Enter Weblogic domain name:" DOMAIN_NAME
    if [ $(whoami) != $DOMAIN_OWNER ]; then
        DOMAIN_NAME_TEST=$(sudo su  $DOMAIN_OWNER -c "ls $(dirname $DOMAIN_HOME)/$DOMAIN_NAME/bin/startNodeManager.sh")
        test -z "$DOMAIN_NAME_TEST" && unset DOMAIN_HOME
    else
        DOMAIN_HOME_TEST=$(ls $(dirname $DOMAIN_HOME)/$DOMAIN_NAME/bin/startNodeManager.sh)
        test -z "$DOMAIN_NAME_TEST" && unset DOMAIN_HOME
    fi

fi

# save provided data to configuration if no value was provided / discovered
if [ ! -z "$DOMAIN_OWNER" ]; then
    config_value=$(getcfg $config_id DOMAIN_OWNER)
    if [ "$config_value" != $DOMAIN_OWNER ]; then
        setcfg $config_id DOMAIN_OWNER $DOMAIN_OWNER force 2>/dev/null
    fi
fi

if [ ! -z "$DOMAIN_NAME" ]; then
    config_value=$(getcfg $config_id DOMAIN_NAME)
    if [ "$config_value" != $DOMAIN_NAME ]; then
        setcfg $config_id DOMAIN_NAME $DOMAIN_NAME force 2>/dev/null
    fi
fi

if [ ! -z "$DOMAIN_HOME" ]; then
    config_value=$(getcfg $config_id DOMAIN_HOME)
    if [ "$config_value" != $DOMAIN_HOME ]; then
        setcfg $config_id DOMAIN_HOME $DOMAIN_HOME force 2>/dev/null
    fi
fi

export DOMAIN_OWNER
export DOMAIN_TYPE
export DOMAIN_HOME
export DOMAIN_NAME

# final test of DOMAIN_HOME 
if [ $(whoami) != $DOMAIN_OWNER ]; then
    DOMAIN_HOME_TEST=$(sudo su  $DOMAIN_OWNER -c "ls $DOMAIN_HOME/bin/startNodeManager.sh")
    test -z "$DOMAIN_HOME_TEST" && unset DOMAIN_HOME
else
    DOMAIN_HOME_TEST=$(ls $DOMAIN_HOME/bin/startNodeManager.sh)
    test -z "$DOMAIN_HOME_TEST" && unset DOMAIN_HOME
fi

if [ -z "$DOMAIN_NAME" ]; then
    echo "DOMAIN_NAME not set or wrong. Exiting."
    exit 1
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

#
# run
#

case $WLS_INSTANCE in
nodemanager)
    start_service="$DOMAIN_HOME/bin/startNodeManager.sh"
    stop_service="$DOMAIN_HOME/bin/stopNodeManager.sh"

    stdout_log=$DOMAIN_HOME/nodemanager/nodemanager.out
    stderr_log=$DOMAIN_HOME/nodemanager/nodemanager.err
    
    start_mode=blocking

    start_priority=60
    stop_priority=90
    ;;
*)
    case $DOMAIN_TYPE in
    wls)
        cat <<EOF
    Running for WebLogic:
    1. DOMAIN_HOME:  $DOMAIN_HOME
    2. DOMAIN_HOME:  $DOMAIN_NAME
    3. DOMAIN_OWNER: $DOMAIN_OWNER
    4. INSTANCE:     $WLS_INSTANCE

EOF
        case $WLS_INSTANCE in
        adminserver)
            start_service="$DOMAIN_HOME/bin/startWebLogic.sh"
            stop_service="$DOMAIN_HOME/bin/stopWebLogic.sh"

            stdout_log=$DOMAIN_HOME/servers/AdminServer/logs/AdminServer.out
            stderr_log=$DOMAIN_HOME/servers/AdminServer/logs/AdminServer.err

            start_mode=blocking

            start_priority=90
            stop_priority=60
            ;;
        *)
            if [ $(whoami) != $DOMAIN_OWNER ]; then
                NM_HOST=$(sudo su  $DOMAIN_OWNER -c "cat $DOMAIN_HOME/nodemanager/nodemanager.properties | grep ListenAddress | cut -d= -f2")
                NM_PORT=$(sudo su  $DOMAIN_OWNER -c "cat $DOMAIN_HOME/nodemanager/nodemanager.properties | grep ListenPort | cut -d= -f2")
            else
                NM_HOST=$(cat $DOMAIN_HOME/nodemanager/nodemanager.properties | grep ListenAddress | cut -d= -f2 )
                NM_PORT=$(cat $DOMAIN_HOME/nodemanager/nodemanager.properties | grep ListenPort | cut -d= -f2 )
            fi
            start_service="$script_dir/wls_startServer.sh $DOMAIN_NAME $DOMAIN_HOME $NM_HOST $NM_PORT $WLS_INSTANCE"
            stop_service="$script_dir/wls_stopServer.sh $DOMAIN_NAME $DOMAIN_HOME $NM_HOST $NM_PORT $WLS_INSTANCE"

            start_mode=requesting

            start_priority=95
            stop_priority=55
            ;;
        esac
        ;;
    ohs)
        cat <<EOF
    Running for OHS:
    1. DOMAIN_HOME:  $DOMAIN_HOME
    2. DOMAIN_HOME:  $DOMAIN_NAME
    3. DOMAIN_OWNER: $DOMAIN_OWNER
    4. INSTANCE:     $WLS_INSTANCE

EOF
    start_service="$DOMAIN_HOME/bin/startComponent.sh $WLS_INSTANCE"
    stop_service="$DOMAIN_HOME/bin/stopComponent.sh $WLS_INSTANCE"

    start_mode=requesting

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
