class Admin::VaRulesController < Admin::AutomationsController
  include Va::Constants
  
  skip_before_filter :check_automation_feature
  before_filter :set_filter_data, :only => [ :create, :update ]
  
  def index
    @inactive_rules = all_scoper.disabled
    super
  end
    
  def deactivate
    va_rule = scoper.find(params[:id])
    va_rule.active = false
    va_rule.save
    redirect_back_or_default redirect_url
  end
  
  def activate
    va_rule = all_scoper.disabled.find(params[:id])
    va_rule.active = true
    va_rule.save
    redirect_back_or_default redirect_url
  end
 
  protected
    def scoper
      current_account.va_rules
    end
    
    def all_scoper
      current_account.all_va_rules
    end
    
    def human_name
      "Dispatch'r rule"
    end
    
    def set_filter_data
      @va_rule.filter_data = params[:filter_data].blank? ? [] : ActiveSupport::JSON.decode(params[:filter_data])
      set_nested_fields_data @va_rule.filter_data
    end

    def edit_data
      @filter_input = ActiveSupport::JSON.encode @va_rule.filter_data
      super
    end
    
    def load_object
      @va_rule = all_scoper.find(params[:id])
      @obj = @va_rule #Destroy of model-controller-methods needs @obj
    end
    
    def load_config
      super
      
      @agents = current_account.users.technicians.inject([["", I18n.t('ticket.none')]]) do |agents, au|
                agents << [au.id, au.name]
                agents
              end
      @groups  = current_account.groups.find(:all, :order=>'name').inject([["", I18n.t('ticket.none')]]) do |groups, ag|
                groups << [ag.id, ag.name]
                groups
              end

      filter_hash   = [
        { :name => -1, :value => "--- #{t('click_to_select_filter')} ---" },
        { :name => "from_email", :value => t('from_email'), :domtype => "autocompelete", 
          :data_url => autocomplete_helpdesk_authorizations_path, :operatortype => "email" },
        { :name => "to_email", :value => t('to_email'), :domtype => "text",
          :operatortype => "email" },
        { :name => -1, :value => "--------------------------" },
        { :name => "subject", :value => t('ticket.subject'), :domtype => "text",
          :operatortype => "text" },
        { :name => "description", :value => t('description'), :domtype => "text",
          :operatortype => "text" },
        { :name => "subject_or_description", :value =>  t('subject_or_description'), 
          :domtype => "text", :operatortype => "text" },
        { :name => "priority", :value => t('ticket.priority'), :domtype => "dropdown", 
          :choices => Helpdesk::Ticket::PRIORITY_NAMES_BY_KEY.sort, :operatortype => "choicelist" },
        { :name => "ticket_type", :value => t('ticket.type'), :domtype => "dropdown", 
          :choices => current_account.ticket_type_values.collect { |c| [ c.value, c.value ] }, 
          :operatortype => "choicelist" },
        { :name => "status", :value => t('ticket.status'), :domtype => "dropdown", 
          :choices => Helpdesk::TicketStatus.status_names(current_account), :operatortype => "choicelist"},
        { :name => "source", :value => t('ticket.source'), :domtype => "dropdown", 
          :choices => Helpdesk::Ticket::SOURCE_NAMES_BY_KEY.sort, :operatortype => "choicelist" },
        { :name => "responder_id", :value => I18n.t('ticket.agent'), :domtype => "dropdown",
          :operatortype => "object_id", :choices => @agents },
        { :name => "group_id", :value => I18n.t('ticket.group'), :domtype => "dropdown",
          :operatortype => "object_id", :choices => @groups },
        { :name => -1, :value => "------------------------------" },
        { :name => "contact_name", :value => t('contact_name'), :domtype => "text", 
          :operatortype => "text" },
        { :name => "company_name", :value => t('company_name'), :domtype => "text", 
          :operatortype => "text"}]
                                                   
      filter_hash = filter_hash + additional_filters
      add_custom_filters filter_hash
      @filter_defs  = ActiveSupport::JSON.encode filter_hash
      @op_types     = ActiveSupport::JSON.encode OPERATOR_TYPES
      @op_list      = ActiveSupport::JSON.encode OPERATOR_LIST
    end
    
    def additional_actions
      {}
    end
    
    def additional_filters
      []
    end
  
    def add_custom_filters filter_hash
      current_account.ticket_fields.custom_fields.each do |field|
        filter_hash.push({
          :id => field.id,
          :name => field.name,
          :value => field.label,
          :field_type => field.field_type,
          :domtype => (field.field_type == "nested_field") ? "nested_field" : field.flexifield_def_entry.flexifield_coltype,
          :choices =>  (field.field_type == "nested_field") ? field.nested_choices : field.picklist_values.collect { |c| [c.value, c.value ] },
          :action => "set_custom_field",
          :operatortype => CF_OPERATOR_TYPES.fetch(field.field_type, "text"),
          :nested_fields => nested_fields(field)
        })
      end
    end
  
end
