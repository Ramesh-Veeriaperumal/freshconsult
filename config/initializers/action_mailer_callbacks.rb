require 'action_mailer'
require 'smtp_tls'

module ActionMailerCallbacks
  
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::TagHelper

  def self.included(base)
    base.extend ClassMethods
    base.alias_method_chain :deliver!, :deliver_callbacks
  end

  module ClassMethods
    @mailbox = nil
    
    def set_mailbox _mailbox
      @mailbox = _mailbox
    end

    def smtp_mailbox
      @mailbox
    end

    def set_smtp_settings
      if smtp_mailbox
        self.smtp_settings = {
          :tls                  => smtp_mailbox.use_ssl,
          :enable_starttls_auto => true,
          :user_name            => smtp_mailbox.user_name,
          :password             => smtp_mailbox.decrypt_password(smtp_mailbox.password),
          :address              => smtp_mailbox.server_name,
          :port                 => smtp_mailbox.port,
          :authentication       => smtp_mailbox.authentication,
          :domain               => smtp_mailbox.domain
        }
      else
        self.smtp_settings = Helpdesk::EMAIL[:outgoing][Rails.env.to_sym]
      end
    end

    def reset_smtp_settings
      self.smtp_settings = Helpdesk::EMAIL[:outgoing][Rails.env.to_sym]
    end   
  end

  def deliver_with_deliver_callbacks!(*args)
    @mail = auto_link_mail @mail
    self.class.reset_smtp_settings
    self.class.set_smtp_settings
    deliver_without_deliver_callbacks!(*args)
    @mail
  end

  def auto_link_mail mail=@mail
    #Does mail contain parts?
    if(!mail.parts.blank?)
      #if first part is multipart/mixed then delete --> temporary fix
      if(mail.parts[0].content_type.start_with?("multipart/mixed") && mail.parts[0].body.blank?)
        mail.parts.delete_at(0)
      end
      #send parts for auto_link
      auto_link_section(mail.parts)
    # if no parts and content is html then auto_link
    elsif(mail.content_type.start_with?("text/html"))
      autolinked_body = Rinku.auto_link(mail.body.to_s, :urls)
      encode_body(mail, autolinked_body)
    end
    mail
  end
    
  private
    def auto_link_section(section)
      section.each do |sub_section|
        if(sub_section.content_type.start_with?("text/html") && sub_section.content_disposition != "attachment")
          autolinked_body = Rinku.auto_link(sub_section.body.to_s, :urls)
          encode_body(sub_section, autolinked_body)
        end
        auto_link_section(sub_section.parts) unless sub_section.parts.blank?
      end
    end

    def encode_body(part, autolinked_body)
      case (part.content_transfer_encoding || "").downcase
        when "base64" then
          part.body = Mail::Encodings::Base64.encode(autolinked_body)
        when "quoted-printable"
          part.body = [normalize_new_lines(autolinked_body)].pack("M*")
        else
          part.body = autolinked_body
      end
    end
end

ActionMailer::Base.send :include, ActionMailerCallbacks