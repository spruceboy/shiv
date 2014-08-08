#!/usr/bin/env ruby
require 'trollop'
require 'yaml'
require "curb"

opts = Trollop::options do
  opt :verbose, "Be more verbose", :default => false
  opt :threads, "Number of tilers to run at a time", :default => 3
end



threads = []

times = []


###
# Threads for each fetcher
1.upto(opts[:threads]) do |i|
  threads << Thread.new do
    loop do
      begin
          #using backticks
          #command = ["curl", "-o", "/dev/null", "http://spam.gina.alaska.edu/tiles/bdl/tile/#{rand(2**10)}/#{rand(2**10)/10"]
          start_time = Time.now 
          Curl.get("http://spam.gina.alaska.edu/tiles/bdl/tile/#{rand(2**10)}/#{rand(2**10)}/10")
	  times << Time.now - start_time
	  #puts times.length
      rescue => e
        puts e.to_s
      end
    end
  end
end

threads << Thread.new do
    while (times.length < 10 ) do 
	sleep(10) 
    end
    loop do
      begin
	min = times.first
	max = times.first
	sum = 0
	times.each do |i| 
		sum += i
		min = i if (i < min)
		max = i if (i > max)
	end 
	puts("Stats: ##{times.length} ave:#{sum.to_f/times.length} min:#{min} max:#{max}")
	sleep(10)
      rescue => e
        puts e.to_s
      end
    end
  end


threads.each {|t| t.join}



