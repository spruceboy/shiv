#!/usr/bin/env ruby

require "yaml"
require "pp"




towns = File.open(ARGV.first) {|x| YAML.load(x)}

towns.keys.each do |x|
    puts("Doing #{x}")
    s = `echo "#{towns[x].join(" ")}" | cs2cs +proj=latlong  +to +init=epsg:900913`
    a = `echo "#{towns[x].join(" ")}" | cs2cs +proj=latlong  +to +init=epsg:102006`
    towns[x] = { "google" =>s.split(/\s+/)[0,2], "alaska" =>a.split(/\s+/)[0,2], "latlong" => towns[x] }
end

File.open(ARGV.last, "w") {|x| YAML.dump(towns,x)}

