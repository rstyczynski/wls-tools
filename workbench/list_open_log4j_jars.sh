function list_open_log4j_jars() {

  echo "=======================================" 
  echo "===== List log4j in open files ========"
  echo "======================================="
  echo "== host: $(hostname)" 
  echo "== user: $(whoami)" 
  echo "== date: $(date)" 
  echo "======================================="

  # check sudo rights
  timeout 1 sudo whoami >/dev/null 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "Error. Not able to sudo. Exiting...."
    return 1
  fi

  java_pids=$(ps aux | grep '/bin/java' | tr -s ' ' | grep -v 'grep --color=auto /bin/java' | cut -d' ' -f2)

  for java_pid in $java_pids; do
    echo ================
    echo Java pid:$java_pid
    echo ================

    sudo lsof -p $java_pid | grep 'log4j-core' | tr -s ' ' | cut -d' ' -f9
    if [ ${PIPESTATUS[1]} -ne 0 ];then
      echo "(log4j-core not detected in open files.)"
    fi
  done

  echo Done.
}

# run full report
list_open_log4j_jars

# just show unique files
list_open_log4j_jars | grep '^/' | sort -u




