class SAAS::AccountDataCleanup
  include Marketplace::ApiMethods
  include Cache::Memcache::ContactField
  include Cache::Memcache::CompanyField
  include Cache::FragmentCache::Base
  include MemcacheKeys
  include AddTamDefaultFieldsHelper
  include SAAS::DropFeatureData
  include SAAS::AddFeatureData

  attr_accessor :account, :features_to_process, :action

  def initialize(account = Account.current, features_to_process = [], action = 'drop')
    @account = account
    @action  = action
    @features_to_process = features_to_process
  end

  def perform_cleanup
    features_to_process.each do |feature|
      method = "handle_#{feature}_#{action}_data"
      begin
        safe_send(method) if respond_to?(method)
      rescue Exception => e
        NewRelic::Agent.notice_error(e)
      end
    end
    clear_fragment_caches
  end


  def handle_create_observer_drop_data
    account.all_observer_rules.find_each do |rule|
      rule.destroy
    end
    Rails.logger.info "Deleting all observer rules and creating fixtures again #{account.id}"
    account.reload
    Fixtures::DefaultObserver.create_rule
  end

def handle_supervisor_drop_data
  account.all_supervisor_rules.destroy_all
end

def handle_add_watcher_drop_data
  account.ticket_subscriptions.find_each do |ts|
    ts.destroy
  end
end

def handle_basic_twitter_drop_data
  Social::TwitterHandle.drop_advanced_twitter_data(account)
end

def handle_basic_facebook_drop_data
  #we need to keep one fb page. So removing everything except the oldest one.
  fb_count = 0
  account.facebook_pages.order("created_at asc").find_each do |fb|
    next if fb_count < 1
    fb.destroy
    fb_count+=1
  end
end

  def handle_skill_based_round_robin_drop_data
    account.groups.skill_based_round_robin_enabled.each do |group|
      if account.features?(:round_robin_load_balancing) || account.features?(:round_robin) 
        group.ticket_assign_type = Group::TICKET_ASSIGN_TYPE[:round_robin]
        group.capping_limit = 0 unless account.features?(:round_robin_load_balancing)
        group.save!
      else
        group.turn_off_automatic_ticket_assignment
      end
    end
    account.skills.destroy_all
  end

  def handle_round_robin_load_balancing_drop_data
    account.groups.capping_enabled_groups.each do |group|
      group.turn_off_automatic_ticket_assignment
    end 
  end

  def handle_round_robin_drop_data
    account.groups.basic_round_robin_enabled.each do |group|
      group.turn_off_automatic_ticket_assignment
    end 
  end
  
  def handle_occasional_agent_drop_data
    #marking all occasional agents as full time.
    account.agents.where(occasional:true).find_each do |agent|
      agent.occasional = false
      agent.save
    end
  end

  def handle_custom_status_drop_data
    account.ticket_statuses.where(is_default:false).find_each do |status|
      status.deleted = true
      status.save
      ModifyTicketStatus.perform_async({ :status_id => status.status_id, :status_name => status.name })
    end
  end

  def handle_custom_ticket_fields_drop_data
    account.ticket_fields.where(default:false).destroy_all
    #deleting requester widget cache
    key = REQUESTER_WIDGET_FIELDS % { :account_id => account.id }
    MemcacheKeys.delete_from_cache key
    #custom ticket fields and custom status are tied up with same feature name. so handle deletion together!
    handle_custom_status_drop_data
  end

  def handle_custom_contact_fields_drop_data
    account.contact_form.custom_contact_fields.each do |c_f|
      c_f.destroy
    end
    clear_contact_fields_cache
  end

  def handle_custom_company_fields_drop_data
    account.company_form.custom_company_fields.each do |c_f|
      c_f.destroy
    end
    clear_company_fields_cache
  end

  def handle_custom_ticket_views_drop_data
    account.ticket_filters.destroy_all
  end

  def handle_rebranding_drop_data
    main_portal = account.main_portal
    main_portal.preferences = default_portal_preferences
    main_portal.save
    key = ACCOUNT_MAIN_PORTAL % { :account_id => account.id }
    MemcacheKeys.delete_from_cache key
  end

  def handle_unique_contact_identifier_drop_data
    account.revoke_feature(:unique_contact_identifier)
    external_id_field = account.contact_form.default_fields.where(name: 'unique_external_id').first
    if external_id_field.present?
      external_id_field.visible_in_portal = false
      if external_id_field.field_options && external_id_field.field_options["widget_position"].present?
        external_id_field.field_options.delete("widget_position")
      end
      external_id_field.save
    end
    clear_contact_fields_cache
  end

  def handle_custom_apps_drop_data
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
        {}, {:type => "#{Marketplace::Constants::EXTENSION_TYPE[:plug]},#{Marketplace::Constants::EXTENSION_TYPE[:custom_app]}"}
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


  def handle_customer_slas_drop_data
    account.sla_policies.where(is_default:false).destroy_all
    update_all_in_batches({ :sla_policy_id => account.sla_policies.default.first.id }) { |cond|
      account.companies.where(@conditions).limit(@batch_size).update_all(cond)
    }
    #account.sla_details.update_all(:override_bhrs => true) #this too didn't work.
    update_all_in_batches({ :override_bhrs => true }){ |cond|
      account.sla_policies.default.first.sla_details.where(@conditions).limit(@batch_size).update_all(cond)
    }
  end

  def handle_multi_timezone_drop_data
    UpdateTimeZone.perform_async({:time_zone => account.time_zone})
  end

  def handle_multiple_emails_drop_data
    account.global_email_configs.where(primary_role:false).each do |ec|
      ec.destroy
    end
  end

  def handle_multi_product_drop_data
    account.products.destroy_all
  end

  def handle_shared_ownership_toggle_drop_data
    account.revoke_feature(:shared_ownership)
    account.installed_applications.with_name("shared_ownership").destroy_all
    handle_shared_ownership_drop_data
  end

  def handle_shared_ownership_add_data
    account.toggle_shared_ownership true
  end

  def handle_shared_ownership_drop_data
    account.toggle_shared_ownership false
  end

  def handle_link_tickets_toggle_add_data
    account.revoke_feature(:link_tickets_toggle) unless account.update_ticket_dynamo_shard
  end

  def handle_link_tickets_toggle_drop_data
    account.revoke_feature(:link_tickets)
    account.installed_applications.with_name("link_tickets").destroy_all
    handle_link_tickets_drop_data
  end

  def handle_link_tickets_add_data
    clear_fragment_caches
  end

  def handle_link_tickets_drop_data
    ::Tickets::ResetAssociations.perform_async({:link_feature_disable => true})
    clear_fragment_caches
  end

  def handle_parent_child_tickets_toggle_add_data
    account.revoke_feature(:parent_child_tickets_toggle) unless account.update_ticket_dynamo_shard
  end

  def handle_parent_child_tickets_toggle_drop_data
    account.revoke_feature(:parent_child_tickets)
    account.installed_applications.with_name("parent_child_tickets").destroy_all
    handle_parent_child_tickets_drop_data
  end

  def handle_parent_child_tickets_add_data
    clear_fragment_caches
  end

  def handle_parent_child_tickets_drop_data
    ::Tickets::ResetAssociations.perform_async({:parent_child_feature_disable => true})
    clear_fragment_caches
    obj = account.features?(:ticket_templates) ? "parent" : "prime"
    account.safe_send("#{obj}_templates").destroy_all
  end

  def handle_ticket_activity_export_drop_data
    ticket_activity_export = account.activity_export
    return if ticket_activity_export.nil? || !ticket_activity_export.active
    ticket_activity_export.active = false
    ticket_activity_export.save
  end

  def handle_auto_ticket_export_drop_data
    account.scheduled_ticket_exports.destroy_all
  end

  def handle_multiple_companies_toggle_drop_data
    account.remove_secondary_companies
  end

  def handle_multiple_companies_toggle_add_data
    unless account.ticket_fields_from_cache.find { |tf| tf.name == "company"}.present?
      account.ticket_fields.create(:name => "company",
                                   :label => "Company",
                                   :label_in_portal => "Company",
                                   :description => "Ticket Company",
                                   :field_type => "default_company",
                                   :position => account.ticket_fields_from_cache.length+1,
                                   :default => true,
                                   :required => true,
                                   :visible_in_portal => true, 
                                   :editable_in_portal => true,
                                   :required_in_portal => true,
                                   :ticket_form_id => account.ticket_field_def.id)
      clear_fragment_caches
    end
  end

  def handle_tam_default_fields_add_data
    populate_tam_fields_data
  end

  def handle_smart_filter_add_data
    account.twitter_handles.order("created_at asc").find_each do |twitter|
      twitter.default_stream.prepare_for_upgrade_from_sprout
    end
  end

  def handle_unique_contact_identifier_add_data
    unless account.contact_form.default_fields.find { |tf| tf.name == "unique_external_id"}.present?
      contact_fields = {
                          :account_id => account.id,
                          :contact_form_id => account.contact_form.id,
                          :name => "unique_external_id",
                          :column_name => 'default',
                          :label => "Unique External Id",
                          :label_in_portal => "Unique External Id",
                          :deleted => 0,
                          :field_type => ContactField::DEFAULT_FIELD_PROPS[:default_unique_external_id][:type],
                          :position => account.contact_form.contact_fields.length,
                          :required_for_agent => 0,
                          :visible_in_portal => 0,
                          :editable_in_portal => 0,
                          :editable_in_signup => 0,
                          :required_in_portal => 0,
                          :created_at => Time.now.to_s(:db),
                          :updated_at => Time.now.to_s(:db)
                        }
        ActiveRecord::Base.connection.execute(%(
        INSERT INTO contact_fields (#{contact_fields.keys.join(",")}) VALUES 
        (#{contact_fields.values.map{|f| "'#{f}'"}.join(",")})
        ))
      clear_contact_fields_cache
    end
  end

  def handle_support_bot_drop_data
    account.bots.destroy_all
    account.clear_bots_from_cache
  end

  def handle_custom_dashboard_drop_data
    account.dashboards.destroy_all
  end

  def handle_custom_dashboard_add_data
    account.launch(:es_msearch)
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
