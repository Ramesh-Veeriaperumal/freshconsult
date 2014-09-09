class Helpdesk::Ticket < ActiveRecord::Base

	validates_presence_of :requester_id, :message => "should be a valid email address"
  validates_numericality_of :source, :status, :only_integer => true
  validates_numericality_of :requester_id, :responder_id, :only_integer => true, :allow_nil => true
  validates_inclusion_of :source, :in => 1..SOURCES.size
  validates_inclusion_of :priority, :in => PRIORITY_TOKEN_BY_KEY.keys, :message=>"should be a valid priority" #for api
  validates_uniqueness_of :display_id, :scope => :account_id

  validate on: :create do |ticket|
    req = ticket.requester
    if req
      ticket.spam = true if req.deleted?
      if req.blocked?
        Rails.logger.debug "User blocked! No more tickets allowed for this user" 
        ticket.errors.add(:base,"User blocked! No more tickets allowed for this user")
      end
    end
  end

  validate on: :create do |ticket|
    if (ticket.cc_email && ticket.cc_email[:cc_emails] && 
      ticket.cc_email[:cc_emails].count >= TicketConstants::MAX_EMAIL_COUNT)
      Rails.logger.debug "You have exceeded the limit of #{TicketConstants::MAX_EMAIL_COUNT} cc emails for this ticket" 
      ticket.errors.add(:base,"You have exceeded the limit of #{TicketConstants::MAX_EMAIL_COUNT} cc emails for this ticket")
    end
  end

end