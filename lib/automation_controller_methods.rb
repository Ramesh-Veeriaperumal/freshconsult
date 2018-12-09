module AutomationControllerMethods

  include Integrations::IntegrationHelper
  include Spam::SpamAction
  SEPARATOR = "-----------------------"

  def index
    @va_rules = all_scoper
    respond_to do |format|
      format.html { @va_rules } #index.html.erb
      format.any(:json) { render request.format.to_sym => @va_rules.map {|rule| {:id => rule.id, :name => rule.name, :active => rule.active} }}
    end
  end

  def new
    @va_rule.match_type = :all
  end

  def create
    @va_rule.match_type ||= :all
    set_nested_fields_data @va_rule.action_data if @va_rule.action_data
    if @va_rule.save
      flash[:notice] = t(:'flash.general.create.success', :human_name => human_name)
      flash[:highlight] = dom_id(@va_rule)
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
    set_nested_fields_data @va_rule.action_data
    if @va_rule.update_attributes(params[:va_rule])
      flash[:notice] = t(:'flash.general.update.success', :human_name => human_name)
      flash[:highlight] = dom_id(@va_rule)
      redirect_back_or_default redirect_url
    else
      load_config
      edit_data
      render :action => 'edit'
    end
  end

  def clone_rule
    edit_data
    @va_rule.name = "%s #{@va_rule.name}" % t('dispatch.copy_of')
  end

  def ticket_type_values_with_none
    [['', t('none')]]+current_account.ticket_types_from_cache.collect { |c| [ c.value, c.value ] }
  end

  protected

  def reorder_scoper
    scoper
  end

  def reorder_redirect_url
    redirect_url
  end

  def load_object
    @va_rule = all_scoper.find(params[:id])
    @obj = @va_rule #Destroy of model-controller-methods needs @obj
  end

  def edit_data(obj = @va_rule)
    @action_input = ActiveSupport::JSON.encode obj.action_data
  end

  def set_nested_fields_data(data)
    data.each do |f|
      f['nested_rules'] = (ActiveSupport::JSON.decode f['nested_rules']).map{ |a| a.symbolize_keys! } if (f['nested_rules'])
    end
  end

  def get_event_performer
    [[-2, t('admin.observer_rules.event_performer')]]
  end

  def load_config
    @agents = [[0, t('admin.observer_rules.assigned_agent')]] + get_event_performer + none_option
    @agents.concat agents_list
    @watcher_agents = agents_list

    @groups = [[0, t('admin.observer_rules.assigned_group')]] + none_option
    @groups.concat groups_list_from_cache
    
    load_internal_group_agents if allow_shared_ownership_fields?

    @products = current_account.products.collect {|p| [p.id, p.name]}

    actions = get_actions
    add_shared_ownership_actions(actions) if allow_shared_ownership_fields?
    append_integration_actions actions
    actions = actions.select{ |action| action.fetch(:condition, true) }
    add_custom_actions actions
    @action_defs = ActiveSupport::JSON.encode actions
  end

  def automations_controller?
    controller_name == "scenario_automations"
  end

  def va_rules_controller?
    controller_name == "va_rules"
  end

  def supervisor_rules_controller?
    controller_name == "supervisor_rules"
  end

  def observer_rules_controller?
    controller_name == "observer_rules"
  end

  def multi_product_account?
    current_account.multi_product_enabled?
  end

  def survey_active_account?
    current_account.any_survey_feature_enabled_and_active?
  end

  def multi_timezone_account?
    current_account.multi_timezone_enabled?
  end

  def multi_language_account?
    current_account.features?(:multi_language)
  end

  def add_custom_actions action_hash
    special_case = none_option
    current_account.ticket_fields.non_encrypted_custom_fields.each do |field|
      action_hash.push({
                         :id => field.id,
                         :name => field.name,
                         :field_type => field.field_type,
                         :value => t('set_field_label_as', :custom_field_name => field.label),
                         :domtype => (field.field_type == "nested_field") ? "nested_field" : field.flexifield_def_entry.flexifield_coltype,
                         :choices => (field.field_type == "nested_field") ? (field.nested_choices_with_special_case special_case) : special_case+field.picklist_values.collect { |c| [c.value, c.value ] },
                         :action => "set_custom_field",
                         :handler => field.flexifield_def_entry.flexifield_coltype,
                         :nested_fields => nested_fields(field),
                         :unique_action => true
      })
    end
  end

  def add_shared_ownership_actions action_hash
    action_hash.push(
      { :name => "internal_group_id", :value => t('ticket.assign_to_internal_group'), :domtype => 'dropdown',
        :choices => @internal_groups, :unique_action => true  },
      { :name => "internal_agent_id", :value => t('ticket.assign_to_internal_agent'), :domtype => 'dropdown',
        :choices => @internal_agents, :unique_action => true  },
      { :name => -1, :value => SEPARATOR }
      )
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

  # For handling json escape inside hash data
  def escape_html_entities_in_json
    ActiveSupport::JSON::Encoding.escape_html_entities_in_json = true
  end

  def load_internal_group_agents
    internal_group_ids  = current_account.account_status_groups_from_cache.collect(&:group_id).uniq
    internal_agent_ids  = current_account.agent_groups.where(:group_id => internal_group_ids).pluck(:user_id).uniq
    @internal_groups    = none_option + groups_list_from_cache.select {|g| internal_group_ids.include?(g[0])}.compact
    @internal_agents    = get_event_performer + none_option + agents_list.select {|a| internal_agent_ids.include?(a[0])}.compact
    @internal_agents_condition = @internal_agents[1..-1]
  end

  def allow_shared_ownership_fields?
    current_account.shared_ownership_enabled? && !supervisor_rules_controller?
  end

  def groups_list_from_cache
    @groups_list ||= current_account.groups_from_cache.sort_by(&:name).collect { |g| [g.id, CGI.escapeHTML(g.name)]}
  end

  def agents_list
    @agents_list ||= current_account.users.technicians.collect { |au| [au.id, CGI.escapeHTML(au.name)] }
  end

  def none_option
    [['', t('none')]]
  end

  def validate_email_template
    action_data = (ActiveSupport::JSON.decode params[:action_data]) if params[:action_data].present?
    action_data.each do |action|
      validate_template_content(action['email_subject'], action['email_body'], 
        EmailNotificationConstants::EMAIL_TO_REQUESTOR) if action['name'] == 'send_email_to_requester'
    end
  end

  def get_actions
    # IMPORTANT - If an action requires a privilege to be executed, then add it
    # in ACTION_PRIVILEGE in Va::Action class

    set_actions = [
        { :name => -1, :value => t('click_to_select_action') },
        { :name => "priority", :value => t('set_priority_as'), :domtype => "dropdown",
          :choices => TicketConstants.priority_list.sort, :unique_action => true },
        { :name => "ticket_type", :value => t('set_type_as'), :domtype => "dropdown",
          :choices => current_account.ticket_type_values.collect { |c| [ c.value, c.value ] },
          :unique_action => true },
        { :name => "status", :value => t('set_status_as'), :domtype => "dropdown",
          :choices => Helpdesk::TicketStatus.status_names(current_account),
          :unique_action => true }
    ]

    add_actions = [
        { :name => -1, :value => SEPARATOR },
        { :name => "add_comment", :value => t('add_note'), :domtype => 'comment',
          :condition => automations_controller? },
        { :name => "add_tag", :value => t('add_tags'), :domtype => "autocomplete_tags", 
            :data_url => tags_search_autocomplete_index_path, :unique_action => true },
        { :name => "add_a_cc", :value => t('add_a_cc'), :domtype => 'single_email',
          :condition => va_rules_controller? },
        { :name => "add_watcher", :value => t('dispatch.add_watcher'), :domtype => 'multiple_select',
          :choices => @watcher_agents, :unique_action => true, :condition => current_account.add_watcher_enabled? },
        { :name => "trigger_webhook", :value => t('trigger_webhook'), :domtype => 'webhook',
          :unique_action => true,
          :condition => (va_rules_controller? || observer_rules_controller?) }
    ]

    assign_actions = [
        { :name => -1, :value => SEPARATOR },
        { :name => "responder_id", :value => t('ticket.assign_to_agent'),
          :domtype => 'dropdown', :choices => @agents[1..-1], :unique_action => true  },
        { :name => "group_id", :value => t('email_configs.info9'), :domtype => 'dropdown',
          :choices => @groups[1..-1], :unique_action => true  },
        { :name => "product_id", :value => t('admin.products.assign_product'),
          :domtype => 'dropdown', :choices => none_option+@products,
          :condition => multi_product_account? }
    ]

    email_actions = [
        { :name => -1, :value => SEPARATOR },
        { :name => "send_email_to_group", :value => t('send_email_to_group'),
          :domtype => 'email_select', :choices => @groups-[@groups[1]] },
        { :name => "send_email_to_agent", :value => t('send_email_to_agent'),
          :domtype => 'email_select',
          :choices => get_event_performer.empty? ? @agents-[@agents[1]] : @agents-[@agents[2]] },
        { :name => "send_email_to_requester", :value => t('send_email_to_requester'),
          :domtype => 'email' }
    ]

    other_actions = [
        { :name => -1, :value => SEPARATOR},
        { :name => "delete_ticket", :value => t('delete_the_ticket'), :unique_action => true },
        { :name => "mark_as_spam", :value => t('mark_as_spam'), :unique_action => true },
        { :name => "skip_notification", :value => t('dispatch.skip_notifications'),
          :condition => va_rules_controller? },
        { :name => -1, :value => SEPARATOR }
    ]
    actions =  set_actions + add_actions + assign_actions
    actions += email_actions if current_account.verified?
    actions += other_actions
  end
end
