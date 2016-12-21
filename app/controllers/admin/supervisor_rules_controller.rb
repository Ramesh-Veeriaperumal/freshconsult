class Admin::SupervisorRulesController < Admin::VaRulesController
  
  before_filter { |c| c.requires_admin_feature :supervisor }
  protected
  
    def scoper
      current_account.supervisor_rules
    end
    
    def all_scoper
      current_account.all_supervisor_rules
    end
    
    def human_name
      "Supervisor rule"
    end

    def get_event_performer
      []
    end

end
