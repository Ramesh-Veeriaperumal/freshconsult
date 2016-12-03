class SAAS::AccountDataCleanup

  include Marketplace::ApiMethods
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
  end

  def handle_create_observer_data
    account.all_observer_rules.destroy_all
    Fixtures::DefaultObserver.create_rule
  end

  def handle_supervisor_data
    account.all_supervisor_rules.destroy_all
  end 

  def handle_add_watcher_data
    account.ticket_subscriptions.destroy_all
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
  end

  def handle_custom_contact_fields_data
    account.contact_form.custom_contact_fields.destroy_all
  end

  def handle_custom_company_fields_data
    account.company_form.custom_company_fields.destroy_all
  end

  def handle_custom_ticket_views_data
    account.ticket_filters.destroy_all
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

end