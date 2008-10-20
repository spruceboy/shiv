require "yaml"
grid= Array.new(512,Array.new(512,0.0))
0.upto(511) {|x| grid[x] = Array.new(512,0.0) } 
File.open("this_is_a_test", "w") {|x| x.write(grid.to_yaml) }

