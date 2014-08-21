module Helpdesk::Email::TicketMethods
  include Redis::RedisKeys
  include Redis::OthersRedis
  include ParserUtil

  def get_original_user
    e_email = orig_email_from_text
    get_user(e_email , email[:email_config], email[:text]) unless e_email.nil?
  end

  def orig_email_from_text #To process mails fwd'ed from agents
    content = email[:text] || email[:description_html]
    if (content && (content.gsub("\r\n", "\n") =~ /^>*\s*From:\s*(.*)\s+<(.*)>$/ or 
                          content.gsub("\r\n", "\n") =~ /^\s*From:\s(.*)\s+\[mailto:(.*)\]/ or  
                          content.gsub("\r\n", "\n") =~ /^>>>+\s(.*)\s+<(.*)>$/))
      name = $1
      email = $2
      if email =~ EMAIL_REGEX
        { :name => name, :email => $1 }
      end
    end
  end

  def current_agent?
    user.agent? && !user.deleted?
  end

  def create_ticket_object
    self.ticket = Helpdesk::Ticket.new(
        :account_id => account.id,
        :subject => email[:subject],
        :ticket_body_attributes => {
                      :description => email[:text], 
                      :description_html => email[:description_html]
        },
        :requester => user,
        :to_email => email[:to][:email],
        :to_emails => email[:to_emails],
        :cc_email => hash_cc_emails,
        :email_config => email[:email_config],
        :status => Helpdesk::Ticketfields::TicketStatus::OPEN,
        :source => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email]
      )
    ticket.sender_email = email[:from][:email]
  end

  def hash_cc_emails
    #Using .dup as otherwise its stored in reference format(&id0001 & *id001).
    {:cc_emails => email[:cc], :fwd_emails => [], :reply_cc => email[:cc].dup}
  end

  def check_valid_ticket
    check_for_chat_sources
    check_for_spam
    check_for_auto_responders
    check_support_emails_from
  end

  def check_for_chat_sources
    set_chat_source
    if snap_engage?
      chat_email =  email[:subject].scan(EMAIL_REGEX).uniq.first
      ticket.email = chat_email unless chat_email.blank? && (chat_email == "unknown@example.com")
    end
  end

  def set_chat_source
    ticket.source = Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:chat] if Helpdesk::Ticket::CHAT_SOURCES.has_value?(email[:from][:domain])
  end

  def snap_engage?
    email[:from][:domain] == Helpdesk::Ticket::CHAT_SOURCES[:snapengage]
  end

  def check_for_spam
    ticket.spam = true if ticket.requester.deleted?
  end

  def check_for_auto_responders
    ticket.skip_notification = true if auto_responder?(email[:headers])
  end

  def auto_responder?(headers)
    headers.present? && ((headers =~ /Auto-Submitted: auto-(.)+/i) || (headers =~ /Precedence: auto_reply/) || ((headers =~ /Precedence: (bulk|junk)/i) && (headers =~ /Reply-To: <>/i) ))
  end

  def check_support_emails_from
    ticket.skip_notification = true if user && account.support_emails.any? {|email| email.casecmp(user.email) == 0}
  end

  def finalize_ticket_save
    ticket_message_id = header_processor.zendesk_email || header_processor.message_id
    begin
      header_info_update(ticket_message_id)
      ticket.save_ticket!
    rescue ActiveRecord::RecordInvalid => e
      FreshdeskErrorsMailer.error_email(ticket,email,e)
    end
    create_redis_key_for_ticket(ticket_message_id) unless ticket_message_id.nil?
  end

  def header_processor
    @header_processor ||= Helpdesk::Email::ProcessByMessageId.new(email[:message_id], email[:in_reply_to], email[:references])
  end

  def header_info_update ticket_message_id
    (ticket.header_info ||= {}).merge!(:message_ids => [ticket_message_id]) unless ticket_message_id.nil?
  end

  def create_redis_key_for_ticket ticket_message_id
    set_others_redis_key(header_processor.message_key(account, ticket_message_id), ticket.display_id, 86400 * 7)
  end

end