require 'spec_helper'

describe Search::V2::SolutionsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    setup_searchv2
    @ticket = @account.tickets.first
  end

  before(:each) do
    log_in(@agent)
    request.env["HTTP_ACCEPT"] = 'application/x-javascript'
  end

  after(:all) do
    teardown_searchv2
  end

  it "should render the correct template for related solutions" do
    get :related_solutions, :ticket => @ticket.id
    response.should render_template('search/solutions/related_solutions')
  end

  it "should render the correct template for search solutions" do
    get :search_solutions, :ticket => @ticket.id
    response.should render_template('search/solutions/search_solutions')
  end
end