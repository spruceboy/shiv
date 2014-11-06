#!/usr/bin/env ruby
require 'trollop'
require 'yaml'

opts = Trollop::options do
  opt :verbose, "Be more verbose", :default => false
  opt :threads, "Number of tilers to run at a time", :default => 3
end



queue = []

threads = []

MAX_QUEUE = 10000

reader = 1


###
# Reader for each file..
ARGV.each do |item|
  threads << Thread.new do
    treader = reader
    reader += 1 
    loop do
      begin
        puts("INFO Reader #{treader}: opening #{item}")
        fifo = File.open(item)
        loop do
	    while (queue.length > MAX_QUEUE ) 
		puts("INFO Reader #{treader}: Queue too big..")
		sleep(30)
	    end

            ln = fifo.readline
            list = ln.split
            tile = {"cfg"=>list[0], "x" => list[1].to_i,"y" => list[2].to_i,"z" => list[3].to_i}
            puts("READ Reader #{treader}: #{tile.to_s}") if ( opts[:verbose])
            queue.push(tile)
        end
      rescue => e
          puts "Error Reader #{treader}: " + e.to_s
      end
    end
  end
end


waffle = 0 


###
# Threads for each tiler.
1.upto(opts[:threads]) do |i|
  threads << Thread.new do
    loop do
      puts("Engine ##{i} Waking up.")  if ( opts[:verbose])
      item = queue.shift
      
      #write to fifo.. needed so nothing blocks. 
      begin
        if (item)
          #using backticks
          command = ["./external_tiler", item["cfg"], "test", item["x"].to_s, item["y"].to_s, item["z"].to_s]
	  puts ("Running #{command.join(" ")}") if ( opts[:verbose])
          results = YAML.load(`#{command.join(" ")}`)
          #using popen
          #results = YAML.load(IO.popen(command.join(" ") {|f| f.readlines}))
          puts("Engine ##{i}: error? #{results["error"]}") if ( opts[:verbose])
          if (results["error"])
            #output from the external tiler should include backtrace, logs, and reason..
            #({"error"=>true, "reason" => e, "backtrace" => e.backtrace, "logs"=>logs }, STDOUT)
            puts "Engine ##{i}: external tiler error, reason -> #{results["reason"]}, backtrace -> #{results["backtrace"]}, command line -> '#{command.join(" ")}'"
          end

          waffle += 1
          if ( waffle%50 == 0)
		puts("#{waffle} tiles seeded (to go #{queue.length}). last one => #{item["cfg"]} #{item["x"]} #{item["y"]} #{item["z"]}")
		waffle = 0 if (waffle > 1000000)
          end

        else
          puts("Engine ##{i}: #{self.class.to_s}: Sleeping, nothing to do.") if ( opts[:verbose])
          sleep(1)
        end
      rescue => e
        puts "ERROR -> \"#{e.to_s}\" for #{YAML.dump(item)}"
      end
    end
  end
end

threads.each {|t| t.join}



