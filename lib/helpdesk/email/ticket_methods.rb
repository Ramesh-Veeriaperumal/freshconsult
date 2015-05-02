module Helpdesk::Email::TicketMethods
  include Redis::RedisKeys
  include Redis::OthersRedis
  include ParserUtil
  include AccountConstants

  def get_original_user
    get_user(orig_email_from_text , email[:email_config], email[:text]) unless orig_email_from_text.blank?
  end

  def orig_email_from_text #To process mails fwd'ed from agents
    @orig_user ||= begin
      content = email[:text] || email[:description_html]
      if (content && (content.gsub("\r\n", "\n") =~ /^>*\s*From:\s*(.*)\s+<(.*)>$/ or 
                            content.gsub("\r\n", "\n") =~ /^\s*From:\s(.*)\s+\[mailto:(.*)\]/ or  
                            content.gsub("\r\n", "\n") =~ /^>>>+\s(.*)\s+<(.*)>$/))
        name = $1
        email = $2
        if email =~ EMAIL_REGEX
          return { :name => name, :email => $1 }
        end
      end
      {}
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

    if current_agent?
      ticket.sender_email = get_original_email || email[:from][:email]
      alter_forwarding_based_user       
    end
  end

  def alter_forwarding_based_user
    self.user = (get_original_user || user)
    ticket.requester = user
  end

  def get_original_email
    (orig_email_from_text.present?)  ? orig_email_from_text[:email] : nil
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
    headers.present? && check_headers_for_responders(Hash[JSON.parse(headers)])
  end

  def check_headers_for_responders header_hash
    (header_hash["Auto-Submitted"] =~ /auto-(.)+/i || header_hash["Precedence"] =~ /(bulk|junk|auto_reply)/i).present?
  end

  def check_support_emails_from
    ticket.skip_notification = true if user && account.support_emails.any? {|email| email.casecmp(user.email) == 0}
  end

  def finalize_ticket_save
    ticket_message_id = header_processor.zendesk_email || header_processor.message_id
    begin
      header_info_update(ticket_message_id)
      ticket.save_ticket!
      
      # Insert header to schema_less_ticket_dynamo
      begin
        Timeout::timeout(0.5) do
          dynamo_obj = Helpdesk::Email::SchemaLessTicketDynamo.new
          dynamo_obj['account_id'] = Account.current.id
          dynamo_obj['ticket_id'] = ticket.id
          dynamo_obj['headers'] = JSON.parse(self.email[:headers]).map{|x| "#{x[0]}: #{x[1]}" }.join("\n")
          dynamo_obj.save
        end
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
      
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