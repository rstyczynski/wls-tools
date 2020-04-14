#!/bin/bash


unset compareDomains
function compareDomains() {
    left_host=$1
    left_domain=$2
    left_snapshot=$3
    right_host=$4
    right_domain=$5
    right_snapshot=$6

    left_domain_home=$base_dir/servers/$left_host/$left_snapshot/$left_domain
    right_domain_home=$base_dir/servers/$right_host/$right_snapshot/$right_domain

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
        find . -type f -depth 1 | cut -d'/' -f2 | sort >$tmp/files_left
        files_left=$(cat $tmp/files_left)

        if [ ! -z "$files_left" ]; then
            if [ -d $right_domain_home/$directory ]; then
                cd $right_domain_home/$directory
                find . -type f -depth 1 | cut -d'/' -f2  | sort >$tmp/files_right
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
                        echo "======================================================="
                        echo Left: $left_domain_home/$directory/$file
                        echo Right: $right_domain_home/$directory/$file
                        echo "======================================================="
                        diff $left_domain_home/$directory/$file $right_domain_home/$directory/$file >$tmp/diff_file
                        if [ $? -eq 0 ]; then
                            echo OK

                            report_root=$base_dir/report/$left_host\_$left_domain\_$left_snapshot\_vs_$right_host\_$right_domain\_$right_snapshot
                            mkdir -p $report_root/$directory
                            git diff --color-words --no-index $left_domain_home/$directory/$file $right_domain_home/$directory/$file > $report_root/$directory/$file.txt
                            ansifilter -i $report_root/$directory/$file.txt -H -o $report_root/$directory/$file.html
                        else
                            echo "MISMATCH detected."
                            cat $tmp/diff_file

                            report_root=$base_dir/report/$left_host\_$left_domain\_$left_snapshot\_vs_$right_host\_$right_domain\_$right_snapshot
                            mkdir -p $report_root/$directory
                            git diff --color-words --no-index $left_domain_home/$directory/$file $right_domain_home/$directory/$file > $report_root/$directory/$file.txt
                            ansifilter -i $report_root/$directory/$file.txt -H -o $report_root/$directory/$file.html
                        fi
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

base_dir=/Users/rstyczynski/Developer/diff-test/wls-index
left=10.106.3.15
right=10.106.4.14

cd $base_dir/servers/$left/current
for left_domain_name in $(find . -type d -depth 1 | cut -d'/' -f2 | sort); do
    cd $base_dir/servers/$right/current
    for right_domain_name in $(find . -type d -depth 1 | cut -d'/' -f2 | sort); do
        echo $left_domain_name vs. $right_domain_name
        compareDomains \
        $left  $left_domain_name  current \
        $right $right_domain_name current
    done
done

cd $base_dir


