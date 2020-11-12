module DataVersioning
  module Model
    extend ActiveSupport::Concern

    include Redis::RedisKeys
    include Redis::OthersRedis

    included do
      after_commit :update_version_timestamp, if: :valid_version_changes?
    end

    def version_entity_key
      @version_entity_key ||= self.respond_to?(:custom_version_entity_key) ? custom_version_entity_key : self.class::VERSION_MEMBER_KEY.to_s
    end

    def update_version_timestamp
      Rails.logger.info "Account version update :: #{self.try(:account_id)} :: #{self.class.name} :: #{version_entity_key}"
      set_others_redis_hash_set(version_key, version_entity_key, Time.now.utc.to_i)
    end

    def valid_version_changes?
      true
    end
  end
end
