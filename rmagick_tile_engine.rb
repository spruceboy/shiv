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
    
    ##
    # Get some fonts for writting debug stuff into the tiles..
    @font = '/usr/share/fonts/dejavu-lgc/DejaVuLGCSans.ttf'
    @debug_color = "rgb(250,0,0)"
    @debug_message_format = "Debug:%d/%d/%d"
    
    ##
    # downloader..
    @downloader = SimpleHttpClient.new
    
    ##
    # record class name for later debug messages
    @lt = self.class.to_s + ":"
    
    @locker = TileLockerFile.new(@log)
    
    setup_labels()
    setup_watermarking()
  end
  
  private
  
  ##
  #Setup stuff if labels are required
  def setup_labels
    return if (!@cfg["label"]) #no labels..
    # Color for marking - if configured to do so..
    @label_color= "rgb(#{@cfg["label"]["color"][0]}, #{@cfg["label"]["color"][1]}, #{@cfg["label"]["color"][2]} )"
    @label_blend = @cfg["label"]["color"][3].to_f  / 256.0
    @label_size = @cfg["label"]["size"]
  end
    
  ##
  # setup stuff if watermarking is required..
  def setup_watermarking
    return if (!@cfg["watermark"]) #no watermarking..
    @watermark = true
    @watermark_image = Magick::Image::read(@cfg["watermark"]["image"]).first 
    @watermark_xbuff =  @cfg["watermark"]["x_buffer"]
    @watermark_ybuff =  @cfg["watermark"]["y_buffer"] + @watermark_image.rows
    @watermark_max_x =  @x_size - 2*@watermark_xbuff - @watermark_image.columns
    @watermark_max_y =  @y_size - 2*@watermark_ybuff - @watermark_image.rows
    @watermark_blend = @cfg["watermark"]["blending"]
  end
  
  ##
  # draws text, what a pain!
  # Wow, this is stupid.. Cannot reliably write text into images w/rmagick, need to make a new image,
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
  
  # reduce the number of colors, useful if original dataset has a limited number of colors..
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
  
  ###
  # Get a temp file...
  def get_tempfile ()
    return Tempfile.new("shiv_temp_tile", @cfg["temp_area"])
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
      i = get_tempfile()
      
      #convert x,y,z to a bounding box
      bbox = x_y_z_to_map_x_y(x,y,z)
      
      #format the wms/whatever url
      url = sprintf(@cfg["source_url"], @x_size , @y_size, bbox["x_min"],bbox["y_min"], bbox["x_max"], bbox["y_max"] )
      
      #get the raw image data..
      @log.loginfo(@lt+mn + "(#{url})")
      
      #fetch and load the image
      im = Magick::Image::from_blob(@downloader.easy_body(url)).first
      
      #Is the image returned good?
      raise("No img returned for #{url} -> something serously wrong - WMS is probibly broken..") if ( !im )
      
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
    x,y = shift_x_y(x,y)

    begin
      @log.msgdebug(@lt+mn + ":Locking for #{x},#{y},#{z}")
      if ( @locker.check_and_wait(x,y,z)) #Returns when ok to start fetching tiles, true if fetch was done durring waiting..
        # If we are here, then the lock released and the tile is already generated - return!
        @locker.release_lock(x,y,z)
        return
      end
      
      # Temp file for temp local storage of image..
      t = get_tempfile() 
      @log.msgdebug(@lt+mn + "tmpfile => {#{t.path}}")
      
      #get url..
      url=get_url_for_x_y_z(x,y,z)
      
      # Download the image to a local copy..
      @log.msgdebug(@lt+mn + "url => {#{url}}")
      
      #Download to tmp file..
      #@downloader.easy_download(url, t.path)
      im = Magick::Image::from_blob(@downloader.easy_body(url)).first
      
      raise "No img returned for #{url} -> something serously wrong. Mostly likely the image fetched is not a image (broken server)." if (!im)
      
      # Label..
      im = draw_text(im, @label_font, @cfg["label"]["text"],5+rand(im.columns/2.0),5+rand(im.rows-30),@label_color,@label_blend) if (@label_color)
      
      #reduce colors, if configured to do so.
      im = color_reduce(im) if (@num_colors)
      
      #Loop though grid, writting out tiles
      each_tile_ul(x,y,z) do |ul_x, ul_y, path|
        if (!File.exists?(path) || true)
          tile = im.crop(ul_x,ul_y, @x_size,@y_size)
          tile = draw_text(tile, @font, sprintf(@debug_message_format, x+i,y+j, z),10,210,@debug_color, 1.0) if (@tile_debug)
          tile = watermark(tile) if (@watermark)
          tile.write(path)
          tile.destroy!
        else
          @log.msgerror(@lt+mn + "should not have found #{x}/#{y}/#{z}")
          raise "dup tile found for #{x}/#{y}/#{z} - whats the deal jay, fix me!"
        end
      end
      @locker.release_lock(x,y,z) # Release that lock!
    rescue
      @locker.release_lock(x,y,z) # Release that lock! -> verything has gone bonkers, so bail..
      raise
    end
  end
end
