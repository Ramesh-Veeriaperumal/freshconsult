require_relative '../test_helper'

class FreshcallerAccountTest < ActiveSupport::TestCase
  include FreshcallerAccountTestHelper

  def setup
    super
    @account = @account.make_current
    CentralPublishWorker::FreshcallerAccountWorker.jobs.clear
  end

  def teardown
    Account.unstub(:current)
  end

  def test_create_freshcaller_account
    fcaller_account = create_freshcaller_account @account
    assert_equal 1, CentralPublishWorker::FreshcallerAccountWorker.jobs.size
    payload = fcaller_account.central_publish_payload.to_json
    payload.must_match_json_expression(freshcaller_account_publish_pattern(fcaller_account))
    fcaller_account.destroy
  end

  def test_destroy_freshcaller_account
    fcaller_account = create_freshcaller_account @account
    CentralPublishWorker::FreshcallerAccountWorker.jobs.clear
    fcaller_account.destroy
    assert_equal 1, CentralPublishWorker::FreshcallerAccountWorker.jobs.size
    job = CentralPublishWorker::FreshcallerAccountWorker.jobs.last
    assert_equal 'freshcaller_account_destroy', job['args'][0]
    job['args'][1]['model_properties'].must_match_json_expression(freshcaller_account_destroy_pattern(fcaller_account))
  end
end