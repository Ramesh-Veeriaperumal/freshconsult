module Helpdesk::Email::NoteMethods

  include Helpdesk::Utils::ManageCcEmails
  include EmailHelper

  def build_note_object
    self.note = ticket.notes.build(note_params)     
    set_note_source
    set_note_category
    note.subject = Helpdesk::HTMLSanitizer.clean(email[:subject])
    check_for_auto_responders(note, email[:headers])
    check_support_emails_from(note, user, account)
  end

  def set_note_category
    note.schema_less_note.category = ::Helpdesk::Note::CATEGORIES[:third_party_response] if rsvp_to_fwd?
  end

  def set_note_source
    note.source = Account.current.helpdesk_sources.note_source_keys_by_token[(from_fwd_emails? or note.notable.agent_performed?(user) or rsvp_to_fwd?) ? "note" : "email"]
  end

  def rsvp_to_fwd?
    @rsvp_to_fwd ||= ((Account.current.features?(:threading_without_user_check) || (!ticket.cc_email.nil? && !ticket.cc_email[:cc_emails].nil? && ticket.cc_email[:cc_emails].include?(email[:from][:email])) || user.agent?) && reply_to_forward(header_processor.all_message_ids))
  end

  def note_params
    {
      :private => (from_fwd_emails? or reply_to_private_note?(header_processor.all_message_ids) or rsvp_to_fwd?),
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
      unless cc_email_hash_value.blank?
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
      :body => tokenize_emojis(email[:stripped_text]),
      :body_html => sanitize_note_message(email[:stripped_html]),
      :full_text => tokenize_emojis(email[:text]),
      :full_text_html => sanitize_note_message(email[:description_html])
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

  def sanitize_note_message msg
    sanitized_msg = run_with_timeout(NokogiriTimeoutError) { Nokogiri::HTML(msg).at_css("body") }
    remove_identifier_span(sanitized_msg) unless sanitized_msg.blank?
    remove_survey_div(sanitized_msg) unless sanitized_msg.blank?
    sanitized_msg.inner_html unless sanitized_msg.blank?
  end

  def remove_identifier_span msg
    id_span = msg.css("span[title='fd_tkt_identifier']") || select_id_span(msg)
    id_span.remove if id_span
  end

  def remove_survey_div msg
    survey_div = msg.css("div[title='freshdesk_satisfaction_survey']")
    survey_div.remove unless survey_div.blank?
  end

  def select_id_span msg
    msg.css("span[style]").select{|x| x.to_s.include?('fdtktid')}
  end

  def update_ticket_cc
    email[:cc].map!{ |val| parse_email(val.downcase)[:email]}
    ticket.cc_email = updated_ticket_cc_emails(email[:cc], ticket, note, 
      email[:in_reply_to], email[:to][:email], email[:to_emails])
  end
end
