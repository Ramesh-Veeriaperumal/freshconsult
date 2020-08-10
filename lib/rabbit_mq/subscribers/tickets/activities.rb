module RabbitMq::Subscribers::Tickets::Activities

  include RabbitMq::Constants
  include ActivityConstants
  include RabbitMq::Subscribers::TicketBodies::Activities
  include RabbitMq::Subscribers::Subscriptions::Activities
  VALID_MODELS = ["ticket", "ticket_body", "subscription"]

  PROPERTIES_TO_CONSIDER      = [:requester_id, :responder_id, :group_id, :priority, :ticket_type, :subject,
                                 :source, :status, :product_id, :spam, :deleted, :parent_ticket, :due_by,
                                 :association_type, :internal_group_id, :internal_agent_id, :sl_skill_id]
  PROPERTIES_TO_CONVERT       = [:group_id, :product_id, :status, :association_type, :internal_group_id, :sl_skill_id]
  PROPERTIES_AS_ARRAY         = [:add_tag, :add_watcher, :rule, :add_a_cc, :add_comment, :email_to_requester,
                                 :email_to_group, :email_to_agent, :association_type, :thank_you_note]
  PROPERTIES_RENAME_MAP       = {}
  SHARED_OWNERSHIP_PROPERTIES = [:internal_group_id, :internal_agent_id]

  def mq_activities_ticket_properties(action)
    self.to_rmq_json(activities_keys,action) 
  end

  def mq_activities_subscriber_properties(action)
    if self.is_a?(Helpdesk::Ticket)
      ticket_subscriber_properties(action)
    elsif self.is_a?(Helpdesk::TicketBody)
      ticket_body_subscriber_properties(action)
    elsif self.is_a?(Helpdesk::Subscription)
      subscription_subscriber_properties(action)
    end    
  end

  def ticket_subscriber_properties(action)
    destroy_action?(action) ? {} : activities_subscriber_properties(action)
  end

  def activities_subscriber_properties(action)
    skip_dashboard = (User.current.nil? || Thread.current[:skip_dashboard_activity].present?)
    ticket_changes = {}
    # Adding info for ticket import
    self.activity_type = {:type => "ticket_import"} if ticket_import? and create_action?(action)

    # Adding shared ownership reset changes. if shared ownership attributes present in model changes and not in system changes.
    # When status is changed, resetting shared ownership fields should be captured.
    self.activity_type = shared_ownership_reset_changes if va_rule_changes? and self.activity_type.nil? and Account.current.shared_ownership_enabled?

    # Add activity type info to ticket changes if any
    if activity_type?
      ticket_changes.merge!({:activity_type => self.activity_type})
      # Add target id for newly created ticket via note split
      ticket_changes[:activity_type][:target_ticket_id] ||= [self.display_id] if activity_type[:type].include?("ticket_split_target")
    end
    # Adding system changes seperately
    if va_rule_changes?    #for system changes
      ticket_changes.merge!(process_system_changes(system_changes.dup))
    elsif round_robin?
      # do nothing
    elsif archive          # for archive
      ticket_changes.merge!(misc_changes) if misc_changes?
    elsif delete_status?   # delete status
      ticket_changes.merge!(misc_changes) if misc_changes?
    else
      changes = create_action?(action) ? flexifield.before_save_changes : @model_changes
      custom_field_changes = process_flexifields(changes, "flexifield_name") unless destroy_action?(action)
      ticket_changes.merge!(custom_field_changes) if custom_field_changes.present?
      ticket_changes.merge!(misc_changes) if misc_changes?
      ticket_changes.merge!(ticket_related_changes) if !manual_publish?
      ticket_changes.merge!(set_default_priority) if create_action?(action) and !priority_present?(ticket_changes)
    end
    properties = { object_id: self.display_id, skip_dashboard: skip_dashboard, skip_dynamo: false, hypertrail_version: CentralConstants::HYPERTRAIL_VERSION }
    self.misc_changes = nil if misc_changes?
    if va_rule_changes?
      properties.merge({:system_changes => ticket_changes, :content => {} })
    else
      properties.merge({:content => ticket_changes})
    end
  end

  def mq_activities_valid(action, model)
    if VALID_MODELS.include?(model)
      safe_send("mq_activities_#{model}_valid", action, model)
    else
      false
    end
  end

  def mq_activities_ticket_valid(action, model)
    activity_valid_model?(model) && ticket_valid?(action)
  end

  private

  def activity_sl_skill_id(value)
    if is_num?(value[1])
      skill_name = Account.current.skills_from_cache.find {|skill| skill.id == value[1].to_i}.try(:name)
      return false if !skill_name
      value[1] = skill_name
    end
    {:skill_name => add_dont_care(value)}
  end

  def fetch_group_name(value)
    if is_num?(value[1])
      group = Account.current.groups_from_cache.find{|x| x.id == value[1].to_i}
      return false if !group
      value[1] = group.name
    end
  end

  def activity_group_id(value)
    fetch_group_name(value) == false ? false : {:group_id => add_dont_care(value)}
  end

  def activity_internal_group_id(value)
    fetch_group_name(value) == false ? false : {:internal_group_id => add_dont_care(value)}
  end

  def activity_product_id(value)
    if is_num?(value[1])
      product  = Account.current.products_from_cache.find {|x| x.id == value[1].to_i}
      return false if !product    # deleted product in action of va rule
      value[1] = product.name
    end
    {:product_id => add_dont_care(value)}
  end

  def add_dont_care(value)
    value[0] = DONT_CARE_VALUE if !value[0].nil?
    value[1] = nil if value[1].blank? and !value[1].nil?
    value
  end

  def activity_status(value)
    status = Account.current.ticket_status_values_from_cache.find{|x| x.status_id == value[1].to_i}
    if !status      # deleted status in action of va rule -> change to open
      value = [2, "Open"]
    else
      value[0] = value[1].to_i
      value[1] = status.name
    end
    {:status => value}
  end

  def activity_association_type(value)
    v = value.compact
    case v[0]
    when 1 # assoc parent tkt
      value[0].nil? ? {:assoc_parent_tkt_link => self.associates} : {:assoc_parent_tkt_unlink => self.associates}
    when 2 # child tkt
      assoc_prt_tkt_id = @assoc_parent_ticket ? [@assoc_parent_ticket.display_id] : self.associates
      value[0].nil? ? {:child_tkt_link => assoc_prt_tkt_id} : {:child_tkt_unlink => assoc_prt_tkt_id}
    when 3 # tracker tkt
      value[0].nil? ? {:tracker_link => [@related_ticket.display_id]} : {:tracker_reset => []}
      # for tracker tickets. doing manual push
    when 4 # related tkt
      tracker = tracker_ticket_id ? [ tracker_ticket_id.to_i ] : self.associates
      value[0].nil? ? {:rel_tkt_link => tracker } : {:rel_tkt_unlink => tracker }
    end
  end

  def activity_valid_model?(model)
    model == "ticket"
  end
    
  def ticket_valid?(action)
    destroy_action?(action) || archive || manual_publish? || user_changes? || system_changes?
  end 

  def ticket_import?
    self.import_id.present?
  end

  def activities_keys
    ACTIVITIES_TICKET_KEYS
  end

  def valid_model_changes
    # using dup -> to avoid modifying model_changes values
    changes_hash = i_to_s(valid_ticket_changes.dup)
    changes_hash
  end

  def valid_ticket_changes
    @model_changes.nil?  ? {} : @model_changes.dup.select{|k,v| PROPERTIES_TO_CONSIDER.include?(k) || ff_fields.include?(k.to_s) }
  end


  def shared_ownership_reset_changes
    reset_changes = {}
    SHARED_OWNERSHIP_PROPERTIES.each do |key|
      reset_changes[key] = @model_changes[key] if (@model_changes.present? and @model_changes[key].present? and @model_changes[key][1].nil?) and
      no_reset_actions_in_system_changes?(key)
    end
    if reset_changes.present?
      reset_changes[:type] = "shared_ownership_reset"
      reset_changes
    end
  end

  def no_reset_actions_in_system_changes?(key)
    system_changes.each do |rule_id, actions|
      return false if actions[key].present? and actions[key][1].nil?
    end
    true
  end

  # Change ids to string and replace dont care value for old values
  def i_to_s(actions)
    hash = {}
    actions.each do |k,v|
      # using dup -> to avoid modifying model_changes values
      key = PROPERTIES_RENAME_MAP[k.to_sym] || k
      v1  = PROPERTIES_AS_ARRAY.include?(key.to_sym) ? v.dup : add_dont_care(v.dup)
      if PROPERTIES_TO_CONVERT.include?(key.to_sym)
        value = safe_send("activity_#{key}", v1.dup)
        hash.merge!(value) if value != false
      else
        hash[key] = v1
      end
    end
    hash
  end

  def set_default_priority
    {:priority => [nil, TicketConstants::PRIORITY_KEYS_BY_TOKEN[:low]]}
  end

  def ticket_related_changes
    valid_model_changes.delete_if {|k,v| ff_fields.include?(k.to_s)}
  end

  def user_changes?
    ticket_changes_present? and !Va::RuleActivityLogger.automation_execution?
  end

  def system_changes?
    (va_rule_changes? || round_robin?) && ticket_changes_present?
  end

  def ticket_changes_present?
    valid_ticket_changes.present? || misc_changes?
  end

  def priority_present?(changes)
    changes[:priority].present?
  end

  def round_robin?
    activity_type? and activity_type[:type] == "round_robin" and User.current.nil?
  end

  def scenario_changes?  # Changes from scenario automations
    User.current.present? and Va::RuleActivityLogger.automation_execution?
  end

  def va_rule_changes?         # Changes by any rules
    system_changes.present?
  end

  def misc_changes?
    misc_changes.present?
  end

  def manual_publish?
    merge_target_activity? || split_source_activity?
  end

  def activity_type?
    activity_type.present?
  end

  def merge_target_activity?
     activity_type? and activity_type[:type] == "ticket_merge_target"
  end

  def split_source_activity?
     activity_type? and activity_type[:type] == "ticket_split_source"
  end

  def add_scenario(changes)
    keys = changes.keys
    keys.each do |x|
      actions = changes[x]
      if actions[:rule].present?
        actions[:execute_scenario] = actions[:rule]
        actions.delete(:rule)
      end
    end
    changes
  end

  def process_flexifields(changes, field)
    # field -> values
    # "flexifield_name" for user changes
    # "flexifield_alias" for system changes
    ticket_changes = {}
    checked        = []
    unchecked      = []
    acc_ff_fields  = Account.current.flexifields_with_ticket_fields_from_cache
    ff_fields_name = acc_ff_fields.map(&field.to_sym).map(&:to_sym)
    changes.each do |k,v|
      tf = acc_ff_fields.find {|f_field| f_field.safe_send(field) == k.to_s}.ticket_field if ff_fields_name.include?(k.to_sym)
      if tf
        case tf.field_type
        when "custom_paragraph", "custom_text", "encrypted_text", "secure_text"
          # for single line/multi line/encrypted text/secure text
          value = [nil, DONT_CARE_VALUE]
        when "custom_checkbox" # for check box
          (v[1] == true || v[1] == "1") ? checked << "#{tf.label}" : unchecked << "#{tf.label}"
        when "custom_date" # for date field
          value = v[1].is_a?(Time)  ? [nil,v[1].utc.strftime('%-d %b, %Y')] : add_dont_care(v)
        when "custom_number"
          value = v[1].is_a?(Integer) ? [nil, v[1].to_s] : add_dont_care(v)
        else
          value = add_dont_care(v)
        end
        # flexifield changes will be removed from changes hash for system changes
        changes.delete(k) if field == "flexifield_alias"
        ticket_changes.merge!({"#{tf.label}".to_sym => value}) if tf.field_type != "custom_checkbox"
      end
    end
    ticket_changes.merge!({:checked => checked}) if checked.present?
    ticket_changes.merge!({:unchecked => unchecked}) if unchecked.present?
    ticket_changes
  end

  def process_system_changes(sys_change)
    sys_change.each do |rule_id, actions| # for each rule
      # using dup -> to avoid modifying actual system changes values
      processed_changes = i_to_s(actions.dup)
      flexi_changes = process_flexifields(processed_changes, "flexifield_alias")
      processed_changes.merge!(flexi_changes)
      sys_change[rule_id] = processed_changes
    end
    add_scenario(sys_change) if scenario_changes?
    sys_change
  end

  def is_num?(string)
    Integer(string)
    true
  rescue ArgumentError, TypeError
    false
  end

  def delete_status?
    self.misc_changes.present? and self.misc_changes[:delete_status]
  end

end
