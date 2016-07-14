class HelpdeskReports::ParamConstructor::Glance < HelpdeskReports::ParamConstructor::Base
  include HelpdeskReports::Field::Ticket

  METRICS = [ "RECEIVED_TICKETS", "RESOLVED_TICKETS","UNRESOLVED_TICKETS", 
              "REOPENED_TICKETS", "AVG_FIRST_RESPONSE_TIME", "AVG_RESPONSE_TIME",
              "AVG_RESOLUTION_TIME", "AVG_FIRST_ASSIGN_TIME", "FCR_TICKETS",
              "RESPONSE_SLA", "RESOLUTION_SLA","UNRESOLVED_PREVIOUS_BENCHMARK"]

  BUCKET_METRICS_AND_CONDS = {
    "RECEIVED_TICKETS" => ["customer_interactions", "agent_interactions"],
    "RESOLVED_TICKETS" => ["customer_interactions", "agent_interactions"],
    "REOPENED_TICKETS" => ["customer_interactions", "agent_interactions", "reopen_count"]
  }

  def initialize options
    @report_type = :glance
    super options
  end

  def build_params
    query_params | bucket_query_params
  end

  def query_params
    glance_params = {
      reference: true
    }

    METRICS.inject([]) do |params, metric|
      query = basic_param_structure.merge(glance_params)
      query[:metric] = metric
      query[:group_by] = glance_group_by(metric)
      params << query
    end
  end

  def bucket_query_params
    BUCKET_METRICS_AND_CONDS.keys.inject([]) do |params, metric|
      bucket_query = basic_param_structure
      bucket_query[:reference] = false
      bucket_query[:metric] = metric
      bucket_query[:bucket] = true
      bucket_query[:bucket_conditions] = BUCKET_METRICS_AND_CONDS[metric]
      params << bucket_query
    end
  end

  def glance_group_by metric
    status_metrics = ["RECEIVED_TICKETS", "REOPENED_TICKETS","UNRESOLVED_TICKETS"]
    gp_by = ["source", "priority", "ticket_type"]

    gp_by |= ["product_id"] if Account.current.products.any?   
    gp_by |= ["status"] if status_metrics.include?(metric)
    gp_by |= ["historic_status"] if metric == "UNRESOLVED_TICKETS"
    gp_by |= check_and_add_custom_field_in_group_by
  end

  def check_and_add_custom_field_in_group_by
    cf = Account.current.custom_dropdown_fields_from_cache.first || Account.current.nested_fields_from_cache.first 
    cf ? [cf.flexifield_def_entry.flexifield_name] : []
  end

end