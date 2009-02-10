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
  
  def initialize (cfg, logger)
    @cfg = cfg
    @log = logger
    @storage_format = cfg["storage_format"]
    @requests = {}
  end
  
  
  ##
  # Returns the path to a tile
  def get_tile (x,y,z)
    path = get_path(x,y,z)
    tile_gen(x,y,z) if (!File.exists?(path))
    tile_gen(x,y,z) if (File.exists?(path) && File.size?(path) == 0)
    return path
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
      path= get_path(x,y,z)
      while ( !File.exists?(path) || File.size?(path) == nil )
        @log.msgdebug("TileEngine:"+"check_and_wait -> waiting on #{x},#{y},#{z}")
        sleep(0.01)
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
  
end

###############
# Imlib2 based tile engine... what fun!
# Probibly needs to be abstracted out, as the imlib2 based section is really small...

class Imlib2TileEngine  < TileEngine
  
  require "imlib2"
  
  ##
  # Create a mutex for locking on a per-engine basis...
  #Classed based, as ruby's imlib2 appears to have thread issues...
  @@m_lock = Mutex.new
  
  
  def initialize (cfg, logger)
    super(cfg,logger)
    @x_size = cfg["tiles"]["x_size"]
    @y_size = cfg["tiles"]["y_size"]
    @x_count = cfg["tiles"]["x_count"]
    @y_count = cfg["tiles"]["y_count"]
    
    ##
    # Set image cache big enough for a 5kX5k image...
    Imlib2::Cache::image = 5*5*1024*3
    
    
    ##
    # Get some fonts for writting debug stuff into the tiles..
    Imlib2::Font.add_path("/usr/share/X11/fonts/Type1/")
    Imlib2::Font.add_path("/usr/share/fonts/dejavu-lgc/")
    @font = Imlib2::Font.new 'DejaVuLGCSans/8'
    @debug_color = Imlib2::Color::RED
    @debug_message_format = "Debug:%d/%d/%d"
    
    ##
    # downloader..
    @downloader = SimpleHttpClient.new
    
    ##
    # Create a mutex for locking on a per-engine basis...
    
    ##
    # debug flag
    @tile_debug = cfg["debug"]
    
    ##
    # record class name for later debug messages
    @lt = self.class.to_s + ":"
    
    ##
    # Color for marking...
    
    if (@cfg["label"])
      @label_color = Imlib2::Color::RgbaColor.new( *cfg["label"]["color"]) 
      @label_font = Imlib2::Font.new "DejaVuLGCSans/#{cfg["label"]["size"]}"
    end
    
    if (@cfg["watermark"])
      @watermark = true
      @watermark_image = Imlib2::Image.load( @cfg["watermark"]["image"])
      @watermark_xbuff =  @cfg["watermark"]["x_buffer"]
      @watermark_ybuff =  @cfg["watermark"]["y_buffer"] + @watermark_image.height
      @watermark_max_x =  @x_size - 2*@watermark_xbuff - @watermark_image.width
      @watermark_max_y =  @y_size - 2*@watermark_ybuff - @watermark_image.height
      @watermark_src_rec = [ 0, 0,@watermark_image.width, @watermark_image.height ]
    end
    
    #@locker = TileLocker.new(@log)
    @locker = TileLockerFile.new(@log)
  end
  private
  
  # Makes a tile.
  def tile_gen (x,y,z)
    
    mn = "tile_gen:"
    @log.msgdebug(@lt+mn + "(#{x},#{y},#{z})")
    
    #@@m_lock.synchronize do    
      # Do something more interesting here...
      
      # Check to see if the tile has allready been generated (prevous request made it after this request was queed)
      return if ( File.exists?(get_path(x,y,z)))
      
      @log.loginfo("Imlib2TileEngine:tile_gen (#{x},#{y},#{z})..")
    
      ##
      # Figure if full tile fetching is in order...
      side = 2**z
      if ( (x > side-@x_count) || y > side-@y_count  )
        ##
        # Full Fetch: No - do the tiles one by one.. full fetch would go outside the limits..
        return fetch_single_tile(x,y,z)
      else
        ##
        # Full Fetch: Yes
        return fetch_tile_set(x,y,z)
      end
    ## Unlock
    #end
  end
  
  
  ##
  # Fetch a single tile.. - normally used to fetch edges or cover-the-whole-earth-tiles
  def fetch_single_tile(x,y,z)
    mn = "fetch_single_tile:"
    @log.msgdebug(@lt+mn + "(#{x},#{y},#{z})")
    
    # Local file to write data too
    i = Tempfile.new(@cfg["temparea"])
    
    #convert x,y,z to a bounding box
    bbox = x_y_z_to_map_x_y(x,y,z)
    
    #format the wms/whatever url
    url = sprintf(@cfg["source_url"], @x_size , @y_size, bbox["x_min"],bbox["y_min"], bbox["x_max"], bbox["y_max"] )
    
    if ( @locker.check_and_wait(x,y,z)) #Returns when ok to start fetching tiles, true if fetch was done durring waiting..
      @locker.release_lock(x,y,z)
      return
    end
    
    #get the raw image data..
    @log.loginfo("Imlib2TileEngine:fetch_single_tile (#{url})")
    @downloader.easy_download(url, i.path)
    @log.loginfo("Imlib2TileEngine:fetch_single_tile(got url) ")
    
    
    @@m_lock.synchronize do 
      #load up the imaeg
      im = Imlib2::Image.load(i.path)
    
      #if debug, draw some info into the tiles themselves..
      im.draw_text(@font, sprintf(@debug_message_format, x,y, z),10,10,@debug_color) if (@tile_debug)
    
      #make the directory..
      mk_path(x,y,z)
    
      #save the image, and do format conversion if needed..
      im.save(get_path(x,y,z))
      im.delete!
    end
    
    @locker.release_lock(x,y,z) #Done, next guy can procede..
  end
  
  ##
  # fetch a set of tiles in a @x_count by @y_count grid..
  def fetch_tile_set(x,y,z)
    mn = "fetch_tile_set:"
    @log.msgdebug(@lt+mn + "(#{x},#{y},#{z})")
    
    ###
    # shift so its aligned to the x_size/y_size grid...
    x = (x / @x_count)*@x_count
    y = (y / @y_count)*@y_count
    
    @log.msgdebug(@lt+mn + "rebased to (#{x},#{y},#{z})")
    
    if ( @locker.check_and_wait(x,y,z)) #Returns when ok to start fetching tiles, true if fetch was done durring waiting..
      @locker.release_lock(x,y,z)
      return
    end
    
    # Temp file for temp local storage of image..
    t = Tempfile.new(@cfg["temparea"])
    @log.msgdebug(@lt+mn + "tmpfile => {#{t.path}}")
    
    # x,y,z to bounding box
    bbox = x_y_z_to_map_x_y(x,y,z)
    
    # bounding box of end tile set 
    bbox_big = x_y_z_to_map_x_y(x+@x_count-1,y+@y_count-1,z)
    
    #Format the url..
    url = sprintf(@cfg["source_url"], @x_size*@x_count , @y_size*@y_count, bbox["x_min"],bbox["y_min"], bbox_big["x_max"], bbox_big["y_max"] )
    
    # Download the image to a local copy..
    @log.msgdebug(@lt+mn + "url => {#{url}}")
    @downloader.easy_download(url, t.path)
    
    @log.msgdebug(@lt+mn + ":Locking for #{x},#{y},#{z}")
    @@m_lock.synchronize do
      begin
        im = Imlib2::Image.load(t.path)
      rescue Imlib2::FileError
        @locker.release_lock(x,y,z)
        @log.msgerror(@lt+mn + "Bad image for: #{x}/#{y}/#{z} at url \"#{url}\"")
        raise Imlib2::FileError.new()
      end
    
      #log how big it is.. just debugging stuff..
      @log.msgdebug(@lt+mn + "image.x (#{im.width})")
      @log.msgdebug(@lt+mn + "image.y (#{im.height})")
    
      #Loop though grid, writting out tiles
      0.upto(@x_count-1) do |i|
        0.upto(@y_count-1) do |j|
          mk_path(i+x,j+y,z)
          path = get_path(x+i,y+j,z)
          @log.msgdebug(@lt+mn + ":cutting (#{i*@x_size}, #{j*@y_size})")
          if (!File.exists?(path))
            #im.crop(i*@x_size,j*@y_size, @x_size,@y_size).save(path)
            tile = im.crop(i*@x_size,(@y_count - j - 1)*@y_size, @x_size,@y_size)
            tile.draw_text(@label_font, @cfg["label"]["text"],10,10,@label_color) if (@label_color)
            tile.draw_text(@font, sprintf(@debug_message_format, x+i,y+j, z),10,10,@debug_color) if (@tile_debug)
            if ( @watermark)
              x_fiddle = rand(@watermark_max_x).to_i
              y_fiddle = rand(@watermark_max_y).to_i
              dst_rec = [@watermark_xbuff+x_fiddle, @watermark_ybuff+y_fiddle, @watermark_image.width, @watermark_image.height]
              tile.blend!(@watermark_image, @watermark_src_rec,dst_rec, true)
            end
            tile.save(path)
            tile.delete!
            tile = nil    #might not be needed, just so tile gets deleted/freed..
            #GC.start  #get rid of that tile! Disabled right now, think i fixed issues..
          else
            @log.msgerror(@lt+mn + "should not have found #{x}/#{y}/#{z}")
          end
        end
      end
      
      im.delete!
      im=nil
    end
    GC.start   #issues, issues, issues, perhaps this will fix..
    @locker.release_lock(x,y,z) # Release that lock!
  end
  
  
  private
  
end


####
# Newer tilesetup 

class ExternalTileEngine  < TileEngine
  
  def initialize (cfg, logger)
    super(cfg,logger)
    @lt = "ExternalTileEngine"
    
    @command_path = File.dirname(__FILE__) + "/tile_grabber.rb"
    
    @config = ARGV.first ##This sucks sooo bad... Major punt here... Jay sucks..
  end
  private
  
  # Makes a tile.
  def tile_gen (x,y,z)
    path = get_path(x,y,z)
    # Check to see if the tile has allready been generated (prevous request made it after this request was queed)
    return path if ( File.exists?(path))
    command = [@command_path, @config, @cfg["title"], x.to_s, y.to_s, z.to_s]
    @log.msgdebug(@lt+"running -> #{command.join(" ")}")
    
    @log.msginfo(@lt+"Starting subtiler (#{x},#{y}.#{z})..")
    results = YAML.load(`#{command.join(" ")}`)
    @log.msginfo(@lt+"Subtiler finished (#{x},#{y}.#{z}).")
    if (results["error"])
      raise "external tiler error, reason -> #{results["reason"]}"
    end
    return get_path(x,y,z)
  end

end

##
# A per tile clocking sceme... fun for all..

class TileLocker
  def initialize (log)
    @log = log
    @locker = {}
    @wait = 0.2
    @m_lock = Mutex.new
    @lt = "TileLocker"
  end
  
   ###
  # This is confusing.. pay attention!
  # This function is used to control requests, if a request is in progress, it waits until the request is finished, then returns true, with the lock not set/altered.
  # If a request is not in progress, it returns false and sets the lock.
  def check_and_wait (x,y,z)
    busy = false
    while ( !check_lock(x,y,z))
      @log.msgdebug(@lt+"check_and_wait -> waiting on #{x},#{y},#{z}")
      sleep(@wait)
      busy = true
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
  def initialize (log)
    @log = log
    @lock_dir = "./locks/"
    @wait = 0.2
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
    return("#{@lock_dir}#{x}_#{y}_#{z}")
  end
  
  def locked(x,y,z)
    @m_lock.synchronize do
      path = getpath(x,y,z)
      if ( File.exists?(path) && ((Time.now - File.mtime(path)) > WAIT_TIME) )
        @log.msgerror(@lt +"Lock timeout on #{x},#{y},#{z}  ")
        File.delete(path)
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