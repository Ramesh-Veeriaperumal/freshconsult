class PortalObserver < ActiveRecord::Observer
  include Cache::Memcache::Portal
	include Redis::RedisKeys

  	def before_update(portal)
  	  backup_changes(portal)
    end

    def before_destroy(portal)
      backup_changes(portal)
    end

    def after_create(portal)
      create_shard_mapping(portal)
      create_template(portal)
    end

    def after_update(portal)
      update_shard_mapping(portal)
    end
     
    def after_destroy(portal)
      remove_domain_mapping(portal)
      notify_custom_ssl_removal(portal)
  	end
    
    def after_commit(portal)
      if portal.send(:transaction_include_action?, :update)
        commit_on_update(portal)
      elsif portal.send(:transaction_include_action?, :destroy)
        commit_on_destroy(portal)
      end
      true
    end
    
    private

    def commit_on_update(portal)
      clear_portal_cache
    end

    def commit_on_destroy(portal)
      clear_portal_cache
    end

    def create_template(portal)
      portal.build_template()
      portal.template.save()
    end

    def backup_changes(portal)
      @old_object = Portal.find_by_account_id_and_id(portal.account_id,portal.id)
      @all_changes = portal.changes.clone
    end

    def notify_custom_ssl_removal(portal)
      if portal.elb_dns_name
        FreshdeskErrorsMailer.error_email( nil, 
                                              { "domain_name" => portal.portal_url }, 
                                              nil, 
                                              { :subject => "Custom SSL to be removed for ##{portal.account_id}" })
      end
    end
	
    def create_shard_mapping(portal)
      unless portal.portal_url.blank?
        create_domain_mapping(portal)
      end
    end

    def update_shard_mapping(portal)
      if portal.portal_url.blank? 
        remove_domain_mapping(portal)
      elsif  @old_object.portal_url.blank? and !portal.portal_url.blank?
        create_domain_mapping(portal)
      else
        domain_mapping = DomainMapping.find_by_portal_id_and_account_id(portal.id,portal.account_id)
        domain_mapping.update_attribute(:domain,portal.portal_url)  
      end
    end

    def create_domain_mapping(portal)
      shard_mapping = ShardMapping.find_by_account_id(portal.account_id)
      shard_mapping.domains.create!({:domain => portal.portal_url,:account_id => portal.account_id, :portal_id => portal.id})
    end

    def remove_domain_mapping(portal)
      domain_mapping = DomainMapping.find_by_portal_id_and_account_id(portal.id,portal.account_id)
      domain_mapping.destroy if domain_mapping
    end
	
end