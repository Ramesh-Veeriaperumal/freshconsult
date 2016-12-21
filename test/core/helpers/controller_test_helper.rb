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
      return user if user.can_view_all_tickets? and user.privilege?(:manage_canned_responses) and !user.agent.occasional?
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
end