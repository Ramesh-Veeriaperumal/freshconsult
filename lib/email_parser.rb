module EmailParser

  include AccountConstants

  def parse_addresses(addresses)
    addresses = addresses.split(",") if addresses.is_a?(String)
    name = ""
    plain_emails = []
    emails = []
    addresses.each do |add|
      begin
        to_field = Mail::ToField.new
        to_field.value =  add
        email = to_field.addrs.first
        address = email.address
        address = Mail::Encodings.unquote_and_convert_to(address, "UTF-8") if address.include?("=?")
        if address =~ EMAIL_REGEX
          if email.name.present?
            email_name = email.name
            email_name = email.name.prepend(name) and name="" if name.present?
            plain_emails.push $1.downcase
            emails.push "#{format_name(email_name)} <#{$1.downcase}>".strip
          else
            plain_emails.push $1.downcase
            emails.push $1.downcase
          end
        else
          name << "#{address} , "
        end
      rescue Exception => e
        Rails.logger.debug "Exception when parsing addresses #{addresses} : #{add}"
        add.gsub!("\'", "")
        add.gsub!("\"", "")
        position = add =~ EMAIL_REGEX
        if position
          email_address = $1.downcase
          name = name.present? ? name << add[0..position-1] : add[0..position-1]
          name.gsub!("<", "")
          name.gsub!(">", "")
          plain_emails.push email_address
          emails.push "#{format_name(name)}  <#{email_address}>"
          name = ""
        else
          name << "#{add} "
        end
      end
    end
    { :emails => emails.uniq, :plain_emails => plain_emails.uniq }
  end

  def format_name(name)
    (name =~ SPECIAL_CHARACTERS_REGEX and name !~ /".+"/) ? "\"#{name}\"" : name
  end
end
