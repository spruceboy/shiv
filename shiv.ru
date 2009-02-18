require "shiv_includes"
require "pp"


#run SimpleHandlerRack.new
#use Rack::CommonLogger

cfg = File.open("shiv.op.yml"){|x| YAML.load(x)}
cfg["log"]["logdir"] = ARGV[1]
pp cfg["log"]
run Roundhouse.new(cfg)
