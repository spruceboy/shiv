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

if (ARGV.length != 1)
  puts("Usage:")
  puts("\t./tile_grabber.rb {pipe}")
  YAML.dump({"error"=>true, "logs"=>[]}, STDOUT)
  exit(-1)
end

pipe = File.open(ARGV[0])
waffle=0  #event counter..
start_time = Time.now

while (true)
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
   
    ln = pipe.readline
    list = ln.split
    tile = {"cfg"=>list[0], "x" => list[1].to_i,"y" => list[2].to_i,"z" => list[3].to_i}
    next if (!(tile["cfg"] && tile["x"] && tile["y"] && tile["z"] ))

    cfg = File.open(tile["cfg"]) {|fd| YAML.load(fd)}

    # x,y,z -> self explainitaory. 
    x = tile["x"]
    y = tile["y"]
    z = tile["z"]

    raise ("x,y,or z is out of range for (#{x},#{y},#{z})") if (x > (2**(z+1)) || y > (2**(z+1) ) || z > 24 ) 

    #go though the configs, find the correct one..
    tile_engine =  RmagickTileEngine.new(cfg, log)

    # get the tile in question..
    path = tile_engine.get_tile(x,y,z)

    waffle += 1
    if ( waffle%15 == 0)
      puts("#{waffle} tiles seeded. last one => #{tile["cfg"]} #{tile["x"]} #{tile["y"]} #{tile["z"]}")
      puts("\trate is: #{15.0/(Time.now - start_time)} sets/sec")
      start_time = Time.now
      waffle = 0 if (waffle > 1000000)
    end
  rescue EOFError => e
    sleep(20)
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
    #Mailer.deliver_message(@cfg["mailer_config"], @cfg["mailer_config"]["to"], "tile grabber crash..", [stuff])
    puts stuff
    YAML.dump({"error"=>false, "logs"=>logs}, STDOUT)
  end
end


