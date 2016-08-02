class Dashboard::UnresolvedTicket < Dashboard
  
  attr_accessor :es_enabled, :filter_condition, :group_by, :order_by, :widget_name

  DEFAULT_LIMIT = 10

  WIDGET_OPTIONS = {
    :unresolved_tickets_by_priority     =>  {:method => "aggregation",  :fallback => "db"},
    :unresolved_tickets_by_status       =>  {:method => "aggregation",  :fallback => "db"},
    :unresolved_tickets_by_ticket_type  =>  {:method => "aggregation",  :fallback => "db"},
    :unresolved_tickets_by_age          =>  {:method => "records",      :fallback => "db"}
  }

  #group_by should be an array EX::: ["status"], ["priority"]
  #order by is a string EXX:: "count(*) desc", "created_at desc"
  #filter_condition should be key value pairs EX::: {:group_id => 1, :priority => 3, :responder_id => 1} 
  def initialize(es_enabled, options = {})
    @es_enabled = es_enabled
    @filter_condition = options[:filter_condition].presence || {}
    @group_by = options[:group_by].presence || []
    @order_by = options[:order_by].presence || "created_at asc"
    @widget_name = options[:widget_name].to_sym
  end

  def fetch_aggregation
    tickets_count = if es_enabled
      begin
        aggregation_from_es
      rescue Exception => e
        Rails.logger.info "Exception in Fetching unresolved tickets for Dashboard widget -, #{widget_name}, #{e.message}"
        NewRelic::Agent.notice_error(e)
        return {}
      end
    else
      send("aggregation_from_#{WIDGET_OPTIONS[widget_name][:fallback]}")
    end
    id_name_mapping(tickets_count,group_by.first.to_sym)
  end

  def fetch_records
    if es_enabled
      begin
        records_from_es
      rescue Exception => e
        Rails.logger.info "Exception in Fetching unresolved tickets records for Dashboard widget -,#{widget_name}, #{e.message}"
        NewRelic::Agent.notice_error(e)
      end
    else
      send("records_from_#{WIDGET_OPTIONS[widget_name][:fallback]}")
    end
  end

  private

  def records_from_db
    default_scoper.where(filter_condition).group(group_by).order(order_by).limit(DEFAULT_LIMIT).inject([]) do |res_arr,t|
      res_arr << {:id => t.display_id, :subject => t.subject, :days => (Time.zone.now.to_date - t.created_at.to_date).round}
    end
  end

  def records_from_es
    action_hash,negative_conditions = form_es_query_hash
    es_response = Search::Filters::Docs.new(action_hash, negative_conditions).records('Helpdesk::Ticket',
                                                                          {
                                                                            :order_entity=> "created_at", 
                                                                            :order_sort => "asc", 
                                                                            :page => 1, 
                                                                            :per_page => DEFAULT_LIMIT
                                                                            })
    es_response.inject([]) do |res_arr,t|
      res_arr << {:id => t.display_id, :subject => t.subject, :days => (Time.zone.now.to_date - t.created_at.to_date).round}
    end
  end

  def aggregation_from_db
    default_scoper.where(filter_condition).group(group_by).order(order_by).count
  end

  def aggregation_from_es
    action_hash,negative_conditions = form_es_query_hash
    action_hash.push({ "condition" => "group_id", "operator" => "is_in", "value" => filter_condition[:group_id].to_s}) if filter_condition[:group_id].present?
    es_response = Search::Dashboard::Docs.new(action_hash,negative_conditions,group_by.dup.to_a,options_for_query ).aggregation(Helpdesk::Ticket)
    response_hash = parse_es_response(es_response)
  end

  def options_for_query
    include_missing = ["priority", "status"].include?(group_by.first.to_s) ?  false : true
    {:first_limit => send(GROUP_BY_VALUES_MAPPING[group_by.first.to_s]).count, :include_missing => include_missing}
  end

end