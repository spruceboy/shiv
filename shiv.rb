require 'rubygems'
require 'mongrel'
require 'pp'
require 'lumber'
require 'tile_engine'
require 'handler'
require 'yaml'
require 'kml_generator'
 
 # Ussage
 if (ARGV.length != 2)
   puts("Usage: ./shiv.rb <configfile.yml> <port_number>")
   exit(-1)
 end
 
 #load config file..
 cfg = File.open(ARGV.first) {|x| YAML.load(x)}
 if ( cfg == nil )
   puts("Usage: ./shiv.rb <configfile.yml>")
   puts("#{ARGV.first} is not a good yaml file... try again later..")
   exit(-1)
 end

 #get a logger..
 logger = TileLumber.new(cfg["log"])
 logger.logstatus("Starting.")
 
 #Create a mongrel server..
 h = Mongrel::HttpServer.new(cfg["http"]["bind"], ARGV[1].to_i)
 logger.loginfo("Server up, #{cfg["http"]["bind"]}/#{ARGV[1].to_i} ")
 
 #mount up the /benchmark area..
 h.register( cfg["http"]["base"] + "/benchmark", BenchmarkHandler.new(logger))
 
 #mount up the /exit area..
 h.register( cfg["http"]["base"] + "/magic/exit", ExitHandler.new(logger))
 
 
 #loop though the tile engines in the config file, and fire up and mount each..
 cfg["tile_engines"].each do |tcfg|
    path = cfg["http"]["base"] + "/" + tcfg["title"] + "/tile/"
    logger.msginfo("Main:Setting up '#{path}''")
    h.register(path, TileHandler.new(tcfg, logger, cfg["http"]))
    path = cfg["http"]["base"] + "/" + tcfg["title"] + "/bbox/"
    logger.msginfo("Main:Setting up '#{path}''")
    h.register(path, BBoxTileHandler.new(tcfg, logger, cfg["http"]))
 end
 h.register(cfg["http"]["base"] + "/" + "kml", KMLHandler.new(logger, cfg["kml"]))
 
 
 logger.logstatus("Up.")
 
 # Done, begin the fun!
 h.run.join
