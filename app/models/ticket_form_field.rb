class TicketFormField < ActiveRecord::Base
	
  # include Cache::Memcache::Helpdesk::TicketFormField

  self.primary_key = :id
	belongs_to_account

	belongs_to :flexifield_def
	belongs_to :ticket_field, :class_name => 'Helpdesk::TicketField'

  attr_accessible :form_id, :ticket_field_id, :ff_col_name, :field_alias, 
    				:sub_section_field, :account_id, :position
  acts_as_list :scope => 'form_id = #{form_id}'


end