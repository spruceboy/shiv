require "shiv_includes"
require "pp"

cfg = Object::File.open("shiv.yml"){|x| YAML.load(x)}

# So, once a upon a time it was possible to pass arguments to rackup configs via the comand line..
# then it stopped working, and life was bad.
# meanwhile, this code switched to passing arguments via the --eval line..

if (set_postfix)
	cfg["log"]["logdir"] = "./logs"+set_postfix  #passed via the "--eval" arguements to rackup.. 
	cfg["idler"] = "./idler"+set_postfix 
else
	cfg["log"]["logdir"] = "./logs/"  #double check..
	cfg["idler"] = "./idler_default"
end
use Rack::Sendfile
use Rack::CommonLogger
run Roundhouse.new(cfg)

