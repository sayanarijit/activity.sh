#!/bin/bash

# set -x   # For debugging

# Menu with function declarations ----------------------------------------------
declare -A MENU
MENU[a]="ping-check"
MENU[b]="ssh-check"
MENU[c]="console-check"
MENU[d]="config-check"
MENU[e]="execute-command"
MENU[f]="login-check"
MENU[w]="publish-unpublish"
MENU[x]="delete-activity"
MENU[y]="rename-activity"

# Initialize global variables --------------------------------------------------
REPORT_DIR="/tmp/activity-reports"

# ACTIVITY_NAME
if [ -d "$REPORT_DIR" ] && [ "$(ls $REPORT_DIR)" ]; then
  echo "Previous activities"
  echo "───────────────────"
  ls -t -1 $REPORT_DIR
  echo
  read -p "Enter activity name to continue or leave blank to start fresh : " ACTIVITY_NAME
  echo
  [ "$ACTIVITY_NAME" ] && [ ! -d "$REPORT_DIR/$ACTIVITY_NAME" ] && echo "Not found !" && exit 1
  [ ! "$ACTIVITY_NAME" ] && ACTIVITY_NAME=$(date|tr ' ' '_'|tr ':' '-')
else
  ACTIVITY_NAME=$(date|tr ' ' '_'|tr ':' '-')
fi

# Paths
ACTIVITY_DIR="$REPORT_DIR/$ACTIVITY_NAME"
BASIC_REPORT_DIR="$ACTIVITY_DIR/basic_report"                                   # Files under it contains hostnames only
PING_CHECK_DIR="$BASIC_REPORT_DIR/ping_check"
SSH_CHECK_DIR="$BASIC_REPORT_DIR/ssh_check"
CONSOLE_CHECK_DIR="$BASIC_REPORT_DIR/console_check"
LOGIN_CHECK_DIR="$BASIC_REPORT_DIR/login_check"
ADVANCE_REPORT_DIR="$ACTIVITY_DIR/advance_report"                               # Files/directories under it contains outputs
EXECUTE_COMMAND_DIR="$ADVANCE_REPORT_DIR/execute_command"
CONFIG_CHECK_DIR="$ADVANCE_REPORT_DIR/config_check"
SET_SSH_KEY_SCRIPT="/script/bin/setPassKey.sh"                                  # Will run if 1st ssh attempt fails
WEBSITE_PATH="/var/www/html/activity-reports"                                   # To publish reports in website
WEBPAGE_FILE="./activity.php"                                                   # This is the home page for website

# Timeouts
SSH_TIMEOUT=10
SSH_SET_KEY_TIMEOUT=25

# Servers
WEBSERVER="localhost"                                                           # Will be used to publish reports
REFERENCE_SERVER="localhost"                                                    # Will be used to varify ssh passwords

# unix PASSWORD
while :; do
  read -sp "Enter unix password : " PASSWORD && echo && \
   sshpass -p $PASSWORD ssh -q -o ConnectTimeout=3 -o StrictHostKeyChecking=no $REFERENCE_SERVER id &>/dev/null && \
    break
done

# Other variables
MAX_BACKGROUND_PROCESS=100;                                                     # Maximum no. of background process to run simultaneously
HR=$(for ((i=0;i<$(tput cols);i++));do echo -en "─";done;echo)

# Custom functions (can be edited)----------------------------------------------

# Single action functions (executes one host at a time)

generate-ping-report ()
{
  if ping -c1 -w1 $1 &>/dev/null; then
    echo $1 >> "$PING_CHECK_DIR/available_hosts"
  else
    echo $1 >> "$PING_CHECK_DIR/unavailable_hosts"
  fi
  return 0
}

generate-ssh-report ()
{
  sudo ssh-keygen -R $1 &>/dev/null
  ssh-keygen -R $1 &>/dev/null

  # Try 1 : Try login with root
  start=$(date +%s)
  hostname=$(timeout -s9 $SSH_TIMEOUT sudo ssh -q -o ConnectTimeout=3 -o StrictHostKeyChecking=no $1 "hostname" 2>/dev/null) &>/dev/null
  end=$(date +%s)

  if [ "$hostname" ];then
    echo $1 >> "$SSH_CHECK_DIR/ssh_reachable_hosts"
    echo $1 >> "$SSH_CHECK_DIR/ssh_with_root_login"
    if (( $end-$start <= 5 )); then
      echo $1 >> "$SSH_CHECK_DIR/ssh_time_within_5_sec"
    else
      echo $1 >> "$SSH_CHECK_DIR/ssh_time_above_5_sec"
    fi
  else
    # Try 2 : Set passwordless key and try login with root
    temp=$(timeout -s9 $SSH_SET_KEY_TIMEOUT sudo $SET_SSH_KEY_SCRIPT $1 &>/dev/null) &>/dev/null

    start=$(date +%s)
    hostname=$(timeout -s9 $SSH_TIMEOUT sudo ssh -q -o ConnectTimeout=3 -o StrictHostKeyChecking=no $1 "hostname" 2>/dev/null) &>/dev/null
    end=$(date +%s)

    if [ "$hostname" ];then
      echo $1 >> "$SSH_CHECK_DIR/ssh_reachable_hosts"
      echo $1 >> "$SSH_CHECK_DIR/ssh_with_root_login"
      if (( $end-$start <= 5 )); then
        echo $1 >> "$SSH_CHECK_DIR/ssh_time_within_5_sec"
      else
        echo $1 >> "$SSH_CHECK_DIR/ssh_time_above_5_sec"
      fi
    else
      # Try 3 : Login with unix account
      start=$(date +%s)
      hostname=$(timeout -s9 $SSH_TIMEOUT sshpass -p $PASSWORD ssh -q -o ConnectTimeout=3 -o StrictHostKeyChecking=no $1 "hostname" 2>/dev/null) &>/dev/null
      end=$(date +%s)

      if [ "$hostname" ];then
        echo $1 >> "$SSH_CHECK_DIR/ssh_reachable_hosts"
        echo $1 >> "$SSH_CHECK_DIR/ssh_root_login_not_possible"
        if (( $end-$start <= 5 )); then
          echo $1 >> "$SSH_CHECK_DIR/ssh_time_within_5_sec"
        else
          echo $1 >> "$SSH_CHECK_DIR/ssh_time_above_5_sec"
        fi
      else
        echo $1 >> "$SSH_CHECK_DIR/ssh_unreachable_hosts"
      fi
    fi
  fi
  return 0
}

generate-execute-command-report ()
{
  hosts=()
  file="$SSH_CHECK_DIR/ssh_with_root_login"
  [ -f "$file" ] && hosts=( $(cat "$file") )
  if in-array $1 ${hosts[*]}; then
    ssh_string="sudo ssh -q -o ConnectTimeout=3 -o StrictHostKeyChecking=no"
  else
    hosts=()
    file="$SSH_CHECK_DIR/ssh_root_login_not_possible"
    [ -f "$file" ] && hosts=( $(cat "$file") )
    if in-array $1 ${hosts[*]}; then
      ssh_string="sshpass -p $PASSWORD ssh -q -o ConnectTimeout=3 -o StrictHostKeyChecking=no"
    else
      echo "SSH: $1 : Not reachable" >> $3/error/$1
      return 1
    fi
  fi
  temp=$(timeout -s9 $SSH_TIMEOUT $ssh_string $1 "$2" > $3/output/$1 2> $3/error/$1) 2>/dev/null
}

generate-console-report ()
{
  cons="ilo con imm ilom alom xscf power"
  for c in $cons;do
    fqdn=""
    ping -c1 -w1 "$1-$c" &>/dev/null && \
     fqdn=$(nslookup "$1-$c"|grep -i "$1-$c"|grep -v NXDOMAIN|awk '{ if (/Name:/) {print $2} else if (/canonical name/) {print $1} else {print $0} }') && \
      echo "$1 $fqdn" >> $CONSOLE_CHECK_DIR/console_available && break
  done
  [ ! "$fqdn" ] && echo $1 >> $CONSOLE_CHECK_DIR/console_not_available
}

generate-login-report ()
{
  hosts=()
  file="$SSH_CHECK_DIR/ssh_with_root_login"
  [ -f "$file" ] && hosts=( $(cat "$file") )
  if in-array $1 ${hosts[*]}; then
    user=$(sudo ssh -q -o ConnectTimeout=3 -o StrictHostKeyChecking=no $1 "last|grep pts|grep -v root|tail -1"|awk '{print $1}')
    [ ! "$user" ] && echo $1 >> "$LOGIN_CHECK_DIR/no_user_found" && return 0
    id=$(sudo ssh -q -o ConnectTimeout=3 -o StrictHostKeyChecking=no $1 "su $user -s /bin/sh -c 'cd && id'" 2>/dev/null)
    if [ "$id" ]; then
      echo $1 >> "$LOGIN_CHECK_DIR/user_login_successful"
    else
      echo $1 >> "$LOGIN_CHECK_DIR/user_login_unsuccessful"
    fi
  else
    echo $1 >> "$LOGIN_CHECK_DIR/ssh_root_login_not_possible"
  fi
}

# Looper functions (reads input and calls single action functions in loop)
ping-check ()
{
  [ -d "$PING_CHECK_DIR" ] && rm -rf "$PING_CHECK_DIR"
  mkdir -p "$PING_CHECK_DIR" || exit 1

  echo "Paste targets below and press 'CTRL+D'"
  echo "──────────────────────────────────────"
  cat > $PING_CHECK_DIR/all_hosts
  targets=( $(cat "$PING_CHECK_DIR/all_hosts") )
  echo
  [ ! "${targets}" ] && echo "No target found..." && exit 1

  i=0
  c=${#targets[*]}
  for t in ${targets[*]}; do
    i=$(($i+1))
    echo -en "  Generating ping check report... ($i/$c)                 \r"
    generate-ping-report $t &
    [ $(($i%$MAX_BACKGROUND_PROCESS)) == 0 ] && wait
  done
  wait
  echo "                                                                   "
}

ssh-check ()
{
  [ -f "$PING_CHECK_DIR/available_hosts" ] || ping-check
  [ -d "$SSH_CHECK_DIR" ] && rm -rf "$SSH_CHECK_DIR"
  mkdir -p "$SSH_CHECK_DIR" || exit 1

  targets=( $(cat "$PING_CHECK_DIR/available_hosts") )
  echo
  [ ! "${targets}" ] && echo "No target found..." && exit 1

  sudo ssh 2>/dev/null
  i=0
  c=${#targets[*]}
  for t in ${targets[*]}; do
    i=$(($i+1))
    echo -en "  Generating ssh check report... ($i/$c)                 \r"
    generate-ssh-report $t &
    [ $(($i%$MAX_BACKGROUND_PROCESS)) == 0 ] && wait
  done
  wait
  echo "                                                                   "
}

execute-command ()
{
  [ -f "$SSH_CHECK_DIR/ssh_reachable_hosts" ] || ssh-check

  dir="$EXECUTE_COMMAND_DIR/$(date +%s)"
  mkdir -p "$dir/output" || exit 1
  mkdir -p "$dir/error" || exit 1

  targets=( $(cat "$SSH_CHECK_DIR/ssh_reachable_hosts") )
  echo
  [ ! "${targets}" ] && echo "No target found..." && exit 1

  read -p "Enter command to run on reachable servers : " command_to_run
  [ ! "$command_to_run" ] && echo "No command to run !" && exit 1
  echo "$command_to_run" > "$dir/name" || exit 1

  sudo ssh 2>/dev/null
  c=${#targets[*]}
  i=0
  for t in ${targets[*]}; do
    i=$(($i+1))
    echo -en "  Generating command output report... ($i/$c)                 \r"
    generate-execute-command-report $t "$command_to_run" "$dir" &
    [ $(($i%$MAX_BACKGROUND_PROCESS)) == 0 ] && wait
  done
  wait
  echo "                                                                   "
  echo "Find the report inside directory- $dir"
  echo "or publish this activity report to access it in browser."
  echo
  read -sp "[press ENTER to continue]"
}

console-check ()
{
  [ -f "$PING_CHECK_DIR/all_hosts" ] || ping-check
  [ -d "$CONSOLE_CHECK_DIR" ] && rm -rf "$CONSOLE_CHECK_DIR"
  mkdir -p "$CONSOLE_CHECK_DIR" || exit 1

  targets=( $(cat "$PING_CHECK_DIR/all_hosts") )
  echo
  [ ! "${targets}" ] && echo "No target found..." && exit 1

  i=0
  c=${#targets[*]}
  for t in ${targets[*]}; do
    i=$(($i+1))
    echo -en "  Generating console check report... ($i/$c)                 \r"
    generate-console-report $t &
    [ $(($i%$MAX_BACKGROUND_PROCESS)) == 0 ] && wait
  done
  wait
  echo "                                                                   "
}

config-check ()
{
  files_to_check=( "/etc/fstab" "/etc/passwd" "/etc/shadow" "/etc/master.passwd" "/etc/mtab" \
                  "/etc/nsswitch.conf" "/etc/yp.conf" "/etc/ssh/sshd_config" "/etc/network/interfaces" \
                  "/etc/puppet.conf" "/var/spool/cron/crontabs/root" "/etc/sudoers" )

  command_to_run="echo OS Arch;echo =============================;uname -a;echo;echo;"
  command_to_run=$command_to_run"echo Linux distro;echo =============================;lsb_release -a;echo;echo;"
  command_to_run=$command_to_run"echo Uptime;echo =============================;uptime;echo;echo;"
  command_to_run=$command_to_run"echo Network;echo =============================;ifconfig -a;echo;echo;"
  command_to_run=$command_to_run"echo Gateway;echo =============================;netstat -nr;echo;echo;"

  for f in ${files_to_check[*]}; do
    command_to_run=$command_to_run"echo $f;echo =============================;cat $f;echo;echo;"
  done

  [ -f "$SSH_CHECK_DIR/ssh_reachable_hosts" ] || ssh-check

  dir="$CONFIG_CHECK_DIR/$(date +%s)"
  mkdir -p "$dir/output" || exit 1
  mkdir -p "$dir/error" || exit 1

  targets=( $(cat "$SSH_CHECK_DIR/ssh_reachable_hosts" 2>/dev/null) )
  echo
  [ ! "${targets}" ] && echo "No target found..." && exit 1

  echo "Config check - "$(date) > $dir/name || exit 1

  sudo ssh 2>/dev/null
  c=${#targets[*]}
  i=0
  for t in ${targets[*]}; do
    i=$(($i+1))
    echo -en "  Generating configuration check report... ($i/$c)                 \r"
    generate-execute-command-report $t "$command_to_run" "$dir" &
    [ $(($i%$MAX_BACKGROUND_PROCESS)) == 0 ] && wait
  done
  wait
  echo "                                                                   "
  echo "Find the report inside directory- $dir"
  echo "or publish this activity report to access it in browser."
  echo
  read -sp "[press ENTER to continue]"
}

login-check ()
{
  [ -f "$SSH_CHECK_DIR/ssh_with_root_login" ] || ssh-check
  [ -d "$LOGIN_CHECK_DIR" ] && rm -rf "$LOGIN_CHECK_DIR"
  mkdir -p "$LOGIN_CHECK_DIR" || exit 1

  targets=( $(cat "$SSH_CHECK_DIR/ssh_with_root_login") )
  echo
  [ ! "${targets}" ] && echo "No target found..." && exit 1

  sudo ssh 2>/dev/null
  c=${#targets[*]}
  i=0
  for t in ${targets[*]}; do
    i=$(($i+1))
    echo -en "  Generating login check report... ($i/$c)                 \r"
    generate-login-report $t &
    [ $(($i%$MAX_BACKGROUND_PROCESS)) == 0 ] && wait
  done
  wait
  echo "                                                                   "
}

# Core functions (do not edit) -------------------------------------------------

in-array ()
{
  x=$1 && shift
  for e; do
    [[ $x == $e ]] && return 0
  done
  return 1
}

publish-unpublish ()
{
  if sudo ssh $WEBSERVER "ls -d $WEBSITE_PATH/$ACTIVITY_NAME &>/dev/null" ; then
    echo
    echo -e "This activity is published on \e[40;38;5;82m http://\e[30;48;5;82m$WEBSERVER/activity-reports/$ACTIVITY_NAME \e[0m"
    echo
    read -sp "[press ENTER to unpublish current activity report]"
    sudo ssh $WEBSERVER "rm -rf $WEBSITE_PATH/$ACTIVITY_NAME"
   else
    read -sp "[press ENTER to publish current activity report]"
    sudo scp -r "$ACTIVITY_DIR" "$WEBSERVER:$WEBSITE_PATH/$ACTIVITY_NAME"
    sudo scp "$WEBPAGE_FILE" "$WEBSERVER:$WEBSITE_PATH/$ACTIVITY_NAME/index.php"
    if [ $? == 0 ]; then
      echo
      echo -e "This activity report is published on \e[40;38;5;82m http://\e[30;48;5;82m$WEBSERVER/activity-reports/$ACTIVITY_NAME \e[0m"
      echo
      read -sp "[press ENTER to continue]"
    else
      echo
      echo "Could not publish activity report. Please try again."
      echo
      read -sp "[press ENTER to continue]"
    fi
  fi
}

delete-activity ()
{
  echo
  echo "You are going to delete $ACTIVITY_DIR and unpublish website if exists."
  echo
  read -sp "[press ENTER to confirm deletion]"
  echo
  if sudo ssh $WEBSERVER "ls -d $WEBSITE_PATH/$ACTIVITY_NAME &>/dev/null" ; then
    sudo ssh $WEBSERVER "rm -rf $WEBSITE_PATH/$ACTIVITY_NAME"
  fi
  [ -d "$ACTIVITY_DIR" ] && rm -rf "$ACTIVITY_DIR" && echo "Deleted $ACTIVITY_DIR"
  exit 0
}

rename-activity ()
{
  if [ ! -d "$ACTIVITY_DIR" ];then
    echo; echo "Activity hasn't started yet !"; echo
  else
    read -p "Enter new name for this activity : " name
    if [ "$name" ]; then
      name=$(echo "$name"|sed -e 's/[^a-zA-Z0-9]/_/g')
      if sudo ssh $WEBSERVER "ls -d $WEBSITE_PATH/$ACTIVITY_NAME &>/dev/null" ; then
        sudo ssh $WEBSERVER "mv -f $WEBSITE_PATH/$ACTIVITY_NAME $WEBSITE_PATH/$name"
      fi
      mv -f "$ACTIVITY_DIR" "$REPORT_DIR/$name" && echo "Rename successful..." && exit 0
    fi
  fi
  read -sp "[press ENTER to continue]"
}

display-menu ()
{
  declare -A reports
  while :; do
    clear
    [ -d "$ACTIVITY_DIR" ] && chmod -R 0777 "$ACTIVITY_DIR" 2>/dev/null
    # Display report
    echo -e "Activity name: $ACTIVITY_NAME    Activity dir: $ACTIVITY_DIR"
    echo $HR

    basic_reports=( $(find "$BASIC_REPORT_DIR" -type d 2>/dev/null) )
    unset basic_reports[0]
    i=0
    report=""
    for d in ${basic_reports[*]}; do
      report=$report"\e[4m$(basename $d)\e[0m \n"
      found=( $(find $d -type f 2>>/dev/null) )
      for f in ${found[*]}; do
        i=$(($i+1))
        reports[$i]="$f"
        report=$report" $i) $(basename $f) : $(cat $f|wc -l) \n"
      done
    done

    advance_reports=( $(find "$ADVANCE_REPORT_DIR" -maxdepth 1 -type d 2>/dev/null) )
    unset advance_reports[0]
    i=0
    for d in ${advance_reports[*]}; do
      report=$report"\e[4m$(basename $d)\e[0m \n"
      found=( $(find "$d" -maxdepth 1 -type d 2>/dev/null) )
      unset found[0]
      for f in ${found[*]}; do
        i=$(($i+1))
        reports[e$i]="$f/error"
        reports[o$i]="$f/output"
        report=$report" o$i) $(cat "$f/name"|tr " " "_") output \n"
        report=$report" e$i) $(cat "$f/name"|tr " " "_") error \n"
      done
    done

    [ ! "${reports[*]}" ] && report="Nothing to show !"
    echo -e "$report"|column -t|tr '_' ' '
    echo

    # Print menu
    menu=""
    for k in ${!MENU[@]};do
      menu=$menu"$k)_${MENU[$k]}\n"
    done
    echo $HR
    echo -e "$menu"|column -x|tr "-" " "|tr "_" " "
    echo $HR

    # Prompt for input
    ans=""
    read -p "> " ans
    case $ans in
      [1-9])
        [ "${reports[$ans]}" ] && echo && cat ${reports[$ans]} && echo && read -sp "[Press ENTER to continue]";;
      [eo][1-9])
        read -p "Search hostname(wildcard) or leave blank to display all : " search && echo
        option=""
        [ "$search" ] && option="-name "$search

        for h in $(find ${reports[$ans]} -type f $option|xargs -l basename 2>/dev/null);do
          echo "* "$h$HR; cat "${reports[$ans]}/$h"; echo;echo;
        done

        read -sp "[Press ENTER to continue]";;
      [a-z])
        ${MENU[$ans]};;
    esac
    [ -d "$ACTIVITY_DIR" ] && chmod -R 0777 "$ACTIVITY_DIR" 2>/dev/null
  done
  echo
}

# Function call ----------------------------------------------------------------
display-menu
