require "yaml"
require "heat_map_tools"
cfg = YAML.load(File.open("shiv.revamp.yml"))
h = Imlib2HeatMapper.new(cfg["heatmap"], cfg)
h.AddTile(0,0,7,"137.229.19.1")
puts("---------------------------------")
h.AddTile(0,0,6,"137.229.19.1")
puts("---------------------------------")
1.upto(100) { h.AddTile(254,254,8,"137.229.19.1")}
1.upto(100) { h.AddTile(2,2,3,"137.229.19.1")}
puts("---------------------------------")
h.AddTile(2**11-1,2**11-1,11,"137.229.19.1")
puts("---------------------------------")
h.AddTile(32,32,11,"137.229.19.1")

puts("Done.")

h.GetImageWithBackground()






