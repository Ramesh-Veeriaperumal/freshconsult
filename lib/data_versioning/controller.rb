module DataVersioning
  module Controller
    include Redis::RedisKeys
    include Redis::OthersRedis
    extend ActiveSupport::Concern

    included do
      before_filter :verify_data_version, only: :index
      after_filter  :versionize_latest_timestamp, only: :index
    end

    private

      def verify_data_version
        if etag_matched?
          Rails.logger.debug "Data not changed:: #{version_entity_value}, klass:: #{self.class.name}"
          add_etag_to_response_header(version_entity_value)
          head 304
        end
      end

      def versionize_latest_timestamp
        add_etag_to_response_header(latest_timestamp)
        set_others_redis_hash_set(version_key, version_entity_key, latest_timestamp) if version_entity_value.nil? || version_entity_value.to_i < latest_timestamp.to_i
      end

      def version_entity_value
        @version_entity_value ||= get_others_redis_hash_value(version_key, version_entity_key)
      end

      def version_entity_key
        @version_entity_key ||= "#{cname.upcase}_LIST"
      end

      def latest_timestamp
        @latest_timestamp ||= Time.now.utc.to_i
      end

      def etag_matched?
        header_version = request.headers['If-None-Match']
        header_version.present? && header_version == EtagGenerator.generate_etag(version_entity_value)
      end
  end
end
