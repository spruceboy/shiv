#!/usr/bin/env ruby
require 'rubygems'
require 'tempfile'
require 'thread'
require 'http_client_tools'
require 'yaml'
require 'tile_engine'
require 'lumber'
require 'xmlsimple'

####
# This thing/wiget/unholy abomination is a command line tile fetcher - used to seperate out the tile extration process from shiv,
# to make things a little more fault tollerant/durrable.

if (ARGV.length != 5)
  puts('Usage:')
  puts("\t./tile_grabber.rb [tile_engine.cfg.yml] [name] [x] [y] [z]")
  YAML.dump({ 'error' => true, 'logs' => [] }, STDOUT)
  exit(-1)
end

begin
  ##
  # Someday do something useful with these logs - perhaps route back to shiv, and have shiv do something usefull with them.
  error_lst = []
  info_lst = []
  debug_lst = []
  logs = { 'error' => error_lst, 'info_lst' => info_lst, 'debug_lst' => debug_lst }

  log = LumberAppendNoFile.new({ 'debug' => true, 'info' => true, 'verbose' => true }, error_lst, debug_lst, info_lst)
  log.msginfo('CMD -> {' + ARGV.join(' ') + '}')

  ## Read the config file..
  cfg = File.open(ARGV[0]) { |fd| YAML.load(fd) }
  if cfg['esri_config']
    puts 'using:' + ARGV[0] + '/' + cfg['esri_config']
    cfg['esri'] = File.open(File.dirname(ARGV[0]) + '/' + cfg['esri_config']) { |fd| XmlSimple.xml_in(fd.read) }
  end

  # x,y,z -> self explainitaory.
  x = ARGV[2].to_i
  y = ARGV[3].to_i
  z = ARGV[4].to_i

  # raise ("x,y,or z is out of range for (#{x},#{y},#{z})") if (x > (2**(z+1)) || y > (2**(z+1) ) || z > 24 )

  # go though the configs, find the correct one..
  tile_engine = RmagickTileEngine.new(cfg, log)
  fail ("x,y,or z is out of range for (#{x},#{y},#{z})") unless tile_engine.valid?(x, y, z)

  # get the tile in question..
  path = tile_engine.get_tile(x, y, z)
rescue => e
  require 'mailer'
  YAML.dump({ 'error' => true, 'reason' => e.to_s, 'backtrace' => e.backtrace, 'logs' => logs }, STDOUT)
  # Ok, something very bad happend here... what to do..
  stuff = ''
  stuff += "--------------------------\n"
  stuff = "Broken at #{Time.now}"
  stuff += "--------------------------\n"
  stuff += e.to_s + "\n"
  stuff += "--------------------------\n"
  stuff += ARGV.join(' ') + "\n"
  stuff += "--------------------------\n"
  stuff += e.backtrace.join("\n")
  stuff += "--------------------------\n"
  # Mailer.deliver_message(@cfg["mailer_config"], @cfg["mailer_config"]["to"], "tile grabber crash..", [stuff])
  exit(-1)
end

YAML.dump({ 'error' => false, 'logs' => logs }, STDOUT)
