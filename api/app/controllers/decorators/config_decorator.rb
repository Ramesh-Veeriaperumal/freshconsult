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
    ret_hash[:growthscore_app_id] = GrowthScoreConfig['app_id']  if User.current.privilege?(:admin_tasks) || User.current.privilege?(:manage_account)
    ret_hash.merge!(update_billing_info)
    ret_hash
  end

  def warn_items
    warn_items = {}
    warn_items[:livechat_deprecation] = livechat_deprecation?
    warn_items[:freshfone_deprecation] = freshfone_deprecation?
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

end
