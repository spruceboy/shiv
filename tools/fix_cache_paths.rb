require "yaml"

projs=[]
ARGV.each do |i|
	item= File.open(i) {|x| YAML.load(x)}
	if item
		next if ( !item["cache_dir"].include?("hub/cache/production/wind"))
		target = "/hub/cache/production/aea/" + item["title"] + "/"
		puts item["cache_dir"] + "=>" + target
		system("mv -v #{item["cache_dir"]} #{target}")
		item["cache_dir"] = target
		File.open(i, "w") {|fd| YAML.dump(item, fd)}
	end
end

