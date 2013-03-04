class Helpdesk::SchemaLessNote < ActiveRecord::Base

	set_table_name "helpdesk_schema_less_notes"

	alias_attribute :header_info, :text_nc01
	alias_attribute :category, :int_nc01
	alias_attribute :response_time_in_seconds, :int_nc02
	alias_attribute :response_time_by_bhrs, :int_nc03

	serialize :to_emails
	serialize :cc_emails
	serialize :bcc_emails
	serialize :header_info

	belongs_to_account	
	belongs_to :note, :class_name =>'Helpdesk::Note'

	attr_protected :note_id, :account_id

end