class Account::Setup::CreatedObjectsObserver < ActiveRecord::Observer

	include Account::Setup::ObserverUtils

	observe Agent, EmailConfig, VaRule, Admin::DataImport, Integrations::InstalledApplication,
		Social::TwitterHandle, Freshcaller::Account


	def after_commit(object)
		if object.safe_send(:transaction_include_action?, :create)
			if account_signup_completed? && current_flag_unmarked?(object) && additional_check(object)
				mark_current_flag(object)
			end
		end
	end

	protected

	def setup_keys_for_model
		{
			"Agent" 				=> "agents",
			"EmailConfig" 			=> "support_email",
			"VaRule" 				=> "automation",
			"ScenarioAutomation" 	=> "automation",
			"Admin::DataImport" 	=> "data_import",
			"Integrations::InstalledApplication" => "custom_app",
			"Social::TwitterHandle" => "twitter",
			"Freshfone::Number" 	=> "freshfone_number",
			"Freshcaller::Account"	=> "freshfone_number"
		}
	end

	def account_signup_completed?
		!Account.current.background_fixtures_running? && Account.current.new_account_setup?
	end

	def additional_check(object)
		current_flag = current_flag(object)
		respond_to?("additional_check_for_#{current_flag}") ? safe_send("additional_check_for_#{current_flag}", object) : true
	end
end
