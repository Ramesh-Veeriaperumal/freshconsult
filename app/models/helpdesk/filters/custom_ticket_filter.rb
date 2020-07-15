class Helpdesk::Filters::CustomTicketFilter < Wf::Filter
  
  include Search::TicketSearch
  include Helpdesk::Ticketfields::TicketStatus
  include Cache::Memcache::Helpdesk::Filters::CustomTicketFilter
  include Collaboration::TicketFilter
  include Cache::Memcache::Dashboard::Custom::CacheData

  attr_accessor :query_hash

  concerned_with :presenter

  has_many :dashboard_widgets, class_name: 'DashboardWidget', foreign_key: 'ticket_filter_id'

  after_commit :update_widgets, on: :update

  before_destroy :deactivate_widgets, :save_deleted_filters_info

  publishable on: [:create, :update, :destroy]

  MODEL_NAME = "Helpdesk::Ticket"
  TICKET_FIELD_DATA = 'ticket_field_data'.freeze
  FLEXIFIELDS = 'flexifields'.freeze

  def self.deleted_condition(input)
    { "condition" => "deleted", "operator" => "is", "value" => input}
  end
  
  def self.spam_condition(input)
    { "condition" => "spam", "operator" => "is", "value" => input}
  end

  def self.unresolved_condition
    { "condition" => "status", "operator" => "is_in", "value" => 0}
  end

  def self.service_task_type_condition
    { 'condition' => 'ticket_type', 'operator' => 'is_in', 'value' => Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_TYPE }
  end

  def on_hold_filter
    [{ "condition" => "status", "operator" => "is_in", "value" => (Helpdesk::TicketStatus::onhold_statuses(Account.current)).join(',')},
      { "condition" => "spam", "operator" => "is", "value" => false},{ "condition" => "deleted", "operator" => "is", "value" => false}]
  end

  def raised_by_me_filter
    [{ "condition" => "requester_id", "operator" => "is_in", "value" => [User.current.id]},
     { "condition" => "spam", "operator" => "is", "value" => false},
     { "condition" => "deleted", "operator" => "is", "value" => false}]
  end

  def self.unassigned_condition
    { 'condition' => 'responder_id', 'operator' => 'is_in', 'value' => -1 }
  end

  def self.fetch_appointment_time
    appointment_time = {}
    appointment_time[:start_time] = Account.current.custom_date_time_fields_from_cache.find { |x| x.name == TicketFilterConstants::FSM_APPOINTMENT_START_TIME + "_#{Account.current.id}" }
    appointment_time[:end_time] = Account.current.custom_date_time_fields_from_cache.find { |x| x.name == TicketFilterConstants::FSM_APPOINTMENT_END_TIME + "_#{Account.current.id}" }
    appointment_time
  end

  def self.appointment_time_in_the_past_condition
    appointment_time = Helpdesk::Filters::CustomTicketFilter.fetch_appointment_time
    { 'condition' => "#{custom_field_table_name}.#{appointment_time[:end_time].column_name}", 'operator' => 'is', 'value' => 'in_the_past', 'ff_name' => appointment_time[:end_time].name.to_s }
  end

  def self.appointment_time_ends_today_condition
    appointment_time = Helpdesk::Filters::CustomTicketFilter.fetch_appointment_time
    { 'condition' => "#{custom_field_table_name}.#{appointment_time[:end_time].column_name}", 'operator' => 'is', 'value' => 'today', 'ff_name' => appointment_time[:end_time].name.to_s }
  end

  def self.appointment_time_starts_today_condition
    appointment_time = Helpdesk::Filters::CustomTicketFilter.fetch_appointment_time
    { 'condition' => "#{custom_field_table_name}.#{appointment_time[:start_time].column_name}", 'operator' => 'is', 'value' => 'today', 'ff_name' => appointment_time[:start_time].name.to_s }
  end

  def self.open_pending_condition
    { 'condition' => 'status', 'operator' => 'is_in', 'value' => "#{OPEN}, #{PENDING}" }
  end

  def unassigned_service_tasks_filter
    [Helpdesk::Filters::CustomTicketFilter.unassigned_condition,
     Helpdesk::Filters::CustomTicketFilter.open_pending_condition,
     Helpdesk::Filters::CustomTicketFilter.service_task_type_condition,
     Helpdesk::Filters::CustomTicketFilter.deleted_condition(false),
     Helpdesk::Filters::CustomTicketFilter.spam_condition(false)]
  end

  def service_tasks_starting_today_filter
    [Helpdesk::Filters::CustomTicketFilter.open_pending_condition,
     Helpdesk::Filters::CustomTicketFilter.appointment_time_starts_today_condition,
     Helpdesk::Filters::CustomTicketFilter.service_task_type_condition,
     Helpdesk::Filters::CustomTicketFilter.deleted_condition(false),
     Helpdesk::Filters::CustomTicketFilter.spam_condition(false)]
  end

  def overdue_service_tasks_filter
    [Helpdesk::Filters::CustomTicketFilter.appointment_time_in_the_past_condition,
     Helpdesk::Filters::CustomTicketFilter.open_pending_condition,
     Helpdesk::Filters::CustomTicketFilter.service_task_type_condition,
     Helpdesk::Filters::CustomTicketFilter.deleted_condition(false),
     Helpdesk::Filters::CustomTicketFilter.spam_condition(false)]
  end

  def service_tasks_due_today_filter
    [Helpdesk::Filters::CustomTicketFilter.appointment_time_ends_today_condition,
     Helpdesk::Filters::CustomTicketFilter.open_pending_condition,
     Helpdesk::Filters::CustomTicketFilter.service_task_type_condition,
     Helpdesk::Filters::CustomTicketFilter.deleted_condition(false),
     Helpdesk::Filters::CustomTicketFilter.spam_condition(false)]
  end

  def unresolved_service_tasks_filter
    [Helpdesk::Filters::CustomTicketFilter.unresolved_condition,
     Helpdesk::Filters::CustomTicketFilter.service_task_type_condition,
     Helpdesk::Filters::CustomTicketFilter.deleted_condition(false),
     Helpdesk::Filters::CustomTicketFilter.spam_condition(false)]
  end

  def self.collab_filter_condition(display_ids)
    [{ "condition" => "helpdesk_tickets.display_id", "operator" => "is_in", "value" => display_ids.join(",")},
      spam_condition(false), deleted_condition(false)]
  end

  # This filter function fetches data from collaboration/tickets.rb; that fetches data from collab microservice
  def ongoing_collab_filter
    @collab_tickets ||= Helpdesk::Filters::CustomTicketFilter.collab_filter_condition(Collaboration::Ticket.new.fetch_collab_tickets)
  end

  def shared_by_me_filter
    status_groups = Account.current.account_status_groups_from_cache
    shared_filter_condition(status_groups, "responder_id")
  end

  def shared_with_me_filter
    user_group_ids = User.current.group_ids
    status_groups = Account.current.account_status_groups_from_cache.select{|sg| user_group_ids.include?(sg.group_id)}
    shared_filter_condition(status_groups, TicketConstants::INTERNAL_AGENT_ID)
  end

  def shared_filter_condition(status_groups, agent_type)
    sg_group_ids  = status_groups.map(&:group_id).uniq
    sg_status_ids = status_groups.map(&:status_id).uniq
    status_ids    = Account.current.ticket_status_values_from_cache.select{|s| 
      sg_status_ids.include?(s.id)}.map(&:status_id)

    conditions_array = [ 
      { "condition" => agent_type, "operator" => "is_in", "value" => "0"},
      Helpdesk::Filters::CustomTicketFilter.spam_condition(false),
      Helpdesk::Filters::CustomTicketFilter.deleted_condition(false)
    ]
    conditions_array << { "condition" => "status", "operator" => "is_in", "value" => status_ids.join(',')} if status_ids.present?
    conditions_array << { "condition" => TicketConstants::INTERNAL_GROUP_ID, "operator" => "is_in", "value" => sg_group_ids.join(',')} if sg_group_ids.present?
    conditions_array
  end

  def api_all_tickets_filter
    [self.class.spam_condition(false), self.class.deleted_condition(false)]
  end

  def self.trashed_condition(input)
    { "condition" => 
      "helpdesk_schema_less_tickets.#{Helpdesk::SchemaLessTicket.trashed_column}", 
      "operator" => "is", "value" => input}
  end

  def self.created_in_last_month
    {"condition" => "created_at", "operator" => "is_greater_than", "value" => "last_month"}
  end

  DEFAULT_FILTERS = { 
                      "spam" => [spam_condition(true),deleted_condition(false),trashed_condition(false)],
                      "deleted" =>  [deleted_condition(true),trashed_condition(false)],
                      "overdue" =>  [{ "condition" => "due_by", "operator" => "due_by_op", "value" => TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:all_due]},spam_condition(false),deleted_condition(false) ],
                      "pending" => [{ "condition" => "status", "operator" => "is_in", "value" => PENDING},spam_condition(false),deleted_condition(false)],
                      "open" => [{ "condition" => "status", "operator" => "is_in", "value" => OPEN},spam_condition(false),deleted_condition(false)],
                      "due_today" => [{ "condition" => "due_by", "operator" => "due_by_op", "value" => TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_today]},spam_condition(false),deleted_condition(false)],
                      "new" => [{ "condition" => "status", "operator" => "is_in", "value" => OPEN},{ "condition" => "responder_id", "operator" => "is_in", "value" => "-1"},spam_condition(false),deleted_condition(false)],
                      "monitored_by" => [{ "condition" => "helpdesk_subscriptions.user_id", "operator" => "is_in", "value" => "0"},spam_condition(false),deleted_condition(false)],
                      "new_and_my_open" => [{ "condition" => "status", "operator" => "is_in", "value" => OPEN},{ "condition" => "responder_id", "operator" => "is_in", "value" => "-1,0"},spam_condition(false),deleted_condition(false)],
                      "all_tickets" => [spam_condition(false),deleted_condition(false),created_in_last_month],
                      "unresolved" => [unresolved_condition, spam_condition(false), deleted_condition(false)],
                      "article_feedback" => [spam_condition(false), deleted_condition(false)],
                      'unresolved_article_feedback' => [unresolved_condition, spam_condition(false), deleted_condition(false)],
                      'my_article_feedback' => [spam_condition(false), deleted_condition(false)]
  }
  DEFAULT_FILTERS_FOR_SEARCH = { 
                      "spam" => "spam:true AND deleted:false",
                      "deleted" =>  "deleted:true",
                      "spam_deleted" =>  "spam:false AND deleted:false",
                      "pending" => "status:#{PENDING} AND spam:false AND deleted:false",
                      "open" => "status:#{OPEN} AND spam:false AND deleted:false",
                      "new" => "spam:false AND deleted:false AND agent_id:null AND status:#{OPEN}",
                   }

  DYNAMIC_DEFAULT_FILTERS = (['on_hold', 'raised_by_me', 'ongoing_collab', 'shared_by_me', 'shared_with_me'] + Admin::AdvancedTicketing::FieldServiceManagement::Constant::FSM_TICKET_FILTERS).freeze
  USER_COLUMNS = ["responder_id", "helpdesk_subscriptions.user_id", "internal_agent_id"]
  GROUP_COLUMNS = ["group_id", "internal_group_id"]
  SCHEMA_LESS_COLUMNS = [
      "helpdesk_schema_less_tickets.boolean_tc02",
      "helpdesk_schema_less_tickets.product_id"
    ]

  DYNAMIC_FIELDS = ["responder_id", "group_id", "internal_group_id", "internal_agent_id"]

  after_create :create_accesible
  after_update :save_accessible

  after_commit :clear_cache
   
  def create_accesible     
    self.accessible = Admin::UserAccess.new( {:account_id => account_id }.merge(self.visibility)  )
    self.save
  end
  
  def save_accessible
    self.accessible.update_attributes(self.visibility) unless self.visibility.blank?
  end
  
  def has_permission?(user)
    (accessible.all_agents?) or (accessible.only_me? and accessible.user_id == user.id) or (accessible.group_agents_visibility? and !user.agent_groups.find_by_group_id(accessible.group_id).nil?)
  end

  def update_condition key, replace_key
    conditions = self.data[:data_hash]
    updated = false

    conditions.each do |condition|
      next if key != condition["condition"]
      updated = true
      if replace_key.present?
        condition["condition"] = replace_key
      else
        conditions.delete(condition)
      end
    end

    self.query_hash = conditions if updated
    updated
  end

  def definition
    @definition ||= begin
      defs = {}
      filter_attribute_hash = Hash[Array.wrap(query_hash).collect { |c| [(c['condition'] || c[:condition]).to_sym, true] }]
      # default fields
      default_columns_defs(defs, filter_attribute_hash)
      # Shared agent, group columns
      shared_agent_group_columns_defs(defs, filter_attribute_hash, TicketConstants::SHARED_AGENT_COLUMNS_KEYS_BY_TOKEN, :responder_id)
      shared_agent_group_columns_defs(defs, filter_attribute_hash, TicketConstants::SHARED_GROUP_COLUMNS_KEYS_BY_TOKEN, :group_id)

      # Custom date time field
      if current_filter_includes_custom_field?(filter_attribute_hash.keys)
        fsm_columns_defs(defs)
        # Custom dropdown fields
        custom_dropdown_defs(defs, filter_attribute_hash)
        # Custom nested fields
        nested_fields_defs(defs, filter_attribute_hash)
      end
      # misc defs
      misc_defs(defs, filter_attribute_hash)
      defs
    end
  end

  def build_field_hash(col)
    field_container = get_container_from_field(col)
    {
      get_op_from_field(col).to_sym => field_container,
      :name => col.label,
      :container => field_container,
      :operator => get_op_from_field(col),
      :options => fetch_custom_choices(col)
    }
  end

  def fetch_custom_choices(col)
    join_tf_data? ? get_custom_choices_by_id(col) : get_custom_choices(col)
  end

  def fetch_field_key(col)
    join_tf_data? ? fetch_ffs_col_name_from_field(col) : get_id_from_field(col)
  end

  def join_tf_data?
    @join_tf_data ||= Account.current.join_ticket_field_data_enabled?
  end

  def fetch_ffs_col_name_from_field(tf)
    col_name = tf.respond_to?(:column_name) && tf.column_name.present? ? tf.column_name : tf.flexifield_def_entry.flexifield_name
    "ticket_field_data.#{col_name}"
  end
  
  def default_order
    'created_at'
  end

  def default_filter(filter_name, from_export = false, from_api=false)
    default_value = from_export ? "all_tickets" : "new_and_my_open"
    self.name = filter_name.blank? ? default_value : filter_name

    if "on_hold".eql?filter_name
      on_hold_filter
    elsif "raised_by_me".eql?filter_name
      raised_by_me_filter
    elsif collab_filter_enabled_for?(filter_name)
      ongoing_collab_filter
    elsif (from_api && "all_tickets".eql?(filter_name))
     api_all_tickets_filter
    elsif("shared_by_me" == filter_name and Account.current.shared_ownership_enabled?)
      shared_by_me_filter
    elsif("shared_with_me" == filter_name and Account.current.shared_ownership_enabled?)
      shared_with_me_filter
    elsif filter_name == 'unresolved_service_tasks'
      unresolved_service_tasks_filter
    elsif filter_name == 'unassigned_service_tasks'
      unassigned_service_tasks_filter
    elsif filter_name == 'overdue_service_tasks'
      overdue_service_tasks_filter
    elsif filter_name == 'service_tasks_due_today'
      service_tasks_due_today_filter
    elsif filter_name == 'service_tasks_starting_today'
      service_tasks_starting_today_filter
    else
      DEFAULT_FILTERS.fetch(filter_name, DEFAULT_FILTERS[default_value]).dclone
    end
  end

  def default_filter_for_es_search(filter_name)
    Time.use_zone(Account.current.time_zone) do
      default_value = "all_tickets"
      if ["overdue","due_today","all_tickets","unresolved","new_and_my_open"].include?(filter_name)
        DEFAULT_FILTERS_FOR_SEARCH["spam_deleted"] + " AND " + safe_send("#{filter_name}_filter")
      elsif "on_hold".eql?filter_name
        statuses = Helpdesk::TicketStatus.onhold_statuses(Account.current)
        DEFAULT_FILTERS_FOR_SEARCH["spam_deleted"] + " AND " + (statuses.present? ? "(status:" + statuses.join(' OR status:') + ")" : "status:null")
      elsif collab_filter_enabled_for?(filter_name) or "raised_by_me".eql?filter_name
        # custom_ticket_filter_query(ongoing_collab_filter)  need to do
        DEFAULT_FILTERS_FOR_SEARCH["spam_deleted"] + " AND requester_id:#{User.current.id}"
      elsif(["shared_by_me","shared_with_me"].include?(filter_name) and Account.current.shared_ownership_enabled?)
        safe_send("#{filter_name}_filter")
      elsif 'unassigned_service_tasks'.eql? filter_name
        DEFAULT_FILTERS_FOR_SEARCH['spam_deleted'] + " AND responder_id:null AND ( status:2 OR status:3 ) AND type:'#{Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_TYPE}'"
      elsif 'overdue_service_tasks'.eql? filter_name
        DEFAULT_FILTERS_FOR_SEARCH['spam_deleted'] + " AND fsm_appointment_end_time:<'#{Time.zone.now.ago(1.second).utc.iso8601}'  AND ( status:2 OR status:3 ) AND type:'#{Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_TYPE}'"
      elsif 'service_tasks_due_today'.eql? filter_name
        DEFAULT_FILTERS_FOR_SEARCH['spam_deleted'] + " AND fsm_appointment_end_time:>'#{Time.zone.now.beginning_of_day.utc.iso8601}' AND fsm_appointment_end_time:<'#{Time.zone.now.end_of_day.utc.iso8601}' AND ( status:2 OR status:3 ) AND type:'#{Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_TYPE}'"
      elsif 'service_tasks_starting_today'.eql? filter_name
        DEFAULT_FILTERS_FOR_SEARCH['spam_deleted'] + " AND fsm_appointment_start_time:>'#{Time.zone.now.beginning_of_day.utc.iso8601}' AND fsm_appointment_start_time:<'#{Time.zone.now.end_of_day.utc.iso8601}' AND ( status:2 OR status:3 ) AND type:'#{Admin::AdvancedTicketing::FieldServiceManagement::Constant::SERVICE_TASK_TYPE}'"
      else
        DEFAULT_FILTERS_FOR_SEARCH.fetch(filter_name, DEFAULT_FILTERS_FOR_SEARCH[default_value]).dclone
      end
    end
  end

  def overdue_filter
    "due_by:<'#{Time.zone.now.utc.iso8601}' AND status_stop_sla_timer:false AND status_deleted:false"
  end

  def due_today_filter
    "due_by:>'#{Time.zone.now.beginning_of_day.utc.iso8601}' AND due_by:<'#{Time.zone.now.end_of_day.utc.iso8601}' AND status_stop_sla_timer:false AND status_deleted:false"
  end

  def all_tickets_filter
    "created_at:>'#{Time.zone.now.ago(1.month).beginning_of_day.utc.iso8601}' AND created_at:<'#{Time.zone.now.utc.iso8601}'"
  end

  def unresolved_filter
    statuses = Helpdesk::TicketStatus.unresolved_statuses(Account.current).join(" OR status:")
    "(status:" + statuses + ")"
  end

  def new_and_my_open_filter
    "(agent_id:null or agent_id:#{User.current.id})"
  end

  def default_filter_query_hash filter_name
    DYNAMIC_DEFAULT_FILTERS.include?(filter_name) ? send("#{filter_name}_filter") : 
        DEFAULT_FILTERS.fetch(filter_name).dclone
  end
  
  def self.deserialize_from_params(params)
    filter = Account.current.ticket_filters.new(params[:wf_model])
    filter.deserialize_from_params(params)
  end
 
  
  def deserialize_from_params(params)  
    @conditions = []
    @match                = :and
    @key                  = params[:wf_key]         || self.id.to_s
    self.model_class_name = params[:wf_model]       if params[:wf_model]
    @per_page             = params[:wf_per_page]    || default_per_page

    #if parameter page is not given(nil) or if its value is 0(string comparision), redirect to page 1 otherwise set it as it was given
    @page                 = (params[:page].nil? || (params[:page] == "0")) ? 1 : params[:page]

    @order_type           = TicketsFilter::SORT_ORDER_FIELDS.map{|x| x[0].to_s }.include?(params[:wf_order_type]) ? params[:wf_order_type] : default_order_type
    @order                = TicketsFilter.sort_fields_options.map{|x| x[1].to_s }.include?(params[:wf_order]) ? params[:wf_order] : default_order
    @without_pagination   = params[:without_pagination]         if params[:without_pagination]
    @filter_fields_to_select   = params[:select_fields]         if params[:select_fields]
    @html_format = params[:html_format] || false
    
    
    self.id   =  params[:wf_id].to_i            unless params[:wf_id].blank?
    self.name =  params[:filter_name].to_s.strip     unless params[:filter_name].blank?

    @fields = []
    unless params[:wf_export_fields].blank?
      params[:wf_export_fields].split(",").each do |fld|
        @fields << fld.to_sym
      end
    end

    if params[:wf_export_format].blank?
      @format = :html
    else  
      @format = params[:wf_export_format].to_sym
    end

    if join_tf_data? && !params[:data_hash].blank? 
      params[:data_hash] = ActiveSupport::JSON.decode params[:data_hash] if !params[:data_hash].kind_of?(Array)
      make_duplicate_params(params[:data_hash].dup)
      picklist_transformer = Helpdesk::Ticketfields::PicklistValueTransformer::StringToId.new
      benchmark_ticket_filter {
        picklist_transformer.modify_data_hash(params[:data_hash])
      }
    end

    action_hash = []
    if !params[:data_hash].blank? 
      action_hash = params[:data_hash]
      action_hash = ActiveSupport::JSON.decode params[:data_hash] if !params[:data_hash].kind_of?(Array)
    end

    #### Very bad condition need to change -- error prone
    if !params[:filter_name].eql?("spam") and !params[:filter_name].eql?("deleted")
      action_hash.push({ "condition" => "spam", "operator" => "is", "value" => false})
      action_hash.push({ "condition" => "deleted", "operator" => "is", "value" => false})
    end

    if params[:data_hash].blank?
      action_hash = default_filter(params[:filter_name], !!params[:export_fields], ['json', 'xml', 'nmobile'].include?(params[:format]))
      if Admin::AdvancedTicketing::FieldServiceManagement::Constant::FSM_TICKET_FILTERS.include? params[:filter_name]
        sort_options = TicketsFilter.field_agent_sort_options
        @order = sort_options[:order_by] unless params[:wf_order]
        @order_type = sort_options[:order_type] unless params[:wf_order_type]
      end
    end
    action_hash = remove_invalid_conditions(action_hash)
    self.query_hash = action_hash

    action_hash.each do |filter|
      add_condition(filter["condition"], filter["operator"].to_sym, filter["value"]) unless filter["value"].nil?
    end

    add_requester_conditions(params)
    add_tag_filter(params)

    add_article_feedback_conditions(params)
    
    if params[:wf_submitted] == 'true'
      validate!
    end
    if join_tf_data? && @original_data 
      process_query_hash
    end
    return self
  end

  def make_duplicate_params(array_list)
    benchmark_ticket_filter {
      @cloned_data = Marshal.load(Marshal.dump(array_list))
    }

    benchmark_ticket_filter {
      @original_data = @cloned_data.each_with_object({}) do |obj, res_hash|
        if obj['ff_name'] && obj['ff_name'] != 'default'
          res_hash[obj['ff_name']] = obj
        end
      end
    }
  end

  def benchmark_ticket_filter
    time_taken = Benchmark.realtime { yield }
    Rails.logger.info "Ticket Filter Time taken: #{time_taken} Account ID: #{Account.current.id}"
  end

  def process_query_hash
    self.query_hash.each do |q_hash|
      if @original_data[q_hash['ff_name']]
        q_hash['value'] = @original_data[q_hash['ff_name']]['value']
        q_hash['condition'] = @original_data[q_hash['ff_name']]['condition']
      end
    end
  end

  def add_requester_conditions(params)
    add_condition("requester_id", :is_in, params[:requester_id]) unless params[:requester_id].blank?
    add_condition("owner_id", :is_in, params[:company_id]) unless params[:company_id].blank?
  end

  def add_article_feedback_conditions(params)
    if params[:article_id].present? && article_feedback_filter?
      article_id = params[:language_id].present? ? Account.current.solution_articles.where(parent_id: params[:article_id], language_id: params[:language_id]).first.id : params[:article_id]
      add_condition('article_tickets.article_id', :is, article_id)
    end
    add_condition("article_tickets.article_id", :is_in, Solution::Article.portal_articles(params[:portal_id],params[:language_id]).pluck(:id).join(',')) if params[:portal_id].present? && params[:language_id].present? && self.name == 'article_feedback'
    add_condition("solution_articles.user_id", :is, User.current.id) if my_article_feedback_filter?
  end

  def add_tag_filter(params)
    add_condition("helpdesk_tags.id", :is_in, params[:tag_id]) unless params[:tag_id].blank?
  end

  def remove_invalid_conditions action_hash
    reject_conditions = []
    unless Account.current.shared_ownership_enabled?
      reject_conditions = TicketConstants::SHARED_AGENT_COLUMNS_ORDER + TicketConstants::SHARED_GROUP_COLUMNS_ORDER
    end
    
    reject_conditions << TicketConstants::DEFAULT_COLUMNS_OPTIONS[:nr_due_by] unless Account.current.next_response_sla_enabled?
    
    action_hash.reject!{|condition_hash| reject_conditions.include?(condition_hash["condition"])} if reject_conditions.present?
    action_hash
  end

  def ticket_select
    "helpdesk_tickets.id,helpdesk_tickets.subject,helpdesk_tickets.requester_id,helpdesk_tickets.responder_id,
     helpdesk_tickets.status,helpdesk_tickets.priority,helpdesk_tickets.due_by,helpdesk_tickets.display_id,
     helpdesk_tickets.frDueBy,helpdesk_tickets.source,helpdesk_tickets.group_id,helpdesk_tickets.isescalated,
     helpdesk_tickets.ticket_type,helpdesk_tickets.email_config_id,helpdesk_tickets.owner_id,
     helpdesk_tickets.association_type"
  end

  def sql_conditions
    @sql_conditions  ||= begin
      if errors? 
        all_sql_conditions = [" 1 = 2 "] 
      else
        all_sql_conditions = [""]
        conditions_array = conditions
        conditions_array = handle_any_mode(conditions_array) if Account.current.shared_ownership_enabled?
        conditions_array.each do |condition|
          handle_special_values(condition)
          sql_condition = condition.container.sql_condition
          unless sql_condition
            raise Wf::FilterException.new("Unsupported operator  for container #{condition.container.class.name}")
          end

          if all_sql_conditions[0].size > 0
            all_sql_conditions[0] << ( match.to_sym == :any ? "  OR" : " AND ")
          end

          all_sql_conditions[0] << sql_condition[0]
          sql_condition[1..-1].each do |c|
            all_sql_conditions << c
          end
        end
      end
      all_sql_conditions
    end
  end

  def serialize_to_params(merge_params = {})
    params = {}
    params[:wf_type]        = self.class.name
    params[:wf_match]       = match
    params[:wf_model]       = model_class_name
    params[:wf_order]       = order
    params[:wf_order_type]  = order_type
    params[:wf_per_page]    = per_page
    
    
    params[:data_hash] = self.query_hash
    params
  end

  def sort_by_response? 
    order.to_sym.eql?(:agent_responded_at) || order.to_sym.eql?(:requester_responded_at)
  end

  def sort_by_flexi_field?(order_by)
    TicketFilterConstants::SORTABLE_CUSTOM_FIELDS.key?(order_by)
  end

  def results
    db_type = (sort_by_response? || !Account.current.master_queries?) ? :run_on_slave : :run_on_master
    Sharding.safe_send(db_type) do
      @results ||= begin
        handle_empty_filter! 
        all_conditions = sql_conditions
        all_joins = get_joins(sql_conditions)
        all_joins[0].concat(states_join) if all_conditions[0].include?("helpdesk_ticket_states")
        model_klass = if Account.current.launched?(:force_index_tickets) and open_status_in_conditions?
                        model_class.use_index("index_helpdesk_tickets_status_and_account_id")
                      else
                        model_class
                      end

        if @without_pagination
          return model_klass.select(@filter_fields_to_select).joins(all_joins).where(all_conditions).order(order_clause).limit(per_page).offset((page - 1) * per_page).to_a
        end
        
        select_column = @html_format ? ticket_select : 'helpdesk_tickets.*'
        select_column = "DISTINCT(helpdesk_tickets.id) as 'unique_id' , #{select_column}" if all_conditions[0].include?('helpdesk_tags.name')

        recs = model_klass.select(select_column).joins(all_joins).where(all_conditions).order(order_clause)
               .preload([:ticket_states, :ticket_status, :responder, :requester, :schema_less_ticket])
               .paginate(page: page, per_page: per_page, total_entries: count_without_query)
        recs.wf_filter = self
        recs
      end
    end
  end

  def open_status_in_conditions?
    if Account.current.wf_comma_filter_fix_enabled?
      query_hash.any? { |q_h| q_h["condition"] == "status" && ((Array.wrap(q_h["value"]) & [0, '0', OPEN, OPEN.to_s]).any?) }
    else
      query_hash.any? { |q_h| q_h["condition"] == "status" && (q_h["value"].to_s.split(",").include?(OPEN.to_s) || q_h["value"].to_s.split(",").include?("0")) }
    end
  end

  def count_without_query
    # ActiveRecord::Base.connection.select_values('SELECT FOUND_ROWS() AS "TOTAL_ROWS"').pop
    per_page.to_f*page.to_f+1
  end

  def get_joins(all_conditions)
    all_joins = [""]
    if join_tf_data?
      all_joins = tf_data_join if all_conditions[0].include?('ticket_field_data') || sort_by_flexi_field?(order)
    elsif all_conditions[0].include?('flexifields') || sort_by_flexi_field?(order)
      all_joins = joins
    end
    all_joins[0].concat(monitor_ships_join) if all_conditions[0].include?("helpdesk_subscriptions.user_id")
    all_joins[0].concat(tags_join) if all_conditions[0].include?("helpdesk_tags.name")
    all_joins[0].concat(statues_join) if all_conditions[0].include?("helpdesk_ticket_statuses")
    all_joins[0].concat(schema_less_join) if join_schema_less?(all_conditions)
    all_joins[0].concat(article_tickets_join) if article_feedback_filter?
    all_joins[0].concat(articles_join) if my_article_feedback_filter?
    all_joins[0].concat(states_join) if sort_by_response?
    all_joins
  end

  def statues_join
    " INNER JOIN helpdesk_ticket_statuses ON 
          helpdesk_tickets.account_id = helpdesk_ticket_statuses.account_id AND 
          helpdesk_tickets.status = helpdesk_ticket_statuses.status_id "
  end

  def schema_less_join
    " INNER JOIN helpdesk_schema_less_tickets ON helpdesk_tickets.id = helpdesk_schema_less_tickets.ticket_id 
                                      AND helpdesk_tickets.account_id = helpdesk_schema_less_tickets.account_id "
  end

  def tags_join
    " INNER JOIN `helpdesk_tag_uses` ON (`helpdesk_tickets`.`id` = `helpdesk_tag_uses`.`taggable_id` 
                                        AND `helpdesk_tag_uses`.`taggable_type` = 'Helpdesk::Ticket') 
      INNER JOIN `helpdesk_tags` ON (`helpdesk_tags`.`id` = `helpdesk_tag_uses`.`tag_id`)  "
  end

  def monitor_ships_join
   " INNER JOIN helpdesk_subscriptions ON helpdesk_subscriptions.ticket_id = helpdesk_tickets.id "
  end

  def users_join
   " INNER JOIN users ON users.id = helpdesk_tickets.requester_id and users.account_id = helpdesk_tickets.account_id "
  end

  def states_join
    " INNER JOIN helpdesk_ticket_states on helpdesk_ticket_states.ticket_id = helpdesk_tickets.id 
    AND helpdesk_ticket_states.account_id = helpdesk_tickets.account_id "
  end

  def article_tickets_join
    " INNER JOIN `article_tickets` ON `article_tickets`.`ticketable_id` = `helpdesk_tickets`.`id` 
    AND `article_tickets`.`account_id` = `helpdesk_tickets`.`account_id` AND `article_tickets`.`ticketable_type` = 'Helpdesk::Ticket' "
  end

  def articles_join
    " #{article_tickets_join} INNER JOIN `solution_articles` ON `solution_articles`.`id` = `article_tickets`.`article_id` 
      AND `article_tickets`.`account_id` = `solution_articles`.`account_id` "
  end

  def joins
    ["INNER JOIN flexifields ON flexifields.flexifield_set_id = helpdesk_tickets.id and  flexifields.account_id = helpdesk_tickets.account_id "]
  end

  def tf_data_join
    ["INNER JOIN ticket_field_data ON ticket_field_data.flexifield_set_id = helpdesk_tickets.id and  ticket_field_data.account_id = helpdesk_tickets.account_id "]          
  end      

  def order_field
    "helpdesk_tickets.#{@order}"
  end

  def order_clause
    @order_clause ||= begin
      order_columns = order
      #order_columns = "id" if "created_at".eql?(order_columns) #Removing to check if the performace hit was because of 
                                                                # this causing mysql to use id index instead of account_id index
      order_parts = order_columns.split('.')
      
      if sort_by_response? 
        "helpdesk_ticket_states.#{order} #{order_type}, helpdesk_tickets.created_at asc"
      elsif sort_by_flexi_field?(order_columns)
        def_entry = Account.current.flexifields_with_ticket_fields_from_cache.find do |x|
          x.flexifield_alias == TicketFilterConstants::SORTABLE_CUSTOM_FIELDS[order_columns] + "_#{Account.current.id}"
        end
        flexi_col_name = def_entry.flexifield_name
        flexi_table_name = Helpdesk::Filters::CustomTicketFilter.custom_field_table_name
        "#{flexi_table_name}.#{flexi_col_name} #{order_type}"
      else
        if order_parts.size > 1
          "#{order_parts.first.camelcase.constantize.table_name}.#{order_parts.last} #{order_type}"
        else
          if ['priority','status'].include?(order_parts.first)
            "#{model_class_name.constantize.table_name}.#{order_parts.first} #{order_type}, helpdesk_tickets.created_at asc"
          else
            "#{model_class_name.constantize.table_name}.#{order_parts.first} #{order_type}"
          end
        end
      end
    end
  end

  def self.custom_field_table_name
    Account.current.ticket_field_limit_increase_enabled? ? TICKET_FIELD_DATA : FLEXIFIELDS
  end

  def save_deleted_filters_info
    @deleted_model_info = as_api_response(:central_publish)
  end

  private

    def current_filter_includes_custom_field?(filter_keys)
      filter_keys.find do |key|
        str_key = key.to_s
        str_key.include?('flexifields') || str_key.include?('ticket_field_data')
      end
    end

    def default_columns_defs(defs, filter_attribute_hash)
      TicketConstants::DEFAULT_COLUMNS_KEYS_BY_TOKEN.each do |name, cont|
        name = name.to_sym
        next unless filter_attribute_hash.key?(name)

        op_list = get_op_list(cont)
        defs[name] = {
          op_list.to_sym => cont,
          :name => name,
          :container => cont,
          :operator => op_list,
          :options => get_default_choices(name)
        }
      end
      defs
    end

    def shared_agent_group_columns_defs(defs, filter_attribute_hash, cols, key)
      cols.each do |name, cont|
        name = name.to_sym
        next unless filter_attribute_hash.key?(name)

        op_list = get_op_list(cont)
        defs[name] = {
          op_list.to_sym => cont,
          :name => name,
          :container => cont,
          :operator => op_list,
          :options => get_default_choices(key)
        }
      end
      defs
    end

    def fsm_columns_defs(defs)
      fsm_date_time_fields = TicketFilterConstants::FSM_DATE_TIME_FIELDS.collect { |x| x + "_#{Account.current.id}" }
      Account.current.custom_date_time_fields_from_cache.select { |x| fsm_date_time_fields.include?(x.name) }.each do |col|
        defs[get_id_from_field(col).to_sym] = {
          get_op_from_field(col).to_sym => get_container_from_field(col),
          name: col.label,
          container: get_container_from_field(col),
          operator: get_op_from_field(col),
          options: get_custom_choices(col)
        }
      end
      defs
    end

    def custom_dropdown_defs(defs, filter_attribute_hash)
      Account.current.custom_dropdown_fields_from_cache.each do |col|
        key = fetch_field_key(col).to_sym
        next unless filter_attribute_hash.key?(key)

        defs[key] = build_field_hash(col)
      end
      defs
    end

    def nested_fields_defs(defs, filter_attribute_hash)
      nested_fields = Account.current.nested_fields_from_cache
      ActiveRecord::Associations::Preloader.new(nested_fields, %i[level1_picklist_values nested_fields_with_flexifield_def_entries]).run
      nested_fields.each do |col|
        key = fetch_field_key(col).to_sym
        next unless filter_attribute_hash.key?(key)

        defs[key] = build_field_hash(col)
        col.nested_fields_with_flexifield_def_entries.each do |nested_col|
          defs[fetch_field_key(nested_col).to_sym] = { get_op_list('dropdown').to_sym => 'dropdown', :name => nested_col.label, :container => 'dropdown', :operator => get_op_list('dropdown'), :options => [] }
        end
      end
      defs
    end

    def misc_defs(defs, filter_attribute_hash)
      defs[:'helpdesk_subscriptions.user_id'] = { operator: :is_in, is_in: :dropdown, options: [], name: 'helpdesk_subscriptions.user_id', container: :dropdown } if filter_attribute_hash.key?(:'helpdesk_subscriptions.user_id')
      defs[:'article_tickets.article_id'] = { operator: :is_in, is_in: :dropdown, options: [], name: 'article_tickets.article_id', container: :dropdown } if article_feedback_filter?
      defs[:'solution_articles.user_id'] = { operator: :is, is: :numeric, options: [], name: 'solution_articles.user_id', container: :numeric } if my_article_feedback_filter?
      defs[:'helpdesk_tickets.display_id'] = { operator: :is_in, is_in: :dropdown, options: [], name: 'helpdesk_tickets.display_id', container: :dropdown } if filter_attribute_hash.key?(:'helpdesk_tickets.display_id')
      defs[:spam] = { operator: :is, is: :boolean, options: [], name: :spam, container: :boolean } if filter_attribute_hash.key?(:spam)
      defs[:deleted] = { operator: :is, is: :boolean, options: [], name: :deleted, container: :boolean } if filter_attribute_hash.key?(:deleted)
      defs[:"helpdesk_schema_less_tickets.#{Helpdesk::SchemaLessTicket.trashed_column}"] = { operator: :is, is: :boolean, options: [], name: :trashed, container: :boolean } if filter_attribute_hash.key?(:"helpdesk_schema_less_tickets.#{Helpdesk::SchemaLessTicket.trashed_column}")
      defs[:requester_id] = { operator: :is_in, is_in: :dropdown, options: [], name: :requester_id, container: :dropdown } if filter_attribute_hash.key?(:requester_id) # Added for email based custom view, which will be used in integrations.
      defs[:'helpdesk_tickets.id'] = { operator: :is_in, is_in: :dropdown, options: [], name: 'helpdesk_tickets.id', container: :dropdown } if filter_attribute_hash.key?(:'helpdesk_tickets.id')
      defs[:'helpdesk_ticket_states.resolved_at'] = { operator: :is_greater_than, is_in: :resolved_at, options: [], name: 'helpdesk_ticket_states.resolved_at', container: :resolved_at } if filter_attribute_hash.key?(:'helpdesk_ticket_states.resolved_at')
      defs
    end

  def join_schema_less? all_conditions
    SCHEMA_LESS_COLUMNS.any?{|col| all_conditions[0].include?(col)}
  end

  def handle_special_values(condition, user_types = USER_COLUMNS, group_types = GROUP_COLUMNS)
    key = condition.key.to_s
    type = case 
    when user_types.include?(key)
      :user
    when group_types.include?(key)
      :group
    when key.include?("status")
      :status
    end

    if type
      if Account.current.wf_comma_filter_fix_enabled?
        values = condition.container.values
      else
        values = condition.container.value.split(",")
      end
      if values.include?("0")
        values.delete("0")
        values << convert_special_values(type)
        if Account.current.wf_comma_filter_fix_enabled?
          condition.container.values = values.flatten
        end
      end
      unless Account.current.wf_comma_filter_fix_enabled?
        condition.container.values[0] = values.join(",")
      end
    end
  end

  def convert_special_values(type)
    case type
    when :user
      User.current.id.to_s
    when :group
      ids = User.current.agent_groups.pluck(:group_id)
      ids.blank? ? ["-2"] : ids
    when :status
      Helpdesk::TicketStatus::unresolved_statuses(Account.current)
    end
  end

  # For handling a special case where the conditions contains any_agent with unassigned and any_group with some values
  # Query will be something like below
  # (responder_id in val OR internal_agent in val OR 
  #   (group_id in val AND responder_id is NULL) OR (internal_group in val AND internal_agent is NULL ))
  # For generating such sql condition combining agents and groups, we need values of both agent and group.
  def handle_any_mode(conditions)
    agent_index = group_index = nil
    conditions.each_with_index do |condition, index|
      handle_special_values(condition, ["any_agent_id"], ["any_group_id"])
      if Account.current.wf_comma_filter_fix_enabled?
        values = condition.container.values
      else
        values = condition.container.value.split(",")
      end
      key = condition.key.to_s

      if key == "any_agent_id" and values.include?("-1")
        agent_index = index
      elsif key == "any_group_id" and values.present?
        if Account.current.wf_comma_filter_fix_enabled?
          condition.container.values = values if values.delete('-1')
        else
          condition.container.values[0] = values.join(",") if values.delete("-1")
        end
        group_index = index
      end
    end

    if agent_index and group_index
      val = {:agent => conditions[agent_index].container.values, :group => conditions[group_index].container.values}
      conditions[agent_index].container.values = val
    end
    conditions
  end

  def dynamic_filter?
    # Checking if the filter condition contains me or my groups
    if Account.current.wf_comma_filter_fix_enabled?
      accessible.only_me? || self.data[:data_hash].any? { |cond| DYNAMIC_FIELDS.include?(cond['condition']) && cond['value'] && (Array.wrap(cond['value']) & [0, '0']).any? }
    else
      accessible.only_me? || self.data[:data_hash].any? { |cond| DYNAMIC_FIELDS.include?(cond['condition']) && cond['value'] && cond['value'].to_s.split(',').include?('0') }
    end
  end

  def update_widgets
    dynamic_filter? ? deactivate_widgets : clear_dashboards_filters_cache
  end

  def clear_dashboards_filters_cache
    filter_dashboards = Account.current.dashboard_widgets.where('ticket_filter_id = ?', id).pluck(:dashboard_id)
    filter_dashboards.each { |dashboard_id| clear_ticket_filter_widgets_from_cache(dashboard_id) }
  end

  def deactivate_widgets
    Helpdesk::DeactivateFilterWidgets.perform_async({ filter_id: self.id })
  end

  def article_feedback_filter?
    ['article_feedback', 'unresolved_article_feedback'].include?(name)
  end

  def my_article_feedback_filter?
    name == 'my_article_feedback'
  end

  class << self
    include Cache::Memcache::Helpdesk::Filters::CustomTicketFilter
  end
end
