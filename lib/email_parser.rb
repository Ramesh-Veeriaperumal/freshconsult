module EmailParser

  include AccountConstants

  def parse_addresses(addresses, options = {})
    return {:emails => [], :plain_emails => []} if addresses.blank?
    addresses = addresses.split(",") if addresses.is_a?(String)
    name = ""
    plain_emails = []
    emails = []

    ignore_emails = options[:ignore_emails].to_a
    ignore_emails = ignore_emails.map(&:downcase) if ignore_emails.present?

    addresses.each do |add|
      begin
        to_field = Mail::ToField.new
        to_field.value =  add
        parsed_addresses = to_field.addrs
        parsed_addresses.each do |email| 
          address = email.address
          address = Mail::Encodings.unquote_and_convert_to(address, "UTF-8") if address.include?("=?")
          if address =~ EMAIL_REGEX
            parsed_email = $1.downcase

            next if ignore_emails.include?(parsed_email)

            plain_emails.push parsed_email            

            if email.name.present?
              email_name = email.name
              email_name = email.name.prepend(name) and name="" if name.present?
              emails.push "#{format_name(email_name)} <#{parsed_email}>".strip
            else
              emails.push parsed_email
            end
          else
            name << "#{address} , "
          end
        end
      rescue Exception => e
        Rails.logger.debug "Exception when parsing addresses #{addresses} : #{add}"
        add.gsub!("\'", "")
        add.gsub!("\"", "")
        position = add =~ EMAIL_REGEX
        if position
          email_address = $1.downcase
          next if ignore_emails.include?(email_address)
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
