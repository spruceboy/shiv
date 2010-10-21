#!/bin/bash
# Example "start" script..
# Fires up two instances shiv
screen -S shiv-dev_drg_1 -d -m scripts/example_dev_rack_1.bash
screen -S shiv-dev_drg_2 -d -m scripts/example_dev_rack_2.bash



