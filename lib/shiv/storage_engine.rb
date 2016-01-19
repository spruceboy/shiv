# storage engines controls the structure of the cache files

# standard shiv default storage engine
class StorageEngine
  PATH_FORMAT = '%02d/%03d/%03d/%09d/%09d/%09d_%09d_%09d.%s'
  def initialize(cfg, _logger)
    @cfg = cfg
  end

  def get_path(x, y, z)
    @cfg['cache_dir'] + sprintf(PATH_FORMAT, z, x % 128, y % 128, x, y, x, y, z, @storage_format)
  end
end

# ESRI exploded cache storage engine
class ESRIStorageEngine
  PATH_FORMAT = 'dfg_common_ginaImagery0114exp/Layers/_alllayers/L%02d/R%08x/C%08x.%s'
  def initialize(cfg, _logger)
    @cfg = cfg
  end

  def get_path(x, y, z)
    @cfg['cache_dir'] + sprintf(PATH_FORMAT, z, y, x, @cfg['storage_format'])
  end
end
