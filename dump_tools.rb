#!/usr/bin/env ruby

class DataDump
    def DataDump.dump(s,fl)
        File.open(fl,"w") do |x|
            x.write("---\n")
            s.each do |ii|
                x.write("- ")
                ii.each_index do |iii|
                    x.write("  ") if (iii != 0 )
                    x.write("- #{ii[iii].to_s}\n")
                end
            end
            
            x.flush()
        end
    end
end
