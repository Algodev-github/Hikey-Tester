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

#   Open a video on Android OS using the URI passed by argument
#   org.videolan.vlc/.gui.video.VideoPlayerActivity -d file:///storage/emulated/0/Movies/demo.mp4
#
#   N.B: this script is not intended to be used as a single script, but only with
#   the Hikey-Tester suite

SCRIPT_NAME="Hikey-Video-Play.sh"

# Main variables
video_file=${1-""}
video_time=${2-30}
android_player="com.android.gallery3d"
android_player_activity=".app.MovieActivity"
pid_player=""

# Show help function
help () {
    local help_message="
    Open a video file on an Android OS device using the provided URI

    USAGE: sh $SCRIPT_NAME URI

    Author: Luca Miccio <lucmiccio@gmail.com>
    "
}

openVideo () {
    video_time=$((video_time+5))
    local uri=$1
    am start -n  $android_player/$android_player_activity -d $uri
}

close () {
    local vlc_pid=""
    vlc_pid=$(pidof org.videolan.vlc)
    if [ "$vlc_pid" != "" ]; then
        echo "Closing vlc..."
        kill -9 $vlc_pid
    fi

    if [[ "$pid_player" != "" ]]; then
        echo "Closing the video player..."
        kill -9 $pid_player
        pid_player=""
    fi

    kill -SIGINT $(jobs -p) >/dev/null 2>&1 || true
}

# Handle SIGINT SIGTERM and INT
trap 'close; exit 1' SIGKILL SIGTERM SIGINT

# Handle -h and --help options
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    clear
	help
	exit 0
fi


### MAIN ###

# Close old player
pid_player=$(pidof $android_player)

if [[ "$pid_player" != "" ]]; then
    close
fi

echo "Starting player..."
openVideo $video_file
echo "Wating for $video_time s. Ctrl+c to stop"
while [[ "$pid_player" == "" ]]; do
    echo "Getting pid..."
    pid_player=$(pidof $android_player)
done
echo "Player pid: $pid_player"

sleep $video_time

close

exit 0
