


class Lumber
    
    
    #basic rules
    # debug - stuff only of interest to debugging, on if @debug
    # info - noisy stuff, on if not quiet
    # error - always on
    
    
    def initialize ( cfg )
        @cfg = cfg
        
        ##
        # Defaults
        @debug = false
        @info = false
        @quiet = false
        @verbose = false
        
        @verbose = true if (cfg["verbose"])
        @info = true if (cfg["info"])
        @quiet = true if (cfg["quiet"])
        @debug = true if (cfg["debug"])
        
        @error_fd = File.open(cfg["logdir"] + "/error.log", "a")
        @debug_fd = File.open(cfg["logdir"] + "/debug.log", "a")
        @info_fd = File.open(cfg["logdir"] + "/info.log", "a")
        
        msgerror("Start.")
        msginfo("Logging Started.")
    end
    
    
    def msginfo(s)
        return if (@quiet)
        return if (!@verbose)
        format_for_output(@info_fd, "INFO", s)
        format_for_output(STDOUT, "INFO", s)
    end
    
    def loginfo(s)
        msginfo(s)
    end
    
    def msgdebug(s)
        return if ( !@debug || @quiet)
        format_for_output(@info_fd, "DEBUG", s)
        format_for_output(STDOUT, "DEBUG", s)
        format_for_output(@debug_fd, "DEBUG", s)
    end
    
    def msgstatus( s)
        return if ( !@verbose || @quiet)
        format_for_output(STDOUT, "STATUS", s)
    end
    
    def logstatus(s)
        msgstatus(s)
    end
    
    def msgerror(s)
        format_for_output(@info_fd, "ERROR", s)
        format_for_output(@error_fd, "ERROR", s)
        format_for_output(STDERR, "ERROR", s)
    end
    
    def logerr(s)
        msgerror(s)
    end
    
    def puts (s)
        msgstatus(s)
    end
    
    private
    
    def format_for_output (out,label,s)
        out.write(sprintf("(%s:%s) %s\n", get_time.strftime("%Y/%m/%d %H:%M:%S"), label, s))
    end
    
    def get_time ( )
        return (Time.now.utc )
    end
    
end



##
# Stub class, only logs to stdout..

class LumberNoFile
    
    #basic rules
    # debug - stuff only of interest to debugging, on if @debug
    # info - noisy stuff, on if not quiet
    # error - always on
    
    
    def initialize ( cfg )
        @cfg = cfg
        
        ##
        # Defaults
        @debug = false
        @info = false
        @quiet = false
        @verbose = false
        
        @verbose = true if (cfg["verbose"])
        @info = true if (cfg["info"])
        @quiet = true if (cfg["quiet"])
        @debug = true if (cfg["debug"])
        
        @error_fd = STDOUT
        @debug_fd = STDOUT
        @info_fd = STDOUT
        
        msgerror("Start.")
        msginfo("Logging Started.")
    end
    
    
    def msginfo(s)
        return if (@quiet)
        return if (!@verbose)
        format_for_output(@info_fd, "INFO", s)
        format_for_output(STDOUT, "INFO", s)
    end
    
    def loginfo(s)
        msginfo(s)
    end
    
    def msgdebug(s)
        return if ( !@debug || @quiet)
        format_for_output(@info_fd, "DEBUG", s)
        format_for_output(STDOUT, "DEBUG", s)
    end
    
    def msgstatus( s)
        return if ( !@verbose || @quiet)
        format_for_output(STDOUT, "STATUS", s)
    end
    
    def logstatus(s)
        msgstatus(s)
    end
    
    def msgerror(s)
        format_for_output(@info_fd, "ERROR", s)
        format_for_output(@error_fd, "ERROR", s)
        format_for_output(STDERR, "ERROR", s)
    end
    
    def logerr(s)
        msgerror(s)
    end
    
    def puts (s)
        msgstatus(s)
    end
    
    def log_xfer ( request, response,size,tm)
        xfer =  { "access" => get_time,
            "url"=>request.params["REQUEST_URI"],
            "host" => request.params["REMOTE_ADDR"],
            "sz" => size,
            "tm" => tm }
        yml = YAML.dump(xfer)
        STDOUT.write(yml)
    end
    
    def log_access(request)
        #nothing..
    end
    
    private
    
    def format_for_output (out,label,s)
        out.write(sprintf("(%s:%s) %s\n", get_time.strftime("%Y/%m/%d %H:%M:%S"), label, s))
    end
    
    def get_time ( )
        return (Time.now.utc )
    end
    
end

##
# Stub class, only logs to stdout..

class LumberAppendNoFile < LumberNoFile
    
    #basic rules
    # debug - stuff only of interest to debugging, on if @debug
    # info - noisy stuff, on if not quiet
    # error - always on
    
    
    def initialize ( cfg, error_lst, debug_lst, info_lst)
        @cfg = cfg
        
        ##
        # Defaults
        @debug = false
        @info = false
        @quiet = false
        @verbose = false
        
        @verbose = true if (cfg["verbose"])
        @info = true if (cfg["info"])
        @quiet = true if (cfg["quiet"])
        @debug = true if (cfg["debug"])
        
        @error_fd = error_lst
        @debug_fd = debug_lst
        @info_fd = info_lst
        
        msgerror("Start.")
        msginfo("Logging Started.")
    end
    
    def msginfo(s)
        return if (@quiet)
        return if (!@verbose)
        format_for_output(@info_fd, "INFO", s)
    end
    
    def loginfo(s)
        msginfo(s)
    end
    
    def msgdebug(s)
        return if ( !@debug || @quiet)
        format_for_output(@info_fd, "DEBUG", s)
    end
    
    def msgstatus( s)
        return if ( !@verbose || @quiet)
    end
    
      
    def msgerror(s)
        format_for_output(@info_fd, "ERROR", s)
        format_for_output(@error_fd, "ERROR", s)
    end
    
    private
        
    def format_for_output (out,label,s)
        out << sprintf("(%s:%s) %s\n", get_time.strftime("%Y/%m/%d %H:%M:%S"), label, s)
    end
end


class HttpLumber < Lumber
     def initialize ( cfg )
        super(cfg)
        @hits_fd = File.open(cfg["logdir"] + "/hits.log", "a")
        @perf_fd = File.open(cfg["logdir"] + "/xfer.log", "a")
     end
     
     def log_request ( s)
        STDERR.write("Bad - not to be used directly...")
        exit(-1)
     end
     
     def log_access(request)
        STDERR.write("Bad - not to be used directly...")
        exit(-1)
     end
     
     def log_xfer ( request)
        STDERR.write("Bad - not to be used directly...")
        exit(-1)
     end
     
end


##
# Mongrel related stuff goes here...
class MongrelLumber < HttpLumber
    def initialize ( cfg )
        super(cfg)
    end
    def log_access(request)
        format_for_output(@hits_fd,"",request.params["REMOTE_ADDR"] + ":" + request.params["REQUEST_URI"])
    end
    
    ##
    # For now, the same as log_access...
    def log_request ( r)
        log_access(r)
    end
end

##
# Tile generator specific stuff goes here...
class TileLumber < MongrelLumber
    def initialize ( cfg )
        super(cfg)
    end
    
    
     def log_xfer ( request, response,size,tm)
        xfer =  { "access" => get_time,
            "url"=>request.params["REQUEST_URI"],
            "host" => request.params["REMOTE_ADDR"],
            "sz" => size,
            "tm" => tm }
        yml = YAML.dump(xfer)
        @perf_fd.write(yml)
     end
    
end
