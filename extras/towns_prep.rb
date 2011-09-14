#!/usr/bin/env ruby
# A very basic util to add to a yaml-ized list of towns google and alaska albers cordinates..
# Possibly not very useful to the masses.. but included non-the-less.

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

