require "shiv_includes"


#run SimpleHandlerRack.new
#use Rack::CommonLogger


run BenchmarkHandler.new(LumberNoFile.new({}))
