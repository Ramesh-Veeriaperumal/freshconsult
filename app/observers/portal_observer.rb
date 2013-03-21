class PortalObserver < ActiveRecord::Observer
  include Cache::Memcache::Portal
	include RedisKeys

  	def before_update(portal)
  	  backup_changes(portal)
    end

    def before_destroy(portal)
      backup_changes(portal)
    end

    def after_create(portal)
      create_shard_mapping(portal)
    end

    def after_update(portal)
      update_shard_mapping(portal)
    end
  	 
  	def after_destroy(portal)
  	  remove_domain_mapping(portal)
  	end

  	def after_destroy(portal)
  	  increment_version
  	end

  	def after_save(portal)
  	  increment_version
  	end

    def after_commit_on_update(portal)
      clear_portal_cache
    end

    def after_commit_on_destroy(portal)
      clear_portal_cache
    end

 private

    def backup_changes(portal)
      @old_object = portal.clone
      @all_changes = portal.changes.clone
      @all_changes.symbolize_keys!
    end

	def increment_version
    return unless Account.current
		return if get_key(PORTAL_CACHE_ENABLED) === "false"
		Rails.logger.debug "::::::::::Sweeping from portal"
		key = PORTAL_CACHE_VERSION % { :account_id => Account.current.id }
		increment key
	end

	def create_shard_mapping(portal)
      unless portal.portal_url.blank?
        create_domain_mapping(portal.portal_url)
      end
    end

    def update_shard_mapping(portal)
      if portal.portal_url.blank? 
        remove_domain_mapping(portal)
      elsif  @old_object.portal_url.blank? and !portal.portal_url.blank?
        create_domain_mapping(portal.portal_url)
      else
        domain_mapping = DomainMapping.find_by_portal_id_and_account_id(portal.id,portal.account_id)
        domain_mapping.update_attribute(:domain,portal.portal_url)  
      end
    end

    def create_domain_mapping(domain)
      shard_mapping = ShardMapping.find_by_account_id(account_id)
      shard_mapping.domains.create!({:domain => domain,:account_id => account_id, :portal_id => id})
    end

    def remove_domain_mapping(portal)
      domain_mapping = DomainMapping.find_by_portal_id_and_account_id(portal.id,portal.account_id)
      domain_mapping.destroy if domain_mapping
    end

	
end