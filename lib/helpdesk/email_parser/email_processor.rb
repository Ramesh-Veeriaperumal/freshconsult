
class Helpdesk::EmailParser::EmailProcessor

	SET_CHARSETS = "{\"text\" : \"#{Encoding::UTF_8.to_s}\", \"html\" :\"#{Encoding::UTF_8.to_s}\"}"

	attr_accessor :raw_eml, :processed_mail

	def initialize(raw_eml)
		self.raw_eml = raw_eml
	end

	def process_mail
		self.processed_mail = Helpdesk::EmailParser::ProcessedMail.new(raw_eml)
		ticket_params = get_ticket_params
		return ticket_params
	end

	def get_processed_mail
		self.processed_mail ||= process_mail
	end

	private

	def get_ticket_params
	  	ticket_params = Hash.new
	    content_params = get_content_parameters(processed_mail)
	    ticket_params.merge!(content_params) if content_params.present?

	    uid_fetch_params = get_uid_fetch_parameters(processed_mail)
	    ticket_params.merge!(uid_fetch_params)

	    attachment_params = get_attachment_parameters(processed_mail)
	    ticket_params.merge!(attachment_params) if attachment_params.present?

	    ticket_params = ticket_params.with_indifferent_access
	    Rails.logger.info "Processed Params : #{ticket_params.inspect}"
	    
	    return ticket_params
  	rescue => e
    	Rails.logger.error "Error while parsing the mail : #{e.message} - #{e.backtrace}"
	end

	def get_content_parameters(processed_mail) 
	    content_params = { 
	      :from          => processed_mail.from,
	      :to            => processed_mail.to,
	      :cc            => processed_mail.cc,
	      :subject       => processed_mail.subject,
	      :text          => processed_mail.text,
	      :html          => processed_mail.html,
	      :charsets      => SET_CHARSETS,
	      :headers       => processed_mail.header_string,    
	      :attachments   => processed_mail.attachments.size
	    }
	    return content_params
  	end

  	def get_uid_fetch_parameters(processed_mail)
    	uid_fetch_params = {
        	:message_id    => processed_mail.message_id,
	        :references    => processed_mail.references,
	        :in_reply_to   => processed_mail.in_reply_to,
	        :internal_date => processed_mail.date
	      } 
	    return uid_fetch_params
  	end

  	def get_attachment_parameters(processed_mail)
	    attachment_params = {
	      	"attachment-info".to_sym => {},
	      	"content-ids".to_sym => {}
	    }

	    processed_mail.attachments.each_with_index do |attachment, index|
	      	attachment_params[:"content-ids"]["#{attachment.content_id}"] = "attachment#{index+1}" if attachment.content_id
	      	attachment_params["attachment#{index+1}"] = attachment
	      	attachment_params[:"attachment-info"][:"attachment#{index+1}"] = { 
	        	:filename => attachment.original_filename, 
	        	:type => attachment.content_type }
	    end
	    
	    attachment_params[:"attachment-info"] = attachment_params[:"attachment-info"].to_json
	    attachment_params[:"content-ids"]     = attachment_params[:"content-ids"].to_json

	    return attachment_params
	end

end

