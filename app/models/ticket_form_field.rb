class TicketFormField < ActiveRecord::Base
	
  # include Cache::Memcache::Helpdesk::TicketFormField

	belongs_to_account

	belongs_to :flexifield_def
	belongs_to :ticket_field, :class_name => 'Helpdesk::TicketField'

end