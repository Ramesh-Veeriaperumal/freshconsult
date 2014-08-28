class TicketFormField < ActiveRecord::Base
	
  # include Cache::Memcache::Helpdesk::TicketFormField

	belongs_to_account

	belongs_to :flexifield_def
	belongs_to :ticket_field, :class_name => 'Helpdesk::TicketField'

	acts_as_list
  	attr_accessible :form_id, :ticket_field_id, :ff_col_name, :field_alias, 
    				:sub_section_field, :account_id

	# scope_condition for acts_as_list
  def scope_condition
    "form_id = #{form_id}"
  end

end