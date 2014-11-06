#!/usr/bin/env ruby


require "rubygems"
require "http_client_tools"
require "yaml"
require "pp"


require 'trollop'
require 'yaml'

opts = Trollop::options do
  opt :verbose, "Be more verbose", :default => false
  opt :config, "Config file", :default => "./conf.d/bdl_google.conf.yml"
  opt :z, "max zoom", :default => 10
  opt :min_z, "min zoom", :default => 7
  opt :towns, "towns", :default => "tools/towns_plus.yml"
  opt :queue, "queue", :default => "./idler_1"
  opt :fiddle, "fiddle", :default => 128
  opt :key, "projection (google)", :default => "google"
end

PATH_FORMAT = "%02d/%03d/%03d/%09d/%09d/%09d_%09d_%09d.%s"

# Returns path to an (x,y,z) set.. 
def done? (x,y,z, cache_dir, storage_format = "jpg")
         #puts cache_dir + sprintf(PATH_FORMAT, z,x%128,y%128,x,y,x,y,z,storage_format)
         File.exists?(cache_dir + sprintf(PATH_FORMAT, z,x%128,y%128,x,y,x,y,z,storage_format))
end




def get_tile ( x,y,z,cfg)
     w_x = (cfg["base_extents"]["xmax"] - cfg["base_extents"]["xmin"])/(2.0 **(z.to_f))
     w_y = (cfg["base_extents"]["ymax"] - cfg["base_extents"]["ymin"])/(2.0 **(z.to_f))
    tile_x = ((x.to_f-cfg["base_extents"]["xmin"])/w_x ).to_i
    tile_y = ((y.to_f-cfg["base_extents"]["ymin"])/w_y ).to_i
    return { "x" => tile_x, "y" => tile_y}
end


def shuffle (s )
     0.upto(s.length) do |x|
	  i = rand(s.length-1)
	  z = i
	  while (z==i)
	       z = rand(s.length) 
	  end
	  
	  t = s[i]
	  s[i] = s[z]
	  s[z] = t
     end
     
     return s
end

def do_tile(cfg, x,y,z,waggle, config_path)
     waffle = 0
     max = 2**z-1
     STDOUT.printf(" #{z} ")
     i = (x-waggle)
     while (i <= x+waggle) do 
	  j = (y-waggle)
	  while ( j <= y+waggle) do
	       i = 0 if (i < 0)
	       j = 0 if (j < 0)
	       i = max if (i >max)
	       j = max if (j > max)
	       #system("ruby", "tile_grabber.rb", config_path, name, "#{i}", "#{j}", "#{z}")
	       #puts("Seed: #{config_path} #{i} #{j} #{z}")
	       @queue.syswrite("#{config_path} #{i} #{j} #{z}\n") 
		if ( !done?(i,j,z, cfg["cache_dir"]))
			@queue.syswrite("#{config_path} #{i} #{j} #{z}\n")
			@queue.flush
			waffle += 1
		end
	       if ( waffle%200 == 0)
		    STDOUT.printf(".")
		    STDOUT.flush()
	       end
	       j += cfg["tiles"]["y_count"]
	  end
	 i += cfg["tiles"]["x_count"]
	 sleep(1)
     end
     
     return if (z <= @min_zoom)
     do_tile(cfg, x/2, y/2, z-1, waggle/2, config_path) if ( x != 0 && y != 0 && z != 0)
end



tile_conf = File.open(opts[:config]){|x| YAML.load(x) }
towns_conf = File.open(opts[:towns]){|x| YAML.load(x) }

z = opts[:z].to_i
fiddle = opts[:fiddle]
key = opts[:key]
@min_zoom = opts[:min_z]

@queue = File.open(opts[:queue], "w") 

shuffle(towns_conf.keys).each do |town_k|
	  STDOUT.printf("Doing #{key}|#{town_k}:")
	  STDOUT.flush()
	  town = towns_conf[town_k]
	  pp town
	  tile = get_tile(town[key][0], town[key][1], z, tile_conf )
	  puts ("#{town_k}  http://tiles.gina.alaska.edu/tiles/#{tile_conf["title"]}/tile/#{tile["x"]}/#{2**z -tile["y"]}/#{z}  http://tiles.gina.alaska.edu/tiles/#{tile_conf["title"]}/tile/#{tile["x"]/8}/#{2**(z-3) -tile["y"]/8}/#{z-3}")
	  do_tile(tile_conf, tile["x"], tile["y"], z, fiddle, opts[:config])
end

puts("Done.")
