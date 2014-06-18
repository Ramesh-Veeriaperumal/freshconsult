require 'spec_helper'

describe Helpdesk::MobihelpTicketExtrasController do
	integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

	before(:all) do
    @user_email = "mh_user@customer.in"
    @user_device_id = "11111-22222-3333333-31231"
    @user = create_mobihelp_user(@account , @user_email, @user_device_id)
  end

  before(:each) do
    login_admin
  end

  it "should display ticket data" do
    ticket_attributes = get_sample_mobihelp_ticket_attributes("New test ticket", @user_device_id, @user)
    test_ticket = create_mobihelp_ticket(ticket_attributes)
    get :index, :ticket_id => test_ticket
    response.should render_template "helpdesk/mobihelp_ticket_extras/index.html.erb"
  end
end
