module Helpdesk::Email::TicketMethods
  include Redis::RedisKeys
  include Redis::OthersRedis
  include ParserUtil
  include AccountConstants
  include EmailHelper
  include Helpdesk::ProcessAgentForwardedEmail

  def get_original_user
    email_from_text = account.disable_agent_forward_enabled? ? {} : orig_email_from_text
    unless email_from_text.blank?
      self.original_sender = email_from_text[:email]
      email_from_text[:cc_emails].reject!{ |cc_email| kbase_email?(cc_email) or requester_email?(cc_email) }
      email[:cc].concat(email_from_text[:cc_emails]).uniq!
      email[:to_emails].concat(email_from_text[:cc_emails])
      get_user(email_from_text , email[:email_config], email[:text], true)
    end
  end

  def orig_email_from_text #To process mails fwd'ed from agents
    content = email[:text] || email[:description_html]
    identify_original_requestor(content)
  end

  def current_agent?
    user.agent? && !user.deleted?
  end

  def create_ticket_object
    alter_forwarding_based_user if current_agent?

    self.ticket = Helpdesk::Ticket.new(
        :account_id => account.id,
        :subject => email[:subject],
        :ticket_body_attributes => {
            description:      email[:text],
            description_html: email[:description_html]
        },
        :requester => user,
        :to_email => email[:to][:email],
        :to_emails => email[:to_emails],
        :cc_email => hash_cc_emails,
        :email_config => email[:email_config],
        :status => Helpdesk::Ticketfields::TicketStatus::OPEN,
        :source => Helpdesk::Source::EMAIL
      )
    self.ticket.build_archive_child(:archive_ticket_id => archive_ticket.id) if archive_ticket
    ticket.sender_email = self.original_sender
  end

  def alter_forwarding_based_user
    self.user = (get_original_user || user)
  end

  def hash_cc_emails
    #Using .dup as otherwise its stored in reference format(&id0001 & *id001).
    {:cc_emails => global_cc.dup, :fwd_emails => [],
      :bcc_emails => [], :reply_cc => global_cc.dup, :tkt_cc =>  email[:cc].dup}
  end

  def check_valid_ticket
    check_for_chat_sources
    check_for_spam
    check_for_auto_responders(ticket, email[:headers])
    check_support_emails_from(ticket, user, account)
  end

  def check_for_chat_sources
    set_chat_source
    if snap_engage?
      chat_email =  email[:subject].scan(EMAIL_REGEX).uniq.first
      ticket.email = chat_email unless chat_email.blank? && (chat_email == "unknown@example.com")
    end
  end

  def set_chat_source
    ticket.source = Helpdesk::Source::CHAT if Helpdesk::Ticket::CHAT_SOURCES.has_value?(email[:from][:domain])
  end

  def snap_engage?
    email[:from][:domain] == Helpdesk::Ticket::CHAT_SOURCES[:snapengage]
  end

  def check_for_spam
    ticket.spam = true if ticket.requester.deleted?
  end

  def finalize_ticket_save
    ticket_message_id = header_processor.zendesk_email || header_processor.message_id
    message_id_list = [ticket_message_id, header_processor.all_message_ids].flatten.uniq
    begin
      header_info_update(message_id_list)
      ticket.save_ticket!
      
    rescue ActiveRecord::RecordInvalid => e
      # FreshdeskErrorsMailer.error_email(ticket,email,e)
      NewRelic::Agent.notice_error(e)
    end
    cleanup_attachments ticket
    message_id_list.each do |msg_id|
      store_ticket_threading_info(msg_id)
    end
  end

  def header_processor
    @header_processor ||= Helpdesk::Email::ProcessByMessageId.new(email[:message_id][1..-2], 
                                                                  email[:in_reply_to][1..-2], 
                                                                  email[:references])
  end

  def header_info_update ticket_message_id
    (ticket.header_info ||= {}).merge!(:message_ids => ticket_message_id) unless ticket_message_id.nil?
  end
    
  private 
  #All recipients are moved to global Cc to have them part of the entire ticket conversation 
  def global_cc
    sup_emails              = Account.current.support_emails.map(&:downcase)
    additional_to_emails    = email[:to_emails].reject{|mail| email[:to][:email].include?(mail) or sup_emails.include?(mail.downcase)}
    @global_cc ||= additional_to_emails.push(email[:cc]).flatten.compact.uniq 
  end

  def store_ticket_threading_info(message_id)
    related_ticket_info = header_processor.get_ticket_info_from_redis(account, message_id)
    if related_ticket_info
      ticket_id_list = $1 if related_ticket_info =~ /(.+?):/
    end
    related_tickets_display_info = ticket_id_list.present? ? ((ticket_id_list.to_s) +","+ (ticket.display_id.to_s)) : ticket.display_id.to_s

    header_processor.set_ticket_id_with_message_id account, message_id, related_tickets_display_info
  end

end