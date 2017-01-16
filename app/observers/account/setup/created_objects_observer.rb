class Account::Setup::CreatedObjectsObserver < ActiveRecord::Observer

	include Account::Setup::ObserverUtils

	observe Agent, EmailConfig, VaRule, Admin::DataImport, Integrations::InstalledApplication,
		Social::TwitterHandle, Freshfone::Number


	def after_commit(object)
		if object.send(:transaction_include_action?, :create)
			if account_signup_completed? && current_flag_unmarked?(object)
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
			"Freshfone::Number" 	=> "freshfone_number"
		}
	end

	def account_signup_completed?
		Account.current.try(:setup).to_i > 0
	end
end