#!/usr/bin/ruby

require "rubygems"
require "tempfile"
require "thread"
require "http_client_tools"

###
# Notes
#                     **** tile Layout ****************
#   Tiles are referenced like x/y/z, where z is the zoom level
#   Example:
#   0/2/1   | 1/2/1 | 2/2/1
#   0/1/1   | 1/1/1 | 2/1/1
#   0/0/1   | 1/0/1 | 2/0/1
#
#   This is the oposide from google maps, in the y dir
#   Google maps looks like this:
#   0/0/1   | 1/0/1 | 2/0/1
#   0/1/1   | 1/1/1 | 2/1/1
#   0/2/1   | 1/2/1 | 2/2/1



class TileEngine
  
  #local cache path..
  PATH_FORMAT = "%02d/%03d/%03d/%09d/%09d/%09d_%09d_%09d.%s"
  WAIT_TIME = 0.5
  MAX_WAIT_TIME = 120
  
  def initialize (cfg, logger)
    @cfg = cfg
    @log = logger
    @storage_format = cfg["storage_format"]
    @requests = {}
    
    # Save some stuff for easy (shorter typing) access later..
    @x_size = cfg["tiles"]["x_size"]
    @y_size = cfg["tiles"]["y_size"]
    @x_count = cfg["tiles"]["x_count"]
    @y_count = cfg["tiles"]["y_count"]
    @num_colors =  cfg["tiles"]["colors"] - 4 if ( cfg["tiles"]["colors"] )
    
    #to Debug or not to Debug
    # debug flag
    @tile_debug = cfg["debug"] if (cfg["debug"])
    
  end
  
  def get_cfg()
    @cfg
  end
  
  
  ##
  # Returns the path to a tile
  def get_tile (x,y,z)
    path = get_path(x,y,z)
    tile_gen(x,y,z) if (!File.exists?(path))
    tile_gen(x,y,z) if (File.exists?(path) && (File.size?(path) == nil))
    #puts("size of #{path} -> #{File.size?(path)}")
    return path
  end

  def is_fiddle (x,y,z)
   return false if (!@cfg["tiles"]["fiddle"])
   return false if ( x ==0 || y == 0 )
   return true if ( (x < (2**z-1)) && (y < 2**z-1)) 
   return false
  end
  
  ##
  # Note -> z level = log(width of world / width of request)/log(2)
  # takes a bbox, returns the tile that it repersents..
  # Todo: Handle case where things to not match..
  def min_max_to_xyz(min_x,min_y, max_x,max_y)
    @log.loginfo("TileEngine:min_max_to_xyz (#{min_x},#{min_y},#{max_x}, #{max_y})..")
    dx = max_x - min_x
    dy = max_y - min_y
    
    zx = Math.log( (@cfg["base_extents"]["xmax"] - @cfg["base_extents"]["xmin"])/ dx) / Math.log(2)
    zy = Math.log( (@cfg["base_extents"]["ymax"] - @cfg["base_extents"]["ymin"])/ dy) / Math.log(2)
    
    x = (min_x - @cfg["base_extents"]["xmin"])/dx
    y = (min_y - @cfg["base_extents"]["ymin"])/dy 
    
    x = x.to_i 
    y = y.to_i 
    
    
    @log.msgdebug("TileEngine:min_max_to_xyz:zlevels.. (#{zx},#{zy})..")
    
    @log.msgdebug("TileEngine:min_max_to_xyz:results (#{x},#{y},#{zx})..")
    return x,y,zx.to_i
  end
  
  
  ###
  # Fixer/waiter - checks to see if a tile has been generated, if not waits until it shows up..
  def check_and_wait(x,y,z)
      counter = (MAX_WAIT_TIME/WAIT_TIME).to_i
      path= get_path(x,y,z)
      while ( !File.exists?(path) || File.size?(path) == 0 )
        @log.msgdebug("TileEngine:"+"check_and_wait -> waiting on #{x},#{y},#{z} t#{counter}(#{@cfg["title"]})")
	counter = counter - 1
	raise "timed out while waiting for waiting on #{@cfg["title"]}(#{x},#{y},#{z})" if (counter < 0 ) 
        sleep(WAIT_TIME)
      end
  end
  
  
  
  ##
  # Returns path to an (x,y,z) set.. 
  def get_path (x,y,z)
    return @cfg["cache_dir"] + sprintf(PATH_FORMAT, z,x%128,y%128,x,y,x,y,z,@storage_format)
  end
  
  private
  
  ##
  # creates the path for a tile..
  def mk_path(x,y,z)
    splits = File.dirname(get_path(x,y,z)).split("/")
    start = splits.first
    splits.delete_at(0)
    splits.each do |x|
      start += "/" + x
      if ( !File.exists?(start))
        @log.msgdebug("mk_path: making #{start}")
        begin
          Dir.mkdir(start)
        rescue => e
            @log.msgerror("mk_path: Something when wrong, probibly allready there..#{e.to_s}")
        end
      end
    end
  end
  
  ##
  # Stub - don't call directly, subclass
  def tile_gen(x,y,z)
      exit(-1)
  end
  
  ##
  # Takes a x,y,z, return the tiles bounding box
  
  def x_y_z_to_map_x_y ( x,y,z)
    w_x = (@cfg["base_extents"]["xmax"] - @cfg["base_extents"]["xmin"])/(2.0 **(z.to_f))
    w_y = (@cfg["base_extents"]["ymax"] - @cfg["base_extents"]["ymin"])/(2.0 **(z.to_f))
    x_min = @cfg["base_extents"]["xmin"] + x*w_x
    return { "x_min" => @cfg["base_extents"]["xmin"] + x*w_x,
      "y_min" => @cfg["base_extents"]["ymin"] + y*w_y,
      "x_max" => @cfg["base_extents"]["xmin"] + (x+1)*w_x,
      "y_max" => @cfg["base_extents"]["ymin"] + (y+1)*w_y}
  end
  
  #does a block w/upper left and path - used to loop though tiles for cutting them up..
  def each_tile_ul(x,y,z)
    if (is_fiddle(x,y,z))
    	0.upto(@x_count) do |i|
      		0.upto(@y_count) do |j|
        		mk_path(i+x,j+y,z)
        		path = get_path(x+i,y+j,z)
			next if ( i == 0 || j ==0 || i == @x_count|| i == @y_count) 
        		yield( i*@x_size, ((@y_count+1) - j - 1)*@y_size, path)
      		end
    	end
    else
        0.upto(@x_count-1) do |i|
                0.upto(@y_count-1) do |j|
                        mk_path(i+x,j+y,z)
                        path = get_path(x+i,y+j,z)
                        yield( i*@x_size, (@y_count - j - 1)*@y_size, path)
                end
        end
    end
  end
    
  #shifts x + y to align with grid..
  def shift_x_y(x,y)
    x = (x / @x_count)*@x_count
    y = (y / @y_count)*@y_count
    return x,y
  end
  
  #get url - returns the url for a bounding box
  def get_url_for_x_y_z(x,y,z)
      # x,y,z to bounding box
      bbox = x_y_z_to_map_x_y(x,y,z)
      
      # bounding box of end tile set 
      bbox_big = x_y_z_to_map_x_y(x+@x_count-1,y+@y_count-1,z)

      x_count = @x_count
      y_count = @y_count 

      # If fiddle is turned on, inlargen request by 1 tile in each direction
      if (is_fiddle(x,y,z))
		bbox = x_y_z_to_map_x_y(x-1,y-1,z)
		bbox_big = x_y_z_to_map_x_y(x+@x_count,y+@y_count,z)
		x_count += 2
		y_count += 2
      end
      
      #Format the url..
      sprintf(@cfg["source_url"], @x_size*x_count , @y_size*y_count, bbox["x_min"],bbox["y_min"], bbox_big["x_max"], bbox_big["y_max"] )
  end
end

####
# Newer tilesetup 

class ExternalTileEngine  < TileEngine
  require "idler"
  
  #@@idler = Idler.new(1)
  @@idler = nil
  
  def initialize (cfg, logger )
    super(cfg,logger)
    @lt = "ExternalTileEngine"
    
    @command_path = File.dirname(__FILE__) + "/external_tiler"
    
    @@idler = Idler.new(1, cfg["idler"]) if ( ! @@idler )   #Only create an idler if a instance is instaicated. My spelling sucks.  So does my coding.

    @font = '/usr/share/fonts/dejavu-lgc/DejaVuLGCSans.ttf' 
    @label_size = 20
  end
  
  
  def make_tiles(x,y,z)
    path = get_path(x,y,z)
    # Check to see if the tile has allready been generated (prevous request made it after this request was queed)
    return path if ( File.size?(path) != nil)
    
    command = [@command_path, @cfg["config_path"], @cfg["title"], x.to_s, y.to_s, z.to_s]
    @log.msginfo(@lt+"running -> #{command.join(" ")}")
    
    @log.msginfo(@lt+"Starting subtiler (#{x},#{y}.#{z})..")
    
    #using backticks
    results = YAML.load(`#{command.join(" ")}`)
    #using popen
    #results = YAML.load(IO.popen(command.join(" ") {|f| f.readlines}))
    
    @log.msginfo(@lt+"Subtiler finished (#{x},#{y}.#{z}).")
    if (results["error"])
      #output from the external tiler should include backtrace, logs, and reason..
      #({"error"=>true, "reason" => e, "backtrace" => e.backtrace, "logs"=>logs }, STDOUT)
      raise "external tiler error, reason -> #{results["reason"]}, backtrace -> #{results["backtrace"]}, command line -> '#{command.join(" ")}'"
    end
    return path
  end



  # check to see if we need to draw alt text on image
  def alt_tile?(x,y,z,request)
	return false if !@cfg["notice"]
	return false if !@cfg["notice"]["auth"]
	return true if ENV["AUTH_TEST"]
	return false if !request.env[@cfg["notice"]["auth"]]
	return true if (rand(@cfg["notice"]["one_out_of"]) == 0 )
	return false
  end

  # draw alt text and return image as string.  
  def get_alt_tile(x,y,z)
      im = Magick::Image::read(get_path(x,y,z)).first
      im = warning_text(im, @font, @cfg["notice"]["notice"],20,128)
      im.format = @cfg["storage_format"]
      blob = im.to_blob.dup
      im.destroy!
      return blob
  end

  private

  ##
  # draws warning notice
  # Wow, this is stupid.. Cannot reliably write text into images w/rmagick, need to make a new image,
  # then blend... wow the pain!
  #
  def warning_text(img,font, msg,x,y)
    over_color = "rgb(254,245,245)"
    under_color = "rgb(0,0,0)"
    blend = 1.0

    ##
    # Move text about..
    x += rand(20) - 10
    y += rand(40) - 20 

    # Build a image to contain the text...
    mark = Magick::Image.new(img.columns, img.rows) {
      self.background_color = 'transparent'
      }

    # Create the "Draw"
    dr = Magick::Draw.new
    dr.stroke(@cfg["notice"]["background"])
    dr.fill(@cfg["notice"]["background"])
    dr.pointsize(@cfg["notice"]["size"])

    #Hardcoded faont, should be config option..
    dr.font('DejaVu-LGC-Sans-Book')

    # the "{" is important, apparently need because of embeded spaces, not clear if needed, appears to work without,but docs say it is needed...
    dr.text(x,y,"{" + msg + "}")
    dr.fill(@cfg["notice"]["foreground"])
    dr.stroke(@cfg["notice"]["foreground"])
    dr.text(x+3,y-3,"{" + msg + "}")

    #draw the text into the blank image
    dr.draw(mark)

    #blend the images, w/specified transparency
    img = img.dissolve(mark,@cfg["notice"]["blending"], 1.0)

    mark.destroy!

    #return image..
    return img
  end

  
  # Makes a tile.
  def tile_gen (x,y,z)
    
    path = get_path(x,y,z)
    # Check to see if the tile has allready been generated (prevous request made it after this request was queed)
    return path if ( File.size?(path) != nil)
    
    ##
    # Queue up everything around the request, to get maximise data generation. 
    (-2).upto(2) {|dx| (-2).upto(2) {|dy| @@idler.add(self, x+dx*@cfg["tiles"]["x_count"],y+dy*@cfg["tiles"]["y_count"],z) if (!(dy == 0 && dx == 0)) }}
    
    make_tiles(x,y,z)
    
  end

end

##
# A per tile clocking sceme... fun for all..

class TileLocker
  def initialize (log)
    @log = log
    @locker = {}
    @wait = 0.3
    @m_lock = Mutex.new
    @lt = "TileLocker"
  end
  
   ###
  # This is confusing.. pay attention!
  # This function is used to control requests, if a request is in progress, it waits until the request is finished, then returns true, with the lock not set/altered.
  # If a request is not in progress, it returns false and sets the lock.
  def check_and_wait (x,y,z)
    counter = 0
    busy = false
    while ( !check_lock(x,y,z))
      @log.msgdebug(@lt+"check_and_wait -> waiting on #{x},#{y},#{z} (#{counter})")
      sleep(@wait)
      busy = true
      counter += 1
    end
    
    release_lock(x,y,z) if (busy)  # Release lock, and data has allready been generated..
    return busy
  end
  
  
  # Returns true if locked, false otherwise..
  def check_lock(x,y,z)
    token = "#{x}_#{y}_#{z}"
    @m_lock.synchronize do
      if (!@locker[token])
        @log.msgdebug(@lt+"locking on #{x},#{y},#{z}")
        @locker[token] = Time.now
        return true
      else
        return false
      end
    end
  end
  
  #to be called after check_and_wait..
  def release_lock (x,y,z)
    token = "#{x}_#{y}_#{z}"
    @m_lock.synchronize {@locker.delete(token) }
  end
  
end


class TileLockerFile
  WAIT_TIME= (60*3)
  def initialize (log, title="default")
    @title = title
    @log = log
    @lock_dir = "./locks/"
    @wait = 0.3
    @m_lock = Mutex.new
    @lt = "TileLockerFile:"
  end
  
   ###
  # This is confusing.. pay attention!
  # This function is used to control requests, if a request is in progress, it waits until the request is finished, then returns true, with the lock not set/altered.
  # If a request is not in progress, it returns false and sets the lock.
  # Ok, I lied, it should always return with a lock in place..
  def check_and_wait (x,y,z)
    busy = false
    while ( !check_lock(x,y,z))
      @log.msgdebug(@lt+"check_and_wait -> waiting on #{x},#{y},#{z}")
      sleep(@wait)
      busy = true
    end
    return busy
  end
  
  
  # Returns true if locked, false otherwise..
  def check_lock(x,y,z)
    if (!locked(x,y,z))
        @log.msgdebug(@lt+"locking on #{x},#{y},#{z}")
        return true
      else
        return false
    end
  end
  
  #to be called after check_and_wait..
  def release_lock (x,y,z)
    @log.msgdebug(@lt+"releasing #{x},#{y},#{z}")
    @m_lock.synchronize do
     begin 
      File.delete(getpath(x,y,z))
     rescue => e
      @log.msgerror(@lt+"release lock -> colision at #{x},#{y},#{z} (#{e.to_s})")
     end
    end
  end
  
  
  def getpath(x,y,z)
    return("#{@lock_dir}#{@title}_#{x}_#{y}_#{z}")
  end
  
  def locked(x,y,z)
    @m_lock.synchronize do
      path = getpath(x,y,z)
      
      begin  #this section deals with old locks - if lock file exists and is old, delete..
        if ( File.exists?(path) && ((Time.now - File.mtime(path)) > WAIT_TIME) )
          @log.msgerror(@lt +"Lock timeout on #{x},#{y},#{z}  ")
          File.delete(path)
        end
      rescue
        # Do nothing - means file is gone.
      end
      
      # Normal path
      if (File.exists?(path))
        return true
      else
        File.open(path, "w" ) {|fl| fl.write(Time.now.to_s); fl.flush()}
        return false
      end
    end
  end
  
end



require "rmagick_tile_engine"
require "idler"
