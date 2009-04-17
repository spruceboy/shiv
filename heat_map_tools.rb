#!/usr/bin/env ruby


##
# Stuff related to the heat map part of shiv..
# Blame jay@alaska.edu for problems..

require "rubygems"
require "GD"
require "tempfile"
require "thread"
require "http_client_tools"


class HeatMapper
    require "imlib2"
    ##
    # cfg is the config hash, logger is the handle to the logger item..
    def initialize ( cfg, logger)
        @lt = "HeatMapper:"
        @cfg = cfg
        @logger = logger
        @z_level_map = cfg["z_level_map"]
        @side = 2**@z_level_map
        @grid = File.open(@cfg["stat_save_file"]) {|x| YAML.load(x)} if (File.exists?(@cfg["stat_save_file"]))
        CalculateGrid() if (!@grid )
        StartStatWriter()
    end
    
    ##
    # adds a tile to the heatmap..
    def AddTile( x,y,z,ip)
        return if (IncludeIP(ip))
        AddHit(x,y,z,ip)
    end
    
    #Gets a image..
    def GetImage()
        puts("Not implemented, don't use fool!")
        exit(-1)
    end
     
    #Gets a image with/bg 
    def GetImageWithBackground()
        puts("Not implemented, don't use fool!")
        exit(-1)
    end
    
    private
    
    #returns true if the ip should be excluded -ie is in the exclude list..
    def IncludeIP ( ip)
        @cfg["exclude_ip"].each do |k|
            k.strip!
            kk = ip[0,k.length]
            kk.strip!
            if (kk == k)
                return true
            end
        end
        
        return false
    end
    
    
    ##
    # This class is really lame - yamling is soo slow, had to write my own yamler...
    def dump(s,fl)
        File.open(fl,"w") do |x|
            x.write("---\n")
            s.each do |ii|
                x.write("- ")
                ii.each_index do |iii|
                    x.write("  ") if (iii != 0 )
                    x.write("- #{ii[iii].to_s}\n")
                end
            end
            
            x.flush()
        end
    end
    def CalculateGrid
        ##
        # setup grid..
        @logger.loginfo(@lt+"Calculating grid..")
        @grid = Array.new(@side)
        0.upto(@side) do |x|
            @grid[x] = Array.new(@side,0.0)
        end
        #File.open(@cfg["stat_save_file"],"w") {|fl| YAML.dump(@grid, fl)}
        #File.open(@cfg["stat_save_file"],"w") {|fl| fl.write(YAML.dump(@grid))}
        dump(@grid,@cfg["stat_save_file"] )
        @logger.loginfo(@lt+"Calculating grid..done.")
    end
    
    def StartStatWriter ()
        Thread.new do
            while (true)
                begin
                    @logger.loginfo(@lt+"StatWriter.sleeping..")
                    sleep(@cfg["stat_sync_time"])
                    @logger.loginfo(@lt+"StatWriter.waking..")
                    @logger.loginfo(@lt+"StatWriter.Start Dump")
                    #File.open(@cfg["stat_save_file"],"w") {|x| YAML.dump(@grid, x)}
                    dump(@grid,@cfg["stat_save_file"] )
                    @logger.loginfo(@lt+"StatWriter.End Dump")
                rescue => err
                    puts err.to_s   ## Some more elegant should be done, I think..
                end
            end
        end
    end
    
    def AddHit ( x,y,z, ip)
        return if (!check_ip(ip) )
        working_x = working_y = nil
        if ( z >= @z_level_map )  #zoom level is at or better than res of grid
            working_x = x / ( 2 ** (z - @z_level_map))
            working_y = y / ( 2 ** (z - @z_level_map))
            @grid[working_x][working_y] += 1.0
        else                       #zoom level is less than res of grid, up sample
            working_x = x * ( 2 ** (@z_level_map-z))
            working_y = y * ( 2 ** (@z_level_map-z))
            
            working_x.upto(working_x + 2 ** (@z_level_map-z)-1) do |i|
                working_y.upto(working_y + 2 ** (@z_level_map-z)-1) do |j|
                    @grid[i][j] += 1.0 
                end
            end
            
        end
    end
    
    private
    
    def check_ip (ip)
        return true; 
    end
end


class Imlib2HeatMapper < HeatMapper
    def initialize ( cfg, logger)
        super(cfg,logger)
    end
    
    ###
    # Returns a path to a image with the current level of junk in it...
    def GetImage()
        side = 2**@z_level_map
        im = Imlib2::Image.new(side,side)
        min = max = @grid[0][0]
        palet = Array.new(side)
        palet.each_index do |i|
            palet[i] = Imlib2::Color::RgbaColor.new(i,0,0,255)
        end
        0.upto(side-1) do |x|
            0.upto(side-1) do |y|
                if ( @grid[x][y] != 0 )
                    max = @grid[x][y] if ( @grid[x][y] > max)
                    min = @grid[x][y] if ( @grid[x][y] < min)
                end
            end
        end
        
        @logger.loginfo("Min = #{min} , max = #{max}")
        
        offset = 0
        max = max -offset
        min = min-offset
        
        delta = (max - min) / 256.0
        delta = 1 if (delta <= 0)
        
        @logger.loginfo("Min = #{min} , max = #{max} , delta = #{delta}")
        
        0.upto(side-1) do |x|
            0.upto(side-1) do |y|
                
                v = @grid[x][y]-offset
                index = ((v-min)/delta).to_i  if (v > 0)
                
                index = 0 if (!index|| index < 0)
                index = 255 if ( index > 255)
                
                c = palet[index]
                if ( !c)
                    puts("Problem! -> #{index}")
                    exit(-1)
                end
                im.draw_pixel(x,y,c)
                #im.draw_pixel(x,y,palet[((@grid[x][y]-min)/delta).to_i])
            end
        end
            
        im.draw_pixel(0,side/2-1,Imlib2::Color::RgbaColor.new(0,255,0,255))
        0.upto(255) {|i| im.draw_pixel(i,side/2-1,palet[i])}
        
        im.save(@cfg["stat_image_file"]+".tmp.png")
        im.delete!
        return @cfg["stat_image_file"]+".tmp.png"
    end
    
    def GetImageWithBackground()
        return GetImageWithBackgroundCmdLine()
    end
    
    private
    
    def GetImageWithBackgroundCmdLine()
        command = []
        command << "convert"
        command << GetImage()
        command << "-crop"
        command << "#{@side/2}x#{@side/2}+0+0"
        command << "-resize"
        command << "2048x2048"
        command << @cfg["stat_image_file"]
        command << "-compose"
        command << "screen"
        command << "-composite"
        command << @cfg["stat_image_file"] + ".heat.png"

        system(*command)
        return @cfg["stat_image_file"] + ".heat.png"
    end
    
    
    #  This is all busted, go away fools!
    #def GetImageWithBackgroundImlib2()
    #    ##
    #    # Setup context..
    #    ctx = Imlib2::Context.new
    #    ctx.operation = Imlib2::Op::ADD
    #    ctx.blend = true
    #    ctx.push
    #    heat_map = Imlib2::Image.load(GetImage())
    #    iw, ih = heat_map.width, heat_map.height
    #    new_w, new_h = iw /2, ih/2
    #    bg = Imlib2::Image.load(@cfg["stat_image_file"])
    #    heat_map.crop_scaled!(0, 0, iw/2, iw/2,bg.width,bg.height)
    #    bg.blend!(heat_map, 0,0,heat_map.width, heat_map.height,0,0,heat_map.width, heat_map.height)
    #    bg.save(@cfg["stat_image_file"] + ".heat.png")
    #    bg.delete!
    #    heat_map.delete!
    #    return @cfg["stat_image_file"] + ".heat.png"
    #end 
    #
    #def GetImageWithBackgroundGD()
    #    heat_map = GD::Image.new_from_png(GetImage())
    #    side = 2**@z_level_map                                  
    #    bg = GD::Image.new_from_png(@cfg["stat_image_file"])
    #    heat_map_scaled = GD::Image.new(2048,2048)
    #    heat_map.copyMerge(bg, 0,0,128,128, 2048,2048,75.0)
    #    File.open(@cfg["stat_image_file"] + ".heat.png","w") { |fl| bg.png(fl) }
    #   return @cfg["stat_image_file"] + ".heat.png"
    #end
    
    private
end
