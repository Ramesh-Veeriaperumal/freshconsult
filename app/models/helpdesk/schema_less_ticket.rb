class Helpdesk::SchemaLessTicket < ActiveRecord::Base
	
	include BusinessHoursCalculation
	
	COUNT_COLUMNS_FOR_REPORTS = ["agent_reassigned", "group_reassigned", "reopened", 
                                  "private_note", "public_note", "agent_reply", "customer_reply"]
  
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
	alias_attribute :reports_hash, :text_tc02

	# Attributes used in Freshservice
	alias_attribute :department_id, :long_tc10

	serialize :to_emails
	serialize :text_tc01, Hash
	serialize :text_tc02, Hash

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
	
	# Methods for new reports starts here
	def set_first_assign_bhrs(created_at_time, first_assigned, group)
		return if reports_hash.has_key?("first_assign_in_bhrs")
		first_assign_by_bhrs = nil
		BusinessCalendar.execute(self.ticket) {
			first_assign_by_bhrs = calculate_time_in_bhrs(created_at_time, first_assigned, group)
		}
  	self.reports_hash.merge!("first_assign_by_bhrs" => first_assign_by_bhrs)
	end
	
	def first_response_id=(note_id)
		unless reports_hash.has_key?("first_response_id")
			self.reports_hash.merge!("first_response_id" => note_id)
			self.save
		end
	end
	
	["agent", "group"].each do |type|
		define_method("set_#{type}_assigned_flag") do
			return if reports_hash.has_key?("#{type}_reassigned_flag")
			if reports_hash.has_key?("#{type}_assigned_flag")
				self.reports_hash.delete("#{type}_assigned_flag")
				flag_name = "#{type}_reassigned_flag"
			else
				flag_name = "#{type}_assigned_flag"
			end
		  self.reports_hash.merge!(flag_name => true)
		end
	end
	
	COUNT_COLUMNS_FOR_REPORTS.each do |count_type|
		define_method("update_#{count_type}_count") do |action|
			previous_count = self.reports_hash["#{count_type}_count"]
			case action
			when "create"
				current_count = previous_count.to_i + 1
			when "destroy"
				current_count = (previous_count.to_i == 0 ? nil : previous_count.to_i -  1)
			else
				current_count = nil
			end
			self.reports_hash["#{count_type}_count"] = current_count unless current_count.nil?
		end
	end
	# Methods for new reports ends here
end