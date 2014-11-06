require "shiv_includes"
require "pp"


send_map = Proc.new do |x|
	STDERR.puts "Foo!:#{x}"
	return "X-Sendfile"
end

#use Rack::Sendfile,
#	:variation => "X-Sendfile",
#	:mapping => nil
use Rack::Sendfile
use Rack::CommonLogger


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

app= Roundhouse.new(cfg)

# setup caching
if ( cfg["http"]["memcache"] )
        require 'dalli'
        require 'rack/cache'
        use Rack::Cache, :verbose     => true, 
               :metastore   => cfg["http"]["memcache"]["servers"][0] + cfg["http"]["memcache"]["tag"]+"_meta",
               :entitystore => cfg["http"]["memcache"]["servers"][0] + cfg["http"]["memcache"]["tag"]+"_entity"
        puts "Rack Cache Using: #{cfg["http"]["memcache"]["servers"][0] + cfg["http"]["memcache"]["tag"]+"meta"} " + 
		"and #{cfg["http"]["memcache"]["servers"][0] + cfg["http"]["memcache"]["tag"]+"entity"}"
end

run app
