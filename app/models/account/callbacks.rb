class Account < ActiveRecord::Base

  before_create :downcase_full_domain,:set_default_values, :set_shard_mapping, :save_route_info
  before_create :add_features_to_binary_column
  before_update :check_default_values, :update_users_time_zone, :backup_changes
  before_destroy :backup_changes, :make_shard_mapping_inactive

  after_create :populate_features, :change_shard_status
  after_update :change_shard_mapping, :update_default_business_hours_time_zone,:update_google_domain, :update_route_info
  before_update :update_global_pod_domain 

  after_update :update_freshfone_voice_url, :if => :freshfone_enabled?
  after_update :update_livechat_url_time_zone, :if => :freshchat_enabled?
  after_update :update_activity_export, :if => :ticket_activity_export_enabled?

  before_validation :sync_name_helpdesk_name
  
  after_destroy :remove_global_shard_mapping, :remove_from_master_queries
  after_destroy :remove_shard_mapping, :destroy_route_info

  after_commit :add_to_billing, :enable_elastic_search, on: :create
  after_commit :clear_api_limit_cache, :update_redis_display_id, on: :update
  after_commit ->(obj) { obj.clear_cache }, on: :update
  after_commit ->(obj) { obj.clear_cache }, on: :destroy
  
  after_commit :enable_searchv2, :enable_count_es, :enable_collab, :set_falcon_preferences, on: :create
  after_commit :disable_searchv2, :disable_count_es, on: :destroy
  after_commit :update_sendgrid, on: :create
  after_commit :remove_email_restrictions, on: :update , :if => :account_verification_changed?

  after_commit :update_crm_and_map, on: :update, :if => :account_domain_changed?

  after_commit :update_account_details_in_freshid, on: :update, :if => :update_freshid?
  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher

  after_launchparty_change :trigger_launchparty_feature_callbacks

  def downcase_full_domain
    self.full_domain.downcase!
  end

  def check_default_values
    dis_max_id = get_max_display_id
    if self.ticket_display_id.blank? or (self.ticket_display_id < dis_max_id)
       self.ticket_display_id = dis_max_id
    end
  end

  def update_redis_display_id
    if features?(:redis_display_id) && @all_changes.key?(:ticket_display_id) 
      key = TICKET_DISPLAY_ID % { :account_id => self.id }
      display_id_increment = @all_changes[:ticket_display_id][1] - get_display_id_redis_key(key).to_i - 1
      if display_id_increment > 0
        success = increment_display_id_redis_key(key, display_id_increment)
        set_display_id_redis_key(key, TicketConstants::TICKET_START_DISPLAY_ID) unless success
      end
    end
  end

  def update_users_time_zone #Ideally this should be called in after_update
    if time_zone_changed? && !features.multi_timezone?
      all_users.update_all_with_publish({ :time_zone => time_zone })
    end
  end

  def enable_elastic_search
    SearchSidekiq::CreateAlias.perform_async({ :sign_up => true }) if self.esv1_enabled?
  end

  def populate_features
    add_features_of self.plan_name
    SELECTABLE_FEATURES.each { |key,value| features.send(key).create  if value}
    TEMPORARY_FEATURES.each { |key,value| features.send(key).create  if value}
    ADMIN_CUSTOMER_PORTAL_FEATURES.each { |key,value| features.send(key).create  if value}
    LAUNCHPARTY_FEATURES.select{|k,v| v}.each_key {|feature| self.launch(feature)}
    # Temp for falcon signup
    # Enable customer portal by default
    if falcon_ui_applicable?
      self.launch(:falcon_signup)           # To track falcon signup accounts
      self.launch(:falcon_portal_theme)  unless redis_key_exists?(DISABLE_PORTAL_NEW_THEME)   # Falcon customer portal
      self.launch(:archive_ghost)           # enabling archive ghost feature
    end
  end

  def update_activity_export
    ScheduledExport::ActivitiesExport.perform_async if time_zone_changed? && activity_export_from_cache.try(:active)
  end

  protected

    def set_default_values
      self.time_zone = Time.zone.name if time_zone.nil? #by Shan temp.. to_s is kinda hack.
      self.helpdesk_name = name if helpdesk_name.nil?
      self.shared_secret = generate_secret_token
      self.sso_options = set_sso_options_hash
      self.ssl_enabled = true
    end

    def backup_changes
      @old_object = Account.find(id)
      @all_changes = self.changes.clone
    end

    def account_verification_changed?
      @all_changes.key?("reputation") && self.verified?
    end

    def account_domain_changed?
      @all_changes.key?("full_domain")
    end

    def account_name_changed?
      @all_changes.key?("name")
    end

    def update_freshid?
      freshid_enabled? && (account_domain_changed? || account_name_changed?)
    end

    def remove_email_restrictions
      AccountActivation::RemoveRestrictionsWorker.perform_async
    end

  private

    # define your callback method in this format ->
    # eg:  on launch  feature_name => falcon, method_name => def falcon_on_launch ; end
    #      on rollback feature_name => falcon, method_name => def falcon_on_rollback ; end
    def trigger_launchparty_feature_callbacks(changes)
      self.make_current
      args = { :feature => changes, :account_id => self.id }
      LaunchPartyActionWorker.perform_async(args)
    end

    def sync_name_helpdesk_name
      self.name = self.helpdesk_name if helpdesk_name_changed?
      self.helpdesk_name = self.name if name_changed?
    end

    def add_to_billing
      Billing::AddSubscriptionToChargebee.perform_async
    end

    def create_shard_mapping
      if Fdadmin::APICalls.non_global_pods? && domain_mapping = DomainMapping.find_by_domain(full_domain) 
        self.id = domain_mapping.account_id
        populate_google_domain(domain_mapping.shard) if google_account?
      else
        shard_mapping = ShardMapping.new({:shard_name => ShardMapping.latest_shard,:status => ShardMapping::STATUS_CODE[:not_found],
                                               :pod_info => PodConfig['CURRENT_POD']})
        shard_mapping.domains.build({:domain => full_domain})  
        populate_google_domain(shard_mapping) if google_account? #remove this when the new google marketplace is stable.
        shard_mapping.save!                            
        self.id = shard_mapping.id
      end
    end

    def set_shard_mapping
      begin
        create_shard_mapping
      rescue => e
        Rails.logger.error e.message
        Rails.logger.error e.backtrace.join("\n\t")
        Rails.logger.info "Shard mapping exception caught"
        errors[:base] << "Domain is not available!"
        return false
      end
    end

    def add_features_to_binary_column
      begin
        bitmap_value = 0
        #This || condition is to handle special case during deployment
        #until new signup is enabled, we need to have older list.
        plan_features_list =  if PLANS[:subscription_plans][self.plan_name].nil?
                                FEATURES_DATA[:plan_features][:feature_list]
                              else
                                PLANS[:subscription_plans][self.plan_name][:features]
                              end
        plan_features_list.each do |key, value|
          bitmap_value = self.set_feature(key)
        end
        self.selectable_features_list.each do |feature_name, enable_on_signup|
          bitmap_value = enable_on_signup ? self.set_feature(feature_name) : bitmap_value
        end 
        # Temp for falcon signup
        # Enable falcon UI for helpdesk by default
        if falcon_ui_applicable?
          [:falcon, :freshcaller].each do |feature_key|
            bitmap_value = self.set_feature(feature_key)
          end
        end
        self.plan_features = bitmap_value
      rescue Exception => e
        Rails.logger.info "Issue in bitmap calculation - account signup #{e.message}"
        NewRelic::Agent.notice_error(e)
      end
    end

    #Remove this when the new marketplace signup is stable and working.
    # Also knock of that google account column from accounts table.
    def populate_google_domain(shard_mapping)
      shard_mapping.build_google_domain({:domain => google_domain})
    end

    def change_shard_mapping
      if full_domain_changed?
        domain_mapping = DomainMapping.find_by_account_id_and_domain(id,@old_object.full_domain)
        domain_mapping.update_attribute(:domain,full_domain)
      end
    end

    def update_global_pod_domain
      if Fdadmin::APICalls.non_global_pods? and full_domain_changed?
        request_parameters = {
          :account_id => id,
          :target_method => :change_domain_mapping_for_pod ,
          :old_domain => @old_object.full_domain,
          :new_domain => full_domain 
        }
        response = Fdadmin::APICalls.connect_main_pod(request_parameters)
        raise ActiveRecord::Rollback, "Domain Already Taken" unless response && response["account_id"]
      end
    end

    def update_google_domain
      if google_domain_changed? and !google_domain.blank?
        gd = GoogleDomain.find_by_account_id(id)
        if gd.nil?  
          gd = GoogleDomain.new
          gd.account_id = id
          gd.domain = google_domain
          gd.save
        else
          gd.update_attribute(:domain,google_domain)
        end
      end
    end

    def change_shard_status
      shard_mapping = ShardMapping.find_by_account_id(id)
      shard_mapping.status = ShardMapping::STATUS_CODE[:ok]
      shard_mapping.save
    end

    def remove_shard_mapping
      shard_mapping = ShardMapping.find_by_account_id(id)
      shard_mapping.destroy
    end

    def remove_global_shard_mapping
      if Fdadmin::APICalls.non_global_pods?
        request_parameters = {:account_id => id,:target_method => :remove_shard_mapping_for_pod }
        PodDnsUpdate.perform_async(request_parameters)
      end
    end

    def make_shard_mapping_inactive
      SendgridDomainUpdates.perform_async({:action => 'delete', :domain => full_domain, :vendor_id => Account::MAIL_PROVIDER[:sendgrid]})
      shard_mapping = ShardMapping.find_by_account_id(id)
      shard_mapping.status = ShardMapping::STATUS_CODE[:not_found]
      shard_mapping.save
    end

    def remove_from_master_queries
      remove_member_from_redis_set(MASTER_QUERIES,self.id)
    end

    def update_freshfone_voice_url
      if full_domain_changed? or ssl_enabled_changed?
        freshfone_account.update_voice_url
      end
    end

    def update_livechat_url_time_zone
      if (full_domain_changed? || time_zone_changed?) && !chat_setting.site_id.blank?
        LivechatWorker.perform_async({
          :account_id    => id,
          :worker_method => "update_site",
          :siteId        => chat_setting.site_id,
          :attributes    => { :site_url => full_domain, :timezone => time_zone }
        })
      end
    end

    def update_default_business_hours_time_zone
      return if self.business_calendar.default.first.nil?
      if time_zone_changed?
        default_business_calender = self.business_calendar.default.first
        default_business_calender.time_zone = self.time_zone
        default_business_calender.save
      end
    end

    def save_route_info
      # add default route info to redis
      Rails.logger.info "Adding domain #{full_domain} to Redis routes."
      Redis::RoutesRedis.set_route_info(full_domain, id, full_domain)
    end

    def destroy_route_info
      Rails.logger.info "Removing domain #{full_domain} from Redis routes."
      Redis::RoutesRedis.delete_route_info(full_domain)
    end

    def update_route_info
      if full_domain_changed?
        vendor_id = Account::MAIL_PROVIDER[:sendgrid]
        Redis::RoutesRedis.delete_route_info(full_domain_was)
        Redis::RoutesRedis.set_route_info(full_domain, id, full_domain)
        Subscription::UpdatePartnersSubscription.perform_async({:event_type => :domain_updated })
        SendgridDomainUpdates.perform_async({:action => 'delete', :domain => full_domain_was, :vendor_id => vendor_id})
        SendgridDomainUpdates.perform_async({:action => 'create', :domain => full_domain, :vendor_id => vendor_id})
      end
    end
    
    def enable_searchv2
      if self.features?(:es_v2_writes)
        if redis_key_exists?(SEARCH_SERVICE_SIGNUP)
          self.launch(:service_reads)
          self.launch(:service_writes)
        end
        SearchV2::Manager::EnableSearch.perform_async
        self.launch(:es_v2_reads)
      end
    end

    def enable_count_es
      if redis_key_exists?(DASHBOARD_FEATURE_ENABLED_KEY)
        CountES::IndexOperations::EnableCountES.perform_async({ :account_id => self.id }) 
      end
    end

    def disable_searchv2
      SearchV2::Manager::DisableSearch.perform_async(account_id: self.id)
    end

    def disable_count_es
      if redis_key_exists?(DASHBOARD_FEATURE_ENABLED_KEY)
       [:admin_dashboard, :agent_dashboard, :supervisor_dashboard].each do |f|
          self.rollback(f)
        end
      end
      #CountES::IndexOperations::DisableCountES.perform_async({ :account_id => self.id, :shard_name => ActiveRecord::Base.current_shard_selection.shard }) unless dashboard_new_alias?
    end

    def update_sendgrid
      SendgridDomainUpdates.perform_async({:action => 'create', :domain => full_domain, :vendor_id => Account::MAIL_PROVIDER[:sendgrid]})
    end

    def enable_collab
      CollabPreEnableWorker.perform_async
    end

    def set_falcon_preferences
      if falcon_ui_applicable?
        self.main_portal.template.preferences = self.main_portal.template.default_preferences.merge({:personalized_articles=>true})
        self.main_portal.template.save!
      end
    end

    def update_crm_and_map
      if (Rails.env.production? or Rails.env.staging?)
        Resque.enqueue_at(15.minutes.from_now, CRM::AddToCRM::UpdateAdmin, {:account_id => self.id})
        Resque.enqueue_at(15.minutes.from_now, Marketo::AddLead, {:account_id => self.id})
      end
    end

    def update_account_details_in_freshid
      account = self.make_current
      account_details_params = { name: account.name, account_id: account.id }
      account_details_params[:domain] = account_domain_changed? ? @all_changes[:full_domain].first : account.full_domain
      account_details_params[:new_domain] = account_domain_changed? ? account.full_domain : nil
      Freshid::AccountDetailsUpdate.perform_async(account_details_params)
    end

    def falcon_ui_applicable?
      ismember?(FALCON_ENABLED_LANGUAGES, self.language)
    end

end
