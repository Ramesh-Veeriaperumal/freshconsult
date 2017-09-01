class DataVersionObserver < ActiveRecord::Observer
  observe Account, Product

  include Redis::RedisKeys
  include Redis::OthersRedis

  def after_commit(object)
    if object.is_a?(Account) && object.previous_changes.key?(:plan_features)
      object.versionize_timestamp
    elsif object.is_a?(Product)
      update_version_timestamp('TICKET_FIELD_LIST')
    end
  end

  def update_version_timestamp(entity_key)
    set_others_redis_hash_set(version_key, entity_key, Time.now.utc.to_i)
  end
end
