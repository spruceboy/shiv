#!/usr/bin/env ruby
require 'rubygems'
require 'trollop'
require 'tempfile'
require 'thread'
require 'yaml'
require 'shiv/tile_engine'
require 'shiv/lumber'
require 'xmlsimple'

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

waiting_interval = 3
update_interval = 1000

queue = Queue.new

###
# Reader..


@done = false

threads << Thread.new do
  loop do
    begin
             ln = pipe.readline
             # puts "Reader: " + ln
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
               puts 'Reader: Queue full.'
               sleep waiting_interval
               next
             end
           rescue EOFError
             puts('INFO reader: out of things to do.. ')
	     if (!opts[:pipe])
		puts("INFO reader: Done.")
		@done = true
		break
             else
		pipe = File.open(opts[:pipe])
             	sleep(10)
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

threads << Thread.new do
  while !@done do
	puts("INFO: queue size #{queue.length}")
	sleep(1)
  end
end

###
# Threads for each tiler.
1.upto(opts[:threads]) do |i|
  threads << Thread.new do
    # thread it
    my_id = i

    # counters for progress
    waffle = 0
    tiles = 0
    last_tiles = 0
    start_time = Time.now
    tile_engine = nil

    # config file helper..
    cfg = nil
    puts "Starting Worker #{my_id}"
    while (!@done || !queue.empty?) do
      begin
        ##
        # Someday do something useful with these logs
        # perhaps route back to shiv, and have shiv do
        # something usefull with them.

        # empty places to store logs
        error_lst = []
        info_lst = []
        debug_lst = []

        logs = { 'error' => error_lst,
                 'info_lst' => info_lst,
                 'debug_lst' => debug_lst }

        log = LumberAppendNoFile.new({ 'debug' => true,
                                       'info' => true,
                                       'verbose' => true },
                                     error_lst,
                                     debug_lst,
                                     info_lst)

        log.msginfo('CMD -> {' + ARGV.join(' ') + '}')

        tile = queue.pop(true)
        unless tile
	  if ( @done )
	  	puts ("INFO(#{my_id}): done")
		break
	  else
          	puts("INFO(#{my_id}): queue empty.. #{queue.length}")
          	sleep waiting_interval
          	next
	  end
        end

        # load configs, skiping if it is the same as the last one.
        if cfg.nil? || cfg['path'] != tile['cfg'] || tile_engine.nil?
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
          tile_engine = RmagickTileEngine.new(cfg, log)
        end

        # newer versions use this
        # if (!tile_engine.valid?(x,y,z))
        #   raise ("x,y,or z is out of range for (#{x},#{y},#{z})")
        # end

	#check to see if tile production is already in progress..
	if (tile_engine.in_progress(tile['x'], tile['y'], tile['z']))
		#puts "INFO(#{my_id}) skipping #{tile['x']}/#{tile['y']}/#{tile['z']}"
		next
	end

        tile_engine.get_tile(tile['x'], tile['y'], tile['z'])

        waffle += 1
        tiles += cfg['tiles']['x_count'] * cfg['tiles']['y_count']
        if waffle % update_interval == 0
          seed_rate = (tiles - last_tiles).to_f / (Time.now - start_time)
          start_time = Time.now
          last_tiles = tiles
          puts "INFO(#{my_id}) #{tiles} tiles seeded"
          #puts "INFO(#{my_id}) last: #{tile.to_yaml}"
          puts "INFO(#{my_id}) rate is: #{seed_rate} sets/sec"
          waffle = 0 if waffle > 1_000_000
        end
      rescue ThreadError => e 
	 puts("INFO(#{my_id}): queue empty.. #{queue.length}")
         sleep waiting_interval
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
        YAML.dump({ 'error' => false, 'logs' => logs }, STDOUT)
      end
    end
  end
end

threads.each(&:join)
