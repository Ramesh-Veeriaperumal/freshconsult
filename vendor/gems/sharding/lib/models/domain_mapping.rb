
class DomainMapping < ActiveRecord::Base

  self.primary_key = :id
	not_sharded
    
    validates_uniqueness_of :domain

    after_update :clear_cache, :update_route53 , :if => :domain_changed?
  	after_destroy :clear_cache,:delete_route_53

    after_commit :create_route_53 , :on => :create

	belongs_to :shard, :class_name => 'ShardMapping',:foreign_key => :account_id

	scope :main_portal, :conditions => ['portal_id IS NULL']

	def act_as_directory
  end

	def clear_cache
	  key = MemcacheKeys::SHARD_BY_DOMAIN % { :domain => domain }
    MemcacheKeys.delete_from_cache key
    clear_global_pod_cache if Fdadmin::APICalls.non_global_pods?
	end

  # * * * POD Operation Methods Begin * * *
  def update_route53
    update_route_53({ :action => 'UPDATE', :old_domain => domain_was }) if Fdadmin::APICalls.non_global_pods?
  end

  def create_route_53
    update_route_53({:action => 'CREATE'}) if Fdadmin::APICalls.non_global_pods?
  end

  def delete_route_53
    update_route_53({:action => 'DELETE'}) if Fdadmin::APICalls.non_global_pods?
  end

  def update_route_53(options)
    domain_config = {:domain_name => domain, :region => "podeuwest1" }.merge(options)
    PodDnsUpdate.perform_async(domain_config)
  end

  def clear_global_pod_cache
    request_parameters = {:domain => [domain],:target_method => :clear_domain_mapping_cache_for_pods}
    Fdadmin::APICalls.connect_main_pod(request_parameters)
  end
  # * * * POD Operation Methods Ends * * * 
end