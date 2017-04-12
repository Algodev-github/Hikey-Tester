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

# Setup correctly the Hikey Board with all the necessary files in order to test
# the board with Hikey-Tester suite

# Main variables
needed_files=("Hikey-Timer.sh" "Hikey-Tester.sh" "Hikey-Video-Play.sh" "Hikey-Tester-Util.sh" "Hikey-Open-Application.sh" "Hikey-Update-Workload.sh" "demo.mp4")
demo_file="Hikey-Demo.sh"
test_folder="/sdcard/Hikey-Tester/"
res_folder="$test_folder/Results-Demo"
fio_folder="$test_folder/fiojobs"

# Utility functions
check_command_dependecies () {
    local check_command=$1
    command -v $check_command >/dev/null 2>&1 || { echo >&2 "ERROR: $check_command required but it's not installed.\nAborting."; exit 1; }
}

file_exists () {

	if [ ! -f $1 ]; then
	    echo "ERROR FILE: $1 not found!"
		exit 1
	fi

}

check_dependencies () {
    echo -n "Checking adb dependency..."
    check_command_dependecies adb
    echo "Ok"

    for file in "${needed_files[@]}"; do
        echo -n "Checking $file..."
        file_exists $file
        echo "Ok"
    done

    echo -n "Checking $demo_file..."
    if [ ! -f $demo_file ]; then
        echo "WARNING FILE: $demo_file not found!"
        demo_file="NULL"
    fi
    echo "Ok"

}

create_directory () {
    adb shell mkdir $test_folder 2>/dev/null
}

copy_file_to_board () {
    local file_to_copy=$1
    adb push $1 $test_folder
}

copy_files_to_board () {
    for file in "${needed_files[@]}"; do
        copy_file_to_board $file
    done

    if [ "$demo_file" != "NULL" ]; then
        copy_file_to_board $demo_file
    fi

    copy_file_to_board test/

}

create_folder_dependency () {
    adb shell mkdir $fio_folder 2>/dev/null
    adb shell mkdir $res_folder 2>/dev/null
}


######## MAIN ######
check_dependencies

echo "Creating directory..."
create_directory
sleep 1

echo "Copying files..."
copy_files_to_board
create_folder_dependency
sleep 1

echo "All files copied. Now you can start to test your Hikey!"
echo "Just go to the $test_folder in your board using adb."
exit 0
