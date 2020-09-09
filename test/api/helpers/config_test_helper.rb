module ConfigTestHelper 
  include Concerns::ApplicationViewConcern
  include Redis::RedisKeys
  include Redis::OthersRedis

  def config_pattern(dkim_config_required)
    config_hash = Hash.new
    config_hash[:social] = social_config_pattern
    config_hash[:zendesk_app_id] = zendesk_app_id
    config_hash[:email] = email_mailbox_config_pattern
    config_hash[:warnings] = warn_list_pattern
    config_hash[:dkim_configuration] = dkim_configuration_pattern(dkim_config_required)
    config_hash[:freshid] = freshid_config_pattern
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
    warn_items[:downgrade_policy_reminder] = redis_key_exists?(Account.current.downgrade_policy_email_reminder_key)
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

    social_config[:twitter_app_blocked] = true if twitter_app_blocked?
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
    email_config[:rate_limited] = redis_key_exists?(format(EMAIL_RATE_LIMIT_BREACHED, account_id: Account.current.id))
    email_config[:mailbox_oauth_reauth_required] = mailbox_oauth_reauthorization_required?
    email_config
  end

  def zendesk_app_id
    ZendeskAppConfig::FALCON_APP_ID if redis_key_exists?(ZENDESK_IMPORT_APP_KEY)
  end

  def dkim_configuration_pattern(dkim_config_required_flag)
    dkim_config = {
      dkim_configuration_required: false
    }
    return dkim_config unless dkim_config_required_flag

    if dkim_configuration_required?
      dkim_config[:dkim_configuration_required] = true
      dkim_config[:dkim_configuration_link] = DKIM_LINK
      dkim_config[:dkim_support_link] = DKIM_SUPPORT_LINK
    end
    dkim_config
  end

  def freshid_config_pattern
    client_id = if Account.current.freshid_enabled?
                  FRESHID_CLIENT_ID.to_s
                elsif Account.current.freshid_org_v2_enabled?
                  FRESHID_V2_CLIENT_ID.to_s
                end
    {
      client_id: client_id
    }
  end
end
