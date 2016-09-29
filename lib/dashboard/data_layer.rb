class Dashboard::DataLayer < Dashboard
  include MemcacheKeys
  include Cache::Memcache::Dashboard::CacheData

  attr_accessor :es_enabled, :filter_condition, :group_by, :workload_name, :cache_available, :include_missing

  def initialize(es_enabled, options = {})
    @es_enabled = es_enabled
    @filter_condition = options[:filter_condition].presence || {}
    @group_by = options[:group_by].presence || []
    @workload_name = options[:workload].to_s
    @cache_available = options[:cache_data] || false
    @include_missing = options[:include_missing] || false
  end

  def fetch_aggregation
    group_workload? ? admin_widget_from_cache : supervisor_widget_from_cache
  end

  def aggregated_data
    es_enabled ? aggregation_from_es : aggregation_from_db
  rescue Exception => e
    Rails.logger.info "Exception in Fetching workload tickets for Dashboard widget -, #{workload_name}, #{e.backtrace}"
    #Already raised to newrelic before. Just returning {} so that UI displays "no data to display"
    {}
  end

  private

   def aggregation_from_es
    action_hash,negative_conditions = form_es_query_hash
    filter_condition.each do |key, value|
      filter_val = value.is_a?(Array) ? value.join(",") : value
      action_hash.push({ "condition" => key.to_s, "operator" => "is_in", "value" => filter_val}) if filter_condition[key].present?
    end

    es_response = Search::Dashboard::Docs.new(action_hash,negative_conditions,group_by.dup, limit_options).aggregation(Helpdesk::Ticket)["name"]["buckets"]
    es_res_hash = parse_es_response_v2(es_response)
    if include_missing
      #Logic for constructing missing fields starts here...
      action_hash.push({"condition" => group_by.first,"operator" => "is_in", "value" => "-1" })
      missing_es_response = Search::Dashboard::Docs.new(action_hash,negative_conditions,["status"],{:first_limit => last_group_by_limit}).aggregation(Helpdesk::Ticket)["name"]["buckets"]
      missing_es_res_hash = missing_es_response.inject({}) do |res_hash, response|
        res_hash.merge([nil,response["key"]] => response["doc_count"])
      end
      
      es_res_hash.merge!(missing_es_res_hash)
    end
    es_res_hash
  end



  def aggregation_from_db
    if include_missing
      #this is for unresolved dashboard. We dont need to do an order by from this page. 
      default_scoper.where(filter_condition).group(group_by).count
    else
      #Need to order by count as we are showing by descending order in UI. ES returns data by count desc always by default
      default_scoper.where(filter_condition).where("#{workload_name} is not NULL").group(group_by).order("count(*) desc").count
    end
  end

  def limit_options
    if include_missing
      {:first_limit => first_group_by_limit, :second_limit => last_group_by_limit}
    else
      {:first_limit => DEFAULT_ORDER_LIMIT, :second_limit => DEFAULT_ORDER_LIMIT}
    end
  end

  def group_workload?
    workload_name == "group_id"
  end

  def agent_workload?
    workload_name == "responder_id"
  end

  def first_group_by_limit
    send(GROUP_BY_VALUES_MAPPING[group_by.first.to_s]).count
  end

  def last_group_by_limit
    send(GROUP_BY_VALUES_MAPPING[group_by.last.to_s]).count
  end

  def group_filter_present?
    !filter_condition[:group_id].blank?
  end

  def can_cache_data?
    cache_available
  end


  ###ES CACHING METHODS#####
  def admin_widget_from_cache
    return aggregated_data if !can_cache_data? || User.current.assigned_ticket_permission
    from_cache = workload_from_cache(workload_name, "PERMISSION:#{Agent::PERMISSION_KEYS_BY_TOKEN[:all_tickets]}", group_by.last.to_s) 
    return from_cache if User.current.can_view_all_tickets?
    group_access_list = user_agent_groups.inject({}) do |list, group_id|
      list.merge!(from_cache.select {|k| k.is_a?(Array) and (k.first.to_i == group_id)})
    end
    group_access_list.merge!({:time_since => from_cache[:time_since]})
  end

  def supervisor_widget_from_cache
    return aggregated_data unless can_cache_data?
    cache_identifier = if filter_condition[:group_id].present?
      "GROUP:#{filter_condition[:group_id].to_i}"
    else
      User.current.restricted? ? "USER:#{User.current.id}" : "PERMISSION:#{Agent::PERMISSION_KEYS_BY_TOKEN[:all_tickets]}"
    end

    groupwise_cached_data(workload_name, cache_identifier, group_by.last.to_s)
  end

  ###ES CACHING METHODS#####  

end