require "yaml"

template = File.open("source.shiv.op.yml"){|fd| YAML.load(fd) }
z = {}
ARGV.each do |x|
	hsh = {}
	hsh["source"]
	hsh["tl"] = {"x" => -180.0 , "y" => 90.0 }
	hsh["br"] = {"x" => 180.0 , "y" => -90.0 }
	hsh["source"] = "http://hippy.gina.alaska.edu/snaptiles/#{x}/bbox/%.20f/%.20f/%.20f/%.20f/"
	hsh["url"] = "http://hippy.gina.alaska.edu/snaptiles/kml/%s/%.20f/%.20f/%.20f/%.20f"
	z[x] = hsh
end
template["kml"]["sets"] = z

File.open("shiv.op.yml", "w") {|fd| YAML.dump(template, fd)}

