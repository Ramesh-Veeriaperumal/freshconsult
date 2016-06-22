#todo: Most of the methods in this class are already available in helpdesk/process_by_message_id.rb
# chk possibility of merging both the codes

class Helpdesk::Email::ProcessByMessageId < Struct.new(:message_id, :in_reply_to, :references)
  include Redis::RedisKeys
  include Redis::OthersRedis

  def ticket_from_headers from_email, account, email_config
    ticket = parent_ticket(from_email, account, email_config)
  end

  def archive_ticket_from_headers from_email, account, email_config
    ticket = parent_ticket(from_email, account, email_config, true)
  end

  def message_key(account, message_id)
    EMAIL_TICKET_ID % {:account_id => account.id, :message_id => message_id}
  end

  def zendesk_email
    (message_id =~ /@zendesk.com/ and in_reply_to =~ /@zendesk.com/) ? in_reply_to : nil
  end

  def set_ticket_id_with_message_id account, ticket_key, ticket_display_id_info
    latest_msg_id = zendesk_email || message_id
    set_others_redis_key(message_key(account, ticket_key),
                         "#{ticket_display_id_info}:#{latest_msg_id}",
                         86400*7) unless ticket_key.nil?
  end

  def all_message_ids
    reply_to = in_reply_to
    all_keys = (references || "").split("\t")
    all_keys = all_keys.collect { |key| key.scan(/<([^>]+)/) }.flatten
    all_keys << reply_to if reply_to
    all_keys.reverse
  end

  def get_ticket_info_from_redis(account, message_id)
      get_others_redis_key(message_key(account, message_id))
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
      #Not done here right now. Might create unnecessary code duplicate if done without refactoring

      #find ticket based on each display id
      if ticket_display_id_list.count == 1
        matched_ticket = find_ticket(account, ticket_display_id_list[0], is_archive)
      else
        ticket_display_id_list.each do |ticket_id|
          ticket = find_ticket(account, ticket_id, is_archive)
          matched_ticket ||= ticket #will be used if none of the ticket's email config matches with current email config
          ticket_email_config = ticket.email_config if ticket.present?
          if email_config.present? && ticket_email_config.present?
            if email_config.id == ticket_email_config.id
              matched_ticket = ticket 
              break
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

end
