class Helpdesk::Email::IdentifyTicket < Struct.new(:email, :user, :account)

  attr_accessor :ticket, :archived_ticket
  include EmailHelper

  IDENTIFICATION_METHODS = ['subject_id_based_ticket', 'assign_header_based_ticket', 'ticket_from_email_body' , 'ticket_from_id_span']

  def belongs_to_ticket
    IDENTIFICATION_METHODS.each do |fn|
      safe_send(fn)
      if ticket
        check_parent
        return nil if ticket.is_a?(Helpdesk::ArchiveTicket)
        return ticket if can_be_added_to_ticket?
      end
    end
    nil
  end

  def subject_id_based_ticket
    display_id = Helpdesk::Ticket.extract_id_token(email[:subject], account.ticket_id_delimiter)
    self.ticket = account.tickets.find_by_display_id(display_id) if display_id
  end

  def assign_header_based_ticket
    header_processor = Helpdesk::Email::ProcessByMessageId.new(email[:message_id][1..-2], 
                                                               email[:in_reply_to][1..-2], 
                                                               email[:references])
    self.ticket = header_processor.ticket_from_headers(email[:from_email], account, email[:email_config])
  end

  def ticket_from_email_body
    display_span = parsed_html.css("span[title='fd_tkt_identifier']")
    self.ticket = ticket_from_span(display_span.last) unless display_span.blank?
  end

  def ticket_from_id_span
    display_span = parsed_html.css("span[style]").select{|x| x.to_s.include?('fdtktid')}
    self.ticket = ticket_from_span(display_span.last) unless display_span.blank?
  end

  def parsed_html
    @parsed ||= run_with_timeout(NokogiriTimeoutError) { Nokogiri::HTML(email[:html]) }
  end

  def check_parent
    self.ticket = ticket_parent if ticket_parent && valid_ticket_contact(ticket_parent)
  end

  def ticket_parent
    return @par if @set_parent
    if account.features_included?(:archive_tickets) && self.ticket
      parent_ticket_id = ticket.schema_less_ticket.parent_ticket
      if parent_ticket_id
        @par ||= ticket.parent 
        unless @par
          @set_parent = true
          return self.archived_ticket = Helpdesk::ArchiveTicket.find_by_ticket_id(parent_ticket_id) 
        else
          @set_parent = true
          return @par
        end
      else
        @par = nil
        @set_parent = true
        return nil
      end
    end
    @par ||= ticket.parent
  end

  def can_be_added_to_ticket?
    ticket && (valid_user || valid_ticket_contact(ticket) || account.threading_without_user_check_enabled?)
  end

  def valid_user
    (user and user.agent? and !user.deleted? and email[:from][:email].downcase == user.email.downcase) or belongs_to_same_company?
  end

  def valid_ticket_contact given_ticket
    (given_ticket.requester.email and in_requester_email?(given_ticket)) or (user and given_ticket.included_in_cc?(user.email)) or
    (email[:from][:email] == given_ticket.sender_email) or
    given_ticket.included_in_cc?(email[:from][:email])
  end

  def in_requester_email? given_ticket
    user and given_ticket.requester.email.include?(user.email)
  end

  def ticket_from_span span
    display_id, fetched_account_id = span.inner_html.split(":")
    return if email_from_another_portal?(account, fetched_account_id)
    account.tickets.find_by_display_id(display_id.to_i) unless display_id.blank?
  end

  def archive_ticket_from_span span
    display_id = span.inner_html
    account.archive_tickets.find_by_display_id(display_id.to_i) unless display_id.blank?
  end

  def belongs_to_same_company?
    user and user.company_id and (user.company_id == ticket.company_id)
  end

  # archive methods

  def belongs_to_archive
    IDENTIFICATION_METHODS.each do |fn|
      safe_send("archive_"+fn) unless self.archived_ticket
      if self.archived_ticket
        self.ticket = self.archived_ticket
        merge_flag_for_parent_ticket = can_be_added_to_ticket?
        parent_ticket = self.archived_ticket.parent_ticket
        # If merge ticket change the archive_ticket
        if parent_ticket && parent_ticket.is_a?(Helpdesk::ArchiveTicket)
          self.archived_ticket = parent_ticket
        elsif parent_ticket && parent_ticket.is_a?(Helpdesk::Ticket)
          self.ticket = parent_ticket
          if can_be_added_to_ticket?
            return self.ticket 
          end
        end
        # If not merge check if archive child present
        self.ticket = self.archived_ticket
        flag_archive_ticket = can_be_added_to_ticket?
        linked_ticket = self.archived_ticket.ticket
        if linked_ticket
          self.ticket = linked_ticket
          flag_can_be_parent_ticket = can_be_added_to_ticket?
          self.ticket = linked_ticket.parent if linked_ticket.parent  
          if can_be_added_to_ticket? or flag_can_be_parent_ticket or flag_archive_ticket or merge_flag_for_parent_ticket
            return self.ticket
          else
            return nil
          end
        end
        return self.archived_ticket if flag_archive_ticket or merge_flag_for_parent_ticket
        return nil
      end
    end
    nil
  end

  def archive_subject_id_based_ticket
    display_id = Helpdesk::Ticket.extract_id_token(email[:subject], account.ticket_id_delimiter)
    self.archived_ticket = account.archive_tickets.find_by_display_id(display_id) if display_id 
  end

  def archive_assign_header_based_ticket
    header_processor = Helpdesk::Email::ProcessByMessageId.new(email[:message_id][1..-2], 
                                                               email[:in_reply_to][1..-2], 
                                                               email[:references])
    self.archived_ticket = header_processor.archive_ticket_from_headers(email[:from_email], account, email[:email_config])
  end

  def archive_ticket_from_email_body
    display_span = parsed_html.css("span[title='fd_tkt_identifier']")
    self.archived_ticket = archive_ticket_from_span(display_span.last) unless display_span.blank?
  end

  def archive_ticket_from_id_span
    display_span = parsed_html.css("span[style]").select{|x| x.to_s.include?('fdtktid')}
    self.archived_ticket = archive_ticket_from_span(display_span.last) unless display_span.blank?
  end

end
