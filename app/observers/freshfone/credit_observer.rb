class Freshfone::CreditObserver < ActiveRecord::Observer
	observe Freshfone::Credit

	def after_save(freshfone_credit)
		account = freshfone_credit.account
		update_freshfone_account_state(freshfone_credit, account) if freshfone_credit.available_credit_changed?
		trigger_auto_recharge(freshfone_credit) if credit_threshold_reached?(freshfone_credit)
	end

	def after_update(freshfone_credit)
		account = freshfone_credit.account
		restore_freshfone_account_state(account) if freshfone_credit.freshfone_suspended?
	end

	private

		def update_freshfone_account_state(freshfone_credit, account)
			return if account.freshfone_account.blank?
			if account_to_be_suspended?(freshfone_credit)
				suspend_freshfone_account(account)
				FreshfoneNotifier.deliver_suspended_account(account)
			end
		end

		def suspend_freshfone_account(account)
			account.freshfone_account.suspend_with_expiry = true
			account.freshfone_account.suspend
		end

		def credit_threshold_reached?(freshfone_credit)
			freshfone_credit.auto_recharge? and
				freshfone_credit.available_credit <= Freshfone::Credit::CREDIT_LIMIT[:threshold]
		end

		def trigger_auto_recharge(freshfone_credit)
			freshfone_credit.send_later(:perform_auto_recharge)
		end
		
		def restore_freshfone_account_state(account)
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

end
