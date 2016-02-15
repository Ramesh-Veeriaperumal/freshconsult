
class DomainMapping < ActiveRecord::Base

  self.primary_key = :id
	not_sharded
    
    validates_uniqueness_of :domain

    after_update :clear_cache
  	after_destroy :clear_cache

	belongs_to :shard, :class_name => 'ShardMapping',:foreign_key => :account_id

	scope :main_portal, :conditions => ['portal_id IS NULL']

	def act_as_directory
  end

	def clear_cache
	  key = MemcacheKeys::SHARD_BY_DOMAIN % { :domain => domain }
    MemcacheKeys.delete_from_cache key
    clear_global_pod_cache if Fdadmin::APICalls.non_global_pods?
	end

  def clear_global_pod_cache
    request_parameters = {:domain => domain,:target_method => :clear_domain_mapping_cache_for_pods}
    Fdadmin::APICalls.connect_main_pod(
      :post,
      request_parameters,PodConfig['pod_paths']['pod_endpoint'],
      "#{AppConfig['freshops_subdomain']['global']}.#{AppConfig['base_domain'][Rails.env]}")
  end
end