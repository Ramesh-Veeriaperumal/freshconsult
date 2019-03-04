require_relative '../test_helper'

class SubscriptionTest < ActiveSupport::TestCase
  include SubscriptionTestHelper

  #def test_subscription_update_without_feature
  #  @account.rollback(:audit_logs_central_publish)
  #  CentralPublisher::Worker.jobs.clear
  #  update_subscription
  #  assert_equal 0, CentralPublisher::Worker.jobs.size
  #ensure
  #  @account.launch(:audit_logs_central_publish)
  #end

  def test_subscription_update_with_feature
    CentralPublisher::Worker.jobs.clear
    update_subscription
    assert_equal 1, CentralPublisher::Worker.jobs.size
    subscription = Account.current.subscription
    payload = subscription.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_post_pattern(subscription))
  end
end
