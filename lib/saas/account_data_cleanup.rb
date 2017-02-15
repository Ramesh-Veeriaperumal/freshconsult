class SAAS::AccountDataCleanup

  include Marketplace::ApiMethods
  include Cache::Memcache::ContactField
  include Cache::Memcache::CompanyField
  include Cache::FragmentCache::Base
  include MemcacheKeys

  attr_accessor :account, :features_to_drop


  def initialize(account = Account.current, features_to_drop = [])
    @account = account
    @features_to_drop = features_to_drop
  end

  def perform_cleanup
    features_to_drop.each do |feature|
      method = "handle_#{feature}_data"
      begin
        send(method) if respond_to?(method)
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
    end
    clear_fragment_caches
  end


  def handle_create_observer_data
    account.all_observer_rules.find_each do |rule|
      rule.destroy
    end
    Rails.logger.info "Deleting all observer rules and creating fixtures again #{account.id}"
    account.reload
    Fixtures::DefaultObserver.create_rule
  end

def handle_supervisor_data
  account.all_supervisor_rules.destroy_all
end 

def handle_add_watcher_data
  account.ticket_subscriptions.find_each do |ts|
    ts.destroy
  end
end

def handle_basic_twitter_data
    #we need to keep one twitter page. So removing everything except the oldest one.
    twitter_count = 0
    account.twitter_handles.order("created_at asc").find_each do |twitter|
      next if twitter_count < 1
      twitter.destroy
      twitter_count+=1
    end
end

def handle_basic_facebook_data
  #we need to keep one fb page. So removing everything except the oldest one.
  fb_count = 0
  account.facebook_pages.order("created_at asc").find_each do |fb|
    next if fb_count < 1
    fb.destroy
    fb_count+=1
  end
end

def handle_occasional_agent_data
  #marking all occasional agents as full time.
  account.agents.where(occasional:true).find_each do |agent|
    agent.occasional = false
    agent.save
  end
end

def handle_custom_status_data
  account.ticket_statuses.where(is_default:false).find_each do |status|
    status.deleted = true
    status.save
    ModifyTicketStatus.perform_async({ :status_id => status.status_id, :status_name => status.name })
  end
end

  def handle_custom_ticket_fields_data
    account.ticket_fields.where(default:false).destroy_all
    #deleting requester widget cache
    key = REQUESTER_WIDGET_FIELDS % { :account_id => account.id }
    MemcacheKeys.delete_from_cache key
    #custom ticket fields and custom status are tied up with same feature name. so handle deletion together!
    handle_custom_status_data
  end

  def handle_custom_contact_fields_data
    account.contact_form.custom_contact_fields.each do |c_f|
      c_f.destroy
    end
    clear_contact_fields_cache
  end

  def handle_custom_company_fields_data
    account.company_form.custom_company_fields.each do |c_f|
      c_f.destroy
    end
    clear_company_fields_cache
  end

  def handle_custom_ticket_views_data
    account.ticket_filters.destroy_all
  end

  def handle_rebranding_data
    main_portal = account.main_portal
    main_portal.preferences = default_portal_preferences
    main_portal.save
    key = ACCOUNT_MAIN_PORTAL % { :account_id => account.id }
    MemcacheKeys.delete_from_cache key
  end

  def handle_custom_apps_data
    begin
      Integrations::Application.freshplugs(account).destroy_all
      
      # Remove fa_developer feature - To prevent the developer from using Marketplac Developer portal
      account.features.fa_developer.destroy if account.features_included?(:fa_developer)

      # Remove the installed custom apps from Marketplace
      custom_apps_ext_ids = []
      installed_apps_ext_ids = []
      total_custom_apps = mkp_custom_apps
      if error_status?(total_custom_apps)
        Rails.logger.info  "Error in fetching custom apps from Global API"
        return
      else
        custom_apps_ext_ids = total_custom_apps.body.map { |ext| ext['id'] }
      end

      installed_apps_payload = account_payload(
        Marketplace::ApiEndpoint::ENDPOINT_URL[:installed_extensions] % 
        { :product_id => Marketplace::Constants::PRODUCT_ID, :account_id => account.id},
        {}, {:type => Marketplace::Constants::EXTENSION_TYPE[:plug]}
        )
      installed_apps_response = get_api(installed_apps_payload, MarketplaceConfig::ACC_API_TIMEOUT)
      if error_status?(installed_apps_response)
        Rails.logger.info  "Error in fetching installed custom apps from Account API"
        return
      else
        installed_apps_ext_ids = installed_apps_response.body.map { |ext| ext['extension_id'] }  
      end

      extensions_to_delete = custom_apps_ext_ids & installed_apps_ext_ids
      extensions_to_delete.each do |extension_id|
        uninstall_response = uninstall_extension({:extension_id => extension_id })
        if error_status?(uninstall_response)
          Rails.logger.info  "Error in uninstalling the custom apps in Account API"
          return
        else
          Rails.logger.info  "Done uninstalling the custom app with extension_id: #{extension_id}"
        end
      end
    rescue Exception => e
      Rails.logger.info "Exception in custom apps data deletion.. #{e.backtrace}"
      NewRelic::Agent.notice_error(e)
      raise e
    end
  end


  def handle_customer_slas_data
    account.sla_policies.where(is_default:false).destroy_all
    update_all_in_batches({ :sla_policy_id => account.sla_policies.default.first.id }) { |cond|
      account.companies.where(@conditions).limit(@batch_size).update_all(cond)
    }
    #account.sla_details.update_all(:override_bhrs => true) #this too didn't work.
    update_all_in_batches({ :override_bhrs => true }){ |cond| 
      account.sla_policies.default.first.sla_details.where(@conditions).limit(@batch_size).update_all(cond)
    }
  end

  def handle_multiple_business_hours_data
    update_all_in_batches({ :time_zone => account.time_zone }){ |cond| 
      records = account.all_users.where(@conditions).limit(@batch_size)
      count   = records.update_all(cond)
      records.map(&:sqs_manual_publish)
      count
    }
  end

  def handle_multiple_emails_data
    account.global_email_configs.where(primary_role:false).each do |ec|
      ec.destroy
    end
  end

  def handle_multi_product_data
    account.products.destroy_all
  end

  private

  def default_portal_preferences
    HashWithIndifferentAccess.new(
    {
      :bg_color => "#efefef",
      :header_color => "#252525",
      :tab_color => "#006063",
      :personalized_articles => true
    }
    )
  end


  def update_all_in_batches(change_hash)
    change_hash.symbolize_keys!
    frame_conditions(change_hash)
    begin
      updated_count = yield(change_hash)
    end while updated_count == @batch_size
    nil
  end

  def frame_conditions(change_hash)
    # Excluding created_at, updated_at as != is bad check
    @conditions = [[]]
    @batch_size = change_hash.delete(:batch_size) || 500
    change_hash.except(:created_at, :updated_at).each do |key ,value|
      if value.nil?
        @conditions[0] << "`#{key}` is not null"
      else
        @conditions[0] << "`#{key}` != ?"
        @conditions << value
      end
    end
    @conditions[0] = @conditions[0].join(" and ")
    nil
  end
end
