#!/bin/bash

$HOME/umc/lib/os-service.sh os-probe.yaml stop

# init cron
cron_section_start="# START umc - os"
cron_section_stop="# STOP umc - os"

(crontab -l 2>/dev/null | 
sed "/$cron_section_start/,/$cron_section_stop/d") | crontab -
