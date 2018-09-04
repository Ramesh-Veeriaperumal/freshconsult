require_relative '../test_helper'

class PostTest < ActiveSupport::TestCase
  include DiscussionsTestHelper

  def setup
    super
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account.launch(:post_central_publish)
    @@before_all_run = true
  end

  def test_central_publish_with_launch_party_disabled
    @account.rollback(:post_central_publish)
    CentralPublisher::Worker.jobs.clear
    t = create_test_topic(Forum.first)
    assert_equal 0, CentralPublisher::Worker.jobs.size
  ensure
    @account.launch(:post_central_publish)
  end

  def test_central_publish_with_launch_party_enabled
    CentralPublisher::Worker.jobs.clear
    t = create_test_topic(Forum.first)
    assert_equal 1, CentralPublisher::Worker.jobs.size
  end

  def test_post_create_with_central_publish
    test_topic = create_test_topic(Forum.first)
    test_post = create_test_post(test_topic)
    payload = test_post.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_post_pattern(test_post))
    assoc_payload = test_post.associations_to_publish.to_json
    assoc_payload.must_match_json_expression(central_publish_post_association_pattern)
  end
end