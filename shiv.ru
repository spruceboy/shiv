require "shiv_includes"


#run SimpleHandlerRack.new
#use Rack::CommonLogger

run Roundhouse.new(File.open("shiv.op.yml"){|x| YAML.load(x)})
