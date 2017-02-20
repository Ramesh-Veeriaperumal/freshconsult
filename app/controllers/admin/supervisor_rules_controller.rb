class Admin::SupervisorRulesController < Admin::VaRulesController
  
  before_filter :check_supervisor_feature
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

    def check_supervisor_feature
      non_covered_admin_feature unless current_account.supervisor_enabled?
    end

end
