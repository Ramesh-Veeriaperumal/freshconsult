class FormTicketFieldValue < ActiveRecord::Base
  self.primary_key = :id
	
	belongs_to_account

	belongs_to :flexifield_def
	belongs_to :ticket_field, :class_name => 'Helpdesk::TicketField'

end