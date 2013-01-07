# brew-webstack-control

A shell script to control, by default, a Homebrew-installed web development stack with nginx, php-fpm and MySQL without using OS X LaunchAgents.

This script could easily be configured to support other daemon processes as well, provided they have pidfiles.

## Usage

```
chmod +x control.sh
./control.sh start|stop|restart|reload|status
```

## Configuration

Each process to handle has one configuration "block" comprised of a few set variables, some of which are required:

* **(required)** `CONF_PATH`
  * Path to the executable file used for launching.
* **(required)** `CONF_PID`
  * Path to the process' pidfile.
* (optional) `CONF_SUDO`
  * Set to true to run all commands for the process with `sudo`.
* (optional) `CONF_START`
  * Custom command used to launch process.
  * If absent, `CONF_PATH` will be executed during start.
* (optional) `CONF_STOP`
  * Custom command used to stop process.
  * If absent, `SIGQUIT` will be sent to the process.
* (optional) `CONF_RELOAD`
  * Custom command used to reload process configuration.
  * If absent, process will be skipped during reload.

In `CONF_STOP` and `CONF_RELOAD`, any occurence of the string `__PID__` will be replaced with the running process' PID.
