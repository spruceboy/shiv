#!/usr/bin/env ruby

require 'rubygems'
require 'curb'
require 'http_client_tools'

# downloader = SimpleHttpClient.new()
downloader = SimpleCurbHttpClient.new

total_tm = 0
x = 1
rot = 200
loop do
  # STDOUT.write(".")
  # STDOUT.flush
  start_tm = Time.now
  downloader.easy_download(ARGV.first, '/dev/null')
  total_tm += Time.now - start_tm
  if x > rot
    puts "\nPerf = #{total_tm / x.to_f}, thats #{1.0 / (total_tm / x.to_f)} "
    x = 0
    total_tm = 0
  end
  x += 1
end
