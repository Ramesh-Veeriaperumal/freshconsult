module Helpdesk::ProcessByMessageId
  include Redis::RedisKeys
  include Redis::OthersRedis

  MESSAGE_ID_REGEX = /<+([^>]+)/

  def ticket_from_headers from_email, account, email_config
    ticket = parent_ticket(from_email, account, email_config)
  end

  def archive_ticket_from_headers from_email, account, email_config
    ticket = parent_ticket(from_email, account, email_config, true)
  end

  def message_key(account, message_id)
    EMAIL_TICKET_ID % {:account_id => account.id, :message_id => message_id}
  end

  def message_id
    @email_message_id ||= lambda do 
      if params[:message_id].present? && params[:message_id] =~ /#{MESSAGE_ID_REGEX}/i
        $1
      elsif params[:headers] =~ /^message-id: #{MESSAGE_ID_REGEX}/i
        $1
      elsif params[:headers] =~ /^x-ms-tnef-correlator: #{MESSAGE_ID_REGEX}/i
        $1
      elsif params[:headers] =~ /message-id: #{MESSAGE_ID_REGEX}/i
        Rails.logger.debug "Message-id match found in the middle of header text - #{$1}"
        $1
      end
    end.call
  end

  def zendesk_email
    (message_id =~ /@zendesk.com/ and in_reply_to =~ /@zendesk.com/) ? in_reply_to : nil
  end

  #stores related ticket's display ids in redis which will be used while threading notes with parent tickets 
  def set_ticket_id_with_message_id account, ticket_key, ticket_display_id_info
    latest_msg_id = zendesk_email || message_id
    set_others_redis_key(message_key(account, ticket_key),
                         "#{ticket_display_id_info}:#{latest_msg_id}",
                         86400*7) unless ticket_key.nil?
  end

  def in_reply_to
    @email_in_reply_to ||= lambda do 
      if params[:in_reply_to].present? && params[:in_reply_to] =~ /#{MESSAGE_ID_REGEX}/i
        $1
      elsif params[:headers] =~ /in-reply-to: #{MESSAGE_ID_REGEX}/i
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

    def parent_ticket from_email, account, email_config, is_archive = false
      all_keys = all_message_ids
      return nil if all_keys.blank?
      all_keys.each do |message_id|
        ticket = find_ticket_by_msg_id(account, message_id, email_config, is_archive)
        return ticket if ticket.present?
      end
      nil
    end

    #Will return the ticket which matches the given message id. 
    #If multiple tickets matches with the given message id ,then the one which has the same emailconfig
    # as the current one is selected. If no emailconfig matches, the first ticket is taken by default.
    def find_ticket_by_msg_id(account, message_id, email_config, is_archive = false)
      matched_ticket = nil
      related_ticket_info = get_ticket_info_from_redis(account, message_id)
      if related_ticket_info
        ticket_id_list = $1 if related_ticket_info =~ /(.+?):/

        if ticket_id_list.present?
          ticket_display_id_list = ticket_id_list.split(",")
          matched_ticket = find_ticket_thread(account, ticket_display_id_list, email_config, is_archive)
        end

        if matched_ticket.present?
          set_ticket_id_with_message_id account, message_id, ticket_id_list #to reset expiry
        end
      end
      return matched_ticket
    end


    def find_ticket_thread(account, ticket_display_id_list, email_config, is_archive = false)
      matched_ticket = nil
      #if more than one ticket id matches workaround to skip unncessary parsing
      if ticket_display_id_list.count > 1
        ticket = find_ticket_from_email_body_or_id_span(account)
        matched_ticket = ticket if ticket.present?
      end

      unless matched_ticket.present?
        #find ticket based on each display id
        if ticket_display_id_list.count == 1
          matched_ticket = find_ticket(account, ticket_display_id_list[0], is_archive)
        else
          ticket_display_id_list.each do |ticket_id|
            ticket = find_ticket(account, ticket_id, is_archive)
            matched_ticket ||= ticket #will be used if none of the ticket's email config matches with current email config
            ticket_email_config = ticket.email_config if ticket.present? && ticket.respond_to?(:email_config) #email config check for archive tickets
            if email_config.present? && ticket_email_config.present?
              if email_config.id == ticket_email_config.id
                matched_ticket = ticket 
                break
              end
            end
          end
        end
      end
      return matched_ticket
    end

    def find_ticket(account, ticket_id, is_archive)
      if is_archive
        ticket = account.archive_tickets.find_by_display_id(ticket_id)
      else
        ticket = account.tickets.find_by_display_id(ticket_id)
      end
      return ticket
    end

    def find_ticket_from_email_body_or_id_span(account)
      return ticket_from_email_body(account) || ticket_from_id_span(account)
    end

    def get_ticket_info_from_redis(account, message_id)
      get_others_redis_key(message_key(account, message_id))
    end

    def references
      @email_references ||= params[:references].present? ? scan_quoted_message_ids(params[:references]) : (get_references || [])
      get_valid_message_ids(@email_references)
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
      text.squish.scan(/#{MESSAGE_ID_REGEX}/).flatten
    end

    def get_valid_message_ids(message_id_array)
      valid_message_ids = []
      message_id_array.each do |msg_id|
        if msg_id.present? && ( !(msg_id.strip.downcase == "null" || msg_id.strip.downcase == "nil") )
          valid_message_ids.push(msg_id) 
        end
      end
      return valid_message_ids
    end
end
