#!/usr/bin/env ruby


require "rubygems"
require "http_client_tools"
require "yaml"
require "pp"


queue = File.open("idler_6", "w")

level = 10

PATH_FORMAT = "%02d/%03d/%03d/%09d/%09d/%09d_%09d_%09d.%s"

# Returns path to an (x,y,z) set.. 
  def done? (x,y,z, cache_dir, storage_format)
	#puts cache_dir + sprintf(PATH_FORMAT, z,x%128,y%128,x,y,x,y,z,storage_format)
        File.exists?(cache_dir + sprintf(PATH_FORMAT, z,x%128,y%128,x,y,x,y,z,storage_format))
  end

ARGV.each do |cfg|
	puts("Doing #{cfg}..")
	tile_cfg = File.open(cfg) {|fd| YAML.load(fd) } 


	x_inc = tile_cfg["tiles"]["x_count"]
	y_inc = tile_cfg["tiles"]["y_count"]
	3.upto(level) do |z|
		x = 0
		while (x < 2**z)
			y = 0
			while ( y < 2**z )
				if ( !done?(x,y,z, tile_cfg["cache_dir"], tile_cfg["storage_format"]))
					puts("Seeding #{cfg} name #{x} #{y} #{z}")
					queue.syswrite("#{cfg} #{x} #{y} #{z}\n")
				else
					STDOUT.print(".")
				end
				y += y_inc
			end
			x+= x_inc
		end
		puts("Done with level #{z} , out of #{level}..")
	end
end

puts("Done.")
