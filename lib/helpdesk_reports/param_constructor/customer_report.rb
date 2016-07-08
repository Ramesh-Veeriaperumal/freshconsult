class HelpdeskReports::ParamConstructor::CustomerReport < HelpdeskReports::ParamConstructor::Base

  METRICS = ["CUSTOMER_CURRENT_HISTORIC","UNRESOLVED_TICKETS"]

  def initialize options
    @report_type = :customer_report
    super options
  end

  def build_params
    query_params
  end

  def query_params
    cr_params = { group_by: ["company_id"], sorting: true }

    METRICS.inject([]) do |params, metric|
      query = basic_param_structure.merge(cr_params)
      query[:metric] = metric
      params << query
    end

  end

end