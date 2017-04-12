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

#   Measure the latency simulating updates of applications in background.
#   The updates are simluated simply by installing and uninstalling a set
#   of given applications while a single writer is running in the background
#   in order to simulate the download of an application. The writer has a fixed
#   rate to simulate an average internet connection og 120 Mb/s.
#
#   N.B: this script is not intended to be used as a single script, but only with
#   the Hikey-Tester suite

# Main variables
pid=$$
app_folder=$1
iteration=$2
sequential=$3
echo $app_to_open
app_to_open="com.facebook.katana"
activity=".activity.FbMainTabActivity"
end=0
parent_folder=$(echo $(pwd))
app_installed=(com.linkedin.android com.dropbox.android com.microsoft.office.excel \
com.google.android.music com.twitter.android com.netflix.ninja )
fiojob_name="fiojobs/download.fio"

trap 'close' SIGKILL SIGTERM SIGINT


clean_garbage() {

    for package in "${app_installed[@]}"
    do
        echo -n "Uninstalling: "$package
        output=$(pm uninstall $package 2>/dev/null)    #2>/dev/null

        if [ "$output" == "Success" ]; then
            echo " [Done]"
        else
            echo " [NOT INSTALLED]"
        fi
    done

    # Remove Temporary folder created by the pm command
    echo "Removing garbage..."
    rm -rf /data/app/*.tmp
}

close () {
    echo "Terminating update workload..."
    # Close timer if active
    kill -2 $(cat timer_pid.txt 2> /dev/null) 2> /dev/null
    rm -rf timer_pid.txt

    end=1
    kill -SIGKILL $(jobs -lp) >/dev/null 2>&1 || true
    killall app_process >/dev/null 2>&1 || true
    clean_garbage
    exit 1
}

install_all_applications () {

    # The main loop that install continuosly all the applications in the
    # $app_folder
    for file in *.apk
    do

     if [[ $file = "*.apk" ]]; then
        echo "No apk file in folder $app_folder"
        exit 1
     fi

     echo "Installing $file"
     if [ $end -eq 0 ]; then
         if [ $sequential -eq 1 ]; then
             pm install $file
         else
             pm install $file &
         fi
     else
         exit 0
     fi

    done
}

generate_fiojob() {

    if [ ! -d fiojobs/ ]; then
        mkdir fiojobs
    fi

	if [ ! -f  $fiojob_name ]; then
   		echo "Creating $fiojob_name..."
		local fio_dwn="
		[global]\n
		time_based\n
		runtime=120\n
		group_reporting\n
		size=256m\n
        rate=,15m\n

        [job download]\n
        filename=/data/tmp/DOWNLOAD_write\n
        rw=write
		"
		echo $fio_dwn > $fiojob_name
	fi
}

simulate_download () {
    generate_fiojob
    fio $fiojob_name
}

# Check if the test folder is present
if [ ! -d test/ ]; then
    echo "ERROR : test folder not found!"
	exit 1
fi

echo "Cleaning setup..."
clean_garbage >/dev/null 2>&1 || true

echo "Starting background writer that simulates a file download..."
simulate_download &

cd $app_folder

echo "Start installing applications..."
for i in $(seq 1 $iteration)
do
    install_all_applications &
done

cd $parent_folder

# Sleeping for a few seconds to simulate a normal user situation...
secs=7
while [ $secs -gt 0 ]; do
   echo  "Starting $app_to_open in : $secs" #\033[0K\r"
   sleep 1
   : $((secs--))
done
sleep 1

# Open the app
sh Hikey-Open-Application.sh "$app_to_open" "$activity" &
 while [[ true ]]; do
     sleep 1
     sync
     echo "\nParallel sync completed"
 done
