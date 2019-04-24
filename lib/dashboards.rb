class Dashboards

  include Dashboard::UtilMethods
  include Helpdesk::Ticketfields::TicketStatus
  TICKET_SCOPE = [
    [:assigned,     "assigned",     0],
    [:permissible,  "permissible",  1]
  ]

  TICKET_SCOPE_OPTIONS = TICKET_SCOPE.map { |i| [i[1], i[2]] }
  TICKET_SCOPE_NAMES_BY_KEY = Hash[*TICKET_SCOPE.map { |i| [i[2], i[1]] }.flatten]
  TICKET_SCOPE_KEYS_BY_TOKEN = Hash[*TICKET_SCOPE.map { |i| [i[0], i[2]] }.flatten]
  TICKET_SCOPE_KEYS_BY_NAME = Hash[*TICKET_SCOPE.map { |i| [i[1], i[2]] }.flatten]
  TICKET_SCOPE_TOKEN_BY_KEY = Hash[*TICKET_SCOPE.map { |i| [i[2], i[0]] }.flatten]
  
  STANDARD_DASHBOARD = [
     #key, widget name(partial name), h,w, group by, order by, limit, 
    [:activities,   "activity",                             2,6],
    [:todo,         "todo",                                 1,1],
    [:freshfone,    "phone",                                1,1],
    [:chat,         "chat",                                 1,1],
    [:agent_status, "agent_status",                         1,1],
    [:gamification, "gamification",                         1,1],
    [:moderation,   "forum_moderation",                     1,1]
  ]

  AGENT_DASHBOARD = [
    #key, widget name, h,w, group by, order by, limit, 
    [:activities,   "activity",                             4,2],
    [:tickets,      "due",                                  2,1],
    [:todo,         "todo",                                 2,1],
    [:tickets,      "unresolved_tickets_by_priority",       2,1],
    [:tickets,      "unresolved_tickets_by_status",         2,1],
    [:tickets,      "unresolved_tickets_by_ticket_type",    2,1],
    [:tickets,      "agent_received_resolved",              2,1],
    [:tickets,      "unresolved_tickets_by_age",            2,1],
    [:gamification, "gamification",                         2,1],
    [:csat,         "csat",                                 2,1],
    [:moderation,   "forum_moderation",                     2,1],
    [:freshfone,    "phone",                                2,1],
    [:chat,         "chat",                                 2,1]
  ]

  SUPERVISOR_DASHBOARD = [
    #key, widget name, h,w, group by, order by, limit, 
    [:tickets,        "unresolved_tickets_by_priority",     2,1],
    [:tickets,        "unresolved_tickets_by_status",       2,1],
    [:agent_status,   "agent_status",                       2,1],
    [:tickets,        "unresolved_tickets_by_ticket_type",  2,1],
    [:tickets,        "agent_performance",                  2,1],
    [:freshfone,      "phone",                              2,1],
    [:activities,     "activity",                           4,2],
    [:chat,           "chat",                               2,1],
    [:todo,           "todo",                               2,1],
    [:tickets,        "top_agents_by_open_tickets",         2,1],
    [:moderation,     "forum_moderation",                   2,1]
  ]

 ADMIN_DASHBOARD = [
    #key, widget name, h,w, group by, order by, limit, 
    [:tickets,      "tickets_workload",                     2,1],
    [:tickets,      "unresolved_tickets_by_priority",       2,1],
    [:tickets,      "unresolved_tickets_by_status",         2,1],
    [:tickets,      "unresolved_tickets_by_ticket_type",    2,1],
    [:tickets,      "group_performance",                    2,1],
    [:agent_status, "agent_status",                         2,1],
    [:tickets,      "top_customers_by_open_tickets",        2,1],
    [:todo,         "todo",                                 2,1],
    [:freshfone,    "phone",                                2,1],
    [:activities,   "activity",                             4,2],
    [:chat,         "chat",                                 2,1],
    [:moderation,   "forum_moderation",                     2,1]
  ]

  REDSHIFT_TIME_FORMAT = "%-d %b, %Y"

  GROUP_BY_VALUES_MAPPING = {
    "responder_id"      => "agent_list_from_cache",
    "group_id"          => "group_list_from_cache",
    "ticket_type"       => "ticket_type_list_from_cache",
    "priority"          => "priority_list_from_cache",
    "status"            => "status_list_from_cache",
    "internal_group_id" => "group_list_from_cache",
    "internal_agent_id" => "agent_list_from_cache"
  }

  DEFAULT_ORDER_LIMIT = 50

  def ticket_scope
    User.current.privilege?(:view_reports) ? TICKET_SCOPE_KEYS_BY_TOKEN[:permissible] : TICKET_SCOPE_KEYS_BY_TOKEN[:assigned]
  end

  def form_es_query_hash
    action_hash = []
    action_hash.push({ "condition" => "responder_id", "operator" => "is_in", "value" => User.current.id}) if assigned_permission? and User.current 
    action_hash.push(Helpdesk::Filters::CustomTicketFilter.spam_condition(false))
    action_hash.push(Helpdesk::Filters::CustomTicketFilter.deleted_condition(false))
    negative_conditions = [{ 'condition' => 'status', 'operator' => 'is_not', 'value' => "#{RESOLVED},#{CLOSED}" }]
    [action_hash,negative_conditions]
  end

  def default_scoper
    account = Account.current
    default_filters = if account.launched?(:force_index_tickets)
                        account.tickets.visible.use_index("index_helpdesk_tickets_status_and_account_id").permissible(User.current).unresolved
                      else
                        account.tickets.visible.permissible(User.current).unresolved
                      end
    assigned_permission? ? default_filters.where(responder_id:User.current.id) : default_filters
  end

  def assigned_permission?
    TICKET_SCOPE_NAMES_BY_KEY[ticket_scope] == "assigned"
  end

  def scoped_permission?
    TICKET_SCOPE_NAMES_BY_KEY[ticket_scope] == "permissible"
  end
  
  def status_list_from_cache
    @statuses_list ||= Helpdesk::TicketStatus.status_names_from_cache(Account.current).to_h
    @statuses_list.delete_if {|st| [Helpdesk::Ticketfields::TicketStatus::RESOLVED, Helpdesk::Ticketfields::TicketStatus::CLOSED].include?(st)}
  end

  def group_list_from_cache
    @groups_list ||= Account.current.groups_from_cache.collect { |g| [g.id, g.name]}.to_h
  end

  def agent_list_from_cache
    @agents_list ||=Account.current.agents_details_from_cache.collect { |au| [au.id, au.name] }.to_h
  end

  def priority_list_from_cache
    TicketConstants.priority_list
  end

  def ticket_type_list_from_cache
    @ticket_type_list ||= Account.current.ticket_types_from_cache.collect { |g| [g.value, g.value]}.to_h
  end

  def user_agent_groups
    @user_agent_groups ||= begin
      agent_groups = User.current.agent_groups.pluck(:group_id)
      agent_groups.empty? ? [-2] : agent_groups        
    end   
  end

  #Parsing logic starts for single and double group by as the data response is different for them
  def parse_es_response(es_response)
    doc_hits = es_response["name"]["buckets"]
    response_hash = doc_hits.inject({}) do |res_hash,data|
      res_hash.merge!({data["key"] => data["doc_count"]})
    end
    if es_response.key?("missing_field")
      response_hash.merge!({nil => es_response["missing_field"]["doc_count"]})
    end
    response_hash
  end

  def parse_es_response_v2(es_response)
    es_res_hash = {}
    es_response.each do |data|
      tmp_h = {}
      data["name"]["buckets"].each do |bkt|
        tmp_h[[data["key"],bkt["key"]]] = bkt["doc_count"]
        es_res_hash.merge!(tmp_h)
      end
    end
    es_res_hash
  end
  #Parsing logic ends for single and double group by as the data response is different for them

  def redshift_custom_date_format time
    time.is_a?(Array) ? redshift_date_range_format(time) : redshift_date_format(time)
  end

  def redshift_group_filter group_id
    {  "condition" => "group_id", 
        "operator"  => "is_in",
        "value"     => "#{group_id}"}
  end

  def redshift_user_filter
    { "condition" => "agent_id", 
      "operator"  => "is_in",
      "value"     => User.current.id}
  end

  def redshift_product_filter product_id
    {   "condition" => "product_id", 
        "operator"  => "is_in",
        "value"     => "#{product_id}"}
  end

  def redshift_ticket_type_filter(ticket_type)
    { 'condition' => 'ticket_type',
      'operator'  => 'is_in',
      'value'     => ticket_type.to_s }
  end

  def handle_redshift_filters options={}
    filter_params = []
    filter_params = (filter_params << redshift_user_filter) if (options[:include_user].present? || User.current.assigned_ticket_permission)
    return filter_params if (User.current.can_view_all_tickets? && @req_params[:group_id].blank? && @req_params[:product_id].blank?)
    if @req_params[:group_id].present?
      filter_params = (filter_params << redshift_group_filter(@req_params[:group_id]) )
    end
    if @req_params[:product_id].present?
      filter_params = (filter_params << redshift_product_filter(@req_params[:product_id]) )
    end
    filter_params
  end

  def redshift_date_format time
    time.strftime(REDSHIFT_TIME_FORMAT)
  end

  def redshift_date_range_format time
    start_date, end_date = redshift_date_format(time[0]), redshift_date_format(time[1])
    "#{start_date} - #{end_date}"
  end

  def redshift_error_response
    {errors: I18n.t("helpdesk.realtime_dashboard.something_went_wrong")}
  end

  def is_redshift_error? response
    response[0].present? && (response[0][:errors].present? || response[0]["errors"].present?)
  end

  def group_id_param
    return @req_params["group_id"] if @req_params["group_id"].present?
    @req_params["group_id"] = user_agent_groups.join(",") if User.current.group_ticket_permission
  end

end