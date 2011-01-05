class VaRulesController < ApplicationController
  include ModelControllerMethods
  
  before_filter :set_selected_tab
  
  def index
    @va_rules = scoper.all
  end

  def new
    @va_rule.match_type = :all
    load_filter_config
  end

  def create
    rule_hash = ActiveSupport::JSON.decode params[:save_json]
    puts " RULE_HASH for VA Save #{rule_hash.inspect}"
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
    load_filter_config
  end

  def update
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
                        {:name => "from_email_id", :value => "From Email Id", :domtype => "autocompelete", :autocompelete_url => "allemailsurl" },
                        {:name => "to_email_id"  , :value => "To Email Id"  , :domtype => "autocompelete", :autocompelete_url => "allemailsurl" },
                        {:name => 0              , :value => "------------------------------"},
                        {:name => "subject"      , :value => "Subject",       :domtype => "text" },
                        {:name => "description"  , :value => "Description...",   :domtype => "paragraph" },
                        {:name => "priority"     , :value => "Priority",      :domtype => "dropdown", :choices => [{:name => "1", :value => "Low"}, 
                                                                                                                   {:name => "2", :value => "Medium"}, 
                                                                                                                   {:name => "3", :value => "High"}, 
                                                                                                                   {:name => "4", :value => "Urgent"}] },
                        {:name => "tag"          , :value => "Tag",           :domtype => "autocompelete", :autocompelete_url => "alltagsurl" },
                        {:name => "type"         , :value => "Type",          :domtype => "dropdown", :choices => [{:name => "1", :value => "Incident"}, 
                                                                                                                   {:name => "2", :value => "Question"}, 
                                                                                                                   {:name => "3", :value => "Problem"}] },
                        {:name => "status"       , :value => "Status",        :domtype => "dropdown", :choices => [{:name => "open", :value => "Open"}, 
                                                                                                                   {:name => "closed", :value => "Closed"},
                                                                                                                   {:name => "resolved", :value => "Resolved"},
                                                                                                                   {:name => "onhold", :value => "On Hold"}] },
                        {:name => "source"       , :value => "Source",        :domtype => "dropdown", :choices => [{:name => "1", :value => "Email"}, 
                                                                                                                   {:name => "2", :value => "Phone"},
                                                                                                                   {:name => "3", :value => "Self Service"},
                                                                                                                   {:name => "4", :value => "Via Agent"}] },
                        {:name => 0              , :value => "------------------------------"},
                        {:name => "contact_name" , :value => "Contact Name",  :domtype => "autocompelete", :autocompelete_url => "contactnameurl" },
                        {:name => "company_name" , :value => "Company Name",  :domtype => "autocompelete", :autocompelete_url => "companynameurl" },
                        {:name => "support_plan" , :value => "Support Plan",  :domtype => "dropdown", :choices => [{:name => "1", :value => "Platinum"}, 
                                                                                                                   {:name => "2", :value => "Gold"}, 
                                                                                                                   {:name => "3", :value => "Silver"}] }]
      
      @filter_defs   = ActiveSupport::JSON.encode filter_hash
      
      condition_hash  = [{:name => "is"          , :value => "is"         }, {:name => "is_not"          , :value => "is not"}, 
                         {:name => "contains"    , :value => "Contains"   }, {:name => "does_not_contain", :value => "Does not contain"}, 
                         {:name => "starts_with" , :value => "Starts with"}, {:name => "ends_with"       , :value => "Ends with"}]
                         
      @condition_defs = ActiveSupport::JSON.encode condition_hash
      
      action_hash     = [{:name => 0              , :value => "--- Click to Select Action ---"},
                         {:name => "s_priority"  , :value => "Set Priority as", :domtype => "dropdown" , :choices => [{:name => "1", :value => "Low"}, 
                                                                                                                    {:name => "2", :value => "Medium"}, 
                                                                                                                    {:name => "3", :value => "High"},
                                                                                                                    {:name => "4", :value => "Urgent"}] },
                         {:name => "s_type"       , :value => "Set Type as"    , :domtype => "dropdown" , :choices => [{:name => "1", :value => "Incident"}, 
                                                                                                                    {:name => "2", :value => "Question"}, 
                                                                                                                    {:name => "3", :value => "Problem"}] },
                         {:name => "s_status"     , :value => "Set Status as"  , :domtype => "dropdown" , :choices => [{:name => "open", :value => "Open"}, 
                                                                                                                    {:name => "closed", :value => "Closed"},
                                                                                                                    {:name => "resolved", :value => "Resolved"},
                                                                                                                    {:name => "onhold", :value => "On Hold"}]},
                         {:name => 0              , :value => "------------------------------"},                                                                                           
                         {:name => "add_comment"  , :value => "Add Comment as" , :domtype => 'comment'},
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
