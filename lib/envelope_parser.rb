module EnvelopeParser

	include AccountConstants
	include ParserUtil

    def parse_to_emails(params)
      	to_emails = []
      	envelope = params[:envelope]
      	if envelope.present?
        	to_emails.push(get_to_emails_from_envelope(envelope))
      	else
      		to_emails.push(parse_email_with_domain(params[:to]))
  		end
  		return to_emails.flatten
    end

    def get_to_emails_from_envelope(envelope)
    	to_emails = []
    	envelope_to = get_to_address_from_envelope(envelope)
        if multiple_envelope_to_address?(envelope_to)
    		envelope_to.each do |email|
      			to_emails.push(parse_email_with_domain(email))
      		end
        else
        	to_emails.push(parse_email_with_domain(envelope_to)) if envelope_to.present?
       	end
       	return to_emails.flatten
    end

    def multiple_envelope_to_address?(envelope_to)
      	if envelope_to.present? && envelope_to.is_a?(Array) && envelope_to.count > 1
  			return true
     	else
      		return false
      	end
    end

    def get_to_address_from_envelope(envelope)
    	(ActiveSupport::JSON.decode envelope)['to']
    end

    def get_domain_from_envelope(envelope)
      envelope_to = get_to_address_from_envelope(envelope).first
      parse_email_with_domain(envelope_to)[:domain]
    end

    def get_user_from_email(email_text)
      email = parse_email_text(email_text.strip)[:email]
      if(email && (email =~ EMAIL_REGEX))
        email = $1
      elsif(email_text =~ EMAIL_REGEX) 
        email = $1  
      end
      email
    end

end