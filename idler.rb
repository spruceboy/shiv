#!/usr/bin/env ruby



###
# Idler
# Queues up additional requests, and does them in the background, hopefully speeding up panning&zooming in uncached areas.


class Idler
  def initialize(n, fifo_path)
    @MAX_QUEUE=3000    #should be configureable.
    system("mkfifo", fifo_path)
    @fifo = File.open(fifo_path, "w+")
    
    puts("#{self.class.to_s}: Starting.")
    @queue = []
    
    1.upto(n) do
      Thread.new do
        loop do
          item = @queue.shift
          
          #write to fifo.. needed so nothing blocks. 
          begin
            if (item)
              #puts("#{self.class.to_s}: doing #{item["x"]}, #{item["y"]}, #{item["z"]}")
              @fifo.syswrite("#{item["path"]} #{item["x"]} #{item["y"]} #{item["z"]}\n")
            else
              #puts("#{self.class.to_s}: Sleeping, nothing to do.")
              sleep(10)
              #puts("#{self.class.to_s} Waking up.")
            end
          rescue => e
            puts e.to_s
          end
        end
      end
    end
  end
  
  def add ( cfg, x,y,z)
    
    #return if values out of reasonable limits
    return if (x < 0 || y < 0 || x >= 2**z || y >= 2**z)
    
    #return if queue is really large
    if (@queue.length > @MAX_QUEUE)
      puts("Idler: Queue full!")
      return
    end
    
    #puts("#{self.class.to_s}: Adding #{cfg} #{x}/#{y}/#{z}.")
    #add to queue
    @queue << {"path" => cfg.get_cfg["config_path"], "x" => x, "y" => y,"z" => z}
  end
end
