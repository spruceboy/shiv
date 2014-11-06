require "yaml"
def proj (z)
        z.split("?").each do |x|
                match = /\w+=EPSG:(\d+)/.match(z)
                next if (!match)
                return match[1].to_i if (0 < match[1].to_i && match[1].to_i < 99999999)
        end
end




def mapper( s ) 
	maping = { 102006 => 3338, 900913 => 3857 }
	s = maping[s] if (maping[s])
	"EPSG:#{s}"
end

projs=[]
ARGV.each do |i|
        item= File.open(i) {|x| YAML.load(x)}
        if item
                epsg_proj = mapper(proj(item["source_url"]))
                puts i + "==>" + epsg_proj.to_s

                item["notes"] = {} if (!item["notes"])

		#projection
                item["notes"]["projection"] = epsg_proj if (!item["notes"]["projection"])
		
		if (item["esri_rest"])
			item["notes"]["description"] = item["esri_rest"]["description"]	if (!item["notes"]["description"])
			item["notes"]["copyrighttext"] = item["esri_rest"]["copyrightText"] if (!item["notes"]["copyrightText"])
		else
			item["notes"]["description"] = "TBD." if (!item["notes"]["description"])
                        item["notes"]["copyrighttext"] = "TBD." if (!item["notes"]["copyrightText"])
		end
                File.open(i, "w") {|fd| YAML.dump(item, fd)}
                projs << epsg_proj if (!projs.include?(epsg_proj))
        end
end


puts "projections Used: " + projs.join(" ")
