#!/bin/bash
. ~/.bashrc
export PATH=$PATH:/usr/local/bin/
cd /home/webdev/tilesrv
screen -d -m -S shiv_one /usr/local/bin/ruby shiv.rb shiv.3333.yml 3333 
screen -d -m -S shiv_two /usr/local/bin/ruby shiv.rb shiv.3334.yml 3334

