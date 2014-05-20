require 'spec_helper'

describe Helpdesk::MobihelpTicketExtrasController do
	integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

	before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.env['HTTP_REFERER'] = 'sessions/new'
    log_in(@user)
  end

  it "should display ticket data" do
    test_ticket = create_mobihelp_ticket
    get :index, :ticket_id => test_ticket
    response.should render_template "helpdesk/mobihelp_ticket_extras/index.html.erb"
  end
end
