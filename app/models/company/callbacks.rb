class Company < ActiveRecord::Base
  
  after_commit :map_contacts_to_company, on: :create
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
      domain_changes = self.changes["domains"].compact
      domain_changes[0].split(",").map { |domain| 
                    domain_changes[1].gsub!( /(^#{domain}\s?,)|(,?\s?#{domain})/, '') } if domain_changes[1]
      map_contacts_to_company(domain_changes[1].blank? ? domain_changes[0] : domain_changes[1])
    end
    
    def map_contacts_to_company(domains = self.domains)
      User.update_all("customer_id = #{self.id}", 
        ['SUBSTRING_INDEX(email, "@", -1) IN (?) and customer_id is null and account_id = ?', 
        get_domain(domains), self.account_id]) unless domains.blank?
    end
    
    def backup_company_changes
      @model_changes = self.changes.clone.to_hash
      @model_changes.merge!(flexifield.changes)
      @model_changes.symbolize_keys!
    end
    
    def get_domain(domains)
      domains.split(",").map{ |s| s.gsub(/^(\s)?(http:\/\/)?(www\.)?/,'').gsub(/\/.*$/,'') }
    end
    
end