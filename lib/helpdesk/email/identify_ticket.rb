class Helpdesk::Email::IdentifyTicket < Struct.new(:email, :user, :account, :email_config)

  include Ecommerce::HelperMethods
  attr_accessor :ticket

  IDENTIFICATION_METHODS = ['subject_id_based_ticket', 'assign_header_based_ticket', 'ticket_from_email_body' , 'ticket_from_id_span', 'ecommerce_ticket']

  def belongs_to_ticket
    IDENTIFICATION_METHODS.each do |fn|
      send(fn)
      check_parent if ticket and ticket_parent
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

  def ecommerce_ticket
    return if self.email_config
    self.ticket = ebay_parent_ticket(user.email, email[:subject], self.email_config.id) if ecommerce?(user.email, email[:to][:email])
  end

  def parsed_html
    @parsed ||= Nokogiri::HTML(email[:html])
  end

  def check_parent
    self.ticket = ticket_parent if valid_ticket_contact(ticket_parent)
  end

  def ticket_parent
    @par ||= ticket.parent
  end

  def can_be_added_to_ticket?
  	ticket and (valid_user or valid_ticket_contact(ticket))
  end

  def valid_user
    (user.agent? and !user.deleted? and email[:from][:email].downcase == user.email.downcase) or belongs_to_same_company?
  end

  def valid_ticket_contact given_ticket
    (given_ticket.requester.email and in_requester_email?(given_ticket)) or (given_ticket.included_in_cc?(user.email))
  end

  def in_requester_email? given_ticket
    given_ticket.requester.email.include?(user.email)
  end

  def ticket_from_span span
    display_id = span.inner_html
    account.tickets.find_by_display_id(display_id.to_i) unless display_id.blank?
  end

  def belongs_to_same_company?
  	user.company_id and (user.company_id == ticket.requester.company_id)
  end

end