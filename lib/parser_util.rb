module ParserUtil

VALID_EMAIL_REGEX = /\b[-a-zA-Z0-9.'’_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b/

	def parse_email_text(email_text)
		if email_text =~ /"?(.+?)"?\s+<(.+?)>/
    	{:name => $1.tr('"',''), :email => $2}
  	elsif email_text =~ /<(.+?)>/
   		{:name => "", :email => $1}
   	else
   		{:name => "", :email => email_text}	
  	end
	end
  
  def parse_to_comma_sep_emails(emails)
    emails.map { |email| parse_email_text(email)[:email] }.join(", ") 
  end

  def fetch_valid_emails(addresses)
    if addresses.is_a? String
      addresses = addresses.split(/,|;/)
    end
     
    addresses = addresses.collect do |address|
      next if address.blank?
      address = address.gsub('"','').gsub("'",'')

      matches = address.strip.scan(/(\w[^<\>]*)<(\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,10}\b)\>\z|\A<!--?((\b[A-Z0-9._%+-]+)@[A-Z0-9.-]+\.[A-Z]{2,10}\b)-->?\z/i)
      
      if matches[0] && matches[0][1]
        email = matches[0][1]
        name = matches[0][0]
      elsif matches[0] && matches[0][2]
        email = matches[0][2]
        name = matches [0][3]
      else
        # Validating plain email addresses,
        simple_email_regex = /\b[-a-zA-Z0-9.'’_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,10}\b/
        simple_email  = address.scan(simple_email_regex)
        if simple_email
          email = simple_email[0]
          name = ""
        end
    end
      unless email.blank? and name.blank?
        "#{name.gsub(/\./, ' ').strip} <#{email.downcase.strip}>".strip
      end
    end
    addresses.compact.uniq
  end

  def validate_emails(email_array, ticket = @parent)
    unless email_array.blank?
      if email_array.is_a? String
        email_array = email_array.split(/,|;/)
      end
        email_array.delete_if {|x| (extract_email(x) == ticket.requester.email or !(valid_email?(x))) }
        email_array = email_array.collect{|e| e.gsub(/\,/,"")}
        email_array = email_array.uniq
    end
  end
    
  def extract_email(email)
    email = $1 if email =~ /<(.+?)>/
    email
  end
    
  def valid_email?(email)
    email = extract_email(email)
    (email =~ VALID_EMAIL_REGEX) ? true : false
  end

  
end