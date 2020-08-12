# frozen_string_literal: true

class Email::Mailbox::OauthRedis
  include Redis::RedisKeys
  include Redis::OthersRedis
  OAUTH_REDIS_KEY_EXPIRY_TIME = 600 # 10 min
  attr_accessor :redis_key

  def initialize(options = {})
    @redis_key = options[:redis_key].presence || oauth_redis_key(options[:provider])
    Rails.logger.info "OauthRedis key - #{@redis_key}"
  end

  def populate_hash(members_hash, expiry = false)
    set_others_redis_hash(@redis_key, members_hash)
    set_others_redis_expiry(@redis_key, OAUTH_REDIS_KEY_EXPIRY_TIME) if expiry
  end

  def remove_hash
    remove_others_redis_key(@redis_key)
  end

  def exists?
    redis_key_exists?(@redis_key)
  end

  def fetch_hash
    get_others_redis_hash(@redis_key)
  end

  def oauth_redis_key(provider)
    # generate a 5 digit random number for the key.
    format(
      MAILBOX_OAUTH,
      provider: provider, account_id: Account.current.id,
      user_id: User.current.id,
      random_number: rand(10**4...10**5)
    )
  end
end
