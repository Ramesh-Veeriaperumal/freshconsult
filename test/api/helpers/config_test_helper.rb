module ConfigTestHelper 
  include Concerns::ApplicationViewConcern
  include Redis::RedisKeys
  include Redis::OthersRedis

  def config_pattern 
    config_hash = Hash.new
    config_hash[:social] = social_config_pattern
    config_hash[:zendesk_app_id] = zendesk_app_id
    config_hash[:email] = email_mailbox_config_pattern
    config_hash[:warnings] = warn_list_pattern
    config_hash[:growthscore_app_id] = GrowthScoreConfig['app_id']  if User.current.privilege?(:admin_tasks) || User.current.privilege?(:manage_account)
    config_hash.merge!(update_billing_info)
    config_hash
  end

  def warn_list_pattern
    warn_items = {}
    warn_items[:livechat_deprecation] = livechat_deprecation?
    warn_items[:freshfone_deprecation] = freshfone_deprecation?
    if admin?
      warn_items.merge!(card_expired?)
    end  
    warn_items[:invoice_overdue] = grace_period_exceeded? if invoice_due?
    warn_items
  end

  def social_config_pattern
    social_config = {}
    if facebook_reauth_required?
      social_config[:facebook_reauth_required] = true 
      social_config[:facebook_reauth_link] = facebook_reauth_link
    else
      social_config[:facebook_reauth_required] = false
    end 

    if twitter_reauth_required?
      social_config[:twitter_reauth_required] = true
      social_config[:twitter_reauth_link] = twitter_reauth_link
    else
      social_config[:twitter_reauth_required] = false
    end
    social_config
  end


  def email_mailbox_config_pattern
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
