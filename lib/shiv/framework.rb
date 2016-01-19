#!/usr/bin/env ruby

require 'shiv_includes'
require 'pp'

########################
# Very small framework for shiv, only
# this was the starting point: http://theexciter.com/files/cabinet.rb.txt , but only a rough one

## Error generating stub class... silly
class HttpError < RackWelder
  def initialize(_request, response, status, msg, mime_type = 'plain/text')
    response.status = status
    response.body = [msg]
    response.headers['Content-Type'] = mime_type
    response.headers[CONTENT_LENGTH] = response.body.join.length.to_s
  end
end

## Passes requests off to the relevent handlers
class Roundhouse
  def initialize(cfg)
    load(cfg)
  end

  ##
  # Loads/reloads a config set..
  def load(cfg)
    @cfg = cfg
    @routes = {}
    # get a logger..
    # log to specified dir
    @logger = TileLumber.new(cfg['log'])
    @logger.logstatus('Starting.')

    # mount up the /benchmark area..
    reg(cfg['http']['base'] + '/benchmark', BenchmarkHandler.new(@logger))

    path = cfg['http']['base'] + cfg['controller']['base_url']
    @logger.msginfo("Main:Setting up the controller at '#{path}''")
    reg(path, ControllerHandler.new(@logger, cfg, self))

    # loop though the tile engines in the config file, and fire up and mount each..
    configs(cfg) do |tcfg|
      path = cfg['http']['base'] + '/' + tcfg['title'] + '/tile/'
      @logger.msginfo("Main:Setting up '#{path}''")
      reg(path, TileHandler.new(tcfg, @logger, cfg['http']))
      path = cfg['http']['base'] + '/' + tcfg['title'] + '/bbox/'
      @logger.msginfo("Main:Setting up '#{path}''")
      reg(path, BBoxTileHandler.new(tcfg, @logger, cfg['http']))
      path = cfg['http']['base'] + '/ArcGIS/rest/services/' + tcfg['title'] + '/MapServer/'
      @logger.msginfo("Main:Setting up '#{path}''")
      reg(path, ESRIRestTileHandler.new(tcfg, @logger, cfg['http']))
      if  tcfg['kml']
        path = cfg['http']['base'] + '/' + tcfg['title'] + '/kml/'
        reg(path, KMLHandler.new(@logger, cfg['http'], tcfg['title']))
      end
    end

    ##
    # ESRI TOC serving gadget..
    reg(cfg['http']['base'] + '/ArcGIS/rest/services', ESRI_Service_Fooler.new(@logger, cfg['esri']))
    reg(cfg['http']['base'] + '/ArcGIS/rest/info', ESRI_Service_Fooler_Info.new(@logger, cfg['esri']))
    @logger.logstatus('Up.')
  end

  # Rack entry point..
  def call(env)
    request = Rack::Request.new(env)
    response = Rack::Response.new
    handler = route(env['PATH_INFO'])
    if !handler
      HttpError.new(request, response, 404, 'Lost?')
    else
      sz = handler.process(request, response)
        end
    [response.status, response.headers, response.body]
  end

  private

  ##
  # have stock_url be handled by handler
  def reg(stock_url, handler)
    url = stock_url.split(/\/+/).join('/')
    @logger.msginfo("Mounting up #{url} with #{handler.class}")
    @routes[url] = { 'handler' => handler, 'path_length' => url.length }
  end

  ##
  # Takes a url and has it handed by the reg(istered) handler.
  def route(stock_url)
    url = stock_url.split(/\/+/).join('/')
    @routes.keys.each do |x|
      # @logger.msginfo("Main:route:Looking at '#{url}' (#{url[0,@routes[x]['path_length']]}) for '#{x}'")
      if x == url[0, @routes[x]['path_length']]
        # @logger.msginfo("Main:route: #{@routes[x]["handler"].class.to_s} will do '#{url}'")
        return @routes[x]['handler']
      end
    end
    nil # Bad, nothing matched
  end

  ##
  # Loops though config dir, setting up each config..
  def configs(cfg)
    Dir.glob(cfg['tile_engines']['conf_dir'] + '/*.conf.yml').each do |item|
      engine_cfg = File.open(item) { |fd| YAML.load(fd) }
      engine_cfg['mailer_config'] = cfg['tile_engines']['mailer_config']
      engine_cfg['config_path'] = item
      # load esri config stuff..
      if engine_cfg['esri_config']
        engine_cfg['esri'] = File.open(File.dirname(item) + '/' + engine_cfg['esri_config']) { |fd| XmlSimple.xml_in(fd.read) }
      end
      yield engine_cfg
    end
  end
end
