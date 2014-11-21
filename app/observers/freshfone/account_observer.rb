class Freshfone::AccountObserver < ActiveRecord::Observer
	observe Freshfone::Account

	def before_create(freshfone_account)
		account = freshfone_account.account
		initialize_subaccount_details(freshfone_account, account)
	end

	def before_update(freshfone_account) 
		set_expiry(freshfone_account) if freshfone_account.state_changed?
	end

	def before_destroy(freshfone_account)
		freshfone_account.close
	end

	def after_commit(freshfone_account)
    if freshfone_account.send(:transaction_include_action?, :create)
      set_usage_trigger(freshfone_account)
    end
    true
	end

	private
		def initialize_subaccount_details(freshfone_account, account)
			unless Rails.env.test?
  			sub_account = TwilioMaster.client.accounts.create({ :friendly_name => subaccount_name(account) })
  			application = sub_account.applications.create({
  											:friendly_name => account.name,
  											:voice_url => "#{freshfone_account.host}/freshfone/voice", 
  											:voice_fallback_url => "#{freshfone_account.host}/freshfone/voice_fallback"
  										})		
  			queue = sub_account.queues.create(:friendly_name => account.name)
  			
  			freshfone_account.twilio_subaccount_id = sub_account.sid
  			freshfone_account.twilio_subaccount_token = sub_account.auth_token
  			freshfone_account.twilio_application_id = application.sid
  			freshfone_account.queue = queue.sid
  			freshfone_account.friendly_name = sub_account.friendly_name
		  end
		end

		def set_expiry(freshfone_account)
			if freshfone_account.suspended? and freshfone_account.suspend_with_expiry
		# minus 1.day to avoid twilio collecting number renewal amount from our account on the next day
				freshfone_account.expires_on = 1.month.from_now - 1.day
			elsif freshfone_account.active?
				freshfone_account.expires_on = nil
			end
		end

		def subaccount_name(account)
			"#{account.name.parameterize.underscore}_#{account.id}"
		end

		def set_usage_trigger(freshfone_account)
      trigger_options = { :trigger_type => :daily_credit_threshold,
                          :account_id => freshfone_account.account.id,
                          :trigger_value => "75",
                          :usage_category => "totalprice",
                          :recurring => "daily" }
      Resque.enqueue(Freshfone::Jobs::UsageTrigger, trigger_options)
		end

end