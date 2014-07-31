class Freshfone::CreditObserver < ActiveRecord::Observer
	observe Freshfone::Credit

	include Freshfone::NodeEvents

	def after_update(freshfone_credit)
		account = freshfone_credit.account
		update_freshfone_widget(freshfone_credit, account) if freshfone_credit.available_credit_changed?
		restore_freshfone_account_state(account, freshfone_credit) if freshfone_credit.freshfone_suspended?
		update_freshfone_account_state(freshfone_credit, account) if freshfone_credit.available_credit_changed?
		notify_low_balance(freshfone_credit, account) if freshfone_credit.available_credit_changed?
		trigger_auto_recharge(freshfone_credit) if credit_threshold_reached?(freshfone_credit)
	end

	private
		def notify_low_balance(freshfone_credit, account)
			if credit_limit_on_disabled_auto_recharge?(freshfone_credit)
				# notify_freshfone_admin_dashboard
				FreshfoneNotifier.low_balance(account, freshfone_credit.available_credit) 
			end
		end

		def update_freshfone_account_state(freshfone_credit, account)
			return if account.freshfone_account.blank?
			if account_to_be_suspended?(freshfone_credit)
				suspend_freshfone_account(account)
				FreshfoneNotifier.suspended_account(account)
			end
		end

		def suspend_freshfone_account(account)
			account.freshfone_account.suspend_with_expiry = true
			account.freshfone_account.suspend
		end

		def update_freshfone_widget(freshfone_credit, account)
      if !freshfone_credit.auto_recharge?
      	if freshfone_credit.below_calling_threshold?
        	publish_freshfone_widget_state(account, "disable")
        else
        	publish_freshfone_widget_state(account, "enable") if recharged_after_threshold?(freshfone_credit)
        end
      end
    end

		def credit_limit_on_disabled_auto_recharge?(freshfone_credit)
			!freshfone_credit.auto_recharge? and 
			!already_notified?(freshfone_credit) and 
			!freshfone_credit.freshfone_suspended? and
			freshfone_credit.recharge_alert?
		end

		def credit_threshold_reached?(freshfone_credit)
			freshfone_credit.auto_recharge? and
				freshfone_credit.auto_recharge_threshold_reached?
		end

		def trigger_auto_recharge(freshfone_credit)
			freshfone_credit.send_later(:perform_auto_recharge)
		end
		
		def restore_freshfone_account_state(account, freshfone_credit)
			return if freshfone_credit.zero_balance?
			if account.freshfone_account.restore
				restore_freshfone_numbers(account)
			end
		end

		def restore_freshfone_numbers(account)
			account.freshfone_numbers.expired.update_all(
							:state => Freshfone::Number::STATE[:active])
		end

		def account_to_be_suspended?(freshfone_credit)
			!freshfone_credit.freshfone_suspended? && freshfone_credit.zero_balance?
		end

		def recharged_after_threshold?(freshfone_credit)
			previously_low?(freshfone_credit) and !freshfone_credit.below_calling_threshold?
		end

		def previously_low?(credit)
			credit.available_credit_was <= Freshfone::Credit::CREDIT_LIMIT[:calling_threshold]
		end

		def already_notified?(credit)
			credit.available_credit_was <= Freshfone::Credit::CREDIT_LIMIT[:recharge_alert]
		end

end
