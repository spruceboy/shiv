#!/bin/bash
# An example "shiv" start script, for one "shiv" instance.
# setup the enviroment..
. $HOME/.bashrc
# start shiv
rackup --eval "log_dir='./logs2/'" -E deployment -p 5557 -s mongrel shiv.ru 
