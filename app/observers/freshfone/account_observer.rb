class Freshfone::AccountObserver < ActiveRecord::Observer
	observe Freshfone::Account

	def before_update(freshfone_account) 
		set_expiry(freshfone_account) if freshfone_account.state_changed?
	end

	def before_destroy(freshfone_account)
		freshfone_account.close
	end

	def after_create(freshfone_account)
		set_usage_trigger(freshfone_account)
	end

	def after_update(freshfone_account)
		check_security_whitelist_changes freshfone_account
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
				:account_id 		=> freshfone_account.account.id,
				:usage_category => 'totalprice',
				:recurring 			=> 'daily' }
			freshfone_account.triggers.each do |_key, value|
				trigger_options[:trigger_value] = value
				Resque.enqueue(Freshfone::Jobs::UsageTrigger, trigger_options)
			end
		end

		def check_security_whitelist_changes(freshfone_account)
			return unless freshfone_account.security_whitelist_changed?
			if freshfone_account.security_whitelist
				Freshfone::UsageTrigger.remove_daily_threshold_with_level(freshfone_account,:second_level)
			else
				Freshfone::UsageTrigger.create_daily_threshold_trigger(
					Hash[*freshfone_account.triggers.assoc(:second_level)],
					freshfone_account.account_id)
			end
		end
end
