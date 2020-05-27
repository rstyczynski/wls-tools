#!/bin/bash

rounds=$1 

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

: ${rounds:=10}

pnp_always_replace=1
rm -rf /tmp/pnp_vault_test.tmp
echo -n "Save test:"
for cnt in $(eval echo {1..$rounds}); do
    key1=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' | fold -w 32| sed 's/[\x01-\x1F\x7F]/x/g' | head  -1) 
    value1=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' | fold -w 32 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1)
    $DIR/pnp_vault.sh save "$key1" "$value1"

    read_value1=$($DIR/pnp_vault.sh read $key1)

    echo "$key1 $value1 $read_value1" >>/tmp/pnp_vault_test.tmp

    if [ "$read_value1" == "$value1" ]; then
        echo -n +
    else
        echo -n "-"
        echo 
        echo "$key1 : $value1 vs. $read_value1" 
    fi
done
echo 

echo -n "Replace test:"
pnp_always_replace=1
for cnt in $(eval echo {1..$rounds}); do
    key=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' | fold -w 32 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1)        
    
    value=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' | fold -w 32 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1)
    $DIR/pnp_vault.sh save "$key" "$value"
    
    value=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' | fold -w 32 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1)
    $DIR/pnp_vault.sh save "$key" "$value"
    
    value=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' | fold -w 32 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1)
    $DIR/pnp_vault.sh save "$key" "$value"
    
    value=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' | fold -w 32 | sed 's/[\x01-\x1F\x7F]/x/g' | head  -1)
    $DIR/pnp_vault.sh save "$key" "$value"

    read_value=$($DIR/pnp_vault.sh read $key)

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

rm -rf /tmp/pnp_vault_reread.tmp
for known_key in $(cat /tmp/pnp_vault_test.tmp | cut -f1 -d' '); do
    read_value="$($DIR/pnp_vault.sh read "$known_key")"
    echo "$known_key $read_value"
    echo "$known_key $read_value $read_value" >>/tmp/pnp_vault_reread.tmp
done
diff  /tmp/pnp_vault_test.tmp /tmp/pnp_vault_reread.tmp

#rm /tmp/pnp_vault_reread.tmp
#rm /tmp/pnp_vault_test.tmp
echo Done.
