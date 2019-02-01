module DataVersioning
  module Controller
    include Redis::RedisKeys
    include Redis::OthersRedis
    extend ActiveSupport::Concern

    module ClassMethods
      def send_etags_along(entity_key)
        # This is the method that has to be called

        before_filter :verify_data_version, only: :index
        after_filter  :versionize_latest_timestamp, only: :index

        define_method "version_entity_key" do
          entity_key
        end
      end
    end

    module InstanceMethods

      private

        def verify_data_version
          if etag_matched?
            Rails.logger.debug "Data not changed:: #{version_entity_value}, klass:: #{self.class.name}"
            add_etag_to_response_header(version_entity_value)
            head 304
          end
        end

        def versionize_latest_timestamp
          if version_entity_value
            add_etag_to_response_header(version_entity_value)
          else
            add_etag_to_response_header(latest_timestamp_for_versions)
            set_others_redis_hash_set(version_key, version_entity_key, latest_timestamp_for_versions)
          end
        end

        def version_entity_value
          version_set[version_entity_key]
        end

        def latest_timestamp_for_versions
          @latest_timestamp_for_versions ||= Time.now.utc.to_i
        end

        def etag_matched?
          header_version = request.headers['If-None-Match']
          header_version.present? && header_version == EtagGenerator.generate_etag(version_entity_value, self.class::CURRENT_VERSION)
        end

        def set_app_data_version
          response.headers['X-Account-Data-Version'] = overall_data_version
        end

        def overall_data_version
          Digest::MD5.hexdigest(version_set_values.join)
        end

        def version_set_values
          values = []
          (Account::COMBINED_VERSION_ENTITY_KEYS | [Marketplace::Constants::MARKETPLACE_VERSION_MEMBER_KEY]).each do |key|
            values << version_set[key]
          end
          if Account.current.custom_translations_enabled? && User.current.try(:supported_language)
            CustomTranslation::VERSION_MEMBER_KEYS.values.each do |key|
              version_key = format(key, language_code: User.current.try(:supported_language))
              values << version_set[version_key]
            end
          end
          values.compact
        end

        def version_set
          @version_set ||= get_others_redis_hash(version_key)
        end
    end
  end
end
