export PATH=$PATH:/usr/local/lib/ruby/gems/1.8/bin
screen -S shiv-prod-3333 -d -m rackup -E deployment -p 3333 -s mongrel shiv.ru ./log_one/
screen -S shiv-prod-3334 -d -m rackup -E deployment -p 3334 -s mongrel shiv.ru ./log_two/

