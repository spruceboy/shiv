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


#takes a bbob, and returns an array of points suitable for
#converting to a linestring
def bbox_to_line_array(bbox, factory)
  [
    factory.point(bbox['x_min'], bbox['y_min']),
    factory.point(bbox['x_min'], bbox['y_max']),
    factory.point(bbox['x_max'], bbox['y_max']),
    factory.point(bbox['x_max'], bbox['y_min']),
    factory.point(bbox['x_min'], bbox['y_min'])
  ]
end

#takes a x,y,z bbox, and converts it to a geometry
def togeo(engine, x, y, z, factory)
  bbox = engine.x_y_z_to_map_x_y(x, y, z)
  factory.polygon(factory.line_string(bbox_to_line_array(bbox, factory)))
end

def isin?(engine, geo,x, y, z, factory)
  bbox_geo = togeo(engine, x, y, z, factory)
  (bbox_geo.within?(geo) || geo.within?(bbox_geo) || geo.intersects?(bbox_geo))
end

def dolevel(x, y, z, cfg, opts, geo, engine)
  return if z > opts[:z]
  STDERR.puts("Progress: #{x}/#{y}/#{z}") if (z == 7)
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
end

cfg = File.open(opts[:cfg]) { |fd| YAML.load(fd) }

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

if (opts[:pipe] )
	@pipe = File.open(opts[:pipe], 'w')
end

STDERR.puts("Begining..")
geos.each { |x| dolevel(0, 0, 0, cfg, opts, x, tile_engine) }

