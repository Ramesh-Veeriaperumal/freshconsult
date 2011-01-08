class VaRulesController < ApplicationController
  include ModelControllerMethods
  
  before_filter :set_selected_tab
  before_filter :load_filter_config, :only => [:new, :edit]
  
  def index
    @va_rules = scoper.all
    
    t = Helpdesk::Ticket.new
    t.subject = "Number"
    t.status = "open"
    t.description = "go"
    #t.ticket_type = 2
    t.tags = [Helpdesk::Tag.new(:name => "hardware"), Helpdesk::Tag.new(:name => "software")]
    
    @va_rules.each do |vr|
      puts "###############"
      puts vr.inspect
      puts vr.conditions.inspect
      puts "DOES IT MATCH #{vr.pass_through t}"
      puts "@@@@@@@@@@@@@@@"
    end
  end

  def new
    @va_rule.match_type = :all
  end

  def create
    rule_hash = ActiveSupport::JSON.decode params[:save_json]
    #puts " RULE_HASH for VA Save #{rule_hash.inspect}"
    #puts "And Rule's name is #{@va_rule.name}"
    
    @va_rule.filter_data = rule_hash["conditions"]
    @va_rule.action_data = rule_hash["actions"]
    
    if @va_rule.save
      flash[:notice] = "The virtual agent rule has been created."
      redirect_to va_rules_path
    else
      render :action => 'new'
    end
  end

  def edit
  end

  def update
    redirect_to va_rules_path
  end

  def destroy
  end

  protected
    def set_selected_tab
      @selected_tab = "Admin"
    end
  
    def scoper
      current_account.va_rules
    end

    def load_filter_config
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
                        {:name => "type"         , :value => "Type",          :domtype => "dropdown", :choices => Helpdesk::Ticket::TYPE_NAMES_BY_KEY.sort, 
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
      
      condition_hash  = [{:name => "is"          , :value => "is"         }, {:name => "is_not"          , :value => "is not"}, 
                         {:name => "contains"    , :value => "Contains"   }, {:name => "does_not_contain", :value => "Does not contain"}, 
                         {:name => "starts_with" , :value => "Starts with"}, {:name => "ends_with"       , :value => "Ends with"}]
                         
      @condition_defs = ActiveSupport::JSON.encode condition_hash
      
      action_hash     = [{:name => 0              , :value => "--- Click to Select Action ---"},
                         {:name => "priority"     , :value => "Set Priority as", :domtype => "dropdown" , :choices => Helpdesk::Ticket::PRIORITY_NAMES_BY_KEY.sort },
                         {:name => "ticket_type"  , :value => "Set Type as"    , :domtype => "dropdown" , :choices => Helpdesk::Ticket::TYPE_NAMES_BY_KEY.sort },
                         {:name => "status"       , :value => "Set Status as"  , :domtype => "dropdown" , :choices => Helpdesk::Ticket::STATUS_NAMES_BY_KEY.sort},
                         {:name => 0              , :value => "------------------------------"},                                                                                           
                         {:name => "add_tag"      , :value => "Add Tag(s)"  , :domtype => 'autocompelete', :autocompelete_url => "allemailsurl"},
                         {:name => 0              , :value => "------------------------------"},
                         {:name => "assign_to_agent" , :value => "Assign to Agent"  , :domtype => 'dropdown', :choices => [{:name => "1", :value => "Edward"}, 
                                                                                                                           {:name => "2", :value => "John Patrick"},
                                                                                                                           {:name => "3", :value => "Susan Renolds"},
                                                                                                                           {:name => "4", :value => "Gary Matheew"}]},
                         {:name => "assign_to_group" , :value => "Assign to Group"  , :domtype => 'dropdown', :choices => [{:name => "1", :value => "Hardware"}, 
                                                                                                                           {:name => "2", :value => "Software"},
                                                                                                                           {:name => "3", :value => "Tech support"},
                                                                                                                           {:name => "4", :value => "Product Group"}]},
                         {:name => 0              , :value => "------------------------------"},
                         {:name => "send_email_group" , :value => "Send Email to Group"  , :domtype => 'autocompelete', :autocompelete_url => "groupemailsurl"},
                         {:name => "send_email_agent" , :value => "Send Email to Agent"  , :domtype => 'autocompelete', :autocompelete_url => "agentemailsurl"},
                         {:name => "send_email_user"  , :value => "Send Email to User"   , :domtype => 'autocompelete', :autocompelete_url => "useremailsurl"},
                        ]
      
      @action_defs    = ActiveSupport::JSON.encode action_hash
    end

end
