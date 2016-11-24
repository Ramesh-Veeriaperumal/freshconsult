module Search
  module V2

    class Tenant
      attr_accessor :id
      
      SUPPORTED_LOCALES = %w(ja-JP ko ru-RU zh-CN) 
      SUPPORTED_TYPES   = %w(article) #=> To-do: Bad. See how it cannot be hardcoded.

      def initialize(tenant_id)
        @id = tenant_id.to_i
      end

      # Fetch from cache/reinitialize
      def self.fetch(tenant_id)
        Store::Cache.instance.fetch(Store::Cache::TENANT % { tenant_id: tenant_id }) do
          Tenant.new(tenant_id)
        end
      end

      # The cluster that the account is present in
      # Will return cluster1, cluster2
      def home_cluster
        Store::Cache.instance.fetch(Store::Cache::HOME_CLUSTER % { tenant_id: id }) do
          Store::Data.instance.tenant_info(id)['home_cluster']
        end
      end

      # The alias for a type of an account
      # Eg., for type user: users_1
      def alias(type)
        Store::Cache.instance.fetch(Store::Cache::ALIAS % { tenant_id: id, type: type }) do
          Store::Data.instance.tenant_info(id)[type]
        end
      end
      
      # Language specific alias - articles_p1s1v1_zh_cn, articles_p1s1v1_it
      # To-do: See how to implement with language ID
      #
      def multilang_alias(type, locale)
        # Safety catch to prevent dynamic index creation
        # This way data is sent to the default index in case locale is not supported
        return self.alias(type) unless multilang_available?(type, locale)

        [self.alias(type), locale.underscore.downcase].join('_')
      end
      
      # Hack for multilang solutions
      # To-do: See how to implement with language ID
      #
      def multilang_available?(type, locale)
        SUPPORTED_TYPES.include?(type) && SUPPORTED_LOCALES.include?(locale.to_s)
      end
      
      #_Note_: Will have a problem is alias is somehow removed at ES.
      # Might not be using this if we're not using aliases
      def index_name(alias_name)
        Search::V2::Utils::EsClient.new(:get,
                                        [cluster_path, '_alias', alias_name].join('/')
                                      ).response.keys.first
      end

      # When account is newly registered/details updated
      # (*) Clear Memcache
      # (*) Store config details in data store
      def bootstrap
        Store::Data.instance.store_config(id)
        # Removed registering aliases to Cluster as using routing now.
      end

      # When account is removed
      # (*) Remove config details from data store
      # (*) Clear Memcache
      def rollback
        # Removed unregistering aliases from Cluster as using routing now.
        Store::Data.instance.remove_config(id)
      end
      
      # The ELB ip + cluster-identifier
      # Eg: http://localhost:9200/cluster1/users_1/_search
      def cluster_path
        return ES_V2_CONFIG[:esv2_host] if (Rails.env.development? or Rails.env.test?)
        [ES_V2_CONFIG[:esv2_host], home_cluster].join('/')
      end

      # For a tenant's document, get its ES path
      # Eg., for user 1: http://localhost:9200/users_1/user/1
      def document_path(type, document_id)
        [cluster_path, self.alias(type), type, document_id].join('/')
      end
      
      # Accounts like Pinnacle sports have exclusive index for multilingual content
      # Eg., for user 1: http://localhost:9200/users_p1s1v1_zh_cn/user/1
      #
      def multilang_document_path(type, document_id, locale)
        [cluster_path, self.multilang_alias(type, locale), type, document_id].join('/')
      end

      # The path to make a bulk call to for a type
      # Eg., for bulk users: http://localhost:9200/users_1/user/_bulk
      def bulk_path(type = nil)
        [cluster_path, self.alias(type), type, '_bulk'].join('/')
      end

      # The path to access aliases
      # Eg., for ticket & users: http://localhost:9200/users_1,tickets_1
      def aliases_path(types=[], locale='')
        [
          cluster_path,
          types.collect do |type| 
            locale.present? ? self.multilang_alias(type, locale) : self.alias(type)
          end.uniq.compact.join(',')
        ].join('/')
      end
    end

  end
end