#!/usr/bin/env ruby

require "rubygems"
###
#  http client tools
#  Url/fetching/curl like stuff
#

class HttpClient
    ##
    # Stub for future use...
end

##
# Openuri/wget combo version
class SimpleHttpClient < HttpClient
    require "open-uri"
    def easy_download ( url, path )
        system("wget", "-q", "-O", path, url )
        return true if (File.exists?(path) && File.size(path) > 0 )
        return false
    end
      
    def easy_body ( url)
        return open(url).read
    end
end


###
# Curl based version
class SimpleCurlHttpClient < HttpClient
    require "curb"
    def easy_download ( url, path )
        system("curl", "--output", path, url )
        return true if (File.exists?(path) && File.size(path) > 0 )
        return false
    end
    
    def easy_body ( url)
        return Curl::Easy.perform(url).body_str
    end
end

##
# Curb based version
class SimpleCurbHttpClient < HttpClient
    def easy_download ( url, path )
        Curl::Easy.download(url, path)
        return true if (File.exists?(path) && File.size(path) > 0 )
        return false
    end 
end



