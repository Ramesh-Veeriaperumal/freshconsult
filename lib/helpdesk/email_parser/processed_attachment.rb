require 'mail'
require 'timeout'

class Helpdesk::EmailParser::ProcessedAttachment

	include Helpdesk::EmailParser::MailProcessingUtil
	include Helpdesk::EmailParser::EmailParseError

	attr_accessor :part, :text, :html, :attachments

	def initialize(part, default_charset = DEFAULT_CHARSET)
		self.part = part
		self.default_charset = default_charset #workaround - to handle case with no proper encoding information
		self.text = ""
		self.html = ""
		self.attachments = []
		process_attachment
	end

	private

	def process_attachment
		return unless part.attachment?
		if(part.mime_type == TNEF_MIME_TYPE)
			fetch_html_attachment_from_tnef_content
		else
			fetch_attachment
		end
	rescue Helpdesk::EmailParser::ParseError => e
		raise e
	rescue => e 
		raise_parse_error "Error while parsing part for an attachment : #{e.message} - #{e.backtrace}"
	end

	def fetch_attachment 
		if(part.content_transfer_encoding && ["UUENCODE", "X-UUENCODE"].include?(part.content_transfer_encoding.upcase))
      		lines = /begin \d\d\d (.*)\r\nend/m.match(part.raw_source)[1].split /[\r\n]+/
      		encoded = lines[1..-2].join("\n")
      		attachment = Helpdesk::EmailParser::MailAttachment.new(encoded.unpack("u")[0])
      	elsif(part.content_transfer_encoding.upcase == "QUOTED-PRINTABLE")
      		attachment = Helpdesk::EmailParser::MailAttachment.new(part.decoded.unpack("M")[0])
    	else
      		attachment = Helpdesk::EmailParser::MailAttachment.new(part.decoded)
    	end
    	
    	attachment.is_inline_attachment = part.inline? if part.respond_to?(:inline?) 
    	attachment.original_filename = part.filename.strip unless part.filename.blank?
    	attachment.content_type = part.mime_type
    	attachment.content_id = part.content_id[1..-2] if part.content_id
    	self.attachments << attachment
    rescue => e
    	raise_parse_error "Error while parsing part for an attachment : #{e.message} - #{e.backtrace}"
	end

	def fetch_html_attachment_from_tnef_content
    	begin 
    		Tnef.unpack(part) do |file|
		        attachment = Helpdesk::EmailParser::MailAttachment.new(File.read(file))
		        unless MIME::Types.type_for(file)[0].nil?
		          attachment.content_type = MIME::Types.type_for(file)[0].content_type
		        else
		          attachment.content_type = "application/octet-stream"
		        end
		        attachment.original_filename = File.basename(file)

		        if attachment.original_filename == 'message.html'
		          self.html << encode_data(attachment.string, default_charset) 
		        else 
		          self.attachments << attachment
		        end
		    end
		    content_id_list = parse_content_ids(self.html)
		    self.attachments.each do |attachment|
		    	if content_id_list.present?
		    		matching_content_id = content_id_list.find{ |cid| cid.include?(attachment.original_filename) }
		    		attachment.content_id = matching_content_id if matching_content_id.present?
		    	end
		    end 
    	rescue =>e
    		#chk notify_error possibility here
    		email_parsing_log "Exception while extracting tnef content! : #{e.message} - #{e.backtrace}"
    		self.html = ""
			self.attachments = []
      		fetch_attachment
    	end
	end

	attr_accessor :default_charset
end