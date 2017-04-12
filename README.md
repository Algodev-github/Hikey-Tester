# Hikey-Tester
This test script is designed to measure the performance of I/O
schedulers, in particular with NOOP and BFQ schedulers, using the
[Hikey "LeMaker" Board](http://www.96boards.org/product/hikey/) running
Android.

These benchmarks have been written just for internal use.
In particular,  we did not spend time in guaranteeing that the programs have a
homogeneous interface, or any error.

## Dependencies
This script requires on the Hikey Board:
- [fio](https://github.com/axboe/fio)

## How to install
To use the Hikey-Tester there are very simple steps to reproduce:
- Download the .zip file containing all the necessary files
- Extract the files from the .zip to a folder
- Create a folder named "Hikey-Tester" on the Hikey Board using adb
```
$ adb shell mkdir /sdcard/Hikey-Tester/
```
- Copy all the files inside the board using adb in the correct folder

## Install using setup script
To make this installation even easier there is a script named "setupHikey.sh"
which automatically installs all the files to the Hikey Board.  
After extracted the .zip you have just to  
- Go inside the extracted folder using the terminal:
```
$ cd /path/to/folder
```
- Execute the script:
```
$ ./setupHikey.sh
```

# Basic usage
Log using adb:
```
$ adb shell
```
Get root permissions:
```
$ su
```
Go into the Hikey-Tester folder using the terminal:
```
# cd /sdcard/Hikey-Tester/
```
Run the Hikey-Tester.sh script under root permissions:
```
# sh Hikey-Tester.sh
```
- Execute **sh Hikey-Tester.sh -h** for more options.

# Demo
It is also provided a simple demo script named "Hikey-Demo.sh" which
simplifies the use of the test script, running a series of default tests.

* Execute **sh Hikey-Demo.sh -h** for more options.

# Info
For more information about BFQ and its integration in Android visit
[BFQ on Android](http://algogroup.unimore.it/algodev/bfqonandroid/)
# License
This program is under [GNU General Public License](https://www.gnu.org/licenses/gpl-3.0-standalone.html)
