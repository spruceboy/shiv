#!/bin/bash
. $HOME/.bashrc
rackup --eval "log_dir='./logs1/'" -E deployment -p 5556 -s mongrel shiv.ru 


