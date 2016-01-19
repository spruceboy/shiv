#!/usr/bin/env ruby
# Sends email. Used to send error emails on the case of fatal errors.
# Gave up on activemailer, now uses https://github.com/mikel/mail
require 'mail'

class Mailer
  def self.deliver_message(conf, email_to, email_subject, email_body)
    Mail.defaults do
      delivery_method :smtp,         address: conf['setup'][:address],
                                     domain: conf['setup'][:domain]
    end

    Mail.deliver do
      from conf['from']
      to email_to
      subject email_subject
      body email_body.join("\n")
    end
  end
end
