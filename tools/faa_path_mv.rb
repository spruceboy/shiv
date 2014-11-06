require "yaml"

projs=[]
ARGV.each do |i|
	item= File.open(i) {|x| YAML.load(x)}
	if item
		next if (!item["title"].include?("faa") || item["cache_dir"].include?("/faa/"))
		target = "/hub/cache/faa/" + item["title"] + "/"
		puts item["cache_dir"] + "=>" + target 
		puts "mv  #{item["cache_dir"]} #{target}"
		 item["cache_dir"] = target
		File.open(i, "w") {|fd| YAML.dump(item, fd)}
	end
end

