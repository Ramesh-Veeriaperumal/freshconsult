require 'action_mailer'
require 'smtp_tls'

module ActionMailerCallbacks

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    @mailbox = nil

    def set_mailbox _mailbox
      @mailbox = _mailbox
    end

    def smtp_mailbox
      @mailbox
    end
    
    def set_smtp_settings(mail)
      if smtp_mailbox
        smtp_settings = {
          :tls                  => smtp_mailbox.use_ssl,
          :enable_starttls_auto => true,
          :user_name            => smtp_mailbox.user_name,
          :password             => smtp_mailbox.decrypt_password(smtp_mailbox.password),
          :address              => smtp_mailbox.server_name,
          :port                 => smtp_mailbox.port,
          :authentication       => smtp_mailbox.authentication,
          :domain               => smtp_mailbox.domain
        }
        self.smtp_settings = smtp_settings
        mail.delivery_method(:smtp, smtp_settings)
      else
        reset_smtp_settings(mail)
      end
      @mailbox = nil
    end

    def reset_smtp_settings(mail)
      self.smtp_settings = Helpdesk::EMAIL[:outgoing][Rails.env.to_sym]
      mail.delivery_method(:smtp, Helpdesk::EMAIL[:outgoing][Rails.env.to_sym])
    end   
  end
end

ActionMailer::Base.send :include, ActionMailerCallbacks

require 'auto_link_mail_interceptor'
ActionMailer::Base.register_interceptor(AutoLinkMailInterceptor)
