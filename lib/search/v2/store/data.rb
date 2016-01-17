module Search
  module V2
    module Store

      class Data
        include Singleton

        TENANT_TABLE = (Rails.env.test? ? 'tenant_info_test' : 'tenant_info')

        # Get tenant info from cache/data store
        def tenant_info(tenant_id)
          Cache.instance.fetch(Cache::TENANT_INFO % { tenant_id: tenant_id }) do
            $dynamo_client.get_item(table_name: TENANT_TABLE, key: { tenant_id: tenant_id }).item
          end
        end

        # Store the tenant config in data store
        def store_config(tenant_id)
          $dynamo_client.put_item(table_name: TENANT_TABLE, item: config(tenant_id))
        end

        # Remove the tenant config from data store
        def remove_config(tenant_id)
          $dynamo_client.delete_item(table_name: TENANT_TABLE, key: { tenant_id: tenant_id })
        end

        private

          def config(tenant_id)
            # latest_cluster = Rails.env.development? ? 1 : 1 #=> Latest cluster from host_list(Dynamo/YML)

            ES_V2_SUPPORTED_TYPES.inject({}) do |type_hash, (type, params)|
              type_hash[type] = (params[:alias_prefix] % { alias_suffix: tenant_id }); type_hash
            end.merge(
              'tenant_id'     => tenant_id,
              'home_cluster'  => ES_V2_CLUSTERS[:esv2_host]#, #=> Mostly no use in future.
              # 'cluster_id'    => "v2_cluster_#{latest_cluster}"
            )
          end
      end

    end
  end
end