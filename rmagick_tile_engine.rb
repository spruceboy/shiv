#!/usr/bin/env ruby

###############
# RMagick based tile engine... what fun!
# Designed to be used by a seperate tile generator
# to hid rmagick issues (leaks, strangeness of all sorts..)

class RmagickTileEngine  < TileEngine
  require "rubygems"
  require "RMagick"
  
  def initialize (cfg, logger)
    super(cfg,logger)
    @x_size = cfg["tiles"]["x_size"]
    @y_size = cfg["tiles"]["y_size"]
    @x_count = cfg["tiles"]["x_count"]
    @y_count = cfg["tiles"]["y_count"]
    @num_colors =  cfg["tiles"]["colors"] - 4 if ( cfg["tiles"]["colors"] )
    
    
    ##
    # Get some fonts for writting debug stuff into the tiles..
    @font = '/usr/share/fonts/dejavu-lgc/DejaVuLGCSans.ttf'
    @debug_color = "rgb(250,0,0)"
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
      @label_color= "rgb(#{cfg["label"]["color"][0]}, #{cfg["label"]["color"][1]}, #{cfg["label"]["color"][2]} )"
      @label_blend = cfg["label"]["color"][3].to_f  / 256.0
      @label_size = cfg["label"]["size"]
    end
    
    if (@cfg["watermark"])
      @watermark = true
      @watermark_image = Magick::Image::read(@cfg["watermark"]["image"]).first 
      @watermark_xbuff =  @cfg["watermark"]["x_buffer"]
      @watermark_ybuff =  @cfg["watermark"]["y_buffer"] + @watermark_image.rows
      @watermark_max_x =  @x_size - 2*@watermark_xbuff - @watermark_image.columns
      @watermark_max_y =  @y_size - 2*@watermark_ybuff - @watermark_image.rows
      @watermark_blend = @cfg["watermark"]["blending"]
    end
    
    @locker = TileLockerFile.new(@log)
    
  end
  private
  
  
  ##
  # draws text, what a pain!
  # Wow, this is stupid.. Cannot reliably write text into images, need to make a new image,
  # then blend... wow the pain!
  #
  def draw_text (img,font, msg,x,y, color, blend )
    
    ##
    # Move text about..
    #x += rand(img.columns-x*4)
    #y += rand(img.rows-y*4)
    
    # Build a image to contain the text...
    mark = Magick::Image.new(img.columns, img.rows) {
      self.background_color = 'transparent'
      }
    
    # Create the "Draw"
    dr = Magick::Draw.new
    dr.stroke(color)
    dr.fill(color)
    dr.pointsize(@label_size)
    
    #Hardcoded faont, should be config option..
    dr.font('DejaVu-LGC-Sans-Book')
    
    # the "{" is important, apparently need because of embeded spaces, not clear if needed, appears to work without,but docs say it is needed...
    dr.text(x,y,"{" + msg + "}")
    
    #draw the text into the blank image
    dr.draw(mark)
    
    #blend the images, w/specified transparency
    img = img.dissolve(mark,blend, 1.0)
  
    #return image..
    return img
  end
  
  def watermark ( img)
    x_fiddle = rand(@watermark_max_x).to_i
    y_fiddle = rand(@watermark_max_y).to_i
    ## arguments should be configurable, or random +/1 a configureable bit.. improve this.
    watered = img.dissolve(@watermark_image,@watermark_blend, 1.0, @watermark_xbuff+x_fiddle, @watermark_ybuff+y_fiddle )
    img.destroy!
    return watered
  end
  
  def color_reduce ( img)
    ## arguments should be configurable, or random +/1 a configureable bit.. improve this.
    img = img.quantize(@num_colors, Magick::RGBColorspace)
    return img
  end
  
  # Makes a tile.
  def tile_gen (x,y,z)
    
    mn = "tile_gen:"
    @log.msgdebug(@lt+mn + "(#{x},#{y},#{z})")
    
      # Check to see if the tile has allready been generated (prevous request made it after this request was queed)
      return if ( File.exists?(get_path(x,y,z)))
      
      @log.loginfo(@lt+ "tile_gen (#{x},#{y},#{z})..")
    
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
  end
  
  ##
  # Fetch a single tile.. - normally used to fetch edges or cover-the-whole-earth-tiles
  def fetch_single_tile(x,y,z)
    mn = "fetch_single_tile:"
    @log.msgdebug(@lt+mn + "(#{x},#{y},#{z})")
    begin
      if ( @locker.check_and_wait(x,y,z)) #Returns when ok to start fetching tiles, true if fetch was done durring waiting..
        @locker.release_lock(x,y,z)
        return
      end
      
      # Local file to write data too
      i = Tempfile.new(@cfg["temp_area"])
      
      #convert x,y,z to a bounding box
      bbox = x_y_z_to_map_x_y(x,y,z)
      
      #format the wms/whatever url
      url = sprintf(@cfg["source_url"], @x_size , @y_size, bbox["x_min"],bbox["y_min"], bbox["x_max"], bbox["y_max"] )
      
      #get the raw image data..
      @log.loginfo(@lt+mn + "(#{url})")
      #@downloader.easy_download(url, i.path)
      im = Magick::Image::from_blob(@downloader.easy_body(url)).first
      
      
      if ( !im )
        raise "No img returned for #{url} -> something serously wrong."
      end
      
      #if debug, draw some info into the tiles themselves..
      im = draw_text(im,
          @label_font,
          @cfg["label"]["text"],
          5+rand(im.columns/2.0),
          5+rand(im.rows-30),
          @label_color,
          @label_blend) if (@label_color)
      im = draw_text(im, @font, sprintf(@debug_message_format, x,y, z),10,210,@debug_color, 1.0) if (@tile_debug)
      
      #make the directory..
      mk_path(x,y,z)
      
      #save the image, and do format conversion if needed..
      im.write(get_path(x,y,z))
      im.destroy!
      @locker.release_lock(x,y,z) # Release that lock!
    rescue
      @locker.release_lock(x,y,z) # Release that lock! -> verything has gone bonkers, so bail..
      raise
    end
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
    
    begin
    
      @log.msgdebug(@lt+mn + "rebased to (#{x},#{y},#{z})")
    
      @log.msgdebug(@lt+mn + ":Locking for #{x},#{y},#{z}")
      if ( @locker.check_and_wait(x,y,z)) #Returns when ok to start fetching tiles, true if fetch was done durring waiting..
        @locker.release_lock(x,y,z)
        return
      end
      
      # Temp file for temp local storage of image..
      t = Tempfile.new(@cfg["temp_area"])
      @log.msgdebug(@lt+mn + "tmpfile => {#{t.path}}")
      
      # x,y,z to bounding box
      bbox = x_y_z_to_map_x_y(x,y,z)
      
      # bounding box of end tile set 
      bbox_big = x_y_z_to_map_x_y(x+@x_count-1,y+@y_count-1,z)
      
      #Format the url..
      url = sprintf(@cfg["source_url"], @x_size*@x_count , @y_size*@y_count, bbox["x_min"],bbox["y_min"], bbox_big["x_max"], bbox_big["y_max"] )
      
      # Download the image to a local copy..
      @log.msgdebug(@lt+mn + "url => {#{url}}")
      
      #Download to tmp file..
      #@downloader.easy_download(url, t.path)
      im = Magick::Image::from_blob(@downloader.easy_body(url)).first
      
      if ( !im )
        raise "No img returned for #{url} -> something serously wrong."
      end
      
      im = color_reduce(im) if (@num_colors)
      
      #Loop though grid, writting out tiles
      0.upto(@x_count-1) do |i|
        0.upto(@y_count-1) do |j|
          mk_path(i+x,j+y,z)
          path = get_path(x+i,y+j,z)
          @log.msgdebug(@lt+mn + ":cutting (#{i*@x_size}, #{j*@y_size})")
          if (!File.exists?(path) || true)
            tile = im.crop(i*@x_size,(@y_count - j - 1)*@y_size, @x_size,@y_size)
            tile = draw_text(tile, @label_font, @cfg["label"]["text"],5+rand(tile.columns/2.0),5+rand(tile.rows-30),@label_color,@label_blend) if (@label_color)
            tile = draw_text(tile, @font, sprintf(@debug_message_format, x+i,y+j, z),10,210,@debug_color, 1.0) if (@tile_debug)
            if ( @watermark)
              tile = watermark(tile)
            end
            tile.write(path)
            tile.destroy!
          else
            @log.msgerror(@lt+mn + "should not have found #{x}/#{y}/#{z}")
            raise "dup tile found for #{x}/#{y}/#{z} - whats the deal jay, fix me!"
          end
        end
      end
      @locker.release_lock(x,y,z) # Release that lock!
    rescue
      @locker.release_lock(x,y,z) # Release that lock! -> verything has gone bonkers, so bail..
      raise
    end
  end
end