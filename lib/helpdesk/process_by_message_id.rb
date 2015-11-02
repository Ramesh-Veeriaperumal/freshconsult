module Helpdesk::ProcessByMessageId
  include Redis::RedisKeys
  include Redis::OthersRedis

  def ticket_from_headers from_email, account
    ticket = parent_ticket(from_email, account)
  end

  def archive_ticket_from_headers from_email, account
    ticket = archive_parent_ticket(from_email, account)
  end

  def message_key(account, message_id)
    EMAIL_TICKET_ID % {:account_id => account.id, :message_id => message_id}
  end

  def message_id
    headers = params[:headers]
    if (headers =~ /message-id: <([^>]+)/i)
      result = $1
    end
  end

  def zendesk_email
    (message_id =~ /@zendesk.com/ and in_reply_to =~ /@zendesk.com/) ? in_reply_to : nil
  end

  def set_ticket_id_with_message_id account, ticket_key, ticket
    latest_msg_id = zendesk_email || message_id
    set_others_redis_key(message_key(account, ticket_key),
                         "#{ticket.display_id}:#{latest_msg_id}",
                         86400*7) unless ticket_key.nil?
  end

  def in_reply_to
    headers = params[:headers]
    if (headers =~ /in-reply-to: <([^>]+)/i)
      result = $1
    end
  end

  private

    def parent_ticket from_email, account
      reply_to = in_reply_to
      all_keys = references
      all_keys << reply_to if reply_to
      return nil if all_keys.blank?
      all_keys.reverse.each do |ticket_key|
        ticket_id = get_others_redis_key(message_key(account, ticket_key))
        if ticket_id
          ticket_id = $1 if ticket_id =~ /(.+?):/
          ticket = account.tickets.find_by_display_id(ticket_id)
        end
        if ticket
          set_ticket_id_with_message_id account, ticket_key, ticket
          return ticket
        end
      end
      nil
    end

    def archive_parent_ticket from_email, account
      reply_to = in_reply_to
      all_keys = references 
      all_keys << reply_to if reply_to
      return nil if all_keys.blank?
      all_keys.reverse.each do |ticket_key|
        ticket_id = get_others_redis_key(message_key(account, ticket_key))
        if ticket_id
          ticket_id = $1 if ticket_id =~ /(.+?):/
          ticket = account.archive_tickets.find_by_display_id(ticket_id)
        end
        if ticket
          set_ticket_id_with_message_id account, ticket_key, ticket
          return ticket
        end
      end
      nil
    end

    def references
      @references = get_references || []
    end

    def get_references
      headers = params[:headers]
      if (headers =~ /references: (.+)/im)
        result = $1.scan(/<([^>]+)/).flatten
      end
    end
end
