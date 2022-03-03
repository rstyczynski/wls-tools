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

    case $wls_component in
    ohs)
        $DOMAIN_HOME/bin/startComponent.sh $OHS_INSTANCE >> $DOMAIN_HOME/config/fmwconfig/components/OHS/instances/$OHS_INSTANCE/$ohs_component.out
        ;;
    esac

}


function stop() {

    case $wls_component in
    ohs)
        $DOMAIN_HOME/bin/stopComponent.sh $OHS_INSTANCE >> $DOMAIN_HOME/config/fmwconfig/components/OHS/instances/$OHS_INSTANCE/$ohs_component.out
        ;;
    esac
}

function status() {
    echo "not implemented"
}


function register_initd() {
    cat >/tmp/$ohs_component <<EOF
#!/bin/bash
#
# chkconfig:   12345 01 99
# description: OHA startup service for $ohs_component
#

sudo su - $DOMAIN_OWNER /etc/init.d/$ohs_component \$1
EOF

    chmod +x /tmp/$ohs_component
    sudo mv /tmp/$ohs_component /etc/init.d/$ohs_component

    sudo chkconfig --add $ohs_component

    echo echo "Service registered. Start the service:"
    cat <<EOF
sudo service $ohs_component start
sudo service $ohs_component status
sudo service $ohs_component stop
EOF
}

function unregister_initd() {

    stop
    sudo chkconfig --del $ohs_component
    sudo rm -f /etc/init.d/$ohs_component

    echo "Service unregistered."
}

function register_systemd() {

    cat >/tmp/$ohs_component <<EOF
[Unit]
Description=OHS start script - $ohs_component

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

    sudo mv /tmp/$ohs_component /etc/systemd/system/$ohs_component.service
    sudo systemctl daemon-reload
    sudo systemctl enable $ohs_component.service

    echo "Service registered. Start and manage the service:"
    cat <<EOF
sudo systemctl start $ohs_component
sudo systemctl status $ohs_component
sudo systemctl restart $ohs_component
sudo systemctl stop $ohs_component

sudo journalctl -u $ohs_component
sudo journalctl -u $ohs_component -f
EOF

}

function unregister_systemd() {

    stop
    sudo systemctl disable $ohs_component.service
    sudo rm -f /etc/systemd/system/$ohs_component.service

    sudo systemctl daemon-reload

    echo "Service unregistered."
}

#
# RUN SCRIPT
#

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

max_int=2147483647

case $1 in
start | stop | status | restart | register | unregister)
    operation=$1
    shift
    
    wls_component=ohs

    ohs_identifier=$1
    shift
    ohs_identifier=${ohs_identifier:-ohs1}

    OHS_INSTANCE=$1
    shift

    DOMAIN_HOME=$1
    shift

    DOMAIN_OWNER=$1
    shift

    ohs_component=$wls_component\_$ohs_identifier
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

#
# get / set domain home
#
source $script_dir/config.sh 

if [ -z "$OHS_INSTANCE" ]; then
    DOMAIN_OWNER=$(getcfg $ohs_identifier OHS_INSTANCE 2>/dev/null)
fi

if [ -z "$DOMAIN_HOME" ]; then
    DOMAIN_HOME=$(getcfg $ohs_identifier DOMAIN_HOME 2>/dev/null)
fi

if [ -z "$DOMAIN_OWNER" ]; then
    DOMAIN_OWNER=$(getcfg $ohs_identifier DOMAIN_OWNER 2>/dev/null)
fi

if [ -z "$DOMAIN_HOME" ] || [ -z "$DOMAIN_OWNER" ] || [ -z "$OHS_INSTANCE" ]  ; then
    #
    # OHS discovery
    #
    echo -n "OHS discovery..."
    ohs_processes=$(ps aux | grep httpd | sed 's/-d /cfg=/g' | tr ' ' '\n' | grep cfg= | cut -f2 -d= | sort -u)
    if [ -z "$ohs_processes" ]; then
        echo 'Error. OHS not detected'
    else
        for ohs_process in $ohs_processes; do
            export OHS_INSTANCE=$(basename $ohs_process)
            export DOMAIN_NAME=$(echo $ohs_process | grep -oP 'domains/.*/config' | cut -f2 -d/)
            export DOMAIN_HOME=$(echo $ohs_process | grep -oP ".*/$DOMAIN_NAME")
            export DOMAIN_OWNER=$(ps aux | grep httpd | grep httpd | grep $ohs_processes | cut -d' ' -f1 | sort -u | head -1)
            echo "OHS instance: $OHS_INSTANCE"
            echo "Domain owner: $DOMAIN_OWNER"
            echo "Domain name: $DOMAIN_NAME"
            echo "Domain home: $DOMAIN_HOME"
        done
    fi


    if [ -z "$DOMAIN_HOME" ] || [ -z "$DOMAIN_OWNER" ] || [ -z "$OHS_INSTANCE" ]; then
        echo "Running OHS processes not found."

        #
        # OHS manual parametrisation
        #

        # ask for username and test
        test -z "$DOMAIN_OWNER" && read -p "Enter OHS domain owner name:" DOMAIN_OWNER

        DOMAIN_OWNER_TEST=$(sudo su - $DOMAIN_OWNER -c 'echo $(whoami)' | tail -1) # tail -1 is used to eliminate potential ssh banner
        test -z "$DOMAIN_OWNER_TEST" && unset DOMAIN_OWNER

        # get domain home from users's env, ask for, and test
        test -z "$DOMAIN_HOME" && DOMAIN_HOME=$(sudo su - $DOMAIN_OWNER -c 'echo $DOMAIN_HOME' | tail -1) # tail -1 is used to eliminate potential ssh banner
        
        test -z "$DOMAIN_HOME" && read -p "Enter OHS domain home directory:" DOMAIN_HOME

        DOMAIN_HOME_TEST=$(sudo su - $DOMAIN_OWNER -c "ls $DOMAIN_HOME/bin/startComponent.sh")
        test -z "$DOMAIN_HOME_TEST" && unset DOMAIN_HOME

        # ask for instance name
        test -z "$OHS_INSTANCE" && read -p "Enter OHS instance name:" OHS_INSTANCE
  
        OHS_INSTANCE_TEST=$(sudo su - $DOMAIN_OWNER -c "ls $DOMAIN_HOME/config/fmwconfig/components/OHS/instances/$OHS_INSTANCE") # tail -1 is used to eliminate potential ssh banner
        test -z "$OHS_INSTANCE_TEST" && unset OHS_INSTANCE
    fi

    if [ ! -z "$DOMAIN_OWNER" ] && [ ! -z "$DOMAIN_HOME" ] && [ ! -z "$OHS_INSTANCE" ]; then
        setcfg $ohs_identifier DOMAIN_OWNER $DOMAIN_OWNER force 2>/dev/null
        setcfg $ohs_identifier DOMAIN_HOME $DOMAIN_HOME force 2>/dev/null
        setcfg $ohs_identifier OHS_INSTANCE $OHS_INSTANCE force 2>/dev/null
    fi
fi

export DOMAIN_OWNER
export DOMAIN_HOME
export OHS_INSTANCE

if [ -z "$DOMAIN_OWNER" ] || [ -z "$DOMAIN_HOME" ] || [ -z "$OHS_INSTANCE" ]; then
    echo "OHS parameters are not valid:"
    echo "- OHS instance: $OHS_INSTANCE"
    echo "- OHS owner: $DOMAIN_OWNER"
    echo "- Domain home: $DOMAIN_HOME"
    echo 
    echo  "Exiting."
    exit 1
fi

# final test of DOMAIN_HOME 
DOMAIN_HOME_TEST=$(sudo su - $DOMAIN_OWNER -c "ls $DOMAIN_HOME/config/fmwconfig/components/OHS/instances/$OHS_INSTANCE")
if [ -z "$DOMAIN_HOME_TEST" ]; then
    echo "Cannot access OHS instance home. OHS parameters:"
    echo "- OHS instance: $OHS_INSTANCE"
    echo "- OHS owner: $DOMAIN_OWNER"
    echo "- Domain home: $DOMAIN_HOME"
    echo 
    echo  "are not set or wrong. Directory $DOMAIN_HOME/config/fmwconfig/components/OHS/instances/$OHS_INSTANCE cannot be accessed. Exiting."
    exit 1
fi

#
# run
#

cat <<EOF
Running for OHS:
- OHS instance: $OHS_INSTANCE
- OHS owner:    $DOMAIN_OWNER
- Domain home:  $DOMAIN_HOME

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
    ohs)
        start_service="$DOMAIN_HOME/bin/startComponent.sh $OHS_INSTANCE"
        stop_service="$DOMAIN_HOME/bin/stopComponent.sh $OHS_INSTANCE"
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
