# maps tile x/y/z to map cords, and back.
class XYZMapper
  def initialize(cfg, logger)
    @cfg = cfg
    @log = logger

    @x_count = cfg['tiles']['x_count']
    @y_count = cfg['tiles']['y_count']
  end

  ##
  # Note -> z level = log(width of world / width of request)/log(2)
  # takes a bbox, returns the tile that it repersents..
  # Todo: Handle case where things to not match..
  def min_max_to_xyz(min_x, min_y, max_x, max_y)
    @log.loginfo('TileEngine:min_max_to_xyz ' \
    "(#{min_x},#{min_y},#{max_x}, #{max_y})..")
    dx = max_x - min_x
    dy = max_y - min_y

    zx = Math.log((@cfg['base_extents']['xmax'] - @cfg['base_extents']['xmin']) / dx) /
         Math.log(2)
    # This should be checked - it means the request isn't for a square tile, or something else is wrong
    # zy = Math.log((@cfg['base_extents']['ymax'] - @cfg['base_extents']['ymin']) / dy) / Math.log(2)

    x = (min_x - @cfg['base_extents']['xmin']) / dx
    y = (min_y - @cfg['base_extents']['ymin']) / dy

    [x.to_i, y.to_i, zx.to_i]
  end

  # maps x,y,z tile to map projection x/y/min/max
  def x_y_z_to_map_x_y(x, y, z)
    width = 2.0**(z.to_f)
    w_x = (@cfg['base_extents']['xmax'] - @cfg['base_extents']['xmin']) / width
    w_y = (@cfg['base_extents']['ymax'] - @cfg['base_extents']['ymin']) / width

    { 'x_min' => @cfg['base_extents']['xmin'] + x * w_x,
      'y_min' => @cfg['base_extents']['ymin'] + y * w_y,
      'x_max' => @cfg['base_extents']['xmin'] + (x + 1) * w_x,
      'y_max' => @cfg['base_extents']['ymin'] + (y + 1) * w_y }
  end

  def x_y_z_to_map_x_y_enlarged(x, y, z, x_count, y_count)
    bbox_big = x_y_z_to_map_x_y(x + x_count - 1, y + y_count - 1, z)
    # x,y,z to bounding box
    bbox = x_y_z_to_map_x_y(x,y,z)

    { 'x_min' => bbox['x_min'],
      'y_min' => bbox['y_min'],
      'x_max' => bbox_big['x_max'],
      'y_max' => bbox_big['y_max']}

  end

  def single?(x, y, z)
    side = 2**z
    return true if ((x > side - @x_count) || (y > side - @y_count))
    false
  end

  def valid?(x, y, z)
    false if x > (2**(z + 1)) || y > (2**(z + 1)) || z > 24
    true
  end

  def up?
    true
  end

  def max_x(z)
    2**z
  end

  def max_y(z)
    2**z
  end
end

# maps tile x/y/z to map coords using ERSI style configs.
class ESRIXYZMapper < XYZMapper
  ESRI_TILE_SIZE = 512

  def initialize(cfg, logger)
    super(cfg, logger)

    setup_resolutions(cfg)
    save_origin(cfg)
  end

  # save LODs in a easier to access manner
  def setup_resolutions(cfg)
    @resolutions = []
    cfg['esri']['TileCacheInfo'][0]['LODInfos'][0]['LODInfo'].each do |x|
      @resolutions[x['LevelID'][0].to_i] = x['Resolution'][0].to_f
    end
  end

  # pull origins out
  def save_origin(cfg)
    @orig_x = cfg['esri']['TileCacheInfo'][0]['TileOrigin'][0]['X'][0].to_f
    @orig_y = cfg['esri']['TileCacheInfo'][0]['TileOrigin'][0]['Y'][0].to_f
  end

  def x_y_z_to_map_x_y(x, y, z)
    orig_x, orig_y = orig
    res = get_res(z)
    {
      'x' => x,
      'y' => y,
      'z' => z,
      'x_min' =>  orig_x + x * ESRI_TILE_SIZE * res,
      'y_min' =>  orig_y - (y + 1) * ESRI_TILE_SIZE * res,
      'x_max' =>  orig_x + (x + 1) * ESRI_TILE_SIZE * res,
      'y_max' =>  orig_y - (y) * ESRI_TILE_SIZE * res
    }
  end

  def x_y_z_to_map_x_y_enlarged(x, y, z, x_count, y_count)
    res = get_res(z)
    {
      'x' => x,
      'y' => y,
      'z' => z,
      'x_min' =>  @orig_x + x * ESRI_TILE_SIZE * res,
      'y_min' =>  @orig_y - (y + y_count) * ESRI_TILE_SIZE * res,
      'x_max' =>  @orig_x + (x + x_count) * ESRI_TILE_SIZE * res,
      'y_max' =>  @orig_y - (y) * ESRI_TILE_SIZE * res
    }
  end

  def single?(x, y, _z)
    return true if x < @x_count || y < @y_count
    false
  end

  def valid?(_x, _y, _z)
    true
  end

  def up?
    false
  end

  def max_x(z)
    (@cfg['base_extents']['xmax'] - @orig_x) / (get_res(z) * ESRI_TILE_SIZE).to_i + 1
  end

  def max_y(z)
    (@orig_y - @cfg['base_extents']['ymin']) / (get_res(z) * ESRI_TILE_SIZE).to_i + 1
  end

  private

  def get_res(z)
    # @cfg["esri"]["TileCacheInfo"][0]["LODInfos"][0]["LODInfo"][z]["Resolution"][0].to_f
    @resolutions[z]
  end

  def orig
    # [@cfg["esri"]["TileCacheInfo"][0]["TileOrigin"][0]["X"][0].to_f, @cfg["esri"]["TileCacheInfo"][0]["TileOrigin"][0]["Y"][0].to_f]
    [@orig_x, @orig_y]
  end
end
