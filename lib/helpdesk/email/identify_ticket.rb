class Helpdesk::Email::IdentifyTicket < Struct.new(:email, :user, :account)

  attr_accessor :ticket, :archived_ticket
  include EmailHelper

  IDENTIFICATION_METHODS = ['subject_id_based_ticket', 'assign_header_based_ticket', 'ticket_from_email_body' , 'ticket_from_id_span']

  def belongs_to_ticket
    IDENTIFICATION_METHODS.each do |fn|
      send(fn)
      if ticket
        tck_parent = ticket_parent
        if tck_parent && tck_parent.is_a?(Helpdesk::ArchiveTicket)
          check_parent
          return nil
        elsif tck_parent
          check_parent
        end 
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
    self.ticket = header_processor.ticket_from_headers(email[:from_email], account)
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
    self.ticket = ticket_parent if valid_ticket_contact(ticket_parent)
  end

  def ticket_parent
    return @par if @set_parent
    if account.features?(:archive_tickets) && self.ticket
      parent_ticket_id = ticket.schema_less_ticket.parent_ticket
      if parent_ticket_id
        @par ||= ticket.parent 
        unless @par
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
    ticket and (valid_user or valid_ticket_contact(ticket))
  end

  def valid_user
    (user.agent? and !user.deleted? and email[:from][:email].downcase == user.email.downcase) or belongs_to_same_company?
  end

  def valid_ticket_contact given_ticket
    (given_ticket.requester.email and in_requester_email?(given_ticket)) or (given_ticket.included_in_cc?(user.email)) or
    (email[:from][:email] == given_ticket.sender_email)
  end

  def in_requester_email? given_ticket
    given_ticket.requester.email.include?(user.email)
  end

  def ticket_from_span span
    display_id = span.inner_html
    account.tickets.find_by_display_id(display_id.to_i) unless display_id.blank?
  end

  def archive_ticket_from_span span
    display_id = span.inner_html
    account.archive_tickets.find_by_display_id(display_id.to_i) unless display_id.blank?
  end

  def belongs_to_same_company?
    user.company_id and (user.company_id == ticket.company_id)
  end

  # archive methods

  def belongs_to_archive
    IDENTIFICATION_METHODS.each do |fn|
      send("archive_"+fn) unless self.archived_ticket
      if self.archived_ticket
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
        
        linked_ticket = self.archived_ticket.ticket
        if linked_ticket
          self.ticket = linked_ticket
          self.ticket = linked_ticket.parent if linked_ticket.parent  
          return self.ticket
        end
        return self.archived_ticket
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
    self.archived_ticket = header_processor.archive_ticket_from_headers(email[:from_email], account)
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
