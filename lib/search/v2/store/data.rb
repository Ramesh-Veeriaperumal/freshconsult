module Search
  module V2
    module Store

      class Data
        include Singleton

        TENANT_TABLE  = ES_V2_DYNAMO_TABLES[:tenant]
        CLUSTER_TABLE = ES_V2_DYNAMO_TABLES[:cluster]
        
        ######################
        ### Tenant methods ###
        ######################

        # Get tenant info from cache/data store
        def tenant_info(tenant_id)
          unless Rails.env.development?
            get_item(
            TENANT_TABLE,
            Cache::TENANT_INFO % { tenant_id: tenant_id },
            ({ tenant_id: tenant_id })
          )
          else
            {
              "ticket"=>"tickets_p1s1v1",
              "note"=>"notes_p1s1v1",
              "user"=>"users_p1s1v1",
              "topic"=>"topics_p1s1v1",
              "post"=>"posts_p1s1v1",
              "article"=>"articles_p1s1v1",
              "company"=>"companies_p1s1v1",
              "tag"=>"tags_p1s1v1",
              "archiveticket"=>"archivetickets_p1s1v1",
              "archivenote"=>"archivenotes_p1s1v1",
              'tenant_id'=> 1,
              'home_cluster'=>'cluster1'
            }
          end
        end

        # Store the tenant config in data store
        def store_config(tenant_id)
          set_item(TENANT_TABLE, tenant_config(tenant_id))
          clear_tenant_cache(tenant_id)
        end

        # Remove the tenant config from data store
        def remove_config(tenant_id)
          remove_item(TENANT_TABLE, { tenant_id: tenant_id })
          clear_tenant_cache(tenant_id)
        end
        
        #######################
        ### Cluster methods ###
        #######################
        
        # Get cluster info from cache/data store
        def cluster_info(cluster_id)
          get_item(
            CLUSTER_TABLE,
            Cache::CLUSTER_INFO % { cluster_id: cluster_id },
            ({ cluster_id: cluster_id })
          )
        end
        
        # To-do: Revisit to handle hard-coded index
        def latest_cluster_info
          condition = { "current" => { attribute_value_list: ["true"], comparison_operator: "EQ" }}
          query_records(CLUSTER_TABLE, 'current-timestamp-index', condition).last
        end
        
        # Store the cluster config in data store
        # Pass following to tweak defaults:
        # current - to set as current cluster. If not passed, current is removed if existing
        # user_split - to set user_split value explicitly
        # user_version - to set user_version explicitly
        def store_cluster_info(cluster_id, opts={})
          set_item(CLUSTER_TABLE, cluster_config(cluster_id, opts))
          clear_cluster_cache(cluster_id)
        end
        
        # Remove the cluster config from data store
        def remove_cluster_info(cluster_id)
          remove_item(CLUSTER_TABLE, { cluster_id: cluster_id })
          clear_cluster_cache(cluster_id)
        end
        
        #############################
        ### Common dynamo methods ###
        #############################
        
        def get_item(table, cache_key, key_params)
          Cache.instance.fetch(cache_key) do
            $dynamo_v2_client.get_item(
              table_name: table,
              consistent_read: true,
              key: key_params
            ).item
          end
        end
        
        def set_item(table, params)
          $dynamo_v2_client.put_item(
            table_name: table,
            item: params
          )
        end
        
        def remove_item(table, key_params)
          $dynamo_v2_client.delete_item(table_name: table, key: key_params)
        end
        
        def query_records(table, index, condition)
          $dynamo_v2_client.query({
            table_name: table,
            index_name: index,
            key_conditions: condition
          }).items
        end

        private

          def tenant_config(tenant_id)
            latest_cluster = Cluster.latest_cluster

            ES_V2_SUPPORTED_TYPES.inject({}) do |type_hash, (type, params)|
              # To-do: Instead of populating tickets_1, users_1, etc., we need to use an index specific alias.
              type_hash[type] = (params[:alias_prefix] % { alias_suffix: latest_cluster.alias_accessor }); type_hash
            end.merge(
              'tenant_id'     => tenant_id,
              'home_cluster'  => latest_cluster.cluster_id
            )
          end

          def clear_tenant_cache(tenant_id)
            Store::Cache.instance.remove(Store::Cache::HOME_CLUSTER % { tenant_id: tenant_id })
            Store::Cache.instance.remove(Store::Cache::TENANT % { tenant_id: tenant_id })
            Store::Cache.instance.remove(Store::Cache::TENANT_INFO % { tenant_id: tenant_id })
            ES_V2_SUPPORTED_TYPES.keys.each do |type|
              Store::Cache.instance.remove(Store::Cache::ALIAS % { tenant_id: tenant_id, type: type })
            end
          end
          
          # Bootstraps default values like split:1, version:v1
          # Usage:
          # ------
          # Search::V2::Store::Data.instance.store_cluster_info('cluster3')
          # Search::V2::Store::Data.instance.store_cluster_info('cluster1',{
          #   'user' => { 'suffix_params' => { 'current_partition' => 'partition2' }}
          # })
          def cluster_config(cluster_id, opts)
            Hash.new.tap do |cluster_params|
              cluster_params[:cluster_id] = cluster_id
              cluster_params[:current]    = 'true'
              cluster_params[:accessor]   = 'p1s1v1' #=> Alias access pattern
              cluster_params[:timestamp]  = (Time.now.to_f * 1000).ceil
              ES_V2_SUPPORTED_TYPES.keys.each do |type|
                cluster_params[type] = Hash.new.tap do |type_params|
                  type_params['suffix_pattern'] = "%{current_partition}_%{current_split}_%{current_version}"
                  type_params['suffix_params']  = Hash.new.tap do |suffix_params|
                    suffix_params['current_partition']  = 'partition1'
                    suffix_params['current_split']      = 'split1'
                    suffix_params['current_version']    = 'v1'
                  end
                end
              end
            end.deep_merge(opts)
          end
          
          def clear_cluster_cache(cluster_id)
            Store::Cache.instance.remove(Store::Cache::CLUSTER % { cluster_id: cluster_id })
            Store::Cache.instance.remove(Store::Cache::CLUSTER_INFO % { cluster_id: cluster_id })
            Store::Cache.instance.remove(Store::Cache::LASTEST_CLUSTER)
            ES_V2_SUPPORTED_TYPES.keys.each do |type|
              Store::Cache.instance.remove(Store::Cache::CLUSTER_INDEX_SUFFIX % { cluster_id: cluster_id, type: type })
            end
          end
      end

    end
  end
end