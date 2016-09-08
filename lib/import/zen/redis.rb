module Import::Zen::Redis
  include Redis::RedisKeys
  include Redis::ZenImportRedis

  def set_redis_key node, value
    add_to_zen_import_hash(zi_key,node,value)
  end

  def clear_redis_key
    remove_zen_import_redis_key(zi_key)
    remove_zen_import_redis_key(zen_dropdown_key)
  end

  def set_import_user(value)
    clear_redis_key
    add_to_zen_import_hash(zi_key,'current_user',value)
  end

  def zi_key
    ZENDESK_IMPORT_STATUS % { :account_id => Account.current.id }
  end

  def zen_dropdown_key
    ZENDESK_IMPORT_CUSTOM_DROP_DOWN % {:account_id => Account.current.id}
  end

  def increment_key node
    incr_queue_count_hash(zi_key,node)
  end

  def set_queue_keys node
    set_redis_key("total_#{node}",0) 
    set_redis_key("#{node}_completed",0)
    set_redis_key("#{node}_queued",0)
  end

end