module ParserUtil

	def parse_email_text(email_text)
		if email_text =~ /(.+) <(.+?)>/
        	{:name => $1, :email => $2}
      	elsif email_text =~ /<(.+?)>/
       		{:name => "", :email => $1}
       	else
       		{:name => "", :email => email_text}	
      	end
	end
end