require_relative '../test_helper'

class FreshchatAccountTest < ActiveSupport::TestCase
  include FreshchatAccountTestHelper
  include ::Freshchat::Util

  def setup
    super
    @account = @account.make_current
    CentralPublishWorker::FreshchatAccountWorker.jobs.clear
  end

  def teardown
    Account.unstub(:current)
  end

  def test_create_freshchat_account
    @account.launch(:freshid_org_v2)
    @account.freshchat_account&.destroy
    fchat_account = create_freshchat_account @account
    assert_equal 1, CentralPublishWorker::FreshchatAccountWorker.jobs.size
    payload = fchat_account.central_publish_payload.to_json
    payload.must_match_json_expression(freshchat_account_publish_pattern(fchat_account))
    assert_equal fchat_account.domain, "#{@account.domain}.freshchat.com"
    fchat_account.destroy
    @account.rollback(:freshid_org_v2)
  end

  def test_update_freshchat_account
    fchat_account = @account.freshchat_account || create_freshchat_account(@account)
    CentralPublishWorker::FreshchatAccountWorker.jobs.clear
    fchat_account.update_attributes({enabled: !fchat_account})
    assert_equal 1, CentralPublishWorker::FreshchatAccountWorker.jobs.size
    payload = fchat_account.central_publish_payload.to_json
    payload.must_match_json_expression(freshchat_account_publish_pattern(fchat_account))
    job = CentralPublishWorker::FreshchatAccountWorker.jobs.last
    assert_equal 'freshchat_account_update', job['args'][0]
    assert_equal(model_changes_freshchat_account_enabled(!fchat_account.enabled, fchat_account.enabled), job['args'][1]['model_changes'])
    fchat_account.destroy
  end

  def test_destroy_freshchat_account
    fchat_account = create_freshchat_account @account
    CentralPublishWorker::FreshchatAccountWorker.jobs.clear
    fchat_account.destroy
    assert_equal 1, CentralPublishWorker::FreshchatAccountWorker.jobs.size
    job = CentralPublishWorker::FreshchatAccountWorker.jobs.last
    assert_equal 'freshchat_account_destroy', job['args'][0]
    job['args'][1]['model_properties'].must_match_json_expression(freshchat_account_destroy_pattern(fchat_account))
  end

end