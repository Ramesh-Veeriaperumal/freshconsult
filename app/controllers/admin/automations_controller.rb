class Admin::AutomationsController < Admin::AdminController
  include ModelControllerMethods
  include Helpdesk::ReorderUtility
   
  before_filter :load_config, :only => [:new, :edit]
  before_filter :check_automation_feature
  
  def index
    @va_rules = all_scoper
  end
  
  def new
    @va_rule.match_type = :all
  end

  def create
    @va_rule.action_data = params[:action_data].blank? ? [] : (ActiveSupport::JSON.decode params[:action_data])
    @va_rule.match_type ||= :all
    set_nested_fields_data @va_rule.action_data if @va_rule.action_data
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
    @va_rule.action_data = params[:action_data].blank? ? [] : (ActiveSupport::JSON.decode params[:action_data])
    set_nested_fields_data @va_rule.action_data
    if @va_rule.update_attributes(params[:va_rule])
      flash[:notice] = t(:'flash.general.update.success', :human_name => human_name)
      redirect_back_or_default redirect_url
    else
      load_config
      edit_data
      render :action => 'edit'
    end
  end
  
  protected 
  
    def scoper
      current_account.scn_automations
    end

    def all_scoper
      current_account.all_scn_automations
    end
    
    def cname
      @cname ||= "va_rule"
    end

    def reorder_scoper
      scoper
    end

    def reorder_redirect_url
      redirect_url
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

    def set_nested_fields_data(data)
      data.each do |f|        
        f["nested_rules"] = (ActiveSupport::JSON.decode f["nested_rules"]).map{ |a| a.symbolize_keys! } if (f["nested_rules"])
      end
    end
    
    def load_config
      @agents = [[0, t('admin.observer_rules.assigned_agent')], [-2, t('admin.observer_rules.event_performer')]]
      @agents.concat current_account.users.technicians.collect { |au| [au.id, au.name] }

      @groups = [[0, t('admin.observer_rules.assigned_group')]]
      @groups.concat current_account.groups.find(:all, :order=>'name' ).collect { |g| [g.id, g.name]}

      @products = current_account.products.collect {|p| [p.id, p.name]}
      
      action_hash     = [
        { :name => -1, :value => t('click_to_select_action') },
        { :name => "priority", :value => t('set_priority_as'), :domtype => "dropdown", 
          :choices => TicketConstants.priority_list.sort },
        { :name => "ticket_type", :value => t('set_type_as'), :domtype => "dropdown", 
          :choices => current_account.ticket_type_values.collect { |c| [ c.value, c.value ] } },
        { :name => "status", :value => t('set_status_as'), :domtype => "dropdown", 
          :choices => Helpdesk::TicketStatus.status_names(current_account)},
        { :name => -1, :value => "-----------------------" },
        { :name => "add_tag", :value => t('add_tags'), :domtype => 'text' },
        { :name => -1, :value => "-----------------------" },
        { :name => "responder_id", :value => t('ticket.assign_to_agent'), 
          :domtype => 'dropdown', :choices => @agents[1..-1] },
        { :name => "group_id", :value => t('email_configs.info9'), :domtype => 'dropdown', 
          :choices => @groups },
        { :name => -1, :value => "-----------------------" },
        { :name => "send_email_to_group", :value => t('send_email_to_group'), 
          :domtype => 'email_select', :choices => @groups },
        { :name => "send_email_to_agent", :value => t('send_email_to_agent'), 
          :domtype => 'email_select', :choices => @agents },
        { :name => "send_email_to_requester", :value => t('send_email_to_requester'), 
          :domtype => 'email' },
        { :name => -1, :value => "-----------------------" },
        { :name => "delete_ticket", :value => t('delete_the_ticket')},
        { :name => "mark_as_spam", :value => t('mark_as_spam')},
        { :name => -1, :value => "-----------------------" } ]
                        
      additional_actions.each { |index, value| action_hash.insert(index, value) }
      add_custom_actions action_hash
      @action_defs = ActiveSupport::JSON.encode action_hash
    end
    
    def additional_actions
      actions = {5 => {:name => "add_comment"  , :value => t('add_note')      , :domtype => 'comment'}}
      actions[10] = { :name => "product_id", :value => t('admin.products.assign_product'),
          :domtype => 'dropdown', :choices => @products } if current_account.features?(:multi_product)
      actions
    end
    
    def add_custom_actions action_hash
      no_value = [['', t('any_val.none')]]
       current_account.ticket_fields.custom_fields.each do |field|
         action_hash.push({ 
           :id => field.id,
           :name => field.name,
           :field_type => field.field_type,
           :value => t('set_field_label_as', :custom_field_name => field.label), 
           :domtype => (field.field_type == "nested_field") ? "nested_field" : field.flexifield_def_entry.flexifield_coltype,
           :choices => (field.field_type == "nested_field") ? (field.nested_choices no_value) : no_value+field.picklist_values.collect { |c| [c.value, c.value ] },
           :action => "set_custom_field", 
           :handler => field.flexifield_def_entry.flexifield_coltype,
           :nested_fields => nested_fields(field)
           })
       end
    end
    
    def check_automation_feature
      requires_feature :scenario_automations 
    end

    def nested_fields ticket_field
      nestedfields = { :subcategory => "", :items => "" }
      if ticket_field.field_type == "nested_field"
        ticket_field.nested_ticket_fields.each do |field|
          nestedfields[(field.level == 2) ? :subcategory : :items] = { :name => field.field_name, :label => field.label }      
        end
      end
      nestedfields
    end
end
