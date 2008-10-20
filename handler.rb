#!/usr/bin/env ruby
#
# Mongrel related happyness... And it seems like tommarrow might not come...
#

# Helper class w/some mongrel speeder-uppers...
#
# Has things that most mongrel handler sub classes should have..

##
# Provides heat map related stuff...
#require "heat_map_tools"

##
# provides a way to mail errors etc..
require "mailer"

#************************************************************************************************

##
# Mongrel helper master class - should contain everything that is shared by mongrel handlers..
# Don't create one, subclass one..

class MongrelWelder < Mongrel::HttpHandler
    private
      
      ##
      # Taken from dir handler..
      def send_file_full(req_path, request, response,type="png", header_only=false)
	 stat = File.stat(req_path)

         # Set the last modified times as well and etag for all files
	 mtime = stat.mtime
         # Calculated the same as apache, not sure how well the works on win32
	 etag = Mongrel::Const::ETAG_FORMAT % [mtime.to_i, stat.size, stat.ino]

         modified_since = request.params[Mongrel::Const::HTTP_IF_MODIFIED_SINCE]
	 none_match = request.params[Mongrel::Const::HTTP_IF_NONE_MATCH]

         # test to see if this is a conditional request, and test if
	 # the response would be identical to the last response
         same_response = case
                      when modified_since && !last_response_time = Time.httpdate(modified_since) rescue nil : false
                      when modified_since && last_response_time > Time.now                                  : false
                      when modified_since && mtime > last_response_time                                     : false
                      when none_match     && none_match == '*'                                              : false
                      when none_match     && !none_match.strip.split(/\s*,\s*/).include?(etag)              : false
                      else modified_since || none_match  # validation successful if we get this far and at least one of the header exists
                      end

	 header = response.header
         header[Mongrel::Const::ETAG] = etag

	 if same_response
	    response.start(304) {}
	    return 0
	 else

	    # First we setup the headers and status then we do a very fast send on the socket directly

            # Support custom responses except 404, which is the default. A little awkward. 
	    response.status = 200 if response.status == 404
	    header[Mongrel::Const::LAST_MODIFIED] = mtime.httpdate
   
	    header[Mongrel::Const::CONTENT_TYPE] = "image/#{type}"

   	    # send a status with out content length
   	    response.send_status(stat.size)
	    response.send_header

	    if not header_only
	       #response.send_file(req_path, stat.size < Const::CHUNK_SIZE * 2)
	       response.send_file(req_path, stat.size < 16*1024 * 2)
	    end
	    return stat.size
	 end
      end
end



#************************************************************************************************

##
# Simplest Handler of them all...  Not sure if used or not

class SimpleHandler < MongrelWelder 
    def initialize ( log)
      @logger = log
      @REMOTE_IP_TAG="HTTP_X_FORWARDED_FOR"
    end
    def process(request, response)
      @logger.puts("hit -> #{request.params[@REMOTE_IP_TAG]} -> #{request.params["REQUEST_URI"]}")
      response.start(200) do |head,out|
        head["Content-Type"] = "text/plain"
        out.write("hello!\n")
      end
    end
end



#************************************************************************************************
##
# Exit Handler - quits when hit...  needs more safety!

class ExitHandler < MongrelWelder 
    def initialize ( log)
      @logger = log
      @REMOTE_IP_TAG="HTTP_X_FORWARDED_FOR"
    end
    def process(request, response)
      @logger.puts("Got Exit request -> #{request.params[@REMOTE_IP_TAG]} -> #{request.params["REQUEST_URI"]}")
      exit(-1)
    end
end
#************************************************************************************************
 
###
# Tile Handler - does google map like requests..
# Handles google maps like tile requests, of the form /tag/tiles/x/y/z
class TileHandler < MongrelWelder
    
    def initialize (cfg, log, http_cfg)
        
        #save stuff for later
	@logger = log
	@cfg = cfg
	@url_root = http_cfg["base"]    #/tag/
	@http_cfg = http_cfg
	@tile_engine =  Imlib2TileEngine.new(cfg, log)   #Use the imlib2 engine..
	
	@lt = self.class.to_s + ":"
	@logger.loginfo(@lt+"Starting")
	@REMOTE_IP_TAG="HTTP_X_FORWARDED_FOR"
    end
   
   #Handle a request
    def process(request, response)
        begin
            
            mn = "process:"  #name of this method.. used for logging..
            
            #log request
            @logger.loginfo(@lt+mn + "hit -> #{request.params[@REMOTE_IP_TAG]} -> #{request.params["REQUEST_URI"]}")
            
            #time of start..
            start_tm = Time.now
             
            # Log access...
            @logger.log_access(request)
            
            ##
            #Remove prefix from url..
            uri = request.params["REQUEST_URI"]
            uri = uri[@url_root.length,uri.length] if ( uri[0,@url_root.length] == @url_root)
            uri = uri.split("/")
              
            ##
            #Uri looks like:
            #	(0)/bdl(1)/tile(2)/x(3)/y(4)/z(5)
            #validate url..
            if (uri.length != 6 || uri[2] != "tile" )
                if ( uri[3] == "heatmap")
                    #generate and send heatmap back to browser..
                    @logger.loginfo(@lt+mn + ".Heatmap request")
                    size = send_file_full(@heatmapper.GetImageWithBackground(), request, response, "png")
                    #Log xfer..
                    @logger.log_xfer(request,response,size, Time.now-start_tm)
                else
                    @logger.logerr("Bad uri '#{request.params["REQUEST_URI"]} from #{request.params[@REMOTE_IP_TAG]}")
                    response.start(404) do |head,out|
                        head["Content-Type"] = "text/plain"
                        out.write("The uri, #{request.params["REQUEST_URI"]}, is not good.\n")
                        out.write("URI length is #{uri.length}")
                        0.upto(uri.length-1) do |index|
                            out.write("{[#{index}]=>[#{uri[index]}]}")
                        end
                        out.write("Sadness...\n")
                    end
                end
                return		# Done with no-tile related stuff...
            end
              
            x = uri[3].to_i
            y = uri[4].to_i
            z = uri[5].to_i
            
            ##
            # Flip... go from jays tile scheme to googles..
            y = 2**z-y-1
            
            # Call get tile..
            path = @tile_engine.get_tile(x,y,z)
            
            # Wait for it to show up..
            @tile_engine.check_and_wait(x,y,z)
              
            ##
            # Do request..
            size = send_file_full(path,request,response,@cfg["storage_format"])
              
            #Log xfer..
            @logger.log_xfer(request,response,size, Time.now-start_tm)
            
        rescue => excpt
            ###
            # Ok, something very bad happend here... what to do..
            
            # send out "broken" image
            send_file_full(@cfg["error"]["img"],request,response,@cfg["error"]["format"])
               
               
            # send out broken email..
            stuff = "Broken at #{Time.now.to_s}"
            stuff += "--------------------------\n"
            stuff += excpt.to_s + "\n"
            stuff += "--------------------------\n"
            stuff += excpt.backtrace.join("\n")
            stuff += "--------------------------\n"
            stuff += "request => " + YAML.dump(request)+ "\n-------\n"
            Mailer.deliver_message(@cfg["mailer_config"], @cfg["mailer_config"]["to"], "shiv crash..", [stuff])
            @logger.logerr("Crash in::#{@lt}" + stuff)
        end
    end
end
  
  
###
# Handels google earth like tile requests, or more acurately, tile requests based off of lat/long requests rather than explicit tile numberings..
# Reguests are like /tag/bbox/minx/miny/maxx/maxy
  
class BBoxTileHandler < MongrelWelder
    def initialize (cfg, log, http_cfg)
	@logger = log
	@cfg = cfg
	@http_cfg = http_cfg
	@url_root = http_cfg["base"]
	@tile_engine =  Imlib2TileEngine.new(cfg, log)
	@lt = self.class.to_s + ":"
	@logger.loginfo(@lt+"Starting")
    end
   
   def process(request, response)
       
    begin
       
	mn = "process:"
	  
	@logger.loginfo(@lt+mn + "hit -> #{request.params[@REMOTE_IP_TAG]} -> #{request.params["REQUEST_URI"]}")
	
	
	# Log access...
	@logger.log_access(request)
	
	##
	# get start time, for tracking purposes..
	start_tm = Time.now
	
	##
	#Remove prefix from url..
	uri = request.params["REQUEST_URI"]
	uri = uri[@url_root.length,uri.length] if ( uri[0,@url_root.length] == @url_root)
	uri = uri.split("/")
	
	#validate url..
	# Url should be of the form "(0)/token(1)/bbox(2)/minx(3)/miny(4)/maxx(5)/maxy(6)"
	# Example:
	#"/drg_geo/bbox/-150.46875000000000000000/66.44531250000000000000/-149.76562500000000000000/66.79687500000000000000"
	if (uri.length != 7 || uri[2].downcase != "bbox")
	    @logger.logerr("Bad uri '#{request.params["REQUEST_URI"]} from #{request.params[@REMOTE_IP_TAG]}")
		response.start(404) do |head,out|
		head["Content-Type"] = "text/plain"
		out.write("The uri, #{request.params["REQUEST_URI"]}, is not good.\n")
		0.upto(uri.length-1) do |index|
		    out.write("{[#{index}]=>[#{uri[index]}]}")
		end
		out.write("URI length is #{uri.length}")
		out.write("Sadness...\n")
	    end
	    return;
	end
	
	##
	# Uri is good, so do something...
       
	x,y,z =  @tile_engine.min_max_to_xyz( uri[3].to_f, uri[4].to_f, uri[5].to_f, uri[6].to_f)
	
	path = @tile_engine.get_tile(x,y,z)
	
	# Wait for it to show up..
        @tile_engine.check_and_wait(x,y,z)
        
	##
	# Do request..
	size = send_file_full(path,request,response)
	  
	#Log xfer..
	@logger.log_xfer(request,response,size, Time.now-start_tm)
    rescue => excpt
        ###
        # Ok, something very bad happend here... what to do..
        send_file_full(@cfg["error"]["img"],request,response,@cfg["error"]["format"])
               
        stuff = "Broken at #{Time.now.to_s}"
        stuff += "--------------------------\n"
        stuff += excpt.to_s + "\n"
        stuff += "--------------------------\n"
        stuff += excpt.backtrace.join("\n")
        stuff += "--------------------------\n"
        stuff += "request => " + YAML.dump(request)+ "\n-------\n"
        Mailer.deliver_message(@cfg["mailer_config"], @cfg["mailer_config"]["to"], "shiv crash..", [stuff])
        @logger.logerr("Crash in::#{@lt}" + stuff)
    end
   end
end
 
###
# Handler designed to show how fast a mongrel should go, doing only the basic amount of work to dump a file..
# Testing only...
 class BenchmarkHandler < MongrelWelder
   def initialize ( log)
      @logger = log
   end
   
   def process(request, response)
      
      @logger.puts("hit -> #{request.params[@REMOTE_IP_TAG]} -> #{request.params["REQUEST_URI"]}")
      start_tm = Time.now
      # Log access...
      @logger.log_access(request)
      
      ##
      # Do request..
      size = send_file_full("test_tile.jpg",request,response)
      
      #Log xfer..
      @logger.log_xfer(request,response,size, Time.now-start_tm)
   end
 
   private
      
 end
