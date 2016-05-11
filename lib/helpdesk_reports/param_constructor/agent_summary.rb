class HelpdeskReports::ParamConstructor::AgentSummary < HelpdeskReports::ParamConstructor::Base

  AGENT_SUMMARY_METRICS = ["AGENT_SUMMARY_CURRENT", "AGENT_SUMMARY_HISTORIC"]

  def initialize options
    @report_type = :agent_summary
    super options
  end

  def build_params
    query_params
  end

  def query_params
    summary_params = { group_by: ["agent_id"] }

    AGENT_SUMMARY_METRICS.inject([]) do |params, metric|
      query = basic_param_structure.merge(summary_params)
      query[:metric] = metric
      params << query
    end
  end

end