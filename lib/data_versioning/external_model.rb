module DataVersioning
  module ExternalModel
    extend ActiveSupport::Concern

    include Redis::RedisKeys
    include Redis::OthersRedis

    def update_version_timestamp(version_entity_key)
      # version timestamp update for external models
      set_others_redis_hash_set(version_key, version_entity_key, Time.now.utc.to_i)
    end
  end
end