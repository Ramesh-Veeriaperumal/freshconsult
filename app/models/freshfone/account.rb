class Freshfone::Account < ActiveRecord::Base
	self.table_name =  :freshfone_accounts
  self.primary_key = :id
	
	belongs_to_account
	serialize :triggers, Hash
	has_many :freshfone_usage_triggers, :class_name => "Freshfone::UsageTrigger", 
						:dependent => :delete_all, :foreign_key => :freshfone_account_id
  has_many :freshfone_addresses, :class_name => "Freshfone::Address",
  					:dependent => :delete_all, :foreign_key => :freshfone_account_id
	alias_attribute :token, :twilio_subaccount_token
	alias_attribute :app_id, :twilio_application_id
	attr_protected :account_id
	attr_accessor :suspend_with_expiry

	TRIGGER_LEVELS = [
			[:first_level, 75],
			[:second_level, 200]
	]
	TRIGGER_LEVELS_HASH = Hash[*TRIGGER_LEVELS.map { |i| [i[0], i[1]] }.flatten]
	TRIGGER_LEVELS_REVERSE_HASH = Hash[*TRIGGER_LEVELS.map { |i| [i[1], i[0]] }.flatten]

	STATE = [
		[ :active, "active", 1 ],
		[ :suspended, "suspended", 2 ],
		[ :closed, "closed", 3 ],
		[ :expired, "expired", 4]
	]
	STATE_HASH = Hash[*STATE.map { |i| [i[0], i[2]] }.flatten]
	STATE_AS_STRING = Hash[*STATE.map { |i| [i[0], i[1]] }.flatten]

	STATE_HASH.each_pair do |key, value|
		define_method("#{key}?") do
			self.state == value
		end
	end 

	#validates_presence_of :twilio_subaccount_id, :twilio_subaccount_token, :queue, :friendly_name
	validates_presence_of :account_id
	validates_inclusion_of :state, :in => STATE_HASH.values,
		:message => "%{value} is not a valid state"

	scope :filter_by_due, lambda { |expires_on|
		{
			:include => :account, 
			:conditions => { :state => STATE_HASH[:suspended],
											 :expires_on => (expires_on.beginning_of_day .. expires_on.end_of_day) }
		}
	}

	def freshfone_subaccount
		unless account.freshfone_account.blank?
			current_freshfone_account = account.freshfone_account
			account_sid = current_freshfone_account.twilio_subaccount_id
			auth_token = current_freshfone_account.twilio_subaccount_token
			Twilio::REST::Client.new(account_sid, auth_token).account
		end
	end

	def update_voice_url
		freshfone_application.update({
				:voice_url => "#{host}/freshfone/voice",
				:voice_fallback_url => "#{host}/freshfone/voice_fallback",
				:status_callback => "#{host}/freshfone/conference_call/status"
			})
	rescue => e
		Rails.logger.error "Error on Updating Voice URL of Freshfone for Account :: #{self.account_id}"
		Rails.logger.error "Exception Stacktrace :: #{e.backtrace.join('\n\t')}"
	end

	def suspend
		update_twilio_subaccount_state STATE_AS_STRING[:suspended]
		update_attributes(:state => STATE_HASH[:suspended], :expires_on => 1.month.from_now)
	end

	def close
		update_twilio_subaccount_state STATE_AS_STRING[:closed]
		update_attributes(:state => STATE_HASH[:closed], :deleted => true)
	end

	def restore
		update_twilio_subaccount_state STATE_AS_STRING[:active]
		update_attributes(:state => STATE_HASH[:active], :expires_on => nil, :deleted => false)
	end

	def expire
		delete_numbers # soft deletion
		update_attributes(:state => STATE_HASH[:expired], :deleted => true)		
	end

	def self.find_due(expires_on = Time.zone.now)
		self.filter_by_due(expires_on)
	end

	def process_subscription
		if suspended?
			begin
				# twilio_subaccount.incoming_phone_numbers.list.each do |number|
				# 	number.delete
				# end
				# account.freshfone_numbers.destroy_all
			rescue Exception => e
				desc = "Unable to release all numbers for account #{account.id}."
				puts "#{desc} : #{e}"
      	NewRelic::Agent.notice_error(e, {:description => desc})
			end
		end
	end

	def undo_security_whitelist
		return 'notice' unless security_whitelist
		return 'suspended' if suspended?
		return 'error' unless active?
  	update_attributes!(:security_whitelist => false)
  	'success'
	end

	def do_security_whitelist
		return 'notice' if security_whitelist
		return 'suspended' if suspended?
		return 'error' unless active?
		update_attributes!(:security_whitelist => true)
		'success'
	end

	def update_triggers(params)
		update_attributes!(:triggers =>
			{ :first_level => params[:trigger_first].to_i,
				:second_level => params[:trigger_second].to_i
			})
	end

	def update_conference_status_url(callback_url = nil)
		app = twilio_subaccount.applications.get(app_id)
		app.update(:status_callback => callback_url)
	end

	def enable_conference
		account.features.freshfone_conference.create unless account.features?(:freshfone_conference)
		update_conference_status_url("#{host}/freshfone/conference_call/status")
	end

	def disable_conference
		account.features.freshfone_conference.destroy if account.features?(:freshfone_conference)
		update_conference_status_url
	end

	def update_twilio_subaccount_state(status)
		twilio_subaccount.update(:status => status)
	end

	def host
		"#{account.url_protocol}://#{account.full_domain}"
	end

	def twilio_subaccount
		TwilioMaster.client.accounts.get(self.twilio_subaccount_id)
	end

	def freshfone_application
		@app ||= twilio_subaccount.applications.get(app_id)
	end

	private

		def delete_numbers
			account.freshfone_numbers.each do |number|
				number.update_attributes(:deleted => true)
			end
		end
end