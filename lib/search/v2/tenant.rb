class Search::V2::Tenant
  attr_accessor :id

  def initialize(tenant_id)
    @id = tenant_id.to_i
  end

  # Fetch from cache/reinitialize
  def self.fetch(tenant_id)
    Search::V2::Store::Cache.instance.fetch(Search::V2::Store::Cache::TENANT % { tenant_id: tenant_id }) do
      Search::V2::Tenant.new(tenant_id)
    end
  end

  # The cluster that the account is present in
  def home_cluster
    Search::V2::Store::Cache.instance.fetch(Search::V2::Store::Cache::CLUSTER % { tenant_id: id }) do
      Search::V2::Store::Data.instance.tenant_info(id)['home_cluster']
    end
  end

  # The alias for a type of an account
  # Eg., for type user: users_1
  def alias(type)
    Search::V2::Store::Cache.instance.fetch(Search::V2::Store::Cache::ALIAS % { tenant_id: id, type: type }) do
      Search::V2::Store::Data.instance.tenant_info(id)[type]
    end
  end

  # When account is newly registered/details updated
  # (*) Clear Memcache
  # (*) Store config details in data store
  # (*) Create corresponding aliases in ES
  def bootstrap
    clear_cache
    Search::V2::Store::Data.instance.store_config(id)
    aliases = SUPPORTED_TYPES.each_pair.map do |type, params|
      { add: {
        index: params[:index_prefix] % { index_suffix: 'v1' }, # To-do: Get version from store
        alias: self.alias(type),
        routing: id,
        filter: { term: { account_id: id } }
      }
      }
    end
    Typhoeus.post([home_cluster, '_aliases'].join('/'), body: ({ actions: aliases }.to_json))
  end

  def rollback
    aliases = SUPPORTED_TYPES.each_pair.map do |type, params|
      { remove: {
        index: params[:index_prefix] % { index_suffix: 'v1' }, # To-do: Get version from store
        alias: self.alias(type)
      }
      }
    end
    Typhoeus.post([home_cluster, '_aliases'].join('/'), body: ({ actions: aliases }.to_json))
    clear_cache
    Search::V2::Store::Data.instance.remove_config(id)
  end

  # For a tenant's document, get its ES path
  # Eg., for user 1: http://localhost:9200/users_1/user/1
  def document_path(type, document_id)
    [home_cluster, self.alias(type), type, document_id].join('/')
  end

  # The path to make a bulk call to for a type
  # Eg., for bulk users: http://localhost:9200/users_1/user/_bulk
  def bulk_path(type = nil)
    [home_cluster, self.alias(type), type, '_bulk'].join('/')
  end

  # To verify:
  # Index request:
  # home_cluster/alias/type/document_id - More than one request, but one type at a time
  # Search request:
  # home_cluster/aliases/_search - More than one type at a time

  private

    def clear_cache
      Search::V2::Store::Cache.instance.remove(Search::V2::Store::Cache::CLUSTER % { tenant_id: id })
      Search::V2::Store::Cache.instance.remove(Search::V2::Store::Cache::TENANT % { tenant_id: id })
      Search::V2::Store::Cache.instance.remove(Search::V2::Store::Cache::TENANT_INFO % { tenant_id: id })
      SUPPORTED_TYPES.keys.each do |type|
        Search::V2::Store::Cache.instance.remove(Search::V2::Store::Cache::ALIAS % { tenant_id: id, type: type })
      end
    end
end
