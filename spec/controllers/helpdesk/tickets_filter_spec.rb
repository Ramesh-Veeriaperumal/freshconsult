require 'spec_helper'

describe Helpdesk::TicketsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
    @group = @account.groups.first
  end

  before(:each) do
    log_in(@agent)
  end

  it "should test all filter test cases" do
    get :filter_options
    filters = assigns(:show_options)
    Wf::TestCase.new(filters).working
  end

end