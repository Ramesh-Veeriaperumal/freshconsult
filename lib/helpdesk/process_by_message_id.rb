module Helpdesk::ProcessByMessageId
  include Redis::RedisKeys
  include Redis::OthersRedis

  TEXT_IN_BRACKETS = /<([^>]+)/

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
    @email_message_id ||= lambda do 
      if params[:message_id].present? && params[:message_id] =~ /#{TEXT_IN_BRACKETS}/i
        $1
      elsif params[:headers] =~ /^message-id: #{TEXT_IN_BRACKETS}/i
        $1
      elsif params[:headers] =~ /^x-ms-tnef-correlator: #{TEXT_IN_BRACKETS}/i
        $1
      elsif params[:headers] =~ /message-id: #{TEXT_IN_BRACKETS}/i
        Rails.logger.debug "Message-id match found in the middle of header text - #{$1}"
        $1
      end
    end.call
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
    @email_in_reply_to ||= lambda do 
      if params[:in_reply_to].present? && params[:in_reply_to] =~ /#{TEXT_IN_BRACKETS}/i
        $1
      elsif params[:headers] =~ /in-reply-to: #{TEXT_IN_BRACKETS}/i
        $1
      end
    end.call
  end

  def all_message_ids
    reply_to = in_reply_to
    all_keys = references || []
    all_keys << reply_to if reply_to
    all_keys.reverse
  end

  private

    def parent_ticket from_email, account
      all_keys = all_message_ids
      return nil if all_keys.blank?
      all_keys.each do |ticket_key|
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
      all_keys = all_message_ids
      return nil if all_keys.blank?
      all_keys.each do |ticket_key|
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
      @email_references ||= params[:references].present? ? scan_quoted_message_ids(params[:references]) : (get_references || [])
    end

    def get_references
      headers = params[:headers]
      reference_text = ""
      headers.gsub("\r\n", "\n").split("\n").map do |line| 
        break if (reference_text.present? && line =~ /(.+): /)
        reference_text << ($1 || line) if line =~ /^references: (.+)/i or reference_text.present?
      end
      scan_quoted_message_ids(reference_text) if reference_text.present?
    end

    def scan_quoted_message_ids(text)
      text.squish.scan(/#{TEXT_IN_BRACKETS}/).flatten
    end
end
