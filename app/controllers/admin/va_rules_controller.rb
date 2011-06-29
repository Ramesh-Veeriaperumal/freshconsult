class Admin::VaRulesController < Admin::AutomationsController
  
  skip_before_filter :check_automation_feature
  
  OPERATOR_TYPES = {
    "custom_dropdown" => "choicelist",
    "custom_checkbox" => "checkbox"
  }
  
  def index
    @inactive_rules = current_account.disabled_va_rules
    super
  end
  
  def create
    set_filter_data
    super
  end
  
  def update
    set_filter_data
    super
  end
  
  def set_filter_data
    @va_rule.filter_data = params[:filter_data].blank? ? [] : ActiveSupport::JSON.decode(params[:filter_data])
  end
   
  def deactivate
    va_rule = scoper.find(params[:id])
    va_rule.active = false
    va_rule.save
    redirect_back_or_default redirect_url
  end
  
  def activate
    va_rule = current_account.disabled_va_rules.find(params[:id])
    va_rule.active = true
    va_rule.save
    redirect_back_or_default redirect_url
  end
 
  protected
    def scoper
      current_account.va_rules
    end
    
    def human_name
      "Dispatch'r rule"
    end
    
    def edit_data
      @filter_input = ActiveSupport::JSON.encode @va_rule.filter_data
      super
    end
    
    def load_object
      @va_rule = current_account.all_va_rules.find(params[:id])
      @obj = @va_rule #Destroy of model-controller-methods needs @obj
    end
    
    def load_config
      super
      
      filter_hash   = [
        { :name => 0, :value => "--- #{t('click_to_select_filter')} ---" },
        { :name => "from_email", :value => t('from_email'), :domtype => "autocompelete", 
          :data_url => autocomplete_helpdesk_authorizations_path, :operatortype => "email" },
        { :name => "to_email", :value => t('to_email'), :domtype => "text",
          :operatortype => "email" },
        { :name => 0, :value => "--------------------------" },
        { :name => "subject", :value => t('ticket.subject'), :domtype => "text",
          :operatortype => "text" },
        { :name => "description", :value => t('description'), :domtype => "text",
          :operatortype => "text" },
        { :name => "subject_or_description", :value =>  t('subject_or_description'), 
          :domtype => "text", :operatortype => "text" },
        { :name => "priority", :value => t('ticket.priority'), :domtype => "dropdown", 
          :choices => Helpdesk::Ticket::PRIORITY_NAMES_BY_KEY.sort, :operatortype => "choicelist" },
        { :name => "ticket_type", :value => t('ticket.type'), :domtype => "dropdown", 
          :choices => Helpdesk::Ticket::TYPE_NAMES_BY_KEY.sort, :operatortype => "choicelist" },
        { :name => "status", :value => t('ticket.status'), :domtype => "dropdown", 
          :choices => Helpdesk::Ticket::STATUS_NAMES_BY_KEY.sort, :operatortype => "choicelist" },
        { :name => "source", :value => t('ticket.source'), :domtype => "dropdown", 
          :choices => Helpdesk::Ticket::SOURCE_NAMES_BY_KEY.sort, :operatortype => "choicelist" },
        { :name => 0, :value => "------------------------------" },
        { :name => "contact_name", :value => t('contact_name'), :domtype => "text", 
          :operatortype => "text" },
        { :name => "company_name", :value => t('company_name'), :domtype => "text", 
          :operatortype => "text"}]
                                                   
      add_custom_filters filter_hash
      @filter_defs   = ActiveSupport::JSON.encode filter_hash
      
      operator_types  = {
        :email       => ["is", "is_not", "contains", "does_not_contain"],
        :text        => ["is", "is_not", "contains", "does_not_contain", "starts_with", "ends_with"],
        :checkbox    => ["selected", "not_selected"],
        :choicelist  => ["is", "is_not"]}
      
      @op_types        = ActiveSupport::JSON.encode operator_types
      
      operator_list  =  {:is                =>  t('is'),
                         :is_not            =>  t('is_not'),
                         :contains          =>  t('contains'),
                         :does_not_contain  =>  t('does_not_contain'),
                         :starts_with       =>  t('starts_with'),
                         :ends_with         =>  t('ends_with'),
                         :between           =>  t('between'),
                         :between_range     =>  t('between_range'),
                         :selected          =>  t('selected'),
                         :not_selected      =>  t('not_selected') } 
      
      @op_list        = ActiveSupport::JSON.encode operator_list
    end
    
    def additional_actions
      {}
    end
  
  protected
  
    def add_custom_filters filter_hash
      current_account.ticket_fields.custom_fields.each do |field|
        filter_hash.push({
          :name => field.name,
          :value => field.label,
          :domtype => field.flexifield_def_entry.flexifield_coltype,
          :choices => field.picklist_values.collect { |c| [ c.value, c.value ] },
          :action => "set_custom_field",
          :operatortype => OPERATOR_TYPES.fetch(field.field_type, "text")
        })
      end
    end
  
end
