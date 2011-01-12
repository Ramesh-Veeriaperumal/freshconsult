class VaRulesController < AutomationsController
  
  def index
    @inactive_rules = current_account.disabled_va_rules
    super
  end
  
  def create
    @va_rule.filter_data = ActiveSupport::JSON.decode params[:filter_data]
    super
  end
  
  def edit
    @filter_input = ActiveSupport::JSON.encode @va_rule.filter_data
    super
  end
  
  def update
    @va_rule.filter_data = ActiveSupport::JSON.decode params[:filter_data]
    super
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
      "virtual agent rule"
    end
    
    def load_config
      super
      
      filter_hash    = [{:name => 0              , :value => "--- Click to Select Filter ---"},
                        {:name => "from_email"   , :value => "From Email", :domtype => "autocompelete", :autocompelete_url => "allemailsurl", 
                                                   :operatortype => "email"},
                        {:name => "to_email"     , :value => "To Email"  , :domtype => "autocompelete", :autocompelete_url => "allemailsurl",
                                                   :operatortype => "email"},
                        {:name => 0              , :value => "--------------------------"},
                        {:name => "subject"      , :value => "Subject",       :domtype => "text",
                                                   :operatortype => "text"},
                        {:name => "description"  , :value => "Description...",   :domtype => "paragraph",
                                                   :operatortype => "text"},
                        {:name => "tag_names"    , :value => "Tag",           :domtype => "autocompelete", :autocompelete_url => "alltagsurl",
                                                   :operatortype => "text"},
                        {:name => "priority"     , :value => "Priority",      :domtype => "dropdown", :choices => Helpdesk::Ticket::PRIORITY_NAMES_BY_KEY.sort, 
                                                   :operatortype => "choicelist"},                        
                        {:name => "ticket_type"         , :value => "Type",          :domtype => "dropdown", :choices => Helpdesk::Ticket::TYPE_NAMES_BY_KEY.sort, 
                                                   :operatortype => "choicelist"},
                        {:name => "status"       , :value => "Status",        :domtype => "dropdown", :choices => Helpdesk::Ticket::STATUS_NAMES_BY_KEY.sort, 
                                                   :operatortype => "choicelist"},
                        {:name => "source"       , :value => "Source",        :domtype => "dropdown", :choices => Helpdesk::Ticket::SOURCE_NAMES_BY_KEY.sort, 
                                                   :operatortype => "choicelist"},
                        {:name => 0              , :value => "------------------------------"},
                        {:name => "contact"      , :value => "Contact Name",  :domtype => "autocompelete", :autocompelete_url => "contactnameurl",
                                                   :operatortype => "text"},
                        {:name => "company"      , :value => "Company Name",  :domtype => "autocompelete", :autocompelete_url => "companynameurl", 
                                                   :operatortype => "text"}]
      
      @filter_defs   = ActiveSupport::JSON.encode filter_hash
      
      operator_types  = {:email       => ["is", "is_not", "contains", "not_contain"],
                         :text        => ["is", "is_not", "contains", "not_contain", "starts_with", "ends_with"],
                         :choicelist  => ["is", "is_not"]}
      
      @op_types        = ActiveSupport::JSON.encode operator_types
      
      operator_list  =  {:is              =>  "Is",
                         :is_not          =>  "Is not",
                         :contains        =>  "Contains",
                         :not_contain     =>  "Does not contain",
                         :starts_with     =>  "Starts with",
                         :ends_with       =>  "Ends with",
                         :between         =>  "Between",
                         :between_range   =>  "Between Range"}; 
      
      @op_list        = ActiveSupport::JSON.encode operator_list
    end
  
end
