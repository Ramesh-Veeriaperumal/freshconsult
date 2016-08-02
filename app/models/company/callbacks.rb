class Company < ActiveRecord::Base
  
  after_commit :clear_cache
  after_commit :nullify_contact_mapping, on: :destroy
  after_commit :inst_app_business_event_create, on: :create, :if => :allow_inst_app_business_rule?
  after_commit :inst_app_business_event_update, on: :update, :if => :allow_inst_app_business_rule?
  
  before_create :check_sla_policy
  before_update :check_sla_policy, :backup_company_changes

  
  # Callbacks will be executed in the order in which they have been included. 
  # Included rabbitmq callbacks at the last
  include RabbitMq::Publisher
  
  
  #setting default sla
  def check_sla_policy    
    if self.sla_policy_id.nil?   
      default_sla_policy = account.sla_policies.default.first    
      self.sla_policy_id = default_sla_policy ? default_sla_policy.id : nil
    end    
  end
  
  private
    
    def backup_company_changes
      @model_changes = self.changes.clone.to_hash
      @model_changes.merge!(flexifield.changes)
      @model_changes.merge!(company_domains_changes || {})
      @model_changes.symbolize_keys!
    end

    def nullify_contact_mapping
      Users::UpdateCompanyId.perform_async({ :domains => nil,
                                             :company_id => nil,
                                             :current_company_id => self.id })
    end

    def company_domains_changes
      new_dom = []
      old_dom = []
      company_domains.each do |x|
        new_dom << x.domain unless x.marked_for_destruction?
        old_dom << x.domain unless x.new_record?
      end
      return {:domains => [ old_dom, new_dom] } if old_dom != new_dom
    end
end
