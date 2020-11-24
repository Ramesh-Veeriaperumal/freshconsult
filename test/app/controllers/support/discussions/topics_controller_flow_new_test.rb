# frozen_string_literal: true

require_relative '../../../../api/api_test_helper'
['forum_helper.rb', 'solutions_helper.rb', 'user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
class Support::Discussions::TopicsControllerFlowTest < ActionDispatch::IntegrationTest
  include ForumHelper
  include SolutionsHelper
  include UsersHelper

  def test_monitor_with_different_user_json
    user = add_new_user(@account, active: true)
    user2 = add_new_user(@account, active: true)
    set_request_auth_headers(user)
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    topic = create_test_topic(forum, user2)
    monitorship = monitor_topic(topic, user2)
    params = { user_id: user2.id, status: 0 }
    put "/support/discussions/topics/#{monitorship.monitorable_id}/monitor.json", params
    assert_equal true, response.body.include?('Permission denied for user')
    assert_response 403
  end

  def test_monitor_with_different_user_xml
    user = add_new_user(@account, active: true)
    user2 = add_new_user(@account, active: true)
    set_request_auth_headers(user)
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    topic = create_test_topic(forum, user2)
    monitorship = monitor_topic(topic, user2)
    params = { user_id: user2.id, status: 0 }
    put "/support/discussions/topics/#{monitorship.monitorable_id}/monitor.xml", params
    assert_equal true, response.body.include?('Permission denied for user')
    assert_response 403
  end

  def test_new_when_get_draft_from_redis_throws_error
    user = add_new_user(@account, active: true)
    set_request_auth_headers(user)
    Account.any_instance.stubs(:multilingual?).returns(false)
    Support::Discussions::TopicsController.any_instance.stubs(:preview?).returns(true)
    Portal::Template.any_instance.stubs(:get_draft).raises(StandardError)
    assert_raises(RuntimeError) do
      get 'support/discussions/topics/new', url_locale: nil
    end
  ensure
    Account.any_instance.unstub(:multilingual?)
    Support::Discussions::TopicsController.any_instance.unstub(:preview?)
    Portal::Template.any_instance.unstub(:get_draft)
  end

  private

    def old_ui?
      true
    end
end
