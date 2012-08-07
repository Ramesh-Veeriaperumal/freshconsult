class Helpdesk::SchemaLessNote < ActiveRecord::Base

	set_table_name "helpdesk_schema_less_notes"

	serialize :to_emails
	serialize :cc_emails
	serialize :bcc_emails

	belongs_to_account	
	belongs_to :note, :class_name =>'Helpdesk::Note'

	attr_protected :note_id, :account_id

end