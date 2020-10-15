module DashboardTestHelper
  include ApiDashboardConstants
  include Community::ModerationCount
  include DashboardConcern
  include Dashboard::UtilMethods
  include Helpdesk::DashboardHelper

  def scorecard_pattern(parameter = {})
    set_dashboard_type
    scorecard_fields = ROLE_BASED_SCORECARD_FIELDS[@dashboard_type.to_sym]
    options = {}
    options[:trends] = scorecard_fields
    options[:filter_options] = {}
    options[:filter_options][:group_id] = parameter[:group_id] if parameter.key?(:group_id)
    options[:filter_options][:product_id] = parameter[:product_id] if parameter.key?(:product_id)
    options[:is_agent] = @dashboard_type.include?('agent')
    scorecard_hash = ::Dashboard::TrendCount.new(true, options).fetch_count
    @scorecard = {}
    scorecard_hash.each_with_index do |(key, value),index|
      @scorecard[key] = {
        id: index,
        name: key.to_s,
        value: value
      }
    end
    @scorecard.values
  end

  def scorecard_stub_data
    set_dashboard_type
    scorecard_fields = ROLE_BASED_SCORECARD_FIELDS[@dashboard_type.to_sym]
    stub_data = {}
    stub_data["results"] = {}
    scorecard_fields.each_with_index do |field, index|
      stub_data["results"][field.to_s] = {"total" => rand(1000), "results"=>[]}
    end
    SearchServiceResult.new({"records" => stub_data})
  end

  def scorecard_pattern_search_service(stub_data)
    result = []
    stub_data.records["results"].each_with_index do |record,index|
      result << {"id"=>index,"name"=>"#{record[0]}","value"=>record[1]["total"]}
    end
    result.as_json
  end

  def unreloved_tickets_stub_data(params)
    status_ids = params[:status_ids].present? ? params[:status_ids] : status_list_from_cache
    group_by_field = params[:group_by]
    first_ids = params[:"#{(group_by_field + "s")}"] || [-1,3,4,7,12]
    stub_data = {}
    stub_data["total"] =
    stub_data["results"] = []
    first_ids.each do |id|
      data = {"key"=>"#{group_by_field}", "value"=>"#{id}", "count"=>rand(1000), "groups" => []}
      status_ids.each do |i|
        data["groups"] << {"key"=>"status", "value"=>"#{i}", "count"=>rand(1000)}
      end
      stub_data["results"] << data
    end
    SearchServiceResult.new({"records" => stub_data})
  end
  def set_dashboard_type
    type = if User.current.privilege?(:admin_tasks)
              'admin'
            elsif User.current.privilege?(:view_reports)
              'supervisor'
            else
              'agent'
            end
    @dashboard_type = Account.first.sla_management_enabled? ? type : "sprout_17_"+type 
  end

  def survey_info_pattern(options = {})
    @widget_count = ::Dashboard::SurveyWidget.new.fetch_records(options)
    result_array = CSAT_FIELDS.dup
    @widget_count[:results].each do |key, val|
      result_array[key.downcase.to_sym][:value] = val
    end

    @widget_count[:results] = result_array.values
    @widget_count[:id] = 1
    @widget_count
  end

  def survey_multi_group_pattern(options = {})
    options[:time_range] = INVERTED_TIME_PERIODS['day']
    @widget_count = ::Dashboard::SurveyWidget.new.filtered_records(options)
    csat_response = CSAT_FIELDS.deep_dup
    @widget_count[:results].each do |key, val|
      csat_response[key.downcase.to_sym][:value] = val
    end
    @widget_count[:results] = csat_response.values
    @widget_count[:id] = 1
    @widget_count
  end

  def omni_channel_pattern
    {
      widgets: omnichannel_widget_config,
      id: '1'
    }
  end

  def moderation_count_pattern
    fetch_spam_counts
    @counts
  end

  def unresolved_tickets_pattern(params)
    load_unresolved_filter params
    @unresolved_hash = fetch_unresolved_tickets params
  end

  def ticket_trends_pattern
    ["today", "yesterday", "last_dump_time"]
  end

  def ticket_metrics_pattern
    ["received", "resolved", "first_response", "avg_response", "sla", "last_dump_time"]
  end
  
  def load_unresolved_filter(params)
    group_by_key = [params[:group_by].to_sym, :status]
    column_key_mapping = unresolved_column_key_mapping
    @group_by = column_key_mapping.values_at(*group_by_key) || column_key_mapping[:group_id]
    report_group_by = @group_by.first
    @report_type = 
        [column_key_mapping[:responder_id], column_key_mapping[:internal_agent_id]].include?(report_group_by) ?
        column_key_mapping[:responder_id] : column_key_mapping[:group_id]
    @filter_condition  = {}

    column_key_mapping.keys.each do |filter|
      next unless params[filter].present?
      filter_values = params[filter]
      if filter_values.include?("0")
        filter_values.delete("0")
        filter_values.concat(user_agent_groups.map(&:to_s))
        filter_values.uniq!
      end
      instance_var = case filter
          when :internal_agent_id
            :responder_id
          when :internal_group_id
            :group_id
          when :group_ids
            :group_id
          when :responder_ids
            :responder_id
          when :status_ids
            :status
          when :product_ids
            :product_id
          else
            filter
          end

      self.instance_variable_set("@#{instance_var}", filter_values)
      @filter_condition.merge!({column_key_mapping[filter] => filter_values}) if filter_values.present?
    end
  end

  def fetch_unresolved_tickets params
    es_enabled = true
    #Send only column names to ES for aggregation since column names are used as keys
    #need to work here based on es and db
    options = {:group_by => @group_by, :filter_condition => @filter_condition, :cache_data => false, :include_missing => true, :workload => @group_by.first.to_s}
    if params[:widget]
      options[:include_missing] = false if @group_id.present?
      options[:limit_option] = UNRESOLVED_TICKETS_WIDGET_ROW_LIMIT
    elsif instance_variable_get("@#{@group_by.first}").present? || User.current.assigned_ticket_permission
      options[:include_missing] = false
    end
    ticket_counts = ::Dashboard::DataLayer.new(es_enabled,options).aggregated_data
    build_response(ticket_counts, params, options[:include_missing])
  end

  def status_list_from_cache
    statuses = Helpdesk::TicketStatus.status_names_from_cache(Account.current).to_h
    statuses.delete_if {|st| [Helpdesk::Ticketfields::TicketStatus::RESOLVED, Helpdesk::Ticketfields::TicketStatus::CLOSED].include?(st)}
    filter_list(statuses, @status)
  end

  def filter_list(values, retain_values)
    return values if retain_values.blank?
    values.keep_if {|x| retain_values.map(&:to_i).include?(x)}
  end

  def build_response(ticket_counts, params, include_missing = false)
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
      stats_hash << { 'status_id' => 0, 'count' => total_count } unless params[:widget]
      res_array << { @group_by.first => -1, 'stats' => stats_hash }
    end
    group_by_values.keys.each do |group|
      total_count = 0
      status_counts = statuses_list.inject([]) do |obj,status|
        status_count = ticket_counts[[group, status]] || 0
        total_count += status_count
        obj << {"status_id" => status, "count" => ticket_counts[[group,status]] || 0}
      end
      status_counts << { 'status_id' => 0, 'count' => total_count } unless params[:widget]
      res_array << { @group_by.first => group, 'stats' => status_counts } unless total_count.zero? && !valid_row?(group)
    end
    if !params[:widget]
      return res_array
    elsif @group_id.present?
      status_counts = res_array[0]["stats"]
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

  def enable_gamification
    Account.current.add_feature(:gamification)
    yield
  ensure
    disable_gamification
  end

  def disable_gamification
    Account.current.revoke_feature(:gamification)
  end

  def quests_pattern(quests)
    quests.map { |quest| quest_pattern(quest) }
  end

  def quest_pattern(quest)
    {
      id: quest.id,
      name: quest.name,
      description: quest.description,
      points: quest.points,
      badge_id: quest.badge_id,
      category: quest.category,
      sub_category: quest.sub_category,
      created_at: quest.created_at.try(:utc),
      updated_at: quest.updated_at.try(:utc)
    }
  end
end
