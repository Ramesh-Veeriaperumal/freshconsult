class Dashboard::UnresolvedTicketWorkload < Dashboard
include Helpdesk::Ticketfields::TicketStatus
include Cache::Memcache::Dashboard::CacheData

  attr_accessor :es_enabled, :filter_condition, :group_by, :workload_name, :options
  
  #this class handles double group by for unresolved tickets from group, agent, status, type, priority (any 2 of these 5)
  def initialize(es_enabled, options = {})
    @es_enabled = es_enabled
    @options = options
    @filter_condition = options[:filter_condition].presence || {}
    @group_by = options[:group_by].presence || []
    @workload_name = options[:workload] || "responder_id"
  end

  def fetch_aggregation
    options.merge!({:cache_data => true, :include_missing => false}) #Will not cache from unresolved dashboard and dont need unassigned tickets here.
    filtered_response = Dashboard::DataLayer.new(es_enabled,options).fetch_aggregation
    top_hits = fetch_top_hits(filtered_response)
    process_response(filtered_response, top_hits.compact)
  end

  def process_response(resp, top_hits)
    group_by_values_1 = fetch_primary_group_by_values(group_by.first.to_s)
    group_by_values_2 = send(GROUP_BY_VALUES_MAPPING[group_by.last.to_s])

    group_by_names = []
    formatted_response = top_hits.inject({}) do |res_hash, id|
      group_by_names << group_by_values_1[id]
      res_hash.merge!({group_by_values_1[id] => group_drilled_down_list(id,resp,group_by_values_2)})
    end
    {:data => formatted_response, :order => group_by_names, :series => group_by_values_2.values, :time_since => time_since(resp)}
  end

  def group_drilled_down_list(id,resp,list)
    list.inject([]) do |resp_arr, lst|
      resp_arr << {:value => resp[[id,lst.first]].to_i, :name => lst.last }
    end
  end

  private

  def fetch_top_hits(resp)
    filtered_response = resp.reject{|k| k == :time_since}
    group_by_values_1 = fetch_primary_group_by_values(group_by.first.to_s)
    top_hits = group_by_values_1.inject({}) do |res_hash,list|
      res_hash.merge!({list.first => filtered_response.select{|y| y.first == list.first}.values.sum})
    end
    top_hits = top_hits.sort_by {|key, value| value}.reverse.to_h.keys
    top_hits[0..DEFAULT_ORDER_LIMIT]
  end

  def time_since(response)
    response[:time_since].present? ? Time.zone.at(response[:time_since]) : Time.zone.now
  end

  def fetch_primary_group_by_values(grp_by)
    @primary_group_by_value ||= if workload_name == "group_id"
      group_primary_values
    else
      agent_primary_values
    end
  end

  def agents_for_group(group_ids)
    agents = send(GROUP_BY_VALUES_MAPPING[group_by.first.to_s])
    agent_ids = Account.current.agent_groups.where(:group_id => group_ids).pluck(:user_id).uniq
    agent_ids.inject({}) do |agent_hash, agent_id|
      agent_hash.merge!({agent_id => agents[agent_id]})
    end
  end

  def group_primary_values
    if User.current.restricted?
      group_ids = Account.current.groups.select("id,name").where(id: user_agent_groups)
      group_ids.inject({}) do |group_hash, group|
        group_hash.merge!(group.id => group.name)
      end
    else
      send(GROUP_BY_VALUES_MAPPING[group_by.first.to_s])
    end
  end

  def agent_primary_values
    if User.current.assigned_ticket_permission
      {User.current.id => User.current.name}
    elsif User.current.group_ticket_permission
      group_ids = filter_condition[:group_id].presence || user_agent_groups
      agents_for_group(group_ids)
    else
      filter_condition[:group_id].present? ? agents_for_group(filter_condition[:group_id]) : send(GROUP_BY_VALUES_MAPPING[group_by.first.to_s])
    end
  end

end