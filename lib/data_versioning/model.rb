module DataVersioning
  module Model
    extend ActiveSupport::Concern

    include Redis::RedisKeys
    include Redis::OthersRedis

    included do
      after_commit :update_version_timestamp
    end

    def version_entity_key
      @version_entity_key ||= "#{self.class::VERSION_MEMBER_KEY}_LIST"
    end

    def update_version_timestamp
      set_others_redis_hash_set(version_key, version_entity_key, Time.now.utc.to_i)
    end
  end
end
