#!/usr/bin/env ruby

require 'rubygems'
require 'http_client_tools'
require 'yaml'
require 'pp'
require 'tile_engine'

def get_tile(x, y, z, cfg)
  w_x = (cfg['base_extents']['xmax'] - cfg['base_extents']['xmin']) / (2.0**(z.to_f))
  w_y = (cfg['base_extents']['ymax'] - cfg['base_extents']['ymin']) / (2.0**(z.to_f))
  tile_x = ((x.to_f - cfg['base_extents']['xmin']) / w_x).to_i
  tile_y = ((y.to_f - cfg['base_extents']['ymin']) / w_y).to_i
  { 'x' => tile_x, 'y' => tile_y }
end

def x_y_z_to_map_x_y(x, y, z)
  w_x = (@cfg['base_extents']['xmax'] - @cfg['base_extents']['xmin']) / (2.0**(z.to_f))
  w_y = (@cfg['base_extents']['ymax'] - @cfg['base_extents']['ymin']) / (2.0**(z.to_f))
  x_min = @cfg['base_extents']['xmin'] + x * w_x
  { 'x_min' => @cfg['base_extents']['xmin'] + x * w_x,
    'y_min' => @cfg['base_extents']['ymin'] + y * w_y,
    'x_max' => @cfg['base_extents']['xmin'] + (x + 1) * w_x,
    'y_max' => @cfg['base_extents']['ymin'] + (y + 1) * w_y }
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
  # puts("do_tile(#{x},#{y},#{z},#{waggle})")
  waggle = cfg['tiles']['x_count'] if waggle < cfg['tiles']['x_count']
  waggle = cfg['tiles']['y_count'] if waggle < cfg['tiles']['y_count']
  waffle = 0
  max = 2**z - 1
  STDOUT.printf(" #{z} ")
  i = x - waggle
  i = 0 if i < 0
  while i <= x + waggle && i <= max
    j = y - waggle
    j = 0 if j < 0
    while j <= y + waggle && j <= max
      # puts("j = #{j}")
      # puts("Path is #{@eng.get_path(i,j,z)}")
      unless File.exist?(@eng.get_path(i, j, z))
        command = "./external_tiler #{config_path} #{name} #{i} #{j} #{z}"
        # puts("Running \"#{command}\"")
        start_tm = Time.now
        status = YAML.load(`#{command}`)
        printf("Run took %g s {#{command}}\n", (Time.now - start_tm))
        if status['error']
          pp status
          exit(-1)
        end
     end

      waffle += 1
      if waffle % 10 == 0
        STDOUT.printf('.')
        STDOUT.flush
     end
      j += cfg['tiles']['y_count']
    end
    i += cfg['tiles']['x_count']
  end

  do_tile(cfg, x / 2, y / 2, z - 1, waggle / 2, config_path, name) if x != 0 && y != 0 && z != 0
end

shiv_conf = File.open(ARGV[0]) { |x| YAML.load(x) }
towns_conf = File.open(ARGV[1]) { |x| YAML.load(x) }

z = ARGV[3].to_i
fiddle = ARGV[4].to_i
fiddle = 128 unless fiddle
key = ARGV[5]
key = 'google' unless key

puts("fiddle = #{fiddle}")

@eng = TileEngine.new(shiv_conf, nil)
shuffle(towns_conf.keys).each do |town_k|
  STDOUT.printf("Doing #{key}|#{town_k}:")
  STDOUT.flush
  town = towns_conf[town_k]
  pp town
  tile = get_tile(town[key][0], town[key][1], z, shiv_conf)
  do_tile(shiv_conf, tile['x'], tile['y'], z, fiddle, ARGV[0], ARGV[2])
end

puts('Done.')
