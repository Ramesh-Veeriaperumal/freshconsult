class Freshfone::AccountObserver < ActiveRecord::Observer
	observe Freshfone::Account

	def before_update(freshfone_account)
		set_expiry(freshfone_account) if freshfone_account.state_changed?
	end

	def before_destroy(freshfone_account)
		freshfone_account.close unless freshfone_account.closed?
		FreshfoneNotifier.deliver_freshfone_ops_notifier(freshfone_account.account,
			:message => "Freshfone Account Closed For Account :: #{freshfone_account.account_id}")
	end

	def after_create(freshfone_account)
		freshfone_account.enable_conference
		freshfone_account.enable_custom_forwarding
	end

	def after_commit(freshfone_account)
		return unless freshfone_account.safe_send(:transaction_include_action?, :create)
		set_usage_trigger(freshfone_account)
		initiate_trial_actions(freshfone_account) if freshfone_account.trial?
	end

	def after_update(freshfone_account)
		check_security_whitelist_changes freshfone_account
		if trial_removal_preconditions?(freshfone_account)
			Freshfone::UsageTrigger.remove_calls_usage_triggers(freshfone_account)
			account = freshfone_account.account
			insert_freshfone_credit(account)
			remove_onboarding_feature(account)
		end
	end

	private
		def set_expiry(freshfone_account)
			if freshfone_account.suspended? and freshfone_account.suspend_with_expiry
				freshfone_account.expires_on = 1.month.from_now - 1.day # minus 1.day to avoid twilio collecting number renewal amount from our account on the next day
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

		def insert_freshfone_credit(account)
			account.create_freshfone_credit if account.freshfone_credit.blank?
		end

		def remove_onboarding_feature(account)
			account.features.freshfone_onboarding.destroy if account.features?(
				:freshfone_onboarding)
		end

		def trial_removal_preconditions?(freshfone_account)
			freshfone_account.state_changed? &&
				freshfone_account.in_trial_states?(freshfone_account.state_was) &&
					freshfone_account.active?
		end

		def build_trigger_options(account_id, name, value)
			{ :trigger_type   => name.to_sym,
				:account_id     => account_id,
				:trigger_value  => "#{value}",
				:usage_category => name.to_s.gsub('_', '-') } # to match Twilio Usage Category
		end

		def initiate_trial_actions(ff_account)
			generate_trial_triggers(ff_account)
			FreshfoneNotifier.send_later(:deliver_phone_trial_initiated,
				ff_account.account)
		end

		def generate_trial_triggers(freshfone_account)
			subscription = freshfone_account.subscription
			Resque.enqueue(
					Freshfone::Jobs::UsageTrigger,
					build_trigger_options(
							freshfone_account.account_id,
							Freshfone::Subscription::INBOUND_HASH[:trigger],
							(subscription.present? ? subscription.inbound[:minutes] :
								Freshfone::Subscription::INBOUND_HASH[:minutes])))
			Resque.enqueue(
					Freshfone::Jobs::UsageTrigger,
					build_trigger_options(
							freshfone_account.account_id,
							Freshfone::Subscription::OUTBOUND_HASH[:trigger],
							(subscription.present? ? subscription.outbound[:minutes] :
								Freshfone::Subscription::OUTBOUND_HASH[:minutes])))
		end
end
