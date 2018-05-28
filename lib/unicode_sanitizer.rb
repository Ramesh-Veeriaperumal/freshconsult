module UnicodeSanitizer

  def self.encode_emoji(item, *elements)
    if Account.current.launched?(:encode_emoji)
      elements.flatten!
      elements.each do |body|
        item.safe_send("#{body}_html=", utf84b_html_c(item.safe_send("#{body}_html")))
        item.safe_send("#{body}=", remove_4byte_chars(item.safe_send(body)))
      end
    end
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
