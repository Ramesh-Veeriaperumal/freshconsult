module HelpdeskReports::Helper::ThresholdApiHelper

  include Cache::Memcache::Reports::ReportsCache

  THRESHOLD_DAYS_LIMIT_KEY = "THRESHOLD_DAYS_LIMIT_KEY"
  THRESHOLD_DANGER_PC_KEY = "THRESHOLD_DANGER_PC_KEY"
  THRESHOLD_WARNING_PC_KEY = "THRESHOLD_WARNING_PC_KEY"
  THRESHOLD_REQUEST_BATCH_SIZE_KEY = "THRESHOLD_REQUEST_BATCH_SIZE_KEY"
  CACHE_TIMEOUT_24_HRS = 84600

  METRIC_TYPES = {
    count:"count",
    avg:"avg",
    percentage:"percentage"
  }

  DEFAULT_CONFIG = {}

  DEFAULT_CONFIG[THRESHOLD_DAYS_LIMIT_KEY] = 7
  DEFAULT_CONFIG[THRESHOLD_DANGER_PC_KEY] = {"count": 20, "avg":20, "percentage":5}
  DEFAULT_CONFIG[THRESHOLD_WARNING_PC_KEY] = {"count": 10, "avg":10, "percentage":2.5}
  DEFAULT_CONFIG[THRESHOLD_REQUEST_BATCH_SIZE_KEY] = 2

  COUNT_METRICS = ['RECEIVED_TICKETS','RESOLVED_TICKETS','REOPENED_TICKETS','UNRESOLVED_TICKETS','TICKETS_VIEW_THRESHOLD']

  PERCENTAGE_METRICS = ['RESPONSE_SLA','RESOLUTION_SLA']

  INCREASE_BAD_METRICS = ['AVG_FIRST_ASSIGN_TIME','AVG_RESOLUTION_TIME','AVG_FIRST_RESPONSE_TIME', 'AVG_RESPONSE_TIME','REOPENED_TICKETS','UNRESOLVED_TICKETS','RECEIVED_TICKETS','TICKETS_VIEW_THRESHOLD' ]

  def transform_threshold_request

    if(params["filter_id"])
      if(is_number? params["filter_id"])
        filter_obj = Account.current.ticket_filters.find(params["filter_id"])
        params.delete("filter_id")
        if(filter_obj.has_permission?(User.current))
          filter_res = []
          filter_hash =  filter_obj.data[:data_hash]
          default_fields = []
          custom_fields = []
          filter_hash.each do | item |
            # //filter_res.push({key:item["condition"], value: item["value"]})
            if(item["ff_name"])
              if(item["ff_name"]=='default')
                default_fields.push(item)
              else
                custom_fields.push(item)
              end
            end
          end
          params["filter"] = transform_filters(default_fields,custom_fields)
        end
      else
        default_fields  = Account.current.ticket_filters.any? ? Account.current.ticket_filters.first.default_filter(params["filter_id"]) : []
        params["filter"] = default_fields.any? ? transform_filters(default_fields) : []
      end
    end
    @root_params = params.clone
    params[:_json] = [HelpdeskReports::ParamConstructor::ThresholdApiParams.new(params).build_params]
  end





  def get_threshold
    busy_hr_request
  end

  def busy_hr_request
    @query_params = params[:_json]
    recieved_tkts = build_and_execute
    calculate_threshold_request(recieved_tkts)
  end

  def calculate_threshold_request(recieved_tkts)
    bHr = get_busiest_hour(recieved_tkts)
    request_arr = HelpdeskReports::ParamConstructor::ThresholdApiParams.new(@root_params,{busy_hr:bHr , days_limit:get_days_limit }).build_params
    result_arr = []
    request_arr.each_slice(get_request_bacth_size) do |req|
      @query_params = req
      result_arr << make_request.values
    end
    final_result = define_threshold(result_arr.flatten ,request_arr)
    final_result[:busy_hr] = bHr
    final_result
  end

  private

  def get_busiest_hour(recieved_tkts)
    hourly_arr = recieved_tkts.first["result"]

    if hourly_arr.any?
      hourly_arr.sort! { |a, b| b["count"].to_i <=> a["count"].to_i }
      hourly_arr[0]["h"]
    else
      0
    end

  end

  def define_threshold(day_wise_result , request_arr)
    metric = request_arr[0][:metric]
    is_increase = INCREASE_BAD_METRICS.include? (metric)
    metric_type = COUNT_METRICS.include?(metric)? METRIC_TYPES[:count] : PERCENTAGE_METRICS.include?(metric)? METRIC_TYPES[:percentage] : METRIC_TYPES[:avg]
    day_wise_ticket_count = 0
    day_wise_result.each do | day|
      begin
        day_wise_ticket_count += day[:general][:metric_result]
      rescue
        Rails.logger.info(" Data Missing for #{day.to_s}")
      end
    end
    avg = day_wise_ticket_count / day_wise_result.length
    {
      metric: metric,
      metric_type:metric_type,
      avg:avg.round,
      level2: is_increase ?  (avg *  (1+(0.01*get_danger_pc(metric_type)))).round :  (avg *  (1-(0.01*get_danger_pc(metric_type)))).round ,
      level1: is_increase ? (avg * (1+(0.01*get_warning_pc(metric_type)))).round : (avg * (1-(0.01*get_warning_pc(metric_type)))).round
    }
  end

  def make_request
    build_and_execute
    parse_result
    @processed_result
    # @no_data ? (@data = nil) : format_result
    # @results
  end


  def cache_feature_config
    config = HelpdeskReportsConfig.find(1).get_config;
    MemcacheKeys.cache(THRESHOLD_DAYS_LIMIT_KEY, config[:days_limit], CACHE_TIMEOUT_24_HRS)
    MemcacheKeys.cache(THRESHOLD_WARNING_PC_KEY, config[:warning_pc], CACHE_TIMEOUT_24_HRS)
    MemcacheKeys.cache(THRESHOLD_DANGER_PC_KEY, config[:danger_pc], CACHE_TIMEOUT_24_HRS)
    MemcacheKeys.cache(THRESHOLD_REQUEST_BATCH_SIZE_KEY, config[:request_bacth_size], CACHE_TIMEOUT_24_HRS)
  end

  def get_days_limit
    cache_feature_config unless MemcacheKeys.get_from_cache(THRESHOLD_DAYS_LIMIT_KEY)
    (MemcacheKeys.get_from_cache(THRESHOLD_DAYS_LIMIT_KEY) || DEFAULT_CONFIG[THRESHOLD_DAYS_LIMIT_KEY]).to_i
  end

  def get_warning_pc(type)
    cache_feature_config unless  MemcacheKeys.get_from_cache(THRESHOLD_WARNING_PC_KEY)
    (MemcacheKeys.get_from_cache(THRESHOLD_WARNING_PC_KEY)|| DEFAULT_CONFIG[THRESHOLD_WARNING_PC_KEY])[type.to_sym].to_i
  end

  def get_danger_pc(type)
    cache_feature_config unless  MemcacheKeys.get_from_cache(THRESHOLD_DANGER_PC_KEY)
    (MemcacheKeys.get_from_cache(THRESHOLD_DANGER_PC_KEY) || DEFAULT_CONFIG[THRESHOLD_DANGER_PC_KEY])[type.to_sym].to_i
  end

  def get_request_bacth_size
    cache_feature_config unless  MemcacheKeys.get_from_cache(THRESHOLD_REQUEST_BATCH_SIZE_KEY)
    (MemcacheKeys.get_from_cache(THRESHOLD_REQUEST_BATCH_SIZE_KEY)|| DEFAULT_CONFIG[THRESHOLD_REQUEST_BATCH_SIZE_KEY]).to_i
  end


  private
  #   owner_id = company_id
  #   responder_id = agent_id
  #
  #   tag transformation
  #   product key transformation
  #   ticket_type transformation
  #   group_id = 0 means all groups
  #
  #   ignore - due_by , status , created_date
  #
  #   direct conversions - source, priority, association_type, requester_id
  #

  def transform_default_filters (default_fields)
    final_filters = []
    default_fields.each do |item|
      condition  = item["condition"]
      values = item["value"].to_s
      case condition
      when "responder_id"
        csv_split = values.split(",")
        csv_split[csv_split.index("0")] = User.current.id  if csv_split.include?"0"
        csv_split.delete_at(csv_split.index("-1")) if csv_split.include?"-1"
        final_filters.push({key: "agent_id",  value: csv_split.join(',')})
      when "status"
        csv_split = values.split(",")
        if csv_split.include?"0"
          csv_split.delete("0")
          csv_split = [*csv_split ,*Helpdesk::TicketStatus::unresolved_statuses(Account.current).map(&:to_s)].uniq
        end
        final_filters.push({key: "status",  value: csv_split.join(',')})
      when "group_id"
        csv_split = values.split(",")
        csv_split.delete_at(csv_split.index("0")) if csv_split.include?"0"
        final_filters.push({key: "group_id",  value: csv_split.join(',')}) if csv_split.any?
      when "owner_id"
        final_filters.push({key: "company_id",  value: values})
      when "ticket_type"
        csv_split = values.split(",")
        ids_arr = Account.current.ticket_type_values.where(value:csv_split).map{|item| item[:id]}
        final_filters.push({key: "ticket_type", value: ids_arr.join(",")}) if ids_arr.any?
      when "helpdesk_tags.name"
        csv_split = values.split(",")
        ids_arr = Account.current.tags.where(name:csv_split).map{|item| item[:id]}
        final_filters.push({key: "tag_id",  value: ids_arr.join(",")}) if ids_arr.any?
      when "helpdesk_schema_less_tickets.product_id"
        final_filters.push({key: "product_id",  value: values})
      when "source", "priority", "association_type", "requester_id"
        final_filters.push({key: condition,  value: values})
      end
    end
    final_filters
  end

  def transform_custom_filters (custom_fields)
    final_filters = []
    custom_fields.each do |item|
      col_name = item["condition"].split(".")[1]
      values = item["value"].to_s
      if col_name.start_with?("ffs")
        csv_split = values.split(",")
        ticket_field = Account.current.ticket_fields.find_by_name(item["ff_name"])
        if(ticket_field)
          ids_arr = ticket_field.picklist_values.where(value:csv_split).map{|item| item[:id]}
          final_filters.push({key: col_name,  value: ids_arr.join(',')}) if ids_arr.any?
        end
      elsif col_name.start_with?("ff_int") || col_name.start_with?("ff_date") || col_name.start_with?("ff_boolean") || col_name.start_with?("ff_decimal")
        final_filters.push({key: col_name,  value: values})
      end
    end
    final_filters
  end

  def transform_filters(default_fields,custom_fields=nil)
    final_filters = []
    final_filters.push(transform_default_filters(default_fields))
    final_filters.push(transform_custom_filters(custom_fields)) unless custom_fields.nil?
    final_filters.flatten
  end


  def is_number? string
    true if Float(string) rescue false
  end

end
