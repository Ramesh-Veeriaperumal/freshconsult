
require 'action_mailer'
require 'smtp_tls'

module ActionMailerCallbacks

  def self.included(base)
    base.extend ClassMethods
    base.cattr_accessor :mailbox
  end

  module ClassMethods
    
    def set_smtp_settings
      if mailbox
        self.smtp_settings = {
          :tls                  => mailbox.use_ssl,
          :enable_starttls_auto => true,
          :user_name            => mailbox.user_name,
          :password             => mailbox.decrypt_password(mailbox.password),
          :address              => mailbox.server_name,
          :port                 => mailbox.port,
          :authentication       => mailbox.authentication,
          :domain               => mailbox.domain
        }
      else
        self.smtp_settings = Helpdesk::EMAIL[:outgoing][Rails.env.to_sym]
      end
    end

    def reset_smtp_settings
      self.smtp_settings = Helpdesk::EMAIL[:outgoing][Rails.env.to_sym]
    end   
  end
end

ActionMailer::Base.send :include, ActionMailerCallbacks

require 'auto_link_mail_interceptor'
ActionMailer::Base.register_interceptor(AutoLinkMailInterceptor)