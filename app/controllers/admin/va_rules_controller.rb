class Admin::VaRulesController < Admin::AutomationsController
  include Va::Constants
  
  skip_before_filter :check_automation_feature
  before_filter :set_filter_data, :only => [ :create, :update ]
  before_filter :hide_password_in_webhook, :only => [:edit]
  # TODO-RAILS3 password moved to application.rb but need to check action_data
  # filter_parameter_logging :action_data, :password
  
  def activate_deactivate
    @va_rule = all_scoper.find(params[:id])
    @va_rule.update_attributes({:active => params[:va_rule][:active]})  
    type = params[:va_rule][:active] == "true" ? 'activation' : 'deactivation'
      
    flash[:highlight] = dom_id(@va_rule)
    flash[:notice] = t("flash.general.#{type}.success", :human_name => human_name)
    redirect_to :action => 'index'
  end

  def toggle_cascade
    if feature?(:cascade_dispatchr)
      current_account.features.cascade_dispatchr.destroy
    else
      current_account.features.cascade_dispatchr.create
    end
    current_account.reload
    render :nothing => true
  end
 
  protected
    def scoper
      current_account.va_rules
    end
    
    def all_scoper
      current_account.all_va_rules
    end
    
    def human_name
      "Dispatch'r rule"
    end
    
    def set_filter_data
      @va_rule.filter_data = params[:filter_data].blank? ? [] : ActiveSupport::JSON.decode(params[:filter_data])
      set_nested_fields_data @va_rule.filter_data
    end

    def edit_data
      @filter_input = ActiveSupport::JSON.encode @va_rule.filter_data
      super
    end
    
    def load_object
      @va_rule = all_scoper.find(params[:id])
      @obj = @va_rule #Destroy of model-controller-methods needs @obj
    end
    
    def get_event_performer
      [[-2, I18n.t('ticket_creating_agent')]]
    end

    def load_config
      super
      
      @agents = current_account.users.technicians.inject([["", I18n.t('ticket.none')]]) do |agents, au|
                agents << [au.id, au.name]
                agents
              end
      @groups  = current_account.groups.find(:all, :order=>'name').inject([["", I18n.t('ticket.none')]]) do |groups, ag|
                groups << [ag.id, CGI.escapeHTML(ag.name)]
                groups
              end

      filter_hash   = [
        { :name => -1, :value => t('click_to_select_filter') },
        { :name => "from_email", :value => t('from_email'), :domtype => "autocompelete", 
          :data_url => requesters_search_autocomplete_index_path, :operatortype => "email" },
        { :name => "to_email", :value => t('to_email'), :domtype => "text",
          :operatortype => "email" },
        { :name => "ticlet_cc", :value => t('ticket_cc'), :domtype => "text",
          :operatortype => "email", :condition => va_rules_controller? },
        { :name => -1, :value => "-----------------------" },
        { :name => "subject", :value => t('ticket.subject'), :domtype => "text",
          :operatortype => "text" },
        { :name => "description", :value => t('description'), :domtype => "text",
          :operatortype => "text", :condition => !supervisor_rules_controller? },
        { :name => "subject_or_description", :value =>  t('subject_or_description'), 
          :domtype => "text", :operatortype => "text" },
        { :name => "last_interaction", :value => I18n.t('last_interaction'), :domtype => "text",
          :operatortype => "text", :condition => observer_rules_controller? },
        { :name => "priority", :value => t('ticket.priority'), :domtype => "dropdown", 
          :choices => TicketConstants.priority_list.sort, :operatortype => "choicelist" },
        { :name => "ticket_type", :value => t('ticket.type'), :domtype => "dropdown", 
          :choices => current_account.ticket_type_values.collect { |c| [ c.value, c.value ] }, 
          :operatortype => "choicelist" },
        { :name => "status", :value => t('ticket.status'), :domtype => "dropdown", 
          :choices => Helpdesk::TicketStatus.status_names(current_account), :operatortype => "choicelist"},
        { :name => "source", :value => t('ticket.source'), :domtype => "dropdown", 
          :choices => TicketConstants.source_list.sort, :operatortype => "choicelist" },
        { :name => "product_id", :value => t('admin.products.product_label_msg'), :domtype => 'dropdown', 
          :choices => [['', t('none')]]+@products, :operatortype => "choicelist",
          :condition => multi_product_account? },
        { :name=> "created_at", :value => t('ticket.created_during.title'), :domtype => "dropdown",
          :operatortype => "date_time", :choices => VAConfig::CREATED_DURING_NAMES_BY_KEY.sort,
          :condition => va_rules_controller? },
        { :name => "responder_id", :value => I18n.t('ticket.agent'), :domtype => "dropdown",
          :operatortype => "object_id", :choices => @agents },
        { :name => "group_id", :value => I18n.t('ticket.group'), :domtype => "dropdown",
          :operatortype => "object_id", :choices => @groups },
        { :name => -1, :value => "-----------------------" },
        { :name => "contact_name", :value => t('contact_name'), :domtype => "text", 
          :operatortype => "text" },
        { :name => "company_name", :value => t('company_name'), :domtype => "text", 
          :operatortype => "text"}
      ]

      filter_hash = filter_hash.select{ |filter| filter.fetch(:condition, true) }
      add_time_based_filters filter_hash
      add_ticket_state_filters filter_hash
      add_custom_filters filter_hash

      @filter_defs  = ActiveSupport::JSON.encode filter_hash
      @op_types     = ActiveSupport::JSON.encode OPERATOR_TYPES
      @op_list      = ActiveSupport::JSON.encode OPERATOR_LIST
    end

    def add_time_based_filters filter_hash
      if supervisor_rules_controller?
        filter_hash.push *time_based_filters
      end
    end

    def time_based_filters
      [ 
        { :name => -1, :value => "-----------------------"  },
        { :name => "created_at", :value => I18n.t('ticket.created_at'), :domtype => "number",
          :operatortype => "hours" },
        { :name => "pending_since", :value => I18n.t('ticket.pending_since'), :domtype => "number",
          :operatortype => "hours" },
        { :name => "resolved_at", :value => I18n.t('ticket.resolved_at'), :domtype => "number",
          :operatortype => "hours" },
        { :name => "closed_at", :value => I18n.t('ticket.closed_at'), :domtype => "number",
          :operatortype => "hours" },
        { :name => "opened_at", :value => I18n.t('ticket.opened_at'), :domtype => "number",
          :operatortype => "hours" },
        { :name => "first_assigned_at", :value => I18n.t('ticket.first_assigned_at'), 
          :domtype => "number", :operatortype => "hours" },
        { :name => "assigned_at", :value => I18n.t('ticket.assigned_at'), :domtype => "number",
          :operatortype => "hours" },
        { :name => "requester_responded_at", :value => I18n.t('ticket.requester_responded_at'), 
          :domtype => "number", :operatortype => "hours" },
        { :name => "agent_responded_at", :value => I18n.t('ticket.agent_responded_at'), 
          :domtype => "number", :operatortype => "hours" },
        { :name => "frDueBy", :value => I18n.t('ticket.first_response_due'), 
          :domtype => "number", :operatortype => "hours" },
        { :name => "due_by", :value => I18n.t('ticket.due_by'), :domtype => "number",
          :operatortype => "hours" }
      ]
    end

    def add_ticket_state_filters filter_hash
      if supervisor_rules_controller? || observer_rules_controller?
        filter_hash.push *ticket_state_filters
      end
    end

    def ticket_state_filters
      # operatortype should not be named hours for a count type.. need to change
      [
        { :name => -1, :value => "-----------------------"  },
        { :name => "inbound_count", :value => I18n.t('ticket.inbound_count'), :domtype => "number",
          :operatortype => "hours" },
        { :name => "outbound_count", :value => I18n.t('ticket.outbound_count'), :domtype => "number",
          :operatortype => "hours" }
      ]
    end

    def add_custom_filters filter_hash
      special_case = [['', t('none')]]
      nested_special_case = [['--', t('any_val.any_value')], ['', t('none')]]
      cf = current_account.ticket_fields.custom_fields
      unless cf.blank? 
        filter_hash.push({ :name => -1,
                          :value => "---------------------" 
                          })
        cf.each do |field|
          next if field.field_type == 'custom_decimal' # To be removed once decimal fields UI is enabled
          filter_hash.push({
            :id => field.id,
            :name => field.name,
            :value => field.label,
            :field_type => field.field_type,
            :domtype => (field.field_type == "nested_field") ? "nested_field" : field.flexifield_def_entry.flexifield_coltype,
            :choices =>  (field.field_type == "nested_field") ? (field.nested_choices_with_special_case nested_special_case) : special_case+field.picklist_values.collect { |c| [c.value, c.value ] },
            :action => "set_custom_field",
            :operatortype => CF_OPERATOR_TYPES.fetch(field.field_type, "text"),
            :nested_fields => nested_fields(field)
          })
        end
      end
    end

    def hide_password_in_webhook
      @va_rule.hide_password!
    end
  
end
