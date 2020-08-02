#!/bin/bash


unset compareHosts
function compareHosts() {
    left_host=$1
    left_domain=$2
    left_snapshot=$3
    right_host=$4
    right_domain=$5
    right_snapshot=$6

    left_domain_home=$base_dir/$left_host/$left_snapshot/wls/$left_domain
    right_domain_home=$base_dir/$right_host/$right_snapshot/wls/$right_domain

    echo $left_domain_home vs. $right_domain_home

    cd $left_domain_home
    find . -type d | sort >$tmp/dirs_left
    cd $right_domain_home
    find . -type d | sort >$tmp/dirs_right

    diff $tmp/dirs_left $tmp/dirs_right >$tmp/diff_dirs
    if [ $? -ne 0 ]; then
        # look for extra dirs at left
        extra_left=$(cat $tmp/diff_dirs | grep '<')
        if [ ! -z "$extra_left" ]; then
            echo "MISMATCH: Missing directories at $right. Extra dirs: $extra_left"

            report_root=$base_dir/report/$left_host\_$left_domain\_$left_snapshot\_vs_$right_host\_$right_domain\_$right_snapshot
            mkdir -p $report_root
            cat $tmp/diff_dirs | grep '<' >$report_root/missing_dirs_at_right
        fi 

        # look for extra dirs at right
        extra_right=$(cat $tmp/diff_dirs | grep '>')
        if [ ! -z "$extra_right" ]; then
            echo "MISMATCH: Extra directories at $right. Extra dirs: $extra_right"

            report_root=$base_dir/report/$left_host\_$left_domain\_$left_snapshot\_vs_$right_host\_$right_domain\_$right_snapshot
            mkdir -p $report_root
            cat $tmp/diff_dirs | grep '>' >$report_root/extra_dirs_at_right
        fi 
    fi

    # apart from differences, compare dirs
    for directory in $(cat $tmp/dirs_left); do
        echo Checking $directory
        cd $left_domain_home/$directory
        find . -type f | cut -d'/' -f2 | sort >$tmp/files_left
        files_left=$(cat $tmp/files_left | grep -v variables | grep -v '.DS_Store')

        if [ ! -z "$files_left" ]; then
            if [ -d $right_domain_home/$directory ]; then
                cd $right_domain_home/$directory
                find . -type f | cut -d'/' -f2  | sort >$tmp/files_right
                files_right=$(cat $tmp/files_right)

                if [ ! -z "$files_right" ]; then
                    # compare
                    diff $tmp/files_left $tmp/files_right >$tmp/diff_files
                    if [ $? -ne 0 ]; then
                        # look for extra files at left
                        extra_left=$(cat $tmp/diff_files | grep '<')
                        if [ ! -z "$extra_left" ]; then
                            echo "MISMATCH: Missing files at $right. Extra files: $extra_left"

                            report_root=$base_dir/report/$left_host\_$left_domain\_$left_snapshot\_vs_$right_host\_$right_domain\_$right_snapshot
                            mkdir -p $report_root/$directory
                            cat $tmp/diff_files | grep '<' >$report_root/$directory/missing_files_at_right
                        fi 

                        # look for extra files at right
                        extra_right=$(cat $tmp/diff_files | grep '>')
                        if [ ! -z "$extra_right" ]; then
                            echo "MISMATCH: Extra files at $right. Extra files: $extra_right"

                            report_root=$base_dir/report/$left_host\_$left_domain\_$left_snapshot\_vs_$right_host\_$right_domain\_$right_snapshot
                            mkdir -p $report_root/$directory
                            cat $tmp/diff_files | grep '>' >$report_root/$directory/extra_files_at_right
                        fi 
                    fi

                    # apart from differences, compare files
                    for file in $files_left; do

                        #
                        # add to report
                        #

                        anchorCnt=$((anchorCnt+1))

                        # Actual data
                        echo "<a id=\"$anchorCnt\"></a>" >> $report_root/report.html
                        echo "<h1>" >> $report_root/report.html
                        echo $directory/$file >> $report_root/report.html
                        echo "</h1>" >> $report_root/report.html

                        echo "======================================================="
                        echo Left: $left_domain_home/$directory/$file
                        echo Right: $right_domain_home/$directory/$file
                        echo "======================================================="
                        diff $left_domain_home/$directory/$file $right_domain_home/$directory/$file >$tmp/diff_file
                        if [ $? -eq 0 ]; then
                            diff_result=NO
                            echo OK

                            report_root=$base_dir/report/$left_host\_$left_domain\_$left_snapshot\_vs_$right_host\_$right_domain\_$right_snapshot
                            mkdir -p $report_root/$directory

                            cat $left_domain_home/$directory/$file > $report_root/$directory/$file.txt

                            cat $left_domain_home/$directory/$file | sed 's|$|</br>|g' > $report_root/$directory/$file.html

                            # report
                            text_style='style="color:green;"'
                            echo "<p $text_style>" >> $report_root/report.html
                            cat $report_root/$directory/$file.html >> $report_root/report.html
                            echo "</p>" >> $report_root/report.html
                        else
                            diff_result=YES
                            echo "MISMATCH detected."
                            cat $tmp/diff_file

                            report_root=$base_dir/report/$left_host\_$left_domain\_$left_snapshot\_vs_$right_host\_$right_domain\_$right_snapshot
                            mkdir -p $report_root/$directory
                            git diff --color-words --no-index $left_domain_home/$directory/$file $right_domain_home/$directory/$file > $report_root/$directory/$file.txt
                            highlight -i $report_root/$directory/$file.txt -H -o $report_root/$directory/$file.html

                            # report
                            cat $report_root/$directory/$file.html | grep -v '<meta charset="ISO-8859-1">' | xmllint --xpath '/html/body'  - >> $report_root/report.html

                        fi


                        # ToC
                        if [ $diff_result == YES ]; then
                            text_style='style="color:red;"'
                        else
                            text_style='style="color:green;"'
                        fi

                        echo "<li $text_style>"  >> $report_root/index.html
                        echo  "<a href=\"#$anchorCnt\">" >> $report_root/index.html
                        echo $directory/$file >> $report_root/index.html
                        echo "</a>" >> $report_root/index.html
                        echo "</li>" >> $report_root/index.html
                    done

                else
                    echo "MISMATCH: Whole directory empty at $right. Missing files: $files_left"
                fi
            else
                echo "MISMATCH: Directory does not exist at $right. Missing directory: $directory "
            fi
        else
            echo "WARNNING: Whole directory empty at $left"
        fi
    done
}

tmp=/tmp/$$
mkdir -p $tmp

wls_diff_root=~/cfgmon
base_dir=$wls_diff_root
report_root=$wls_diff_root/report

left=10.196.3.40
right=10.196.7.51

left_domain_name=domain
right_domain_name=domain

left_snapshot=current
right_snapshot=current

rm -f $report_root/report.html
rm -f $report_root/index.html
anchorCnt=0


compareHosts \
$left  $left_domain_name  $left_snapshot \
$right $right_domain_name $right_snapshot


echo "<html>" > $report_root/diff_report.html

echo "<head>"                >>$report_root/diff_report.html
echo "<title>"               >>$report_root/diff_report.html
echo "$left_host\_$left_domain\_$left_snapshot\_vs_$right_host\_$right_domain\_$right_snapshot"  >>$report_root/diff_report.html
echo "</title>"              >>$report_root/diff_report.html
echo "</head>"               >>$report_root/diff_report.html

echo "<body>"                >>$report_root/diff_report.html


echo "<p style=\"font-size:20px\">" >>$report_root/diff_report.html

date  >>$report_root/diff_report.html
echo "</br>"              >>$report_root/diff_report.html

echo "<h1>"                  >>$report_root/diff_report.html
echo "Weblogic compare report for: " >>$report_root/diff_report.html
echo "$left_host | $left_domain | $left_snapshot vs." >>$report_root/diff_report.html
echo "$right_host | $right_domain | $right_snapshot </br>"  >>$report_root/diff_report.html
echo "</h1>"                  >>$report_root/diff_report.html

echo "</p>"              >>$report_root/diff_report.html

echo "<h1>Substituted variables</h1>"  >>$report_root/diff_report.html
echo "<h2>Global</h2>"  >>$report_root/diff_report.html
cat $base_dir/servers/$left/$snapshot/variables | sed 's|$|</br>|g' >>$report_root/diff_report.html

echo "<h2>$left</h2>"  >>$report_root/diff_report.html
echo "<h3>domain</h3>"  >>$report_root/diff_report.html
cat $base_dir/servers/$left/$snapshot/$left_domain_name/variables | sed 's|$|</br>|g' >>$report_root/diff_report.html
for wls_name in $(ls $base_dir/servers/$left/$snapshot/$left_domain_name/servers); do
   echo "<h3>$wls_name</h3>"  >>$report_root/diff_report.html
   cat $base_dir/servers/$left/$snapshot/$left_domain_name/servers/$wls_name/variables >>$report_root/diff_report.html
done

echo "<h2>$right</h2>"  >>$report_root/diff_report.html
echo "<h3>domain</h3>"  >>$report_root/diff_report.html
cat $base_dir/servers/$right/$snapshot/$right_domain_name/variables | sed 's|$|</br>|g' >>$report_root/diff_report.html
for wls_name in $(ls $base_dir/servers/$right/$snapshot/$right_domain_name/servers); do
   echo "<h3>$wls_name</h3>"  >>$report_root/diff_report.html
   cat $base_dir/servers/$right/$snapshot/$right_domain_name/servers/$wls_name/variables >>$report_root/diff_report.html
done

echo "<h1>Compared files</h1>"  >>$report_root/diff_report.html
echo "<ul>"                  >>$report_root/diff_report.html
cat $report_root/index.html  >>$report_root/diff_report.html
echo "</ul>"                 >>$report_root/diff_report.html
cat $report_root/report.html >>$report_root/diff_report.html
echo "</body>"               >>$report_root/diff_report.html
echo "</html>"               >> $report_root/diff_report.html

cd $base_dir


