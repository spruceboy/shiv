require "yaml"

def mapper( s ) 
	maping = { 102006 => 3338, 900913 => 3857 }
	s = maping[s] if (maping[s])
	"EPSG:#{s}"
end


roots=[]
paths=[]
Dir.glob("conf.d/*.conf.yml").each do |ii|
	i = File.open(ii) {|x| YAML.load(x)}
	#puts  "#{i} -> #{i["cache_dir"]}"
	i["cache_dir"].gsub!("/hub/tile_cache", "/hub/cache")
	i["cache_dir"].gsub!("/hub/cache/cache", "/hub/cache")
	paths << i["cache_dir"]
	dirname = File.dirname(i["cache_dir"])
	puts dirname
	roots << dirname if (!roots.include?(dirname))
end


unknown = []


roots.each do |x|
	Dir.glob("#{x}/*").each do |item|
		unknown << item if (!paths.include?(item+"/"))
	end
end


puts
puts "Unaccounted for:"
puts "------------------------------"
unknown.each do |x|
	puts x
end

