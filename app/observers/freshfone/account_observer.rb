class Freshfone::AccountObserver < ActiveRecord::Observer
	observe Freshfone::Account

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
		def set_expiry(freshfone_account)
			if freshfone_account.suspended? and freshfone_account.suspend_with_expiry
		# minus 1.day to avoid twilio collecting number renewal amount from our account on the next day
				freshfone_account.expires_on = 1.month.from_now - 1.day
			elsif freshfone_account.active?
				freshfone_account.expires_on = nil
			end
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