class Helpdesk::Ticket < ActiveRecord::Base

	validates_presence_of :requester_id, :message => "should be a valid email address"
  validates_numericality_of :source, :status, :only_integer => true
  validates_numericality_of :requester_id, :responder_id, :only_integer => true, :allow_nil => true
  validates_inclusion_of :source, :in => 1..SOURCES.size
  validates_inclusion_of :priority, :in => PRIORITY_TOKEN_BY_KEY.keys, :message=>"should be a valid priority" #for api

  validate_on_create do |ticket|
    req = ticket.requester
    if req
      ticket.spam = true if req.deleted?
      if req.blocked?
        Rails.logger.debug "User blocked! No more tickets allowed for this user" 
        ticket.errors.add_to_base("User blocked! No more tickets allowed for this user")
      end
    end
  end

end