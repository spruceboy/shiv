#!/usr/bin/env ruby

class JMailer
    
  def initialize (cfg, logger)
    @cfg = cfg
    @log = logger
  end
  
  def send ( to, subject, body )
  end
end



require "rubygems"
require 'action_mailer'

class Mailer < ActionMailer::Base
    
       def message(conf,to, subject, body)
                ActionMailer::Base.smtp_settings =  conf['setup']
                 @from = conf['from']
                 @recipients= to
                 @subject = subject
                 @body = body.join("\n")
        end
end

##Use like conf =  {
#        "setup" => { :address => "dino.gi.alaska.edu",
#                :domain => "gina.alaska.edu"
#                },
#        "to" => "jay@alaska.edu",
#        "from" => "jay@alaska.edu",
#        "subject" => "test,test,test"
#}
#
#
##p = Mailer.new ( conf, "jay@alaska.edu", "jay@alaska.edu", "test,test,test", ["this is a test.", "this is a test2"])
#
#         Mailer.deliver_message(conf, ["this is a test.", "this is a test2"])

