require_relative '../unit_test_helper'
require 'sidekiq/testing'
require 'faker'
require 'webmock/minitest'

Sidekiq::Testing.fake!

require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'agent_status_test_helper.rb')

class UpdateAgentStatusAvailabilityTest < ActiveSupport::TestCase
  include AccountTestHelper
  include AgentStatusTestHelper
  def setup
    @account = Account.first.present? ? Account.first.make_current : create_test_account
    agent = @account.users.where(helpdesk_agent: true).first
    User.stubs(:current).returns(agent)
    WebMock.allow_net_connect!
  end

  def teardown
    Account.reset_current_account
    User.reset_current_user
  end

  def test_worker_hitting_shift_microservice
    req_stub = stub_request(:patch, 'http://localhost:8080/api/v1/agent_statuses').to_return(body: sample_show.to_json, status: 200)
    UpdateAgentStatusAvailability.new.perform(request_id: SecureRandom.uuid)
    assert_equal 0, UpdateAgentStatusAvailability.jobs.size
  ensure
    UpdateAgentStatusAvailability.jobs.clear
    remove_request_stub(req_stub)
  end

  def test_worker_should_rescue_error
    User.stubs(:current).returns(nil)
    resp = UpdateAgentStatusAvailability.new.perform(request_id: SecureRandom.uuid)
    assert_equal false, resp
  ensure
    UpdateAgentStatusAvailability.jobs.clear
  end
end
