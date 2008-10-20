#!/usr/bin/env ruby

require "dump_tools"
require "yaml"


size = 1024
s = Array(size)
0.upto(size-1){|i| s[i]= Array.new(size, 0.0)}

start_tm = Time.now
YAML.dump(s, File.open("test_yaml","w"))
puts("Yaml dump took #{(Time.now - start_tm)/60.0}m")

start_tm = Time.now
DataDump.dump(s, "test_dumper")
puts("DataDump dump took #{(Time.now - start_tm)/60.0}m")

