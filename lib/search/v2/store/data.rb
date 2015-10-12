class Search::V2::Store::Data
  include Singleton

  # Get tenant info from cache/data store
  def tenant_info(tenant_id)
    Search::V2::Store::Cache.instance.fetch(Search::V2::Store::Cache::TENANT_INFO % { tenant_id: tenant_id }) do
      $dynamo_client.get_item(table_name: 'tenant_info', key: { tenant_id: tenant_id }).item
    end
  end

  # Store the tenant config in data store
  def store_config(tenant_id)
    $dynamo_client.put_item(table_name: 'tenant_info', item: config(tenant_id))
  end

  # Remove the tenant config from data store
  def remove_config(tenant_id)
    $dynamo_client.delete_item(table_name: 'tenant_info', key: { tenant_id: tenant_id })
  end

  private

    def config(tenant_id)
      SUPPORTED_TYPES.inject({}) do |type_hash, (type, params)|
        type_hash[type] = (params[:index_prefix] % { index_suffix: tenant_id }); type_hash
      end.merge(
        'tenant_id' => tenant_id,
        'home_cluster' => 'http://localhost:9200' # To-Do: get_lru_cluster
      )
    end
end
