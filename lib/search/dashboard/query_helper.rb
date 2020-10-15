module Search::Dashboard::QueryHelper
  include Admin::AdvancedTicketing::FieldServiceManagement::Util
  include AdvancedTicketScopes
  # For search service count cluster migration. This file is used for filter params to FQL Strings.

  # Field mapping used to transform to search service field
  COLUMN_MAPPING = {
      'helpdesk_schema_less_tickets.boolean_tc02' =>  'trashed',
      'owner_id'                                  =>  'company_id',
      'helpdesk_tags.id'                          =>  'tag_ids',
      'helpdesk_tags.name'                        =>  'tag',
      'helpdesk_subscriptions.user_id'            =>  'watchers',
      'helpdesk_schema_less_tickets.product_id'   =>  'product_id',
      'internal_group'                            =>  'internal_group_id',
      'internal_agent'                            =>  'internal_agent_id',
      'ticket_type'                               =>  'type',
      'frDueBy'                                   =>  'fr_due_by'
    }

  FRESHQUERY_TRANSFORMATION = {
    'fr_due_by' => 'frDueBy',
    'type' => 'ticket_type',
    'tag' => 'tag_names'
  }.freeze
  STRING_FIELDS = ['type', 'tag', 'ticket_type', 'tag_names'].freeze

  NOT_ANALYZED_COLUMNS = { "type" => "ticket_type" }

  SINGLE_QUOTE = '#&$!SinQuo'.freeze
  DOUBLE_QUOTE = '#&$!DouQuo'.freeze
  BACK_SLASH = '#&$!BacSla'.freeze

  DUE_BY_FIELDS = [:due_by, :fr_due_by, :nr_due_by, :frDueBy].freeze

  # WF Filter conditions is convert into FQL Format for search service
  def transform_fields(wf_conditions)
    conditions = []
    wf_conditions.each do |field|
      cond_field = (COLUMN_MAPPING[field['condition']].presence || field['condition'].to_s)
      if Account.current.wf_comma_filter_fix_enabled?
        field_values = field['value'].is_a?(Array) ? field['value'].map(&:to_s) : field['value'].to_s.split(::FilterFactory::TicketFilterer::TEXT_DELIMITER)
      else
        field_values = field['value'].to_s.split(',')
      end
      field_values = field_values.map { |value| Account.current.launched?(:dashboard_java_fql_performance_fix) ? encode_new_fql(value) : encode_value(value) } # Hack to handle special chars in query
      if cond_field.include?(QueryHash::FLEXIFIELDS) || cond_field.include?(QueryHash::TICKET_FIELD_DATA)
        conditions << transform_flexifield_filter_new_fql(field, field_values)
      elsif cond_field.present?
      	conditions << transform_field(cond_field, field_values) 
      end
    end
    conditions << construct_query_for_restricted if @with_permissible and User.current.agent? and User.current.restricted?
    conditions.join(" AND ")
  end

  def transform_flexifield_filter_new_fql(field, field_values)
    field_name = field['ff_name'].gsub("_#{Account.current.id}", '')
    condition = transform_flexifield_filter(field_name, field_values)
    condition = condition.gsub(field_name, field['condition'].split('.').last) if Account.current.launched?(:dashboard_java_fql_performance_fix)
    condition
  end

  def construct_query_for_restricted
    Account.current.shared_ownership_enabled? ? shared_ownership_permissible_filter : permissible_filter 
  end

  def permissible_filter
    ({
      :group_tickets      =>  add_or_condition([transform_group_id('group_id', ['0']),transform_responder_id('responder_id', [User.current.id.to_s])]),
      :assigned_tickets   =>  transform_responder_id('responder_id', [User.current.id.to_s])
    })[Agent::PERMISSION_TOKENS_BY_KEY[User.current.agent.ticket_permission]]
  end

  def shared_ownership_permissible_filter
    ({
      :group_tickets    => add_or_condition([transform_group_id('group_id', ['0']),transform_internal_group_id('internal_group_id', ['0']),transform_responder_id('responder_id', [User.current.id.to_s]),transform_internal_agent_id('internal_agent_id', [User.current.id.to_s])]),
      :assigned_tickets => add_or_condition([transform_responder_id('responder_id', [User.current.id.to_s]),transform_internal_agent_id('internal_agent_id', [User.current.id.to_s])])
      })[Agent::PERMISSION_TOKENS_BY_KEY[User.current.agent.ticket_permission]]
  end

  # External filter conditions is convert into FQL Format for search service.  
  # @filter_condition -> external filters in form of {"group_id" => [1,2], "status" => [3]}
  def construct_filter_query_es
    temp = []
    @filter_condition.each do |k,v|
      cond_field = (COLUMN_MAPPING[k].presence || k.to_s)
      temp << transform_field(cond_field, v.map(&:to_s)) #to make string
    end
    temp << construct_query_for_restricted if @with_permissible and User.current.agent? and User.current.restricted?
    temp.join(' AND ')
  end

  # create group_by hash which will be sent to search service group by hash. It is used for aggs by field_name
  # sample level_1 => {"field_name" => "status", "missing" => true/false}
  def group_by_field(field, missing=false, limit=100, order=nil )
    group_by={}
    group_by["field"] = group_by_field_name(field)
    group_by["missing"] = missing
    group_by["limit"] = limit
    group_by["order"] = order if order.present?
    group_by
  end

  def group_by_field_name(f_name)
    fname = COLUMN_MAPPING[f_name].presence || f_name
    fname = NOT_ANALYZED_COLUMNS[fname] + ".not_analyzed" if NOT_ANALYZED_COLUMNS.keys.include?(fname)
    fname = fname + ".not_analyzed" if fname.include?("ffs")
    fname
  end

  # For handling responder ids
  def transform_responder_id(field_name , values)
    if values.include?('0')
      values.delete('0')
      values.push(User.current.id.to_s)
    end
    transform_filter('responder_id', values)
  end

  # For handling group id
  ['transform_group_id','transform_internal_group_id'].each do |method_name|
    define_method method_name do |field_name, values|
      if values.include?('0')
        values.delete('0')
        if advanced_scope_enabled?
          @current_agent_group ||= User.current.all_agent_groups.pluck(:group_id).map(&:to_s)
        else
          @current_agent_group ||= User.current.agent_groups.pluck(:group_id).map(&:to_s)
        end
        values.concat(@current_agent_group)
      end
      transform_filter(field_name, values)
    end
  end

  def transform_any_group_id(field_name, values)
    "(#{transform_field('group_id', values.dup)} OR #{transform_field('internal_group_id', values.dup)})"
  end

  def transform_any_agent_id(field_name, values)
    "(#{transform_field('responder_id', values.dup)} OR #{transform_field('internal_agent_id', values.dup)})"
  end

  #For handling status
  def transform_status(field_name, values)
    if values.include?('0')
      values.delete('0')
      values.concat(Helpdesk::TicketStatus.unresolved_statuses(Account.current).map(&:to_s))
    end
    transform_filter(field_name, values)
  end

  # For handling internal agent ids
  ["transform_watchers", "transform_internal_agent_id"].each do |method_name|
    define_method method_name do |field_name, values|
      if values.include?('0')
        values.delete('0')
        values.push(User.current.id.to_s)
      end
      transform_filter(field_name, values)
    end
  end
    
  # Handle conditions with null queries 
  def transform_filter(field_name, values)
    null_included = values.include?("-1")
    values.delete('-1') if null_included
    return "#{field_name}:null" unless values.present?
  	query = "#{field_name}:" + values.join(" OR #{field_name}:")
    query = "#{field_name}:'" + values.join("' OR #{field_name}:'") + "'" if STRING_FIELDS.include?(field_name)
    query =  query + " OR #{field_name}:null"  if null_included 
  	(values.length > 1 || null_included) ? "(" + query + ")"  : query
  end

  #handling flexifields 
  def transform_flexifield_filter(field_name, values)
    if TicketFilterConstants::FSM_DATE_TIME_FIELDS.include?(field_name) # fsm appointment fields check
      transform_fsm_appointment_times(field_name, values)
    else
      queries = []
      if values.include?('-1')
        values.delete('-1')
        queries << "#{field_name}:null"
      end
      queries.push(*values.map { |val| "#{field_name}:'#{val}'" }) if values.present?
      queries.length > 1 ? add_or_condition(queries) : queries.first
    end
  end

    # Only one value can be chosen
  def transform_created_at(field_name, value)
    value = value.first #=> One value in array as we do .split
    case value
    when 'today'
      "created_at:>'#{Time.zone.now.beginning_of_day.utc.iso8601}'"
    when 'yesterday'
      "created_at:>'#{Time.zone.now.yesterday.beginning_of_day.utc.iso8601}' AND created_at:<'#{Time.zone.now.beginning_of_day.utc.iso8601}'"
    when 'week'
      "created_at:>'#{Time.zone.now.beginning_of_week.utc.iso8601}'"
    when 'last_week'
      "created_at:>'#{Time.zone.now.beginning_of_day.ago(7.days).utc.iso8601}'"
    when 'month'
      "created_at:>'#{Time.zone.now.beginning_of_month.utc.iso8601}'"
    when 'last_month'
      "created_at:>'#{Time.zone.now.beginning_of_day.ago(1.month).utc.iso8601}'"
    when 'two_months'
      "created_at:>'#{Time.zone.now.beginning_of_day.ago(2.months).utc.iso8601}'"
    when 'six_months'
      "created_at:>'#{Time.zone.now.beginning_of_day.ago(6.months).utc.iso8601}'"
    else
      if value.to_s.is_number?
      	"created_at:>'#{Time.zone.now.ago(value.to_i.minutes).utc.iso8601}'"
      else
        start_date, end_date = value.split('-')
        "created_at:>'#{Time.zone.parse(start_date).utc.iso8601}' AND created_at:<'#{Time.zone.parse(end_date).end_of_day.utc.iso8601}'"
      end
    end
  end

  def transform_updated_at(field_name, value)
    value = value.first
    "updated_at:>'#{Time.zone.parse(value).utc.iso8601}'"
  end

  DUE_BY_FIELDS.each do |field_name|
    define_method "transform_#{field_name}" do |field_name, values|
      transform_due_by_fields(field_name, values)
    end
  end

  # due by fields
  def transform_due_by_fields(field_name, values)
    queries = []
    min_value = minimum_required_due_condition(values.collect(&:to_i))
    values.each do |value|
      next if min_value.present? && value.to_i > min_value

      case value.to_i
      # Overdue
      when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:all_due]
      	queries << "#{field_name}:<'#{Time.zone.now.utc.iso8601}'"
      # Today
      when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_today]
      	queries << "(#{field_name}:>'#{Time.zone.now.beginning_of_day.utc.iso8601}' AND #{field_name}:<'#{Time.zone.now.end_of_day.utc.iso8601}')"
      # Tomorrow
      when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_tomo]
      	queries << "(#{field_name}:>'#{Time.zone.now.tomorrow.beginning_of_day.utc.iso8601}' AND #{field_name}:<'#{Time.zone.now.tomorrow.end_of_day.utc.iso8601}')"
      # Next 8 hours
      when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_eight]
      	queries << "(#{field_name}:>'#{Time.zone.now.utc.iso8601}' AND #{field_name}:<'#{8.hours.from_now.utc.iso8601}')"
      # Next 4 hours
      when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_four]
        queries << "(#{field_name}:>'#{Time.zone.now.utc.iso8601}' AND #{field_name}:<'#{4.hours.from_now.utc.iso8601}')"
      # Next 2 hours
      when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_two]
        queries << "(#{field_name}:>'#{Time.zone.now.utc.iso8601}' AND #{field_name}:<'#{2.hours.from_now.utc.iso8601}')"
      # Next 1 hour
      when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_hour]
        queries << "(#{field_name}:>'#{Time.zone.now.utc.iso8601}' AND #{field_name}:<'#{1.hours.from_now.utc.iso8601}')"
      # Next 30 minutes
      when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_half_hour]
        queries << "(#{field_name}:>'#{Time.zone.now.utc.iso8601}' AND #{field_name}:<'#{30.minutes.from_now.utc.iso8601}')"
      end
    end
    add_or_condition(queries) + ' AND status_stop_sla_timer:false AND status_deleted:false' + (field_name == 'fr_due_by' ? fr_due_conditions : '')
  end

  def fr_due_conditions
    " AND (#{transform_filter('source', Helpdesk::Source.default_ticket_source_keys_by_token.except(:outbound_email).values)}) AND agent_responded_at:null"
  end

  def minimum_required_due_condition(conditions)
    (conditions - TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN.slice(:all_due, :due_today, :due_tomo).values).min
  end

  def add_or_condition(queries)
    "(" + queries.join(" OR ") + ")"
  end

  #for common transform fields
  def transform_field(field_name, values)
    field_name = (FRESHQUERY_TRANSFORMATION[field_name] || field_name) if Account.current.launched?(:dashboard_java_fql_performance_fix)
    begin
      condition = safe_send("transform_#{field_name}", field_name, values)
    rescue StandardError
      condition = transform_filter(field_name, values)
    end
    condition
  end

  # for FSM appointment start time and end time fields
  def transform_fsm_appointment_times(field_name, values)
    field_name = fsm_field_display_name(field_name)
    value = values.first
    date_filter_values = TicketFilterConstants::DATE_TIME_FILTER_DEFAULT_OPTIONS_HASH
    start_time, end_time = case value
                            when date_filter_values[:today]
                              [Time.zone.now.beginning_of_day, Time.zone.now.end_of_day]
                            when date_filter_values[:tomorrow]
                              [Time.zone.now.tomorrow.beginning_of_day, Time.zone.now.tomorrow.end_of_day]
                            when date_filter_values[:yesterday]
                              [Time.zone.now.yesterday.beginning_of_day, Time.zone.now.yesterday.end_of_day]
                            when date_filter_values[:week]
                              [Time.zone.now.beginning_of_week, Time.zone.now.end_of_week]
                            when date_filter_values[:last_week]
                              [Time.zone.now.prev_week.beginning_of_week, Time.zone.now.prev_week.end_of_week]
                            when date_filter_values[:next_week]
                              [Time.zone.now.next_week.beginning_of_week, Time.zone.now.next_week.end_of_week]
                            when date_filter_values[:in_the_past]
                              [nil, Time.zone.now.ago(1.second)]
                            when date_filter_values[:none]
                              [nil, nil]
                            else
                              start, finish = value.split(' - ')
                              [Time.zone.parse(start.to_s), Time.zone.parse(finish.to_s)]
                           end
    to_es_condition(field_name, start_time.try(:utc).try(:iso8601), end_time.try(:utc).try(:iso8601))
  end

  def to_es_condition(field_name, start_time, end_time)
    if start_time && end_time
      "#{field_name}:>'#{start_time}' AND #{field_name}:<'#{end_time}'"
    elsif start_time
      "#{field_name}:>'#{start_time}'"
    elsif end_time
      "#{field_name}:<'#{end_time}'"
    else
      "#{field_name}:null"
    end
  end

  def encode_new_fql(value)
    value.gsub(/[']/, '\'' => "\\'")
  end

  def encode_value(value)
    # Hack to handle special chars in query
    value.gsub(/['"\\]/, '\'' => SINGLE_QUOTE, '"' => DOUBLE_QUOTE, '\\' => BACK_SLASH)
  end

  def decode_values(values)
    # Hack to handle special characters ' " \ in query
    values.gsub(SINGLE_QUOTE, '\'').gsub(DOUBLE_QUOTE, '\"').gsub(BACK_SLASH, '\\\\\\\\')
  end
end
