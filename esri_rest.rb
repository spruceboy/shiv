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
	@render=RenderEng.new()
    end
   
   def process(request, response)
       
    begin
	##
	# get start time, for tracking purposes..
	start_tm = Time.now
	
	params = request.params()
	pp params.keys
	
	# first check the style of request - if includes json, then probibly a getpoo request..
	#obvoulsy better checking is in order..
	if (params["f"] &&  params["f"]=="json")
	    ##
	    # Do request..
	    # Dig up parms..
	    if (params["callback"])
		give_X(response, 200, "text/plain", params["callback"] + "(" + get_poo().to_json + ");")
	    else
		give_X(response, 200, "text/plain", get_poo().to_json)
	    end
	    return
	end
	
	##
	# Now check to see if it is a "tile,export, or an index reqeust.." request..
	
	case(request.env["PATH_INFO"].split("/MapServer/")[1])
	    when "export" then
		give_301(response, get_export_url(params) )
		return
	    when nil then
		give_X(response, 200, "text/html",@render.render("esri_mapserver",@cfg))
		return
	end
	    
	##
	# Now should be a tile request..
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
	#Setup LODs..
	@cfg["esri_rest"]["LOD"].each { |i|  hsh_template["tileInfo"]["lods"] << i}

	hsh_template["documentInfo"] = @cfg["esri_rest"]["documentInfo"] if ( @cfg["esri_rest"]["documentInfo"] )
        hsh_template["copyrightText"] = @cfg["esri_rest"]["copyrightText"] if (  @cfg["esri_rest"]["copyrightText"] )
        hsh_template["description"] = @cfg["esri_rest"]["description"] if (  @cfg["esri_rest"]["description"] )
	
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
   
   def get_export_url(params)
	width,height = params["size"].split(",")
	bbox = params["bbox"]
	pp width
	pp height
	pp bbox
	url =sprintf(@cfg["esri_rest"]["export_url"], width, height, bbox)
	pp url
	return url
   end
end

##
# Serves up kml..
class ESRI_Service_Fooler < RackWelder
  
  #set stuff up, log=logger, cfg=shiv kml config.
  def initialize ( log,cfg)
    @logger = log
    
    #the ip of the requesting host..
    @REMOTE_IP_TAG="HTTP_X_FORWARDED_FOR"
    
    #save the config..
    @cfg = cfg
    
    #save the root url.
    @url_root = @cfg["root_url"]
  end
  
  
   # Do something..
  def process(request, response)
       begin
	##
	# get start time, for tracking purposes..
	start_tm = Time.now
	params = request.params()
        give_X(response, 200, "text/plain", "Something is coming to this page soon.")
	return
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


# Serves up kml..
class ESRI_Service_Fooler_Info < RackWelder

  #set stuff up, log=logger, cfg=shiv kml config.
  def initialize ( log,cfg)
    @logger = log

    #the ip of the requesting host..
    @REMOTE_IP_TAG="HTTP_X_FORWARDED_FOR"

    #save the config..
    @cfg = cfg

    #save the root url.
    @url_root = @cfg["root_url"]
  end


   # Do something..
  def process(request, response)
       begin
        ##
        # get start time, for tracking purposes..
        start_tm = Time.now
        params = request.params()
        give_X(response, 200, "text/plain", '{"currentVersion":10.04,"soapUrl":null,"secureSoapUrl":null,"authInfo":{"isTokenBasedSecurity":false}}')
        return
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

