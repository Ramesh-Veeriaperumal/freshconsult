module TestClassMethods
  @@last_gc_run = Time.now
  RESERVED_IVARS = %w(@loaded_fixtures @test_passed @fixture_cache @method_name @_assertion_wrapped @_result @__name__ @account @fixture_connections).map(&:to_sym)
  @@reserved_ivars = RESERVED_IVARS
  DEFERRED_GC_THRESHOLD = (ENV['DEFER_GC'] || 1.0).to_f

  def get_agent
    create_test_account
    @account = Account.first
    @agent = get_admin
  end

  def create_session
    @agent.make_current
    session = UserSession.create!(@agent)
    session.save
    set_request_auth_headers
  end

  def clear_instance_variables
    (instance_variables - @@reserved_ivars).each do |ivar|
      instance_variable_set(ivar, nil)
    end
  end

  def begin_gc_deferment
    GC.disable if DEFERRED_GC_THRESHOLD > 0
  end

  def reconsider_gc_deferment
    if DEFERRED_GC_THRESHOLD > 0 && Time.now - @@last_gc_run >= DEFERRED_GC_THRESHOLD
      GC.enable
      GC.start
      GC.disable

      @@last_gc_run = Time.now
    end
  end

  def log_out
    UserSession.find.try(:destroy)
    User.reset_current_user
  end

  def set_request_params
    @request.host = @account.full_domain
    @request.env['HTTP_REFERER'] = '/sessions/new'
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36\
                                  (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    @request.env['CONTENT_TYPE'] = 'application/json'
  end

  def set_request_auth_headers(user = nil)
    if CustomRequestStore.read(:private_api_request) || old_ui?
      UserSession.any_instance.stubs(:cookie_credentials).returns([(user || @agent).persistence_token, (user || @agent).id])
    else
      auth = ActionController::HttpAuthentication::Basic.encode_credentials((user || @agent).single_access_token, 'X')
      @request.env['HTTP_AUTHORIZATION'] = auth
    end
  end

  def set_request_headers
    @headers ||= {}
    if CustomRequestStore.read(:private_api_request) || old_ui?
      UserSession.any_instance.stubs(:cookie_credentials).returns([@agent.persistence_token, @agent.id])
    else
      auth = ActionController::HttpAuthentication::Basic.encode_credentials(@agent.single_access_token, 'X')
      @headers = { 'HTTP_AUTHORIZATION' => auth, 'HTTP_HOST' => 'localhost.freshpo.com' }
    end
    @write_headers = @headers.merge('CONTENT_TYPE' => 'application/json')
  end

  def reset_request_headers
    if CustomRequestStore.read(:private_api_request) || old_ui?
      UserSession.any_instance.unstub(:cookie_credentials)
    end
  end

  def old_ui?
    false
  end

  def set_custom_auth_headers(headers, part1, part2)
    auth = ActionController::HttpAuthentication::Basic.encode_credentials(part1, part2)
    headers.merge('HTTP_AUTHORIZATION' => auth, 'HTTP_HOST' => 'localhost.freshpo.com')
  end

  def count_api_queries
    QueryCounter.total_query_count = 0
    QueryCounter.api_query_count = 0
    QueryCounter.queries = []
    yield
    [QueryCounter.total_query_count, QueryCounter.api_query_count, QueryCounter.queries]
  end

  def trace_query(pattern, block)
    QueryCounter.queries = []
    block.call
    QueryCounter.queries.find { |q| q.match(pattern) }
  end

  def trace_query_condition(pattern, from, to, &block)
    query = trace_query(pattern, block)
    query.partition(from).last.partition(to).first
  end

  def count_queries
    QueryCounter.total_query_count = 0
    yield
    QueryCounter.total_query_count
  end

  def write_to_file(v1, v2, class_name = self.class.name)
    path = "#{Rails.root}/test/api/query_reports"
    if File.exist?("#{path}/#{class_name}_details.rb")
      File.rename("#{path}/#{class_name}_details.rb", "#{path}/#{class_name}_old_details.rb")
    end

    File.open("#{path}/#{class_name}_details.rb", 'w+') do |f|
      f.write(JSON.pretty_generate v1 || {})
      f.write("\n")
      f.write(JSON.pretty_generate v2 || {})
    end
  end

  def enable_cache(block = {})
    system 'memcached &'
    MetalApiController.perform_caching = true
    yield block
  ensure
    MetalApiController.perform_caching = false
    system "ps -ef | grep memcached | grep -v 'grep' | awk '{print $2}' | xargs kill"
  end

  def login_as(user)
    session = UserSession.create!(user)
    session.save
    set_request_auth_headers(user)
  end
end

include TestClassMethods
