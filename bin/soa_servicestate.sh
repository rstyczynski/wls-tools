#!/bin/bash

# parameters
wls_env=$1
wls_name=$2


function oci_notification() {
    local oci_notification_msg=$1

    timeout 30 oci ons message publish --topic-id $oci_topic_id --body "$oci_notification_msg"
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        err_msg="Error sending OCI notification. Code: $exit_code"
        echo $err_msg
        loggger "$script_code: $err_msg"
    fi
}

function stop() {
    error_code=$1
    [ -z "$error_code" ] && error_code=0

    rm -rf /tmp/$$\_$script_code
    exit $error_code
}

function usage(){
    echo "Usage: soa_service_state env server_name"
    stop 1
}

if [ -z "$wls_env" ]; then
    usage
    stop 1
fi

if [ -z "$wls_name" ]; then
    usage
    stop 1
fi

if [ ! -d ~/etc ]; then 
    echo "Note: cfg directory does not exist. Creating ~/etc"
    mkdir ~/etc
fi

if [ "$(stat -c %a ~/etc)" != "700" ]; then
    echo "Note: Wrong cfg directory access rights. Fixing ~/etc to 700"
    chmod 700 ~/etc
fi

#
#
#

script_code=soa_servicestate
tmp=/tmp/$$\_$script_code; mkdir -p $tmp

# clean up after ctrl-break
trap stop INT

# set / get parameters
function getParameters() {

    # address
    lookup_code=$(echo $(hostname)\_$wls_env\_$wls_name\_ip)
    wls_ip=$(cat ~/etc/soa.cfg | grep "$lookup_code" | tail -1 | cut -d= -f2 )
    if [ -z "$wls_ip" ]; then
        read -t 15 -p 'wls_ip:' wls_ip
        if [ $? -ne 0 ]; then
            echo 'Error: server address not known and not privided.'
            return 1
        else
            echo "$lookup_code=$wls_ip" >>~/etc/soa.cfg
            chmod 600 ~/etc/soa.cfg
        fi
    fi

    # port
    lookup_code=$(echo $(hostname)\_$wls_env\_$wls_name\_port)
    wls_port=$(cat ~/etc/soa.cfg | grep "$lookup_code" | tail -1 | cut -d= -f2 )
    if [ -z "$wls_port" ]; then
        read -t 15 -p 'wls_port:' wls_port
        if [ $? -ne 0 ]; then
            echo 'Error: server port not known and not privided.'
            return 1
        else
            echo "$lookup_code=$wls_port" >>~/etc/soa.cfg
            chmod 600 ~/etc/soa.cfg
        fi
    fi

    # error handler ip
    lookup_code=$(echo $(hostname)\_$wls_env\_$wls_name\_csf_ip)
    csf_ip=$(cat ~/etc/soa.cfg | grep "$lookup_code" | tail -1 | cut -d= -f2 )
    if [ -z "$csf_ip" ]; then
        read -t 15 -p 'csf_ip:' csf_ip
        if [ $? -ne 0 ]; then
            echo 'Error: error handler address not known and not privided.'
            return 1
        else
            echo "$lookup_code=$csf_ip" >>~/etc/soa.cfg
            chmod 600 ~/etc/soa.cfg
        fi
    fi

    #error handler port
    lookup_code=$(echo $(hostname)\_$wls_env\_$wls_name\_csf_port)
    csf_port=$(cat ~/etc/soa.cfg | grep "$lookup_code" | tail -1 | cut -d= -f2 )
    if [ -z "$csf_port" ]; then
        read -t 15 -p 'csf_port:' csf_port
        if [ $? -ne 0 ]; then
            echo 'Error: Error handler port not known and not privided.'
            return 1
        else
            echo "$lookup_code=$csf_port" >>~/etc/soa.cfg
            chmod 600 ~/etc/soa.cfg
        fi
    fi

    #oci notification topic id
    lookup_code=$(echo $(hostname)\_$wls_env\_$wls_name\_oci_topic_id)
    oci_topic_id=$(cat ~/etc/soa.cfg | grep "$lookup_code" | tail -1 | cut -d= -f2 )
    if [ -z "$oci_topic_id" ]; then
        read -t 15 -p 'oci_topic_id:' oci_topic_id
        if [ $? -ne 0 ]; then
            echo 'Error: oci_topic_id not known and not privided.'
            return 1
        else
            echo "$lookup_code=$oci_topic_id" >>~/etc/soa.cfg
            chmod 600 ~/etc/soa.cfg
        fi
    fi

    # username
    lookup_code=$(echo $(hostname)_$wls_env\_$wls_ip\_$wls_port\_user\_$script_code | sha256sum | cut -f1 -d' ')
    wls_user=$(cat ~/etc/secrets.cfg | grep "$lookup_code" | tail -1 | cut -d= -f2)
    if [ -z "$wls_user" ]; then
        read -t 15 -p 'wls_user:' wls_user
        if [ $? -ne 0 ]; then
            echo 'Error: user name not known and not privided.'
            return 1
        else
            echo "$lookup_code=$wls_user" >>~/etc/secrets.cfg
            chmod 600 ~/etc/secrets.cfg
        fi
    fi

    # password
    lookup_code=$(echo $(hostname)\_$wls_env\_$wls_ip\_$wls_port\_pass\_$script_code | sha256sum | cut -f1 -d' ')
    wls_pass=$(cat ~/etc/secrets.cfg | grep "$lookup_code" | tail -1 | cut -d= -f2)
    if [ -z "$wls_pass" ]; then
        read -t 15 -s -p 'wls_pass:' wls_pass
        if [ $? -ne 0 ]; then
            echo 'Error: password not known and not privided.'
            return 1
        else
            echo "$lookup_code=$wls_pass" >>~/etc/secrets.cfg
            chmod 600 ~/etc/secrets.cfg
        fi
    fi

    lookup_code=$(echo $(hostname)\_$wls_env\_$wls_ip\_$wls_port\_csf_auth\_$script_code | sha256sum | cut -f1 -d' ')
    csf_auth=$(cat ~/etc/secrets.cfg | grep "$lookup_code" | tail -1 | cut -d= -f2)
    if [ -z "$csf_auth" ]; then
        read -t 15 -s -p 'csf_auth:' csf_auth
        if [ $? -ne 0 ]; then
            echo 'Error: csf_auth not known and not privided.'
            return 1
        else
            echo "$lookup_code=$csf_auth" >>~/etc/secrets.cfg
            chmod 600 ~/etc/secrets.cfg
        fi
    fi

}

# send service state to CSF
function reportCompositeDown() {
    composite_name=$1

    reporting_date=$(date --rfc-3339=ns | tr ' ' T)
    payload=$tmp/payload.xml
    cat >$payload <<EOF
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:v1="http://www.alshaya.com/phoenix/integrations/schemas/common/ProcessLogMessage/v1.0">
   <soapenv:Header/>
   <soapenv:Body>
      <v1:ErrorHandlerInput>
         <ErrorCode xmlns="">SVCMON001-01</ErrorCode>
         <ErrorMessage xmlns="">Composite is down</ErrorMessage>
         <IntegrationId xmlns="">INTMON001</IntegrationId>
         <SubIntegrationId xmlns="">00022458281</SubIntegrationId>
         <InstanceId xmlns="">$composite_name</InstanceId>
         <SecondaryId xmlns="">NONE1</SecondaryId>
         <ReportingDate xmlns="">$reporting_date</ReportingDate>
         <ComponentType xmlns="">BPEL</ComponentType>
         <ComponentId xmlns="">NONE2</ComponentId>
         <ProcessStage xmlns="">Composite Monitoring Component</ProcessStage>
      </v1:ErrorHandlerInput>
   </soapenv:Body>
</soapenv:Envelope>
EOF

    timeout 5 curl -X POST http://$csf_ip:$csf_port/soa-infra/services/common/CommonErrorHandler/CommonErrorHandlerService \
    -H "Content-Type: text/xml" \
    -H "Authorization: Basic $csf_auth" \
    -H "SOAPAction: processExceptionMsg" \
    -d @$payload
    return_code=$?

    return $return_code
}


# get all parameters
getParameters
if [ $? -ne 0 ]; then
    err_msg='Error getting parameters. Service check not performed.'
    echo $err_msg
    stop 2
fi

# invoke service check
comp_file=$tmp/composites.txt
rm -rf $comp_file
export CONFIG_JVM_ARGS=-Djava.security.egd=file:/dev/./urandom
timeout 60 $MW_HOME/oracle_common/common/bin/wlst.sh -skipWLSModuleScanning <<EOF
wls_ip     = '$wls_ip'
wls_port   = '$wls_port'
wls_user   = '$wls_user'
wls_pass   = '$wls_pass'

old_stdout = sys.stdout
sys.stdout = open('$comp_file', 'w')
sca_listDeployedComposites(wls_ip,wls_port,wls_user,wls_pass)
sys.stdout = old_stdout
exit()
EOF
exit_code=$?
if [ $exit_code -ne 0 ]; then
    err_msg="Error starting WLST: $MW_HOME/oracle_common/common/bin/wlst.sh. Code: $exit_code. Details: $(cat $comp_file | head -10)"
    echo $err_msg
    oci_notification "$err_msg"
    stop 3
fi

grep 'isDefault=true' $comp_file >/dev/null
if [ $? -ne 0 ]; then
    err_msg="Error getting service state. Service check not performed. Cause: $(cat $comp_file)"
    echo $err_msg
    oci_notification "$err_msg"
    stop 4
fi

# report
services_down=$(cat $comp_file | grep 'isDefault=true' | grep 'mode=active' | grep 'state=off' | cut -f2 -d' ' | cut -f1 -d, | sort)
services_down_cnt=$(cat $comp_file | grep 'isDefault=true' | grep 'mode=active' | grep 'state=off' | cut -f2 -d' ' | cut -f1 -d, | sort | wc -l)
if [ $services_down_cnt -eq 0 ]; then
    err_msg="All good. All services up."
    echo $err_msg
    oci_notification "$err_msg"
else
    echo "Services down. Sending notifications."
    delivery_error=0
    delivery_cnt=0
    for svc_name in $services_down; do
        reportCompositeDown $svc_name
        if [ $? -eq 0 ]; then
            delivery_ok=$(( $delivery_ok + 1 ))
        else
            err_msg="Error sending notification."
            echo $err_msg
            delivery_error=$(( $delivery_error + 1 ))
        fi
    done
    err_msg="Services down. Discovered:$services_down_cnt, reported:$delivery_ok, not reported: $delivery_error.
Check CSF logs for details."

    oci_notification "$err_msg"
fi

echo "Done."
stop