module Concerns::ApplicationViewConcern
  extend ActiveSupport::Concern

  INVOICE_GRACE_PERIOD = 15.days

  def formated_date(date_time, options={})
    default_options = {
      :format => :short_day_with_time,
      :include_year => false,
      :include_weekday => true,
      :translate => true
    }
    options = default_options.merge(options)
    time_format = (current_account.date_type(options[:format]) if current_account) || "%a, %-d %b, %Y at %l:%M %p"
    unless options[:include_year]
      time_format = time_format.gsub(/,\s.\b[%Yy]\b/, "") if (date_time.year == Time.now.year)
    end

    unless options[:include_weekday]
      time_format = time_format.gsub(/\A(%a|A),\s/, "")
    end
    final_date = options[:translate] ? (I18n.l date_time , :format => time_format) : (date_time.strftime(time_format))
  end

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

  def custom_mailbox_error?
    Account.current.check_custom_mailbox_status
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
end