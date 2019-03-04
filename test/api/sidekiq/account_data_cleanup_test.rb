
require_relative '../unit_test_helper'
require_relative '../test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
require Rails.root.join('test', 'core', 'helpers', 'groups_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class NewPlanChangeWorkerTest < ActionView::TestCase
  include AccountTestHelper
  include GroupsTestHelper
  def test_round_robin_load_balancing_drop_data
    create_test_account   
    group = @account.groups[0]
    group.capping_limit = 10
    group.ticket_assign_type = 1
    group.save
    SAAS::AccountDataCleanup.new(@account, ["round_robin_load_balancing"], "drop").perform_cleanup
    group.reload
    assert_equal group.capping_limit, 0
    assert_equal group.ticket_assign_type, 0
  end

  def test_round_robin_drop_data   
    create_test_account 
    group = @account.groups[0]
    group.capping_limit = 0
    group.ticket_assign_type = 1
    group.save
    SAAS::AccountDataCleanup.new(@account, ["round_robin"], "drop").perform_cleanup
    group.reload
    assert_equal group.capping_limit, 0
    assert_equal group.ticket_assign_type, 0
  end
		
  def test_in_planchangeworker_round_robin_drop_data_should_not_work
    skip('failures and errors 21')
    create_test_account
    group = @account.groups[0]
    group.capping_limit = 0
    group.ticket_assign_type = 1
    group.save
    PlanChangeWorker.new.perform({:features => ["round_robin", "round_robin_load_balancing"], :action => "drop"})
    group.reload
    assert_equal group.capping_limit, 0
    assert_equal group.ticket_assign_type, 0
  end

  def test_marketplace_apps_cleanup
    create_test_account
    mock_installed_applications = [MiniTest::Mock.new]
    mock_app = MiniTest::Mock.new
    mock_app.expect(:slack?, true)
    mock_installed_applications.first.expect(:application, mock_app)
    mock_installed_applications.first.expect(:destroy, true)
    marketplace_response_body = {}.tap do |app|
      app['id'] = 1
      app['addon'] = {}
    end
    mock_marketplace_ext_response = {}.tap do |app|
      app['id'] = 1
      app['extension_id'] = 1
      app['addon'] = false
    end
    freshrequest_mock = MiniTest::Mock.new
    mock_marketplace_response = MiniTest::Mock.new
    FreshRequest::Client.stubs(:new).returns(freshrequest_mock)
    4.times do
      mock_marketplace_response.expect :status, 200
      mock_marketplace_response.expect :nil?, false
    end
    2.times do
      freshrequest_mock.expect :get, mock_marketplace_response
    end
    mock_marketplace_response.expect :body, [marketplace_response_body]
    mock_marketplace_response.expect :body, [mock_marketplace_ext_response]
    mock_marketplace_response.expect :body, [mock_marketplace_response]
    freshrequest_mock.expect :delete, mock_marketplace_response

    @account.stub(:installed_applications, mock_installed_applications) do
      SAAS::AccountDataCleanup.new(@account, ['custom_apps'], 'drop').perform_cleanup
    end
    assert mock_marketplace_response.verify
    assert freshrequest_mock.verify
  end
end
