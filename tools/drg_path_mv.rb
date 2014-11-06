require "yaml"

projs=[]
ARGV.each do |i|
	item= File.open(i) {|x| YAML.load(x)}
	if item
		next if (!item["title"].include?("drg") || !item["cache_dir"].include?("/hub/tile_cache/") || item["cache_dir"].include?("/production/"))
		target = "/hub/cache/drg/" + item["title"] + "/"
		puts item["cache_dir"] + "=>" + target 
		system("mv -v  #{item["cache_dir"]} #{target}")
		item["cache_dir"] = target
		File.open(i, "w") {|fd| YAML.dump(item, fd)}
	end
end

