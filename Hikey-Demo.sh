#!/bin/bash
#   Copyright (C) 2017 Luca Miccio <lucmiccio@gmail.com>

#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.

#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.


# This demo tests the Hikey "LeMaker" Board using the Hikey-Tester script suite


# Main variables
script_name="Hikey-Tester-Demo"
test_script="Hikey-Tester.sh"
lat_workloads=( "" "-r 3" "-r 2 -w 1")
thr_workloads=( "-r 3" "-r 2 -w 1")
rand=0
schedulers=(noop bfq)
video=file:///sdcard/Hikey-Tester/demo.mp4
my_pid_file=Hikey-Tester-Pid.txt
run_all=1
run_thr=0
run_video=0
run_lat=0
run_update=0
enable_pause=0
debug=0
results_dir="Results-Demo"
group_results=0

# Utility functions
show_help () {
    local help_message="
    $script_name

    The demo must be run using the Hikey LeMaker Board to properly work cause it
    makes use of the Hikey-Tester script suite, which works only with this board.


    USAGE:
    sh $script_name.sh [options ...]

    Options:
    -all (default): run all the tests
    -latency: run the latency test only
    -throughput: run the throughput test only
    -video : run the video playing test only
    -update : run the update test only
    -rand : if true, use also random background workload (throughput test only)
    -enable_pause: enable a \"[Enter] to start\" step every test
    -group_results: group the results of the throughput test for every scheduler
    -help| -h : display this message

    Advanced options:
    -debug: enable verbose output

    Example:
    sh demo.sh -video -latency
    This command will run the video playing test first, then the latency
    test.


    Author: Luca Miccio <lucmiccio@gmail.com>
    "

    clear
    echo "$help_message"
}

# Handle -h and --help options
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
	exit 0
fi

pause () {
    local phrase=$1
    local start=0
    echo "\n$phrase"
    read -n1 -s key
    echo
    while [ "$key" != '' ]; do
        echo "\n$phrase"
        read -n 1 -s key
        echo
    done

}

 start_latency_test () {
    local scheduler=$1
    local background_io=$2
    local time_test=30
    local low_latency_enabled=""

    if [ "$scheduler" == 'bfq' ]; then
        low_latency_enabled="-low_lat"
    fi

    if [ "$background_io" == "" ]; then
        time_test=15
    fi

    if [ $debug -eq 1 ]; then
        echo -n "sh $test_script -sched $scheduler -time $time_test $scheduler $background_io $low_latency_enabled\n"
    fi
    sh $test_script -sched $scheduler -time $time_test $background_io $low_latency_enabled
}

start_thr_test () {
    local scheduler=$1
    local background_io=$2

    if [ $debug -eq 1 ]; then
        echo -n "sh $test_script -sched $scheduler $background_io -thr -time 35\n"
    fi

    local thr_cmd="sh $test_script -sched $scheduler $background_io -thr -time 35"
    eval "$thr_cmd"

    local workload="$(echo -e $background_io | sed 's/ //g')"
    mv outfile.txt $results_dir/"outfile-$scheduler$workload.txt"

    # If rand is set, run also the test with random workload
    if [ $rand -eq 1 ];then

        if [ $debug -eq 1 ];then
            echo "Running thr test with random workload"
        fi

        eval "$thr_cmd -rand true"
        mv outfile.txt $results_dir/"outfile-$scheduler$workload-rand.txt"
    fi
}


start_video_test () {
    local scheduler=$1
    local background_io=$2
    local low_latency_enabled=""

    if [ "$scheduler" == 'bfq' ]; then
        low_latency_enabled="-low_lat"
    fi


    if [ $debug -eq 1 ]; then
        echo -n "sh $test_script -sched $scheduler $background_io -video $video $low_latency_enabled\n"
    fi

    sh $test_script -sched $scheduler $background_io -video $video $low_latency_enabled
}

# Multipurose function that runs a test
run_test () {
    local test_function=$1
    local test_type=$2
    local test_workload_name=$3
    local test_workload

    if [ "$test_workload_name" == "lat_workloads" ]; then
        test_workload=("${lat_workloads[@]}")
    else
        test_workload=("${thr_workloads[@]}")
    fi

    if [ $debug -eq 1 ]; then
        echo "Current workload items:"
        for work in "${test_workload[@]}"; do
            echo "Work:$work"
        done
    fi

    echo "Starting $test_type test..."
    if [ "$test_workload_name" == "update" ]; then
        local workload="-update"
        for i in ${schedulers[@]}; do
            local message_param="Starting the $test_type test with the following parameters:\n- scheduler: $i\n- workload: $workload"
            echo "\n$message_param"

            if [[ $enable_pause -eq 1 ]]; then
                message_pause="Press [Enter] to start..."
                pause "$message_pause"
            fi
            sleep 1
            $test_function $i "$workload"
            sleep 3
        done

        return 0
    fi

    for k in "${test_workload[@]}"; do
        local workload

        if [ "$k" == "" ]; then
            workload="no workload"
        else
            workload=$k
        fi

        for i in ${schedulers[@]}; do
            local message_param="Starting the $test_type test with the following parameters:\n- scheduler: $i\n- workload: $workload"
            echo "\n$message_param"

            if [[ $enable_pause -eq 1 ]]; then
                message_pause="Press [Enter] to start..."
                pause "$message_pause"
            fi
            sleep 1
            $test_function $i "$k"
            sleep 3
        done
    done
}

create_group_results () {
    local filename="group_report_"
    local catfile="$results_dir/outfile-"
    local outfile="$results_dir/group/group_report_"

    mkdir -p $results_dir/group 2> /dev/null

    for sched in ${schedulers[@]}; do
        echo "Group results for $sched: " > $outfile$sched.txt
        cat $catfile$sched* | sed '3d;5d;7d' >> $outfile$sched.txt
    done
}

close_current_test () {
    echo -n "Continue? [Yy/Nn]: "
    read -n1 -s key

    if [[ "$key" == "N" || "$key" == "n" ]]; then
        echo
        exit 1
    fi

}

trap 'echo Interrupting test; close_current_test;' SIGKILL SIGTERM SIGINT


########################## Handle multiple options ############################
while :
do
    case "$1" in
        -enable_pause)
            enable_pause=1
            shift
            ;;
        -all)
            run_all=1
            break
            ;;
        -video)
            run_video=1
            run_all=0
            shift
            ;;
        -throughput)
            run_thr=1
            run_all=0
            shift
            ;;
        -latency)
            run_lat=1
            run_all=0
            shift
            ;;
        -update)
            run_update=1
            run_all=0
            shift
            ;;
        -rand)
            rand=1
            shift
            ;;
        -group_results)
            group_results=1
            shift
            ;;
        -debug)
            debug=1
            shift
            ;;
        -*)
	        echo "ERROR: Unknown option: $1" >&2
	        exit 1
	        ;;
        *)  # No more options
	        break
	        ;;
    esac
done

sleep 1

################MAIN#################
echo "Hikey Tester Demo"

# First of all we have to check if the user has root privileges
USER=$(whoami)
if [[ "$USER" != 'root' ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi


# Execute only the test choosen
if [[ $run_all -eq 1 || $run_lat -eq 1 ]]; then
    run_test "start_latency_test" "latency" "lat_workloads"
    sleep 2
fi

if [[ $run_all -eq 1 || $run_thr -eq 1 ]]; then
    mkdir $results_dir 2>/dev/null
    run_test "start_thr_test" "throughput" "thr_workloads"
    sleep 2

    if [ $group_results -eq 1 ]; then
        echo "Creating group results..."
        sleep 3
        create_group_results
        echo "File(s) saved in $results_dir/group"
    fi
fi

if [[ $run_all -eq 1 || $run_video -eq 1 ]]; then
    run_test "start_video_test" "video playing" "lat_workloads"
    sleep 2
fi

if [[ $run_all -eq 1 || $run_update -eq 1 ]]; then
    run_test "start_latency_test" "update test" "update"
    sleep 2
fi

echo "Demo ended"
exit 0
