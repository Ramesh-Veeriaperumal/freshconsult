class Helpdesk::SchemaLessTicket < ActiveRecord::Base
  
	set_table_name "helpdesk_schema_less_tickets"

	belongs_to :ticket, :class_name => 'Helpdesk::Ticket', :foreign_key => 'ticket_id'
	belongs_to :product
	belongs_to_account

	attr_protected :account_id

	alias_attribute :skip_notification, :boolean_tc01
	alias_attribute :header_info, :text_tc01
	alias_attribute :st_survey_rating, :int_tc01
	alias_attribute :trashed, :boolean_tc02
	alias_attribute :access_token, :string_tc01

	serialize :to_emails
	serialize :header_info

	validates_uniqueness_of :string_tc01, :scope => :account_id,:allow_nil => true

	def self.trashed_column
		:boolean_tc02
	end

	def self.find_by_access_token(token)
		find_by_string_tc01(token)
	end

	#updating access_token for old tickets
	def update_access_token(token)  #for avoiding call back have put as separate method
		update_attribute(:string_tc01, token)
	end
end