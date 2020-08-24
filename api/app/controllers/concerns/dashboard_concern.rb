module DashboardConcern
  extend ActiveSupport::Concern
  include ApiDashboardConstants
  include SolutionConcern

  def feature_name
    case action_name
    when 'survey_info'
      feature_key = :surveys unless current_account.any_survey_feature_enabled_and_active?
    when 'moderation_count'
      feature_key = :forums
    end
    feature_key
  end

  def sanitize_params
    sanitize_parameters_type
  end

  def sanitize_parameters_type
    %i(product_id group_id responder_id status internal_group_id internal_agent_id).each do |key|
      params[key] = params[key].is_a?(Array) ? params[key].collect(&:to_i) : params[key].to_i if params[key].present?
    end
    params[:group_by] = params[:group_by].to_s if params[:group_by].present?
  end

  def load_unresolved_filter
    group_by_key = [params[:group_by].to_sym, :status]
    column_key_mapping = unresolved_column_key_mapping
    @group_by = column_key_mapping.values_at(*group_by_key) || column_key_mapping[:group_id]
    report_group_by = @group_by.first
    @report_type =  if [column_key_mapping[:responder_id], column_key_mapping[:internal_agent_id]].include?(report_group_by)
                      column_key_mapping[:responder_id]
                    else
                      column_key_mapping[:group_id]
                    end
    load_filter_conditions
  end

  def unresolved_column_key_mapping
    UNRESOLVED_COLUMN_KEY_MAPPING.clone
  end

  def load_filter_conditions
    @filter_condition = {}

    column_key_mapping = unresolved_column_key_mapping
    column_key_mapping.keys.each do |filter|
      next if params[filter].blank?
      filter_values = params[filter]
      if filter_values.include?(0)
        filter_values.delete(0)
        filter_values.concat(user_agent_groups.map(&:to_s))
        filter_values.uniq!
      end
      instance_var = get_filter_type(filter)
      instance_variable_set("@#{instance_var}", filter_values)
      @filter_condition.merge!(column_key_mapping[filter] => filter_values) if filter_values.present?
    end
  end

  def get_filter_type(filter)
    filter_type = case filter
                  when :internal_agent_id
                    :responder_id
                  when :internal_group_id
                    :group_id
                  else
                    filter
                  end
    filter_type
  end

  def fetch_unresolved_tickets
    # Send only column names to ES for aggregation since column names are used as keys
    # need to work here based on es and db
    options = { group_by: @group_by, filter_condition: @filter_condition, cache_data: false, include_missing: true, workload: @group_by.first.to_s }
    if params[:widget]
      options[:include_missing] = false if @group_id.present?
      options[:limit_option] = UNRESOLVED_TICKETS_WIDGET_ROW_LIMIT
    elsif instance_variable_get("@#{@group_by.first}").present? || User.current.assigned_ticket_permission
      options[:include_missing] = false
    end
    if Account.current.launched?(:count_service_es_reads)
      options[:filter_condition].merge!({spam: [false], deleted: [false]})
      ticket_counts = Dashboard::SearchServiceTrendCount.new(options).fetch_count
      ticket_counts = parse_results(ticket_counts)
    else
      ticket_counts = ::Dashboard::DataLayer.new(current_account.features?(:countv2_reads), options).aggregated_data
    end
    build_response(ticket_counts, options[:include_missing], params[:widget])
  end

  def build_response(ticket_counts, include_missing = false, is_widget = false)
    statuses_list = status_list_from_cache.keys
    build_group_by_list
    res_array = []
    if include_missing
      total_count = 0
      stats_hash = statuses_list.inject([]) do |obj, status|
        status_count = ticket_counts[[nil, status]] || 0
        total_count += status_count
        obj << { 'status_id' => status, 'count' => status_count }
      end
      stats_hash << { 'status_id' => 0, 'count' => total_count } unless is_widget
      res_array << { @group_by.first => -1, 'stats' => stats_hash }
    end
    group_by_values.keys.each do |group|
      total_count = 0
      status_counts = statuses_list.inject([]) do |obj, status|
        status_count = ticket_counts[[group, status]] || 0
        total_count += status_count
        obj << { 'status_id' => status, 'count' => status_count }
      end
      status_counts << { 'status_id' => 0, 'count' => total_count } unless params[:widget]
      res_array << { @group_by.first => group, 'stats' => status_counts } unless total_count.zero? && !valid_row?(group)
    end
    if !params[:widget]
      return res_array
    elsif @group_id.present?
      return [] if res_array.empty?
      status_counts = res_array[0]['stats']
      res_array[0]['stats'] = status_counts.sort_by { |k, v|
          k['count']
        }.reverse[0..(UNRESOLVED_TICKETS_WIDGET_ROW_LIMIT - 1)].reject { |k,v|
          k['count'] == 0
        }
    else
      return res_array.sort_by { |k, v|
          k['stats'][0]['count']
        }.reverse[0..(UNRESOLVED_TICKETS_WIDGET_ROW_LIMIT - 1)].reject { |k,v|
          k['stats'][0]['count'] == 0
        }
    end
  end

  def set_dashboard_type
    type = if current_user.privilege?(:admin_tasks)
             'admin'
           elsif current_user.privilege?(:view_reports)
             'supervisor'
           else
             'agent'
           end
    @dashboard_type = current_account.sla_management_enabled? ? type : 'sprout_17_' + type
  end

  def omnichannel_widget_config
    widgets_details = []
    widgets = OMNI_CHANNEL_DASHBOARD.dup
    widget_object = ::Dashboard::Grid.new(6)
    widgets_with_coordinates = widget_object.process_omni_widgets(widgets)
    widgets_with_coordinates.each_with_index do |widget, index|
      widgets_details.push(widget.instance_values.symbolize_keys.merge(id: index))
    end
    widgets_details
  end

  def widget_config
    widgets = widget_list dashboard_type
    widgets_details = []
    widgets.each_with_index do |widget, index|
      if is_sol_dashboard?
        widgets_details.push(widget.instance_values.symbolize_keys.merge(id: "solutions-default-#{widget.name}"))
      else
        widgets_details.push(widget.instance_values.symbolize_keys.merge(id: index))
      end
    end
    widgets_details
  end

  def widget_list(dashboard_type)
    widgets = is_sol_dashboard? ? solution_widgets(dashboard_type) : default_widgets(dashboard_type)
    set_widget_privileges
    widgets.select! { |widget| widget_privileges[widget.first.to_sym] }
    widget_object = ::Dashboard::Grid.new
    widgets_with_coordinates = widget_object.process_widgets(widgets, dashboard_type)
    widgets_with_coordinates
  end

  def default_widgets(dashboard_type)
    if current_account.subscription.sprout_plan?
      items = SPROUT_DASHBOARD.dup
      items << [:unresolved_tickets, 'unresolved-tickets', 2, 2] if current_user.privilege?(:admin_tasks) || current_user.privilege?(:view_reports)
      items
    elsif dashboard_type.include?('admin')
      ADMIN_DASHBOARD.dup
    elsif dashboard_type.include?('supervisor')
      SUPERVISOR_DASHBOARD.dup
    else
      AGENT_DASHBOARD.dup
    end
  end

  def solution_widgets(dashboard_type)
    DASHBOARD_WIGETS_FOR_SOLUTIONS.dup
  end

  def set_widget_privileges
    if is_sol_dashboard?
      @widget_privileges = check_solutions_related_widgets
    else
      non_sprout_plan = current_account.subscription.non_sprout_plan?
      @widget_privileges = {
        tickets: true,
        activities: !non_sprout_plan,
        todo: true,
        trend_count: non_sprout_plan,
        unresolved_tickets: current_account.unresolved_tickets_widget_for_sprout_enabled? || non_sprout_plan
      }
      widgets_with_feature = check_widgets_with_feature(non_sprout_plan)
      chat_related_widgets = check_chat_related_widgets(non_sprout_plan)
      @widget_privileges.merge!(widgets_with_feature)
      @widget_privileges.merge!(chat_related_widgets)
    end
    @widget_privileges
  end

  def check_widgets_with_feature(non_sprout_plan)
    {
      csat: current_account.any_survey_feature_enabled_and_active?,
      gamification: gamification_feature?(current_account),
      moderation: non_sprout_plan && current_account.features?(:forums) && privilege?(:delete_topic)
    }
  end

  def check_chat_related_widgets(non_sprout_plan)
    # Marking chat as false because the widget is not ready. When it is ready, it can be uncommented and deployed
    chat_feature = current_account.chat_activated? && current_account.chat_setting.active
    {
      chat: false, # non_sprout_plan && chat_feature
      agent_status: non_sprout_plan && (round_robin?)
    }
  end

  def check_solutions_related_widgets
    {
      all_categories: true,
      all_folders: true,
      all_articles: true,
      all_feedback: true,
      all_drafts: true,
      in_review: current_account.article_approval_workflow_enabled?,
      approved: current_account.article_approval_workflow_enabled?,
      published: true,
      outdated: secondary_language?,
      article_performance: true,
      approval_pending_articles: current_account.article_approval_workflow_enabled? && current_user.privilege?(:approve_article),
      recent_drafts: true,
      articles_by_language: current_account.multilingual?
    }
  end

  def round_robin?
    (current_user.privilege?(:admin_tasks) || current_user.privilege?(:manage_availability)) && current_account.features?(:round_robin) && current_user.accessible_groups.round_robin_groups.any?
  end

  def set_root_key
    response.api_root_key = ROOT_KEY[action_name.to_sym]
  end

  def validate_dashboard_delegator
    assign_and_sanitize_params
    delegator_params = build_delegator_params
    validate_delegator(nil, delegator_params)
  end

  def assign_and_sanitize_params
    ParamsHelper.assign_and_clean_params(PARAMS_FIELD_NAME_MAPPINGS.dup, params)
    sanitize_params
  end

  def build_delegator_params
    options = { dashboard_type: dashboard_type }
    DELEGATOR_PARAM_KEYS_FOR_ACTIONS[params[:action].to_sym].each do |param|
      options[param] = params[param]
    end
    options
  end

  def constants_class
    :ApiDashboardConstants.to_s.freeze
  end

  def set_custom_errors(item = @item)
    ErrorHelper.rename_error_fields(ERROR_FIELD_NAME_MAPPINGS.dup, item)
  end

  private

  def parse_results(counts)
    results = {}
    counts["results"].each do |result|
      value = result["value"].to_i == -1 ? nil : result["value"].to_i
      result["groups"].each do |group|
        results[[value, group["value"].to_i]] = group["count"]
      end
    end
    results
  end

  def parse_scorecard_hash(response, trends)
    result = {}
    trends.each do |trend|
      result[trend.to_s] = response.present? && response['results'].present? && response['results'][trend.to_s].present? ? response['results'][trend.to_s]['total'] : 0
    end
    result
  end

  def is_sol_dashboard?
    params["id"].to_i === ApiDashboardConstants::DASHBOARD_FOR[:solutions]
  end
end
