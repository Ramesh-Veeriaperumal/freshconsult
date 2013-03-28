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

  def scan_for_valid_email(email)
    if (email =~ /<(.+?)>/) 
      email 
    else 
      email.scan(VALID_EMAIL_REGEX).uniq[0]
    end
  end

  def fetch_valid_emails email_array
    unless email_array.blank?
      if email_array.is_a? String
        email_array = email_array.split(/,|;/)
      end
      email_array = email_array.collect do |email|  
        scanned_email = scan_for_valid_email(email)
        scanned_email.strip if scanned_email
      end
      email_array = email_array.compact.uniq
    else
      email_array = []
    end
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