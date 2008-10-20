#!/usr/bin/env ruby
#lock file helper

require 'yaml'

require 'mailer'

class Locker
    def initialize ( hsh,logger )
        @logger = logger
    end
    
    def lock
        
    end
    
    def unlock
        
    end
    
    def active?
        
    end
end


class YamlLock < Locker
    
    def initialize ( hsh,logger,path )
        supper(hsh, logger)
        @lock_path = path
        ##
        # Should be configurable...
        @lock_time_out = 2*60    #2 min..
    end
    
    
    def lock
        
    end
    
    def unlock
        
    end
    
    def active?
        
    end
    
    private
    
    def lock_check ( )
        return false if ( !File.exists?(@lock_path))
        return false if ( File.size?(@lock_path))
        lock_cfg = load_lock()
        return false if (!lock_cfg)
        return false if ((Time.now - lock_cfg["lock_tm"]) > 2)
        return true
    end
    
    def load_lock ( )
        return File.open(@lock_path) { |x| YAML.load(x) }
    end
    
end


class RunLock

        ##
        # Hsh is a hash
        # should look like
        #       [lockfile] => "pathtolockfile"
        #       [message] => "lock file msg..."
        #       [mailer] -> {mailer conf}
        def initialize ( hsh )
                @hsh = hsh
                @pid = Process.pid
                if ( !File.exists?(hsh['lockfile']) )
                        lock()
                else
                        ##
                        # lock allready exists, read it, then decide if to email out warning...
                        lock_info = YAML.load(File.open(hsh['lockfile']) )
                        if (lock_info['lock_time'].to_f < (Time.now - 24*60*60).to_f)
                                if ( hsh['alert'] )
                                        body = []
                                        body << "A lock is still active."
                                        body << "It looks like "
                                        body << "-----------------------------"
                                        body << YAML.dump(lock_info )
                                        Mailer.deliver_message(hsh["mailer"], body)
                                end
                        end

                        if (!File.exists?("/proc/" + lock_info["pid"].to_s)  )
                                if ( hsh['alert'] )
                                         body = []
                                         body << "A lock is still active but the pid (#{hsh['pid']}) is not active."
                                         body << "-----------------------------"
                                         body << YAML.dump(lock_info )
                                         Mailer.deliver_message(hsh["mailer"], body)
                                 end
                        end

                        raise RuntimeError, "Lock still active."
                end
        end

        def lock ( )
                conf = {
                                "message" => @hsh["message"],
                                "pid" => @pid,
                                "lock_time" => Time.now
                }
                File.open( @hsh["lockfile"], 'w' ) do |out|
                        YAML.dump( conf, out )
                end

        end

        def unlock( )
                File.unlink(@hsh["lockfile"])
        end

end
