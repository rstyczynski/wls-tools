function report_patches() {
    rm -f patches_all.tmp
    for inventory in ./*-inventory.txt; do
        cat $inventory | tr -s ' ' | grep -e "^Patch [0-9]" | cut -d' ' -f1,2 | sort -t' ' -k2 -n >>patches_all.tmp
    done
    cat patches_all.tmp | sort -u >patches_all

    echo "======"
    echo "Patches seen of all envs"
    echo "======"
    cat patches_all
    echo "^^^^^^^^^"
    echo

    for inventory in ./*-inventory.txt; do
        echo "======"
        echo "$inventory"
        echo "======"
        cat $inventory | tr -s ' ' | grep -e "^Patch [0-9]" | cut -d' ' -f1,2 | sort -t' ' -k2 -n >$inventory.patches
        diff $inventory.patches patches_all |
            sed 's/>/missing:/g' |
            grep missing
        echo "^^^^^^^^^"
        echo
    done

    echo "======"
    echo "Patches applied in "
    echo "======"
    IFS=$'\n'
    for patch in $(cat patches_all); do
        echo -n "$patch"
        for inventory in ./*-inventory.txt; do
            grep $patch $inventory.patches >/dev/null && echo -n "| $(echo $inventory | sed 's/-inventory.txt//g') |"
        done
        echo
    done

    rm -f patches_all
    rm -f patches_all.tmp
    rm *.patches
}

