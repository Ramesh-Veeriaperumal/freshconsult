class Account < ActiveRecord::Base

	before_create :set_default_values, :set_shard_mapping
  before_update :check_default_values, :update_users_time_zone, :backup_changes
  before_destroy :backup_changes, :make_shard_mapping_inactive

  after_create :populate_features, :change_shard_status
  after_update :change_shard_mapping, :update_default_business_hours_time_zone,:update_google_domain
  after_update :update_freshfone_voice_url, :if => :freshfone_enabled?
  after_update :update_freshchat_url, :if => :freshchat_enabled?
  after_destroy :remove_shard_mapping

  after_commit_on_create :add_to_billing, :enable_elastic_search
  after_commit_on_update :clear_cache, :clear_api_limit_cache, :update_redis_display_id
  after_commit_on_destroy :clear_cache, :delete_reports_archived_data


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
      all_users.update_all(:time_zone => time_zone)
    end
  end

  def enable_elastic_search
    Resque.enqueue(Search::CreateAlias, { :account_id => self.id, :sign_up => true })
  end

  def populate_features
    add_features_of subscription.subscription_plan.name.downcase.to_sym
    SELECTABLE_FEATURES.each { |key,value| features.send(key).create  if value}
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
      @all_changes.symbolize_keys!
    end

  private

  	def add_to_billing
      Resque.enqueue(Billing::AddToBilling, { :account_id => id })
    end

    def create_shard_mapping
      shard_mapping = ShardMapping.new({:shard_name => ShardMapping.latest_shard, :status => ShardMapping::STATUS_CODE[:not_found]})
      shard_mapping.domains.build({:domain => full_domain})  
      populate_google_domain(shard_mapping) if google_account?
      shard_mapping.save!                            
      self.id = shard_mapping.id
    end

    def set_shard_mapping
      begin
        create_shard_mapping
       rescue
        Rails.logger.info "Shard mapping exception caught"
        errors.add_to_base("Domain is not available!")
        return false
      end
    end

    def populate_google_domain(shard_mapping)
      shard_mapping.build_google_domain({:domain => google_domain})
    end

    def change_shard_mapping
      if full_domain_changed?
        domain_mapping = DomainMapping.find_by_account_id_and_domain(id,@old_object.full_domain)
        domain_mapping.update_attribute(:domain,full_domain)
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

    def make_shard_mapping_inactive
      shard_mapping = ShardMapping.find_by_account_id(id)
      shard_mapping.status = ShardMapping::STATUS_CODE[:not_found]
      shard_mapping.save
    end

    def delete_reports_archived_data
      Resque.enqueue(Workers::DeleteArchivedData, {:account_id => id})
    end

    def update_freshfone_voice_url
      if full_domain_changed? or ssl_enabled_changed?
        freshfone_account.update_voice_url
      end
    end

    def update_freshchat_url
      Resque.enqueue(Workers::Freshchat, {
        :account_id    => id,
        :worker_method => "update_site", 
        :siteId        => chat_setting.display_id, 
        :attributes    => { :site_url => full_domain }
      }) if full_domain_changed?
    end

    def update_default_business_hours_time_zone
      return if self.business_calendar.default.first.nil?
      if time_zone_changed?
        default_business_calender = self.business_calendar.default.first
        default_business_calender.time_zone = self.time_zone
        default_business_calender.save
      end
    end

end
