class Admin::VaRulesController < Admin::AutomationsController
  
  skip_before_filter :check_automation_feature
  
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
      
    default_filter_hash   = [{:name => 0              , :value => "--- Click to Select Filter ---"},
                        {:name => "from_email"   , :value => "From Email", :domtype => "autocompelete", :data_url => autocomplete_helpdesk_authorizations_path, 
                                                   :operatortype => "email"},
                        {:name => "to_email"     , :value => "To Email"  , :domtype => "text",
                                                   :operatortype => "email"},
                        {:name => 0              , :value => "--------------------------"},
                        {:name => "subject"      , :value => "Subject",       :domtype => "text",
                                                   :operatortype => "text"},
                        {:name => "description"  , :value => "Description",   :domtype => "text",
                                                   :operatortype => "text"},
                        {:name => "subject_or_description", :value => "Subject or Description",   :domtype => "text",
                                                   :operatortype => "text"},
                        {:name => "priority"     , :value => "Priority",      :domtype => "dropdown", :choices => Helpdesk::Ticket::PRIORITY_NAMES_BY_KEY.sort, 
                                                   :operatortype => "choicelist"},                        
                        {:name => "ticket_type"  , :value => "Type",          :domtype => "dropdown", :choices => Helpdesk::Ticket::TYPE_NAMES_BY_KEY.sort, 
                                                   :operatortype => "choicelist"},
                        {:name => "status"       , :value => "Status",        :domtype => "dropdown", :choices => Helpdesk::Ticket::STATUS_NAMES_BY_KEY.sort, 
                                                   :operatortype => "choicelist"},
                        {:name => "source"       , :value => "Source",        :domtype => "dropdown", :choices => Helpdesk::Ticket::SOURCE_NAMES_BY_KEY.sort, 
                                                   :operatortype => "choicelist"},
                        {:name => 0              , :value => "------------------------------"},
                        {:name => "contact_name" , :value => "Contact Name",  :domtype => "text",
                                                   :operatortype => "text"},
                        {:name => "company_name" , :value => "Company Name",  :domtype => "text", 
                                                   :operatortype => "text"}]
                                                   
      filter_hash = add_custom_filters default_filter_hash
      
      @filter_defs   = ActiveSupport::JSON.encode filter_hash
      
      operator_types  = {:email       => ["is", "is_not", "contains", "does_not_contain"],
                         :text        => ["is", "is_not", "contains", "does_not_contain", "starts_with", "ends_with"],
                         :checkbox    => ["selected", "not_selected"],
                         :choicelist  => ["is", "is_not"]}
      
      @op_types        = ActiveSupport::JSON.encode operator_types
      
      operator_list  =  {:is                =>  "Is",
                         :is_not            =>  "Is not",
                         :contains          =>  "Contains",
                         :does_not_contain  =>  "Does not contain",
                         :starts_with       =>  "Starts with",
                         :ends_with         =>  "Ends with",
                         :between           =>  "Between",
                         :between_range     =>  "Between Range",
                         :selected          =>  "Selected",
                         :not_selected      =>  "Not Selected" } 
      
      @op_list        = ActiveSupport::JSON.encode operator_list
    end
    
    def additional_actions
      {}
    end
  
  protected
  
  def add_custom_filters filter_hash
  
   @ticket_field = Helpdesk::FormCustomizer.find(:first ,:conditions =>{:account_id => current_account.id})
   
   @json_data = ActiveSupport::JSON.decode(@ticket_field.json_data)
   
   @json_data.each do |field|
     
     if field["fieldType"].eql?("custom")       
       
        item = {:name =>  field["label"] , :value =>  field["display_name"] ,  :domtype => field["type"], :action => "set_custom_field"  , :operatortype => "text"}
        
        if "dropdown".eql?(field["type"])
          choice_values = get_choices field
          item = {:name =>  field["label"] , :value =>  field["display_name"] ,  :domtype => field["type"], :choices => choice_values , :action => "set_custom_field" , :operatortype => "choicelist" }
        end
        
       if "checkbox".eql?(field["type"])
          choice_values = get_choices field
          item = {:name =>  field["label"] , :value =>  field["display_name"] ,  :domtype => field["type"], :choices => choice_values , :action => "set_custom_field" , :operatortype => "checkbox" }
        end
        
        filter_hash.push(item)
     end
     
   end
   
  return filter_hash
 
end

def get_choices field
  
  Array values =[]
          
  field["choices"].each {|choice| values.push([choice["value"],choice["value"]])}
                  
  return values 
end
  
end
