
#!/bin/bash

mkdir -p /tmp/$$
tmp=/tmp/$$


function os_tcp_top() {
    echo "======================================="
    echo "===== Open TCP channels sumamry ======="
    echo "==== having more that 1 connection ===="
    echo "======================================="
    echo "== host: $(hostname)"
    echo "== user: $(whoami)"
    echo "== date: $(date)"
    echo "======================================="
    echo "======================================="
    echo "======================================="

    ss -n | grep ESTAB | grep . | tr -s ' ' | cut -f6 -d' ' | sort >$tmp/db_conns

    for db_conn in $(cat $tmp/db_conns | sort -u); do
        echo -n "=== $db_conn >> "
        cat $tmp/db_conns | grep $db_conn | wc -l
    done | sort -k3 -t'>' -n -r | grep -v '>> 1$'

    rm -rf tmp=/tmp/$$    
}


os_tcp_top $@

