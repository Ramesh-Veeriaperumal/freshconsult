class Email::Mailbox::GmailOauthRedis
  include Redis::RedisKeys
  include Redis::OthersRedis
  GMAIL_OAUTH_REDIS_KEY_EXPIRY_TIME = 600 # 10 min
  attr_accessor :redis_key
  
  def initialize(options = {})
    @redis_key = options[:redis_key].present? ? options[:redis_key] : gmail_oauth_redis_key
    Rails.logger.info "GmailOauthRedis key - #{@redis_key}"
  end
  
  def populate_hash(members_hash, expiry = false)
    set_others_redis_hash(@redis_key, members_hash)
    set_others_redis_expiry(@redis_key, GMAIL_OAUTH_REDIS_KEY_EXPIRY_TIME) if expiry
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
  
  def gmail_oauth_redis_key
    # generate a 5 digit random number for the key.
    format(
      MAILBOX_GMAIL_OAUTH,
      account_id: Account.current.id,
      user_id: User.current.id,
      random_number: rand(10**4...10**5)
    )
  end
end
