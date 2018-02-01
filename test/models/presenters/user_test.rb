require_relative '../test_helper'

class UserTest < ActiveSupport::TestCase

  def test_central_publish_payload
    user = add_new_user(@account)
    payload = user.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_user_pattern(user))
  end
end