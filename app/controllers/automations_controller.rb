class AutomationsController < ApplicationController
  include ModelControllerMethods
  
  before_filter :set_selected_tab
  before_filter :load_config, :only => [:new, :edit]
  
  def index
    @va_rules = scoper.find(:all)
  end
  
  def new
    @va_rule.match_type = :all
  end

  def create
    @va_rule.action_data = ActiveSupport::JSON.decode params[:action_data]
    @va_rule.match_type ||= :all
    
    if @va_rule.save
      flash[:notice] = "The #{human_name} has been created."
      redirect_back_or_default redirect_url
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
      redirect_back_or_default redirect_url
    else
      render :action => 'edit'
    end
  end
   
  def reorder
    new_pos = ActiveSupport::JSON.decode params[:reorderlist]
    
    va_rules = scoper.find(:all)
    va_rules.each do |va_rule|
      new_p = new_pos[va_rule.id.to_s]
      if va_rule.position != new_p
        va_rule.position = new_p
        va_rule.save
      end
    end
    redirect_back_or_default redirect_url
  end
  
  protected
    def set_selected_tab
      @selected_tab = "Admin"
    end
  
    def scoper
      current_account.scn_automations
    end
    
    def cname
      @cname ||= "va_rule"
    end
    
    def build_object #Some bug with build during new, so moved here from ModelControllerMethods
      @va_rule = params[:va_rule].nil? ? VARule.new : scoper.build(params[:va_rule])
    end
    
    def human_name
      "automation"
    end
    
    def load_config
      a_users = User.find(:all , :conditions =>{:role_token => ['poweruser','admin']}, :order => 'name')      
        agents = a_users.collect { |au| [au.id, au.name] }
        
      groups  = Group.find(:all).collect { |g| [g.id, g.name]}     
      
      action_hash     = [{:name => 0              , :value => "--- Click to Select Action ---"},
                         {:name => "priority"     , :value => "Set Priority as"  , :domtype => "dropdown", :choices => Helpdesk::Ticket::PRIORITY_NAMES_BY_KEY.sort },
                         {:name => "ticket_type"  , :value => "Set Type as"      , :domtype => "dropdown", :choices => Helpdesk::Ticket::TYPE_NAMES_BY_KEY.sort },
                         {:name => "status"       , :value => "Set Status as"    , :domtype => "dropdown", :choices => Helpdesk::Ticket::STATUS_NAMES_BY_KEY.sort},
                         {:name => 0              , :value => "------------------------------"},
                         {:name => "add_comment"  , :value => "Add Comment"      , :domtype => 'comment'},
                         {:name => "add_tag"      , :value => "Add Tag(s)"       , :domtype => 'autocompelete', :autocompelete_url => "allemailsurl"},
                         {:name => 0              , :value => "------------------------------"},
                         {:name => "responder_id" , :value => "Assign to Agent"  , :domtype => 'dropdown', :choices => agents },
                         {:name => "group_id"     , :value => "Assign to Group"  , :domtype => 'dropdown', :choices => groups },
                         {:name => 0              , :value => "------------------------------"},
                         {:name => "send_email_to_group" , :value => "Send Email to Group"  , :domtype => 'autocompelete', :autocompelete_url => "groupemailsurl"},
                         {:name => "send_email_to_agent" , :value => "Send Email to Agent"  , :domtype => 'autocompelete', :autocompelete_url => "agentemailsurl"},
                         {:name => "send_email_to_requester"  , :value => "Send Email to Requester"   , :domtype => 'autocompelete', :autocompelete_url => "useremailsurl"},
                        ]
      
      @action_defs    = ActiveSupport::JSON.encode action_hash
    end
end
