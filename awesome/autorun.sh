#!/bin/sh

run() {
  if ! pgrep -f "$1" ; 
  then
     "$@" &
  fi
}

run "/usr/bin/nitrogen" --restore
run "/usr/bin/VBoxClient-all"
run "/home/tom/.config/awesome/autohidewibox.py"
