#locking utils
require 'thread'
# A per tile clocking sceme... fun for all..

class TileLocker
  def initialize(log)
    @log = log
    @locker = {}
    @wait = 0.3
    @m_lock = Mutex.new
    @lt = 'TileLocker'
  end

  ###
  # This is confusing.. pay attention!
  # This function is used to control requests, if a request is in progress, it waits until the request is finished, then returns true, with the lock not set/altered.
  # If a request is not in progress, it returns false and sets the lock.
  def check_and_wait(x, y, z)
    busy = false
    until  check_lock(x, y, z)
      @log.msgdebug(@lt + "check_and_wait -> waiting on #{x},#{y},#{z}")
      sleep(@wait)
      busy = true
    end

    release_lock(x, y, z) if busy # Release lock, and data has allready been generated..
    busy
  end

  # Returns true if locked, false otherwise..
  def check_lock(x, y, z)
    token = "#{x}_#{y}_#{z}"
    @m_lock.synchronize do
      if !@locker[token]
        @log.msgdebug(@lt + "locking on #{x},#{y},#{z}")
        @locker[token] = Time.now
        return true
      else
        return false
      end
    end
  end

  # to be called after check_and_wait..
  def release_lock(x, y, z)
    token = "#{x}_#{y}_#{z}"
    @m_lock.synchronize { @locker.delete(token) }
  end
end

class TileLockerFile
  WAIT_TIME = (60 * 3)
  def initialize(log)
    @log = log
    @lock_dir = './locks/'
    @wait = 0.3
    @m_lock = Mutex.new
    @lt = 'TileLockerFile:'
  end

  def is_locked?(x,y,z)
	File.exists?(getpath(x,y,z))
  end

  ###
  # This is confusing.. pay attention!
  # This function is used to control requests, if a request is in progress, it waits until the request is finished, then returns true, with the lock not set/altered.
  # If a request is not in progress, it returns false and sets the lock.
  # Ok, I lied, it should always return with a lock in place..
  def check_and_wait(x, y, z)
    busy = false
    until  check_lock(x, y, z)
      @log.msgdebug(@lt + "check_and_wait -> waiting on #{x},#{y},#{z}")
      puts (".")
      sleep(@wait)
      busy = true
    end
    busy
  end

  # Returns true if locked, false otherwise..
  def check_lock(x, y, z)
    if !locked(x, y, z)
      @log.msgdebug(@lt + "locking on #{x},#{y},#{z}")
      return true
    else
      return false
    end
  end

  # to be called after check_and_wait..
  def release_lock(x, y, z)
    @log.msgdebug(@lt + "releasing #{x},#{y},#{z}")
    @m_lock.synchronize do
      begin
        File.delete(getpath(x, y, z))
      rescue => e
        @log.msgerror(@lt + "release lock -> colision at #{x},#{y},#{z} (#{e})")
      end
    end
  end

  def getpath(x, y, z)
    ("#{@lock_dir}#{x}_#{y}_#{z}")
  end

  def locked(x, y, z)
    @m_lock.synchronize do
      path = getpath(x, y, z)

      begin # this section deals with old locks - if lock file exists and is old, delete..
        if  File.exist?(path) && ((Time.now - File.mtime(path)) > WAIT_TIME)
          @log.msgerror(@lt + "Lock timeout on #{x},#{y},#{z}  ")
          File.delete(path)
        end
      rescue
        # Do nothing - means file is gone.
      end

      # Normal path
      if File.exist?(path)
        return true
      else
        File.open(path, 'w') { |fl| fl.write(Time.now.to_s); fl.flush }
        return false
      end
    end
  end
end
