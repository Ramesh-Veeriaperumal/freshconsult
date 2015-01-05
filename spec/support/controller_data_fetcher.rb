class ControllerDataFetcher

  # Use this class to fetch acessible variables of the controllers
  # Done by initializing the controller and populating the required variables like request, current_url

  # HOW TO :-
  # In RETRIEVE_VARIABLES constant just add the controller variables to be fetched under the controller name
  # Then set the current account and current user and use the methods 
  # For reference, check va_rule_spec.rb, before(:all) method

  ENV = { "REQUEST_METHOD"=>"GET", "REQUEST_PATH"=>"/admin/observer_rules/8/edit", "REQUEST_URI"=>"/admin/observer_rules/8/edit", "HTTP_VERSION"=>"HTTP/1.1", "HTTP_HOST"=>"localhost.freshpo.com", "HTTP_CONNECTION"=>"keep-alive", "HTTP_CACHE_CONTROL"=>"max-age=0", "HTTP_ACCEPT"=>"text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8", 
    "HTTP_USER_AGENT"=>"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.131 Safari/537.36", "HTTP_REFERER"=>"http://localhost.freshpo.com:3000/admin/observer_rules", "HTTP_ACCEPT_ENCODING"=>"gzip,deflate,sdch", "HTTP_ACCEPT_LANGUAGE"=>"en-US,en;q=0.8", 
    "HTTP_COOKIE"=>"user_credentials=3e242c9cc64bb0320302333bd121b405f33b1b17541af343181cdf20c3058fffb09609074187993ec528efccb52a0a1b5fec2d251e8b60925d589f71d8522e59%3A%3A1; helpdesk_node_session=df9e0910c54e9a0f908f74793eb19afb5be302da166328b10e1eb7fb2b365e7d4c54c61774808a8f9e052cb11a118efa4b02815292ddb41fd26ecf61d8f694ff; 
    contacts_sort=all; wf_order=created_at; wf_order_type=desc; ticket_view_choice=detail; filter_name=new_and_my_open; 
    _helpkit_session=BAh7CToPc2Vzc2lvbl9pZEkiJTdmYWFjZmVkMWM3NmNlNDZhM2Q0YzlkYWFmMTc4YWVhBjoGRVRJIhV1c2VyX2NyZWRlbnRpYWxzBjsGRkkiAYAzZTI0MmM5Y2M2NGJiMDMyMDMwMjMzM2JkMTIxYjQwNWYzM2IxYjE3NTQxYWYzNDMxODFjZGYyMGMzMDU4ZmZmYjA5NjA5MDc0MTg3OTkzZWM1MjhlZmNjYjUyYTBhMWI1ZmVjMmQyNTFlOGI2MDkyNWQ1ODlmNzFkODUyMmU1OQY7BlRJIhh1c2VyX2NyZWRlbnRpYWxzX2lkBjsGRmkGSSIKZmxhc2gGOwZGSUM6J0FjdGlvbkNvbnRyb2xsZXI6OkZsYXNoOjpGbGFzaEhhc2h7AAY6CkB1c2VkewA%3D--056fc4e4a2e5447cbf233d9558b20ca1048526e3", 
    "GATEWAY_INTERFACE"=>"CGI/1.2", "SERVER_NAME"=>"localhost.freshpo.com", "SERVER_PORT"=>"3000", "SERVER_PROTOCOL"=>"HTTP/1.1", "SERVER_SOFTWARE"=>"Mongrel 1.2.0.pre2", "PATH_INFO"=>"/admin/observer_rules/8/edit", "SCRIPT_NAME"=>"", "REMOTE_ADDR"=>"127.0.0.1", "rack.version"=>[1, 1],
    "rack.multithread"=>false, "rack.multiprocess"=>false, "rack.run_once"=>false, "rack.url_scheme"=>"http", "QUERY_STRING"=>"", "rack.session"=>{:session_id=>"7faacfed1c76ce46a3d4c9daaf178aea", "user_credentials"=>"3e242c9cc64bb0320302333bd121b405f33b1b17541af343181cdf20c3058fffb09609074187993ec528efccb52a0a1b5fec2d251e8b60925d589f71d8522e59", "user_credentials_id"=>1, "flash"=>{}}, 
    "rack.session.options"=>{:key=>"_session_id", :domain=>nil, :path=>"/", :expire_after=>nil, :httponly=>true, :id=>"7faacfed1c76ce46a3d4c9daaf178aea"}, "CLIENT_IP"=>"127.0.0.1", "rack.request.query_string"=>"", "rack.request.query_hash"=>{}, "action_controller.request.path_parameters"=>{"controller"=>"admin/observer_rules", "action"=>"edit", "id"=>"8"}, 
    "rack.session.options"=>{:key=>"_session_id", :domain=>nil, :path=>"/", :expire_after=>nil, :httponly=>true, :id=>"7faacfed1c76ce46a3d4c9daaf178aea"}, "CLIENT_IP"=>"127.0.0.1", "rack.request.query_string"=>"", "rack.request.query_hash"=>{},'rack.input'=>'testing',
    "action_controller.request.path_parameters"=>{"controller"=>"admin/observer_rules", "action"=>"edit", "id"=>"8"}
  }

  REQUEST  = ActionController::Request.new ENV

  RETRIEVE_VARIABLES = {  Helpdesk::ScenarioAutomationsController => [:action_defs],
                          Admin::VaRulesController                => [:action_defs, :filter_defs, :op_types],
                          Admin::SupervisorRulesController        => [:action_defs, :filter_defs, :time_based_filters, :op_types],
                          Admin::ObserverRulesController          => [:action_defs, :filter_defs, :event_defs,
                                                                        :op_types] }

  CONTROLLER_ATTR_ACCESSORS = [:action_defs, :filter_defs, :event_defs, :op_types]

  attr_accessor :controller

  def initialize controller_class
    unless RETRIEVE_VARIABLES.keys.include?(controller_class)
      raise 'Class should be defined in ControllerDataFetcher::RETRIEVE_VARIABLES'
    end
    @controller = controller_class.new
    CONTROLLER_ATTR_ACCESSORS.each do |accessor_variable|
      @controller.class.send :attr_accessor, accessor_variable
    end
  end

  def fetch_data
    prep_the_controller 
    retrieve_data
  end

  private

    def prep_the_controller
      controller.request = REQUEST
      controller.params = {}
      controller.send :initialize_current_url # Actioncontroller::Base method # Hack
      controller.send :load_config
    end

    def retrieve_data
      RETRIEVE_VARIABLES[controller.class].each do |var|
        self.class.send :attr_accessor, var
        retrieve var
      end
    end

    def retrieve var
      send("#{var}=", controller.send(var))
    end

end