module Helpdesk::StringUtil
    
  def show_quoted_text(text, address)
      
    return text if text.blank?
    
    regex_arr = [
      Regexp.new("From:\s*" + Regexp.escape(address), Regexp::IGNORECASE),
      Regexp.new("<" + Regexp.escape(address) + ">", Regexp::IGNORECASE),
      Regexp.new(Regexp.escape(address) + "\s+wrote:", Regexp::IGNORECASE),   
      Regexp.new("\\n.*.\d.*." + Regexp.escape(address) ),
      Regexp.new("On.*?wrote:"),
      Regexp.new("-+original\s+message-+\s*", Regexp::IGNORECASE),
      Regexp.new("from:\s*", Regexp::IGNORECASE)
    ]
    tl = text.length
    #calculates the matching regex closest to top of page
    index = regex_arr.inject(tl) do |min, regex|
        (text.index(regex) or tl) < min ? (text.index(regex) or tl) : min
    end
    
    original_msg = text[0, index]
    old_msg = text[index,text.size]
    #Sanitizing the split code   
    original_msg = Nokogiri::HTML(original_msg).at_css("body").inner_html
    old_msg  = sanitize_old_msg(old_msg) unless old_msg.blank?

    unless old_msg.blank?
     original_msg = original_msg +
     "<div class='freshdesk_quote'>" +
     "<blockquote class='freshdesk_quote'>" + old_msg + "</blockquote>" +
     "</div>"
    end   
    return original_msg
end


 def sanitize_old_msg html
      doc = Nokogiri::HTML(html)
      begin
        doc.css("blockquote").each_with_index do |node , index|
          node.remove if index > 0
        end
      rescue
      end
    html = doc.at_css("body").inner_html 
    return html
 end
end