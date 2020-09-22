module Concerns::ApplicationViewConcern
  extend ActiveSupport::Concern
    include Redis::OthersRedis
    include Redis::RedisKeys

  INVOICE_GRACE_PERIOD = 15.days

  DKIM_LINK = '/a/admin/email_configs/dkim'.freeze
  DKIM_SUPPORT_LINK = 'https://support.freshdesk.com/support/solutions/articles/228151-how-do-i-enable-dkim-for-my-email-domain-'.freeze

  def formated_date(date_time, options={})
    default_options = {
      :format => :short_day_with_time,
      :include_year => false,
      :include_weekday => true,
      :translate => true
    }
    options = default_options.merge(options)
    time_format = (current_account.date_type(options[:format]) if defined?(current_account).present?) || "%a, %-d %b, %Y at %l:%M %p"
    unless options[:include_year]
      time_format = time_format.gsub(/,\s.\b[%Yy]\b/, "") if (date_time.year == Time.now.year)
    end

    unless options[:include_weekday]
      time_format = time_format.gsub(/\A(%a|A),\s/, "")
    end
    time_format = time_format.sub('at', I18n.t('at'))
    final_date = options[:translate] ? (I18n.l date_time , :format => time_format) : (date_time.strftime(time_format))
  end

  TIME_TO_DISPLAY_CARD_BANNER = 15.days

  def facebook_reauth_link 
    "/a/admin/social/facebook_streams";
  end

  def twitter_reauth_link 
    "/a/admin/social/streams";
  end

  def email_config_link
    "/a/admin/email_configs";
  end

  def facebook_reauth_required?
    Account.current.fb_reauth_check_from_cache
  end

  def twitter_reauth_required?
    Account.current.twitter_reauth_check_from_cache
  end

  def twitter_app_blocked?
    redis_key_exists?(TWITTER_APP_BLOCKED)
  end

  def custom_mailbox_error?
    get_others_redis_hash_value(CUSTOM_MAILBOX_STATUS_CHECK, Account.current.id)
  end

  def mailbox_reauthorization_required?
    get_others_redis_hash_value(REAUTH_MAILBOX_STATUS_CHECK, Account.current.id)
  end

  def freshfone_deprecation?
    Account.current.freshfone_enabled? && !Account.current.freshcaller_enabled?
  end

  def livechat_deprecation?
    Account.current.livechat_enabled? && !(Account.current.freshchat_enabled? && Account.current.freshchat_account.try(:enabled))
  end

  def invoice_due?
    admin? && invoice_due_banner_enabled && invoice_due_exists?
  end

  def admin?
    User.current.privilege?(:admin_tasks)
  end

  def card_expired?
    ret_hash = {}
    key = CARD_EXPIRY_KEY % { :account_id => Account.current.id }
    if redis_key_exists?(key)
      value = get_others_redis_hash(key)
      if value["next_renewal"] <= (DateTime.now + TIME_TO_DISPLAY_CARD_BANNER) && value["next_renewal"] > value["card_expiry_date"]
          ret_hash ={
            :next_renewal_date => value["next_renewal"],
            :card_expired => value["card_expiry_date"] <= DateTime.now
          }
      end
    end
    ret_hash
  end 

  def invoice_due_banner_enabled
    !Account.current.skip_invoice_due_warning_enabled?
  end

  def invoice_due_key
    format(INVOICE_DUE, account_id: Account.current.id)
  end

  def invoice_due_exists?
    redis_key_exists?(invoice_due_key)
  end

  def invoice_due_date
    get_others_redis_key(invoice_due_key).to_i
  end

  def grace_period_exceeded?
    Time.now.utc.to_i - invoice_due_date > INVOICE_GRACE_PERIOD
  end

  def update_billing_info
    billing_info = {}
    billing_info[:billing_info_update_enabled] = true if allow_billing_info_update?
    billing_info
  end

  def allow_billing_info_update?
    User.current.privilege?(:manage_account) && Account.current.launched?(:update_billing_info)
  end

  def dkim_configuration_required?
    redis_key_exists?(
      format(
        MIGRATE_MANUALLY_CONFIGURED_DOMAINS,
        account_id: current_account.id
      )
    )
  end
end
