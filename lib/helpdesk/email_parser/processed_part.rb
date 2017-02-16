require 'mail'
require 'timeout'

class Helpdesk::EmailParser::ProcessedPart

	include Helpdesk::EmailParser::MailProcessingUtil
	include Helpdesk::EmailParser::EmailParseError

	attr_accessor :part, :text, :html, :attachments, :text_charset

	def initialize(part, default_charset = DEFAULT_CHARSET)
		self.part = part
		self.default_charset = default_charset
		self.text = ""
		self.html = ""
		self.attachments = []
		self.is_child_part = false
		self.is_delivery_status_part = false
		process_part
	end

	def is_child_part?
		is_child_part
	end

	def is_delivery_status_part?
		is_delivery_status_part
	end

	private

	def process_part
		return if part.multipart?
		if( part.attachment? )
          	fetch_attachment_from_part
        elsif(has_attachment_content_type?)
	        fetch_known_attachment_from_part
        elsif(part.mime_type == TEXT_MIME_TYPE)
          	fetch_text_from_part
        elsif(part.mime_type == HTML_MIME_TYPE)
          	fetch_html_from_part
        elsif(part.mime_type == RFC822_MIME_TYPE || part.mime_type == RFC822_HEADER_MIME_TYPE)
          	fetch_text_html_attachment_from_child_part
          	self.is_child_part = true
        elsif( part.respond_to?(:delivery_status_report_part?) && part.delivery_status_report_part? )
        	fetch_delivery_status_data
        	self.is_delivery_status_part = true
        elsif known_attachment_type?
        	fetch_known_attachment_from_part
        else
        	fetch_text_from_part
          	#to be decided - whether content shd be added as attachment or text
       	end
    rescue Helpdesk::EmailParser::ParseError => e
		raise e
	rescue => e 
		raise_parse_error "Error while parsing part: #{e.message} - #{e.backtrace}"
 	end

	def known_attachment_type?
    	unless part.content_type.nil?
      		return KNOWN_ATTACHMENT_CONTENT_TYPES.any?{|t| part.content_type.match(t)}
    	else
      		return false
    	end
  	end

  	def has_attachment_content_type?
	  	content_type = part.content_type rescue nil
     	content_disposition = part.content_disposition rescue nil
      	if content_type.present?
      		return true if content_type.match(/attachment/i).present?
      	end
      	if content_disposition.present?
      		return true if content_disposition.match(/attachment/i).present?
      	end
      	return false
	end

	def fetch_text_from_part
		self.text_charset = valid_charset(part) #workaround - to handle case with no proper encoding information
		self.text = encode_data(part.body.decoded, text_charset)
	rescue => e
		email_parsing_log "Error in fetch_text_from_part , message: #{e.message} - #{e.backtrace}"
		self.text_charset = valid_charset(part) #workaround - to handle case with no proper encoding information
		self.text = encode_data(part.body.raw_source, text_charset)
	end

	def fetch_html_from_part
		self.text_charset = valid_charset(part) #workaround - to handle case with no proper encoding information
		self.text_charset = get_charset_from_html_content if text_charset.blank?
		self.html = encode_data(part.body.decoded, text_charset)
		#self.text_charset = get_charset_from_html_content if text_charset.blank?
	rescue => e
		email_parsing_log "Error in fetch_html_from_part , message: #{e.message} - #{e.backtrace}"
		self.text_charset = valid_charset(part) #workaround - to handle case with no proper encoding information
		self.html = encode_data(part.body.raw_source, text_charset)
	end

	def get_charset_from_html_content
		decoded_body = part.body.decoded
		if decoded_body.present?
			limited_content = decoded_body[0..300]
			if limited_content =~ HTML_CONTENT_CHARSET_PATTERN1 || limited_content =~ HTML_CONTENT_CHARSET_PATTERN2
				charset = $1
				return ENCODING_MAPPING[mail_content.charset.upcase] if ENCODING_MAPPING[charset.upcase]
    			return charset if is_default_charset(charset)
			end
		end
		return nil
	rescue => e
		email_parsing_log "Error while fetching charset from html content : #{e.message} - #{e.backtrace}"
		return nil
	end

	def fetch_attachment_from_part
		processed_attachment = Helpdesk::EmailParser::ProcessedAttachment.new(part, default_charset)
		self.text = processed_attachment.text if processed_attachment.text.present?
		self.html = processed_attachment.html if processed_attachment.html.present?
		self.attachments = processed_attachment.attachments if processed_attachment.attachments.present?
	end

	def fetch_known_attachment_from_part
		if(part.content_transfer_encoding && ["UUENCODE", "X-UUENCODE"].include?(part.content_transfer_encoding.upcase))
      		lines = /begin \d\d\d (.*)\r\nend/m.match(part.raw_source)[1].split /[\r\n]+/
      		encoded = lines[1..-2].join("\n")
      		attachment = Helpdesk::EmailParser::MailAttachment.new(encoded.unpack("u")[0])
    	else
      		attachment = Helpdesk::EmailParser::MailAttachment.new(decoded_part_body)
    	end

    	filename = ""
    	if part.filename.present?
    		filename = part.filename.strip
    	else
    		extension = Rack::Mime::MIME_TYPES.invert[part.mime_type].to_s
    		extension = ".eml" if extension.downcase == '.mime'
    		filename = ('attachment' + extension )
    	end

    	attachment.original_filename = filename
    	attachment.content_type = part.mime_type
    	attachment.content_id = part.content_id if part.content_id
    	self.attachments << attachment
    rescue => e
	    raise_parse_error "Error while processing known attachment type part: #{e.message} - #{e.backtrace}"
    end

	#report part processing starts here

	def fetch_delivery_status_data
	    report_data = ""
	    action = get_delivery_status_data_values('action')
	    final_recipient = get_delivery_status_data_values('final-recipient')
	    diagnostic_code = get_delivery_status_data_values('diagnostic-code')
	    error_status = get_delivery_status_data_values('status')
	    if action.is_a?(Array)
	      count = action.length
	      index = 0
	      while index < count do
	        report_data << "Action: "+action[index]+"\r\n" if (action && action[index].present?)
	        report_data << "Final-Recipient: "+final_recipient[index]+"\r\n" if (final_recipient && final_recipient[index].present?)
	        report_data << "Diagnostic-Code: "+diagnostic_code[index]+"\r\n" if (diagnostic_code && diagnostic_code[index].present?)
	        report_data << "Status: "+error_status[index]+"\r\n" if (error_status && error_status[index].present?)
	        report_data << "\r\n"
	        index += 1
	      end
	    else
	      report_data << "Action: "+action+"\r\n" if action
	      report_data << "Final-Recipient: "+final_recipient+"\r\n" if final_recipient
	      report_data << "Diagnostic-Code: "+diagnostic_code+"\r\n" if diagnostic_code
	      report_data << "Status: "+error_status+"\r\n" if error_status
	    end
	    self.text = report_data
	    # self.html = text_to_html(report_data)
	rescue => e
	    raise_parse_error "Error while processing delivery status part data: #{e.message} - #{e.backtrace}"
	end

	#workaround to get key values from delivery_status_data instead of direct calls to action,diagnostic_code,
  	#error_status,etc.. required only for old mail gems . in latest 2.6 and above gems normal mail.action call should work
  	def get_delivery_status_data_values(key)
    	if part.delivery_status_report_part?
        	delivery_status_data = part.delivery_status_data
        	if delivery_status_data[key].is_a?(Array)
          		delivery_status_data[key].map { |a| a.value }
        	elsif !delivery_status_data[key].nil?
          		delivery_status_data[key].value
        	else
          		nil
        	end
    	end
  	end

  	#report part processing ends here

  	def fetch_text_html_attachment_from_child_part
		child_mail_eml = part.body
		processed_child_mail = Helpdesk::EmailParser::ProcessedMail.new(child_mail_eml)
		fetch_text_for_child_part(processed_child_mail)
		fetch_html_for_child_part(processed_child_mail)
		self.attachments = processed_child_mail.attachments if processed_child_mail.attachments.present?
	rescue Helpdesk::EmailParser::ParseError => e
		raise e
	rescue => e 
		raise_parse_error "Error while parsing child RFC822 part: #{e.message} - #{e.backtrace}"
	end

  	def fetch_text_for_child_part(processed_mail)
  		self.text << "\r\n----- Original message -----"+"\r\n"
		self.text << processed_mail.header_string + "\r\n \r\n" if processed_mail.header_string.present?
		self.text << processed_mail.text if processed_mail.text.present?
  	end

  	def fetch_html_for_child_part(processed_mail)
  		if processed_mail.html.present?
  			html_content = ""
			html_content << "\r\n----- Original message -----"+"\r\n"
			html_content << "From:" + processed_mail.from + "\r\n"
			html_content << "To:" + processed_mail.to + "\r\n"
			html_content << "CC:" + processed_mail.cc + "\r\n"
			html_content << "Date:" + processed_mail.date + "\r\n"
			html_content << "Subject:" + processed_mail.subject + "\r\n \r\n"
			self.html << text_to_html(html_content)
			self.html << processed_mail.html if processed_mail.html.present?
		end
  	end

  	def decoded_part_body
    	part.body.decoded
  	rescue Mail::UnknownEncodingType => e
    	email_parsing_log "Encoding error in part body : #{part.body.encoding}"
    	part.body_encoding = "7bit"
    	part.body.decoded
  	end

  	attr_accessor :is_child_part, :is_delivery_status_part, :default_charset

end

