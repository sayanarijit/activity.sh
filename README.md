# activity.sh

![activity.sh command-line view view](https://github.com/sayanarijit/activity.sh/blob/master/activity.sh-commandline.png?raw=true)
![activity.sh browser view](https://github.com/sayanarijit/activity.sh/blob/master/activity.sh-browser.png?raw=true)

## What is it for
This script is for Linux/UNIX system admins to quickly and efficiently scan large list of hosts in the environment, run different pre-built checks on them, execute command through ssh and generate report of the findings.

## Features
* Basic functions: ping check, ssh check, console check, configuration check, execute command, login check (local user),
  health check (cpu, uptime, active sessions, local volumes), mount check (read only fs), port scan, report generation.
* Interactive and very easy to use.
* Runs simultaneous background process.
* Smart enough to run functions step by step (e.g. before performing ssh check, it performs ping check first).
* Anyone can modify the global variables, add or delete functions (it's customizable).
* Best feature is, it can create a fully featured website for the reports it has generated to make it easier to browse.

## How does it work
Find the demo video here: [activity.sh demo](https://youtu.be/dvHasF3Ap0c)

## Requirements, pre-checks and pre-configuration
Most of the functions in this script runs ssh. So the basic requirements are:
* Required tools/programs that must be installed are: bash, ping, ssh (with sudo access), ssh-keygen (with sudo access), scp (with sudo access), sshpass, timeout, grep, cut, awk, xargs, find, nc.
* All the hosts to be scanned must have ssh enabled and must be accessible from the host running this script.
* A different script that imports ssh keys to other hosts is recommended to be mentioned in the "SET_SSH_KEY_SCRIPT" variable along with proper timeout of the script mentioned in "SET_SSH_KEY_TIMEOUT" variable. activity.sh will call this script in case the first ssh with root login attempt fails.
* A directory with enough disk space must be mentioned in "REPORT_DIR" variable where all the generated reports will be stored. (by default it is user's home directory).
* A reference server must be mentioned in "REFERENCE_SERVER" to validate passwords of users running this script and a personal UNIX/Linux web server with php enabled is recommended to be mentioned in "WEBSERVER" variable along with website directory mentioned in "WEBSITE_PATH" variable to publish the generated reports on website (by default localhost is mentioned). These servers must be accessible through ssh with root login without needing root password.
* If the activity.php file needs to be moved to any other directory, make sure it is mentioned in "WEBPAGE_FILE" variable.

## How to setup and run
* [Download zip file](https://github.com/sayanarijit/activity.sh/archive/master.zip)
```
wget https://github.com/sayanarijit/activity.sh/archive/master.zip
```
* Extract zip
```
unzip master.zip
```
* Modify script (change SET_SSH_KEY_SCRIPT, SET_SSH_KEY_TIMEOUT, REPORT_DIR, REFERENCE_SERVER, WEBSERVER, WEBSITE_PATH etc. variables as per your [requirement] (#requirements-pre-checks-and-pre-configuration))
```
cd activity.sh-master
vim activity.sh
```
* Create path for website on webserver
```
sudo mkdir -p "/var/www/html/activity-reports"       # Assuming localhost is the webserver (must be running php)
```
* Run script
```
chmod +x activity.sh
./activity.sh
```
