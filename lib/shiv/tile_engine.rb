#!/usr/bin/ruby
require 'tempfile'
require 'thread'
require 'shiv/idler'
require 'shiv/storage_engine'
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
  # local cache path..
  PATH_FORMAT = '%02d/%03d/%03d/%09d/%09d/%09d_%09d_%09d.%s'
  WAIT_TIME = 0.5

  def initialize(cfg, logger)
    @cfg = cfg
    @log = logger
    @storage_format = cfg['storage_format']
    @requests = {}

    # Save some stuff for easy (shorter typing) access later..
    @x_size = cfg['tiles']['x_size']
    @y_size = cfg['tiles']['y_size']
    @x_count = cfg['tiles']['x_count']
    @y_count = cfg['tiles']['y_count']
    @num_colors = cfg['tiles']['colors'] - 4 if cfg['tiles']['colors']

    # to Debug or not to Debug
    # debug flag
    @tile_debug = cfg['debug'] if cfg['debug']

    # deside which tile storage backend
    if cfg['mode'] && cfg['mode'] == 'esri'
      @storage_backend = ESRIStorageEngine.new(cfg, logger)
      @tile_mapper = ESRIXYZMapper.new(cfg, logger)
    else
      @storage_backend = StorageEngine.new(cfg, logger)
      @tile_mapper = XYZMapper.new(cfg, logger)
    end
  end

  ##
  # max x for y
  def max_x(z)
    @tile_mapper.max_x(z)
  end

  ##
  # max y for z
  def max_y(z)
    @tile_mapper.max_y(z)
  end

  ##
  # check that x,y,z are valid.
  def valid?(x, y, z)
    @tile_mapper.valid?(x, y, z)
  end

  ##
  # Returns the path to a tile
  def get_tile(x, y, z)
    path = get_path(x, y, z)
    tile_gen(x, y, z) unless File.exist?(path)
    tile_gen(x, y, z) if File.exist?(path) && (File.size?(path).nil?)
    # puts("size of #{path} -> #{File.size?(path)}")
    path
  end

  def is_fiddle(x, y, z)
    return false unless @cfg['tiles']['fiddle']
    return false if x == 0 || y == 0
    return true if (x < (2**z - 1)) && (y < 2**z - 1)
    false
  end

  ##
  # Note -> z level = log(width of world / width of request)/log(2)
  # takes a bbox, returns the tile that it repersents..
  # Todo: Handle case where things to not match..
  def min_max_to_xyz(min_x, min_y, max_x, max_y)
    @tile_mapper.min_max_to_xyz(min_x, min_y, max_x, max_y)
  end

  ###
  # Fixer/waiter - checks to see if a tile has been generated, if not waits until it shows up..
  def check_and_wait(x, y, z)
    path = get_path(x, y, z)
    while !File.exist?(path) || File.size?(path) == 0
      @log.msgdebug('TileEngine:' + "check_and_wait -> waiting on #{x},#{y},#{z}")
      sleep(WAIT_TIME)
    end
  end

  ##
  # Returns path to an (x,y,z) set..
  def get_path(x, y, z)
    @storage_backend.get_path(x, y, z)
  end

  ##
  # Takes a x,y,z, return the tiles bounding box

  def x_y_z_to_map_x_y(x, y, z)
    @tile_mapper.x_y_z_to_map_x_y(x, y, z)
  end

  def x_y_z_to_map_x_y_enlarged(x, y, z, x_count, y_count)
    @tile_mapper.x_y_z_to_map_x_y_enlarged(x, y, z, x_count, y_count)
  end

  private

  ##
  # creates the path for a tile..
  def mk_path(x, y, z)
    splits = File.dirname(get_path(x, y, z)).split('/')
    start = splits.first
    splits.delete_at(0)
    splits.each do |x|
      start += '/' + x
      next if  File.exist?(start)
      @log.msgdebug("mk_path: making #{start}")
      begin
        Dir.mkdir(start)
      rescue => e
        @log.msgerror("mk_path: Something when wrong, probibly allready there..#{e}")
      end
    end
  end

  ##
  # Stub - don't call directly, subclass
  def tile_gen(_x, _y, _z)
    exit(-1)
  end

  # does a block w/upper left and path - used to loop though tiles for cutting them up..
  def each_tile_ul(x, y, z)
    0.upto(@x_count - 1) do |i|
      0.upto(@y_count - 1) do |j|
        # mk_path(i+x,j+y,z)
        next if is_fiddle(x, y, z) && (i == 0 || j == 0 || i == @x_count || i == @y_count)
        path = get_path(x + i, y + j, z)
        if @tile_mapper.up?
          yield(i * @x_size, (@y_count - j - 1) * @y_size, path, i + x, j + y, z)
        else
          # puts "#{i}/#{j}"
          yield(i * @x_size, j * @y_size, path, i + x, j + y, z)
        end
      end
    end
  end

  # shifts x + y to align with grid..
  def shift_x_y(x, y)
    x = (x / @x_count) * @x_count
    y = (y / @y_count) * @y_count
    [x, y]
  end

  # get url - returns the url for a bounding box
  def get_url_for_x_y_z(x, y, z)
    x_count = @x_count
    y_count = @y_count
    x_mod = x
    y_mod = y

    # If fiddle is turned on, inlargen request by 1 tile in each direction
    if is_fiddle(x, y, z)
      x_count += 2
      y_count += 2
      x_mod -= 1
      y_mod -= 1
    end

    bbox = x_y_z_to_map_x_y_enlarged(x_mod, y_mod, z, @x_count, @y_count)

    # Format the url..
    sprintf(@cfg['source_url'], @x_size * x_count, @y_size * y_count, bbox['x_min'], bbox['y_min'], bbox['x_max'], bbox['y_max'])
  end
end

####
# Newer tilesetup

class ExternalTileEngine < TileEngine
  require 'shiv/idler'

  # @@idler = Idler.new(1)
  @@idler = nil

  def initialize(cfg, logger)
    super(cfg, logger)
    @lt = 'ExternalTileEngine'

    @command_path = File.dirname(__FILE__) + '/external_tiler'

    @@idler = Idler.new(1) unless @@idler # Only create an idler if a instance is instaicated. My spelling sucks.  So does my coding.
  end

  def make_tiles(x, y, z)
    path = get_path(x, y, z)
    # Check to see if the tile has allready been generated (prevous request made it after this request was queed)
    return path unless File.size?(path).nil?

    command = [@command_path, @cfg['config_path'], @cfg['title'], x.to_s, y.to_s, z.to_s]
    @log.msginfo(@lt + "running -> #{command.join(' ')}")

    @log.msginfo(@lt + "Starting subtiler (#{x},#{y}.#{z})..")

    # using backticks
    results = YAML.load(`#{command.join(' ')}`)
    # using popen
    # results = YAML.load(IO.popen(command.join(" ") {|f| f.readlines}))

    @log.msginfo(@lt + "Subtiler finished (#{x},#{y}.#{z}).")
    if results['error']
      # output from the external tiler should include backtrace, logs, and reason..
      # ({"error"=>true, "reason" => e, "backtrace" => e.backtrace, "logs"=>logs }, STDOUT)
      fail "external tiler error, reason -> #{results['reason']}, backtrace -> #{results['backtrace']}, command line -> '#{command.join(' ')}'"
    end
    path
  end

  private

  # Makes a tile.
  def tile_gen(x, y, z)
    path = get_path(x, y, z)
    # Check to see if the tile has allready been generated (prevous request made it after this request was queed)
    return path unless File.size?(path).nil?

    ##
    # Queue up everything around the request, to get maximise data generation.
    (-1).upto(1) { |dx| (-1).upto(1) { |dy| @@idler.add(self, x + dx * @cfg['tiles']['x_count'], y + dy * @cfg['tiles']['y_count'], z) unless dy == 0 && dx == 0 } }

    make_tiles(x, y, z)
  end
end

class ExternalTileEngine < TileEngine
  require 'shiv/idler'

  # @@idler = Idler.new(1)
  @@idler = nil

  def initialize(cfg, logger)
    super(cfg, logger)
    @lt = 'ExternalTileEngine'

    @command_path = File.dirname(__FILE__) + '/external_tiler'

    @@idler = Idler.new(1) unless @@idler # Only create an idler if a instance is instaicated. My spelling sucks.  So does my coding.
  end

  def make_tiles(x, y, z)
    path = get_path(x, y, z)
    # Check to see if the tile has allready been generated (prevous request made it after this request was queed)
    return path unless File.size?(path).nil?

    command = [@command_path, @cfg['config_path'], @cfg['title'], x.to_s, y.to_s, z.to_s]
    @log.msginfo(@lt + "running -> #{command.join(' ')}")

    @log.msginfo(@lt + "Starting subtiler (#{x},#{y}.#{z})..")

    # using backticks
    results = YAML.load(`#{command.join(' ')}`)
    # using popen
    # results = YAML.load(IO.popen(command.join(" ") {|f| f.readlines}))

    @log.msginfo(@lt + "Subtiler finished (#{x},#{y}.#{z}).")
    if results['error']
      # output from the external tiler should include backtrace, logs, and reason..
      # ({"error"=>true, "reason" => e, "backtrace" => e.backtrace, "logs"=>logs }, STDOUT)
      fail "external tiler error, reason -> #{results['reason']}, backtrace -> #{results['backtrace']}, command line -> '#{command.join(' ')}'"
    end
    path
  end

  private

  # Makes a tile.
  def tile_gen(x, y, z)
    path = get_path(x, y, z)
    # Check to see if the tile has allready been generated (prevous request made it after this request was queed)
    return path unless File.size?(path).nil?

    ##
    # Queue up everything around the request, to get maximise data generation.
    (-1).upto(1) { |dx| (-1).upto(1) { |dy| @@idler.add(self, x + dx * @cfg['tiles']['x_count'], y + dy * @cfg['tiles']['y_count'], z) unless dy == 0 && dx == 0 } }

    make_tiles(x, y, z)
  end
end

##
# A per tile clocking sceme... fun for all..

class TileLocker
  def initialize(log)
    @log = log
    @locker = {}
    @wait = 0.3
    @m_lock = Mutex.new
    @lt = 'TileLocker'
  end

  ###
  # This is confusing.. pay attention!
  # This function is used to control requests, if a request is in progress, it waits until the request is finished, then returns true, with the lock not set/altered.
  # If a request is not in progress, it returns false and sets the lock.
  def check_and_wait(x, y, z)
    busy = false
    until  check_lock(x, y, z)
      @log.msgdebug(@lt + "check_and_wait -> waiting on #{x},#{y},#{z}")
      sleep(@wait)
      busy = true
    end

    release_lock(x, y, z) if busy # Release lock, and data has allready been generated..
    busy
  end

  # Returns true if locked, false otherwise..
  def check_lock(x, y, z)
    token = "#{x}_#{y}_#{z}"
    @m_lock.synchronize do
      if !@locker[token]
        @log.msgdebug(@lt + "locking on #{x},#{y},#{z}")
        @locker[token] = Time.now
        return true
      else
        return false
      end
    end
  end

  # to be called after check_and_wait..
  def release_lock(x, y, z)
    token = "#{x}_#{y}_#{z}"
    @m_lock.synchronize { @locker.delete(token) }
  end
end

class TileLockerFile
  WAIT_TIME = (60 * 3)
  def initialize(log)
    @log = log
    @lock_dir = './locks/'
    @wait = 0.3
    @m_lock = Mutex.new
    @lt = 'TileLockerFile:'
  end

  ###
  # This is confusing.. pay attention!
  # This function is used to control requests, if a request is in progress, it waits until the request is finished, then returns true, with the lock not set/altered.
  # If a request is not in progress, it returns false and sets the lock.
  # Ok, I lied, it should always return with a lock in place..
  def check_and_wait(x, y, z)
    busy = false
    until  check_lock(x, y, z)
      @log.msgdebug(@lt + "check_and_wait -> waiting on #{x},#{y},#{z}")
      sleep(@wait)
      busy = true
    end
    busy
  end

  # Returns true if locked, false otherwise..
  def check_lock(x, y, z)
    if !locked(x, y, z)
      @log.msgdebug(@lt + "locking on #{x},#{y},#{z}")
      return true
    else
      return false
    end
  end

  # to be called after check_and_wait..
  def release_lock(x, y, z)
    @log.msgdebug(@lt + "releasing #{x},#{y},#{z}")
    @m_lock.synchronize do
      begin
        File.delete(getpath(x, y, z))
      rescue => e
        @log.msgerror(@lt + "release lock -> colision at #{x},#{y},#{z} (#{e})")
      end
    end
  end

  def getpath(x, y, z)
    ("#{@lock_dir}#{x}_#{y}_#{z}")
  end

  def locked(x, y, z)
    @m_lock.synchronize do
      path = getpath(x, y, z)

      begin # this section deals with old locks - if lock file exists and is old, delete..
        if  File.exist?(path) && ((Time.now - File.mtime(path)) > WAIT_TIME)
          @log.msgerror(@lt + "Lock timeout on #{x},#{y},#{z}  ")
          File.delete(path)
        end
      rescue
        # Do nothing - means file is gone.
      end

      # Normal path
      if File.exist?(path)
        return true
      else
        File.open(path, 'w') { |fl| fl.write(Time.now.to_s); fl.flush }
        return false
      end
    end
  end
end
