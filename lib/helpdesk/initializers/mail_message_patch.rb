#patching it with changes from mail gem 2.6.4 & removing unnecessary space separator logic in mail message.rb

require 'mail'
Mail::Message.class_eval do
  include Email::Mailbox::Oauth2Helper
  include Email::Mailbox::Utils
  include Email::Mailbox::Constants

    def deliver
      inform_interceptors
      response = ""
      begin
        if delivery_handler
          response = delivery_handler.deliver_mail(self) { do_delivery }
        else
          response = do_delivery
        end
      rescue Net::SMTPAuthenticationError => e
        Rails.logger.info "Net::SMTPAuthenticationError while sending email - #{e.message}"
        update_mailbox_error_type if valid_auth_error?(e)
        Rails.logger.info 'Authentication error occurred for OAuth mailbox!' if oauth_retry?
      rescue Net::SMTPFatalError => e
        Rails.logger.info "Net::SMTPFatalError while sending email by deliver - #{e.message}"
        raise if e.to_s.downcase.include?('line length exceeded')
      rescue StandardError => e
        Rails.logger.info "SMTP error while sending email #{e.message}"
      end

      Rails.logger.info 'Error! Response is blank for OAuth mailbox' if response.blank? && oauth_retry?
      Rails.logger.info "Email successfully relayed to SMTP mail server. Response from mail server: #{response.string}" if response.present? && response.class == Net::SMTP::Response
      inform_observers
      self
    end

  def deliver!
    inform_interceptors
    response = ''
    begin
      response = delivery_method.deliver!(self)
    rescue Net::SMTPAuthenticationError => e
      Rails.logger.info "Net::SMTPAuthenticationError while sending email by deliver! - #{e.message}"
      update_mailbox_error_type if valid_auth_error?(e)
      log_mail_message
      raise e
    rescue Net::SMTPFatalError => e
      Rails.logger.info "Net::SMTPFatalError while sending email by deliver! - #{e.message}"
      log_mail_message
      raise if e.to_s.downcase.include?('line length exceeded')
    rescue StandardError => e
      Rails.logger.info "StandardError while sending email by deliver! - #{e.class} :: #{e.message}"
      log_mail_message
      raise e
    end
    raise 'Error! Response is blank for OAuth mailbox by deliver!' if response.blank? && oauth_retry?

    Rails.logger.info "Email successfully relayed to SMTP mail server through deliver!. Response from mail server: #{response.string}" if response.present? && response.class == Net::SMTP::Response
    inform_observers
    delivery_method.settings[:return_response] ? response : self
  end

    private
      

      HEADER_SEPARATOR_WITH_MATCH_PATTERN = /(#{Mail::Patterns::CRLF}#{Mail::Patterns::CRLF}|#{Mail::Patterns::CRLF}#{Mail::Patterns::WSP}*#{Mail::Patterns::CRLF}(?!#{Mail::Patterns::WSP}))/m
      HEADER_SEPARATOR_WITH_NO_WHITESPACE = /#{Mail::Patterns::CRLF}#{Mail::Patterns::CRLF}(?!#{Mail::Patterns::WSP})/m
      HEADER_FIELD_PATTERN = /^\w(.*):(.*)$/
      
    def parse_message
      header_part, match_pattern, body_part = raw_source.lstrip.split(HEADER_SEPARATOR_WITH_MATCH_PATTERN, 2)

      if match_pattern && (match_pattern =~ HEADER_SEPARATOR_WITH_NO_WHITESPACE).nil? 
        if body_part.present?
          first_line = body_part.split("\n").first
          if first_line =~ HEADER_FIELD_PATTERN
            header_part, body_part = raw_source.lstrip.split(HEADER_SEPARATOR_WITH_NO_WHITESPACE, 2)
          end
        end
      end

      self.header = header_part
      self.body   = body_part
    end

      def oauth_retry?
        self.delivery_method.settings[:authentication] == Email::Mailbox::Constants::OAUTH && !failed_mailbox?(self.from.try(:[], 0))
      end

      def log_mail_message
        Rails.logger.info "Mail::Message - #{self.inspect}"
      end

      def valid_auth_error?(message)
        message.to_s[0..2].eql?(Email::Mailbox::Constants::SMTP_AUTH_ERROR_CODE)
      end
end

#Added disposition_type check to inline? method of part class
Mail::Part.class_eval do
          
    def inline?
      header[:content_disposition].disposition_type == 'inline' if header[:content_disposition].respond_to?(:disposition_type)
    end
    
end

Mail::Body.class_eval do
    
    #Added to set deafult value in Regexp.escape if boundary is nil
    def split!(boundary)
      self.boundary = boundary
      parts = raw_source.split(/(?:\A|\r\n)--#{Regexp.escape(boundary || "")}(?=(?:--)?\s*$)/)
      # Make the preamble equal to the preamble (if any)
      self.preamble = parts[0].to_s.strip
      # Make the epilogue equal to the epilogue (if any)
      self.epilogue = parts[-1].to_s.sub('--', '').strip
      parts[1...-1].to_a.each { |part| @parts << Mail::Part.new(part) }
      self
    end

end

#Make Content-transfer-encoding as 8 bit if it comes as UTF-8
Mail::Encodings.register("UTF-8",Mail::Encodings::EightBit)


# Latest changes from Mail Encoding Module
module Mail
  module Encodings

  ENCODED_VALUE = /\=\?([^?]+)\?([QB])\?[^?]*?\?\=/mi
  FULL_ENCODED_VALUE = /(\=\?[^?]+\?[QB]\?[^?]*?\?\=)/mi
  Q_VALUES       = ['Q','q']
  B_VALUES       = ['B','b']
  EMPTY          = ''
  
    def Encodings.value_decode(str)
        # Optimization: If there's no encoded-words in the string, just return it
        return str unless str =~ ENCODED_VALUE

        lines = collapse_adjacent_encodings(str)

        # Split on white-space boundaries with capture, so we capture the white-space as well
        lines.each do |line|
          line.gsub!(ENCODED_VALUE) do |string|
            case $2
            when *B_VALUES then b_value_decode(string)
            when *Q_VALUES then q_value_decode(string)
            end
          end
        end.join("")
    end
    
    def Encodings.collapse_adjacent_encodings(str)
        results = []
        previous_encoding = nil
        lines = str.split(FULL_ENCODED_VALUE)
        lines.each_slice(2) do |unencoded, encoded|
          if encoded
            encoding = value_encoding_from_string(encoded)
            if encoding == previous_encoding && unencoded.blank? #slightly changed from mail gem 2.6.4
              results.last << encoded
            else
              results << unencoded unless unencoded == EMPTY
              results << encoded
            end
            previous_encoding = encoding
          else
            results << unencoded
          end
        end

        results
    end

    def Encodings.value_encoding_from_string(str)
        str[ENCODED_VALUE, 1]
    end

  end
end

#
module Mail
  class Ruby19

    def Ruby19.b_value_decode(str)
      match = str.match(/\=\?(.+)?\?[Bb]\?(.*)\?\=/m)
      if match
        charset = match[1]
        str = Ruby19.decode_base64(match[2])
        str.force_encoding(pick_encoding(charset))
      end
      decoded = str.encode("utf-8", :invalid => :replace, :replace => "")
      decoded.valid_encoding? ? decoded : decoded.encode("utf-16le", :invalid => :replace, :replace => "").encode("utf-8")
      rescue Encoding::UndefinedConversionError , Encoding::ConverterNotFoundError => e
        Rails.logger.info "Encoding conversion failed : #{e.message} - #{e.backtrace}"
        str.dup.force_encoding("utf-8")
    end

    def Ruby19.q_value_decode(str)
      match = str.match(/\=\?(.+)?\?[Qq]\?(.*)\?\=/m)
      if match
        charset = match[1]
        string = match[2].gsub(/_/, '=20')
        # Remove trailing = if it exists in a Q encoding
        string = string.sub(/\=$/, '')
        str = Encodings::QuotedPrintable.decode(string)
        str.force_encoding(pick_encoding(charset))
      end
      decoded = str.encode("utf-8", :invalid => :replace, :replace => "")
      decoded.valid_encoding? ? decoded : decoded.encode("utf-16le", :invalid => :replace, :replace => "").encode("utf-8")
    rescue Encoding::UndefinedConversionError, Encoding::ConverterNotFoundError => e
      Rails.logger.info "Encoding conversion failed : #{e.message} - #{e.backtrace}"
      str.dup.force_encoding("utf-8")
    end

    def Ruby19.pick_encoding(charset)
      case charset

      # ISO-8859-15, ISO-2022-JP and alike
      when /iso-?(\d{4})-?(\w{1,2})/i
        "ISO-#{$1}-#{$2}"

      # "ISO-2022-JP-KDDI"  and alike
      when /iso-?(\d{4})-?(\w{1,2})-?(\w*)/i
        "ISO-#{$1}-#{$2}-#{$3}"

      # UTF-8, UTF-32BE and alike
      when /utf-?(\d{1,2})?(\w{1,2})/i
        "UTF-#{$1}#{$2}".gsub(/\A(UTF-(?:16|32))\z/, '\\1BE')

      when /Windows-?1258/i
        "Windows-1252"

      # Windows-1252 and alike
      when /Windows-?(.*)/i
        "Windows-#{$1}"

      when /^8bit$/
        Encoding::ASCII_8BIT

      # Microsoft-specific alias for CP949 (Korean)
      when 'ks_c_5601-1987' , 'MS949' #added 'MS949'
        Encoding::CP949

      when 'cp-850'     #added from mail gem 2.6.4
        Encoding::CP850 

      when 'latin2'   #added from mail gem 2.6.4
        Encoding::ISO_8859_2

      # Wrongly written Shift_JIS (Japanese)
      when 'shift-jis'
        Encoding::Shift_JIS

      # GB2312 (Chinese charset) is a subset of GB18030 (its replacement)
      when /gb2312/i
        Encoding::GB18030

      else
        charset
      end
    end

  end
end
