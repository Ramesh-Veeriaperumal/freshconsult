module SelectAllRedisMethods
  include Redis::RedisKeys
  include Redis::OthersRedis

  DELIMITER = "||"

  def bulk_action_redis_value
    account = Account.current
    get_others_redis_hash(bulk_action_redis_key)
  end

  def set_bulk_action_redis_key(params, batch_id = "")
    account = Account.current
    user = User.current
    redis_current_value = bulk_action_redis_value
    if redis_current_value.present?
      bulk_action_redis_append_batch(account.id, redis_current_value, batch_id)
    else
      set_others_redis_hash(bulk_action_redis_key, construct_select_all_redis_value(
        params,
        batch_id
      ))
    end
    set_others_redis_expiry(bulk_action_redis_key, bulk_action_redis_expiry)
  end

  def bulk_action_redis_key
    SELECT_ALL % { :account_id => Account.current.id }
  end
  private
    def construct_select_all_redis_value(params, batch_id)
      {
        "user_id"     => User.current.id,
        "user_name"   => User.current.name,
        "domain_name" => Account.current.full_domain,
        "parameters"  => params.to_json,
        "batches"     => batch_id
      }
    end

    def bulk_action_redis_expiry
      7.days
    end
    
    def bulk_action_redis_append_batch(account_id, redis_value, batch_id)
      redis_value["batches"] =  !redis_value["batches"].present? ? 
        batch_id 
        : %(#{redis_value["batches"]}#{DELIMITER}#{batch_id})
      set_others_redis_hash(bulk_action_redis_key, redis_value)
    end
end
