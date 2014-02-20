class TicketFormField < ActiveRecord::Base
	
  # include Cache::Memcache::Helpdesk::TicketFormField

	belongs_to_account

	belongs_to :flexifield_def
	belongs_to :ticket_field, :class_name => 'Helpdesk::TicketField'

	acts_as_list

	# named_scope :form_custom_fields, :conditions=>["ff_col_name is not null"]
 #  named_scope :event_fields, lambda { |id|
 #    { :conditions => ["(field_type = 'custom_dropdown' or field_type = 'custom_checkbox' 
 #                      or field_type = 'nested_field') and ticket_form_fields.flexifield_def_id = ? ", id],
 #      :include => :flexifield_def
 #    }
 #  } 

  # after_commit :clear_cache

	# scope_condition for acts_as_list
  def scope_condition
    "form_id = #{form_id}"
  end

  def to_ff_field ff_alias = nil
    (ff_alias.nil? || field_alias == ff_alias) ? ff_col_name : nil
  end

  def to_ff_alias ff_field = nil
    (ff_field.nil? || ff_col_name == ff_field) ? field_alias : nil
  end

end