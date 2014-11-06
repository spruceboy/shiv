require "yaml"

projs=[]
ARGV.each do |i|
	item= File.open(i) {|x| YAML.load(x)}
	if item
		item["watermark"] = {} if (!item["watermark"])
		item["watermark"]["x_buffer"]= 10
  		item["watermark"]["y_buffer"] = 10
  		item["watermark"]["blending"] = 0.20
  		item["watermark"]["image"] = "/hub/cache/images/tile_logo.small.bw.png"
		item["watermark"]["one_out_of"] = 9

		item.delete("label") if (item["label"])
		File.open(i, "w") {|fd| YAML.dump(item, fd)}
	end
end

