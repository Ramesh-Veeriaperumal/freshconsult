module AutomationRulesTestHelper
  FIELD_OPERATOR_MAPPING = {
    email:           { fields:    ['from_email', 'to_email', 'ticlet_cc'],
                       performer: 1,
                       event:     "update",
                       operators: ['is', 'is_not', 'contains', 'does_not_contain'],
                       actions:   ['priority', 'ticket_type', 'status', 'responder_id', 'product_id', 'group_id']},
    text:            { fields:    ['subject', 'description', 'subject_or_description'],
                       performer: 2,
                       event:     "agent",
                       operators: ['is', 'is_not', 'contains', 'does_not_contain',
                                   'starts_with', 'ends_with'],
                       actions:   ['add_tag']},
    choicelist:      { fields:    ['priority', 'ticket_type', 'status', 'source', 'product_id'],
                       performer: 3,
                       event:     "value",
                       operators: ['in', 'not_in'],
                       actions:   ['add_a_cc']},
    date_time:       { fields:    ['created_during'],
                       performer: 1,
                       event:     "change",
                       operators: ['during'],
                       actions:   ['add_watcher']},
    object_id:       { fields:    ['responder_id', 'group_id', 'internal_agent_id', 'internal_group_id'],
                       performer: 2,
                       event:     "nested_field",
                       operators: ['in', 'not_in'],
                       actions:   ['forward_ticket']},
    object_id_array: { fields:    ['tag_ids'],
                       performer: 3,
                       event:     "update",
                       operators: ['in', 'and', 'not_in'],
                       actions:   ['delete_ticket']},
    checkbox:        { fields:    ['checkbox'],
                       performer: 1,
                       event:     "agent",
                       operators: ['selected', 'not_selected'],
                       actions:   ['mark_as_spam']},
    number:          { fields:    ['number'],
                       performer: 2,
                       event:     "value",
                       operators: ['is', 'is_not', 'greater_than', 'less_than'],
                       actions:   ['add_note']},
    decimal:         { fields:    ['decimal'],
                       performer: 3,
                       event:     "change",
                       operators: ['is', 'is_not', 'greater_than', 'less_than'],
                       actions:   ['responder_id']},
    date:            { fields:    ['date'],
                       performer: 1,
                       event:     "update",
                       operators: ['is' , 'is_not', 'greater_than', 'less_than'],
                       actions:   ['group_id']},
    nested_field:    { fields:    ['nested_field'],
                       performer: 1,
                       event:     "agent",
                       operators: ['is' , 'is_not', 'is_any_of'],
                       actions:   ['status']}
  }

  def generate_performer(performer_type)
    case performer_type
    when 1
      get_technician.make_current
      {
        "type" => "1",
        "members" => [get_technician.id]
      }
    when 2
      get_contact.make_current
      { "type" => "2" }
    when 3
      get_technician.make_current
      { "type" => "3" }
    when 4
      User.reset_current_user
      { "type" => "4" }
    end
  end

  def generate_event(event_type)
    case event_type
    when "update"
      [{
        name: "priority",
        from: 2,
        to: 3
      }]
    when "agent"
      [{
        name: "responder_id",
        from: get_technician.id,
        to: get_new_technician.id
      }]
    when "value"
      [{
        name: "ticket_action",
        value: "update"
      }]
    when "change"
      [{ name: "due_by" }]
    when "nested_field"
      parent_field = create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city))
      parent_field_choices = parent_field.picklist_values.pluck(:value)
      child_levels = parent_field.child_levels.all
      child_level_1 = child_levels.first
      child_level_1_choices = child_level_1.picklist_values.pluck(:value)
      child_level_2 = child_levels.last
      child_level_2_choices = child_level_2.picklist_values.pluck(:value)
      [{
        name: parent_field.column_name,
        from: parent_field_choices.first,
        to: parent_field_choices.first,
        rule_type: ["nested_rule", "nested_rule"],
        from_nested_rules: [
          {name: child_level_1.column_name, value: child_level_1_choices.first},
          {name: child_level_2.column_name, value: child_level_2_choices.first}
        ],
        to_nested_rules: [
          {name: child_level_1.column_name, value: child_level_1_choices.first},
          {name: child_level_2.column_name, value: child_level_2_choices.last}
        ],
        nested_rule: [
          {name: child_level_1.column_name, from: child_level_1_choices.first, to: child_level_1_choices.first},
          {name: child_level_2.column_name, from: child_level_2_choices.first, to: child_level_2_choices.last}
        ]
      }]
    end
  end

  def verify_action_data(action, ticket, not_operator)
    case true
    when ['priority', 'ticket_type', 'status', 'responder_id', 'product_id', 'group_id'].include?(action[:name])
      assert_equal ticket.safe_send(action[:name]), action[:value]
    when action == 'add_tag'
      assert_equal ticket.tag_names.last, action[:value]
    when action == 'add_a_cc'
      assert_equal ticket.cc_email[:cc_emails].last, action[:value]
    when action == 'add_watcher'
      assert_equal ticket.subscriptions.pluck(:user_id).last, action[:value][0]
    when action == 'forward_ticket'
      assert_equal ticket.notes.last.body, action[:fwd_note_body]
    when action == 'delete_ticket'
      assert_equal ticket.deleted, true
    when action == 'mark_as_spam'
      assert_equal ticket.spam, true
    when action == 'add_note'
      assert_equal ticket.notes.last.body, action[:note_body]
    end
  end

  def generate_action_data(action, not_operator)
    case true
    when ['responder_id', 'group_id'].include?(action)
      {
        name: action,
        value: generate_value(:object_id, action, not_operator)
      }
    when ['priority', 'ticket_type', 'status', 'product_id'].include?(action)
      {
        name: action,
        value: generate_value(:choicelist, action, not_operator)
      }
    when action == 'add_tag'
      {
        name: action,
        value: generate_value(:add_tag, action, not_operator)
      }
    when action == 'add_a_cc'
      {
        name: action,
        value: generate_value(:email, action, not_operator)
      }
    when action == 'add_watcher'
      {
        name: action,
        value: [generate_value(:object_id, 'responder_id', false)]
      }
    when action == 'forward_ticket'
      {
        name: action,
        fwd_to: [generate_value(:email, action, not_operator)],
        fwd_note_body: generate_value(:text, action, not_operator)
      }
    when action == 'add_note'
      {
        name: action,
        notify_agents: [get_technician.id],
        note_body: generate_value(:text, action, not_operator)
      }
    when ['delete_ticket', 'mark_as_spam'].include?(action)
      {
        name: action
      }
    end
  end

  def generate_ticket_params(field_name, ticket_value)
    params = case field_name
    when 'from_email'
      user = add_new_user(Account.current, { email: ticket_value})
      return {sender_email: ticket_value, requester_id: user.id}
    when 'ticlet_cc'
      field_name = 'cc_emails'
    when 'subject_or_description'
      field_name = 'subject'
    when 'created_during'
      field_name = 'created_at'
      ticket_value = Time.zone.today + 23.hours
    when 'to_email'
      field_name = 'to_emails'
    when 'internal_agent_id'
      internal_group = ticket_value ? @account.technicians.find_by_id(ticket_value).groups.first : nil
      status = internal_group.status_groups.first.status.status_id if internal_group.present?
      return {internal_agent_id: ticket_value,
              internal_group_id: internal_group.try(:id),
              status: status}
    when 'internal_group_id'
      internal_group = ticket_value ? @account.groups.find_by_id(ticket_value) : nil
      status = internal_group.status_groups.first.status.status_id if internal_group.present?
      return {internal_group_id: internal_group.try(:id),
              status: status}
    end
    field_name.ends_with?("_#{@account.id}") ? {custom_field: { "#{field_name}": ticket_value }} : 
                                              { "#{field_name}": ticket_value }
  end

  def generate_value(operator_type, field_name, not_operator, operator=nil)
    case operator_type
    when :email
      field_name.to_sym.eql?(:to_email) ? Faker::Internet.email.to_a : Faker::Internet.email
    when :text
      Faker::Lorem.characters(10)
    when :choicelist
      case field_name
      when 'priority'
        not_operator ? 1 : 2
      when 'ticket_type'
        not_operator ? 'Question' : 'Incident'
      when 'status'
        not_operator ? 2 : 3
      when 'source'
        not_operator ? 1 : 2
      when 'product_id'
        @account.products.new(name: Faker::Name.name).save if @account.products.count == 0
        product = @account.products.first
        not_operator ? nil : product.id
      end
    when :date_time
      not_operator ? 'business_hours' : 'non_business_hours'
    when :object_id
      case field_name
      when 'internal_agent_id'
        group = @account.ticket_statuses.visible.where(is_default: false).first.status_groups.first.group
        agents = group.agents
        not_operator ? nil : agents.first.id
      when 'internal_group_id'
        group = @account.ticket_statuses.visible.where(is_default: false).first.status_groups.first.group
        not_operator ? nil : group.id
      when 'group_id'
        not_operator ? nil : get_group.id
      when 'responder_id'
        not_operator ? nil : get_technician.id
      end
    when :object_id_array
      tag = get_tag
      not_operator ? nil : [tag.id]
    when :nested_field
      field, choices = get_nested_field(field_name)
      value = not_operator ? choices.last : choices.first
      operator == 'is_any_of' ? [value] : value
    when :checkbox
      not_operator ? false : true
    when :date
      return '2017-11-02' if not_operator
      case operator
      when 'greater_than'
        (Time.zone.now - 1.day).strftime('%Y-%m-%d')
      when 'less_than'
        (Time.zone.now + 1.day).strftime('%Y-%m-%d')
      else
        Time.zone.now.strftime('%Y-%m-%d')
      end
    when :number
      return 1 if not_operator
      case operator
      when 'greater_than'
        1
      when 'less_than'
        3
      else
        2
      end
    when :decimal
      return 1.0 if not_operator
      case operator
      when 'greater_than'
        1.0
      when 'less_than'
        3.0
      else
        2.0
      end
    when 'add_tag'
      get_tag.name
    end
  end

  def get_tag
    @tag ||= begin
      @account.tags.new(name: Faker::Name.name).save if @account.tags.count == 0
      @account.tags.first
    end
  end

  def get_technician
    @tech ||= Account.current.technicians.first
  end

  def get_new_technician
    @new_tech ||= begin
      new_tech = Account.current.technicians.last
      new_tech = add_agent(Account.current,
                           name: Faker::Name.name,
                           email: Faker::Internet.email,
                           active: 1,
                           role: 1, agent: 1,
                           role_ids: [Account.current.roles.find_by_name('Account Administrator').id.to_s],
                           ticket_permission: 1) if new_tech.id == get_technician.id
      new_tech
    end
  end

  def get_contact
    @contact ||= Account.current.contacts.first
  end

  def get_group
    @group ||= Account.current.groups.first
  end

  def get_nested_field(field_name)
    field = @account.ticket_fields_with_nested_fields.find_by_name(field_name)
    field = create_dependent_custom_field(%w(test_custom_country test_custom_state test_custom_city)) unless field.present?
    choices = field.choices.present? ? field.choices.flatten.uniq : []
    [field, choices]
  end
end
