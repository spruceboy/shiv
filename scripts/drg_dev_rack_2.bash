#!/bin/bash
. $HOME/.bashrc
rackup --eval "log_dir='./logs2/'" -E deployment -p 5557 -s mongrel shiv.ru 


