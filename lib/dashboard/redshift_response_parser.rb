class Dashboard::RedshiftResponseParser
  include Dashboard::UtilMethods

  SECONDS_IN_A_DAY = 86400

  def initialize raw_data, options = {}
    @raw_data   = raw_data
    @group_id   = options[:group_id]
    @dump_time  = (options[:dump_time] || 4.hours.ago)
    convert_values_to_integer
  end

  def agent_unresolved
    process_agent_unresolved
  end

  def customer_unresolved
    process_customer_unresolved
  end

  def agent_summary
    process_agent_summary
  end

  def agents_summary
    process_supervisor_agents_summary
  end

  def groups_summary
    process_admin_groups_summary
  end

  def admin_channel_workload
    process_admin_channel_workload
  end

  def transform_glance_data
    process_glance_raw_data
  end

  def admin_group_received_resolved
    data_hash = process_admin_group_received_resolved
    data_values = data_hash.deep_symbolize_keys.values
    name = data_values.map{|x| x[:name]}
    received = data_values.map{|x| x[:received_count]}
    resolved = data_values.map{|x| x[:resolved_count]}
    {   "categories"  => name,
        "ids"         => data_hash.keys,
        "series" => ["received", "resolved"],
        "values" => [
                  { "name" => "received", "data"  => received},
                  { "name" => "resolved", "data"  => resolved}
        ],
        "last_dump_time" => @dump_time
    }

  end

  def supervisor_agent_received_resolved
    data_hash = process_supervisor_agent_received_resolved
    data_values = data_hash.deep_symbolize_keys.values

    name = data_values.map{|x| x[:name]}
    received = data_values.map{|x| x[:received_count]}
    resolved = data_values.map{|x| x[:resolved_count]}
    {   "categories" => name,
        "ids"         => data_hash.keys,
        "series" => ["received", "resolved"],
        "values" => [
                  { "name" => "received", "data"  => received},
                  { "name" => "resolved", "data"  => resolved}
        ],
        "last_dump_time" => @dump_time
    }
  end

  def agent_received_resolved
    day_names = Date::ABBR_DAYNAMES.rotate
    dom = (Time.now.beginning_of_month.to_date..Time.now.end_of_month.to_date).map{ |date| date.strftime("%d") }
    wrc, wrs, mrc, mrs = process_agent_received_resolved_metric
    {
      "week" => 
      {
        "categories"  => [day_names],
        "series"      => ["received", "resolved"],
        "values"      => [{
                            "name"  => "received",
                            "data"  => wrc
                          },{
                            "name"  => "resolved",
                            "data"  => wrs
                            }]
      },
      "month" => {
        "categories"  => [dom],
        "series"      => ["received", "resolved"],
        "values"      => [{
                            "name"  => "received",
                            "data"  => mrc
                          },{
                            "name"  => "resolved",
                            "data"  => mrs
                          }]
      },
      "last_dump_time" => @dump_time
    }
  end

  def admin_tickets_workload
    process_admin_tickets_workload
  end

  private 

  def process_agent_unresolved
    user_ids = @raw_data.map{|x| x["agent_id"]}
    users_hash = user_id_name_mapping(user_ids, true)
    @raw_data.each do |row|
      if users_hash[row["agent_id"]].present?
        user_name = users_hash[row["agent_id"]]
        row[:name] = user_name 
      end
    end
    {
      "agents"          => @raw_data,
      "last_dump_time"  => @dump_time
    }
  end

  def process_customer_unresolved
    @raw_data = @raw_data.select{|x| x["count"] > 2 }
    user_ids = @raw_data.map{|x| x["requester_id"]}
    users_hash = user_id_name_mapping(user_ids)
    company_name_hash = user_id_company_name_mapping(user_ids)
    @raw_data.each do |row|
      if users_hash[row["requester_id"]].present?
        user_name = users_hash[row["requester_id"]]
        row[:name] = user_name
        row[:company_name] = company_name_hash[row["requester_id"]] if company_name_hash[row["requester_id"]].present?
      end
    end
    {
      "customers"       => @raw_data,
      "last_dump_time"  => @dump_time   
    }  
  end

  def process_admin_channel_workload
    padding_by_source = source_by_hours_padding
    @raw_data.each do |row|
      next if (padding_by_source[row["source"]].blank? || padding_by_source[row["source"]][row["h"]].blank?)
      padding_by_source[row["source"]][row["h"]].merge!(row)
    end
    {   :source_workload => padding_by_source,
        :source_id_name_mappings => ticket_source_names_by_key
    }.merge(dump_time_hash)
  end

  def process_admin_tickets_workload
    padded_hours = hours_received_resolved_padding
    @raw_data.each do |row|
      next if padded_hours[row["h"]].blank?
      padded_hours[row["h"]].merge!(row)
    end
    padded_hours.merge(dump_time_hash)
  end

  def process_supervisor_agents_summary
    padded_agents_list = padding_for_agents(false)
    @raw_data.each do |row|
      if row["agent_id"].blank?
        padded_agents_list[0].merge!(row) if row.key?("agent_id")
      elsif padded_agents_list[row["agent_id"].to_i].present?
        padded_agents_list[row["agent_id"].to_i].merge!(row)
        padded_agents_list[row["agent_id"].to_i]["avg_resolution_time"] = convert_seconds_to_day(padded_agents_list[row["agent_id"].to_i]["avg_resolution_time"]) 
      end
    end
    padded_agents_list.merge(dump_time_hash)
  end

  def process_admin_groups_summary
    padded_groups_list = padding_for_groups(false)
    @raw_data.each do |row|
      if row["group_id"].blank?
        padded_groups_list[0].merge!(row) if row.key?("group_id")
      elsif padded_groups_list[row["group_id"].to_i].present?
        padded_groups_list[row["group_id"].to_i].merge!(row)
        padded_groups_list[row["group_id"].to_i]["avg_resolution_time"] = convert_seconds_to_day(padded_groups_list[row["group_id"].to_i]["avg_resolution_time"]) 
      end
    end
    padded_groups_list.merge(dump_time_hash)
  end

  def process_admin_group_received_resolved
    padded_groups_list = padding_for_groups
    @raw_data.each do |row|
      if row["group_id"].blank?
        padded_groups_list[0].merge!(row) if row.key?("group_id")
      elsif padded_groups_list[row["group_id"].to_i].present?
        padded_groups_list[row["group_id"].to_i].merge!(row)
      end
    end
    sort_by_received_resolved padded_groups_list
  end

  def process_supervisor_agent_received_resolved
    padded_agents_list = padding_for_agents
    @raw_data.each do |row|
      if row["agent_id"].blank?
        padded_agents_list[0].merge!(row) if row.key?("agent_id")
      elsif padded_agents_list[row["agent_id"].to_i].present?
        padded_agents_list[row["agent_id"].to_i].merge!(row)
      end
    end
    sort_by_received_resolved padded_agents_list
  end


  def process_agent_summary
    week_padding   = agent_summary_padding_week
    month_padding  = agent_summary_padding_month
    @raw_data.each do |row|
      next if row["doy"].blank?
      day_of_month  = label_for_x_axis(row["doy"], "day_of_month")
      day_of_week   = label_for_x_axis(row["doy"], "dow")
      week_padding[day_of_week]   = row if is_current_week?(row["doy"])
      month_padding[day_of_month] = row
    end
    {
      "week"            => week_padding,
      "month"           => month_padding,
      "last_dump_time"  => @dump_time
    }
  end

  def process_agent_received_resolved_metric
    month_received_data = {}
    month_resolved_data = {}
    week_received_data = {}
    week_resolved_data = {}
    
    
    @raw_data.each do |row|
      next if row["doy"].blank?
      day_of_month = label_for_x_axis(row["doy"], "day_of_month")
      day_of_week = label_for_x_axis(row["doy"], "dow")
      month_received_data[day_of_month] = row["received_count"]
      month_resolved_data[day_of_month] = row["resolved_count"]

      week_received_data[day_of_week] = row["received_count"] if is_current_week?(row["doy"])
      week_resolved_data[day_of_week] = row["resolved_count"] if is_current_week?(row["doy"])
    end

    month_padding = create_padding("day_of_month")
    week_padding = create_padding("dow")

    week_received_data = week_padding.merge(week_received_data)
    week_resolved_data = week_padding.merge(week_resolved_data)

    month_received_data = month_padding.merge(month_received_data)
    month_resolved_data = month_padding.merge(month_resolved_data)

    month_received_data_array = month_received_data.values
    month_resolved_data_array = month_resolved_data.values

    week_received_data_array = week_received_data.values
    week_resolved_data_array = week_resolved_data.values

    [week_received_data_array, week_resolved_data_array, month_received_data_array, month_resolved_data_array]
  end

  def label_for_x_axis point, trend
    case trend
      when "doy"
        date = point.is_a?(Date) ? point : Date.parse(point)
        "#{date.strftime('%d %b, %Y')}"
      when "dow"
        date = point.is_a?(Date) ? point : Date.parse(point)
        "#{date.strftime('%a')}"
      when "day_of_month"
        date = point.is_a?(Date) ? point : Date.parse(point)
        date.strftime('%d').to_i
      end
  end

  def create_padding trend
    padding_hash = {}
    case trend
      when "day_of_month"
        (Time.now.beginning_of_month.to_date..Time.now.end_of_month.to_date).each do |i| 
            i = label_for_x_axis(i, "day_of_month")
            padding_hash[i] = 0
        end
      when "dow"
        (Time.now.beginning_of_week.to_date..Time.now.end_of_week.to_date).to_a.each do |i|
          i = label_for_x_axis(i, "dow")
          padding_hash[i] = 0
        end
      end
    padding_hash
  end

  def is_current_week? date
    date = date.is_a?(Date) ? date : Date.parse(date)
    (Time.now.beginning_of_week.to_date..Time.now.end_of_week.to_date).cover?(date)
  end

  def padding_for_agents for_received_resolved = true
    agents = agents_list(true)
    agents[0] = "Unassigned"
    padding_hash = {}
    agents.each do |agentid, agent_name|
      padding_hash[agentid] = {
        "name"                => agent_name,
        "resolved_count"      => 0,
        "avg_resolution_time" => nil,
        "resolution_sla"      => nil,
        "fcr_tickets"         => nil
      }
      padding_hash[agentid]["received_count"] = 0 if for_received_resolved
    end
    padding_hash
  end

  def padding_for_groups for_received_resolved = true
    padding_hash = {}
    groups = groups_list
    groups[0] = "Unassigned"
    groups.each do |group_id, group_name|
      padding_hash[group_id] = {
        "name"                => group_name,
        "resolved_count"      => 0,
        "resolved_tickets"    => 0,
        "avg_resolution_time" => nil,
        "resolution_sla"      => nil,
        "fcr_tickets"         => nil
      }
      padding_hash[group_id]["received_count"] = 0 if for_received_resolved
    end
    padding_hash
  end

  def agent_summary_padding_month
    dom = (Time.now.beginning_of_month.to_date..Time.now.end_of_month.to_date).map{ |date| date.strftime("%d") }
    padding = dom.inject({}) do | hash, day|
      hash[day] = default_glance_hash
      hash
    end
    padding
  end

  def agent_summary_padding_week
    day_names = Date::ABBR_DAYNAMES.rotate
    padding = day_names.inject({}) do | hash, day|
      hash[day] = default_glance_hash
      hash
    end
    padding
  end

  def hours_received_resolved_padding
    max_hour = Time.zone.parse(@dump_time.to_s).strftime("%k").to_i
    hours = (0..max_hour).to_a
    padding = hours.inject({}) do | hash, hour|
      hash[hour] = default_received_resolved_hash
      hash
    end
    padding
  end

  def default_received_resolved_hash
    {
      "received_count"              =>   0,
      "resolved_count"              =>   0,
    }
  end

  def default_glance_hash
    {
      "received_tickets"              =>   0,
      "resolved_tickets"              =>   0,
      "avg_resolution_time"           =>   nil,
      "resolution_sla_tickets_count"  =>   0,
      "resolution_sla"                =>   nil,
      "fcr_tickets_tickets_count"     =>   0,
      "fcr_tickets"                   =>   nil
    }
  end

  def source_by_hours_padding
    padded_hash = {}
    ticket_source_ids.each do |source_id|
      padded_hash[source_id] = hours_received_resolved_padding
    end
    padded_hash
  end

  def convert_seconds_to_day sec      
    (sec.to_f/SECONDS_IN_A_DAY).round(2) if sec.present?
  end

  def convert_values_to_integer
    processed_raw_data = @raw_data.inject([]) do |processed_array, raw_data|
      processed_array << process_raw_data_to_integer(raw_data)
      processed_array
    end
    @raw_data = processed_raw_data
  end

  def process_raw_data_to_integer raw_data
    raw_data.merge(raw_data) { |k, v| Integer(v) rescue v }
  end

  def ticket_source_names_by_key
    names_by_keys = TicketConstants::SOURCE_NAMES_BY_KEY.keys.inject({}) do |hash, key|
      hash[key] = I18n.t(TicketConstants::SOURCE_NAMES_BY_KEY[key])
      hash
    end
    names_by_keys
  end

  def user_id_name_mapping ids, agent = false
    users = Account.current.all_users.where(id: ids, helpdesk_agent: agent).select("id, name")
    users_hash = users.inject({}) do |hash, user|
      hash[user.id] = user.name
      hash
    end
    users_hash
  end

  def user_id_company_name_mapping ids = []
    users = Account.current.all_users.where(id: ids).select("id, customer_id")
    return {} if users.blank?
    company_ids = users.map(&:customer_id)
    return {} if company_ids.compact.blank?
    companies = Account.current.companies.where(id: company_ids.compact)
    company_id_name_hash = companies.inject({}) do |hash, company|
      hash[company.id] = company.name
      hash
    end
    users_hash = users.inject({}) do |hash, user|
      hash[user.id] = company_id_name_hash[user.customer_id] if (user.customer_id.present? && company_id_name_hash[user.customer_id].present?)
      hash
    end
    users_hash
  end

  def process_glance_raw_data
    @raw_data.each do |row|
      row["avg_resolution_time"] = nil if row["avg_resolution_time"].blank?
      row["resolution_sla"] = nil if row["resolution_sla"].blank?
      row["fcr_tickets"] = nil if row["fcr_tickets"].blank?
      if row["resolved_tickets"].present? && row["resolved_tickets"] > 0
        row["resolution_sla"]       = ( (row["resolution_sla_count"].to_f/row["resolved_tickets"]) * 100).round  if row["resolution_sla_count"].present?
        row["avg_resolution_time"]  = convert_seconds_to_day (row["resolution_time_sum"].to_f/row["resolved_tickets"])  if row["resolution_time_sum"].present?
      end
      row["fcr_tickets"] = ((row["fcr_count"].to_f/row["fcr_total_tickets_count"]) * 100).round if (row["fcr_count"].present?) && (row["fcr_total_tickets_count"].present? && row["fcr_total_tickets_count"] > 0)
    end
  end

  def dump_time_hash
    {
      last_dump_time: @dump_time
    }
  end

  def sort_by_received_resolved result_list
    result_list.sort_by{|key, value| value["received_count"].to_i }.reverse.to_h
  end

end