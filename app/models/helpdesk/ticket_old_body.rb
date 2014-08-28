# This model will be deprecated and removed soon
# New tickets created should not be stored in this table, they should be stored in riak

class Helpdesk::TicketOldBody < ActiveRecord::Base
  self.table_name =  'helpdesk_ticket_bodies'
  self.primary_key =  :id

  belongs_to_account
  belongs_to :ticket, :class_name => "Helpdesk::Ticket", :foreign_key => "ticket_id"

  attr_protected :account_id

  #  returns false by default 
  #  preventing update a ticket_body in case of ticket update gets called in cases
  #  where ticket_body is not yet defined and only ticket_old_body is present
  def attributes_changed?
  	false
  end

end