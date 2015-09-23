class HelpdeskReports::Formatter::Ticket::GroupSummary
  
  include HelpdeskReports::Util::Ticket
  
  attr_accessor :result

  def initialize data, args = {}
    @result = data
    @args = args
  end
  
  def perform
    id_metric_hash = group_ids_and_metrics
    @summary = build_summary id_metric_hash
    populate_result_in_summary
    @summary.sort_by{|g| g[:group_name]}
  end
  
  def group_ids_and_metrics
    ids, metrics = [], []
    result.each do |metric, res|
      res.symbolize_keys!
      metrics << metric.downcase
      groups = res[:group_id] || res[:previous_object_id]
      ids << groups.keys.collect{|id| id ? id.to_i : nil} if groups
    end
    ids = ids.flatten.uniq.compact
    if @args[:user_ids].present?
      scoped_ids = scope_groups_with_agent_filter
      ids &= scoped_ids
    end
    { ids: ids, metrics: metrics}
  end
  
  def scope_groups_with_agent_filter
    users = Account.current.users.where(helpdesk_agent: true).find_all_by_id(@args[:user_ids], :include => :agent_groups)
    users.inject([]) do |group_ids, usr|
      group_ids |= usr.agent_groups.collect{|ag| ag.group_id}
      group_ids
    end
  end
  
  def build_summary id_metric_hash
    ids = id_metric_hash[:ids]
    group_hash = group_id_name_hash ids
    metrics = id_metric_hash[:metrics]
    metric_hash = build_metric_hash metrics
    ids &= group_hash.keys # Not showing result for deleted groups
    (ids || []).inject([]) do |summary, id|
      summary << metric_hash.merge(group_id: id, group_name: group_hash[id])
      summary
    end
  end
  
  def group_id_name_hash ids
    Account.current.groups.find_all_by_id(ids, :select => "id, name").collect{ |g| [g.id, g.name]}.to_h
  end
  
  def build_metric_hash metrics
    (metrics || []).inject({}) do |hash, metric|
      hash[metric] = nil
      hash
    end
  end
  
  def populate_result_in_summary
    @summary.each do |group|
      id = group[:group_id]
      group.keys.each do |metric|
        next if metric == :group_id || metric == :group_name
        met = metric.upcase
        tmp = result[met][:group_id] || result[met][:previous_object_id]   
        # If particular QUERY failed(query error, system error, timedout) for a metric, its result is shown as NOT_APPLICABLE
        if result[met][:error]
          group[metric] = NOT_APPICABLE
        elsif tmp and tmp[id.to_s]
          group[metric] = tmp[id.to_s]
        else
          group[metric] = default_value(met)
        end
      end
    end
  end

  def default_value metric
    METRIC_TO_QUERY_TYPE[metric.to_sym] == "Count" ? 0 : NOT_APPICABLE
  end

end