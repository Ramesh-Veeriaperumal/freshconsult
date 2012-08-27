class Helpdesk::SchemaLessTicket < ActiveRecord::Base
  
	set_table_name "helpdesk_schema_less_tickets"

	belongs_to :helpdesk_ticket 

	belongs_to :product

	belongs_to_account

	attr_protected :account_id

	alias_attribute :skip_notification, :boolean_tc01
	alias_attribute :header_info, :text_tc01

	serialize :to_emails
	serialize :header_info
end