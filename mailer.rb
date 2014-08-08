#!/usr/bin/env ruby
require "tempfile"

class JMailer
    
  def initialize (cfg, logger)
    @cfg = cfg
    @log = logger
  end
  
  def send ( to, subject, body )
  end
end



# Gave up on activemailer, now uses https://github.com/mikel/mail
# Gave up on mail, now just using mailx.  Sigh.
require "mail"

class Mailer 
  def Mailer.deliver_message(conf,email_to, email_subject, email_body)
    msg = Tempfile.new("tiler_error_msg")
    msg.write(email_body.join("\n"))
    msg.flush
    msg.close
    system("mailx -s \"#{email_subject}\" -r \"#{conf['from']}\" \"#{email_to}\" < #{msg.path}")
    msg.unlink
  end
end


#require "yaml"
#conf = File.open("shiv.yml") {|fd| YAML.load(fd)}["tile_engines"]["mailer_config"]
#Mailer.deliver_message(conf, "jay@alaska.edu", "test,test,test", ["this is a test.", "this is a test2"])

