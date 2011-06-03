class Admin::AutomationsController < Admin::AdminController
  include ModelControllerMethods
   
  before_filter :load_config, :only => [:new, :edit]
  before_filter :check_automation_feature
  
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
      flash[:notice] = t(:'flash.general.create.success', :human_name => human_name)
      redirect_back_or_default redirect_url
    else
      load_config
      edit_data
      render :action => 'new'
    end
  end

  def edit
    edit_data
  end

  def update
    @va_rule.action_data = ActiveSupport::JSON.decode params[:action_data]
    
    if @va_rule.update_attributes(params[:va_rule])
      flash[:notice] = t(:'flash.general.update.success', :human_name => human_name)
      redirect_back_or_default redirect_url
    else
      load_config
      edit_data
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
      "scenario"
    end
    
    def edit_data
      @action_input = ActiveSupport::JSON.encode @va_rule.action_data
    end
    
    def load_config
      a_users = current_account.users.find(:all , :conditions =>{:user_role => [User::USER_ROLES_KEYS_BY_TOKEN[:poweruser],User::USER_ROLES_KEYS_BY_TOKEN[:admin]]}, :order => 'name')      
      agents = a_users.collect { |au| [au.id, au.name] }
      agents << ([0, '{{ticket.agent}}'])

      groups  = current_account.groups.find(:all).collect { |g| [g.id, g.name]}
      groups << ([0, '{{ticket.group}}'])
      
      action_hash     = [{:name => 0              , :value => "--- #{t('click_select_action')} ---"},
                         {:name => "priority"     , :value => t('set_priority_as')  , :domtype => "dropdown", :choices => Helpdesk::Ticket::PRIORITY_NAMES_BY_KEY.sort },
                         {:name => "ticket_type"  , :value => t('set_type_as')      , :domtype => "dropdown", :choices => Helpdesk::Ticket::TYPE_NAMES_BY_KEY.sort },
                         {:name => "status"       , :value => t('set_status_as')    , :domtype => "dropdown", :choices => Helpdesk::Ticket::STATUS_NAMES_BY_KEY.sort},
                         {:name => 0              , :value => "------------------------------"},
                         {:name => "add_tag"      , :value => t('add_tags')       , :domtype => 'text'},
                         {:name => 0              , :value => "------------------------------"},
                         {:name => "responder_id" , :value => t('ticket.assign_to_agent')  , :domtype => 'dropdown', :choices => agents },
                         {:name => "group_id"     , :value => t('email_configs.info9')  , :domtype => 'dropdown', :choices => groups },
                         {:name => 0              , :value => "------------------------------"},
                         {:name => "send_email_to_group" , :value => t('send_email_to_group')  , :domtype => 'email_select', :choices => groups},
                         {:name => "send_email_to_agent" , :value => t('send_email_to_agent')  , :domtype => 'email_select', :choices => agents},
                         {:name => "send_email_to_requester"  , :value => t('send_email_to_requester')   , :domtype => 'email'},
                        ]
                        
      additional_actions.each { |index, value| action_hash.insert(index, value) }
      
      action_hash = add_custom_actions action_hash
      
      @action_defs    = ActiveSupport::JSON.encode action_hash
    end
    
    def additional_actions
      {5, {:name => "add_comment"  , :value => "Add Note"      , :domtype => 'comment'}}
    end
    
    
    def add_custom_actions action_hash
       @ticket_field = Helpdesk::FormCustomizer.find(:first ,:conditions =>{:account_id => current_account.id})
       @json_data = ActiveSupport::JSON.decode(@ticket_field.json_data)
       
       @json_data.each do |field|
         if field["fieldType"].eql?("custom")
            Array values =[]
            if "dropdown".eql?(field["type"])
              field["choices"].each {|choice| values.push([choice["value"],choice["value"]])}
            end
           
            item = {:name =>  field["label"] , :value =>  "Set #{field["display_name"]} as" ,  :domtype => field["type"] , :choices => values , :action => "set_custom_field" ,:handler =>field["type"]}
            action_hash.push(item)
         end
       end
      return action_hash
    end
    
    def check_automation_feature
      requires_feature :scenario_automations 
    end

end
