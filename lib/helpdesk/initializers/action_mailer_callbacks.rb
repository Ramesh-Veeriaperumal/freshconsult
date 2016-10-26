require 'action_mailer'
require 'smtp_tls'

module ActionMailerCallbacks

  def self.included(base)
    base.extend ClassMethods
    base.extend Helpdesk::Email::OutgoingCategory
  end

  module ClassMethods
    @email_confg = nil
        
    def set_email_config _email_config
      @email_confg = _email_config
    end
    
    def email_config
      @email_confg
    end
    
    def set_smtp_settings(mail)
      account_id_field = mail.header["Account-Id"]
      ticket_id_field = mail.header["Ticket-Id"]
      mail_type_field = mail.header["Type"]
      account_id = account_id_field.value if account_id_field.present?
      ticket_id = ticket_id_field.value if ticket_id_field.present?
      mail_type = (mail_type_field.present? && mail_type_field.value.present?) ? mail_type_field.value : "empty"
      account_id = account_id.present? ? account_id : -1
      ticket_id = ticket_id.present? ? ticket_id : -1
      mail.header["Account-Id"] = nil
      mail.header["Ticket-Id"] = nil
      mail.header["Type"] = nil
      if (email_config && email_config.smtp_mailbox)
        smtp_mailbox = email_config.smtp_mailbox
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
        Rails.logger.debug "Used SMTP mailbox : #{email_config.smtp_mailbox.user_name} in email config : #{email_config.id} while email delivery"
        self.smtp_settings = smtp_settings
        mail.delivery_method(:smtp, smtp_settings)
      elsif (email_config && email_config.category)
        Rails.logger.debug "Used EXISTING category : #{email_config.category} in email config : #{email_config.id} while email delivery"
        category_id = email_config.category
        self.smtp_settings = read_smtp_settings(category_id)
        mail.delivery_method(:smtp, read_smtp_settings(category_id))
        set_custom_headers(mail, category_id, account_id, ticket_id, mail_type)
      else
        mailgun_traffic = get_mailgun_percentage
        if mailgun_traffic > 0 && Random::DEFAULT.rand(100) < mailgun_traffic
          category_id = reset_smtp_settings(mail, true)
        else
          category_id = reset_smtp_settings(mail)
        end
        set_custom_headers(mail, category_id, account_id, ticket_id, mail_type)
      end
      @email_confg = nil
    end

    def reset_smtp_settings(mail, use_mailgun = false)
      begin
        category_id = get_category_header(mail) || get_category_id(use_mailgun)
      rescue Exception => e
        Rails.logger.debug "Exception occurred while getting category id : #{e} - #{e.message} - #{e.backtrace}"
        NewRelic::Agent.notice_error(e)
        category_id = nil
      end
      Rails.logger.debug "Fetched category : #{category_id} while email delivery"
      self.smtp_settings = read_smtp_settings(category_id)
      mail.delivery_method(:smtp, read_smtp_settings(category_id))
      return category_id
    end

    def set_custom_headers(mail, category_id, account_id, ticket_id, mail_type)
      if category_id.to_i > 10
        Rails.logger.debug "Sending email via mailgun"
        mail.header['X-Mailgun-Variables'] = "{\"account_id\": #{account_id},\"ticket_id\": #{ticket_id},\"type\": \"#{mail_type}\"}"
      else
        Rails.logger.debug "Sending email via sendgrid"
        mail.header['X-SMTPAPI'] = "{\"unique_args\":{\"account_id\": #{account_id},\"ticket_id\":#{ticket_id},\"type\":\"#{mail_type}\"}}"
      end
    end   
        
    def read_smtp_settings(category_id)
      if (!category_id.nil?) && (!Helpdesk::EMAIL["category-#{category_id}".to_sym].nil?)
        Helpdesk::EMAIL["category-#{category_id}".to_sym][Rails.env.to_sym]
      else 
        Helpdesk::EMAIL[:outgoing][Rails.env.to_sym]
      end
    end

    def get_category_header(mail)
      mail.header["X-FD-Email-Category"].to_s.to_i if mail.present? and mail.header["X-FD-Email-Category"].present?
    end
  end
end

ActionMailer::Base.send :include, ActionMailerCallbacks

require 'auto_link_mail_interceptor'
ActionMailer::Base.register_interceptor(AutoLinkMailInterceptor)
