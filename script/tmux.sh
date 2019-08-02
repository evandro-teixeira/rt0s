#!/bin/bash

session="rt0s"

tmux -2 new-session -d -s $session

tmux new-window -t $session:1 -n 'DBG'
tmux split-window -h
tmux select-pane -t 0
tmux send-keys "arm-none-eabi-gdb -x script/gdbinit" C-m
tmux select-pane -t 1
tmux send-keys "JLinkExe -device STM32F030R8 -if SWD -speed 4000 \
	-autoconnect 1" C-m
tmux select-pane -t 0

tmux -2 attach-session -t $session

