require 'mail'
require 'timeout'

class Helpdesk::EmailParser::ProcessedMail

	include Helpdesk::EmailParser::MailProcessingUtil
	include Helpdesk::EmailParser::EmailParseError

	attr_accessor :raw_eml, :mail, :from, :to, :cc , :subject, :text, :html, :header, :header_string, :attachments, :message_id, :references, :in_reply_to, :date

	def initialize(raw_eml)
		self.raw_eml = raw_eml
		self.mail = Mail.new(raw_eml)
		self.text = ""
		self.html = ""
		self.attachments = []
		process_content
	end

	def get_header_field(field_name)
		header[field_name].to_s
	end

private

	def process_content
		fetch_header_content
		fetch_text_html_and_attachment
	rescue Helpdesk::EmailParser::ParseError => e
		raise e
	rescue => e 
		raise_parse_error "Error while processing part: #{e.message} - #{e.backtrace}" 	
	end

	def fetch_header_content
		self.from = get_from_address
		self.to = get_to_address
		self.cc = get_cc_address
		self.subject = get_decoded_subject
		self.header = get_header
		self.header_string = get_header_data
		self.message_id = get_message_id
		self.date = get_date
		self.in_reply_to = get_in_reply_to
		self.references = get_references
	end

	def get_from_address
		mail[:from].to_s
	end

	def get_to_address
		mail.to.blank? ? mail.header['Delivered-To'].to_s : ((mail.to.kind_of? String) ? mail.to : mail.to.join(','))
	end

	def get_cc_address
		mail[:cc].to_s
	end

	def get_decoded_subject
		subject_field = nil
   	 	mail.header.fields.each {|f| subject_field = f if f.name == "Subject"}
    	encoded_subject = subject_field ? subject_field.value : ""
    	subject = encoded_subject.index("=?") ? Mail::Encodings.unquote_and_convert_to(encoded_subject, 'UTF-8') : mail.subject
	end

	def get_header
		mail.header
	end

	def get_header_data
		mail.header.to_s
  	rescue Exception => e
    	mail.header.raw_source
	end

	def get_message_id
		build_message_id(mail.message_id)
	end

	def get_date
		mail.date.to_formatted_s(:rfc822) if mail.date.present?
	end

	def get_in_reply_to
		build_message_id(mail.in_reply_to)
	end

	def get_references
	    if mail.references.present?
	    	references = mail.references
	      	if references.is_a?(String) 
	        	return build_message_id(references)
	      	elsif references.is_a?(Array)
	        	return references.map {|reference| build_message_id(reference) }.join(",")
	      	end
	    end
  	end

  	def is_enclosed_by_brackets?(str)
    	str.match(/<([^<>]+)>/) if str.present?
  	end

  	def build_message_id(reference_text)
    	is_enclosed_by_brackets?(reference_text) ? reference_text : enclose_with_brackets(reference_text)
  	end

  	def enclose_with_brackets(str)
    	"<" << str << ">" if str.present?
  	end

	def regular_mail_with_attachment?
		parts_count = (mail.text_part ? 1 : 0) + (mail.html_part ? 1 : 0) + mail.attachments.count
		(mail.parts.count != 0) && (mail.parts.count == parts_count) 
	end

	def fetch_text_html_and_attachment
		if mail.multipart?
			#do parsing
			fetch_text_html_attachment_for_all_parts
		else
			fetch_text_html_attachment_for_single_part
		end
	end

	def fetch_text_html_attachment_for_all_parts
		default_charset = DEFAULT_CHARSET #workaround - to handle case with no proper encoding information
		mail.all_parts.each do |p| 

        	processed_part = Helpdesk::EmailParser::ProcessedPart.new(p, default_charset)
        	default_charset = processed_part.text_charset if processed_part.text_charset.present?

        	#if part is a delivery status part and there is some html content ,then the delivery status text is added to html content
        	#if there is no html content, then delivery status text will be added to text content and eventually should be added to html if required 
        	if processed_part.is_delivery_status_part?
        		self.html << text_to_html(processed_part.text) if  self.html.present?
        	end
        	#if part is a child part and there is some text content and no html content ,then the text content is added as html content
        	if processed_part.html.present?
        		if ((processed_part.is_child_part?) && (!self.html.present?) && (self.text.present?))
        			self.html << text_to_html(self.text)
        		end
        		self.html << processed_part.html + "<br>"
        	end
        	self.text << processed_part.text + "\r\n" if processed_part.text.present?
        	self.attachments.concat(processed_part.attachments) if processed_part.attachments.present?
      	end
    rescue Helpdesk::EmailParser::ParseError => e
		raise e
	rescue => e 
		raise_parse_error "Error while processing part: #{e.message} - #{e.backtrace}" 
	end

	def fetch_text_html_attachment_for_single_part
		processed_part = Helpdesk::EmailParser::ProcessedPart.new(mail)
		self.text << processed_part.text if processed_part.text.present?
		self.html << processed_part.html if processed_part.html.present?
        self.attachments.concat(processed_part.attachments) if processed_part.attachments.present?
	end

	def decoded_mail_body()
    	mail.body.decoded
  	rescue Mail::UnknownEncodingType => e
    	email_parsing_log "Encoding error in mail body : #{mail.body.encoding}"
    	mail.body_encoding = "7bit"
    	mail.body.decoded
  	end
	
end

