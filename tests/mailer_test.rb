#!/usr/bin/env ruby

require "mailer"

conf =  {
        "setup" => { :address => "dino.gi.alaska.edu",
                :domain => "gina.alaska.edu"
                },
        "to" => "jay@alaska.edu",
        "from" => "jay@alaska.edu",
        "subject" => "test,test,test"
}


#p = Mailer.new ( conf, "jay@alaska.edu", "jay@alaska.edu", "test,test,test", ["this is a test.", "this is a test2"])

     Mailer.deliver_message(conf, "jay@alaska.edu", "Test,test,test", ["this is a test.", "this is a test2"])
     Mailer.deliver_message(conf, "cable@alaska.edu", "Test,test,test - cable", ["this is a test.", "this is a test2"])

