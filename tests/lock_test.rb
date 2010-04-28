require "tile_engine"
require "lumber"

lock = TileLockerFile.new(LumberNoFile.new({"debug"=> true, "info" => true, "verbose" => true}))

lock.check_and_wait(93462,273846,20)
puts("locked")
sleep(100)
lock.release_lock(0,0,0)
