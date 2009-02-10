#!/usr/bin/env ruby
require "rubygems"
require "tempfile"
require "thread"
require "http_client_tools"
require "yaml"
require "tile_engine"
require "lumber"

####
# This thing/wiget/unholy abomination is a command line tile fetcher - used to seperate out the tile extration process from shiv,
# to make things a little more fault tollerant/durrable.

begin
  ##
  # Someday do something useful with these logs - perhaps route back to shiv, and have shiv do something usefull with them.
  error_lst = Array.new
  info_lst = Array.new
  debug_lst = Array.new
  logs = { "error" => error_lst, "info_lst" => info_lst, "debug_lst" => debug_lst}
    
  log = LumberAppendNoFile.new({"debug"=> true, "info" => true, "verbose" => true},error_lst, debug_lst, info_lst )
  log.msginfo("CMD -> {" + ARGV.join(" ") + "}")
  
  ## Read the config file..
  cfg = YAML.load(File.open(ARGV[0]))["tile_engines"]
  
  # This is the "shiv instance" ---> for example "bdl" or "bdl_geo"
  name = ARGV[1]
  
  # x,y,z -> self explainitaory. 
  x = ARGV[2].to_i
  y = ARGV[3].to_i
  z = ARGV[4].to_i

  #go though the configs, find the correct one..
  cfg.each {|item| next if @cfg;  @cfg = item if ( item["title"] == name)}

  # Setup the tile engine
  tile_engine =  RmagickTileEngine.new(@cfg, log)
  
  # get the tile in question..
  path = tile_engine.get_tile(x,y,z)
rescue => e
  require "mailer"
  YAML.dump({"error"=>true, "reason" => e, "backtrace" => e.backtrace, "logs"=>logs }, STDOUT)
  # Ok, something very bad happend here... what to do..
  stuff = ""
  stuff += "--------------------------\n"
  stuff = "Broken at #{Time.now.to_s}"
  stuff += "--------------------------\n"
  stuff += e.to_s + "\n"
  stuff += "--------------------------\n"
  stuff += ARGV.join(" ") + "\n"
  stuff += "--------------------------\n"
  stuff += e.backtrace.join("\n")
  stuff += "--------------------------\n"
  Mailer.deliver_message(@cfg["mailer_config"], @cfg["mailer_config"]["to"], "tile grabber crash..", [stuff])
  exit(-1)
end

YAML.dump({"error"=>false, "logs"=>logs}, STDOUT)


