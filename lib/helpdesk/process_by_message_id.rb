module Helpdesk::ProcessByMessageId
  include Redis::RedisKeys
  include Redis::OthersRedis

  def ticket_from_headers from_email, account
    ticket = parent_ticket(from_email, account)
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

  private

    def parent_ticket from_email, account
      reply_to = in_reply_to
      all_keys = references 
      all_keys << reply_to if reply_to
      return nil if all_keys.blank?
      all_keys.reverse.each do |ticket_key|
        ticket_id = get_others_redis_key(message_key(account, ticket_key))
        ticket = account.tickets.find_by_display_id(ticket_id) if ticket_id
        if ticket
          set_others_redis_expiry(message_key(account, ticket_key), 86400*7)
          return ticket
        end
      end
      nil
    end

    def in_reply_to
      headers = params[:headers]
      if (headers =~ /in-reply-to: <([^>]+)/i)
        result = $1
      end
    end

    def references
      @references = get_references || []
    end

    def get_references
      headers = params[:headers]
      if (headers =~ /references: (.+)/i)
        result = $1.scan(/<([^>]+)/).flatten
      end
    end

end