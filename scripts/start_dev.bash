#!/bin/bash
rackup -E production -p 3333 -s mongrel --eval "log_dir='./logs/'"  shiv.ru
