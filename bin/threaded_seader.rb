#!/usr/bin/env ruby
require 'rubygems'
require 'trollop'
require 'tempfile'
require 'thread'
require 'yaml'
require 'shiv/tile_engine'
require 'shiv/lumber'
require 'xmlsimple'

##
# Loads configs
def load_cfg(tile, opts, tile_configs)
  # check to see if it is already in the tile_configs hash..
  return tile_configs[tile['cfg']] if tile_configs[tile['cfg']]

  puts("Loading #{tile['cfg']}")
  cfg = File.open(tile['cfg']) { |fd| YAML.load(fd) }
  if cfg['esri_config']
    esri_cfg_file = File.dirname(tile['cfg']) + '/' + cfg['esri_config']
    cfg['esri'] = File.open(esri_cfg_file) do |fd|
      XmlSimple.xml_in(fd.read)
    end
   end
  cfg['path'] = tile['cfg']
  cfg['tiles']['x_count'] *= opts[:seed_mult]
  cfg['tiles']['y_count'] *= opts[:seed_mult]

  # adjust path if needed
  if (opts[:path_override] != '')
    cfg['cache_dir'] = opts[:path_override] +
                       '/' +
                       File.basename(cfg['cache_dir']) +
                       '/'
    if cfg['watermark']['image']
      watermark_path = [opts[:path_override],
                        '/images/',
                        File.basename(cfg['watermark']['image'])]
      cfg['watermark']['image'] = watermark_path.join
    end
   end
  tile_engine = RmagickTileEngine.new(cfg, NullLumber.new)
  tile_configs[tile['cfg']] = [tile_engine, cfg]
end

####
# This thing/wiget/unholy abomination is a command line
# tile fetcher - used to seperate out the tile extration process from shiv,
# to make things a little more fault tollerant/durrable.

opts = Trollop.options do
  opt :verbose, 'Be more verbose', default: false
  opt :threads, 'Number of tilers to run at a time', default: 3
  opt :pipe, 'pipe', default: nil
  opt :path_override, 'Override path', default: ''
  opt :seed_mult, 'Grow the meta-tiling by this ammount', default: 1
end

# open tile stream
pipe = STDIN
if opts[:pipe]
  system("rm -f -v #{opts[:pipe]}") if File.exist?(opts[:pipe])
  system("mkfifo #{opts[:pipe]}")
  pipe = File.open(opts[:pipe])
end

threads = []

waiting_interval = 1
update_interval = 20
@tiles_done = 0

queue = Queue.new

###
# Reader..
# reads list of tiles from stdin or from a pipe
@done = false
threads << Thread.new do
  loop do
    begin
             ln = pipe.readline
             list = ln.split
             tile = { 'cfg' => list[0],
                      'x' => list[1].to_i,
                      'y' => list[2].to_i,
                      'z' => list[3].to_i }
             unless tile['cfg'] && tile['x'] && tile['y'] && tile['z']
               puts("Reader: bad input '#{list}'")
               next
             end
             queue.push(tile)
             if queue.length > 200_000
               sleep waiting_interval
               next
             end
           rescue EOFError
             puts('INFO reader: out of things to do.. ')
             if !opts[:pipe]
               puts('INFO reader: Done.')
               @done = true
               break
             else
               pipe = File.open(opts[:pipe])
               sleep(waiting_interval)
             end
             puts('INFO reader: waking up.')
           rescue RuntimeError => e
             stuff = ''
             stuff += "--------------------------\n"
             stuff += "Broken at #{Time.now}"
             stuff += "--------------------------\n"
             stuff += e.to_s + "\n"
             stuff += "--------------------------\n"
             stuff += ARGV.join(' ') + "\n"
             stuff += "--------------------------\n"
             stuff += e.backtrace.join("\n")
             stuff += "--------------------------\n"
             puts stuff
           end
  end
end

##
# queue watcher - prints length of queue
# peroidlicly.
threads << Thread.new do
  until @done
    puts("INFO: queue size #{queue.length}")
    sleep(60)
  end
end

###
# Performance watcher - prings performance status perodicly.
threads << Thread.new do
  done_last = 0
  last_time = Time.now
  start_time = Time.now
  sleep(60)
  until @done
    if @tiles_done == 0
      puts 'PERF: nothing done.. '
    else
      time_now = Time.now
      seed_rate = @tiles_done.to_f / (time_now - start_time)
      tiles_done_since_last_run = @tiles_done - done_last
      seed_rate_rec = (tiles_done_since_last_run).to_f / (time_now - last_time)
      done_last = @tiles_done
      last_time = time_now
      puts "PERF: #{@tiles_done} tiles seeded"
      puts "PERF: rate is: #{seed_rate} sets/sec"
      puts "PERF: current rate is: #{seed_rate_rec} sets/sec, #{tiles_done_since_last_run} tile sets"
    end
    sleep(60)
  end
end

###
# tiling threads - generates tiles
1.upto(opts[:threads]) do |i|
  threads << Thread.new do
    # thread it
    my_id = i

    # counters for progress
    waffle = 0
    tiles = 0
    last_tiles = 0
    start_time = Time.now

    tile_configs = {}

    puts "Starting Worker #{my_id}"
    while !@done || !queue.empty?
      begin

        tile = queue.pop(true)
        unless tile
          if @done
            puts ("INFO(#{my_id}): done")
            break
          else
            puts("INFO(#{my_id}): queue empty.. #{queue.length}")
            sleep waiting_interval
            next
          end
        end

        tile_engine, cfg = load_cfg(tile, opts, tile_configs)

        unless tile_engine.valid?(tile['x'], tile['y'], tile['z'])
          fail ("x,y,or z is out of range for #{tile['x']}/#{tile['y']}/#{tile['z']}")
        end

        next if tile_engine.generated?(tile['x'], tile['y'], tile['z'])

        # check to see if tile production is already in progress..
        if tile_engine.in_progress(tile['x'], tile['y'], tile['z'])
          next
        else
          tile_engine.get_tile(tile['x'], tile['y'], tile['z'])
        end

        @tiles_done += cfg['tiles']['x_count'] * cfg['tiles']['y_count']
      rescue ThreadError => e
        puts("THREAD(#{my_id}): queue empty.. #{queue.length}")
        sleep waiting_interval
        puts("THREAD(#{my_id}): waking up..")
      rescue RuntimeError => e
        stuff = ''
        stuff += "--------------------------\n"
        stuff += "Broken at #{Time.now}"
        stuff += "--------------------------\n"
        stuff += e.to_s + "\n"
        stuff += "--------------------------\n"
        stuff += ARGV.join(' ') + "\n"
        stuff += "--------------------------\n"
        stuff += e.backtrace.join("\n")
        stuff += "--------------------------\n"
        puts stuff
      rescue Exception => e
        stuff = ''
        stuff += "--------------------------\n"
        stuff += "Broken at #{Time.now}"
        stuff += "--------------------------\n"
        stuff += e.to_s + "\n"
        stuff += "--------------------------\n"
        stuff += ARGV.join(' ') + "\n"
        stuff += "--------------------------\n"
        stuff += e.backtrace.join("\n")
        stuff += "--------------------------\n"
        puts stuff
      end
    end
  end
end

threads.each(&:join)
