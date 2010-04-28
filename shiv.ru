require "shiv_includes"
require "pp"


#run SimpleHandlerRack.new
#use Rack::CommonLogger

cfg = Object::File.open("shiv.op.yml"){|x| YAML.load(x)}
run Roundhouse.new(cfg)
