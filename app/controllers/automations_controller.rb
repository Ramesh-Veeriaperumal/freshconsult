class AutomationsController < ApplicationController
  include ModelControllerMethods
  
  before_filter :set_selected_tab
  before_filter :load_config, :only => [:new, :edit]
  
  def new
    @va_rule.match_type = :all
  end

  def create    
    @va_rule.action_data = ActiveSupport::JSON.decode params[:action_data]
    
    if @va_rule.save
      flash[:notice] = "The #{human_name} has been created."
      redirect_to va_rules_path
    else
      render :action => 'new'
    end
  end

  def edit
    @action_input = ActiveSupport::JSON.encode @va_rule.action_data
  end

  def update
    @va_rule.action_data = ActiveSupport::JSON.decode params[:action_data]
    
    if @va_rule.update_attributes(params[:va_rule])
      flash[:notice] = "The #{human_name} has been updated."
      redirect_to va_rules_path
    else
      render :action => 'edit'
    end
  end

  protected
    def set_selected_tab
      @selected_tab = "Admin"
    end
  
    def scoper
      current_account.scn_automations
    end
    
    def build_object #Some bug with build during new, so moved here from ModelControllerMethods
      @va_rule = params[:va_rule].nil? ? VARule.new : scoper.build(params[:va_rule])
    end
    
    def human_name
      "automation"
    end
    
    def load_config
      action_hash     = [{:name => 0              , :value => "--- Click to Select Action ---"},
                         {:name => "priority"     , :value => "Set Priority as"  , :domtype => "dropdown", :choices => Helpdesk::Ticket::PRIORITY_NAMES_BY_KEY.sort },
                         {:name => "ticket_type"  , :value => "Set Type as"      , :domtype => "dropdown", :choices => Helpdesk::Ticket::TYPE_NAMES_BY_KEY.sort },
                         {:name => "status"       , :value => "Set Status as"    , :domtype => "dropdown", :choices => Helpdesk::Ticket::STATUS_NAMES_BY_KEY.sort},
                         {:name => 0              , :value => "------------------------------"},                                                                                           
                         {:name => "add_tag"      , :value => "Add Tag(s)"       , :domtype => 'autocompelete', :autocompelete_url => "allemailsurl"},
                         {:name => 0              , :value => "------------------------------"},
                         {:name => "responder_id" , :value => "Assign to Agent"  , :domtype => 'dropdown', :choices => [["1", "Edward"], 
                                                                                                                        ["2", "John Patrick"],
                                                                                                                        ["3", "Susan Renolds"],
                                                                                                                        ["4", "Gary Matheew"]]},
                         {:name => "group_id"     , :value => "Assign to Group"  , :domtype => 'dropdown', :choices => [["1", "Hardware"], 
                                                                                                                        ["2", "Software"],
                                                                                                                        ["3", "Tech support"],
                                                                                                                        ["4", "Product Group"]]},
                         {:name => 0              , :value => "------------------------------"},
                         {:name => "send_email_to_group" , :value => "Send Email to Group"  , :domtype => 'autocompelete', :autocompelete_url => "groupemailsurl"},
                         {:name => "send_email_to_agent" , :value => "Send Email to Agent"  , :domtype => 'autocompelete', :autocompelete_url => "agentemailsurl"},
                         {:name => "send_email_to_requester"  , :value => "Send Email to Requester"   , :domtype => 'autocompelete', :autocompelete_url => "useremailsurl"},
                        ]
      
      @action_defs    = ActiveSupport::JSON.encode action_hash
    end
end
