module Helpdesk::EmailParser::MailProcessingUtil
  
	include DevNotification
  include Helpdesk::EmailParser::Constants

  def valid_charset(mail_content)
    if mail_content.try(:charset) # check whether else condition is required if no charset is available
    		return ENCODING_MAPPING[mail_content.charset.upcase] if ENCODING_MAPPING[mail_content.charset.upcase]
    		return mail_content.charset if is_default_charset(mail_content.charset)
    		"UTF-8"
  	end
  end

  def is_default_charset(charset)
    DEFAULT_ENCODING_FORMATS.include?(charset.upcase)
  end

	def encode_data(mail_data, detected_encoding="UTF-8")
  	res = mail_data.force_encoding(detected_encoding).encode("UTF-8")
    if !res.valid_encoding?
      email_parsing_log "Detected invalid encoding characters!!"
      res = handle_undefined_characters(mail_data, detected_encoding)
    end
    return res
    rescue Exception => e
      #proper info required
  	 email_parsing_log "Encoding error : #{e.class}, #{e.message}, #{e.backtrace}"
  	 # presence of undefined characters in mail_data causes encode("UTF-8") to fail
  	 handle_undefined_characters(mail_data, detected_encoding)
  end

  def encode_header_data(mail_data, detected_encoding="us-ascii")
    if detected_encoding.present?
      res = mail_data.force_encoding(detected_encoding).encode("UTF-8")
    else
      detection = CharlockHolmes::EncodingDetector.detect(mail_data)
      email_parsing_log "Unable to detect encoding type" if detection.nil?
      detected_encoding = detection.nil? ? "us-ascii" : detection[:encoding]
      res = mail_data.force_encoding(detected_encoding).encode("UTF-8")
    end
    if !res.valid_encoding?
      email_parsing_log "Detected invalid encoding characters in header data!!"
      res = handle_undefined_characters(mail_data, detected_encoding)
    end
    return res
    rescue Exception => e
      #proper info required
     email_parsing_log "Encoding error : #{e.class}, #{e.message}, #{e.backtrace}"
     # presence of undefined characters in mail_data causes encode("UTF-8") to fail
     handle_undefined_characters(mail_data, detected_encoding)
  end

  def handle_undefined_characters(mail_data, detected_encoding)
  	mail_data.force_encoding(detected_encoding).encode(Encoding::UTF_8, :undef => :replace, 
                                                                      :invalid => :replace, 
                                                                        :replace => '')
    rescue Exception => e
      #proper info required
  	
  	   mail_data.force_encoding("UTF-8").encode(Encoding::UTF_8, :undef => :replace, 
                                                                      :invalid => :replace, 
                                                                      :replace => '')
  end

  def text_to_html(body)
    result_string = ""
    body.each_char.with_index do |char, i|
      case (char)
        when "&"
          result_string << "&amp;"
        when "<"
          result_string << "&lt;"
        when ">"
          result_string << "&gt;"
        when "\t"
          result_string << "&nbsp;&nbsp;&nbsp;&nbsp;"
        when "\n"
          result_string << "<br>"
        when "\""
          result_string << "&quot;"
        when "\'"
          result_string << "&#39;"
        else
          result_string << char
      end
    end
    "<p>" + result_string + "</p>"
  end

  def email_parsing_log msg
    Rails.logger.info "#{Time.now.utc} - #{Thread.current.object_id} -  - #{msg} "
  end

  def parse_content_ids(content)
      regex = /((src=)(\")(cid:)(.*?)(\"))/
      cids  = content.scan(regex).map {|m| m[4].to_s}
  end

end

