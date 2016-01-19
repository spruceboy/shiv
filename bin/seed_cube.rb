#!/usr/bin/env ruby

require 'rubygems'
require 'http_client_tools'
require 'yaml'
require 'pp'

level = 10

ARGV.each do |cfg|
  puts("Doing #{cfg}..")
  tile_cfg = File.open(cfg) { |fd| YAML.load(fd) }
  x_inc = tile_cfg['tiles']['x_count']
  y_inc = tile_cfg['tiles']['y_count']
  0.upto(level) do |z|
    x = 0
    while x < 2**z
      y = 0
      while y < 2**z
        puts("Doing ./external_tiler #{cfg} name #{x} #{y} #{z}")
        zing = YAML.load(`./external_tiler #{cfg} name #{x} #{y} #{z}`)
        if zing['error']
          puts("Errored out on \"./external_tiler #{cfg} name #{x} #{y} #{z}\" ..")
          exit(-1)
        end
        y += y_inc
      end
      sleep(10) # sleep way, little cpu waster!
      x += x_inc
    end
    puts("Done with level #{z} , out of #{level}..")
  end
end

puts('Done.')
