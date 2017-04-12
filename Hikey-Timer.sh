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

#   Simple timer to count the start up time of the application
#
#   N.B: this script is not intended to be used as a single script, but only with
#   the Hikey-Tester suite

my_pid=$$
echo $my_pid > timer_pid.txt
startup=0
trap "echo \"\n----Stopping timer----\n\"; exit 1" SIGINT SIGKILL SIGHUP
echo "\n----Starting timer----\n"
while [[ true ]]; do
    startup=$((startup+1))
    echo $startup > s_time.txt
    sleep 0.9
done
