#!/usr/bin/env ruby
require "rubygems"
require "tile_engine"
require "lumber"
require "yaml"
require 'getoptlong'
require 'pp'

class WipeEngine  < TileEngine
  def initialize (cfg, logger, bbox, dry)
    super(cfg,logger)
    @dry = dry
    @xmin = bbox[1][0]
    @ymin = bbox[0][1]
    @xmax = bbox[0][0]
    @ymax = bbox[1][1]
  end

  def bbox_checker (x,y,z)
    tile_bbox=x_y_z_to_map_x_y( x,y,z)
    
    ## Is the tile completely outside the bbox?
    #return false if (@xmax < tile_bbox["x_min"] || @xmin > tile_bbox["x_max"])
    #return false if (@ymax < tile_bbox["y_min"] || @ymin > tile_bbox["y_max"])
    
    ## Does tile completely incase the bbox?
    return true if (@xmax <= tile_bbox["x_max"] && @xmin >= tile_bbox["x_min"] &&
      @ymax <= tile_bbox["y_max"] && @ymin >= tile_bbox["y_min"] )
    ## Does the bbox overlap the tile?
    return true if (
       (
          (@xmin <= tile_bbox["x_max"] && @xmin >= tile_bbox["x_min"] ) ||
          (@xmax >= tile_bbox["x_min"] && @xmax <= tile_bbox["x_max"] )
       ) && (
          (@ymin <= tile_bbox["y_max"] && @ymin >= tile_bbox["y_min"] ) ||
          (@ymax >= tile_bbox["y_min"] && @ymax <= tile_bbox["y_max"] )
       )
      )
    #return false if (@xmax < tile_bbox["x_min"] || @xmin > tile_bbox["x_max"])
    #return false if (@ymax < tile_bbox["y_min"] || @ymin > tile_bbox["y_max"])
    return false
  end

  def wipe(x,y,z)
    return if (z > 24)
    return if (!bbox_checker(x,y,z))
    path = get_path(x,y,z)
    if (@dry)
      puts("(#{x},#{y},#{z}, #{path} matchs..)")
    else
      File.unlink(path) if ( File.exists?(path))
    end
    0.upto(1) do |i|
      0.upto(1) do |k|
        wipe(x*2+i,y*2+k, z+1)
      end
    end
  end
end


##
# Options..
opts = GetoptLong.new(
    [ "--shiv_config",        "-s",   GetoptLong::REQUIRED_ARGUMENT ],
    [ "--update",             "-u",   GetoptLong::REQUIRED_ARGUMENT ],
    [ "--name",               "-n",   GetoptLong::REQUIRED_ARGUMENT ],
    [ "--dry",                "-d",   GetoptLong::NO_ARGUMENT ],
    [ "--help",               "-h",   GetoptLong::NO_ARGUMENT ]
)


begin
  @dry = nil
  opts.each do |opt, arg|
    case opt
      when "--shiv_config"
        @cfg = File.open(arg) {|x| YAML.load(x)}["tile_engines"]
      when "--update"
        @update_list = File.open(arg) {|x| YAML.load(x)}
      when "--name"
        @name = arg
      when "--dry"
        @dry = true
      when "--help"
        puts("Run like: ./tile_wiper.rb [-s|--shiv_config] shiv.conf [-u|--update] update_list.yml [-n|--name] tile_set_name")
        exit(-1)
    end
  end
rescue
    puts("Hmmm, errored out while arg processing.. not sure what the deal is..")
end

# Find the correct item..
c = 0
while ( @cfg[c]["title"] != @name ) do c += 1 end
@update_list.each do |item|
  tile_engine = WipeEngine.new(@cfg[c], LumberNoFile.new({}), item["google_box"], @dry)
  puts("Doing #{item["scene_gid"]}")
  tile_engine.wipe(0,0,0 )
  exit(-1)
end

