module Onboarding::OnboardingHelperMethods
  include Onboarding::OnboardingRedisMethods

  def complete_admin_onboarding
    complete_account_onboarding
    current_user.agent.update_attribute(:onboarding_completed, false)
  end

  def update_admin_related_info
    update_account_info
    update_portal_info
    update_admin_account_config
    update_email_config_name
  end

  def update_current_user_info
    @email = Mail::Address.new(params[cname]['admin_email'])
    @item.keep_user_active = true
    @item.email = params[cname]['admin_email']
    @item.name = name_from_email
  end

  def update_admin_account_config
    account_config = current_account.account_configuration
    account_config.contact_info[:first_name] = name_from_email
    account_config.contact_info[:last_name] = name_from_email
    account_config.contact_info[:email] = params[cname]['admin_email']
    account_config.billing_emails[:invoice_emails] = [params[cname]['admin_email']]
    account_config.company_info[:name] = company_name_from_email
    account_config.save!
  end

  def update_account_info
    current_account.name = company_name_from_email
    current_account.save!
  end

  def update_portal_info
    portal_to_be_updated = current_account.main_portal
    return if portal_to_be_updated.name != AccountConstants::ANONYMOUS_ACCOUNT_NAME

    portal_to_be_updated.name = company_name_from_email
    portal_to_be_updated.save!
  end

  def update_email_config_name
    email_config = current_account.primary_email_config
    return if email_config.name != AccountConstants::ANONYMOUS_ACCOUNT_NAME

    email_config.name = company_name_from_email
    email_config.save!
  end

  def convert_to_trial
    acc_addl_settings = current_account.account_additional_settings
    acc_addl_settings.additional_settings.delete(:anonymous_account)
    acc_addl_settings.save!
  end

  private

    def name_from_email
      @email.local.tr('.', ' ')
    end

    def company_name_from_email
      Freemail.free?(@email.address) ? name_from_email : @email.domain.split('.').first
    end
end
