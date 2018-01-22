class ConfigDecorator < ApiDecorator 
  include Concerns::ApplicationViewConcern
  include Redis::RedisKeys
  include Redis::OthersRedis

  def to_hash 
    ret_hash = {}
    ret_hash[:social] = social_config
    ret_hash[:zendesk_app_id] = zendesk_app_id
    ret_hash
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
    if twitter_reauth_required?
      twitter_config[:twitter_reauth_required] = true
      twitter_config[:twitter_reauth_link] = twitter_reauth_link
    else
      twitter_config[:twitter_reauth_required] = false
    end
    twitter_config
  end

  def zendesk_app_id
    ZendeskAppConfig::FALCON_APP_ID if redis_key_exists?(ZENDESK_IMPORT_APP_KEY)
  end

end