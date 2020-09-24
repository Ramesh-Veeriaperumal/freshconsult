require 'spec_helper'

RSpec.configure do |c|
  c.include Redis::RedisKeys
  c.include Redis::IntegrationsRedis
  c.include FreshfoneDashboardSpecHelper
end

RSpec.describe Freshfone::DashboardController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false
  
  before(:all) do
    @account.freshfone_calls.destroy_all
  end

  before(:each) do
    create_test_freshfone_account
    @request.host = @account.full_domain
    @account.freshfone_calls.destroy_all
    @account.freshfone_callers.delete_all
  end


  it 'should render valid json on dashboard_stats' do
    log_in(@agent)
    key = Redis::RedisKeys::NEW_CALL % {:account_id => @account.id}
    create_freshfone_user
    add_to_set(key, "1234")
    @freshfone_user.update_attributes(:incoming_preference => 1, :presence => 2)
    get :dashboard_stats, { :format => "json" }
    expected = {
      :available_agents => @account.freshfone_users.online_agents.count,
      :busy_agents => @account.freshfone_users.busy_agents.count,
      :active_calls_count => @account.freshfone_calls.active_calls.count,
      :queued_calls_count => @account.freshfone_calls.queued_calls.count
    }.to_json
    response.body.should be_eql(expected)
  end

  it 'should redirect to login when non-twilio-aware methods are called by not logged in users' do
    get :dashboard_stats, { :format => "json" }
    expected = {
      :require_login => true
    }.to_json
    response.body.should be_eql(expected)
  end

  it 'should return all freshfone numbers on index' do
    log_in(@agent)
    create_in_progress_calls
    create_queued_call
    active_calls_count = @account.freshfone_calls.active_calls.count
    queued_calls_count = @account.freshfone_calls.queued_calls.count
    get :index
    assigns[:freshfone_active_calls].count.should be_eql(active_calls_count)
    assigns[:queued_calls].count.should be_eql(queued_calls_count)
    response.should render_template "freshfone/dashboard/index"
  end
end