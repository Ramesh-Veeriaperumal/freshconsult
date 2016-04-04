class Helpdesk::SchemaLessNote < ActiveRecord::Base
	
	include RabbitMq::Publisher
	# Including this because we are doing business hour calculation in rabbitmq for reports
	include BusinessHoursCalculation

	self.table_name =  "helpdesk_schema_less_notes"
	self.primary_key = :id
	
	alias_attribute :header_info, :text_nc01
	alias_attribute :category, :int_nc01
	alias_attribute :response_time_in_seconds, :int_nc02
	alias_attribute :response_time_by_bhrs, :int_nc03
	alias_attribute :email_config_id, :long_nc01
	alias_attribute :subject, :string_nc01
	
	serialize :to_emails
	serialize :cc_emails
	serialize :bcc_emails
	serialize :header_info

	belongs_to_account	
	belongs_to :note, :class_name =>'Helpdesk::Note'

	attr_protected :note_id, :account_id
	validate :cc_and_bcc_emails_count
	

	def self.resp_time_column
		:int_nc02
	end

	def self.resp_time_by_bhrs_column
		:int_nc03
	end

	def cc_and_bcc_emails_count
		if ((!cc_emails.blank? && cc_emails.is_a?(Array) && cc_emails.count >= TicketConstants::MAX_EMAIL_COUNT) || 
				(!bcc_emails.blank? && bcc_emails.is_a?(Array) && bcc_emails.count >= TicketConstants::MAX_EMAIL_COUNT) ||
				(!to_emails.blank? && to_emails.is_a?(Array) && to_emails.count >= TicketConstants::MAX_EMAIL_COUNT))
			self.errors.add(:base,"You have exceeded the limit of #{TicketConstants::MAX_EMAIL_COUNT} emails")
			return false
		end
		return true
	end
end
