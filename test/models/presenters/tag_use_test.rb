require_relative '../test_helper'

class TagUseTest < ActiveSupport::TestCase
	include TagUseTestHelper

  def test_central_publish_payload
    tag_use = create_tag_use(@account)
    payload = tag_use.central_publish_payload.to_json
    msg = JSON.parse(payload)
    payload.must_match_json_expression(central_publish_tag_use_pattern(tag_use))
  end
end