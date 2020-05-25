#!/bin/bash

pnp_vault_debug=0

function read_secret() {
    local key=$1
    local privacy=$2

    if [ -z "$key" ]; then
        echo "usage: get_secret key"
        return 1
    fi

    : ${privacy:=script}

    umask 077

    local lookup_code=$(echo $(hostname)\_$key | sha256sum | cut -f1 -d' ')

    case $privacy in
    script)
        if [ -f $0 ]; then
            local seed=$(stat -c %i%g $0 | sha256sum | cut -f1 -d' ')
        else
            echo 'Warning. Script level privacy chosen, but running from shell. Falling to user level privacy.'
            local seed=$(stat -c %i%g ~ | sha256sum | cut -f1 -d' ')
        fi
        ;;
    user)
        local seed=$(stat -c %i%g ~ | sha256sum | cut -f1 -d' ')
        ;;
    host)
        local seed=$(hostname -f | sha256sum | cut -f1 -d' ')
        ;;
    *)
        echo 'Error. Privacy level not known. Falling to user level privacy.'
        local seed=$(hostname -f | sha256sum | cut -f1 -d' ')
        ;;
    esac

    [ $pnp_vault_debug -gt 2 ] && echo $seed
    [ $pnp_vault_debug -gt 2 ] && echo $lookup_code

    local element_pos=0
    local lookup_code_element=.
    local lookup_result=true
    unset value
    while [ ! -z "$lookup_code_element" ]; do

        local lookup_code_element=${lookup_code:$element_pos:1}
        if [ ! -z "$lookup_code_element" ]; then
            local lookup_code_element_value=$((16#$lookup_code_element))
            local seed_element=${seed:$lookup_code_element_value:1}
            [ $pnp_vault_debug -gt 2 ] && echo $element_pos, $lookup_code_element, $lookup_code_element_value, $seed_element
            
            local lookup_code_seed=$(echo $seed_element$element_pos$lookup_code | sha256sum | cut -f1 -d' ')
            [ $pnp_vault_debug -gt 2 ] && echo $lookup_code_seed

            local kv=$(grep $lookup_code_seed ~/etc/secret/$seed_element 2>/dev/null | tail -1)
            if [ -z "$kv" ]; then
                if [ -z "$value" ]; then
                    [ $pnp_vault_debug -gt 2 ] && echo "Not found"
                    lookup_result=false
                else
                    lookup_result=true
                    [ $pnp_vault_debug -gt 2 ] && echo "Value: $value"
                fi
                break
            else
                local value_element=$(echo $kv | cut -d= -f2)
                local value=$value$value_element
            fi
            element_pos=$(( $element_pos + 1 ))
        fi
    done

    if [ "$lookup_result" = "true" ]; then
        echo $value
        return 0
    else
        return 1
    fi
}

function save_secret() {
    local key=$1
    local value=$2
    local privacy=$3

    umask 077

    if [ -z "$key" ]; then
        echo "usage: save_secret key value"
        return 1
    fi

    if [ -z "$value" ]; then
        echo "usage: save_secret key value"
        return 1
    fi

    if [ ! -d ~/etc ]; then 
        echo "Note: cfg directory does not exist. Creating ~/etc"
        mkdir ~/etc
    fi

    if [ "$(stat -c %a ~/etc)" != "700" ]; then
        echo "Note: Wrong cfg directory access rights. Fixing ~/etc to 0700"
        chmod 0700 ~/etc
    fi

    if [ ! -d ~/etc/secret ]; then
        mkdir -p ~/etc/secret
    fi        

    : ${privacy:=script}

    local lookup_code=$(echo $(hostname)\_$key | sha256sum | cut -f1 -d' ')

    case $privacy in
    script)
        if [ -f $0 ]; then
            local seed=$(stat -c %i%g $0 | sha256sum | cut -f1 -d' ')
        else
            echo 'Warning. Script level privacy chosen, but running from shell. Falling to user level privacy.'
            local seed=$(stat -c %i%g ~ | sha256sum | cut -f1 -d' ')
        fi
        ;;
    user)
        local seed=$(stat -c %i%g ~ | sha256sum | cut -f1 -d' ')
        ;;
    host)
        local seed=$(hostname -f | sha256sum | cut -f1 -d' ')
        ;;
    *)
        echo 'Error. Privacy level not known. Falling to user level privacy.'
        local seed=$(hostname -f | sha256sum | cut -f1 -d' ')
        ;;
    esac

    local lookup_code=$(echo $(hostname)\_$key | sha256sum | cut -f1 -d' ')

    local element_pos=0
    local lookup_code_element=.
    while [ ! -z "$lookup_code_element" ]; do
        local lookup_code_element=${lookup_code:$element_pos:1}

        if [ ! -z "$lookup_code_element" ]; then
            local lookup_code_element_value=$((16#$lookup_code_element))
            local seed_element=${seed:$lookup_code_element_value:1}

            [ $pnp_vault_debug -gt 2 ] && echo $element_pos, $lookup_code_element, $lookup_code_element_value, $seed_element
            
            local lookup_code_seed=$(echo $seed_element$element_pos$lookup_code | sha256sum | cut -f1 -d' ')
            local value_element=${value:$element_pos:1}

            [ $pnp_vault_debug -gt 2 ] && echo $value_element

            if [ ! -z "$value_element" ]; then
                echo "$lookup_code_seed=$value_element" >> ~/etc/secret/$seed_element
                element_pos=$(( $element_pos + 1 ))
            else
                break
            fi
        fi
    done

    #reorganize secrets
    #
    # TODO: not possible w/o delete as I'm taking latest hash from each piece
    #
    # (
    # flock -x 8;
    #     rm -rf ~/etc/secret.new
    #     mkdir ~/etc/secret.new
    #     for secret in $(ls ~/etc/secret/* | grep -v lock); do
    #         sort $secret >~/etc/secret.new/$(basename $secret)
    #     done
    #     rm -rf ~/etc/secret
    #     mv ~/etc/secret.new ~/etc/secret
    # ) 8>~/etc/secret/lock
}

