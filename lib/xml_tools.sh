#!/bin/bash

function xml_tools::node2DSV() {
    xml_file=$1
    key_pfx=$2
    received_xml_anchor=$3
    received_complex_nodes=$4

    # echo "dumpComplexNodes: $key_pfx"
    # echo ">> $xml_anchor"
    # echo ">> $received_complex_nodes"
    for section in $received_complex_nodes; do

        if [ "$section" != "." ]; then
            xml_anchor="$received_xml_anchor/$section"
        else
            xml_anchor="$received_xml_anchor"
        fi
        #basic
        #echo basic: "$xml_anchor/*[not(*)]"
        basic_nodes=$(xmllint --xpath "$xml_anchor/*[not(*)]" $xml_file 2>/dev/null | sed 's/></>\n</g' | tr '>' '<' | cut -d'<' -f2)
        # print values
        for node in $basic_nodes; do
            echo $node | grep "/$" >/dev/null
            if [ $? -eq 0 ]; then
                # tag w/o value
                value="(exist)"
            else
                #echo "value:$xml_anchor/$node/text()"
                value=$(cxmllint --xpath "$xml_anchor/$node/text()" $xml_file)
            fi

            if [ "$section" != "." ]; then
                echo "$key_pfx$delim$section$delim$node = $value"
            else
                echo "$key_pfx$delim$node = $value"
            fi
        done

        #complex
        #echo "final complex:$xml_anchor/*[(*)]"
        complex_nodes=$(xmllint --xpath "$xml_anchor/*[(*)]" $xml_file 2>/dev/null | sed 's/></>\n</g' | grep -v '^ ' | tr -d '<' | tr -d '>')
        if [ ! -z "$complex_nodes" ]; then
            # run in subshell
            if [ "$section" != "." ]; then
                (dumpComplexNodes "$key_pfx$delim$section" $xml_anchor "$complex_nodes")
            else
                (dumpComplexNodes $xml_file "$key_pfx" $xml_anchor "$complex_nodes")
            fi

        fi
    done
}
