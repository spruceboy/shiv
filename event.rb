require 'rubygems'
#require "swiftcore/evented_mongrel"
require 'mongrel'
#require "swiftcore/swiftiplied_mongrel"
require 'pp'
require 'lumber'
require 'tile_engine'
require 'handler'
require 'yaml'
require 'kml_generator'
require 'rack'

Rack::Handler::Mongrel.run  BenchmarkHandlerRack.new, :Port => 3333
#run SimpleHandlerRack.new
