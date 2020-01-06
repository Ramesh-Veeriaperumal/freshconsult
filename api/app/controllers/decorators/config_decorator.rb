class ConfigDecorator < ApiDecorator 
  include Concerns::ApplicationViewConcern
  include Redis::RedisKeys
  include Redis::OthersRedis

  def to_hash 
    ret_hash = {}
    ret_hash[:social] = social_config
    ret_hash[:email] = email_mailbox_config
    ret_hash[:zendesk_app_id] = zendesk_app_id
    ret_hash[:warnings] = warn_items
    ret_hash.merge!(update_billing_info)
    ret_hash[:dkim_configuration] = dkim_configuration
    ret_hash
  end

  def warn_items
    warn_items = {}
    warn_items[:livechat_deprecation] = livechat_deprecation?
    warn_items[:freshfone_deprecation] = freshfone_deprecation?
    warn_items[:downgrade_policy_reminder] = redis_key_exists?(current_account.downgrade_policy_email_reminder_key)
    warn_items.merge!(card_expired?) if admin?
    warn_items[:invoice_overdue] = grace_period_exceeded? if invoice_due?
    warn_items
  end

  def social_config
    social_config = {}
    social_config.merge!(facebook_config)
    social_config.merge!(twitter_config)
    social_config
  end

  def facebook_config
    facebook_config = {}
    if facebook_reauth_required?
      facebook_config[:facebook_reauth_required] = true 
      facebook_config[:facebook_reauth_link] = facebook_reauth_link
    else
      facebook_config[:facebook_reauth_required] = false
    end 
    facebook_config
  end

  def twitter_config
    twitter_config = {}
    twitter_config[:twitter_app_blocked] = true if twitter_app_blocked?
    if twitter_reauth_required?
      twitter_config[:twitter_reauth_required] = true
      twitter_config[:twitter_reauth_link] = twitter_reauth_link
    else
      twitter_config[:twitter_reauth_required] = false
    end
    twitter_config
  end

  def email_mailbox_config
    email_config = {}
    if custom_mailbox_error?
      email_config[:custom_mailbox_error] = true
      email_config[:email_config_link] = email_config_link
    else
      email_config[:custom_mailbox_error] = false
    end
    email_config

  end

  def zendesk_app_id
    ZendeskAppConfig::FALCON_APP_ID if redis_key_exists?(ZENDESK_IMPORT_APP_KEY)
  end

  def dkim_configuration
    dkim_config = {
      dkim_configuration_required: false
    }
    if dkim_configuration_required?
      dkim_config[:dkim_configuration_required] = true
      dkim_config[:dkim_configuration_link] = DKIM_LINK
      dkim_config[:dkim_support_link] = DKIM_SUPPORT_LINK
    end
    dkim_config
  end
end
