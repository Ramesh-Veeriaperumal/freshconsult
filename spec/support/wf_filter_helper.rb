module WfFilterHelper

  PARAMS1 = {:data_hash=>"[{\"condition\": \"responder_id\", \"operator\": \"is_in\", \"ff_name\": \"default\", \"value\": \"0,-1\"}, {\"condition\": \"group_id\", \"operator\": \"is_in\", \"ff_name\": \"default\", \"value\": \"0,3\"}, {\"condition\": \"status\", \"operator\": \"is_in\", \"ff_name\": \"default\", \"value\": \"2\"}]", 
    :wf_model=>"Helpdesk::Ticket", :wf_order=>"created_at", :wf_order_type=>"desc", :visibility=>{"visibility"=>"3", "user_id"=>"1", "group_id"=>"1"}, :custom_ticket_filter => { :visibility => {"visibility"=>"3", "user_id"=>"1", "group_id"=>"1"}}}
  PARAMS2 = {:data_hash=>"[{\"condition\": \"responder_id\", \"operator\": \"is_in\", \"ff_name\": \"default\", \"value\": \"0,-1\"}, {\"condition\": \"group_id\", \"operator\": \"is_in\", \"ff_name\": \"default\", \"value\": \"0,3\"}, {\"condition\": \"created_at\", \"operator\": \"is_greater_than\", \"ff_name\": \"default\", \"value\": \"60\"}, {\"condition\": \"due_by\", \"operator\": \"due_by_op\", \"ff_name\": \"default\", \"value\": \"4\"}, {\"condition\": \"status\", \"operator\": \"is_in\", \"ff_name\": \"default\", \"value\": \"2,5\"}, {\"condition\": \"priority\", \"operator\": \"is_in\", \"ff_name\": \"default\", \"value\": \"4\"}, {\"condition\": \"ticket_type\", \"operator\": \"is_in\", \"ff_name\": \"default\", \"value\": \"Incident\"}, {\"condition\": \"source\", \"operator\": \"is_in\", \"ff_name\": \"default\", \"value\": \"8\"}]", 
    :filter_name=>"Blah", :wf_model=>"Helpdesk::Ticket", :wf_order=>"created_at", :wf_order_type=>"desc", :visibility=>{"visibility"=>"3", "user_id"=>"1", "group_id"=>"1"}, :custom_ticket_filter => { :visibility => {"visibility"=>"3", "user_id"=>"1", "group_id"=>"1"}}}

  COMPARABLE_KEYS = [:wf_order, :wf_model, :wf_order_type]
  DEFAULT_FILTER = 'all_tickets'

  def create_filter args 
    params = {:filter_name => Faker::Name.name}.merge(args.symbolize_keys!)
    wf_filter = Helpdesk::Filters::CustomTicketFilter.deserialize_from_params(params)
    wf_filter.visibility = params[:visibility]
    wf_filter.save
    wf_filter
  end

  def check_filter_equality filter, params
    filter_hash = filter.serialize_to_params
    params_data_hash = JSON.parse params[:data_hash]
    Helpdesk::Filters::CustomTicketFilter::DEFAULT_FILTERS[DEFAULT_FILTER].each do |filter|
      params_data_hash << filter
    end

    COMPARABLE_KEYS.each do |key|
      filter_hash[key].should be_eql(params[key])
    end
    filter.data[:data_hash].should be_eql(params_data_hash)
  end

end