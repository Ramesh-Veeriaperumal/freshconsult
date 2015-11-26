class Company < ActiveRecord::Base
  
  after_commit :map_contacts_to_company, on: :create
  after_commit :nullify_contact_mapping, on: :destroy
  after_commit :clear_cache
  after_update :map_contacts_on_update, :if => :domains_changed?
  
  before_create :check_sla_policy
  before_update :check_sla_policy, :backup_company_changes
  
  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  #include RabbitMq::Publisher
  
  
  #setting default sla
  def check_sla_policy    
    if self.sla_policy_id.nil?   
      default_sla_policy = account.sla_policies.default.first    
      self.sla_policy_id = default_sla_policy ? default_sla_policy.id : nil
    end    
  end
  
  private
  
    def map_contacts_on_update
      domain_changes = @model_changes[:domains].compact
      old_list = (domain_changes[0] || "").split(",").collect(&:strip)
      new_list = (domain_changes[1] || "").split(",").collect(&:strip)
      new_domains = new_list - old_list
      old_domains = old_list - new_list
      map_contacts_to_company(new_domains) if new_domains.present?
      Users::UpdateCompanyId.perform_async({ :domains => old_domains, 
                                             :company_id => nil,
                                             :current_company_id => self.id }) if old_domains.present?
    end
    
    def map_contacts_to_company(domains = self.domains)
      Users::UpdateCompanyId.perform_async({ :domains => domains, :company_id => self.id }) unless domains.blank?
    end
    
    def backup_company_changes
      @model_changes = self.changes.clone.to_hash
      @model_changes.merge!(flexifield.changes)
      @model_changes.symbolize_keys!
    end

    def nullify_contact_mapping
      Users::UpdateCompanyId.perform_async({ :company_id => nil,
                                             :current_company_id => self.id })
    end
end
