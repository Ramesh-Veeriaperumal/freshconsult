class HelpdeskReports::Formatter::Ticket::AgentSummary
  
  include HelpdeskReports::Util::Ticket
  
  attr_accessor :result

  def initialize data
    @result = data
  end
  
  def perform
    id_metric_hash = agent_ids_and_metrics
    @summary = build_summary id_metric_hash
    populate_result_in_summary
    @summary.sort_by{|a| a[:agent_name]}
  end
  
  def agent_ids_and_metrics
    ids, metrics = [], []
    result.each do |metric, res|
      res.symbolize_keys!
      metrics << metric.downcase
      agents = res[:agent_id] || res[:actor_id] || res[:previous_object_id]
      ids << agents.keys.collect{|id| id ? id.to_i : nil} if agents
    end
    { ids: ids.flatten.uniq.compact, metrics: metrics}
  end
  
  def build_summary id_metric_hash
    ids = id_metric_hash[:ids]
    agent_hash = agent_id_name_hash ids
    metrics = id_metric_hash[:metrics]
    metric_hash = build_metric_hash metrics
    ids &= agent_hash.keys # Not showing result for deleted agents
    (ids || []).inject([]) do |summary, id|
      summary << metric_hash.merge(agent_id: id, agent_name: agent_hash[id])
      summary
    end
  end
  
  def agent_id_name_hash ids
    Account.current.users.where(helpdesk_agent: true).
                          find_all_by_id(ids, :select => "id, name").
                          collect{ |a| [a.id, a.name]}.to_h
  end
  
  def build_metric_hash metrics
    (metrics || []).inject({}) do |hash, metric|
      hash[metric] = nil
      hash
    end
  end
  
  def populate_result_in_summary
    @summary.each do |agent|
      id = agent[:agent_id]
      agent.keys.each do |metric|
        next if metric == :agent_id || metric == :agent_name
        met = metric.upcase
        tmp = result[met][:agent_id] || result[met][:actor_id] || result[met][:previous_object_id]
        # If particular QUERY failed(query error, system error, timedout) for a metric, its result is shown as NOT_APPLICABLE
        if result[met][:error]
          agent[metric] = NOT_APPICABLE
        elsif tmp and tmp[id.to_s]
          agent[metric] = tmp[id.to_s]
        else
          agent[metric] = default_value(met)
        end
      end
    end
  end

  def default_value metric
    METRIC_TO_QUERY_TYPE[metric.to_sym] == "Count" ? 0 : NOT_APPICABLE
  end

end