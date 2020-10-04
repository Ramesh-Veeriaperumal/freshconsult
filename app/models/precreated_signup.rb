class PrecreatedSignup < ActivePresenter::Base
  include Helpdesk::Roles
  include Redis::RedisKeys
  include Redis::OthersRedis
  include ::Freshcaller::Util
  include ::Onboarding::OnboardingHelperMethods

  presents :account, :user

  attr_accessor :contact_first_name, :contact_last_name, :org_id, :join_token, :fresh_id_version, :org_domain, :bundle_id, :bundle_name,
                :aloha_signup, :organisation, :freshid_user, :account_domain, :referring_product

  before_validation :set_time_zone, :set_fs_cookie, :set_i18n_locale, :set_freshid_signup_version, :update_current_user_info, :update_current_account_info

  before_save :assign_freshid_v2_org_and_account, if: proc { freshid_v2_signup_allowed? && aloha_signup }
  after_save :update_account_domain, :update_main_portal_info, :update_subscription, :update_email_config_name
  after_save :create_freshid_v2_org_and_account, if: proc { freshid_v2_signup_allowed? && !aloha_signup }
  after_save :complete_signup_process

  def complete_signup_process
    account.suppress_freshid_calls = false
    account.is_anonymous_account = false
    update_admin_account_config(user.email, user.phone)
    account.update_default_forum_category(account_name)
    convert_to_trial(true, referring_product)
    enable_external_services(user.email, true)
  end

  def update_main_portal_info
    update_portal_info(@locale)
    current_portal.make_current
  end

  def update_current_user_info
    user.keep_user_active = true
    user.name = "#{first_name} #{last_name}"
  end

  def update_current_account_info
    @email = Mail::Address.new(user.email.to_str)
    account.name = account_name
  end

  def locale=(language)
    @locale = (language.presence || I18n.default_locale).to_s
  end

  def time_zone=(utc_offset)
    utc_offset = utc_offset.blank? ? 'Eastern Time (US & Canada)' : utc_offset.to_f
    t_z = ActiveSupport::TimeZone[utc_offset]
    @time_zone = t_z ? t_z.name : 'Eastern Time (US & Canada)'
  end

  def metrics=(metrics_obj)
    account.conversion_metric_attributes = metrics_obj if metrics_obj
  end

  def create_freshid_v2_org_and_account
    account.suppress_freshid_calls = true
    account.launch_freshid_with_omnibar(true) if freshid_v2_signup?
    account.create_freshid_v2_account(user, join_token, org_domain)
  end

  def assign_freshid_v2_org_and_account
    account.suppress_freshid_calls = true
    account.launch_freshid_with_omnibar(true) if freshid_v2_signup?
    account.account_additional_settings.bundle_details_setter(bundle_id, bundle_name, true)
    freshid_organisation = JSON.parse(organisation.to_json, object_class: OpenStruct)
    freshid_organisation.alternate_domain = nil
    account.organisation = Organisation.find_or_create_from_freshid_org(freshid_organisation)
    fid_user = JSON.parse(freshid_user.to_json, object_class: OpenStruct)
    user.sync_profile_from_freshid(fid_user) if fid_user.present?
  end

  def update_subscription
    @old_subscription = account.subscription.dup
    if aloha_signup && bundle_id && bundle_name
      account.subscription.update_subscription_on_signup(:estate_omni_jan_20)
    elsif account.enable_sprout_trial_onboarding?
      account.subscription.update_subscription_on_signup(:sprout_jan_20)
    end
  end

  def execute_post_signup_steps
    user.publish_agent_update_central_payload
    SAAS::SubscriptionEventActions.new(account, @old_subscription).change_plan
  end

  private

    def update_account_domain
      account.suppress_freshid_calls = true
      if account_domain && account.update_default_domain_and_email_config(account_domain) && account.freshcaller_account.present?
        propagate_new_domain_to_freshcaller
        account.mark_customize_domain_setup_and_save
      end
    end

    def current_account
      account
    end

    def current_portal
      account.main_portal
    end

    def account_name
      account.name.blank? || account.name == AccountConstants::ANONYMOUS_ACCOUNT_NAME ? company_name_from_email : account.name
    end

    def first_name
      contact_first_name || user.first_name
    end

    def last_name
      contact_last_name || user.last_name
    end

    def set_i18n_locale
      I18n.locale = account.language.to_sym
    end

    def set_time_zone
      account.time_zone = @time_zone
    end

    def freshid_v2_signup_allowed?
      (fresh_id_version.blank? && redis_key_exists?(FRESHID_V2_NEW_ACCOUNT_SIGNUP_ENABLED)) || freshid_v2_signup?
    end

    def freshid_v2_signup?
      @freshid_v2_signup ||= (fresh_id_version == Freshid::V2::Constants::FRESHID_SIGNUP_VERSION_V2)
    end

    def set_fs_cookie
      account.set_fs_cookie_by_domain
    end

    def set_freshid_signup_version
      account.fresh_id_version = fresh_id_version
    end
end
