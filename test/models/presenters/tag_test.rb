require_relative '../test_helper'

class TagTest < ActiveSupport::TestCase
	include TagTestHelper

  def test_central_publish_payload
    tag = create_tag(@account)
    payload = tag.central_publish_payload.to_json
    msg = JSON.parse(payload)
    payload.must_match_json_expression(central_publish_tag_pattern(tag))
  end
end
