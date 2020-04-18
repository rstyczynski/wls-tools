#!/bin/bash

function xml_tools::getCmplexNodes() {
    xml_file=$1
    xml_anchor=$2

    #
    # Brute force way of getting children
    # XML file MUST be correctly formatted with space indents
    #
    top_tag=$(xmllint --xpath "$xml_anchor" $xml_file | head -1 | tr -d '<' | tr -d '>' )
    indent=$(xmllint --xpath "$xml_anchor" $xml_file | grep -v "$top_tag>" | head -1 | tr -cd ' \t' | wc -c)

    xmllint --xpath "$xml_anchor" $xml_file | 
    grep -v "$top_tag>" | 
    cut -b$(( $indent +1 ))-99999 | 
    grep -v '^ ' | 
    grep -v '</'  |
    tr -d '<' | tr -d '>' 
}

function xml_tools::node2DSV() {
    xml_file=$1
    key_pfx=$2
    received_xml_anchor=$3
    received_complex_nodes=$4

    # echo "dumpComplexNodes: $key_pfx"
    # echo ">> $xml_anchor"
    # echo ">> $received_complex_nodes"
    for section in $received_complex_nodes; do

        # echo "section:>>$section<<"
        if [ "$section" != '.' ]; then
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
                value=$(xmllint --xpath "$xml_anchor/$node/text()" $xml_file)
            fi

            if [ "$section" != '.' ]; then
                echo "$key_pfx$delim$section$delim$node = $value"
            else
                echo "$key_pfx$delim$node = $value"
            fi
        done

        #complex
        # #echo "final complex:$xml_anchor/*[(*)]"
        # complex_nodes=$(xmllint --xpath "$xml_anchor/*[(*)]" $xml_file 2>/dev/null | 
        # sed 's/></>\n</g' |      # newlines when tags are one ater another
        # grep -v '^ ' |           # remove all with indent i.e. children 
        # tr -d '<' | tr -d '>' |  # remove xml chars
        # grep -v '^/')            # remove closing tag

        #echo xml_tools::getCmplexNodes $xml_file $xml_anchor
        complex_nodes=$(xml_tools::getCmplexNodes $xml_file $xml_anchor)
        #echo $complex_nodes

        if [ ! -z "$complex_nodes" ]; then
            # run in subshell
            if [ "$section" != "." ]; then
                (xml_tools::node2DSV $xml_file "$key_pfx$delim$section" $xml_anchor "$complex_nodes")
            else
                (xml_tools::node2DSV $xml_file "$key_pfx" $xml_anchor "$complex_nodes")
            fi

        fi
    done
}



