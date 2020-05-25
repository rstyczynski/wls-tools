#!/bin/bash

# parameters
wls_env=$1
wls_name=$2


function stop() {
    error_code=$1
    [ -z "$error_code" ] && error_code=0

    rm -rf /tmp/$$\_$caller
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

if [ "$(chmod 700 ~/etc)" != "700" ]; then
    echo "Note: Wrong cfg directory access rights. Fixing ~/etc to 700"
    chmod 700 ~/etc
fi

#
#
#

caller=soa_servicestate
tmp=/tmp/$$\_$caller; mkdir -p $tmp


function getParameters() {

    # address
    lookup_code=$(echo $(hostname)\_$wls_env\_$wls_name\_ip)
    wls_ip=$(cat ~/etc/soa.cfg | grep "$lookup_code" | tail -1 | cut -d= -f2 )
    if [ -z "$wls_ip" ]; then
        read -t 5 -p 'wls_ip:' wls_ip
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
        read -t 5 -p 'wls_port:' wls_port
        if [ $? -ne 0 ]; then
            echo 'Error: server port not known and not privided.'
            return 1
        else
            echo "$lookup_code=$wls_port" >>~/etc/soa.cfg
            chmod 600 ~/etc/soa.cfg
        fi
    fi

    # error handler ip
    lookup_code=$(echo $(hostname)\_$wls_env\_$wls_name\_err_ip)
    err_ip=$(cat ~/etc/soa.cfg | grep "$lookup_code" | tail -1 | cut -d= -f2 )
    if [ -z "$err_ip" ]; then
        read -t 5 -p 'err_ip:' err_ip
        if [ $? -ne 0 ]; then
            echo 'Error: error handler address not known and not privided.'
            return 1
        else
            echo "$lookup_code=$err_ip" >>~/etc/soa.cfg
            chmod 600 ~/etc/soa.cfg
        fi
    fi

    #error handler port
    lookup_code=$(echo $(hostname)\_$wls_env\_$wls_name\_err_port)
    err_port=$(cat ~/etc/soa.cfg | grep "$lookup_code" | tail -1 | cut -d= -f2 )
    if [ -z "$err_port" ]; then
        read -t 5 -p 'err_port:' err_port
        if [ $? -ne 0 ]; then
            echo 'Error: Error handler port not known and not privided.'
            return 1
        else
            echo "$lookup_code=$err_port" >>~/etc/soa.cfg
            chmod 600 ~/etc/soa.cfg
        fi
    fi

    # username
    lookup_code=$(echo $(hostname)_$wls_env\_$wls_ip\_$wls_port\_user\_$caller | sha256sum | cut -f1 -d' ')
    wls_user=$(cat ~/etc/secrets.cfg | grep "$lookup_code" | tail -1 | cut -d= -f2)
    if [ -z "$wls_user" ]; then
        read -t 5 -p 'wls_user:' wls_user
        if [ $? -ne 0 ]; then
            echo 'Error: user name not known and not privided.'
            return 1
        else
            echo "$lookup_code=$wls_user" >>~/etc/secrets.cfg
            chmod 600 ~/etc/secrets.cfg
        fi
    fi

    # password
    lookup_code=$(echo $(hostname)\_$wls_env\_$wls_ip\_$wls_port\_pass\_$caller | sha256sum | cut -f1 -d' ')
    wls_pass=$(cat ~/etc/secrets.cfg | grep "$lookup_code" | tail -1 | cut -d= -f2)
    if [ -z "$wls_pass" ]; then
        read -t 5 -s -p 'wls_pass:' wls_pass
        if [ $? -ne 0 ]; then
            echo 'Error: password not known and not privided.'
            return 1
        else
            echo "$lookup_code=$wls_pass" >>~/etc/secrets.cfg
            chmod 600 ~/etc/secrets.cfg
        fi
    fi
}

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

    curl -X POST http://$err_ip:$err_port/soa-infra/services/common/CommonErrorHandler/CommonErrorHandlerService \
    -H "Content-Type: text/xml" \
    -H "Authorization: Basic a2F0aGlyYXZhbms6d2VsY29tZTEyMw==" \
    -H "SOAPAction: processExceptionMsg" \
    -d @$payload

}

getParameters
if [ $? -ne 0 ]; then
    echo 'Error getting parameters. Service check not performed.'
    stop 2
fi

comp_file=$tmp/composites.txt
rm -rf $comp_file
$MW_HOME/oracle_common/common/bin/wlst.sh <<EOF
wls_ip = '$wls_ip'
wls_port   = '$wls_port'
wls_user   = '$wls_user'
wls_pass   = '$wls_pass'

old_stdout = sys.stdout
sys.stdout = open('$comp_file', 'w')
sca_listDeployedComposites(wls_ip,wls_port,wls_user,wls_pass)
sys.stdout = old_stdout
exit()
EOF
if [ $? -ne 0 ]; then
    echo "Error starting WLST: $MW_HOME/oracle_common/common/bin/wlst.sh"
    stop 3
fi

grep 'isDefault=true' $comp_file >/dev/null
if [ $? -ne 0 ]; then
    echo "Error getting service state. Service check not performed. Cause: $(cat $comp_file)"
    stop 4
fi

services_down=$(cat $comp_file | grep 'isDefault=true' | grep 'mode=active' | grep 'state=off' | cut -f2 -d' ' | cut -f1 -d, | sort)
for svc_name in $services_down; do
    reportCompositeDown $svc_name
done

stop