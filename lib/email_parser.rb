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
        to_field.value =  (Account.current && Account.current.launched?(:q_value_encode)) ? (encode_non_usascii_q_val(add, "UTF-8")) : add
        parsed_addresses = to_field.addrs
        parsed_addresses.each do |email| 
          address = email.address
          address = Mail::Encodings.unquote_and_convert_to(address, "UTF-8") if address.include?("=?")
          if address =~ AccountConstants.email_regex
            parsed_email = $1.downcase

            next if ignore_emails.include?(parsed_email)
            plain_emails.push parsed_email            

            if email.name.present?
              email_name = email.name
              email_name = email.name.prepend(name) and name="" if name.present?
              emails.push "#{format_email_name(email_name)} <#{parsed_email}>".strip
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
        position = add =~ AccountConstants.email_regex
        if position
          email_address = $1.downcase
          next if ignore_emails.include?(email_address)
          name = name.present? ? name << add[0..position-1] : add[0..position-1]
          name.gsub!("<", "")
          name.gsub!(">", "")
          plain_emails.push email_address
          emails.push "#{format_email_name(name)}  <#{email_address}>"
          name = ""
        else
          name << "#{add} "
        end
      end
    end
    { :emails => emails.uniq, :plain_emails => plain_emails.uniq }
  end
    
  def format_email_name(name)
    (name =~ SPECIAL_CHARACTERS_REGEX and name !~ /".+"/) ? "\"#{name}\"" : name
  end

  def encode_non_usascii_q_val(address, charset)
    return address if address.ascii_only? or charset.nil?
    # Encode all strings embedded inside of quotes
    address = address.gsub(/("[^"]*")/) { |s| Mail::Encodings.q_value_encode(unquote(s), charset) }
    # Then loop through all remaining items and encode as needed
    tokens = address.split(/\s/)
    map_with_index(tokens) do |word, i|
      if word.ascii_only?
        word
      else
        previous_non_ascii = i>0 && tokens[i-1] && !tokens[i-1].ascii_only?
        if previous_non_ascii
          word = " #{word}"
        end
        Mail::Encodings.q_value_encode(word, charset)
      end
    end.join(' ')
  end

  def unquote( str )
    if str =~ /^"(.*?)"$/
      unescape($1)
    else
      str
    end
  end

  def unescape( str )
    str.gsub(/\\(.)/, '\1')
  end

  def map_with_index( enum, &block )
    results = []
    enum.each_with_index do |token, i|
      results[i] = yield(token, i)
    end
    results
  end

end
