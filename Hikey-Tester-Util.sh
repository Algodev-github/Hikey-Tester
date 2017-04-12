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

#   Utility functions for the Hikey-Tester suite

# Change this values only if you now what you are doing
HD=mmcblk0
fiofolder="fiojobs"

# Tracing functions
init_tracing () {

	local sched=$1
	echo "Initializate tracing..."
        if [ "$tracing" == "1" ] ; then

                if [ ! -d /sys/kernel/debug/tracing ] ; then
                        mount -t debugfs none /sys/kernel/debug
                fi

                echo nop > /sys/kernel/debug/tracing/current_tracer
                echo 50000 > /sys/kernel/debug/tracing/buffer_size_kb
                echo "Buffer size: $(cat /sys/kernel/debug/tracing/buffer_size_kb) kb"

				if [[ "$tracer" == "blk" ]]; then
                	echo "${sched}*" "__${sched}*" >\
                        	/sys/kernel/debug/tracing/set_ftrace_filter
				else
					echo "" > /sys/kernel/debug/tracing/set_ftrace_filter
				fi

				echo $tracer > /sys/kernel/debug/tracing/current_tracer
				echo -n "Selected tracer: "
				cat /sys/kernel/debug/tracing/current_tracer
        fi
}

set_tracing () {
    if [ "$1" == "1" ] ; then
		echo "Setting tracing..."
	fi

       # if test -a /sys/kernel/debug/tracing/tracing_enabled; then
			#if [[ $tracer == "wakeup_rt" ]]; then
		#	echo "echo $1 > /sys/kernel/debug/tracing/tracing_on"
		#	echo $1 > /sys/kernel/debug/tracing/tracing_on
				#else
                #echo "echo $1 > /sys/kernel/debug/tracing/tracing_enabled"
                #echo $1 > /sys/kernel/debug/tracing/tracing_enabled
				#fi
		#fi
		if [ $testing -eq 1 ];then
			echo "echo $1 > /sys/kernel/debug/tracing/tracing_on"
			echo "echo $1 > /sys/block/$HD/trace/enable"
		fi
		echo $1 > /sys/kernel/debug/tracing/tracing_on
        echo $1 > /sys/block/$HD/trace/enable

}

# Scheduler functions
change_sched () {

	echo $1 > /sys/block/$HD/queue/scheduler

	# Handle possible error
	local error=$?
	if [[ "$error" != "0" ]]
	then
		echo "ERROR: $1 scheduler not found"
		exit 1
	fi

	echo "Current Scheduler:" $(cat /sys/block/$HD/queue/scheduler)

	# Temporary disabled slice_idle option
	if [[ "$1" == "bfq" ]]
	then
		echo $low_lat > /sys/block/$HD/queue/iosched/low_latency
		echo -n "Low latency:"
        cat /sys/block/$HD/queue/iosched/low_latency
    #    	echo $sliceidle > /sys/block/mmcblk0/queue/iosched/slice_idle
	#	echo -n Slice idle:
    #    	cat /sys/block/mmcblk0/queue/iosched/slice_idle
	fi
}

# Change t_slow parameter for BFQ scheduler
# N.B: this function MUST be used only for testing and
# only if the t_slow change is enabled in BFQ.
change_t_slow () {

    echo "Changing t_slow time..."
    is_a_number $1
    echo $1 > /sys/block/$HD/queue/iosched/t_slow
    local time=$(cat /sys/block/$HD/queue/iosched/t_slow)
    echo "Current t_slow time: $time"

}

# Workload functions
setup_file_to_read () {

	for k in $(seq 1 $num_read)
	do
		if [ ! -f /data/tmp/BIGFILE_read$k ]
		then
			dd if=/dev/zero of=/data/tmp/BIGFILE_read$k bs=1048576 count=256
		fi
	done
}

setup_file_to_write () {
	for k in $(seq 1 $num_write)
	do
		if [ -f /data/tmp/BIGFILE_write$k ]
		then
			rm /data/tmp/BIGFILE_write$k
		fi
	done
}

setup_test_file () {

	# Check if the tmp folder exists
	if [ ! -d /data/tmp ]; then
		mkdir /data/tmp
	fi

	setup_file_to_read

   	if [ $num_write -gt 0 ];then
   	 	setup_file_to_write
   	fi
}

check_fiofolder () {
	rm -rf $fiofolder
	mkdir $fiofolder 2> /dev/null
}

generate_single_jf () {

	local filename="$fiofolder/fiojob${rand}.fio"
	local n_write=$num_write
	local n_read=$num_read

	if [ $n_write -gt 0 ]; then
		local size="size=256m"
	fi

	if [ ! -f  $filename ]; then
   		echo "Creating $filename..."
		global="
		[global]\n
		time_based\n
		runtime=$runtime\n
		group_reporting\n
		$size
		"
		echo $global > $filename

		# Insert write jobs
		for n in $(seq 1 $n_write)
		do
			local job="
			[job write-$n]\n
			filename=/data/tmp/BIGFILE_write$n\n
			rw=${rand}write

			"
			echo $job >> $filename
		done

		# Insert read jobs
		for n in $(seq 1 $n_read)
		do
			local job="
			[job read-$n]\n
			filename=/data/tmp/BIGFILE_read$n\n
			rw=${rand}read

			"
			echo $job >> $filename
		done

	fi
}

genereate_workload () {

	check_fiofolder
	generate_single_jf
	sync
	fio $fiofolder/fiojob${rand}.fio --output=fiout.out &
	# File copies test
	#cp  /data/tmp/BIGFILE_read1 /data/tmp/BIGFILE_read1.1 &
	#cp /data/tmp/BIGFILE_read2 /data/tmp/BIGFILE_read2.2 &
}

# Utility functions
contains () {

	local e
	local ARRAY=$2
	for e in ${ARRAY[@]};
		do [[ "$e" == "$1" ]] && return 0;
	done

	return 1
}

is_a_number () {

	local number=$1
	if [ "$number" -eq "$number" ] 2>/dev/null; then
		: # No errors
	else
		echo "ERROR: $number input not correct..."
		exit 1;
	fi

}

file_exists () {

	if [ ! -f $1 ]; then
	    echo "ERROR FILE: $1 not found!"
		exit 1
	fi

}

sleep_for () {
	local seconds=$1

	while [[ true ]]; do
		sleep $seconds &
		wait
	done
}

display_and_exit () {
	local message=$1

	echo $message
	exit 1
}
