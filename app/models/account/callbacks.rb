class Account < ActiveRecord::Base
  require 'launch_party/feature_class_mapping'
  include Subscription::Currencies::Constants

  before_create :set_default_values, :set_shard_mapping, :save_route_info
  before_create :update_currency_for_anonymous_account, if: :is_anonymous_account
  before_create :add_features_to_binary_column
  validates_inclusion_of :time_zone, in: TIME_ZONES, if: :validate_timezone?
  before_update :check_default_values, :backup_changes, :check_timezone_update
  before_update :update_global_pod_domain
  before_update :generate_encryption_key, if: :enabled_custom_encrypted_fields?
  before_update :delete_encrypted_fields, if: :disabled_custom_encrypted_fields?
  before_update :toggle_parent_child_infra, :if => :parent_child_dependent_features_changed?
  before_update :clear_ocr_data, if: :ocr_feature_disabled?
  before_update :toggle_private_inline_feature, if: :secure_attachments_feature_changed?
  before_destroy :backup_changes, :make_shard_mapping_inactive

  after_create :make_current, :populate_features, :change_shard_status
  after_update :change_dashboard_limit, :if => :field_service_management_enabled_changed?
  after_update :change_shard_mapping, :update_default_business_hours_time_zone,
               :update_google_domain, :update_route_info, :update_users_time_zone

  after_update :clear_domain_cache, :if => :account_domain_changed?
  after_update :update_freshfone_voice_url, :if => :freshfone_enabled?
  after_update :update_livechat_url_time_zone, :if => :livechat_enabled?
  after_update :update_activity_export, :if => :ticket_activity_export_enabled?
  after_update :update_advanced_ticketing_applications, :if => :disable_old_ui_feature_changed?
  after_update :set_disable_old_ui_changed_now, :if => :disable_old_ui_changed?
  after_update :update_round_robin_type, if: :lbrr_by_omniroute_feature_changed?
  after_update :advanced_ticket_scopes_feature_removed?, if: :plan_features_changed?

  before_validation :sync_name_helpdesk_name
  before_validation :downcase_full_domain, :only => [:create , :update] , :if => :full_domain_changed?
  before_validation :build_new_subscription, on: :create
  after_destroy :remove_global_shard_mapping, :remove_from_master_queries
  after_destroy :destroy_freshid_account, if: :freshid_integration_enabled?
  after_destroy :remove_shard_mapping, :destroy_route_info

  after_destroy :destroy_account_email_service

  after_commit :enable_elastic_search, on: :create
  after_commit :add_to_billing, on: :create, unless: :is_anonymous_account
  after_commit :clear_api_limit_cache, :update_redis_display_id, on: :update
  after_commit ->(obj) { obj.clear_cache }, on: :update
  after_commit ->(obj) { obj.clear_cache }, on: :destroy

  after_commit :enable_fresh_connect, on: :create, unless: :is_anonymous_account
  after_commit :enable_searchv2, :enable_count_es, :set_falcon_preferences, on: :create
  after_commit :disable_searchv2, on: :destroy
  after_commit :update_sendgrid, on: :create
  after_commit :remove_email_restrictions, on: :update , :if => :account_verification_changed?

  after_commit :update_crm_and_map, :send_domain_change_email, :update_account_domain_in_chargebee, on: :update, if: :account_domain_changed?
  after_commit :change_fluffy_account_domain, on: :update, if: [:account_domain_changed?, :fluffy_integration_enabled?]
  after_commit :update_bot, on: :update, if: :update_bot?

  after_commit :update_account_details_in_freshid, on: :update, :if => :update_freshid?
  after_commit :trigger_launchparty_feature_callbacks, on: :create
  after_commit :disable_freshid, on: :update, :if => [:sso_enabled_freshid_account?, :freshid_migration_not_in_progress?]
  after_commit :enable_freshid, on: :update, :if => [:sso_disabled_not_freshid_account?, :freshid_migration_not_in_progress?]

  after_commit :mark_customize_domain_setup_and_save, on: :create, if: :full_signup?
  after_commit :update_advanced_ticketing_applications, on: :update, if: :disable_old_ui_changed

  after_commit :remove_organisation_account_mapping, on: :destroy, if: :freshid_org_v2_enabled?
  after_commit :update_help_widgets, on: :update, if: [:help_widget_enabled?, :branding_feature_toggled?]
  after_commit :create_rts_account, on: :create

  after_commit :create_freshvisual_configs, on: :create
  after_commit :update_freshvisual_configs, on: :update, if: :call_freshvisuals_api?
  after_commit :update_account_domain_in_sandbox, if: -> { account_domain_changed? && sandbox_account_id.present? }
  after_commit :trigger_bitmap_feature_callback, if: :advanced_ticket_scopes_removed

  after_commit ->(obj) { obj.perform_qms_operations }, on: :create, if: :quality_management_system_feature_toggled?
  after_commit ->(obj) { obj.perform_qms_operations }, on: :update, if: :quality_management_system_feature_toggled?

  after_rollback :destroy_freshid_account_on_rollback, on: :create, if: -> { freshid_integration_signup_allowed? && !domain_already_exists? }
  after_rollback :signup_completed, on: :create

  after_save :add_or_remove_email_notification_templates, if: :next_response_sla_feature_changed?

  publishable on: [:create, :update]

  attr_accessor :advanced_ticket_scopes_removed

  include MemcacheKeys

  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher

  after_launchparty_change :collect_launchparty_actions

  def downcase_full_domain
    self.full_domain.downcase!
  end

  def contact_info
    account = self.make_current
    account.account_configuration.contact_info.select { |type| CONTACT_DATA.include? type.to_sym }
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

  def update_users_time_zone
    if time_zone_changed? && !multi_timezone_enabled?
      self.set_time_zone_updation_redis
      UpdateTimeZone.perform_async({:time_zone => time_zone})
    end
  end

  def enable_elastic_search
    SearchSidekiq::CreateAlias.perform_async({ :sign_up => true }) if self.esv1_enabled?
  end

  def enable_fresh_connect
    ::Freshconnect::RegisterFreshconnect.perform_async if freshconnect_signup_allowed?
  end

  def create_rts_account
    AccountCreation::RTSAccountCreate.perform_async if agent_collision_revamp_enabled?
  end

  def populate_features
    SELECTABLE_FEATURES.each { |key,value| features.safe_send(key).create  if value}
    TEMPORARY_FEATURES.each { |key,value| features.safe_send(key).create  if value}
    ADMIN_CUSTOMER_PORTAL_FEATURES.each { |key,value| features.safe_send(key).create  if value}
    LAUNCHPARTY_FEATURES.select{|k,v| v}.each_key {|feature| self.launch(feature)}

    launch_condition_based_features

    # Temp for falcon signup
    # Enable customer portal by default
    if falcon_ui_applicable?
      self.launch(:falcon_signup)           # To track falcon signup accounts
      self.launch(:falcon_portal_theme)  unless redis_key_exists?(DISABLE_PORTAL_NEW_THEME)   # Falcon customer portal
    end
    if freshid_integration_signup_allowed?
      freshid_v2_signup? ? launch_freshid_with_omnibar(true) : launch_freshid_with_omnibar
    end
    if redis_key_exists?(ENABLE_AUTOMATION_REVAMP)
      launch(:automation_revamp)
    end
    #next response sla feature based on redis. Remove once its stable
    if redis_key_exists?(ENABLE_NEXT_RESPONSE_SLA)
      launch(:sla_policy_revamp)
    end
    if redis_key_exists?(EMBERIZE_AGENT_FORM)
      [:emberize_agent_form, :emberize_agent_list].each do |feature|
        self.launch(feature)
      end
      self.launch(:omni_chat_agent) if redis_key_exists?(AGENT_CHAT_MANAGEMENT)
    end
  end

  def update_activity_export
    ScheduledExport::ActivitiesExport.perform_async if time_zone_changed? && activity_export_from_cache.try(:active)
  end

  def update_advanced_ticketing_applications
    NewPlanChangeWorker.perform_async({features: [:disable_old_ui], action: @action})
  end

  def parent_child_dependent_features_changed?
    PARENT_CHILD_INFRA_FEATURES.any? { |f| self.safe_send("#{f}_feature_changed?")}
  end

  def toggle_parent_child_infra
    parent_child_infra_features_present? ? self.set_feature(:parent_child_infra) : self.reset_feature(:parent_child_infra)
  end

  def parent_child_infra_features_present?
    PARENT_CHILD_INFRA_FEATURES.any? { |f| self.safe_send("#{f}_enabled?")} 
  end

  def destroy_account_email_service
    account_params = {
      account_id: self.id.to_s,
      account_domain: self.full_domain
    }
    Email::AccountDetailsDestroyWorker.perform_async(account_params)
  end

  # Need to revisit when we push all the events for an account
  def central_publish_worker_class
    "CentralPublishWorker::AccountWorker"
  end

  def save_deleted_model_info
    @deleted_model_info = {
      id: id,
      name: name,
      full_domain: full_domain,
    }
  end

  def generate_encryption_key
    encryption_key = SecureRandom.base64(50)
    AccountEncryptionKeys.update id.to_s, { hipaa_key: encryption_key }
  end

  def clear_ocr_data
    reset_ocr_account_id
    groups.ocr_enabled_groups.each do |group|
      group.turn_off_automatic_ticket_assignment
    end
  end

  def change_dashboard_limit
    if field_service_management_enabled?
      account_additional_settings.increment_dashboard_limit
    else
      account_additional_settings.decrement_dashboard_limit
    end
  end

  def change_fluffy_account_domain
    fluffy_account = current_fluffy_limit(@all_changes[:full_domain].first)
    if fluffy_account.present?
      fluffy_account.name = full_domain
      Fluffy::ApiWrapper.fluffy_add_account(account: fluffy_account)
      destroy_fluffy_account(@all_changes[:full_domain].first)
    end
  end

  def update_round_robin_type
    if lbrr_by_omniroute_enabled?
      groups.capping_enabled_groups.each(&:enable_lbrr_by_omniroute)
    else
      groups.omniroute_powered_rr_groups.each(&:turn_off_automatic_ticket_assignment)
    end
  end

  def toggle_private_inline_feature
    if secure_attachments_enabled?
      self.set_feature(:private_inline)
    else
      self.reset_feature(:private_inline)
    end
  end

  def add_or_remove_email_notification_templates
    next_response_sla_enabled? ? add_nr_email_notifications : remove_nr_email_notifications
  end

  def sandbox_account_id
    @sandbox_account_id ||= sandbox_job.try(:sandbox_account_id)
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

    def check_timezone_update
      self.time_zone = @old_object.time_zone if @all_changes.key?("time_zone") && 
                                                self.time_zone_updation_running?
    end

    def validate_timezone?
      !time_zone_updation_running? && time_zone_changed?
    end

    def account_verification_changed?
      @all_changes.key?("reputation") && self.verified?
    end

    def update_bot?
      return false unless account_domain_changed? || account_ssl_changed?
      portal = self.main_portal
      return false unless portal.portal_url.blank?
      @bot = portal.bot
      return false unless @bot.present?
      true
    end

    def account_domain_changed?
      @all_changes.present? && @all_changes.key?("full_domain")
    end

    def account_ssl_changed?
      @all_changes.key?("ssl_enabled")
    end

    def account_name_changed?
      @all_changes.present? && @all_changes.key?("name")
    end

    def sso_enabled_changed?
      @all_changes.key?('sso_enabled')
    end

    def remove_email_restrictions
      AccountActivation::RemoveRestrictionsWorker.perform_async
    end

    def falcon_ui_applicable?
      ismember?(FALCON_ENABLED_LANGUAGES, self.language)
    end

    def enabled_custom_encrypted_fields?
      custom_encrypted_fields_feature_changed? && hipaa_and_encrypted_fields_enabled?
    end

    def disabled_custom_encrypted_fields?
      custom_encrypted_fields_feature_changed? && !hipaa_and_encrypted_fields_enabled?
    end

    def delete_encrypted_fields
      RemoveEncryptedFieldsWorker.perform_async
    end

    def ocr_feature_disabled?
      omni_channel_routing_feature_changed? && !omni_channel_routing_enabled?
    end

    def perform_qms_operations
      ::QualityManagementSystem::PerformQmsOperationsWorker.perform_async
    end

  private

    def launch_condition_based_features
      condition_based_launchparty_features = get_others_redis_hash(CONDITION_BASED_LAUNCHPARTY_FEATURES)
      if condition_based_launchparty_features.present?
        condition_based_launchparty_features.each { |key, value| self.launch(key.to_sym) if value.to_bool }
      end
    end

    def collect_launchparty_actions(changes)
      feature_name = changes[:launch] || changes[:rollback]
      @launch_party_features ||= []
      @launch_party_features << changes if FeatureClassMapping.get_class(feature_name.to_s)
      # self.new_record? is false in after create hook so using id_changed? method which will be true in all the hook except
      # after_commit for new record or modified record.
      admin_only_mint_on_launch(changes)
      versionize_timestamp unless id_changed?
      trigger_launchparty_feature_callbacks unless self.id_changed?
    end

    # define your callback method in this format ->
    # eg:  on launch  feature_name => falcon, method_name => def falcon_on_launch ; end
    #      on rollback feature_name => falcon, method_name => def falcon_on_rollback ; end
    def trigger_launchparty_feature_callbacks
      return if @launch_party_features.blank?
      args = { :features => @launch_party_features, :account_id => self.id }
      LaunchPartyActionWorker.perform_async(args)
      @launch_party_features = nil
    end

    def trigger_bitmap_feature_callback
      return unless advanced_ticket_scopes_removed

      args = { account_id: id, change: :revoke_feature, feature_name: 'advanced_ticket_scopes' }
      BitmapActionWorker.perform_async(args)
    end

    def sync_name_helpdesk_name
      self.name = self.helpdesk_name if helpdesk_name_changed?
      self.helpdesk_name = self.name if name_changed?
    end

    def admin_only_mint_on_launch(feature_changes)
      if feature_changes[:launch] && feature_changes[:launch].include?(:admin_only_mint)
        self.set_falcon_redis_keys
      end
    end

    def add_to_billing
      if sandbox?
        Billing::AddSubscriptionToChargebee.new.perform
      else
        Billing::AddSubscriptionToChargebee.perform_async
      end
    end

    def update_account_domain_in_chargebee
      Billing::UpdateAccountDomain.perform_async
    end

    def build_new_subscription
      currency = fetch_currency
      self.build_subscription(plan: @plan, next_renewal_at: @plan_start, creditcard: @creditcard, address: @address, affiliate: @affiliate, subscription_currency_id: currency)
      subscription.set_billing_params(currency)
    end

    def fetch_currency
      return DEFAULT_CURRENCY if conversion_metric.nil?

      country = conversion_metric.country
      COUNTRY_MAPPING[country].nil? ? DEFAULT_CURRENCY : COUNTRY_MAPPING[country]
    end

    def create_shard_mapping
      if Fdadmin::APICalls.non_global_pods? && domain_mapping = DomainMapping.find_by_domain(full_domain) 
        self.id = domain_mapping.account_id
        populate_google_domain(domain_mapping.shard) if google_account?
      else
        shard_mapping = ShardMapping.new(shard_name: ShardMapping.current_shard_selection.shard.nil? ? ShardMapping.latest_shard : ShardMapping.current_shard_selection.shard.to_s, status: ShardMapping::STATUS_CODE[:not_found], pod_info: PodConfig['CURRENT_POD'])
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
                                FEATURES_DATA[:plan_features][:feature_list].dup
                              else
                                PLANS[:subscription_plans][self.plan_name][:features].dup
                              end

        plan_features_list.delete(:support_bot) if revoke_support_bot?
        plan_features_list = plan_features_list - (UnsupportedFeaturesList || [])

        plan_features_list.each do |key, value|
          bitmap_value = self.set_feature(key)
        end
        self.selectable_features_list.each do |feature_name, enable_on_signup|
          bitmap_value = enable_on_signup ? self.set_feature(feature_name) : bitmap_value
        end 
        # Temp for falcon signup
        # Enable falcon UI for helpdesk by default
        if falcon_ui_applicable?
          [:falcon, :freshcaller, :freshcaller_widget].each do |feature_key|
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

    def clear_domain_cache
      key = ACCOUNT_BY_FULL_DOMAIN % { :full_domain => @old_object.full_domain }
      MemcacheKeys.delete_from_cache key
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

    def update_currency_for_anonymous_account
      subscription.set_billing_params('USD')
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
      self.launch(:count_service_es_writes)
      self.launch(:count_service_es_reads)
    end

    def disable_searchv2
      SearchV2::Manager::DisableSearch.perform_async(account_id: self.id)
    end

    def update_sendgrid
      SendgridDomainUpdates.perform_async({:action => 'create', :domain => full_domain, :vendor_id => Account::MAIL_PROVIDER[:sendgrid]})
    end

    def set_falcon_preferences
      if falcon_ui_applicable?
        self.main_portal.template.preferences = self.main_portal.template.default_preferences.merge({:personalized_articles=>true})
        self.main_portal.template.save!
      end
    end

    def update_crm_and_map
      if (Rails.env.production? or Rails.env.staging?) && !self.sandbox?
        CRMApp::Freshsales::AdminUpdate.perform_at(15.minutes.from_now, { account_id: id }) unless disable_freshsales_api_integration?
        Subscriptions::AddLead.perform_at(15.minutes.from_now, {:account_id => self.id})
      end
    end

    def freshconnect_signup_allowed?
      redis_key_exists? FRESHCONNECT_NEW_ACCOUNT_SIGNUP_ENABLED
    end

    def update_bot
      response, response_code = Freshbots::Bot.update_bot(@bot)
      raise response unless response_code == Freshbots::Bot::BOT_UPDATION_SUCCESS_STATUS
    rescue => e
      error_msg = "FRESHBOTS UPDATE ERROR FOR ACCOUNT DOMAIN/SSL CHANGE :: Bot external id : #{@bot.external_id}
                         :: Account id : #{@bot.account_id} :: Portal id : #{@bot.portal_id}"
      NewRelic::Agent.notice_error(e, { description: error_msg })
      Rails.logger.error("#{error_msg} :: #{e.inspect}")
    end

    def update_help_widgets
      help_widgets.active.map(&:upload_configs)
    end

    def send_domain_change_email
      account_name = previous_changes.key?("name") ? previous_changes["name"].first : name
      SendDomainChangedMail.perform_async({ account_name: account_name })
    end

    def disable_old_ui_changed?
      self.changes[:plan_features].present? && bitmap_feature_changed?(Fdadmin::FeatureMethods::BITMAP_FEATURES_WITH_VALUES[:disable_old_ui])
    end

    def field_service_management_enabled_changed?
      @all_changes[:plan_features].present? && bitmap_feature_changed?(Fdadmin::FeatureMethods::BITMAP_FEATURES_WITH_VALUES[:field_service_management])
    end

    def advanced_ticket_scopes_feature_removed?
      added_or_drop = changes[:plan_features].present? && bitmap_feature_changed?(Fdadmin::FeatureMethods::BITMAP_FEATURES_WITH_VALUES[:advanced_ticket_scopes])
      Rails.logger.info "Advanced ticket scope #{changes.inspect} => #{added_or_drop}"
      self.advanced_ticket_scopes_removed = (added_or_drop == 'drop')
    end

    # Checks if a bitmap feature has been added or removed
    # old_feature ^ new_feature - Will give the list of all features that have been modified in update call
    # (old_feature ^ new_feature) & (2**feature_val) - Will return zero if the given feature has not been modified
    # old_feature & (2**feature_val) - Checks if the given feature is part of old_feature. If so, the feature has been removed. Else,it's been added.
    def bitmap_feature_changed?(feature_val)
      old_feature = self.changes[:plan_features][0].to_i
      new_feature = self.changes[:plan_features][1].to_i
      return false if ((old_feature ^ new_feature) & (2**feature_val)).zero?
      @action = (old_feature & (2**feature_val)).zero? ? "add" : "drop"
    end

    def set_disable_old_ui_changed_now
      self.disable_old_ui_changed = true
    end

    def call_freshvisuals_api?
      analytics_features_changed?
    end

    def analytics_features_changed?
      reports_features = HelpdeskReports::Constants::FreshvisualFeatureMapping::REPORTS_FEATURES_LIST
      previous_changes[:plan_features].present? && reports_features.any? { |f| safe_send("#{f}_feature_toggled?") }
    end

    def enqueue_freshvisual_configs
      Reports::FreshvisualConfigs.perform_async
    end
    alias create_freshvisual_configs enqueue_freshvisual_configs
    alias update_freshvisual_configs enqueue_freshvisual_configs

    def domain_already_exists?
      domain_mapping = DomainMapping.find_by_domain(full_domain) if full_domain.present?
      domain_mapping.present? && id != domain_mapping.account_id
    end

    def update_account_domain_in_sandbox
      ::Admin::Sandbox::UpdateDomainWorker.perform_async(sandbox_account_id: sandbox_account_id, production_full_domain: full_domain)
    end

    def add_nr_email_notifications
      add_email_notification(EmailNotification::NEXT_RESPONSE_SLA_REMINDER, EmailNotificationConstants::DEFAULT_NR_REMINDER_TEMPLATE)
      add_email_notification(EmailNotification::NEXT_RESPONSE_SLA_VIOLATION, EmailNotificationConstants::DEFAULT_NR_VIOLATION_TEMPLATE)
    end

    def add_email_notification(type, template)
      email_notification = email_notifications.build(
        notification_type: type,
        requester_notification: false,
        agent_notification: true,
        agent_subject_template: template[:agent_subject_template],
        agent_template: template[:agent_template]
      )
      email_notification.save
      email_notification
    end

    def remove_nr_email_notifications
      email_notifications.where(notification_type: [ EmailNotification::NEXT_RESPONSE_SLA_REMINDER, EmailNotification::NEXT_RESPONSE_SLA_VIOLATION ]).destroy_all
    end
end
