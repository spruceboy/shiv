#!/usr/bin/env ruby
require 'rubygems'
require 'trollop'
require 'tempfile'
require 'thread'
require 'shiv'
require 'xmlsimple'
require 'pp'
require 'rgeo/shapefile'

# reads the geometry out of the shapefile, and returns an array of geometry
def readgeos(shapefile)
  STDERR.puts("INFO: reading #{shapefile}")
  geos = []
  require 'rgeo/shapefile'
  RGeo::Shapefile::Reader.open(shapefile) do |file|
    STDERR.puts "File contains #{file.num_records} records."
    file.each do |record|
      geos << record.geometry
    end
  end

  geos
end

# takes a bbob, and returns an array of points suitable for
# converting to a linestring
def bbox_to_line_array(bbox, factory)
  [
    factory.point(bbox['x_min'], bbox['y_min']),
    factory.point(bbox['x_min'], bbox['y_max']),
    factory.point(bbox['x_max'], bbox['y_max']),
    factory.point(bbox['x_max'], bbox['y_min']),
    factory.point(bbox['x_min'], bbox['y_min'])
  ]
end

# takes a x,y,z bbox, and converts it to a geometry
def togeo(engine, x, y, z, factory)
  bbox = engine.x_y_z_to_map_x_y(x, y, z)
  factory.polygon(factory.line_string(bbox_to_line_array(bbox, factory)))
end

def isin?(engine, geo, x, y, z, factory)
  bbox_geo = togeo(engine, x, y, z, factory)

  #pp 'bbox:'
  #pp bbox_geo
  #pp 'geo:'
  #pp geo
  (bbox_geo.within?(geo) || geo.within?(bbox_geo) || !geo.disjoint?(bbox_geo))
end

def dolevel(x, y, z, cfg, opts, geo, engine)
  return if z > opts[:z]
  STDERR.puts("Progress: #{x}/#{y}/#{z}")  if (z == 7)
  return unless isin?(engine, geo, x, y, z, @factory)

  if @pipe
    @pipe.syswrite("#{opts[:cfg]} #{x} #{y} #{z}\n")
  else
    puts "#{opts[:cfg]} #{x} #{y} #{z}"
  end

  0.upto(1) do |i|
    0.upto(1) do |j|
      dolevel(x * 2 + i, y * 2 + j, z + 1, cfg, opts, geo, engine)
    end
  end
end

def do_per_level(opts, geo, engine, tile_mapper)
  bbox = RGeo::Cartesian::BoundingBox.create_from_geometry(geo)
  opts[:s].upto(opts[:z]) do |z|
    tile_min_max = tile_mapper.tile_min_and_max_for_bbox(bbox.min_x, bbox.min_y, bbox.max_x, bbox.max_y, z) 
    pp tile_min_max
    tile_min_max['x_min'].upto(tile_min_max['x_max']) do |x|
      tile_min_max['y_min'].upto(tile_min_max['y_max']) do |y|
        next unless isin?(engine, geo, x, y, z, @factory)
        if @pipe
          @pipe.syswrite("#{opts[:cfg]} #{x} #{y} #{z}\n")
        else
          puts "#{opts[:cfg]} #{x} #{y} #{z}"
          end
      end
    end
  end
end

# This thing/wiget/unholy abomination is a command line tile fetcher
# used to seperate out the tile extration process from shiv,
# to make things a little more fault tollerant/durrable.

opts = Trollop.options do
  opt :verbose, 'Be more verbose', default: false
  opt :cfg, 'config', default: 'This is it'
  opt :shapefile, 'shapefile', default: 'shapefile'
  opt :pipe, 'pipe', default: nil
  opt :z, 'z_level_max', default: 5
  opt :s, 'z_level_min', default: 1
  opt :x, 'max_x', default: 30_000_000.0
  opt :y, 'may_y', default: 30_000_000.0
  opt :combine, 'combine', default: false
  opt :strange_z_levels, 'use this option if the zoom levels are not all power of 2 - for example does a tile x/y/z completely cover x*2/y*2/z+1', default: false
end

cfg = File.open(opts[:cfg]) { |fd| YAML.load(fd) }

##
# Esri special case handling - need to wrap into engines..
if cfg['esri_config']
  esri_cfg_file = File.dirname(opts[:cfg]) + '/' + cfg['esri_config']
  cfg['esri'] = File.open(esri_cfg_file) do |fd|
    XmlSimple.xml_in(fd.read)
  end
end

# error junk
error_lst = []
info_lst = []
debug_lst = []

# geo factory
@factory = RGeo::Cartesian.factory

log = LumberAppendNoFile.new(
  { 'debug' => true, 'info' => true, 'verbose' => true },
  error_lst, debug_lst, info_lst)
tile_engine = RmagickTileEngine.new(cfg, log)

geos = readgeos(opts[:shapefile])

if opts[:combine]
  sum = geos.first
  geos.each { |x| sum = sum.union(x) }
  geos = [sum]
end

@pipe = File.open(opts[:pipe], 'w') if opts[:pipe]

STDERR.puts('Begining..')
geos = geos[0, 1]
if !opts[:strange_z_levels]
  geos.each { |x| dolevel(0, 0, 0, cfg, opts, x, tile_engine) }
else
  tile_mapper = ESRIXYZMapper.new(cfg, log)
  geos.each { |x| do_per_level(opts, x, tile_engine, tile_mapper) }
end
