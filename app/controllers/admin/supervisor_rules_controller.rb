class Admin::SupervisorRulesController < Admin::VaRulesController
  
  STATE_FILTERS = [
    { :name => 0, :value => "------------------------------" },
    { :name => "created_at", :value => I18n.t('ticket.created_at'), :domtype => "number",
      :operatortype => "hours" },
    { :name => "pending_since", :value => I18n.t('ticket.pending_since'), :domtype => "number",
      :operatortype => "hours" },
    { :name => "resolved_at", :value => I18n.t('ticket.resolved_at'), :domtype => "number",
      :operatortype => "hours" },
    { :name => "closed_at", :value => I18n.t('ticket.closed_at'), :domtype => "number",
      :operatortype => "hours" },
    { :name => "opened_at", :value => I18n.t('ticket.opened_at'), :domtype => "number",
      :operatortype => "hours" },
    { :name => "first_assigned_at", :value => I18n.t('ticket.first_assigned_at'), 
      :domtype => "number", :operatortype => "hours" },
    { :name => "assigned_at", :value => I18n.t('ticket.assigned_at'), :domtype => "number",
      :operatortype => "hours" },
    { :name => "requester_responded_at", :value => I18n.t('ticket.requester_responded_at'), 
      :domtype => "number", :operatortype => "hours" },
    { :name => "agent_responded_at", :value => I18n.t('ticket.agent_responded_at'), 
      :domtype => "number", :operatortype => "hours" },
    { :name => "first_response_due", :value => I18n.t('ticket.first_response_due'), 
      :domtype => "number", :operatortype => "hours" },
    { :name => "due_by", :value => I18n.t('ticket.due_by'), :domtype => "number",
      :operatortype => "hours" },
    { :name => "inbound_count", :value => I18n.t('ticket.inbound_count'), :domtype => "number",
      :operatortype => "hours" },
    { :name => 0, :value => "------------------------------" }
  ]
  
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
    
    def additional_filters
      STATE_FILTERS
    end
end
