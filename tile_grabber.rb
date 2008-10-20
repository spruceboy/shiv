#!/usr/bin/env ruby
require "rubygems"
require "imlib2"
require "tempfile"
require "thread"
require "http_client_tools"
require "yaml"
require "pp"
require "tile_engine"
require "lumber"

log = LumberNoFile.new({"debug"=> true, "info" => true, "verbose" => true})
cfg = YAML.load(File.open(ARGV[0]))["tile_engines"]
name = ARGV[1]
x = ARGV[2].to_i
y = ARGV[3].to_i
z = ARGV[4].to_i

cfg.each {|item| next if @cfg;  @cfg = item if ( item["title"] == name)}

pp @cfg
tile_engine =  Imlib2TileEngine.new(@cfg, log)
path = tile_engine.get_tile(x,y,z)



