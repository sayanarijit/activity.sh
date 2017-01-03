# activity.sh

This is a powerfull (customizable) script for system admins to be prepared for upcoming bulk server activities.

Features:
* Basic functions: ping check, ssh check, console check, configuration check, execute command, login check, report generation.
* Interactive and very easy to use.
* Runs simultaneous background process.
* Smart enough to run functions step by step (e.g. before performing ssh check, it performs ping check first).
* Anyone can modify the global variables, add or delete functions (it's customizable).
* Best feature is, it can create a fully featured website for the reports it has generated to make it easier to browse.

Usage:
* [Download zip] (https://github.com/sayanarijit/activity.sh/archive/master.zip)
```
wget https://github.com/sayanarijit/activity.sh/archive/master.zip
```
* Extract zip
```
unzip master.zip
```
* Modify script
```
cd activity.sh-master
vi activity.sh
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
