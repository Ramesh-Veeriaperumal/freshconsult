class Helpdesk::Email::IdentifyTicket < Struct.new(:email, :user, :account)

  attr_accessor :ticket

  IDENTIFICATION_METHODS = ['subject_id_based_ticket', 'assign_header_based_ticket', 'ticket_from_email_body' , 'ticket_from_id_span']

  def belongs_to_ticket
    IDENTIFICATION_METHODS.each do |fn|
      send(fn)
      return ticket if can_be_added_to_ticket?
    end
    nil
  end

  def subject_id_based_ticket
    display_id = Helpdesk::Ticket.extract_id_token(email[:subject], account.ticket_id_delimiter)
    self.ticket = account.tickets.find_by_display_id(display_id) if display_id
  end

  def assign_header_based_ticket
    header_processor = Helpdesk::Email::ProcessByMessageId.new(email[:message_id], email[:in_reply_to], email[:references])
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
    @parsed ||= Nokogiri::HTML(email[:html])
  end

  def can_be_added_to_ticket?
  	ticket and (valid_user or valid_ticket_contact)
  end

  def valid_user
    (user.agent? and !user.deleted?) or belongs_to_same_company?
  end

  def valid_ticket_contact
    (ticket.requester.email and in_requester_email?) or (ticket.included_in_cc?(user.email))
  end

  def in_requester_email?
    ticket.requester.email.include?(user.email)
  end

  def ticket_from_span span
    display_id = span.inner_html
    account.tickets.find_by_display_id(display_id.to_i) unless display_id.blank?
  end

  def belongs_to_same_company?
  	user.customer_id and (user.customer_id == ticket.requester.customer_id)
  end

end