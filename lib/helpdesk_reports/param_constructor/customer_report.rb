class HelpdeskReports::ParamConstructor::CustomerReport < HelpdeskReports::ParamConstructor::Base

  def initialize options
    @report_type = :customer_report
    super options
  end

  def build_params
    query_params
  end

  def query_params
    cr_params = {
        metric: "CUSTOMER_CURRENT_HISTORIC",
        group_by: ["company_id"],
    }
    cr_params = basic_param_structure.merge(cr_params)
    [cr_params]
  end

end