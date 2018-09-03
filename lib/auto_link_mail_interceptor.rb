class AutoLinkMailInterceptor

  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::TagHelper

  def self.delivering_email(mail)
    Rails.logger.debug "auto_linking mail #{mail.inspect}!"
    ActionMailer::Base.reset_smtp_settings(mail)
    ActionMailer::Base.set_smtp_settings(mail)
    auto_link_mail(mail)
  end

  private
    def self.sandbox_footer(content)
      content.raw_source.replace("<div style= 'padding:5px 0;margin-bottom: 10px;border-bottom:solid 1px #dadfe3;color:#d08d0b'>#{I18n.t('sandbox.sandbox_mail')}</div>".html_safe + content.raw_source) if Account.current.try(:sandbox?)
      content
    end

    def self.auto_link_mail mail=@mail
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
        autolinked_body = FDRinku.auto_link(sandbox_footer(mail.body).to_s)
        encode_body(mail, autolinked_body)
      end
      convert_email_to_base64 mail if (Thread.current[:line_length_exceeded] == true)
      mail
    end

    def self.auto_link_section(section)
      section.each do |sub_section|
        if(sub_section.content_type.start_with?("text/html") && sub_section.content_disposition != "attachment")
          autolinked_body = FDRinku.auto_link(sandbox_footer(sub_section.body).to_s)
          encode_body(sub_section, autolinked_body)
        end
        auto_link_section(sub_section.parts) unless sub_section.parts.blank?
      end
    end

    def self.encode_body(part, autolinked_body)
      Rails.logger.debug "DEBUG :: INSIDE encode_body :: #{part.content_transfer_encoding}"
      case (part.content_transfer_encoding || "").downcase
        when "base64" then
          part.body = Mail::Encodings::Base64.encode(autolinked_body)
        when "quoted-printable"
          part.body = [normalize_new_lines(autolinked_body)].pack("M*")
        else
          part.body = autolinked_body
      end
    end

    def self.normalize_new_lines(text)
      text.to_s.gsub(/\r\n?/, "\n")
    end

    def self.convert_email_to_base64 mail=@mail
      if(!mail.parts.blank?)
        mail.parts.each do |part|
        convert_part_to_base64 part
      end
      else
        mail.content_transfer_encoding = "base64"
        mail.body = Mail::Encodings::Base64.encode(mail.body.to_s)
      end
    end

    def self.convert_part_to_base64 part
      if(part.multipart?)
        part.parts.each do |part|
          convert_part_to_base64 part
        end
      else
        part.content_transfer_encoding = "base64"
        part.body = Mail::Encodings::Base64.encode(part.body.to_s)
      end
    end

end