module ControllerTestHelper

  def log_in(user)
    session = UserSession.create!(user) if user.present?
  end

  def login_admin()
    @agent = get_admin
    log_in(@agent)
  end

  def get_admin()
    users = @account.account_managers
    users.each do |user|
      return user if user.agent && user.can_view_all_tickets? && user.privilege?(:manage_canned_responses) && !user.agent.occasional? && user.active?
    end
    add_test_agent(@account)
  end

  def set_request_params
    @request.host = @account.full_domain
    @request.env['HTTP_REFERER'] = '/sessions/new'
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36\
                                  (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    @request.env['CONTENT_TYPE'] = 'application/json'
  end

  def set_request_auth_headers(user = nil)
    if CustomRequestStore.read(:private_api_request)
      UserSession.any_instance.stubs(:cookie_credentials).returns([(user || @agent).persistence_token, (user || @agent).id])
    else
      auth = ActionController::HttpAuthentication::Basic.encode_credentials((user || @agent).single_access_token, 'X')
      @request.env['HTTP_AUTHORIZATION'] = auth
    end
  end

  def login_as(user)
    session = UserSession.create!(user) if user.present?
    session.save
    set_request_auth_headers user
  end
  
  def log_out
    UserSession.find.try(:destroy)
    User.reset_current_user
  end
end
