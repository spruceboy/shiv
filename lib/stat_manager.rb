#!/usr/bin/env ruby
##
#
# This is currently unused.
#

class StatManager
  def initialize
    # should load, not dump..
    @lstats = {}
    @sstats
  end

  def add(type, ip)
    add_stat(@lstats, type, Time.now.year * 100 + Time.now.month, ip)
    add_stat(@sstats, type, Time.now.jday, ip)
  end

  private

  def add_stat(hsh, type, key, ip)
    Time.now.year
    hsh[type] = {} unless hsh[type]
    hsh[type][key] = {} unless hsh[type][key]
    hsh[type][key][ip] = 0 unless hsh[type][key][ip]
    hsh[type][key][ip] += 1
  end
end
