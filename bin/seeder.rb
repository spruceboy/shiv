#!/usr/bin/env ruby

require 'rubygems'
require 'http_client_tools'
require 'yaml'
require 'pp'

def get_tile(x, y, z, cfg)
  w_x = (cfg['base_extents']['xmax'] - cfg['base_extents']['xmin']) / (2.0**(z.to_f))
  w_y = (cfg['base_extents']['ymax'] - cfg['base_extents']['ymin']) / (2.0**(z.to_f))
  tile_x = ((x.to_f - cfg['base_extents']['xmin']) / w_x).to_i
  tile_y = 2**z - ((y.to_f - cfg['base_extents']['ymin']) / w_y).to_i
  { 'x' => tile_x, 'y' => tile_y }
end

def shuffle(s)
  0.upto(s.length) do |_x|
    i = rand(s.length - 1)
    z = i
    z = rand(s.length) while z == i

    t = s[i]
    s[i] = s[z]
    s[z] = t
  end

  s
end

def do_tile(cfg, x, y, z, waggle, config_path, name)
  waffle = 0
  max = 2**z - 1
  STDOUT.printf(" #{z} ")
  (x - waggle).upto(x + waggle) do |i|
    (y - waggle).upto(y + waggle) do |j|
      i = 0 if i < 0
      j = 0 if j < 0
      i = max if i > max
      j = max if j > max
      system('ruby', 'tile_grabber.rb', config_path, name, "#{i}", "#{j}", "#{z}")
      waffle += 1
      if waffle % 50 == 0
        STDOUT.printf('.')
        STDOUT.flush
     end
    end
  end

  do_tile(cfg, x / 2, y / 2, z - 1, waggle / 2) if x != 0 && y != 0 && z != 0
end

shif_conf = File.open(ARGV[0]) { |x| YAML.load(x) }
towns_conf = File.open(ARGV[1]) { |x| YAML.load(x) }

z = ARGV[3].to_i
fiddle = ARGV[4].to_i
fiddle = 128 unless fiddle
key = ARGV[5]
key = 'google' unless key

shif_conf['tile_engines'].each do |item|
  next if (item['title'] != ARGV[2])
  shuffle(towns_conf.keys).each do |town_k|
    STDOUT.printf("Doing #{key}|#{town_k}:")
    STDOUT.flush
    town = towns_conf[town_k]
    pp town
    tile = get_tile(town[key][0], town[key][1], z, item)
    do_tile(item, tile['x'], tile['y'], z, fiddle, ARGV[0], ARGV[2])
    exit(-1)
  end
  # Curl::Easy.download(ARGV.first + "/#{x}/#{y}/#{z}" , "/dev/null")
end

puts('Done.')
