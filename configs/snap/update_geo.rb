require "yaml"

template = File.open("snap.template.geo.yml"){|fd| YAML.load(fd) }

ARGV.each do |x|
	url = "http://hippy.gina.alaska.edu/snap/example_wms?layers=#{x}&styles=&service=WMS&width=%d&format=image/png&request=GetMap&height=%d&srs=EPSG:4326&version=1.1.1&bbox=%6.10f,%6.10f,%6.10f,%6.10f"
 	cfg  = template.dup
	cfg["source_url"] = url
	cfg["title"] = x + ".geo"
	cfg["cache_dir"] =  "/hub/cache/production/" + x + ".geo" + "/"

	File.open(x+".geo.conf.yml", "w") {|fd| YAML.dump(cfg, fd)}
end
