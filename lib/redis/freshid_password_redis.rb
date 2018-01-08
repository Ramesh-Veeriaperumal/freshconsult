module Redis::FreshidPasswordRedis
  include Redis::RedisKeys
  include Redis::OthersRedis

  PASSWORD_HASH_EXPIRY_TIME = 86_400.seconds

  def set_password_flag(email)
    get_set_others_redis_key(key(email), true, PASSWORD_HASH_EXPIRY_TIME)
  end

  def password_flag_exists?(email)
    get_others_redis_key(key(email))
  end

  def remove_password_flag(email, account_id = Account.current.try(:id))
    remove_others_redis_key(key(email, account_id))
  end

  private

    def key(email, account_id = Account.current.try(:id))
      FRESHID_USER_PW_AVAILABILITY % { account_id: account_id, email: email }
    end
end
