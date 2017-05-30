require 'mail'
require 'timeout'

class Helpdesk::EmailParser::ProcessedMail

	include Helpdesk::EmailParser::MailProcessingUtil
	include Helpdesk::EmailParser::EmailParseError

	attr_accessor :raw_eml, :mail, :from, :to, :cc , :subject, :text, :html, :header, :header_string, :attachments, :message_id, :references, :in_reply_to, :date, :mail_header_default_charset

	SUBJECT_PATTERN = /(=\?.*?\?[QB]\?.*?\?=)/
	ENCODED_VALUE = /\=\?([^?]+)\?([QB])\?[^?]*?\?\=/mi

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
		fetch_text_html_and_attachment
		fetch_header_content
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
		from_addr = ""
		begin
			from_addr = mail[:from].to_s
			if mail[:from].value =~ ENCODED_VALUE
				return from_addr
			else
				return encode_header_data(from_addr, self.mail_header_default_charset)
			end
		rescue Exception => e
			begin
				Rails.logger.info "Exception while fetching from address from parsed email object - #{e.message} - #{e.backtrace}"
				from_addr = mail.from.to_s
				return encode_header_data(from_addr, self.mail_header_default_charset)
			rescue Exception => e
				replace_invalid_characters
				from_addr = @encoded_header[:from].to_s
				return from_addr
			end
		end
	end

	def get_to_address
		to_addr = ""
		begin
			#mail.to returns address container[Array]. Contact name will not come only email addresses will be returned, so encoding unquote_and_convert will not be required ideally
			to_addr = mail.to.blank? ? mail.header['Delivered-To'].to_s : ((mail.to.kind_of? String) ? mail.to : mail.to.join(',')) 
			return encode_header_data(to_addr, self.mail_header_default_charset)
		rescue Exception => e
			Rails.logger.info "Exception while fetching to address from parsed email object - #{e.message} - #{e.backtrace}"
			replace_invalid_characters
			to_addr = @encoded_header.to.blank? ? @encoded_header.header['Delivered-To'].to_s : 
			((@encoded_header.to.kind_of? String) ? @encoded_header.to : @encoded_header.to.join(','))
			return to_addr
		end
	end

	def get_cc_address
		cc_addr = ""
		begin
			cc_addr = mail[:cc].to_s
			if mail[:cc].value =~ ENCODED_VALUE
				return cc_addr
			else
				return encode_header_data(cc_addr, self.mail_header_default_charset)
			end
		rescue Exception => e
			begin 
				Rails.logger.info "Exception while fetching cc address from parsed email object - #{e.message} - #{e.backtrace}"
				cc_addr = mail.cc.to_s
				return encode_header_data(cc_addr, self.mail_header_default_charset)
			rescue Exception => e
				replace_invalid_characters
				cc_addr = @encoded_header[:cc].to_s
				return cc_addr
			end
		end
	end

	def get_decoded_subject
		subject_field = nil
		begin
   	 	mail.header.fields.each {|f| subject_field = f if f.name == "Subject"}
   		rescue Exception => e
   			Rails.logger.info "Exception while fetching subject from parsed email object - #{e.message} - #{e.backtrace}"
   			replace_invalid_characters
   			@encoded_header.header.fields.each {|f| subject_field = f if f.name == "Subject"}
   		end

   		encoded_subject = subject_field ? subject_field.value : ""
    	subject = ""
    	if encoded_subject.index("=?")
    		subject = get_encoded_content_as_utf8(encoded_subject)
    		return subject
    	else
    		subject = mail.subject
    		return encode_header_data(subject.to_s, self.mail_header_default_charset)
    	end
	  	rescue Exception => e
	  		Rails.logger.info "Exception while converting subject #{e.message} - #{e.backtrace}"
	  		replace_invalid_characters
	  		return @encoded_header.subject
	end

	def get_encoded_content_as_utf8(encoded_content)
		val =""
    	es_split = encoded_content.split(SUBJECT_PATTERN)
    	es_split = es_split.reject { |str| str.blank? }
    	es_split.each do |line|
    		converted_content = ""
    		if line.index(SUBJECT_PATTERN)
    			converted_content = Mail::Encodings.unquote_and_convert_to(line, 'UTF-8')
    		else
    			converted_content = encode_header_data(line, self.mail_header_default_charset)
    		end
    		val = val + converted_content
    	end 
    	return val.to_s
	end

	def get_header
		mail.header
	rescue Exception => e
		Rails.logger.info "Exception while fetching header from parsed email object - #{e.message} - #{e.backtrace}"
		replace_invalid_characters
		@encoded_header.header
	end

	#should monitor and decide whether utf-8 encoding has to be done
	def get_header_data
		encode_header_data(mail.header.to_s)
	rescue Exception => e
		begin
  			mail.header.raw_source
  		rescue Exception => e
  			Rails.logger.info "Exception while fetching header from parsed email object - #{e.message} - #{e.backtrace}"
  			replace_invalid_characters
			@encoded_header.header.to_s
  		end
	end

	def get_message_id
		build_message_id(mail.message_id)
	end

	def get_date
		mail.date.to_formatted_s(:rfc822) if mail.date.present?
	end

	def get_in_reply_to
		if mail.in_reply_to.present?
			in_rep_to = mail.in_reply_to
			if in_rep_to.is_a?(String)
				return build_message_id(in_rep_to)
			elsif in_rep_to.is_a?(Array)
	        	return in_rep_to.map {|reply_to| build_message_id(reply_to) }.join(",")
			end
		end
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
        	if processed_part.text_charset.present?
        		default_charset = processed_part.text_charset
        		fetch_mail_header_default_charset(default_charset) unless self.mail_header_default_charset.present?
        	end

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

	def fetch_mail_header_default_charset(default_charset)
		if mail.charset.present?
			self.mail_header_default_charset = mail.charset
		elsif default_charset.present?
			self.mail_header_default_charset = default_charset
		end
	end

	def fetch_text_html_attachment_for_single_part
		processed_part = Helpdesk::EmailParser::ProcessedPart.new(mail)
		self.text << processed_part.text if processed_part.text.present?
		self.html << processed_part.html if processed_part.html.present?
        self.attachments.concat(processed_part.attachments) if processed_part.attachments.present?
        fetch_mail_header_default_charset(processed_part.text_charset) if processed_part.text_charset.present?
	end

	def decoded_mail_body()
    	mail.body.decoded
  	rescue Mail::UnknownEncodingType => e
    	email_parsing_log "Encoding error in mail body : #{mail.body.encoding}"
    	mail.body_encoding = "7bit"
    	mail.body.decoded
  	end

	def replace_invalid_characters
		if @encoded_header.blank?
			Rails.logger.info "Encoding invalid characters while parsing email"
			email_text = mail.header.raw_source.encode(Encoding::UTF_8, :undef => :replace,
				 :invalid => :replace, :replace => '?')
			@encoded_header = Mail.new(email_text)
		end
	end
	
end

