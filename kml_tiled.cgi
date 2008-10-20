#!/usr/bin/ruby
require "pp"
require "cgi"
require "rubygems"
require "xmlsimple"
require 'yaml'


def url_to_lower_level(hcfg,set,tl_x, tl_y, br_x, br_y)
  STDERR.printf("url_to_lower_level(%g,%g) -> (%g,%g)\n", br_x.to_f, br_y.to_f, tl_x.to_f , tl_y.to_f) 
  return sprintf(hcfg["url"],set,tl_x, tl_y, br_x, br_y)
end

def url_to_img(hcfg,set,tl_x, tl_y, br_x, br_y)
  STDERR.printf("url_to_lower_level(%g,%g) -> (%g,%g)\n", br_x.to_f, br_y.to_f, tl_x.to_f , tl_y.to_f)
  if ( (br_x - tl_x) > 45)
    return sprintf(hcfg["source_low"],tl_x, br_y, br_x, tl_y)
  else
    return sprintf(hcfg["source"],tl_x, br_y, br_x, tl_y)
  end
end

def hshtoLatLonAltBox ( cfg,set,tl_x, tl_y, br_x, br_y , note)

  maxlodpixels = -1
  #maxlodpixels = 680
  #maxlodpixels = -1 if ((  br_x - tl_x   > 5 ))
  STDERR.printf("((br_x - tl_x))=>%g (%s)\n",(br_x - tl_x), note )
  
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


def do_level (cfg,set,tl_x, tl_y, br_x, br_y)
  
  w = br_x -  tl_x
  h = tl_y -  br_y
  w = w / 2.0
  h = h / 2.0
  STDERR.printf("w=>%g\n",w )
  STDERR.printf("h=>%g\n",h)
  
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
 
=begin
      
        #x0/00
        children << do_file( cfg, path, x,      y,      level+1,        tl,     {"x"=>(tl["x"]+w ) , "y"=>(tl["y"]-h )} )
        #0x/00
        children << do_file( cfg, path, x+1,    y,      level+1,        {"x"=>(tl["x"]+w ) , "y"=>(tl["y"])}, {"x"=>(br["x"]) , "y"=>(tl["y"]-h)} )
        #00/x0
        children << do_file( cfg, path, x, y+1, level+1,        {"x"=>(tl["x"]) , "y"=>(br["y"]+h)}, {"x"=>(br["x"]-w) , "y"=>(br["y"])} )
        #00/0x
        children << do_file( cfg, path, x+1,    y+1,    level+1,        {"x"=>(tl["x"]+w) , "y"=>(br["y"]+h)}, br )
=end
	
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
    #File.open(cfg["basename"]+".kml", "w") { |x| x.write XmlSimple.xml_out(hsh,  { "rootname" => 'kml'}) }
    #cfg["children"].each{|z| do_level(z) }  if ( cfg["children"] && cfg["children"] != nil )
    #pp CobraVsMongoose.hash_to_xml(hsh)
end


begin
  cgi = CGI.new("application/vnd.google-earth.kml+xml")
  tl_x = cgi["tl_x"]
  tl_y = cgi["tl_y"]
  br_x = cgi["br_x"]
  br_y = cgi["br_y"]
  set = cgi["set"]
  if ( br_x == nil || br_y == nil || tl_x == nil|| tl_y == nil||set==nil)
        br_x = "180.0"
        br_y = "-90"
        tl_x = "-180.0"
        tl_y = "90"
        set = "bdl"
  end
  
  STDERR.printf("(%g,%g) -> (%g,%g)\n", br_x.to_f, br_y.to_f, tl_x.to_f , tl_y.to_f)

  
  #cfg = YAML.load(File.open("/www/wms/apps/kml/kml.yml"))
  cfg = File.open("/var/www/apps/kml/kml_new.yml") {|x| YAML.load(x)}
  stuff = do_level(cfg[set],set,tl_x.to_f, tl_y.to_f, br_x.to_f, br_y.to_f)
  cgi.out(options= "application/vnd.google-earth.kml+xml") do
      stuff
  end
rescue => e
  puts e.to_s
  puts e.backtrace
  puts "An error occured... bummer.."
end

