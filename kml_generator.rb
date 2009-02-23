#!/usr/local/bin/ruby
require "pp"
require "cgi"
require "rubygems"
require "xmlsimple"
require 'yaml'



class KMLHandler < RackWelder
  
  def initialize ( log,cfg)
    @logger = log
    @REMOTE_IP_TAG="HTTP_X_FORWARDED_FOR"
    @cfg = cfg
    @url_root = @cfg["root_url"]
  end
  
  
  # Do something..
  def process(request, response)
    begin
      @logger.puts("KML -> #{request.params[@REMOTE_IP_TAG]} -> #{request.params["REQUEST_URI"]}")
     
      uri = request.env["PATH_INFO"]
      if ( uri == nil)
        give404(response, "Try a real url, thats not nil.")
        return
      else
        uri = uri[@url_root.length,uri.length] if ( uri[0,@url_root.length] == @url_root)
        puts uri
        
        # uri once cleaned up, shoudl not be empty..
        if ( uri == "")
          give404(response, "Try a real url, perhaps one that is valid.")
          return
        end
        
        #uri should be for the form /set/lt_x/tl_y/br_x/br_y
        uri = uri.split("/")
        
        if ( uri.length != 5 )
          give404(response, "Try a real url, perhaps one that is valid and of the form /set/lt_x/tl_y/br_x/br_y") if ( uri.length != 5 )
          return
        end
        
        set = uri[0]
        tl_x = uri[1].to_f
        tl_y = uri[2].to_f
        br_x = uri[3].to_f
        br_y = uri[4].to_f
        
        ##
        # This is the case if things are really broken - possibly not possible now..
        # Not sure if the behavior is good, or bad -  should possibly just generate an error now..
        if ( br_x == nil || br_y == nil || tl_x == nil|| tl_y == nil||set==nil)
            br_x = "180.0"
            br_y = "-90"
            tl_x = "-180.0"
            tl_y = "90"
            set = "bdl"
        end
        
        response.status = 200
        response.header["Content-Type"] = "application/vnd.google-earth.kml+xml"
        @logger.msgdebug("KMLHandler:process:"+ sprintf("(%g,%g) -> (%g,%g)", br_x.to_f, br_y.to_f, tl_x.to_f , tl_y.to_f))
        stuff = do_level(@cfg["sets"][set],set,tl_x.to_f, tl_y.to_f, br_x.to_f, br_y.to_f)
        response.write(stuff)
      end
    rescue => excpt
      ###
      # Ok, something very bad happend here... what to do..
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
  
  
  #generates a url to the new down level 
  def url_to_lower_level(hcfg,set,tl_x, tl_y, br_x, br_y)
    @logger.msgdebug("KMLHandler:url_to_lower_level:"+sprintf("url_to_lower_level(%g,%g) -> (%g,%g)", br_x.to_f, br_y.to_f, tl_x.to_f , tl_y.to_f) )
    return sprintf(hcfg["url"],set,tl_x, tl_y, br_x, br_y)
  end

  #url to actual image..
  def url_to_img(hcfg,set,tl_x, tl_y, br_x, br_y)
    @logger.msgdebug("KMLHandler:url_to_img:"+ sprintf("url_to_lower_level(%g,%g) -> (%g,%g)", br_x.to_f, br_y.to_f, tl_x.to_f , tl_y.to_f) )
    return sprintf(hcfg["source"],tl_x, br_y, br_x, tl_y)
  end
  
  
  # Generates a bounding box google kml style
  
  def hshtoLatLonAltBox ( cfg,set,tl_x, tl_y, br_x, br_y , note)
    maxlodpixels = -1
    @logger.msgdebug("KMLHandler:hshtoLatLonAltBox:" + sprintf("((br_x - tl_x))=>%g (%s)",(br_x - tl_x), note ))
    
    #Old Lod
    #  "Lod"=>[ {"maxLodPixels"=>["#{maxlodpixels}"], "minLodPixels"=>["128"],  "minFadeExtent"=>["128"],  "maxFadeExtent"=>["128"]}],
    return {
         "name"=>[sprintf("%s_%.20f_%.20f_%.20f_%.20f%", set,tl_x, tl_y, br_x, br_y) ],
        "Region"=>
          [
            {
              "Lod"=>[ {"maxLodPixels"=>["#{maxlodpixels}"], "minLodPixels"=>["180"]}],
              "LatLonAltBox"=>
                [{
                  "east"=>["#{br_x}"],
                  "south"=>["#{br_y}"],
                  "west"=>["#{tl_x}"],
                  "north"=>["#{tl_y}"]
                }]
            }
          ],
        "Link"=>
          [{
            "href"=>[url_to_lower_level(cfg,set,tl_x, tl_y, br_x, br_y)],
            "viewRefreshMode"=>["onRegion"],
            "viewFormat"=>[{}]
          }]
    } 
  end
  
  
  #generates a kml file for tl,br
  def do_level (cfg,set,tl_x, tl_y, br_x, br_y)
    
    w = br_x -  tl_x
    h = tl_y -  br_y
    w = w / 2.0
    h = h / 2.0
    
    maxlodpixels = -1
    #maxlodpixels = 680
    #maxlodpixels = -1 if ((  br_x - tl_x   > 5 ))
    
    networklink = []
    
    ##
    # Zoom level 24 is the limit...
    
    if ( w > 360.0/(2**20))
        0.upto(1) do |x|
          0.upto(1) do |y|
              networklink += [hshtoLatLonAltBox(cfg,set,tl_x+w*x,     br_y+h*(y+1),    tl_x+w*(x+1),     br_y+h*(y),    "tl")]
          end
      end
     end
 
#Draw order stuff..
# "drawOrder"=>["#{((1.0/w)*180).to_i}"]
    hsh = {"Document"=>
  	[
            {
                "name"=>[sprintf("%s_%.20f_%.20f_%.20f_%.20f%", set,tl_x, tl_y, br_x, br_y) ],
                "NetworkLink"=> networklink,
    		"GroundOverlay"=>
                    [
                        {
                            "LatLonBox"=>
                            [
                                {
                                    "east"=>["#{br_x}"],
                                    "south"=>["#{br_y}"],
                                    "west"=>["#{tl_x}"],
                                    "north"=>["#{tl_y}"]
				}
                            ],
                            "Icon"=>[
                                        {
                                                "href"=>["#{url_to_img(cfg,set,tl_x, tl_y, br_x, br_y)}"]
                                        }
                                    ],
                            "drawOrder"=>["#{((1.0/w)*180).to_i}"]
			}
		    ],
                "Region"=>
     		    [
                        {
                            "Lod"=>[ {"maxLodPixels"=>["#{maxlodpixels}"], "minLodPixels"=>["180"]}],
                            "LatLonAltBox"=>
                                [{
                                    "east"=>["#{br_x}"],
                                    "south"=>["#{br_y}"],
                                    "west"=>["#{tl_x}"],
                                    "north"=>["#{tl_y}"]
                                }]
                        }
                    ]
            }
	],
 	"xmlns"=>"http://earth.google.com/kml/2.1"
    }


    return (XmlSimple.xml_out(hsh,  { "rootname" => 'kml'})  )
  end
end