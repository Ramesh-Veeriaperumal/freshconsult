module TestClassMethods
  def get_agent
    create_test_account
    @account = Account.first
    @agent = get_admin
  end

  def create_session
    session = UserSession.create!(@agent)
    session.save
  end

  def set_request_params
    @request.host = @account.full_domain
    @request.env['HTTP_REFERER'] = '/sessions/new'
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36\
                                  (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    @request.env['CONTENT_TYPE'] = 'application/json'
  end

  def set_request_headers
    auth = ActionController::HttpAuthentication::Basic.encode_credentials(@agent.single_access_token, 'X')
    @headers = { 'HTTP_AUTHORIZATION' => auth, 'HTTP_HOST' => 'localhost.freshpo.com' }
    @write_headers = @headers.merge('CONTENT_TYPE' => 'application/json')
  end

  def count_api_queries(&block)
    QueryCounter.total_query_count = 0
    QueryCounter.api_query_count = 0
    yield
    [QueryCounter.total_query_count, QueryCounter.api_query_count]
  end

  def count_queries(&block)
    QueryCounter.total_query_count = 0
    yield
    QueryCounter.total_query_count
  end
end

include TestClassMethods
