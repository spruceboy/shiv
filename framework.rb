#!/usr/bin/env ruby

require "shiv_includes"
require "pp"



########################
# Very small framework for shiv, only
# this was the starting point: http://theexciter.com/files/cabinet.rb.txt , but only a rough one

## Error generating stub class... silly
class HttpError < RackWelder
  def initialize ( request, response, status, msg, mime_type="plain/text")
    response.status =status
    response.body = [msg]
    response.headers["Content-Type"] = mime_type
    response.headers[CONTENT_LENGTH] = response.body.join.length.to_s
  end
end

## Passes requests off to the relevent handlers
class Roundhouse
    def initialize(cfg )
      @routes = {}
      #get a logger..
      # log to specified dir
      @logger = TileLumber.new(cfg["log"])
      @logger.logstatus("Starting.")
      
      #mount up the /benchmark area..
      reg( cfg["http"]["base"] + "/benchmark", BenchmarkHandler.new(@logger))
      
      #mount up the /exit area..
      # Decide what to do here..
      #reg( cfg["http"]["base"] + "/magic/exit", ExitHandler.new(logger))
      
      
      #loop though the tile engines in the config file, and fire up and mount each..
      cfg["tile_engines"].each do |tcfg|
         path = cfg["http"]["base"] + "/" + tcfg["title"] + "/tile/"
         @logger.msginfo("Main:Setting up '#{path}''")
         reg(path, TileHandler.new(tcfg, @logger, cfg["http"]))
         path = cfg["http"]["base"] + "/" + tcfg["title"] + "/bbox/"
         @logger.msginfo("Main:Setting up '#{path}''")
         reg(path, BBoxTileHandler.new(tcfg, @logger, cfg["http"]))
         path = cfg["http"]["base"] + "/ArcGIS/rest/services/" + tcfg["title"] + "/MapServer/"
         @logger.msginfo("Main:Setting up '#{path}''")
         reg(path, ESRIRestTileHandler.new(tcfg, @logger, cfg["http"]))
      end
      reg(cfg["http"]["base"] + "/" + "kml", KMLHandler.new(@logger, cfg["kml"]))
      
      @logger.logstatus("Up.")
    end
    
    #Rack entry point..
    def call(env)
	request = Rack::Request.new(env)
	response = Rack::Response.new
	handler = route(env["PATH_INFO"])
	if (!handler)
          HttpError.new(request, response, 404, "Lost?")
	else
          sz = handler.process(request, response)
        end
	[response.status, response.headers, response.body]
    end
    
    private
    
    def reg(stock_url, handler)
      url=stock_url.split(/\/+/).join("/")
      @logger.msginfo("Mounting up #{url} with #{handler.class.to_s}")
      @routes[url] = {"handler"=>handler,"path_length" => url.length}
    end
    
    def route(stock_url)
      url=stock_url.split(/\/+/).join("/")
      @routes.keys.each do |x|
        #@logger.msginfo("Main:route:Looking at '#{url}' (#{url[0,@routes[x]['path_length']]}) for '#{x}'")
        if (x == url[0,@routes[x]["path_length"]])
          #@logger.msginfo("Main:route: #{@routes[x]["handler"].class.to_s} will do '#{url}'")
          return @routes[x]["handler"]
        end
      end
      return nil   #Bad, nothing matched
    end
    
end

