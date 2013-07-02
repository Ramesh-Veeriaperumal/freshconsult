module Helpdesk::TicketElasticSearchMethods
	
	def self.included(base)
		base.class_eval do
		
		def es_flexifield_columns
	    @@es_flexi_txt_cols ||= Flexifield.column_names.select {|v| v =~ /^ff(s|_text)/}
	  end

  	def es_notes
	    body = []
		    public_notes.each do |note|
	      note_attachments =[]
	      note.attachments.each do |attachment|
	        note_attachments.push(attachment.content_file_name)
	      end
	      body.push( :body => note.body, :private => note.private, :attachments => note_attachments )
	    end
	    body
	  end

	  def es_from
	    if source == TicketConstants::SOURCE_KEYS_BY_TOKEN[:twitter]
	      requester.twitter_id
	    elsif source == TicketConstants::SOURCE_KEYS_BY_TOKEN[:facebook]
	      requester.fb_profile_id
	    else
	      from_email
	    end
	  end

	  def es_cc_emails
	    cc_email_hash[:cc_emails] if cc_email_hash
	  end

	  def es_fwd_emails
	    cc_email_hash[:fwd_emails] if cc_email_hash
	  end
	 
	 	end
	end

end