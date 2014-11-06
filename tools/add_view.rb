require "yaml"
def proj (z)
	z.split("?").each do |x|
		match = /\w+=EPSG:(\d+)/.match(z)
		next if (!match)
		return match[1].to_i if (0 < match[1].to_i && match[1].to_i < 99999999) 
	end
end

projs=[]
ARGV.each do |i|
	item= File.open(i) {|x| YAML.load(x)}
	if item
		epsg_proj = proj(item["source_url"])
		puts i + "==>" + epsg_proj.to_s
		item["view"] = {} if (!item["view"])
		item["view"]["layout"] = "map_layout_#{epsg_proj}"
		projs << "map_layout_#{epsg_proj}" if (!projs.include?("map_layout_#{epsg_proj}"))
		File.open(i, "w") {|fd| YAML.dump(item, fd)}
	end
end


puts "Layouts Used: " + projs.join(" ")
