module Search
  module V2

    class Cluster
      attr_accessor :cluster_id

      def initialize(cluster_id)
        @cluster_id = cluster_id.to_s
      end

      # Fetch from cache/reinitialize
      def self.fetch(cluster_id)
        Store::Cache.instance.fetch(Store::Cache::CLUSTER % { cluster_id: cluster_id }) do
          Cluster.new(cluster_id)
        end
      end
      
      def self.latest_cluster
        Store::Cache.instance.fetch(Store::Cache::LASTEST_CLUSTER) do
          Store::Data.instance.latest_cluster_info['cluster_id']
        end
      end
      
      def index_suffix(type)
        Store::Cache.instance.fetch(Store::Cache::CLUSTER_INDEX_SUFFIX % { cluster_id: cluster_id, type: type }) do
          suffix_pattern(type) % suffix_params(type)
        end
      end
      
      private

        def suffix_pattern(type)
          Store::Data.instance.cluster_info(cluster_id)[type]['suffix_pattern']
        end
        
        def suffix_params(type)
          Store::Data.instance.cluster_info(cluster_id)[type]['suffix_params'].symbolize_keys
        end
    end

  end
end