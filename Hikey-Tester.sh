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

# This script is used for testing the Hikey Lemaker Version board
# TODO: add description


SCRIPT_NAME="Hikey-Tester.sh"

# Main variables
num_read=0
num_write=0
rand=""
sched="noop"
sliceidle=30 # not used yet. Maybe remove it
set_prio=false # not used yet. Maybe remove it
tracer=blk
is_script_ended=false
tracing=0
runtime=60
SCHEDULERS=()
TRACERS=()
my_pid_file=Hikey-Tester-Pid.txt

# Latency test specific variables
app_to_open="com.facebook.katana"
activity=".activity.FbMainTabActivity"

# Throughput test specific variables
thr=false

# Video test specific variables
video_file=""
pid_video=""

# Update workload specific variables
n_update=0

# Testing variables
testing=0
low_lat=1

source ./Hikey-Tester-Util.sh

# Handle SIGINT SIGTERM and SIGINT
trap 'echo Interrupting; close; exit 1' SIGKILL SIGTERM SIGINT SIGHUP

help () {

local help_message="
Tester for Hikey Lemaker Version board

This script must be run as root

USAGE: sh $SCRIPT_NAME [options]

Options:

    Generic options:
    -sched [scheduler] : set the desired scheduler
    -r [number] : set the number of readers
    -w [number] : set the number of writers
    -rand [true|false] : random reads and writes enabled/disabled
    -time [number] : run the test for [number] seconds

    Test options:
    -app 'com.app.name' 'activity' : start the selected app for testing

    The following options can be used one at the time.
    -thr : measure only throughput without opening any application
        N.B: if not set, this option configures the number of readers and
        writers to the default values for throughput test:
        - readers = 2, writers = 0
        If you want to set a custom readers value, configure first the -r|-w
        options. Smaller values than the default ones will be reset to default.
        If the video option is set with this option, the test will be aborted.
    -video [URI video] : play the selected video during the test
        N.B: if the thr option is set with this option, the test will be aborted.
    -update : simulate, as background workload, the update of the
        applications in the test/ folder.
        N.B: in this case the default workload (fio) is not used and there
        must be a test/ (named \"test\") folder inside the Hikey-Tester folder
        where this script is with the same files as the one provided by the
        test folder that is contained in this suite.
        WARNING: still an experimental option. Use it at your own risk.

    Advanced options:
    -low_lat : set the value of low_latency to 1 (only available with BFQ)
        N.B: this option should be used when testing the latency
        or video playing
    -trace : enable tracing (set automatically if -t is used)
    -t : set tracer
    -tl : list available tracers

    Help options:
    -default : print default values
    -h | --help : display this help


Examples:
    - Run a simple latency test where the default application is opened while
    there is a background I/O and with the BFQ I/O scheduler:
    sh $SCRIPT_NAME -r 3 -sched bfq -low_lat

    - Run a throughput test using 3 reader and 1 writer with the NOOP I/O
    scheduler:
    sh $SCRIPT_NAME -sched noop -r 3 -w 1 -thr


Author: Luca Miccio <lucmiccio@gmail.com>
    "

	echo "$help_message"
	return 0
}

print_default_values () {

    echo "Default values:"

    local values="
    Scheduler: $sched
    Number reader: $num_read
    Number writer: $num_write
    Tracer: $tracer
    App to open: $app_to_open / $activity
    Random: $rand
    Time: $runtime
    Video Uri: $video_file
    Is a throughput test: $thr
    "

    local testing_values="
    T_slow: $T_slow
    "
    echo "$values"

    if [ $testing -eq 1 ]; then
        echo "\nTesting values:"
        echo "$testing_values"
    fi
}

# Handle -h and --help options
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    clear
	help
	exit 0
fi

# Handle -default option
if [ "$1" == "-default" ]; then
    clear
	print_default_values
	exit 0
fi



# Main functions
check_dependencies () {
    local CUR_DEV=mmcblk0

    # Check fio dependency
    if [ ! hash "fio" >/dev/null 2>&1 ]; then
        echo "fio command not found. Please install it and retry."
        exit 1
    fi

	# Get current available schedulers
	local scheds=$(cat /sys/block/$CUR_DEV/queue/scheduler)
	# Remove parentheses
	scheds=$(echo $scheds | sed 's/\[//')
	scheds=$(echo $scheds | sed 's/\]//')
	SCHEDULERS=($scheds)
    # Get current available tracers
	local tracers=$(cat /sys/kernel/debug/tracing/available_tracers)
	TRACERS=($tracers)

	if [ ${#TRACERS[@]} -eq 0 ]; then
		echo "ERROR: No tracers or schedulers found. Aborting test..."
		exit 1
	fi

    if [ ${#SCHEDULERS[@]} -eq 0 ]; then
        echo "ERROR: No tracers or schedulers found. Aborting test..."
		exit 1
    fi
}

close_tester_app () {

	# Kill app process if present
	if [[ "$(pidof $app_to_open )" != "" ]]; then
        echo "Killing application with pid: $(pidof $app_to_open )"
        sleep 2
	    kill $(pidof $app_to_open)
	fi
}

close () {
    # Close timer if active
    kill -2 $(cat timer_pid.txt 2> /dev/null) 2> /dev/null
    rm -rf timer_pid.txt
    close_tester_app
    rm $my_pid_file >/dev/null 2>&1 || true
	is_script_ended=true
    echo "Stopping tracing..."
	set_tracing 0
    echo "Killing jobs..."
    if [ "$pid_video" != "" ]; then
        kill -2 $pid_video
    fi
    kill -SIGHUP $(jobs -lp) >/dev/null 2>&1 || true
    print_test_resume
}

print_results () {
    # | grep aggrb | cut -d, -f 2 | cut -d= -f2 get aggrb from out
    # filename: fiout.out

    #TODO: results for all tests

    # Get results for thr test
    local scheduler=$sched
    local output_file=outfile.txt
    local r="r: $num_read"
    local w="w: $num_write"
    local thr_avg_r=$(cat fiout.out | grep aggrb | cut -d, -f 2 | cut -d= -f2  | grep -m1 K 2>/dev/null)
    local thr_avg_w
    if [ $num_write -gt 0 ]; then
        thr_avg_w=$(cat fiout.out | grep aggrb | cut -d, -f 2 | cut -d= -f2 | tail -1 2>/dev/null)
    else
        thr_avg_w="0KB/s"
    fi

    local header='Scheduler\tReaders\tWriters\tRandom\tThroughput(Avg)\n'

    if [ "$rand" == "" ]; then
        rand="false"
    else
        rand="true"
    fi
    {
        printf '%5s%10s%15s%18s%25s\n' "Scheduler" "Readers" "Writers" "Random" "Throughput(Avg R - W)"
        printf '%5s%11s%16s%20s%23s\n' "$scheduler" "$r" "$w" "$rand" "$thr_avg_r-$thr_avg_w"
    } | tee $output_file

    echo "Results written in: $output_file"
    rm -rf fiout.out
}

print_test_resume () {

    local resume="The test is executed with $sched scheduler, $num_read reader, $num_write writer."
    echo "$resume"

    if [ "$thr" == "true" ]; then
        local thr_resume="Mode: throughput test"
        echo "$thr_resume"
        print_results
    elif [ "$video_file" != "" ]; then
        local video_resume="Mode: video test.\nVideo opened: $video_file"
        echo "$video_resume"
    elif [ $n_update -gt 0 ]; then
        echo "Mode: simulate updates workload"
        echo "Startup-time:" $(cat s_time.txt 2>/dev/null)
        rm -rf s_time.txt
    else
        local app_resume="Mode: latency test.\nApp opened: $app_to_open"
        echo "$app_resume"
        echo "Startup-time:" $(cat s_time.txt 2>/dev/null )
        rm -rf s_time.txt
    fi

}

# First of all we have to check if the user has root privileges
USER=$(whoami)
if [[ "$USER" != 'root' ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Check if there are all file/variables dependecies
check_dependencies

########################## Handle multiple options ############################
while :
do
    case "$1" in
        -t_slow)
            is_a_number $2
            t_slow=$2
            shift 2
            ;;
	    -sched)
	        contains "$2" "${SCHEDULERS[*]}"
	        if [ $? -eq 0 ]; then
		        sched=$2
	        else
		        echo "Input scheduler not found"
		        echo "Available schedulers are: ${SCHEDULERS[@]}"
		        exit 1
	        fi
	        shift 2
	        ;;
	    -slice)
	        if [ "$sched" != "bfq" ];then
                display_and_exit "BFQ scheduler must be used.\nDetected: $sched"
	        else
		        slide_idle=$2
	        fi
	        shift 2
	        ;;
		-trace)
			tracing=1
			shift
			;;
	    -t)
	        contains "$2" "${TRACERS[*]}"
	        if [ $? -eq 0 ]; then
		        tracer=$2
				tracing=1
	        else
                display_and_exit "Input tracer not found\nAvailable tracers are: ${TRACERS[@]}"
	        fi
	        shift 2
	        ;;
	    -tl)
            echo "Available tracers:"
	        echo ${TRACERS[@]}
	        exit 0
	        ;;
	    -r)
	        is_a_number $2
            if [ $2 -gt 5 ]; then
                display_and_exit "ERROR: reader value $2 is too big. Max value: 5"
            fi

            num_read=$2
	        shift 2
	        ;;
	    -w)
	        is_a_number $2
            if [ $2 -gt 5 ]; then
                display_and_exit "ERROR: writer value $2 is too big. Max value: 5"
            fi

            num_write=$2
	        shift 2
	        ;;
	    -app)
            if [[ "$2" == "" || "$3" == "" ]]; then
                echo "ERROR: app option wrong"
                help
                exit 1
            else
	               AppToOpen=$2
	               Activity=$3
            fi
	        shift 3
            ;;
        -rand)
	        if [ "$2" == "true" ]; then
   		        rand="rand"
	        elif [ "$2" == "false" ];then
  	  	        rand=""
	        else
		        display_and_exit "ERROR: rand input wrong. Only [true|false] are permitted."
	        fi
	        shift 2
	        ;;
	    -thr)
            if [[  "$video_file" != ""  || $n_update -gt 0 ]]; then
                echo "ERROR: other test options detected. Aborting."
                help
                exit 1
            fi

		    thr=true

            if [ $runtime -lt 30 ];then # set the runtime to the minimun value
                runtime=30              # 30 seconds
            fi

            echo "Throughput mode:"
            echo "WARNING: -app options values will be not considered"
            if [ $num_read -lt 0 ]; then
                echo "Overriding readers value $num_read to default -> 2"
                num_read=2
            fi
            shift
            ;;
        -time)
			is_a_number $2
			runtime=$2
	  	    shift 2
	  	    ;;
        -video)
            if [[  $n_update -gt 0 || "$thr" != "false" ]]; then
                echo "ERROR: other test options detected. Aborting."
                help
                exit 1
            fi

            # Check if the URI is not empty
            if [ -z "${2// }" ]; then
                display_and_exit "ERROR: \"$2\" consists of spaces only."
            fi
            video_file=$2
            shift 2
            ;;
        -low_lat)
            low_lat=1
            shift
            ;;
        -update)
            if [[  "$video_file" != ""  || "$thr" != "false" ]]; then
                echo "ERROR: other test options detected. Aborting."
                help
                exit 1
            fi
            thr="false"
            n_update=1
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

################################# MAIN ########################################
echo "----Starting test----\n"

# Save pid for the Hikey-Toolkit
# TODO: add link to its repo
echo $$ > $my_pid_file

# Setup tracing if needed
if [ $tracing -eq 1 ]; then
    init_tracing $sched
fi

# Close $app_to_open if present
close_tester_app 2> /dev/null

# Set low_lat to 0 if we are running a
# throughput test
if [ "$thr" == "true" ]; then
    low_lat=0
fi

# Change the scheduler
change_sched $sched


echo "Setup files needed..."
setup_test_file

echo -n "Syncing..."
sync
echo "Ok"

echo -n "Drop caches..."
echo 3 > /proc/sys/vm/drop_caches
echo "Ok"

set_tracing $tracing


# Genereate default fio workload only if needed
if [[ $num_read -gt 0 || $num_write -gt 0 ]] && [ $n_update -eq 0 ]; then
    echo "Generating workload in background..."
    genereate_workload
fi


# Start the correct test
if [ "$thr" == "true" ]; then
	echo "Sleep until workload ends: $((runtime+5))s."
    sleep $((runtime+5))

elif [ "$video_file" != "" ]; then
    # Sleeping for a few seconds to simulate a normal user situation...
    sleep 5
    echo "Playing $video_file"
    sh Hikey-Video-Play.sh $video_file $runtime

elif [ $n_update -gt 0 ]; then
    echo "Generating workload simulating application updates..."
    sh Hikey-Update-Workload.sh test/ $n_update 1 #1 seq 0 parallel

else
    # Sleeping for a few seconds to simulate a normal user situation...
    sleep 5
	# Open the app
	sh Hikey-Open-Application.sh "$app_to_open" "$activity" &
	echo "Sleep for $((runtime+5)) seconds"
    echo "Ctrl+c to stop the script when the application is loaded"
    sleep $((runtime+5))

fi

# Stop test
close

echo "Test ended."
exit 0
