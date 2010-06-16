screen -S shiv-prod-5555 -d -m rackup --eval "log_dir='./logs/'" -E deployment -p 5555 -s mongrel shiv.ru ./log_one/


