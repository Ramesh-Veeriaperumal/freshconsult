class Freshfone::Account < ActiveRecord::Base
	set_table_name :freshfone_accounts
	
	belongs_to_account
	has_many :freshfone_usage_triggers, :class_name => "Freshfone::UsageTrigger", 
						:dependent => :delete_all, :foreign_key => :freshfone_account_id
  has_many :freshfone_addresses, :class_name => "Freshfone::Address",
  					:dependent => :delete_all, :foreign_key => :freshfone_account_id
	alias_attribute :token, :twilio_subaccount_token
	alias_attribute :app_id, :twilio_application_id
	attr_protected :account_id
	attr_accessor :suspend_with_expiry

	STATE = [
		[ :active, "active", 1 ],
		[ :suspended, "suspended", 2 ],
		[ :closed, "closed", 3 ]
	]
	STATE_HASH = Hash[*STATE.map { |i| [i[0], i[2]] }.flatten]
	STATE_AS_STRING = Hash[*STATE.map { |i| [i[0], i[1]] }.flatten]

	#validates_presence_of :twilio_subaccount_id, :twilio_subaccount_token, :queue, :friendly_name
	validates_presence_of :account_id
	validates_inclusion_of :state, :in => STATE_HASH.values,
		:message => "%{value} is not a valid state"

	named_scope :filter_by_due, lambda { |expires_on|
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
				:voice_fallback_url => "#{host}/freshfone/voice_fallback"
			})
	end

	def suspend
		update_twilio_subaccount_state STATE_AS_STRING[:suspended]
		update_attributes(:state => STATE_HASH[:suspended], :expires_on => 1.month.from_now)
	end

	def close
		update_twilio_subaccount_state STATE_AS_STRING[:closed]
		update_attributes(:deleted => true)
	end

	def restore
		update_twilio_subaccount_state STATE_AS_STRING[:active]
		update_attributes(:state => STATE_HASH[:active], :expires_on => nil)
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

	def suspended?
		state == STATE_HASH[:suspended]
	end

	def active?
		state == STATE_HASH[:active]
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
		@app ||= freshfone_subaccount.applications.get(app_id)
	end

end