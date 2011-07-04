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
      agents = current_account.users.technicians.collect { |au| [au.id, au.name] }
      agents << ([0, '{{ticket.agent}}'])

      groups  = current_account.groups.find(:all, :order=>'name' ).collect { |g| [g.id, g.name]}
      groups << ([0, '{{ticket.group}}'])
      
      action_hash     = [
        { :name => 0, :value => "--- #{t('click_select_action')} ---" },
        { :name => "priority", :value => t('set_priority_as'), :domtype => "dropdown", 
          :choices => Helpdesk::Ticket::PRIORITY_NAMES_BY_KEY.sort },
        { :name => "ticket_type", :value => t('set_type_as'), :domtype => "dropdown", 
          :choices => Helpdesk::Ticket::TYPE_NAMES_BY_KEY.sort },
        { :name => "status", :value => t('set_status_as'), :domtype => "dropdown", 
          :choices => Helpdesk::Ticket::STATUS_NAMES_BY_KEY.sort },
        { :name => 0, :value => "------------------------------" },
        { :name => "add_tag", :value => t('add_tags'), :domtype => 'text' },
        { :name => 0, :value => "------------------------------" },
        { :name => "responder_id", :value => t('ticket.assign_to_agent'), 
          :domtype => 'dropdown', :choices => agents },
        { :name => "group_id", :value => t('email_configs.info9'), :domtype => 'dropdown', 
          :choices => groups },
        { :name => 0, :value => "------------------------------" },
        { :name => "send_email_to_group", :value => t('send_email_to_group'), 
          :domtype => 'email_select', :choices => groups },
        { :name => "send_email_to_agent", :value => t('send_email_to_agent'), 
          :domtype => 'email_select', :choices => agents },
        { :name => "send_email_to_requester", :value => t('send_email_to_requester'), 
          :domtype => 'email' },
        { :name => 0, :value => "------------------------------" } ]
                        
      additional_actions.each { |index, value| action_hash.insert(index, value) }
      add_custom_actions action_hash
      @action_defs = ActiveSupport::JSON.encode action_hash
    end
    
    def additional_actions
      {5, {:name => "add_comment"  , :value => "Add Note"      , :domtype => 'comment'}}
    end
    
    def add_custom_actions action_hash
       current_account.ticket_fields.custom_fields.each do |field|
         action_hash.push({ 
           :name => field.name, 
           :value => "Set #{field.label} as", 
           :domtype => field.flexifield_def_entry.flexifield_coltype, 
           :choices => field.picklist_values.collect { |c| [ c.value, c.value ] }, 
           :action => "set_custom_field", 
           :handler => field.flexifield_def_entry.flexifield_coltype
           })
       end
    end
    
    def check_automation_feature
      requires_feature :scenario_automations 
    end
end
