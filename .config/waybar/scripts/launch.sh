#!/bin/bash

killall -9 waybar

nohup waybar </dev/null >/dev/null 2>&1 & disown
