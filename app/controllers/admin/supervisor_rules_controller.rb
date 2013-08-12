class Admin::SupervisorRulesController < Admin::VaRulesController
  
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

end
