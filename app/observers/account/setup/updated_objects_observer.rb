class Account::Setup::UpdatedObjectsObserver < ActiveRecord::Observer
  include Account::Setup::ObserverUtils

  observe Account, EmailConfig, VaRule, EmailNotification, Portal

	def after_commit(object)
		if object.safe_send(:transaction_include_action?, :update)
			if current_flag_unmarked?(object) && safe_send("additional_check_for_#{current_flag(object)}", object)
				mark_current_flag(object)
			end
		end
	end

	protected

    def setup_keys_for_model
      {
        'Account' => 'account_admin_email',
        'EmailConfig' => 'support_email',
        'VaRule' => 'automation',
        'ScenarioAutomation' => 'automation',
        'EmailNotification' => 'email_notification',
        'Portal' => 'customize_domain'
      }
    end

	private

  def additional_check_for_support_email(email_config)
    return false unless email_config.previous_changes.keys.include?('reply_email')
    email_config.account.email_service_provider != EmailServiceProvider::EMAIL_SERVICE_PROVIDER_MAPPING['googlemail']
  end

	def additional_check_for_account_admin_email(account)
		account.verified?
	end

	def additional_check_for_automation(va_rule)
		on_activation_changes = ["active", "updated_at"]
		va_rule.previous_changes.keys != on_activation_changes
	end

	def additional_check_for_email_notification(email_notification)
		#This step is related to update email requester notification
		email_notification.account.verified? && email_notification.requester_notification_updated?
	end

	def additional_check_for_customize_domain(portal)
		portal.previous_changes.key?("portal_url")
	end
end
