#########
# Central controller and status

#########
# Base class for controller bits.


class ControlPanelBase < RackWelder
  #set stuff up, log=logger, cfg=shiv kml config.
  def initialize ( log,cfg, list)
    @logger = log
    
    #save the config..
    @cfg = cfg
    
    #save the tilers items
    @list = list
    
    #save the root url.
    @url_root = @cfg["root_url"]
    
    @render=RenderEng.new()
  end
  
  
  private
  
  #handles errors - override error_msg to add a different msg
  def handle_error(excpt, request, response)
    ###
    # Ok, something very bad happend here... what to do..
    #send_file_full(@cfg["error"]["img"],request,response,@cfg["error"]["format"])
    error_msg(response,"A problem has occured..")
	   
    stuff = "Broken at #{Time.now.to_s}"
    stuff += "--------------------------\n"
    stuff += excpt.to_s + "\n"
    stuff += "--------------------------\n"
    stuff += excpt.backtrace.join("\n")
    stuff += "--------------------------\n"
    stuff += "request => " + YAML.dump(request)+ "\n-------\n"
    Mailer.deliver_message(@cfg["tile_engines"]["mailer_config"], @cfg["tile_engines"]["mailer_config"]["to"], "shiv crash..", [stuff])
    @logger.logerr("Crash in::#{@lt}" + stuff)
  end

  def error_msg(response, msg)
    give_X(response, 500, "text/plain",msg)
  end
  
  def remove_root(path)
    path[ @cfg["http"]["base"].length, path.length]
  end
  
  def path_to_chunks(path)
    bits = remove_root(path).split(/\/+/)
    bits.delete_at(0)
    bits
  end
  
  def get_tile_config(item)
    @list.each {|x| return x if (item == x["title"])}
  end
  
  def get_tile_layout(item)
    cfg = get_tile_config(item)
    return "map_layout" if (!cfg["view"] || !cfg["view"]["layout"])
    return cfg["view"]["layout"]
  end
  
end



#ControlPanel
#handles ->
# / -> give index
# /info/tileset -> simple info page
# /map/tileset -> simple interactive map

class ControlPanel < ControlPanelBase
  #set stuff up, log=logger, cfg=shiv kml config.
  def initialize ( log,cfg, list)
    super(log,cfg,list)
  end
  
   # Do something..
  def process(request, response)
       begin
	path = path_to_chunks(request.path)
	puts path.join(":")
	case path.first
	    when nil;give_X(response, 200, "text/html",@render.render("index", @list, "index_layout") )
	    when "info";
		if ( path[1] == nil )
			give_X(response, 404, "text/html","Bad URL.")
		else
			give_X(response, 200, "text/html",@render.render("info", get_tile_config(path[1])))
		end
	    when "map";give_X(response, 200, "text/html",@render.render("map", get_tile_config(path[1]), get_tile_layout(path[1])))
	    else error_msg(response, "Got nothing..")
	end
	return
    rescue => excpt
	handle_error(excpt, request,response)
    end
  end
end

