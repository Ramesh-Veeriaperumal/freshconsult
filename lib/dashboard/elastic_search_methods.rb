module Dashboard::ElasticSearchMethods
  private

  def fetch_unresolved_tickets_from_es(unresolved = false)
    action_hash,negation_conditions = form_es_query_hash(unresolved)

    es_response = Search::Dashboard::Docs.new(action_hash,negation_conditions,[@group_by,"status"]).aggregation(Helpdesk::Ticket)
    es_res_hash = parse_es_response(es_response)

    #Logic for constructing missing fields starts here...
    action_hash.push({"condition" => @group_by,"operator" => "is_in", "value" => "-1" })
    missing_es_response = Search::Dashboard::Docs.new(action_hash,negation_conditions,["status"]).aggregation(Helpdesk::Ticket)
    missing_es_res_hash = missing_es_response.inject({}) do |res_hash, response|
      res_hash.merge([nil,response["key"]] => response["doc_count"])
    end
    
    missing_es_res_hash.merge!(es_res_hash)
    #Logic for constructing missing fields ends here...

    map_id_to_names(missing_es_res_hash)
  end

  def widget_count_from_es(group_by, unresolved = false, my_view = false)
    action_hash, negation_conditions = form_es_query_hash(unresolved, my_view)
    es_response = Search::Dashboard::Docs.new(action_hash,negation_conditions,[group_by]).aggregation(Helpdesk::Ticket)
    response_hash = es_response.inject({}) do |res_hash,data|
      res_hash.merge!({data["key"] => data["doc_count"]})
    end
    if ["group_id", "ticket_type"].include?(group_by.to_s)
      mis_es_res_hash = {}
      action_hash.push({"condition" => group_by.to_s, "operator" => "is_in", "value" => "-1" })
      missing_es_response = Search::Dashboard::Docs.new(action_hash,negation_conditions,["status"]).aggregation(Helpdesk::Ticket)
      unless missing_es_response.blank?
        mis_es_res_hash = {nil => missing_es_response.map {|r| r["doc_count"]}.sum} 
        response_hash.merge!(mis_es_res_hash)
      end
    end
    
    response_hash
  end

  def form_es_query_hash(unresolved = false, my_view = false )
    action_hash = []
    [:group_id,:responder_id,:status,:priority,:ticket_type].each do |filter|
      next unless params[filter].present?
      filter_value = self.instance_variable_get("@#{filter}").join(',') 
      action_hash.push({ "condition" => filter.to_s, "operator" => "is_in", "value" => filter_value}) if filter_value.present? 
    end
    action_hash.push({ "condition" => "responder_id", "operator" => "is_in", "value" => User.current.id }) if my_view
    action_hash.push(Helpdesk::Filters::CustomTicketFilter.spam_condition(false))
    action_hash.push(Helpdesk::Filters::CustomTicketFilter.deleted_condition(false))
    negative_conditions = (unresolved ? [{ "condition" => "status", "operator" => "is_not", "value" => "#{Helpdesk::Ticketfields::TicketStatus::RESOLVED},#{Helpdesk::Ticketfields::TicketStatus::CLOSED}" }] : [])
    [action_hash,negative_conditions]
  end

  def parse_es_response(es_response)
    es_res_hash = {}
    es_response.each do |data|
      tmp_h = {}
      data["name"]["buckets"].each do |bkt|
        tmp_h[[data["key"],bkt["key"]]] = bkt["doc_count"]
        es_res_hash.merge!(tmp_h)
      end
    end
    es_res_hash
  end
end