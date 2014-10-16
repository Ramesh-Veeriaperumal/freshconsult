class TicketFormField < ActiveRecord::Base
	
  # include Cache::Memcache::Helpdesk::TicketFormField

	belongs_to_account

	belongs_to :flexifield_def
	belongs_to :ticket_field, :class_name => 'Helpdesk::TicketField'

	acts_as_list :scope => 'form_id = #{form_id}'
  	attr_accessible :form_id, :ticket_field_id, :ff_col_name, :field_alias, 
    				:sub_section_field, :account_id


end