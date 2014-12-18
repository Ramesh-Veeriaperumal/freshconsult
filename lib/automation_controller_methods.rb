module AutomationControllerMethods

  def index
    @va_rules = all_scoper
    @va_rules
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
    @va_rule.action_data = params[:action_data].blank? ? [] : (ActiveSupport::JSON.decode params[:action_data])
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

  def edit_data
    @action_input = ActiveSupport::JSON.encode @va_rule.action_data
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
    @agents = [[0, t('admin.observer_rules.assigned_agent')]]
    @agents.concat get_event_performer
    @agents.concat [['', t('none')]]+current_account.users.technicians.collect { |au| [au.id, au.name] }
    watcher_agents = current_account.users.technicians.collect { |au| [au.id, au.name] }

    @groups = [[0, t('admin.observer_rules.assigned_group')], ['', t('none')]]
    @groups.concat current_account.groups.find(:all, :order=>'name' ).collect { |g| [g.id, g.name]}

    @products = current_account.products.collect {|p| [p.id, p.name]}

    # IMPORTANT - If an action requires a privilege to be executed, then add it
    # in ACTION_PRIVILEGE in Va::Action class
    action_hash = [
      { :name => -1, :value => t('click_to_select_action') },
      { :name => "priority", :value => t('set_priority_as'), :domtype => "dropdown",
        :choices => TicketConstants.priority_list.sort, :unique_action => true },
      { :name => "ticket_type", :value => t('set_type_as'), :domtype => "dropdown",
        :choices => current_account.ticket_type_values.collect { |c| [ c.value, c.value ] },
        :unique_action => true },
      { :name => "status", :value => t('set_status_as'), :domtype => "dropdown",
        :choices => Helpdesk::TicketStatus.status_names(current_account),
        :unique_action => true },
      { :name => -1, :value => "-----------------------" },
      { :name => "add_comment", :value => t('add_note'), :domtype => 'comment',
        :condition => automations_controller? },
      { :name => "add_tag", :value => t('add_tags'), :domtype => 'text' },
      { :name => "add_a_cc", :value => t('add_a_cc'), :domtype => 'single_email',
        :condition => va_rules_controller? },
      { :name => "add_watcher", :value => t('dispatch.add_watcher'), :domtype => 'multiple_select',
        :choices => watcher_agents, :unique_action => true },
      { :name => "trigger_webhook", :value => t('trigger_webhook'), :domtype => 'webhook',
        :unique_action => true,
        :condition => (va_rules_controller? || observer_rules_controller?) },
      { :name => -1, :value => "-----------------------" },
      { :name => "responder_id", :value => t('ticket.assign_to_agent'),
        :domtype => 'dropdown', :choices => @agents[1..-1], :unique_action => true  },
      { :name => "group_id", :value => t('email_configs.info9'), :domtype => 'dropdown',
        :choices => @groups[1..-1], :unique_action => true  },
      { :name => "product_id", :value => t('admin.products.assign_product'),
        :domtype => 'dropdown', :choices => [['', t('none')]]+@products,
        :condition => multi_product_account? },
      { :name => -1, :value => "-----------------------" },
      { :name => "send_email_to_group", :value => t('send_email_to_group'),
        :domtype => 'email_select', :choices => @groups-[@groups[1]] },
      { :name => "send_email_to_agent", :value => t('send_email_to_agent'),
        :domtype => 'email_select',
        :choices => get_event_performer.empty? ? @agents-[@agents[1]] : @agents-[@agents[2]] },
      { :name => "send_email_to_requester", :value => t('send_email_to_requester'),
        :domtype => 'email' },
      { :name => -1, :value => "-----------------------" },
      { :name => "delete_ticket", :value => t('delete_the_ticket'), :unique_action => true },
      { :name => "mark_as_spam", :value => t('mark_as_spam'), :unique_action => true },
      { :name => "skip_notification", :value => t('dispatch.skip_notifications'),
        :condition => va_rules_controller? },
      { :name => -1, :value => "-----------------------" }
    ]

    action_hash = action_hash.select{ |action| action.fetch(:condition, true) }
    add_custom_actions action_hash
    @action_defs = ActiveSupport::JSON.encode action_hash
  end

  def automations_controller?
    controller_name == "automations"
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
    current_account.features?(:multi_product)
  end

  def survey_featured_account?
    current_account.features?(:surveys, :survey_links)
  end

  def add_custom_actions action_hash
    special_case = [['', t('none')]]
    current_account.ticket_fields.custom_fields.each do |field|
      next if field.field_type == 'custom_decimal' # To be removed once decimal fields UI is enabled
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
end
