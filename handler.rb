#!/usr/bin/env ruby
#
# Web serving related happyness... And it seems like tommarrow might not come...

##
# provides a way to mail errors etc..
require "mailer"

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
    
      ##
      # Taken from dir handler of mongrel, adapted to rack suitiblity.
      # Does not work right now - the Rack::File.new(req_path) logic is screwy
      #
      #  FIXME!!!
      #
      def send_file_full_rack(req_path, request, response,type="png", header_only=false)
	 stat = File.stat(req_path)

         # Set the last modified times as well and etag for all files
	 mtime = stat.mtime
         # Calculated the same as apache, not sure how well the works on win32
	 etag = ETAG_FORMAT % [mtime.to_i, stat.size, stat.ino]

         modified_since = request.env[HTTP_IF_MODIFIED_SINCE]
	 none_match = request.env[HTTP_IF_NONE_MATCH]

         # test to see if this is a conditional request, and test if
	 # the response would be identical to the last response
         same_response = case
                      when modified_since && !last_response_time = Time.httpdate(modified_since) rescue nil then false
                      when modified_since && last_response_time > Time.now                                  then false
                      when modified_since && mtime > last_response_time                                     then false
                      when none_match     && none_match == '*'                                              then false
                      when none_match     && !none_match.strip.split(/\s*,\s*/).include?(etag)              then false
                      else modified_since || none_match  # validation successful if we get this far and at least one of the header exists
                      end

	 header = response.header
         header[ETAG] = etag

	 if same_response
	    response.status = 304
	 else

	    # First we setup the headers and status then we do a very fast send on the socket directly

            # Support custom responses except 404, which is the default. A little awkward. 
	    response.status = 200 if response.status == 404
	    header[LAST_MODIFIED] = mtime.httpdate
   
	    header[CONTENT_TYPE] = type

   	    # send a status with out content length
   	    #response.send_status(stat.size)
	    #response.send_header
	    #response.send_file(req_path, stat.size < 16*1024 * 2)
	    response.body = Rack::File.new(req_path)
	    return stat.size
	 end
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
    # Send out a 404 error, used to give a simple/quick error to usr
    def give404(response, msg)
	give_X(response, 404, "plain/text", msg)
    end
    
    ###
    # Only tested with apache - not sure what lighttp /fooxxx http does
    # todo -> 
    def send_file_xsendfile(request, response,path, mime_type)
	
	#Calculate etag, not sure if needed, perhaps apache does this already
	stat = File.stat(path)
        # Set the last modified times as well and etag for all files
	mtime = stat.mtime
        # Calculated the same as apache, not sure how well the works on win32
	etag = ETAG_FORMAT % [mtime.to_i, stat.size, stat.ino]

        modified_since = request.env[HTTP_IF_MODIFIED_SINCE]
	none_match = request.env[HTTP_IF_NONE_MATCH]

         # test to see if this is a conditional request, and test if
	 # the response would be identical to the last response
	 # Not sure whats going on here - stole from mongrels dir handler, which probibly does everything correctly..
        same_response = case
                      when modified_since && !last_response_time = Time.httpdate(modified_since) rescue nil then false
                      when modified_since && last_response_time > Time.now                                  then false
                      when modified_since && mtime > last_response_time                                     then false
                      when none_match     && none_match == '*'                                              then false
                      when none_match     && !none_match.strip.split(/\s*,\s*/).include?(etag)              then false
                      else modified_since || none_match  # validation successful if we get this far and at least one of the header exists
                      end

	if same_response
	    response.status = 304
	else
	    #Status?
	    response.header[ETAG] = etag
	    response.header["X-Sendfile"] = path
	    response.headers[CONTENT_TYPE] = mime_type
	    response.headers[CONTENT_LENGTH] = "0"
	end
	 
	response.body = []
	
	return stat.size
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
	if (uri.length != 7 || uri[2].downcase != "bbox")
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


#########
# Esri REST style handler..
class ESRIRestTileHandler < RackWelder
    require "json"
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
	##
	# get start time, for tracking purposes..
	start_tm = Time.now
	
	# first check the style of request - if includes json, then probibly a getpoo request..
	#obvoulsy better checking is in order..
	if (request.env["REQUEST_URI"].include?("json") )
	    ##
	    # Do request..
	    give_X(response, 200, "text/plain", get_poo().to_json)
	    return
	end
	mn = "process:"
	  
	@logger.loginfo(@lt+mn + "hit -> #{request.env[@REMOTE_IP_TAG]} -> #{request.env["PATH_INFO"]}")
	
	
	# Log access...
	@logger.log_access(request)
	
	##
	#Remove prefix from url..
	uri = request.env["PATH_INFO"]
	uri = uri[@url_root.length,uri.length] if ( uri[0,@url_root.length] == @url_root)
	uri = uri.split("/")
	#url is like http://server.arcgisonline.com/ArcGIS/rest/services/ESRI_StreetMap_World_2D/MapServer/tile/0/0/1
	# of the form junk/z/y/x.format
	x = uri.last.split(".").first.to_i
	y = uri[-2].to_i
	z = uri[-3].to_i
	y = (2**(z))-y-1   #flip to esri style numbering..
	puts("URI -> #{request.env["PATH_INFO"]} -> #{x},#{y}, #{z}")
	
	
	if (z < 0|| y < 0 || z < 0)
	    @logger.logerr("Bad uri '#{request.env["PATH_INFO"]} from #{request.env[@REMOTE_IP_TAG]}")
	    give404(response, "The uri, #{request.env["PATH_INFO"]}, is not good.\n")
	    return;
	end
	
	##
	# Uri is good, so do something...
       
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
   
   
   private
   
    ###
    # Not sure what ersi calls the Mapserver/json requests, so I call it the "get_poo" request..
    # Anyway, this generates that information as a hash
   def get_poo()
       
    hsh_template = {"spatialReference"=>{"wkid"=>666},
	"mapName"=>"not known",
	"serviceDescription"=>
	    "Not known.",
	"singleFusedMapCache"=>true,
	"layers"=>
	 [{"subLayerIds"=>nil,
	   "name"=>"Not known.",
	   "parentLayerId"=>-1,
	   "id"=>0,
	   "defaultVisibility"=>true}],
	"copyrightText"=>"(c) someone",
	"fullExtent"=>
	 {"spatialReference"=>{"wkid"=>10},
	  "ymax"=>0.0,
	  "xmax"=>0.0,
	  "ymin"=>-10.0,
	  "xmin"=>-3.0},
	"units"=>"esriMeters",
	"tileInfo"=>
	 {"lods"=> [],
	  "spatialReference"=>{"wkid"=>102006},
	  "format"=>"PNG",
	  "compressionQuality"=>0,
	  "origin"=>{"x"=>-0.0, "y"=>0.0},
	  "dpi"=>96,
	  "rows"=>512,
	  "cols"=>512},
	"description"=>"Something should go here.  \n",
	"initialExtent"=>
	 {"spatialReference"=>{"wkid"=>10101},
	  "ymax"=>0.0,
	  "xmax"=>0.0,
	  "ymin"=>-10.0,
	  "xmin"=>-30.0},
	"documentInfo"=>
	 {"Category"=>"shiv",
	  "Subject"=>"shiv",
	  "Keywords"=>"shiv",
	  "Author"=>"shiv",
	  "Title"=>"",
	  "Comments"=>"shiv auto generated rest responce"}}


	#build resolutions
	#basic idea => res_multiplyer = extents/pixels
	extent_width = @cfg["base_extents"]["xmax"] - @cfg["base_extents"]["xmin"]
	tile_width = @cfg["tiles"]["x_size"]
	scale_magic_factor = (51673124.9999999/13671.875) #meters to whatever..
	0.upto(20) do |i|
	    res = extent_width/((2**i)*tile_width)
	    hsh_template["tileInfo"]["lods"] << { "resolution" => res, "scale" => res*scale_magic_factor, "level" => i}
	end
	
	#Set extents..
	hsh_template["initialExtent"]["spatialReference"]={"wkid"=>(@cfg["esri_rest"]["projection"]).to_i}
	hsh_template["initialExtent"]["xmin"] = @cfg["base_extents"]["xmin"]
	hsh_template["initialExtent"]["ymin"] = @cfg["base_extents"]["ymin"]
	hsh_template["initialExtent"]["xmax"] = @cfg["base_extents"]["xmax"]
	hsh_template["initialExtent"]["ymax"] = @cfg["base_extents"]["ymax"]
	
	hsh_template["fullExtent"] = hsh_template["initialExtent"].dup
	hsh_template["serviceDescription"]=
	hsh_template["spatialReference"] ={"wkid"=>(@cfg["esri_rest"]["projection"]).to_i}
	hsh_template["tileInfo"]["spatialReference"]={"wkid"=>(@cfg["esri_rest"]["projection"]).to_i}
	
	#Translate format types to esri like wonder wigets..
	hsh_template["tileInfo"]["format"]= case @cfg["storage_format"]
	    when "png"
		 "PNG"
	    when "jpg"
		"JPEG"
	    else "PNG"
	end
	
	#Translate compression values to something useful, though not sure what they are acutally used for... mystery magic i expect.
	hsh_template["tileInfo"]["compressionQuality"]= case @cfg["storage_format"]
	    when "png"
		0
	    when "jpg"
		70
	    else 0
	end
	
	#fill out random other fields.. fun, fun,fun.
	hsh_template["tileInfo"]["origin"]={"x"=>@cfg["base_extents"]["xmin"], "y"=> @cfg["base_extents"]["ymax"]}
	hsh_template["tileInfo"]["rows"]=@cfg["tiles"]["x_size"]
	hsh_template["tileInfo"]["cols"]=@cfg["tiles"]["y_size"]
	hsh_template["serviceDescription"] = @cfg["esri_rest"]["description"]
	hsh_template["mapName"] = @cfg["title"]
	hsh_template["layers"][0]["name"] = @cfg["title"]
	return hsh_template
  end
end
 
###
# Handler designed to show how fast a mongrel should go, doing only the basic amount of work to dump a file..
# Testing only...
 class BenchmarkHandler < RackWelder
   def initialize ( log)
      @logger = log
   end
   
   def process(request, response)
      
      @logger.puts("hit -> #{request.env[@REMOTE_IP_TAG]} -> #{request.env["PATH_INFO"]}")
      start_tm = Time.now
      # Log access...
      @logger.log_access(request)
      
      ##
      # Do request..
      size = send_file_full("/var/www/html/distro/test_file.jpg", request, response,"image/jpeg")
      
      #Log xfer..
      @logger.log_xfer(request,response,size, Time.now-start_tm)
   end
 
   private
      
 end
#For rack..
class BenchmarkHandlerRack < RackWelder
    def initialize ( )
	#djlsakjflaj
    end
    def process(request, response)
      #request["PATH_INFO"] = "test_file.jpg"
      #response.status = 200
      response.body = []
      response.header["X-Sendfile"] = "/var/www/html/distro/test_file.jpg"
      response.headers[CONTENT_TYPE] = "image/jpeg"
      response.headers[CONTENT_LENGTH] = "0"#File.size?("test_file.jpg").to_s
    end
end
