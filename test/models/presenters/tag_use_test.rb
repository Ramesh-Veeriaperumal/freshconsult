require_relative '../test_helper'

class TagUseTest < ActiveSupport::TestCase
  include TagUseTestHelper

  def test_tag_use_publish
    CentralPublisher::Worker.jobs.clear
    create_tag_use(@account, allow_skip: true)
    assert_equal 2, CentralPublisher::Worker.jobs.size
    assert_equal 'tag_create', CentralPublisher::Worker.jobs[0]['args'][0]
    assert_equal 'tag_use_create', CentralPublisher::Worker.jobs[1]['args'][0]
  end

  def test_central_publish_payload
    tag_use = create_tag_use(@account)
    payload = tag_use.central_publish_payload.to_json
    msg = JSON.parse(payload)
    payload.must_match_json_expression(central_publish_tag_use_pattern(tag_use))
  end
end