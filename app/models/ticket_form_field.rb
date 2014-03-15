class TicketFormField < ActiveRecord::Base
	
  # include Cache::Memcache::Helpdesk::TicketFormField

	belongs_to_account

	belongs_to :flexifield_def
	belongs_to :ticket_field, :class_name => 'Helpdesk::TicketField'

	acts_as_list

	# scope_condition for acts_as_list
  def scope_condition
    "form_id = #{form_id}"
  end

end