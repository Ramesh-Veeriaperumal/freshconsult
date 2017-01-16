class Account::Setup::UpdatedObjectsObserver < ActiveRecord::Observer

	include Account::Setup::ObserverUtils

	observe Account, EmailConfig, VaRule

	def after_commit(object)
		if object.send(:transaction_include_action?, :update)
			if current_flag_unmarked?(object) && send("additional_check_for_#{current_flag(object)}", object)
				mark_current_flag(object)
			end
		end
	end

	protected

	def setup_keys_for_model
		{
			"Account" => "account_admin_email",
			"EmailConfig" => "support_email",
			"VaRule" => "automation",
			"ScenarioAutomation" => "automation",
		}
	end

	private

	def additional_check_for_support_email(email_config)
		email_config.previous_changes.keys.include?("reply_email")
	end

	def additional_check_for_account_admin_email(account)
		account.verified?
	end

	def additional_check_for_automation(va_rule)
		true
	end
end