class HelpdeskReports::Formatter::Ticket::AgentSummary

  include HelpdeskReports::Util::Ticket

  attr_accessor :result

  METRICS = ["AGENT_REASSIGNED_TICKETS", "AVG_FIRST_RESPONSE_TIME", "AVG_RESOLUTION_TIME",
             "AVG_RESPONSE_TIME", "FCR_TICKETS", "PRIVATE_NOTES", "REOPENED_TICKETS",
             "RESOLUTION_SLA", "RESOLVED_TICKETS", "RESPONSE_SLA", "RESPONSES"]

  def initialize data, args = {}
    @result = data
    @args = args
    @current = @result['AGENT_SUMMARY_CURRENT']
    @historic = @result['AGENT_SUMMARY_HISTORIC']
  end

  def perform
    merging_current_historic_data
    removing_unscoped_and_deleted_agent
    populate_result_in_summary
  end

  def merging_current_historic_data
    @current  = [] if (@current.is_a?(Hash) && @current["error"])   || @current.empty? #Handling the edge cases
    @historic = [] if (@historic.is_a?(Hash) && @historic["error"]) || @historic.empty?
    @result = (@current + @historic).group_by{|h| h["agent_id"]}.map{ |k,v| v.reduce(:merge)}
  end

  def removing_unscoped_and_deleted_agent
    @ids = []
    #Fetching result's agent ids
    @result.each { |row| @ids << row["agent_id"].to_i }

    @ids = @ids.flatten.uniq.compact
    scope_agents_with_agent_and_group_filter

    @agent_hash = agent_id_name_hash @ids
    @ids &= @agent_hash.keys # Not showing result for deleted agents
  end

  def scope_agents_with_agent_and_group_filter
    if @args[:agent_ids].present?
      @ids &= @args[:agent_ids]
    end
    if @args[:group_ids].present?
      scoped_ids = list_of_group_agents
      @ids &= scoped_ids
    end
  end

  def list_of_group_agents
    acc_groups = Account.current.groups_from_cache.select{|g| (@args[:group_ids] || []).include? g.id}
    acc_groups.inject([]) do |agents, group|
      agents |= group.agents.collect{|a| a.id}
    end
  end

  def agent_id_name_hash ids
    Account.current.users.where(helpdesk_agent: true).find_all_by_id(ids, :select => "id, name").collect{ |a| [a.id, a.name]}.to_h
  end

  def populate_result_in_summary
    @summary = @result.select do |row|
      id = row["agent_id"].to_i
      if @ids.include?(id)
        row.merge!("agent_name"=>@agent_hash[id])
        METRICS.each do |key|
          value = row[key.downcase]
          if value
            row[key] = value.to_i
          else
            row[key] = default_value(key)
          end
          row.delete(key.downcase)
        end
      end
    end
    @summary.sort_by{|a| a["agent_name"]}
  end

  def default_value metric
    METRIC_TO_QUERY_TYPE[metric.to_sym] == "Count" ? 0 : NA_PLACEHOLDER_SUMMARY
  end

end
