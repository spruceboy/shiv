#
# Web serving related happyness... And it seems like tommarrow might not come...

##
# provides a way to mail errors etc..
require "mailer"
require "cgi"
require "time"

#************************************************************************************************


##
# Base class, don't instatuate, use sub-classes..

class RackWelder
    
    # constants for headers.  Rack should have these, perhaps it does and I am stupid.
    ETAG_FORMAT="\"%x-%x-%x\""
    HTTP_IF_MODIFIED_SINCE="HTTP_IF_MODIFIED_SINCE"
    HTTP_IF_NONE_MATCH="HTTP_IF_NONE_MATCH"
    ETAG  = "ETag"
    CONTENT_TYPE = "Content-Type"
    CONTENT_LENGTH = "Content-Length"
    LAST_MODIFIED = "Last-Modified"
    
    
    
    ##
    # Stub to be used for driving directly by rack, mainly for testing. Not for real use.
    def call(env)
	request = Rack::Request.new(env)
	response = Rack::Response.new
	process(request, response)
	[response.status, response.headers, response.body]
    end

    private
    
	##
	# Sends out a file on disk - switchs between actual file sending and handoff file sending, depending on usage.
    def send_file_full(req_path, request, response,mime_type="image/png", header_only=false )
	return send_file_xsendfile(request, response,req_path, mime_type)
    end
    
    ###
    # General purpose out to http function..
    def give_X(response, status, mime_type, msg)
	headers = response.headers
	response.status =status
	response.body = [msg]
	response.headers["Content-Type"] = mime_type
	response.headers[CONTENT_LENGTH] = response.body.join.length.to_s
    end
    
    ###
    # General purpose out to http function..
    def give_301(response, url)
	headers = response.headers
	response.status = 301
	response.headers["Location"] =url
    end
    
    ###
    # Send out a 404 error, used to give a simple/quick error to usr
    def give404(response, msg)
	give_X(response, 404, "plain/text", msg)
    end
    
    def send_file_full(req_path, request, response,mime_type="image/png", header_only=false )
	return send_file_xsendfile(request, response,req_path, mime_type)
    end
    
    def send_file_xsendfile(request, response,path, mime_type)
        response.body = ShivFile.new(path)
        response.headers[CONTENT_TYPE] = mime_type
	#response.headers["Expires"] = (Time.now+10*60).httpdate
    end
end


class ShivFile
    def initialize (path)
	@path = path
    end
    
    def to_path
	@path
    end

    def each 
	#do nothing.
    end
end



#************************************************************************************************

##
# Simplest Handler of them all...  Not sure if used or not


#************************************************************************************************

##
# Simplest Handler of them all...  Not sure if used or not
# For mongrel
class SimpleHandler < RackWelder 
    def initialize ( log)
      @logger = log
      @REMOTE_IP_TAG="HTTP_X_FORWARDED_FOR"
    end
    def process(request, response)
      @logger.puts("hit -> #{request.env[@REMOTE_IP_TAG]} -> #{request.env["PATH_INFO"]}")
      give_X(response, 200, "text/plain", "Hello #{request.env[@REMOTE_IP_TAG]}.")
    end
end

#************************************************************************************************
##
# Exit Handler - quits when hit...  needs more safety!

class ExitHandler < RackWelder 
    def initialize ( log)
      @logger = log
      @REMOTE_IP_TAG="HTTP_X_FORWARDED_FOR"
    end
    def process(request, response)
      @logger.puts("Got Exit request -> #{request.env[@REMOTE_IP_TAG]} -> #{request.env["PATH_INFO"]}")
      exit(-1)
    end
end
#************************************************************************************************
 
###
# Tile Handler - does google map like requests..
# Handles google maps like tile requests, of the form /tag/tiles/x/y/z
class TileHandler < RackWelder
    
    def initialize (cfg, log, http_cfg)
        
        #save stuff for later
	@logger = log
	@cfg = cfg
	@url_root = http_cfg["base"]    #/tag/
	@http_cfg = http_cfg
	#@tile_engine =  Imlib2TileEngine.new(cfg, log)   #Use the imlib2 engine..
	@tile_engine =  ExternalTileEngine.new(cfg, log)   #Use the external tile engine..
	
	@lt = self.class.to_s + ":"
	@logger.loginfo(@lt+"Starting")
	@REMOTE_IP_TAG="HTTP_X_FORWARDED_FOR"
    end
   
   #Handle a request
    def process(request, response)
        begin
            
            mn = "process:"  #name of this method.. used for logging..
            
            #log request
            @logger.loginfo(@lt+mn + "hit -> #{request.env[@REMOTE_IP_TAG]} -> #{request.env["PATH_INFO"]}")
            
            #time of start..
            start_tm = Time.now
             
            # Log access...
            @logger.log_access(request)
            
            ##
            #Remove prefix from url..
            uri = request.env["PATH_INFO"]
            give404(response, "Try a real url, thats not nil.") if ( uri == nil)
            uri = uri[@url_root.length,uri.length] if ( uri[0,@url_root.length] == @url_root)
            give404(response, "Try a real url, perhaps one that is valid.") if ( uri == "")
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
                    @logger.logerr("Bad uri '#{request.env["PATH_INFO"]} from #{request.env[@REMOTE_IP_TAG]}")
                    give404(response, "The uri, #{request.env["PATH_INFO"]}, is not good.\n")
                end
                return		# Done with no-tile related stuff...
            end
              
            x = uri[3].to_i
            y = uri[4].to_i
            z = uri[5].to_i
            
            ##
            # Flip... go from jays tile scheme to googles..
            y = 2**z-y-1

	    ##
	    # deal with negitive x values..
	    x = (x % (2**z)) if (x < 0)

            if (x > (2**(z+1)) || y > (2**(z+1) ) || z > 24 )
                 @logger.logerr("Bad uri '#{request.env["PATH_INFO"]} from #{request.env[@REMOTE_IP_TAG]}")
                 give404(response, "The uri, #{request.env["PATH_INFO"]}, is not good.\n")
                 return
            end
            


            # Call get tile..
            path = @tile_engine.get_tile(x,y,z)
           
          # Wait for it to show up..
          @tile_engine.check_and_wait(x,y,z)
              
            	##
            	# Do request..
		if  @tile_engine.alt_tile?(x,y,z,request)
			give_X(response, 200 ,@cfg["storage_format"], @tile_engine.get_alt_tile(x,y,z))
		else
	
            		size = send_file_full(path,request,response,@cfg["storage_format"])
		end
              
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
  
class BBoxTileHandler < RackWelder
    def initialize (cfg, log, http_cfg)
	@logger = log
	@cfg = cfg
	@http_cfg = http_cfg
	@url_root = http_cfg["base"]
	#@tile_engine =  Imlib2TileEngine.new(cfg, log)
	@tile_engine =  ExternalTileEngine.new(cfg, log)   #Use the external tile engine..
	@lt = self.class.to_s + ":"
	@logger.loginfo(@lt+"Starting")
    end
   
   def process(request, response)
       
    begin
       
	mn = "process:"
	  
	@logger.loginfo(@lt+mn + "hit -> #{request.env[@REMOTE_IP_TAG]} -> #{request.env["PATH_INFO"]}")
	
	
	# Log access...
	@logger.log_access(request)
	
	##
	# get start time, for tracking purposes..
	start_tm = Time.now
	
	##
	#Remove prefix from url..
	uri = request.env["PATH_INFO"]
	uri = uri[@url_root.length,uri.length] if ( uri[0,@url_root.length] == @url_root)
	uri = uri.split("/")
	
	#validate url..
	# Url should be of the form "(0)/token(1)/bbox(2)/minx(3)/miny(4)/maxx(5)/maxy(6)"
	# Example:
	#"/drg_geo/bbox/-150.46875000000000000000/66.44531250000000000000/-149.76562500000000000000/66.79687500000000000000"
	if (uri.length != 7 && uri.length != 8 || uri[2].downcase != "bbox")
	    @logger.logerr("Bad uri '#{request.env["PATH_INFO"]} from #{request.env[@REMOTE_IP_TAG]}")
	    give404(response, "The uri, #{request.env["PATH_INFO"]}, is not good.\n")
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
# Testing only... image path should be configureable. 
 class BenchmarkHandler < RackWelder
   def initialize ( log)
      @logger = log
      @test_file = '/hub/cache/test/test_file.jpg'
      @test_file_size = File.size(@test_file)
   end
   
   def process(request, response)
      @logger.puts("hit -> #{request.env[@REMOTE_IP_TAG]} -> #{request.env["PATH_INFO"]}")
      start_tm = Time.now
      # Log access...
      @logger.log_access(request)
       size = send_file_full(@test_file,request, response,"image/jpeg")
   end
   private
      
 end

# tile json widget..
class TileJson < RackWelder

  require "json"
  #set stuff up, log=logger, cfg=shiv kml config.
  def initialize (cfg, log,http_conf)
    @logger = log

    #the ip of the requesting host..
    @REMOTE_IP_TAG="HTTP_X_FORWARDED_FOR"

    #save the config..
    @cfg = cfg
  end


   # Do something..
  def process(request, response)
    begin
	params = request.params()

	if (params["callback"])
		give_X(response, 200, "text/plain", params["callback"] + "(" + get_tile_json + ");")
	else
        	give_X(response, 200, "text/plain", get_tile_json())
	end

        return
    rescue => excpt
        ###
        # Ok, something very bad happend here... what to do..
        give_X(response, 500, "text/plain", "Something is broken, this is bad. Email support@gina.alaska.edu if problems continue.")

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


  def get_tile_json ()
	resp = {
    		"tilejson"=> "2.1.0",
    		"name"=> @cfg["title"],
    		"description"=> "TBD.",
    		"attribution"=> "TBD.",
    		"scheme"=> "xyz",

    		"tiles"=> [
        		"/tiles/#{@cfg["title"]}/tile/{x}/{y}/{z}"
    		],
    		"minzoom"=> 0,
    		"maxzoom"=> 22,
	}

	
	##
	# Should expand this a bit, put info in a "combined location"
	if ( @cfg["esri_rest"] )
		resp["description"] = @cfg["esri_rest"]["description"] if ( @cfg["esri_rest"]["description"] )
		resp["attribution"] = @cfg["esri_rest"]["copyrightText"] if (  @cfg["esri_rest"]["copyrightText"] )
	end

	return (resp.to_json)
  end

end
