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
      
      def current_split(type)
        Store::Cache.instance.fetch(Store::Cache::CLUSTER_INDEX_SPLIT % { cluster_id: cluster_id, type: type }) do
          Store::Data.instance.cluster_info(cluster_id)["#{type}_split"]
        end
      end
      
      def current_version(type)
        Store::Cache.instance.fetch(Store::Cache::CLUSTER_INDEX_VERSION % { cluster_id: cluster_id, type: type }) do
          Store::Data.instance.cluster_info(cluster_id)["#{type}_version"]
        end
      end
    end

  end
end