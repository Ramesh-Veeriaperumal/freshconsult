module ConfigTestHelper 
  include Concerns::ApplicationViewConcern
  include Redis::RedisKeys
  include Redis::OthersRedis

  def config_pattern 
    config_hash = Hash.new
    config_hash[:social] = social_config_pattern
    config_hash[:zendesk_app_id] = zendesk_app_id
	  config_hash
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

  def zendesk_app_id
    ZendeskAppConfig::FALCON_APP_ID if redis_key_exists?(ZENDESK_IMPORT_APP_KEY)
  end
end
