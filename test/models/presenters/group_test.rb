require_relative '../test_helper'

class GroupTest < ActiveSupport::TestCase
  include GroupsTestHelper

  def test_central_publish_payload
    group = create_group(@account)
    payload = group.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_group_pattern(group))
  end
end