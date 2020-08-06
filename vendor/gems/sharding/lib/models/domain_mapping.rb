class DomainMapping < ActiveRecord::Base

  self.primary_key = :id
	not_sharded
    
  validates_uniqueness_of :domain

  after_update :clear_cache, :update_route53, :if => :domain_changed?
  after_destroy :clear_cache, :delete_route_53

  after_commit :clear_cache, :create_route_53, :on => :create

  belongs_to :shard, :class_name => 'ShardMapping', :foreign_key => :account_id

  scope :main_portal, -> { where(portal_id: nil) }


  def self.domain_names(account_ids)
    raise 'Too_Many_Accounts_In_Query_Limit' if account_ids.length > 15

    where(portal_id: nil, account_id: account_ids).pluck(:domain)
  end

	def act_as_directory
  end

  def clear_cache
    domains_to_be_cleared = (transaction_include_action? :update) ? [domain_was, domain] : [domain]
    domains_to_be_cleared.each do |domain_to_be_cleared|
      key = MemcacheKeys::SHARD_BY_DOMAIN % { :domain => domain_to_be_cleared }
      MemcacheKeys.delete_from_cache key
      clear_global_pod_cache(domain_to_be_cleared) if Fdadmin::APICalls.non_global_pods?
    end
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
    domain_config = {:domain_name => domain, :region => PodConfig['CURRENT_POD'] }.merge(options)
    PodDnsUpdate.perform_async(domain_config)
  end

  def clear_global_pod_cache(domain_to_be_cleared)
    request_parameters = {:domain => [domain_to_be_cleared],:target_method => :clear_domain_mapping_cache_for_pods}
    Fdadmin::APICalls.connect_main_pod(request_parameters)
  end
  # * * * POD Operation Methods Ends * * * 
end
