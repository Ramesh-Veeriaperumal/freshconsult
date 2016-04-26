module Search
  module V2
    module Store

      class Cache
        include Singleton

        #################
        ## Cache Keys
        #################

        ### Tenant Keys ###
        
        ALIAS         = "v1/alias:%{tenant_id}:%{type}"
        HOME_CLUSTER  = "v1/tenant_home:%{tenant_id}"
        TENANT        = "v1/tenant:%{tenant_id}"
        TENANT_INFO   = "v1/tenant_info:%{tenant_id}"
        
        ### Cluster Keys ###
        
        CLUSTER               = "v1/cluster:%{cluster_id}"
        CLUSTER_INFO          = "v1/cluster_info:%{cluster_id}"
        LASTEST_CLUSTER       = "v1/latest_cluster"
        CLUSTER_INDEX_SPLIT   = "v1/split:%{cluster_id}:%{type}"
        CLUSTER_INDEX_VERSION = "v1/version:%{cluster_id}:%{type}"

        # Can add necessary methods from here:
        # https://github.com/mperham/dalli/blob/master/lib/dalli/client.rb

        def fetch(key, expiry = 0, &block)
          fallback = proc { yield } # Not checking - block_given? - as it should be given.

          error_handle(fallback) do
            $memcache.fetch(key, expiry, nil, &block)
          end
        end

        def remove(key)
          error_handle { $memcache.delete(key) }
        end

        def error_handle(fallback = nil)
          yield
        rescue => e
          # To-Do: Notify to newrelic
          Rails.logger.error "Exception :: #{e.message}"

          # Fallback for when memcache goes down.
          fallback.call if fallback.present?
        end
      end

    end
  end
end