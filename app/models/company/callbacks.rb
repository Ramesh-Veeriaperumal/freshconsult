class Company < ActiveRecord::Base
  
  after_commit :map_contacts_to_company, on: :create
  after_commit :nullify_contact_mapping, on: :destroy
  after_commit :clear_cache
  after_update :map_contacts_on_update, :if => :domains_changed?
  
  before_create :check_sla_policy
  before_validation :update_company_domains, :if => :domains_changed?
  before_update :check_sla_policy, :backup_company_changes
  before_save :format_domain, :if => :domains_changed?
  
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
      domain_changes = @model_changes[:domains]
      old_list = domains_array(domain_changes[0])
      new_list = domains_array(domain_changes[1])
      new_domains = new_list - old_list
      old_domains = old_list - new_list
      map_contacts_to_company(new_domains) if new_domains.present?
      Users::UpdateCompanyId.perform_async({ :domains => old_domains, 
                                             :company_id => nil,
                                             :current_company_id => self.id }) if old_domains.present?
    end
    
    def map_contacts_to_company(domains = domains_array(self.domains) )
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

    def domains_array(domains)
      domains ||= ""
      domains.split(",").collect(&:strip).reject(&:blank?)
    end

    def format_domain
      self.domains = domains_array(self.domains).join(',').prepend(",").concat(",") if self.domains
    end

    def added_domains
      domain_changes = self.changes[:domains]      
      domains_array(domain_changes[1]) - domains_array(domain_changes[0])
    end

    def removed_domains
      domain_changes = self.changes[:domains]     
      domains_array(domain_changes[0]) - domains_array(domain_changes[1])
    end

    def update_company_domains
      self.company_domains_attributes = [domain_hash_list(added_domains), domain_hash_list(removed_domains, true)].flatten.uniq
    rescue
      errors.add(:base,"#{I18n.t('companies.valid_comapany_domain')}")
    end

    def domain_hash_list(domains_list, destroy=false)
      domains_list.collect do |dom|
        dom = get_host_without_www dom
        id = self.company_domains.find_by_domain(dom).try(:id)
        {:id=>id, :domain=>dom, :_destroy=>destroy}
      end
    end

    def get_host_without_www(url)
      uri = URI.parse(url)
      uri = URI.parse("http://#{url}") if uri.scheme.nil?
      host = uri.host.downcase
      host.start_with?('www.') ? host[4..-1] : host
    end

end
