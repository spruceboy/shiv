#!/usr/bin/env ruby



###
# Idler
# Queues up additional requests, and does them in the background, hopefully speeding up panning&zooming in uncached areas.


class Idler
  def initialize(n)
    
    puts("#{self.class.to_s}: Starting.")
    @queue = []
    
    1.upto(n) do
      Thread.new do
        loop do
          puts("#{self.class.to_s} Waking up.")
          item = @queue.shift
          
          begin
            if (item)
              puts("#{self.class.to_s}: doing #{item["x"]}, #{item["y"]}, #{item["z"]}")
              item["engine"].make_tiles(item["x"], item["y"], item["z"])
            else
              puts("#{self.class.to_s}: Sleeping, nothing to do.")
              sleep(10)
            end
          rescue => e
            puts e.to_s
          end
        end
      end
    end
  end
  
  def add ( engine, x,y,z)
    #return if values out of reasonable limits
    return if (x < 0 || y < 0 || x >= 2**z || y >= 2**z)
    
    
    puts("#{self.class.to_s}: Adding #{x}/#{y}/#{z}.")
    #add to queue
    @queue << {"engine" => engine, "x" => x, "y" => y,"z" => z}
  end
end
