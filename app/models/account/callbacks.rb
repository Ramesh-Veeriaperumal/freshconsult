class Account < ActiveRecord::Base

	before_create :set_default_values, :set_shard_mapping
  before_update :check_default_values, :update_users_time_zone, :backup_changes
  before_destroy :update_crm, :backup_changes, :make_shard_mapping_inactive

  after_create :populate_features, :change_shard_status
  after_update :change_shard_mapping, :update_users_language
  after_destroy :remove_shard_mapping

  after_commit_on_create :add_to_billing, :enable_elastic_search
  after_commit_on_update :clear_cache
  after_commit_on_destroy :clear_cache, :delete_reports_archived_data


  def check_default_values
    dis_max_id = get_max_display_id
    if self.ticket_display_id.blank? or (self.ticket_display_id < dis_max_id)
       self.ticket_display_id = dis_max_id
    end
  end

  def update_users_time_zone #Ideally this should be called in after_update
    if time_zone_changed? && !features.multi_timezone?
      all_users.update_all(:time_zone => time_zone)
    end
  end
  
  def update_users_language
    all_users.update_all(:language => main_portal.language) if !features.multi_language? and main_portal
  end

  def enable_elastic_search
    es_index_id = ElasticsearchIndex.es_id_for(self.id)
    self.create_es_enabled_account(:account_id => self.id, :index_id => es_index_id)
  end

  def populate_features
    add_features_of subscription.subscription_plan.name.downcase.to_sym
    SELECTABLE_FEATURES.each { |key,value| features.send(key).create  if value}
  end

  protected

  	def set_default_values
      self.time_zone = Time.zone.name if time_zone.nil? #by Shan temp.. to_s is kinda hack.
      self.helpdesk_name = name if helpdesk_name.nil?
      self.preferences = HashWithIndifferentAccess.new({:bg_color => "#efefef",:header_color => "#252525", :tab_color => "#006063"})
      self.shared_secret = generate_secret_token
      self.sso_options = set_sso_options_hash
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

    def update_crm
      Resque.enqueue(CRM::AddToCRM::DeletedCustomer, id)
    end

    def set_shard_mapping
      shard_mapping = ShardMapping.new({:shard_name => ShardMapping.latest_shard, :status => ShardMapping::STATUS_CODE[:not_found]})
      shard_mapping.domains.build({:domain => full_domain})  
      shard_mapping.save                             
      self.id = shard_mapping.id
    end

    def change_shard_mapping
      if full_domain_changed?
        domain_mapping = DomainMapping.find_by_account_id_and_domain(id,@old_object.full_domain)
        domain_mapping.update_attribute(:domain,full_domain)
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

end