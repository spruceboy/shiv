#!/bin/bash
# An example "shiv" start script, for one "shiv" instance.
# setup the enviroment..
. $HOME/.bashrc

# start shiv
rackup --eval "log_dir='./logs1/'" -E deployment -p 5556 -s mongrel shiv.ru 
