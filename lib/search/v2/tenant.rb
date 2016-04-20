module Search
  module V2

    class Tenant
      attr_accessor :id

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
      
      #_Note_: Will have a problem is alias is somehow removed at ES.
      def index_name(alias_name)
        Search::V2::Utils::EsClient.new(:get,
                                        [cluster_path, '_alias', alias_name].join('/')
                                      ).response.keys.first
      end

      # When account is newly registered/details updated
      # (*) Clear Memcache
      # (*) Store config details in data store
      # (*) Create corresponding aliases in ES
      def bootstrap
        Store::Data.instance.store_config(id)
        cluster_obj = Cluster.fetch(home_cluster)
        aliases = ES_V2_SUPPORTED_TYPES.each_pair.map do |type, params|
          index_suffix = [cluster_obj.current_version(type), cluster_obj.current_split(type)].join('_')
          {
            add: (Hash.new.tap do |alias_props|
              alias_props[:index]           = params[:index_prefix] % { index_suffix: index_suffix }
              alias_props[:alias]           = self.alias(type)
              alias_props[:routing]         = id
              alias_props[:filter]          = ({ bool: {
                                                  must: [
                                                    { type: { value: type }},
                                                    { term: { account_id: id }}
                                                  ]
                                                }})
            end)
          }
        end

        Utils::EsClient.new(:post, 
                            [cluster_path, '_aliases'].join('/'), 
                            ({ actions: aliases }.to_json),
                            Search::Utils::SEARCH_LOGGING[:all]
                          ).response
      end

      def rollback
        aliases = ES_V2_SUPPORTED_TYPES.each_pair.map do |type, params|
          { remove: {
            index: self.index_name(self.alias(type)), #=> Hit request and get as it'll be single source of truth.
            alias: self.alias(type)
          }
          }
        end
        
        Utils::EsClient.new(:post, 
                            [cluster_path, '_aliases'].join('/'), 
                            ({ actions: aliases }.to_json),
                            Search::Utils::SEARCH_LOGGING[:all]
                          ).response
        
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

      # The path to make a bulk call to for a type
      # Eg., for bulk users: http://localhost:9200/users_1/user/_bulk
      def bulk_path(type = nil)
        [cluster_path, self.alias(type), type, '_bulk'].join('/')
      end

      # The path to access aliases
      # Eg., for ticket & users: http://localhost:9200/users_1,tickets_1
      def aliases_path(types=[])
        [
          cluster_path,
          types.collect { |type| self.alias(type) }.compact.join(',')
          ].join('/')
      end
    end

  end
end