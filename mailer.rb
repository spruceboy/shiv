#!/usr/bin/env ruby

class JMailer
    
  def initialize (cfg, logger)
    @cfg = cfg
    @log = logger
  end
  
  def send ( to, subject, body )
  end
end



# Gave up on activemailer, now uses https://github.com/mikel/mail
require "mail"

class Mailer 
       def Mailer.deliver_message(conf,email_to, email_subject, email_body)

		Mail.defaults do
			delivery_method :smtp, { 
					:address => conf["setup"][:address],
        				:domain  => conf["setup"][:domain],
        		}
		end

		Mail.deliver do
   			from    conf['from']
   			to      email_to
   			subject email_subject
   			body    email_body.join("\n")
		end
	end
end
##p = Mailer.new ( conf, "jay@alaska.edu", "jay@alaska.edu", "test,test,test", ["this is a test.", "this is a test2"])
#
#         Mailer.deliver_message(conf, ["this is a test.", "this is a test2"])

