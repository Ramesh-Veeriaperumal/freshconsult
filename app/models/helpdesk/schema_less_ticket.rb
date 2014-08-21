class Helpdesk::SchemaLessTicket < ActiveRecord::Base
  
	self.table_name =  "helpdesk_schema_less_tickets"
	self.primary_key = :id

	belongs_to :ticket, :class_name => 'Helpdesk::Ticket', :foreign_key => 'ticket_id'
	belongs_to :product

	belongs_to :sla_policy, :class_name => "Helpdesk::SlaPolicy", :foreign_key => "long_tc01"
	belongs_to :parent, :class_name => 'Helpdesk::Ticket', :foreign_key => 'long_tc02'

	belongs_to_account

	attr_protected :account_id

	alias_attribute :skip_notification, :boolean_tc01
	alias_attribute :header_info, :text_tc01
	alias_attribute :st_survey_rating, :int_tc01
	alias_attribute :survey_rating_updated_at, :datetime_tc01
	alias_attribute :trashed, :boolean_tc02
	alias_attribute :sender_email, :string_tc03
	alias_attribute :access_token, :string_tc01
	alias_attribute :escalation_level, :int_tc02
	alias_attribute :sla_policy_id, :long_tc01
	alias_attribute :manual_dueby, :boolean_tc03
	alias_attribute :parent_ticket, :long_tc02

	# Attributes used in Freshservice
	alias_attribute :department_id, :long_tc10

	serialize :to_emails
	serialize :text_tc01, Hash

	validates_uniqueness_of :string_tc01, :scope => :account_id,:allow_nil => true

	def self.trashed_column
		:boolean_tc02
	end

	def self.survey_rating_column
		:int_tc01
	end

	def self.survey_rating_updated_at_column
		:datetime_tc01
	end

	def self.find_by_access_token(token)
		find_by_string_tc01(token)
	end

	#updating access_token for old tickets
	def update_access_token(token)  #for avoiding call back have put as separate method
		update_attribute(:string_tc01, token)
	end
end