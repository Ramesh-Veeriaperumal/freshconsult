class HelpdeskReports::ParamConstructor::GroupSummary < HelpdeskReports::ParamConstructor::Base

  GROUP_SUMMARY_METRICS = ["GROUP_SUMMARY_CURRENT", "GROUP_SUMMARY_HISTORIC"]

  def initialize options
    @report_type = :group_summary
    super options
  end

  def build_params
    query_params
  end

  def query_params
    summary_params = { group_by: ["group_id"] }

    GROUP_SUMMARY_METRICS.inject([]) do |params, metric|
      query = basic_param_structure.merge(summary_params)
      query[:metric] = metric
      params << query
    end
  end

end