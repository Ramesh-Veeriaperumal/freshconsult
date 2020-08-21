require_relative '../test_helper'

class VaRuleTest < ActiveSupport::TestCase
  include VaRuleTestHelper

  def test_va_rule_update_with_feature
    CentralPublisher::Worker.jobs.clear
    update_va_rule
    assert_equal 1, CentralPublisher::Worker.jobs.size
    va_rule = Account.current.va_rules.first
    payload = va_rule.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_post_pattern(va_rule))
  end
end
