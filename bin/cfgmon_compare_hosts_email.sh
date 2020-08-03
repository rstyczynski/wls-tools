#!/bin/bash

source ~/etc/smtp.cfg

cfgmon_root=~/cfgmon

cfgmon_server=$(cat ~/etc/compare.hosts.cfg | grep '^cfgmon_server' | cut -d= -f2)
cfgmon_jump=$(cat ~/etc/compare.hosts.cfg | grep '^cfgmon_jump' | cut -d= -f2)
TO_EMAIL_ADDRESS=$(cat ~/etc/compare.hosts.cfg | grep '^email_to' | cut -d= -f2)

reports_pdf=$(ls $cfgmon_root/reports/*.pdf)
for report_pdf in $reports_pdf; do

    report_dir=$(echo $report_pdf | sed 's/.pdf//')
    source $report_dir/parameters

    EMAIL_SUBJECT="Diff report: $left_instance vs. $right_instance"

    timeout 30 mailx -v \
        -S nss-config-dir=/etc/pki/nssdb/ \
        -S smtp-use-starttls \
        -S ssl-verify=ignore \
        -S smtp=smtp://$SMTP_ADDRESS:$SMTP_PORT \
        -S from=$FROM_EMAIL_ADDRESS \
        -S smtp-auth-user=$ACCOUNT_USER \
        -S smtp-auth-password=$ACCOUNT_PASSWORD \
        -S smtp-auth=plain \
        -a $report_pdf \
        -s "$EMAIL_SUBJECT" \
        $TO_EMAIL_ADDRESS << EOF
Hello!

find attached diff report for $left_instance vs. $right_instance. You will receive such report every week. 

The report is refreshed four times a day for the following instance combinations:
$(cat ~/etc/compare.hosts.cfg | egrep '^compare_set[0-9]+=' | cut -d= -f2)

, to be avilable online at http://  (remove) $cfgmon_server/cfgmon/reports/$(basename $report_dir).

To access reports from your PC, set port forwarding in SSH usign putty or like this: 

ssh -J you@$cfgmon_jump -L 6501:$cfgmon_server:80 you@$cfgmon_server

and reach the report at http://  (remove) localhost:6501/cfgmon/reports/$(basename $report_dir).

---

Note that at http://  (remove) localhost:6501/cfgmon/servers you have available repository of server configuration collected for subset of machines. Do you want to know current patchset for $left_host? Just point your browser to: http://  (remove) localhost:6501/cfgmon/servers/$left_host/current/wls/domain/middleware/opatch/patches

From Project VCN you can use curl i.e. 

curl http://  (remove) $cfgmon_server/cfgmon/servers/$left_host/current/wls/domain/middleware/opatch/patches
$(curl http://$cfgmon_server/cfgmon/servers/$left_host/current/wls/domain/middleware/opatch/patches)

Interested in current JVM args? You have it as easy as executing curl. 

curl http://  (remove) $cfgmon_server/cfgmon/servers/$left_host/current/wls/domain/runtime/servers/$left_instance/jvm/args
$(curl http://$cfgmon_server/cfgmon/servers/$left_host/current/wls/domain/runtime/servers/$left_instance/jvm/args)

Want fo compare patches? Not a problem.

left_host=$left_host
right_host=$right_host
curl http://  (remove) $cfgmon_server/cfgmon/servers/$left_host/current/wls/domain/middleware/opatch/patches > /tmp/left.patches
curl http://  (remove) $cfgmon_server/cfgmon/servers/$right_host/current/wls/domain/middleware/opatch/patches > /tmp/right.patches
sdiff /tmp/left.patches /tmp/right.patches
$(curl http://$cfgmon_server/cfgmon/servers/$left_host/current/wls/domain/middleware/opatch/patches > /tmp/left.patches;
curl http://$cfgmon_server/cfgmon/servers/$right_host/current/wls/domain/middleware/opatch/patches > /tmp/right.patches;
sdiff /tmp/left.patches /tmp/right.patches)

Browse for available data at http://  (remove) $cfgmon_server/cfgmon/servers/

Regards
Ryszard Styczynski
EOF

done
