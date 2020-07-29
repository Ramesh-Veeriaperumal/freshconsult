module Onboarding::OnboardingHelperMethods
  include Onboarding::OnboardingRedisMethods
  include AccountsHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def complete_admin_onboarding
    complete_account_onboarding
    current_user.agent.update_attribute(:onboarding_completed, false)
  end

  def update_admin_related_info(admin_email, admin_phone = nil)
    update_account_info(admin_email)
    update_portal_info
    update_admin_account_config(admin_email, admin_phone)
    update_email_config_name
  end

  def update_current_user_info(admin_email)
    @item.keep_user_active = true
    @item.email = admin_email
    @item.name = first_name
    @item.save!
  end

  def update_admin_account_config(admin_email, admin_phone)
    account_config = current_account.account_configuration
    account_config.contact_info = (account_config.contact_info || {}).merge({
      first_name: first_name,
      last_name: last_name,
      email: admin_email,
      phone: admin_phone
    })
    account_config.billing_emails = (account_config.billing_emails || {}).merge({
      invoice_emails: [admin_email]
    })
    account_config.company_info = (account_config.company_info || {}).merge({
      name: account_name,
      anonymous_account: current_account.is_anonymous_account
    })
    account_config.save!
  end

  def update_account_info(admin_email)
    @email = Mail::Address.new(admin_email)
    current_account.name = account_name
    current_account.save!
  end

  def enable_external_services(admin_email, precreated_account = false)
    current_account.safe_send(:add_to_billing)
    signup_params = construct_signup_params unless precreated_account
    add_to_crm(current_account.id, signup_params) unless precreated_account
    add_account_info_to_dynamo(admin_email) unless precreated_account
    current_account.enable_fresh_connect
    enqueue_for_enrichment unless precreated_account
  end

  def update_portal_info(language = nil)
    portal_to_be_updated = current_account.main_portal
    return if portal_to_be_updated.name != AccountConstants::ANONYMOUS_ACCOUNT_NAME

    portal_to_be_updated.name = account_name
    portal_to_be_updated.language = language if language
    portal_to_be_updated.save!
    current_portal.reload
  end

  def update_email_config_name
    email_config = current_account.primary_email_config
    return if email_config.name != AccountConstants::ANONYMOUS_ACCOUNT_NAME

    email_config.name = account_name
    email_config.save!
  end

  def convert_to_trial(precreated_account = false, referring_product = nil)
    acc_addl_settings = current_account.account_additional_settings
    acc_addl_settings.additional_settings.delete(:anonymous_account)
    if precreated_account
      acc_addl_settings.set_onboarding_version
      acc_addl_settings.enable_freshdesk_freshsales_bundle
      acc_addl_settings.referring_product_setter(referring_product) if referring_product
    end
    acc_addl_settings.save!
  end

  private

    def enqueue_for_enrichment
      return unless Rails.env.production? || !current_account.ehawk_spam? || !current_account.opt_out_analytics_enabled?
      ContactEnrichment.perform_async(email_update: true)
    end

    def account_name
      company_name_from_email
    end

    def first_name
      name_from_email
    end

    def last_name
      name_from_email
    end

    def name_from_email
      @email.local.tr('.', ' ')
    end

    def company_name_from_email
      Freemail.free?(@email.address) ? name_from_email : @email.domain.split('.').first
    end

    def construct_signup_params
      key = format(ACCOUNT_SIGN_UP_PARAMS, account_id: current_account.id)
      response = get_others_redis_key(key)
      return {} if response.blank?

      JSON.parse(response).symbolize_keys!
    end
end
