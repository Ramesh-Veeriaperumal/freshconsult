module Helpdesk::Email::NoteMethods

  include Helpdesk::Utils::ManageCcEmails

  def build_note_object
    self.note = ticket.notes.build(note_params)     
    set_note_source
    note.subject = Helpdesk::HTMLSanitizer.clean(email[:subject])
  end

  def set_note_source
    note.source = Helpdesk::Note::SOURCE_KEYS_BY_TOKEN[(from_fwd_emails? or user.agent?) ? "note" : "email"]
  end

  def note_params
    {
      :private => (from_fwd_emails? and user.customer?),
      :incoming => true,
      :note_body_attributes => separate_quoted_text ,
      :user => user, #by Shan temp
      :account_id => account.id,
      :from_email => email[:from][:email],
      :to_emails => email[:to_emails],
      :cc_emails => email[:cc]
    }
  end

  def from_fwd_emails?
    @from_fwd_emails ||= begin
      cc_email_hash_value = ticket.cc_email_hash
      unless cc_email_hash_value.nil?
        cc_email_hash_value[:fwd_emails].any? {|f_email| f_email.include?(email[:from][:email]) }
      else
        false
      end
    end
	end

  def separate_quoted_text
    # msg_hash = {}
    # # for plain text
    # plain = show_quoted_text(email[:text]) || {}
    # # for html text
    # html = show_quoted_text(email[:description_html], false) || {}
    
    {
      :body => email[:stripped_text], 
      :body_html => sanitize_message(email[:stripped_html]), 
      :full_text => email[:text], 
      :full_text_html => sanitize_message(email[:description_html])
    }
  end

  # def show_quoted_text(text, plain=true)
  #   return text if text.blank?
  #   address = ticket.reply_email
  #   regex_arr = construct_regex_array(Regexp.escape(address))
  #   tl = text.length
  #   #calculates the matching regex closest to top of page
  #   index = regex_arr.inject(tl) do |min, regex|
  #       (text.index(regex) or tl) < min ? (text.index(regex) or tl) : min
  #   end
  #   return get_body_and_full_text(text, index, plain)
  # end

  # def construct_regex_array address
  #   [
  #     Regexp.new("From:\s*" + address, Regexp::IGNORECASE),
  #     Regexp.new("<" + address + ">", Regexp::IGNORECASE),
  #     Regexp.new(address + "\s+wrote:", Regexp::IGNORECASE),   
  #     Regexp.new("\\n.*.\d.*." + address ),
  #     Regexp.new("<div>\n<br>On.*?wrote:"), #iphone
  #     Regexp.new("On.*?wrote:"),
  #     Regexp.new("-+original\s+message-+\s*", Regexp::IGNORECASE),
  #     Regexp.new("from:\s*", Regexp::IGNORECASE)
  #   ]
  # end

  # def get_body_and_full_text text, index, plain
  #   original_msg = text[0, index]
  #   old_msg = text[index,text.size]
    
  #   return  {:body => original_msg, :full_text => text } if plain
  #   #Sanitizing the original msg and old msg

  #   original_msg = sanitize_message(original_msg) unless original_msg.blank?
  #   old_msg = sanitize_message(old_msg) unless old_msg.blank?
      
  #   full_text = get_full_text(original_msg, old_msg)
  #   {:body => full_text, :full_text => full_text}  #temp fix made for showing quoted text in incoming conversations
  # end

  # def get_full_text original_msg, old_msg
  #   return original_msg if old_msg.blank?
  #   %(#{original_msg}<div class='freshdesk_quote'><blockquote class='freshdesk_quote'>#{old_msg}</blockquote></div>)
  # end

  def sanitize_message msg
    sanitized_msg = Nokogiri::HTML(msg).at_css("body")
    remove_identifier_span(sanitized_msg)
    sanitized_msg.inner_html unless sanitized_msg.blank? 
  end

  def remove_identifier_span msg
    id_span = msg.css("span[title='fd_tkt_identifier']") || select_id_span(msg)
    id_span.remove if id_span
  end

  def select_id_span msg
    msg.css("span[style]").select{|x| x.to_s.include?('fdtktid')}
  end

  def update_ticket_cc
    cc_email = ticket.cc_email_hash || {:cc_emails => [], :fwd_emails => []}
    cc_emails_val = filter_cc_emails(account, (email[:to_emails] | email[:cc]), ticket.requester.email)
    cc_email[:cc_emails] = cc_emails_val | cc_email[:cc_emails].compact.collect! {|x| (parse_email x)[:email]}
    ticket.cc_email = cc_email
  end
end