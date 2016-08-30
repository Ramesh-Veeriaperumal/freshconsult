class Account < ActiveRecord::Base

  before_create :set_default_values, :set_shard_mapping, :save_route_info
  before_update :check_default_values, :update_users_time_zone, :backup_changes
  before_destroy :backup_changes, :make_shard_mapping_inactive

  after_create :populate_features, :change_shard_status
  after_update :change_shard_mapping, :update_default_business_hours_time_zone,:update_google_domain, :update_route_info
  before_update :update_global_pod_domain 

  after_update :update_freshfone_voice_url, :if => :freshfone_enabled?
  after_update :update_livechat_url_time_zone, :if => :freshchat_enabled?

  after_destroy :remove_global_shard_mapping, :remove_from_slave_queries
  after_destroy :remove_shard_mapping, :destroy_route_info

  after_commit :add_to_billing, :enable_elastic_search, on: :create
  after_commit :clear_api_limit_cache, :update_redis_display_id, on: :update
  after_commit ->(obj) { obj.clear_cache }, on: :update
  after_commit ->(obj) { obj.clear_cache }, on: :destroy
  
  after_commit :enable_searchv2, :enable_count_es, on: :create
  after_commit :disable_searchv2, :disable_count_es, on: :destroy
  after_commit :update_sendgrid, on: :create

  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher 
  
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
    SearchSidekiq::CreateAlias.perform_async({ :sign_up => true }) if ES_ENABLED
  end

  def populate_features
    add_features_of subscription.subscription_plan.name.downcase.to_sym
    SELECTABLE_FEATURES.each { |key,value| features.send(key).create  if value}
    TEMPORARY_FEATURES.each { |key,value| features.send(key).create  if value}
    ADMIN_CUSTOMER_PORTAL_FEATURES.each { |key,value| features.send(key).create  if value}
    add_member_to_redis_set(SLAVE_QUERIES, self.id)
    #self.launch(:disable_old_sso)
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

  private

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

    def remove_from_slave_queries
      remove_member_from_redis_set(SLAVE_QUERIES,self.id)
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
      SearchV2::Manager::EnableSearch.perform_async if self.features_included?(:es_v2_writes)
    end

    def enable_count_es
      CountES::IndexOperations::EnableCountES.perform_async({ :account_id => self.id }) if Account.current.features?(:countv2_writes)
    end

    def enable_count_es
      CountES::IndexOperations::EnableCountES.perform_async({ :account_id => self.id }) if Account.current.features?(:count_es_writes)
    end
    
    def disable_searchv2
      SearchV2::Manager::DisableSearch.perform_async(account_id: self.id)
    end

    def disable_count_es
      CountES::IndexOperations::DisableCountES.perform_async({ :account_id => self.id, :shard_name => ActiveRecord::Base.current_shard_selection.shard })
    end

    def update_sendgrid
      SendgridDomainUpdates.perform_async({:action => 'create', :domain => full_domain, :vendor_id => Account::MAIL_PROVIDER[:sendgrid]})
    end
end
