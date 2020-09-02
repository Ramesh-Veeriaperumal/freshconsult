module UnicodeSanitizer

  EMOJI_ENCODING_TIMEOUT = 5

  def self.encode_emoji(item, *elements)
    Timeout.timeout(EMOJI_ENCODING_TIMEOUT) do
      elements.flatten!
      elements.each do |body|
        item.safe_send("#{body}_html=", utf84b_html_c(item.safe_send("#{body}_html")))
        item.safe_send("#{body}=", remove_4byte_chars(item.safe_send(body)))
      end
    end
  rescue TimeoutError => e
    NewRelic::Agent.notice_error(e, description: 'TimeoutError occured while encoding emoji')
    raise
  end

  def self.encode_emoji_hash(attributes, key, *elements)
    return attributes if attributes.blank?

    begin
      Timeout.timeout(EMOJI_ENCODING_TIMEOUT) do
        elements.each do |ele|
          attributes[key][ele] = remove_4byte_chars(attributes[key][ele]) if attributes[key][ele]
          attributes[key][ele + '_html'] = utf84b_html_c(attributes[key][ele + '_html']) if attributes[key][ele + '_html']
        end if attributes[key]
      end
    rescue TimeoutError => e
      NewRelic::Agent.notice_error(e, description: 'TimeoutError occured while encoding emoji')
      raise
    end
    attributes
  end

  def self.utf84b_html_c(content)
    if !content.nil?
      j = []
      content.each_char do |i|
        if i.bytesize > 3
          j.push('&#')
          j.push(i.unpack('U*')) # "a".ord.to_s(16) "a".ord puts "\u{65}" 124.chr
          j.push(';')
        else
          j.push(i)
        end
      end
      j.join
    else
      content
    end
  rescue StandardError => e
    Rails.logger.info "Exception while utf84b_html_c : #{e.message} : #{e.backtrace}"
    content
  end

  def self.remove_4byte_chars(content)
    if !content.nil?
      j = []
      content.each_char do |i|
        i.bytesize > 3 ? j.push('?') : j.push(i)
      end
      j.join
    else
      content
    end
  rescue StandardError => e
    Rails.logger.info "Exception while remove_utf84b : #{e.message} : #{e.backtrace}"
    content
  end
end
