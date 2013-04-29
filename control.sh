#!/bin/sh
# control.sh - http://github.com/salaman/brew-webstack-control
#
# Script to control a Homebrew-installed NGINX + PHP-FPM + MySQL stack.
# Potentially extendable to other processes (see configuration below).
#
# This file is public domain and comes with NO WARRANTY of any kind.
#
# Configuration:
# Each process to handle has one configuration "block" comprised
# of a few set variables, some of which are required:
#
# (required) CONF_PATH
#   Path to the executable file used for launching.
# (required) CONF_PID
#   Path to the process' pidfile.
#
# (optional) CONF_SUDO
#   Set to true to run all commands for the process with sudo.
# (optional) CONF_START
#   Custom command used to launch process.
#   If absent, CONF_PATH will be executed during start.
# (optional) CONF_STOP
#   Custom command used to stop process.
#   If absent, SIGQUIT will be sent to the process.
# (optional) CONF_RELOAD
#   Custom command used to reload process configuration.
#   If absent, process will be skipped during reload.
#
# In CONF_STOP and CONF_RELOAD, any occurence of the string
# "__PID__" will be replaced with the running process' PID.
#

i=0 # Configuration start, do not change

#################################################
### BEGIN USER CONFIGURATION
#################################################

## nginx

CONF_PATH[$i]="$(brew --prefix nginx)/bin/nginx"
CONF_PID[$i]="/usr/local/var/run/nginx.pid"
CONF_SUDO[$i]=true
CONF_RELOAD[$i]="${CONF_PATH[$i]} -s reload"
(( i++ ))

## php-fpm

CONF_PATH[$i]="$(brew --prefix php54)/sbin/php-fpm"
CONF_PID[$i]="/usr/local/var/run/php-fpm.pid"
CONF_START[$i]="${CONF_PATH[$i]} -D"
CONF_RELOAD[$i]="kill -USR2 __PID__"
(( i++ ))

## mysqld

CONF_PATH[$i]="$(brew --prefix mysql)/bin/mysql.server"
CONF_PID[$i]="/usr/local/var/mysql/$(hostname).pid"
CONF_START[$i]="${CONF_PATH[$i]} start"
CONF_STOP[$i]="${CONF_PATH[$i]} stop"
CONF_RELOAD[$i]="${CONF_PATH[$i]} reload"
(( i++ ))

#################################################
### END USER CONFIGURATION
#################################################

is_running() {
    if [ "$#" -eq "1" ]; then
        if [ -z "${CONF_PID[$1]}" ]; then # Check if there is a pidfile in conf
            echo "\033[33mPlease specify a pidfile for $(basename ${CONF_PATH[$1]}).\033[m"
        elif [ -r "${CONF_PID[$1]}" -a -s "${CONF_PID[$1]}" ]; then # Check if the pidfile exists
            PROC_PID=`cat ${CONF_PID[$1]}`
            local P_COUNT=`ps xww -o pid= -p ${PROC_PID}` # Make sure the PID actually exists
            if [ "$P_COUNT" -ge "0" ]; then
                return 1 # Process is running
            fi
        fi
    fi

    return 0 # Process not running or wrong parameters
}

do_for_all_paths() {
    for (( i = 0; i < ${#CONF_PATH[@]}; i++ )); do
        # Make sure path is valid and executable
        if [ ! -x "${CONF_PATH[$i]}" ]; then
            echo "\033[33mPath \"${CONF_PATH[$i]}\" is not a valid executable file.\033[m"
            continue
        fi

        # Set command prefix if sudo is needed
        [ "${CONF_SUDO[$i]}" = "true" ] && CMD_PREFIX="sudo " || CMD_PREFIX=

        # Call appropriate action function
        $1 $i
    done
}

start() {
    is_running $i
    local TMP_RUNNING=$?
    if [ "$TMP_RUNNING" -eq "0" ]; then # Make sure process is not running
        echo "\033[32mStarting $(basename ${CONF_PATH[$1]})...\033[m"
        if [ -n "${CONF_START[$1]}" ]; then
            ${CMD_PREFIX}${CONF_START[$1]}
        else
            # Execute normally from path
            ${CMD_PREFIX}${CONF_PATH[$1]}
        fi
    fi
}

stop() {
    is_running $i
    local TMP_RUNNING=$?
    if [ "$TMP_RUNNING" -gt "0" ]; then # Make sure process is running
        echo "\033[32mStopping $(basename ${CONF_PATH[$1]}) (pid ${PROC_PID})...\033[m"
        if [ -n "${CONF_STOP[$1]}" ]; then
            ${CMD_PREFIX}${CONF_STOP[$1]//__PID__/${PROC_PID}}
        else
            # Send SIGQUIT
            ${CMD_PREFIX}kill -QUIT ${PROC_PID}
        fi
    fi
}

reload() {
    is_running $i
    local TMP_RUNNING=$?
    if [ "$TMP_RUNNING" -gt "0" ]; then # Make sure process is running
        if [ -n "${CONF_RELOAD[$1]}" ]; then
            echo "\033[32mReloading $(basename ${CONF_PATH[$1]})...\033[m"
            ${CMD_PREFIX}${CONF_RELOAD[$1]//__PID__/${PROC_PID}}
        fi
    fi
}

status() {
    is_running $i
    local TMP_RUNNING=$?
    if [ "$TMP_RUNNING" -gt "0" ]; then
        # Process is running
        echo "\033[32m$(basename ${CONF_PATH[$1]}) is running; pid ${PROC_PID}\033[m"
    else
        # Process is not running
        echo "$(basename ${CONF_PATH[$1]}) is not running"
    fi
}

case "$1" in
    start|stop|reload|status)
        do_for_all_paths $1
        ;;
    restart)
        do_for_all_paths stop
        sleep 1
        do_for_all_paths start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|reload|status}"
        ;;
esac
