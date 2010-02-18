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
    @xmin = bbox[0][0].to_f
    @ymin = bbox[0][1].to_f
    @xmax = bbox[1][0].to_f
    @ymax = bbox[1][1].to_f
  end
  
  def between(min, item, max)
    return false if ( item < min)
    return false if ( item > max)
    return true
  end

  def bbox_checker (x,y,z)
    tile_bbox=x_y_z_to_map_x_y( x,y,z)
    #pp tile_bbox
    ## Is the tile completely outside the bbox?
    return false if (@xmax < tile_bbox["x_min"] || @xmin > tile_bbox["x_max"])
    return false if (@ymax < tile_bbox["y_min"] || @ymin > tile_bbox["y_max"])
    
    ## Does bbox inside tile?
    if (tile_bbox["x_max"] >= @xmax && tile_bbox["x_min"] <= @xmin &&
      tile_bbox["y_max"] >= @ymin && tile_bbox["y_min"] <= @ymin )
      puts("(#{x},#{y},#{z}) contains bbox") if (@dry)
      return true
    end
    
    ## Is the tile complete inside the bbox?
    if (tile_bbox["x_max"] <= @xmax && tile_bbox["x_min"] >= @xmin &&
      tile_bbox["y_max"] <= @ymax && tile_bbox["y_min"] >= @ymin )
      puts("(#{x},#{y},#{z}) inside bbox") if ( @dry)
      return true
    end
    
    ## Does the bbox overlap the tile?
    if (
       (
          ( @xmin <= tile_bbox["x_max"] && @xmin >= tile_bbox["x_min"] ) ||
          (@xmax >= tile_bbox["x_min"] && @xmax <= tile_bbox["x_max"] ) ||
          ( @xmax >= tile_bbox["x_max"] && @xmin <= tile_bbox["x_min"])
       ) && (
          (@ymin <= tile_bbox["y_max"] && @ymin >= tile_bbox["y_min"] ) ||
          (@ymax >= tile_bbox["y_min"] && @ymax <= tile_bbox["y_max"] ) ||
          ( @ymax >= tile_bbox["y_max"] && @ymin <= tile_bbox["y_min"])
       )
      )
      puts("(#{x},#{y},#{z}) inside bbox or overlaps") if ( @dry)
      return true
    end
    #if (between(@xmin, tile_bbox["x_max"], @xmax)||between(@xmin, tile_bbox["x_min"], @xmax) )
    #    puts ("test #{@xmin} < #{tile_bbox["x_max"]} < #{@xmax} || #{@xmin} < #{tile_bbox["x_min"]} < #{@xmax}")
    #    if ( between(@ymin, tile_bbox["y_max"], @ymax)||between(@ymin, tile_bbox["y_min"], @ymax) )
    #       return true
    #    end
    #end
      
    #return false if (@xmax < tile_bbox["x_min"] || @xmin > tile_bbox["x_max"])
    #return false if (@ymax < tile_bbox["y_min"] || @ymin > tile_bbox["y_max"])
    return false
  end

  def wipe(x,y,z)
    return if (z > 22)
    return if (!bbox_checker(x,y,z))
    path = get_path(x,y,z)
    
    ## To delete or not to delete, that is the question..
    if (@dry)
      bbox = x_y_z_to_map_x_y( x,y,z)
      puts("(#{x},#{y},#{z}, #{path} matchs..)")
      puts("(#{x},#{2**z-y-1},#{z}) => http://wms.alaskamapped.org/bdl/akmap.jpg?REQUEST=GetMap&SERVICE=WMS&STYLES=&VERSION=1.1.1&BGCOLOR=0xFFFFFF&TRANSPARENT=TRUE&LAYERS=bdl_low_res,bdl_mid_res,bdl_high_res&FORMAT=image/jpeg&BBOX=#{bbox["x_min"]},#{bbox["y_min"]},#{bbox["x_max"]},#{bbox["y_max"]}&SRS=EPSG:900913&WIDTH=256&HEIGHT=256&reaspect=false")
    else
      if ( File.exists?(path))
        File.unlink(path)
        puts("INFO:Deleting '#{path}'")
      end
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
  #tile_engine.wipe(2619,2**16-18467-1,16)
  #tile_engine.wipe(1309,2**15-9233-1,15)
  #tile_engine.wipe(2619,47079,16)
  #http://retry.gina.alaska.edu/tilesrv/bdl/tile/2625/18456/16
  #tile_engine.wipe(2625,2**16-18456-1,16)
  #tile_engine.wipe(2622, 2**16-18450-1, 16)
end

