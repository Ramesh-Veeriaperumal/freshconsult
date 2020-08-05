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
      clear_sitemap(portal)
      remove_domain_mapping(portal)
      notify_custom_ssl_removal(portal)
      remove_custom_domain_from_global(portal) if Fdadmin::APICalls.non_global_pods?
  	end
    
    def after_commit(portal)
      if portal.safe_send(:transaction_include_action?, :update)
        commit_on_update(portal)
      elsif portal.safe_send(:transaction_include_action?, :destroy)
        commit_on_destroy(portal)
      end
      update_users_language(portal) if portal.main_portal? and @all_changes.present? and @all_changes.has_key?(:language)
      true
    end
    
    private

    def commit_on_update(portal)
      clear_portal_cache
      if @all_changes.present? && (@all_changes.has_key?(:portal_url) || @all_changes.has_key?(:ssl_enabled))
        @bot = portal.bot
        update_bot if @bot.present?
      end
    end

    def commit_on_destroy(portal)
      clear_portal_cache
    end

    def create_template(portal)
      portal.build_template()
      portal.template.save
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
      # for primary portal alone URL can be blank.
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

      account = portal.account
      if Fdadmin::APICalls.non_global_pods? && account.launched?(:trigger_domain_mapping_deletion) && @old_object.portal_url.present?
        Rails.logger.info "Triggering domain_mapping deletion from non-US pod: #{account.id} #{@old_object.portal_url}"
        remove_custom_domain_from_global(@old_object)
      end
    end

    def clear_sitemap(portal)
      Community::ClearSitemap.perform_async(portal.account_id, portal.id)
    end

    def update_users_language(portal)
      account = portal.account
      unless account.features.multi_language?
        User.current.update_attribute(:language, account.language) if User.current
        Users::UpdateLanguage.perform_async({ :account_id => account.id }) 
      end
    end

    def remove_custom_domain_from_global(portal)
      request_parameters = {
        :target_method => :remove_domain_mapping_for_pod,
        :domain => portal.portal_url,
        :account_id => portal.account_id
      }
      PodDnsUpdate.perform_async(request_parameters)
    end

    def update_bot
      response, response_code = Freshbots::Bot.update_bot(@bot)
      raise response unless response_code == Freshbots::Bot::BOT_UPDATION_SUCCESS_STATUS
    rescue => e
      error_msg = "FRESHBOTS UPDATE ERROR FOR PORTAL URL/SSL CHANGE :: Bot external id : #{@bot.external_id}
                         :: Account id : #{@bot.account_id} :: Portal id : #{@bot.portal_id}"
      NewRelic::Agent.notice_error(e, { description: error_msg })
      Rails.logger.error("#{error_msg} :: #{e.inspect}")
    end
	
end
