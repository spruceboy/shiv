require "shiv_includes"
require "pp"

cfg = Object::File.open("shiv.yml"){|x| YAML.load(x)}

# So, once a upon a time it was possible to pass arguments to rackup configs via the comand line..
# then it stopped working, and life was bad.
# meanwhile, this code switched to passing arguments via the --eval line..

if (log_dir)
	cfg["log"]["logdir"] = log_dir  #passed via the "--eval" arguements to rackup.. 
else
	cfg["log"]["logdir"] = "./logs/"  #double check..
end
run Roundhouse.new(cfg)

