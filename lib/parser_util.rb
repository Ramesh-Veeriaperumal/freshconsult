module ParserUtil

#EMAIL_REGEX      = /(\b(?:([\x81-\x9f\xe0-\xef][\x40-\x7e\x80-\xfc])*([\xa1-\xfe][\xa1-\xfe])*([\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf][\x80-\xbf])*([A-Z0-9_\.%\+\-\'=])*)+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,4})\b)/i
#EMAIL_REGEX_USER = /(\A(?:([\x81-\x9f\xe0-\xef][\x40-\x7e\x80-\xfc])*([\xa1-\xfe][\xa1-\xfe])*([\xc0-\xdf][\x80-\xbf]|[\xe0-\xef][\x80-\xbf][\x80-\xbf])*([A-Z0-9_\.%\+\-\'=])*)+@(?:[A-Z0-9\-]+\.)+(?:[A-Z]{2,4})\z)/i

VALID_EMAIL_REGEX = /\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b/

	def parse_email_text(email_text)
		if email_text =~ /(.+) <(.+?)>/
        	{:name => $1, :email => $2}
      	elsif email_text =~ /<(.+?)>/
       		{:name => "", :email => $1}
       	#elsif email_text =~ EMAIL_REGEX
       		#{:name => "", :email => $1}
       	else
       		{:name => "", :email => email_text}	
      	end
	end
  
  def parse_to_comma_sep_emails(emails)
    emails.map { |email| parse_email_text(email)[:email] }.join(", ") 
  end
  
end