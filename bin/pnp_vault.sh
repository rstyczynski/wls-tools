#!/bin/bash

pnp_vault_debug=0
pnp_always_replace=0
lock_fd=8

#
# helper
# 

function get_seed() {
    local privacy="$1"

    case $privacy in
        script)
            if [ -f $0 ]; then
                local seed=$(stat -c %i%g $0 | sha256sum | cut -f1 -d' ')
            else
                >&2 echo 'Warning. Script level privacy chosen, but running from shell. Falling to user level privacy.'
                local seed=$(stat -c %i%g ~ | sha256sum | cut -f1 -d' ')
            fi
            ;;
        user)
            local seed=$(stat -c %i%g ~ | sha256sum | cut -f1 -d' ')
            ;;
        host)
            local seed=$(stat -c %i%g /etc  | sha256sum | cut -f1 -d' ')
            ;;
        *)
            >&2 echo 'Error. Privacy level not known. Falling to user level privacy.'
            local seed=$(stat -c %i%g ~ | sha256sum | cut -f1 -d' ')
            ;;
    esac
    [ $pnp_vault_debug -gt 0 ] && echo $seed

    echo $seed
}

#
# main
#

function read_secret() {
    local key="$1"
    local privacy="$2"

    if [ -z "$key" ]; then
        >&2 echo "usage: read_secret key user|host|script"
        return 1
    fi


    if [ -z "$internal_read" ]; then
        # lock dataset for changes
        exec 8>~/etc/secret.lock
        flock -x -w 5 $lock_fd
        if [ $? -ne 0 ]; then
            echo "Error. Other process keeps dataset."
            return 127
        fi
    fi

    : ${privacy:=user}

    umask 077

    local seed=$(get_seed $privacy)

    local lookup_code=$(echo $(hostname)\_$key | sha256sum | cut -f1 -d' ')
    [ $pnp_vault_debug -gt 0 ] && echo $lookup_code


    local element_pos=0
    local lookup_code_element=.
    local lookup_result=true
    unset value
    while [ ! -z "$lookup_code_element" ]; do

        local lookup_code_element=${lookup_code:$element_pos:1}
        if [ ! -z "$lookup_code_element" ]; then
            local lookup_code_element_value=$((16#$lookup_code_element))
            local seed_element=${seed:$lookup_code_element_value:1}
            [ $pnp_vault_debug -gt 0 ] && echo $element_pos, $lookup_code_element, $lookup_code_element_value, $seed_element
            
            local lookup_code_seed=$(echo $seed_element$element_pos$lookup_code | sha256sum | cut -f1 -d' ')
            [ $pnp_vault_debug -gt 0 ] && echo $lookup_code_seed

            if [ -z "$internal_read" ]; then
                secret_repo=~/etc/secret
            else
                secret_repo=$internal_read
            fi

            if [ $pnp_always_replace -eq 1 ]; then 
                local kv=$(grep $lookup_code_seed $secret_repo/$seed_element 2>/dev/null | head -1)    
            else
                local kv=$(grep $lookup_code_seed $secret_repo/$seed_element 2>/dev/null | tail -1)
            fi

            if [ -z "$kv" ]; then
                if [ -z "$value" ]; then
                    [ $pnp_vault_debug -gt 0 ] && echo "Not found"
                    lookup_result=false
                else
                    lookup_result=true
                    [ $pnp_vault_debug -gt 0 ] && echo "Value: $value"
                fi
                break
            else
                local value_element=$(echo "$kv" | cut -d' ' -f2)
                local value="$value$value_element"
            fi
            element_pos=$(( $element_pos + 1 ))
        fi
    done
    
    if [ -z "$internal_read" ]; then
        # remove lock
        flock -u $lock_fd
        rm ~/etc/secret.lock
    fi

    if [ "$lookup_result" = "true" ]; then
        echo "$value"
        return 0
    else
        return 1
    fi
}

function save_secret() {
    local key="$1"
    local value="$2"
    local privacy="$3"

    umask 077

    if [ -z "$key" ]; then
        >&2  echo "usage: save_secret key value user|host|script"
        return 1
    fi

    if [ -z "$value" ]; then
        >&2 echo "usage: save_secret key value user|host|script"
        return 1
    fi

    if [ ! -d ~/etc ]; then 
        >&2 echo "Note: cfg directory does not exist. Creating ~/etc"
        mkdir ~/etc
    fi

    if [ "$(stat -c %a ~/etc)" != "700" ]; then
        >&2 echo "Note: Wrong cfg directory access rights. Fixing ~/etc to 0700"
        chmod 0700 ~/etc
    fi

    if [ ! -d ~/etc/secret ]; then
        mkdir -p ~/etc/secret
    fi        

    # lock dataset for changes
    exec 8>~/etc/secret.lock
    flock -x -w 5 $lock_fd
    if [ $? -ne 0 ]; then
        echo "Error. Other process keeps dataset."
        return 127
    fi

    rm -rf ~/etc/secret.tx
    mkdir -p ~/etc/secret.tx
    cp ~/etc/secret/* ~/etc/secret.tx

    rm -rf ~/etc/secret.prev
    mv ~/etc/secret ~/etc/secret.prev

    : ${privacy:=user}

    if [ $pnp_always_replace -eq 1 ]; then
        internal_read=~/etc/secret.tx
        delete_secret $key $privacy
        unset internal_read
    fi

    local seed=$(get_seed $privacy)

    local lookup_code=$(echo $(hostname)\_$key | sha256sum | cut -f1 -d' ')
    [ $pnp_vault_debug -gt 0 ] && echo $lookup_code

    local element_pos=0
    local lookup_code_element=.
    while [ ! -z "$lookup_code_element" ]; do
        local lookup_code_element=${lookup_code:$element_pos:1}
        if [ ! -z "$lookup_code_element" ]; then
            local lookup_code_element_value=$((16#$lookup_code_element))
            local seed_element=${seed:$lookup_code_element_value:1}

            [ $pnp_vault_debug -gt 0 ] && echo $element_pos, $lookup_code_element, $lookup_code_element_value, $seed_element
            
            local lookup_code_seed=$(echo $seed_element$element_pos$lookup_code | sha256sum | cut -f1 -d' ')
            local value_element=${value:$element_pos:1}

            [ $pnp_vault_debug -gt 0 ] && echo $value_element

            if [ ! -z "$value_element" ]; then
                echo "$lookup_code_seed $value_element" >> ~/etc/secret.tx/$seed_element
            else
                break
            fi
            element_pos=$(( $element_pos + 1 ))
        fi
    done

    #
    # verification
    #
    internal_read=~/etc/secret.tx 
    read_value=$(read_secret $key $privacy)
    unset internal_read
    if [ "$value" != "$read_value" ]; then
        echo "Error writing key due to low entropy. Retry with different key. This key is lost."
    
        echo "$key : $value vs. $read_value" 

        rm -rf ~/etc/secret.tx
        rm -rf ~/etc/secret
        mv ~/etc/secret.prev ~/etc/secret

        # remove lock
        flock -u $lock_fd
        rm ~/etc/secret.lock
        return 10
    else

        rm -rf ~/etc/secret.prev
        rm -rf ~/etc/secret
        mv ~/etc/secret.tx ~/etc/secret

        # shuffle entries to eliminate entry order
        if [ $pnp_always_replace -eq 1 ]; then

            rm -rf ~/etc/secret.shuffle
            mkdir ~/etc/secret.shuffle
            for secret in ~/etc/secret/*; do
                shuf $secret > ~/etc/secret.shuffle/$(basename $secret)
            done
            rm -rf ~/etc/secret
            mv ~/etc/secret.shuffle ~/etc/secret
        
        fi

        # remove lock
        flock -u $lock_fd
        rm ~/etc/secret.lock
    fi

}


function delete_secret() {
    local key="$1"
    local privacy="$2"

    umask 077

    if [ -z "$key" ]; then
        >&2  echo "usage: delete_secret key  user|host|script"
        return 1
    fi

    if [ ! -d ~/etc ]; then 
        >&2 echo "Note: cfg directory does not exist. Creating ~/etc"
        mkdir ~/etc
    fi

    if [ "$(stat -c %a ~/etc)" != "700" ]; then
        >&2 echo "Note: Wrong cfg directory access rights. Fixing ~/etc to 0700"
        chmod 0700 ~/etc
    fi

    if [ ! -d ~/etc/secret ]; then
        mkdir -p ~/etc/secret
    fi        

    if [ -z "$internal_read" ]; then
        # lock dataset for changes
        exec 8>~/etc/secret.lock
        flock -x -w 5 $lock_fd
        if [ $? -ne 0 ]; then
            echo "Error. Other process keeps dataset."
            return 127
        fi
    fi

    : ${privacy:=user}

    local seed=$(get_seed $privacy)

    local lookup_code=$(echo $(hostname)\_$key | sha256sum | cut -f1 -d' ')
    [ $pnp_vault_debug -gt 0 ] && echo $lookup_code

    rm -rf ~/etc/secret.delete
    mkdir ~/etc/secret.delete
    if [ -z "$internal_read" ]; then
        secret_repo=~/etc/secret
    else   
        secret_repo=$internal_read
    fi

    cp $secret_repo/* ~/etc/secret.delete

    local element_pos=0
    local lookup_code_element=.
    while [ ! -z "$lookup_code_element" ]; do
        local lookup_code_element=${lookup_code:$element_pos:1}

        if [ ! -z "$lookup_code_element" ]; then
            local lookup_code_element_value=$((16#$lookup_code_element))
            local seed_element=${seed:$lookup_code_element_value:1}

            [ $pnp_vault_debug -gt 0 ] && echo $element_pos, $lookup_code_element, $lookup_code_element_value, $seed_element
            
            local lookup_code_seed=$(echo $seed_element$element_pos$lookup_code | sha256sum | cut -f1 -d' ')

            if [ -f ~/etc/secret.delete/$seed_element ]; then
                cat ~/etc/secret.delete/$seed_element | sed "/^$lookup_code_seed/d"  > ~/etc/secret.delete/$seed_element.new
                mv ~/etc/secret.delete/$seed_element.new ~/etc/secret.delete/$seed_element
            fi

            element_pos=$(( $element_pos + 1 ))
        fi
    done


    rm -rf $secret_repo
    mv ~/etc/secret.delete $secret_repo

    if [ -z "$internal_read" ]; then
        # remove lock
        flock -u $lock_fd
        rm ~/etc/secret.lock
    fi
}

function pnp_vault_test() {
    rounds=$1 

    : ${rounds:=10}

    rm -rf /tmp/pnp_vault_test.tmp
    pnp_always_replace=0
    echo -n "Save test:"
    for cnt in $(eval echo {1..$rounds}); do
        key=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1) 
        value=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1)
        save_secret "$key" "$value"

        read_value=$(read_secret $key)

        echo "$key $value $read_value" >>/tmp/pnp_vault_test.tmp

        if [ "$read_value" == "$value" ]; then
            echo -n +
        fi
    done
    echo 

    echo -n "Replace test:"
    pnp_always_replace=0
    for cnt in $(eval echo {1..$rounds}); do
        key=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1)        
        
        value=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1)
        save_secret "$key" "$value"
        
        value=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1)
        save_secret "$key" "$value"
        
        value=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1)
        save_secret "$key" "$value"
        
        value=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1)
        save_secret "$key" "$value"

        read_value=$(read_secret $key)

        echo "$key $value $read_value" >>/tmp/pnp_vault_test.tmp

        if [ "$read_value" == "$value" ]; then
            echo -n +
        else
            echo -n "-"
            echo 
            echo "$key : $value vs. $read_value" 
        fi
    done
    echo 

    echo -n "Replace test with delete and reshuffle:"
    pnp_always_replace=1
    for cnt in $(eval echo {1..$rounds}); do
        key=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 8 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1)       
        
        value=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1)
        save_secret "$key" $value

        value=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1)
        save_secret "$key" $value
        
        value=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1)
        save_secret "$key" $value

        value=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1)
        save_secret "$key" $value

        read_value=$(read_secret "$key")
        
        echo "$key $value $read_value" >>/tmp/pnp_vault_test.tmp

        if [ "$read_value" == "$value" ]; then
            echo -n "+"
        else
            echo -n "-"
            echo 
            echo "$key : $value vs. $read_value" 
        fi
    done
    echo

    rm -rf /tmp/pnp_vault_reread.tmp
    for key in $(cat /tmp/pnp_vault_test.tmp | cut -f1 -d' '); do
        read_value="$(read_secret "$key")"
        echo "$key $read_value"
        echo "$key $read_value $read_value" >>/tmp/pnp_vault_reread.tmp
    done
    diff  /tmp/pnp_vault_test.tmp /tmp/pnp_vault_reread.tmp

    #rm /tmp/pnp_vault_reread.tmp
    #rm /tmp/pnp_vault_test.tmp
    echo Done.
}


#
# 
#
function usage() {
    cat <<EOF
usage: pnp_vault save|read|delete key [value] [privacy]

, where
privacy user|host|script with default user

EOF
}

function __main__() {
    operation=$1; shift

    case $operation in
        save)
            save_secret $@
            ;;
        read)
            read_secret $@
            ;;
        delete)
            delete_secret $@
            ;;
        test)
            pnp_vault_test $@
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

# prevent staring main in source mode
[ -f $0 ] && __main__ $@
