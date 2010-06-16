require "yaml"

template = File.open("snap.template.yml"){|fd| YAML.load(fd) }

ARGV.each do |x|
	url = "http://hippy.gina.alaska.edu/snap/example_wms_google?layers=#{x}&styles=&service=WMS&width=%d&format=image/png&request=GetMap&height=%d&srs=EPSG:900913&version=1.1.1&bbox=%6.10f,%6.10f,%6.10f,%6.10f"
 	cfg  = template.dup
	cfg["source_url"] = url
	cfg["title"] = x
	cfg["cache_dir"] =  "/hub/cache/production/speedy/" + x + "/"

	File.open(x+".conf.yml", "w") {|fd| YAML.dump(cfg, fd)}
end
